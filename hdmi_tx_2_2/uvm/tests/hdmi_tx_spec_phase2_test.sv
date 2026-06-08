// SPEC.md §1 Phase 2 — FRL 48G, VRR/ALLM, 10bpc, YUV422
class hdmi_tx_spec_phase2_test extends hdmi_tx_spec_phase_base_test;
  `uvm_component_utils(hdmi_tx_spec_phase2_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    spec_phase = SPEC_PHASE2;
  endfunction
endclass
