local fs = require('@lune/fs')
local task = require('@lune/task')

-- defs
export type path = relative_path | absolute_path
export type relative_path<from = absolute_path> = string
export type absolute_path = string

-- functions
type ptr<T> = { T }
local function spawn_read_descendants_paths(path: string, local_path: string, out: { string }, remaining: ptr<number>)
	for _, name in fs.readDir(path) do
		remaining[1] += 1
		task.spawn(function()
			if fs.isFile(path .. '/' .. name) then
				table.insert(out, local_path .. '/' .. name)
			else
				spawn_read_descendants_paths(path .. '/' .. name, local_path .. '/' .. name, out, remaining)
			end
			remaining[1] -= 1
		end)
	end
end
local function read_descendants_paths_handle(path: path): { path }
	local remaining = { 0 }
	local out = {}

	spawn_read_descendants_paths(path, path, out, remaining)
	while remaining[1] > 0 do
		task.wait()
	end

	return out
end

local function clear_path(path: absolute_path): string
	local count = 0
	repeat
		path, count = path:gsub('[/\\]([^/\\%.]+)[/\\]%.%.', '') -- resolve '..'
	until count == 0

	return path
		:gsub('[/\\]%.([/\\])', '%1') -- remove '.'
		:gsub('[/\\][/\\]', '/') -- remove empty names
		:gsub('[/\\]$', '') -- remove post '/'
		:gsub('^%.[/\\]', '')
end

local function relative_path_to(from: absolute_path, to: absolute_path): relative_path
	local next_origin_ancestor = from:gmatch('[^/\\]+')
	local next_target_ancestor = to:gmatch('[^/\\]+')

	local target_ancestor = next_target_ancestor()
	for origin_ancestor in next_origin_ancestor do
		if origin_ancestor ~= target_ancestor then break end
		target_ancestor = next_target_ancestor()
	end

	local result = (if next_origin_ancestor() then '../../' else '')
		.. (if target_ancestor then target_ancestor .. '/' else '')

	for c in next_origin_ancestor do
		result = '../' .. result
	end
	for child in next_target_ancestor do
		result ..= '/' .. child
	end

	return clear_path(result)
end

local function module_location()
	local dirty_path = debug.info(2, 's')
	local path = dirty_path:match('^[/\\]?')

	for ancestor in dirty_path:gmatch('[^/\\]+') do
		if ancestor == '.' then continue end
		if not fs.isDir(path .. ancestor) then break end
		path ..= ancestor .. '/'
	end
	return clear_path(path)
end

-- module
return table.freeze {
	read_descendants_paths = read_descendants_paths_handle,
	relative_path_to = relative_path_to,
	module_location = module_location,
	clear_path = clear_path,
}
