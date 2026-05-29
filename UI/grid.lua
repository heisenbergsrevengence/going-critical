local helper = require("helper")
local config = require("config")

local grid = {}

function grid.create(Width, Height, gridSize, gridColor)
	gridSize = gridSize or config.grid.size
	local canvas = love.graphics.newCanvas(Width, Height)

	love.graphics.setCanvas(canvas)
	love.graphics.clear()

	helper.setRGBColor(config.colors.gridLines)
	love.graphics.setLineWidth(2)

	for x = 0, Width, gridSize do
		love.graphics.line(x, 0, x, Height)
	end

	for y = 0, Height, gridSize do
		love.graphics.line(0, y, Width, y)
	end

	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1)
	return canvas
end

return grid
