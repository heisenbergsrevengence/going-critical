local condenser = {
	name = "condenser",
	config = {
		size = { 2, 2 },
		ports = {
			input = {
				{ x = 0, y = 0.5, label = "steam" },
				{ x = 0.5, y = 2, label = "cooling" },
			},
			output = {
				{ x = 2, y = 0.5, label = "feedwater" },
				{ x = 0.5, y = 0, label = "cooling" },
			},
		},
	},
	controls = {},
	state = {
		inlet_steam_pressure = 0,
		inlet_steam_temp = 0,
		outlet_water_temp = 0,
		cooling_flow_rate = 0,
		vacuum_pressure = 0.005, -- MPa, low pressure for efficiency
		integrity = 100,
		tube_leak = false,
	},
}

-- condenses low pressure steam back to water for feedwater
function condenser.run(self, dt, input_steam, input_cooling)
	local state = self.state
	local config = self.config

	state.inlet_steam_pressure = input_steam.pressure
	state.inlet_steam_temp = input_steam.temp
	state.cooling_flow_rate = input_cooling.flow_rate

	-- condensation rate depends on cooling water flow
	local cooling_effectiveness = input_cooling.flow_rate / 100
	local condensation_rate = input_steam.flow_rate * cooling_effectiveness

	-- outlet water temp based on heat rejection
	state.outlet_water_temp = input_cooling.temp + (input_steam.temp - input_cooling.temp) * 0.3

	-- vacuum pressure rises if cooling is insufficient
	if cooling_effectiveness < 0.5 then
		state.vacuum_pressure = state.vacuum_pressure + dt * 0.01
	else
		state.vacuum_pressure = math.max(0.005, state.vacuum_pressure - dt * 0.005)
	end

	-- tube leak contaminates feedwater
	if state.integrity < 70 then
		state.tube_leak = true
	end

	local output_feedwater = {
		temp = state.outlet_water_temp,
		pressure = state.vacuum_pressure,
		flow_rate = condensation_rate,
		phase = "water",
	}

	local output_cooling = {
		temp = input_cooling.temp + 10, -- warmed by condensation
		pressure = input_cooling.pressure,
		flow_rate = input_cooling.flow_rate,
	}

	return output_feedwater, output_cooling, state
end

return condenser
