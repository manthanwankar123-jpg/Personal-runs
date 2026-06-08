// Legacy alias → SPEC.md §6 regression
class hdmi_tx_regression_test extends hdmi_tx_spec_regression_test;
  `uvm_component_utils(hdmi_tx_regression_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass
