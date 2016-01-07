dofile("util/build.lua")
dofile("util/shell.lua")
dofile("util/merger.lua")
dofile("util/tests.lua")
dofile("util/misc.lua")

--
-- Globals
--

BUILD_HEADER = [[
	SIMPLOO - Simple Lua Object Orientation

	The MIT License (MIT)
	Copyright (c) 2014 maurits.tv
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the \"Software\"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
]]

DIST_FILE = "dist/simploo.lua"

WATCHER_INTERVAL_MS = 100

--
-- Menu
--

menu = {}

function menu:init()
	while true do
		local action = shell:createMenu({
			"Build simpoo",
			"Start watching monitor (continuous merge and execute on change - io heavy!)",
			"Run tests",
			"Exit"
		}, "Choose an action")

		if action == 1 then
			self:build()
		elseif action == 2 then
			self:watch()
		elseif action == 3 then
			self:tests()
		elseif action == 4 then
			return
		end
	end
end

function menu:build()
	build:execute(DIST_FILE)

	print("build successful! See " .. DIST_FILE)
end

function menu:watch()
	print("Watching..")

	local lastContent = {}

	while true do
		local files, err = build:getSourceFiles()

		if not files then
			print("[watch] failed: " .. tostring(err))
		end

		for k, name in pairs(files) do
			local file, err = io.open("src/" .. name, "r")

			if file then
				local content = file:read("*all")

				if not lastContent[name] then -- First boot
					lastContent[name] = content
				elseif lastContent[name] ~= content then
					for i=0, 10 do
						print()
					end
					
					local status, err = pcall(function()
						local files = build:getSourceFiles()

						for k, v in pairs(files) do
							dofile("src/" .. v)
						end
					end)

					if not status then
						print("[watch] failed: " .. tostring(err))
					end

					lastContent[name] = content
				end

				file:close()
			end
		end

		--[[
		-- Do watch
		local fileContent, err = build:mergeTargetFiles()

		if not fileContent then
			print("[watch] failed: " .. tostring(err))
		end
		
		if fileContent ~= lastContent then
			-- Execute simploo!
			local status, err = pcall(function()
				print("[watch] reloading!")
				loadstring(fileContent)()
			end)

			if not status then
				print("[watch] failed: " .. tostring(err))
			end
		end

		lastContent = fileContent
		]]

		-- Force all discarded instances to be finalized constantly
        if collectgarbage then
            collectgarbage()
        end

		shell:sleep(WATCHER_INTERVAL_MS)
	end
end

function menu:tests()
	-- Execute test files
	local files, err = tests:getSourceFiles()

	if not files then
		print("[tests] no tests ran: " .. tostring(err))
	end

	for k, v in pairs(files) do
		-- Execute simploo files
		simploo = nil
		
		local files, err = build:getSourceFiles()

		if not files then
			print("[exec] failed: " .. tostring(err))
		end

		for k, name in pairs(files) do
			local file, err = io.open("src/" .. name, "r")

			if file then
				local content = file:read("*all")

				local status, err = pcall(function()
					dofile("src/" .. name)
				end)

				if not status then
					print("[exec] failed: " .. tostring(err))
				end

				file:close()
			end
		end

		-- Execute the test file
		dofile("tests/" .. v)
	end
end

menu:init()
