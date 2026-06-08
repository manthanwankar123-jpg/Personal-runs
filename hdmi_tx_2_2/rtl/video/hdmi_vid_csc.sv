import hdmi_tx_pkg::*;

module hdmi_vid_csc (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  pix_fmt_e    pix_fmt,
    input  logic [29:0] vid_data,
    input  logic        vid_de,
    input  logic        vid_hsync,
    input  logic        vid_vsync,
    output logic [29:0] pix_data,
    output logic        pix_de,
    output logic        pix_hsync,
    output logic        pix_vsync,
    output logic        frame_start,
    output logic        line_start,
    output logic [3:0]  pix_bpp
);

  logic [29:0] data_q;
  logic        de_q, hsync_q, vsync_q;
  logic        vsync_d, hsync_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_q      <= '0;
      de_q        <= 1'b0;
      hsync_q     <= 1'b0;
      vsync_q     <= 1'b0;
      vsync_d     <= 1'b0;
      hsync_d     <= 1'b0;
      frame_start <= 1'b0;
      line_start  <= 1'b0;
      pix_bpp     <= 4'd8;
    end else if (enable) begin
      unique case (pix_fmt)
        PIX_RGB101010: begin
          data_q  <= vid_data[29:0];
          pix_bpp <= 4'd10;
        end
        PIX_YUV422: begin
          data_q  <= {vid_data[29:22], vid_data[19:12], vid_data[9:2]};
          pix_bpp <= 4'd8;
        end
        default: begin
          data_q  <= {2'b00, vid_data[23:0]};
          pix_bpp <= 4'd8;
        end
      endcase

      de_q    <= vid_de;
      hsync_q <= vid_hsync;
      vsync_q <= vid_vsync;
      vsync_d <= vid_vsync;
      hsync_d <= vid_hsync;
      frame_start <= vid_vsync & ~vsync_d;
      line_start  <= vid_hsync & ~hsync_d;
    end else begin
      de_q        <= 1'b0;
      frame_start <= 1'b0;
      line_start  <= 1'b0;
    end
  end

  assign pix_data  = data_q;
  assign pix_de    = de_q;
  assign pix_hsync = hsync_q;
  assign pix_vsync = vsync_q;

endmodule
