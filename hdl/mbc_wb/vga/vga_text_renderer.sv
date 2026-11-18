/**
 * @file    vga_text_renderer.sv
 * @brief   VGA text-mode renderer pipeline.
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date    03_May-2026
 * @version 1.2 (removed unused ports)
 *
 * @detail
 * This module converts text RAM cells and font ROM rows into a 1-bit text
 * pixel stream.
 *
 * Pipeline contract:
 *
 *   The text RAM and font ROM are both synchronous registered-output memories.
 *   Therefore each memory contributes one clock cycle of latency.
 *
 *   To avoid hidden request-register latency, this renderer drives memory
 *   request addresses combinationally:
 *
 *       o_text_rd_addr   = i_text_addr
 *       o_font_char_code = i_text_cell[7:0]
 *       o_font_glyph_y   = glyph_y_s1
 *
 *   The renderer only registers sideband/control signals so they remain aligned
 *   with the memory data as it returns.
 *
 * Pipeline timing:
 *
 *   Cycle N, after clock edge:
 *       text RAM output i_text_cell corresponds to i_text_addr captured by
 *       the text RAM at that clock edge.
 *
 *       glyph_x_s1/glyph_y_s1/hsync_s1/vsync_s1/video_on_s1 correspond to
 *       that same pixel.
 *
 *       The font ROM address is driven combinationally from:
 *           i_text_cell[7:0] and glyph_y_s1
 *
 *   Cycle N+1, after clock edge:
 *       font ROM output i_glyph_row corresponds to the character/glyph_y from
 *       Cycle N.
 *
 *       glyph_x_s2/hsync_s2/vsync_s2/video_on_s2 correspond to that same pixel.
 *
 *       The final text pixel is selected combinationally:
 *           i_glyph_row[7 - glyph_x_s2]
 *
 * Text cell format:
 *   bits [15:12] = background palette index, future use
 *   bits [11:8]  = foreground palette index, future use
 *   bits [7:0]   = character code
 *
 * Font row convention:
 *   glyph_row[7] = leftmost pixel
 *   glyph_row[0] = rightmost pixel
 */
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps
`default_nettype wire

module vga_text_renderer (
    input  logic        i_clk,
    input  logic        i_rst,

    // timing signals
    input  logic        i_hsync,
    input  logic        i_vsync,
    input  logic        i_video_on,

    // decoded text coordinates
    input  logic [2:0]  i_glyph_x,
    input  logic [3:0]  i_glyph_y,
    input  logic [11:0] i_text_addr,

    // text RAM interface
    output logic [11:0] o_text_rd_addr,
    input  logic [15:0] i_text_cell,

    // font ROM interface
    output logic [7:0]  o_font_char_code,
    output logic [3:0]  o_font_glyph_y,
    input  logic [7:0]  i_glyph_row,

    // aligned outputs
    output logic        o_text_pixel,
    output logic        o_hsync,
    output logic        o_vsync,
    output logic        o_video_on
);

    //--------------------------------------------------------------------------
    // Stage 1 sideband registers
    //
    // These align with the text RAM output i_text_cell after the text RAM
    // synchronous read latency.
    //--------------------------------------------------------------------------

    logic [2:0] glyph_x_s1;
    logic [3:0] glyph_y_s1;
    logic       hsync_s1;
    logic       vsync_s1;
    logic       video_on_s1;

    //--------------------------------------------------------------------------
    // Stage 2 sideband registers
    //
    // These align with the font ROM output i_glyph_row after the font ROM
    // synchronous read latency.
    //--------------------------------------------------------------------------

    logic [2:0] glyph_x_s2;
    logic       hsync_s2;
    logic       vsync_s2;
    logic       video_on_s2;

    //--------------------------------------------------------------------------
    // Combinational memory request outputs
    //
    // Do not register these requests here. The RAM/ROM modules already register
    // their outputs. Registering the requests here would add hidden latency and
    // make sideband alignment harder to reason about.
    //--------------------------------------------------------------------------

    assign o_text_rd_addr   = i_text_addr;

    assign o_font_char_code = i_text_cell[7:0];
    assign o_font_glyph_y   = glyph_y_s1;

    //--------------------------------------------------------------------------
    // Pipeline sideband alignment
    //--------------------------------------------------------------------------

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            glyph_x_s1  <= 3'd0;
            glyph_y_s1  <= 4'd0;
            hsync_s1    <= 1'b1;
            vsync_s1    <= 1'b1;
            video_on_s1 <= 1'b0;

            glyph_x_s2  <= 3'd0;
            hsync_s2    <= 1'b1;
            vsync_s2    <= 1'b1;
            video_on_s2 <= 1'b0;
        end
        else begin
            //------------------------------------------------------------------
            // Stage 1:
            // Align current pixel sideband with the text RAM data that appears
            // after the text RAM samples o_text_rd_addr.
            //------------------------------------------------------------------

            glyph_x_s1  <= i_glyph_x;
            glyph_y_s1  <= i_glyph_y;
            hsync_s1    <= i_hsync;
            vsync_s1    <= i_vsync;
            video_on_s1 <= i_video_on;

            //------------------------------------------------------------------
            // Stage 2:
            // Align sideband with the font ROM row that appears after the font
            // ROM samples o_font_char_code/o_font_glyph_y.
            //------------------------------------------------------------------

            glyph_x_s2  <= glyph_x_s1;
            hsync_s2    <= hsync_s1;
            vsync_s2    <= vsync_s1;
            video_on_s2 <= video_on_s1;
        end
    end

    //--------------------------------------------------------------------------
    // Final pixel generation
    //
    // The font row and glyph_x_s2 are aligned during the same cycle.
    // The color mux will still gate the final RGB output with o_video_on, but
    // gating text_pixel here keeps inactive pixels quiet in simulation.
    //--------------------------------------------------------------------------

    always_comb begin
        o_hsync    = hsync_s2;
        o_vsync    = vsync_s2;
        o_video_on = video_on_s2;

        if (video_on_s2) begin
            o_text_pixel = i_glyph_row[3'd7 - glyph_x_s2];
        end
        else begin
            o_text_pixel = 1'b0;
        end
    end

endmodule: vga_text_renderer

