local helper = require("helper")
local config = require("config")
local screenManager = require("UI.screen")
local sidebarModule = require("UI.sidebar")
local dragdrop = require("UI.dragdrop")

local playing = {
	placedComponents = {}, -- list of {id, component, gridX, gridY}
	pipes = {}, -- list of {startCompId, startPortType, startPortIndex, endCompId, endPortType, endPortIndex}
	pipeDrawing = nil, -- current pipe being drawn
	sidebar = nil,
	components = nil,
	screenWidth = 0,
	screenHeight = 0,
	sidebarWidth = 130,
	nextComponentId = 1,
	-- World size
	worldWidth = 0,
	worldHeight = 0,
	-- Camera state for pan/zoom
	cameraX = 0,
	cameraY = 0,
	zoom = 1,
	minZoom = 0.25,
	maxZoom = 2,
	isPanning = false,
	panStartX = 0,
	panStartY = 0,
	panStartCamX = 0,
	panStartCamY = 0,
}

function playing:init(components)
	self.components = components
end

function playing:enter()
	self.screenWidth, self.screenHeight = love.graphics.getDimensions()

	-- World size for grid extent
	local worldScale = 4
	self.worldWidth = self.screenWidth * worldScale
	self.worldHeight = self.screenHeight * worldScale

	-- No more canvases - draw everything directly for crisp rendering at any zoom
	self.placedComponents = {}
	self.pipes = {}
	self.pipeDrawing = nil
	self.nextComponentId = 1

	-- Reset camera state
	self.cameraX = 0
	self.cameraY = 0
	self.zoom = 1
	self.isPanning = false

	-- Create sidebar using element system
	self.sidebar = sidebarModule.new({
		x = 0,
		y = 0,
		width = self.sidebarWidth,
		height = self.screenHeight,
		components = self.components,
		opacity = 0,
	})

	-- Animate sidebar sliding in
	self.sidebar.x = -self.sidebarWidth
	self.sidebar.opacity = 255
	self.sidebar:tweenTo({ x = 0 }, 0.4, { easing = "outCubic" })

	-- Set up drag drop callback
	dragdrop.onDrop = function(component, gridX, gridY, existingId)
		self:placeComponent(component, gridX, gridY, existingId)
	end
end

-- Convert screen coordinates to world coordinates (accounting for camera)
function playing:screenToWorld(screenX, screenY)
	local worldX = (screenX - self.cameraX) / self.zoom
	local worldY = (screenY - self.cameraY) / self.zoom
	return worldX, worldY
end

-- Convert world coordinates to screen coordinates
function playing:worldToScreen(worldX, worldY)
	local screenX = worldX * self.zoom + self.cameraX
	local screenY = worldY * self.zoom + self.cameraY
	return screenX, screenY
end

-- Check if screen position is over the grid area (not sidebar)
function playing:isOverGrid(screenX, screenY)
	return screenX > self.sidebarWidth
end

-- Place a component on the grid and redraw the canvas
function playing:placeComponent(component, gridX, gridY, existingId)
	local id = existingId or self.nextComponentId
	if not existingId then
		self.nextComponentId = self.nextComponentId + 1
	end
	table.insert(self.placedComponents, {
		id = id,
		component = component,
		gridX = gridX,
		gridY = gridY,
	})
	-- No need to redraw canvas - we draw directly each frame
end

-- Find placed component by ID
function playing:getComponentById(id)
	for _, placed in ipairs(self.placedComponents) do
		if placed.id == id then
			return placed
		end
	end
	return nil
end

-- Remove a placed component by index and return it
function playing:removeComponentAt(index)
	local removed = table.remove(self.placedComponents, index)
	return removed
end

-- Get the screen position of a port on a placed component
function playing:getPortPosition(compId, portType, portIndex)
	local placed = self:getComponentById(compId)
	if not placed then
		return nil, nil
	end

	local comp = placed.component
	local ports = comp.config and comp.config.ports
	if not ports then
		return nil, nil
	end

	local portList = ports[portType]
	if not portList or not portList[portIndex] then
		return nil, nil
	end

	local port = portList[portIndex]
	local gridSize = dragdrop.gridSize

	local sizeX = comp.config.size and comp.config.size[1] or 1
	local sizeY = comp.config.size and comp.config.size[2] or 1

	-- Calculate component position with centering
	local offsetX = (1 - sizeX) * gridSize / 2
	local offsetY = (1 - sizeY) * gridSize / 2
	if sizeX >= 1 then
		offsetX = 0
	end
	if sizeY >= 1 then
		offsetY = 0
	end

	local compX = placed.gridX * gridSize + offsetX
	local compY = placed.gridY * gridSize + offsetY

	local direction = self:getPortDirection(port, sizeX, sizeY)
	return compX + port.x * gridSize, compY + port.y * gridSize, direction
