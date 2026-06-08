import hdmi_tx_pkg::*;

module hdmi_frl_lt #(
    parameter bit FAST_LT = 1'b0
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  frl_rate_e   frl_rate,
    input  logic [2:0]  lane_count,
    input  logic        flt_ready,
    input  logic        phy_ready,
    output logic        busy,
    output logic        done,
    output logic        test_pattern_en
);

  typedef enum logic [2:0] {
    LT_LTS1,
    LT_LTS2,
    LT_LTS3,
    LT_LTS4,
    LT_DONE,
    LT_IDLE
  } lt_state_e;

  lt_state_e state;
  logic [15:0] timer;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= LT_IDLE;
      busy             <= 1'b0;
      done             <= 1'b0;
      test_pattern_en  <= 1'b0;
      timer            <= '0;
    end else begin
      done <= 1'b0;

      unique case (state)
        LT_IDLE: begin
          test_pattern_en <= 1'b0;
          if (start) begin
            busy  <= 1'b1;
            timer <= '0;
            if (FAST_LT)
              state <= LT_LTS4;
            else
              state <= LT_LTS1;
          end
        end

        LT_LTS1: begin
          state <= LT_LTS2;
        end

        LT_LTS2: begin
          if (phy_ready)
            state <= LT_LTS3;
        end

        LT_LTS3: begin
          test_pattern_en <= 1'b1;
          if (flt_ready)
            state <= LT_LTS4;
          else if (timer > 16'd1000)
            state <= LT_LTS4;
          else
            timer <= timer + 16'd1;
        end

        LT_LTS4: begin
          test_pattern_en <= 1'b0;
          state           <= LT_DONE;
        end

        LT_DONE: begin
          done <= 1'b1;
          busy <= 1'b0;
          state <= LT_IDLE;
        end

        default: state <= LT_IDLE;
      endcase
    end
  end

endmodule
