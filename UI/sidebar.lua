local element = require("UI.element")
local helper = require("helper")
local config = require("config")
local dragdrop = require("UI.dragdrop")

local sidebar = {}
sidebar.__index = sidebar
setmetatable(sidebar, { __index = element })

function sidebar.new(props)
	props = props or {}
	local self = element.new(props)
	setmetatable(self, sidebar)

	-- Filter out pipe from sidebar (it's spawned from ports)
	self.components = {}
	for _, comp in ipairs(props.components or {}) do
		if comp.name ~= "pipe" then
			table.insert(self.components, comp)
		end
	end

	self.padding = 15
	self.cardHeight = 90
	self.hoveredCard = nil

	-- Scrolling
	self.scrollY = 0
	self.targetScrollY = 0
	self.scrollSpeed = 12 -- animation speed multiplier
	self.scrollWheelSpeed = 40 -- pixels per scroll tick

	return self
end

-- Calculate total content height
function sidebar:getContentHeight()
	local count = #self.components
	return self.padding + (self.cardHeight + self.padding) * count
end

-- Calculate max scroll (how far down we can scroll)
function sidebar:getMaxScroll()
	local contentHeight = self:getContentHeight()
	local viewHeight = self.height
	return math.max(0, contentHeight - viewHeight)
end

function sidebar:getCardBounds(index)
	local cardW = self.width - self.padding * 2
	local cardH = self.cardHeight
	local cardX = self.x + self.padding
	local cardY = self.y + self.padding + (cardH + self.padding) * (index - 1) - self.scrollY
	return cardX, cardY, cardW, cardH
end

function sidebar:getCardAtPoint(px, py)
	-- Check if point is within sidebar bounds
	if px < self.x or px > self.x + self.width or py < self.y or py > self.y + self.height then
		return nil, nil
	end

	for i, component in ipairs(self.components) do
		local cardX, cardY, cardW, cardH = self:getCardBounds(i)
		-- Only return if card is visible (within sidebar bounds)
		if cardY + cardH > self.y and cardY < self.y + self.height then
			if px >= cardX and px <= cardX + cardW and py >= cardY and py <= cardY + cardH then
				return i, component
			end
		end
	end
	return nil, nil
end

function sidebar:update(dt)
	element.update(self, dt)

	-- Smooth scroll animation
	local diff = self.targetScrollY - self.scrollY
	if math.abs(diff) > 0.5 then
		self.scrollY = self.scrollY + diff * self.scrollSpeed * dt
	else
		self.scrollY = self.targetScrollY
	end

	-- Update hovered card
	local mx, my = love.mouse.getPosition()
	local index, _ = self:getCardAtPoint(mx, my)
	self.hoveredCard = index
end

function sidebar:draw()
	if not self.visible or self.opacity <= 0 then return end

	-- Background
	helper.setRGBColor(config.colors.uiBackground, self.opacity)
	love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

	-- Set up scissor to clip cards outside sidebar
	love.graphics.setScissor(self.x, self.y, self.width, self.height)

	-- Draw cards
	love.graphics.setLineWidth(4)
	for i, component in ipairs(self.components) do
		local cardX, cardY, cardW, cardH = self:getCardBounds(i)

		-- Skip cards that are completely outside visible area
		if cardY + cardH < self.y or cardY > self.y + self.height then
			goto continue
		end

		local rx, ry = 8, 8

		-- Card border
		helper.setRGBColor(config.colors.blue, self.opacity)
		love.graphics.rectangle("line", cardX, cardY, cardW, cardH, rx, ry)

		-- Card fill
		if self.hoveredCard == i then
			helper.setRGBColor(config.colors.greyLight, self.opacity) -- lighter on hover
		else
			helper.setRGBColor(config.colors.grey, self.opacity) -- grey fill
		end
		love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, rx, ry)

		-- Card text
		local font = love.graphics.getFont()
		local textHeight = font:getHeight()
		local textY = cardY + (cardH - textHeight) / 2
		helper.setRGBColor(config.colors.white, self.opacity)
		love.graphics.printf(component.name, cardX, textY, cardW, "center")

		::continue::
	end

	-- Remove scissor
	love.graphics.setScissor()

	-- Draw scrollbar if content is scrollable
	local maxScroll = self:getMaxScroll()
	if maxScroll > 0 then
		local scrollbarWidth = 4
		local scrollbarPadding = 4
		local viewHeight = self.height
		local contentHeight = self:getContentHeight()

		-- Scrollbar track
		local trackX = self.x + self.width - scrollbarWidth - scrollbarPadding
		local trackY = self.y + scrollbarPadding
		local trackHeight = self.height - scrollbarPadding * 2

		helper.setRGBColor(config.colors.greyDark, self.opacity * 0.5)
		love.graphics.rectangle("fill", trackX, trackY, scrollbarWidth, trackHeight, 2, 2)

		-- Scrollbar thumb
		local thumbHeight = math.max(20, (viewHeight / contentHeight) * trackHeight)
		local thumbY = trackY + (self.scrollY / maxScroll) * (trackHeight - thumbHeight)

		helper.setRGBColor(config.colors.greyMedium, self.opacity)
		love.graphics.rectangle("fill", trackX, thumbY, scrollbarWidth, thumbHeight, 2, 2)
	end

	-- Reset color
	love.graphics.setColor(1, 1, 1, 1)

	-- Draw children
	element.draw(self)
