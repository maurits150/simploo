-- Test that user-defined members don't conflict with internal parser fields
-- Internal fields: _name, _ns, _parents, _members, _usings

Test.testBlockSyntaxNameMember = function()
    class "TestBlockName" {
        public {
            name = "test_value";
        };
    }

    local inst = TestBlockName()
    assertEquals(inst.name, "test_value")
end

Test.testBuilderSyntaxNameMember = function()
    local c = class("TestBuilderName")
    c.public.name = "builder_value"
    c:register()

    local inst = TestBuilderName()
    assertEquals(inst.name, "builder_value")
end

Test.testBuilderSyntaxParentsMember = function()
    local c = class("TestBuilderParents")
    c.public.parents = {"a", "b", "c"}
    c:register()

    local inst = TestBuilderParents()
    assertEquals(inst.parents[1], "a")
    assertEquals(inst.parents[2], "b")
    assertEquals(inst.parents[3], "c")
end

Test.testBuilderSyntaxMembersMember = function()
    local c = class("TestBuilderMembers")
    c.public.members = {foo = "bar"}
    c:register()

    local inst = TestBuilderMembers()
    assertEquals(inst.members.foo, "bar")
end
