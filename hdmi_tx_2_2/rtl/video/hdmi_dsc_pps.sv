import hdmi_tx_pkg::*;

// DSC Picture Parameter Set generator (VESA DSC 1.2 subset for HDMI).
module hdmi_dsc_pps (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        load,
    input  logic [15:0] pic_width,
    input  logic [15:0] pic_height,
    input  logic [7:0]  bits_per_pixel,
    output logic [7:0]  pps_byte,
    output logic [5:0]  pps_idx,
    output logic        pps_valid
);

  logic [7:0] pps_mem [0:63];
  logic [5:0] idx;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pps_valid <= 1'b0;
      pps_byte  <= '0;
      pps_idx   <= '0;
      idx       <= '0;
    end else if (load) begin
      pps_mem[0]  <= 8'h00;
      pps_mem[1]  <= 8'h00;
      pps_mem[2]  <= 8'h01;
      pps_mem[3]  <= 8'h22;
      pps_mem[4]  <= pic_width[7:0];
      pps_mem[5]  <= pic_width[15:8];
      pps_mem[6]  <= pic_height[7:0];
      pps_mem[7]  <= pic_height[15:8];
      pps_mem[8]  <= bits_per_pixel;
      pps_mem[9]  <= 8'h08;
      pps_mem[10] <= 8'h20;
      pps_mem[11] <= 8'h03;
      pps_mem[12] <= 8'h0C;
      pps_mem[13] <= 8'h00;
      pps_mem[14] <= 8'h0A;
      pps_mem[15] <= 8'h02;
      idx       <= '0;
      pps_idx   <= '0;
      pps_valid <= 1'b1;
    end else if (pps_valid) begin
      pps_byte <= pps_mem[idx];
      pps_idx  <= idx;
      if (idx >= 6'd15) begin
        pps_valid <= 1'b0;
        idx       <= '0;
      end else begin
        idx <= idx + 6'd1;
      end
    end
  end

endmodule
