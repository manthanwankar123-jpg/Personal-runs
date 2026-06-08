class hdmi_tx_link_bringup_seq extends uvm_sequence #(hdmi_tx_reg_item);
  `uvm_object_utils(hdmi_tx_link_bringup_seq)

  hdmi_tx_env_config cfg;

  function new(string name = "hdmi_tx_link_bringup_seq");
    super.new(name);
  endfunction

  task body();
    hdmi_tx_reg_item req;

    if (!uvm_config_db#(hdmi_tx_env_config)::get(null, "uvm_test_top", "cfg", cfg))
      `uvm_fatal("NOCFG", "cfg missing")

    req = hdmi_tx_reg_item::type_id::create("req");
    req.op = REG_WRITE; req.addr = REG_ULTRA96; req.data = cfg.ultra96_cfg;
    start_item(req); finish_item(req);

    req = hdmi_tx_reg_item::type_id::create("req");
    req.op = REG_WRITE; req.addr = REG_LIP; req.data = cfg.lip_latency_ms;
    start_item(req); finish_item(req);

    req = hdmi_tx_reg_item::type_id::create("req");
    req.op = REG_WRITE; req.addr = REG_VIDEO_CFG;
    req.data = {18'b0, cfg.bpc, cfg.pix_fmt, cfg.vic};
    start_item(req); finish_item(req);

    req = hdmi_tx_reg_item::type_id::create("req");
    req.op = REG_WRITE; req.addr = REG_LINK_CFG; req.data = cfg.link_cfg;
    start_item(req); finish_item(req);

    // Re-write ULTRA96 immediately before enable (first APB beat can be lost on cold start)
    req = hdmi_tx_reg_item::type_id::create("req");
    req.op = REG_WRITE; req.addr = REG_ULTRA96; req.data = cfg.ultra96_cfg;
    start_item(req); finish_item(req);

    req = hdmi_tx_reg_item::type_id::create("req");
    req.op = REG_WRITE; req.addr = REG_CTRL; req.data = 32'h0000_0001;
    start_item(req); finish_item(req);
  endtask
endclass
