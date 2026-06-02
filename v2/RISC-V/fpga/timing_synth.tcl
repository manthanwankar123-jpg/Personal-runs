# timing_synth.tcl — Vivado synth+impl for v2 Fmax estimate
# Usage: vivado -mode batch -source fpga/timing_synth.tcl -tclargs <part> [target_mhz]

set proj_root [file normalize [file dirname [info script]]/..]
cd $proj_root

set part "xc7a35tcsg324-1"
set target_mhz 50.0
if {[llength $argv] >= 1} {
  set part [lindex $argv 0]
}
if {[llength $argv] >= 2} {
  set target_mhz [lindex $argv 1]
}
set req_period [expr {1000.0 / $target_mhz}]
set io_delay [expr {min(2.0, $req_period * 0.10)}]

set rtl_dir [file join $proj_root rtl]
set out_dir [file join $proj_root fpga vivado_timing [string tolower $part]]
file mkdir $out_dir
file copy -force [file join $proj_root sim program.hex] [file join $out_dir program.hex]

puts "INFO: Project root: $proj_root"
puts "INFO: Target part:  $part"

create_project -force riscv_timing_v2 $out_dir -part $part
set_property target_language Verilog [current_project]
set_property verilog_define {FPGA_TIMING_SYNTH} [current_fileset]

read_verilog -sv \
  [file join $rtl_dir riscv_pkg.sv] \
  [file join $rtl_dir instr_rom.sv] \
  [file join $rtl_dir alu.sv] \
  [file join $rtl_dir regfile.sv] \
  [file join $rtl_dir imm_gen.sv] \
  [file join $rtl_dir control.sv] \
  [file join $rtl_dir csr_file.sv] \
  [file join $rtl_dir unified_mem.sv] \
  [file join $rtl_dir riscv_core.sv]
read_verilog -sv [file join [file dirname [info script]] riscv_core_sta_top.sv]

cd $out_dir
synth_design -top riscv_core_sta_top -part $part -flatten_hierarchy none
cd $proj_root

set nregs_syn [llength [all_registers]]
puts "INFO: Register count after synth: $nregs_syn"

set hc [get_cells -hierarchical -filter {REF_NAME == riscv_core}]
if {[llength $hc] > 0} {
  set_property KEEP_HIERARCHY true $hc
}

create_clock -name clk -period $req_period [get_ports clk]
set_input_delay  -clock clk $io_delay [get_ports rst]
set_output_delay -clock clk $io_delay [get_ports {dbg_pc trap_entered}]
set_false_path -from [get_ports rst]
# Debug outputs are registered but not on the core critical path
set_false_path -to [get_ports {dbg_pc trap_entered}]

place_design
route_design

write_checkpoint -force [file join $out_dir riscv_core_routed.dcp]

set nregs [llength [all_registers]]
puts "INFO: Register count after route: $nregs"

set rpt [file join $out_dir timing_summary.rpt]
report_timing_summary -delay_type min_max -report_unconstrained \
  -check_timing_verbose -file $rpt -max_paths 10 -input_pins -routable_nets

set wns ""
set tns ""
if {[llength [get_clocks -quiet clk]] > 0} {
  set req_period [get_property PERIOD [get_clocks clk]]
}
set paths [get_timing_paths -setup -max_paths 1 -quiet]
if {[llength $paths] > 0} {
  set wns [get_property SLACK $paths]
}
set tns_paths [get_timing_paths -setup -nworst 2000 -quiet]
if {[llength $tns_paths] > 0} {
  set tns 0.0
  foreach p $tns_paths {
    set s [get_property SLACK $p]
    if {$s < 0} { set tns [expr {$tns + $s}] }
  }
}

set fmax_mhz "N/A"
if {$wns ne ""} {
  set achieved_period [expr {$req_period - $wns}]
  if {$achieved_period > 0.001} {
    set fmax_mhz [expr {1000.0 / $achieved_period}]
  }
}

puts ""
puts "============================================================"
puts "  v2 pipelined core"
puts "  Part:          $part"
puts "  Constraint:    [format %.1f [expr {1000.0 / $req_period}]] MHz ([format %.3f $req_period] ns)"
puts "  WNS:           $wns ns"
puts "  TNS:           $tns ns"
if {$fmax_mhz eq "N/A"} {
  puts "  Est. Fmax:     N/A"
} else {
  puts "  Est. Fmax:     [format %.1f $fmax_mhz] MHz"
}
puts "  Report:        $rpt"
puts "============================================================"

report_utilization -file [file join $out_dir utilization.rpt]
report_ram -file [file join $out_dir ram.rpt]

close_project
exit 0
