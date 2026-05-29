local heat_exchanger = {
	name = "heat exchanger",
	config = {
		size = { 2, 2 },
		ports = {
			input = {
				{ x = 0, y = 0.5, label = "primary" },
				{ x = 0.5, y = 2, label = "secondary" },
			},
			output = {
				{ x = 2, y = 0.5, label = "primary" },
				{ x = 0.5, y = 0, label = "secondary" },
			},
		},
		heat_transfer_coefficient = 0.5, -- how efficiently heat transfers
	},
	controls = {},
	state = {
		primary_temp = 100,
		primary_pressure = 1.0,
		secondary_temp = 20,
		secondary_pressure = 1.0,
		heat_transfer_rate = 0,
		fouling = 0, -- 0-100, reduces efficiency
		integrity = 100,
	},
}

-- input_primary = hot water from reactor
-- input_secondary = cold water from cooling circuit
function heat_exchanger.run(self, dt, input_primary, input_secondary)
	local state = self.state
	local config = self.config

	-- fouling reduces heat transfer efficiency
	local efficiency = config.heat_transfer_coefficient * (1 - state.fouling / 100)

	-- heat transfer based on temperature difference
	local temp_delta = input_primary.temp - input_secondary.temp
	local transfer = temp_delta * efficiency * math.min(input_primary.flow_rate, input_secondary.flow_rate) * dt

	state.heat_transfer_rate = transfer / dt
	state.primary_temp = input_primary.temp - transfer / math.max(input_primary.flow_rate, 0.1)
	state.secondary_temp = input_secondary.temp + transfer / math.max(input_secondary.flow_rate, 0.1)
	state.primary_pressure = input_primary.pressure
	state.secondary_pressure = input_secondary.pressure

	-- leak failure: if integrity drops, fluids mix
	if state.integrity < 50 then
		local leak_rate = (50 - state.integrity) / 50
		state.secondary_pressure = state.secondary_pressure + (input_primary.pressure - input_secondary.pressure) * leak_rate * 0.1
	end

	local output_primary = {
		temp = state.primary_temp,
		pressure = input_primary.pressure * 0.98,
		flow_rate = input_primary.flow_rate,
	}

	local output_secondary = {
		temp = state.secondary_temp,
		pressure = state.secondary_pressure * 0.98,
		flow_rate = input_secondary.flow_rate,
	}

	return output_primary, output_secondary, state
end

return heat_exchanger
