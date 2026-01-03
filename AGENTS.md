- Performance is critical. No `debug.getinfo` in hot paths (wrappers, metamethods).
- Tests don't need pcall - menu.lua handles errors. Only use pcall when testing failures.
- Don't add `namespace ""` to tests - simploo reloads fresh per test file.
- NEVER read dist/ files - outdated.
- Run tests: `printf '4\n5' | lua menu.lua`
- Manual init (outside menu.lua): load files from src/sourcefiles.txt in order:
  ```lua
  for name in io.open("src/sourcefiles.txt"):read("*a"):gmatch("[^\r\n]+") do
      dofile("src/" .. name)
  end
  ```
- ALWAYS read all src/ files before working (unless told not to).
- Benchmarks: compare to README numbers, run all 3 lua versions, ask to update README.
