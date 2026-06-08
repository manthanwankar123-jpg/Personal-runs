import hdmi_tx_pkg::*;

module hdmi_tmds_encoder (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        video_data,
    input  logic [7:0]  data,
    input  logic        c0,
    input  logic        c1,
    input  logic        load,
    output logic [9:0]  code,
    output logic        disparity
);

  logic disp_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      code    <= '0;
      disp_q  <= 1'b0;
      disparity <= 1'b0;
    end else if (load) begin
      if (!video_data) begin
        code      <= tmds_control_code(c1, c0, disp_q);
        disp_q    <= disp_q;
      end else begin
        code      <= tmds_encode_video(data, disp_q);
        disp_q    <= next_disparity_video(code, disp_q);
      end
      disparity <= disp_q;
    end
  end

endmodule
