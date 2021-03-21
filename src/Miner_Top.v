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
// File name     : Miner_Top.v
// Author        : Jose R Garcia
// Created       : 2020/12/06 00:33:28
// Last modified : 2021/03/08 21:47:29
// Project Name  : 
// Module Name   : Miner_Top
// Description   : The Miner_Top is the top level wrapper. It stitches together
//                 the miner, the algorithm specific modules and the 
//                 communication interfaces.
//
// Additional Comments:
//   
/////////////////////////////////////////////////////////////////////////////////
module Miner_Top #( 
  parameter integer P_LOOP_LOG2        = 4, // Valid range: [4, 5]
  parameter integer P_SPI_MODE         = 0, // SPI clock polarity and phase mode.
  parameter integer P_NONCE_SEED       = 0, //
  parameter integer P_CDC_SYNCH_LEVELS = 3,
  parameter integer P_P2S_FIFO_DEPTH   = 2, //
  parameter integer P_ANLOGIC_EG4      = 0  //
)(
  //
  input i_system_clk,   // 
  input i_system_reset, // 
  // SPI Interface
  input  i_spi_clk,  //
  output o_spi_miso, //
  input  i_spi_mosi, //
  input  i_spi_ss,    // 

  output o_waiting //
);

  ///////////////////////////////////////////////////////////////////////////////
  // Internal Parameter Declarations
  ///////////////////////////////////////////////////////////////////////////////
  localparam integer L_DATA_OUT_MSB = 256+96-1; // midstate + data - 1 
  localparam integer L_NONCE_MSB    = 31;       // nonce most significant bit

  ///////////////////////////////////////////////////////////////////////////////
  // Internal Signals Declarations
  ///////////////////////////////////////////////////////////////////////////////
  // SPI WB Master
  wire       w_spi_write_stb;
  wire [7:0] w_spi_write_data;
  wire       w_spi_write_ack;
  // Serial_To_Parallel_Bytes WB Master 
  wire                    w_bytes2words_stb;
  wire [L_DATA_OUT_MSB:0] w_bytes2words_data;
  wire                    w_bytes2words_ack = 1'b1;
  // miner_sha256 Wishbone Master
  wire                 w_miner_stb;
  wire [L_NONCE_MSB:0] w_miner_data;
  wire                 w_miner_ack;
  // Parallel_To_Serial_Bytes WB Master
  //wire       w_words2bytes_cyc;
  wire       w_words2bytes_stb;
  wire [7:0] w_words2bytes_data;
  wire       w_words2bytes_ack;

  ///////////////////////////////////////////////////////////////////////////////
  //            ********      Architecture Declaration      ********           //
  ///////////////////////////////////////////////////////////////////////////////
  
  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : spi_slave
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  SPI_Slave #( 
    .P_SPI_MODE(P_SPI_MODE), // P_SPI_MODE
    .P_CDC_SYNCH_LEVELS(P_CDC_SYNCH_LEVELS)
  ) spi_slave (
    // SPI Interface
    .i_spi_clk(i_spi_clk),
    .o_spi_miso(o_spi_miso),
    .i_spi_mosi(i_spi_mosi),
    .i_spi_ss(i_spi_ss),
    // Control/Data Signals,
    .i_clk(i_system_clk),     // FPGA Clock
    .i_reset(i_system_reset), // FPGA Reset
    // Wishbone (Standard) Write Master Interface
    .o_master_write_stb(w_spi_write_stb),   // Data Valid pulse (1 clock cycle)
    .o_master_write_data(w_spi_write_data), // Byte received on MOSI
    .i_master_write_ack(w_spi_write_ack),   // 
    // Wishbone(Standard) Write Slave Interface
    .i_slave_write_stb(w_words2bytes_stb),   // WB write enable
    .i_slave_write_data(w_words2bytes_data), // Byte to serialize to MISO.
    .o_slave_write_ack(w_words2bytes_ack)    // WB acknowledge
  );

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : bytes2words
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  Serial_To_Parallel_Bytes #( 
    .P_DATA_OUT_MSB(L_DATA_OUT_MSB) // P_DATA_OUT_MSB
  ) bytes2words(
    .i_clk(i_system_clk),     // 
    .i_reset(i_system_reset), // 
    // Wishbone(Standard) Write Slave Interface
    .i_slave_write_stb(w_spi_write_stb),   // WB write enable
    .i_slave_write_data(w_spi_write_data), // WB data
    .o_slave_write_ack(w_spi_write_ack), // WB acknowledge 
    // Wishbone (Standard) Write Master Interface
    .o_master_write_stb(w_bytes2words_stb),   // WB write enable
    .o_master_write_data(w_bytes2words_data), // WB data
    .i_master_write_ack(w_bytes2words_ack)    // WB acknowledge
  );

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : miner_sha256_0
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  Miner #(
    .P_LOOP_LOG2(P_LOOP_LOG2),            // P_LOOP_LOG2
    .P_MINER_DATA_IN_MSB(L_DATA_OUT_MSB), // P_DATA_IN_MSB
    .P_NONCE_MSB(L_NONCE_MSB),            // P_NONCE_MSB
    .P_NONCE_SEED(P_NONCE_SEED),
    .P_ANLOGIC_EG4(P_ANLOGIC_EG4)
  ) miner_sha256 (
    //
    .i_clk(i_system_clk),
    .i_reset(i_system_reset),
    // Wishbone(Standard) Write Slave Interface
    .i_slave_write_stb(w_bytes2words_stb),   // WB write enable
    .i_slave_write_data(w_bytes2words_data), // WB data
    // Wishbone (Standard) Write Master Interface
    .o_master_write_stb(w_miner_stb),   // WB write enable
    .o_master_write_data(w_miner_data), // WB data
    .i_master_write_ack(w_miner_ack),    // WB acknowledge
    //
    .o_waiting(o_waiting)
  );

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : words2bytes
  // Description : Takes data words and outputs a .
  ///////////////////////////////////////////////////////////////////////////////
  Parallel_To_Serial_Bytes #( 
    .P_DATA_IN_MSB(L_NONCE_MSB),  // P_DATA_IN_MSB
    .P_FIFO_DEPTH(P_P2S_FIFO_DEPTH),
    .P_ANLOGIC_EG4(P_ANLOGIC_EG4) // P_ANLOGIC_EG4
  ) words2bytes (
    .i_clk(i_system_clk),     // 
    .i_reset(i_system_reset), // 
    // Wishbone(Standard) Write Slave Interface
    .i_slave_write_stb(w_miner_stb),   // WB write enable
    .i_slave_write_data(w_miner_data), // WB data
    .o_slave_write_ack(w_miner_ack),   // WB acknowledge
    // Wishbone (Standard) Write Master Interface
    //.o_master_write_cyc(),                    // WB cycle
    .o_master_write_stb(w_words2bytes_stb),   // WB write strobe
    .o_master_write_data(w_words2bytes_data), // WB data
    .i_master_write_ack(w_words2bytes_ack)    // WB acknowledge
  );

endmodule
