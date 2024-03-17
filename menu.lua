--[[
-- RUN THIS FILE WITH YOUR PREFERRED LUA BINARY TO BUILD SIMPLOO
--]]

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
	Copyright (c) 2016 maurits.tv
	
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
WATCHER_INTERVAL_MS = 300

--
-- Menu
--

menu = {}

function menu:init()
	while true do
		local action = shell:createMenu({
			"Build simpoo",
			"Start watching monitor + run code on change (io heavy!)",
			"Start watching monitor + runs tests on change",
			"Run tests",
			"Exit"
		}, "Choose an action")

		if action == 1 then
			self:build()
		elseif action == 2 then
			self:watch("run")
		elseif action == 3 then
			self:watch("test")
		elseif action == 4 then
			self:tests()
		elseif action == 5 then
			return
		end
	end
end

function menu:build()
	build:execute(DIST_FILE)

	print("build successful! See " .. DIST_FILE)
end

function menu:watch(mode)
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
					for i=0, 5 do
						print("--- RELOADING ---- [@ " .. os.clock() .. "]")
					end

					if mode == "test" then
						self:tests()
					elseif mode == "run" then
						self:run()
					end

					lastContent[name] = content
				end

				file:close()
			end
		end

		-- Force all discarded instances to be finalized constantly
        if collectgarbage then
            collectgarbage()
        end

		shell:sleep(WATCHER_INTERVAL_MS)
	end
end

function menu:run()
	local status, err = pcall(function()
		local files = build:getSourceFiles()

		for k, v in pairs(files) do
			dofile("src/" .. v)
		end
	end)

	if not status then
		print("[watch] failed: " .. tostring(err))
	end


end

function menu:tests()
	-- Execute test files
	local testfiles, err = tests:getSourceFiles()

	if not testfiles then
		print("[tests] no tests ran: " .. tostring(err))
	end

	for _, testproduction in pairs({false, true}) do -- Test in both production mode and non-production
		print("\n\n\n\n\n===================================================")
		print("== Running test with production mode " .. (testproduction and "ON" or "OFF"))
		print("===================================================")

		for k, v in pairs(testfiles) do
			-- Wipe simploo reference
			simploo = nil

			Test = {}

			-- Run the simploo files
			local simploofiles, err = build:getSourceFiles()

			if not simploofiles then
				print("[exec] failed: " .. tostring(err))
			end

			for k, name in pairs(simploofiles) do
				local file, err = io.open("src/" .. name, "r")

				if file then
					local status, err = pcall(function()
						dofile("src/" .. name)
					end)

					if not status then
						print("[exec] failed: " .. tostring(err))
					end

					file:close()
				end
			end

			-- Set production mode
			simploo.config["production"] = testproduction

			-- Execute the test files
			dofile("tests/" .. v)

			-- Run luaunit
			LuaUnit:run("Test")
		end
	end
end

menu:init()
