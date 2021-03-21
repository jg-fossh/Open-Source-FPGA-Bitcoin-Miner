/////////////////////////////////////////////////////////////////////////////////
// BSD 3-Clause License
// 
// Copyright (c) 2021, Jose R. Garcia
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
// File name     : Sync_FIFO.v
// Author        : Jose R Garcia
// Created       : 2021/01/11 21:51:08
// Last modified : 2021/02/27 12:14:00
// Project Name  : FIFO
// Module Name   : Sync_FIFO
// Description   : Single Clock FIFO, Generic.
//
// Additional Comments:
//   Uses BRAMs as the storage elements.
/////////////////////////////////////////////////////////////////////////////////
module Sync_FIFO #(
  parameter integer P_SYNC_FIFO_DATA_MSB = 0, //
  parameter integer P_SYNC_FIFO_DEPTH    = 0  // 
)(
  input i_clk,        // clock
  input i_reset_sync, // synchronous reset
  // Wishbone (Standard) Master Read Interface
  input                           i_fifo_read,      // Read strobe
  output [P_SYNC_FIFO_DATA_MSB:0] o_fifo_read_data, // Read data
  output                          o_fifo_empty,     // Read empty
  // Wishbone (Standard) Master Write Interface
  input                           i_fifo_write,      // WB write enable 
  input  [P_SYNC_FIFO_DATA_MSB:0] i_fifo_write_data, // WB data
  output                          o_fifo_full        // WB acknowledge
);

  ///////////////////////////////////////////////////////////////////////////////
  // Local Parameter Declarations
  ///////////////////////////////////////////////////////////////////////////////
  localparam integer L_FIFO_INDEX_MSB = $clog2(P_SYNC_FIFO_DEPTH)-1;

  ///////////////////////////////////////////////////////////////////////////////
  // Signals Declarations
  ///////////////////////////////////////////////////////////////////////////////
  // Read Index Process Signals
  reg [L_FIFO_INDEX_MSB:0] r_read_index;
  // Write Index Process Signals
  reg [L_FIFO_INDEX_MSB:0] r_write_index;
  wire                     w_full = r_write_index==P_SYNC_FIFO_DEPTH ? 1'b1 : 1'b0;

  ///////////////////////////////////////////////////////////////////////////////
  //           ********      Architecture Declaration      ********            //
  ///////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Read Index Process
  // Description : TBD.
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
  	if (i_reset_sync == 1'b1) begin
  		r_read_index  <= 0;
  	end
  	else if (i_fifo_read == 1'b1) begin
      if (r_read_index == (r_write_index-1)) begin
        // Indices caught up with each other.
  			r_read_index <= 0;
  		end
      else begin
        // Increment read index
  			r_read_index <= (r_read_index+1);
      end
  	end
  end

  assign o_fifo_empty = r_write_index==0 ? 1'b1 : 1'b0;
  
  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Write Index Process Signals
  // Description : TBD.
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
  	if (i_reset_sync == 1'b1) begin
  		r_write_index <= 0;
  	end
  	else if (i_fifo_write == 1'b1) begin
      if (r_read_index == (r_write_index-1)) begin
        // Indices caught up with each other. Reset index.
  			r_write_index <= 0;
      end
      else begin
        // Increment write index
  			r_write_index <= (r_write_index+1);
  		end
  	end
  end
  assign o_fifo_full = r_write_index==P_SYNC_FIFO_DEPTH ? 1'b1 : 1'b0;

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : data_fifo
  // Description : 
  ///////////////////////////////////////////////////////////////////////////////
  Generic_BRAM #(
    P_SYNC_FIFO_DATA_MSB, // P_BRAM_DATA_MSB
    L_FIFO_INDEX_MSB,     // P_BRAM_ADDRESS_MSB
    P_SYNC_FIFO_DEPTH,    // P_BRAM_DEPTH
    0,                    // P_BRAM_HAS_FILE
    0                     // P_BRAM_INIT_FILE
  ) fifo_bram (
    .i_wclk(i_clk),
    .i_we(i_fifo_write),
    .i_rclk(i_clk),
    .i_waddr(r_write_index),
    .i_raddr(r_read_index),
    .i_wdata(i_fifo_write_data),
    .o_rdata(o_fifo_read_data)
  );

endmodule
