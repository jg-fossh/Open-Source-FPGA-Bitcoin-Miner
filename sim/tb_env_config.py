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
# File name     : tb_env_config.py
# Author        : Jose R Garcia
# Created       : 2020/11/05 20:08:35
# Last modified : 2021/02/24 23:46:02
# Project Name  : UVM Python Verification Library
# Module Name   : tb_env_config
# Description   : Test Bench Configurations
#
# Additional Comments:
#
#################################################################################
import cocotb
from cocotb.triggers import *
from uvm import *
from externals.SPI_Slave.spi_if import *
from externals.SPI_Slave.spi_config import *

class tb_env_config(UVMObject):
    """         
       Class: Test Bench Environment Configuration
        
       Definition: Contains .
    """

    def __init__(self, name="tb_env_config"):
        super().__init__(name)
        """
           Function: new
          
           Definition: Test environment configuration object.

           Args:
             name: This agents name.
             parent: NONE
        """
        self.spi_cfg = None # spi_config.type_id.create("spi_cfg", self)

        self.has_scoreboard = False           # scoreboard on/off
        self.has_predictor  = False           # predictor on/off
        self.has_functional_coverage = False  # predictor on/off
        self.tag = "tb_env_config"


uvm_component_utils(tb_env_config)
