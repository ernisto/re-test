local test = require('@lib/lib')
local spec, run, _focus, skip = test.suite()

function run.should_run_this_test() end
function skip.should_skip_this_test()
	error('shouldnt run')
end

return spec
