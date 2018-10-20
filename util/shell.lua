dofile("util/build.lua")

shell = {}

function shell:takeUserInput()
   io.flush()
   return io.read()
end

function shell:createMenu(optionsList, questionText)
	if questionText then
		print("------------------------------")
		print("-- " .. questionText .. "")
	end

	print("------------------------------")

	for k, v in pairs(optionsList) do
		print(string.format("%d. %s", k, v))
	end

	print("------------------------------")

	local choice
	repeat
		if choice then
			print("invalid option")
		end

		choice = tonumber(shell:takeUserInput())
	until optionsList[choice]

	return choice, optionsList[choice]
end

function shell:sleep(miliseconds)
	-- Sleep
	local command = build:getOS() == "windows" and ("ping 192.0.2.0 -n 1 -w " .. miliseconds .. " >nul") or ("sleep " .. (miliseconds / 1000))
	os.execute(command)
	--local handle = io.popen(command)
	--local result = handle:read("*a")
	--handle:close()
end