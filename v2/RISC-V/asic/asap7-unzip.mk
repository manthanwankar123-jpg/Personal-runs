# ASAP7 stdcell liberty setup (7 nm predictive PDK)
# https://github.com/The-OpenROAD-Project/asap7
#
# Copy into cloned repo:  cp asic/asap7-unzip.mk asic/asap7/Makefile
# Or clone first:         git clone --depth 1 https://github.com/The-OpenROAD-Project/asap7.git asic/asap7
#                         git clone --depth 1 https://github.com/The-OpenROAD-Project/asap7sc7p5t_28.git asic/asap7/asap7sc7p5t_28

LIBDIR := lib/NLDM
SRC    := asap7sc7p5t_28/LIB/NLDM
ARCHS  := AO INVBUF OA SEQ SIMPLE
VT     := RVT_TT

.PHONY: unzip clean

unzip:
	@mkdir -p $(LIBDIR)
	@for a in $(ARCHS); do \
	  f="$(SRC)/asap7sc7p5t_$${a}_$(VT)_nldm_"*.lib.7z; \
	  if ls $$f 1>/dev/null 2>&1; then \
	    echo "Extracting $$f"; \
	    7z x -o$(LIBDIR) -y $$f; \
	  else \
	    echo "ERROR: missing $$f — clone asap7sc7p5t_28 into asap7/"; \
	    exit 1; \
	  fi; \
	done
	@echo "ASAP7 RVT TT NLDM libs ready in $(LIBDIR)/"

clean:
	rm -rf $(LIBDIR)
