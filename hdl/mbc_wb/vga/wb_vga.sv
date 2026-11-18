/**
 * @file	wb_vga.sv
 * @brief	Top-level Wishbone VGA text-mode peripheral.	
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date	03-May-2026 (removed unused ports/signals)
 * @version	1.2
 *
 * @detail
 * Structural wrapper for the MBV/Wishbone VGA subsystem.
 * Rendering logic is intentionally kept in submodules.
 *
 * Clock domains:
 *   - sysclk : 100 MHz Wishbone / MBV CPU domain
 *   - vgaclk : 25 MHz VGA pixel/rendering domain (640 x 480 @ 60Hz)
 *
 * Reset:
 *   - individual resets for WB/CPU side and VGA side
 *	 - Resets are synchronized in wb_subsystem (asynchronous assertion, synchronous deassertion)
 *
 * VGA output port names match the Nexys4 DDR XDC:
 *   - VGA_R[3:0]	Red, Green and Blue DAC inputs
 *   - VGA_G[3:0]
 *   - VGA_B[3:0]
 *   - VGA_HS		Horizontal sync (asserted low)
 *   - VGA_VS		Vertical sync (asserted low)
 *	 - VGA_VDE		Video Data Enable (video-on) used for HDMI bridge
 */
 // SPDX-License-Identifier: MIT

