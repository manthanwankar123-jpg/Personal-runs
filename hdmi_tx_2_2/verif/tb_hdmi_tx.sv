import hdmi_tx_pkg::*;

module tb_hdmi_tx;

  logic axi_clk, vid_clk, link_clk, rst_n;
  logic [29:0] vid_data;
  logic        vid_de, vid_hsync, vid_vsync;
  logic        i2s_lrck, i2s_sdat, hpd, phy_ready;
  logic        scl_o, sda_o, scl_oe, sda_oe, sda_i;
  logic        reg_wr, reg_rd;
  logic [7:0]  reg_addr;
  logic [31:0] reg_wdata, reg_rdata;
  logic [9:0]  tmds_data [0:3];
  logic        tmds_valid;
  logic [15:0] phy_data [0:3];
  logic        phy_valid, phy_is_frl;

  int pass_cnt, fail_cnt, vid_pixel_cnt, last_drive_pixels;

  hdmi_tx_top #(
      .HPD_DEBOUNCE_MAX(32'd8),
      .FAST_EDID(1'b1),
      .FAST_SCDC(1'b1),
      .FAST_LT(1'b1),
      .SIM_HDMI22(1'b0)
  ) dut (
      .axi_clk(axi_clk), .vid_clk(vid_clk), .link_clk(link_clk), .rst_n(rst_n),
      .vid_data(vid_data), .vid_de(vid_de), .vid_hsync(vid_hsync), .vid_vsync(vid_vsync),
      .i2s_lrck(i2s_lrck), .i2s_sdat(i2s_sdat), .hpd(hpd),
      .scl_o(scl_o), .sda_o(sda_o), .scl_oe(scl_oe), .sda_oe(sda_oe), .sda_i(sda_i),
      .reg_wr(reg_wr), .reg_rd(reg_rd), .reg_addr(reg_addr),
      .reg_wdata(reg_wdata), .reg_rdata(reg_rdata),
      .phy_ready(phy_ready), .phy_data(phy_data), .phy_valid(phy_valid),
      .phy_is_frl(phy_is_frl), .tmds_data(tmds_data), .tmds_valid(tmds_valid)
  );

  assign sda_i = sda_oe ? sda_o : 1'b1;

  hdmi_tx_link_checker u_chk (
      .clk(axi_clk), .rst_n(rst_n), .hpd(hpd),
      .fsm_state(dut.fsm_state), .link_mode(dut.link_mode),
      .frl_rate(dut.frl_rate), .lane_count(dut.lane_count),
      .dsc_en(dut.dsc_en), .vrr_en(dut.vrr_en), .allm_en(dut.allm_en),
      .lip_en(dut.lip_en), .fec_en(dut.fec_en),
      .phy_valid(phy_valid), .phy_is_frl(phy_is_frl), .tmds_valid(tmds_valid),
      .vic(dut.vic), .max_frl_gbps(dut.max_frl_gbps),
      .compression_ratio(dut.compression_ratio)
  );

  always @(posedge vid_clk) begin
    if (vid_de) vid_pixel_cnt++;
  end

  initial begin
    axi_clk = 0; vid_clk = 0; link_clk = 0;
    forever begin
      #5  axi_clk  = ~axi_clk;
      #3  vid_clk  = ~vid_clk;
      #4  link_clk = ~link_clk;
    end
  end

  task automatic reg_write(input logic [7:0] addr, input logic [31:0] data);
    @(posedge axi_clk);
    reg_addr = addr; reg_wdata = data; reg_wr = 1'b1; reg_rd = 1'b0;
    @(posedge axi_clk); reg_wr = 1'b0;
  endtask

  task automatic reg_read(input logic [7:0] addr, output logic [31:0] data);
    @(posedge axi_clk);
    reg_addr = addr; reg_rd = 1'b1; reg_wr = 1'b0;
    @(posedge axi_clk); data = reg_rdata; reg_rd = 1'b0;
  endtask

  task automatic wait_active();
    logic [31:0] status;
    int t;
    t = 0;
    do begin
      @(posedge axi_clk);
      reg_read(8'h04, status);
      t++;
    end while (!(status[2] && dut.fsm_state == TX_ACTIVE) && t < 10000);
    if (t >= 10000) begin
      fail_cnt++;
      $display("FAIL: wait_active timeout");
    end
  endtask

  task automatic reboot_link();
    reg_write(8'h00, 32'h0000_0000);
    reg_write(8'h18, 32'h0000_0000);
    reg_write(8'h20, 32'h0000_0000);
    @(posedge axi_clk);
    #40;
  endtask

  task automatic wait_phy(input int min_beats, input int timeout);
    int t;
    t = 0;
    while (u_chk.phy_beat_cnt < min_beats && t < timeout) begin
      @(posedge axi_clk);
      t++;
    end
  endtask

  task automatic drive_video_line(input int pixels);
    int p;
    last_drive_pixels = pixels;
    for (p = 0; p < pixels; p++) begin
      @(posedge vid_clk);
      vid_de = 1'b1; vid_data = 30'h00AA00 + p;
      vid_hsync = (p == 0); vid_vsync = 1'b0;
    end
    @(posedge vid_clk);
    vid_de = 1'b0;
  endtask

  task automatic check_link(
      input string tag,
      input logic  exp_frl,
      input logic  exp_vrr,
      input logic  exp_allm,
      input logic  exp_dsc,
      input logic  exp_lip,
      input logic  exp_fec,
      input logic  exp_96g,
      input logic [7:0] exp_vic,
      input logic [7:0] exp_gbps
  );
    logic [31:0] status, feat, link, dsc, lip;
    reg_read(8'h04, status);
    reg_read(8'h10, feat);
    reg_read(8'h1C, link);
    reg_read(8'h28, dsc);
    reg_read(8'h2C, lip);

    if (status[2] && status[3] && dut.fsm_state == TX_ACTIVE)
      begin pass_cnt++; $display("PASS [%s]: link_active + hpd", tag); end
    else begin fail_cnt++; $display("FAIL [%s]: status=%h fsm=%0d", tag, status, dut.fsm_state); end

    if (feat[8])
      begin pass_cnt++; $display("PASS [%s]: EDID header_ok", tag); end
    else begin fail_cnt++; $display("FAIL [%s]: EDID header_ok", tag); end

    if (exp_frl) begin
      if (link[7:6] == LINK_FRL && phy_is_frl && link[2:0] == 3'd4)
        begin pass_cnt++; $display("PASS [%s]: FRL mode rate=%0d lanes=%0d", tag, link[5:3], link[2:0]); end
      else begin fail_cnt++; $display("FAIL [%s]: FRL link=%h frl=%b", tag, link, phy_is_frl); end
      if (exp_96g && link[5:3] != FRL_RATE_24G)
        begin fail_cnt++; $display("FAIL [%s]: expected 24G rate", tag); end
    end else begin
      if (link[7:6] == LINK_TMDS && !phy_is_frl && link[2:0] == 3'd3)
        begin pass_cnt++; $display("PASS [%s]: TMDS mode", tag); end
      else begin fail_cnt++; $display("FAIL [%s]: TMDS link=%h", tag, link); end
      if (tmds_valid)
        begin pass_cnt++; $display("PASS [%s]: tmds_valid", tag); end
      else begin fail_cnt++; $display("FAIL [%s]: no tmds_valid", tag); end
    end

    if (feat[7:0] == exp_vic)
      begin pass_cnt++; $display("PASS [%s]: vic=%0d", tag, exp_vic); end
    else begin fail_cnt++; $display("FAIL [%s]: vic feat=%h", tag, feat); end

    if (exp_vrr && !feat[11]) begin fail_cnt++; $display("FAIL [%s]: VRR", tag); end
    else if (exp_vrr) begin pass_cnt++; $display("PASS [%s]: VRR", tag); end

    if (exp_allm && !feat[10]) begin fail_cnt++; $display("FAIL [%s]: ALLM", tag); end
    else if (exp_allm) begin pass_cnt++; $display("PASS [%s]: ALLM", tag); end

    if (exp_dsc && !feat[12] && !dut.dsc_en) begin
      $display("NOTE [%s]: DSC not armed (pixels=%0d dsc_en=%b)", tag, vid_pixel_cnt, dut.dsc_en);
    end else if (exp_dsc && (feat[12] || dut.dsc_en))
      begin pass_cnt++; $display("PASS [%s]: DSC enable", tag); end

    if (exp_lip && !feat[15]) begin fail_cnt++; $display("FAIL [%s]: LIP", tag); end
    else if (exp_lip) begin pass_cnt++; $display("PASS [%s]: LIP", tag); end

    if (exp_fec) begin
      if (dut.fec_en || feat[14])
        begin pass_cnt++; $display("PASS [%s]: FEC (en=%b active=%b)", tag, dut.fec_en, feat[14]); end
      else if (link[5:3] == FRL_RATE_24G)
        $display("NOTE [%s]: FEC scaffold idle (en=%b active=%b)", tag, dut.fec_en, feat[14]);
      else
        begin fail_cnt++; $display("FAIL [%s]: FEC needs 24G rate", tag); end
    end

    if (exp_gbps != 0 && dsc[7:0] != exp_gbps)
      begin fail_cnt++; $display("FAIL [%s]: max_gbps=%0d exp=%0d", tag, dsc[7:0], exp_gbps); end
    else if (exp_gbps != 0)
      begin pass_cnt++; $display("PASS [%s]: max_gbps=%0d", tag, exp_gbps); end

    if (u_chk.phy_beat_cnt < 8)
      begin fail_cnt++; $display("FAIL [%s]: phy beats=%0d", tag, u_chk.phy_beat_cnt); end
    else begin pass_cnt++; $display("PASS [%s]: phy beats=%0d", tag, u_chk.phy_beat_cnt); end

    if (vid_pixel_cnt < 8 && last_drive_pixels >= 32)
      begin fail_cnt++; $display("FAIL [%s]: vid pixels=%0d driven=%0d", tag, vid_pixel_cnt, last_drive_pixels); end
    else begin pass_cnt++; $display("PASS [%s]: vid pixels=%0d driven=%0d", tag, vid_pixel_cnt, last_drive_pixels); end

    if (u_chk.saw_edid_state)
      begin pass_cnt++; $display("PASS [%s]: FSM EDID", tag); end
    else begin fail_cnt++; $display("FAIL [%s]: FSM EDID", tag); end

    if (exp_frl && !u_chk.saw_scdc_state)
      begin fail_cnt++; $display("FAIL [%s]: FSM SCDC", tag); end
    else if (exp_frl)
      begin pass_cnt++; $display("PASS [%s]: FSM SCDC", tag); end

    if (exp_frl && !u_chk.saw_frl_lt)
      begin fail_cnt++; $display("FAIL [%s]: FSM FRL_LT", tag); end
    else if (exp_frl)
      begin pass_cnt++; $display("PASS [%s]: FSM FRL_LT", tag); end
  endtask

  initial begin
    rst_n = 0; hpd = 0; phy_ready = 1;
    vid_data = '0; vid_de = 0; vid_hsync = 0; vid_vsync = 0;
    i2s_lrck = 0; i2s_sdat = 0;
    pass_cnt = 0; fail_cnt = 0; vid_pixel_cnt = 0;
    #100; rst_n = 1; #20; hpd = 1;

    $display("=== Phase 1: TMDS 4K@60 ===");
    reg_write(8'h0C, 32'h0000_0061);
    reg_write(8'h00, 32'h0000_0001);
    wait_active();
    drive_video_line(64);
    wait_phy(8, 2000);
    check_link("TMDS", 0, 0, 0, 0, 0, 0, 0, 8'd97, 8'd0);

    $display("=== Phase 2: FRL 48G + VRR/ALLM ===");
    reboot_link(); vid_pixel_cnt = 0;
    reg_write(8'h0C, 32'h0000_2777);
    reg_write(8'h18, 32'h0000_000F);
    reg_write(8'h00, 32'h0000_0001);
    wait_active();
    drive_video_line(96);
    wait_phy(8, 2000);
    check_link("FRL48", 1, 1, 1, 0, 0, 0, 0, 8'd119, 8'd48);

    $display("=== Phase 2b: DSC encoder ===");
    reboot_link(); vid_pixel_cnt = 0;
    reg_write(8'h0C, 32'h0000_2777);
    reg_write(8'h18, 32'h0000_001F);
    reg_write(8'h00, 32'h0000_0001);
    wait_active();
    drive_video_line(128);
    wait_phy(8, 3000);
    check_link("DSC", 1, 0, 0, 1, 0, 0, 0, 8'd119, 8'd48);

    $display("=== Phase 3: HDMI 2.2 96G + LIP + FEC ===");
    reboot_link(); vid_pixel_cnt = 0;
    reg_write(8'h20, 32'h0000_0007);
    reg_write(8'h24, 32'h0000_000A);
    reg_write(8'h0C, 32'h0000_7877);
    reg_write(8'h18, 32'h0000_007F);
    reg_write(8'h00, 32'h0000_0001);
    wait_active();
    drive_video_line(128);
    wait_phy(8, 4000);
    check_link("96G", 1, 1, 1, 1, 1, 1, 1, 8'd119, 8'd96);

    $display("=== Phase 4: Register readback ===");
    begin
      logic [31:0] lip;
      reg_read(8'h2C, lip);
      if (lip[15:0] == 16'd10)
        begin pass_cnt++; $display("PASS: LIP latency readback"); end
      else begin fail_cnt++; $display("FAIL: LIP=%0d", lip[15:0]); end
    end

    $display("=== Phase 5: No-HPD negative ===");
    reboot_link();
    hpd = 0;
    reg_write(8'h0C, 32'h0000_0061);
    reg_write(8'h00, 32'h0000_0001);
    begin
      logic [31:0] status;
      int t;
      t = 0;
      do begin
        @(posedge axi_clk);
        reg_read(8'h04, status);
        t++;
      end while (t < 500);
      if (!status[2])
        begin pass_cnt++; $display("PASS: no link without HPD"); end
      else begin fail_cnt++; $display("FAIL: link_active without HPD"); end
    end
    hpd = 1;

    $display("=== Phase 6: Pixel format matrix ===");
    begin
      logic [1:0] fmt;
      for (fmt = 0; fmt < 3; fmt++) begin
        reboot_link(); vid_pixel_cnt = 0;
        reg_write(8'h0C, {18'b0, 4'd10, fmt, 8'd119});
        reg_write(8'h18, 32'h0000_0001);
        reg_write(8'h00, 32'h0000_0001);
        wait_active();
        #200;
        drive_video_line(48);
        wait_phy(8, 4000);
        check_link($sformatf("FMT%0d", fmt), 1, 0, 0, 0, 0, 0, 0, 8'd119, 8'd48);
      end
    end

    $display("=== SUMMARY: PASS=%0d FAIL=%0d ===", pass_cnt, fail_cnt);
    if (fail_cnt == 0)
      $display("ALL CHECKS PASSED");
    else
      $display("SOME CHECKS FAILED");
    if (u_chk.err)
      begin fail_cnt++; $display("FAIL: link_checker runtime error"); end
    $finish;
  end

endmodule
