local display = require('./display')
local render_bar = display.render_bar
local txt_color = display.txt_color
local format_time = display.time
local bold = display.bold
local tag = display.tag

local nerdfont = display.nerdfont
local reset = display.reset
local dim = display.dim

type case_defs = { [string]: test_fn }
type case = { name: string, fn: test_fn, skipped: true?, focused: true? }
type test_fn = () -> ()
type spec = { name: string, path: string, run: case_defs, focus: case_defs, skip: case_defs }

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

local function run(specs: { spec })
	local total_time = 0
	local total = collect(specs)

	local total_passed = 0
	local total_failed = 0
	local total_skipped = 0

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

			local function with_trace(err)
				return debug.traceback(reset .. '│   ' .. dim .. err, 2):gsub('\n[^\n]+\n[^\n]+\n?$', '')
			end

			local start = os.clock()
			local ok, err = xpcall(case.fn :: any, with_trace)

			local took_time = os.clock() - start
			total_time += took_time

			local color, str = format_time(took_time)
			local timer = ' ' .. dim .. txt_color(color) .. str

			if ok then
				passed += 1
				print(
					'│   '
						.. tag(2, display.nerdfont.check, 'PASS')
						.. ' '
						.. txt_color(2)
						.. bold(name)
						.. timer
						.. reset
				)
			else
				failed += 1
				print(
					'│   '
						.. tag(1, display.nerdfont.bad, 'FAIL')
						.. ' '
						.. txt_color(1)
						.. bold(name)
						.. timer
						.. '\n'
						.. dim
						.. err:gsub('\n$', ''):gsub('\n', reset .. '\n│   ' .. dim)
						.. reset
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
