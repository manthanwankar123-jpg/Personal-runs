class hdmi_tx_sink_sequencer extends uvm_sequencer #(hdmi_tx_sink_item);
  `uvm_component_utils(hdmi_tx_sink_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
