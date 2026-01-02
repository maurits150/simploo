--[[
    Consolidated access modifier tests.
    
    Tests public, protected, and private access in parallel scenarios.
    
    Access rules:
    - public: accessible from anywhere
    - protected: accessible from same class + subclasses
    - private: accessible from same class only
]]

-- Skip in production mode - access checks are disabled
if simploo.config["production"] then
    print("skipping test because it won't work in production mode")
    return
end

---------------------------------------------------------------------
-- Same class access: all modifiers should be accessible
---------------------------------------------------------------------

-- Tests that a class's own methods can access all its members regardless of modifier.
-- Within the same class, public, protected, and private members should all be
-- readable and writable. This is the baseline behavior - access restrictions
-- only apply when crossing class boundaries (external code or other classes).
function Test:testSameClassCanAccessAllModifiers()
    class "AccessTest" {
        public    { pubVar = "public" };
        protected { protVar = "protected" };
        private   { privVar = "private" };

        public {
            getPublic = function(self)
                return self.pubVar
            end;
            getProtected = function(self)
                return self.protVar
            end;
            getPrivate = function(self)
                return self.privVar
            end;
            setAll = function(self, pub, prot, priv)
                self.pubVar = pub
                self.protVar = prot
                self.privVar = priv
            end;
        }
    }

    local instance = AccessTest.new()

    -- All reads should work from within the class
    assertEquals(instance:getPublic(), "public")
    assertEquals(instance:getProtected(), "protected")
    assertEquals(instance:getPrivate(), "private")

    -- All writes should work from within the class
    instance:setAll("pub2", "prot2", "priv2")
    assertEquals(instance:getPublic(), "pub2")
    assertEquals(instance:getProtected(), "prot2")
    assertEquals(instance:getPrivate(), "priv2")
end

---------------------------------------------------------------------
-- Subclass access: public and protected yes, private no
---------------------------------------------------------------------

-- Tests that subclass methods can access parent's public and protected members.
-- Protected is specifically designed for inheritance - it allows child classes
-- to read and write the member while still hiding it from external code.
-- This enables extending parent behavior without exposing implementation details.
function Test:testSubclassCanAccessPublicAndProtected()
    class "Parent" {
        public    { pubVar = "public" };
        protected { protVar = "protected" };
        private   { privVar = "private" };
    }

    class "Child" extends "Parent" {
        public {
            readPublic = function(self)
                return self.pubVar
            end;
            readProtected = function(self)
                return self.protVar
            end;
            writePublic = function(self, v)
                self.pubVar = v
            end;
            writeProtected = function(self, v)
                self.protVar = v
            end;
        }
    }

    local instance = Child.new()

    -- Public access from child: should work
    assertEquals(instance:readPublic(), "public")
    instance:writePublic("pub2")
    assertEquals(instance:readPublic(), "pub2")

    -- Protected access from child: should work
    assertEquals(instance:readProtected(), "protected")
    instance:writeProtected("prot2")
    assertEquals(instance:readProtected(), "prot2")
end

-- Tests that subclass methods cannot access parent's private members.
-- Private means "only accessible within the declaring class" - even child
-- classes are treated as external. This enforces encapsulation: parent's
-- private implementation can change without breaking child classes.
function Test:testSubclassCannotAccessPrivate()
    class "ParentPriv" {
        private { secret = "hidden" };
    }

    class "ChildPriv" extends "ParentPriv" {
        public {
            tryReadPrivate = function(self)
                return self.secret
            end;
            tryWritePrivate = function(self, v)
                self.secret = v
            end;
        }
    }

    local instance = ChildPriv.new()

    -- Private read from child: should fail
    local success = pcall(function()
        instance:tryReadPrivate()
    end)
    assertFalse(success)

    -- Private write from child: should fail
    success = pcall(function()
        instance:tryWritePrivate("hacked")
    end)
    assertFalse(success)
end

---------------------------------------------------------------------
-- Outside access: only public works
---------------------------------------------------------------------

