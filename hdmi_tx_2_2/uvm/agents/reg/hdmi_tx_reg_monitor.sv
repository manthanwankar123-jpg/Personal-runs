class hdmi_tx_reg_monitor extends uvm_monitor;
  `uvm_component_utils(hdmi_tx_reg_monitor)

  virtual hdmi_tx_reg_if vif;
  uvm_analysis_port #(hdmi_tx_reg_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual hdmi_tx_reg_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "reg vif not set")
  endfunction

  task run_phase(uvm_phase phase);
    hdmi_tx_reg_item tr;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.wr || vif.mon_cb.rd) begin
        tr = hdmi_tx_reg_item::type_id::create("tr");
        tr.op   = vif.mon_cb.wr ? REG_WRITE : REG_READ;
        tr.addr = vif.mon_cb.addr;
        tr.data = vif.mon_cb.wr ? vif.mon_cb.wdata : vif.mon_cb.rdata;
        ap.write(tr);
      end
    end
  endtask
endclass
