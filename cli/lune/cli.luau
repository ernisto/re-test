local fs = require('@lune/fs')
local process = require('@lune/process')
local test = require('@pkg/test')

local path = process.args[1] or '.'
local parents_children = { { path } }
local specs = {}

for _, children in parents_children do
	for _, child in children do
		if fs.isDir(child) then
			table.insert(parents_children, fs.readDir(child))
			continue
		end
		if not child:match('%.spec%.luau?$') then continue end

		local success, result = xpcall(require :: any, debug.traceback, child)
		if type(result) ~= 'table' then
			print(`unexpected return ('{result}') during require('{child}')`)
			continue
		end
		if not success then
			print(`error {result} ocurred during require('{child}')`)
			continue
		end

		local spec = if type(result.run) == 'table' then result else { run = result }
		spec.name = spec.name or child:match('([^/\\]+)%.spec%.luau?$')
		spec.path = spec.path or child
		spec.focus = spec.focus or {}
		spec.skip = spec.skip or {}
		table.insert(specs, spec)
	end
end

test.run(specs)
