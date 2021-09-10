#------------------------------------------------------------------------------
# Build-specific Variables
#------------------------------------------------------------------------------

ifndef DFSIM_TOP
  $(info `DFSIM_TOP` may be set to change the name of toplevel entity.)
  DFSIM_TOP = Testbench
  $(info `DFSIM_TOP` set to `$(DFSIM_TOP)` by default.)
endif

ifndef DFSIM_SCRIPT
  $(error `DFSIM_SCRIPT` must be set to the LUA script implementing the simulation logic!')
endif

ifndef DFSIM_LIST
  $(error `DFSIM_LIST` must be set to a file containing a list of hardware source files!)
endif

ifndef DFSIM_MODEL_DIR
  $(warning `DFSIM_MODEL_DIR` must be set to a writable directory for model build artifacts.)
  DFSIM_MODEL_DIR = $(realpath ./build)
  $(warning `DFSIM_MODEL_DIR` set to $(DFSIM_MODEL_DIR) by default.)
endif
SW_BUILD_DIR   = $(DFSIM_MODEL_DIR)/sw
SW_BUILD_LOG   = $(SW_BUILD_DIR)/build.log
SW_BUILD_ERR   = $(SW_BUILD_DIR)/error.log
SW_BUILD_LIB   = $(SW_BUILD_DIR)/aux.a
HW_BUILD_DIR   = $(DFSIM_MODEL_DIR)/hw
HW_BUILD_LOG   = $(HW_BUILD_DIR)/build.log
HW_BUILD_ERR   = $(HW_BUILD_DIR)/error.log
HW_BUILD_LIST  = $(HW_BUILD_DIR)/sources.lst
HW_BUILD_MODEL = $(DFSIM_MODEL_DIR)/$(DFSIM_TOP)

ifndef DFSIM_WAVE_DIR
  $(warning `DFSIM_WAVE_DIR` must be set to a writable directory for simulation artifacts.)
  DFSIM_WAVE_DIR = $(realpath ./wave)
  $(warning `DFSIM_WAVE_DIR` set to $(DFSIM_WAVE_DIR) by default.)
endif
WAVE_DIR  = $(DFSIM_WAVE_DIR)/$(shell date +%Y_%m_%d_%H%M%S)
WAVE_LINK = $(DFSIM_WAVE_DIR)/latest
WAVE_FILE = $(WAVE_DIR)/$(DFSIM_TOP).ghw
WAVE_LOG = $(WAVE_DIR)/$(DFSIM_TOP).log


#------------------------------------------------------------------------------
# Project-specific Variables
#------------------------------------------------------------------------------

SW_DIR  = $(realpath ./sw)
SW_SRCS = $(shell find $(SW_DIR) -name ".*" -prune -o -type f -name '*.cpp' -print)
SW_OBJS = $(SW_SRCS:$(SW_DIR)/%.cpp=$(SW_BUILD_DIR)/%.o)
SW_DEPS = $(SW_OBJS:.o=.d)

CXXFLAGS  += -std=c++17 -g -O0
GHDLFLAGS += -g --std=02


#------------------------------------------------------------------------------
# User Information
#------------------------------------------------------------------------------

.PHONY: usage
usage:
	@echo "Usage:"
	@echo " make usage     - Display this info panel"
	@echo " make info      - Display build variables"
	@echo " make swlib     - Build software testbench library"
	@echo " make model     - Build simulation model from hardware sources and software library"
	@echo " make sim       - Run simulation model and generate a trace"
	@echo " make clean     - Delete build artifacts, keep simulation traces"
	@echo " make clean-all - Delete build artifacts and simulation traces"
	@echo
	@echo "Environment:"
	@echo " DFSIM_TOP       - Name of toplevel entity"
	@echo " DFSIM_LIST      - File containing a list of hardware source files"
	@echo " DFSIM_MODEL_DIR - Writable directory for model build artifacts (optional, `./build` by default)"
	@echo " DFSIM_WAVE_DIR        - Writable directory for simulation artifacts (optional, `./wave` by default)"

.PHONY: info
info:
	@echo "Variables:"
	@echo " DFSIM_TOP          = $(DFSIM_TOP)"
	@echo " DFSIM_SCRIPT       = $(DFSIM_SCRIPT)"
	@echo " DFSIM_LIST         = $(DFSIM_LIST)"
	@echo
	@echo " DFSIM_MODEL_DIR    = $(DFSIM_MODEL_DIR)"
	@echo " SW_BUILD_DIR       = $(SW_BUILD_DIR)"
	@echo " SW_BUILD_LOG       = $(SW_BUILD_LOG)"
	@echo " SW_BUILD_ERR       = $(SW_BUILD_ERR)"
	@echo " SW_BUILD_LIB       = $(SW_BUILD_LIB)"
	@echo " HW_BUILD_DIR       = $(HW_BUILD_DIR)"
	@echo " HW_BUILD_LOG       = $(HW_BUILD_LOG)"
	@echo " HW_BUILD_ERR       = $(HW_BUILD_ERR)"
	@echo " HW_BUILD_LIST      = $(HW_BUILD_LIST)"
	@echo " HW_BUILD_MODEL     = $(HW_BUILD_MODEL)"
	@echo
	@echo " DFSIM_WAVE_DIR     = $(DFSIM_WAVE_DIR)"
	@echo " WAVE_DIR           = $(WAVE_DIR)"
	@echo " WAVE_LINK          = $(WAVE_LINK)"
	@echo " WAVE_FILE          = $(WAVE_FILE)"
	@echo
	@echo " SW_DIR             = $(SW_DIR)"
	@echo " SW_SRCS            = $(SW_SRCS)"
	@echo " SW_OBJS            = $(SW_OBJS)"
	@echo " SW_DEPS            = $(SW_DEPS)"
	@echo " CXXFLAGS           = $(CXXFLAGS)"
	@echo " GHDLFLAGS          = $(GHDLFLAGS)"


#------------------------------------------------------------------------------
# Software Testbench: Compile static library from C++ sources
#------------------------------------------------------------------------------

.PHONY: swlib
swlib:
	@mkdir -p $(SW_BUILD_DIR)
	@rm -f $(SW_BUILD_ERR)
	@echo | tee $(SW_BUILD_LOG)
	@echo "--- Building Software Library" | tee -a $(SW_BUILD_LOG)
	@$(MAKE) $(SW_BUILD_LIB) 2>&1 | tee -a $(SW_BUILD_LOG)

CMD_COMPILE = $(CXX) $(CXXFLAGS) -c $< -MMD -o $@
CMD_LIB = $(AR) rcs $@ $^

$(SW_BUILD_DIR)/%.o: $(SW_DIR)/%.cpp
	@mkdir -p $(@D)
	@echo $(CMD_COMPILE)
	@$(CMD_COMPILE) 2>$(SW_BUILD_ERR) || (echo "----- Errors, see $(SW_BUILD_ERR)"; exit 1)

$(SW_BUILD_LIB): $(SW_OBJS)
	@mkdir -p $(@D)
	@echo $(CMD_LIB)
	@$(CMD_LIB) 2> $(SW_BUILD_ERR) || (echo "----- Errors, see $(SW_BUILD_ERR)"; exit 1)

-include $(SW_DEPS)

#------------------------------------------------------------------------------
# Hardware Model: Build and link with ghdl
#------------------------------------------------------------------------------


.PHONY: model
model: swlib
	@mkdir -p $(HW_BUILD_DIR)
	@rm -f $(HW_BUILD_ERR)
	@echo | tee $(HW_BUILD_LOG)
	@echo "--- Building Hardware Model" | tee -a $(HW_BUILD_LOG)
	@$(MAKE) $(HW_BUILD_MODEL) 2>&1 | tee -a $(HW_BUILD_LOG)

CMD_REMOVE = ghdl remove --workdir=$(HW_BUILD_DIR)
CMD_IMPORT = ghdl import --workdir=$(HW_BUILD_DIR) $$HW_SRC
CMD_MAKE = ghdl make -Mu -b --workdir=$(HW_BUILD_DIR) $(GHDLFLAGS) -o $(HW_BUILD_MODEL) $(DFSIM_TOP)
CMD_LINK = ghdl link --LINK=$(CXX) --workdir=$(HW_BUILD_DIR) -Wl,$(SW_BUILD_LIB) -Wl,-llua $(GHDLFLAGS) -o $(HW_BUILD_MODEL) $(DFSIM_TOP)

$(HW_BUILD_MODEL): $(DFSIM_LIST)
	@mkdir -p $(HW_BUILD_DIR)
	@if [ "$(shell cat $(HW_BUILD_LIST) | sort | md5sum)" != \
	      "$(shell cat $(DFSIM_LIST) | sort | md5sum)" ]; then \
	  echo; \
	  echo "--- Updating hardware source library"; \
	  echo $(CMD_REMOVE); $(CMD_REMOVE); \
	  cat $(DFSIM_LIST) | while read HW_SRC; do \
	    echo $(CMD_IMPORT); \
	    $(CMD_IMPORT) 2>$(HW_BUILD_ERR) || (echo "----- Errors, see $(HW_BUILD_ERR)"; exit 1); \
	  done && cat $(DFSIM_LIST) > $(HW_BUILD_LIST) || exit 1; \
	else \
	  echo; \
	  echo "--- Keeping hardware source library"; \
	fi
	@echo
	@echo "--- Building hardware model for: $(DFSIM_TOP)"
	@echo $(CMD_MAKE)
	@$(CMD_MAKE) 2>$(HW_BUILD_ERR) || (echo "----- Errors, see $(HW_BUILD_ERR)"; exit 1)
	@echo
	@echo "--- Linking model for: $(DFSIM_TOP)"
	@echo $(CMD_LINK)
	@$(CMD_LINK) 2>$(HW_BUILD_ERR) || (echo "----- Errors, see $(HW_BUILD_ERR)"; exit 1)

#------------------------------------------------------------------------------
# Simulation: Execute model and store waveforms
#------------------------------------------------------------------------------

.PHONY: sim
sim: $(HW_BUILD_MODEL)
	@echo
	@echo "--- Simulating hardware model for: $(DFSIM_TOP)"
	@echo "----- Waveform at: $(WAVE_FILE)"
	@mkdir -p $(WAVE_DIR)
	@ln -sfrn $(WAVE_DIR) $(WAVE_LINK)
	@script -c "$(HW_BUILD_MODEL) --wave=$(WAVE_FILE) -gCFGSCRIPT=$(DFSIM_SCRIPT)" $(WAVE_LOG)

#TODO-lw add support for -gg_CfgDir=$(parent $(DFSIM_SCRIPT)) -gg_RunDir=$(WAVE_DIR)


#------------------------------------------------------------------------------
# Cleanup
#------------------------------------------------------------------------------

.PHONY: clean
clean:
ifdef SW_BUILD_DIR
	rm -rf $(SW_BUILD_DIR)
endif
ifdef HW_BUILD_DIR
	rm -rf $(HW_BUILD_DIR)
endif
ifdef HW_BUILD_MODEL
	rm -f  $(HW_BUILD_MODEL)
endif

.PHONY: clean-all
clean-all: clean
ifdef DFSIM_WAVE_DIR
	rm -rf $(DFSIM_WAVE_DIR)
endif

