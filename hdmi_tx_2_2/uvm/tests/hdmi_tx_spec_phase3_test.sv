// SPEC.md §3 Phase 3 — FRL 96G (Ultra96), LIP (§3.2), RS-FEC (§3.3)
class hdmi_tx_spec_phase3_test extends hdmi_tx_spec_phase_base_test;
  `uvm_component_utils(hdmi_tx_spec_phase3_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    spec_phase = SPEC_PHASE3;
  endfunction
endclass
