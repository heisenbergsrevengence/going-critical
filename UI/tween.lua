local tween = {}

-- Active tweens list
local tweens = {}

-- Easing functions
local easings = {
	linear = function(t) return t end,
	inQuad = function(t) return t * t end,
	outQuad = function(t) return t * (2 - t) end,
	inOutQuad = function(t)
		if t < 0.5 then return 2 * t * t end
		return -1 + (4 - 2 * t) * t
	end,
	outCubic = function(t)
		t = t - 1
		return t * t * t + 1
	end,
	outBack = function(t)
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
	end,
}

-- Create a new tween
-- target: table whose properties will be tweened
-- props: table of {property = targetValue}
-- duration: time in seconds
-- options: {easing = "outQuad", onComplete = function, delay = 0}
function tween.to(target, props, duration, options)
	options = options or {}
	local t = {
		target = target,
		props = {},
		duration = duration,
		elapsed = 0,
		delay = options.delay or 0,
		easing = easings[options.easing or "outQuad"] or easings.outQuad,
		onComplete = options.onComplete,
		started = false,
	}

	-- Store start values
	for prop, endVal in pairs(props) do
		t.props[prop] = {
			start = target[prop],
			finish = endVal,
		}
	end

	table.insert(tweens, t)
	return t
end

-- Cancel a specific tween
function tween.cancel(t)
	for i, tw in ipairs(tweens) do
		if tw == t then
			table.remove(tweens, i)
			return true
		end
	end
	return false
end

-- Cancel all tweens on a target
function tween.cancelAll(target)
	for i = #tweens, 1, -1 do
		if tweens[i].target == target then
			table.remove(tweens, i)
		end
	end
end

-- Update all tweens (call from love.update)
function tween.update(dt)
	for i = #tweens, 1, -1 do
		local t = tweens[i]

		-- Handle delay
		if t.delay > 0 then
			t.delay = t.delay - dt
		else
			t.elapsed = t.elapsed + dt
			local progress = math.min(t.elapsed / t.duration, 1)
			local easedProgress = t.easing(progress)

			-- Update each property
			for prop, vals in pairs(t.props) do
				t.target[prop] = vals.start + (vals.finish - vals.start) * easedProgress
			end

			-- Complete?
			if progress >= 1 then
				if t.onComplete then
					t.onComplete()
				end
				table.remove(tweens, i)
			end
		end
	end
end

-- Check if any tweens are active on a target
function tween.isActive(target)
	for _, t in ipairs(tweens) do
		if t.target == target then
			return true
		end
	end
	return false
end

-- Get number of active tweens
function tween.count()
	return #tweens
end

return tween
