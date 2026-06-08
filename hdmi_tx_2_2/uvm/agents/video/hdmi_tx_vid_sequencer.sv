class hdmi_tx_vid_sequencer extends uvm_sequencer #(hdmi_tx_vid_item);
  `uvm_component_utils(hdmi_tx_vid_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
