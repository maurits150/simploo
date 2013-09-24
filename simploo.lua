--[[
	SIMPLOO - The simple lua object-oriented programming library!

	The MIT License (MIT)
	Copyright (c) 2013 maurits.tv
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
]]

SIMPLOO = SIMPLOO or {}
SIMPLOO.CLASSES = {}
SIMPLOO.CLASS_MT = {}
SIMPLOO.CLASS_FUNCTIONS = {}

null = "NullVariable"

local _public_ = "PublicAccess"
local _protected_ = "ProtectedAccess"
local _private_ = "PrivateAccess"

local _static_ = "StaticMemberType"
local _final_ = "FinalMember/FinalClass"
local _abstract_ = "AbstractMember"
local _meta_ = "MetaMethodMember"

local function _duplicateTable(tbl, _lookup)
	local copy = {}
	
	for i, v in pairs(tbl) do
		if not _notable and type(v) == "table" then
			_lookup = _lookup or {}
			_lookup[tbl] = copy

			if _lookup[v] then
				copy[i] = _lookup[v] -- we already copied this table. reuse the copy.
			else
				copy[i] = _duplicateTable(v,_lookup) -- not yet copied. copy it.
			end
		else
			copy[i] = rawget(tbl, i)
		end
	end
	
	if debug then -- bypasses __metatable
		local mt = debug.getmetatable(tbl)
		if mt then
			debug.setmetatable(copy, mt)
		end
	else -- oh well...
		local mt = getmetatable(tbl)
		if mt then
			setmetatable(copy, mt)
		end
	end

	return copy
end

local function _duplicateClass(tbl, _lookup)
	local copy = {}
	
	for i, v in pairs(tbl) do
		if i == "___members" or i == "___parents" then
			_lookup = _lookup or {}
			_lookup[tbl] = copy

			if _lookup[v] then
				copy[i] = _lookup[v] -- we already copied this table. reuse the copy.
			else
				if i == "___members" then -- deepcopy members
					copy[i] = {}
					
					for memberName, memberData in pairs(v) do
						copy[i][memberName] = {}
						
						for memberKey, memberValue in pairs(memberData) do
							if memberKey == "value" and type(memberValue) == "table" then
								if memberData.static then -- dont bother copying over static members
									copy[i][memberName][memberKey] = false
								else
									copy[i][memberName][memberKey] = _duplicateTable(memberValue, _lookup)
								end
							else
								copy[i][memberName][memberKey] = rawget(memberData, memberKey)
							end
						end
					end
					
				elseif i == "___parents" then
					copy[i] = _duplicateClass(v, _lookup) -- not yet copied. copy it.
				end
			end
		elseif i == "___registry" or i == "___cache" then
			copy[i] = {}
		else
			copy[i] = rawget(tbl, i)
		end
	end

	if debug then -- bypasses __metatable
		local mt = debug.getmetatable(tbl)
		if mt then
			debug.setmetatable(copy, mt)
		end
	else -- oh well...
		local mt = getmetatable(tbl)
		if mt then
			setmetatable(copy, mt)
		end
	end

	return copy
end

local function _setGlobal(name, value)
	local classTableChain = {}
	for k, v in string.gmatch(name, "%a+") do
		table.insert(classTableChain, k)
	end
	
	_G[name] = value
	
	if #classTableChain > 1 then
		local tbl
		local lastTable
		local startTable
		for i=1, #classTableChain do
			local classTable = classTableChain[i]
			
			if i == 1 then
				if not _G[classTable] then
					_G[classTable] = {}
					getmetatable(_G[classTable], {
						__classtable = true
					})
				end
				
				lastTable = _G[classTable]
			elseif i == #classTableChain then
				--print(name, classTable, value)
				lastTable[classTable] = value
			else
				if not lastTable[classTable] then
					lastTable[classTable] = {}
				end
			
				lastTable = lastTable[classTable]
			end
		end
	end
end

local function _getFunctionArgs(func)
	if type(func) ~= "function" then
		error("calling ____member_getargs on non function")
	end

	local strargs = ""
	
	if debug then
		local dbg = debug.getinfo(func)
		if dbg and dbg.nparams then
			for i = 1, dbg.nparams do
				strargs = strargs .. debug.getlocal(func, i) .. (i < dbg.nparams and ", " or "")
			end
		else
			return {"no dbg or dbg.nparams for " .. func}
		end
	else
		strargs = "unknown.. no debug library!"
	end
	
	return strargs
end

function isclass(v)
	return (getmetatable(v) and getmetatable(v).__class and true) or false
end

local function _realPath(p)
	return 
		p:gsub("[^/]+/%.%./","/")
		 :gsub("/[^/]+/%.%./","/")
		 :gsub("/%./", "/")
		 :gsub("/%./","/")
		 :gsub("//","/")
