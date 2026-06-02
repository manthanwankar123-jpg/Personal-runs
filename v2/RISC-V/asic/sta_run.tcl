# sta_run.tcl — OpenSTA timing for mapped riscv_core_asic_top

read_liberty $::env(STA_LIBERTY)
if {[info exists ::env(STA_LIB_FILES)] && $::env(STA_LIB_FILES) ne ""} {
  foreach lib $::env(STA_LIB_FILES) {
    if {$lib ne $::env(STA_LIBERTY)} {
      read_liberty $lib
    }
  }
}

read_verilog $::env(STA_NETLIST)
link_design riscv_core_asic_top

create_clock -name clk -period $::env(STA_PERIOD) [get_ports clk]
if {[info exists ::env(STA_TIME_UNIT)] && $::env(STA_TIME_UNIT) eq "ps"} {
  set_clock_uncertainty 50 [get_clocks clk]
} else {
  set_clock_uncertainty 0.05 [get_clocks clk]
}

source $::env(STA_SDC)

report_checks -path_delay max -fields {slew cap input_pins nets} -digits 3
report_worst_slack -max -digits 3
report_tns -digits 3

set mhz [format %.1f [expr {1000.0 / $::env(STA_PERIOD)}]]
puts "Target:        $mhz MHz ($::env(STA_PERIOD) ns)"

exit 0
