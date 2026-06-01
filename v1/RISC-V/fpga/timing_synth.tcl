# timing_synth.tcl — Vivado synth+impl for Fmax estimate (no bitstream)
# Usage: vivado -mode batch -source fpga/timing_synth.tcl

set proj_root [file normalize [file dirname [info script]]/..]
cd $proj_root

# Default: Arty A7-35T; override with: vivado ... -tclargs xc7a100tcsg324-1
set part "xc7a35tcsg324-1"
if {[llength $argv] >= 1} {
  set part [lindex $argv 0]
}

set rtl_dir [file join $proj_root rtl]
set out_dir [file join $proj_root fpga vivado_timing]
file mkdir $out_dir
file copy -force [file join $proj_root sim program.hex] [file join $out_dir program.hex]

puts "INFO: Project root: $proj_root"
puts "INFO: Target part:  $part"

create_project -force riscv_timing $out_dir -part $part
set_property target_language Verilog [current_project]
set_property verilog_define {FPGA_TIMING_SYNTH} [current_fileset]

# 16 KiB memories + BRAM inference (see instr_mem.sv / data_mem.sv)
read_verilog -sv [glob -nocomplain [file join $rtl_dir *.sv]]
read_verilog -sv [file join [file dirname [info script]] riscv_core_sta_top.sv]

# Top with probe outputs so opt_design does not delete the CPU
cd $out_dir
synth_design -top riscv_core_sta_top -part $part -flatten_hierarchy none
cd $proj_root

set nregs_syn [llength [all_registers]]
puts "INFO: Register count after synth: $nregs_syn"

set hc [get_cells -hierarchical -filter {REF_NAME == riscv_core}]
if {[llength $hc] > 0} {
  set_property KEEP_HIERARCHY true $hc
}

# Probe: default 50 MHz; implementation will report achievable Fmax
create_clock -name clk -period 20.000 [get_ports clk]
set_input_delay  -clock clk 2.0 [get_ports rst]
set_output_delay -clock clk 2.0 [get_ports {halt_0 dbg_pc}]
set_false_path -from [get_ports rst]

# Keep netlist for timing (opt_design can trim "unused" CPU when outputs look constant)
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
set req_period 20.0
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
puts "  Part:          $part"
puts "  Constraint:    [format %.1f [expr {1000.0 / $req_period}]] MHz ([format %.3f $req_period] ns)"
puts "  WNS:           $wns ns"
puts "  TNS:           $tns ns"
if {$fmax_mhz eq "N/A"} {
  puts "  Est. Fmax:     N/A (no reg-to-reg paths in STA — see note below)"
} else {
  puts "  Est. Fmax:     [format %.1f $fmax_mhz] MHz"
}
puts "  Report:        $rpt"
puts "============================================================"
report_utilization -file [file join $out_dir utilization.rpt]
report_ram -file [file join $out_dir ram.rpt]

close_project
exit 0
