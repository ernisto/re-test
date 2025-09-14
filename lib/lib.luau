local display = require('./display')
local highlight_syntax = display.highlight_syntax
local render_bar = display.render_bar
local txt_color = display.txt_color
local format_time = display.time
local bold = display.bold
local tag = display.tag

local nerdfont = display.nerdfont
local theme = display.theme
local reset = display.reset
local dim = display.dim

type case_defs = { [string]: test_fn }
type case = { name: string, fn: test_fn, skipped: true?, focused: true? }
type test_fn = () -> ()
type spec = { name: string, path: string, run: case_defs, focus: case_defs, skip: case_defs }

type cwd_path = string -- ./**/*.luau?
type absolute_path = string -- C:/**/*.luau?
export type env_fs = {
	read_file: (absolute_path) -> string,
	abs_path_to_cwd_relative: (absolute_path) -> cwd_path,
}

-- functions
local function spec_test(input_name: string?): (spec, ...case_defs)
	local path = debug.info(2, 's')
	local lune_path = path:match('%[string (%b"")%]')
	if lune_path then path = lune_path:sub(2, -2) end

	local name = input_name or path:gsub('%.luau?$', ''):gsub('%.spec$', ''):match('([^/\\]+)$')
	local run = {}
	local focus = {}
	local skip = {}
	return { name = name, path = path, run = run, focus = focus, skip = skip }, run, focus, skip
end

type spec_collection = { spec: spec, cases: { case } }
local function collect(specs: { spec }): { count: number, specs: { spec_collection } }
	local count = 0
	local theres_focused = false
	local spec_collection = {}

	for _, spec in specs do
		local run, focus, skip = spec.run, spec.focus, spec.skip
		local test_cases: { case } = {}

		for name, fn in run do
			table.insert(test_cases, { name = name, fn = fn })
		end
		for name, fn in skip do
			table.insert(test_cases, { name = name, fn = fn, skipped = true })
		end
		for name, fn in focus do
			table.insert(test_cases, { name = name, fn = fn, focused = true })
			theres_focused = true
		end
		table.insert(spec_collection, { spec = spec, cases = test_cases })
		count += #test_cases
	end

	if theres_focused then
		for _, collection in spec_collection do
			local tests = collection.cases
			for index = #tests, 1, -1 do
				local test = tests[index]
				if test.focused then continue end

				table.remove(tests, index)
				count -= 1
			end
		end
	end

	return { count = count, specs = spec_collection }
end

local function task_poll()
	local pending_count = 0
	local waiting

	local function add(func)
		pending_count += 1
		coroutine.wrap(function()
			pcall(func)
			pending_count -= 1
			if pending_count == 0 then coroutine.resume(waiting) end
		end)()
	end
	local function wait()
		if pending_count == 0 then return end
		waiting = coroutine.running()
		coroutine.yield()
	end

	return add, wait
end

export type suite_test_result = { time: number, tests: number, fails: number, passes: number, skips: number }
local function run(env_fs: env_fs, specs: { spec }): suite_test_result
	local total_time = 0
	local total = collect(specs)

	local total_passed = 0
	local total_failed = 0
	local total_skipped = 0

	local function draw_backtrace(msg: string): () -> string
		local stackframes = {}
		local level = 2

		local spawn_job, wait_all_jobs = task_poll()
		repeat
			level += 1
			local path, line, func = debug.info(level, 'slf')
			if not path then break end

			local stackframe = { path = path, line = line, func = func, code = nil :: string? }
			table.insert(stackframes, stackframe)

			spawn_job(function()
				stackframe.code = env_fs.read_file(path .. '.luau')
			end)
		until false

		local function await_extract_err()
			local display = ''
			wait_all_jobs()

			for i, stackframe in stackframes do
				if i == #stackframes - 2 then break end
				local code, path, error_line = stackframe.code, stackframe.path, stackframe.line
				local _def_line, def_name = debug.info(stackframe.func, 'ln')
				if error_line == -1 then continue end

				-- stylua: ignore
				display ..= `\n{dim}{theme.number}{env_fs.abs_path_to_cwd_relative(path)}:{error_line}: `
					.. `{theme.keyword}function`
					.. (if def_name then ` {theme.func_name}{def_name}` else '')

				if not code then continue end
				local error_code_line = code:split('\n')[error_line]:gsub('^%s+', '')

				local first_line = `{env_fs.abs_path_to_cwd_relative(path)}:{error_line}: `
				display ..= '\n' .. string.rep(' ', #first_line + 4) .. dim .. highlight_syntax(error_code_line)
			end

			return msg, display
		end
		return await_extract_err
	end

	for _, collection in total.specs do
		local tests = collection.cases
		local collection_name = collection.spec.name
		print('│ ' .. tag(4, nerdfont.lua, collection_name) .. ' ' .. dim .. collection.spec.path .. reset)

		local skipped = 0
		local failed = 0
		local passed = 0

		for _, case in tests do
			local name = case.name:gsub('^%l', string.upper):gsub('_', ' ')
			if case.skipped then
				print('│   ' .. tag(3, display.nerdfont.skip, 'SKIP') .. ' ' .. txt_color(3) .. bold(name) .. reset)
				skipped += 1
				continue
			end

			local start = os.clock()
			local ok, err = xpcall(case.fn :: any, draw_backtrace)

			local took_time = os.clock() - start
			total_time += took_time

			local color, str = format_time(took_time)
			local timer = txt_color(color) .. str

			if ok then
				passed += 1
				local prefix = tag(2, display.nerdfont.check, 'PASS')

				print(`│   {prefix} {txt_color(2)}{bold(name)}{reset} {dim}{timer}{reset}`)
			else
				failed += 1
				local path_msg, backtrace = err()
				local nested_backtrace = backtrace:gsub('\n', reset .. '\n│   ' .. dim)
				local msg = path_msg:gsub('^C:[^:]+:%d+: ', '')

				local prefix = tag(1, display.nerdfont.bad, 'FAIL')
				print(
					`│   {prefix} {txt_color(1)}{bold(name)}{reset} {msg} {dim}{timer}{nested_backtrace}{reset}\n│`
				)
			end
		end

		total_passed += passed
		total_failed += failed
		total_skipped += skipped
		print('│ ')
	end

	print('╰' .. render_bar(total.count, total_passed, total_failed, total_skipped, total_time))
	print()
end

-- module
return table.freeze({
	spec = spec_test,
	run = run,
})