end

local function _doValue(key, value, scope, child)
	if type(value) == "function" then
		local function f(a, b, c, d, e, f, g, h, i, j)
			local k, l, m, n, o, p, q, r, s, t
			
			local prev_self = self
			local prev_scope = __scope
			
			self = child
			__scope = scope
			
			k, l, m, n, o, p, q, r, s, t =
				value(a, b, c, d, e, f, g, h, i, j)
			
			self = prev_self
			__scope = prev_scope
			
			
			if t then
				return k, l, m, n, o, p, q, r, s, t
			elseif s then
				return k, l, m, n, o, p, q, r, s
			elseif r then
				return k, l, m, n, o, p, q, r
			elseif q then
				return k, l, m, n, o, p, q
			elseif p then
				return k, l, m, n, o, p
			elseif o then
				return k, l, m, n, o
			elseif n then
				return k, l, m, n
			elseif m then
				return k, l, m
			elseif l then
				return k, l
			elseif k then
				return k
			end 
		end
		
		return f
	else
		return value
	end
end

do
	-- Remove any remaining/old classes from the global table.
	for k, v in pairs(SIMPLOO.CLASSES or {}) do
		_setGlobal(k, nil)
	end
end

SIMPLOO.CLASS_MT = {
	__class = true,
	__tostring = function(self)
		
		-- We disable the metamethod on ourselfs, so we can tostring ourselves without getting into an infinite loop.
		-- And no, rawget doesn't work because we want to call a metamethod on ourself: __tostring
		local __tostring = getmetatable(self).__tostring
		getmetatable(self).__tostring = nil

		-- Grap the definition string.
		local origstr = string.format("LuaClass: %s <%s> {%s}", self:get_name(), self.___instance and "instance" or "class", tostring(self):sub(8))
		
		-- see if we have a custom tostring, this is below the actual tostring because we wanna be able to use the original tostring inside the error
		if self:____member_isvalid("___meta__tostring") then
			local custstr = self:___meta__tostring(self, origstr)
			if custstr then
				return custstr
			end
		end
		
		-- Enable our metamethod again.
		getmetatable(self).__tostring = __tostring
		
		-- Return string.
		return origstr
	end,

	__call = function(self, ...)
		-- When we call class instances, we actually call their constructors
		if self.___instance then
			return self:____construct(...)
		else
			error("Please use " .. self:get_name() .. ".new() to instantiate this class.")
		end
	end;
	
	__gc = function(self)
		-- Lua doesn't really do anything with errors happening inside __gc (doesn't even print them in my test)
		-- So we catch them by hand and print them!
		local s, e = pcall(function()
			self:___finalize()
		end)

		if not s then
			print(string.format("ERROR: class %s: error __gc function: %s", self:get_name(), e))
		end
	end;
	
	__concat = function(self, other)
		-- We disable the metamethod on ourselfs, so we can tostring ourselves without getting into an infinite loop.
		-- And no, rawget doesn't work because we want to call a metamethod on ourself: __tostring
		local __tostring = getmetatable(self).__tostring
		getmetatable(self).__tostring = nil
		
		if self:____member_isvalid("___meta__concat") then
			local str = self:___meta__concat(self, other)
			if not str then
				error(string.format("class %s, metamethod %s: must return string", self, "__concat"))
			end
			
			return str
		end
		
		local str = tostring(self) .. other
		
		-- Enable our metamethod again.
		getmetatable(self).__tostring = __tostring
		
		return str
	end;

	__index = function(invokedOn, mKey)
		if invokedOn.___parents[mKey] then
			return invokedOn.___parents[mKey]
		end
		
		local locationOf = invokedOn.___registry[mKey]
		
		if isclass(locationOf) then
			local access = locationOf.___members[mKey].access
			local static = locationOf.___members[mKey].static
			local value = locationOf.___members[mKey].value
			local isfunc = locationOf.___members[mKey].isfunc
			
			-- ...
			if not static and not invokedOn.___instance then
				print("---------------------" ..
					"\n\tStatic: " .. tostring(static) .. "\n\tmKey = " .. mKey .. "\n\tAccess = " .. access .. "\n\tinvokedOn = " .. invokedOn ..
					"\n\tlocationOf = " .. locationOf .. "\n\t__scope = " .. tostring(__scope))

				error(string.format("access to %s member %s: you cannot access this member variable unless it's static", invokedOn, mKey))
			end
			
			-- Redirect statics
			if invokedOn.___instance and static then -- Redirect to global class.
				if not invokedOn:get_class() then
					error(string.format("cannot find class of instance %s", invokedOn))
				end
				
				return invokedOn:get_class()[mKey]
			end
			
			if access == _public_ then
				-- continue...
			elseif access == _protected_ then
				if (
						not __scope
						or
						not __scope:instance_of(locationOf.___name)
					) then
					
					print("---------------------" ..
					"\n\tStatic: " .. tostring(static) .. "\n\tmKey = " .. mKey .. "\n\tAccess = " .. access .. "\n\tinvokedOn = " .. invokedOn ..
					"\n\tlocationOf = " .. locationOf .. "\n\t__scope = " .. tostring(__scope))
				
					error(string.format("class %s: invalid read access attempt to protected member '%s': accessed by %s",
						locationOf, mKey, __scope or "- code outside class boundaries -"))
				end
			elseif access == _private_ then
				if (
						not __scope
						or
						locationOf.___name ~= __scope.___name
					) then
					
					print("---------------------" ..
					"\n\tStatic: " .. tostring(static) .. "\n\tmKey = " .. mKey .. "\n\tAccess = " .. access .. "\n\tinvokedOn = " .. invokedOn ..
					"\n\tlocationOf = " .. locationOf .. "\n\t__scope = " .. tostring(__scope))
					
					error(string.format("class %s: invalid read access attempt to private member '%s': accessed by %s",
						locationOf, mKey, __scope or "- code outside class boundaries -"))
				end
			end
			
			return value
		elseif locationOf == "?" then
			error(string.format("class %s: lookup of ambiguous member %s: this member is defined " ..
					"in multiple parents, we don't know which one to use... use self.<ParentName><:or.>%s instead!",
				invokedOn:get_name(), mKey, 
					mKey))
		else		
			if invokedOn:____member_isvalid("___meta__index") then
				local custval = invokedOn:___meta__index(invokedOn, mKey)
				
				if custval then
					return custval
				end
			end
		end
		
		return nil-- Member not found, returning nil
	end;
	
	__newindex = function(invokedOn, mKey, mValue)
		if invokedOn.___parents[mKey] then
			error("error: setting parent variable: this variable is used to access your class parent")
		end
		
		local locationOf = invokedOn.___registry[mKey]
		
		if isclass(locationOf) then
			local access = locationOf.___members[mKey].access
			local static = locationOf.___members[mKey].static
			local value = locationOf.___members[mKey].value
			local final = locationOf.___members[mKey].final
			local isfunc = locationOf.___members[mKey].isfunc
			
			-- ...
			if not static and not invokedOn.___instance then
					print("---------------------" ..
					"\n\tStatic: " .. tostring(static) .. "\n\tmKey = " .. mKey .. "\n\tAccess = " .. access .. "\n\tinvokedOn = " .. invokedOn ..
					"\n\tlocationOf = " .. locationOf .. "\n\t__scope = " .. tostring(__scope))

				error(string.format("access to %s member %s: you cannot access this member variable unless it's static", invokedOn, mKey))
			elseif final then
				error(string.format("inside class <%s>: invalid write access to class member '%s': member is final", invokedOn, mKey))
			elseif isfunc then
				error(string.format("access to class member %s: you cannot modify class methods during runtime.", mKey))
			end
			
			-- Redirect statics
			if invokedOn.___instance and static then -- Redirect to global class.
				if not invokedOn:get_class() then
					error(string.format("cannot find class of instance %s", invokedOn))
				end
				
				invokedOn:get_class()[mKey] = mValue

				return -- DO NOT REMOVE! because the callscope is false so things will bug out!
			end

			if access == _public_ then
				-- continue...
			elseif access == _protected_ then
				if (
						not __scope
						or
						not __scope:instance_of(locationOf.___name)
					) then

					print("---------------------" ..
					"\n\tStatic: " .. tostring(static) .. "\n\tmKey = " .. mKey .. "\n\tAccess = " .. access .. "\n\tinvokedOn = " .. invokedOn ..
					"\n\tlocationOf = " .. locationOf .. "\n\t__scope = " .. tostring(__scope))
				
					error(string.format("class %s: invalid write access attempt to protected member '%s': accessed by %s",
						locationOf, mKey, __scope or "- code outside class boundaries -"))
				end
			elseif access == _private_ then
				if (
						not __scope
						or
						locationOf.___name ~= __scope.___name
					) then

					print("---------------------" ..
					"\n\tStatic: " .. tostring(static) .. "\n\tmKey = " .. mKey .. "\n\tAccess = " .. access .. "\n\tinvokedOn = " .. invokedOn ..
					"\n\tlocationOf = " .. locationOf .. "\n\t__scope = " .. tostring(__scope))

					error(string.format("class %s: invalid write access attempt to private member '%s': accessed by %s",
						locationOf, mKey, __scope or "- code outside class boundaries -"))
				end
			end

			locationOf.___members[mKey].value = mValue
			
			return
		elseif locationOf == "?" then
			error(string.format("class %s: lookup of ambiguous member %s: this member is defined " ..
					"in multiple parents, we don't know which one to use... use self.<ParentName><:or.>%s instead!",
				invokedOn:get_name(), mKey, 
					mKey))
		else
			if invokedOn:____member_isvalid("___meta__newindex") then
				invokedOn:___meta__newindex(invokedOn, mKey, mValue)
			
				return
			end
		end
		
		error(string.format("class %s: invalid write attempt to undefined variable '%s", invokedOn, mKey))
	end;
	
	__unm = function(self)
		-- infinite recursion protection
		local __unm = getmetatable(self).__unm
		getmetatable(self).__unm = nil
		
		if self:____member_isvalid("___meta__unm") then
			return self:___meta__unm(self)
		end
		
		getmetatable(self).__unm = __unm
	end;
	
	__add = function(self, class2)
		-- infinite recursion protection
		local __add = getmetatable(self).__add
		getmetatable(self).__add = nil
		
		if self:____member_isvalid("___meta__add") then
			return self:___meta__add(self, class2)
		end
		
		getmetatable(self).__add = __add
	end;
	
	__sub = function(self, class2)
		-- infinite recursion protection
		local __sub = getmetatable(self).__sub
		getmetatable(self).__sub = nil
		
		
		if self:____member_isvalid("___meta__sub") then
			return self:___meta__sub(self, class2)
		end
		
		getmetatable(self).__sub = __sub
	end;
	
	__mul = function(self, class2)
		-- infinite recursion protection
		local __mul = getmetatable(self).__mul
		getmetatable(self).__mul = nil
		
		if self:____member_isvalid("___meta__mul") then
			return self:___meta__mul(self, class2)
		end
		
		getmetatable(self).__mul = __mul
	end;
	
	__div = function(self, class2)
		-- infinite recursion protection
		local __div = getmetatable(self).__div
		getmetatable(self).__div = nil
		
		if self:____member_isvalid("___meta__div") then
			return self:___meta__div(self, class2)
		end
		
		getmetatable(self).__div = __div
	end;
	
	__mod = function(self, class2)
		-- infinite recursion protection
		local __mod = getmetatable(self).__mod
		getmetatable(self).__mod = nil
		
		if self:____member_isvalid("___meta__mod") then
			return self:___meta__mod(self, class2)
		end
		
		getmetatable(self).__mod = __mod
	end;
	
	__pow = function(self, class2)
		-- infinite recursion protection
		local __pow = getmetatable(self).__pow
		getmetatable(self).__pow = nil
		
		if self:____member_isvalid("___meta__pow") then
			return self:___meta__pow(self, class2)
		end
		
		getmetatable(self).__pow = __pow
	end;
	
	__eq = function(self, class2)
		-- infinite recursion protection
		local __eq = getmetatable(self).__eq
		getmetatable(self).__eq = nil
		
		if self:____member_isvalid("___meta__eq") then
			
			return self:___meta__eq(self, class2)
		end
		
		getmetatable(self).__eq = __eq
	end;
	
	__lt = function(self, class2)
		-- infinite recursion protection
		local __lt = getmetatable(self).__lt
		getmetatable(self).__lt = nil
		
		if self:____member_isvalid("___meta__lt") then
			return self:___meta__lt(self, class2)
		end
		
		getmetatable(self).__lt = __lt
	end;
	
	__le = function(self, class2)
		-- infinite recursion protection
		local __le = getmetatable(self).__le
		getmetatable(self).__le = nil
		
		if self:____member_isvalid("___meta__add") then
			return self:___meta__add(self, class2)
		end
		
		getmetatable(self).__le = __le
	end;
}

