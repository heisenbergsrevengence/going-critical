local relief_valve = {
	name = "relief valve",
	config = {
		size = { 0.5, 0.5 },
		ports = {
			input = { { x = 0, y = 0.25 } },
			output = { { x = 0.5, y = 0.25 } },
		},
	},
	controls = {
		setpoint_pressure = 10.0, -- MPa, opens above this
	},
	state = {
		is_open = false,
		discharge_flow_rate = 0,
		stuck_open = false,
		stuck_closed = false,
		integrity = 100,
	},
}

-- automatic pressure relief, not player controlled during operation
function relief_valve.run(self, dt, input)
	local state = self.state
	local controls = self.controls

	-- determine if valve should be open
	local should_open = input.pressure > controls.setpoint_pressure

	if state.stuck_open then
		state.is_open = true
	elseif state.stuck_closed then
		state.is_open = false
	else
		state.is_open = should_open
	end

	-- discharge flow when open
	if state.is_open then
		state.discharge_flow_rate = input.flow_rate * 0.5 -- vents portion of flow
	else
		state.discharge_flow_rate = 0
	end

	local output = {
		temp = input.temp,
		pressure = state.is_open and controls.setpoint_pressure or input.pressure,
		flow_rate = input.flow_rate - state.discharge_flow_rate,
	}

	return output, state
end

return relief_valve
