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
// File name     : Parallel_To_Serial_Bytes.v
// Author        : Jose R Garcia
// Created       : 2020/12/06 00:33:28
// Last modified : 2021/03/05 17:22:35
// Project Name  : 
// Module Name   : Parallel_To_Serial_Bytes
// Description   : The Parallel_To_Serial_Bytes takes a byte of data and accumulates until
//                 
//
// Additional Comments:
//   .
/////////////////////////////////////////////////////////////////////////////////
module Parallel_To_Serial_Bytes #( 
  parameter integer P_DATA_IN_MSB = 7, //
  parameter integer P_FIFO_DEPTH  = 2,
  parameter integer P_ANLOGIC_EG4 = 0  //
)(
  input i_clk,   // 
  input i_reset, // 
  // Wishbone(Standard) Write Slave Interface
  input                   i_slave_write_stb,  // WB write enable
  input [P_DATA_IN_MSB:0] i_slave_write_data, // WB data
  output                  o_slave_write_ack,  // WB acknowledge
  // Wishbone (Standard) Write Master Interface
  output       o_master_write_stb,  // WB write enable
  output [7:0] o_master_write_data, // WB data
  input        i_master_write_ack   // WB acknowledge
);

  ///////////////////////////////////////////////////////////////////////////////
  // Internal Parameter Declarations
  ///////////////////////////////////////////////////////////////////////////////
  localparam integer L_NUM_BYTES = (P_DATA_IN_MSB+1)/8 ;
  localparam integer L_INDEX_MSB = $clog2(L_NUM_BYTES)-1;
  ///////////////////////////////////////////////////////////////////////////////
  // Internal Signals Declarations
  ///////////////////////////////////////////////////////////////////////////////
  // WB Slave Process
  reg r_fifo_ack;
  // Data Buffer Process
  reg  [7:0]           r_data;
  reg  [L_INDEX_MSB:0] r_data_index;
  // WB Slave Process
  reg r_write_stb;
  // FIFO
  wire                   w_fifo_stb;
  wire                   w_fifo_ack;
  wire [P_DATA_IN_MSB:0] w_fifo_data;
  // 
  wire w_ready    = (i_master_write_ack==1'b1 || r_write_stb==1'b0) ? 1'b1 : 1'b0;
  
  ///////////////////////////////////////////////////////////////////////////////
  //            ********      Architecture Declaration      ********           //
  ///////////////////////////////////////////////////////////////////////////////
  
  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : Wishbone Write Slave Process
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  Sync_FIFO_WB #(
    P_DATA_IN_MSB, // P_SYNC_FIFO_WB_DATA_MSB
    P_FIFO_DEPTH,  // P_SYNC_FIFO_WB_DEPTH
    1,             // P_SYNC_FIFO_WB_FLOW_CTRL
    P_ANLOGIC_EG4  // P_SYNC_FIFO_WB_TECHNOLOGY
  ) p2b_fifo (
    .i_clk(i_clk),          // clock
    .i_reset_sync(i_reset), // synchronous reset
    // Wishbone (Standard) Slave Input Interface
    .i_slave_fifo_write_stb(i_slave_write_stb),   // WB write enable
    .o_slave_fifo_write_ack(o_slave_write_ack),   // WB acknowledge 
    .i_slave_fifo_write_data(i_slave_write_data), // WB data
    // Wishbone (Standard) Master Output Interface
    .o_master_fifo_write_stb(w_fifo_stb),  // WB read strobe
    .i_master_fifo_write_ack(r_fifo_ack),  // WB read acknowledge
    .o_master_fifo_write_data(w_fifo_data) // WB read data
  );

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Wishbone Write Slave Process
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
    if (i_reset == 1'b1) begin
      r_fifo_ack   <= 1'b0;
      r_data_index <= 'h0;
    end
    else if (r_data_index == 'h0 && r_write_stb == 1'b0) begin
      // Waiting for new data word.
      if (w_fifo_stb == 1'b1 && w_ready == 1'b1) begin
        // 
        r_write_stb <= 1'b1;
      end
      // Do not acknowledge until the whole word is consumed 
      r_fifo_ack <= 1'b0;
    end
    else if (w_ready == 1'b1) begin
      if (r_data_index == L_NUM_BYTES) begin
        //
        r_fifo_ack   <= 1'b1;
        r_write_stb  <= 1'b0;
        r_data_index <= 'h0;
      end
      else begin
        //
        r_data_index <= r_data_index + 1;
      end
    end
  end

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Data Mux
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  always @(r_data_index, w_fifo_data) begin
    case (r_data_index)
      2'h0 : begin
        r_data = w_fifo_data[7:0];
      end
      2'h1 : begin
        r_data = w_fifo_data[15:8];
      end
      2'h2 : begin
        r_data = w_fifo_data[23:16];
      end
      2'h3 : begin
        r_data = w_fifo_data[31:24];
      end
      default: begin
        r_data = w_fifo_data[7:0];
      end
    endcase
  end
  //
  assign o_master_write_stb  = r_write_stb;
  assign o_master_write_data = r_data;

endmodule