do
	do -- Free to use class utility functions.
		function SIMPLOO.CLASS_FUNCTIONS:is_a(className)
			return self:get_name() == className
		end

		function SIMPLOO.CLASS_FUNCTIONS:instance_of(className)
			if self.___cache["instance_of-" .. className] then
				return true
			end
			
			if self:get_name() == className then
				return true
			else
				for parentClassName, parentObject in pairs(self.___parents) do
					if parentObject:instance_of(className) then
						self.___cache["instance_of-" .. tostring(className)] = true
						
						return true
					end
				end
			end

			return false
		end

		function SIMPLOO.CLASS_FUNCTIONS:child_of(classObject)
			if self.___cache["child_of_" .. tostring(classObject)] then
				return true
			end
			
			if self == classObject then
				return true
			else
				for parentClassName, parentObject in pairs(self.___parents) do
					if parentObject:child_of(classObject) then
						self.___cache["child_of-" .. tostring(classObject)] = true
						
						return true
					end
				end
			end
			
			return false
		end

		function SIMPLOO.CLASS_FUNCTIONS:get_name()
			return self.___name
		end

		function SIMPLOO.CLASS_FUNCTIONS:get_class()
			return SIMPLOO.CLASSES[self:get_name()]
		end

		function SIMPLOO.CLASS_FUNCTIONS:new(...)
			if self.___instance then
				error("you cannot instantiate an instance!")
			end
			
			if self.___abstract then
				error(string.format("cannot instantiate class %s: class is abstract", self:get_name()))
			end
			
			self:___check_unimplemented_abstract()
			
			local instance = self:___instantiate(...)
			
			-- Update member functions
			instance:___updatefunctions()
			
			-- Activate the instance
			instance:____add_finalizer()
			
			-- Rebuild registry, because we duplicated everything and the references are still old.
			instance:___build_registry()
			
			-- Calls constructor
			instance:____construct(instance, ...)
			
			return instance
		end
	end

	do -- Hidden class utility functions.
		function SIMPLOO.CLASS_FUNCTIONS:____construct(_caller, ...)
			if self.___instance then
				--[[
				-- While I would love to auto call constructors, it's probably
				-- causing more problems then it solves because the number
				-- of arguments is unpredictable.
				
				for parentName, parentObject in pairs(self.___parents) do
					parentObject:____construct(_caller, ...)
				end
				]]
				
				for _, name in pairs({"__construct"}) do
					if self:____member_isvalid(name)
						
						-- limit to local class only, otherwise it would
						-- start calling parent constructors if our own is missing
						-- and this would be inconsistent behavior
						and self:____member_getlocation(name) == self then
						self[name](_caller, ...)
					end
				end
			else
				error("calling ____construct on non-instance")
			end
		end

		function SIMPLOO.CLASS_FUNCTIONS:___finalize()
			if self.___instance then
				for parentName, parentObject in pairs(self.___parents) do
					parentObject:___finalize()
				end
			
				for _, name in pairs({"__finalize"}) do
					if self:____member_isvalid(name) then
						-- Bypass metatable restrictions
						return self:____member_get(name).value(self)
					end
				end
			else
				-- Lua 5.2 will call this in __gc even when we're working with a class
				-- so let's just return false here
				--error("calling ___finalize on non-instance")
				
				return false
			end
		end

		function SIMPLOO.CLASS_FUNCTIONS:____declare()
			if not self.___instance then
				for parentName, parentObject in pairs(self.___parents) do
					parentObject:____declare()
				end
			
				for _, name in pairs({"__declare"}) do
					if self:____member_isvalid(name) then
						-- Bypass metatable restrictions
						return self:____member_get(name).value(self)
					end
				end
			else
				error("calling ____declare on instance")
			end
		end

		function SIMPLOO.CLASS_FUNCTIONS:____duplicate()
			return _duplicateClass(self, nil, true)
		end
		
		function SIMPLOO.CLASS_FUNCTIONS:___instantiate(...)
			-- Duplicate
			local instance = self:____duplicate()
			
			instance.___instance = true
			
			-- Add parents
			for parentName, parentObject in pairs(instance.___parents) do
				instance.___parents[parentName] = parentObject:___instantiate(...)
			end
			
			return instance
		end
		
		function SIMPLOO.CLASS_FUNCTIONS:___updatefunctions(_child)
			for mKey, mData in pairs(self.___members) do
				if mData.isfunc then
					mData.value = _doValue(mKey, mData.rawvalue, self, _child or self)
				end
			end
			
			for parentName, parentObject in pairs(self.___parents) do
				parentObject:___updatefunctions(self)
			end
		end
		
		function SIMPLOO.CLASS_FUNCTIONS:____add_finalizer()
			--[[
			-- We don't loop through all parents here, only the lowest child needs this hook.
			for parentName, parentObject in pairs(self.___parents) do
				parentObject:____add_finalizer()
			end]]

			-- Setup the finalizer proxy for lua 5.1
			if _VERSION == "Lua 5.1" then
				local proxy = newproxy(true)
				local mt = getmetatable(proxy)
				mt.MetaName = "SimplooGC"
				mt.__class = self
				mt.__gc = function(self)
					local tbl = getmetatable(self).__class
					
					if tbl then
						-- Lua doesn't really do anything with errors happening inside __gc (doesn't even print them in my test)
						-- So we catch them by hand and print them!
						local s, e = pcall(function()
							tbl:___finalize()
						end)

						if not s then
							print(string.format("ERROR: class %s: error __gc function: %s",
								tbl:get_name(), e))
						end
					else
						--print("no tbl found in __gc of class.. what!!?") 
					end
				end
				
				rawset(self, "___gc", proxy)
			end
		end

		function SIMPLOO.CLASS_FUNCTIONS:____member_isvalid(memberName)
			return self.___registry[memberName] and true or false
		end
		
		function SIMPLOO.CLASS_FUNCTIONS:____member_getlocation(memberName)
			return self.___registry[memberName]
		end

		function SIMPLOO.CLASS_FUNCTIONS:____member_getluatype(memberName)
			return type(self.___registry[memberName] and self.___registry[memberName].___members[memberName].value)
		end
		
		function SIMPLOO.CLASS_FUNCTIONS:____member_get(memberName)
			return self.___registry[memberName] and self.___registry[memberName].___members[memberName]
		end

		function SIMPLOO.CLASS_FUNCTIONS:____member_getargs(memberName)
			local reg =  self.___registry[memberName]

			if not reg then
				error(string.format("class %s: attempted to call ____member_getargs on invalid member '%s'", self:get_name(), memberName))
			end
			
			return reg:____member_get(memberName).args
		end
	end		

	-- Build the registry and the reverse-registry.
	do
		function SIMPLOO.CLASS_FUNCTIONS:___build_registry()
			local registryVars = {}
			
			for parentName, parentObject in pairs(self.___parents) do
				local parentVars = parentObject:___build_registry()
				
				for mName, mObject in pairs(parentVars) do
					if registryVars[mName] then
						-- We allow this now, but you are required to specify the parent when you want to access
						-- a member that multiple parents contain.
						--error("ambiguous member")
						
						registryVars[mName] = "?"
					else
						registryVars[mName] = mObject
					end
				end
			end
			
			for mName, mData in pairs(self.___members) do
				if registryVars[mName] and registryVars[mName] ~= "?" then
					if registryVars[mName]:____member_get(mName).final then
						error(string.format("class %s: cannot override member %s: member is final", self, mName))
					end
				end
				
				registryVars[mName] = self
			end
			
			self.___registry = registryVars
			
			return registryVars
		end
	end
	
	do
		function SIMPLOO.CLASS_FUNCTIONS:___check_unimplemented_abstract()
			for memberName, locationClass in pairs(self.___registry) do
				if isclass(locationClass) then
					local member = locationClass.___members[memberName]
					if member.abstract then
						local memberType = locationClass:____member_getluatype(memberName)
						local err = string.format("cannot instantiate class %s: class has unimplemented abstract member ",
							self:get_name())
							
						if memberType == "function" then
							err = err .. string.format("(function) '%s(%s)'", memberName, locationClass:____member_getargs(memberName))
						else
							err = err .. string.format("(%s) '%s'", memberType, memberName)
						end
						
						err = err .. string.format(" defined in class '%s'", locationClass:get_name())
						
						error(err)
					end
				end
			end
		end
	end

	-- Here we check if the access of children aren't less than those of parents
	do
		function SIMPLOO.CLASS_FUNCTIONS:___check_parent_access(_child)
			local level = {} -- we just need this very shortly so can compare them
			level[_public_] = 1
			level[_private_] = 2
			level[_protected_] = 3
			
			if not self.___instance then
				for parentName, parentObject in pairs(self.___parents) do
					parentObject:___check_parent_access()
				end
			end
			
			if _child then
				local childAccess = _child.___registry[mName]:____member_get(mName).access
				local parentAccess = self:____member_get(mName).access

				if level[childAccess] > level[parentAccess] then
					error(string.format("class %s: access level of member '%s' is stricter than parent: was %s in parent but is %s in child", self.___name, mName, parentAccess, childAccess))
				end
			end
		end
	end

	-- Setup the metatables on the class + all children
	do
		function SIMPLOO.CLASS_FUNCTIONS:___init_metatable()
			setmetatable(self, SIMPLOO.CLASS_MT)
		end
	end
