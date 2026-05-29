local tween = require("UI.tween")
local helper = require("helper")

local element = {}
element.__index = element

function element.new(props)
	props = props or {}
	local self = setmetatable({
		x = props.x or 0,
		y = props.y or 0,
		width = props.width or 100,
		height = props.height or 100,
		opacity = props.opacity or 255,
		scale = props.scale or 1,
		visible = props.visible ~= false,
		enabled = props.enabled ~= false,
		children = {},
		parent = nil,
	}, element)
	return self
end

-- Add a child element
function element:addChild(child)
	child.parent = self
	table.insert(self.children, child)
	return child
end

-- Remove a child element
function element:removeChild(child)
	for i, c in ipairs(self.children) do
		if c == child then
			c.parent = nil
			table.remove(self.children, i)
			return true
		end
	end
	return false
end

-- Get absolute position (accounting for parent offsets)
function element:getAbsolutePosition()
	local x, y = self.x, self.y
	if self.parent then
		local px, py = self.parent:getAbsolutePosition()
		x = x + px
		y = y + py
	end
	return x, y
end

-- Check if point is inside element
function element:containsPoint(px, py)
	local x, y = self:getAbsolutePosition()
	return px >= x and px <= x + self.width * self.scale
		and py >= y and py <= y + self.height * self.scale
end

-- Tween properties
function element:tweenTo(props, duration, options)
	return tween.to(self, props, duration, options)
end

-- Convenience: fade in
function element:fadeIn(duration, options)
	options = options or {}
	self.opacity = 0
	self.visible = true
	return self:tweenTo({ opacity = 255 }, duration or 0.3, options)
end

-- Convenience: fade out
function element:fadeOut(duration, options)
	options = options or {}
	local origOnComplete = options.onComplete
	options.onComplete = function()
		self.visible = false
		if origOnComplete then origOnComplete() end
	end
	return self:tweenTo({ opacity = 0 }, duration or 0.3, options)
end

-- Convenience: slide in from direction
function element:slideIn(fromX, fromY, duration, options)
	local targetX, targetY = self.x, self.y
	self.x = fromX
	self.y = fromY
	self.visible = true
	return self:tweenTo({ x = targetX, y = targetY }, duration or 0.4, options)
end

-- Update element and children
function element:update(dt)
	if not self.visible then return end
	for _, child in ipairs(self.children) do
		child:update(dt)
	end
end

-- Draw element and children (override in subclasses)
function element:draw()
	if not self.visible or self.opacity <= 0 then return end
	-- Subclasses implement their own drawing
	for _, child in ipairs(self.children) do
		child:draw()
	end
end

-- Handle mouse press (returns true if handled)
function element:mousepressed(mx, my, button)
	if not self.visible or not self.enabled then return false end
	-- Check children first (reverse order for top-most first)
	for i = #self.children, 1, -1 do
		if self.children[i]:mousepressed(mx, my, button) then
			return true
		end
	end
	return false
end

-- Handle mouse release
function element:mousereleased(mx, my, button)
	if not self.visible or not self.enabled then return false end
	for i = #self.children, 1, -1 do
		if self.children[i]:mousereleased(mx, my, button) then
			return true
		end
	end
	return false
end

-- Handle mouse move
function element:mousemoved(mx, my, dx, dy)
	if not self.visible then return false end
	for i = #self.children, 1, -1 do
		if self.children[i]:mousemoved(mx, my, dx, dy) then
			return true
		end
	end
	return false
end

return element
