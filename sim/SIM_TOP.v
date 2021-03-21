/////////////////////////////////////////////////////////////////////////////////
// BSD 3-Clause License
// 
// Copyright (c) 2020, Jose R. Garcia
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// 
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
// 
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
// 
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
/////////////////////////////////////////////////////////////////////////////////
// File name     : GID_TOP.v
// Author        : Jose R Garcia
// Created       : 2020/11/04 23:20:43
// Last modified : 2021/03/08 13:28:58
// Project Name  : MINER
// Module Name   : SIMs_TOP
// Description   : The SIM_TOP is a wrapper to include the missing signals
//                 required by the verification agents.
//
// Additional Comments:
//   
/////////////////////////////////////////////////////////////////////////////////
module SIM_TOP #(
  // Compile time configurable generic parameters
  parameter integer P_LOOP_LOG2        = 4, // Valid range: [0, 5]
  parameter integer P_SPI_MODE         = 0, // 0, 1, 2, 3
  parameter integer P_NONCE_SEED       = 0, //3938194598,
  parameter integer P_CDC_SYNCH_LEVELS = 2,
  parameter integer P_P2S_FIFO_DEPTH   = 16,
  parameter integer P_ANLOGIC_EG4      = 0  //
)(
  // Component's clocks and resets
  input i_clk,   // Main Clock
  input i_reset, // Synchronous Reset
  // SPI Interface
  input  i_spi_clk,  // 
  output o_spi_miso, // 
  input  i_spi_mosi, // 
  input  i_spi_ss,  // 
  // Stubs
  input  o_mo_en,
  input  o_sclk_en,
  input  o_ss_out,
  input  o_so,
  input  o_so_en,
  output i_si,
  output i_sclk_in,
  output i_ss_in,
  output i_in_clk,
  output i_ext_clk //
);
  ///////////////////////////////////////////////////////////////////////////////
  // Internal Parameter Declarations
  ///////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  // Internal Signals Declarations
  ///////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  //            ********      Architecture Declaration      ********           //
  ///////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : div
  // Description : Instance of a Goldschmidt Division implementation.
  ///////////////////////////////////////////////////////////////////////////////
  Miner_Top #( 
    .P_LOOP_LOG2(P_LOOP_LOG2),  // P_LOOP_LOG2
    .P_SPI_MODE(P_SPI_MODE),   // P_SPI_MODE
    .P_NONCE_SEED(P_NONCE_SEED),
    .P_P2S_FIFO_DEPTH(P_P2S_FIFO_DEPTH),
    .P_CDC_SYNCH_LEVELS(P_CDC_SYNCH_LEVELS),
    .P_ANLOGIC_EG4(P_ANLOGIC_EG4) //
  ) miner_top (
    //
    .i_system_clk(i_clk),  // 
    .i_system_reset(i_reset), //
    // SPI Interface
    .i_spi_clk(i_spi_clk),  //
    .o_spi_miso(o_spi_miso), //
    .i_spi_mosi(i_spi_mosi), //
    .i_spi_ss(i_spi_ss)    // 
  );

endmodule
