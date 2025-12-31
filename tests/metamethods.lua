--[[
    Tests custom metamethod support (__tostring, __call, __add, etc).
    
    Verifies that user-defined metamethods are properly invoked
    when instances are used with Lua operators and built-in functions.
]]

-- Tests that custom __newindex and __index metamethods correctly intercept
-- property access on instances. When setting instance.foo, it should route
-- through __newindex to store in data table. Reading should use __index
-- to retrieve from data table instead of normal member lookup.
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

-- Tests that a custom __tostring metamethod in the meta block is properly
-- invoked when tostring() is called on an instance. The metamethod should
-- receive self and be able to access instance members to build the string.
-- This enables readable debug output and custom string representations.
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

-- Tests that the __call metamethod allows instances to be invoked like functions.
-- After construction, calling instance(args) invokes the __call handler.
-- This is useful for creating callable objects like functors or command patterns.
-- The metamethod receives self followed by any passed arguments.
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

-- Tests that the __concat metamethod enables using the .. operator with instances.
-- When instance .. "string" is evaluated, __concat receives self and the other operand.
-- This allows natural string building patterns with custom objects.
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

-- Tests that the __unm metamethod enables the unary minus operator on instances.
-- When -instance is evaluated, __unm is called with self to compute the negation.
-- Useful for mathematical types like vectors or complex numbers.
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

-- Tests that the __add metamethod enables the + operator on instances.
-- When instance + other is evaluated, __add receives self and the right operand.
-- Useful for implementing mathematical addition on custom types.
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

-- Tests that the __sub metamethod enables the binary - operator on instances.
-- When instance - other is evaluated, __sub receives self and the right operand.
-- Useful for implementing subtraction on custom mathematical types.
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

-- Tests that the __mul metamethod enables the * operator on instances.
-- When instance * other is evaluated, __mul receives self and the right operand.
-- Useful for scalar multiplication, matrix operations, or scaling objects.
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

-- Tests that the __div metamethod enables the / operator on instances.
-- When instance / other is evaluated, __div receives self and the divisor.
-- Useful for implementing division on custom mathematical types.
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

-- Tests that the __mod metamethod enables the % (modulo) operator on instances.
-- When instance % other is evaluated, __mod receives self and the divisor.
-- Useful for implementing remainder operations on custom types.
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

-- Tests that the __pow metamethod enables the ^ (exponentiation) operator.
-- When instance ^ other is evaluated, __pow receives self and the exponent.
-- Useful for implementing power operations on custom mathematical types.
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

-- Tests that the __eq metamethod enables custom equality comparison with ==.
-- By default, two different instances are never equal (different tables).
-- With __eq, we can define semantic equality (e.g., same id means equal).
-- Both operands must have the same __eq metamethod for it to be invoked.
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

-- Tests that the __lt metamethod enables the < (less than) comparison operator.
-- When a < b is evaluated, __lt receives both instances to compare.
-- This also enables > via Lua's automatic reversal (a > b becomes b < a).
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

-- Tests that the __le metamethod enables the <= (less than or equal) operator.
-- When a <= b is evaluated, __le receives both instances to compare.
-- This also enables >= via Lua's automatic reversal (a >= b becomes b <= a).
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

-- Tests that metamethods defined on a parent class work on child instances.
-- When a child inherits from a parent with __add, using + on the child
-- should invoke the parent's __add metamethod correctly.
function Test:testInheritedMetamethod()
    class "MetaParent" {
        public {
            value = 0;
            
            meta {
                __add = function(self, other)
                    return self.value + other
                end;
            }
        }
    }

    class "MetaChild" extends "MetaParent" {
        public {
            childValue = "child";
        }
    }

    local child = MetaChild.new()
    child.value = 10
    assertEquals(child + 5, 15)
end

-- Tests that metamethods inherited through multiple levels work correctly.
-- Grandchild should be able to use __mul defined on grandparent.
function Test:testDeeplyInheritedMetamethod()
    class "MetaGrandparent" {
        public {
            value = 0;
            
            meta {
                __mul = function(self, other)
                    return self.value * other
                end;
            }
        }
    }

    class "MetaParent2" extends "MetaGrandparent" {
        public {
            parentValue = "parent";
        }
    }

    class "MetaGrandchild" extends "MetaParent2" {
        public {
            grandchildValue = "grandchild";
        }
    }

    local grandchild = MetaGrandchild.new()
    grandchild.value = 6
    assertEquals(grandchild * 7, 42)
end
