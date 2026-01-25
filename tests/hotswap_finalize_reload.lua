--[[
    Tests that __finalize can access private members after a full simploo reload.
    
    This simulates what happens when:
    1. A class with private members and __finalize is defined
    2. An instance is created
    3. simploo is completely reset and reloaded (like in a game mode reload)
    4. The class is redefined
    5. The old instance gets garbage collected
    
    The bug: After reload, the scope wrapper captures the NEW baseInstance,
    but access checks may fail if there's a mismatch between scope and owner.
]]

-- Tests that __finalize can access private members after full simploo reload
function Test:testFinalizePrivateAfterFullReload()
    -- Skip in production mode - access checks are disabled anyway
    if simploo.config["production"] then
        return
    end

    -- Enable hotswap
    simploo.hotswap:init()

    local capturedSecret = nil
    local finalizeCalled = false

    class "ReloadFinalizeTest" {
        private { secret = "original_secret" };
        
        __finalize = function(self)
            finalizeCalled = true
            capturedSecret = self.secret
        end;
    }

    local instance = ReloadFinalizeTest.new()

    -- Simulate full simploo reload (like game mode reload)
    -- This is what happens: config is preserved, simploo table is reset
    local preservedConfig = simploo.config
    local preservedHotswapInstances = simploo_hotswap_instances
    
    -- Reset simploo completely
    simploo = {config = preservedConfig}
    
    -- Reload all simploo files
    for name in io.open("src/sourcefiles.txt"):read("*a"):gmatch("[^\r\n]+") do
        dofile("src/" .. name)
    end
    
    -- Restore hotswap instances (this survives reload in real scenario)
    simploo_hotswap_instances = preservedHotswapInstances
    
    -- Re-init hotswap (hooks were cleared during reload)
    simploo.hotswap:init()

    -- Redefine the class (triggers hotswap)
    class "ReloadFinalizeTest" {
        private { secret = "new_default" };
        
        __finalize = function(self)
            finalizeCalled = true
            capturedSecret = self.secret
        end;
    }
    
    -- Let the old instance be garbage collected
    instance = nil
    collectgarbage("collect")
    collectgarbage("collect")

    -- The __finalize should have been able to access the private member
    assertTrue(finalizeCalled, "finalize was not called")
    assertEquals(capturedSecret, "original_secret")
end

-- Tests private method access in __finalize after reload
function Test:testFinalizePrivateMethodAfterFullReload()
    -- Skip in production mode - access checks are disabled anyway
    if simploo.config["production"] then
        return
    end

    -- Enable hotswap
    simploo.hotswap:init()

    local cleanupCalled = false

    class "ReloadFinalizeMethodTest" {
        private {
            cleanup = function(self)
                cleanupCalled = true
            end;
        };
        
        __finalize = function(self)
            self:cleanup()
        end;
    }

    local instance = ReloadFinalizeMethodTest.new()

    -- Simulate full simploo reload
    local preservedConfig = simploo.config
    local preservedHotswapInstances = simploo_hotswap_instances
    
    simploo = {config = preservedConfig}
    
    for name in io.open("src/sourcefiles.txt"):read("*a"):gmatch("[^\r\n]+") do
        dofile("src/" .. name)
    end
    
    simploo_hotswap_instances = preservedHotswapInstances
    simploo.hotswap:init()

    -- Redefine the class
    class "ReloadFinalizeMethodTest" {
        private {
            cleanup = function(self)
                cleanupCalled = true
            end;
        };
        
        __finalize = function(self)
            self:cleanup()
        end;
    }

    -- Trigger GC
    instance = nil
    collectgarbage("collect")
    collectgarbage("collect")

    assertTrue(cleanupCalled, "private cleanup method was not called")
end
