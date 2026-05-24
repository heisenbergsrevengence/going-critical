local pump = {
	config = {
		size = { 1, 0.5 },
		ports = {
			input = { { side = "left", fluid = "water" } },
			output = { { side = "right", fluid = "water" } },
		},
	},
	controls = {
		power = 10, -- watts i guess? its not being powered BY anything
	},
	state = {
		flow_rate = 100, -- kg/hr
		temp = 100, -- celcius
		integrity = 100, --percent,also counts as effeciency
		pressure = 6.5, -- Mpa
	},
}
-- pump curve: pressure_rise = max_head * (1 - (flow_rate/max_flow)^2)
-- rearranged: flow_rate = max_flow * sqrt(1 - (pressure_rise/max_head))

-- resistance comes from downstream; sum of all valve positions, component drops
-- input = { temp, pressure, flow_rate } of incoming
function pump.run(self, dt, input, downstream_resistance)
	local state = self.state
	local controls = self.controls
	local speed_fraction = (state.power / 100) * (state.integrity / 100)

	-- scale max values by speed; both head and flow scale with speed
	local max_head = 8.0 * speed_fraction -- MPa, tunable per pump type
	local max_flow = 500 * speed_fraction -- kg/s, tunable per pump type

	-- operating point: where pump curve meets system resistance
	-- pressure_rise = resistance * flow^2  AND  pressure_rise = max_head*(1-(flow/max_flow)^2)
	-- solving for flow_rate:
	local flow_rate = max_flow * math.sqrt(max_head / (max_head + downstream_resistance * max_flow ^ 2))
	local pressure_rise = downstream_resistance * flow_rate ^ 2

	-- cavitation: if inlet pressure too low, pump loses flow rapidly
	local npsh_required = 0.5 -- MPa minimum inlet pressure, tunable
	if input.pressure < npsh_required then
		local cavitation_factor = input.pressure / npsh_required
		flow_rate = flow_rate * cavitation_factor ^ 2
		pressure_rise = pressure_rise * cavitation_factor
		state.integrity = state.integrity - (1 - cavitation_factor) * dt * 10
	end

	local output = {
		temp = input.temp,
		pressure = input.pressure + pressure_rise,
		flow_rate = flow_rate,
	}

	return output, state
end

return pump
