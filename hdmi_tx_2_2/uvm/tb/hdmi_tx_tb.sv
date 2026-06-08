`timescale 1ns/1ps

import uvm_pkg::*;
import hdmi_tx_pkg::*;
import hdmi_tx_reg_defs::*;
import hdmi_tx_env_pkg::*;

module hdmi_tx_tb;

  logic axi_clk, vid_clk, link_clk, rst_n;
  bit   hdmi22_sink;

  localparam int HPD_DEBOUNCE_P = 8;
  localparam bit FAST_EDID_P    = 1'b1;
  localparam bit FAST_SCDC_P    = 1'b1;
  localparam bit FAST_LT_P      = 1'b1;
  localparam bit SIM_HDMI22_P   = 1'b0;

  hdmi_tx_reg_if  reg_if (axi_clk);
  hdmi_tx_vid_if  vid_if (vid_clk);
  hdmi_tx_sink_if sink_if (axi_clk);
  hdmi_tx_phy_if  phy_if (link_clk);
  hdmi_tx_fsm_if  fsm_if (axi_clk);

  assign fsm_if.state = dut.fsm_state;

  logic [29:0] vid_data;
  logic        vid_de, vid_hsync, vid_vsync;
  logic        i2s_lrck, i2s_sdat;
  logic        scl_o, sda_o, scl_oe, sda_oe, sda_i, sda_slave;

  assign vid_data  = vid_if.data;
  assign vid_de    = vid_if.de;
  assign vid_hsync = vid_if.hsync;
  assign vid_vsync = vid_if.vsync;

  hdmi_tx_top #(
      .HPD_DEBOUNCE_MAX(HPD_DEBOUNCE_P),
      .FAST_EDID(FAST_EDID_P),
      .FAST_SCDC(FAST_SCDC_P),
      .FAST_LT(FAST_LT_P),
      .SIM_HDMI22(SIM_HDMI22_P)
  ) dut (
      .axi_clk(axi_clk), .vid_clk(vid_clk), .link_clk(link_clk), .rst_n(rst_n),
      .vid_data(vid_data), .vid_de(vid_de), .vid_hsync(vid_hsync), .vid_vsync(vid_vsync),
      .i2s_lrck(i2s_lrck), .i2s_sdat(i2s_sdat),
      .hpd(sink_if.hpd),
      .scl_o(scl_o), .sda_o(sda_o), .scl_oe(scl_oe), .sda_oe(sda_oe), .sda_i(sda_i),
      .reg_wr(reg_if.wr), .reg_rd(reg_if.rd), .reg_addr(reg_if.addr),
      .reg_wdata(reg_if.wdata), .reg_rdata(reg_if.rdata),
      .phy_ready(sink_if.phy_ready),
      .phy_data(phy_if.data), .phy_valid(phy_if.valid), .phy_is_frl(phy_if.is_frl),
      .tmds_data(phy_if.tmds), .tmds_valid(phy_if.tmds_valid)
  );

  hdmi_tx_ddc_slave u_sink (
      .clk(axi_clk), .rst_n(rst_n), .hdmi22_sink(hdmi22_sink),
      .scl(scl_o), .sda_i(sda_i), .scl_oe(scl_oe), .sda_oe(sda_oe), .sda_o(sda_slave)
  );

  assign sda_i = sda_oe ? sda_o : sda_slave;

  bind dut hdmi_tx_assertions u_asrt (
      .clk(axi_clk),
      .rst_n(rst_n),
      .enable(dut.enable),
      .hpd(sink_if.hpd),
      .pkt_enable(dut.pkt_enable),
      .link_mode(dut.link_mode),
      .phy_is_frl(phy_if.is_frl),
      .phy_valid(phy_if.valid),
      .tmds_valid(phy_if.tmds_valid),
      .fsm_state(dut.fsm_state),
      .lane_count(dut.lane_count),
      .dsc_en(dut.dsc_en),
      .vrr_en(dut.vrr_en),
      .lip_en(dut.lip_en),
      .fec_en(dut.fec_en)
  );

  bind dut hdmi_tx_link_checker u_chk (
      .clk(axi_clk),
      .rst_n(rst_n),
      .hpd(sink_if.hpd),
      .fsm_state(dut.fsm_state),
      .link_mode(dut.link_mode),
      .frl_rate(dut.frl_rate),
      .lane_count(dut.lane_count),
      .dsc_en(dut.dsc_en),
      .vrr_en(dut.vrr_en),
      .allm_en(dut.allm_en),
      .lip_en(dut.lip_en),
      .fec_en(dut.fec_en),
      .phy_valid(phy_if.valid),
      .phy_is_frl(phy_if.is_frl),
      .tmds_valid(phy_if.tmds_valid),
      .vic(dut.vic),
      .max_frl_gbps(dut.max_frl_gbps),
      .compression_ratio(dut.compression_ratio)
  );

  initial begin
    hdmi22_sink = 1'b0;
    void'($value$plusargs("HDMI22_SINK=%0d", hdmi22_sink));
  end

  initial begin
    axi_clk = 0; vid_clk = 0; link_clk = 0;
    forever begin
      #5  axi_clk  = ~axi_clk;
      #3  vid_clk  = ~vid_clk;
      #4  link_clk = ~link_clk;
    end
  end

  initial begin
    rst_n = 0;
    i2s_lrck = 0; i2s_sdat = 0;
    sink_if.hpd = 0;
    sink_if.phy_ready = 1;
    reg_if.wr = 0; reg_if.rd = 0;
    vid_if.de = 0; vid_if.data = 0;
    #100;
    rst_n = 1;
  end

  initial begin
    uvm_config_db#(virtual hdmi_tx_reg_if)::set(null, "uvm_test_top.env.reg_agt*", "vif", reg_if);
    uvm_config_db#(virtual hdmi_tx_vid_if)::set(null, "uvm_test_top.env.vid_agt*", "vif", vid_if);
    uvm_config_db#(virtual hdmi_tx_sink_if)::set(null, "uvm_test_top.env.sink_agt*", "vif", sink_if);
    uvm_config_db#(virtual hdmi_tx_phy_if)::set(null, "uvm_test_top.env.phy_agt*", "vif", phy_if);
    uvm_config_db#(virtual hdmi_tx_fsm_if)::set(null, "uvm_test_top.env.sb", "fsm_vif", fsm_if);
    run_test();
  end

endmodule
