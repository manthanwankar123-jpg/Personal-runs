import hdmi_tx_pkg::*;

module hdmi_tx_top #(
    parameter int unsigned HPD_DEBOUNCE_MAX = 32'd1000,
    parameter bit          FAST_EDID        = 1'b0,
    parameter bit          FAST_SCDC        = 1'b0,
    parameter bit          FAST_LT          = 1'b0,
    parameter bit          SIM_HDMI22       = 1'b0
) (
    input  logic        axi_clk,
    input  logic        vid_clk,
    input  logic        link_clk,
    input  logic        rst_n,

    input  logic [29:0] vid_data,
    input  logic        vid_de,
    input  logic        vid_hsync,
    input  logic        vid_vsync,

    input  logic        i2s_lrck,
    input  logic        i2s_sdat,

    input  logic        hpd,
    output logic        scl_o,
    output logic        sda_o,
    output logic        scl_oe,
    output logic        sda_oe,
    input  logic        sda_i,

    input  logic        reg_wr,
    input  logic        reg_rd,
    input  logic [7:0]  reg_addr,
    input  logic [31:0] reg_wdata,
    output logic [31:0] reg_rdata,

    input  logic        phy_ready,

    output logic [15:0] phy_data [0:3],
    output logic        phy_valid,
    output logic        phy_is_frl,

    output logic [9:0]  tmds_data [0:3],
    output logic        tmds_valid
);

  logic        enable, soft_rst;
  logic [7:0]  vic;
  logic        force_frl, force_96g;
  logic        dsc_req, vrr_req, allm_req, lip_req, fec_req;
  pix_fmt_e    pix_fmt;
  logic [3:0]  bpc;
  ultra96_tier_e ultra96_tier;
  logic [15:0] lip_latency_ms;
  logic        sim_hdmi22_en;

  logic        edid_start, edid_done, edid_ok, parse_edid;
  logic        mode_calc, mode_valid;
  logic        scdc_start, scdc_done, frl_lt_start, frl_lt_done, flt_ready;
  logic        pkt_enable, scramble_en, infoframe_load;
  logic        infoframe_pending, infoframe_done;
  tx_state_e   fsm_state;

  link_mode_e  link_mode;
  frl_rate_e   frl_rate;
  logic [2:0]  lane_count;
  logic        dsc_en, vrr_en, allm_en, lip_en, fec_en;
  logic [7:0]  max_frl_gbps;

  logic [7:0]  edid_mem [0:EDID_LEN-1];
  logic        header_ok, cea_present;
  logic        sink_frl_capable;
  logic [2:0]  sink_max_frl_rate, sink_max_lanes;
  logic        sink_dsc_capable, sink_vrr_capable, sink_allm_capable;
  logic        sink_hdmi22, sink_lip_capable;

  logic [29:0] csc_data, dsc_data;
  logic        csc_de, dsc_de, dsc_mode;
  logic        pix_vsync, frame_start, vsync_fall;
  logic [7:0]  lane3_aux, compression_ratio;

  logic [15:0] aud_l, aud_r;
  logic        aud_valid;

  logic [7:0]  lane0, lane1, lane2, lane3;
  logic        lane_video, lane_c0, lane_c1, pkt_out_valid;

  logic [23:0] if_data, lip_data;
  logic        if_valid, lip_valid;
  logic        lip_load;

  logic [15:0] frl_data [0:3];
  logic        frl_valid, fec_active;

  always_ff @(posedge axi_clk or negedge rst_n) begin
    if (!rst_n) begin
      enable        <= 1'b0;
      soft_rst      <= 1'b0;
      vic           <= 8'd97;
      force_frl     <= 1'b0;
      force_96g     <= 1'b0;
      dsc_req       <= 1'b0;
      vrr_req       <= 1'b0;
      allm_req      <= 1'b0;
      lip_req       <= 1'b0;
      fec_req       <= 1'b0;
      pix_fmt       <= PIX_RGB888;
      bpc           <= 4'd8;
      ultra96_tier  <= ULTRA96_48;
      lip_latency_ms<= 16'd5;
      sim_hdmi22_en <= 1'b0;
    end else if (reg_wr) begin
      unique case (reg_addr)
        8'h00: begin
          enable   <= reg_wdata[0];
          soft_rst <= reg_wdata[1];
        end
        8'h0C: begin
          vic     <= reg_wdata[7:0];
          pix_fmt <= pix_fmt_e'(reg_wdata[9:8]);
          bpc     <= reg_wdata[13:10];
        end
        8'h18: begin
          force_frl <= reg_wdata[0];
          dsc_req   <= reg_wdata[1];
          vrr_req   <= reg_wdata[2];
          allm_req  <= reg_wdata[3];
          lip_req   <= reg_wdata[4];
          fec_req   <= reg_wdata[5];
          force_96g <= reg_wdata[6];
        end
        8'h20: begin
          ultra96_tier  <= ultra96_tier_e'(reg_wdata[1:0]);
          sim_hdmi22_en <= reg_wdata[2];
        end
        8'h24: lip_latency_ms <= reg_wdata[15:0];
        default: ;
      endcase
    end
  end

  always_comb begin
    reg_rdata = 32'd0;
    if (reg_rd) begin
      unique case (reg_addr)
        8'h04: reg_rdata = {24'd0, hpd, (fsm_state == TX_ACTIVE), edid_done, 1'b0};
        8'h10: reg_rdata = {8'd0, lip_en, fec_active, phy_is_frl, dsc_en, vrr_en, allm_en,
                            cea_present, header_ok, vic};
        8'h1C: reg_rdata = {18'd0, link_mode, frl_rate, lane_count};
        8'h28: reg_rdata = {16'd0, compression_ratio, max_frl_gbps};
        8'h2C: reg_rdata = {16'd0, lip_latency_ms};
        default: reg_rdata = 32'd0;
      endcase
    end
  end

  assign infoframe_pending = 1'b1;
  assign parse_edid        = edid_done;
  assign edid_ok           = header_ok;
  assign lane3_aux         = dsc_mode ? dsc_data[7:0] : csc_data[7:0];
  assign lip_load          = infoframe_load && lip_en;

  hdmi_tx_fsm u_fsm (
      .clk(axi_clk), .rst_n(rst_n & ~soft_rst), .enable(enable), .hpd(hpd),
      .hpd_debounce_max(HPD_DEBOUNCE_MAX),
      .edid_done(edid_done), .edid_ok(edid_ok), .mode_valid(mode_valid),
      .link_mode(link_mode), .scdc_done(scdc_done), .frl_lt_done(frl_lt_done),
      .state(fsm_state), .edid_start(edid_start), .mode_calc(mode_calc),
      .scdc_start(scdc_start), .frl_lt_start(frl_lt_start),
      .pkt_enable(pkt_enable), .scramble_en(scramble_en), .infoframe_load(infoframe_load)
  );

  hdmi_ddc_bus #(
      .FAST_EDID(FAST_EDID), .FAST_SCDC(FAST_SCDC)
  ) u_ddc (
      .clk(axi_clk), .rst_n(rst_n & ~soft_rst),
      .edid_start(edid_start), .edid_done(edid_done), .edid_data(edid_mem),
      .scdc_start(scdc_start), .link_mode(link_mode), .frl_rate(frl_rate),
      .lane_count(lane_count), .scdc_done(scdc_done), .flt_ready(flt_ready),
      .scl_o(scl_o), .sda_o(sda_o), .scl_oe(scl_oe), .sda_oe(sda_oe), .sda_i(sda_i)
  );

  hdmi_edid_parser u_edid (
      .clk(axi_clk), .rst_n(rst_n & ~soft_rst), .parse(parse_edid),
      .sim_sink_hdmi21(FAST_EDID), .sim_sink_hdmi22(SIM_HDMI22 || sim_hdmi22_en),
      .edid_data(edid_mem), .valid(), .header_ok(header_ok), .cea_present(cea_present),
      .cea_dtd_offset(),
      .sink_frl_capable(sink_frl_capable), .sink_max_frl_rate(sink_max_frl_rate),
      .sink_max_lanes(sink_max_lanes), .sink_dsc_capable(sink_dsc_capable),
      .sink_vrr_capable(sink_vrr_capable), .sink_allm_capable(sink_allm_capable),
      .sink_hdmi22(sink_hdmi22), .sink_lip_capable(sink_lip_capable)
  );

  hdmi_mode_calc u_mode (
      .clk(axi_clk), .rst_n(rst_n & ~soft_rst), .calc(mode_calc),
      .sink_frl_capable(sink_frl_capable), .sink_max_frl_rate(sink_max_frl_rate),
      .sink_max_lanes(sink_max_lanes), .sink_dsc_capable(sink_dsc_capable),
      .sink_vrr_capable(sink_vrr_capable), .sink_allm_capable(sink_allm_capable),
      .sink_hdmi22(sink_hdmi22), .sink_lip_capable(sink_lip_capable),
      .ultra96_tier(ultra96_tier), .force_frl(force_frl), .force_96g(force_96g),
      .vic(vic), .pix_fmt(pix_fmt), .bpc(bpc),
      .dsc_req(dsc_req), .vrr_req(vrr_req), .allm_req(allm_req),
      .lip_req(lip_req), .fec_req(fec_req),
      .link_mode(link_mode), .frl_rate(frl_rate), .lane_count(lane_count),
      .dsc_en(dsc_en), .vrr_en(vrr_en), .allm_en(allm_en),
      .lip_en(lip_en), .fec_en(fec_en), .max_frl_gbps(max_frl_gbps), .valid(mode_valid)
  );

  hdmi_frl_lt #(
      .FAST_LT(FAST_LT)
  ) u_frl_lt (
      .clk(axi_clk), .rst_n(rst_n & ~soft_rst), .start(frl_lt_start),
      .frl_rate(frl_rate), .lane_count(lane_count), .flt_ready(flt_ready),
      .phy_ready(phy_ready), .busy(), .done(frl_lt_done), .test_pattern_en()
  );

  hdmi_vid_csc u_csc (
      .clk(vid_clk), .rst_n(rst_n & ~soft_rst), .enable(pkt_enable), .pix_fmt(pix_fmt),
      .vid_data(vid_data), .vid_de(vid_de), .vid_hsync(vid_hsync), .vid_vsync(vid_vsync),
      .pix_data(csc_data), .pix_de(csc_de), .pix_hsync(), .pix_vsync(pix_vsync),
      .frame_start(frame_start), .line_start(), .pix_bpp()
  );

  hdmi_dsc_wrap u_dsc (
      .clk(vid_clk), .rst_n(rst_n & ~soft_rst), .enable(pkt_enable), .dsc_en(dsc_en),
      .pix_data(csc_data), .pix_de(csc_de), .frame_start(frame_start),
      .out_data(dsc_data), .out_de(dsc_de), .out_dsc_mode(dsc_mode),
      .lane3_data(), .compression_ratio(compression_ratio)
  );

  always_ff @(posedge vid_clk or negedge rst_n) begin
    if (!rst_n) vsync_fall <= 1'b0;
    else        vsync_fall <= ~pix_vsync & pkt_enable;
  end

  hdmi_audio_in u_aud (
      .clk(axi_clk), .rst_n(rst_n & ~soft_rst), .enable(pkt_enable),
      .i2s_lrck(i2s_lrck), .i2s_sdat(i2s_sdat),
      .sample_l(aud_l), .sample_r(aud_r), .sample_valid(aud_valid), .fifo_full()
  );

  hdmi_gaming_meta u_game (
      .clk(link_clk), .rst_n(rst_n & ~soft_rst), .load(infoframe_load),
      .vrr_en(vrr_en), .allm_en(allm_en), .scdc_allm(), .em_data_valid(), .em_data()
  );

  hdmi_infoframe_gen u_if (
      .clk(link_clk), .rst_n(rst_n & ~soft_rst), .load(infoframe_load),
      .vic(vic), .pix_fmt(pix_fmt), .bpc(bpc), .vrr_en(vrr_en), .dsc_en(dsc_en),
      .if_data(if_data), .if_len(), .if_valid(if_valid)
  );

  hdmi_lip_gen u_lip (
      .clk(link_clk), .rst_n(rst_n & ~soft_rst), .load(lip_load),
      .source_latency_ms(lip_latency_ms), .audio_latency_ms(16'd2),
      .lip_data(lip_data), .lip_valid(lip_valid), .lip_len()
  );

  hdmi_packetizer u_pkt (
      .clk(link_clk), .rst_n(rst_n & ~soft_rst), .enable(pkt_enable), .link_mode(link_mode),
      .pix_data(dsc_data), .pix_de(dsc_de), .frame_start(frame_start),
      .aud_l(aud_l), .aud_r(aud_r), .aud_valid(aud_valid),
      .infoframe_pending(infoframe_pending), .lip_pending(lip_en),
      .if_data(if_data), .if_valid(if_valid),
      .lip_data(lip_data), .lip_valid(lip_valid),
      .lane3_aux(lane3_aux),
      .lane0_data(lane0), .lane1_data(lane1), .lane2_data(lane2), .lane3_data(lane3),
      .lane_video(lane_video), .lane_c0(lane_c0), .lane_c1(lane_c1),
      .out_valid(pkt_out_valid), .infoframe_done(infoframe_done)
  );

  hdmi_tmds_link u_tmds (
      .clk(link_clk), .rst_n(rst_n & ~soft_rst),
      .enable(pkt_enable && (link_mode == LINK_TMDS)), .scramble_en(scramble_en),
      .vsync_fall(vsync_fall),
      .lane0_data(lane0), .lane1_data(lane1), .lane2_data(lane2),
      .lane_video(lane_video), .lane_c0(lane_c0), .lane_c1(lane_c1),
      .in_valid(pkt_out_valid && (link_mode == LINK_TMDS)),
      .tmds_data(tmds_data), .tmds_valid(tmds_valid)
  );

  hdmi_frl_link u_frl (
      .clk(link_clk), .rst_n(rst_n & ~soft_rst),
      .enable(pkt_enable && (link_mode == LINK_FRL)), .fec_en(fec_en),
      .lane0_data(lane0), .lane1_data(lane1), .lane2_data(lane2), .lane3_data(lane3),
      .in_valid(pkt_out_valid && (link_mode == LINK_FRL)),
      .frl_data(frl_data), .frl_valid(frl_valid), .fec_active(fec_active)
  );

  hdmi_link_mux u_mux (
      .link_mode(link_mode), .tmds_data(tmds_data), .tmds_valid(tmds_valid),
      .frl_data(frl_data), .frl_valid(frl_valid),
      .phy_data(phy_data), .phy_valid(phy_valid), .phy_is_frl(phy_is_frl)
  );

endmodule
