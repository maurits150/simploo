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
local _final_ = "FinalMember"

--[[
	Copies a table and it's metatable
]]

local function duplicateTable(_table, _lookup_table)
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
				copy[i] = duplicateTable(v,_lookup_table) -- not yet copied. copy it.
			end
		end
	end

	debug.setmetatable(copy, debug.getmetatable(_table))

	return copy
end

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
		class.___instance = true

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
		local str = string.format("LuaClass: %s <%s> {%s}", self:get_name(), self.___instance and "instance" or "class", tostring(self):sub(8))

		-- Enable our metatable again.
		setmetatable(self, mt)

		-- Return string.
		return str
	end,

	__call = function(self, ...)
		-- When we call class instances, we actually call their constructors
		-- When not an instance, we create a new instance.
		if self:is_instance() then
			for _, constructorName in pairs({self:get_name(), "__construct"}) do
				if self:valid_member(constructorName) then
					if self:member_getaccess(constructorName) ~= _public_ then
						error(string.format("cannot create instance of class %s: constructor function '%s': access level is not public", constructorName, self:get_name()))
					else
						return self[constructorName] and self[constructorName](self, ...)
					end
				end
			end

			if self.super then
				return self.super(self.super, ...)
			else
				-- No parent constructor and no local constructor, so there's nothing to return.
			end
		else
			return createClassInstance(self:get_name(), ...)
		end
	end;

	__index = function(self, mKey)
		if mKey == "super" then
			return rawget(self, "___super")
		elseif mKey == "___super" or mKey == "___name" then
			error(string.format("invalid read access to hidden class member '%s'", mKey))
		elseif mKey == "___members" or mKey == "___registry" or mKey == "___cache" or mKey == "___functionality" then
			error(string.format("invalid read access to hidden class member '%s'", mKey))
		end

		local locationClass = self.___registry[mKey]
		if locationClass then
			local access = locationClass.___members[mKey].access
			local static = locationClass.___members[mKey].static
			local value = locationClass.___members[mKey].fvalue or locationClass.___members[mKey].value

			if self.___instance  and static then -- Redirect to global class.
				return self:get_class()[mKey]
			end

			if access == _public_ then
				return value
			elseif access == _protected_ then
				local stackLevel = static and 3 or 2
				local info = debug.getinfo(stackLevel, "nf")
				local name = info and info.name or "unknown"
				local func = info and info.func

				-- The below functions check used to be using the callInfo.name to look up the class members direct, but debug.getinfo(2).name
				-- seems to return incorrect values, when used to lookup functions that directly return protected class member calls.
				-- This seems to be a lua bug. So now we just make a table that uses the actual functions as keys, which is hopefully just as
				-- well performing as we don't want to iterate through all members to see if it matches the 2nd stack function.
				if (not info and static) -- This means that this static call isn't a call redirected from within an instance (since frame nr.4 is nonexistent), so it should always be allowed.
					or locationClass == self or self.___functionality[func] then
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
			error(string.format("inside class <%s>: invalid write access to class member '%s': super is a reserved keyword", tostring(self), mKey))
		elseif mKey == "___name" or mKey == "___super" or
				mKey == "___members" or mKey == "___registry" or mKey == "___cache" or mKey == "___functionality" then
			error(string.format("inside class <%s>: invalid write access to hidden class member '%s': these variables are used internally", tostring(self), mKey))
		end

		local locationClass = self.___registry[mKey]

		if locationClass then
			local access = locationClass.___members[mKey].access
			local static = locationClass.___members[mKey].static
			local final = locationClass.___members[mKey].final

			if final then
				error(string.format("inside class <%s>: invalid write access to class member '%s': member is final", tostring(self), mKey))
			end

			if self.___instance and static then  -- Redirect to global class.
				self:get_class()[mKey] = mValue

				return
			end

			if access == _public_ then
				locationClass.___members[mKey].value = mValue
				locationClass.___members[mKey].fvalue = type(mVal) == "function" and 
					function(self, ...)
						return mVal(self.___registry[mKey], ...)
					end

				return
			elseif access == _protected_ then
				local stackLevel = static and 3 or 2
				local info = debug.getinfo(stackLevel, "nf")
				local name = info and info.name or "unknown"
				local func = info and info.func

				-- The below functions check used to be using the callInfo.name to look up the class members direct, but debug.getinfo(2).name
				-- seems to return incorrect values, when used to lookup functions that directly return protected class member calls.
				-- This seems to be a lua bug. So now we just make a table that uses the actual functions as keys, which is hopefully just as
				-- well performing as we don't want to iterate through all members to see if it matches the 2nd stack function.
				if (not info and static) -- This means that this static call isn't a call redirected from within an instance (since frame nr.4 is nonexistent), so it should always be allowed.
					or locationClass == self or self.___functionality[func] then
					locationClass.___members[mKey].value = mValue
					locationClass.___members[mKey].fvalue = type(mVal) == "function" and 
						function(self, ...)
							return mVal(self.___registry[mKey], ...)
						end

					return
				else
					error(string.format("invalid set access attempt to protected member '%s' located in <%s> via <%s> function '%s' (check nr. 3 in stack trace)", mKey, tostring(locationClass.locationClass), tostring(self), name))
				end
			elseif access == _private_ then
				if locationClass == self then
					locationClass.___members[mKey].value = mValue
					locationClass.___members[mKey].fvalue = type(mVal) == "function" and 
						function(self, ...)
							return mVal(self.___registry[mKey], ...)
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
	local finalClass = creatorData["final"]

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

	-- Check if superclass isn't final
	if superClassName ~= nil and LUA_CLASSES[superClassName]:is_final() then
		error(string.format("class %s cannot extend from class %s, class is final", className, superClassName))
	end

	local newClass = {}
	newClass.___name = className
	newClass.___final = finalClass
	
	do -- Setup class data.
		-- Setup members
		-- Setup the members metatable, that redirects all calls to static members to the class.
		newClass.___members = {}
		for mKey, mData in pairs(creatorMembers) do
			local mValue = mData.value;
			local mAccess = (mData.modifiers[_public_] and _public_) or
					(mData.modifiers[_protected_] and _protected_) or
					(mData.modifiers[_private_] and _private_) or
					_private_ -- default value without keywords
			local mStatic = mData.modifiers[_static_] and true or false;
			local mFinal = mData.modifiers[_final_] and true or false;

			newClass.___members[mKey] = {
				value = mValue,
				access = mAccess,
				static = mStatic,
				final = mFinal,
				fvalue = type(mData.valu) == "function" and 
					function(self, ...)
						return mData.valu(self.___registry[mKey], ...)
					end,
			}
		end

		-- Define the super class.
		if LUA_CLASSES[superClassName] then
			-- We do NOT DUPLICATE HERE
			-- If we did, static variables wouldn't work because each class would have a different instance of the superclass.
			-- The super class will still be duplicates when we initialize a new instance, because :duplicate() would traverse up and copy the ___super table too
			newClass.___super =  LUA_CLASSES[superClassName]
		end

		-- Add a variable that will be set to true on instances.
		newClass.___instance = false
	end

	do -- Setup utility functions
		newClass.___cache = {}

		function newClass:is_a(className)
			return self:get_name() == className
		end

		function newClass:instance_of(className)
			if self.___cache["instance_of_" .. className] then
				return true
			end

			local iter = self
			while iter ~= nil do
				if iter:get_name() == class then
					self.___cache["instance_of_" .. class] = true

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
			return self.___name
		end

		function newClass:is_final()
			return self.___final
		end

		function newClass:valid_member(memberName)
			return self.___registry[memberName] and true or false
		end

		function newClass:member_getaccess(memberName)
			return self.___registry[memberName] and self.___registry[memberName].___members[memberName].access
		end

		function newClass:member_getluatype(memberName)
			return type(self.___registry[memberName] and self.___registry[memberName].___members[memberName].value)
		end

		function newClass:is_static(memberName)
			return self.___registry[memberName] and self.___registry[memberName].___members[memberName].static
		end

		function newClass:member_getargs(memberName)
			local reg =  self.___registry[memberName]

			if not reg then
				error(string.format("class %s: attempted to call member_getargs on invalid member '%s'", self:get_name(), memberName))
			end

			local value = reg.___members[memberName].value

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
			return self.___instance
		end

		function newClass:duplicate(_table, _lookup_table)
			return duplicateTable(self)
		end
	end

	do -- Build the registry and the reverse-registry.
		newClass.___registry = {}
		newClass.___functionality = {}

		local iter = newClass
		while iter ~= nil do
			for mName, mData in pairs(iter.___members) do
				-- This is important, we have to skip assignment if there is already a member found earlier
				-- or else we priorise parents above children.
				if not newClass.___registry[mName] then
					newClass.___registry[mName] = iter
				end

				-- Here we keep track of all functions this class or its parents contains, this can be used
				-- to check whether calls to protected functions came from this class or its parents.
				if type(mData.value) == "function" then
					newClass.___functionality[mData.value] = true
				end
			end
			
			iter = rawget(iter, "___super")
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
					local interfaceMemberStatic = interface:is_static(memberName)
					local classMemberStatic = newClass:is_static(memberName)
					
					if classMemberStatic ~= interfaceMemberStatic then
						error(string.format("class %s is supposed to implement member '%s' as a '%s' member, but it's specified as the '%s' variable_type in the class",
									className, memberName, interfaceMemberStatic and "static" or "instance", classMemberStatic and "static" or "instance"))
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
	_G[className] = newClass

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
			return self.___members
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
	local implementsList = creatorData["implements"]
	local finalInterface = creatorData["final"]
	
	-- Check for double
	if LUA_INTERFACES[interfaceName] then
		error(string.format("double setup of interface %s, failed to setup new interface", interfaceName))
	end

	-- Check for parent
	if superInterfaceName ~= nil and not LUA_INTERFACES[superInterfaceName] then
		error(string.format("parent for interface %s does not exist. failed to setup interface", interfaceName))
	end

	-- Check if superinterface isn't final
	if superInterfaceName ~= nil and LUA_INTERFACES[superInterfaceName]:is_final() then
		error(string.format("interface %s cannot extend from class %s: class is final", interfaceName, superInterfaceName))
	end

	-- Check if an interface isn't trying to implement an interface....
	if implementsList then
		error(string.format("interface %s cannot implement other interfaces", interfaceName))
	end


	-- Setup the interface
	local newInterface = {}
	newInterface.___name = interfaceName
	newInterface.___members = {}
	newInterface.___final = finalInterface

	-- Parse all variables in the public/protected/private tables.
	for mKey, mData in pairs(creatorMembers) do
		local mValue = mData.value;
		local mAccess = (mData.modifiers[_public_] and _public_) or
				(mData.modifiers[_protected_] and _protected_) or
				(mData.modifiers[_private_] and _private_) or
				_private_
		local mStatic = mData.modifiers[_static_] and true or false;
		local mFinal = mData.modifiers[_final] and true or false;

		newInterface.___members[mKey] = {
			value = mValue,
			access = mAccess,
			static = mStatic,
			final = mFinal,
			fvalue = type(mData.valu) == "function" and 
				function(self, ...)
					return mData.valu(self.___registry[mKey], ...)
				end,
		}
	end

	-- Copy all members from the parent interface (if specified)
	local superInterface = LUA_INTERFACES[superInterfaceName]
	if superInterface then
		for mKey, mVal in pairs(superInterface.___members) do
			if newInterface.___members[mKey] then
				if newInterface.___members[mKey].access ~= superInterface.___members[mKey].access then
					error(string.format("interface %s has a member called '%s' specified as %s, but it's superinterface has this member specified as %s", interfaceName, mKey, superInterface.___access[mKey]))
				end
			else
				newInterface.___members[mKey] = superInterface.___members[mKey]
			end
		end
	end

	do -- Setup utility functions
		function newInterface:valid_member(memberName)
			return self.___members[memberName] and true or false
		end

		function newInterface:get_name()
			return self.___name
		end

		function newInterface:member_getaccess(memberName)
			return self.___members[memberName] and self.___members[memberName].access
		end

		function newInterface:member_getluatype(memberName)
			return type(self.___members[memberName] and self.___members[memberName].value)
		end

		function newInterface:is_static(memberName)
			return self.___members[memberName] and self.___members[memberName].static
		end

		function newInterface:is_final()
			return self.___final
		end

		function newInterface:member_getargs(memberName)
			local member =  self.___members[memberName]

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
	
	local function defineVariable(dataTable, modifierTable)
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

	local function recursiveModifiers(key, onfinished, _modifiers)
		local _modifiers = _modifiers or {}

		return setmetatable({}, {
			__index = function(self, key)
				if key == "public" then
					_modifiers[_public_] = true

					return recursiveModifiers(key, onfinished, _modifiers)
				elseif key == "protected" then
					_modifiers[_protected_] = true

					return recursiveModifiers(key, onfinished, _modifiers)
				elseif key == "private" then
					_modifiers[_private_] = true

					return recursiveModifiers(key, onfinished, _modifiers)
				elseif key == "static" then
					_modifiers[_static_] = true

					return recursiveModifiers(key, onfinished, _modifiers)
				elseif key == "final" then
					_modifiers[_final_] = true

					return recursiveModifiers(key, onfinished, _modifiers)
				else
					error(string.format('invalid keyword: %s', key))
				end
			end,

			__newindex = function(self, key, value)
				onfinished(_modifiers, key, value)
			end,

			__call = function(self, table)
				for k, v in pairs(table) do
					onfinished(_modifiers, k, v)
				end
			end,
		})
	end

	local function compileMembers(data, _results, _modifiers)
		if not _results then
			local results = {}
			local modifiers = {}

			compileMembers(data, results, modifiers)

			return results;
		else
			if data["___members"] then
				for _, pKey in pairs(data["___modifiers"]) do
					_modifiers[pKey] = true
				end


				for mKey, mVal in pairs(data["___members"]) do
					if _results[mKey] then
						error('double usage of variable ' .. mKey)
					end

					_results[mKey] = {value = mVal, modifiers = duplicateTable(_modifiers)}
				end

				for childNum, childVal in pairs(data["___children"]) do
					compileMembers(childVal, _results, _modifiers)
				end


				for _, pKey in pairs(data["___modifiers"]) do
					_modifiers[pKey] = nil
				end
			end
		end
	end

	local classSetupMembersCall = setmetatable({}, {
		__call = function(self, data)
			if data then
				local wrapper = defineVariable(data, {})
				creatorMembers = compileMembers(wrapper)
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
			else
				local t = recursiveModifiers(key, function(modifierTable, mKey, mVal)
					creatorMembers[mKey] = {value = mVal, modifiers = duplicateTable(modifierTable)}
				end)

				return t[key]
			end
		end,

		__newindex = function(self, key, value)
			local t = recursiveModifiers(key, function(modifierTable, mKey, mVal)
				creatorMembers[mKey] = {value = mVal, modifiers = duplicateTable(modifierTable)}
			end)

			t[key] = value
		end,
	})
	
	do -- Class/interface creation functions
		function class(className, opt)
			if creatorType or creatorData then
				error(string.format("unfinished class creation (didn't register previous class %s?)", creatorData["name"]))
			end

			-- Intialize class creation
			creatorType = "class"
			creatorData = {}
			creatorData["name"] = className
			creatorMembers = {}

			-- Parse options for alternative syntax
			if opt then
				options(opt)
			end

			return classSetupMembersCall
		end

		function interface(interfaceName)
			creatorType = "interface"
			creatorData = {}
			creatorData["name"] = interfaceName
			creatorMembers = {}

			return classSetupMembersCall
		end

		function extends(s)
			if creatorType == "class" then
				creatorData["super"] = s
			elseif creatorType == "interface" then
				creatorData["super"] = s
			else
				error("extending on nothing - make sure you called class() first")
			end
			
			return classSetupMembersCall
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
				error("implementing on nothing - make sure you called class() first")
			end

			return classSetupMembersCall
		end

		function options(options)
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

			if options["final"] then
				final()
			end

			return classSetupMembersCall
		end
	end

	do -- Member variable functions
		function public(rawMemberTable)
			if not rawMemberTable then
				error("running public keyword without value")
			end

			return defineVariable(rawMemberTable, {_public_})
		end

		function protected(rawMemberTable)
			if not rawMemberTable then
				error("running protected keyword without value")
			end

			return defineVariable(rawMemberTable, {_protected_})
		end

		function private(rawMemberTable)
			if not rawMemberTable then
				error("running private keyword without value")
			end

			return defineVariable(rawMemberTable, {_private_})
		end

		function static(rawMemberTable)
			if not rawMemberTable then
				error("running static keyword without value")
			end

			return defineVariable(rawMemberTable, {_static_})
		end
	end

	do -- Either to set modifiers of a class, OR to set modifiers of a class member
		function final(rawMemberTable)
			if rawMemberTable then -- We're making class members final
				return defineVariable(rawMemberTable, {_final_})
			else -- We're making a class final
				if not creatorType then
					error("setting final on nothing - make sure you called class() first")
				end

				creatorData["final"] = true

				return classSetupMembersCall
			end
		end
	end
end
