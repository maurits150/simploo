simploo.config = {}

--
-- Production Mode
--
-- Description: This setting disables non essential parts simploo in order to improve performance on production environments.
-- Be aware that certain usage and safety checks are disabled as well so keep this disable when developing and testing.
-- Default: false
--

simploo.config['production'] = false

--
-- Expose Syntax
--
-- Description: Expose all syntax related functions as globals instead of having to call simploo.syntax.<fn> explicitly.
-- Default: true
--

simploo.config['exposeSyntax'] = true