
function pt(t, indent, done) -- print table
	if not t then
		print("niltable")
		return
	end

	done = done or {}
	indent = indent or 0
	for k, v in pairs(t or {}) do
		io.write(string.rep(" ", indent))
		
		if type(v) == "table" and not done[v] and k ~= "owner" then
			done[v] = true
			
			io.write(tostring(k) .. ":" .. "\n")
			
			pt(v, indent + 4, done)
		else
			io.write(tostring(k) .. " = ")
			io.write(tostring(v) .. "\n")
		end
	end
end

local callCounter, callTimes, callClock = {}, {}, {}
function profile_start()
	debug.sethook(function(event)
		local debugInfo = debug.getinfo(2, "Sln")
		
		if debugInfo.what ~= "Lua" then
			return
		end
		
		local funcName = debugInfo.name or (debugInfo.source .. ":" .. debugInfo.linedefined)
		
		if event == "call" then
			callClock[funcName] = os.clock()
		else
			if callClock[strFuncName] then
				local callTime = os.clock() - callClock[funcName]
				callTimes[funcName] = (callTimes[funcName] or 0) + callTime
				callCounter[funcName] = (callCounter[funcName] or 0) + 1
			end
		end
	end, "cr")
end

function profile_end()
	-- The code to debug ends here reset the hook
	debug.sethook()

	-- Print the results
	for funcName, callTime in pairs(callTimes) do
		print(("function %s took %.3f seconds after %d calls"):format(funcName, callTime, callCounter[funcName]))
	end
end
