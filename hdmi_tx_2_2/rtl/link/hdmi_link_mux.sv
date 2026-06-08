import hdmi_tx_pkg::*;

module hdmi_link_mux (
    input  link_mode_e  link_mode,
    input  logic [9:0]  tmds_data [0:3],
    input  logic        tmds_valid,
    input  logic [15:0] frl_data [0:3],
    input  logic        frl_valid,
    output logic [15:0] phy_data [0:3],
    output logic        phy_valid,
    output logic        phy_is_frl
);

  always_comb begin
    phy_is_frl = (link_mode == LINK_FRL);
    if (link_mode == LINK_FRL) begin
      phy_data  = frl_data;
      phy_valid = frl_valid;
    end else begin
      phy_data[0] = {6'd0, tmds_data[0]};
      phy_data[1] = {6'd0, tmds_data[1]};
      phy_data[2] = {6'd0, tmds_data[2]};
      phy_data[3] = {6'd0, tmds_data[3]};
      phy_valid   = tmds_valid;
    end
  end

endmodule
