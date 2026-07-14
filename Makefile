.PHONY: test test_file

test: tests/mini.nvim
	nvim --headless --clean -u tests/minimal_init.lua -c "luafile tests/runner.lua"

# Run test from file at `$FILE` environment variable
test_file: tests/mini.nvim
	nvim --headless --clean -u tests/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

tests/mini.nvim:
	git submodule update --init --recursive tests/mini.nvim
