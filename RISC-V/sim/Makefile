# Unit tests with Verilator
VERILATOR  ?= verilator
RTL_DIR    := ../rtl
ALU_MDIR   := obj_dir_alu
REG_MDIR   := obj_dir_regfile
IMM_MDIR   := obj_dir_imm
CTL_MDIR   := obj_dir_control
CORE_MDIR  := obj_dir_core

.PHONY: all alu_sim alu_lint regfile_sim regfile_lint imm_gen_sim imm_gen_lint \
        control_sim control_lint core_sim core_lint clean

all: alu_sim

alu_lint:
	$(VERILATOR) --lint-only -Wall \
		$(RTL_DIR)/riscv_pkg.sv \
		$(RTL_DIR)/alu.sv \
		alu_tb.sv

alu_sim: alu_lint
	$(VERILATOR) --binary -Wall --top-module alu_tb -Mdir $(ALU_MDIR) \
		$(RTL_DIR)/riscv_pkg.sv \
		$(RTL_DIR)/alu.sv \
		alu_tb.sv
	./$(ALU_MDIR)/Valu_tb

regfile_lint:
	$(VERILATOR) --lint-only -Wall \
		$(RTL_DIR)/riscv_pkg.sv \
		$(RTL_DIR)/regfile.sv \
		regfile_tb.sv

regfile_sim: regfile_lint
	$(VERILATOR) --binary -Wall --top-module regfile_tb -Mdir $(REG_MDIR) \
		$(RTL_DIR)/riscv_pkg.sv \
		$(RTL_DIR)/regfile.sv \
		regfile_tb.sv
	./$(REG_MDIR)/Vregfile_tb

imm_gen_lint:
	$(VERILATOR) --lint-only -Wall -Wno-UNUSEDSIGNAL \
		$(RTL_DIR)/riscv_pkg.sv \
		$(RTL_DIR)/imm_gen.sv \
		imm_gen_tb.sv

imm_gen_sim: imm_gen_lint
	$(VERILATOR) --binary -Wall -Wno-UNUSEDSIGNAL --top-module imm_gen_tb -Mdir $(IMM_MDIR) \
		$(RTL_DIR)/riscv_pkg.sv \
		$(RTL_DIR)/imm_gen.sv \
		imm_gen_tb.sv
	./$(IMM_MDIR)/Vimm_gen_tb

control_lint:
	$(VERILATOR) --lint-only -Wall -Wno-UNUSEDSIGNAL \
		$(RTL_DIR)/riscv_pkg.sv \
		$(RTL_DIR)/control.sv \
		control_tb.sv

control_sim: control_lint
	$(VERILATOR) --binary -Wall -Wno-UNUSEDSIGNAL --top-module control_tb -Mdir $(CTL_MDIR) \
		$(RTL_DIR)/riscv_pkg.sv \
		$(RTL_DIR)/control.sv \
		control_tb.sv
	./$(CTL_MDIR)/Vcontrol_tb

core_lint:
	$(VERILATOR) --lint-only -Wall -Wno-UNOPTFLAT -Wno-UNUSEDSIGNAL \
		$(RTL_DIR)/riscv_pkg.sv \
		$(RTL_DIR)/alu.sv \
		$(RTL_DIR)/regfile.sv \
		$(RTL_DIR)/imm_gen.sv \
		$(RTL_DIR)/control.sv \
		$(RTL_DIR)/instr_mem.sv \
		$(RTL_DIR)/data_mem.sv \
		$(RTL_DIR)/riscv_core.sv \
		core_tb.sv

core_sim: core_lint
	$(VERILATOR) --binary -Wall -Wno-UNOPTFLAT -Wno-UNUSEDSIGNAL --top-module core_tb -Mdir $(CORE_MDIR) \
		$(RTL_DIR)/riscv_pkg.sv \
		$(RTL_DIR)/alu.sv \
		$(RTL_DIR)/regfile.sv \
		$(RTL_DIR)/imm_gen.sv \
		$(RTL_DIR)/control.sv \
		$(RTL_DIR)/instr_mem.sv \
		$(RTL_DIR)/data_mem.sv \
		$(RTL_DIR)/riscv_core.sv \
		core_tb.sv
	./$(CORE_MDIR)/Vcore_tb

clean:
	rm -rf $(ALU_MDIR) $(REG_MDIR) $(IMM_MDIR) $(CTL_MDIR) $(CORE_MDIR) obj_dir *.log
