/**
 * @file vga_timing_640x480.sv
 * @brief VGA timing generator for 640x480 @ 60 Hz.
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date	29-Apr-2026
 * @version	1.0
 *
 * @detail
 * Horizontal timing:
 *   active video : 640 pixels
 *   front porch  : 16 pixels
 *   sync pulse   : 96 pixels
 *   back porch   : 48 pixels
 *   total        : 800 pixels
 *
 * Vertical timing:
 *   active video : 480 lines
 *   front porch  : 10 lines
 *   sync pulse   : 2 lines
 *   back porch   : 33 lines
 *   total        : 525 lines
 *
 * Outputs:
 *   o_pix_x    : active-region x coordinate, 0..639
 *   o_pix_y    : active-region y coordinate, 0..479
 *   o_hsync    : active-low horizontal sync
 *   o_vsync    : active-low vertical sync
 *   o_video_on : high during active video region
 *
 * Notes:
 *   - Counters continue through the full 800x525 timing frame.
 *   - o_pix_x/o_pix_y are only meaningful when o_video_on is high.
 *   - Syncs are generated active-low for standard VGA.

 * @note Timing assumes a 25 MHz pixel clock.
 */
// SPDX-License-Identifier: MIT

`default_nettype wire

module vga_timing_640x480 (
    input  logic        i_clk_pix,
    input  logic        i_rst,

    output logic [9:0]  o_pix_x,
    output logic [9:0]  o_pix_y,
    output logic        o_hsync,
    output logic        o_vsync,
    output logic        o_video_on
);

    //--------------------------------------------------------------------------
    // VGA 640x480 @ 60 Hz timing constants
    //--------------------------------------------------------------------------

    localparam int H_ACTIVE = 640;
    localparam int H_FP     = 16;
    localparam int H_SYNC   = 96;
    localparam int H_BP     = 48;
    localparam int H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;

    localparam int V_ACTIVE = 480;
    localparam int V_FP     = 10;
    localparam int V_SYNC   = 2;
    localparam int V_BP     = 33;
    localparam int V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;

    localparam int H_SYNC_START = H_ACTIVE + H_FP;
    localparam int H_SYNC_END   = H_ACTIVE + H_FP + H_SYNC;

    localparam int V_SYNC_START = V_ACTIVE + V_FP;
    localparam int V_SYNC_END   = V_ACTIVE + V_FP + V_SYNC;

    //--------------------------------------------------------------------------
    // Counters
    //--------------------------------------------------------------------------

    logic [9:0] h_count;
    logic [9:0] v_count;

    //--------------------------------------------------------------------------
    // Horizontal and vertical counters
    //--------------------------------------------------------------------------

    always_ff @(posedge i_clk_pix) begin
        if (i_rst) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end
        else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;

                if (v_count == V_TOTAL - 1) begin
                    v_count <= 10'd0;
                end
                else begin
                    v_count <= v_count + 10'd1;
                end
            end
            else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Timing outputs
    //--------------------------------------------------------------------------

    always_comb begin
        o_video_on = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);

        o_pix_x = h_count;
        o_pix_y = v_count;

        // Standard VGA syncs are asserted low
        o_hsync = ~((h_count >= H_SYNC_START) && (h_count < H_SYNC_END));
        o_vsync = ~((v_count >= V_SYNC_START) && (v_count < V_SYNC_END));
    end

endmodule: vga_timing_640x480
