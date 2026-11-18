/**
 * @file    sevensegment.sv
 * @brief   8-digit 7-segment display controller
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date    27-Jan-2026
 * @version 1.0
 *
 * @detail
 * This module controls an 8-digit 7-segment display. The eight digits can be displayed as
 * hex digits or as special characters for blanking the digit or displaying a single segment.
 * The decimal points (dots) between each digit are also controlled.  Each digit is displayed
 * according to the following code.	
 * 
 * Value	     Displays
 * 0 - 9	Characters 0 to 9
 * 10 - 15	Characters A to F
 * 16 - 22	Single segments a - g
 * 23 		Blank (Off)
 * 24 - 29	Uppercase H, L, W, l, r, n
 * 30 - 31	Blank (Off)
 *
 * The decimal points are on or off for each digit according to input dp
 */

module sevensegment #(
	// parameters
	parameter integer	CLK_FREQUENCY_HZ = 100000000, 
	parameter integer	REFRESH_FREQUENCY_HZ = 500,
	parameter integer	RESET_POLARITY_LOW = 1,
	parameter integer 	CNTR_WIDTH = 32,
	
	parameter integer	SIMULATE = 0,
	parameter integer	SIMULATE_FREQUENCY_CNT = 5
)
(
	// ports
	input logic		clk,			// system clock
	input logic		reset,			// system reset signal

	input logic [7:0]	enables,		// digit enables[7:0]. 0 to enable a digit
	input logic [4:0]	d0, d1, d2, d3,		// digits to be display d[0] is rightmost digit
	input logic [4:0]	d4, d5, d6, d7,		// digit[7] is leftmost digit
	input logic [7:0]	dp,			// decimal points to be displayed

	output logic [7:0]	seg = 8'b11111111,	// common cathode outputs to display digits
	output logic [7:0]	an  = 8'b11111110	// anode outputs to display digits
);

	
	// reset - asserted low by default
	logic reset_in = RESET_POLARITY_LOW ? ~reset : reset;
	
	// clock divider 
	logic [CNTR_WIDTH-1:0]	clk_cnt;
	logic [CNTR_WIDTH-1:0] 	top_cnt = SIMULATE ? SIMULATE_FREQUENCY_CNT : ((CLK_FREQUENCY_HZ / REFRESH_FREQUENCY_HZ) - 1);

	// cathode outputs for each digit
	logic [7:0]		dig0, dig1, dig2, dig3, dig4, dig5, dig6, dig7;	
	
	// anode outputs for each digit.  Asserted low if enables[n] is low
	logic [7:0] digit1, digit2, digit3, digit4, digit5, digit6, digit7, digit8;
	
	assign digit1 = enables[0] ? 8'b11111111 : 8'b11111110;
	assign digit2 = enables[1] ? 8'b11111111 : 8'b11111101;
	assign digit3 = enables[2] ? 8'b11111111 : 8'b11111011;
	assign digit4 = enables[3] ? 8'b11111111 : 8'b11110111;
	assign digit5 = enables[4] ? 8'b11111111 : 8'b11101111;
	assign digit6 = enables[5] ? 8'b11111111 : 8'b11011111;
	assign digit7 = enables[6] ? 8'b11111111 : 8'b10111111;
	assign digit8 = enables[7] ? 8'b11111111 : 8'b01111111;

	// clock divider counter
	always_ff @(posedge clk) begin: clock_divider
		if (reset_in) begin
			clk_cnt <= 0;
		end
		else if(clk_cnt == top_cnt) begin
			clk_cnt <= 1'b0;
		end
		else begin
			clk_cnt <= clk_cnt + 1'b1;
		end
	end: clock_divider

	always_ff @ (posedge clk) begin: anode_control
		if (reset_in) begin
			an <= digit1;
		end
		else if (clk_cnt == top_cnt) begin
			unique case (an)
				digit1: an <= digit2;
				digit2: an <= digit3;
				digit3: an <= digit4;
				digit4: an <= digit5;
				digit5: an <= digit6;
				digit6: an <= digit7;
				digit7: an <= digit8;
				digit8: an <= digit1;
			endcase
		end
		else begin
			an <= an;
		end
	end: anode_control

	always_ff @(posedge clk) begin: cathode_control
		unique case (an) 
			digit1: seg <= dig0;
			digit2: seg <= dig1;
			digit3: seg <= dig2;
			digit4: seg <= dig3;
			digit5: seg <= dig4;
			digit6: seg <= dig5;
			digit7: seg <= dig6;
			digit8: seg <= dig7;
		endcase
	end: cathode_control

