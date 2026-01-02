--[[
    Tests for parent constructor warning behavior (dev mode only).
    
    In dev mode, SIMPLOO warns if a child constructor doesn't call its parent constructor.
    This matches the behavior of languages like Java/JavaScript that enforce parent
    constructor calls.
]]

-- Skip these tests in production mode since warnings are dev-mode only
if simploo.config.production then
    print("skipping constructor warning tests in production mode")
    return
end

-- Capture warnings by temporarily replacing print
local warnings = {}
local originalPrint = print
local function capturePrint(...)
    local msg = table.concat({...}, "\t")
    if msg:match("^WARNING:") then
        table.insert(warnings, msg)
    else
        originalPrint(...)
    end
end

local function clearWarnings()
    warnings = {}
end

local function getWarnings()
    return warnings
end

local function setupCapture()
    clearWarnings()
    _G.print = capturePrint
end

local function teardownCapture()
    _G.print = originalPrint
end

-- Test that warning is issued when parent constructor is not called
function Test:testWarningWhenParentConstructorNotCalled()
    setupCapture()
    
    class "WarnParent" {
        value = 0;
        
        __construct = function(self)
            self.value = 42
        end;
    }
    
    class "WarnChild" extends "WarnParent" {
        __construct = function(self)
            -- Intentionally NOT calling self.WarnParent()
        end;
    }
    
    local c = WarnChild.new()
    
    teardownCapture()
    
    local warns = getWarnings()
    assertEquals(#warns, 1)
    assertTrue(warns[1]:match("WarnChild"))
    assertTrue(warns[1]:match("WarnParent"))
end

-- Test that no warning when parent constructor IS called
function Test:testNoWarningWhenParentConstructorCalled()
    setupCapture()
    
    class "GoodParent" {
        value = 0;
        
        __construct = function(self)
            self.value = 42
        end;
    }
    
    class "GoodChild" extends "GoodParent" {
        __construct = function(self)
            self.GoodParent()  -- Properly calling parent constructor
        end;
    }
    
    local c = GoodChild.new()
    
    teardownCapture()
    
    assertEquals(#getWarnings(), 0)
    assertEquals(c.value, 42)  -- Parent constructor ran
end

-- Test that no warning when parent has no constructor
function Test:testNoWarningWhenParentHasNoConstructor()
    setupCapture()
    
    class "NoConstructParent" {
        value = 10;
    }
    
    class "NoConstructChild" extends "NoConstructParent" {
        __construct = function(self)
            -- Parent has no constructor, so nothing to call
        end;
    }
    
    local c = NoConstructChild.new()
    
    teardownCapture()
    
    assertEquals(#getWarnings(), 0)
end

-- Test that no warning when child has no constructor (inherits parent's)
function Test:testNoWarningWhenChildInheritsConstructor()
    setupCapture()
    
    class "InheritParent" {
        value = 0;
        
        __construct = function(self)
            self.value = 99
        end;
    }
    
    class "InheritChild" extends "InheritParent" {
        -- No constructor, inherits parent's
    }
    
    local c = InheritChild.new()
    
    teardownCapture()
    
    assertEquals(#getWarnings(), 0)
    assertEquals(c.value, 99)  -- Parent constructor ran
end

-- Test warning in deep hierarchy (A -> B -> C, C doesn't call B)
-- Only warns about direct parent B, not grandparent A
function Test:testWarningInDeepHierarchy()
    setupCapture()
    
    class "DeepA" {
        __construct = function(self)
        end;
    }
    
    class "DeepB" extends "DeepA" {
        __construct = function(self)
            self.DeepA()  -- B properly calls A
        end;
    }
    
    class "DeepC" extends "DeepB" {
        __construct = function(self)
            -- C does NOT call B
        end;
    }
    
    local c = DeepC.new()
    
    teardownCapture()
    
    local warns = getWarnings()
    -- Only warns about direct parent B, not inherited grandparent A
    assertEquals(#warns, 1)
    assertTrue(warns[1]:match("DeepC"))
    assertTrue(warns[1]:match("DeepB"))
end

-- Test warning for multiple parents (only warns for those not called)
function Test:testWarningWithMultipleInheritance()
    setupCapture()
    
    class "MultiA" {
        __construct = function(self)
        end;
    }
    
    class "MultiB" {
        __construct = function(self)
        end;
    }
    
    class "MultiChild" extends "MultiA, MultiB" {
        __construct = function(self)
            self.MultiA()  -- Only calls A, not B
        end;
    }
    
    local c = MultiChild.new()
    
    teardownCapture()
    
    local warns = getWarnings()
    assertEquals(#warns, 1)
    assertTrue(warns[1]:match("MultiChild"))
    assertTrue(warns[1]:match("MultiB"))
end

-- Test that constructor can only be called once (double-call prevention)
function Test:testConstructorCannotBeCalledTwice()
    class "DoubleCallParent" {
        callCount = 0;
        
        __construct = function(self)
            self.callCount = self.callCount + 1
        end;
    }
    
    class "DoubleCallChild" extends "DoubleCallParent" {
        __construct = function(self)
            self.DoubleCallParent()
            self.DoubleCallParent()  -- Second call should be no-op
            self.DoubleCallParent()  -- Third call should be no-op
        end;
    }
    
    local c = DoubleCallChild.new()
    assertEquals(c.callCount, 1)  -- Only called once despite 3 attempts
end

-- Test calling parent constructor with arguments
function Test:testParentConstructorWithArguments()
    setupCapture()
    
    class "ArgParent" {
        a = 0;
        b = 0;
        
        __construct = function(self, a, b)
            self.a = a
            self.b = b
        end;
    }
    
    class "ArgChild" extends "ArgParent" {
        c = 0;
        
        __construct = function(self, a, b, c)
            self.ArgParent(a, b)
            self.c = c
        end;
    }
    
    local c = ArgChild.new(1, 2, 3)
    
    teardownCapture()
    
    assertEquals(#getWarnings(), 0)
    assertEquals(c.a, 1)
    assertEquals(c.b, 2)
    assertEquals(c.c, 3)
end

-- Test calling parent constructor directly (not via __call syntax)
function Test:testDirectConstructorCall()
    setupCapture()
    
    class "DirectParent" {
        value = 0;
        
        __construct = function(self)
            self.value = 123
        end;
    }
    
    class "DirectChild" extends "DirectParent" {
        __construct = function(self)
            -- Call constructor directly instead of self.DirectParent()
            self.DirectParent:__construct()
        end;
    }
    
    local c = DirectChild.new()
    
    teardownCapture()
    
    assertEquals(#getWarnings(), 0)
    assertEquals(c.value, 123)
end
