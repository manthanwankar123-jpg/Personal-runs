# report_timing_mhz.tcl — re-report timing on an existing routed DCP (seconds, not hours)
# Usage: vivado -mode batch -source fpga/report_timing_mhz.tcl -tclargs <mhz> [part_or_dcp]

set target_mhz 200.0
if {[llength $argv] >= 1} {
  set target_mhz [lindex $argv 0]
}

set fpga_dir [file normalize [file dirname [info script]]]
set dcp [file join $fpga_dir vivado_timing riscv_core_routed.dcp]
if {[llength $argv] >= 2} {
  set arg2 [string tolower [lindex $argv 1]]
  if {[string match *.dcp $arg2]} {
    set dcp [file normalize $arg2]
  } else {
    set dcp [file join $fpga_dir vivado_timing $arg2 riscv_core_routed.dcp]
  }
}

if {![file exists $dcp]} {
  puts "ERROR: No routed checkpoint at $dcp"
  puts "Run first:  cd fpga && ./run_timing.sh <part> 50"
  exit 1
}

set req_period [expr {1000.0 / $target_mhz}]
set io_delay [expr {min(2.0, $req_period * 0.10)}]

open_checkpoint $dcp

reset_timing
create_clock -name clk -period $req_period [get_ports clk]
set_input_delay  -clock clk $io_delay [get_ports rst]
set_output_delay -clock clk $io_delay [get_ports {dbg_pc trap_entered}]
set_false_path -from [get_ports rst]
set_false_path -to [get_ports {dbg_pc trap_entered}]

set rpt_dir [file dirname $dcp]
set rpt [file join $rpt_dir timing_summary_${target_mhz}mhz.rpt]
report_timing_summary -delay_type min_max -report_unconstrained \
  -check_timing_verbose -file $rpt -max_paths 10 -input_pins -routable_nets

set wns ""
set tns 0.0
set paths [get_timing_paths -setup -max_paths 1 -quiet]
if {[llength $paths] > 0} {
  set wns [get_property SLACK $paths]
}
foreach p [get_timing_paths -setup -nworst 5000 -quiet] {
  set s [get_property SLACK $p]
  if {$s < 0} { set tns [expr {$tns + $s}] }
}

set fmax_mhz "N/A"
if {$wns ne ""} {
  set achieved [expr {$req_period - $wns}]
  if {$achieved > 0.001} {
    set fmax_mhz [expr {1000.0 / $achieved}]
  }
}

set part [get_property PART [current_design]]

puts ""
puts "============================================================"
puts "  v2 — timing report on routed checkpoint (no re-route)"
puts "  Part:          $part"
puts "  Constraint:    [format %.1f $target_mhz] MHz ([format %.3f $req_period] ns)"
puts "  WNS:           $wns ns"
puts "  TNS:           $tns ns"
if {$fmax_mhz eq "N/A"} {
  puts "  Est. Fmax:     N/A (same placement; see WNS)"
} else {
  puts "  Est. Fmax:     [format %.1f $fmax_mhz] MHz"
}
if {$wns ne "" && $wns < 0} {
  puts "  => Does NOT meet [format %.0f $target_mhz] MHz (need more RTL/timing work)"
}
puts "  Report:        $rpt"
puts "  Checkpoint:    $dcp"
puts "============================================================"

close_design
exit 0
