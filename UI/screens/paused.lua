local helper = require("helper")
local config = require("config")
local screenManager = require("UI.screen")

local paused = {
	overlayOpacity = 0,
	buttonOpacity = 0,
	resumeHovered = false,
	quitHovered = false,
}

function paused:enter()
	self.overlayOpacity = 0
	self.buttonOpacity = 0

	local tween = require("UI.tween")
	tween.to(self, { overlayOpacity = 180 }, 0.2, {
		easing = "outQuad",
		onComplete = function()
			tween.to(self, { buttonOpacity = 255 }, 0.2, { easing = "outQuad" })
		end
	})
end

function paused:exit()
	self.overlayOpacity = 0
	self.buttonOpacity = 0
end

function paused:getButtonBounds()
	local w, h = love.graphics.getDimensions()
	local btnW, btnH = 200, 50
	local btnX = (w - btnW) / 2
	local resumeY = h * 0.45
	local quitY = h * 0.55
	return btnX, resumeY, quitY, btnW, btnH
end

function paused:update(dt)
	local mx, my = love.mouse.getPosition()
	local btnX, resumeY, quitY, btnW, btnH = self:getButtonBounds()

	self.resumeHovered = mx >= btnX and mx <= btnX + btnW
		and my >= resumeY and my <= resumeY + btnH
		and self.buttonOpacity > 100

	self.quitHovered = mx >= btnX and mx <= btnX + btnW
		and my >= quitY and my <= quitY + btnH
		and self.buttonOpacity > 100
end

function paused:draw()
	local w, h = love.graphics.getDimensions()

	-- Draw playing screen underneath
	local playingScreen = screenManager.screens["playing"]
	if playingScreen and playingScreen.draw then
		playingScreen:draw()
	end

	-- Dark overlay
	helper.setRGBColor(config.colors.black, self.overlayOpacity) -- semi-transparent black
	love.graphics.rectangle("fill", 0, 0, w, h)

	-- Paused text
	local titleFont = love.graphics.newFont(36)
	love.graphics.setFont(titleFont)
	helper.setRGBColor(config.colors.uiBackground, self.buttonOpacity)
	local titleText = "PAUSED"
	local titleWidth = titleFont:getWidth(titleText)
	love.graphics.print(titleText, (w - titleWidth) / 2, h * 0.3)

	-- Buttons
	local btnX, resumeY, quitY, btnW, btnH = self:getButtonBounds()
	local btnFont = love.graphics.newFont(20)
	love.graphics.setFont(btnFont)

	-- Resume button
	self:drawButton(btnX, resumeY, btnW, btnH, "Resume", self.resumeHovered)

	-- Quit to Menu button
	self:drawButton(btnX, quitY, btnW, btnH, "Quit to Menu", self.quitHovered)

	-- Reset
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(love.graphics.newFont(12))
end

function paused:drawButton(x, y, w, h, text, hovered)
	-- Button background
	if hovered then
		helper.setRGBColor(config.colors.blueHover, self.buttonOpacity) -- darker blue on hover
	else
		helper.setRGBColor(config.colors.blue, self.buttonOpacity)
	end
	love.graphics.rectangle("fill", x, y, w, h, 6, 6)

	-- Button border
	helper.setRGBColor(config.colors.blueDark, self.buttonOpacity)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, w, h, 6, 6)

	-- Button text
	helper.setRGBColor(config.colors.white, self.buttonOpacity)
	local font = love.graphics.getFont()
	local textWidth = font:getWidth(text)
	local textHeight = font:getHeight()
	love.graphics.print(text, x + (w - textWidth) / 2, y + (h - textHeight) / 2)
end

function paused:mousepressed(x, y, button)
	if button ~= 1 then return end
	if self.buttonOpacity < 100 then return end

	local btnX, resumeY, quitY, btnW, btnH = self:getButtonBounds()

	-- Resume button
	if x >= btnX and x <= btnX + btnW and y >= resumeY and y <= resumeY + btnH then
		screenManager.switchTo("playing", { transition = "fade", duration = 0.2 })
		return
	end

	-- Quit button
	if x >= btnX and x <= btnX + btnW and y >= quitY and y <= quitY + btnH then
		screenManager.switchTo("start", { transition = "fade", duration = 0.3 })
		return
	end
end

function paused:keypressed(key)
	if key == "escape" then
		screenManager.switchTo("playing", { transition = "fade", duration = 0.2 })
	end
end

return paused
