each components can be described as a pure-ish function with an input and output,with each module in the components/ dir being treated as a component

Pipe:
  - technically not a reactor component like the rest but still will be coded as one
  - simply passes one component's output to another's input,doesnt do transforms
  - this allows for emergent behavior(eg if a player wires a pipe between 2 non-trivial components(like a heat exchanger and reactor) the simulation would be accurate)

Reactor Core
- Controls: control rod position (0-100%)/power level, SCRAM button
- Readable: water level, water temp, control rod integrity, core temp, core integrity, neutron flux (power level indicator)
- Inputs: water (flow rate, temp, pressure)
- Outputs: water (higher temp, higher pressure)
- Failure modes:
  - Low coolant flow → core overheat
  - Core overheat → control rod integrity decrease
  - Control rod integrity loss → loss of reactivity control
  - Core integrity loss → meltdown → game over
- Hot-swappable: No ; requires SCRAM first

 

Heat Exchanger
- Controls: none (passive)
- Readable: primary side temp/pressure, secondary side temp/pressure, heat transfer rate
- Inputs: hot water (primary circuit), cold water (secondary circuit)
- Outputs: cooler water (primary), hotter water or steam (secondary, depending on temp delta)
- Failure modes:
  - Primary/secondary circuit leak → fluid mixing → pressure spike on secondary side → pipe rupture risk
  - Fouling (gradual) → reduced heat transfer rate visible on readings
- Hot-swappable: No ; requires SCRAM, high residual heat risk

 

Steam Generator (distinct from heat exchanger ; produces dry steam for turbine)
- Controls: none (passive)
- Readable: steam pressure, steam temp, water level
- Inputs: hot water or steam (from heat exchanger)
- Outputs: dry high-pressure steam
- Failure modes:
  - Low water level → dry firing → component damage
  - Overpressure → rupture disc blows → loss of steam supply
- Hot-swappable: No

 

Pressurizer (relevant for pressurized water reactor later ; keeps primary coolant liquid under high pressure)
- Controls: heater on/off, relief valve
- Readable: system pressure, water level inside pressurizer
- Inputs: water (from primary circuit)
- Outputs: pressure signal to primary circuit
- Failure modes:
  - Heater stuck on → overpressure
  - Relief valve stuck open → loss of coolant pressure → coolant flashes to steam in core
- Hot-swappable: No

 

Turbine
- Controls: governor/speed setpoint, manual trip
- Readable: rotations per minute, inlet steam pressure, outlet steam pressure, power output (megawatts)
- Inputs: high pressure steam
- Outputs: low pressure steam, electricity
- Failure modes:
  - Steam overpressure → blade damage → catastrophic unbalance → full turbine failure
  - Overspeed (loss of load) → automatic trip should fire ; if trip fails → destruction
  - Wet steam (water droplets) → blade erosion over time, readable as efficiency loss
- Hot-swappable: Yes ; can isolate with valves while reactor runs at reduced output

 

Generator
- Controls: none (passive, coupled to turbine)
- Readable: voltage, frequency, power output
- Inputs: mechanical rotation (from turbine shaft)
- Outputs: electricity to grid
- Failure modes:
  - Overspeed from turbine → overvoltage
  - Loss of cooling → winding overheat → insulation failure
- Hot-swappable: No ; requires turbine trip first

 

Condenser
- Controls: none (passive)
- Readable: inlet steam pressure/temp, outlet water temp, cooling water flow rate
- Inputs: low pressure steam, cold water (separate cooling circuit)
- Outputs: condensed water (feedwater), warm water (to cooling tower)
- Failure modes:
  - Loss of cooling water flow → condenser pressure rises → back-pressure on turbine → turbine trip
  - Tube leak → cooling water contaminates feedwater → chemistry issue (readable as conductivity spike)
- Hot-swappable: No ; requires turbine trip

 

Cooling Tower
- Controls: none (passive)
- Readable: inlet water temp, outlet water temp, evaporation loss rate
- Inputs: warm water
- Outputs: cooled water (less volume due to evaporation), water vapor (vented)
- Failure modes:
  - Partial collapse → reduced cooling capacity → condenser back-pressure rises
  - Blockage → flow restriction
- Hot-swappable: Yes ; redundant towers can cover

 

Pump
- Controls: speed (0-100%), on/off
- Readable: flow rate, inlet pressure, outlet pressure, pump speed, motor temperature
- Inputs: fluid (any)
- Outputs: same fluid at higher pressure/flow rate
- Failure modes:
  - Cavitation (inlet pressure too low) → vibration → impeller damage → flow loss
  - Motor overheat (run dry or overloaded) → seizure → full flow loss
  - Seal failure → minor leak → gradual flow degradation
- Hot-swappable: Depends ; non-critical circuit pumps yes, primary coolant pumps no

 

Valve (on/off or throttle)
- Controls: % open (0-100%)
- Readable: upstream pressure, downstream pressure, flow rate through valve
- Inputs: fluid
- Outputs: same fluid, restricted
- Failure modes:
  - Stuck open → cannot isolate circuit
  - Stuck closed → flow blockage → upstream overpressure
- Hot-swappable: Yes if redundant path exists

 

Relief Valve / Safety Valve (automatic, not player-controlled)
- Controls: setpoint pressure (configurable before scenario start)
- Readable: state (open/closed), discharge flow rate
- Inputs: pressurized fluid
- Outputs: fluid vented to waste/atmosphere
- Failure modes:
  - Stuck open → continuous pressure bleed → system depressurization
  - Fails to open → overpressure builds unchecked → rupture
- Hot-swappable: No

 

Shunt Valve
- Controls: split ratio (% to output A vs output B)
- Readable: input flow rate, output A flow rate, output B flow rate
- Inputs: one fluid line
- Outputs: two fluid lines
- Failure modes: same as standard valve
- Hot-swappable: Yes if flow can be rerouted

 

Manifold
- Controls: none (passive)
- Readable: combined flow rate
- Inputs: two fluid lines
- Outputs: one combined fluid line (or inverse ; one in, two out)
- Failure modes: blockage, joint leak
- Hot-swappable: Yes

 

Reservoir
- Controls: none
- Readable: water level, water temp
- Inputs: none (static source)
- Outputs: cold water at fixed temp and pressure
- Failure modes: none (treated as infinite cold source for MVP)
- Hot-swappable: Yes

 

Emergency Core Cooling System(only for later more complex reactors like rmbk)
- Controls: isolation valve (arm/disarm)
- Readable: tank pressure, tank water level, injection valve state
- Inputs: none (self-contained pressurized tank)
- Outputs: high-pressure water injection into reactor core on low-pressure signal
- Failure modes:
  - Isolation valve left closed → injection fails on demand
  - Tank depressurized → insufficient injection pressure
- Hot-swappable: No


holes this list exposes that still need decisions:

1. Does steam vs. water phase state change automatically based on temp/pressure crossing thresholds, or is it fixed per pipe segment?
2. Does the player need to explicitly place a generator, or is it implicit when a turbine is placed?(and there's a bunch of other things that would be default,right?)
