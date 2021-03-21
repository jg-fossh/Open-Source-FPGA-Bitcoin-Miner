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
// File name     : Miner.v
// Author        : Jose R Garcia
// Created       : 2020/12/06 00:33:28
// Last modified : 2021/03/08 21:55:51
// Project Name  :
// Module Name   : Miner
// Description   : The Miner is the
//
// Additional Comments:
//   The nonce will always be larger at the time we discover a valid
//   hash. This is its offset from the nonce that gave rise to the valid
//   hash (except when P_LOOP_LOG2 == 0 or 1, where the offset is 131 or
//   66 respectively).
/////////////////////////////////////////////////////////////////////////////////
module Miner #(
  parameter integer P_LOOP_LOG2            = 4,      // Valid range: [2, 5]
  parameter integer P_MINER_DATA_IN_MSB    = 351,
  parameter integer P_NONCE_MSB            = 31,
  parameter integer P_NONCE_SEED           = 0,
  parameter integer P_ANLOGIC_EG4          = 0  //
)(
  input i_clk,
  input i_reset,
  // Wishbone(Standard) Write Slave Interface
  input                         i_slave_write_stb,  // WB write enable
  input [P_MINER_DATA_IN_MSB:0] i_slave_write_data, // WB data
  // Wishbone (Standard) Write Master Interface
  output                 o_master_write_stb,  // WB write enable
  output [P_NONCE_MSB:0] o_master_write_data, // WB data
  input                  i_master_write_ack,   // WB acknowledge
  //
  output o_waiting //
);
  ///////////////////////////////////////////////////////////////////////////////
  // Internal Parameter Declarations
  ///////////////////////////////////////////////////////////////////////////////
  localparam [5:0]  L_UNWRAP_LEVEL = (6'd1 << P_LOOP_LOG2);
  localparam [31:0] L_NONCE_OFFSET = ((32'h1<<(7-P_LOOP_LOG2))+32'b1);
  //
  localparam integer L_HASHERS_NUM = 64/L_UNWRAP_LEVEL;
	localparam integer L_COUNT_MSB   = L_UNWRAP_LEVEL<=1 ? 0 : $clog2(L_UNWRAP_LEVEL)-1;
  localparam integer L_K_ARRAY_MSB = (L_HASHERS_NUM*32)-1;
  localparam integer L_K_WORDS     = 32*4*16;
  localparam integer L_K_DEPTH     = L_UNWRAP_LEVEL;
  // 
  localparam [383:0] L_HASHER_DATA_PADDING  = 384'h000002800000000000000000000000000000000000000000000000000000000000000000000000000000000080000000;
  // first 32 bits of the fractional parts of the square roots of the first 8 primes 2..19
  localparam [255:0] L_TRANSFORM1_STATE     = 256'h5be0cd191f83d9ab9b05688c510e527fa54ff53a3c6ef372bb67ae856a09e667;
  //
  localparam [255:0] L_TRANSFORM1_INPUT_PAD = 256'h0000010000000000000000000000000000000000000000000000000080000000;
  
  ///////////////////////////////////////////////////////////////////////////////
  // Internal Signals Declarations
  ///////////////////////////////////////////////////////////////////////////////
  // SHA256 Transform 0
  wire [255:0] w_transform0_master_hash;
  // SHA256 Transform 1
  wire [255:0] w_transform1_master_hash;
  // wire [31:0] w_transform1_master_hash;
  wire w_write_stb;
  // Ks ROM
  wire [L_K_ARRAY_MSB:0] w_k_mem;
  // Steps Counter Process
  reg [L_COUNT_MSB:0] r_count;
  reg [L_COUNT_MSB:0] r_ks_addr;
  reg                 r_slave_write_stb;
  reg                 r_stb_waiting;
  // Nonce Increment Process
  //reg [P_NONCE_MSB:0] r_nonce;
  reg [P_NONCE_MSB:0] r_nonce_next; // rename
  reg                 r_write_stb;
  //
  wire [383:0] w_HASHER_DATA_PADDING;
  wire [255:0] w_TRANSFORM1_STATE;
  wire [255:0] w_TRANSFORM1_INPUT_PAD;

  ///////////////////////////////////////////////////////////////////////////////
  //            ********      Architecture Declaration      ********           //
  ///////////////////////////////////////////////////////////////////////////////

  generate
    if (P_ANLOGIC_EG4 == 0) begin
      Generic_BRAM #(
        .P_BRAM_DATA_MSB(L_K_ARRAY_MSB),
        .P_BRAM_ADDRESS_MSB(L_COUNT_MSB),
        .P_BRAM_DEPTH(L_K_DEPTH),
        .P_BRAM_HAS_FILE(1),
        .P_BRAM_INIT_FILE("mem2_4.mem")
      ) Ks_ram (
        .i_wclk(i_clk),
        .i_we(1'b0),
        .i_rclk(i_clk), /* verilator lint_off LITENDIAN */
        .i_waddr('h0),
        .i_raddr(r_ks_addr),
        .i_wdata('h0),
        .o_rdata(w_k_mem)
      );
    end
  endgenerate
  
  generate
    if (P_ANLOGIC_EG4 == 1) begin
      EG_LOGIC_BRAM #(
       .DATA_WIDTH_A(L_K_ARRAY_MSB+1),
      	.ADDR_WIDTH_A(L_COUNT_MSB+1),
      	.DATA_DEPTH_A(L_K_DEPTH),
      	.DATA_WIDTH_B(L_K_ARRAY_MSB+1),
      	.ADDR_WIDTH_B(L_COUNT_MSB+1),
      	.DATA_DEPTH_B(L_K_DEPTH),
      	.MODE("SP"),
      	.REGMODE_A("REG"),
      	.RESETMODE("SYNC"),
      	.IMPLEMENT("9K(FAST)"),
      	.DEBUGGABLE("NO"),
      	.PACKABLE("NO"),
      	.INIT_FILE("../build/ANLOGIC_EAGLE/Contraints/mem2_4.mif"),
      	.FILL_ALL("NONE")
      ) Ks_rom (
        .dia({L_K_ARRAY_MSB+1{1'b0}}),
        .dib({L_K_ARRAY_MSB+1{1'b0}}),
        .addra(r_ks_addr),
        .addrb({L_COUNT_MSB+1{1'b0}}),
        .cea(1'b1),
        .ceb(1'b0),
        .ocea(1'b0),
        .oceb(1'b0),
        .clka(i_clk),
        .clkb(1'b0),
        .wea(1'b0),
        .web(1'b0),
        .bea(1'b0),
        .beb(1'b0),
        .rsta(i_reset),
        .rstb(1'b0),
        .doa(w_k_mem),
        .dob()
      );
    end
  endgenerate

  generate
    if (P_ANLOGIC_EG4 == 1) begin
      EG_LOGIC_BRAM #(
        .DATA_WIDTH_A(384),
      	.ADDR_WIDTH_A(1),
      	.DATA_DEPTH_A(2),
      	.DATA_WIDTH_B(384),
      	.ADDR_WIDTH_B(1),
      	.DATA_DEPTH_B(2),
      	.MODE("SP"),
      	.REGMODE_A("REG"),
      	.RESETMODE("SYNC"),
      	.IMPLEMENT("9K(FAST)"),
      	.DEBUGGABLE("NO"),
      	.PACKABLE("NO"),
      	.INIT_FILE("../build/ANLOGIC_EAGLE/Contraints/data_pad.mif"),
      	.FILL_ALL("NONE")
      ) pad_rom (
        .dia({384{1'b0}}),
        .dib({384{1'b0}}),
        .addra(1'b0),
        .addrb(1'b0),
        .cea(1'b1),
        .ceb(1'b0),
        .ocea(1'b0),
        .oceb(1'b0),
        .clka(i_clk),
        .clkb(1'b0),
        .wea(1'b0),
        .web(1'b0),
        .bea(1'b0),
        .beb(1'b0),
        .rsta(i_reset),
        .rstb(1'b0),
        .doa(w_HASHER_DATA_PADDING),
        .dob()
      );

      EG_LOGIC_BRAM #(
       .DATA_WIDTH_A(256),
      	.ADDR_WIDTH_A(1),
      	.DATA_DEPTH_A(2),
      	.DATA_WIDTH_B(256),
      	.ADDR_WIDTH_B(1),
      	.DATA_DEPTH_B(2),
      	.MODE("SP"),
      	.REGMODE_A("REG"),
      	.RESETMODE("SYNC"),
      	.IMPLEMENT("9K(FAST)"),
      	.DEBUGGABLE("NO"),
      	.PACKABLE("NO"),
      	.INIT_FILE("../build/ANLOGIC_EAGLE/Contraints/state.mif"),
      	.FILL_ALL("NONE")
      ) state_rom (
        .dia({256{1'b0}}),
        .dib({256{1'b0}}),
        .addra(1'b0),
        .addrb(1'b0),
        .cea(1'b1),
        .ceb(1'b0),
        .ocea(1'b0),
        .oceb(1'b0),
        .clka(i_clk),
        .clkb(1'b0),
        .wea(1'b0),
        .web(1'b0),
        .bea(1'b0),
        .beb(1'b0),
        .rsta(i_reset),
        .rstb(1'b0),
        .doa(w_TRANSFORM1_STATE),
        .dob()
      );
      EG_LOGIC_BRAM #(
       .DATA_WIDTH_A(256),
      	.ADDR_WIDTH_A(1),
      	.DATA_DEPTH_A(2),
      	.DATA_WIDTH_B(256),
      	.ADDR_WIDTH_B(1),
      	.DATA_DEPTH_B(2),
      	.MODE("SP"),
      	.REGMODE_A("REG"),
      	.RESETMODE("SYNC"),
      	.IMPLEMENT("9K(FAST)"),
      	.DEBUGGABLE("NO"),
      	.PACKABLE("NO"),
      	.INIT_FILE("../build/ANLOGIC_EAGLE/Contraints/input_pad.mif"),
      	.FILL_ALL("NONE")
      ) input_pad_rom (
        .dia({256{1'b0}}),
        .dib({256{1'b0}}),
        .addra(1'b0),
        .addrb(1'b0),
        .cea(1'b1),
        .ceb(1'b0),
        .ocea(1'b0),
        .oceb(1'b0),
        .clka(i_clk),
        .clkb(1'b0),
        .wea(1'b0),
        .web(1'b0),
        .bea(1'b0),
        .beb(1'b0),
        .rsta(i_reset),
        .rstb(1'b0),
        .doa(w_TRANSFORM1_INPUT_PAD),
        .dob()
      );
    end
  endgenerate

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : sha256_transform0
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  SHA256_Transform #(
	  .P_UNWRAP_LEVEL(L_UNWRAP_LEVEL),
    .P_Ks_MSB(L_K_ARRAY_MSB)
  ) transform0 (
    .i_clk(i_clk),
    //
    .i_slave_write_stb(r_slave_write_stb),  //
    .Ks(w_k_mem),
    .i_slave_write_data({(P_ANLOGIC_EG4==1 ? w_HASHER_DATA_PADDING : L_HASHER_DATA_PADDING), r_nonce_next, i_slave_write_data}), //
    //
    .o_master_write_data(w_transform0_master_hash) //
  );

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : sha256_transform1
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  SHA256_Transform #(
	  .P_UNWRAP_LEVEL(L_UNWRAP_LEVEL),
    .P_Ks_MSB(L_K_ARRAY_MSB)
  ) transform1 (
    .i_clk(i_clk),
    .i_slave_write_stb(r_slave_write_stb),  //
    .Ks(w_k_mem),
    .i_slave_write_data({(P_ANLOGIC_EG4==1 ? w_TRANSFORM1_INPUT_PAD : L_TRANSFORM1_INPUT_PAD), w_transform0_master_hash, (P_ANLOGIC_EG4==1 ? w_TRANSFORM1_STATE : L_TRANSFORM1_STATE)}), //
    //
    .o_master_write_data(w_transform1_master_hash) //
  );
  //
  assign w_write_stb = w_transform1_master_hash[255:252]=='h0 ? 1'b1 : 1'b0;
  //assign w_write_stb = w_transform1_master_hash[255:224]=='h0 ? 1'b1 : 1'b0;
  // assign w_write_stb = (|w_transform1_master_hash[255:224]==1'b0 && r_count==L_UNWRAP_LEVEL) ? 1'b1 : 1'b0;
  // assign w_write_stb = w_transform1_master_hash==32'hA41F32E7 ? 1'b1 : 1'b0;

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Steps Count
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
  	if (i_reset == 1'b1) begin
  		r_count           <= 'h0;
  		r_ks_addr         <= 'h0;
      r_stb_waiting     <= 1'b1;
      r_slave_write_stb <= 1'b0;
		end
		else begin
      if (r_slave_write_stb == 1'b1 || (r_count < L_UNWRAP_LEVEL-1 && r_stb_waiting == 1'b0)) begin
		  	r_count       <= (r_count + 1);
		  end
      else begin
  	  	r_count <= 'h0;
      end
      if (i_slave_write_stb == 1'b1 || (r_ks_addr < L_UNWRAP_LEVEL-1 && r_stb_waiting == 1'b0)) begin
		  	r_ks_addr     <= (r_ks_addr + 1);
        r_stb_waiting <= 1'b0;
		  end
      else begin
  	  	r_ks_addr <= 'h0;
      end
      if (r_nonce_next == -1 && r_count == -1) begin
        r_stb_waiting <= 1'b1;
      end
      r_slave_write_stb <= i_slave_write_stb;
    end
  end

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Nonce Increment
  // Description :
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
    if (i_reset == 1'b1 || i_slave_write_stb == 1'b1) begin
      r_write_stb  <= 1'b0;
      //r_nonce      <= 32'h00000000;
      r_nonce_next <= P_NONCE_SEED; //
    end
    else begin
      if (r_count == L_UNWRAP_LEVEL-1) begin
        if (&r_nonce_next[31:30] == 1'b1 && &r_nonce_next[29:28] == 1'b1 && &r_nonce_next[26:0] == 1'b1) begin
          // Do a jump given the nonce probability distribution.
          r_nonce_next <= r_nonce_next + 32'h07000000;
        end
        else begin
          r_nonce_next <= r_nonce_next + 1;
        end
      end
      //
      if (i_master_write_ack == 1'b1) begin
        r_write_stb <= 1'b0;
      end
      else if (w_write_stb == 1'b1) begin
        r_write_stb <= 1'b1;
        //r_nonce     <= (r_nonce_next - L_NONCE_OFFSET);
      end
    end
  end
  //
  assign o_master_write_stb  = r_stb_waiting==1'b0 ? 
                                 (r_write_stb==1'b0 ? w_write_stb : 1'b1) :
                                 1'b0;
  assign o_master_write_data = (r_nonce_next - L_NONCE_OFFSET);

  assign o_waiting = r_stb_waiting;

endmodule
