// SPEC.md §2 Phase 2b — Unified DDC/SCDC + DSC encoder (§2.1, §2.2)
class hdmi_tx_spec_phase2b_test extends hdmi_tx_spec_phase_base_test;
  `uvm_component_utils(hdmi_tx_spec_phase2b_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    spec_phase = SPEC_PHASE2B;
  endfunction
endclass
