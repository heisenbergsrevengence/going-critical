local manifold = {
	name = "manifold",
	config = {
		size = { 1, 1 },
		ports = {
			input = {
				{ x = 0, y = 0.5, label = "A" },
				{ x = 0.5, y = 1, label = "B" },
			},
			output = { { x = 1, y = 0.5 } },
		},
	},
	controls = {},
	state = {
		combined_flow_rate = 0,
		combined_temp = 0,
		combined_pressure = 0,
		integrity = 100,
		leak_rate = 0,
	},
}

-- combines two fluid lines into one (or can split one into two)
function manifold.run(self, dt, input_a, input_b)
	local state = self.state

	-- combine flows
	state.combined_flow_rate = input_a.flow_rate + input_b.flow_rate

	-- weighted average temperature
	local total_flow = state.combined_flow_rate
	if total_flow > 0 then
		state.combined_temp = (input_a.temp * input_a.flow_rate + input_b.temp * input_b.flow_rate) / total_flow
	else
		state.combined_temp = (input_a.temp + input_b.temp) / 2
	end

	-- average pressure with small loss
	state.combined_pressure = (input_a.pressure + input_b.pressure) / 2 * 0.98

	-- leak if integrity low
	if state.integrity < 80 then
		state.leak_rate = (80 - state.integrity) / 80 * 5 -- up to 5% leak
	else
		state.leak_rate = 0
	end

	local output = {
		temp = state.combined_temp,
		pressure = state.combined_pressure,
		flow_rate = state.combined_flow_rate * (1 - state.leak_rate / 100),
	}

	return output, state
end

return manifold
