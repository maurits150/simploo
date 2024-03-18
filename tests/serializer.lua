function Test:testSerializer()
    class "P" {
        serializable_var_parent = "unset";
        nonserialized_fn = function() end;
        transient {
            unserializable_var_parent = "unset";
        };
    }

    class "C" extends "P" {
        serializable_var = "unset";
        nonserialized_fn = function() end;
        transient {
            unserializable_var = "unset";
        };
    }

    local instance = C.new()
    instance.serializable_var_parent = "serializable var";
    instance.unserializable_var_parent = "unserializable var"

    instance.serializable_var = "serializable var";
    instance.unserializable_var = "unserializable var"

    local data = simploo.serialize(instance)
    assertEquals(data["P"]["serializable_var_parent"], "serializable var")
    assertIsNil(data["P"]["unserializable_var_parent"])
    assertEquals(data["serializable_var"], "serializable var")
    assertIsNil(data["unserializable_var"])

    local newinstance = simploo.deserialize(data)
    assertEquals(newinstance["serializable_var_parent"], "serializable var")
    assertEquals(newinstance["unserializable_var_parent"], "unset")
    assertEquals(newinstance["serializable_var"], "serializable var")
    assertEquals(newinstance["unserializable_var"], "unset")
end
