/**
 * @file	wb_sevenseg.sv
 * @brief	Top level file for enhanced 7-segment display controller
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and CoPilot
 * @date	25-Mar-2026
 * @version	2.0
 *
 * @detail
 * Revision History:
 * -----------------
 *  	1.0		21-Feb-2026	(RK)	Created enhanced 7 seg display controller for RVfpga Syscon
 *	2.0		25-Mar-2026	(RK)	modified to use wb_template.sv.  Functionality is the same.
 *
 * This module controls an 8-digit 7-segment display. The eight digits can be displayed as
 * hex digits or as special characters for blanking the digit or displaying a single segment.
 * The decimal points (dots) between each digit are also controlled.  Each digit is displayed	
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
 * @note This code was ported from the RVfgpa SystemController code, enhanced, and put in it's own file
 */
 // SPDX-License-Identifier: MIT
 
`default_nettype wire

module wb_sevenseg #(
    parameter int DW = 32,
    parameter int AW = 32
)(
    input  logic            i_clk,	// wishbone bus clock = 100MHz
    input  logic            i_reset,	// wishbone bus reset is asserted high

    // Wishbone interface
    input  logic            i_wb_cyc,
    input  logic            i_wb_stb,
    input  logic            i_wb_we,
    input  logic [AW-1:0]   i_wb_addr,
    input  logic [DW-1:0]   i_wb_data,
    input  logic [DW/8-1:0] i_wb_sel,

    output logic            o_wb_ack,
    output logic [DW-1:0]   o_wb_data,

    // 7 segment display controller outputs
    output logic   [ 7:0]  AN,
    output logic           DP,
    output logic   [ 6:0]  Digits_Bits
);

    // define the peripheral registers
    logic [7:0]	    	enables_reg;	// Digit enables, 1 per 7-segment digit
    logic [31:0]	   digits_lo_reg;	// Character codes for display digits[3:0]
    logic [31:0]    	digits_hi_reg;	// Character codes for display digits[7:4
    logic [31:0]	rsvd1_reg;	// *reserved* register 1
    

    // Word index (Wishbone is word-addressed)
    logic [3:0] addr_word;
    assign addr_word = i_wb_addr[5:2];  // 16 MMIO register window (bits[1:0] are byte addresses - handled using i_wb_sel)

    // ------------------------------------------------------------
    // Write logic
    // ------------------------------------------------------------
    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            //enables_reg <= '0;
            //digits_lo_reg <= '0;
            //digits_hi_reg <= '0;
            //rsvd1_reg <= '0;
            
            enables_reg <= 8'h00;
            digits_hi_reg <= 32'b00_0_01110_00_0_01100_00_0_01110_00_1_11111; // ECE<space>, dp[7:4] enabled
            digits_lo_reg <= 32'b00_1_00101_00_1_00100_00_1_00000_00_0_11111; // 540<space>, dp[3:0] enabled
            rsvd1_reg <= 32'hDEADBEEF;
        end else if (i_wb_cyc && i_wb_stb && i_wb_we) begin
            unique case (addr_word)
                4'h0: enables_reg <= apply_sel(enables_reg, i_wb_data, i_wb_sel);
                4'h1: digits_lo_reg <= apply_sel(digits_lo_reg, i_wb_data, i_wb_sel);
                4'h2: digits_hi_reg <= apply_sel(digits_hi_reg, i_wb_data, i_wb_sel);
                4'h3: rsvd1_reg <= apply_sel(rsvd1_reg, i_wb_data, i_wb_sel);
                default: /* ignore writes */;
            endcase
        end
    end

    // ------------------------------------------------------------
    // Read logic
    // ------------------------------------------------------------
    always_comb begin
        unique case (addr_word)
            4'h0: o_wb_data = enables_reg;
            4'h1: o_wb_data = digits_lo_reg;
            4'h2: o_wb_data = digits_hi_reg;
            4'h3: o_wb_data = rsvd1_reg;
            default: o_wb_data = '0;
        endcase
    end

    // ------------------------------------------------------------
    // ACK generation (single-cycle)
    // ------------------------------------------------------------
    always_ff @(posedge i_clk) begin
        if (i_reset)
            o_wb_ack <= 1'b0;
        else
            o_wb_ack <= i_wb_cyc && i_wb_stb;
    end

    // ------------------------------------------------------------
    // 7-segment display controller
    // ------------------------------------------------------------
    logic [7:0] dp;
    assign dp = {digits_hi_reg[29], digits_hi_reg[21], digits_hi_reg[13], digits_hi_reg[5], digits_lo_reg[29], digits_lo_reg[21], digits_lo_reg[13], digits_lo_reg[5]}; 
    
    logic [7:0] dig_bits;
    assign Digits_Bits = dig_bits[6:0];
    assign DP = dig_bits[7];
    
    sevensegment #(
	// parameters
	.CLK_FREQUENCY_HZ(100000000), 
	.REFRESH_FREQUENCY_HZ(500),
	.RESET_POLARITY_LOW(0),
	.CNTR_WIDTH(32),
	
	.SIMULATE(0),
	.SIMULATE_FREQUENCY_CNT(5)
    ) u_sevensegment
    (
	// ports
	.clk(i_clk),			// system clock
	.reset(i_reset),		// system reset signal

	.enables(enables_reg),
	.d0(digits_lo_reg[4:0]),	// digits to be display d[0] is rightmost digit
	.d1(digits_lo_reg[12:8]),
	.d2(digits_lo_reg[20:16]),
	.d3(digits_lo_reg[28:24]),	
	.d4(digits_hi_reg[4:0]),
	.d5(digits_hi_reg[12:8]),
	.d6(digits_hi_reg[20:16]),
	.d7(digits_hi_reg[28:24]),	// digit[7] is leftmost digit
	.dp(dp),			// decimal points to be displayed

	.seg(dig_bits), 	// common cathode outputs to display digits (incl DP)
	.an(AN)				// anode outputs to display digits
    );
    

    // ------------------------------------------------------------
    // Byte-select helper function
    // ------------------------------------------------------------
    function automatic logic [DW-1:0] apply_sel(
        input logic [DW-1:0] old_val,
        input logic [DW-1:0] new_val,
        input logic [DW/8-1:0] sel
    );
        logic [DW-1:0] result;
        result = old_val;

        for (int i = 0; i < DW/8; i++) begin
            if (sel[i])
                result[i*8 +: 8] = new_val[i*8 +: 8];
        end

        return result;
    endfunction

endmodule: wb_sevenseg

