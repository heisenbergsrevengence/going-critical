local valve = {
	name = "valve",
	config = {
		size = { 0.5, 0.5 },
		ports = {
			input = { { x = 0, y = 0.25 } },
			output = { { x = 0.5, y = 0.25 } },
		},
	},
	controls = {
		position = 100, -- percent open (0-100)
	},
	state = {
		upstream_pressure = 0,
		downstream_pressure = 0,
		flow_rate = 0,
		stuck = false,
		stuck_position = nil,
	},
}

-- throttles or blocks fluid flow
function valve.run(self, dt, input)
	local state = self.state
	local controls = self.controls

	state.upstream_pressure = input.pressure

	-- if stuck, ignore control input
	local effective_position = controls.position
	if state.stuck then
		effective_position = state.stuck_position
	end

	-- flow and pressure based on position
	local flow_factor = effective_position / 100
	state.flow_rate = input.flow_rate * flow_factor
	state.downstream_pressure = input.pressure * (0.5 + 0.5 * flow_factor) -- some pressure drop

	local output = {
		temp = input.temp,
		pressure = state.downstream_pressure,
		flow_rate = state.flow_rate,
	}

	return output, state
end

return valve
