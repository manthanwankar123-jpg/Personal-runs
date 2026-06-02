# constraints.sdc — ICsprout55 core STA (OpenSTA)
# Clock created in sta.tcl with sweepable period.

set_input_delay  1.0 -clock clk [get_ports rst]
set_output_delay 1.0 -clock clk [get_ports {dbg_pc trap_entered}]

set_false_path -from [get_ports rst]

set_load 0.005 [all_outputs]
