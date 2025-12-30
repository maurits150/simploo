--[[
    Tests adding new members to instances at runtime.
    
    Members added after instantiation should work like regular members
    but are marked transient (not serialized).
]]

-- Verifies members can be added to instances dynamically after creation
function Test:testAddingRuntimeMembers()
    class "RTM" {}

    local instance = RTM.new()

    instance.runtimeMember = "test"

    assertEquals(instance.runtimeMember, "test")
end