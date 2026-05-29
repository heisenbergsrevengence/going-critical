local shunt_valve = {
	name = "shunt valve",
	config = {
		size = { 1, 1 },
		ports = {
			input = { { x = 0, y = 0.5 } },
			output = {
				{ x = 1, y = 0.5, label = "A" },
				{ x = 0.5, y = 0, label = "B" },
			},
		},
	},
	controls = {
		split_ratio = 50, -- percent to output A (remainder to B)
	},
	state = {
		input_flow_rate = 0,
		output_a_flow_rate = 0,
		output_b_flow_rate = 0,
		stuck = false,
		stuck_ratio = nil,
	},
}

-- splits flow between two outputs
function shunt_valve.run(self, dt, input)
	local state = self.state
	local controls = self.controls

	state.input_flow_rate = input.flow_rate

	-- if stuck, ignore control input
	local effective_ratio = controls.split_ratio
	if state.stuck then
		effective_ratio = state.stuck_ratio
	end

	local ratio_a = effective_ratio / 100
	local ratio_b = 1 - ratio_a

	state.output_a_flow_rate = input.flow_rate * ratio_a
	state.output_b_flow_rate = input.flow_rate * ratio_b

	local output_a = {
		temp = input.temp,
		pressure = input.pressure * 0.95,
		flow_rate = state.output_a_flow_rate,
	}

	local output_b = {
		temp = input.temp,
		pressure = input.pressure * 0.95,
		flow_rate = state.output_b_flow_rate,
	}

	return output_a, output_b, state
end

return shunt_valve
