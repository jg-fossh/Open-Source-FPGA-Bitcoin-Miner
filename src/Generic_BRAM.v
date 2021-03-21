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
// File name     : Generic_BRAM.v
// Author        : Jose R Garcia
// Create        : 21/04/2019 19:25:32
// Last modified : 2021/03/02 19:54:28
// Project Name  : Generic BRAM Module
// Module Name   : Generic_BRAM
// Description   : Inferred BRAM. Most modern synthesis tools can infer this code
//                 as an array of BRAM and map it to specific technologies.
//
// Additional Comments:
//
/////////////////////////////////////////////////////////////////////////////////
module Generic_BRAM #(
  parameter integer P_BRAM_DATA_MSB    = 15,
  parameter integer P_BRAM_ADDRESS_MSB = 4,
  parameter integer P_BRAM_DEPTH       = 32,
  parameter integer P_BRAM_HAS_FILE    = 0,
  parameter         P_BRAM_INIT_FILE   = 0
)(
  input                         i_wclk,
  input                         i_we,
  input                         i_rclk, /* verilator lint_off LITENDIAN */
  input  [P_BRAM_ADDRESS_MSB:0] i_waddr,
  input  [P_BRAM_ADDRESS_MSB:0] i_raddr,
  input  [P_BRAM_DATA_MSB:0]    i_wdata,
  output [P_BRAM_DATA_MSB:0]    o_rdata
 );

  /////////////////////////////////////////////////////////////////////////////
  // Internal Parameter Declarations
  /////////////////////////////////////////////////////////////////////////////
  // Signals Definition
  reg [P_BRAM_DATA_MSB:0] r_mem [0:P_BRAM_DEPTH-1];
  reg [P_BRAM_DATA_MSB:0] r_rdata;

  generate
    if (P_BRAM_HAS_FILE == 1) begin
      initial begin
        // Load initial states of the brams from a file.
        $readmemh(P_BRAM_INIT_FILE, r_mem);
      end
    end
  endgenerate

  ///////////////////////////////////////////////////////////////////////////////
  //            ********      Architecture Declaration      ********           //
  ///////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : mem write access
  // Description : Synchronous writes to memory.
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_wclk) begin
    if (i_we == 1'b1) begin
      r_mem[i_waddr] <= i_wdata;
    end
  end

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : mem read access
  // Description : Synchronous reads memory. There is no read enable signal for
  //               the read side, hence it is always reading on every clock
  //               transition.
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_rclk) begin
      r_rdata <= r_mem[i_raddr];
  end
  assign o_rdata = r_rdata;

endmodule // Generic_BRAM
