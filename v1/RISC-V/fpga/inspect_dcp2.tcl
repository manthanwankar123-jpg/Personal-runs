open_checkpoint /mnt/hw/users/manthan/Personal_runs/RISC-V/fpga/vivado_timing/riscv_core_routed.dcp
puts "Total cells: [llength [get_cells -hierarchical]]"
report_utilization -file /tmp/u.rpt
exit 0
