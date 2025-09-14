local process = require('@lune/process')
if (require('@lune/net') :: any).tcp == nil then
	print(`\27[91mLune version below 0.10.0 detected, pls make sure you are using lune 0.10.2\27[39m`)
	return process.exit(1)
end

local file = require('./file')
local fs = require('@lune/fs')
local stdio = require('@lune/stdio')
local test = require('@pkg/test')

-- utils
local red = '\27[91m'
local yellow = '\27[33m'
local cyan = '\27[96m'
local white = '\27[38m'
local reset = '\27[0m'
local dim = '\27[2m'

local function abs_path_to_cwd_relative(path: string): string
	return file.relative_path_to(process.cwd, path)
end
local function fancy_traceback(err: string): string
	local path, line, msg, traceback =
		tostring(err):match('^runtime error: (%w:[^:]+):(%d+): ([^\n]+)\nstack traceback:\n(.+)\nstack traceback:')
	if not path or not msg or not traceback then return tostring(err) end

	local display = `{abs_path_to_cwd_relative(path)}:{line} {msg}{dim}{white}`

	for _, stackframe in { unpack(traceback:split('\n'), 3) } do
		local _path, _line, _function_name = stackframe:match('^%s*(%w:[^:]+):(%d+): in ([^\n]+)')
		if not _path or not _line then continue end
		display ..= `\n{abs_path_to_cwd_relative(_path)}:{_line} {_function_name ~= '?' and _function_name or ''}`
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
local lune_env = {
	abs_path_to_cwd_relative = abs_path_to_cwd_relative,
	read_file = fs.readFile,
}

-- scan
local did_require_fail = false
for _, cwd_to_child in file.read_descendants_paths(paths[1]) do
	if not cwd_to_child:match('%.spec%.luau?$') then continue end

	local require_path = file.relative_path_to(installation_path, process.cwd .. cwd_to_child):gsub('%.luau?$', '')
	local success, result = xpcall(require, fancy_traceback, require_path)

	if not success then
		warn(`│ Error ocurred during require({cyan}'{cwd_to_child}'{yellow})\n{red}│ {result:gsub('\n', '\n│ ')}`)
		did_require_fail = did_require_fail or true
		continue
	end
	if type(result) ~= 'table' then
		warn(`Unexpected return ({cyan}{stdio.format(result)}{yellow}) during require({cyan}'{cwd_to_child}'{yellow})`)
		did_require_fail = did_require_fail or true
		continue
	end

	local spec = if type(result.run) == 'table' then result else { run = result }
	spec.name = spec.name or cwd_to_child:match('([^/\\]+)%.spec%.luau?$')
	spec.path = if spec.path
		then file.relative_path_to(process.cwd, spec.path)
		else file.clear_path((cwd_to_child:gsub('%.luau?$', '')))

	spec.focus = spec.focus or {}
	spec.skip = spec.skip or {}
	table.insert(specs, spec)
end

-- run
local result = test.run(lune_env, specs)
if did_require_fail or result.fails > 0 then process.exit(1) end
