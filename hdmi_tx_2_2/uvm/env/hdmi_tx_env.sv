class hdmi_tx_env extends uvm_env;
  `uvm_component_utils(hdmi_tx_env)

  hdmi_tx_reg_agent   reg_agt;
  hdmi_tx_vid_agent   vid_agt;
  hdmi_tx_sink_agent  sink_agt;
  hdmi_tx_phy_agent   phy_agt;
  hdmi_tx_checker     sb;
  hdmi_tx_coverage    cov;
  hdmi_tx_env_config  cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(hdmi_tx_env_config)::get(this, "", "cfg", cfg)) begin
      cfg = hdmi_tx_env_config::type_id::create("cfg");
      uvm_config_db#(hdmi_tx_env_config)::set(this, "*", "cfg", cfg);
    end

    reg_agt  = hdmi_tx_reg_agent::type_id::create("reg_agt", this);
    vid_agt  = hdmi_tx_vid_agent::type_id::create("vid_agt", this);
    sink_agt = hdmi_tx_sink_agent::type_id::create("sink_agt", this);
    phy_agt  = hdmi_tx_phy_agent::type_id::create("phy_agt", this);
    sb       = hdmi_tx_checker::type_id::create("sb", this);
    cov      = hdmi_tx_coverage::type_id::create("cov", this);

    uvm_config_db#(uvm_sequencer#(hdmi_tx_reg_item))::set(this, "sb", "reg_sqr", reg_agt.sqr);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    reg_agt.mon.ap.connect(sb.reg_imp);
    reg_agt.mon.ap.connect(cov.analysis_export);
    phy_agt.mon.ap.connect(sb.phy_imp);
    vid_agt.mon.ap.connect(sb.vid_imp);
  endfunction
endclass