// Instantiate a 7-segment decoder for each digit	
Digit Digit0 (
	.clk(clk),
	.d(d0),
	.dp(dp[0]),
	.seg(dig0)
);

Digit Digit1 (
	.clk(clk),
	.d(d1),
	.dp(dp[1]),
	.seg(dig1)
);

Digit Digit2 (
	.clk(clk),
	.d(d2),
	.dp(dp[2]),
	.seg(dig2)
);

Digit Digit3 (
	.clk(clk),
	.d(d3),
	.dp(dp[3]),
	.seg(dig3)
);

Digit Digit4 (
	.clk(clk),
	.d(d4),
	.dp(dp[4]),
	.seg(dig4)
);

Digit Digit5 (
	.clk(clk),
	.d(d5),
	.dp(dp[5]),
	.seg(dig5)
);

Digit Digit6 (
	.clk(clk),
	.d(d6),
	.dp(dp[6]),
	.seg(dig6)
);

Digit Digit7 (
	.clk(clk),
	.d(d7),
	.dp(dp[7]),
	.seg(dig7)
);

endmodule: sevensegment


/**
 * @brief 7-segment digit encoder 
 */
module Digit (
	input logic		clk,
	input logic [4:0]	d,	// digit code to be displayed
	input logic		dp,	// decimal point to be displayed

	output logic [7:0]	seg	// output to seven segment display cathode
);

		/****gfedcba****/
localparam zero	= 7'b1000000;
localparam one	= 7'b1111001;
localparam two	= 7'b0100100;
localparam three = 7'b0110000;
localparam four = 7'b0011001;
localparam five = 7'b0010010;
localparam six = 7'b0000010;
localparam seven = 7'b1111000;
localparam eight = 7'b0000000;
localparam nine = 7'b0010000;
localparam A = 7'b0001000;
localparam B = 7'b0000011;
localparam C = 7'b1000110;
localparam D = 7'b0100001;
localparam E = 7'b0000110;
localparam F = 7'b0001110;
localparam seg_a = 7'b1111110;
localparam seg_b = 7'b1111101;
localparam seg_c = 7'b1111011;
localparam seg_d = 7'b1110111;
localparam seg_e = 7'b1101111;
localparam seg_f = 7'b1011111;
localparam seg_g = 7'b0111111;

localparam upH = 7'b0001001;
localparam upL = 7'b1000111;
localparam upW = 7'b0000001;
localparam lol = 7'b1001111;
localparam lor = 7'b0101111;
localparam lon = 7'b0101011;

localparam  blank = 7'b1111111;

always_ff @(posedge clk) begin: segment_encoder
	unique case (d)
		5'd00: seg <= {~dp,zero};
		5'd01: seg <= {~dp,one};
		5'd02: seg <= {~dp,two};
		5'd03: seg <= {~dp,three};
		5'd04: seg <= {~dp,four};
		5'd05: seg <= {~dp,five};
		5'd06: seg <= {~dp,six};
		5'd07: seg <= {~dp,seven};
		5'd08: seg <= {~dp,eight};
		5'd09: seg <= {~dp,nine};
		5'd10: seg <= {~dp,A};
		5'd11: seg <= {~dp,B};
		5'd12: seg <= {~dp,C};
		5'd13: seg <= {~dp,D};
		5'd14: seg <= {~dp,E};
		5'd15: seg <= {~dp,F};
		5'd16: seg <= {~dp,seg_a};
		5'd17: seg <= {~dp,seg_b};
		5'd18: seg <= {~dp,seg_c};
		5'd19: seg <= {~dp,seg_d};
		5'd20: seg <= {~dp,seg_e};
		5'd21: seg <= {~dp,seg_f};
		5'd22: seg <= {~dp,seg_g};
		5'd23: seg <= {~dp, blank};
		5'd24: seg <= {~dp,upH};
		5'd25: seg <= {~dp,upL};
		5'd26: seg <= {~dp,upW};
		5'd27: seg <= {~dp,lol};
		5'd28: seg <= {~dp,lor};
		5'd29: seg <= {~dp,lon};
		5'd30: seg <= {~dp,blank};
		5'd31: seg <= {~dp,blank};
	endcase
end: segment_encoder

endmodule: Digit
	
