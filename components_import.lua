-- just returns the list of component modules
local function import_folder(folder_path)
	local modules = {}
	local files = love.filesystem.getDirectoryItems(folder_path)

	for _, file in ipairs(files) do
		if file:match("%.lua$") then
			local module_name = file:gsub("%.lua$", "")
			modules[module_name] = require(folder_path .. "." .. module_name)
		end
	end

	return modules
end

return import_folder("./components")
