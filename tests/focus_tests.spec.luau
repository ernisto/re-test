local run, focus, skip = {}, {}, {}

function skip.should_run_this_test()
	print('debugging here')
end
function run.should_ignore_this_test()
	error('shouldnt run')
end

return { run = run, focus = focus, skip = skip, name = 'custom name' }
