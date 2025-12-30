-- Benchmark different scope tracking approaches
-- Run with: lua tests/benchmark_scope.lua

local iterations = 100000000

local function bench(name, fn)
    collectgarbage('collect')
    collectgarbage('collect')
    local startTime = os.clock()
    fn()
    local elapsed = os.clock() - startTime
    print(string.format("%-45s: %.3fs (%.0f ops/sec)", name, elapsed, iterations / elapsed))
end

print("Benchmarking " .. iterations .. " iterations each\n")

print("-- Trick: nil out coroutine.running --\n")

-- The trick: localize coroutine.running, set to nil when disabled
local coroutineRunning = coroutine.running  -- enabled
local scopeByThread = {}

bench("coroutineRunning enabled (or 'main')", function()
    for i = 1, iterations do
        local t = coroutineRunning and coroutineRunning() or "main"
    end
end)

bench("Thread-keyed with enabled check", function()
    for i = 1, iterations do
        local t = coroutineRunning and coroutineRunning() or "main"
        scopeByThread[t] = "test"
        scopeByThread[t] = nil
    end
end)

-- Now disable it
coroutineRunning = nil

bench("coroutineRunning disabled (or 'main')", function()
    for i = 1, iterations do
        local t = coroutineRunning and coroutineRunning() or "main"
    end
end)

bench("Thread-keyed with disabled check", function()
    for i = 1, iterations do
        local t = coroutineRunning and coroutineRunning() or "main"
        scopeByThread[t] = "test"
        scopeByThread[t] = nil
    end
end)

-- Compare to pure local (no table)
local currentScope = nil
bench("Pure local (baseline for comparison)", function()
    for i = 1, iterations do
        currentScope = "test"
        currentScope = nil
    end
end)

print("\n-- Read performance with the trick --\n")

coroutineRunning = coroutine.running
local thread = coroutineRunning and coroutineRunning() or "main"
scopeByThread[thread] = "test"

bench("Read with enabled check", function()
    local x
    for i = 1, iterations do
        local t = coroutineRunning and coroutineRunning() or "main"
        x = scopeByThread[t]
    end
end)

coroutineRunning = nil
scopeByThread["main"] = "test"

bench("Read with disabled check", function()
    local x
    for i = 1, iterations do
        local t = coroutineRunning and coroutineRunning() or "main"
        x = scopeByThread[t]
    end
end)

currentScope = "test"
bench("Read pure local (baseline)", function()
    local x
    for i = 1, iterations do
        x = currentScope
    end
end)

print("\n-- Function swapping approach --\n")

local getScope, setScope

-- Fast mode: pure local
local function initFastMode()
    local scope = nil
    getScope = function() return scope end
    setScope = function(s) scope = s end
end

-- Safe mode: thread-keyed
local function initSafeMode()
    local scopeByThread = {}
    getScope = function() 
        return scopeByThread[coroutine.running() or "main"] 
    end
    setScope = function(s) 
        scopeByThread[coroutine.running() or "main"] = s 
    end
end

initFastMode()
bench("Function swap: fast mode write", function()
    for i = 1, iterations do
        setScope("test")
        setScope(nil)
    end
end)

bench("Function swap: fast mode read", function()
    setScope("test")
    local x
    for i = 1, iterations do
        x = getScope()
    end
end)

initSafeMode()
bench("Function swap: safe mode write", function()
    for i = 1, iterations do
        setScope("test")
        setScope(nil)
    end
end)

bench("Function swap: safe mode read", function()
    setScope("test")
    local x
    for i = 1, iterations do
        x = getScope()
    end
end)

print("\n-- Original benchmarks --\n")

-- Baseline: empty loop
bench("Baseline (empty loop)", function()
    for i = 1, iterations do
    end
end)

-- Option 1b: Local upvalue
local currentScope = nil
bench("Local upvalue set/clear", function()
    for i = 1, iterations do
        currentScope = "test"
        currentScope = nil
    end
end)

-- Option 1c: coroutine.running() call only
bench("coroutine.running() only", function()
    for i = 1, iterations do
        local t = coroutine.running()
    end
end)

-- Option 1c: Thread-keyed table
local scopeByThread = {}
bench("Thread-keyed table set/clear", function()
    for i = 1, iterations do
        local thread = coroutine.running() or "main"
        scopeByThread[thread] = "test"
        scopeByThread[thread] = nil
    end
end)

-- Alternative: rawset on coroutine thread object (if not main)
bench("Thread-keyed (cached thread)", function()
    local thread = coroutine.running() or "main"
    for i = 1, iterations do
        scopeByThread[thread] = "test"
        scopeByThread[thread] = nil
    end
end)

-- What about just checking coroutine.running() once per call?
bench("coroutine.running() or 'main'", function()
    for i = 1, iterations do
        local t = coroutine.running() or "main"
    end
end)

-- Module table access (like simploo._currentScope)
local simploo = { _currentScope = nil }
bench("Module table set/clear", function()
    for i = 1, iterations do
        simploo._currentScope = "test"
        simploo._currentScope = nil
    end
end)

print("\n-- Now testing read performance (used in __index) --\n")

-- Reading from local
currentScope = "test"
bench("Read local upvalue", function()
    local x
    for i = 1, iterations do
        x = currentScope
    end
end)

-- Reading from thread-keyed table  
local thread = coroutine.running() or "main"
scopeByThread[thread] = "test"
bench("Read thread-keyed (cached thread)", function()
    local x
    for i = 1, iterations do
        x = scopeByThread[thread]
    end
end)

-- Reading with coroutine.running() each time
bench("Read thread-keyed (runtime thread)", function()
    local x
    for i = 1, iterations do
        local t = coroutine.running() or "main"
        x = scopeByThread[t]
    end
end)

-- Reading from module table
simploo._currentScope = "test"
bench("Read module table", function()
    local x
    for i = 1, iterations do
        x = simploo._currentScope
    end
end)
