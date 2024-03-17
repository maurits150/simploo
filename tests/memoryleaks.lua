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

    local memoryFreed = math.abs(startMemory - endMemory) < 0.25 -- 0.25Mb difference max
    if not memoryFreed then
        print("START MEMORY", startMemory, "END MEMORY", endMemory)
    end

    assertTrue(memoryFreed) -- less than 0.1 MB difference
end
