import hdmi_tx_pkg::*;

module hdmi_mode_calc (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        calc,
    input  logic        sink_frl_capable,
    input  logic [2:0]  sink_max_frl_rate,
    input  logic [2:0]  sink_max_lanes,
    input  logic        sink_dsc_capable,
    input  logic        sink_vrr_capable,
    input  logic        sink_allm_capable,
    input  logic        sink_hdmi22,
    input  logic        sink_lip_capable,
    input  ultra96_tier_e ultra96_tier,
    input  logic        force_frl,
    input  logic        force_96g,
    input  logic [7:0]  vic,
    input  pix_fmt_e    pix_fmt,
    input  logic [3:0]  bpc,
    input  logic        dsc_req,
    input  logic        vrr_req,
    input  logic        allm_req,
    input  logic        lip_req,
    input  logic        fec_req,
    output link_mode_e  link_mode,
    output frl_rate_e   frl_rate,
    output logic [2:0]  lane_count,
    output logic        dsc_en,
    output logic        vrr_en,
    output logic        allm_en,
    output logic        lip_en,
    output logic        fec_en,
    output logic [7:0]  max_frl_gbps,
    output logic        valid
);

  link_mode_e  mode_q;
  frl_rate_e   rate_q;
  logic [2:0]  lanes_q;
  logic        dsc_q, vrr_q, allm_q, lip_q, fec_q;
  logic [7:0]  gbps_q;
  logic        valid_q;

  function automatic int unsigned vic_refresh(input logic [7:0] vic_in);
    begin
      if (vic_in == 8'd97 || vic_in == 8'd95)
        vic_refresh = 60;
      else if (vic_in == 8'd119 || vic_in == 8'd118)
        vic_refresh = 120;
      else if (vic_in == 8'd120 || vic_in == 8'd121)
        vic_refresh = 240;
      else
        vic_refresh = 60;
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mode_q   <= LINK_TMDS;
      rate_q   <= FRL_RATE_12G;
      lanes_q  <= 3'd4;
      dsc_q    <= 1'b0;
      vrr_q    <= 1'b0;
      allm_q   <= 1'b0;
      lip_q    <= 1'b0;
      fec_q    <= 1'b0;
      gbps_q   <= 8'd48;
      valid_q  <= 1'b0;
    end else if (calc) begin
      logic [31:0] bw_mbps;
      logic [31:0] frl_cap_gbps;
      logic [31:0] tier_cap;
      frl_rate_e   pick_rate;
      logic [2:0]  pick_lanes;

      bw_mbps = pix_bandwidth_mbps(
          H_ACTIVE_4K120, V_ACTIVE_4K120,
          vic_refresh(vic), pix_fmt, bpc
      );

      pick_rate  = frl_rate_e'(sink_max_frl_rate);
      pick_lanes = (sink_max_lanes == 3'd0) ? 3'd4 : sink_max_lanes;
      tier_cap   = ultra96_max_gbps(ultra96_tier);
      frl_cap_gbps = frl_gbps(pick_rate, pick_lanes);

      if (frl_cap_gbps > tier_cap)
        frl_cap_gbps = tier_cap;

      if (force_96g && sink_hdmi22)
        pick_rate = FRL_RATE_24G;

      vrr_q  <= vrr_req && sink_vrr_capable;
      allm_q <= allm_req && sink_allm_capable;
      lip_q  <= lip_req && sink_lip_capable && sink_hdmi22;
      fec_q  <= fec_req && sink_hdmi22 && (pick_rate == FRL_RATE_24G);

      if ((force_frl || force_96g || (bw_mbps > 32'd18000)) && sink_frl_capable) begin
        mode_q  <= LINK_FRL;
        rate_q  <= pick_rate;
        lanes_q <= pick_lanes;
        gbps_q  <= frl_cap_gbps[7:0];
        dsc_q   <= dsc_req && sink_dsc_capable &&
                   (bw_mbps > (frl_cap_gbps * 32'd700));
      end else begin
        mode_q  <= LINK_TMDS;
        rate_q  <= FRL_RATE_12G;
        lanes_q <= 3'd3;
        gbps_q  <= 8'd18;
        dsc_q   <= 1'b0;
        fec_q   <= 1'b0;
      end

      valid_q <= 1'b1;
    end else begin
      valid_q <= 1'b0;
    end
  end

  assign link_mode   = mode_q;
  assign frl_rate    = rate_q;
  assign lane_count  = lanes_q;
  assign dsc_en      = dsc_q;
  assign vrr_en      = vrr_q;
  assign allm_en     = allm_q;
  assign lip_en      = lip_q;
  assign fec_en      = fec_q;
  assign max_frl_gbps = gbps_q;
  assign valid       = valid_q;

endmodule
