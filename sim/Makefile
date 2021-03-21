NPROCS = 1
OS := $(shell uname -s)
ifeq ($(OS),Linux)
  NPROCS := $(shell grep -c ^processor /proc/cpuinfo)
else ifeq ($(OS),Darwin)
  NPROCS := $(shell system_profiler | awk '/Number of CPUs/ {print $$4}{next;}')
endif # $(OS)
THREADS := $(NPROCS)

SIM = verilator
TOPLEVEL_LANG = verilog
EXTRA_ARGS += --trace --trace-structs --default-language 1364-2005 --threads $(THREADS)
VERILOG_SOURCES = $(shell pwd)/../src/Generic_BRAM.v ../src/Sync_FIFO.v ../src/Sync_FIFO_WB.v ../src/Serial_To_Parallel_Bytes.v ../src/Parallel_To_Serial_Bytes.v ../src/SPI_Slave.v ../src/SHA256_Functions.v ../src/SHA256_Digester.v ../src/SHA256_Transform.v ../src/Miner.v ../src/Miner_Top.v ./SIM_TOP.v

PLUSARGS=+UVM_VERBOSITY=UVM_LOW +UVM_NO_RELNOTES
ifneq ($(UVM_TEST),)
  PLUSARGS += +UVM_TESTNAME=$(UVM_TEST)
else
  PLUSARGS += +UVM_TESTNAME=spi_test
endif

TOPLEVEL := SIM_TOP
MODULE   ?= top

include $(shell cocotb-config --makefiles)/Makefile.sim
