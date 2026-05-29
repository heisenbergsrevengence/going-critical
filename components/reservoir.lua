local reservoir = {
	name = "reservoir",
	config = {
		size = { 2, 2 },
		ports = {
			input = {},
			output = { { x = 2, y = 0.5 } },
		},
		fixed_temp = 20, -- celsius, ambient
		fixed_pressure = 0.1, -- MPa, atmospheric + head
	},
	controls = {},
	state = {
		water_level = 100, -- percent (infinite for MVP)
		water_temp = 20,
	},
}

-- infinite cold water source for MVP
function reservoir.run(self, dt, demand_flow_rate)
	local state = self.state
	local config = self.config

	state.water_temp = config.fixed_temp

	local output = {
		temp = config.fixed_temp,
		pressure = config.fixed_pressure,
		flow_rate = demand_flow_rate or 100,
	}

	return output, state
end

return reservoir