end

local function _setupClass(creatorData, creatorMembers)
	local className = creatorData["name"]
	local extendingClasses = creatorData["extends"] or {}
	local finalClass = creatorData["final"] or false

	-- Store the setup location of this class.
	local setupLocationStack = debug and debug.getinfo(4)
	local setupLocation = debug and
		(_realPath(setupLocationStack.short_src .. ":" .. setupLocationStack.currentline))
		or string.format("unknown location %d: no debug library", math.random(0, 10000000))
	
	-- Check for double
	if SIMPLOO.CLASSES[className] then
		local location = SIMPLOO.CLASSES[className].___setupLocation
		
		if setupLocation == location then
			return false
		else
			error(string.format("cannot setup class %s, there's already a class with this name on line (%s)",
				className, location))
		end
	end

	-- Check if parents are valid.
	for _, parentClassName in pairs(extendingClasses) do
		if not SIMPLOO.CLASSES[parentClassName] then
			error(string.format("parent %s for class %s does not exist. failed to setup class", parentClassName, className))
		elseif SIMPLOO.CLASSES[parentClassName].___final then
			error(string.format("parent %s for class %s is final and can not be extended from. failed to setup class", parentClassName, className))
		end
	end
	
	local newClass = {}
	newClass.___name = className
	newClass.___final = finalClass
	newClass.___cache = {}
	newClass.___registry = {}
	newClass.___setupLocation = setupLocation
	
	do -- Setup class data.
		-- Setup members
		newClass.___members = {}

		for mKey, mData in pairs(creatorMembers) do
			if newClass[mKey] then -- Check for double
				error(string.format("failed to setup class %s: member %s already exists", className, mKey))
			end

			local mValue = mData.value;
			local isFunc = type(mValue) == "function"
			local mAccess = (mData.modifiers[_public_] and _public_) or
					(mData.modifiers[_protected_] and _protected_) or
					(mData.modifiers[_private_] and _private_) or
					_private_ -- default value without keywords
			local mStatic = mData.modifiers[_static_] and true or false;
			local mFinal = (mData.modifiers[_final_] and true) or
				(isFunc and mAccess == _private and true) or
				false;
			local mAbstract = mData.modifiers[_abstract_] and true or false;
			local mMeta = mData.modifiers[_meta_] and true or false;
			
			newClass.___members[mKey] = {
				value = mValue, -- will be handled by :___updatefunctions
				access = mAccess,
				static = mStatic,
				final = mFinal,
				abstract = mAbstract,
				isfunc = isFunc,
				rawvalue = mValue,
				meta = mMeta,
				args = isFunc and _getFunctionArgs(mValue), -- used in ____member_getargs
			}
			
			if mAbstract then
				newClass.___abstract = true
			end
		end
	end
	
	do
		-- Define the parents
		newClass.___parents = {}
		
		for _, parentClassName in pairs(extendingClasses) do
			if SIMPLOO.CLASSES[parentClassName] then
				-- We do NOT DUPLICATE HERE
				-- If we did, static variables wouldn't work because each class would have a different instance of the parent.
				-- The parents will still be duplicated when we instantiate a new instance.
				newClass.___parents[parentClassName] = SIMPLOO.CLASSES[parentClassName]
			end
		end

		-- Add a variable that will be set to true on instances.
		newClass.___instance = false
	end
	
	for k, v in pairs(SIMPLOO.CLASS_FUNCTIONS) do
		newClass[k] = v -- copy reference
	end
	
	newClass.new = function(arg1, ...)
		if arg1 == newClass then
			error("calling new() with ':'' instead of '.'?? or are you passsing yourself as the first argument (you can use 'self' for that in your code)")
		end
		
		return SIMPLOO.CLASS_FUNCTIONS.new(newClass, arg1, ...)
	end
			
	-- Update member functions
	newClass:___updatefunctions()
	
	-- Initialize metatable
	newClass:___init_metatable()
	
	-- Check parent access
	newClass:___check_parent_access()
	
	-- Build registry
	newClass:___build_registry()
	
	-- Call declare class function
	newClass:____declare()
	
	-- Create global
	_setGlobal(className, newClass)
	
	-- Store reference.
	SIMPLOO.CLASSES[className] = newClass
