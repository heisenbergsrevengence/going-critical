local turbine = {
	name = "turbine",
	config = {
		size = { 3, 2 },
		ports = {
			input = { { x = 0, y = 0.5 } },
			output = { { x = 3, y = 0.5 } },
		},
		rated_rpm = 3000,
		max_rpm = 3600, -- overspeed trip point
		rated_power = 1000, -- MW
	},
	controls = {
		governor_setpoint = 100, -- percent of rated speed
		tripped = false,
	},
	state = {
		rpm = 0,
		inlet_pressure = 0,
		outlet_pressure = 0,
		power_output = 0, -- MW
		blade_integrity = 100,
		efficiency = 100,
	},
}

-- converts high pressure steam to rotation and low pressure steam
function turbine.run(self, dt, input)
	local state = self.state
	local config = self.config
	local controls = self.controls

	state.inlet_pressure = input.pressure

	if controls.tripped then
		-- turbine coasting down
		state.rpm = state.rpm * (1 - dt * 0.1)
		state.power_output = 0
	else
		-- rpm driven by steam flow and pressure
		local target_rpm = config.rated_rpm * (controls.governor_setpoint / 100) * (input.pressure / 10)
		state.rpm = state.rpm + (target_rpm - state.rpm) * dt * 0.5

		-- overspeed protection
		if state.rpm > config.max_rpm then
			controls.tripped = true
		end

		-- power output based on rpm and steam flow
		state.power_output = (state.rpm / config.rated_rpm)
			* (input.flow_rate / 100)
			* config.rated_power
			* (state.efficiency / 100)
	end

	-- blade damage from overpressure
	if input.pressure > 12 then
		local damage = (input.pressure - 12) * dt * 2
		state.blade_integrity = math.max(0, state.blade_integrity - damage)
	end

	-- wet steam causes blade erosion
	if input.temp < 150 then
		state.efficiency = state.efficiency - dt * 0.5
		state.efficiency = math.max(50, state.efficiency)
	end

	-- catastrophic failure
	if state.blade_integrity <= 2 then
		controls.tripped = true
		state.rpm = 0
	end

	state.outlet_pressure = input.pressure * 0.1 -- large pressure drop across turbine

	local output = {
		temp = input.temp * 0.7,
		pressure = state.outlet_pressure,
		flow_rate = input.flow_rate,
		phase = "steam",
	}

	return output, state
end

return turbine
