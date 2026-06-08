class hdmi_tx_reg_agent extends uvm_agent;
  `uvm_component_utils(hdmi_tx_reg_agent)

  hdmi_tx_reg_driver    drv;
  hdmi_tx_reg_monitor   mon;
  hdmi_tx_reg_sequencer sqr;
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = hdmi_tx_reg_monitor::type_id::create("mon", this);
    if (is_active == UVM_ACTIVE) begin
      drv = hdmi_tx_reg_driver::type_id::create("drv", this);
      sqr = hdmi_tx_reg_sequencer::type_id::create("sqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
