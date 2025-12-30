--[[
    Tests adding new members to instances at runtime.
    
    Members added after instantiation should work like regular members
    but are marked transient (not serialized).
]]

-- Tests that new members can be added to instances dynamically at runtime.
-- When assigning to a key that doesn't exist in the class definition,
-- the __newindex metamethod creates a new member marked as public and transient.
-- Transient means runtime members won't be serialized (they only exist in memory).
function Test:testAddingRuntimeMembers()
    class "RTM" {}

    local instance = RTM.new()

    instance.runtimeMember = "test"

    assertEquals(instance.runtimeMember, "test")
end