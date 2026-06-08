class hdmi_tx_phy_monitor extends uvm_monitor;
  `uvm_component_utils(hdmi_tx_phy_monitor)

  virtual hdmi_tx_phy_if vif;
  uvm_analysis_port #(hdmi_tx_phy_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual hdmi_tx_phy_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "phy vif not set")
  endfunction

  task run_phase(uvm_phase phase);
    hdmi_tx_phy_item tr;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.valid || vif.mon_cb.tmds_valid) begin
        tr = hdmi_tx_phy_item::type_id::create("tr");
        tr.valid       = vif.mon_cb.valid;
        tr.tmds_valid  = vif.mon_cb.tmds_valid;
        tr.is_frl      = vif.mon_cb.is_frl;
        for (int i = 0; i < 4; i++) begin
          tr.data[i] = vif.mon_cb.data[i];
          tr.tmds[i] = vif.mon_cb.tmds[i];
        end
        ap.write(tr);
      end
    end
  endtask
endclass
