local element = require("UI.element")
local helper = require("helper")
local config = require("config")
local screenManager = require("UI.screen")

local start = {
	title = nil,
	startButton = nil,
	buttonHovered = false,
	titleY = 0,
	buttonOpacity = 0,
}

function start:enter()
	local w, h = love.graphics.getDimensions()

	-- Title starts above screen and slides down
	self.titleY = -100
	self.buttonOpacity = 0

	-- Animate title sliding in
	local titleTarget = { y = h * 0.3 }
	local tweenModule = require("UI.tween")
	tweenModule.to(self, { titleY = titleTarget.y }, 0.6, {
		easing = "outBack",
		onComplete = function()
			-- After title lands, fade in button
			tweenModule.to(self, { buttonOpacity = 255 }, 0.4, { easing = "outQuad" })
		end
	})
end

function start:exit()
	-- Could add exit animations here
end

function start:update(dt)
	local mx, my = love.mouse.getPosition()
	local w, h = love.graphics.getDimensions()

	-- Button bounds
	local btnW, btnH = 200, 60
	local btnX = (w - btnW) / 2
	local btnY = h * 0.55

	self.buttonHovered = mx >= btnX and mx <= btnX + btnW
		and my >= btnY and my <= btnY + btnH
		and self.buttonOpacity > 100
end

function start:draw()
	local w, h = love.graphics.getDimensions()

	-- Background
	helper.setRGBColor(config.colors.uiBackground)
	love.graphics.rectangle("fill", 0, 0, w, h)

	-- Title
	local titleFont = love.graphics.newFont(48)
	love.graphics.setFont(titleFont)
	helper.setRGBColor(config.colors.blue)
	local titleText = "Going Critical"
	local titleWidth = titleFont:getWidth(titleText)
	love.graphics.print(titleText, (w - titleWidth) / 2, self.titleY)

	-- Start button
	local btnW, btnH = 200, 60
	local btnX = (w - btnW) / 2
	local btnY = h * 0.55

	-- Button background
	if self.buttonHovered then
		helper.setRGBColor(config.colors.blueHover, self.buttonOpacity) -- darker blue on hover
	else
		helper.setRGBColor(config.colors.blue, self.buttonOpacity)
	end
	love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 8, 8)

	-- Button border
	helper.setRGBColor(config.colors.blueDark, self.buttonOpacity)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 8, 8)

	-- Button text
	local btnFont = love.graphics.newFont(24)
	love.graphics.setFont(btnFont)
	helper.setRGBColor(config.colors.white, self.buttonOpacity)
	local btnText = "Start"
	local btnTextWidth = btnFont:getWidth(btnText)
	local btnTextHeight = btnFont:getHeight()
	love.graphics.print(btnText, btnX + (btnW - btnTextWidth) / 2, btnY + (btnH - btnTextHeight) / 2)

	-- Reset
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(love.graphics.newFont(12))
end

function start:mousepressed(x, y, button)
	if button ~= 1 then return end
	if self.buttonOpacity < 100 then return end

	local w, h = love.graphics.getDimensions()
	local btnW, btnH = 200, 60
	local btnX = (w - btnW) / 2
	local btnY = h * 0.55

	if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
		screenManager.switchTo("playing", { transition = "fade", duration = 0.4 })
	end
end

function start:keypressed(key)
	if key == "return" or key == "space" then
		if self.buttonOpacity > 100 then
			screenManager.switchTo("playing", { transition = "fade", duration = 0.4 })
		end
	end
end

return start
