// EDID + SCDC passive/active sink model for UVM TB
module hdmi_tx_ddc_slave (
    input  logic clk,
    input  logic rst_n,
    input  logic hdmi22_sink,
    input  logic scl,
    input  logic sda_i,
    input  logic scl_oe,
    input  logic sda_oe,
    output logic sda_o
);

  logic [7:0] edid_rom [0:127];
  logic [7:0] scdc_mem [0:255];
  logic       active;
  logic       scl_d;
  logic [7:0] addr;
  logic [7:0] reg_ptr;
  logic [2:0] bit_cnt;
  logic [7:0] shifter;
  logic       reading;

  initial begin
    edid_rom[0] = 8'h00; edid_rom[1] = 8'hFF;
    edid_rom[2] = 8'hFF; edid_rom[3] = 8'hFF;
    edid_rom[4] = 8'hFF; edid_rom[5] = 8'hFF;
    edid_rom[6] = 8'hFF; edid_rom[7] = 8'h00;
    for (int i = 8; i < 128; i++) edid_rom[i] = 8'h00;
    edid_rom[126] = 8'h01;
  end

  assign sda_o = sda_oe ? 1'bz : drive_sda();

  function automatic logic drive_sda();
    logic [7:0] byte_out;
    if (!active || sda_oe) return 1'b1;
    if (addr == 8'hA1 && reading) begin
      if (reg_ptr < 128) byte_out = edid_rom[reg_ptr];
      else               byte_out = 8'h00;
      return byte_out[7-bit_cnt];
    end
    if (addr == 8'hA9 && reading) begin
      byte_out = scdc_mem[reg_ptr];
      return byte_out[7-bit_cnt];
    end
    return 1'b1;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active   <= 1'b0;
      scl_d    <= 1'b1;
      bit_cnt  <= '0;
      reading  <= 1'b0;
      addr     <= '0;
      reg_ptr  <= '0;
      scdc_mem['h31] <= 8'h01;
    end else begin
      scl_d <= scl;
      if (scl_d && !scl && !sda_i && scl_oe)
        active <= 1'b1;
      if (scl_d && !scl && scl_oe) begin
        if (bit_cnt == 3'd7) begin
          bit_cnt <= '0;
          if (!reading) begin
            if (shifter == 8'hA0) begin addr <= 8'hA0; reg_ptr <= shifter; end
            else if (shifter == 8'hA1) begin addr <= 8'hA1; reading <= 1'b1; end
            else if (shifter == 8'hA8) begin addr <= 8'hA8; end
            else if (shifter == 8'hA9) begin addr <= 8'hA9; reading <= 1'b1; end
            else if (addr == 8'hA8) reg_ptr <= shifter;
          end else begin
            if (addr == 8'hA1) reg_ptr <= reg_ptr + 8'd1;
            reading <= 1'b0;
          end
        end else begin
          shifter <= {shifter[6:0], sda_i};
          bit_cnt <= bit_cnt + 3'd1;
        end
      end
      if (sda_oe && !sda_i && scl)
        active <= 1'b0;
      if (hdmi22_sink)
        scdc_mem['h31] <= 8'h01;
    end
  end

endmodule
