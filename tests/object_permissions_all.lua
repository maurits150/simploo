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


