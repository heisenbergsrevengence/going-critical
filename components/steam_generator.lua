local steam_generator = {
	name = "steam generator",
	config = {
		size = { 2, 3 },
		ports = {
			input = { { x = 0, y = 1.5 } },
			output = { { x = 2, y = 1.5 } },
		},
		boiling_point = 100, -- celsius at 1 atm
		max_pressure = 15.0, -- MPa
	},
	controls = {},
	state = {
		steam_pressure = 1.0,
		steam_temp = 100,
		water_level = 80, -- percent
		integrity = 100,
		rupture_disc_blown = false,
	},
}

-- converts hot water/steam into dry high-pressure steam for turbine
function steam_generator.run(self, dt, input)
	local state = self.state
	local config = self.config

	-- water level changes based on flow in vs steam out
	local evaporation_rate = math.max(0, input.temp - config.boiling_point) * 0.1
	state.water_level = state.water_level + (input.flow_rate * 0.01 - evaporation_rate) * dt
	state.water_level = math.max(0, math.min(100, state.water_level))

	-- dry firing damage if water level too low
	if state.water_level < 20 then
		local damage_rate = (20 - state.water_level) / 20
		state.integrity = state.integrity - damage_rate * dt * 5
		state.integrity = math.max(0, state.integrity)
	end

	-- steam pressure builds from heat input
	state.steam_temp = input.temp
	state.steam_pressure = input.pressure * (state.water_level / 100) * (state.integrity / 100)

	-- rupture disc blows at max pressure
	if state.steam_pressure > config.max_pressure and not state.rupture_disc_blown then
		state.rupture_disc_blown = true
	end

	if state.rupture_disc_blown then
		state.steam_pressure = state.steam_pressure * 0.5
	end

	local output = {
		temp = state.steam_temp,
		pressure = state.steam_pressure,
		flow_rate = evaporation_rate * (state.integrity / 100),
		phase = "steam",
	}

	return output, state
end

return steam_generator
