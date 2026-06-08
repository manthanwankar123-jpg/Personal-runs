import hdmi_tx_pkg::*;

// HDMI 2.2 Latency Indication Protocol (LIP) metadata packet.
module hdmi_lip_gen (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        load,
    input  logic [15:0] source_latency_ms,
    input  logic [15:0] audio_latency_ms,
    output logic [23:0] lip_data,
    output logic        lip_valid,
    output logic [4:0]  lip_len
);

  localparam int unsigned LIP_BYTES = 8;
  logic [4:0]  idx;
  logic [7:0]  mem [0:LIP_BYTES-1];

  function automatic logic [7:0] lip_cksum(
      input logic [7:0] b0, b1, b2, b3, b4, b5
  );
    logic [8:0] s;
    begin
      s = 9'h05 + 9'h08 + 9'h00;
      s = s + b0 + b1 + b2 + b3 + b4 + b5;
      lip_cksum = ~(s[7:0] + {7'd0, s[8]});
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lip_valid <= 1'b0;
      lip_data  <= '0;
      lip_len   <= LIP_BYTES[4:0];
      idx       <= '0;
    end else if (load) begin
      mem[0] <= 8'h05;
      mem[1] <= 8'h08;
      mem[2] <= 8'h00;
      mem[3] <= source_latency_ms[15:8];
      mem[4] <= source_latency_ms[7:0];
      mem[5] <= audio_latency_ms[15:8];
      mem[6] <= audio_latency_ms[7:0];
      mem[7] <= lip_cksum(8'h05, 8'h08, 8'h00,
                          source_latency_ms[15:8], source_latency_ms[7:0],
                          audio_latency_ms[15:8]);
      idx       <= '0;
      lip_valid <= 1'b1;
    end else if (lip_valid) begin
      lip_data <= {mem[idx+2], mem[idx+1], mem[idx]};
      if (idx + 5'd3 >= LIP_BYTES[4:0])
        lip_valid <= 1'b0;
      else
        idx <= idx + 5'd1;
    end
  end

endmodule
