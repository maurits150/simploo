simploo.config = {}

--
-- Production Mode
--
-- Description: This setting disables non essential parts simploo in order to improve performance on production environments.
-- Be aware that certain usage and safety checks are disabled as well so keep this disable when developing and testing.
-- Default: false
--

simploo.config["production"] = false

--
-- Expose Syntax
--
-- Description: Expose all syntax related functions as globals instead of having to call simploo.syntax.<fn> explicitly.
-- You can also manually enable or disable the simploo syntax globals in sections of your code by calling simploo.syntax.init() and simploo.syntax.destroy().
-- Default: true
--

simploo.config["exposeSyntax"] = true

--
-- Class Hotswapping
--
-- Description: When defining a class a 2nd time, automatically update all the earlier instances of a class with newly added members. Will slightly increase class instantiation time and memory consumption.
-- Default: false
--
simploo.config["classHotswap"] = true

--
-- Global Namespace Table
--
-- Description: the global table in which simploo writes away all classes
-- Default: _G
--

-- TODO
-- simploo.config["globalNamespaceTable"] = _G