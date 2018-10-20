TestInstancerMultipleInheritance = {}

function TestInstancerMultipleInheritance:testOverrides()
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

LuaUnit:run("TestInstancerMultipleInheritance")