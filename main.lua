local helper = require("helper")
local screenManager = require("UI.screen")
local startScreen = require("UI.screens.start")
local playingScreen = require("UI.screens.playing")
local pausedScreen = require("UI.screens.paused")

local components

function love.load()
	love.window.setFullscreen(true, "desktop")

	-- Load components
	components = helper.import_folder("components")

	-- Initialize playing screen with components
	playingScreen:init(components)

	-- Register screens
	screenManager.register("start", startScreen)
	screenManager.register("playing", playingScreen)
	screenManager.register("paused", pausedScreen)

	screenManager.switchTo("playing", { duration = 0 })
end

function love.update(dt)
	screenManager.update(dt)
end

function love.draw()
	screenManager.draw()
end

function love.keypressed(key, scancode, isrepeat)
	screenManager.keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
	screenManager.keyreleased(key, scancode)
end

function love.mousepressed(x, y, button)
	screenManager.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
	screenManager.mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
	screenManager.mousemoved(x, y, dx, dy)
end

function love.wheelmoved(x, y)
	screenManager.wheelmoved(x, y)
end
