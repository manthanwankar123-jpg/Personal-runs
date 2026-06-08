// Legacy alias → SPEC.md §2 Phase 2b
class hdmi_tx_dsc_test extends hdmi_tx_spec_phase2b_test;
  `uvm_component_utils(hdmi_tx_dsc_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass
