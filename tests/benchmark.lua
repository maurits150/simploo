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
    print("[raw] 10k instantiations (plain class): " .. string.format("%.3f", os.clock() - t) .. "s")

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

    -- 5-level inheritance chain (raw Lua style, 20 members each)
    local A = {}
    A.__index = A
    A.aValue = "a"
    function A.new()
        local self = setmetatable({}, A)
        self.aValue = "a"
        self.a1 = "a1"; self.a2 = "a2"; self.a3 = "a3"; self.a4 = "a4"; self.a5 = "a5"
        self.a6 = "a6"; self.a7 = "a7"; self.a8 = "a8"; self.a9 = "a9"; self.a10 = "a10"
        self.a11 = "a11"; self.a12 = "a12"; self.a13 = "a13"; self.a14 = "a14"; self.a15 = "a15"
        self.a16 = "a16"; self.a17 = "a17"; self.a18 = "a18"
        return self
    end
    function A:aMethod() return self.aValue end

    local B = setmetatable({}, {__index = A})
    B.__index = B
    B.bValue = "b"
    function B.new()
        local self = setmetatable(A.new(), B)
        self.bValue = "b"
        self.b1 = "b1"; self.b2 = "b2"; self.b3 = "b3"; self.b4 = "b4"; self.b5 = "b5"
        self.b6 = "b6"; self.b7 = "b7"; self.b8 = "b8"; self.b9 = "b9"; self.b10 = "b10"
        self.b11 = "b11"; self.b12 = "b12"; self.b13 = "b13"; self.b14 = "b14"; self.b15 = "b15"
        self.b16 = "b16"; self.b17 = "b17"; self.b18 = "b18"
        return self
    end
    function B:bMethod() return self:aMethod() .. self.bValue end

    local C = setmetatable({}, {__index = B})
    C.__index = C
    C.cValue = "c"
    function C.new()
        local self = setmetatable(B.new(), C)
        self.cValue = "c"
        self.c1 = "c1"; self.c2 = "c2"; self.c3 = "c3"; self.c4 = "c4"; self.c5 = "c5"
        self.c6 = "c6"; self.c7 = "c7"; self.c8 = "c8"; self.c9 = "c9"; self.c10 = "c10"
        self.c11 = "c11"; self.c12 = "c12"; self.c13 = "c13"; self.c14 = "c14"; self.c15 = "c15"
        self.c16 = "c16"; self.c17 = "c17"; self.c18 = "c18"
        return self
    end
    function C:cMethod() return self:bMethod() .. self.cValue end

    local D = setmetatable({}, {__index = C})
    D.__index = D
    D.dValue = "d"
    function D.new()
        local self = setmetatable(C.new(), D)
        self.dValue = "d"
        self.d1 = "d1"; self.d2 = "d2"; self.d3 = "d3"; self.d4 = "d4"; self.d5 = "d5"
        self.d6 = "d6"; self.d7 = "d7"; self.d8 = "d8"; self.d9 = "d9"; self.d10 = "d10"
        self.d11 = "d11"; self.d12 = "d12"; self.d13 = "d13"; self.d14 = "d14"; self.d15 = "d15"
        self.d16 = "d16"; self.d17 = "d17"; self.d18 = "d18"
        return self
    end
    function D:dMethod() return self:cMethod() .. self.dValue end

    local E = setmetatable({}, {__index = D})
    E.__index = E
    E.eValue = "e"
    function E.new()
        local self = setmetatable(D.new(), E)
        self.eValue = "e"
        self.e1 = "e1"; self.e2 = "e2"; self.e3 = "e3"; self.e4 = "e4"; self.e5 = "e5"
        self.e6 = "e6"; self.e7 = "e7"; self.e8 = "e8"; self.e9 = "e9"; self.e10 = "e10"
        self.e11 = "e11"; self.e12 = "e12"; self.e13 = "e13"; self.e14 = "e14"; self.e15 = "e15"
        self.e16 = "e16"; self.e17 = "e17"; self.e18 = "e18"
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
    print("[simploo] 10k instantiations (plain class): " .. string.format("%.3f", os.clock() - t) .. "s")

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

-- SIMPLOO benchmark: deep inheritance (5 levels, 20 members each)
function Test:testBenchmarkInheritance()
    -- 5-level inheritance chain: A -> B -> C -> D -> E (20 members each = 100 total)
    class "BenchA" {
        public {
            aValue = "a";
            aMethod = function(self) return self.aValue end;
            a1 = "a1"; a2 = "a2"; a3 = "a3"; a4 = "a4"; a5 = "a5";
            a6 = "a6"; a7 = "a7"; a8 = "a8"; a9 = "a9"; a10 = "a10";
            a11 = "a11"; a12 = "a12"; a13 = "a13"; a14 = "a14"; a15 = "a15";
            a16 = "a16"; a17 = "a17"; a18 = "a18";
        };
    }

    class "BenchB" extends "BenchA" {
        public {
            bValue = "b";
            bMethod = function(self) return self:aMethod() .. self.bValue end;
            b1 = "b1"; b2 = "b2"; b3 = "b3"; b4 = "b4"; b5 = "b5";
            b6 = "b6"; b7 = "b7"; b8 = "b8"; b9 = "b9"; b10 = "b10";
            b11 = "b11"; b12 = "b12"; b13 = "b13"; b14 = "b14"; b15 = "b15";
            b16 = "b16"; b17 = "b17"; b18 = "b18";
        };
    }

    class "BenchC" extends "BenchB" {
        public {
            cValue = "c";
            cMethod = function(self) return self:bMethod() .. self.cValue end;
            c1 = "c1"; c2 = "c2"; c3 = "c3"; c4 = "c4"; c5 = "c5";
            c6 = "c6"; c7 = "c7"; c8 = "c8"; c9 = "c9"; c10 = "c10";
            c11 = "c11"; c12 = "c12"; c13 = "c13"; c14 = "c14"; c15 = "c15";
            c16 = "c16"; c17 = "c17"; c18 = "c18";
        };
    }

    class "BenchD" extends "BenchC" {
        public {
            dValue = "d";
            dMethod = function(self) return self:cMethod() .. self.dValue end;
            d1 = "d1"; d2 = "d2"; d3 = "d3"; d4 = "d4"; d5 = "d5";
            d6 = "d6"; d7 = "d7"; d8 = "d8"; d9 = "d9"; d10 = "d10";
            d11 = "d11"; d12 = "d12"; d13 = "d13"; d14 = "d14"; d15 = "d15";
            d16 = "d16"; d17 = "d17"; d18 = "d18";
        };
    }

    class "BenchE" extends "BenchD" {
        public {
            eValue = "e";
            eMethod = function(self) return self:dMethod() .. self.eValue end;
            e1 = "e1"; e2 = "e2"; e3 = "e3"; e4 = "e4"; e5 = "e5";
            e6 = "e6"; e7 = "e7"; e8 = "e8"; e9 = "e9"; e10 = "e10";
            e11 = "e11"; e12 = "e12"; e13 = "e13"; e14 = "e14"; e15 = "e15";
            e16 = "e16"; e17 = "e17"; e18 = "e18";
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
