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
// File name     : Sync_FIFO_WB.v
// Author        : Jose R Garcia
// Created       : 2021/01/11 21:51:08
// Last modified : 2021/02/28 00:36:01
// Project Name  : FIFO
// Module Name   : Sync_FIFO_WB
// Description   : Single Clock FIFO, Wishbone Interface
//
// Additional Comments:
//   Uses BRAMs as the storage elements.
/////////////////////////////////////////////////////////////////////////////////
module Sync_FIFO_WB #(
  parameter integer P_SYNC_FIFO_WB_DATA_MSB   = 0, //
  parameter integer P_SYNC_FIFO_WB_DEPTH      = 0, //
  parameter integer P_SYNC_FIFO_WB_FLOW_CTRL  = 0, // 0=Allow overflow and underflow, 1=Don't allow
  parameter integer P_SYNC_FIFO_WB_TECHNOLOGY = 0  // 0=generic, 1=Anlogic_EG4
)(
  input i_clk,        // clock
  input i_reset_sync, // synchronous reset
  // Wishbone (Standard) Slave Input Interface
  input                              i_slave_fifo_write_stb,  // WB write enable
  output                             o_slave_fifo_write_ack,  // WB acknowledge
  input  [P_SYNC_FIFO_WB_DATA_MSB:0] i_slave_fifo_write_data, // WB data
  // Wishbone (Standard) Master Output Interface
  output                             o_master_fifo_write_stb,  // WB read strobe
  input                              i_master_fifo_write_ack,  // WB read acknowledge
  output [P_SYNC_FIFO_WB_DATA_MSB:0] o_master_fifo_write_data  // WB read data
);

  ///////////////////////////////////////////////////////////////////////////////
  // Local Parameter Declarations
  ///////////////////////////////////////////////////////////////////////////////
  localparam integer L_ADDR_MSB = $clog2(P_SYNC_FIFO_WB_DEPTH)-1;
  ///////////////////////////////////////////////////////////////////////////////
  // Signals Declarations
  ///////////////////////////////////////////////////////////////////////////////
  // WB Slave Write Input Handshake Process
  reg  r_write_ack;
  wire w_full;
  wire w_write = P_SYNC_FIFO_WB_FLOW_CTRL==0 ? (
                   (i_slave_fifo_write_stb==1'b1 && r_write_ack==1'b0) ? 1'b1 : 1'b0) : (
                   (i_slave_fifo_write_stb== 1'b1 && r_write_ack==1'b0 && w_full==1'b0) ? 1'b1 : 1'b0);
  // WB Master Write Output Handshake Process
  reg  r_master_stb;
  reg  r_wait_ack;
  wire w_empty;
  wire w_read = (r_master_stb== 1'b0 && w_empty==1'b0) ? 1'b1 : 1'b0;

  ///////////////////////////////////////////////////////////////////////////////
  //           ********      Architecture Declaration      ********            //
  ///////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : WB Slave Write Standard Handshake
  // Description : Wishbone standard handshake controls. STALL not supported
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
  	if (i_reset_sync == 1'b1) begin
  		r_write_ack <= 1'b0;
  	end
  	else if (i_slave_fifo_write_stb == 1'b1 && r_write_ack == 1'b0) begin
  		r_write_ack <= 1'b1;
    end
    else begin
  		r_write_ack <= 1'b0;
  	end
  end
  assign o_slave_fifo_write_ack = r_write_ack;

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : WB Master Write Standard Handshake
  // Description : Wishbone standard handshake controls.
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
  	if (i_reset_sync == 1'b1) begin
  		r_master_stb <= 1'b0;
  	end
  	else if (w_empty == 1'b0 && i_master_fifo_write_ack == 1'b0) begin
  		r_master_stb <= 1'b1;
    end
    else if(i_master_fifo_write_ack == 1'b1) begin
  		r_master_stb <= 1'b0;
  	end
  end

  //
  assign o_master_fifo_write_stb = r_master_stb;

  generate
    if (P_SYNC_FIFO_WB_TECHNOLOGY == 0) begin
      ///////////////////////////////////////////////////////////////////////////////
      // Instance    : data_fifo
      // Description :
      ///////////////////////////////////////////////////////////////////////////////
      Sync_FIFO #(
        P_SYNC_FIFO_WB_DATA_MSB, // P_BRAM_DATA_MSB
        L_ADDR_MSB               // P_BRAM_ADDRESS_MSB
      ) data_fifo (
        .i_clk(i_clk),
        .i_reset_sync(i_reset_sync),
        .i_fifo_read(w_read),                        // Read strobe
        .o_fifo_read_data(o_master_fifo_write_data), // Read data
        .o_fifo_empty(w_empty),                      // Read empty
        .i_fifo_write(w_write),                      // WB write enable
        .i_fifo_write_data(i_slave_fifo_write_data), // WB data
        .o_fifo_full(w_full)                         // WB acknowledge
      );
    end
  endgenerate

  generate
    if (P_SYNC_FIFO_WB_TECHNOLOGY == 1) begin
      ///////////////////////////////////////////////////////////////////////////////
      // Instance    : data_fifo
      // Description :
      ///////////////////////////////////////////////////////////////////////////////
      EG_LOGIC_RAMFIFO #(
       	.DATA_WIDTH(P_SYNC_FIFO_WB_DATA_MSB+1),
      	.ADDR_WIDTH(L_ADDR_MSB+1),
      	.SHOWAHEAD(1),
        .IMPLEMENT("AUTO")
      ) data_ramfifo (
      	.rst(i_reset_sync),
      	.di(i_slave_fifo_write_data),
      	.clk(i_clk),
      	.we(w_write),
      	.do(o_master_fifo_write_data),
      	.re(w_read),
      	.empty_flag(w_empty),
      	.full_flag(w_full),
      	.rdusedw(),
      	.wrusedw()
      );
    end
  endgenerate

endmodule