-- Tests that code outside any class can only access public members.
-- External code (test code, scripts, main program) should be able to read
-- and write public members but nothing else. This is the primary use case
-- for public members - they form the class's external API.
function Test:testOutsideCanAccessPublicOnly()
    class "Outsider" {
        public    { pubVar = "public" };
        protected { protVar = "protected" };
        private   { privVar = "private" };
    }

    local instance = Outsider.new()

    -- Public: should work from outside
    assertEquals(instance.pubVar, "public")
    instance.pubVar = "pub2"
    assertEquals(instance.pubVar, "pub2")
end

-- Tests that external code cannot access protected members.
-- Protected members are only for the class hierarchy (self + subclasses).
-- External code attempting to read or write protected members should throw
-- an access error, preventing accidental misuse of inheritance-only APIs.
function Test:testOutsideCannotAccessProtected()
    class "ProtectedOutsider" {
        protected { protVar = "protected" };
    }

    local instance = ProtectedOutsider.new()

    -- Protected read from outside: should fail
    local success = pcall(function()
        local _ = instance.protVar
    end)
    assertFalse(success)

    -- Protected write from outside: should fail
    success = pcall(function()
        instance.protVar = "hacked"
    end)
    assertFalse(success)
end

-- Tests that external code cannot access private members.
-- Private is the most restrictive modifier - only the declaring class can
-- access it. Both read and write operations should fail with an access error.
-- This prevents any external code from depending on private implementation.
function Test:testOutsideCannotAccessPrivate()
    class "PrivateOutsider" {
        private { privVar = "private" };
    }

    local instance = PrivateOutsider.new()

    -- Private read from outside: should fail
    local success = pcall(function()
        local _ = instance.privVar
    end)
    assertFalse(success)

    -- Private write from outside: should fail
    success = pcall(function()
        instance.privVar = "hacked"
    end)
    assertFalse(success)
end

---------------------------------------------------------------------
-- Unrelated class cannot access protected or private
---------------------------------------------------------------------

-- Tests that unrelated classes cannot access each other's protected/private members.
-- When class Unrelated has a method that receives a Target instance, it should
-- only be able to access Target's public members. Protected requires inheritance,
-- and private requires being the same class - neither applies to unrelated classes.
function Test:testUnrelatedClassCannotAccessProtectedOrPrivate()
    class "Target" {
        public    { pubVar = "public" };
        protected { protVar = "protected" };
        private   { privVar = "private" };
    }

    class "Unrelated" {
        public {
            tryReadPublic = function(self, target)
                return target.pubVar
            end;
            tryReadProtected = function(self, target)
                return target.protVar
            end;
            tryReadPrivate = function(self, target)
                return target.privVar
            end;
        }
    }

    local target = Target.new()
    local unrelated = Unrelated.new()

    -- Public: should work
    assertEquals(unrelated:tryReadPublic(target), "public")

    -- Protected: should fail
    local success = pcall(function()
        unrelated:tryReadProtected(target)
    end)
    assertFalse(success)

    -- Private: should fail
    success = pcall(function()
        unrelated:tryReadPrivate(target)
    end)
    assertFalse(success)
end

---------------------------------------------------------------------
-- Deep hierarchy: grandchild can access grandparent's protected
---------------------------------------------------------------------

-- Tests that protected access works through deep inheritance chains.
-- GrandChild extends Parent extends GrandParent: the grandchild should be
-- able to access grandparent's protected members. Protected visibility
-- is inherited transitively - if you're in the family tree, you have access.
function Test:testDeepHierarchyProtectedAccess()
    class "GrandParent" {
        protected { familySecret = "inherited" };
    }

    class "ParentMid" extends "GrandParent" {
    }

    class "GrandChild" extends "ParentMid" {
        public {
            getFamilySecret = function(self)
                return self.familySecret
            end;
            setFamilySecret = function(self, v)
                self.familySecret = v
            end;
        }
    }

    local instance = GrandChild.new()

    -- Grandchild should access grandparent's protected
    assertEquals(instance:getFamilySecret(), "inherited")
    instance:setFamilySecret("updated")
    assertEquals(instance:getFamilySecret(), "updated")
end

---------------------------------------------------------------------
-- Static members follow same access rules
---------------------------------------------------------------------

