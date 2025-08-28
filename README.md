# Usage
The CLI scan all the descendants of the given path or current directory for
all .spec.lua(u) files, requiring them, and collecting all tests to be run.
Theres 3 main ways to define ur .spec files
**tests/a.spec.luau**
```luau
local run = {}

function run.should_run()
end

return run
```
**tests/b.spec.luau**
```luau
local run, focus, skip = {}, {}, {}

function focus.should_run_this_test()
    print('debugging here')
end
function run.should_ignore_this_test()
    error('shouldnt run')
end

return { run = run, focus = focus, skip = skip, name = 'a' }
```
**tests/c.spec.luau**
```luau
local test = require('@pkg/test')
local spec, run, focus, skip = test.spec()

function run.should_run_this_test(deep_assert)  -- soon
end
function skip.should_skip_this_test(deep_assert)
    error('shouldnt run')
end

return spec
```
After define them, just check the tests status running in your terminal
```bash
pesde x ernisto/test tests
```
And you should be able to see something like this:

# Contribuite
Nothing to say, just note if you are in vs code you shouldnt see nothing
except by .luau files, i just recommended by extension to toggle a vsc setting
to be able to see those files is opted-in
