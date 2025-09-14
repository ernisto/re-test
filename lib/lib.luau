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
local no_dim = '\27[22m'

type test_fn = () -> ()
type case_defs = { [string]: test_fn }
type case = { name: string, fn: test_fn, skipped: true?, focused: true? }
type suite = { name: string, path: string, run: case_defs, focus: case_defs, skip: case_defs }

type cwd_path = string -- ./**/*.luau?
type absolute_path = string -- C:/**/*.luau?
export type env_fs = {
	read_file: (absolute_path) -> string,
	abs_path_to_cwd_relative: (absolute_path) -> cwd_path,
}

-- functions
local function suite(input_name: string?): (suite, ...case_defs)
	local path = debug.info(2, 's')
	local lune_path = path:match('%[string (%b"")%]')
	if lune_path then path = lune_path:sub(2, -2) end

	local name = input_name or path:gsub('%.luau?$', ''):gsub('%.suite$', ''):match('([^/\\]+)$')
	local run = {}
	local focus = {}
	local skip = {}
	return { name = name, path = path, run = run, focus = focus, skip = skip }, run, focus, skip
end

type collected_suite = { suite: suite, cases: { case } }
local function collect(suites: { suite }): { count: number, suites: { collected_suite } }
	local count = 0
	local theres_focused = false
	local collected_suites = {}

	for _, suite in suites do
		local run, focus, skip = suite.run, suite.focus, suite.skip
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
		table.sort(test_cases, function(case1, case2)
			return debug.info(case1.fn, 'l') < debug.info(case2.fn, 'l')
		end)
		table.insert(collected_suites, { suite = suite, cases = test_cases })
		count += #test_cases
	end

	if theres_focused then
		for _, collection in collected_suites do
			local tests = collection.cases
			for index = #tests, 1, -1 do
				local test = tests[index]
				if test.focused then continue end

				table.remove(tests, index)
				count -= 1
			end
		end
	end

	table.sort(collected_suites, function(suite1, suite2)
		return suite1.suite.name < suite2.suite.name
	end)

	return { count = count, suites = collected_suites }
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
local function parse_error(path_msg: any): (string, string)
	local msg = if type(path_msg) == 'string'
		then path_msg:gsub('^C:[^:]+:%d+:%s*', '')
		elseif type(path_msg) == 'table' and rawget(path_msg, 'why') then tostring(path_msg.why)
		else tostring(path_msg)

	local a, b = string.match(msg, '^([^\n]*)(.*)')
	return a :: any, b :: any
end

export type suite_test_result = { time: number, tests: number, fails: number, passes: number, skips: number }
local function run(env_fs: env_fs, suites: { suite }): suite_test_result
	local total_time = 0
	local total = collect(suites)

	local total_passed = 0
	local total_failed = 0
	local total_skipped = 0

	local function draw_backtrace(msg: any): () -> string
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

				if error_line == -1 then continue end
				local def_name = debug.info(stackframe.func, 'n')

				-- stylua: ignore
				display ..= `\n  {theme.number}{env_fs.abs_path_to_cwd_relative(path)}.luau:{error_line} `
					.. `{theme.keyword}function {theme.func_name}{def_name or ''}{txt_color()}`

				if not code then continue end
				local error_code_line = code:split('\n')[error_line]:gsub('^%s+', '')

				-- stylua: ignore
				display ..= `\n  {string.format('%4i', error_line)} | {no_dim}{highlight_syntax(error_code_line)}{dim}`
			end

			return msg, display
		end
		return await_extract_err
	end

	for _, collection in total.suites do
		local tests = collection.cases
		local collection_name = collection.suite.name
		print('│ ' .. tag(4, nerdfont.lua, collection_name) .. ' ' .. dim .. collection.suite.path .. reset)

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
				local title, sub = parse_error(path_msg)

				local nested_backtrace = backtrace:gsub('\n', reset .. '\n│   ' .. dim)
				local err_desc = sub:gsub('\n', '\n│     ')

				local prefix = tag(1, display.nerdfont.bad, 'FAIL')
				print(
					`│   {prefix} {txt_color(1)}{bold(name)}{reset} {title} {dim}{timer}{reset}{err_desc}{dim}{nested_backtrace}{reset}\n│`
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

	return table.freeze {
		time = total_time,
		tests = total.count,
		fails = total_failed,
		passes = total_passed,
		skips = total_skipped,
	}
end

-- module
return table.freeze {
	suite = suite,
	run = run,
}
