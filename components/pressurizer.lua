local pressurizer = {
	name = "pressurizer",
	config = {
		size = { 1, 2 },
		ports = {
			input = { { x = 0.5, y = 2 } },
			output = { { x = 0.5, y = 0 } },
		},
		target_pressure = 15.5, -- MPa, typical PWR primary pressure
		max_pressure = 17.0,
	},
	controls = {
		heater_pwr = 0, -- percent in watts
	},
	state = {
		system_pressure = 15.5,
		water_level = 60, -- percent
		heater_temp = 300,
		integrity = 100,
	},
}

-- maintains primary coolant pressure to keep water liquid
function pressurizer.run(self, dt, input)
	local state = self.state
	local config = self.config
	local controls = self.controls

	-- heater increases pressure by heating water
	if controls.heater_on then
		state.heater_temp = state.heater_temp + dt * 50
		state.system_pressure = state.system_pressure + dt * 0.1
	else
		state.heater_temp = math.max(100, state.heater_temp - dt * 20)
		state.system_pressure = state.system_pressure - dt * 0.02
	end

	-- heater stuck on failure
	if state.heater_temp > 400 then
		controls.heater_on = true
	end

	-- water level from input
	state.water_level = state.water_level + input.flow_rate * 0.001 * dt
	state.water_level = math.max(0, math.min(100, state.water_level))

	-- clamp pressure
	state.system_pressure = math.max(0, math.min(config.max_pressure, state.system_pressure))

	local output = {
		temp = input.temp,
		pressure = state.system_pressure,
		flow_rate = input.flow_rate,
	}

	return output, state
end

return pressurizer
