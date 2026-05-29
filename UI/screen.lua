local tween = require("UI.tween")
local helper = require("helper")

local screenManager = {
	screens = {},
	current = nil,
	previous = nil,
	transitioning = false,
	transitionProgress = 0,
	transitionDuration = 0.3,
	transitionType = "fade",
}

-- Register a screen
function screenManager.register(name, screen)
	screenManager.screens[name] = screen
end

-- Switch to a screen with optional transition
function screenManager.switchTo(name, options)
	options = options or {}
	local newScreen = screenManager.screens[name]
	if not newScreen then
		print("Screen not found: " .. name)
		return
	end

	local duration = options.duration or 0.3
	local transition = options.transition or "fade"

	if screenManager.current and duration > 0 then
		-- Start transition
		screenManager.transitioning = true
		screenManager.transitionProgress = 0
		screenManager.transitionDuration = duration
		screenManager.transitionType = transition
		screenManager.previous = screenManager.current

		tween.to(screenManager, { transitionProgress = 1 }, duration, {
			easing = "inOutQuad",
			onComplete = function()
				screenManager.transitioning = false
				screenManager.previous = nil
				if newScreen.enter then
					newScreen:enter()
				end
			end
		})

		if screenManager.current.exit then
			screenManager.current:exit()
		end
		screenManager.current = newScreen
	else
		-- Instant switch
		if screenManager.current and screenManager.current.exit then
			screenManager.current:exit()
		end
		screenManager.current = newScreen
		if newScreen.enter then
			newScreen:enter()
		end
	end
end

-- Get current screen name
function screenManager.getCurrentName()
	for name, screen in pairs(screenManager.screens) do
		if screen == screenManager.current then
			return name
		end
	end
	return nil
end

-- Update current screen
function screenManager.update(dt)
	tween.update(dt)
	if screenManager.current and screenManager.current.update then
		screenManager.current:update(dt)
	end
end

-- Draw current screen with transition
function screenManager.draw()
	if screenManager.transitioning and screenManager.previous then
		-- Draw based on transition type
		if screenManager.transitionType == "fade" then
			-- Draw previous screen fading out
			love.graphics.setColor(1, 1, 1, 1 - screenManager.transitionProgress)
			if screenManager.previous.draw then
				screenManager.previous:draw()
			end

			-- Draw new screen fading in
			love.graphics.setColor(1, 1, 1, screenManager.transitionProgress)
			if screenManager.current.draw then
				screenManager.current:draw()
			end
		else
			-- Default: just draw current
			love.graphics.setColor(1, 1, 1, 1)
			if screenManager.current.draw then
				screenManager.current:draw()
			end
		end
	else
		love.graphics.setColor(1, 1, 1, 1)
		if screenManager.current and screenManager.current.draw then
			screenManager.current:draw()
		end
	end

	-- Reset color
	love.graphics.setColor(1, 1, 1, 1)
end

-- Forward input to current screen
function screenManager.keypressed(key, scancode, isrepeat)
	if screenManager.current and screenManager.current.keypressed then
		screenManager.current:keypressed(key, scancode, isrepeat)
	end
end

function screenManager.keyreleased(key, scancode)
	if screenManager.current and screenManager.current.keyreleased then
		screenManager.current:keyreleased(key, scancode)
	end
end

function screenManager.mousepressed(x, y, button)
	if screenManager.current and screenManager.current.mousepressed then
		screenManager.current:mousepressed(x, y, button)
	end
end

function screenManager.mousereleased(x, y, button)
	if screenManager.current and screenManager.current.mousereleased then
		screenManager.current:mousereleased(x, y, button)
	end
end

function screenManager.mousemoved(x, y, dx, dy)
	if screenManager.current and screenManager.current.mousemoved then
		screenManager.current:mousemoved(x, y, dx, dy)
	end
end

function screenManager.wheelmoved(x, y)
	if screenManager.current and screenManager.current.wheelmoved then
		screenManager.current:wheelmoved(x, y)
	end
end

return screenManager
