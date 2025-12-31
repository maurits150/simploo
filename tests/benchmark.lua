--[[
    Performance benchmarks for SIMPLOO.
    
    Measures:
    - Instance creation (simple and with inheritance)
    - Method calls (simple and inherited)
    - Member access (own and inherited)
]]

local function gc()
    for i = 1, 10 do
        collectgarbage('collect')
    end
end

-- Raw Lua baseline benchmark for comparison.
function Test:testBenchmarkRaw()
    -- Simple class with 20 members
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

    gc()
    local t = os.clock()
    for i = 1, 10000 do
        Simple.new()
    end
    print("[raw] 10k instantiations (20 members): " .. string.format("%.3f", os.clock() - t) .. "s")

    -- Method calls
    local Calls = {}
    Calls.__index = Calls
    function Calls.new() return setmetatable({}, Calls) end
    function Calls:doCall2() local a = print == print end
    function Calls:doCall() self:doCall2() end

    gc()
    local instance = Calls.new()
    t = os.clock()
    for i = 1, 1000000 do
        instance:doCall()
    end
    print("[raw] 1M method calls: " .. string.format("%.3f", os.clock() - t) .. "s")

    -- 5-level inheritance chain (raw Lua style)
    local A = {}
    A.__index = A
    A.aValue = "a"
    function A.new()
        return setmetatable({aValue = "a"}, A)
    end
    function A:aMethod() return self.aValue end

    local B = setmetatable({}, {__index = A})
    B.__index = B
    B.bValue = "b"
    function B.new()
        local self = setmetatable(A.new(), B)
        self.bValue = "b"
        return self
    end
    function B:bMethod() return self:aMethod() .. self.bValue end

    local C = setmetatable({}, {__index = B})
    C.__index = C
    C.cValue = "c"
    function C.new()
        local self = setmetatable(B.new(), C)
        self.cValue = "c"
        return self
    end
    function C:cMethod() return self:bMethod() .. self.cValue end

    local D = setmetatable({}, {__index = C})
    D.__index = D
    D.dValue = "d"
    function D.new()
        local self = setmetatable(C.new(), D)
        self.dValue = "d"
        return self
    end
    function D:dMethod() return self:cMethod() .. self.dValue end

    local E = setmetatable({}, {__index = D})
    E.__index = E
    E.eValue = "e"
    function E.new()
        local self = setmetatable(D.new(), E)
        self.eValue = "e"
        return self
    end
    function E:eMethod() return self:dMethod() .. self.eValue end

    gc()
    t = os.clock()
    for i = 1, 10000 do
        E.new()
    end
    print("[raw] 10k instantiations (5-level inheritance): " .. string.format("%.3f", os.clock() - t) .. "s")

    gc()
    local eInstance = E.new()
    t = os.clock()
    for i = 1, 100000 do
        eInstance:eMethod()
    end
    print("[raw] 100k method chain calls (5 levels): " .. string.format("%.3f", os.clock() - t) .. "s")

    -- Calling method 5 levels up
    local Top = {}
    Top.__index = Top
    function Top.new() return setmetatable({}, Top) end
    function Top:topMethod() local a = print == print end

    local L1 = setmetatable({}, {__index = Top})
    L1.__index = L1
    function L1.new() return setmetatable(Top.new(), L1) end

    local L2 = setmetatable({}, {__index = L1})
    L2.__index = L2
    function L2.new() return setmetatable(L1.new(), L2) end

    local L3 = setmetatable({}, {__index = L2})
    L3.__index = L3
    function L3.new() return setmetatable(L2.new(), L3) end

    local L4 = setmetatable({}, {__index = L3})
    L4.__index = L4
    function L4.new() return setmetatable(L3.new(), L4) end

    local Bottom = setmetatable({}, {__index = L4})
    Bottom.__index = Bottom
    function Bottom.new() return setmetatable(L4.new(), Bottom) end

    gc()
    local bottomInstance = Bottom.new()
    t = os.clock()
    for i = 1, 1000000 do
        bottomInstance:topMethod()
    end
    print("[raw] 1M calls to method 5 levels up: " .. string.format("%.3f", os.clock() - t) .. "s")

    -- Member access
    gc()
    t = os.clock()
    for i = 1, 1000000 do
        local _ = eInstance.aValue
    end
    print("[raw] 1M inherited member access (5 levels): " .. string.format("%.3f", os.clock() - t) .. "s")

    gc()
    t = os.clock()
    for i = 1, 1000000 do
        local _ = eInstance.eValue
    end
    print("[raw] 1M own member access: " .. string.format("%.3f", os.clock() - t) .. "s")
