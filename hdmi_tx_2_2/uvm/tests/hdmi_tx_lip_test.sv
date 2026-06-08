// Legacy alias → SPEC.md §3.2 LIP (subset of Phase 3)
class hdmi_tx_lip_test extends hdmi_tx_spec_phase3_test;
  `uvm_component_utils(hdmi_tx_lip_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass
