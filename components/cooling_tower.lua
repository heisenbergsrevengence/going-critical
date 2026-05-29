local cooling_tower = {
	name = "cooling tower",
	config = {
		size = { 3, 4 },
		ports = {
			input = { { x = 1.5, y = 4 } },
			output = { { x = 1.5, y = 0 } },
		},
		max_cooling_rate = 50, -- degrees C
	},
	controls = {},
	state = {
		inlet_temp = 0,
		outlet_temp = 0,
		evaporation_loss = 0, -- percent of flow
		integrity = 100,
		blockage = 0, -- percent blocked
	},
}

-- cools warm water through evaporation
function cooling_tower.run(self, dt, input)
	local state = self.state
	local config = self.config

	state.inlet_temp = input.temp

	-- cooling effectiveness reduced by blockage and integrity
	local effectiveness = (1 - state.blockage / 100) * (state.integrity / 100)
	local cooling = math.min(config.max_cooling_rate, input.temp - 20) * effectiveness

	state.outlet_temp = input.temp - cooling
	state.outlet_temp = math.max(20, state.outlet_temp) -- can't cool below ambient

	-- evaporation loss proportional to cooling
	state.evaporation_loss = (cooling / config.max_cooling_rate) * 3 -- up to 3% loss

	local output = {
		temp = state.outlet_temp,
		pressure = input.pressure,
		flow_rate = input.flow_rate * (1 - state.evaporation_loss / 100),
	}

	return output, state
end

return cooling_tower