end

-- SIMPLOO benchmark: simple class (no inheritance)
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
    }

    gc()
    local t = os.clock()
    for i = 1, 10000 do
        Benchmark.Simple.new()
    end
    print("[simploo] 10k instantiations (20 members): " .. string.format("%.3f", os.clock() - t) .. "s")

    class "Calls" {
        private {
            doCall2 = function() local a = print == print end;
        };
        public {
            doCall = function(self) self:doCall2() end;
        };
    }

    gc()
    local instance = Benchmark.Calls:new()
    t = os.clock()
    for i = 1, 1000000 do
        instance:doCall()
    end
    print("[simploo] 1M method calls: " .. string.format("%.3f", os.clock() - t) .. "s")
end

-- SIMPLOO benchmark: deep inheritance (5 levels)
function Test:testBenchmarkInheritance()
    -- 5-level inheritance chain: A -> B -> C -> D -> E
    class "BenchA" {
        public {
            aValue = "a";
            aMethod = function(self) return self.aValue end;
        };
    }

    class "BenchB" extends "BenchA" {
        public {
            bValue = "b";
            bMethod = function(self) return self:aMethod() .. self.bValue end;
        };
    }

    class "BenchC" extends "BenchB" {
        public {
            cValue = "c";
            cMethod = function(self) return self:bMethod() .. self.cValue end;
        };
    }

    class "BenchD" extends "BenchC" {
        public {
            dValue = "d";
            dMethod = function(self) return self:cMethod() .. self.dValue end;
        };
    }

    class "BenchE" extends "BenchD" {
        public {
            eValue = "e";
            eMethod = function(self) return self:dMethod() .. self.eValue end;
        };
    }

    -- Test instantiation with 5-level inheritance
    gc()
    local t = os.clock()
    for i = 1, 10000 do
        BenchE.new()
    end
    print("[simploo] 10k instantiations (5-level inheritance): " .. string.format("%.3f", os.clock() - t) .. "s")

    -- Test method call chain (each level calls parent)
    gc()
    local instance = BenchE.new()
    t = os.clock()
    for i = 1, 100000 do
        instance:eMethod()
    end
    print("[simploo] 100k method chain calls (5 levels): " .. string.format("%.3f", os.clock() - t) .. "s")

    -- Test calling method defined 5 levels up
    class "BenchTop" {
        public {
            topMethod = function(self) local a = print == print end;
        };
    }
    class "BenchL1" extends "BenchTop" {}
    class "BenchL2" extends "BenchL1" {}
    class "BenchL3" extends "BenchL2" {}
    class "BenchL4" extends "BenchL3" {}
    class "BenchBottom" extends "BenchL4" {}

    gc()
    local bottomInstance = BenchBottom.new()
    t = os.clock()
    for i = 1, 1000000 do
        bottomInstance:topMethod()
    end
    print("[simploo] 1M calls to method 5 levels up: " .. string.format("%.3f", os.clock() - t) .. "s")

    -- Test direct access to inherited member
    gc()
    t = os.clock()
    for i = 1, 1000000 do
        local _ = instance.aValue
    end
    print("[simploo] 1M inherited member access (5 levels): " .. string.format("%.3f", os.clock() - t) .. "s")

    -- Test direct access to own member
    gc()
    t = os.clock()
    for i = 1, 1000000 do
        local _ = instance.eValue
    end
    print("[simploo] 1M own member access: " .. string.format("%.3f", os.clock() - t) .. "s")
end
