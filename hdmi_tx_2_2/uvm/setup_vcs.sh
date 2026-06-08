#!/usr/bin/env bash
# Source before 'make SIM=vcs ...' if modules are not loaded.
# Equivalent: module load scl vcs/X-2025.06-SP2

export VCS_HOME="${VCS_HOME:-/mnt/hw/tools/snps/vcs/X-2025.06-SP2}"
export VCS_TARGET_ARCH="${VCS_TARGET_ARCH:-linux64}"
export VCS_ARCH_OVERRIDE="${VCS_ARCH_OVERRIDE:-linux}"
export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-27020@h3i1.csl.cloud.synopsys.com.:27020@q7c1.csl.cloud.synopsys.com.}"
export LM_LICENSE_FILE="${LM_LICENSE_FILE:-$SNPSLMD_LICENSE_FILE}"

export PATH="$VCS_HOME/bin:/usr/bin:$PATH"
export LD_LIBRARY_PATH="$VCS_HOME/linux64/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

echo "VCS_HOME=$VCS_HOME"
command -v vcs
