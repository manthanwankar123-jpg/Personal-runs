import hdmi_tx_pkg::*;

module hdmi_gaming_meta (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        load,
    input  logic        vrr_en,
    input  logic        allm_en,
    output logic        scdc_allm,
    output logic        em_data_valid,
    output logic [23:0] em_data
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      scdc_allm     <= 1'b0;
      em_data_valid <= 1'b0;
      em_data       <= '0;
    end else if (load) begin
      scdc_allm     <= allm_en;
      em_data_valid <= vrr_en;
      em_data       <= {8'h01, 8'h00, {6'd0, vrr_en, allm_en}};
    end else begin
      em_data_valid <= 1'b0;
    end
  end

endmodule
