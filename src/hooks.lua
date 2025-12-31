local hook = {}
hook.hooks = {}

simploo.hook = hook

function hook:add(hookName, callbackFn)
    table.insert(self.hooks, {hookName, callbackFn})
end

function hook:remove(hookName, callbackFn)
    for i = #self.hooks, 1, -1 do
        local h = self.hooks[i]
        if h[1] == hookName and (not callbackFn or h[2] == callbackFn) then
            table.remove(self.hooks, i)
            if callbackFn then
                return -- only remove first match when callback specified
            end
        end
    end
end

function hook:fire(hookName, ...)
    -- Fast path: no hooks registered
    if #self.hooks == 0 then
        return ...
    end

    local args = {...}
    for _, v in ipairs(self.hooks) do
        if v[1] == hookName then
            local ret = {v[2]((unpack or table.unpack)(args))}

            -- Overwrite the original value, but do pass it on to the next hook if any
            if ret[1] ~= nil then
                args = ret
            end
        end
    end

    return (unpack or table.unpack)(args)
end