end

-- Snap position to nearest grid center
-- Snap to center of grid cell (not corners)
function playing:snapToGridCenter(x, y)
	local gridSize = dragdrop.gridSize
	local snapX = (math.floor(x / gridSize) + 0.5) * gridSize
	local snapY = (math.floor(y / gridSize) + 0.5) * gridSize
	return snapX, snapY
end

-- Find placed component at screen position, returns index or nil
function playing:getPlacedComponentAt(mx, my)
	local gridSize = dragdrop.gridSize

	-- Check in reverse order (top-most first)
	for i = #self.placedComponents, 1, -1 do
		local placed = self.placedComponents[i]
		local comp = placed.component
		local sizeX = comp.config and comp.config.size and comp.config.size[1] or 1
		local sizeY = comp.config and comp.config.size and comp.config.size[2] or 1

		-- Calculate centered position
		local offsetX = (1 - sizeX) * gridSize / 2
		local offsetY = (1 - sizeY) * gridSize / 2
		if sizeX >= 1 then
			offsetX = 0
		end
		if sizeY >= 1 then
			offsetY = 0
		end

		local x = placed.gridX * gridSize + offsetX
		local y = placed.gridY * gridSize + offsetY
		local w = sizeX * gridSize
		local h = sizeY * gridSize

		if mx >= x and mx <= x + w and my >= y and my <= y + h then
			return i
		end
	end
	return nil
end

-- Find port at screen position, returns port info or nil
function playing:getPortAt(mx, my)
	local gridSize = dragdrop.gridSize
	local hitRadius = 12

	for _, placed in ipairs(self.placedComponents) do
		local comp = placed.component
		local ports = comp.config and comp.config.ports
		if not ports then
			goto continue
		end

		local sizeX = comp.config.size and comp.config.size[1] or 1
		local sizeY = comp.config.size and comp.config.size[2] or 1

		-- Calculate component position with centering
		local offsetX = (1 - sizeX) * gridSize / 2
		local offsetY = (1 - sizeY) * gridSize / 2
		if sizeX >= 1 then
			offsetX = 0
		end
		if sizeY >= 1 then
			offsetY = 0
		end

		local compX = placed.gridX * gridSize + offsetX
		local compY = placed.gridY * gridSize + offsetY

		-- Check input ports
		if ports.input then
			for j, port in ipairs(ports.input) do
				local px = compX + port.x * gridSize
				local py = compY + port.y * gridSize
				local dist = math.sqrt((mx - px) ^ 2 + (my - py) ^ 2)
				if dist <= hitRadius then
					local dir = self:getPortDirection(port, sizeX, sizeY)
					return {
						compId = placed.id,
						portType = "input",
						portIndex = j,
						screenX = px,
						screenY = py,
						direction = dir,
					}
				end
			end
		end

		-- Check output ports
		if ports.output then
			for j, port in ipairs(ports.output) do
				local px = compX + port.x * gridSize
				local py = compY + port.y * gridSize
				local dist = math.sqrt((mx - px) ^ 2 + (my - py) ^ 2)
				if dist <= hitRadius then
					local dir = self:getPortDirection(port, sizeX, sizeY)
					return {
						compId = placed.id,
						portType = "output",
						portIndex = j,
						screenX = px,
						screenY = py,
						direction = dir,
					}
				end
			end
		end

		::continue::
	end
	return nil
end

-- Get direction a port faces based on its position on component edge
function playing:getPortDirection(port, compSizeX, compSizeY)
	local epsilon = 0.01
	if math.abs(port.x) < epsilon then
		return "left"
	elseif math.abs(port.x - compSizeX) < epsilon then
		return "right"
	elseif math.abs(port.y) < epsilon then
		return "up"
	elseif math.abs(port.y - compSizeY) < epsilon then
		return "down"
	end
	-- Default based on position relative to center
	local centerX, centerY = compSizeX / 2, compSizeY / 2
	local dx, dy = port.x - centerX, port.y - centerY
	if math.abs(dx) > math.abs(dy) then
		return dx > 0 and "right" or "left"
	else
		return dy > 0 and "down" or "up"
	end
end

