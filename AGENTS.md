- Performance is critical. Do not use `debug.getinfo` or other debug library functions in code paths that run during method calls (e.g., wrappers, metamethods). These are too slow for hot paths.
- Tests do not need pcall wrappers - the test framework (menu.lua) handles errors. Only use pcall when testing that something should fail (e.g., assertFalse(success) after pcall).
- Do NOT add `namespace ""` to test files - the test framework (menu.lua) reloads simploo fresh for each test file, so namespace state does not persist between files.
- NEVER read any files in dist/ - they are probably outdated and will confuse your context.
- To run tests: `echo "4\n5" | lua menu.lua` (option 4 runs tests, option 5 exits). The menu requires input so you must pipe both options.
- To initialize simploo manually for testing outside menu.lua, load files from src/sourcefiles.txt in order:
  ```lua
  local file = io.open("src/sourcefiles.txt", "r")
  local content = file:read("*all")
  file:close()
  for name in string.gmatch(content, "[^\r\n]+") do
      dofile("src/" .. name)
  end
  ```