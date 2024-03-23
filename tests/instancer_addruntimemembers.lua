function Test:testAddingRuntimeMembers()
    class "RTM" {}

    local instance = RTM.new()

    instance.runtimeMember = "test"

    assertEquals(instance.runtimeMember, "test")
end