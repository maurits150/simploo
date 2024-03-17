simploo.instancer = nil -- Disable the instancer for this test

function Test:testParserOutput()
    function assertParsers(parser, output)
        assertEquals(output.name, "Child")
        assertStrContains(table.concat(output.parentNames, ","), "Parent1")
        assertStrContains(table.concat(output.parentNames, ","), "Parent2")

        assertEquals(output.variables.varOne.modifiers["public"], true)

        assertEquals(output.variables.varTwo.modifiers["public"], true)
        assertEquals(output.variables.varTwo.modifiers["static"], true)

        assertEquals(output.variables.varThree.modifiers["private"], true)

        assertEquals(output.functions.fnTest.modifiers["public"], true)
        assertEquals(type(output.functions.fnTest.value), "function")
        assertEquals(output.functions.fnTest.value(), "data")
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