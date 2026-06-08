class hdmi_tx_vid_driver extends uvm_driver #(hdmi_tx_vid_item);
  `uvm_component_utils(hdmi_tx_vid_driver)

  virtual hdmi_tx_vid_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual hdmi_tx_vid_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "vid vif not set")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      repeat (req.burst_len) begin
        @(vif.drv_cb);
        vif.drv_cb.data  <= req.data;
        vif.drv_cb.de    <= req.de;
        vif.drv_cb.hsync <= req.hsync;
        vif.drv_cb.vsync <= req.vsync;
      end
      seq_item_port.item_done();
    end
  endtask
endclass
