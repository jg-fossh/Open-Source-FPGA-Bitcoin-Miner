#################################################################################
# BSD 3-Clause License
# 
# Copyright (c) 2020, Jose R. Garcia
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#################################################################################
# File name     : test_lib.py
# Author        : Jose R Garcia
# Created       : 2020/11/05 19:26:21
# Last modified : 2021/03/08 12:50:36
# Project Name  : FPGA_MINER
# Module Name   : test_lib
# Description   : 
#
# Additional Comments:
#   Contains the test base and tests.
#################################################################################
import hashlib
import struct
import binascii
from binascii import unhexlify, hexlify

import cocotb
from cocotb.triggers import Timer

from uvm import *
from externals.SPI_Slave.spi_if import *
from externals.SPI_Slave.spi_transfer import *
from externals.SPI_Slave.spi_seq_lib import *
from externals.SPI_Slave.spi_config import *
from externals.SPI_Slave.spi_agent import *
from tb_env_config import *
from tb_env import *
from predictor import *

class test_base(UVMTest):
    """         
       Class: Test Base
        
       Definition: Contains functions, tasks and methods inherited
                   by all tests. (Items common to all tests)
    """

    def __init__(self, name="test_base", parent=None):
        super().__init__(name, parent)
        self.test_pass     = True
        self.tb_env        = None
        self.tb_env_config = None
        self.spi_cfg       = None
        self.printer       = None

    def build_phase(self, phase):
        super().build_phase(phase)
        # Enable transaction recording for everything
        UVMConfigDb.set(self, "*", "recording_detail", UVM_FULL)
        # create this test test bench environment config
        #self.tb_env_config = tb_env_config.type_id.create("tb_env_config", self)
        self.tb_env_config = tb_env_config("tb_env_config")
        self.tb_env_config.has_scoreboard          = False
        self.tb_env_config.has_predictor           = False
        self.tb_env_config.has_functional_coverage = False
        # Create the instruction agent
        #self.spi_cfg = spi_config.type_id.create("spi_cfg", self)
        self.spi_cfg = spi_config("spi_cfg")
        arr = []
        # Get the instruction interface created at top
        if UVMConfigDb.get(None, "*", "vif_spi", arr) is True:
            UVMConfigDb.set(self, "*", "vif_spi", arr[0])
            # Make this agent's interface the interface connected at top
            self.spi_cfg.vif        = arr[0]
            self.spi_cfg.is_active  = 1
        else:
            uvm_fatal("NOVIF", "Could not get vif_spi from config DB")

        # Make this instruction agent the test bench config agent
        self.tb_env_config.spi_cfg = self.spi_cfg
        UVMConfigDb.set(self, "*", "tb_env_config", self.tb_env_config)

        # Create the test bench environment 
        self.tb_env = tb_env.type_id.create("tb_env", self)

        # Create a specific depth printer for printing the created topology
        self.printer = UVMTablePrinter()
        self.printer.knobs.depth = 4


    def end_of_elaboration_phase(self, phase):
        # Print topology
        uvm_info(self.get_type_name(),
            sv.sformatf("Printing the test topology :\n%s", self.sprint(self.printer)), UVM_LOW)


    def report_phase(self, phase):
        if self.test_pass:
            uvm_info(self.get_type_name(), "** UVM TEST PASSED **", UVM_NONE)
        else:
            uvm_fatal(self.get_type_name(), "** UVM TEST FAIL **\n" +
                self.err_msg)


uvm_component_utils(test_base)


class spi_test(test_base):
    """         
       Class: SPI Test
        
       Description: Sends 32-bits of data repeatedly until the end
                    of the simulation 
    """

    def __init__(self, name="spi_test", parent=None):
        super().__init__(name, parent)
        self.hex_payload = []
        self.count       = 32 # amount of bits


    async def run_phase(self, phase):
        cocotb.fork(self.send_payload())

    
    async def send_payload(self):
        #
        spi_sqr = self.tb_env.spi_agent.sqr
        #
        self.hex_payload = 0x000000FF
        #  Create seq0
        spi_seq0               = spi_incr_payload("spi_seq0")
        spi_seq0.payload       = self.hex_payload
        spi_seq0.payload_width = self.count

        while True:
            await spi_seq0.start(spi_sqr)
            #
            self.hex_payload       = self.hex_payload + 1
            spi_seq0               = spi_incr_payload("spi_seq0")
            spi_seq0.payload       = self.hex_payload
            spi_seq0.payload_width = self.count


