--[[
    Tests that instances are properly garbage collected.
    
    Creates many instances and verifies memory doesn't grow
    unbounded after collection.
]]

function Test:testMemoryLeak()
    namespace "memoryleak"

    class "Simple" {
        private {
            privateMember1 = function() end;
            privateMember2 = function() end;
            privateMember3 = function() end;
            privateMember4 = function() end;
            privateMember5 = function() end;
            privateMember6 = "Content";
            privateMember7 = "Content";
            privateMember8 = "Content";
            privateMember9 = "Content";
            privateMember10 = "Content";
        };

        public {
            publicMember1 = function() end;
            publicMember2 = function() end;
            publicMember3 = function() end;
            publicMember4 = function() end;
            publicMember5 = function() end;
            publicMember6 = "Content";
            publicMember7 = "Content";
            publicMember8 = "Content";
            publicMember9 = "Content";
            publicMember10 = "Content";
        };
    };

    for i=1, 3 do
        collectgarbage("collect")
    end

    local startTime = os.clock()
    local startMemory = collectgarbage("count")

    local i = 0
    local r = math.random()
    while os.clock() - startTime < 1 do
        i = i + 1

        memoryleak.Simple.new()

        -- uncomment to test failure logic
        -- _G[r .. "_" .. i] = string.rep("A", i)
    end

    for i=1, 3 do
        collectgarbage("collect")
    end

    local endMemory = collectgarbage("count")

    local memoryFreed = math.abs(startMemory - endMemory) < 250 -- 250KB difference max
    if not memoryFreed then
        print("START MEMORY", startMemory, "END MEMORY", endMemory)
    end

    assertTrue(memoryFreed) -- less than 0.1 MB difference
end

function Test:testStaticsNotCopiedToInstances()
    namespace "memoryleak"

    class "BigStaticVariable" {
        static {
            lots_of_data = {}
        }
    };

    for i=1, 1000 * 100 do
        table.insert(memoryleak.BigStaticVariable.lots_of_data, "A")
    end

    for i=1, 3 do
        collectgarbage("collect")
    end

    local startMemory = collectgarbage("count")

    local instances = {}
    for i=1, 100 do
        table.insert(instances, memoryleak.BigStaticVariable.new())
    end

    for i=1, 3 do
        collectgarbage("collect")
    end

    local endMemory = collectgarbage("count")

    local above1MBused = (endMemory - startMemory) > 1000
    if above1MBused then
        print("START MEMORY", startMemory, "END MEMORY", endMemory)
    end

    assertFalse(above1MBused)
end

--
-- This test fails in LuaJIT / Lua 5.1, something in fenv changed
--
function Test:testMemoryLeakViaUsingsFENVReferencingOldClasses()

    collectgarbage('collect')

    local startMemory = collectgarbage("count")

    for i=1, 50 do
        namespace "namespace1"

        class "ClassA" {
            static {
                data = {}
            };

            __declare = function(self)
                for i=1, 1000 * 100 do
                    -- 1MB of AAA, should give us 1MB x 25 = 25MB used if test fails
                    -- We're inserting into a static so this should get recycled every loop.
                    table.insert(self.data, "A")
                end
            end;
        };


        namespace "namespace2"

        using "namespace1.ClassA" as "ClassA"

        class "ClassB" {
            test = function(self)
            end;
        };

        namespace2.ClassB.new():test()
    end

    collectgarbage('collect')

    local endMemory = collectgarbage("count")

    local above5MBused = (endMemory - startMemory) > 5000
    if above5MBused then
        print("START MEMORY", startMemory, "END MEMORY", endMemory)
    end

    assertFalse(above5MBused)
end