-- Tests that static members follow the same access rules as instance members.
-- Static public is accessible everywhere, static protected only to hierarchy,
-- static private only to declaring class. Access via both instance and class
-- references (StaticAccess.staticPub) should respect these rules.
function Test:testStaticMemberAccess()
    class "StaticAccess" {
        static {
            public    { staticPub = "public" };
            protected { staticProt = "protected" };
            private   { staticPriv = "private" };
        };

        public {
            getStaticPublic = function(self)
                return self.staticPub
            end;
            getStaticProtected = function(self)
                return self.staticProt
            end;
            getStaticPrivate = function(self)
                return self.staticPriv
            end;
        }
    }

    local instance = StaticAccess.new()

    -- All should work from within the class
    assertEquals(instance:getStaticPublic(), "public")
    assertEquals(instance:getStaticProtected(), "protected")
    assertEquals(instance:getStaticPrivate(), "private")

    -- Public static from outside: should work
    assertEquals(StaticAccess.staticPub, "public")

    -- Protected static from outside: should fail
    local success = pcall(function()
        local _ = StaticAccess.staticProt
    end)
    assertFalse(success)

    -- Private static from outside: should fail
    success = pcall(function()
        local _ = StaticAccess.staticPriv
    end)
    assertFalse(success)
end

-- Tests that subclasses can access parent's protected statics but not private.
-- Static protected members should be accessible to child class methods just
-- like instance protected members. Static private remains inaccessible to
-- children, maintaining encapsulation even for class-level data.
function Test:testStaticSubclassAccess()
    class "StaticParent" {
        static {
            protected { sharedValue = "shared" };
            private   { secretValue = "secret" };
        };
    }

    class "StaticChild" extends "StaticParent" {
        public {
            getShared = function(self)
                return self.sharedValue
            end;
            getSecret = function(self)
                return self.secretValue
            end;
        }
    }

    local instance = StaticChild.new()

    -- Protected static from child: should work
    assertEquals(instance:getShared(), "shared")

    -- Private static from child: should fail
    local success = pcall(function()
        instance:getSecret()
    end)
    assertFalse(success)
end

---------------------------------------------------------------------
-- Methods also respect access modifiers
---------------------------------------------------------------------

-- Tests that access modifiers apply to methods the same way as to variables.
-- A protected method can be called by the class's own methods but not from
-- outside. A private method is even more restricted. This allows classes
-- to have internal helper methods that are not part of the public API.
function Test:testMethodAccessModifiers()
    class "MethodAccess" {
        public {
            callProtectedMethod = function(self)
                return self:protectedMethod()
            end;
            callPrivateMethod = function(self)
                return self:privateMethod()
            end;
        };
        protected {
            protectedMethod = function(self)
                return "protected method"
            end;
        };
        private {
            privateMethod = function(self)
                return "private method"
            end;
        };
    }

    local instance = MethodAccess.new()

    -- Calling from within class should work
    assertEquals(instance:callProtectedMethod(), "protected method")
    assertEquals(instance:callPrivateMethod(), "private method")

    -- Calling protected from outside: should fail
    local success = pcall(function()
        instance:protectedMethod()
    end)
    assertFalse(success)

    -- Calling private from outside: should fail
    success = pcall(function()
        instance:privateMethod()
    end)
    assertFalse(success)
end

-- Tests that subclasses can call parent's protected methods.
-- Protected methods are meant to be used by the inheritance hierarchy.
-- A child's public method can delegate to a parent's protected helper,
-- allowing code reuse while keeping the helper hidden from external callers.
function Test:testSubclassCanCallProtectedMethod()
    class "MethodParent" {
        protected {
            helperMethod = function(self)
                return "helper"
            end;
        };
    }

    class "MethodChild" extends "MethodParent" {
        public {
            useHelper = function(self)
                return self:helperMethod()
            end;
        }
    }

    local instance = MethodChild.new()
    assertEquals(instance:useHelper(), "helper")
end

---------------------------------------------------------------------
-- Callbacks with bind() can access private/protected members
---------------------------------------------------------------------