end

do
	local creatorActive = false
	local creatorData = {}
	local creatorMembers = {}

	--[[
		This function gives a special table which is used to detect modifiers.
	]]

	local function _recursiveModifiers(key, onfinished, onKeywordNotFound, _modifiers)
		local _modifiers = _modifiers or {}

		return setmetatable({}, {
			__index = function(self, key)
				if key == "public" then
					_modifiers[_public_] = true
				elseif key == "protected" then
					_modifiers[_protected_] = true
				elseif key == "private" then
					_modifiers[_private_] = true
				elseif key == "static" then
					_modifiers[_static_] = true
				elseif key == "final" then
					_modifiers[_final_] = true
				else
					return onKeywordNotFound(key)
				end

				return _recursiveModifiers(key, onfinished, onKeywordNotFound, _modifiers)
			end,

			__newindex = function(self, key, value)
				onfinished(_modifiers, key, value)
			end,

			__call = function(self, table)
				for k, v in pairs(table) do
					returnonfinished(_modifiers, k, v)
				end
			end,
		})
	end

	local function _pushMembersModifier(dataTable, modifierTable)
		if not creatorMembers then
			error("defining members without any class specification")
		end

		local new = {}
		new["___children"] = {}
		new["___members"] = {}
		new["___modifiers"] = {unpack(modifierTable)}
		
		for k, v in pairs(dataTable) do
			if type(v) == "table" and v["___children"] then
				table.insert(new["___children"], v)
			else
				new["___members"][k] = v
			end
		end

		return new;
	end

	local function _assembleMembers(data, _results, _modifiers)
		if not _results then
			local results = {}
			local modifiers = {}
			
			_assembleMembers(data, results, modifiers)

			return results;
		else
			if data["___members"] then
				for _, pKey in pairs(data["___modifiers"]) do
					_modifiers[pKey] = true
				end

				for mKey, mValue in pairs(data["___members"]) do
					if mKey:sub(1, ("___meta"):len()) == "___meta" and not _modifiers[_meta_] then
						error(string.format("failed to setup class %s: member %s: members starting with '___meta' are reserved for internal use!", creatorData['name'], mKey))
					end
					
					if _results[mKey] then
						error(string.format("failed to setup class %s: double usage of variable %s", creatorData['name'], mKey))
					end

					_results[mKey] = {value = mValue, modifiers = _duplicateTable(_modifiers)}
				end

				for childNum, childVal in pairs(data["___children"]) do
					_assembleMembers(childVal, _results, _modifiers)
				end

				for _, pKey in pairs(data["___modifiers"]) do
					_modifiers[pKey] = nil
				end
			end
		end
	end

	local function resetSetup()
		creatorActive = false
		creatorData = {}
		creatorMembers = {}
	end

	local classSetupObject = setmetatable({
			register = function()
				-- We copy our tables
				local _creatorData = _duplicateTable(creatorData)
				local _creatorMembers = _duplicateTable(creatorMembers)

				-- Reset the setup variables
				resetSetup()
				
				-- Setup our class
				_setupClass(_creatorData, _creatorMembers)
			end
		}, {
			__call = function(self, data)
				if data then
					local wrapper = _pushMembersModifier(data, {})

					creatorMembers = _assembleMembers(wrapper)
				end

				self.register()
			end,

			-- called when adding modifiers
			__index = function(self, key)
				local t = _recursiveModifiers(key, function(modifierTable, mKey, mValue) -- found
					creatorMembers[mKey] = {value = mValue, modifiers = _duplicateTable(modifierTable)}
				end, function(mKey) -- not found, return member
					return creatorMembers[mKey] and creatorMembers[mKey].value
				end)

				return t[key]
			end,

			 -- only called when directly doing newclass.hello = 5, no need for recursive modifiers because any modifiers would make it call __index
			__newindex = function(self, mKey, mValue)
				creatorMembers[mKey] = {value = mValue, modifiers = {}}
			end,
		}
	)
	
	do -- Class creation functions
		function class(newClassName, opt)
			if creatorActive then
				local err = string.format("invalid class setup: class %s: you still haven't finished setting up class %s",
					newClassName, creatorData["name"])
				resetSetup()
				error(err)
			end

			-- Set data
			creatorActive = true
			creatorData["name"] = newClassName

			-- Parse options for alternative syntax
			if opt then
				options(opt)
			end

			return classSetupObject
		end

		function extends(s)
			if creatorActive then
				creatorData["extends"] = creatorData["extends"] or {}
				
				for parent in string.gmatch(s, "([^,^%s.]+)") do
					table.insert(creatorData["extends"], parent)
				end
			else
				error("extending on nothing - make sure you called class() first")
			end
			
			return classSetupObject
		end

		function options(options)
			if options["extends"] then
				if type(options["extends"]) == "table" then
					for k, v in pairs(options["extends"]) do
						extends(v)
					end
				else
					extends(options["extends"])
				end
			end

			if options["final"] then
				final()
			end

			return classSetupObject
		end
	end

	do -- Member variable functions
		function public(rawMemberTable)
			if not rawMemberTable then
				error("running public keyword without value")
			end

			return _pushMembersModifier(rawMemberTable, {_public_})
		end

		function protected(rawMemberTable)
			if not rawMemberTable then
				error("running protected keyword without value")
			end

			return _pushMembersModifier(rawMemberTable, {_protected_})
		end

		function private(rawMemberTable)
			if not rawMemberTable then
				error("running private keyword without value")
			end

			return _pushMembersModifier(rawMemberTable, {_private_})
		end

		function static(rawMemberTable)
			if not rawMemberTable then
				error("running static keyword without value")
			end

			return _pushMembersModifier(rawMemberTable, {_static_})
		end
		
		function abstract(rawMemberTable)
			if not rawMemberTable then
				error("running abstract keyword without value")
			end
			
			return _pushMembersModifier(rawMemberTable, {_abstract_})
		end
		
		function meta(rawMemberTable)
			if not rawMemberTable then
				error("running meta keyword without value")
			end
			
			local t = {}
			for k, v in pairs(rawMemberTable) do
				t["___meta" .. k] = v
			end
			
			return _pushMembersModifier(t, {_meta_, _public_})
		end
	end

	do -- Either to set modifiers of a class, OR to set modifiers of a class member
		function final(rawMemberTable)
			if rawMemberTable then -- We're making class members final
				return _pushMembersModifier(rawMemberTable, {_final_})
			else -- We're making a class final
				if not creatorData then
					error("setting final on nothing")
				end

				creatorData["final"] = true
				
				return classSetupObject
			end
		end
	end
end
