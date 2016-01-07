merger = {}
merger.header = ""
merger.basePath = ""
merger.inputFiles = {}
merger.outputFile = ""

function merger:setBasePath(basePath)
	self.basePath = basePath
end

function merger:setHeaderComment(headerComment)
	self.headerComment = headerComment
end

function merger:setInputFiles(fileList)
	self.inputFiles = fileList
end

function merger:getMergedFiles()
	local content = "--[[\n"
	content = content .. self.headerComment
	content = content .. "]]"

	for k, v in pairs(self.inputFiles) do
		local file, err = io.open(self.basePath .. v, "r")

		if file then
			if content ~= "" then
				content = content .. "\n\n"
			end

			content = content .. "----\n---- " .. v .. "\n----\n\n";
			content = content .. file:read("*all")

			file:close()
		end
	end

	return content
end