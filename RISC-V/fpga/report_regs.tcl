open_project [file join [file dirname [info script]] vivado_timing riscv_timing.xpr]
open_run impl_1
set n [llength [all_registers]]
puts "REGISTER_COUNT: $n"
report_utilization -file [file join [file dirname [info script]] vivado_timing utilization.rpt]
if {$n > 0} {
  report_timing_summary -file [file join [file dirname [info script]] vivado_timing timing_impl.rpt]
  set paths [get_timing_paths -setup -max_paths 1]
  set wns [get_property SLACK $paths]
  set period [get_property PERIOD [get_clocks clk]]
  set fmax [expr {1000.0 / ($period - $wns)}]
  puts "WNS: $wns ns  Period: $period ns  Fmax: $fmax MHz"
}
exit 0
