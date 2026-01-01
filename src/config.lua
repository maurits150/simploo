--
-- Configuration options should be set before loading simploo:
--
-- simploo = {config = {}}
-- simploo.config["production"] = true
-- dofile("simploo.lua")
--

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
-- Base syntax table
--
-- Description: the global table in which simploo exposes syntax functions (class, namespace, extends, etc.)
-- Default: _G
--

config["baseSyntaxTable"] = _G

--
-- Custom modifiers
--
-- Description: add custom modifiers so you can make your own methods that manipulate members
-- Default: {}
--

config["customModifiers"] = {}

--
-- Strict Interfaces
--
-- Description: When enabled, interface validation also checks argument count, names, and varargs. Requires Lua 5.2+.
-- Default: false
--

config["strictInterfaces"] = false

--
-- Apply config variables that aren't defined already.
--
for k, v in pairs(config) do
    if not simploo.config[k] then
        simploo.config[k] = v
    end
end
