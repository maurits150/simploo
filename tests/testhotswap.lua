
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
