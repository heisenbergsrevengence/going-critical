local grid = {}

function grid.create(Width, Height, gridSize, gridColor)
	gridSize = gridSize or 90
	gridColor = gridColor or { 0.8, 0.8, 0.8 }
	local canvas = love.graphics.newCanvas(Width, Height)

	love.graphics.setCanvas(canvas)
	love.graphics.clear()

	love.graphics.setColor(gridColor)
	love.graphics.setLineWidth(2)

	for x = 0, Width, gridSize do
		love.graphics.line(x, 0, x, Height)
	end

	for y = 0, Height, gridSize do
		love.graphics.line(0, y, Width, y)
	end

	love.graphics.setColor(1, 1, 1)
	love.graphics.setCanvas()
	return canvas
end

return grid
