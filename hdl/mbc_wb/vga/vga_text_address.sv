/**
 * @file	vga_text_address.sv
 * @brief	Pixel-to-text-cell address decoder for 80x30 VGA text mode.
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date	03-May-2026
 * @version	1.2
 *
 * @detail
 * Font geometry:
 *   8 pixels wide × 16 pixels tall
 *
 * Screen geometry:
 *   640 / 8  = 80 text columns
 *   480 / 16 = 30 text rows
 *
 * Inputs:
 *   i_pix_x : pixel x coordinate from timing generator
 *   i_pix_y : pixel y coordinate from timing generator
 *
 * Outputs:
 *   o_char_col  : text column, 0..79	// optional cursor control
 *   o_char_row  : text row, 0..29		// optional cursor control
 *   o_glyph_x   : x coordinate within glyph, 0..7
 *   o_glyph_y   : y coordinate within glyph, 0..15
 *   o_text_addr : linear text RAM cell address, row-major
 *
 * Address formula:
 *   o_text_addr = (o_char_row * 80) + o_char_col
 */
// SPDX-License-Identifier: MIT

`default_nettype wire

module vga_text_address (
    input  logic [9:0]  i_pix_x,
    input  logic [9:0]  i_pix_y,

    output logic [6:0]  o_char_col,
    output logic [4:0]  o_char_row,

    output logic [2:0]  o_glyph_x,
    output logic [3:0]  o_glyph_y,
    output logic [11:0] o_text_addr
);

    //--------------------------------------------------------------------------
    // Coordinate conversion
    //--------------------------------------------------------------------------

    always_comb begin
        // 8-pixel-wide glyphs
        o_char_col = i_pix_x[9:3];   // divide by 8
        o_glyph_x  = i_pix_x[2:0];   // mod 8

        // 16-pixel-tall glyphs
        o_char_row = i_pix_y[8:4];   // divide by 16
        o_glyph_y  = i_pix_y[3:0];   // mod 16

        // text_addr = row * 80 + col
        //
        // 80 = 64 + 16, so avoid a multiplier:
        // row * 80 = (row << 6) + (row << 4)
        o_text_addr = ({7'b0, o_char_row} << 6) +
                      ({7'b0, o_char_row} << 4) +
                      {5'b0, o_char_col};
    end

endmodule: vga_text_address
