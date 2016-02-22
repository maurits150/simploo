local hook = {}
hook.hooks = {}

simploo.hook = hook

function hook:add(hookName, callbackFn)
    table.insert(self.hooks, {hookName, callbackFn})
end

function hook:fire(hookName, ...)
    for _, v in pairs(self.hooks) do
        if v[1] == hookName then
            local ret = {v[2](...)}

            -- Return data if there was a return value
            if ret[0] then
                return unpack(ret)
            end
        end
    end
end