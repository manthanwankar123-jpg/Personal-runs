class hdmi_tx_sink_driver extends uvm_driver #(hdmi_tx_sink_item);
  `uvm_component_utils(hdmi_tx_sink_driver)

  virtual hdmi_tx_sink_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual hdmi_tx_sink_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "sink vif not set")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      @(vif.drv_cb);
      vif.drv_cb.hpd        <= req.hpd;
      vif.drv_cb.phy_ready  <= req.phy_ready;
      if (req.hpd_low_cycles > 0) begin
        repeat (req.hpd_low_cycles) @(vif.drv_cb);
        vif.drv_cb.hpd <= 1'b0;
        repeat (req.hpd_low_cycles) @(vif.drv_cb);
        vif.drv_cb.hpd <= 1'b1;
      end
      seq_item_port.item_done();
    end
  endtask
endclass
