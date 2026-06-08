module hdmi_infoframe_gen (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        load,
    input  logic [7:0]  vic,
    input  logic [1:0]  pix_fmt,
    input  logic [3:0]  bpc,
    input  logic        vrr_en,
    input  logic        dsc_en,
    output logic [23:0] if_data,
    output logic [4:0]  if_len,
    output logic        if_valid
);

  localparam int unsigned AVI_BYTES = 13;

  logic [4:0]  byte_idx;
  logic [7:0]  avi_mem [0:AVI_BYTES-1];
  logic [7:0]  colorspace;

  function automatic logic [7:0] infoframe_checksum(
      input logic [7:0] b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11
  );
    logic [8:0] sum;
    begin
      sum = 9'h00 + 9'h02 + 9'h0D + 9'h00;
      sum = sum + b0 + b1 + b2 + b3 + b4 + b5 + b6 + b7 + b8 + b9 + b10 + b11;
      infoframe_checksum = ~(sum[7:0] + {7'd0, sum[8]});
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      if_valid <= 1'b0;
      if_data  <= '0;
      if_len   <= '0;
      byte_idx <= '0;
    end else if (load) begin
      unique case (pix_fmt)
        2'd1: colorspace = 8'h20;
        2'd2: colorspace = (bpc == 4'd10) ? 8'h48 : 8'h08;
        default: colorspace = 8'h08;
      endcase

      avi_mem[0]  <= 8'h02;
      avi_mem[1]  <= 8'h0D;
      avi_mem[2]  <= {vrr_en, dsc_en, 6'd0};
      avi_mem[3]  <= {4'b0000, vic[3:0]};
      avi_mem[4]  <= {vic[7:4], 4'b0000};
      avi_mem[5]  <= colorspace;
      avi_mem[6]  <= 8'h00;
      avi_mem[7]  <= 8'h00;
      avi_mem[8]  <= 8'h00;
      avi_mem[9]  <= 8'h00;
      avi_mem[10] <= 8'h00;
      avi_mem[11] <= 8'h00;
      avi_mem[12] <= infoframe_checksum(
          8'h02, 8'h0D, {vrr_en, dsc_en, 6'd0},
          {4'b0000, vic[3:0]}, {vic[7:4], 4'b0000},
          colorspace, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00
      );
      byte_idx <= '0;
      if_len   <= AVI_BYTES[4:0];
      if_valid <= 1'b1;
    end else if (if_valid) begin
      if_data <= {avi_mem[byte_idx+2], avi_mem[byte_idx+1], avi_mem[byte_idx]};
      if (byte_idx + 5'd3 >= AVI_BYTES[4:0])
        if_valid <= 1'b0;
      else
        byte_idx <= byte_idx + 5'd1;
    end
  end

endmodule
