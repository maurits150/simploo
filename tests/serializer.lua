function Test:testSerializer()
    class "P" {
        public {
            parent_ok = "unset";
        };

        transient {
            parent_bad = "unset";
        };
    }

    class "C" extends "P" {
        public {
            child_ok = "unset";
        };

        transient {
            child_bad = "unset";
        };
    }

    local instance = C.new()
    instance.parent_ok = "ok"
    instance.parent_bad = "no serialize"
    instance.child_ok = "ok"
    instance.child_bad = "no serialize"

    local data = simploo.serialize(instance, function(key, value, modifiers, instance)
        if modifiers.public then
            return value .. "_SERIALIZE_APPEND"
        end
    end)

    assertEquals(data["P"]["parent_ok"], "ok_SERIALIZE_APPEND")
    assertIsNil(data["P"]["parent_bad"])
    assertEquals(data["child_ok"], "ok_SERIALIZE_APPEND")
    assertIsNil(data["child_bad"])

    local newinstance = simploo.deserialize(data, function(key, value, modifiers, instance)
        if modifiers.public then
            return string.sub(value, 1, #value - #"_SERIALIZE_APPEND")
        end
    end)
    assertEquals(newinstance["parent_ok"], "ok")
    assertEquals(newinstance["parent_bad"], "unset")
    assertEquals(newinstance["child_ok"], "ok")
    assertEquals(newinstance["child_bad"], "unset")
end
