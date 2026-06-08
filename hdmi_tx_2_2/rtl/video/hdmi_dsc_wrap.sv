import hdmi_tx_pkg::*;

module hdmi_dsc_wrap (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic        dsc_en,
    input  logic [29:0] pix_data,
    input  logic        pix_de,
    input  logic        frame_start,
    output logic [29:0] out_data,
    output logic        out_de,
    output logic        out_dsc_mode,
    output logic [7:0]  lane3_data,
    output logic [7:0]  compression_ratio
);

  logic [7:0]  enc_byte;
  logic        enc_valid;
  logic [7:0]  pps_byte;
  logic        pps_valid;
  logic        pps_load;

  assign out_dsc_mode = dsc_en;
  assign pps_load     = frame_start && dsc_en && enable;

  hdmi_dsc_pps u_pps (
      .clk(clk), .rst_n(rst_n),
      .load(pps_load),
      .pic_width(16'd3840),
      .pic_height(16'd2160),
      .bits_per_pixel(8'd128),
      .pps_byte(pps_byte),
      .pps_idx(),
      .pps_valid(pps_valid)
  );

  hdmi_dsc_encoder u_enc (
      .clk(clk), .rst_n(rst_n),
      .enable(enable && dsc_en),
      .frame_start(frame_start),
      .pix_data(pix_data),
      .pix_de(pix_de),
      .dsc_byte(enc_byte),
      .dsc_valid(enc_valid),
      .slice_start(),
      .bytes_out(),
      .compression_ratio(compression_ratio)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_data   <= '0;
      out_de     <= 1'b0;
      lane3_data <= '0;
    end else if (!enable) begin
      out_de <= 1'b0;
    end else if (!dsc_en) begin
      out_data   <= pix_data;
      out_de     <= pix_de;
      lane3_data <= pix_data[7:0];
    end else begin
      if (pps_valid) begin
        out_data   <= {22'd0, pps_byte};
        out_de     <= 1'b1;
        lane3_data <= pps_byte;
      end else if (enc_valid) begin
        out_data   <= {22'd0, enc_byte};
        out_de     <= 1'b1;
        lane3_data <= enc_byte;
      end else begin
        out_de <= 1'b0;
      end
    end
  end

endmodule
