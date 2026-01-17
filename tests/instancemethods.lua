--[[
    Tests built-in instance methods like instance_of(), get_name(), 
    get_class(), and get_parents().
    
    Verifies inheritance checking works correctly with single and
    multiple inheritance, including deep hierarchy chains.
]]

-- Tests the instance_of() method for checking class relationships in a hierarchy.
-- With classes P -> M -> C (C extends M extends P), verifies that:
-- (1) child instances are instances of parent classes, (2) instance_of works
-- with both class references and instance references, (3) parent classes are
-- NOT instances of child classes (the relationship is not symmetric).
function Test:testInstanceMethods()
    class "P" {
    }

    class "M" extends "P" {

    }

    class "C" extends "M" {

    }

    -- check current val on instance 1
    local p = P.new()
    local m = M.new()
    local c = C.new()

    assertTrue(m:instance_of(p))

    assertTrue(c:instance_of(P))
    assertTrue(c:instance_of(p))
    assertFalse(P:instance_of(C))
    assertFalse(P:instance_of(c))

    assertTrue(m:instance_of(P))
    assertTrue(m:instance_of(p))
    assertFalse(m:instance_of(C))
    assertFalse(m:instance_of(c))
end

-- Tests instance_of() with multiple inheritance where C extends both A and B.
-- The child instance should be recognized as an instance of all parent classes.
-- This verifies that instance_of traverses all parent branches, not just one.
function Test:testInstanceOfMultipleInheritance()
    class "A" {}
    class "B" {}
    class "C" extends "A, B" {}

    local c = C.new()

    assertTrue(c:instance_of(A))
    assertTrue(c:instance_of(B))
    assertTrue(c:instance_of(C))
end

-- Tests instance_of() with a deep diamond-like hierarchy: Child extends Mid1 and Mid2,
-- where Mid1 extends Base1 and Mid2 extends Base2. Verifies that instance_of
-- correctly identifies the child as an instance of all ancestors (parents and
-- grandparents) while correctly rejecting unrelated classes in different branches.
function Test:testInstanceOfDeepMultipleInheritance()
    class "Base1" {}
    class "Base2" {}
    class "Mid1" extends "Base1" {}
    class "Mid2" extends "Base2" {}
    class "Child" extends "Mid1, Mid2" {}

    local child = Child.new()

    -- Direct parents
    assertTrue(child:instance_of(Mid1))
    assertTrue(child:instance_of(Mid2))

    -- Grandparents
    assertTrue(child:instance_of(Base1))
    assertTrue(child:instance_of(Base2))

    -- Self
    assertTrue(child:instance_of(Child))

    -- Unrelated
    assertFalse(Mid1:instance_of(Mid2))
    assertFalse(Base1:instance_of(Base2))
end

---------------------------------------------------------------------
-- get_name() tests
---------------------------------------------------------------------

-- Tests get_name() returns the class name as a string.
-- From docs: "print(p:get_name())  -- Player"
function Test:testGetName()
    class "GetNamePlayer" {}

    local p = GetNamePlayer.new()
    assertEquals(p:get_name(), "GetNamePlayer")
end

-- Tests get_name() with namespaces returns the full qualified name.
-- From docs: "print(e:get_name())  -- game.entities.Enemy"
function Test:testGetNameWithNamespace()
    namespace "game.entities"

    class "Enemy" {}

    local e = game.entities.Enemy.new()
    assertEquals(e:get_name(), "game.entities.Enemy")
    
    namespace ""
end

---------------------------------------------------------------------
-- get_class() tests
---------------------------------------------------------------------

-- Tests get_class() returns the base class of the instance.
-- From docs: "print(p:get_class() == Player)  -- true"
function Test:testGetClass()
    class "GetClassPlayer" {}

    local p = GetClassPlayer.new()
    assertTrue(p:get_class() == GetClassPlayer)
end

-- Tests that get_class() is equivalent to accessing _base.
-- From docs: "print(p:get_class() == p._base)  -- true"
function Test:testGetClassEqualsBase()
    class "GetClassBase" {}

    local p = GetClassBase.new()
    assertTrue(p:get_class() == p._base)
end

-- Tests get_class() with inheritance returns the actual class, not parent.
function Test:testGetClassWithInheritance()
    class "GetClassParent" {}
    class "GetClassChild" extends "GetClassParent" {}

    local c = GetClassChild.new()
    assertTrue(c:get_class() == GetClassChild)
    assertFalse(c:get_class() == GetClassParent)
end

---------------------------------------------------------------------
-- get_parents() tests
---------------------------------------------------------------------

-- Tests get_parents() returns a table of parent instances.
-- From docs: accessing parents.A and parents.B after extends "A, B"
function Test:testGetParents()
    class "ParentA" {
        value = "A";
    }
    class "ParentB" {
        value = "B";
    }
    class "ChildAB" extends "ParentA, ParentB" {}

    local c = ChildAB.new()
    local parents = c:get_parents()

    -- Should have both parents
    assertTrue(parents.ParentA ~= nil)
    assertTrue(parents.ParentB ~= nil)
end

-- Tests that get_parents() returns empty table for class with no parents.
function Test:testGetParentsNoInheritance()
    class "NoParents" {}

    local n = NoParents.new()
    local parents = n:get_parents()

    -- Should be empty or have no entries
    local count = 0
    for _ in pairs(parents) do
        count = count + 1
    end
    assertEquals(count, 0)
end

-- Tests get_parents() with single inheritance.
function Test:testGetParentsSingleInheritance()
    class "SingleParent" {
        value = 42;
    }
    class "SingleChild" extends "SingleParent" {}

    local c = SingleChild.new()
    local parents = c:get_parents()

    assertTrue(parents.SingleParent ~= nil)
end

-- Tests instance_of() with string class names (v2 backwards compatibility).
-- Accepts both class objects and string names for convenience.
function Test:testInstanceOfWithStringName()
    class "StringTestParent" {}
    class "StringTestChild" extends "StringTestParent" {}

    local c = StringTestChild.new()

    -- String names work
    assertTrue(c:instance_of("StringTestChild"))
    assertTrue(c:instance_of("StringTestParent"))

    -- Non-existent class returns false (not error)
    assertFalse(c:instance_of("NonExistentClass"))

    -- Class objects still work
    assertTrue(c:instance_of(StringTestChild))
    assertTrue(c:instance_of(StringTestParent))
end

-- Tests instance_of() with namespaced string names.
function Test:testInstanceOfWithNamespacedString()
    namespace "testns"
    class "NsParent" {}
    class "NsChild" extends "NsParent" {}
    namespace ""

    local c = testns.NsChild.new()

    -- Full path string works
    assertTrue(c:instance_of("testns.NsChild"))
    assertTrue(c:instance_of("testns.NsParent"))

    -- Short name doesn't work (not registered that way)
    assertFalse(c:instance_of("NsChild"))
end