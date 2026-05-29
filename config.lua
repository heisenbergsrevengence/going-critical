local config = {}

-- Color scheme (RGB values 0-255)
config.colors = {
	-- Primary colors
	blue = { 47, 141, 252 },
	blueDark = { 30, 100, 200 },
	blueHover = { 37, 120, 220 },

	-- UI colors
	uiBackground = { 237, 232, 208 }, -- soft white
	gridBackground = { 229.5, 229.5, 229.5 }, -- grey
	gridLines = { 200, 200, 200 },

	-- Text colors
	white = { 255, 255, 255 },
	black = { 0, 0, 0 },

	-- Grey shades
	grey = { 115, 115, 115 },
	greyLight = { 100, 100, 100 },
	greyMedium = { 150, 150, 150 },
	greyDark = { 200, 200, 200 },

	-- Status colors
	invalid = { 200, 60, 60 }, -- red for errors/invalid states
}

-- Grid and layout constants
config.grid = {
	size = 90, -- grid cell size in pixels
}

config.sidebar = {
	width = 130,
}

config.camera = {
	minZoom = 0.25,
	maxZoom = 2,
	zoomFactor = 1.1,
}

-- Helper function to get color with optional alpha
function config.getColor(colorName, alpha)
	local color = config.colors[colorName]
	if not color then
		return { 255, 255, 255 } -- default to white if not found
	end
	if alpha then
		return { color[1], color[2], color[3], alpha }
	end
	return color
end

return config
