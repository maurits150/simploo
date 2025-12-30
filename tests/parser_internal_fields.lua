-- Test that user-defined members don't conflict with internal parser fields
-- Internal fields: _name, _ns, _parents, _members, _usings

-- Tests that user-defined 'name' member doesn't conflict with parser internals.
-- The parser uses _name internally, but user code should be able to define
-- a member called 'name' without issues. Block syntax stores user members
-- separately from internal parser fields to avoid collisions.
Test.testBlockSyntaxNameMember = function()
    class "TestBlockName" {
        public {
            name = "test_value";
        };
    }

    local inst = TestBlockName()
    assertEquals(inst.name, "test_value")
end

-- Tests that builder syntax allows 'name' as a member without conflict.
-- The parser stores internals in _simploo table (like _simploo.name), so
-- c.public.name goes through __newindex to become a class member, not
-- overwriting the internal parser name field.
Test.testBuilderSyntaxNameMember = function()
    local c = class("TestBuilderName")
    c.public.name = "builder_value"
    c:register()

    local inst = TestBuilderName()
    assertEquals(inst.name, "builder_value")
end

-- Tests that 'parents' as a member name doesn't conflict with internal parents list.
-- The parser stores inheritance info in _simploo.parents, so defining a
-- member called 'parents' works correctly - it becomes a class member
-- containing user data (a table of strings), not the inheritance list.
Test.testBuilderSyntaxParentsMember = function()
    local c = class("TestBuilderParents")
    c.public.parents = {"a", "b", "c"}
    c:register()

    local inst = TestBuilderParents()
    assertEquals(inst.parents[1], "a")
    assertEquals(inst.parents[2], "b")
    assertEquals(inst.parents[3], "c")
end

-- Tests that 'members' as a member name doesn't conflict with internal members table.
-- The parser stores class members in _simploo.members, so a user-defined
-- 'members' becomes a class member with user data (here, a table with foo="bar"),
-- completely separate from the internal member storage.
Test.testBuilderSyntaxMembersMember = function()
    local c = class("TestBuilderMembers")
    c.public.members = {foo = "bar"}
    c:register()

    local inst = TestBuilderMembers()
    assertEquals(inst.members.foo, "bar")
end
