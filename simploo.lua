--[[
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

local function tableCopy(t, _lookup_table)
	if t == nil then
		return nil
	end

	local copy = {}
	debug.setmetatable(copy, debug.getmetatable(t))

	for i, v in pairs(t) do
		if type(v) ~= "table" then
			copy[i] = v
		else
			_lookup_table = _lookup_table or {}
			_lookup_table[t] = copy

			if _lookup_table[v] then
				copy[i] = _lookup_table[v] -- we already copied this table. reuse the copy.
			else
				copy[i] = tableCopy(v,_lookup_table) -- not yet copied. copy it.
			end
		end
	end

	return copy
end

LUA_CLASSES = {}
LUA_INTERFACES = {}

-- Locally we emphasize our access levels with underscores
-- so it's easier to read the code, it serves no other purpose.
local _public_ = "PublicAccess"
local _protected_ = "ProtectedAccess"
local _private_ = "PrivateAccess"

local classMT = {
	__tostring = function(self)
		-- We disable the metatable on ourselfs, so we can tostring ourselves without getting into an infinite loop.
		-- And no, rawget doesn't work because we want to call a metamethod on ourself: __tostring
		local mt = getmetatable(self)
		setmetatable(self, {})

		-- Grap the definition string.
		local str = string.format("LuaClass: %s {%s}", self.__name, tostring(self):sub(8))

		-- Enable our metatable again.
		setmetatable(self, mt)

		-- Return string.
		return str
	end,

	__call = function(self, ...)
		-- When we call class instances, we actually call their constructors!
		if self:member_valid(self.__name) then
			if self:member_getaccess(self.__name) ~= _public_ then
				error(string.format("Cannot create instance of class %s: constructor access level is not public!", self.__name))
			else
				self[self.__name](self, ...)
			end
		end
	end;

	__index = function(self, mKey)
		if mKey == "super" then
			return rawget(self, "__super")
		elseif mKey == "__super" or mKey == "__name" then
			error(string.format("Invalid read access to hidden class member '%s'", mKey))
		elseif mKey == "__members" or mKey == "__registry" or mKey == "__cache" or mKey == "__functionality" then
			error(string.format("Invalid read access to hidden class member '%s'", mKey))
		end

		local locationClass = self.__registry[mKey]
		if locationClass then
			-- Check which access modifier this member has.
			local access = locationClass.__members[mKey].access
			local value = locationClass.__members[mKey].fvalue or locationClass.__members[mKey].value
			
			if access == _public_ then
				return value
			elseif access == _protected_ then
				local info = debug.getinfo(2, "nf")
				local name = info.name
				local func = info.func

				-- The below functions check used to be using the callInfo.name to look up the class members direct, but debug.getinfo(2).name
				-- seems to return incorrect values, when used to lookup functions that directly return protected class member calls.
				-- This seems to be a lua bug. So now we just make a table that uses the actual functions as keys, which is hopefully just as
				-- well performing as we don't want to iterate through all members to see if it matches the 2nd stack function.
				if self.__functionality[func] then
					return value
				else
					error(string.format("Invalid get access attempt to protected member '%s' located in <%s> via <%s> function '%s' (check nr. 3 in stack trace)", mKey, tostring(locationClass), tostring(self), name))
				end
			elseif access == _private_ then
				if locationClass == self  then
					return value
				else
					error(string.format("Invalid get access attempt to private member '%s' located in <%s> by <%s> (check nr. 3 in stack trace)",
						mKey, tostring(locationClass), tostring(self)))
				end
			else
				error(string.format("Class <%s> has defined member '%s' but has no access level defined", tostring(locationClass), mKey))
			end	
		end
		
		--error(string.format("Class <%s> was unable to lookup mKey '%s'", self, mKey))

		return nil
	end,
	
	__newindex = function(self, mKey, mValue)
		if mKey == "super" then
			error(string.format("Invalid write access to class member '%s'", mKey))
		elseif mKey == "__name" or mKey == "__super" then
			error(string.format("Invalid write access to hidden class member '%s'", mKey))
		elseif mKey == "__members" or mKey == "__registry" or mKey == "__cache" or mKey == "__functionality" then
			error(string.format("Invalid write access to hidden class member '%s'", mKey))
		end

		local locationClass = self.__registry[mKey]
		if locationClass then
			-- Check which access modifier this member has.
			local access = locationClass.__members[mKey].access
			if access == _public_ then
				locationClass.__members[mKey].value = mValue
				locationClass.__members[mKey].fvalue = type(mVal) == "function" and 
					function(self, ...)
						return mVal(self.__registry[mKey], ...)
					end

				return
			elseif access == _protected_ then
				local info = debug.getinfo(2, "nf")
				local name = info.name
				local func = info.func

				-- The below functions check used to be using the callInfo.name to look up the class members direct, but debug.getinfo(2).name
				-- seems to return incorrect values, when used to lookup functions that directly return protected class member calls.
				-- This seems to be a lua bug. So now we just make a table that uses the actual functions as keys, which is hopefully just as
				-- well performing as we don't want to iterate through all members to see if it matches the 2nd stack function.
				if self.__functionality[func] then
					locationClass.__members[mKey].value = mValue
					locationClass.__members[mKey].fvalue = type(mVal) == "function" and 
						function(self, ...)
							return mVal(self.__registry[mKey], ...)
						end

					return
				else
					error(string.format("Invalid set access attempt to protected member '%s' located in <%s> via <%s> function '%s' (check nr. 3 in stack trace)", mKey, tostring(locationClass.locationClass), tostring(self), name))
				end
			elseif access == _private_ then
				if locationClass == self then
					locationClass.__members[mKey].value = mValue
					locationClass.__members[mKey].fvalue = type(mVal) == "function" and 
						function(self, ...)
							return mVal(self.__registry[mKey], ...)
						end

					return
				else
					error(string.format("Invalid set access attempt to private member '%s' located in <%s> via <%s> (check nr. 3 in stack trace)", mKey, tostring(locationClass.locationClass), tostring(self)))
				end
			else
				error(string.format("Class <%s> has defined member '%s' but has no access level defined", tostring(locationClass), mKey))
			end	
		else
			error(string.format("Unable to set member '%s' inside class <%s>: member was never defined during class definition", mKey, self))
		end
	end
}

--[[
	Create an instance of a class.
]]

local function createClassInstance(className, ...)
	-- Create a new instance.
	local instance = tableCopy(LUA_CLASSES[className])

	-- Activate the metatables
	local class = instance
	while class ~= nil do
		-- Setup the metatable
		setmetatable(class, classMT)

		class = class.super
	end

	-- Call the constructor
	local ret = instance(...)

	return ret || instance
end

--[[
	Setup a new class.
]]

local function setupClass(creatorData, creatorMembers)
	local className = creatorData["name"]
	local superClassName = creatorData["super"]
	local implementsList = creatorData["implements"]

	-- Check for double
	if LUA_CLASSES[className] then
		error(string.format("Double setup of class %s, failed to setup new class!", className))
	end

	-- Check for parent
	if superClassName ~= nil and not LUA_CLASSES[superClassName] then
		error(string.format("Parent for class %s does not exist! Failed to setup class", className))
	end

	local newClass = {}
	
	
	do -- Setup class data.
		-- Define the members table.
		newClass.__members = {}

		-- Parse all variables in the public/protected/private tables.
		for mKey, mData in pairs(creatorMembers) do
			newClass.__members[mKey] = {value = mData.value, access = mData.access, fvalue = type(mVal) == "function" and 
				function(self, ...)
					return mVal(self.__registry[mKey], ...)
				end
			}
		end

		-- Define the class name.
		newClass.__name = className

		-- Define the super class.
		newClass.__super =  tableCopy(LUA_CLASSES[superClassName])
	end

	do -- Setup utility functions
		newClass.__cache = {}

		function newClass:is_a(className)
			return self.__name == className
		end

		function newClass:instance_of(className)
			if self.__cache["instance_of_" .. className] then
				return true
			end

			local iter = self
			while iter ~= nil do
				if iter.__name == class then
					self.__cache["instance_of_" .. class] = true

					return true
				end

				iter = iter.super
			end

			return false
		end

		function newClass:member_valid(memberName)
			return self.__registry[memberName] and true or false
		end

		function newClass:member_getaccess(memberName)
			return self.__registry[memberName] and self.__registry[memberName].__members[memberName].access
		end

		function newClass:member_gettype(memberName)
			return type(self.__registry[memberName] and self.__registry[memberName].__members[memberName].value)
		end

		function newClass:member_getargs(memberName)
			local reg =  self.__registry[memberName]

			if not reg then
				error(string.format("Class %s: attempted to call member_getargs on invalid member '%s'", self.__name, memberName))
			end

			local value = reg.__members[memberName].value

			if type(value) ~= "function" then
				return {}
			end

			local arglist = {}
			local dbg = debug.getinfo(value)
			if dbg and dbg.nparams then
				for i = 1, dbg.nparams do
					arglist[i] = debug.getlocal(value, i)
				end
			else
				print("no dbg or dbg.nparams for " .. memberName .. "!")
			end

			return arglist
		end
	end

	do -- Build the registry and the reverse-registry.
		newClass.__registry = {}
		newClass.__functionality = {}

		local iter = newClass
		while iter ~= nil do
			for k, v in pairs(iter.__members) do
				-- This is important, we have to skip assignment if there is already a member found earlier
				-- or else we priorise parents above children.
				if not newClass.__registry[k] then
					newClass.__registry[k] = iter
				end

				-- Here we keep track of all functions this class or its parents contains, this can be used
				-- to check whether calls to protected functions came from this class or its parents.
				local value = iter.__members[k].value
				if type(value) == "function" then
					newClass.__functionality[value] = true
				end
			end
			
			iter = rawget(iter, "__super")
		end
	end

	-- Check if we implemented everything the interface specified.
	for _, interfaceName in pairs(implementsList or {}) do
		local interface = LUA_INTERFACES[interfaceName]
		if interface then
			for memberName, interface_memberData in pairs(interface.members) do
				if newClass:member_valid(memberName) then
					-- Check if the access modifiers match up.
					if newClass:member_getaccess(memberName) ~= interface:member_getaccess(memberName) then
						error(string.format("Class %s is supposed to implement member '%s' with %s access, but it's specified with %s access in the class",
									className, memberName, interface_memberData.access,  newClass:member_getaccess(memberName)))
					end

					-- Check if the lua types match up.
					local interfaceType = interface:member_gettype(memberName)
					local classType = newClass:member_gettype(memberName)
					
					if classType ~= interfaceType then
						error(string.format("Class %s is supposed to implement member '%s' as the '%s' lua_type, but it's specified as the '%s' lua_type in the class",
									className, memberName, interfaceType, classType))
					end

					-- Check if the arguments match up.
					local interfaceArgs = interface:member_getargs(memberName)
					local classArgs = newClass:member_getargs(memberName)

					-- Check argument names.
					for k, v in pairs(interfaceArgs) do
						if not classArgs[k] then
							error(string.format("Class %s is supposed to implement member function '%s' argument #%d with the name '%s'",
											className, memberName, k, v, k, classArgs[k]))
						end
						if classArgs[k] ~= v then
							error(string.format("Class %s is supposed to implement member function '%s' argument #%d with the name '%s', but argument #%d is named '%s' instead",
											className, memberName, k, v, k, classArgs[k]))
						end
					end

					for k, v in pairs(classArgs) do
						if interfaceArgs[k] ~= v then
							error(string.format("Class %s is not supposed to implement member function '%s' argument #%d named '%s': this argument isn't specified in the implemented interface '%s'",
											className, memberName, k, v, interfaceName))
						end
					end
				else
					error(string.format("Class %s is missing interface definition: %s '%s' specified in interface isn't implemented",
							className, interface_memberData.access, memberName))
				end
			end
		else
			error(string.format("Class %s attempted to implement non-existant interface '%s'", className, interfaceName))
		end
	end

	-- Store prepared classdata in the registry.
	LUA_CLASSES[className] = newClass
	
	-- Create a global that can be used to create a class instance, or to return the class data.
	_G[className] = setmetatable({}, {
		__call = function(self, ...) -- ... being parameters to be passed to the constructor.
			return createClassInstance(self.__name, ...)
		end;

		__index = newClass;
	})

	--print(string.format("Created new class: %s with superclass %s implementing %s", className, superClassName, implementsName))
end


local interfaceMT = {
	__tostring = function(self)
		-- We disable the metatable on ourselfs, so we can tostring ourselves without getting into an infinite loop.
		-- And no, rawget doesn't work because we want to call a metamethod on ourself: __tostring
		local mt = getmetatable(self)
		setmetatable(self, {})

		-- Grap the definition string.
		local str = string.format("LuaInterface: %s {%s}", self.name, tostring(self):sub(8))

		-- Enable our metatable again.
		setmetatable(self, mt)

		-- Return string.
		return str
	end,

	__index = function(self, key)
		if key == "members" then
			return self.__members
		end
	end,
	
	__newindex = function(self, key, value)
		error("cannot change interface")
	end,
}

--[[
	Setup a new interface.
]]

local function setupInterface(creatorData, creatorMembers)
	local interfaceName = creatorData["name"]
	local superInterfaceName = creatorData["super"]
	
	-- Check for double
	if LUA_INTERFACES[interfaceName] then
		error(string.format("Double setup of interface %s, failed to setup new interface!", interfaceName))
	end

	-- Check for parent
	if superInterfaceName ~= nil and not LUA_INTERFACES[superInterfaceName] then
		error(string.format("Parent for interface %s does not exist! Failed to setup interface", interfaceName))
	end

	-- Setup the interface
	local newInterface = {}
	newInterface.__members = {}

	-- Parse all variables in the public/protected/private tables.
	for mKey, m in pairs(creatorMembers) do
		newInterface.__members[mKey] = {value = m.value, access = m.access, fvalue = type(mVal) == "function" and 
			function(self, ...)
				return mVal(self.__registry[mKey], ...)
			end
		}
	end

	-- Copy all members from the parent interface (if specified)
	local superInterface = LUA_INTERFACES[superInterfaceName]
	if superInterface then
		for mKey, mVal in pairs(superInterface.__members) do
			if newInterface.__members[mKey] then
				if newInterface.__members[mKey].access ~= superInterface.__members[mKey].access then
					error(string.format("Interface %s has a member called '%s' specified as %s, but it's superinterface has this member specified as %s", interfaceName, mKey, superInterface.__access[mKey]))
				end
			else
				newInterface.__members[mKey] = superInterface.__members[mKey]
			end
		end
	end

	do -- Setup utility functions
		function newInterface:member_valid(memberName)
			return self.__members[memberName] and true or false
		end

		function newInterface:member_getaccess(memberName)
			return self.__members[memberName] and self.__members[memberName].access
		end

		function newInterface:member_gettype(memberName)
			return type(self.__members[memberName] and self.__members[memberName].value)
		end

		function newInterface:member_getargs(memberName)
			local member =  self.__members[memberName]

			if not member then
				error(string.format("Class %s: attempted to call member_getargs on invalid member '%s'", self.__name, memberName))
			end

			local value = member.value

			if type(value) ~= "function" then
				return {}
			end

			local arglist = {}
			local dbg = debug.getinfo(value)
			if dbg and dbg.nparams then
				for i = 1, dbg.nparams do
					arglist[i] = debug.getlocal(value, i)
				end
			else
				print("no dbg or dbg.nparams for " .. memberName .. "!")
			end

			return arglist
		end
	end

	-- Setup the metatable
	setmetatable(newInterface, interfaceMT)

	-- Store prepared classdata in the registry.
	LUA_INTERFACES[interfaceName] = newInterface

	--print(string.format("Created new interface: %s with superclass %s", interfaceName, superInterfaceName))
end

do
	local creatorType, creatorData, creatorMembers
	
	local function addMembers(memberTable, access)
		if not creatorMembers then
			error("defining members without any class specification")
		end

		for mKey, mValue in pairs(memberTable) do
			if creatorMembers[mKey] then
				error(string.format("Double definition of member '%s' in class '%s'", mKey, creatorData["name"]))
			else
				creatorMembers[mKey] = {value = mValue, access = access}
			end
		end
	end

	local executionTable = setmetatable({}, {
		__call = function(data)
			PrintTable(data)
			for mKey, mValue in pairs(data or {}) do
				if creatorMembers[mKey] then
					error(string.format("Double definition of member '%s' in class '%s'", mKey, creatorData["name"]))
				else
					creatorMembers[mKey] = {value = mValue, access = _private_}
				end
			end

			if creatorType == "class" then
				setupClass(creatorData, creatorMembers)
			elseif creatorType == "interface" then
				setupInterface(creatorData, creatorMembers)
			end

			creatorType = nil
			creatorData = nil
			creatorMembers = nil
		end,

		__index = function(self, key)
			if key == "public" or key == "protected" or key == "private" then
				local mAccess = 
							(key == "public" and _public_) or
							(key == "protected" and _protected_ ) or
							(key == "private" and _private_)

				return setmetatable({}, {
					__call = function(self, memberTable)
						addMembers(memberTable, mAccess)
					end,

					__newindex = function(self, mKey, mValue)
						addMembers({[mKey] = mValue}, mAccess)
					end
				})
			end
		end
	})

	do -- Shared
		function extends(s)
			if creatorType == "class" then
				creatorData["super"] = s
			elseif creatorType == "interface" then
				creatorData["super"] = s
			else
				error("extending on nothing")
			end
			
			return executionTable
		end
	end

	do -- Class
		function class(className)
			if creatorType or creatorData then
				error("unfinished class creation")
			end

			creatorType = "class"
			creatorData = {}
			creatorData["name"] = className
			creatorMembers = {["public"] = {}, ["protected"] = {}, ["private"] = {}}

			return executionTable
		end

		function implements(...)
			if creatorType == "class" then
				creatorData["implements"] = creatorData["implements"] or {}

				for k, v in pairs({...}) do
					table.insert(creatorData["implements"], v)
				end
			elseif creatorType == "interface" then
				error("You cannot implement an interface in an interface")
			else
				error("implementing on nothing")
			end

			return executionTable
		end


		function public(memberTable)
			if !memberTable then
				error("running public without any member table")
			end

			addMembers(memberTable, _public_)
		end

		function protected(memberTable)
			if !memberTable then
				error("running public without any member table")
			end

			addMembers(memberTable, _protected_)
		end

		function private(memberTable)
			if !memberTable then
				error("running public without any member table")
			end

			addMembers(memberTable, _private_)
		end
	end

	do -- Interface
		function interface(interfaceName)
			creatorType = "interface"
			creatorData = {}
			creatorData["name"] = interfaceName
			creatorMembers = {}

			return executionTable
		end
	end
end