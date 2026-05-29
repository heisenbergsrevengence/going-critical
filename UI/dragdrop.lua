local helper = require("helper")
local config = require("config")

local dragdrop = {
	active = false,
	component = nil,
	existingId = nil, -- ID of existing placed component (for reconnecting pipes)
	ghostX = 0, -- world coordinates
	ghostY = 0,
	offsetX = 0,
	offsetY = 0,
	gridSize = 90,
	onDrop = nil, -- callback(component, gridX, gridY, existingId)
	-- Camera reference (set by playing.lua)
	camera = nil, -- { x, y, zoom }
}

-- Start dragging a component
function dragdrop.start(component, mouseX, mouseY, offsetX, offsetY, existingId)
	dragdrop.active = true
	dragdrop.component = component
	dragdrop.existingId = existingId or nil
	dragdrop.offsetX = offsetX or 0
	dragdrop.offsetY = offsetY or 0
	dragdrop.ghostX = mouseX - dragdrop.offsetX
	dragdrop.ghostY = mouseY - dragdrop.offsetY
end

-- Cancel current drag
function dragdrop.cancel()
	dragdrop.active = false
	dragdrop.component = nil
	dragdrop.existingId = nil
end

-- Convert screen to world coordinates
function dragdrop.screenToWorld(screenX, screenY)
	if dragdrop.camera then
		local worldX = (screenX - dragdrop.camera.x) / dragdrop.camera.zoom
		local worldY = (screenY - dragdrop.camera.y) / dragdrop.camera.zoom
		return worldX, worldY
	end
	return screenX, screenY
end

-- Convert world to screen coordinates
function dragdrop.worldToScreen(worldX, worldY)
	if dragdrop.camera then
		local screenX = worldX * dragdrop.camera.zoom + dragdrop.camera.x
		local screenY = worldY * dragdrop.camera.zoom + dragdrop.camera.y
		return screenX, screenY
	end
	return worldX, worldY
end

-- Update ghost position (snapped to grid in world coordinates)
function dragdrop.updatePosition(mouseX, mouseY)
	if not dragdrop.active then return end

	-- Convert screen to world coordinates
	local worldX, worldY = dragdrop.screenToWorld(mouseX, mouseY)

	-- Snap to grid in world space
	local rawX = worldX - dragdrop.offsetX / (dragdrop.camera and dragdrop.camera.zoom or 1)
	local rawY = worldY - dragdrop.offsetY / (dragdrop.camera and dragdrop.camera.zoom or 1)
	dragdrop.ghostX = math.floor(rawX / dragdrop.gridSize) * dragdrop.gridSize
	dragdrop.ghostY = math.floor(rawY / dragdrop.gridSize) * dragdrop.gridSize
end

-- Drop component at current position
function dragdrop.drop(mouseX, mouseY)
	if not dragdrop.active then return false end

	-- Calculate grid coordinates
	local gridX = math.floor(dragdrop.ghostX / dragdrop.gridSize)
	local gridY = math.floor(dragdrop.ghostY / dragdrop.gridSize)

	-- Call drop callback with existing ID if present
	if dragdrop.onDrop then
		dragdrop.onDrop(dragdrop.component, gridX, gridY, dragdrop.existingId)
	end

	-- Reset state
	local component = dragdrop.component
	dragdrop.active = false
	dragdrop.component = nil
	dragdrop.existingId = nil

	return true, component, gridX, gridY
end

-- Get direction a port faces based on its position on component edge
function dragdrop.getPortDirection(port, compSizeX, compSizeY)
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
	local centerX, centerY = compSizeX / 2, compSizeY / 2
	local dx, dy = port.x - centerX, port.y - centerY
	if math.abs(dx) > math.abs(dy) then
		return dx > 0 and "right" or "left"
	else
		return dy > 0 and "down" or "up"
	end
end

-- Draw an arrowhead at position
function dragdrop.drawArrowhead(px, py, direction, isInput, size, alpha)
	size = size or 8
	alpha = alpha or 200
	helper.setRGBColor(config.colors.greyLight, alpha) -- grey, semi-transparent

	local pointDir = direction
	if isInput then
		if direction == "left" then pointDir = "right"
		elseif direction == "right" then pointDir = "left"
		elseif direction == "up" then pointDir = "down"
		elseif direction == "down" then pointDir = "up"
		end
	end

	local vertices = {}
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

-- Draw connection ports for ghost preview
function dragdrop.drawPorts(comp, x, y)
	local portSize = 10
	local ports = comp.config and comp.config.ports

	if not ports then return end

	local sizeX = comp.config.size and comp.config.size[1] or 1
	local sizeY = comp.config.size and comp.config.size[2] or 1

	-- Draw input ports as inward arrows
	if ports.input then
		for _, port in ipairs(ports.input) do
			local px = x + port.x * dragdrop.gridSize
			local py = y + port.y * dragdrop.gridSize
			local dir = dragdrop.getPortDirection(port, sizeX, sizeY)
			dragdrop.drawArrowhead(px, py, dir, true, portSize, 200)
		end
	end

	-- Draw output ports as outward arrows
	if ports.output then
		for _, port in ipairs(ports.output) do
			local px = x + port.x * dragdrop.gridSize
			local py = y + port.y * dragdrop.gridSize
			local dir = dragdrop.getPortDirection(port, sizeX, sizeY)
			dragdrop.drawArrowhead(px, py, dir, false, portSize, 200)
		end
	end
end

-- Draw ghost preview
function dragdrop.draw()
	if not dragdrop.active or not dragdrop.component then return end

	-- Apply camera transform
	love.graphics.push()
	if dragdrop.camera then
		love.graphics.translate(dragdrop.camera.x, dragdrop.camera.y)
		love.graphics.scale(dragdrop.camera.zoom, dragdrop.camera.zoom)
	end

	-- Get component size in grid units
	local sizeX = dragdrop.component.config and dragdrop.component.config.size and dragdrop.component.config.size[1] or 1
	local sizeY = dragdrop.component.config and dragdrop.component.config.size and dragdrop.component.config.size[2] or 1

	local w = sizeX * dragdrop.gridSize
	local h = sizeY * dragdrop.gridSize

	-- Center smaller components within grid cell
	local offsetX = (1 - sizeX) * dragdrop.gridSize / 2
	local offsetY = (1 - sizeY) * dragdrop.gridSize / 2
	if sizeX >= 1 then offsetX = 0 end
	if sizeY >= 1 then offsetY = 0 end

	local drawX = dragdrop.ghostX + offsetX
	local drawY = dragdrop.ghostY + offsetY

	-- Draw ghost rectangle at snapped position (in world coordinates)
	love.graphics.setLineWidth(2)
	helper.setRGBColor(config.colors.blue, 150) -- blue, semi-transparent
	love.graphics.rectangle("fill", drawX, drawY, w, h, 4, 4)
	helper.setRGBColor(config.colors.blue) -- blue, solid border
	love.graphics.rectangle("line", drawX, drawY, w, h, 4, 4)

	-- Draw connection ports
	dragdrop.drawPorts(dragdrop.component, drawX, drawY)

	-- Draw component name
	love.graphics.setColor(1, 1, 1)
	local font = love.graphics.getFont()
	local textWidth = font:getWidth(dragdrop.component.name)
	local textX = drawX + (w - textWidth) / 2
	local textY = drawY + (h - font:getHeight()) / 2
	love.graphics.print(dragdrop.component.name, textX, textY)

	-- End camera transform
	love.graphics.pop()

	-- Reset color
	love.graphics.setColor(1, 1, 1)
end

return dragdrop