end

function sidebar:wheelmoved(wx, wy)
	if not self.visible or not self.enabled then return false end

	-- Check if mouse is over sidebar
	local mx, my = love.mouse.getPosition()
	if mx < self.x or mx > self.x + self.width or my < self.y or my > self.y + self.height then
		return false
	end

	-- Scroll
	local maxScroll = self:getMaxScroll()
	self.targetScrollY = self.targetScrollY - wy * self.scrollWheelSpeed
	self.targetScrollY = helper.clamp(self.targetScrollY, 0, maxScroll)

	return true
end

function sidebar:mousepressed(mx, my, button)
	if button ~= 1 then return false end
	if not self.visible or not self.enabled then return false end

	local index, component = self:getCardAtPoint(mx, my)
	if index and component then
		-- Start drag
		local cardX, cardY, cardW, cardH = self:getCardBounds(index)
		dragdrop.start(component, mx, my, cardW / 2, cardH / 2)
		return true
	end

	return element.mousepressed(self, mx, my, button)
end

-- Legacy create function for backwards compatibility
function sidebar.create(screenWidth, screenHeight, Width, Height, components)
	local canvas = love.graphics.newCanvas(screenWidth, screenHeight)

	love.graphics.setCanvas(canvas)
	love.graphics.clear()
	love.graphics.setLineWidth(4)
	helper.setRGBColor(config.colors.uiBackground)
	love.graphics.rectangle("fill", 0, 0, Width + 15, Height)

	local padding = 15
	local rectX = 15

	for i, component in ipairs(components) do
		local rectW = Width - 10
		local rectH = 90
		local rectY = padding + (rectH + padding) * (i - 1)
		local rx, ry = 8, 8
		local font = love.graphics.getFont()
		local textHeight = font:getHeight()
		local textY = rectY + (rectH - textHeight) / 2

		helper.setRGBColor(config.colors.blue) -- blue border
		love.graphics.rectangle("line", rectX, rectY, rectW, rectH, rx, ry)
		helper.setRGBColor(config.colors.grey) -- grey fill
		love.graphics.rectangle("fill", rectX, rectY, rectW, rectH, rx, ry)
		helper.setRGBColor(config.colors.white) -- white text
		love.graphics.printf(component.name, rectX, textY, rectW, "center")
	end

	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1)
	return canvas
end

return sidebar
