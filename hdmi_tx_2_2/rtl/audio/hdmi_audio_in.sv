module hdmi_audio_in (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic        i2s_lrck,
    input  logic        i2s_sdat,
    output logic [15:0] sample_l,
    output logic [15:0] sample_r,
    output logic        sample_valid,
    output logic        fifo_full
);

  logic [4:0]  bit_cnt;
  logic [15:0] shift_l;
  logic [15:0] shift_r;
  logic        lrck_d;
  logic        collecting;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bit_cnt      <= '0;
      shift_l      <= '0;
      shift_r      <= '0;
      sample_l     <= '0;
      sample_r     <= '0;
      sample_valid <= 1'b0;
      lrck_d       <= 1'b0;
      collecting   <= 1'b0;
      fifo_full    <= 1'b0;
    end else if (enable) begin
      sample_valid <= 1'b0;
      lrck_d       <= i2s_lrck;

      if (i2s_lrck != lrck_d) begin
        if (collecting) begin
          if (!i2s_lrck) begin
            sample_l     <= shift_l;
            sample_valid <= 1'b1;
          end else begin
            sample_r     <= shift_r;
            sample_valid <= 1'b1;
          end
        end
        collecting <= 1'b1;
        bit_cnt    <= '0;
      end else if (collecting && bit_cnt < 16) begin
        if (!i2s_lrck)
          shift_l <= {shift_l[14:0], i2s_sdat};
        else
          shift_r <= {shift_r[14:0], i2s_sdat};
        bit_cnt <= bit_cnt + 5'd1;
      end
    end else begin
      sample_valid <= 1'b0;
    end
  end

endmodule
