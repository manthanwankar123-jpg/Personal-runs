import hdmi_tx_pkg::*;

module hdmi_packetizer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  link_mode_e  link_mode,
    input  logic [29:0] pix_data,
    input  logic        pix_de,
    input  logic        frame_start,
    input  logic [15:0] aud_l,
    input  logic [15:0] aud_r,
    input  logic        aud_valid,
    input  logic        infoframe_pending,
    input  logic        lip_pending,
    input  logic [23:0] if_data,
    input  logic        if_valid,
    input  logic [23:0] lip_data,
    input  logic        lip_valid,
    input  logic [7:0]  lane3_aux,
    output logic [7:0]  lane0_data,
    output logic [7:0]  lane1_data,
    output logic [7:0]  lane2_data,
    output logic [7:0]  lane3_data,
    output logic        lane_video,
    output logic        lane_c0,
    output logic        lane_c1,
    output logic        out_valid,
    output logic        infoframe_done
);

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_VIDEO,
    ST_INFO,
    ST_LIP,
    ST_AUDIO
  } pkt_state_e;

  pkt_state_e state;
  logic [2:0] pix_phase;
  logic [4:0] if_byte_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= ST_IDLE;
      pix_phase      <= 3'd0;
      lane0_data     <= '0;
      lane1_data     <= '0;
      lane2_data     <= '0;
      lane3_data     <= '0;
      lane_video     <= 1'b0;
      lane_c0        <= 1'b0;
      lane_c1        <= 1'b0;
      out_valid      <= 1'b0;
      infoframe_done <= 1'b0;
      if_byte_cnt    <= '0;
    end else if (!enable) begin
      state     <= ST_IDLE;
      out_valid <= 1'b0;
    end else begin
      out_valid      <= 1'b1;
      infoframe_done <= 1'b0;
      lane_video     <= 1'b0;
      lane_c0        <= 1'b0;
      lane_c1        <= 1'b0;

      unique case (state)
        ST_IDLE: begin
          if (frame_start && infoframe_pending)
            state <= ST_INFO;
          else if (frame_start && lip_pending)
            state <= ST_LIP;
          else if (pix_de)
            state <= ST_VIDEO;
          else if (aud_valid)
            state <= ST_AUDIO;
        end

        ST_VIDEO: begin
          lane_video <= 1'b1;
          if (link_mode == LINK_FRL) begin
            unique case (pix_phase)
              3'd0: lane0_data <= pix_data[29:22];
              3'd1: lane1_data <= pix_data[21:14];
              3'd2: lane2_data <= pix_data[13:6];
              3'd3: lane3_data <= lane3_aux;
              default: ;
            endcase
            if (pix_de)
              pix_phase <= pix_phase + 3'd1;
          end else begin
            unique case (pix_phase[1:0])
              2'd0: lane0_data <= pix_data[23:16];
              2'd1: lane1_data <= pix_data[15:8];
              2'd2: lane2_data <= pix_data[7:0];
              default: ;
            endcase
            lane3_data <= lane3_aux;
            if (pix_de)
              pix_phase <= pix_phase + 3'd1;
          end

          if (!pix_de) begin
            pix_phase <= 3'd0;
            state     <= ST_IDLE;
          end
        end

        ST_INFO: begin
          if (if_valid) begin
            lane0_data <= if_data[23:16];
            lane1_data <= if_data[15:8];
            lane2_data <= if_data[7:0];
            lane3_data <= lane3_aux;
            if_byte_cnt <= if_byte_cnt + 5'd1;
          end else begin
            infoframe_done <= 1'b1;
            if_byte_cnt    <= '0;
            state          <= lip_pending ? ST_LIP : ST_IDLE;
          end
        end

        ST_LIP: begin
          if (lip_valid) begin
            lane0_data <= lip_data[23:16];
            lane1_data <= lip_data[15:8];
            lane2_data <= lip_data[7:0];
            lane3_data <= lane3_aux;
          end else begin
            state <= ST_IDLE;
          end
        end

        ST_AUDIO: begin
          lane0_data <= aud_l[15:8];
          lane1_data <= aud_l[7:0];
          lane2_data <= aud_r[15:8];
          lane3_data <= aud_r[7:0];
          state      <= ST_IDLE;
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule
