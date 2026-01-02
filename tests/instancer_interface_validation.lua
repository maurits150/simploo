--[[
    Tests interface validation in the instancer.
    
    When a class implements an interface, the instancer should verify
    that the class has all methods declared by the interface.
]]

---------------------------------------------------------------------
-- Tests that work in all modes (success cases)
---------------------------------------------------------------------

-- Test: class implementing interface with all methods succeeds
function Test:testImplementsWithAllMethods()
    interface "IMovable" {
        move = function(self, x, y) end;
        getPosition = function(self) end;
    }

    class "MovablePlayer" implements "IMovable" {
        x = 0;
        y = 0;

        move = function(self, dx, dy)
            self.x = self.x + dx
            self.y = self.y + dy
        end;

        getPosition = function(self)
            return self.x, self.y
        end;
    }

    local p = MovablePlayer.new()
    p:move(5, 3)
    local x, y = p:getPosition()
    assertEquals(x, 5)
    assertEquals(y, 3)
end

-- Test: class implementing multiple interfaces
function Test:testImplementsMultipleInterfaces()
    interface "INameable" {
        getName = function(self) end;
        setName = function(self, name) end;
    }

    interface "ICountable" {
        getCount = function(self) end;
        increment = function(self) end;
    }

    class "NamedCounter" implements "INameable, ICountable" {
        name = "";
        count = 0;

        getName = function(self) return self.name end;
        setName = function(self, name) self.name = name end;
        getCount = function(self) return self.count end;
        increment = function(self) self.count = self.count + 1 end;
    }

    local nc = NamedCounter.new()
    nc:setName("MyCounter")
    nc:increment()
    nc:increment()
    assertEquals(nc:getName(), "MyCounter")
    assertEquals(nc:getCount(), 2)
end

-- Test: class implementing extended interface with all methods succeeds
function Test:testImplementsExtendedInterfaceSuccess()
    interface "IBaseAnimal" {
        eat = function(self) end;
    }

    interface "IPet" extends "IBaseAnimal" {
        play = function(self) end;
    }

    class "Dog" implements "IPet" {
        eat = function(self) return "eating" end;
        play = function(self) return "playing" end;
    }

    local dog = Dog.new()
    assertEquals(dog:eat(), "eating")
    assertEquals(dog:play(), "playing")
end

-- Test: class can extend another class AND implement interface
function Test:testExtendsAndImplements()
    interface "ISerializable" {
        serialize = function(self) end;
    }

    class "BaseEntity" {
        id = 0;
        getId = function(self) return self.id end;
    }

    class "SerializableEntity" extends "BaseEntity" implements "ISerializable" {
        serialize = function(self)
            return "id:" .. self.id
        end;
    }

    local e = SerializableEntity.new()
    e.id = 42
    assertEquals(e:getId(), 42)
    assertEquals(e:serialize(), "id:42")
end

-- Test: inherited method from parent class satisfies interface
function Test:testInheritedMethodSatisfiesInterface()
    interface "IIdentifiable" {
        getId = function(self) end;
    }

    class "BaseWithId" {
        id = 0;
        getId = function(self) return self.id end;
    }

    class "ChildWithId" extends "BaseWithId" implements "IIdentifiable" {
        name = "child";
    }

    local child = ChildWithId.new()
    child.id = 99
    assertEquals(child:getId(), 99)
end

-- Test: interface with no methods (marker interface)
function Test:testMarkerInterface()
    interface "IMarker" {}

    class "MarkedClass" implements "IMarker" {
        value = 42;
    }

    local m = MarkedClass.new()
    assertEquals(m.value, 42)
end

-- Test: default interface methods are optional
function Test:testDefaultMethodsAreOptional()
    interface "IWithDefault" {
        required = function(self) end;

        default {
            optional = function(self)
                return "default"
            end;
        };
    }

    class "UsesDefault" implements "IWithDefault" {
        required = function(self) return "required" end;
    }

    local obj = UsesDefault.new()
    assertEquals(obj:required(), "required")
    assertEquals(obj:optional(), "default")
end

-- Test: default methods can be overridden
function Test:testDefaultMethodsCanBeOverridden()
    interface "IOverrideable" {
        default {
            greet = function(self)
                return "Hello"
            end;
        };
    }

    class "CustomGreeting" implements "IOverrideable" {
        greet = function(self)
            return "Hi there!"
        end;
    }

    local obj = CustomGreeting.new()
    assertEquals(obj:greet(), "Hi there!")
end

-- Test: instance_of works with interfaces
function Test:testInstanceOfWithInterface()
    interface "ICheckable" {
        check = function(self) end;
    }

    class "Checker" implements "ICheckable" {
        check = function(self) return true end;
    }

    class "NonChecker" {
        foo = function(self) end;
    }

    local checker = Checker.new()
    local nonChecker = NonChecker.new()

    assertTrue(checker:instance_of(ICheckable))
    assertFalse(nonChecker:instance_of(ICheckable))
