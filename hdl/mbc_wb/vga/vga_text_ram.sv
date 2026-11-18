/**
 * @file vga_text_ram.sv
 * @brief Dual-clock text RAM for VGA text-mode display.
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date	29-Apr-2026
 * @version	1.0
 * 
 * @detail
 * Text geometry:
 *   80 columns × 30 rows = 2400 text cells
 *
 * Text cell format:
 *   bits [7:0]   = character code
 *   bits [11:8]  = foreground palette index
 *   bits [15:12] = background palette index
 *
 * Port A:
 *   Wishbone / CPU side
 *   clocked by sysclk
 *   read/write
 *
 * Port B:
 *   VGA renderer side
 *   clocked by vgaclk
 *   read-only
 *
 * This RAM is the primary CDC boundary between the Wishbone system clock
 * domain and the VGA pixel clock domain.
 */
// SPDX-License-Identifier: MIT

`default_nettype wire

module vga_text_ram #(
    parameter int DEPTH = 2400,
    parameter int AW    = 12,
    parameter string INIT_FILE = "vga_text_init.mem"
) (
    //--------------------------------------------------------------------------
    // Port A: Wishbone / CPU side, sysclk domain
    //--------------------------------------------------------------------------

    input  logic          i_clk_wb,

    input  logic          i_wb_wr_en,
    input  logic [AW-1:0] i_wb_addr,
    input  logic [15:0]   i_wb_wr_data,
    output logic [15:0]   o_wb_rd_data,

    //--------------------------------------------------------------------------
    // Port B: VGA renderer side, vgaclk domain
    //--------------------------------------------------------------------------

    input  logic          i_clk_vga,

    input  logic [AW-1:0] i_vga_rd_addr,
    output logic [15:0]   o_vga_rd_data
);

    //--------------------------------------------------------------------------
    // Default cell value
    //
    // 16'h0F20:
    //   bg = 0
    //   fg = F
    //   char = 0x20, space
    //--------------------------------------------------------------------------

    localparam logic [15:0] DEFAULT_CELL = 16'h0F20;

    //--------------------------------------------------------------------------
    // RAM storage
    //--------------------------------------------------------------------------

    (* ram_style = "block" *)
    logic [15:0] mem [0:DEPTH-1];

    //--------------------------------------------------------------------------
    // Optional initialization
    //--------------------------------------------------------------------------

    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    //--------------------------------------------------------------------------
    // Port A: Wishbone / CPU read-write port
    //
    // Read behavior:
    //   registered synchronous read
    //
    // Write behavior:
    //   write occurs on rising edge when i_wb_wr_en is asserted
    //
    // Read-during-write to same address:
    //   implementation-dependent old/new data behavior is acceptable for this
    //   text display use case.
    //--------------------------------------------------------------------------

    always_ff @(posedge i_clk_wb) begin
        if (i_wb_addr < DEPTH) begin
            if (i_wb_wr_en) begin
                mem[i_wb_addr] <= i_wb_wr_data;
            end

           o_wb_rd_data <= mem[i_wb_addr];
           
 // temporarily return the computed RAM address on reads
 // o_wb_rd_data <= {16'h0000, i_wb_addr};
        end
        else begin
            o_wb_rd_data <= DEFAULT_CELL;
        end
    end

    //--------------------------------------------------------------------------
    // Port B: VGA renderer read-only port
    //
    // Read behavior:
    //   registered synchronous read
    //
    // The renderer pipeline must account for this one-cycle read latency.
    //--------------------------------------------------------------------------

    always_ff @(posedge i_clk_vga) begin
        if (i_vga_rd_addr < DEPTH) begin
            o_vga_rd_data <= mem[i_vga_rd_addr];
        end
        else begin
            o_vga_rd_data <= DEFAULT_CELL;
        end
    end

endmodule: vga_text_ram
