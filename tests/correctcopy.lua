--[[
    Tests that instances correctly share base class references.
    
    Multiple instances should reference the same _base class object
    so static members are properly shared.
]]

-- Tests that all instances of a class share the same _base reference.
-- The _base points to the class definition where static members are stored.
-- This ensures static members are truly shared: modifying one affects all.
-- Also verifies parent references within instances point to the same
-- parent _base across all child instances.
function Test:testInstancesWithParentsShareSameBase()
    class "P" {}
    class "M" extends "P" {}
    class "C" extends "M" {}

    assertTrue(C.new()._base == C.new()._base)
    assertTrue(C.new().M._base == M.new()._base)
    assertTrue(C.new().M.P._base == P.new()._base)
end