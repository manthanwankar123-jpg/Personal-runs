import hdmi_tx_pkg::*;

module hdmi_tx_fsm (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic        hpd,
    input  logic [31:0] hpd_debounce_max,
    input  logic        edid_done,
    input  logic        edid_ok,
    input  logic        mode_valid,
    input  link_mode_e  link_mode,
    input  logic        scdc_done,
    input  logic        frl_lt_done,
    output tx_state_e   state,
    output logic        edid_start,
    output logic        mode_calc,
    output logic        scdc_start,
    output logic        frl_lt_start,
    output logic        pkt_enable,
    output logic        scramble_en,
    output logic        infoframe_load
);

  tx_state_e state_q;
  logic [31:0] db_cnt;
  logic hpd_sync, hpd_deb;
  logic scdc_kick, lt_kick;
  logic mode_calc_sent;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q        <= TX_RESET;
      db_cnt         <= '0;
      hpd_sync       <= 1'b0;
      hpd_deb        <= 1'b0;
      edid_start     <= 1'b0;
      mode_calc      <= 1'b0;
      scdc_start     <= 1'b0;
      frl_lt_start   <= 1'b0;
      pkt_enable     <= 1'b0;
      scramble_en    <= 1'b0;
      infoframe_load <= 1'b0;
      scdc_kick      <= 1'b0;
      lt_kick        <= 1'b0;
      mode_calc_sent <= 1'b0;
    end else begin
      edid_start     <= 1'b0;
      mode_calc      <= 1'b0;
      scdc_start     <= 1'b0;
      frl_lt_start   <= 1'b0;
      infoframe_load <= 1'b0;

      hpd_sync <= hpd;
      if (hpd_sync) begin
        if (db_cnt < hpd_debounce_max)
          db_cnt <= db_cnt + 32'd1;
        else
          hpd_deb <= 1'b1;
      end else begin
        db_cnt  <= '0;
        hpd_deb <= 1'b0;
      end

      unique case (state_q)
        TX_RESET: begin
          pkt_enable     <= 1'b0;
          scramble_en    <= 1'b0;
          scdc_kick      <= 1'b0;
          lt_kick        <= 1'b0;
          mode_calc_sent <= 1'b0;
          if (enable)
            state_q <= TX_WAIT_HPD;
        end

        TX_WAIT_HPD: begin
          if (hpd_deb) begin
            edid_start <= 1'b1;
            state_q    <= TX_READ_EDID;
          end
        end

        TX_READ_EDID: begin
          if (edid_done) begin
            mode_calc_sent <= 1'b0;
            if (edid_ok)
              state_q <= TX_MODE_CALC;
            else
              state_q <= TX_WAIT_HPD;
          end
        end

        TX_MODE_CALC: begin
          if (!mode_calc_sent) begin
            mode_calc      <= 1'b1;
            mode_calc_sent <= 1'b1;
          end
          if (mode_valid) begin
            scdc_kick      <= 1'b0;
            mode_calc_sent <= 1'b0;
            state_q        <= TX_SCDC_CFG;
          end
        end

        TX_SCDC_CFG: begin
          if (!scdc_kick) begin
            scdc_start <= 1'b1;
            scdc_kick  <= 1'b1;
          end else if (scdc_done) begin
            lt_kick <= 1'b0;
            if (link_mode == LINK_FRL)
              state_q <= TX_FRL_LT;
            else begin
              infoframe_load <= 1'b1;
              state_q        <= TX_PROGRAM;
            end
          end
        end

        TX_FRL_LT: begin
          if (!lt_kick) begin
            frl_lt_start <= 1'b1;
            lt_kick      <= 1'b1;
          end else if (frl_lt_done) begin
            infoframe_load <= 1'b1;
            state_q        <= TX_PROGRAM;
          end
        end

        TX_PROGRAM: begin
          scramble_en <= (link_mode == LINK_TMDS);
          pkt_enable  <= 1'b1;
          state_q     <= TX_ACTIVE;
        end

        TX_ACTIVE: begin
          if (!enable)
            state_q <= TX_RESET;
          else if (!hpd_deb)
            state_q <= TX_LOST;
        end

        TX_LOST: begin
          pkt_enable     <= 1'b0;
          scramble_en    <= 1'b0;
          scdc_kick      <= 1'b0;
          lt_kick        <= 1'b0;
          mode_calc_sent <= 1'b0;
          if (hpd_deb)
            state_q <= TX_WAIT_HPD;
          else if (!enable)
            state_q <= TX_RESET;
        end

        default: state_q <= TX_RESET;
      endcase
    end
  end

  assign state = state_q;

endmodule
