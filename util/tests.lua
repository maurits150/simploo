dofile("util/luaunit.lua")

tests = {}

function tests:getSourceFiles()
	local files = {}
	local file, err = io.open("tests/sourcefiles.txt", "r")

	if not file then
		return false, "no sourcefiles.txt found"
	end

	local content = file:read("*all")
	file:close()

	for file in string.gmatch(content, "[^\r\n]+") do
		table.insert(files, file)
	end

	if #files == 0 then
		return false, "file list empty"
	end

	return files
end