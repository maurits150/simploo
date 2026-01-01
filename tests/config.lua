--[[
    Tests configuration options.
    
    Tests exposeSyntax, baseInstanceTable, and customModifiers config options.
    Note: production mode is tested implicitly by object_permissions_all.lua
    which skips when production=true.
]]

---------------------------------------------------------------------
-- exposeSyntax tests
---------------------------------------------------------------------

-- Tests that simploo.syntax.destroy() removes global syntax functions.
function Test:testExposeSyntaxDestroy()
    -- Globals should exist initially
    assertTrue(class ~= nil)
    assertTrue(namespace ~= nil)
    assertTrue(extends ~= nil)
    assertTrue(using ~= nil)
    
    simploo.syntax.destroy()
    
    -- Globals should be removed
    assertTrue(class == nil)
    assertTrue(namespace == nil)
    assertTrue(extends == nil)
    assertTrue(using == nil)
    
    -- Restore for other tests
    simploo.syntax.init()
end

-- Tests that simploo.syntax.init() restores global syntax functions.
function Test:testExposeSyntaxInit()
    simploo.syntax.destroy()
    
    -- Globals should be removed
    assertTrue(class == nil)
    
    simploo.syntax.init()
    
    -- Globals should be restored
    assertTrue(class ~= nil)
    assertTrue(namespace ~= nil)
    assertTrue(extends ~= nil)
    assertTrue(using ~= nil)
end

-- Tests using simploo without polluting globals at all.
function Test:testSyntaxWithoutGlobals()
    local myLib = {}
    local originalSyntaxTable = simploo.config["baseSyntaxTable"]
    local originalInstanceTable = simploo.config["baseInstanceTable"]
    
    -- Remove from _G, use custom table for everything
    simploo.syntax.destroy()
    simploo.config["baseSyntaxTable"] = myLib
    simploo.config["baseInstanceTable"] = myLib
    simploo.syntax.init()
    
    myLib.class "NoGlobalsClass" {
        value = 42;
    }
    
    -- Nothing in _G
    assertTrue(_G.class == nil)
    assertTrue(_G.NoGlobalsClass == nil)
    
    -- Everything in myLib
    local instance = myLib.NoGlobalsClass.new()
    assertEquals(instance.value, 42)
    
    -- Restore
    simploo.syntax.destroy()
    simploo.config["baseSyntaxTable"] = originalSyntaxTable
    simploo.config["baseInstanceTable"] = originalInstanceTable
    simploo.syntax.init()
end

---------------------------------------------------------------------
-- baseSyntaxTable tests
---------------------------------------------------------------------

-- Tests isolating both syntax and classes in a custom table.
function Test:testBaseSyntaxTable()
    local myLib = {}
    local originalSyntaxTable = simploo.config["baseSyntaxTable"]
    local originalInstanceTable = simploo.config["baseInstanceTable"]
    
    -- Destroy from _G, then switch both tables
    simploo.syntax.destroy()
    simploo.config["baseSyntaxTable"] = myLib
    simploo.config["baseInstanceTable"] = myLib
    simploo.syntax.init()
    
    -- Syntax should be in custom table
    assertTrue(myLib.class ~= nil)
    assertTrue(myLib.namespace ~= nil)
    
    -- Syntax should not be in _G
    assertTrue(_G.class == nil)
    
    -- Define class using custom syntax
    myLib.class "IsolatedClass" {
        value = 42;
    }
    
    -- Class should be in custom table
    assertTrue(myLib.IsolatedClass ~= nil)
    assertTrue(_G.IsolatedClass == nil)
    
    -- Should be able to instantiate
    local instance = myLib.IsolatedClass.new()
    assertEquals(instance.value, 42)
    
    -- Restore
    simploo.syntax.destroy()
    simploo.config["baseSyntaxTable"] = originalSyntaxTable
    simploo.config["baseInstanceTable"] = originalInstanceTable
    simploo.syntax.init()
end

---------------------------------------------------------------------
-- baseInstanceTable tests
---------------------------------------------------------------------

