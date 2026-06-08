class hdmi_tx_env_config extends uvm_object;
  `uvm_object_utils(hdmi_tx_env_config)

  bit fast_edid  = 1'b1;
  bit fast_scdc  = 1'b1;
  bit fast_lt    = 1'b1;
  bit hdmi22_sink = 1'b0;

  bit [7:0]  vic = 8'd97;
  bit [1:0]  pix_fmt = 0;
  bit [3:0]  bpc = 4'd8;
  bit [31:0] link_cfg = 32'h0;
  bit [31:0] ultra96_cfg = 32'h0;
  bit [15:0] lip_latency_ms = 16'd5;

  bit expect_frl   = 1'b0;
  bit expect_96g   = 1'b0;
  bit expect_vrr   = 1'b0;
  bit expect_allm  = 1'b0;
  bit expect_lip   = 1'b0;
  bit expect_dsc   = 1'b0;
  bit expect_fec   = 1'b0;
  bit expect_tmds_valid = 1'b0;
  bit deep_check_en = 1'b1;
  bit spec_mode     = 1'b0;

  int unsigned link_timeout_cycles = 5000;
  int unsigned video_lines = 4;
  int unsigned min_phy_beats = 8;
  int unsigned min_vid_pixels = 64;
  int unsigned fsm_trace_samples = 48;

  function new(string name = "hdmi_tx_env_config");
    super.new(name);
  endfunction
endclass
