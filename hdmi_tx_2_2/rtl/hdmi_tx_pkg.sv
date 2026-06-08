package hdmi_tx_pkg;

  localparam int unsigned EDID_LEN = 128;

  // 4K@60 (Phase 1)
  localparam int unsigned H_ACTIVE_4K60 = 3840;
  localparam int unsigned V_ACTIVE_4K60 = 2160;
  localparam int unsigned H_TOTAL_4K60   = 4400;
  localparam int unsigned V_TOTAL_4K60   = 2250;

  // 4K@120 (Phase 2 target)
  localparam int unsigned H_ACTIVE_4K120 = 3840;
  localparam int unsigned V_ACTIVE_4K120 = 2160;
  localparam int unsigned H_TOTAL_4K120   = 4400;
  localparam int unsigned V_TOTAL_4K120   = 2250;

  localparam int unsigned MAX_FRL_GBPS_P2 = 48;
  localparam int unsigned MAX_FRL_GBPS_P3 = 96;

  localparam logic [7:0] EDID_ADDR_W  = 8'hA0;
  localparam logic [7:0] EDID_ADDR_R  = 8'hA1;
  localparam logic [7:0] SCDC_ADDR_W  = 8'hA8;
  localparam logic [7:0] SCDC_ADDR_R  = 8'hA9;

  // SCDC register offsets (HDMI 2.1 subset)
  localparam logic [7:0] SCDC_SOURCE_VERSION  = 8'h01;
  localparam logic [7:0] SCDC_SOURCE_FRL_CONFIG = 8'h10;
  localparam logic [7:0] SCDC_SOURCE_FRL_READY  = 8'h11;
  localparam logic [7:0] SCDC_SINK_FRL_CONFIG   = 8'h30;
  localparam logic [7:0] SCDC_SINK_FRL_STATUS   = 8'h31;
  localparam logic [7:0] SCDC_TMDS_CONFIG       = 8'h20;

  typedef enum logic [3:0] {
    TX_RESET      = 4'd0,
    TX_WAIT_HPD   = 4'd1,
    TX_READ_EDID  = 4'd2,
    TX_MODE_CALC  = 4'd3,
    TX_SCDC_CFG   = 4'd4,
    TX_FRL_LT     = 4'd5,
    TX_PROGRAM    = 4'd6,
    TX_ACTIVE     = 4'd7,
    TX_LOST       = 4'd8
  } tx_state_e;

  typedef enum logic [1:0] {
    LINK_TMDS = 2'd0,
    LINK_FRL  = 2'd1
  } link_mode_e;

  typedef enum logic [2:0] {
    FRL_RATE_3G  = 3'd0,
    FRL_RATE_6G  = 3'd1,
    FRL_RATE_8G  = 3'd2,
    FRL_RATE_10G = 3'd3,
    FRL_RATE_12G = 3'd4,
    FRL_RATE_24G = 3'd5
  } frl_rate_e;

  typedef enum logic [1:0] {
    ULTRA96_48 = 2'd0,
    ULTRA96_64 = 2'd1,
    ULTRA96_80 = 2'd2,
    ULTRA96_96 = 2'd3
  } ultra96_tier_e;

  typedef enum logic [1:0] {
    PIX_RGB888   = 2'd0,
    PIX_YUV422   = 2'd1,
    PIX_RGB101010 = 2'd2
  } pix_fmt_e;

  typedef enum logic [1:0] {
    PKT_VIDEO,
    PKT_CONTROL,
    PKT_AUDIO,
    PKT_INFOFRAME
  } pkt_kind_e;

  function automatic int unsigned frl_gbps(input frl_rate_e rate, input logic [2:0] lanes);
    int unsigned per_lane;
    begin
      unique case (rate)
        FRL_RATE_24G: per_lane = 24;
        FRL_RATE_12G: per_lane = 12;
        FRL_RATE_10G: per_lane = 10;
        FRL_RATE_8G:  per_lane = 8;
        FRL_RATE_6G:  per_lane = 6;
        default:      per_lane = 3;
      endcase
      frl_gbps = per_lane * lanes;
    end
  endfunction

  function automatic int unsigned ultra96_max_gbps(input ultra96_tier_e tier);
    begin
      unique case (tier)
        ULTRA96_96: ultra96_max_gbps = 96;
        ULTRA96_80: ultra96_max_gbps = 80;
        ULTRA96_64: ultra96_max_gbps = 64;
        default:    ultra96_max_gbps = 48;
      endcase
    end
  endfunction

  function automatic int unsigned pix_bandwidth_mbps(
      input int unsigned h_active,
      input int unsigned v_active,
      input int unsigned refresh_hz,
      input pix_fmt_e  fmt,
      input logic [3:0] bpc
  );
    int unsigned bpp;
    begin
      unique case (fmt)
        PIX_YUV422:    bpp = (bpc * 2);
        PIX_RGB101010: bpp = 30;
        default:       bpp = 24;
      endcase
      pix_bandwidth_mbps = (h_active * v_active * refresh_hz * bpp) / 1_000_000;
    end
  endfunction

  function automatic logic [9:0] tmds_control_code(
      input logic c1,
      input logic c0,
      input logic disparity
  );
    logic [9:0] code_pos;
    logic [9:0] code_neg;
    begin
      case ({c1, c0})
        2'b00: begin
          code_pos = 10'b1101010100;
          code_neg = 10'b0010101011;
        end
        2'b01: begin
          code_pos = 10'b0010101011;
          code_neg = 10'b1101010100;
        end
        2'b10: begin
          code_pos = 10'b0101010100;
          code_neg = 10'b1010101011;
        end
        default: begin
          code_pos = 10'b1010101011;
          code_neg = 10'b0101010100;
        end
      endcase
      tmds_control_code = disparity ? code_neg : code_pos;
    end
  endfunction

  function automatic logic [8:0] tmds_q_m(input logic [7:0] data);
    logic [3:0] n1;
    begin
      n1 = $countones(data[7:0]);
      if (n1 > 4 || (n1 == 4 && data[0] == 1'b0)) begin
        tmds_q_m[8]   = 1'b1;
        tmds_q_m[7:0] = ~data[7:0];
      end else begin
        tmds_q_m[8]   = 1'b0;
        tmds_q_m[7:0] = data[7:0];
      end
    end
  endfunction

  function automatic logic [9:0] tmds_encode_video(
      input logic [7:0] data,
      input logic       disparity
  );
    logic [8:0] q_m;
    logic [3:0] n0;
    logic [3:0] n1;
    logic [9:0] code;
    begin
      q_m = tmds_q_m(data);
      n1  = $countones(q_m[7:0]);
      n0  = $countones(q_m[8] ? ~q_m[7:0] : q_m[7:0]);
      if ((disparity == 1'b0 && n1 <= n0) || (disparity == 1'b1 && n1 < n0)) begin
        code[9]   = q_m[8];
        code[8]   = ~q_m[8];
        code[7:0] = (q_m[8] ? ~q_m[7:0] : q_m[7:0]);
      end else begin
        code[9]   = ~q_m[8];
        code[8]   = q_m[8];
        code[7:0] = (q_m[8] ? q_m[7:0] : ~q_m[7:0]);
      end
      tmds_encode_video = code;
    end
  endfunction

  function automatic logic next_disparity_video(
      input logic [9:0] code,
      input logic       disparity
  );
    logic signed [5:0] acc;
    logic [3:0]        ones;
    begin
      ones = $countones(code[7:0]);
      acc  = disparity ? 6'sd1 : -6'sd1;
      if (code[9] == 1'b0) acc = acc - 6'sd1;
      if (code[8] == 1'b0) acc = acc - 6'sd1;
      acc = acc - ($signed(6'sd2) * $signed({2'b00, ones}));
      next_disparity_video = (acc[5] == 1'b0);
    end
  endfunction

endpackage