-- Tests inheritance works with custom baseInstanceTable.
function Test:testBaseInstanceTableWithInheritance()
    local myLib = {}
    local originalSyntaxTable = simploo.config["baseSyntaxTable"]
    local originalInstanceTable = simploo.config["baseInstanceTable"]
    
    simploo.syntax.destroy()
    simploo.config["baseSyntaxTable"] = myLib
    simploo.config["baseInstanceTable"] = myLib
    simploo.syntax.init()
    
    -- With custom tables, use locals for chainable syntax
    local class, extends = myLib.class, myLib.extends
    
    class "BaseClass" {
        value = 100;
        
        getValue = function(self)
            return self.value
        end;
    }
    
    class "ChildClass" extends "BaseClass" {
        childValue = 200;
    }
    
    local instance = myLib.ChildClass.new()
    assertEquals(instance.value, 100)
    assertEquals(instance.childValue, 200)
    assertEquals(instance:getValue(), 100)
    
    -- Restore
    simploo.syntax.destroy()
    simploo.config["baseSyntaxTable"] = originalSyntaxTable
    simploo.config["baseInstanceTable"] = originalInstanceTable
    simploo.syntax.init()
end

-- Tests namespaces work with custom baseInstanceTable.
function Test:testBaseInstanceTableWithNamespace()
    local myLib = {}
    local originalSyntaxTable = simploo.config["baseSyntaxTable"]
    local originalInstanceTable = simploo.config["baseInstanceTable"]
    
    simploo.syntax.destroy()
    simploo.config["baseSyntaxTable"] = myLib
    simploo.config["baseInstanceTable"] = myLib
    simploo.syntax.init()
    
    myLib.namespace "game.entities"
    
    myLib.class "Player" {
        name = "Unknown";
    }
    
    myLib.namespace ""
    
    -- Should create nested structure
    assertTrue(myLib.game ~= nil)
    assertTrue(myLib.game.entities ~= nil)
    assertTrue(myLib.game.entities.Player ~= nil)
    
    local instance = myLib.game.entities.Player.new()
    assertEquals(instance.name, "Unknown")
    
    -- Restore
    simploo.syntax.destroy()
    simploo.config["baseSyntaxTable"] = originalSyntaxTable
    simploo.config["baseInstanceTable"] = originalInstanceTable
    simploo.syntax.init()
end

---------------------------------------------------------------------
-- customModifiers tests
---------------------------------------------------------------------

-- Tests using custom modifiers with a hook to implement behavior.
-- This shows the practical pattern: define modifier, use hook to act on it.
function Test:testCustomModifiersWithHook()
    local myLib = {}
    local originalSyntaxTable = simploo.config["baseSyntaxTable"]
    local originalInstanceTable = simploo.config["baseInstanceTable"]
    local originalModifiers = simploo.config["customModifiers"]
    local loggedMembers = {}
    
    simploo.syntax.destroy()
    simploo.config["baseSyntaxTable"] = myLib
    simploo.config["baseInstanceTable"] = myLib
    simploo.config["customModifiers"] = {"logged"}
    simploo.syntax.init()
    
    -- Hook to process the custom modifier
    local hookFn = function(definitionOutput)
        for memberName, memberData in pairs(definitionOutput.members) do
            if memberData.modifiers.logged then
                table.insert(loggedMembers, memberName)
            end
        end
        return definitionOutput
    end
    
    simploo.hook:add("beforeRegister", hookFn)
    
    myLib.class "LoggedClass" {
        myLib.logged {
            importantValue = 42;
        };
        
        normalValue = 10;
    }
    
    simploo.hook:remove("beforeRegister", hookFn)
    
    -- Hook should have captured the logged member
    assertEquals(#loggedMembers, 1)
    assertEquals(loggedMembers[1], "importantValue")
    
    -- Class should work normally
    local instance = myLib.LoggedClass.new()
    assertEquals(instance.importantValue, 42)
    assertEquals(instance.normalValue, 10)
    
    -- Restore
    simploo.syntax.destroy()
    simploo.config["baseSyntaxTable"] = originalSyntaxTable
    simploo.config["baseInstanceTable"] = originalInstanceTable
    simploo.config["customModifiers"] = originalModifiers
    simploo.syntax.init()
end
