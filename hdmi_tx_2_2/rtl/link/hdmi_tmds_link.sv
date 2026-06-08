import hdmi_tx_pkg::*;

module hdmi_tmds_link (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic        scramble_en,
    input  logic        vsync_fall,
    input  logic [7:0]  lane0_data,
    input  logic [7:0]  lane1_data,
    input  logic [7:0]  lane2_data,
    input  logic        lane_video,
    input  logic        lane_c0,
    input  logic        lane_c1,
    input  logic        in_valid,
    output logic [9:0]  tmds_data [0:3],
    output logic        tmds_valid
);

  logic load_enc;
  logic [9:0] code0, code1, code2;
  logic disp0, disp1, disp2;

  logic [23:0] lfsr;
  logic [9:0] scr0, scr1, scr2, scr_clk;

  hdmi_tmds_encoder u_enc0 (
      .clk(clk), .rst_n(rst_n), .video_data(lane_video),
      .data(lane0_data), .c0(lane_c0), .c1(lane_c1),
      .load(load_enc), .code(code0), .disparity(disp0)
  );

  hdmi_tmds_encoder u_enc1 (
      .clk(clk), .rst_n(rst_n), .video_data(lane_video),
      .data(lane1_data), .c0(lane_c0), .c1(lane_c1),
      .load(load_enc), .code(code1), .disparity(disp1)
  );

  hdmi_tmds_encoder u_enc2 (
      .clk(clk), .rst_n(rst_n), .video_data(lane_video),
      .data(lane2_data), .c0(lane_c0), .c1(lane_c1),
      .load(load_enc), .code(code2), .disparity(disp2)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lfsr       <= 24'hFFFFFF;
      tmds_data  <= '{default: '0};
      tmds_valid <= 1'b0;
      load_enc   <= 1'b0;
    end else if (!enable) begin
      tmds_valid <= 1'b0;
      load_enc   <= 1'b0;
    end else begin
      load_enc <= in_valid;

      if (vsync_fall)
        lfsr <= 24'hFFFFFF;
      else if (in_valid && scramble_en)
        lfsr <= {lfsr[22:0], lfsr[23] ^ lfsr[17] ^ lfsr[15] ^ lfsr[0]};

      if (in_valid) begin
        scr0    = code0;
        scr1    = code1;
        scr2    = code2;
        scr_clk = tmds_control_code(1'b0, 1'b0, 1'b0);
        if (scramble_en) begin
          scr0 = code0 ^ {2'b00, lfsr[23:16]};
          scr1 = code1 ^ {2'b00, lfsr[15:8]};
          scr2 = code2 ^ {2'b00, lfsr[7:0]};
        end
        tmds_data[0] <= scr0;
        tmds_data[1] <= scr1;
        tmds_data[2] <= scr2;
        tmds_data[3] <= scr_clk;
        tmds_valid   <= 1'b1;
      end else begin
        tmds_valid <= 1'b0;
      end
    end
  end

endmodule
