local file = require('./file')
local process = require('@lune/process')
local stdio = require('@lune/stdio')
local test = require('@pkg/test')

-- utils
local red = '\27[91m'
local yellow = '\27[33m'
local cyan = '\27[96m'
local white = '\27[38m'
local reset = '\27[0m'
local dim = '\27[2m'

local function fancy_traceback(err: string): string
	local path, line, msg, traceback =
		tostring(err):match('^runtime error: (%w:[^:]+):(%d+): ([^\n]+)\nstack traceback:\n(.+)\nstack traceback:')
	if not path or not msg or not traceback then return tostring(err) end

	local display = `{file.relative_path_to(process.cwd, path)}:{line} {msg}{dim}{white}`

	for _, stackframe in { unpack(traceback:split('\n'), 3) } do
		local _path, _line, _function_name = stackframe:match('^%s*(%w:[^:]+):(%d+): in ([^\n]+)')
		if not _path or not _line then continue end
		display ..= `\n{file.relative_path_to(process.cwd, _path)}:{_line} {_function_name ~= '?' and _function_name or ''}`
	end

	return display
end
local function warn(msg: string)
	print(yellow .. msg .. reset)
end

-- script
local installation_path = file.module_location()
local paths: { string } = if process.args[1] then table.clone(process.args) else { '.' }
local specs = {}

-- scan
for _, child in file.read_descendants_paths(paths[1]) do
	if not child:match('%.spec%.luau?$') then continue end

	local require_path = file.relative_path_to(installation_path, process.cwd .. child):gsub('%.luau?$', '')
	local success, result = xpcall(require, fancy_traceback, require_path)

	if not success then
		warn(`│ Error ocurred during require({cyan}'{child}'{yellow})\n{red}│ {result:gsub('\n', '\n│ ')}`)
		continue
	end
	if type(result) ~= 'table' then
		warn(`Unexpected return ({cyan}{stdio.format(result)}{yellow}) during require({cyan}'{child}'{yellow})`)
		continue
	end

	local spec = if type(result.run) == 'table' then result else { run = result }
	spec.name = spec.name or child:match('([^/\\]+)%.spec%.luau?$')
	spec.path = if spec.path
		then file.relative_path_to(process.cwd, spec.path)
		else file.clear_path((child:gsub('%.luau?$', '')))

	spec.focus = spec.focus or {}
	spec.skip = spec.skip or {}
	table.insert(specs, spec)
end

-- run
test.run(specs)