`default_nettype wire

module wb_vga (

	// clock and reset signals
    input  logic        sysclk,
    input  logic        vgaclk,

    input  logic        sysreset,
    input  logic	vgareset,

    // Wishbone slave interface - sysclk domain
    input  logic        i_wb_cyc,
    input  logic        i_wb_stb,
    input  logic        i_wb_we,
    input  logic [31:0] i_wb_addr,
    input  logic [31:0] i_wb_data,
    input  logic [3:0]  i_wb_sel,

    output logic [31:0] o_wb_data,
    output logic        o_wb_ack,

    // VGA outputs - vgaclk domain
    output logic [3:0]  VGA_R,
    output logic [3:0]  VGA_G,
    output logic [3:0]  VGA_B,
    output logic        VGA_HS,
    output logic        VGA_VS,
    output logic	VGA_VDE
);

    /***** internal signals to connect the module ports *****/

    //--------------------------------------------------------------------------
    // VGA timing generator signals (vgaclk domain)
    //--------------------------------------------------------------------------
    logic [9:0] pix_x;
    logic [9:0] pix_y;
    logic       hsync_tmg;
    logic       vsync_tmg;
    logic       video_on_tmg;

    //--------------------------------------------------------------------------
    // Text address decode signals (vgaclk domain)
    //--------------------------------------------------------------------------
    logic [6:0]  char_col;
    logic [4:0]  char_row;
    logic [2:0]  glyph_x;
    logic [3:0]  glyph_y;
    logic [11:0] text_addr;

    //--------------------------------------------------------------------------
    // Text RAM signals (sysclk and vgaclk domains)
    // The design is CDC-safe because the RAM is implemented as a dual-port
    // RAM w/ two separate clocks, two independent read paths.
    // There is a single write path because the wb/CPU side interface is the only
    // side that writes to the RAM
    //--------------------------------------------------------------------------

    // CPU/wishbone bus interface (sysclk domain)
    logic [15:0]	wb_rd_data;
    logic			wb_wr_en;
    logic [11:0]	wb_addr;
    logic [15:0]  	wb_wr_data;

    // vga interface (vgaclk domain)
    logic [11:0] 	vga_rd_addr;
    logic [15:0]	vga_rd_data;

    //--------------------------------------------------------------------------
    // Font ROM signals (vgaclk domain)
    //--------------------------------------------------------------------------
    logic [7:0] font_char_code;
    logic [3:0] font_glyph_y;
    logic [7:0] glyph_row;

    //--------------------------------------------------------------------------
    // Renderer outputs (vgaclk domain)
	// The Renderer implements the video display pipeline
    //--------------------------------------------------------------------------
    logic text_pixel;
    logic hsync_r;
    logic vsync_r;
    logic video_on_r;

    //--------------------------------------------------------------------------
    // Color/control register outputs (sysclk domain)
    // These originate in the sysclk-domain control block in this version.
    //
    // TODO: If they are written by software and consumed in the vgaclk domain
    // they should be synchronized or updated through a CDC-safe register bridge.
    // Not done currently because the goal is to replace these with dual-port palette
    // RAMs
    //--------------------------------------------------------------------------
    logic [11:0] fg_color;
    logic [11:0] bg_color;

    //--------------------------------------------------------------------------
    // Color mux outputs (vgaclk domain)
    //--------------------------------------------------------------------------
    logic [11:0] rgb;


    /***** Module instantiations *****/

    //--------------------------------------------------------------------------
    // VGA timing generator
    //--------------------------------------------------------------------------

    vga_timing_640x480 u_vga_timing_640x480 (
        .i_clk_pix  (vgaclk),
        .i_rst      (vgareset),

        .o_pix_x    (pix_x),
        .o_pix_y    (pix_y),
        .o_hsync    (hsync_tmg),
        .o_vsync    (vsync_tmg),
        .o_video_on (video_on_tmg)
    );

    //--------------------------------------------------------------------------
    // Pixel-to-text address decoder
    //--------------------------------------------------------------------------

    vga_text_address u_vga_text_address (
        .i_pix_x     (pix_x),
        .i_pix_y     (pix_y),

		/* will be used for cursor control - optional now */
        .o_char_col  (),
        .o_char_row  (),

        .o_glyph_x   (glyph_x),
        .o_glyph_y   (glyph_y),
        .o_text_addr (text_addr)
    );

    //--------------------------------------------------------------------------
    // Text RAM
    //
    // The design is CDC-safe because the RAM is implemented as a dual-port
    // RAM w/ two separate clocks, two independent read paths.
    // There is a single write path because the wb/CPU side interface is the only
    // side that writes to the RAM
    //--------------------------------------------------------------------------

    vga_text_ram u_vga_text_ram (
	// Port A: Wishbone/CPU side (sysclk domain)
	.i_clk_wb	   (sysclk),
        .i_wb_wr_en    (wb_wr_en),
        .i_wb_addr 	   (wb_addr),
        .i_wb_wr_data  (wb_wr_data),
	.o_wb_rd_data  (wb_rd_data),     

	// video read port
	.i_clk_vga     (vgaclk),
        .i_vga_rd_addr (vga_rd_addr),
        .o_vga_rd_data (vga_rd_data)
    );

     //--------------------------------------------------------------------------
     // CP437 8x16 font ROM
     //--------------------------------------------------------------------------

    font_rom u_font_rom (
        .i_clk        (vgaclk),
        .i_char_code  (font_char_code),
        .i_glyph_y    (font_glyph_y),
        .o_glyph_row  (glyph_row)
    );

    //--------------------------------------------------------------------------
    // Text renderer pipeline
    //--------------------------------------------------------------------------

    vga_text_renderer u_vga_text_renderer (
        .i_clk             (vgaclk),
        .i_rst             (vgareset),

        // timing signals
        .i_hsync           (hsync_tmg),
        .i_vsync           (vsync_tmg),
        .i_video_on        (video_on_tmg),

        // decoded text coordinates
        .i_glyph_x         (glyph_x),
        .i_glyph_y         (glyph_y),
        .i_text_addr       (text_addr),

        // vga Text RAM interface
        .o_text_rd_addr    (vga_rd_addr),
        .i_text_cell	   (vga_rd_data),

        // font ROM interface
        .o_font_char_code  (font_char_code),
        .o_font_glyph_y    (font_glyph_y),
        .i_glyph_row       (glyph_row),

        // aligned outputs
        .o_text_pixel      (text_pixel),
        .o_hsync           (hsync_r),
        .o_vsync           (vsync_r),
        .o_video_on        (video_on_r)
    );

    //--------------------------------------------------------------------------
    // Final color mux
    //--------------------------------------------------------------------------

    vga_color_mux u_vga_color_mux (
        .i_video_on   (video_on_r),
        .i_text_pixel (text_pixel),

        .i_fg_color   (fg_color),
        .i_bg_color   (bg_color),

        .o_rgb        (rgb)
    );

    //--------------------------------------------------------------------------
    // Wishbone VGA control/register block - sysclk domain
    //--------------------------------------------------------------------------

    wb_vga_ctrl u_wb_vga_ctrl (
        .i_clk          (sysclk),
        .i_rst          (sysreset),

        // Wishbone slave interface
        .i_wb_cyc       (i_wb_cyc),
        .i_wb_stb       (i_wb_stb),
        .i_wb_we        (i_wb_we),
        .i_wb_addr      (i_wb_addr),
        .i_wb_data      (i_wb_data),
        .i_wb_sel       (i_wb_sel),

        .o_wb_data      (o_wb_data),
        .o_wb_ack       (o_wb_ack),

        // text RAM CPU interface (sysclk domain)
        .o_txt_wr_en    (wb_wr_en),
        .o_txt_addr  (wb_addr),
        .o_txt_wr_data  (wb_wr_data),
        .i_txt_rd_data  (wb_rd_data),

        // color registers (temp - will be replaced w/ palette RAM)
        .o_fg_color     (fg_color),
        .o_bg_color     (bg_color)
    );

    //--------------------------------------------------------------------------
    // VGA physical output assignments
    //
    // rgb[11:8] = red
    // rgb[7:4]  = green
    // rgb[3:0]  = blue
    //--------------------------------------------------------------------------

    assign VGA_R  = rgb[11:8];
    assign VGA_G  = rgb[7:4];
    assign VGA_B  = rgb[3:0];
    assign VGA_HS = hsync_r;
    assign VGA_VS = vsync_r;
    assign VGA_VDE = video_on_r;

endmodule: wb_vga
