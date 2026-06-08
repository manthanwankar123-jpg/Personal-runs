// Legacy alias → SPEC.md §1 Phase 2 (VRR/ALLM)
class hdmi_tx_gaming_test extends hdmi_tx_spec_phase2_test;
  `uvm_component_utils(hdmi_tx_gaming_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass
