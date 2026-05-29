helper = {}

-- Set color using RGB values (0-255 range)
-- Can be called as:
--   setRGBColor(r, g, b, a) - direct RGB values
--   setRGBColor(colorTable, alpha) - color table {r, g, b} with optional alpha
function helper.setRGBColor(r, g, b, a)
	-- Check if first arg is a table (color from config)
	if type(r) == "table" then
		local color = r
		local alpha = g or 255  -- second arg becomes alpha when first is table
		love.graphics.setColor(color[1] / 255, color[2] / 255, color[3] / 255, alpha / 255)
	else
		a = a or 255
		love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
	end
end

function helper.clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

function helper.lerp(a, b, t)
	return a + (b - a) * t
end

function helper.map(value, inMin, inMax, outMin, outMax)
	return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin)
end

function helper.import_folder(folder_path)
	local modules = {}
	local files = love.filesystem.getDirectoryItems(folder_path)

	for _, file in ipairs(files) do
		if file:match("%.lua$") then
			local module_name = file:gsub("%.lua$", "")
			table.insert(modules, require(folder_path .. "." .. module_name))
		end
	end

	return modules
end

return helper
