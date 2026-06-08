// Legacy alias → SPEC.md §1 Phase 1
class hdmi_tx_tmds_test extends hdmi_tx_spec_phase1_test;
  `uvm_component_utils(hdmi_tx_tmds_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass
