open_checkpoint /mnt/hw/users/manthan/Personal_runs/RISC-V/fpga/vivado_timing/riscv_core_routed.dcp
puts "all_registers: [llength [all_registers]]"
set ffs [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ *FDRE*}]
puts "FDRE cells: [llength $ffs]"
set bram [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ RAMB*}]
puts "RAMB cells: [llength $bram]"
set lutram [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ RAMD*}]
puts "RAMD/LUTRAM: [llength $lutram]"
if {[llength $ffs] > 0} {
  puts [get_property PRIMITIVE_TYPE [lindex $ffs 0]]
}
report_utilization -summary
exit 0