-- Tests that bind() captures the current scope for use in callbacks.
-- When a method passes a callback to another class, that callback loses
-- the original scope. Using self:bind(fn) captures the scope so the callback
-- can still access private members. Essential for event handlers and async code.
function Test:testCallbackWithBindCanAccessPrivate()
    class "CallbackAnimal" {
        private { heartRate = 60 };
        public {
            onHeartbeat = function(self, callback)
                callback()
            end
        }
    }

    class "CallbackPerson" extends "CallbackAnimal" {
        private { name = "Unknown" };
        public {
            setName = function(self, n)
                self.name = n
            end;
            
            setupCallback = function(self)
                -- Use bind() to preserve scope for the callback
                self:onHeartbeat(self:bind(function()
                    assertEquals(self.name, "Bob")
                end))
            end
        }
    }

    local person = CallbackPerson.new()
    person:setName("Bob")
    person:setupCallback()  -- Should not error
end

-- Tests that bind() preserves scope for accessing protected members in callbacks.
-- Similar to private access, protected members require the correct scope.
-- A child class using self:bind(fn) ensures the callback can access
-- protected members inherited from the parent class.
function Test:testCallbackWithBindCanAccessProtected()
    class "CallbackBase" {
        protected { sharedData = "shared" };
        public {
            runCallback = function(self, callback)
                callback()
            end
        }
    }

    class "CallbackChild" extends "CallbackBase" {
        public {
            setupCallback = function(self)
                self:runCallback(self:bind(function()
                    assertEquals(self.sharedData, "shared")
                end))
            end
        }
    }

    local child = CallbackChild.new()
    child:setupCallback()  -- Should not error
end

-- Tests that nested callbacks with bind() maintain correct scope at each level.
-- When a bound callback contains another bound callback, each level should
-- correctly preserve and restore scope. This ensures deeply nested async
-- patterns don't corrupt scope tracking.
function Test:testNestedCallbacksWithBind()
    class "Level1Bind" {
        private { secret1 = "L1" };
        public {
            wrap = function(self, callback)
                callback()
            end
        }
    }

    class "Level2Bind" extends "Level1Bind" {
        private { secret2 = "L2" };
        public {
            testNested = function(self)
                self:wrap(self:bind(function()
                    self:wrap(self:bind(function()
                        assertEquals(self.secret2, "L2")
                    end))
                end))
            end
        }
    }

    local instance = Level2Bind.new()
    instance:testNested()  -- Should not error
end

-- Tests that callbacks without bind() lose their original scope.
-- When a callback is passed to another class and invoked there, the scope
-- becomes that other class. Without bind(), accessing private members of
-- the original class should fail. This demonstrates why bind() is necessary.
function Test:testCallbackWithoutBindFails()
    -- Separate class to run callbacks - simulates event emitter pattern
    class "CallbackRunner" {
        public {
            run = function(self, callback)
                callback()
            end
        }
    }

    class "NoBindClass" {
        private { secret = "hidden" };
        public {
            tryWithoutBind = function(self, runner)
                -- When runner:run() calls the callback, scope will be CallbackRunner, not NoBindClass
                runner:run(function()
                    local _ = self.secret  -- This should fail - wrong scope
                end)
            end
        }
    }

    local runner = CallbackRunner.new()
    local instance = NoBindClass.new()
    local success = pcall(function()
        instance:tryWithoutBind(runner)
    end)
    assertFalse(success)  -- Should fail without bind
end

---------------------------------------------------------------------
-- Coroutine safety: scope is tracked per-thread
---------------------------------------------------------------------

-- Tests that scope tracking works correctly with coroutines.
-- When a method yields and resumes, the scope should be correctly maintained.
-- Scope is tracked per-thread (coroutine), so yielding doesn't corrupt scope.
-- This enables async patterns using coroutines with proper access control.
function Test:testCoroutineScopeSafety()
    class "CoroClass" {
        private { secret = "coroutine-safe" };
        public {
            getSecret = function(self)
                return self.secret
            end;
            
            getSecretWithYield = function(self)
                coroutine.yield()
                return self.secret
            end
        }
    }

    local instance = CoroClass.new()
    
    -- Test that scope works across yield
    local co = coroutine.create(function()
        return instance:getSecretWithYield()
    end)
    
    -- Start coroutine (will yield inside method)
    coroutine.resume(co)
    
    -- While suspended, call another method (should have separate scope)
    assertEquals(instance:getSecret(), "coroutine-safe")
    
    -- Resume and get result
    local success, result = coroutine.resume(co)
    assertTrue(success)
    assertEquals(result, "coroutine-safe")
end

