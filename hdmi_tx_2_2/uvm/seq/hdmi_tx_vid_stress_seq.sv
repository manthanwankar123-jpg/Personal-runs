class hdmi_tx_vid_stress_seq extends uvm_sequence #(hdmi_tx_vid_item);
  `uvm_object_utils(hdmi_tx_vid_stress_seq)

  int unsigned frames = 2;
  int unsigned line_len = 128;

  function new(string name = "hdmi_tx_vid_stress_seq");
    super.new(name);
  endfunction

  task body();
    hdmi_tx_vid_item req;
    int f, p;
    for (f = 0; f < frames; f++) begin
      req = hdmi_tx_vid_item::type_id::create($sformatf("vs_%0d", f));
      start_item(req);
      assert(req.randomize() with {
        de == 1'b0; hsync == 1'b0; vsync == 1'b1; burst_len == 4;
      });
      finish_item(req);

      for (p = 0; p < line_len; p++) begin
        req = hdmi_tx_vid_item::type_id::create($sformatf("px_%0d_%0d", f, p));
        start_item(req);
        assert(req.randomize() with {
          de == 1'b1; vsync == 1'b0; hsync == (p == 0);
          data == (30'h0000FF + p); burst_len == 1;
        });
        finish_item(req);
      end

      req = hdmi_tx_vid_item::type_id::create($sformatf("ve_%0d", f));
      start_item(req);
      assert(req.randomize() with {
        de == 1'b0; vsync == 1'b0; burst_len == 8;
      });
      finish_item(req);
    end
  endtask
endclass