uvm_component_utils(spi_test)


class miner_test(test_base):
    """         
       Class: Miner Test
        
       Description: Sends a single minable payload 
    """

    def __init__(self, name="miner_test", parent=None):
        super().__init__(name, parent)
        self.hex_payload = []
        self.count       = 352 # amount of bits


    async def run_phase(self, phase):
        cocotb.fork(self.send_payload())

    
    async def send_payload(self):
        #
        spi_sqr = self.tb_env.spi_agent.sqr
        #
        # Midstate : (SHA state to begin with)
        #   256'hdc6a3b8d0c69421acb1a5434e536f7d5c3c1b9e44cbb9b8f95f0172efc48d2df
        # Data : (Meassage header items)
        #   96'hdc141787358b0553535f0119
        # Difficulty :
        #   8'h01
        # test_vector = 0xdc141787358b0553535f0119dc6a3b8d0c69421acb1a5434e536f7d5c3c1b9e44cbb9b8f95f0172efc48d2df

        #ver = 2
        #prev_block = "000000000000000117c80378b8da0e33559b5997f2ad55e2f7d18ec1975b9717"
        #mrkl_root = "871714dcbae6c8193a2bb9b2a69fe1c0440399f38d94b3a0f1b447275a29978a"
        #time_ = 0x53058b35 # 2014-02-20 04:57:25
        #bits = 0x19015f53
        #
        #header = ( struct.pack("<L", ver) + (binascii.unhexlify(prev_block)[::-1]) +
        #      binascii.unhexlify(mrkl_root)[::-1] + struct.pack("<LLL", time_, bits))
        #
        #midstate = hashlib.sha256(hashlib.sha256(header).digest()).digest()
        #
        #hexlify(header).decode("utf-8")
        #hexlify(header[::-1]).decode("utf-8")
        #header=hexlify(header[::-1]).decode("utf-8") 
        #
        #hexlify(midstate).decode("utf-8")
        #hexlify(midstate[::-1]).decode("utf-8")
        #midstate=hexlify(midstate[::-1]).decode("utf-8") 
    

        # getwork response:
        # {"id": "1", 
        #   "result": {
        #     "hash1": "00000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000010000", 
        #     "data": "00000001 c570c4764aadb3f09895619f549000b8b51a789e7f58ea750000709700000000 103ca064f8c76c390683f8203043e91466a7fcc40e6ebc428fbcc2d8 9b574a86 4db8345b 1b00b5ac 0000000000000080000000000000000000000000000000000000000000000000000000000000000000000 0000000000080020000", 
        #     "midstate": "e772fc6964e7b06d8f855a6166353e48b2562de4ad037abc889294cea8ed1070", 
        #     "target": "ffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000"
        #   }, 
        #  "error": null}
        # https://www.blockchain.com/btc/block/00000000000070977f58ea75b51a789e549000b89895619f4aadb3f0c570c476
        # https://www.blockchain.com/btc/block/120514
        # uvm_info("Miner Test", sv.sformatf("\n    MIDSTATE :  %d\n", midstate), UVM_LOW)

        # self.hex_payload = int('{:0352b}'.format(test_vector)[::-1], 2)
        self.hex_payload = 0x1b00b5ac4db8345b9b574a86a8ed1070889294cead037abcb2562de466353e488f855a6164e7b06de772fc69    
        # self.hex_payload = 0x9b574a864db8345b1b00b5aca8ed1070889294cead037abcb2562de466353e488f855a6164e7b06de772fc69  
        # self.hex_payload = 0xe772fc6964e7b06d8f855a6166353e48b2562de4ad037abc889294cea8ed10709b574a864db8345b1b00b5ac
        #  Create seq0
        spi_seq0               = spi_incr_payload("spi_seq0")
        spi_seq0.payload       = self.hex_payload
        spi_seq0.payload_width = self.count
        # Send the sequence
        await spi_seq0.start(spi_sqr)


uvm_component_utils(miner_test)
