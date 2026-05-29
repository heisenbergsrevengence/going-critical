local pipe = {
	name = "pipe",
	config = {
		-- Pipe is special: no fixed size, defined by start/end points
		-- No ports
		lineWidth = 7,
	},
	controls = {},
	state = {
		flow_rate = 0,
		temp = 20,
		pressure = 0,
	},
}

-- Create a new pipe instance with start/end points
function pipe.createInstance(startX, startY, endX, endY)
	return {
		name = "pipe",
		startX = startX, -- grid-relative x
		startY = startY, -- grid-relative y
		endX = endX,
		endY = endY,
		config = pipe.config,
		state = {
			flow_rate = 0,
			temp = 20,
			pressure = 0,
		},
	}
end

function pipe.run(self, dt, input)
	local state = self.state

	state.flow_rate = input.flow_rate
	state.temp = input.temp
	state.pressure = input.pressure

	local output = {
		temp = input.temp,
		pressure = input.pressure * 0.99, -- tiny friction loss
		flow_rate = input.flow_rate,
	}

	return output, state
end

return pipe
