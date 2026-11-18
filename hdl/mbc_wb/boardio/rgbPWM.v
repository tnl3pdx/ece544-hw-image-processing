/**
 * @file	rgbPWM_r2.v
 * @brief	Implements a 3-channel PWM circuit to control an RGB LED
 *
 * @author  Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date		21-Feb-2026
 * @version		2.0
 *
 * @detail
 * Implements a 3 channel general purpose PWM circuit. The PWM clock can be provided two ways.  
 * First is to connect the system clock on the clock input and select the clock divider input.  The second way is to bring a clock from a
 * programmable timer that directly controls the PWM clock.
 *
 * @note
 * The design is implemented in Verilog 2001 instead of SystemVerilog because Vivado does not directly support
 * inclusion of SystemVerilog modules as RTL modules in the IP Integrator.A workaround would be to develop the RTL modules in SystemVerilog and then
 * wrap them in a Verilog 2001 "wrapper." 
 * 
 * @note
 * Modified to make counter available as a peripheral register.  Yes,  this likely isn't overly useful but for debug
 * it'd be good to know if the counter is counting properly.
 *
 * @note
 * Changed polarity of reset to asserted high to match reset in a wishbone bus system
 */
 // SPDX-License-Identifier: MIT
 
 module rgbPWM
#(
	parameter USE_DIVIDER = 1'b0,		// 1 to enable clock divider.  0 to provide a direct clock
	parameter DIVIDE_COUNT = 500,		// Clock divider terminal count
	
	parameter POLARITY = 1'b1,		// 1 to drive PWM output high when active.  0 to invert the PWM output
	parameter MAX_COUNT = 256		// maximum count for the PWM counters
)
(
	input wire 		clk,		// input clock	
	input wire 		reset,		// reset signal - asserted HIGH to reset circuit
	input wire [31:0]	controlReg,	// control register - duty cycle and enable bit
	
	// PWM outputs
	output wire 		rgbRED,
	output wire 		rgbGREEN,
	output wire 		rgbBLUE,
	// Debug signals
	output wire		clkPWM,      // PWM counter clock
	output wire [31:0]  	pwmcount     // PWM counter value
);

    reg [31:0] clk_div_cnt;
    reg [31:0] count;
    reg pwm_tick;

    // Clock Divider / Enable Generator
    always @(posedge clk) begin
        if (reset) begin
            clk_div_cnt <= 32'd0;
            pwm_tick <= 1'b0;
        end else if (USE_DIVIDER) begin
            if (clk_div_cnt >= (DIVIDE_COUNT - 1)) begin
                clk_div_cnt <= 32'd0;
                pwm_tick <= 1'b1;
            end else begin
                clk_div_cnt <= clk_div_cnt + 1'b1;
                pwm_tick <= 1'b0;
            end
        end else begin
            pwm_tick <= 1'b1; // No divider used
        end
    end

    // PWM Counter (8-bit resolution)
    always @(posedge clk) begin
        if (reset) begin
            count <= 32'd0;
        end else if (pwm_tick) begin
            count <= (count >= (MAX_COUNT - 1)) ? 32'd0 : count + 1'b1;
        end
    end

    // Simplified PWM Logic (8-bit slices)
    // Map: {Enable[31], Reserved, Red[23:16], Green[15:8], Blue[7:0]}
    wire [7:0] r_duty = controlReg[23:16];
    wire [7:0] g_duty = controlReg[15:8];
    wire [7:0] b_duty = controlReg[7:0];
    wire       en     = controlReg[31];

    assign rgbRED   = en ? (POLARITY ? (count < r_duty) : ~(count < r_duty)) : !POLARITY;
    assign rgbGREEN = en ? (POLARITY ? (count < g_duty) : ~(count < g_duty)) : !POLARITY;
    assign rgbBLUE  = en ? (POLARITY ? (count < b_duty) : ~(count < b_duty)) : !POLARITY;

    // Compatibility outputs
    assign clkPWM = pwm_tick;
    assign pwmcount = count;

endmodule

