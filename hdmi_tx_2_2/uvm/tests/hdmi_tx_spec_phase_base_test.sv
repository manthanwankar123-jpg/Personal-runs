// Base for SPEC.md-aligned phase tests (§1, §2, §3, §5, §6)
class hdmi_tx_spec_phase_base_test extends hdmi_tx_base_test;
  `uvm_component_utils(hdmi_tx_spec_phase_base_test)

  spec_phase_e         spec_phase;
  hdmi_tx_spec_validator spec_v;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    spec_v = hdmi_tx_spec_validator::type_id::create("spec_v");
    spec_v.active_phase = spec_phase;
    apply_spec_phase(spec_phase, cfg);
    cfg.spec_mode = 1'b1;
    uvm_config_db#(hdmi_tx_env_config)::set(this, "*", "cfg", cfg);
    uvm_config_db#(hdmi_tx_env_config)::set(null, "uvm_test_top", "cfg", cfg);
    `uvm_info("SPEC", $sformatf("Running %s", phase_name(spec_phase)), UVM_NONE)
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    if (!cfg.hdmi22_sink)
      void'(uvm_hdl_deposit("hdmi_tx_tb.hdmi22_sink", 1'b0));
  endfunction

  virtual task deep_audit_regs();
    hdmi_tx_reg_audit_seq audit;
    hdmi_tx_reg_read_seq  rd;
    bit [31:0] lip_stat;

    audit = hdmi_tx_reg_audit_seq::type_id::create("audit");
    audit.start(env.reg_agt.sqr);

    rd = hdmi_tx_reg_read_seq::type_id::create("rd");
    rd.addr = SPEC_REG_LIP_STAT;
    rd.start(env.reg_agt.sqr);
    lip_stat = rd.rdata;

    env.sb.note_regs(audit.status, audit.link, audit.feat, audit.dsc, lip_stat);

    spec_v.reset();
    spec_v.check_reg_map(audit.status, audit.feat, audit.link, audit.dsc, lip_stat, cfg);
    spec_v.check_phase_caps(audit.link, audit.feat, audit.dsc,
                            env.sb.phy_beat_cnt, env.sb.tmds_beat_cnt, cfg);
    spec_v.check_fsm_path(env.sb.fsm_state_seen, cfg.expect_frl);

    if (spec_v.err_cnt != 0)
      `uvm_error("SPEC", $sformatf("%s: %0d spec violations", phase_name(spec_phase), spec_v.err_cnt))
    else
      `uvm_info("SPEC", $sformatf("%s: all spec checks passed", phase_name(spec_phase)), UVM_NONE)
  endtask
endclass
