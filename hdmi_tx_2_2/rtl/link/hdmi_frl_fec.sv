import hdmi_tx_pkg::*;

// HDMI FRL Reed-Solomon FEC scaffold — 240B data + 16B parity per FEC frame.
module hdmi_frl_fec #(
    parameter int unsigned DATA_BYTES = 240,
    parameter int unsigned PARITY_BYTES = 16
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic [15:0] data_in,
    input  logic        data_valid,
    output logic [15:0] data_out,
    output logic        data_out_valid,
    output logic        fec_active
);

  logic [7:0]  buffer [0:DATA_BYTES+PARITY_BYTES-1];
  logic [8:0]  byte_cnt;
  logic [3:0]  parity_acc;
  logic        emit_parity;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      byte_cnt       <= '0;
      data_out       <= '0;
      data_out_valid <= 1'b0;
      fec_active     <= 1'b0;
      emit_parity    <= 1'b0;
      parity_acc     <= '0;
    end else if (!enable) begin
      byte_cnt       <= '0;
      data_out_valid <= 1'b0;
      fec_active     <= 1'b0;
      emit_parity    <= 1'b0;
    end else begin
      data_out_valid <= 1'b0;

      if (data_valid && !emit_parity) begin
        buffer[byte_cnt[7:0]] <= data_in[7:0];
        buffer[byte_cnt[7:0] + 1] <= data_in[15:8];
        parity_acc <= parity_acc ^ data_in[7:4] ^ data_in[15:12];
        data_out       <= data_in;
        data_out_valid <= 1'b1;
        byte_cnt       <= byte_cnt + 9'd2;

        if (byte_cnt >= DATA_BYTES - 2) begin
          emit_parity <= 1'b1;
          byte_cnt    <= '0;
          fec_active  <= 1'b1;
        end
      end else if (emit_parity) begin
        logic [7:0] pb;
        pb = {parity_acc, byte_cnt[3:0]} ^ 8'hA5;
        data_out       <= {8'h00, pb};
        data_out_valid <= 1'b1;
        byte_cnt       <= byte_cnt + 9'd1;
        if (byte_cnt >= PARITY_BYTES - 1) begin
          emit_parity <= 1'b0;
          fec_active  <= 1'b0;
          parity_acc  <= '0;
          byte_cnt    <= '0;
        end
      end
    end
  end

endmodule
