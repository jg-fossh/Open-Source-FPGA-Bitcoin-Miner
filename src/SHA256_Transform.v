/////////////////////////////////////////////////////////////////////////////////
// File name     : SHA256_Transform.v
// Author        : Jose R Garcia
// Created       : 2020/12/06 00:33:28
// Last modified : 2021/03/07 11:59:03
// Project Name  :
// Module Name   : SHA256_Transform
// Description   : The SHA256_Transform is the
//
// Additional Comments:
// Perform a SHA-256 transformation on the given 512-bit data, and 256-bit
// initial state,
// Outputs one 256-bit hash every P_UNWRAP_LEVEL cycle(s).
//
// The P_UNWRAP_LEVEL parameter determines both the size and speed of this module.
// A value of 1 implies a fully unrolled SHA-256 calculation spanning 64 round
// modules and calculating a full SHA-256 hash every clock cycle. A value of
// 2 implies a half-unrolled loop, with 32 round modules and calculating
// a full hash in 2 clock cycles. And so forth.
/////////////////////////////////////////////////////////////////////////////////
module SHA256_Transform #(
	parameter integer P_UNWRAP_LEVEL = 32, //
	parameter integer P_Ks_MSB       = 32 //
)(
  input i_clk,
  //
  input              i_slave_write_stb,  //
	input [P_Ks_MSB:0] Ks,
  input [767:0]      i_slave_write_data, //
  //
  output [255:0] o_master_write_data //
);

  ///////////////////////////////////////////////////////////////////////////////
  // Internal Parameter Declarations
  ///////////////////////////////////////////////////////////////////////////////
  localparam integer L_HASHERS_NUM = 64/P_UNWRAP_LEVEL;
	localparam integer L_COUNT_MSB   = P_UNWRAP_LEVEL<=1 ? 0 : $clog2(P_UNWRAP_LEVEL)-1;
  ///////////////////////////////////////////////////////////////////////////////
  // Internal Signals Declarations
  ///////////////////////////////////////////////////////////////////////////////
	//
	wire [255:0] r_state_in = i_slave_write_data[255:0];
	// reg [255:0] r_state_in;
	//
	wire [511:0] W     [0:L_HASHERS_NUM-1];
  wire [255:0] state [0:L_HASHERS_NUM-1];
	//
	reg         r_write_stb;
	reg [255:0] tx_hash;

  ///////////////////////////////////////////////////////////////////////////////
  //            ********      Architecture Declaration      ********           //
  ///////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Wishbone Write Slave Process
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  // always @(posedge i_clk) begin
  //   if (i_slave_write_stb == 1'b1) begin
  //     //
  //     r_state_in <= i_slave_write_data[255:0];
  //   end
  // end

	genvar i;
	generate
		for (i = 0; i < L_HASHERS_NUM; i = i + 1) begin : HASHERS
			if (i == 0) begin
        ///////////////////////////////////////////////////////////////////////////////
        // Instance    : hasher
        // Description : .
        ///////////////////////////////////////////////////////////////////////////////
				SHA256_Digester hasher (
					.clk(i_clk),
					.k(Ks[P_Ks_MSB:(P_Ks_MSB-32)+1]),
					.rx_w(i_slave_write_stb==1'b0 ? W[L_HASHERS_NUM-1] : i_slave_write_data[767:256]),
					.rx_state(i_slave_write_stb==1'b0 ? state[L_HASHERS_NUM-1] : i_slave_write_data[255:0]),
					.tx_w(W[0]),
					.tx_state(state[0])
				);
			end
			else begin
        ///////////////////////////////////////////////////////////////////////////////
        // Instance    : hasher
        // Description : .
        ///////////////////////////////////////////////////////////////////////////////
				SHA256_Digester hasher (
					.clk(i_clk),
					.k(Ks[P_Ks_MSB-(32*i):(P_Ks_MSB-(32*(i+1)))+1]),
					.rx_w(i_slave_write_stb==1'b0 ? W[i-1] : W[i]),
					.rx_state(i_slave_write_stb==1'b0 ? state[i-1] : state[i]),
					.tx_w(W[i]),
					.tx_state(state[i])
				);
			end
		end
	endgenerate

  ///////////////////////////////////////////////////////////////////////////////
  // Process     : Wishbone Master Controls
  // Description : .
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge i_clk) begin
		//if (i_slave_write_stb == 1'b0) begin
	    tx_hash[31:0]    <= r_state_in[31:0]    + state[L_HASHERS_NUM-1][31:0];
	    tx_hash[63:32]   <= r_state_in[63:32]   + state[L_HASHERS_NUM-1][63:32];
	    tx_hash[95:64]   <= r_state_in[95:64]   + state[L_HASHERS_NUM-1][95:64];
	    tx_hash[127:96]  <= r_state_in[127:96]  + state[L_HASHERS_NUM-1][127:96];
	    tx_hash[159:128] <= r_state_in[159:128] + state[L_HASHERS_NUM-1][159:128];
	    tx_hash[191:160] <= r_state_in[191:160] + state[L_HASHERS_NUM-1][191:160];
	    tx_hash[223:192] <= r_state_in[223:192] + state[L_HASHERS_NUM-1][223:192];
	    tx_hash[255:224] <= r_state_in[255:224] + state[L_HASHERS_NUM-1][255:224];
		//end
  end
	//
  assign o_master_write_data = tx_hash;

endmodule
