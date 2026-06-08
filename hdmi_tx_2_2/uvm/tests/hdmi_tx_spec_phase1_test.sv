// SPEC.md §1 Phase 1 — TMDS 4K@60 RGB888
class hdmi_tx_spec_phase1_test extends hdmi_tx_spec_phase_base_test;
  `uvm_component_utils(hdmi_tx_spec_phase1_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    spec_phase = SPEC_PHASE1;
  endfunction
endclass
