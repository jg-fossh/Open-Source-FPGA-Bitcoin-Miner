import random
import cocotb
import sys
# insert at 1, 0 is the script path (or '' in REPL)
sys.path.append('externals/SPI_Slave/')
from cocotb.triggers import Timer
from cocotb.clock import Clock
from uvm.base import run_test, UVMDebug
from uvm.base.uvm_phase import UVMPhase
from uvm.seq import UVMSequence
from externals.SPI_Slave.spi_if import *
from tb_env_config import *
from tb_env import *
from test_lib import *

async def initial_run_test(dut, vif_spi):
    from uvm.base import UVMCoreService
    cs_ = UVMCoreService.get()
    UVMConfigDb.set(None, "*", "vif_spi", vif_spi)
    # await run_test("reg_test")
    await run_test()


async def initial_reset(vif_spi, dut):
    await Timer(0, "ns")
    vif_spi.i_reset <= 1
    await Timer(52, "ns") 
    vif_spi.i_reset <= 0
    cocotb.fork(initial_run_test(dut, vif_spi))


@cocotb.test()
async def top(dut):
    """ Miner Top Test Bench """

    # Map the signals in the DUT to the verification agents interfaces
    
    bus_map = {"i_clk": "i_clk", 
               "i_reset": "i_reset",
               "i_si": "i_si", 
               "i_sclk_in": "i_sclk_in",
               "i_ss_in": "i_ss_in", 
               "i_in_clk": "i_in_clk",
               "o_so_en": "o_so_en",
               "o_so": "o_so",
               "i_mi": "o_spi_miso",
               "i_ext_clk": "i_ext_clk",
               "o_ss_en": "i_spi_ss",
               "o_ss_out": "o_ss_out",
               "o_sclk_en": "o_sclk_en",
               "o_sclk_out": "i_spi_clk",
               "o_mo_en": "o_mo_en",
               "o_mo": "i_spi_mosi"}
 
    vif_spi = spi_if(dut, bus_map)

    # Create a 75MHz clock
    clock = Clock(dut.i_clk, 13.33, units="ns") 
    cocotb.fork(clock.start())  # Start the clock
    # 18 MHz clock
    spi_clock = Clock(dut.i_spi_clk, 55.56, units="ns") 
    cocotb.fork(spi_clock.start())  # Start the clock
    
    cocotb.fork(initial_reset(vif_spi, dut))

    await Timer(80, "us")
