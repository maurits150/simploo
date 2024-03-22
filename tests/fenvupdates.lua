--
-- Test if variables inside the fenv update correctly.
-- Especially when a class is redefined, ensure the variable in the fenv is updated.
--
function Test:testUsingsFenvCleanup()
    -- Create class A
    class "frtns.ClassNormal" {};

    -- Create class B
    class "frtnswildcard.ClassWildcard" {};

    -- Create class C, that uses Class A and B
    using "frtns.ClassNormal" as "ClassNormal"
    using "frtnswildcard.*"

    class "frtns.ClassC" {
        dotest = function(self)
            -- Test for class normal
            if ClassNormal ~= _G["frtns"]["ClassNormal"] then
                print(ClassNormal, _G["frtns"]["ClassNormal"])
            end

            -- Test for class wildcard
            if ClassWildcard ~= _G["frtnswildcard"]["ClassWildcard"] then
                print(ClassWildcard, _G["frtnswildcard"]["ClassNClassWildcardormal"])
            end
            assertTrue(ClassNormal == _G["frtns"]["ClassNormal"])
            assertTrue(ClassWildcard == _G["frtnswildcard"]["ClassWildcard"])
        end;
    }

    -- Recreate class A and B
    class "frtns.ClassNormal" {};
    class "frtnswildcard.ClassWildcard" {};

    -- Run a test that checks if ClassNormal inside the function now reflects the new ClassNormal.
    frtns.ClassC.new():dotest()
end