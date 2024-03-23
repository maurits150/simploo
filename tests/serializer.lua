function Test:testSerializer()
    class "P" {
        parent_ok = "unset";

        transient {
            parent_bad = "unset";
        };
    }

    class "C" extends "P" {
        child_ok = "unset";

        transient {
            child_bad = "unset";
        };
    }

    local instance = C.new()
    instance.parent_ok = "ok"
    instance.parent_bad = "no serialize"
    instance.child_ok = "ok"
    instance.child_bad = "no serialize"

    local data = simploo.serialize(instance)

    assertEquals(data["P"]["parent_ok"], "ok")
    assertIsNil(data["P"]["parent_bad"])
    assertEquals(data["child_ok"], "ok")
    assertIsNil(data["child_bad"])

    local newinstance = simploo.deserialize(data)
    assertEquals(newinstance["parent_ok"], "ok")
    assertEquals(newinstance["parent_bad"], "unset")
    assertEquals(newinstance["child_ok"], "ok")
    assertEquals(newinstance["child_bad"], "unset")
end
