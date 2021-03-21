module e0 (
	input  [31:0] x,
	output [31:0] y
);

  assign y = {x[1:0],x[31:2]} ^ {x[12:0],x[31:13]} ^ {x[21:0],x[31:22]};

endmodule


module e1 (
	input  [31:0] x,
	output [31:0] y
);

	assign y = {x[5:0],x[31:6]} ^ {x[10:0],x[31:11]} ^ {x[24:0],x[31:25]};

endmodule


module ch (
	input  [31:0] x,
	input  [31:0] y,
	input  [31:0] z,
	output [31:0] o
);

	assign o = z ^ (x & (y ^ z));

endmodule


module maj (
	input  [31:0] x,
	input  [31:0] y,
	input  [31:0] z,
	output [31:0] o
);

	assign o = (x & y) | (z & (x | y));

endmodule


module s0 (
	input  [31:0] x,
	output [31:0] y
);

	assign y[31:29] = x[6:4] ^ x[17:15];
	assign y[28:0] = {x[3:0], x[31:7]} ^ {x[14:0],x[31:18]} ^ x[31:3];

endmodule


module s1 (
	input  [31:0] x,
	output [31:0] y
);

	assign y[31:22] = x[16:7] ^ x[18:9];
	assign y[21:0] = {x[6:0],x[31:17]} ^ {x[8:0],x[31:19]} ^ x[31:10];

endmodule


