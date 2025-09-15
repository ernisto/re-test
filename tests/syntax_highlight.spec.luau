local run = {}

function run.string()
	error(`dgfhgdh \b {print [==[ sgfsfg [ ]] ]==]} \{ } == {1 + 2} dfg`)
end
function run.variable()
	local a = 4 + 'sfg' :: any
end
function run.comment()
	error(--[=[ cavalo]] ]=] 'error') -- should error
end

return run
