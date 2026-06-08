class hdmi_tx_sink_agent extends uvm_agent;
  `uvm_component_utils(hdmi_tx_sink_agent)

  hdmi_tx_sink_driver  drv;
  hdmi_tx_sink_sequencer sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = hdmi_tx_sink_driver::type_id::create("drv", this);
    sqr = hdmi_tx_sink_sequencer::type_id::create("sqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
