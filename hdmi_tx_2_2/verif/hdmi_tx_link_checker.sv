import hdmi_tx_pkg::*;

// Cycle-accurate link checker — bind to DUT, used by Verilator TB and UVM SVA
module hdmi_tx_link_checker (
    input logic        clk,
    input logic        rst_n,
    input logic        hpd,
    input tx_state_e   fsm_state,
    input link_mode_e  link_mode,
    input frl_rate_e   frl_rate,
    input logic [2:0]  lane_count,
    input logic        dsc_en,
    input logic        vrr_en,
    input logic        allm_en,
    input logic        lip_en,
    input logic        fec_en,
    input logic        phy_valid,
    input logic        phy_is_frl,
    input logic        tmds_valid,
    input logic [7:0]  vic,
    input logic [7:0]  max_frl_gbps,
    input logic [7:0]  compression_ratio
);

  int unsigned phy_beat_cnt;
  int unsigned tmds_beat_cnt;
  int unsigned fsm_active_cnt;
  tx_state_e   fsm_prev;
  bit          saw_edid_state;
  bit          saw_scdc_state;
  bit          saw_frl_lt;
  bit          err;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      phy_beat_cnt   <= 0;
      tmds_beat_cnt  <= 0;
      fsm_active_cnt <= 0;
      fsm_prev       <= TX_RESET;
      saw_edid_state <= 0;
      saw_scdc_state <= 0;
      saw_frl_lt     <= 0;
      err            <= 0;
    end else begin
      if (phy_valid)   phy_beat_cnt   <= phy_beat_cnt + 1;
      if (tmds_valid)  tmds_beat_cnt  <= tmds_beat_cnt + 1;
      if (fsm_state == TX_ACTIVE) fsm_active_cnt <= fsm_active_cnt + 1;

      if (fsm_state == TX_READ_EDID) saw_edid_state <= 1'b1;
      if (fsm_state == TX_SCDC_CFG)  saw_scdc_state <= 1'b1;
      if (fsm_state == TX_FRL_LT)    saw_frl_lt     <= 1'b1;

      if (fsm_state == TX_ACTIVE && !hpd)
        err <= 1'b1;

      if (link_mode == LINK_FRL && phy_valid && !phy_is_frl)
        err <= 1'b1;
      if (link_mode == LINK_TMDS && phy_valid && phy_is_frl)
        err <= 1'b1;

      fsm_prev <= fsm_state;
    end
  end

  function automatic bit check_tmds_active();
    return (fsm_state == TX_ACTIVE) && (link_mode == LINK_TMDS) &&
           !phy_is_frl && (lane_count == 3'd3);
  endfunction

  function automatic bit check_frl_active(input logic exp_96g);
    bit rate_ok;
    rate_ok = exp_96g ? (frl_rate == FRL_RATE_24G) : (frl_rate >= FRL_RATE_10G);
    return (fsm_state == TX_ACTIVE) && (link_mode == LINK_FRL) &&
           phy_is_frl && (lane_count == 3'd4) && rate_ok;
  endfunction

  function automatic void report(string tag);
    $display("[%s] fsm=%0d mode=%0d rate=%0d lanes=%0d phy=%0d tmds=%0d dsc=%b vrr=%b lip=%b fec=%b",
             tag, fsm_state, link_mode, frl_rate, lane_count,
             phy_beat_cnt, tmds_beat_cnt, dsc_en, vrr_en, lip_en, fec_en);
  endfunction

endmodule
