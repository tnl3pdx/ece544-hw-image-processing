/**
 * @file	vga_color_mux.sv
 * @brief	Final RGB color selector for VGA text-mode output.
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date	29-Apr-2026
 * @version	1.0
 *
 * @detail
 * This module selects the final 12-bit RGB pixel value from:
 *   - video_on
 *   - text pixel bit
 *   - foreground color
 *   - background color
 *
 * Color format:
 *   rgb[11:8] = red
 *   rgb[7:4]  = green
 *   rgb[3:0]  = blue
 *
 * Behavior:
 *   if video_on == 0:
 *       output black
 *   else if text_pixel == 1:
 *       output foreground color
 *   else:
 *       output background color
 *
 * Notes:
 *   - Pure combinational logic.
 *   - Inputs should already be pipeline-aligned by vga_text_renderer.
 */
// SPDX-License-Identifier: MIT

`default_nettype wire

module vga_color_mux (
    input  logic        i_video_on,
    input  logic        i_text_pixel,

    input  logic [11:0] i_fg_color,
    input  logic [11:0] i_bg_color,

    output logic [11:0] o_rgb
);

    always_comb begin
        if (!i_video_on) begin
            o_rgb = 12'h000;
        end
        else if (i_text_pixel) begin
            o_rgb = i_fg_color;
        end
        else begin
            o_rgb = i_bg_color;
        end
    end

endmodule: vga_color_mux