-- Tests that multiple coroutines have independent scope tracking.
-- Two coroutines running methods on the same instance should each maintain
-- their own scope. Resuming them in different orders should not cause
-- one coroutine's scope to leak into another.
function Test:testMultipleCoroutinesDontInterfere()
    class "MultiCoroClass" {
        private { id = 0 };
        public {
            setId = function(self, newId)
                self.id = newId
            end;
            
            getId = function(self)
                return self.id
            end;
            
            yieldAndGetId = function(self)
                coroutine.yield()
                return self.id
            end
        }
    }

    local instance = MultiCoroClass.new()
    instance:setId(42)
    
    local results = {}
    
    local co1 = coroutine.create(function()
        return instance:yieldAndGetId()
    end)
    
    local co2 = coroutine.create(function()
        return instance:yieldAndGetId()
    end)
    
    -- Start both coroutines
    coroutine.resume(co1)
    coroutine.resume(co2)
    
    -- Resume in different order
    local _, r2 = coroutine.resume(co2)
    local _, r1 = coroutine.resume(co1)
    
    assertEquals(r1, 42)
    assertEquals(r2, 42)
end

---------------------------------------------------------------------
-- Cross-instance attacks
---------------------------------------------------------------------

-- Tests that one class cannot access another class's private members.
-- Even if an Attacker class has a method that receives a Victim instance,
-- it should not be able to read the victim's private members. Access control
-- is based on the calling class's identity, not just having a reference.
function Test:testCrossInstanceAttack()
    class "Victim" {
        private { secret = 42 }
    }

    class "Attacker" {
        public {
            steal = function(self, victim)
                return victim.secret
            end
        }
    }

    local victim = Victim.new()
    local attacker = Attacker.new()

    local success = pcall(function()
        return attacker:steal(victim)
    end)
    assertFalse(success)
end

-- Tests that one instance of a class CAN access another instance's private members.
-- Access control is class-based, not instance-based. This matches Java, C++, C#, etc.
-- A method in class Wallet can access private members of ANY Wallet instance.
function Test:testCrossInstanceSameClass()
    class "Wallet" {
        private { money = 0 };
        public {
            __construct = function(self, amount)
                self.money = amount
            end;
            getMoney = function(self)
                return self.money
            end;
            transferFrom = function(self, other, amount)
                local taken = math.min(other.money, amount)  -- works: same class
                other.money = other.money - taken
                self.money = self.money + taken
            end
        }
    }

    local wallet1 = Wallet.new(100)
    local wallet2 = Wallet.new(50)

    -- Can access own private
    assertEquals(wallet1:getMoney(), 100)
    assertEquals(wallet2:getMoney(), 50)

    -- Can access other instance's private (same class)
    wallet1:transferFrom(wallet2, 30)
    assertEquals(wallet1:getMoney(), 130)
    assertEquals(wallet2:getMoney(), 20)
end

---------------------------------------------------------------------
-- Nested method calls
---------------------------------------------------------------------

-- Tests that nested method calls maintain correct scope.
-- When outer() calls inner() which accesses a private member, the scope
-- should still be the class itself. Method call chains should not corrupt
-- scope tracking - each call preserves and restores scope correctly.
function Test:testNestedMethodCalls()
    class "Nested" {
        private { secret = 99 };
        public {
            outer = function(self)
                return self:inner()
            end;
            inner = function(self)
                return self.secret
            end
        }
    }

    local instance = Nested.new()
    assertEquals(instance:outer(), 99)
end

---------------------------------------------------------------------
-- Private method access
---------------------------------------------------------------------

-- Tests that private methods are callable internally but not externally.
-- A public method can call a private helper method (internal access works).
-- External code trying to call the private method directly should fail.
-- This allows implementation details to be hidden behind public APIs.
function Test:testPrivateMethodAccess()
    class "PrivateMethod" {
        private {
            secretMethod = function(self)
                return "secret"
            end
        };
        public {
            callSecret = function(self)
                return self:secretMethod()
            end
        }
    }

    local instance = PrivateMethod.new()

    -- Calling private method from public method (should work)
    assertEquals(instance:callSecret(), "secret")

    -- Calling private method from outside (should fail)
    local success = pcall(function()
        return instance:secretMethod()
    end)
    assertFalse(success)
end
