build = {}


function build:getOS()
	local path = package.config:sub(1, 1)

	return path == "/" and "unix" or "windows"
end

function build:getSourceFiles()
	local files = {}
	local file, err = io.open("src/sourcefiles.txt", "r")

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

function build:mergeTargetFiles()
	local files, err = self:getSourceFiles()

	if not files then
		return false, tostring(err)
	end

	merger:setBasePath("src/")
	merger:setHeaderComment(BUILD_HEADER)
	merger:setInputFiles(files)
	local fileContent, err = merger:getMergedFiles()
	
	if not fileContent then
		return false, "merge failed: " .. tostring(err)
	end
	
	return fileContent
end

function build:execute(outputFile)
	local fileContent, err = build:mergeTargetFiles()

	if not fileContent then
		return false, tostring(err)
	end

	local file, err = io.open(outputFile, "w")
	
	if not file then
		return false, "failed to write output file: " .. tostring(err)
	end

	file:write(fileContent)
	file:flush()
	file:close()

	return true
end