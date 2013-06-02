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

LUA_CLASSES = {}
LUA_INTERFACES = {}


local _public_ = "PublicAccess"
local _protected_ = "ProtectedAccess"
local _private_ = "PrivateAccess"

local _static_ = "StaticMemberType"
local _instance_ = "InstanceMemberType"

--[[
	Creates an instance of a class.
]]

local function createClassInstance(className, ...)
	-- Check if class exists
	if not LUA_CLASSES[className] then
		error(string.format("tried to create invalid class %s", className))
	end

	-- Create a new instance.
	local instance = LUA_CLASSES[className]:duplicate()

	-- Activate the instance
	local class = instance
	while class ~= nil do
		class.__instance = true

		class = class.super
	end

	-- Call the constructor
	local ret = instance(...)

	return ret or instance
end

local classMT = {
	__tostring = function(self)
		-- We disable the metatable on ourselfs, so we can tostring ourselves without getting into an infinite loop.
		-- And no, rawget doesn't work because we want to call a metamethod on ourself: __tostring
		local mt = getmetatable(self)
		setmetatable(self, {})

		-- Grap the definition string.
		local str = string.format("LuaClass: %s <%s> {%s}", self:get_name(), self.__instance and "instance" or "class", tostring(self):sub(8))

		-- Enable our metatable again.
		setmetatable(self, mt)

		-- Return string.
		return str
	end,

	__call = function(self, ...)
		-- When we call class instances, we actually call their constructors
		if self:is_instance() then
			if self:valid_member(self:get_name()) then
				if self:member_getaccess(self:get_name()) ~= _public_ then
					error(string.format("cannot create instance of class %s: constructor access level is not public", self:get_name()))
				else
					return self[self:get_name()](self, ...)
				end
			elseif self.super then
				self.super(self.super, ...)
			end
		else
			return createClassInstance(self:get_name(), ...)
		end
	end;

	__index = function(self, mKey)
		if mKey == "super" then
			return rawget(self, "__super")
		elseif mKey == "__super" or mKey == "__name" then
			error(string.format("invalid read access to hidden class member '%s'", mKey))
		elseif mKey == "__members" or mKey == "__registry" or mKey == "__cache" or mKey == "__functionality" then
			error(string.format("invalid read access to hidden class member '%s'", mKey))
		end

		local locationClass = self.__registry[mKey]
		if locationClass then
			local access = locationClass.__members[mKey].access
			local membertype = locationClass.__members[mKey].membertype
			local value = locationClass.__members[mKey].fvalue or locationClass.__members[mKey].value

			if self.__instance  and membertype == _static_ then -- Redirect to global class.
				return self:get_class()[mKey]
			end

			if access == _public_ then
				return value
			elseif access == _protected_ then
				local stackLevel = membertype == _static_ and 3 or 2
				local info = debug.getinfo(stackLevel, "nf")
				local name = info and info.name or "unknown"
				local func = info and info.func

				-- The below functions check used to be using the callInfo.name to look up the class members direct, but debug.getinfo(2).name
				-- seems to return incorrect values, when used to lookup functions that directly return protected class member calls.
				-- This seems to be a lua bug. So now we just make a table that uses the actual functions as keys, which is hopefully just as
				-- well performing as we don't want to iterate through all members to see if it matches the 2nd stack function.
				if (not info and membertype == _static_) -- This means that this static call isn't a call redirected from within an instance (since frame nr.4 is nonexistent), so it should always be allowed.
					or locationClass == self or self.__functionality[func] then
					return value
				else
					error(string.format("invalid get access attempt to protected member '%s' located in <%s> via <%s> function '%s' (check nr. 3 in stack trace)", mKey, tostring(locationClass), tostring(self), name))
				end
			elseif access == _private_ then
				if locationClass == self  then
					return value
				else
					error(string.format("invalid get access attempt to private member '%s' located in <%s> by <%s> (check nr. 3 in stack trace)",
						mKey, tostring(locationClass), tostring(self)))
				end
			else
				error(string.format("class <%s> has defined member '%s' but has no access level defined", tostring(locationClass), mKey))
			end	
		end
		
		--error(string.format("class <%s> was unable to lookup mKey '%s'", self, mKey))

		return nil
	end,
	
	__newindex = function(self, mKey, mValue)
		if mKey == "super" then
			error(string.format("invalid write access to class member '%s'", mKey))
		elseif mKey == "__name" or mKey == "__super" then
			error(string.format("invalid write access to hidden class member '%s'", mKey))
		elseif mKey == "__members" or mKey == "__registry" or mKey == "__cache" or mKey == "__functionality" then
			error(string.format("invalid write access to hidden class member '%s'", mKey))
		end

		local locationClass = self.__registry[mKey]

		if locationClass then
			local access = locationClass.__members[mKey].access
			local membertype = locationClass.__members[mKey].membertype
			
			if self.__instance and membertype == _static_ then  -- Redirect to global class.
				self:get_class()[mKey] = mValue

				return
			end

			if access == _public_ then
				locationClass.__members[mKey].value = mValue
				locationClass.__members[mKey].fvalue = type(mVal) == "function" and 
					function(self, ...)
						return mVal(self.__registry[mKey], ...)
					end

				return
			elseif access == _protected_ then
				local stackLevel = membertype == _static_ and 3 or 2
				local info = debug.getinfo(stackLevel, "nf")
				local name = info and info.name or "unknown"
				local func = info and info.func

				-- The below functions check used to be using the callInfo.name to look up the class members direct, but debug.getinfo(2).name
				-- seems to return incorrect values, when used to lookup functions that directly return protected class member calls.
				-- This seems to be a lua bug. So now we just make a table that uses the actual functions as keys, which is hopefully just as
				-- well performing as we don't want to iterate through all members to see if it matches the 2nd stack function.
				if (not info and membertype == _static_) -- This means that this static call isn't a call redirected from within an instance (since frame nr.4 is nonexistent), so it should always be allowed.
					or locationClass == self or self.__functionality[func] then
					locationClass.__members[mKey].value = mValue
					locationClass.__members[mKey].fvalue = type(mVal) == "function" and 
						function(self, ...)
							return mVal(self.__registry[mKey], ...)
						end

					return
				else
					error(string.format("invalid set access attempt to protected member '%s' located in <%s> via <%s> function '%s' (check nr. 3 in stack trace)", mKey, tostring(locationClass.locationClass), tostring(self), name))
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
					error(string.format("invalid set access attempt to private member '%s' located in <%s> via <%s> (check nr. 3 in stack trace)", mKey, tostring(locationClass.locationClass), tostring(self)))
				end
			else
				error(string.format("class <%s> has defined member '%s' but has no access level defined", tostring(locationClass), mKey))
			end	
		else
			error(string.format("unable to set member '%s' inside class <%s>: member was never defined during class definition", mKey, self))
		end
	end
}

