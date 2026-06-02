VERILATOR ?= verilator
RTL_DIR   := ../rtl
CORE_MDIR := obj_dir_core

RTL_SRCS := \
	$(RTL_DIR)/riscv_pkg.sv \
	$(RTL_DIR)/instr_rom.sv \
	$(RTL_DIR)/alu.sv \
	$(RTL_DIR)/regfile.sv \
	$(RTL_DIR)/imm_gen.sv \
	$(RTL_DIR)/control.sv \
	$(RTL_DIR)/csr_file.sv \
	$(RTL_DIR)/unified_mem.sv \
	$(RTL_DIR)/riscv_core.sv

.PHONY: all core_sim core_lint clean

all: core_sim

core_lint:
	$(VERILATOR) --lint-only -Wall -Wno-UNOPTFLAT -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
		-I$(RTL_DIR) \
		$(RTL_SRCS) core_tb.sv

core_sim: core_lint
	$(VERILATOR) --binary -Wall -Wno-UNOPTFLAT -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
		-I$(RTL_DIR) \
		--top-module core_tb -Mdir $(CORE_MDIR) \
		$(RTL_SRCS) core_tb.sv
	./$(CORE_MDIR)/Vcore_tb

clean:
	rm -rf $(CORE_MDIR) obj_dir *.log
