local screenWidth, screenHeight
local gridModule = require("grid")
local components = require("components_import")

function love.load()
	love.graphics.setBackgroundColor(0.9, 0.9, 0.9)
	love.window.setFullscreen(true, "desktop")
	screenWidth, screenHeight = love.graphics.getDimensions()

	GridCanvas = gridModule.create(screenWidth, screenHeight)
end

function love.draw()
	love.graphics.draw(GridCanvas, 0, 0)
end
