local config = {}

--
-- Production Mode
--
-- Description: This setting disables non essential parts simploo in order to improve performance on production environments.
-- Be aware that certain usage and safety checks are disabled as well so keep this disable when developing and testing.
-- Default: false
--

config["production"] = false

--
-- Expose Syntax
--
-- Description: Expose all syntax related functions as globals instead of having to call simploo.syntax.<fn> explicitly.
-- You can also manually enable or disable the simploo syntax globals in sections of your code by calling simploo.syntax.init() and simploo.syntax.destroy().
-- Default: true
--

config["exposeSyntax"] = true

--
-- Class Hotswapping
--
-- Description: When defining a class a 2nd time, automatically update all the earlier instances of a class with newly added members. Will slightly increase class instantiation time and memory consumption.
-- Default: false
--
config["classHotswap"] = false

--
-- Base instance table
--
-- Description: the global table in which simploo writes away all classes including namespaces
-- Default: _G
--

config["baseInstanceTable"] = _G

--
-- Custom modifiers
--
-- Description: add custom modifiers so you can make your own methods that manipulate members
-- Default: {}
--

config["customModifiers"] = {}

--
-- Coroutine-safe scope tracking
--
-- Description: When true, private member access tracking is coroutine-safe, allowing methods
-- to yield and resume correctly. When false (default), uses a faster single-threaded approach.
-- Only enable if you call class methods across coroutine yield boundaries.
-- Default: false
--

config["coroutineSafeScope"] = false

--
-- Apply config variables that aren't defined already.
--
for k, v in pairs(config) do
    if not simploo.config[k] then
        simploo.config[k] = v
    end
end
