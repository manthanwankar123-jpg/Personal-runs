import hdmi_tx_pkg::*;

// Slice-based DSC encoder: delta + nibble packing per 8-pixel group.
module hdmi_dsc_encoder #(
    parameter int unsigned SLICE_WIDTH = 32
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic        frame_start,
    input  logic [29:0] pix_data,
    input  logic        pix_de,
    output logic [7:0]  dsc_byte,
    output logic        dsc_valid,
    output logic        slice_start,
    output logic [15:0] bytes_out,
    output logic [7:0]  compression_ratio
);

  typedef enum logic [1:0] {
    DSC_IDLE,
    DSC_HEADER,
    DSC_RUN,
    DSC_PAD
  } dsc_st_e;

  dsc_st_e      state;
  logic [7:0]   prev_r, prev_g, prev_b;
  logic [5:0]   pix_in_slice;
  logic [7:0]   hdr_byte;
  logic [15:0]  raw_count;
  logic [15:0]  comp_count;
  logic [3:0]   nibble_hi;
  logic         have_nibble;

  function automatic logic signed [8:0] delta9(input logic [7:0] cur, input logic [7:0] prev);
    logic signed [9:0] d;
    begin
      d = $signed({2'b00, cur}) - $signed({2'b00, prev});
      if (d > 10'sd127)  delta9 = 9'sd127;
      else if (d < -10'sd128) delta9 = -9'sd128;
      else delta9 = d[8:0];
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= DSC_IDLE;
      dsc_byte         <= '0;
      dsc_valid        <= 1'b0;
      slice_start      <= 1'b0;
      bytes_out        <= '0;
      compression_ratio<= 8'd100;
      prev_r           <= '0;
      prev_g           <= '0;
      prev_b           <= '0;
      pix_in_slice     <= '0;
      raw_count        <= '0;
      comp_count       <= '0;
      have_nibble      <= 1'b0;
    end else if (!enable) begin
      state     <= DSC_IDLE;
      dsc_valid <= 1'b0;
    end else begin
      dsc_valid   <= 1'b0;
      slice_start <= 1'b0;

      unique case (state)
        DSC_IDLE: begin
          if (frame_start) begin
            state        <= DSC_HEADER;
            hdr_byte     <= 8'hA5;
            raw_count    <= '0;
            comp_count   <= '0;
            pix_in_slice <= '0;
            have_nibble  <= 1'b0;
          end
        end

        DSC_HEADER: begin
          dsc_byte    <= hdr_byte;
          dsc_valid   <= 1'b1;
          slice_start <= (hdr_byte == 8'hA5);
          comp_count  <= comp_count + 16'd1;
          if (hdr_byte == 8'hA5)
            hdr_byte <= 8'h5A;
          else
            state <= DSC_RUN;
        end

        DSC_RUN: begin
          if (pix_de) begin
            logic signed [8:0] dr, dg, db;
            logic [3:0]        nibble;
            dr = delta9(pix_data[29:22], prev_r);
            dg = delta9(pix_data[21:14], prev_g);
            db = delta9(pix_data[13:6],  prev_b);
            prev_r <= pix_data[29:22];
            prev_g <= pix_data[21:14];
            prev_b <= pix_data[13:6];
            raw_count <= raw_count + 16'd3;

            nibble = 4'(dr[3:0] ^ dg[3:0] ^ db[3:0]);
            if (!have_nibble) begin
              nibble_hi   <= nibble;
              have_nibble <= 1'b1;
            end else begin
              dsc_byte  <= {nibble, nibble_hi};
              dsc_valid <= 1'b1;
              comp_count <= comp_count + 16'd1;
              have_nibble <= 1'b0;
            end

            pix_in_slice <= pix_in_slice + 6'd1;
            if (pix_in_slice >= SLICE_WIDTH[5:0])
              state <= DSC_PAD;
          end
        end

        DSC_PAD: begin
          if (have_nibble) begin
            dsc_byte    <= {4'h0, nibble_hi};
            dsc_valid   <= 1'b1;
            have_nibble <= 1'b0;
            comp_count  <= comp_count + 16'd1;
          end
          bytes_out <= comp_count;
          if (raw_count != 0)
            compression_ratio <= (comp_count * 8'd100) / raw_count[7:0];
          else
            compression_ratio <= 8'd50;
          pix_in_slice <= '0;
          hdr_byte     <= 8'hA5;
          state        <= DSC_HEADER;
        end

        default: state <= DSC_IDLE;
      endcase
    end
  end

endmodule
