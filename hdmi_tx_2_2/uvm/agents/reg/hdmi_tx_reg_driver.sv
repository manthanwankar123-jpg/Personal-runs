class hdmi_tx_reg_driver extends uvm_driver #(hdmi_tx_reg_item);
  `uvm_component_utils(hdmi_tx_reg_driver)

  virtual hdmi_tx_reg_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual hdmi_tx_reg_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "reg vif not set")
  endfunction

  task run_phase(uvm_phase phase);
    @(vif.drv_cb);
    forever begin
      seq_item_port.get_next_item(req);
      @(vif.drv_cb);
      vif.drv_cb.wr   <= 1'b0;
      vif.drv_cb.rd   <= 1'b0;
      vif.drv_cb.addr <= req.addr;
      if (req.op == REG_WRITE)
        vif.drv_cb.wdata <= req.data;
      @(vif.drv_cb);
      if (req.op == REG_WRITE)
        vif.drv_cb.wr <= 1'b1;
      else
        vif.drv_cb.rd <= 1'b1;
      @(vif.drv_cb);
      if (req.op == REG_READ)
        req.data = vif.drv_cb.rdata;
      vif.drv_cb.wr <= 1'b0;
      vif.drv_cb.rd <= 1'b0;
      seq_item_port.item_done();
    end
  endtask
endclass
