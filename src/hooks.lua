local hook = {}
hook.hooks = {}

simploo.hook = hook

function hook:add(hookName, callbackFn)
    table.insert(self.hooks, {hookName, callbackFn})
end

function hook:fire(hookName, ...)
    local args = {...}
    for _, v in pairs(self.hooks) do
        if v[1] == hookName then
            local ret = {v[2](unpack(args))}

            -- Overwrite the original value, but do pass it on to the next hook if any
            if ret[0] then
                args = ret
            end
        end
    end

    return unpack(args)
end