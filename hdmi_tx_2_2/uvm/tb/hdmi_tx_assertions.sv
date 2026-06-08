import hdmi_tx_pkg::*;

module hdmi_tx_assertions (
    input logic        clk,
    input logic        rst_n,
    input logic        enable,
    input logic        hpd,
    input logic        pkt_enable,
    input link_mode_e  link_mode,
    input logic        phy_is_frl,
    input logic        phy_valid,
    input logic        tmds_valid,
    input tx_state_e   fsm_state,
    input logic [2:0]  lane_count,
    input logic        dsc_en,
    input logic        vrr_en,
    input logic        lip_en,
    input logic        fec_en
);

  property p_frl_flag;
    @(posedge clk) disable iff (!rst_n)
      (pkt_enable && link_mode == LINK_FRL) |-> phy_is_frl;
  endproperty

  property p_tmds_flag;
    @(posedge clk) disable iff (!rst_n)
      (pkt_enable && link_mode == LINK_TMDS) |-> !phy_is_frl;
  endproperty

  property p_active_phy;
    @(posedge clk) disable iff (!rst_n)
      (fsm_state == TX_ACTIVE && enable) |-> ##[1:8000] phy_valid;
  endproperty

  property p_hpd_for_active;
    @(posedge clk) disable iff (!rst_n)
      (fsm_state == TX_ACTIVE) |-> hpd;
  endproperty

  property p_frl_lanes;
    @(posedge clk) disable iff (!rst_n)
      (link_mode == LINK_FRL && fsm_state == TX_ACTIVE) |-> (lane_count == 3'd4);
  endproperty

  property p_tmds_lanes;
    @(posedge clk) disable iff (!rst_n)
      (link_mode == LINK_TMDS && fsm_state == TX_ACTIVE) |-> (lane_count == 3'd3);
  endproperty

  property p_no_pkt_when_disabled;
    @(posedge clk) disable iff (!rst_n)
      (!enable) |-> ##[0:50] !pkt_enable;
  endproperty

  a_frl_flag       : assert property (p_frl_flag);
  a_tmds_flag      : assert property (p_tmds_flag);
  a_active_phy     : assert property (p_active_phy);
  a_hpd_active     : assert property (p_hpd_for_active);
  a_frl_lanes      : assert property (p_frl_lanes);
  a_tmds_lanes     : assert property (p_tmds_lanes);
  a_no_pkt_dis     : assert property (p_no_pkt_when_disabled);

  c_frl_vrr        : cover property (@(posedge clk) fsm_state == TX_ACTIVE && vrr_en);
  c_frl_lip        : cover property (@(posedge clk) fsm_state == TX_ACTIVE && lip_en);
  c_frl_fec        : cover property (@(posedge clk) fsm_state == TX_ACTIVE && fec_en);
  c_dsc_active     : cover property (@(posedge clk) fsm_state == TX_ACTIVE && dsc_en);
  c_fsm_edid       : cover property (@(posedge clk) fsm_state == TX_READ_EDID);
  c_fsm_scdc       : cover property (@(posedge clk) fsm_state == TX_SCDC_CFG);
  c_fsm_frl_lt     : cover property (@(posedge clk) fsm_state == TX_FRL_LT);

endmodule
