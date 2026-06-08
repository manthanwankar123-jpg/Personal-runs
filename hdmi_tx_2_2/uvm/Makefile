# HDMI TX 2.2 UVM verification — VCS / Xcelium / Questa
UVM_DIR    := $(abspath .)
RTL_DIR    := $(abspath ../rtl)
TB_TOP     := hdmi_tx_tb
TEST       ?= hdmi_tx_hdmi22_full_test
SEED       ?= random
SIM        ?= vcs

# Auto-detect site VCS if VCS_HOME unset (see /mnt/hw/tools/modulefiles/vcs/)
VCS_HOME_DEFAULT := /mnt/hw/tools/snps/vcs/X-2025.06-SP2
export VCS_HOME ?= $(VCS_HOME_DEFAULT)
export VCS_TARGET_ARCH ?= linux64
export VCS_ARCH_OVERRIDE ?= linux
export SNPSLMD_LICENSE_FILE ?= 27020@h3i1.csl.cloud.synopsys.com.:27020@q7c1.csl.cloud.synopsys.com.

UVM_HOME_VCS    ?= $(VCS_HOME)/etc/uvm-1.2
UVM_HOME_XRUN   ?= $(XCELIUM_HOME)/tools/methodology/UVM/CDNS-1.2
UVM_HOME_QUESTA ?= $(QUESTA_HOME)/verilog_src/uvm-1.2

VCS_BIN := $(VCS_HOME)/bin/vcs
export PATH := $(VCS_HOME)/bin:/usr/bin:$(PATH)
export LD_LIBRARY_PATH := $(VCS_HOME)/linux64/lib$(if $(LD_LIBRARY_PATH),:$(LD_LIBRARY_PATH),)

LOG_DIR    := logs
COV_DIR    := cov_work
BUILD_DIR  := work

VCS_FLAGS  := -sverilog -timescale=1ns/1ps -full64 -debug_access+all -kdb \
              +incdir+$(RTL_DIR) +incdir+$(UVM_DIR)/iface \
              -f filelist.f -top $(TB_TOP) \
              +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_LOW \
              -l $(LOG_DIR)/$(TEST).log

.PHONY: all compile run regress clean help dirs setup

all: run

setup:
	@echo "VCS_HOME=$(VCS_HOME)"
	@test -x "$(VCS_BIN)" || (echo "VCS not found at $(VCS_BIN). Run: source setup_vcs.sh  OR  module load scl vcs/X-2025.06-SP2"; exit 1)
	@echo "OK: $(VCS_BIN)"

dirs:
	@mkdir -p $(LOG_DIR) $(COV_DIR) $(BUILD_DIR)

help:
	@echo "Targets: setup, compile, run, regress, clean"
	@echo "  SIM=vcs|xrun|questa  TEST=<uvm_test>  SEED=<n|random>"
	@echo ""
	@echo "First-time VCS setup on this server:"
	@echo "  module load scl vcs/X-2025.06-SP2"
	@echo "  # or:  source setup_vcs.sh"
	@echo ""
	@echo "Primary: hdmi_tx_hdmi22_full_test, hdmi_tx_spec_regression_test"
	@echo "Per-phase: hdmi_tx_spec_phase{1,2,2b,3}_test"

compile: dirs setup
ifeq ($(SIM),vcs)
	$(VCS_BIN) $(VCS_FLAGS) -ntb_opts uvm-1.2 \
	    +define+UVM_NO_DEPRECATED \
	    -o $(BUILD_DIR)/simv
else ifeq ($(SIM),xrun)
	@if [ -z "$(XCELIUM_HOME)" ]; then echo "Set XCELIUM_HOME"; exit 1; fi
	xrun -uvm -uvmhome $(UVM_HOME_XRUN) -64bit -sv \
	    -f filelist.f -top $(TB_TOP) \
	    +UVM_TESTNAME=$(TEST) -l $(LOG_DIR)/$(TEST).log \
	    -elaborate
else ifeq ($(SIM),questa)
	@if [ -z "$(QUESTA_HOME)" ]; then echo "Set QUESTA_HOME"; exit 1; fi
	vlib $(BUILD_DIR)
	vlog -64 -sv +incdir+$(RTL_DIR) +incdir+$(UVM_DIR)/iface \
	    +incdir+$(UVM_HOME_QUESTA)/src -f filelist.f \
	    $(UVM_HOME_QUESTA)/src/uvm_pkg.sv
	vopt -64 +acc $(TB_TOP) -o sim_opt
else
	@echo "Unknown SIM=$(SIM)"; exit 1
endif

run: compile
ifeq ($(SIM),vcs)
	$(BUILD_DIR)/simv +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) -l $(LOG_DIR)/$(TEST)_run.log
else ifeq ($(SIM),xrun)
	xrun -R +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) -l $(LOG_DIR)/$(TEST)_run.log
else ifeq ($(SIM),questa)
	vsim -64 -c sim_opt +UVM_TESTNAME=$(TEST) -sv_seed $(SEED) \
	    -do "run -all; quit -f" -l $(LOG_DIR)/$(TEST)_run.log
endif

regress: dirs setup
	@chmod +x regress/run_regress.sh
	./regress/run_regress.sh $(SIM)

clean:
	rm -rf $(LOG_DIR) $(COV_DIR) $(BUILD_DIR) simv simv.d csrc ucli.key \
	    xcelium.d xrun.log xrun.history .simvision
