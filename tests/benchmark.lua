--[[
    Performance benchmark for instance creation.
    
    Measures time to create many instances with various member counts.
]]

-- Raw Lua baseline benchmark for comparison.
-- Uses idiomatic Lua patterns: a class table with a metatable-based new(),
-- matching the same structure as the SIMPLOO benchmark.
function Test:testBenchmarkRaw()
    -- Define class using standard Lua OOP pattern
    local Simple = {}
    Simple.__index = Simple

    function Simple.new()
        local self = setmetatable({}, Simple)
        self.privateMember1 = function() end
        self.privateMember2 = function() end
        self.privateMember3 = function() end
        self.privateMember4 = function() end
        self.privateMember5 = function() end
        self.privateMember6 = "Content"
        self.privateMember7 = "Content"
        self.privateMember8 = "Content"
        self.privateMember9 = "Content"
        self.privateMember10 = "Content"
        self.publicMember1 = function() end
        self.publicMember2 = function() end
        self.publicMember3 = function() end
        self.publicMember4 = function() end
        self.publicMember5 = function() end
        self.publicMember6 = "Content"
        self.publicMember7 = "Content"
        self.publicMember8 = "Content"
        self.publicMember9 = "Content"
        self.publicMember10 = "Content"
        return self
    end

    for i=1, 10 do
        collectgarbage('collect')
    end

    local startTime = os.clock()

    for i=1, 10000 do
        Simple.new()
    end

    print("[raw] completed 10k new instances with 20 members in " .. (os.clock() - startTime))

    local Calls = {}
    Calls.__index = Calls

    function Calls.new()
        return setmetatable({}, Calls)
    end

    function Calls:doCall2()
        local a = print == print
    end

    function Calls:doCall()
        self:doCall2()
    end

    for i=1, 10 do
        collectgarbage('collect')
    end

    local startTime = os.clock()

    local instance = Calls.new()

    for i=1, 1000 * 1000 do
        instance:doCall()
    end

    print("[raw] completed 2M calls in " .. (os.clock() - startTime))
end

-- Performance benchmark measuring instance creation and method call overhead.
-- Creates 10,000 instances with 20 members (10 private + 10 public) and
-- times the operation. Then measures 2 million method calls including a
-- private method invocation to test scope tracking overhead.
-- Not a correctness test - just reports timing for performance analysis.
function Test:testBenchmarkSimploo()
    namespace "Benchmark"

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

    for i=1, 10 do
        collectgarbage('collect')
    end

    local startTime = os.clock()

    for i=1, 10000 do
        Benchmark.Simple.new()
    end


    print("[simploo] completed 10k new instances with 20 members in " .. (os.clock() - startTime))

    class "Calls" {
        private {
            doCall2 = function()
                -- This tests the overhead of the  we have in here.
                local a = print == print
            end
        };
        public {
            doCall = function(self)
                self:doCall2()
            end
        };
    };

    for i=1, 10 do
        collectgarbage('collect')
    end

    local startTime = os.clock()

    local instance = Benchmark.Calls:new()

    for i=1, 1000 * 1000 do
        instance:doCall()
    end

    print("[simploo] completed 2M calls in " .. (os.clock() - startTime))
end
