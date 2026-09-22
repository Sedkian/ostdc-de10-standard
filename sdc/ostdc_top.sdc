# Constrain CLOCK_50 to 50 MHz (20 ns period)
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# Automatically derive clock uncertainty for TimeQuest
derive_clock_uncertainty