end

-- Test: instance_of works with inherited interfaces
function Test:testInstanceOfWithInheritedInterface()
    interface "IBaseInterface" {
        base = function(self) end;
    }

    interface "IDerivedInterface" extends "IBaseInterface" {
        derived = function(self) end;
    }

    class "FullImpl" implements "IDerivedInterface" {
        base = function(self) return "base" end;
        derived = function(self) return "derived" end;
    }

    local obj = FullImpl.new()
    assertTrue(obj:instance_of(IDerivedInterface))
    assertTrue(obj:instance_of(IBaseInterface))
end

-- Test: interface with namespaces
function Test:testInterfaceWithNamespace()
    namespace "validation.test"

    interface "INamespaced" {
        getValue = function(self) end;
    }

    class "NamespacedImpl" implements "INamespaced" {
        getValue = function(self) return 123 end;
    }

    namespace ""

    local obj = validation.test.NamespacedImpl.new()
    assertEquals(obj:getValue(), 123)
end

-- Test: implements interface from different namespace via using
function Test:testImplementsWithUsing()
    namespace "other.ns"

    interface "IRemote" {
        remoteMethod = function(self) end;
    }

    namespace "my.ns"
    using "other.ns.IRemote"

    class "LocalImpl" implements "IRemote" {
        remoteMethod = function(self) return "remote" end;
    }

    namespace ""

    local obj = my.ns.LocalImpl.new()
    assertEquals(obj:remoteMethod(), "remote")
end

---------------------------------------------------------------------
-- Validation tests (skip in production mode)
---------------------------------------------------------------------

if simploo.config["production"] then
    print("skipping interface validation tests in production mode")
    return
end

-- Test: class missing interface method fails at definition time
function Test:testImplementsMissingMethodFails()
    interface "IDrawable" {
        draw = function(self) end;
        setColor = function(self, color) end;
    }

    local success, err = pcall(function()
        class "BadShape" implements "IDrawable" {
            draw = function(self)
                return "drawing"
            end;
        }
    end)

    assertFalse(success)
    assertStrContains(err, "setColor")
    assertStrContains(err, "IDrawable")
end

-- Test: class missing method from one of multiple interfaces fails
function Test:testImplementsMultipleMissingMethodFails()
    interface "IFirst" {
        first = function(self) end;
    }

    interface "ISecond" {
        second = function(self) end;
    }

    local success, err = pcall(function()
        class "PartialImpl" implements "IFirst, ISecond" {
            first = function(self) return 1 end;
        }
    end)

    assertFalse(success)
    assertStrContains(err, "second")
    assertStrContains(err, "ISecond")
end

-- Test: interface not found error
function Test:testImplementsInterfaceNotFound()
    local success, err = pcall(function()
        class "LonelyClass" implements "INonExistent" {
            foo = function(self) end;
        }
    end)

    assertFalse(success)
    assertStrContains(err, "INonExistent")
end

-- Test: interface extending interface - class must implement all
function Test:testImplementsExtendedInterface()
    interface "IBase" {
        baseMethod = function(self) end;
    }

    interface "IDerived" extends "IBase" {
        derivedMethod = function(self) end;
    }

    local success, err = pcall(function()
        class "PartialDerivedImpl" implements "IDerived" {
            derivedMethod = function(self) return "derived" end;
        }
    end)

    assertFalse(success)
    assertStrContains(err, "baseMethod")
end

-- Test: missing required method with default present still fails
function Test:testMissingRequiredWithDefaultPresent()
    interface "IMixed" {
        mustHave = function(self) end;

        default {
            canSkip = function(self) return "skipped" end;
        };
    }

    local success, err = pcall(function()
        class "MissingRequired" implements "IMixed" {}
    end)

    assertFalse(success)
    assertStrContains(err, "mustHave")
end

-- Test: interfaces cannot be instantiated
function Test:testInterfaceCannotBeInstantiated()
    interface "INotInstantiable" {
        foo = function(self) end;
    }

    local success, err = pcall(function()
        INotInstantiable.new()
    end)

    assertFalse(success)
    assertStrContains(err, "interface")
end

-- Test: member with same name but wrong type fails
function Test:testImplementsWrongTypeFails()
    interface "ICallable" {
        call = function(self) end;
    }

    local success, err = pcall(function()
        class "NotCallable" implements "ICallable" {
            call = "not a function";
        }
    end)

    assertFalse(success)
    assertStrContains(err, "call")
    assertStrContains(err, "must be a function")
    assertStrContains(err, "got string")
end

