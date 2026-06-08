import hdmi_tx_pkg::*;

module hdmi_frl_link (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic        fec_en,
    input  logic [7:0]  lane0_data,
    input  logic [7:0]  lane1_data,
    input  logic [7:0]  lane2_data,
    input  logic [7:0]  lane3_data,
    input  logic        in_valid,
    output logic [15:0] frl_data [0:3],
    output logic        frl_valid,
    output logic        fec_active
);

  logic [7:0]  hold0, hold1, hold2, hold3;
  logic        half;
  logic [15:0] raw_frl [0:3];
  logic        raw_valid;

  logic [15:0] fec_out;
  logic        fec_out_valid;

  hdmi_frl_fec u_fec (
      .clk(clk), .rst_n(rst_n), .enable(enable && fec_en),
      .data_in(raw_frl[0]), .data_valid(raw_valid),
      .data_out(fec_out), .data_out_valid(fec_out_valid), .fec_active(fec_active)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      frl_data  <= '{default: '0};
      frl_valid <= 1'b0;
      hold0     <= '0;
      hold1     <= '0;
      hold2     <= '0;
      hold3     <= '0;
      half      <= 1'b0;
      raw_valid <= 1'b0;
    end else if (!enable) begin
      frl_valid <= 1'b0;
      raw_valid <= 1'b0;
      half      <= 1'b0;
    end else begin
      frl_valid <= 1'b0;
      raw_valid <= 1'b0;

      if (in_valid) begin
        if (!half) begin
          hold0 <= lane0_data;
          hold1 <= lane1_data;
          hold2 <= lane2_data;
          hold3 <= lane3_data;
          half  <= 1'b1;
        end else begin
          raw_frl[0] <= {lane0_data, hold0};
          raw_frl[1] <= {lane1_data, hold1};
          raw_frl[2] <= {lane2_data, hold2};
          raw_frl[3] <= {lane3_data, hold3};
          raw_valid  <= 1'b1;
          half       <= 1'b0;

          if (fec_en && fec_out_valid) begin
            frl_data[0] <= fec_out;
            frl_data[1] <= raw_frl[1];
            frl_data[2] <= raw_frl[2];
            frl_data[3] <= raw_frl[3];
            frl_valid   <= 1'b1;
          end else if (!fec_en) begin
            frl_data    <= raw_frl;
            frl_valid   <= 1'b1;
          end
        end
      end
    end
  end

endmodule
