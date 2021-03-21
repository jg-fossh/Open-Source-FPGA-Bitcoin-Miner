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
// File name     : Tang_Primer_Top.v
// Author        : Jose R Garcia
// Created       : 2020/12/06 00:33:28
// Last modified : 2021/03/08 21:55:08
// Project Name  :
// Module Name   : Tang_Primer_Top
// Description   : The Tang_Primer_Top is the top level wrapper. It stitches together
//                 the miner, the algorithm specific modules and the
//                 communication interfaces.
//
// Additional Comments:
//
/////////////////////////////////////////////////////////////////////////////////
module Tang_Primer_Top  #(
  parameter integer P_LOOP_LOG2        = 4, // Valid range: [0, 5]
  parameter integer P_SPI_MODE         = 0,  // SPI clock polarity and phase mode.
  parameter integer P_NONCE_SEED       = 0,  // SPI clock polarity and phase mode.
  parameter integer P_P2S_FIFO_DEPTH   = 64,
  parameter integer P_CDC_SYNCH_LEVELS = 2
)(
  //
  input i_system_clk,   //
  input i_system_reset, //
  // SPI Interface
  input  i_spi_clk,  //
  output o_spi_miso, //
  input  i_spi_mosi, //
  input  i_spi_ss_n, //
  //
  output [2:0] RGB_LED
);

  ///////////////////////////////////////////////////////////////////////////////
  // Internal Parameter Declarations
  ///////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  // Internal Signals Declarations
  ///////////////////////////////////////////////////////////////////////////////
	//input reset;
	wire extlock;
	wire clk0_buf;

  ///////////////////////////////////////////////////////////////////////////////
  //            ********      Architecture Declaration      ********           //
  ///////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : eg_phy_osc_266mhz
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  EG_PHY_OSC #(
		.STDBY("DISABLE")
  ) eg_phy_osc_266mhz (
		.osc_clk(osc_clk),
		.osc_dis(1'b0)
  );

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : pll_inst
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////

  EG_PHY_PLL #(
    .DPHASE_SOURCE("DISABLE"),
  	.DYNCFG("DISABLE"),
  	.FIN("266.000"),
  	.FEEDBK_MODE("NORMAL"),
  	.FEEDBK_PATH("CLKC0_EXT"),
  	.STDBY_ENABLE("DISABLE"),
  	.PLLRST_ENA("ENABLE"),
  	.SYNC_ENABLE("DISABLE"),
  	.DERIVE_PLL_CLOCKS("DISABLE"),
  	.GEN_BASIC_CLOCK("DISABLE"),
  	.GMC_GAIN(2),
  	.ICP_CURRENT(24),
  	.KVCO(2),
  	.LPF_CAPACITOR(1),
  	.LPF_RESISTOR(4),
  	.REFCLK_DIV(7),
  	.FBCLK_DIV(2),
  	.CLKC0_ENABLE("ENABLE"),
  	.CLKC0_DIV(13),
  	.CLKC0_CPHASE(12),
  	.CLKC0_FPHASE(0)
  ) pll_inst (
    .refclk(osc_clk),
  	.reset(i_system_reset),
  	.stdby(1'b0),
  	.extlock(extlock),
  	.load_reg(1'b0),
  	.psclk(1'b0),
  	.psdown(1'b0),
  	.psstep(1'b0),
  	.psclksel(3'b000),
  	.psdone(open),
  	.dclk(1'b0),
  	.dcs(1'b0),
  	.dwe(1'b0),
  	.di(8'b00000000),
  	.daddr(6'b000000),
  	.do({open, open, open, open, open, open, open, open}),
  	.fbclk(clk0_out),
  	.clkc({open, open, open, open, clk0_buf})
  );

  assign RGB_LED[0] = extlock;
  assign RGB_LED[1] = ~i_spi_ss_n;
  
  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : clk_buf0
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
	EG_LOGIC_BUFG clk_buf0 (
    .i(clk0_buf),
    .o(clk0_out)
  );

  ///////////////////////////////////////////////////////////////////////////////
  // Instance    : miner_top
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  Miner_Top #(
    .P_LOOP_LOG2(P_LOOP_LOG2),           //
    .P_SPI_MODE(P_SPI_MODE),             //
    .P_NONCE_SEED(P_NONCE_SEED),         //
    .P_CDC_SYNCH_LEVELS(P_CDC_SYNCH_LEVELS),
    .P_P2S_FIFO_DEPTH(P_P2S_FIFO_DEPTH), //
    .P_ANLOGIC_EG4(1)                    // ANLOGIC EG4 IPs
  ) miner_top (
    //
    .i_system_clk(clk0_out),   //
    .i_system_reset(~extlock | i_system_reset), //
    // SPI Interface
    .i_spi_clk(i_spi_clk),   //
    .o_spi_miso(o_spi_miso), //
    .i_spi_mosi(i_spi_mosi), //
    .i_spi_ss(~i_spi_ss_n),   //
    //
    .o_waiting(RGB_LED[2])
);

endmodule
