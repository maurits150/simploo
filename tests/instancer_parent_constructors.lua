--[[
    Tests that child classes can explicitly call parent methods.
    
    With multiple inheritance, child methods can use self.ParentName:method()
    to invoke specific parent implementations.
]]

-- Tests that child methods can explicitly invoke specific parent methods.
-- With multiple inheritance (C extends A, B), the child's func() can call
-- both self.A:func() and self.B:func() to invoke each parent's implementation.
-- This pattern is essential when the child needs to combine behavior from
-- multiple parents rather than just overriding one.
function Test:testParentConstructors()
	A_CALLED = false
	B_CALLED = false
	C_CALLED = false

	class "A" {
	    func = function(self)
	        A_CALLED = true
	    end;
	}

	class "B" {
	    func = function(self)
	        B_CALLED = true
	    end;
	}

	class "C" extends "A, B" {
	    func = function(self)
	        self.A:func()
	        self.B:func()

	        C_CALLED = true
	    end;
	}

	C.new():func()

	assertTrue(A_CALLED)
	assertTrue(B_CALLED)
	assertTrue(C_CALLED)
end