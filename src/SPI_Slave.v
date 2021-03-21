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
// File name     : SPI_Slave.v
// Author        : Jose R Garcia
// Created       : 2020/12/06 00:33:28
// Last modified : 2021/03/07 10:32:20
// Project Name  : 
// Module Name   : SPI_Slave
// Description   : Creates a SPI slave based on input configuration.
//                 Receives a byte one bit at a time on MOSI
//                 Will also push out byte data one bit at a time on MISO.  
//                 Any data on input byte will be shipped out on MISO.
//                 Supports multiple bytes per transaction when CS_n is kept 
//                 low during the transaction.
//
// Additional Comments:
//   i_clk must be at least 4x faster than i_spi_clk
//   MISO is tri-stated when not communicating.  Allows for multiple
//   SPI Slaves on the same interface.
//
// Parameters:  
//   P_SPI_MODE, can be 0, 1, 2, or 3.
//   Can be configured in one of 4 modes:
//   Mode | Clock Polarity (CPOL) | Clock Phase (CPHA)
//    0   |           0           |        0
//    1   |           0           |        1
//    2   |           1           |        0
//    3   |           1           |        1
/////////////////////////////////////////////////////////////////////////////////
module SPI_Slave #(
  parameter integer P_SPI_MODE         = 0, //
  parameter integer P_CDC_SYNCH_LEVELS = 2  // 2 or higher
)(
  // SPI Interface
  input  i_spi_clk,  // 
  output o_spi_miso, // 
  input  i_spi_mosi, // 
  input  i_spi_ss,   // 
  // Control/Data Signals
  input i_clk,   // FPGA Clock
  input i_reset, // FPGA Reset
  // Wishbone (Standard) Write Master Interface
  output       o_master_write_stb,  // Data Valid pulse (1 clock cycle)
  output [7:0] o_master_write_data, // Byte received on MOSI
  input        i_master_write_ack,  // 
  // Wishbone(Standard) Write Slave Interface
  input        i_slave_write_stb,  // WB write enable
  input  [7:0] i_slave_write_data, // Byte to serialize to MISO.
  output       o_slave_write_ack   // WB acknowledge
);

  ///////////////////////////////////////////////////////////////////////////////
  // Internal Parameter Declarations
  ///////////////////////////////////////////////////////////////////////////////
  // CPOL: Clock Polarity
  // CPOL=0 means clock idles at 0, leading edge is rising edge.
  // CPOL=1 means clock idles at 1, leading edge is falling edge.
  localparam L_CPOL = (P_SPI_MODE==2 || P_SPI_MODE==3) ? 1'b1 : 1'b0;
  // CPHA: Clock Phase
  // CPHA=0 means the "out" side changes the data on trailing edge of clock
  //              the "in" side captures data on leading edge of clock
  // CPHA=1 means the "out" side changes the data on leading edge of clock
  //              the "in" side captures data on the trailing edge of clock
  localparam L_CPHA = (P_SPI_MODE==1 || P_SPI_MODE==3) ? 1'b1 : 1'b0;
  ///////////////////////////////////////////////////////////////////////////////
  // Internal Signals Declarations
  ///////////////////////////////////////////////////////////////////////////////
  // SPI Interface
  wire w_spi_clk;
  wire w_spi_miso_mux;
  // Rx SPI Process
  reg [2:0] r_rx_spi_bit_count;
  reg       r_rx_spi_done;
  reg [7:0] r_rx_spi_byte;
  reg       r_rx_spi_start;
  // CDC Process
  reg       r_rx_cdc_done [P_CDC_SYNCH_LEVELS-1:0];
  reg [7:0] r_rx_cdc_byte [P_CDC_SYNCH_LEVELS-1:0];
  // WB Write Master Process
  reg       r_write_stb;
  reg [7:0] r_write_byte;
  // Tx Process
  reg       r_write_ack;
  reg [7:0] r_tx_byte;
  //
  reg [2:0] r_tx_bit_count;
  reg       r_spi_miso_bit;
  reg       r_preload_miso;
  // Mis.
  integer ii;
  ///////////////////////////////////////////////////////////////////////////////
  //            ********      Architecture Declaration      ********           //
  ///////////////////////////////////////////////////////////////////////////////

  // Clock Phase Select
  assign w_spi_clk = L_CPHA==1'b1 ? ~i_spi_clk : i_spi_clk;

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Rx SPI Process
  // Description : Recover SPI Byte in SPI Clock Domain. Samples line on the 
  //               correct edge of SPI Clock.
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge w_spi_clk) begin
    if (i_reset == 1'b1 || i_spi_ss == 1'b0) begin
      r_rx_spi_done      <= 1'b0;
      r_rx_spi_bit_count <= 3'b000;
      r_rx_spi_byte      <= 8'h00;
      r_rx_spi_start     <= 1'b0;
    end
    else if (i_spi_ss == 1'b1) begin
      r_rx_spi_start <= 1'b1;
      // If chip select enable.
      // Increment bit count
      r_rx_spi_bit_count <= r_rx_spi_bit_count + 1;
      // Receive in LSB, shift up to MSB
      r_rx_spi_byte <= {r_rx_spi_byte[6:0], i_spi_mosi};
      
      if (r_rx_spi_bit_count == 3'b000 && r_rx_spi_start == 1'b1) begin
        // This is the last bit
        r_rx_spi_done <= ~r_rx_spi_done;
      end
    end
    else begin
      r_rx_spi_start <= 1'b0;
    end
  end

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : CDC Process
  // Description : Cross from SPI Clock Domain to main FPGA clock domain. The
  //               FPGA clock is assumed to be a higher rate (faster) than
  //               the SPI clock.
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
    if (i_reset == 1'b1) begin
      r_rx_cdc_done[0] <= 1'b0;
      r_rx_cdc_byte[0] <= 8'h00;
    end
    else begin
      //
      r_rx_cdc_done[0] <= r_rx_spi_done;
      r_rx_cdc_byte[0] <= r_rx_spi_byte;
    end
  end
  genvar hh;
  generate
    for (hh=1; hh<P_CDC_SYNCH_LEVELS; hh = hh + 1) begin
    always @(posedge i_clk) begin
      r_rx_cdc_done[hh] <= r_rx_cdc_done[hh-1];
      r_rx_cdc_byte[hh] <= r_rx_cdc_byte[hh-1];
    end
    end
  endgenerate

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : WB Write Master Process
  // Description : Writes a valid byte through the WB master interface.
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
    if (i_reset == 1'b1) begin
      r_write_stb  <= 1'b0;
      r_write_byte <= 8'h00;
    end
    else begin
      if (r_rx_cdc_done[P_CDC_SYNCH_LEVELS-1] != r_rx_cdc_done[P_CDC_SYNCH_LEVELS-2] && r_write_stb == 1'b0) begin
        // 
        r_write_stb  <= 1'b1;
        r_write_byte <= r_rx_cdc_byte[P_CDC_SYNCH_LEVELS-1];
      end

      if (r_write_stb == 1'b1 && i_master_write_ack == 1'b1) begin
        // 
        r_write_stb <= 1'b0;
      end
    end
  end
  //
  assign o_master_write_stb  = r_write_stb;
  assign o_master_write_data = r_write_byte;

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Tx Byte In Process
  // Description : Register TX Byte when DV pulse comes. Keeps registered byte 
  //               in  this module to get serialized and sent back to master.
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
    if (i_reset == 1'b1) begin
      r_tx_byte   <= 8'h00;
      r_write_ack <= 1'b0;
    end
    else begin
      if (i_slave_write_stb == 1'b1 && r_write_ack == 1'b0) begin
        r_tx_byte   <= i_slave_write_data;
        r_write_ack <= 1'b1;
      end
      else begin
        r_write_ack <= 1'b0;
      end
    end
  end
  //
  assign o_slave_write_ack = r_write_ack;
  
  ///////////////////////////////////////////////////////////////////////////////
  // Process     : MISO Preload Process
  // Description : Control preload signal. Should be 1 when CS is high, but as 
  //               soon as first clock edge is seen it goes low.
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge w_spi_clk) begin
    if (i_spi_ss == 1'b0) begin
      r_preload_miso <= 1'b1;
    end
    else begin
      r_preload_miso <= 1'b0;
    end
  end

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : MISO Bit Process
  // Description : Transmits 1 SPI Byte whenever SPI clock is toggling
  //               Will transmit read data back to SW over MISO line.
  //               Want to put data on the line immediately when CS goes low.
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge w_spi_clk) begin
    if (i_spi_ss == 1'b0) begin
      //
      r_tx_bit_count <= 3'b111;  // Send MSb first
      r_spi_miso_bit <= r_tx_byte[3'b111];  // Reset to MSb
    end
    else begin
      r_tx_bit_count <= r_tx_bit_count - 1;
      // Here is where data crosses clock domains from i_clk to w_spi_clk
      // Can set up a timing constraint with wide margin for data path.
      r_spi_miso_bit <= r_tx_byte[r_tx_bit_count];
    end
  end
  // Preload MISO with top bit of send data when preload selector is high.
  // Otherwise just send the normal MISO data
  assign w_spi_miso_mux = r_preload_miso ? r_tx_byte[3'b111] : r_spi_miso_bit;

  // Tri-state MISO when CS is high.  Allows for multiple slaves to talk.
  assign o_spi_miso = i_spi_ss ? w_spi_miso_mux : 1'bZ;

endmodule