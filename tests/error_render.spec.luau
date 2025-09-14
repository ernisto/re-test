local run = {}

function run.multiline_string()
	error('cavalo\nesperto')
end
function run.object()
	error { why = 'cavalon\nesperto' }
end
function run.tostring_metamethod()
	local err = setmetatable({}, {
		__tostring = function()
			return 'cavalo'
		end,
	})
	error(err)
end

return run
