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
// File name     : Serial_To_Parallel_Bytes.v
// Author        : Jose R Garcia
// Created       : 2020/12/06 00:33:28
// Last modified : 2021/03/02 09:23:44
// Project Name  : 
// Module Name   : Serial_To_Parallel_Bytes
// Description   : The Serial_To_Parallel_Bytes takes a byte of data and accumulates until
//                 
//
// Additional Comments:
//   .
/////////////////////////////////////////////////////////////////////////////////
module Serial_To_Parallel_Bytes #( 
  parameter integer P_DATA_OUT_MSB = 7 //
)(
  input i_clk,   // 
  input i_reset, // 
  // Wishbone(Standard) Write Slave Interface
  input       i_slave_write_stb,  // WB write enable
  input [7:0] i_slave_write_data, // WB data
  output      o_slave_write_ack,  // WB acknowledge
  // Wishbone (Standard) Write Master Interface
  output                    o_master_write_stb,  // WB write enable
  output [P_DATA_OUT_MSB:0] o_master_write_data, // WB data
  input                     i_master_write_ack   // WB acknowledge
);

  ///////////////////////////////////////////////////////////////////////////////
  // Internal Parameter Declarations
  ///////////////////////////////////////////////////////////////////////////////
  localparam integer L_NUM_BYTES = (P_DATA_OUT_MSB+1)/8 ;
  localparam integer L_INDEX_MSB = $clog2(L_NUM_BYTES)-1;
  ///////////////////////////////////////////////////////////////////////////////
  // Internal Signals Declarations
  ///////////////////////////////////////////////////////////////////////////////
  // WB Slave Process
  reg r_slave_ack;
  // Data Buffer Process
  reg  [7:0]           r_data [0:L_NUM_BYTES-1];
  reg  [L_INDEX_MSB:0] r_data_index;
  // WB Slave Process
  reg        r_write_stb;
  reg  [7:0] r_write_data [0:L_NUM_BYTES-1];
  wire       w_write_ready = r_write_stb | i_master_write_ack;
  //
  integer jj;
  
  ///////////////////////////////////////////////////////////////////////////////
  //            ********      Architecture Declaration      ********           //
  ///////////////////////////////////////////////////////////////////////////////
    
   assign o_slave_write_ack = r_slave_ack; 
  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Wishbone Write Slave Process
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
    if (i_reset == 1'b1) begin
      r_slave_ack  <= 1'b0;
      r_data_index <= 6'h00;
      r_data[0]    <= 'h0;
    end
    else begin
      if (i_slave_write_stb == 1'b1 && r_slave_ack == 1'b0 && r_write_stb == 1'b0) begin
        // 
        r_slave_ack <= 1'b1;
        // 
        r_data[r_data_index] <= i_slave_write_data;
        r_data_index         <= r_data_index + 1;
      end
      else begin
        r_slave_ack <= 1'b0;
      end
      if (r_write_stb == 1'b1) begin
        //
        r_data_index <= 'h0;
      end
    end
  end

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Wishbone Master Controls
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
    if (i_reset == 1'b1) begin
      r_write_stb  <= 1'b0;
    end
    else begin
      if (r_data_index == L_NUM_BYTES && r_slave_ack == 1'b1) begin
        // 
        r_write_stb  <= 1'b1;
        // r_write_data <= r_data;
        for (jj=0; jj<L_NUM_BYTES; jj = jj + 1) begin
          // 
          r_write_data[L_NUM_BYTES-1-jj] <= r_data[jj];
        end
      end
      else if (i_master_write_ack == 1'b1) begin
        r_write_stb <= 1'b0;
      end
    end
  end
  assign o_master_write_stb  = r_write_stb;

  genvar ii;
  generate
    for (ii=0; ii<L_NUM_BYTES; ii = ii + 1) begin
      // 
      assign o_master_write_data[(ii*8)+7:ii*8] = r_write_data[ii];
    end
  endgenerate

endmodule
