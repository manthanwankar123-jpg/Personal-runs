import hdmi_tx_pkg::*;

module hdmi_edid_parser (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        parse,
    input  logic        sim_sink_hdmi21,
    input  logic        sim_sink_hdmi22,
    input  logic [7:0]  edid_data [0:EDID_LEN-1],
    output logic        valid,
    output logic        header_ok,
    output logic        cea_present,
    output logic [7:0]  cea_dtd_offset,
    output logic        sink_frl_capable,
    output logic [2:0]  sink_max_frl_rate,
    output logic [2:0]  sink_max_lanes,
    output logic        sink_dsc_capable,
    output logic        sink_vrr_capable,
    output logic        sink_allm_capable,
    output logic        sink_hdmi22,
    output logic        sink_lip_capable
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid             <= 1'b0;
      header_ok         <= 1'b0;
      cea_present       <= 1'b0;
      cea_dtd_offset    <= '0;
      sink_frl_capable  <= 1'b0;
      sink_max_frl_rate <= FRL_RATE_12G;
      sink_max_lanes    <= 3'd4;
      sink_dsc_capable  <= 1'b0;
      sink_vrr_capable  <= 1'b0;
      sink_allm_capable <= 1'b0;
      sink_hdmi22       <= 1'b0;
      sink_lip_capable  <= 1'b0;
    end else if (parse) begin
      header_ok <= (edid_data[0] == 8'h00) &&
                   (edid_data[1] == 8'hFF) &&
                   (edid_data[2] == 8'hFF) &&
                   (edid_data[3] == 8'hFF) &&
                   (edid_data[4] == 8'hFF) &&
                   (edid_data[5] == 8'hFF) &&
                   (edid_data[6] == 8'hFF) &&
                   (edid_data[7] == 8'h00);

      cea_present    <= (edid_data[126] != 8'd0);
      cea_dtd_offset <= '0;

      if (sim_sink_hdmi22) begin
        sink_frl_capable  <= 1'b1;
        sink_max_frl_rate <= FRL_RATE_24G;
        sink_max_lanes    <= 3'd4;
        sink_dsc_capable  <= 1'b1;
        sink_vrr_capable  <= 1'b1;
        sink_allm_capable <= 1'b1;
        sink_hdmi22       <= 1'b1;
        sink_lip_capable  <= 1'b1;
      end else if (sim_sink_hdmi21 || cea_present) begin
        sink_frl_capable  <= 1'b1;
        sink_max_frl_rate <= FRL_RATE_12G;
        sink_max_lanes    <= 3'd4;
        sink_dsc_capable  <= 1'b1;
        sink_vrr_capable  <= 1'b1;
        sink_allm_capable <= 1'b1;
        sink_hdmi22       <= 1'b0;
        sink_lip_capable  <= 1'b0;
      end else begin
        sink_frl_capable  <= 1'b0;
        sink_max_frl_rate <= FRL_RATE_6G;
        sink_max_lanes    <= 3'd3;
        sink_dsc_capable  <= 1'b0;
        sink_vrr_capable  <= 1'b0;
        sink_allm_capable <= 1'b0;
        sink_hdmi22       <= 1'b0;
        sink_lip_capable  <= 1'b0;
      end

      valid <= 1'b1;
    end else begin
      valid <= 1'b0;
    end
  end

endmodule