--[[
	Setup a new class.
]]

local function setupClass(creatorData, creatorMembers)
	local className = creatorData["name"]
	local superClassName = creatorData["super"]
	local implementsList = creatorData["implements"]

	-- Check if there isn't a conflict with a global
	if _G[className] then
		if type(_G[className]) == "table" and not _G[className].get_name or type(_G[className]) ~= "table" then
			error(string.format("cannot setup class %s, there's already a global with this name", className))
		end
	end

	-- Check for double
	if LUA_CLASSES[className] then
		error(string.format("double setup of class %s", className))
	end

	-- Check for parent
	if superClassName ~= nil and not LUA_CLASSES[superClassName] then
		error(string.format("parent for class %s does not exist. failed to setup class", className))
	end

	local newClass = {}
	newClass.__name = className
	
	do -- Setup class data.
		-- Setup members
		-- Setup the members metatable, that redirects all calls to static members to the class.
		newClass.__members = {}

		-- Parse all variables in the public/protected/private tables.
		for mKey, mData in pairs(creatorMembers) do
			newClass.__members[mKey] = {
				value = mData.value,
				access = mData.access,
				membertype = mData.membertype,
				fvalue = type(mVal) == "function" and 
					function(self, ...)
						return mVal(self.__registry[mKey], ...)
					end,
			}
		end

		-- Define the super class.
		if LUA_CLASSES[superClassName] then
			-- We do NOT DUPLICATE HERE
			-- If we did, static variables wouldn't work because each class would have a different instance of the superclass.
			-- The super class will still be duplicates when we initialize a new instance, because :duplicate() would traverse up and copy the __super table too
			newClass.__super =  LUA_CLASSES[superClassName]
		end

		-- Add a variable that will be set to true on instances.
		newClass.__instance = false
	end

	do -- Setup utility functions
		newClass.__cache = {}

		function newClass:is_a(className)
			return self:get_name() == className
		end

		function newClass:instance_of(className)
			if self.__cache["instance_of_" .. className] then
				return true
			end

			local iter = self
			while iter ~= nil do
				if iter:get_name() == class then
					self.__cache["instance_of_" .. class] = true

					return true
				end

				iter = iter.super
			end

			return false
		end

		function newClass:get_class()
			return LUA_CLASSES[self:get_name()]
		end

		function newClass:get_name()
			return self.__name
		end

		function newClass:valid_member(memberName)
			return self.__registry[memberName] and true or false
		end

		function newClass:member_getaccess(memberName)
			return self.__registry[memberName] and self.__registry[memberName].__members[memberName].access
		end

		function newClass:member_getluatype(memberName)
			return type(self.__registry[memberName] and self.__registry[memberName].__members[memberName].value)
		end

		function newClass:member_getmembertype(memberName)
			return self.__registry[memberName] and self.__registry[memberName].__members[memberName].membertype
		end

		function newClass:member_getargs(memberName)
			local reg =  self.__registry[memberName]

			if not reg then
				error(string.format("class %s: attempted to call member_getargs on invalid member '%s'", self:get_name(), memberName))
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
				print("no dbg or dbg.nparams for " .. memberName)
			end

			return arglist
		end

		function newClass:is_instance()
			return self.__instance
		end

		function newClass:duplicate(_table, _lookup_table)
			if _table == nil then
				_table = self
			end

			local copy = {}

			for i, v in pairs(_table) do
				if type(v) ~= "table" then
					copy[i] = rawget(_table, i)
				else
					_lookup_table = _lookup_table or {}
					_lookup_table[_table] = copy

					if _lookup_table[v] then
						copy[i] = _lookup_table[v] -- we already copied this table. reuse the copy.
					else
						copy[i] = self:duplicate(v,_lookup_table) -- not yet copied. copy it.
					end
				end
			end

			debug.setmetatable(copy, debug.getmetatable(_table))

			return copy
		end
	end

	do -- Build the registry and the reverse-registry.
		newClass.__registry = {}
		newClass.__functionality = {}

		local iter = newClass
		while iter ~= nil do
			for mName, mData in pairs(iter.__members) do
				-- This is important, we have to skip assignment if there is already a member found earlier
				-- or else we priorise parents above children.
				if not newClass.__registry[mName] then
					newClass.__registry[mName] = iter
				end

				-- Here we keep track of all functions this class or its parents contains, this can be used
				-- to check whether calls to protected functions came from this class or its parents.
				if type(mData.value) == "function" then
					newClass.__functionality[mData.value] = true
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
				if newClass:valid_member(memberName) then
					-- Check if the access modifiers match up.
					if newClass:member_getaccess(memberName) ~= interface:member_getaccess(memberName) then
						error(string.format("class %s is supposed to implement member '%s' with %s access, but it's specified with %s access in the class",
									className, memberName, interface_memberData.access,  newClass:member_getaccess(memberName)))
					end

					-- Check if the lua types match up.
					local interfaceLuaType = interface:member_getluatype(memberName)
					local classLuaType = newClass:member_getluatype(memberName)
					
					if classLuaType ~= interfaceLuaType then
						error(string.format("class %s is supposed to implement member '%s' as the '%s' lua_type, but it's specified as the '%s' lua_type in the class",
									className, memberName, interfaceLuaType, classLuaType))
					end

					-- Check if the variable types match up.
					local interfaceMemberType = interface:member_getmembertype(memberName)
					local classMemberType = newClass:member_getmembertype(memberName)
					
					if classMemberType ~= interfaceMemberType then
						error(string.format("class %s is supposed to implement member '%s' as the '%s' variable_type, but it's specified as the '%s' variable_type in the class",
									className, memberName, interfaceMemberType, classMemberType))
					end

					-- Check if the arguments match up.
					local interfaceArgs = interface:member_getargs(memberName)
					local classArgs = newClass:member_getargs(memberName)

					-- Check argument names.
					for k, v in pairs(interfaceArgs) do
						if not classArgs[k] then
							error(string.format("class %s is supposed to implement member function '%s' argument #%d with the name '%s'",
											className, memberName, k, v, k, classArgs[k]))
						end
						if classArgs[k] ~= v then
							error(string.format("class %s is supposed to implement member function '%s' argument #%d with the name '%s', but argument #%d is named '%s' instead",
											className, memberName, k, v, k, classArgs[k]))
						end
					end

					for k, v in pairs(classArgs) do
						if interfaceArgs[k] ~= v then
							error(string.format("class %s is not supposed to implement member function '%s' argument #%d named '%s': this argument isn't specified in the implemented interface '%s'",
											className, memberName, k, v, interfaceName))
						end
					end
				else
					error(string.format("class %s is missing interface definition: %s '%s' specified in interface isn't implemented",
							className, interface_memberData.access, memberName))
				end
			end
		else
			error(string.format("class %s attempted to implement non-existant interface '%s'", className, interfaceName))
		end
	end

	-- Store reference to our classdata in the registry.
	LUA_CLASSES[className] = newClass

	-- Setup the metatables on the class + all children
	local class = newClass
	while class ~= nil do
		setmetatable(class, classMT)

		class = class.super
	end
	
	-- Create a global that can be used to create a class instance, or to return the class data.
	_G[className] = newClass;

	--print(string.format("created new class: %s with superclass %s implementing %s", className, superClassName, implementsName))
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
		error(string.format("double setup of interface %s, failed to setup new interface", interfaceName))
	end

	-- Check for parent
	if superInterfaceName ~= nil and not LUA_INTERFACES[superInterfaceName] then
		error(string.format("parent for interface %s does not exist. failed to setup interface", interfaceName))
	end

	-- Setup the interface
	local newInterface = {}
	newInterface.__name = interfaceName
	newInterface.__members = {}

	-- Parse all variables in the public/protected/private tables.
	for mKey, m in pairs(creatorMembers) do
		newInterface.__members[mKey] = {
			value = m.value,
			access = m.access,
			membertype = m.membertype,
			fvalue = type(mVal) == "function" and 
				function(self, ...)
					return mVal(self.__registry[mKey], ...)
				end,
		}
	end

	-- Copy all members from the parent interface (if specified)
	local superInterface = LUA_INTERFACES[superInterfaceName]
	if superInterface then
		for mKey, mVal in pairs(superInterface.__members) do
			if newInterface.__members[mKey] then
				if newInterface.__members[mKey].access ~= superInterface.__members[mKey].access then
					error(string.format("interface %s has a member called '%s' specified as %s, but it's superinterface has this member specified as %s", interfaceName, mKey, superInterface.__access[mKey]))
				end
			else
				newInterface.__members[mKey] = superInterface.__members[mKey]
			end
		end
	end

	do -- Setup utility functions
		function newInterface:valid_member(memberName)
			return self.__members[memberName] and true or false
		end

		function newInterface:get_name()
			return self.__name
		end

		function newInterface:member_getaccess(memberName)
			return self.__members[memberName] and self.__members[memberName].access
		end

		function newInterface:member_getluatype(memberName)
			return type(self.__members[memberName] and self.__members[memberName].value)
		end

		function newInterface:member_getmembertype(memberName)
			return self.__members[memberName] and self.__members[memberName].membertype
		end

		function newInterface:member_getargs(memberName)
			local member =  self.__members[memberName]

			if not member then
				error(string.format("interface %s: attempted to call member_getargs on invalid member '%s'", self:get_name(), memberName))
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
				print("no dbg or dbg.nparams for " .. memberName)
			end

			return arglist
		end
	end

	-- Setup the metatable
	setmetatable(newInterface, interfaceMT)

	-- Store prepared classdata in the registry.
	LUA_INTERFACES[interfaceName] = newInterface

	--print(string.format("created new interface: %s with superclass %s", interfaceName, superInterfaceName))
