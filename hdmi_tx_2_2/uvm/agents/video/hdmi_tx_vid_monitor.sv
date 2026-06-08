class hdmi_tx_vid_monitor extends uvm_monitor;
  `uvm_component_utils(hdmi_tx_vid_monitor)

  virtual hdmi_tx_vid_if vif;
  uvm_analysis_port #(hdmi_tx_vid_item) ap;
  int unsigned frame_cnt;
  int unsigned pixel_cnt;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual hdmi_tx_vid_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "vid vif not set")
  endfunction

  task run_phase(uvm_phase phase);
    hdmi_tx_vid_item tr;
    logic vsync_d;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.vsync && !vsync_d)
        frame_cnt++;
      vsync_d = vif.mon_cb.vsync;
      if (vif.mon_cb.de) begin
        tr = hdmi_tx_vid_item::type_id::create("tr");
        tr.data  = vif.mon_cb.data;
        tr.de    = vif.mon_cb.de;
        tr.hsync = vif.mon_cb.hsync;
        tr.vsync = vif.mon_cb.vsync;
        tr.burst_len = 1;
        pixel_cnt++;
        ap.write(tr);
      end
    end
  endtask
endclass
