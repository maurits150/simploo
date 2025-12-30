--[[
    Tests the parser's output format for class definitions.
    
    Verifies that both block syntax and builder syntax produce
    the same internal parser output structure.
]]

simploo.instancer = nil -- Disable the instancer for this test

-- Verifies block syntax and builder syntax produce identical parser output
function Test:testParserOutput()
    function assertParsers(output)
        assertEquals(output.name, "Child")
        assertStrContains(table.concat(output.parents, ","), "Parent1")
        assertStrContains(table.concat(output.parents, ","), "Parent2")

        assertEquals(output.members.varOne.modifiers["public"], true)

        assertEquals(output.members.varTwo.modifiers["public"], true)
        assertEquals(output.members.varTwo.modifiers["static"], true)

        assertEquals(output.members.varThree.modifiers["private"], true)

        assertEquals(output.members.fnTest.modifiers["public"], true)
        assertEquals(type(output.members.fnTest.value), "function")
        assertEquals(output.members.fnTest.value(), "data")
    end

    -- Parse two test classes
    local parser = class "Child" extends "Parent1, Parent2" {
        public {
            varOne = 3.2;

            static {
                varTwo = 1337;
            };

            fnTest = function()
                return "data"
            end
        };

        private {
            varThree = 11.2;
        };
    }
    parser:setOnFinished(assertParsers) -- Add finished hook (auto called if already finished)

    local parser2 = class("Child", {extends = "Parent1, Parent2"})
    parser2.public.varOne = 3.2
    parser2.public.fnTest = function()
        return "data"
    end
    parser2.public.static.varTwo = 1337
    parser2.private.varThree = 11.2
    parser2:register()
    parser2:setOnFinished(assertParsers) -- Add finished hook (auto called if already finished)
end