-- Calculate distance from point to line segment
function playing:pointToSegmentDistance(px, py, x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	local lengthSq = dx * dx + dy * dy

	if lengthSq == 0 then
		-- Segment is a point
		return math.sqrt((px - x1) ^ 2 + (py - y1) ^ 2)
	end

	-- Project point onto line, clamped to segment
	local t = math.max(0, math.min(1, ((px - x1) * dx + (py - y1) * dy) / lengthSq))
	local projX, projY = x1 + t * dx, y1 + t * dy

	return math.sqrt((px - projX) ^ 2 + (py - projY) ^ 2)
end

-- Check if point is near a pipe path (returns true if within hitRadius of any segment)
function playing:isPointNearPipe(px, py, pipe, hitRadius)
	local startX, startY, startDir = self:getPortPosition(pipe.startCompId, pipe.startPortType, pipe.startPortIndex)
	local endX, endY, endDir = self:getPortPosition(pipe.endCompId, pipe.endPortType, pipe.endPortIndex)

	if not startX or not endX then
		return false
	end

	local startHorizontal = (startDir == "left" or startDir == "right")
	local endHorizontal = (endDir == "left" or endDir == "right")

	-- Check based on pipe routing pattern
	if math.abs(startX - endX) < 1 or math.abs(startY - endY) < 1 then
		-- Straight line
		return self:pointToSegmentDistance(px, py, startX, startY, endX, endY) <= hitRadius
	elseif startHorizontal and endHorizontal then
		-- H-V-H pattern
		local midX = (startX + endX) / 2
		local mid1X, mid1Y = midX, startY
		local mid2X, mid2Y = midX, endY

		return self:pointToSegmentDistance(px, py, startX, startY, mid1X, mid1Y) <= hitRadius
			or self:pointToSegmentDistance(px, py, mid1X, mid1Y, mid2X, mid2Y) <= hitRadius
			or self:pointToSegmentDistance(px, py, mid2X, mid2Y, endX, endY) <= hitRadius
	elseif not startHorizontal and not endHorizontal then
		-- V-H-V pattern
		local midY = (startY + endY) / 2
		local mid1X, mid1Y = startX, midY
		local mid2X, mid2Y = endX, midY

		return self:pointToSegmentDistance(px, py, startX, startY, mid1X, mid1Y) <= hitRadius
			or self:pointToSegmentDistance(px, py, mid1X, mid1Y, mid2X, mid2Y) <= hitRadius
			or self:pointToSegmentDistance(px, py, mid2X, mid2Y, endX, endY) <= hitRadius
	else
		-- L-pattern (single bend)
		local midX, midY
		if startHorizontal then
			midX, midY = endX, startY
		else
			midX, midY = startX, endY
		end

		return self:pointToSegmentDistance(px, py, startX, startY, midX, midY) <= hitRadius
			or self:pointToSegmentDistance(px, py, midX, midY, endX, endY) <= hitRadius
	end
end

-- Find pipe at screen position, returns index or nil
function playing:getPipeAt(mx, my)
	local hitRadius = 10

	for i, pipe in ipairs(self.pipes) do
		if self:isPointNearPipe(mx, my, pipe, hitRadius) then
			return i
		end
	end
	return nil
end

-- Check if a port already has a pipe connected to it
function playing:isPortOccupied(compId, portType, portIndex)
	for _, pipe in ipairs(self.pipes) do
		if (pipe.startCompId == compId and pipe.startPortType == portType and pipe.startPortIndex == portIndex)
			or (pipe.endCompId == compId and pipe.endPortType == portType and pipe.endPortIndex == portIndex) then
			return true
		end
	end
	return false
end

-- Check if a line segment intersects a rectangle (excluding edges for ports)
function playing:segmentIntersectsRect(x1, y1, x2, y2, rx, ry, rw, rh, margin)
	margin = margin or 2 -- small margin to allow pipes to touch edges at ports

	-- Shrink rect by margin to allow edge connections
	rx, ry = rx + margin, ry + margin
	rw, rh = rw - margin * 2, rh - margin * 2

	if rw <= 0 or rh <= 0 then
		return false
	end

	-- Check if segment is completely outside rect bounds
	local minX, maxX = math.min(x1, x2), math.max(x1, x2)
	local minY, maxY = math.min(y1, y2), math.max(y1, y2)

	if maxX < rx or minX > rx + rw or maxY < ry or minY > ry + rh then
		return false
	end

	-- Check if either endpoint is inside rect
	local function pointInRect(px, py)
		return px > rx and px < rx + rw and py > ry and py < ry + rh
	end

	if pointInRect(x1, y1) or pointInRect(x2, y2) then
		return true
	end

	-- Check if segment crosses any edge of rect
	local function segmentsIntersect(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
		local function ccw(px, py, qx, qy, rx, ry)
			return (ry - py) * (qx - px) > (qy - py) * (rx - px)
		end
		return ccw(ax1, ay1, bx1, by1, bx2, by2) ~= ccw(ax2, ay2, bx1, by1, bx2, by2)
			and ccw(ax1, ay1, ax2, ay2, bx1, by1) ~= ccw(ax1, ay1, ax2, ay2, bx2, by2)
	end

	-- Check all 4 edges
	if segmentsIntersect(x1, y1, x2, y2, rx, ry, rx + rw, ry) then return true end
	if segmentsIntersect(x1, y1, x2, y2, rx + rw, ry, rx + rw, ry + rh) then return true end
	if segmentsIntersect(x1, y1, x2, y2, rx, ry + rh, rx + rw, ry + rh) then return true end
	if segmentsIntersect(x1, y1, x2, y2, rx, ry, rx, ry + rh) then return true end

	return false
end

-- Check if a pipe path would intersect any component (excluding start/end components)
function playing:pipeIntersectsComponents(startX, startY, endX, endY, startDir, endDir, excludeCompIds)
	local gridSize = dragdrop.gridSize
	excludeCompIds = excludeCompIds or {}

	-- Build segments based on routing pattern
	local segments = {}
	local startHorizontal = (startDir == "left" or startDir == "right")
	local endHorizontal = (endDir == "left" or endDir == "right")

	if math.abs(startX - endX) < 1 or math.abs(startY - endY) < 1 then
		-- Straight line
		table.insert(segments, { startX, startY, endX, endY })
	elseif startHorizontal and endHorizontal then
		-- H-V-H pattern
		local midX = (startX + endX) / 2
		table.insert(segments, { startX, startY, midX, startY })
		table.insert(segments, { midX, startY, midX, endY })
		table.insert(segments, { midX, endY, endX, endY })
	elseif not startHorizontal and not endHorizontal then
		-- V-H-V pattern
		local midY = (startY + endY) / 2
		table.insert(segments, { startX, startY, startX, midY })
		table.insert(segments, { startX, midY, endX, midY })
		table.insert(segments, { endX, midY, endX, endY })
	else
		-- L-pattern
		local midX, midY
		if startHorizontal then
			midX, midY = endX, startY
		else
			midX, midY = startX, endY
		end
		table.insert(segments, { startX, startY, midX, midY })
		table.insert(segments, { midX, midY, endX, endY })
	end

	-- Check each segment against each component
	for _, placed in ipairs(self.placedComponents) do
		-- Skip excluded components (start/end components)
		local excluded = false
		for _, id in ipairs(excludeCompIds) do
			if placed.id == id then
				excluded = true
				break
			end
		end

		if not excluded then
			local comp = placed.component
			local sizeX = comp.config and comp.config.size and comp.config.size[1] or 1
			local sizeY = comp.config and comp.config.size and comp.config.size[2] or 1

			local offsetX = (1 - sizeX) * gridSize / 2
			local offsetY = (1 - sizeY) * gridSize / 2
			if sizeX >= 1 then offsetX = 0 end
			if sizeY >= 1 then offsetY = 0 end

			local rx = placed.gridX * gridSize + offsetX
			local ry = placed.gridY * gridSize + offsetY
			local rw = sizeX * gridSize
			local rh = sizeY * gridSize

			for _, seg in ipairs(segments) do
				if self:segmentIntersectsRect(seg[1], seg[2], seg[3], seg[4], rx, ry, rw, rh) then
					return true
				end
			end
		end
	end

	return false
end

-- Draw an arrowhead at position pointing in direction
function playing:drawArrowhead(px, py, direction, isInput, size)
	size = size or 8
	helper.setRGBColor(config.colors.greyLight) -- grey

	local vertices = {}
	-- Arrow points INTO component for input, OUT OF component for output
	local pointDir = direction
	if isInput then
		-- Flip direction for input (arrow points inward)
		if direction == "left" then pointDir = "right"
		elseif direction == "right" then pointDir = "left"
		elseif direction == "up" then pointDir = "down"
		elseif direction == "down" then pointDir = "up"
		end
	end

	if pointDir == "right" then
		vertices = { px - size, py - size/2, px - size, py + size/2, px, py }
	elseif pointDir == "left" then
		vertices = { px + size, py - size/2, px + size, py + size/2, px, py }
	elseif pointDir == "down" then
		vertices = { px - size/2, py - size, px + size/2, py - size, px, py }
	elseif pointDir == "up" then
		vertices = { px - size/2, py + size, px + size/2, py + size, px, py }
	end

	love.graphics.polygon("fill", vertices)
end

-- Draw connection ports for a component
function playing:drawPorts(comp, x, y, gridSize)
	local portSize = 10
	local ports = comp.config and comp.config.ports

	if not ports then
		return
	end

	local sizeX = comp.config.size and comp.config.size[1] or 1
	local sizeY = comp.config.size and comp.config.size[2] or 1

	-- Draw input ports as inward arrows
	if ports.input then
		for _, port in ipairs(ports.input) do
			local px = x + port.x * gridSize
			local py = y + port.y * gridSize
			local dir = self:getPortDirection(port, sizeX, sizeY)
			self:drawArrowhead(px, py, dir, true, portSize)
		end
	end

	-- Draw output ports as outward arrows
	if ports.output then
		for _, port in ipairs(ports.output) do
			local px = x + port.x * gridSize
			local py = y + port.y * gridSize
			local dir = self:getPortDirection(port, sizeX, sizeY)
			self:drawArrowhead(px, py, dir, false, portSize)
		end
	end
end

-- Draw a pipe path with Z-pattern routing (2 bends for better visibility)
-- startDir/endDir: "left", "right", "up", "down" - determines routing pattern
-- invalid: if true, draws in red to indicate collision
function playing:drawPipePath(startX, startY, endX, endY, alpha, startDir, endDir, invalid)
	alpha = alpha or 255
	local lineWidth = 8

	if invalid then
		helper.setRGBColor(config.colors.invalid, alpha) -- red for invalid path
	else
		helper.setRGBColor(config.colors.blue, alpha) -- blue
	end
	love.graphics.setLineWidth(lineWidth)
	love.graphics.setLineStyle("smooth")
	love.graphics.setLineJoin("bevel")

	-- Determine if ports face horizontally or vertically
	local startHorizontal = (startDir == "left" or startDir == "right")
	local endHorizontal = (endDir == "left" or endDir == "right")

	-- Draw the path segments
	if math.abs(startX - endX) < 1 then
		-- Vertical line only (aligned vertically)
		love.graphics.line(startX, startY, endX, endY)
		love.graphics.circle("fill", startX, startY, lineWidth / 2)
		love.graphics.circle("fill", endX, endY, lineWidth / 2)
	elseif math.abs(startY - endY) < 1 then
		-- Horizontal line only (aligned horizontally)
		love.graphics.line(startX, startY, endX, endY)
		love.graphics.circle("fill", startX, startY, lineWidth / 2)
		love.graphics.circle("fill", endX, endY, lineWidth / 2)
	elseif startHorizontal and endHorizontal then
		-- Both ports face left/right: H-V-H pattern (horizontal → vertical → horizontal)
		local midX = (startX + endX) / 2
		local mid1X, mid1Y = midX, startY
		local mid2X, mid2Y = midX, endY

		love.graphics.line(startX, startY, mid1X, mid1Y)
		love.graphics.line(mid1X, mid1Y, mid2X, mid2Y)
		love.graphics.line(mid2X, mid2Y, endX, endY)

		love.graphics.circle("fill", startX, startY, lineWidth / 2)
		love.graphics.circle("fill", mid1X, mid1Y, lineWidth / 2)
		love.graphics.circle("fill", mid2X, mid2Y, lineWidth / 2)
		love.graphics.circle("fill", endX, endY, lineWidth / 2)
	elseif not startHorizontal and not endHorizontal then
		-- Both ports face up/down: V-H-V pattern (vertical → horizontal → vertical)
		local midY = (startY + endY) / 2
		local mid1X, mid1Y = startX, midY
		local mid2X, mid2Y = endX, midY

		love.graphics.line(startX, startY, mid1X, mid1Y)
		love.graphics.line(mid1X, mid1Y, mid2X, mid2Y)
		love.graphics.line(mid2X, mid2Y, endX, endY)

		love.graphics.circle("fill", startX, startY, lineWidth / 2)
		love.graphics.circle("fill", mid1X, mid1Y, lineWidth / 2)
		love.graphics.circle("fill", mid2X, mid2Y, lineWidth / 2)
		love.graphics.circle("fill", endX, endY, lineWidth / 2)
	else
		-- Mixed: one horizontal, one vertical - use L-pattern (single bend)
		local midX, midY
		if startHorizontal then
			-- Start goes horizontal, end goes vertical
			midX, midY = endX, startY
		else
			-- Start goes vertical, end goes horizontal
			midX, midY = startX, endY
		end

		love.graphics.line(startX, startY, midX, midY)
		love.graphics.line(midX, midY, endX, endY)

		love.graphics.circle("fill", startX, startY, lineWidth / 2)
		love.graphics.circle("fill", midX, midY, lineWidth / 2)
		love.graphics.circle("fill", endX, endY, lineWidth / 2)
	end
end

function playing:exit()
	-- Could add exit animations here
end

function playing:update(dt)
	if self.sidebar then
		self.sidebar:update(dt)
	end

	-- Update camera reference for dragdrop
	dragdrop.camera = {
		x = self.cameraX,
		y = self.cameraY,
		zoom = self.zoom
	}

	-- Update drag position
	if dragdrop.active then
		local mx, my = love.mouse.getPosition()
		dragdrop.updatePosition(mx, my)
	end
end

-- Draw the grid directly (procedural, always crisp)
function playing:drawGrid()
	local gridSize = dragdrop.gridSize

	-- Calculate visible area in world coordinates
	local visibleLeft = -self.cameraX / self.zoom
	local visibleTop = -self.cameraY / self.zoom
	local visibleRight = (self.screenWidth - self.cameraX) / self.zoom
	local visibleBottom = (self.screenHeight - self.cameraY) / self.zoom

	-- Add some padding
	visibleLeft = visibleLeft - gridSize
	visibleTop = visibleTop - gridSize
	visibleRight = visibleRight + gridSize
	visibleBottom = visibleBottom + gridSize

	-- Snap to grid
	local startX = math.floor(visibleLeft / gridSize) * gridSize
	local startY = math.floor(visibleTop / gridSize) * gridSize
	local endX = math.ceil(visibleRight / gridSize) * gridSize
	local endY = math.ceil(visibleBottom / gridSize) * gridSize

	helper.setRGBColor(config.colors.gridLines) -- grid lines color
	love.graphics.setLineWidth(2 / self.zoom) -- Keep line width consistent on screen

	-- Draw vertical lines
	for x = startX, endX, gridSize do
		love.graphics.line(x, startY, x, endY)
	end

	-- Draw horizontal lines
	for y = startY, endY, gridSize do
		love.graphics.line(startX, y, endX, y)
	end
end

-- Draw a single placed component directly
function playing:drawComponent(placed)
	local gridSize = dragdrop.gridSize
	local comp = placed.component
	local sizeX = comp.config and comp.config.size and comp.config.size[1] or 1
	local sizeY = comp.config and comp.config.size and comp.config.size[2] or 1

	-- Calculate position with centering for small components
	local offsetX = (1 - sizeX) * gridSize / 2
	local offsetY = (1 - sizeY) * gridSize / 2
	if sizeX >= 1 then offsetX = 0 end
	if sizeY >= 1 then offsetY = 0 end

	local x = placed.gridX * gridSize + offsetX
	local y = placed.gridY * gridSize + offsetY
	local w = sizeX * gridSize
	local h = sizeY * gridSize

	-- Draw component box
	love.graphics.setLineWidth(2 / self.zoom)
	helper.setRGBColor(config.colors.blue, 200) -- blue, slightly transparent
	love.graphics.rectangle("fill", x, y, w, h, 4, 4)
	helper.setRGBColor(config.colors.blueDark) -- darker blue border
	love.graphics.rectangle("line", x, y, w, h, 4, 4)

	-- Draw ports
	self:drawPorts(comp, x, y, gridSize)

	-- Draw component name
	helper.setRGBColor(config.colors.white) -- white text
	local font = love.graphics.getFont()
	local textWidth = font:getWidth(comp.name)
	local textX = x + (w - textWidth) / 2
	local textY = y + (h - font:getHeight()) / 2
	love.graphics.print(comp.name, textX, textY)
end

-- Draw all placed components and pipes directly
function playing:drawPlacedElements()
	local gridSize = dragdrop.gridSize

	-- Draw pipes first (behind components)
	for _, pipe in ipairs(self.pipes) do
		local startX, startY, startDir = self:getPortPosition(pipe.startCompId, pipe.startPortType, pipe.startPortIndex)
		local endX, endY, endDir = self:getPortPosition(pipe.endCompId, pipe.endPortType, pipe.endPortIndex)
		if startX and endX then
			self:drawPipePath(startX, startY, endX, endY, 255, startDir, endDir)
		end
	end

	-- Draw components
	for _, placed in ipairs(self.placedComponents) do
		self:drawComponent(placed)
	end
end

function playing:draw()
	-- Draw grid background (full screen)
	helper.setRGBColor(config.colors.gridBackground) -- grey grid background
	love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

	-- Apply camera transform for world elements
	love.graphics.push()
	love.graphics.translate(self.cameraX, self.cameraY)
	love.graphics.scale(self.zoom, self.zoom)

	-- Draw grid directly (always crisp at any zoom)
	self:drawGrid()

	-- Draw placed components and pipes directly
	self:drawPlacedElements()

	-- Draw pipe being drawn (in world space)
	if self.pipeDrawing then
		local startPort = self.pipeDrawing.startPort

		-- Check if start port is already occupied
		local startOccupied = self:isPortOccupied(startPort.compId, startPort.portType, startPort.portIndex)

		-- Check if hovering over an occupied port
		local endOccupied = false
		if self.pipeDrawing.hoverPort then
			endOccupied = self:isPortOccupied(
				self.pipeDrawing.hoverPort.compId,
				self.pipeDrawing.hoverPort.portType,
				self.pipeDrawing.hoverPort.portIndex
			)
		end

		-- Check if path would intersect components (no exclusions)
		local intersects = self:pipeIntersectsComponents(
			self.pipeDrawing.startX,
			self.pipeDrawing.startY,
			self.pipeDrawing.endX,
			self.pipeDrawing.endY,
			self.pipeDrawing.startDir,
			self.pipeDrawing.endDir
		)

		local invalid = intersects or startOccupied or endOccupied

		self:drawPipePath(
			self.pipeDrawing.startX,
			self.pipeDrawing.startY,
			self.pipeDrawing.endX,
			self.pipeDrawing.endY,
			150, -- semi-transparent while drawing
			self.pipeDrawing.startDir,
			self.pipeDrawing.endDir,
			invalid -- pass invalid state for color
		)
	end

	-- End camera transform
	love.graphics.pop()

	-- Draw UI elements in screen space (not affected by camera)
	-- Draw sidebar
	if self.sidebar then
		self.sidebar:draw()
	end

	-- Draw drag ghost (in screen space for smooth dragging)
	dragdrop.draw()

	-- Reset color
	love.graphics.setColor(1, 1, 1, 1)
end

function playing:keypressed(key)
	if key == "escape" then
		if self.pipeDrawing then
			-- Cancel pipe drawing
			self.pipeDrawing = nil
		else
			screenManager.switchTo("paused", { transition = "fade", duration = 0.2 })
		end
	elseif key == "x" then
		-- Delete pipe or component under mouse
		local mx, my = love.mouse.getPosition()
		-- Convert to world coordinates
		local worldX, worldY = self:screenToWorld(mx, my)

		-- Check pipes first (they're thinner and harder to select)
		local pipeIndex = self:getPipeAt(worldX, worldY)
		if pipeIndex then
			table.remove(self.pipes, pipeIndex)
			return
		end

		-- Check components
		local compIndex = self:getPlacedComponentAt(worldX, worldY)
		if compIndex then
			-- Also remove any pipes connected to this component
			local compId = self.placedComponents[compIndex].id
			for i = #self.pipes, 1, -1 do
				local pipe = self.pipes[i]
				if pipe.startCompId == compId or pipe.endCompId == compId then
					table.remove(self.pipes, i)
				end
			end
			table.remove(self.placedComponents, compIndex)
		end
	elseif key == "home" or key == "0" then
		-- Reset camera to default position and zoom
		self.cameraX = 0
		self.cameraY = 0
		self.zoom = 1
	end
end

function playing:mousepressed(x, y, button)
	-- Middle mouse button (or right mouse) for panning anywhere on grid
	if button == 2 or button == 3 then
		if self:isOverGrid(x, y) then
			self.isPanning = true
			self.panStartX = x
			self.panStartY = y
			self.panStartCamX = self.cameraX
			self.panStartCamY = self.cameraY
		end
		return
	end

	if button ~= 1 then
		return
	end

	-- Convert to world coordinates for grid interactions
	local worldX, worldY = self:screenToWorld(x, y)

	-- Check ports first (for pipe drawing)
	local port = self:getPortAt(worldX, worldY)
	if port then
		-- Start drawing a pipe from this port
		self.pipeDrawing = {
			startX = port.screenX,
			startY = port.screenY,
			endX = port.screenX,
			endY = port.screenY,
			startPort = port,
			startDir = port.direction,
		}
		return
	end

	-- Check placed components (for dragging from grid)
	local placedIndex = self:getPlacedComponentAt(worldX, worldY)
	if placedIndex then
		local placed = self:removeComponentAt(placedIndex)
		local comp = placed.component
		local sizeX = comp.config and comp.config.size and comp.config.size[1] or 1
		local sizeY = comp.config and comp.config.size and comp.config.size[2] or 1
		local w = sizeX * dragdrop.gridSize
		local h = sizeY * dragdrop.gridSize
		-- Pass the existing ID so pipes stay connected
		dragdrop.start(comp, x, y, w / 2, h / 2, placed.id)
		return
	end

	-- Check sidebar
	if x < self.sidebarWidth and self.sidebar then
		self.sidebar:mousepressed(x, y, button)
		return
	end

	-- Click on empty grid - start panning
	if self:isOverGrid(x, y) then
		self.isPanning = true
		self.panStartX = x
		self.panStartY = y
		self.panStartCamX = self.cameraX
		self.panStartCamY = self.cameraY
	end
end

function playing:mousereleased(x, y, button)
	-- Stop panning for any button
	if button == 2 or button == 3 then
		self.isPanning = false
		return
	end

	if button ~= 1 then
		return
	end

	-- Stop panning if we were panning with left mouse
	if self.isPanning then
		self.isPanning = false
		return
	end

	-- Convert to world coordinates
	local worldX, worldY = self:screenToWorld(x, y)

	-- Complete pipe drawing
	if self.pipeDrawing then
		-- Check if released on a port (in world coordinates)
		local endPort = self:getPortAt(worldX, worldY)
		if endPort and endPort.compId ~= self.pipeDrawing.startPort.compId then
			local startPort = self.pipeDrawing.startPort

			-- Check if either port already has a pipe connected
			local portOccupied = self:isPortOccupied(startPort.compId, startPort.portType, startPort.portIndex)
				or self:isPortOccupied(endPort.compId, endPort.portType, endPort.portIndex)

			-- Check if pipe would intersect any components (no exclusions)
			local intersects = self:pipeIntersectsComponents(
				startPort.screenX, startPort.screenY,
				endPort.screenX, endPort.screenY,
				startPort.direction, endPort.direction
			)

			if not intersects and not portOccupied then
				-- Create pipe connected to another component's port
				local pipe = {
					startCompId = startPort.compId,
					startPortType = startPort.portType,
					startPortIndex = startPort.portIndex,
					startDir = startPort.direction,
					endCompId = endPort.compId,
					endPortType = endPort.portType,
					endPortIndex = endPort.portIndex,
					endDir = endPort.direction,
				}
				table.insert(self.pipes, pipe)
			end
		end
		self.pipeDrawing = nil
		return
	end

	-- Complete component drag
	if dragdrop.active then
		dragdrop.drop(x, y)
	end
end

function playing:mousemoved(x, y, dx, dy)
	-- Handle panning
	if self.isPanning then
		self.cameraX = self.panStartCamX + (x - self.panStartX)
		self.cameraY = self.panStartCamY + (y - self.panStartY)
		return
	end

	-- Convert to world coordinates for grid interactions
	local worldX, worldY = self:screenToWorld(x, y)

	-- Update pipe drawing end position
	if self.pipeDrawing then
		-- Check if hovering over a valid port (in world coordinates)
		local port = self:getPortAt(worldX, worldY)
		if port and port.compId ~= self.pipeDrawing.startPort.compId then
			-- Snap to port and track hover
			self.pipeDrawing.endX = port.screenX
			self.pipeDrawing.endY = port.screenY
			self.pipeDrawing.endDir = port.direction
			self.pipeDrawing.hoverPort = port
		else
			-- Snap to nearest grid center (in world coordinates)
			local snapX, snapY = self:snapToGridCenter(worldX, worldY)
			self.pipeDrawing.endX = snapX
			self.pipeDrawing.endY = snapY
			self.pipeDrawing.hoverPort = nil -- not hovering over a port
			-- Infer end direction based on cursor position relative to start
			-- Use opposite of start direction for cleaner routing
			local startDir = self.pipeDrawing.startDir
			if startDir == "left" then
				self.pipeDrawing.endDir = "right"
			elseif startDir == "right" then
				self.pipeDrawing.endDir = "left"
			elseif startDir == "up" then
				self.pipeDrawing.endDir = "down"
			elseif startDir == "down" then
				self.pipeDrawing.endDir = "up"
			else
				self.pipeDrawing.endDir = "right"
			end
		end
		return
	end

	-- Update component drag
	if dragdrop.active then
		dragdrop.updatePosition(x, y)
	end
end

function playing:wheelmoved(x, y)
	local mx, my = love.mouse.getPosition()

	-- Check if over sidebar
	if mx < self.sidebarWidth then
		if self.sidebar then
			self.sidebar:wheelmoved(x, y)
		end
		return
	end

	-- Zoom when scrolling over grid
	if y ~= 0 then
		local zoomFactor = 1.1
		local oldZoom = self.zoom
		local newZoom

		if y > 0 then
			newZoom = oldZoom * zoomFactor -- zoom in
		else
			newZoom = oldZoom / zoomFactor -- zoom out
		end

		-- Clamp zoom
		newZoom = helper.clamp(newZoom, self.minZoom, self.maxZoom)

		-- Zoom towards mouse position
		local worldX, worldY = self:screenToWorld(mx, my)
		self.zoom = newZoom
		-- Adjust camera to keep mouse position fixed
		self.cameraX = mx - worldX * newZoom
		self.cameraY = my - worldY * newZoom
	end
end

return playing
