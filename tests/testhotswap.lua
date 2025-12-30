--[[
    Tests class hotswapping functionality.
    
    When a class is redefined, existing instances should receive
    new members while preserving their existing member values.
]]

-- Tests class hotswapping: when a class is redefined, existing instances update.
-- Scenario: Create instance with members keep_me and destroy. Redefine class
-- to have keep_me (different default) and new_item (but no destroy).
-- Expected: Instance's keep_me retains original value, destroy becomes nil,
-- and new_item is added with the new default. This enables live code reloading.
function Test:testHotswap()
    simploo.hotswap:init()

    class "A" {
        keep_me = "I will not be touched.";
        destroy = "I will be destroyed.";
    }

    local instanceA = A.new()
    assertEquals(instanceA.keep_me, "I will not be touched.")
    assertEquals(instanceA.destroy, "I will be destroyed.")

    class "A" {
        keep_me = "I have been touched which is bad!";
        -- destroy = -> this field no longer exist and should become nil
        new_item = "I'm new.";
    }

    assertEquals(instanceA.keep_me, "I will not be touched.")
    assertEquals(instanceA.destroy, nil)
    assertEquals(instanceA.new_item, "I'm new.")
end
