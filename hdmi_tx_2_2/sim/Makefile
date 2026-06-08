VERILATOR ?= verilator
RTL_DIR   := ../rtl
VERIF_DIR := ../verif
OBJ_DIR   := obj_dir_hdmi

RTL_SRCS := \
	$(RTL_DIR)/hdmi_tx_pkg.sv \
	$(RTL_DIR)/video/hdmi_vid_csc.sv \
	$(RTL_DIR)/video/hdmi_dsc_pps.sv \
	$(RTL_DIR)/video/hdmi_dsc_encoder.sv \
	$(RTL_DIR)/video/hdmi_dsc_wrap.sv \
	$(RTL_DIR)/audio/hdmi_audio_in.sv \
	$(RTL_DIR)/packet/hdmi_tmds_encoder.sv \
	$(RTL_DIR)/packet/hdmi_infoframe_gen.sv \
	$(RTL_DIR)/packet/hdmi_gaming_meta.sv \
	$(RTL_DIR)/packet/hdmi_lip_gen.sv \
	$(RTL_DIR)/packet/hdmi_packetizer.sv \
	$(RTL_DIR)/link/hdmi_tmds_link.sv \
	$(RTL_DIR)/link/hdmi_frl_fec.sv \
	$(RTL_DIR)/link/hdmi_frl_link.sv \
	$(RTL_DIR)/link/hdmi_link_mux.sv \
	$(RTL_DIR)/link/hdmi_mode_calc.sv \
	$(RTL_DIR)/link/hdmi_frl_lt.sv \
	$(RTL_DIR)/link/hdmi_tx_fsm.sv \
	$(RTL_DIR)/ddc/hdmi_ddc_bus.sv \
	$(RTL_DIR)/ddc/hdmi_edid_parser.sv \
	$(RTL_DIR)/hdmi_tx_top.sv

.PHONY: all lint sim clean

all: sim

lint:
	$(VERILATOR) --lint-only -Wall -Wno-UNOPTFLAT -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
		-Wno-IMPORTSTAR -Wno-BLKSEQ -Wno-INITIALDLY -Wno-UNUSEDPARAM -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-UNSIGNED \
		-I$(RTL_DIR) \
		$(RTL_SRCS) $(VERIF_DIR)/hdmi_tx_link_checker.sv $(VERIF_DIR)/tb_hdmi_tx.sv

sim: lint
	$(VERILATOR) --binary -Wall -Wno-UNOPTFLAT -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
		-Wno-IMPORTSTAR -Wno-BLKSEQ -Wno-INITIALDLY -Wno-UNUSEDPARAM -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-UNSIGNED \
		-I$(RTL_DIR) \
		--top-module tb_hdmi_tx -Mdir $(OBJ_DIR) \
		$(RTL_SRCS) $(VERIF_DIR)/hdmi_tx_link_checker.sv $(VERIF_DIR)/tb_hdmi_tx.sv
	./$(OBJ_DIR)/Vtb_hdmi_tx

clean:
	rm -rf $(OBJ_DIR) *.log
