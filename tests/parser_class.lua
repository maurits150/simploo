--[[
    Tests the parser's output format for class definitions.
    
    Verifies that both block syntax and builder syntax produce
    the correct internal parser output structure.
]]

simploo.instancer = nil -- Disable the instancer for this test

-- Test: block syntax with extends
function Test:testBlockSyntaxWithExtends()
    local p = class "BlockClassExtends" extends "Parent1, Parent2" {
        public {
            varOne = 3.2;

            static {
                varTwo = 1337;
            };

            fnTest = function()
                return "data"
            end
        };

        private {
            varThree = 11.2;
        };
    }

    p:setOnFinished(function(output)
        assertEquals(output.name, "BlockClassExtends")
        assertEquals(output.type, "class")
        assertEquals(#output.implements, 0)
        assertStrContains(table.concat(output.parents, ","), "Parent1")
        assertStrContains(table.concat(output.parents, ","), "Parent2")

        assertEquals(output.members.varOne.modifiers["public"], true)
        assertEquals(output.members.varTwo.modifiers["public"], true)
        assertEquals(output.members.varTwo.modifiers["static"], true)
        assertEquals(output.members.varThree.modifiers["private"], true)

        assertEquals(output.members.fnTest.modifiers["public"], true)
        assertEquals(type(output.members.fnTest.value), "function")
        assertEquals(output.members.fnTest.value(), "data")
    end)
end

-- Test: block syntax without extends
function Test:testBlockSyntaxWithoutExtends()
    local p = class "BlockClassSimple" {
        value = 42;
        name = "test";
    }

    p:setOnFinished(function(output)
        assertEquals(output.name, "BlockClassSimple")
        assertEquals(output.type, "class")
        assertEquals(#output.parents, 0)
        assertEquals(output.members.value.value, 42)
        assertEquals(output.members.name.value, "test")
    end)
end

-- Test: builder syntax
function Test:testBuilderSyntax()
    local c = class("BuilderClass", {extends = "Parent1, Parent2"})
    c.public.varOne = 3.2
    c.public.fnTest = function()
        return "data"
    end
    c.public.static.varTwo = 1337
    c.private.varThree = 11.2
    c:register()

    c:setOnFinished(function(output)
        assertEquals(output.name, "BuilderClass")
        assertEquals(output.type, "class")
        assertStrContains(table.concat(output.parents, ","), "Parent1")
        assertStrContains(table.concat(output.parents, ","), "Parent2")

        assertEquals(output.members.varOne.modifiers["public"], true)
        assertEquals(output.members.varTwo.modifiers["public"], true)
        assertEquals(output.members.varTwo.modifiers["static"], true)
        assertEquals(output.members.varThree.modifiers["private"], true)

        assertEquals(output.members.fnTest.modifiers["public"], true)
        assertEquals(type(output.members.fnTest.value), "function")
        assertEquals(output.members.fnTest.value(), "data")
    end)
end

-- Test: builder syntax without extends
function Test:testBuilderSyntaxWithoutExtends()
    local c = class("BuilderClassSimple")
    c.value = 42
    c:register()

    c:setOnFinished(function(output)
        assertEquals(output.name, "BuilderClassSimple")
        assertEquals(output.type, "class")
        assertEquals(#output.parents, 0)
        assertEquals(output.members.value.value, 42)
    end)
end

-- Test: class with implements (block syntax)
function Test:testBlockSyntaxWithImplements()
    local p = class "ImplementingClass" implements "IFoo, IBar" {
        foo = function(self) end;
    }

    p:setOnFinished(function(output)
        assertEquals(output.name, "ImplementingClass")
        assertEquals(output.type, "class")
        assertStrContains(table.concat(output.implements, ","), "IFoo")
        assertStrContains(table.concat(output.implements, ","), "IBar")
    end)
end

-- Test: class with both extends and implements
function Test:testBlockSyntaxWithExtendsAndImplements()
    local p = class "FullClass" extends "BaseClass" implements "ISerializable" {
        data = 0;
    }

    p:setOnFinished(function(output)
        assertEquals(output.name, "FullClass")
        assertEquals(output.type, "class")
        assertStrContains(table.concat(output.parents, ","), "BaseClass")
        assertStrContains(table.concat(output.implements, ","), "ISerializable")
    end)
end

-- Test: builder syntax with implements
function Test:testBuilderSyntaxWithImplements()
    local c = class("BuilderImplClass", {implements = "IOne, ITwo"})
    c.value = 42
    c:register()

    c:setOnFinished(function(output)
        assertEquals(output.name, "BuilderImplClass")
        assertStrContains(table.concat(output.implements, ","), "IOne")
        assertStrContains(table.concat(output.implements, ","), "ITwo")
    end)
end

-- Test: builder syntax with extends and implements
function Test:testBuilderSyntaxWithExtendsAndImplements()
    local c = class("BuilderFullClass", {extends = "Base", implements = "IFoo"})
    c.value = 1
    c:register()

    c:setOnFinished(function(output)
        assertEquals(output.name, "BuilderFullClass")
        assertStrContains(table.concat(output.parents, ","), "Base")
        assertStrContains(table.concat(output.implements, ","), "IFoo")
    end)
end

-- Test: all modifiers (block syntax)
function Test:testAllModifiersBlockSyntax()
    local p = class "ModifierClass" {
        public { pubVar = 1; };
        private { privVar = 2; };
        protected { protVar = 3; };
        static { staticVar = 4; };
        const { constVar = 5; };
        abstract { abstractFn = function(self) end; };
        transient { transientVar = 6; };
    }

    p:setOnFinished(function(output)
        assertEquals(output.members.pubVar.modifiers["public"], true)
        assertEquals(output.members.privVar.modifiers["private"], true)
        assertEquals(output.members.protVar.modifiers["protected"], true)
        assertEquals(output.members.staticVar.modifiers["static"], true)
        assertEquals(output.members.constVar.modifiers["const"], true)
        assertEquals(output.members.abstractFn.modifiers["abstract"], true)
        assertEquals(output.members.transientVar.modifiers["transient"], true)
    end)
end

-- Test: nested modifiers (block syntax)
function Test:testNestedModifiersBlockSyntax()
    local p = class "NestedModifierClass" {
        public {
            static {
                const {
                    nestedVar = 100;
                };
            };
        };
    }

    p:setOnFinished(function(output)
        assertEquals(output.members.nestedVar.modifiers["public"], true)
        assertEquals(output.members.nestedVar.modifiers["static"], true)
        assertEquals(output.members.nestedVar.modifiers["const"], true)
    end)
end

-- Test: all modifiers (builder syntax)
function Test:testAllModifiersBuilderSyntax()
    local c = class("ModifierClassBuilder")
    c.public.pubVar = 1
    c.private.privVar = 2
    c.protected.protVar = 3
    c.static.staticVar = 4
    c.const.constVar = 5
    c.abstract.abstractFn = function(self) end
    c.transient.transientVar = 6
    c:register()

    c:setOnFinished(function(output)
        assertEquals(output.members.pubVar.modifiers["public"], true)
        assertEquals(output.members.privVar.modifiers["private"], true)
        assertEquals(output.members.protVar.modifiers["protected"], true)
        assertEquals(output.members.staticVar.modifiers["static"], true)
        assertEquals(output.members.constVar.modifiers["const"], true)
        assertEquals(output.members.abstractFn.modifiers["abstract"], true)
        assertEquals(output.members.transientVar.modifiers["transient"], true)
    end)
end

-- Test: nested modifiers (builder syntax)
function Test:testNestedModifiersBuilderSyntax()
    local c = class("NestedModifierClassBuilder")
    c.public.static.const.nestedVar = 100
    c:register()

    c:setOnFinished(function(output)
        assertEquals(output.members.nestedVar.modifiers["public"], true)
        assertEquals(output.members.nestedVar.modifiers["static"], true)
        assertEquals(output.members.nestedVar.modifiers["const"], true)
    end)
end
