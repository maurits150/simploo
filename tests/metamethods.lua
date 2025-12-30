--[[
    Tests custom metamethod support (__tostring, __call, __add, etc).
    
    Verifies that user-defined metamethods are properly invoked
    when instances are used with Lua operators and built-in functions.
]]

-- Verifies custom __newindex and __index metamethods redirect property access
function Test:testCustomNewIndex()
    class "CustomNewIndex" {
        public {
            data = {};
            
            __newindex = function(self, key, value)
                self.data[key] = value
            end;
            
            __index = function(self, key)
                return self.data[key]
            end;
        }
    }

    local instance = CustomNewIndex.new()
    instance.foo = "bar"
    assertEquals(instance.data.foo, "bar")
    assertEquals(instance.foo, "bar")
end

-- Verifies custom __tostring metamethod is invoked by tostring()
function Test:testCustomToString()
    class "CustomToString" {
        public {
            name = "test";
            
            meta {
                __tostring = function(self)
                    return "CustomToString: " .. self.name
                end;
            }
        }
    }

    local instance = CustomToString.new()
    instance.name = "hello"
    assertEquals(tostring(instance), "CustomToString: hello")
end

-- Verifies instances can be called as functions via __call metamethod
function Test:testCustomCall()
    class "Callable" {
        public {
            value = 0;
            
            meta {
                __call = function(self, x)
                    return self.value + x
                end;
            }
        }
    }

    local instance = Callable.new()
    instance.value = 10
    assertEquals(instance(5), 15)
end

-- Verifies __concat metamethod enables string concatenation with ..
function Test:testCustomConcat()
    class "Concatable" {
        public {
            str = "";
            
            meta {
                __concat = function(self, other)
                    return self.str .. other
                end;
            }
        }
    }

    local instance = Concatable.new()
    instance.str = "hello"
    assertEquals(instance .. " world", "hello world")
end

-- Verifies __unm metamethod enables unary minus operator
function Test:testCustomUnm()
    class "Negatable" {
        public {
            value = 0;
            
            meta {
                __unm = function(self)
                    return -self.value
                end;
            }
        }
    }

    local instance = Negatable.new()
    instance.value = 42
    assertEquals(-instance, -42)
end

-- Verifies __add metamethod enables + operator
function Test:testCustomAdd()
    class "Addable" {
        public {
            value = 0;
            
            meta {
                __add = function(self, other)
                    return self.value + other
                end;
            }
        }
    }

    local instance = Addable.new()
    instance.value = 10
    assertEquals(instance + 5, 15)
end

-- Verifies __sub metamethod enables - operator
function Test:testCustomSub()
    class "Subtractable" {
        public {
            value = 0;
            
            meta {
                __sub = function(self, other)
                    return self.value - other
                end;
            }
        }
    }

    local instance = Subtractable.new()
    instance.value = 10
    assertEquals(instance - 3, 7)
end

-- Verifies __mul metamethod enables * operator
function Test:testCustomMul()
    class "Multipliable" {
        public {
            value = 0;
            
            meta {
                __mul = function(self, other)
                    return self.value * other
                end;
            }
        }
    }

    local instance = Multipliable.new()
    instance.value = 6
    assertEquals(instance * 7, 42)
end

-- Verifies __div metamethod enables / operator
function Test:testCustomDiv()
    class "Dividable" {
        public {
            value = 0;
            
            meta {
                __div = function(self, other)
                    return self.value / other
                end;
            }
        }
    }

    local instance = Dividable.new()
    instance.value = 20
    assertEquals(instance / 4, 5)
end

-- Verifies __mod metamethod enables % operator
function Test:testCustomMod()
    class "Modable" {
        public {
            value = 0;
            
            meta {
                __mod = function(self, other)
                    return self.value % other
                end;
            }
        }
    }

    local instance = Modable.new()
    instance.value = 17
    assertEquals(instance % 5, 2)
end

-- Verifies __pow metamethod enables ^ operator
function Test:testCustomPow()
    class "Powerable" {
        public {
            value = 0;
            
            meta {
                __pow = function(self, other)
                    return self.value ^ other
                end;
            }
        }
    }

    local instance = Powerable.new()
    instance.value = 2
    assertEquals(instance ^ 3, 8)
end

-- Verifies __eq metamethod enables custom equality comparison
function Test:testCustomEq()
    class "Equatable" {
        public {
            id = 0;
            
            meta {
                __eq = function(self, other)
                    return self.id == other.id
                end;
            }
        }
    }

    local a = Equatable.new()
    local b = Equatable.new()
    a.id = 42
    b.id = 42
    assertTrue(a == b)
    
    b.id = 99
    assertFalse(a == b)
end

-- Verifies __lt metamethod enables < comparison
function Test:testCustomLt()
    class "Comparable" {
        public {
            value = 0;
            
            meta {
                __lt = function(self, other)
                    return self.value < other.value
                end;
            }
        }
    }

    local a = Comparable.new()
    local b = Comparable.new()
    a.value = 5
    b.value = 10
    assertTrue(a < b)
    assertFalse(b < a)
end

-- Verifies __le metamethod enables <= comparison
function Test:testCustomLe()
    class "ComparableLE" {
        public {
            value = 0;
            
            meta {
                __le = function(self, other)
                    return self.value <= other.value
                end;
            }
        }
    }

    local a = ComparableLE.new()
    local b = ComparableLE.new()
    a.value = 5
    b.value = 5
    assertTrue(a <= b)
    
    a.value = 3
    assertTrue(a <= b)
    
    a.value = 10
    assertFalse(a <= b)
end
