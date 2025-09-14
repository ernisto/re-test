# Test

A minimal, fast test runner for Luau projects with a beautiful CLI interface.

## Features

- ⚡ **Fast**: Minimal overhead, optimized for speed
- 🎨 **Beautiful Output**: Colored terminal output with progress bars and timing (requires Nerd Fonts)
- 🔍 **Smart Discovery**: Automatically finds and runs all test files
- 🎯 **Focus Mode**: Run only specific tests during development
- ⏭️ **Skip Tests**: Easily skip tests that aren't ready
- 📦 **Zero Dependencies**: Pure Luau implementation
- 🛠️ **Flexible**: Multiple ways to define your tests

## Quick Start

1. Create a test file with `.spec.luau` extension:

```luau
local run = {}

function run.should_run()
    assert(1 + 1 == 2, "Basic math should work")
end

return run
```

2. Run your tests:

```bash
pesde x ernisto/test -- tests
```

3. See the output

> **Note**: For the best experience with special characters and icons, install a [Nerd Font](https://www.nerdfonts.com/) for your terminal.

<img width="884" height="550" alt="image" src="https://github.com/user-attachments/assets/31a35ed3-5802-474f-946e-f20e438cdda7" />




## Test File Formats

### Advanced Format

```luau
local run, focus, skip = {}, {}, {}

function run.should_skip_this_test()
    error('shouldnt run')
end

function focus.should_focus_this_test()
    print('debugging here')
end

function skip.should_skip_this_test()
    error('shouldnt run')
end

return { run = run, focus = focus, skip = skip, name = 'my_suite' }
```

### Using Test Helper (Recommended)

To use the test helper, you must install the package

```bash
pesde install ernisto/test
```

```luau
-- tests/example.spec.luau
local test = require('@pkg/test')
local spec, run, focus, skip = test.suite()

function run.should_pass_simple_test()
    assert(1 + 1 == 2, "Basic math should work")
end

function run.should_handle_strings()
    local result = "hello" .. " " .. "world"
    assert(result == "hello world", "String concatenation failed")
end

return spec
```

## CLI Usage

```bash
# Run tests in current directory
pesde x ernisto/test

# Run tests in specific directory
pesde x ernisto/test -- tests/
```

## Focus Mode

When you have focused tests (tests in the `focus` table), only those tests will run:

```luau
function focus.should_debug_this_specific_issue()
    print('debugging here')
end

function run.should_skip_this_test()
    error('shouldnt run')
end
```

This is perfect for debugging specific issues without running the entire test suite.

## Skip Tests

Use the `skip` table to temporarily disable tests:

```luau
function run.should_run_this_test()
    -- test here
end

function skip.should_skip_this_test()
    error('shouldnt run')
end
```

## Suggested Project Structure

```
your-project/
├── tests/
│   ├── math.spec.luau
│   ├── strings.spec.luau
│   └── utils.spec.luau
├── src/
│   └── your-code.luau
└── pesde.toml
```

## Contributing

Contributions are welcome! Please note:

- If you're using VS Code, you might need to enable `.luau` file visibility in your workspace settings
- All code should be written in Luau
- Tests should be added for new features

## License

MIT License - see [LICENSE](LICENSE) for details.
