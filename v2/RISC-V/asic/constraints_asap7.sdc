# constraints_asap7.sdc — ASAP7 core STA (OpenSTA, 1 ps time unit)
# Clock period set in sta_run.tcl from STA_PERIOD (picoseconds).

set_input_delay  1000 -clock clk [get_ports rst]
set_output_delay 1000 -clock clk [get_ports {dbg_pc trap_entered}]

set_false_path -from [get_ports rst]

set_load 0.005 [all_outputs]
