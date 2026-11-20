/**
 * @file	mbc_wb_nexys4DDR.sv
 * @brief	Top level for the Microblaze Classic + wishbone SoC targeted for Nexys4 DDR board
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date	15-July-2026
 * @version	1.0
 *
 * @detail
 * This is the top level module that instantiates the embedded system (embsys) and the wishbone bus subystem and connects the signals 
 * to the FPGA pins on the Nexys4 DDR board.  This version does not include SDRAM but has 128KB of BRAM for program memory.
 */
 // SPDX-License-Identifier: MIT
 
module mbc_wb_nexys4DDR (
    input  wire        CLK100MHZ,

    // Buttons and switches
    input wire 		CPU_RESETN,
    input wire		BTNC,
    input wire		BTNU,
    input wire		BTNL,
    input wire		BTNR,
    input wire		BTND,
    input  wire [15:0] 	SW,
    
    // LEDs
    output wire [15:0]	LED,

    // RGB LEDs
    output wire 	LED16_B,
    output wire 	LED16_G,
    output wire 	LED16_R,
    
    output wire 	LED17_B,
    output wire 	LED17_G,
    output wire 	LED17_R,

    // 7‑segment display
    output wire		CA,
    output wire		CB,
    output wire		CC,
    output wire		CD,
    output wire		CE,
    output wire		CF,
    output wire		CG,
    output wire		DP,   
    output wire [0:7]   AN,

    // VGA controller
    output [3:0]	VGA_R,
    output [3:0]	VGA_G,
    output [3:0]	VGA_B,
    output 		VGA_HS,
    output		VGA_VS,

    // UART
    output wire        UART_RXD_OUT,
    input  wire        UART_TXD_IN,
    
    // DDR Signals
    output wire [12:0]DDR2_0_addr,
    output wire [2:0]DDR2_0_ba,
    output wire DDR2_0_cas_n,
    output wire [0:0]DDR2_0_ck_n,
    output wire [0:0]DDR2_0_ck_p,
    output wire [0:0]DDR2_0_cke,
    output wire [0:0]DDR2_0_cs_n,
    output wire [1:0]DDR2_0_dm,
    inout wire [15:0]DDR2_0_dq,
    inout wire [1:0]DDR2_0_dqs_n,
    inout wire [1:0]DDR2_0_dqs_p,
    output wire [0:0]DDR2_0_odt,
    output wire DDR2_0_ras_n,
    output wire DDR2_0_we_n
);

    // -----------------------DDR2_0_addr-------------------------------------
    // Clock and Reset logic - active‑low reset)
    // ------------------------------------------------------------
    wire sysclk;		// 100MHz in this configuration
    wire vgaclk; 		// 25MHz in this configuration 
    wire refclk;        // 200MHz in this configuration
    wire locked;		// PLL locked from clock generator
    wire m_wb_reset;	// Wishbone bus reset from AXI/Wishbone bus bridge 

    wire sysreset_n = CPU_RESETN & locked;
    wire wb_reset = ~sysreset_n | m_wb_reset;	// Wishbone bus reset is asserted high
      
    // ------------------------------------------------------------
    // System Clock
    // ------------------------------------------------------------  
    clk_wiz_0 u_clkgen
   (
    .clk_out1(sysclk),		// 100MHz for CPU, AXI, and WB
    .clk_out2(vgaclk),		// 25MHz for 640 x 480 x 60Hz
    .clk_out3(refclk),      // 200 MHz for DDR
    .resetn(CPU_RESETN),
    .locked(locked),
    .clk_in1(CLK100MHZ)
    );
    
    // ------------------------------------------------------------
    // wb_subsystem debug port (if needed) - Normally left unconnected
    // -----------------------------------------------------------
    wire [31:0] wb_debug;
    
 
    /*********** debug/bring-up options **********/
    // test LEDs, switches, buttons totally in hardware
    //assign LED = {SW[15:5], (SW[4:0] & BTNS)};
    
    // UartLite debug - use LED[15] to show UART_RXD_Out
    //assign LED = {UART_RXD_OUT, LED[14:0]};
    
    // ------------------------------------------------------------
    // Swizzle for the 5 pushbuttons on the Nexys A7 (Nexys4 DDR) board
    wire [4:0] btns_raw;
    assign btns_raw = {BTNC, BTNU, BTND, BTNL, BTNR};
    
    // ------------------------------------------------------------
    // Swizzle for the RGB LEDs to match constraints file
    // -----------------------------------------------------------
    wire [2:0] RGB0_raw, RGB1_raw;

    // rgbled periphral outputs: {RED, GREEN, BLUE};
    assign {LED16_R, LED16_G, LED16_B} = {RGB0_raw[2], RGB0_raw[1], RGB0_raw[0]};
    assign {LED17_R, LED17_G, LED17_B} = {RGB1_raw[2], RGB1_raw[1], RGB1_raw[0]};


    // ------------------------------------------------------------
    // Swizzle for Nexys4 DDR single 8-digit display 7-segment display 
    // ------------------------------------------------------------   
    wire [6:0] seg_raw;   // g..a
    wire       dp_raw;    // decimal point
    wire [7:0] an_raw;    // 8 anodes for 8 digits
    
    // 7‑segment raw signals from wb_subsystem
    // an_raw[7:4] → D0_AN (upper display) or upper digits for Nexys4 DDR
    // an_raw[3:0] → D1_AN (lower display) or lower digits for Nexys4 DDR
    
    // Anodes, AN[7] - leftmost digit, AN[0] rightmost digit
    assign {AN[7], AN[6], AN[5], AN[4]} = {an_raw[7], an_raw[6], an_raw[5], an_raw[4]};
    assign {AN[3], AN[2], AN[1], AN[0]} = {an_raw[3], an_raw[2], an_raw[1], an_raw[0]};
    
    // Segment pattern: wb_sevenseg:  (g..a),  constraints: (g..a)
    assign {CG, CF, CE, CD, CC, CB, CA} = seg_raw;
    assign DP = dp_raw;


    // ------------------------------------------------------------
    // Wishbone bus signals between axilit2wbsp bridge and our
    // wb_subsystem
    // ------------------------------------------------------------
    wire m_wb_cyc, m_wb_stb, m_wb_we, m_wb_ack, m_wb_err;
    wire [25:0] m_wb_adr; // word addressed
    wire [31:0] m_wb_dat_w, m_wb_dat_r;
    wire [3:0]  m_wb_sel;
    wire m_wb_stall;  // not generated in this wb_subsystem
    wire wb_irq0, wb_irq1;
    assign m_wb_stall = 1'b0;
    assign m_wb_err = 1'b0;
    
    // turn the word_aligned wb address into the byte aligned address the wb peripherals expect
    logic [31:0] wb_byte_addr;
    assign wb_byte_addr = {4'b0000, m_wb_adr, 2'b00};


    // ------------------------------------------------------------
    // Instantiate the embedded system (embsys)
    // ------------------------------------------------------------        
    mbc_wb_embsys u_embsys (
        // system clock and reset
        .sysclk(sysclk),
        .refclk(refclk),
        .sysreset_n(sysreset_n),
        
        // UARTLite connections
        .uart_rtl_0_rxd(UART_TXD_IN),	    // FT2232 output, FPGA input
        .uart_rtl_0_txd(UART_RXD_OUT),	// FT2232 input, FPGA output 
  
        // Wishbone bus connections
        .m_wb_ack_0(m_wb_ack),
        .m_wb_adr_0(m_wb_adr),
        .m_wb_cyc_0(m_wb_cyc),
        .m_wb_dat_r_0(m_wb_dat_r),
        .m_wb_dat_w_0(m_wb_dat_w),
        .m_wb_err_0(m_wb_err),
        .m_wb_reset_0(m_wb_reset),
        .m_wb_sel_0(m_wb_sel),
        .m_wb_stall_0(m_wb_stall),
        .m_wb_stb_0(m_wb_stb),
        .m_wb_we_0(m_wb_we),
        
        // Wishbone interrupt inputs to embedded system Interrupt controller
        .wb_irq0(wb_irq0),
        .wb_irq1(wb_irq1),
        
        // DDR Signals
        .DDR2_0_addr(DDR2_0_addr),
        .DDR2_0_ba(DDR2_0_ba),
        .DDR2_0_cas_n(DDR2_0_cas_n),
        .DDR2_0_ck_n(DDR2_0_ck_n),
        .DDR2_0_ck_p(DDR2_0_ck_p),
        .DDR2_0_cke(DDR2_0_cke),
        .DDR2_0_cs_n(DDR2_0_cs_n),
        .DDR2_0_dm(DDR2_0_dm),
        .DDR2_0_dq(DDR2_0_dq),
        .DDR2_0_dqs_n(DDR2_0_dqs_n),
        .DDR2_0_dqs_p(DDR2_0_dqs_p),
        .DDR2_0_odt(DDR2_0_odt),
        .DDR2_0_ras_n(DDR2_0_ras_n),
        .DDR2_0_we_n(DDR2_0_we_n)
     );
    
       
    // ------------------------------------------------------------
    // Instantiate the interface to all WB peripherals
    // ------------------------------------------------------------

    wb_subsystem u_wb_subsystem (
    	// clock and reset for the wishbone bus peripherals
    	.i_clk(sysclk),
    	.i_reset(wb_reset),	

	// clock and reset for vga controller
	.i_clk_vga(vgaclk),
	.i_reset_vga(wb_reset),

    	// Wishbone master interface (from axil2wbsp)
    	.i_wb_cyc(m_wb_cyc),
    	.i_wb_stb(m_wb_stb),
    	.i_wb_we(m_wb_we),
    	.i_wb_addr(wb_byte_addr),
    	.i_wb_data(m_wb_dat_w),
    	.i_wb_sel(m_wb_sel),  
	.o_wb_ack(m_wb_ack),
    	.o_wb_data(m_wb_dat_r),

    	// Optional IRQs from peripherals
    	.o_irq0(wb_irq0),
    	.o_irq1(wb_irq1),

    	// Board I/O - Buttons switches, leds, RGB LEDs
    	.btns(btns_raw),
    	.sw(SW),
    	.leds(LED),
    	.rgb1RGB(RGB0_raw),
    	.rgb2RGB(RGB1_raw),

	// 7 segment display controller outputs
    	.AN(an_raw),
    	.DP(dp_raw),
    	.Digits_Bits(seg_raw),

		// VGA controller outputs
		.VGA_R(VGA_R),
		.VGA_G(VGA_G),
		.VGA_B(VGA_B),
		.VGA_HS(VGA_HS),
		.VGA_VS(VGA_VS),
		.VGA_VDE(),	// used w/ VGA-HDMI bridge
    	
    	// debug outputs
    	.wb_debug()		// normally unconnected
   );      

endmodule: mbc_wb_nexys4DDR

