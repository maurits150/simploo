--[[
    Tests that instances correctly share base class references.
    
    Multiple instances should reference the same _base class object
    so static members are properly shared.
]]

function Test:testInstancesWithParentsShareSameBase()
    class "P" {}
    class "M" extends "P" {}
    class "C" extends "M" {}

    assertTrue(C.new()._base == C.new()._base)
    assertTrue(C.new().M._base == M.new()._base)
    assertTrue(C.new().M.P._base == P.new()._base)
end