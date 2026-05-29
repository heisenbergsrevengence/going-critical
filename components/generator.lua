local generator = {
	name = "generator",
	config = {
		size = { 2, 2 },
		ports = {
			input = { { x = 0, y = 0.5 } },
			output = { { x = 2, y = 0.5 } },
		},
		rated_voltage = 20, -- kV
		rated_frequency = 50, -- Hz
		rated_power = 1000, -- MW
	},
	controls = {},
	state = {
		voltage = 0,
		frequency = 0,
		power_output = 0, -- MW
		winding_temp = 50,
		integrity = 100,
	},
}

-- input is mechanical rotation from turbine (rpm-based)
function generator.run(self, dt, turbine_rpm, turbine_power)
	local state = self.state
	local config = self.config

	-- frequency proportional to rpm (assuming 2-pole generator)
	state.frequency = turbine_rpm / 60

	-- voltage proportional to rpm
	state.voltage = config.rated_voltage * (turbine_rpm / 3000)

	-- power output from turbine
	state.power_output = turbine_power * (state.integrity / 100)

	-- winding temperature rises with load
	local load_factor = state.power_output / config.rated_power
	state.winding_temp = 50 + load_factor * 100

	-- overspeed causes overvoltage damage
	if state.voltage > config.rated_voltage * 1.1 then
		state.integrity = state.integrity - dt * 5
	end

	-- overheating damage
	if state.winding_temp > 150 then
		state.integrity = state.integrity - dt * 2
	end

	state.integrity = math.max(0, state.integrity)

	return state
end

return generator
