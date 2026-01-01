--[[
    Tests the parser's handling of interface syntax.
    
    Verifies that interface definitions produce correct parser output
    and that the syntax keywords work correctly.
]]

simploo.instancer = nil -- Disable the instancer for parser-only tests

-- Test: interface block syntax
function Test:testInterfaceBlockSyntax()
    local p = interface "ITestable" {
        test = function(self) end;
        getValue = function(self) end;
    }

    p:setOnFinished(function(output)
        assertEquals(output.name, "ITestable")
        assertEquals(output.type, "interface")
        assertEquals(#output.implements, 0)
        assertEquals(type(output.members.test.value), "function")
        assertEquals(type(output.members.getValue.value), "function")
    end)
end

-- Test: interface with extends (block syntax)
function Test:testInterfaceBlockSyntaxWithExtends()
    local p = interface "IChild" extends "IParent1, IParent2" {
        childMethod = function(self) end;
    }

    p:setOnFinished(function(output)
        assertEquals(output.name, "IChild")
        assertEquals(output.type, "interface")
        assertStrContains(table.concat(output.parents, ","), "IParent1")
        assertStrContains(table.concat(output.parents, ","), "IParent2")
    end)
end

-- Test: interface cannot use implements
function Test:testInterfaceCannotImplement()
    local success = pcall(function()
        interface "IBad" implements "IFoo" {
            method = function(self) end;
        }
    end)
    -- Clean up parser instance left behind by the error
    simploo.parser.instance = nil
    assertFalse(success)
end

-- Test: interface builder syntax
function Test:testInterfaceBuilderSyntax()
    local p = interface("IBuilder")
    p.getValue = function(self) end
    p.setValue = function(self, v) end
    p:register()

    p:setOnFinished(function(output)
        assertEquals(output.name, "IBuilder")
        assertEquals(output.type, "interface")
        assertEquals(type(output.members.getValue.value), "function")
        assertEquals(type(output.members.setValue.value), "function")
    end)
end

-- Test: interface builder syntax with extends
function Test:testInterfaceBuilderSyntaxWithExtends()
    local p = interface("IChildBuilder", {extends = "IParentBuilder"})
    p.childMethod = function(self) end
    p:register()

    p:setOnFinished(function(output)
        assertEquals(output.name, "IChildBuilder")
        assertEquals(output.type, "interface")
        assertStrContains(table.concat(output.parents, ","), "IParentBuilder")
    end)
end

-- Test: interface with modifiers on members (block syntax)
function Test:testInterfaceWithModifiersBlockSyntax()
    local p = interface "IWithMods" {
        public {
            pubMethod = function(self) end;
        };
    }

    p:setOnFinished(function(output)
        assertEquals(output.name, "IWithMods")
        assertEquals(output.type, "interface")
        assertEquals(output.members.pubMethod.modifiers["public"], true)
    end)
end

-- Test: interface with modifiers (builder syntax)
function Test:testInterfaceWithModifiersBuilderSyntax()
    local p = interface("IWithModsBuilder")
    p.public.pubMethod = function(self) end
    p:register()

    p:setOnFinished(function(output)
        assertEquals(output.name, "IWithModsBuilder")
        assertEquals(output.type, "interface")
        assertEquals(output.members.pubMethod.modifiers["public"], true)
    end)
end

-- Test: empty interface (block syntax)
function Test:testEmptyInterfaceBlockSyntax()
    local p = interface "IEmpty" {
    }

    p:setOnFinished(function(output)
        assertEquals(output.name, "IEmpty")
        assertEquals(output.type, "interface")
        local count = 0
        for _ in pairs(output.members) do count = count + 1 end
        assertEquals(count, 0)
    end)
end

-- Test: empty interface (builder syntax)
function Test:testEmptyInterfaceBuilderSyntax()
    local p = interface("IEmptyBuilder")
    p:register()

    p:setOnFinished(function(output)
        assertEquals(output.name, "IEmptyBuilder")
        assertEquals(output.type, "interface")
        local count = 0
        for _ in pairs(output.members) do count = count + 1 end
        assertEquals(count, 0)
    end)
end

-- Test: interface with properties (block syntax)
function Test:testInterfaceWithPropertiesBlockSyntax()
    local p = interface "IWithProps" {
        defaultValue = 0;
        name = "";
    }

    p:setOnFinished(function(output)
        assertEquals(output.name, "IWithProps")
        assertEquals(output.type, "interface")
        assertEquals(output.members.defaultValue.value, 0)
        assertEquals(output.members.name.value, "")
    end)
end

-- Test: interface with properties (builder syntax)
function Test:testInterfaceWithPropertiesBuilderSyntax()
    local p = interface("IWithPropsBuilder")
    p.defaultValue = 0
    p.name = ""
    p:register()

    p:setOnFinished(function(output)
        assertEquals(output.name, "IWithPropsBuilder")
        assertEquals(output.type, "interface")
        assertEquals(output.members.defaultValue.value, 0)
        assertEquals(output.members.name.value, "")
    end)
end
