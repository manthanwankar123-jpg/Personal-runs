import hdmi_tx_pkg::*;

module hdmi_vid_in (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic [23:0] vid_data,
    input  logic        vid_de,
    input  logic        vid_hsync,
    input  logic        vid_vsync,
    output logic [23:0] pix_data,
    output logic        pix_de,
    output logic        pix_hsync,
    output logic        pix_vsync,
    output logic        frame_start,
    output logic        line_start
);

  logic vsync_d, hsync_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pix_data   <= '0;
      pix_de     <= 1'b0;
      pix_hsync  <= 1'b0;
      pix_vsync  <= 1'b0;
      vsync_d    <= 1'b0;
      hsync_d    <= 1'b0;
      frame_start <= 1'b0;
      line_start  <= 1'b0;
    end else if (enable) begin
      pix_data   <= vid_data;
      pix_de     <= vid_de;
      pix_hsync  <= vid_hsync;
      pix_vsync  <= vid_vsync;
      vsync_d    <= vid_vsync;
      hsync_d    <= vid_hsync;
      frame_start <= vid_vsync & ~vsync_d;
      line_start  <= vid_hsync & ~hsync_d;
    end else begin
      pix_de      <= 1'b0;
      frame_start <= 1'b0;
      line_start  <= 1'b0;
    end
  end

endmodule
