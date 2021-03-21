module SHA256_Digester (
	input clk,
	//
	input [31:0]  k,
	input [511:0] rx_w,
	input [255:0] rx_state,
  //
	output reg [511:0] tx_w,
	output reg [255:0] tx_state
);

  // 
	wire [31:0] e0_w;
	wire [31:0] e1_w;
	wire [31:0] ch_w;
	wire [31:0] maj_w;
	wire [31:0] s0_w;
	wire [31:0] s1_w;
	//
	wire [31:0] t1    = rx_state[255:224] + e1_w + ch_w + k + rx_w[31:0];
	wire [31:0] t2    = e0_w + maj_w;
	wire [31:0] new_w = s1_w + rx_w[319:288] + s0_w + rx_w[31:0];

  //
	e0  e0_blk	(rx_state[31:0], e0_w);
	e1	e1_blk	(rx_state[159:128], e1_w);
	ch	ch_blk	(rx_state[159:128], rx_state[191:160], rx_state[223:192], ch_w);
	maj	maj_blk	(rx_state[31:0], rx_state[63:32], rx_state[95:64], maj_w);
	s0	s0_blk	(rx_w[63:32], s0_w);
	s1	s1_blk	(rx_w[479:448], s1_w);

	always @(posedge clk) begin
		tx_w[511:480] <= new_w;
		tx_w[479:0]   <= rx_w[511:32];
    // 
		tx_state[255:224] <= rx_state[223:192];
		tx_state[223:192] <= rx_state[191:160];
		tx_state[191:160] <= rx_state[159:128];
		tx_state[159:128] <= rx_state[127:96] + t1;
		tx_state[127:96]  <= rx_state[95:64];
		tx_state[95:64]   <= rx_state[63:32];
		tx_state[63:32]   <= rx_state[31:0];
		tx_state[31:0]    <= t1 + t2;
	end

endmodule