-- Test: strict interfaces disabled - mismatched args allowed
function Test:testNonStrictInterfaceAllowsMismatch()
    local originalStrict = simploo.config["strictInterfaces"]
    simploo.config["strictInterfaces"] = false
    
    interface "INonStrict" {
        action = function(self, a, b, c) end;
    }

    class "FlexibleImpl" implements "INonStrict" {
        action = function(self, x) end;
    }

    simploo.config["strictInterfaces"] = originalStrict

    local obj = FlexibleImpl.new()
    assertTrue(obj ~= nil)
end

-- Test: call default method from override via self.InterfaceName:method()
function Test:testCallDefaultMethodFromOverride()
    interface "ICallableDefault" {
        default {
            greet = function(self)
                return "Hello"
            end;
        };
    }

    class "ExtendedGreeter" implements "ICallableDefault" {
        greet = function(self)
            return self.ICallableDefault:greet() .. ", World!"
        end;
    }

    local obj = ExtendedGreeter.new()
    assertEquals(obj:greet(), "Hello, World!")
end

-- Test: interface reference exists only when interface has default methods
function Test:testInterfaceReferenceOnlyWithDefaults()
    interface "INoDefaults" {
        foo = true;
    }

    interface "IWithDefaults" {
        bar = true;
        default {
            baz = function(self) return "baz" end;
        };
    }

    class "ImplNoDefaults" implements "INoDefaults" {
        foo = function(self) return "foo" end;
    }

    class "ImplWithDefaults" implements "IWithDefaults" {
        bar = function(self) return "bar" end;
    }

    local noDefaults = ImplNoDefaults.new()
    local withDefaults = ImplWithDefaults.new()

    assertEquals(noDefaults.INoDefaults, nil)
    assertNotEquals(withDefaults.IWithDefaults, nil)
end

-- Test: call default method even when overriding all methods
function Test:testCallDefaultWhenOverridden()
    interface "IOverrideAll" {
        default {
            action = function(self)
                return "default action"
            end;
        };
    }

    class "OverridesAll" implements "IOverrideAll" {
        action = function(self)
            local defaultResult = self.IOverrideAll:action()
            return "override + " .. defaultResult
        end;
    }

    local obj = OverridesAll.new()
    assertEquals(obj:action(), "override + default action")
end

-- Test: multiple interfaces with defaults
function Test:testMultipleInterfacesWithDefaults()
    interface "ILogger" {
        default {
            log = function(self, msg)
                return "LOG: " .. msg
            end;
        };
    }

    interface "IFormatter" {
        default {
            format = function(self, val)
                return "[" .. tostring(val) .. "]"
            end;
        };
    }

    class "LogFormatter" implements "ILogger, IFormatter" {
        output = function(self, val)
            return self.ILogger:log(self.IFormatter:format(val))
        end;
    }

    local obj = LogFormatter.new()
    assertEquals(obj:output(42), "LOG: [42]")
end

-- Test: deep interface inheritance (5 levels)
function Test:testDeepInterfaceInheritance()
    interface "ILevel1" { method1 = true; }
    interface "ILevel2" extends "ILevel1" { method2 = true; }
    interface "ILevel3" extends "ILevel2" { method3 = true; }
    interface "ILevel4" extends "ILevel3" { method4 = true; }
    interface "ILevel5" extends "ILevel4" { method5 = true; }

    class "DeepImpl" implements "ILevel5" {
        method1 = function(self) return 1 end;
        method2 = function(self) return 2 end;
        method3 = function(self) return 3 end;
        method4 = function(self) return 4 end;
        method5 = function(self) return 5 end;
    }

    local obj = DeepImpl.new()
    assertEquals(obj:method1(), 1)
    assertEquals(obj:method2(), 2)
    assertEquals(obj:method3(), 3)
    assertEquals(obj:method4(), 4)
    assertEquals(obj:method5(), 5)
    
    -- instance_of works for all levels
    assertTrue(obj:instance_of(ILevel1))
    assertTrue(obj:instance_of(ILevel3))
    assertTrue(obj:instance_of(ILevel5))
end

-- Test: only default methods are copied, not required methods
function Test:testOnlyDefaultMethodsCopied()
    local interfaceRequiredFn = function(self) return "interface required" end
    
    interface "ICheckCopy" {
        required = interfaceRequiredFn;
        
        default {
            optional = function(self) return "interface default" end;
        };
    }

    class "CheckCopyImpl" implements "ICheckCopy" {
        required = function(self) return "class required" end;
        -- optional not overridden - should use default
    }

    local obj = CheckCopyImpl.new()
    
    -- Class method should NOT be the interface's function (required methods not copied)
    assertEquals(obj:required(), "class required")
    assertNotEquals(obj:get_member("required").value, interfaceRequiredFn)
    
    -- Default method should be copied from interface
    assertEquals(obj:optional(), "interface default")
end
