class hdmi_tx_vid_line_seq extends uvm_sequence #(hdmi_tx_vid_item);
  `uvm_object_utils(hdmi_tx_vid_line_seq)
  int unsigned line_pixels = 64;
  bit [29:0]   base_color = 30'h00FF00;
  function new(string name = "hdmi_tx_vid_line_seq"); super.new(name); endfunction
  task body();
    hdmi_tx_vid_item req;
    req = hdmi_tx_vid_item::type_id::create("req");
    start_item(req);
    assert(req.randomize() with {
      de == 1'b1; hsync == 1'b0; vsync == 1'b0;
      data == local::base_color; burst_len == local::line_pixels;
    });
    finish_item(req);
  endtask
endclass

class hdmi_tx_vid_frame_seq extends uvm_sequence #(hdmi_tx_vid_item);
  `uvm_object_utils(hdmi_tx_vid_frame_seq)
  int unsigned lines = 4;
  function new(string name = "hdmi_tx_vid_frame_seq"); super.new(name); endfunction
  task body();
    hdmi_tx_vid_line_seq ln;
    ln = hdmi_tx_vid_line_seq::type_id::create("ln");
    ln.line_pixels = 32;
    repeat (lines) ln.start(m_sequencer);
  endtask
endclass
