// timing_cfg.vh — synthesis-only timing defines (not used in sim)
//
// Vivado:  verilog_define {FPGA_TIMING_SYNTH}
// ASIC:    sv2v -DASIC_TIMING_SYNTH

`ifdef FPGA_TIMING_SYNTH
 `define PIPELINE_TIMING 1
`endif