end

do
	local creatorType, creatorData, creatorMembers
	
	local function addVariable(memberTable, memberType, varAccess)
		if not creatorMembers then
			error("defining members without any class specification")
		end

		if varAccess then -- If we have an ccess level defined, look through all statics which don't have one and set it.
			for mKey, mValue in pairs(creatorMembers) do
				if mValue.membertype == _static_ and not mValue.access then
					mValue.access = varAccess
				end
			end
		end

		for mKey, mValue in pairs(memberTable) do
			if creatorMembers[mKey] then
				error(string.format("double definition of member '%s' in class '%s'", mKey, creatorData["name"]))
			else
				creatorMembers[mKey] = {value = mValue, membertype = memberType, access = varAccess}
			end
		end
	end

	local executionTable = setmetatable({}, {
		__call = function(data)
			for mKey, mValue in pairs(data or {}) do
				if creatorMembers[mKey] then
					error(string.format("double definition of member '%s' in class '%s'", mKey, creatorData["name"]))
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
			if key == "register" then
				return self
			end

			if key == "public" or key == "protected" or key == "private" then
				local mAccess = 
							(key == "public" and _public_) or
							(key == "protected" and _protected_ ) or
							(key == "private" and _private_)

				return setmetatable({}, {
					__call = function(self, memberTable)
						addVariable(memberTable, _instance_, mAccess)
					end,

					__index = function(self, key)
						if key == "static" then
							return setmetatable({}, {
								__newindex = function(self, mKey, mValue)
									addVariable({[mKey] = mValue}, _static_, mAccess)
								end
							})
						end
					end,

					__newindex = function(self, mKey, mValue)
						addVariable({[mKey] = mValue}, _instance_, mAccess)
					end
				})
			end
		end,

		__newindex = function(self, key, value)
			error(string.format("attempting to add new member variable %s without an access specifier", key))
		end,
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
		function class(className, options)
			if creatorType or creatorData then
				error(string.format("unfinished class creation (didn't register previous class %s?)", creatorData["name"]))
			end

			-- Intialize class creation
			creatorType = "class"
			creatorData = {}
			creatorData["name"] = className
			creatorMembers = {}

			-- Parse options for alternative syntax
			if options then
				if options["extends"] then
					extends(options["extends"])
				end

				if options["implements"] then
					if type(options["implements"]) == "table" then
						for k, v in pairs(options["implements"]) do
							implements(v)
						end
					else
						implements(options["implements"])
					end
				end
			end

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
			if not memberTable then
				error("running public without any member table")
			end

			addVariable(memberTable, _instance_, _public_)
		end

		function protected(memberTable)
			if not memberTable then
				error("running public without any member table")
			end

			addVariable(memberTable, _instance_, _protected_)
		end

		function private(memberTable)
			if not memberTable then
				error("running public without any member table")
			end

			addVariable(memberTable, _instance_, _private_)
		end

		function static(memberTable)
			if not memberTable then
				error("running static without any member table")
			end

			addVariable(memberTable, _static_)
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