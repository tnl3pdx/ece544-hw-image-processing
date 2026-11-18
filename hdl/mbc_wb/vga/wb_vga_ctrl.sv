/**
 * @file    wb_vga_ctrl.sv
 * @brief   Wishbone control interface for VGA text-mode peripheral.
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date	29-Apr-2026
 * @version	1.0
 *
 * @details
 * Important:
 *   The AXI-Lite to Wishbone bridge presents a WORD address to Wishbone.
 *   Therefore all local address constants in this module are WORD offsets,
 *   not byte offsets.
 *
 * VGA byte map:
 *   0x0000 - 0x12BF : text RAM window
 *   0x2000 - 0x203F : palette window, future
 *   0x3000          : VGA_CTRL, future
 *   0x3004          : VGA_CURSOR, future
 *   0x3010          : FG_COLOR
 *   0x3014          : BG_COLOR
 *
 * VGA local Wishbone word map:
 *   0x0000 - 0x04AF : text RAM window, two 16-bit cells per word
 *   0x0800 - 0x080F : palette window, future
 *   0x0C00          : VGA_CTRL, future
 *   0x0C01          : VGA_CURSOR, future
 *   0x0C04          : FG_COLOR
 *   0x0C05          : BG_COLOR
 */
// SPDX-License-Identifier: MIT

`default_nettype wire

module wb_vga_ctrl (
    input  logic        i_clk,
    input  logic        i_rst,

    // Wishbone slave interface
    input  logic        i_wb_cyc,
    input  logic        i_wb_stb,
    input  logic        i_wb_we,
    input  logic [31:0] i_wb_addr,   // WORD address from AXI-Lite/WB bridge
    input  logic [31:0] i_wb_data,
    input  logic [3:0]  i_wb_sel,

    output logic [31:0] o_wb_data,
    output logic        o_wb_ack,

    // Text RAM CPU interface, sysclk domain
    output logic        o_txt_wr_en,
    output logic [11:0] o_txt_addr,
    output logic [15:0] o_txt_wr_data,
    input  logic [15:0] i_txt_rd_data,

    // Temporary fallback colors until palette RAM is fully wired in
    output logic [11:0] o_fg_color,
    output logic [11:0] o_bg_color
);

    //--------------------------------------------------------------------------
    // Local word-addressed map
    //--------------------------------------------------------------------------

    localparam logic [13:0] TEXT_FIRST_WORD = 14'h0000;
    localparam logic [13:0] TEXT_LAST_WORD  = 14'h04AF; // 1200 words - 1

    localparam logic [13:0] PAL_FIRST_WORD  = 14'h0800;
    localparam logic [13:0] PAL_LAST_WORD   = 14'h080F;

    localparam logic [13:0] REG_VGA_CTRL    = 14'h0C00;
    localparam logic [13:0] REG_VGA_CURSOR  = 14'h0C01;
    localparam logic [13:0] REG_FG_COLOR    = 14'h0C04;
    localparam logic [13:0] REG_BG_COLOR    = 14'h0C05;

    typedef enum logic [2:0] {
        S_IDLE,
        S_TEXT_WR_HI,
        S_TEXT_RD_LO,
        S_TEXT_RD_HI,
        S_ACK
    } state_t;

    state_t state;
    state_t next_state;

    logic [13:0] local_word_addr;
    logic        wb_access;
    logic        text_region_hit;
    logic        palette_region_hit;

    logic [11:0] cell_base_addr;
    logic [11:0] saved_cell_base_addr;

    logic        lower_cell_write;
    logic        upper_cell_write;
    logic [15:0] saved_hi_wr_data;

    logic [15:0] text_rd_lo;

    logic [11:0] fg_color_reg;
    logic [11:0] bg_color_reg;

    //--------------------------------------------------------------------------
    // Address decode
    //
    // The VGA slot is 64 KB bytes = 16K 32-bit words.
    // Therefore the local VGA word address is i_wb_addr[13:0].
    //--------------------------------------------------------------------------

    assign local_word_addr = i_wb_addr[15:2];

    assign wb_access = i_wb_cyc && i_wb_stb;

    assign text_region_hit =
        (local_word_addr >= TEXT_FIRST_WORD) &&
        (local_word_addr <= TEXT_LAST_WORD);

    assign palette_region_hit =
        (local_word_addr >= PAL_FIRST_WORD) &&
        (local_word_addr <= PAL_LAST_WORD);

    // Each WB word maps to two 16-bit text cells.
    assign cell_base_addr = {local_word_addr[10:0], 1'b0};

    assign lower_cell_write =
        i_wb_we && text_region_hit && (i_wb_sel[1:0] == 2'b11);

    assign upper_cell_write =
        i_wb_we && text_region_hit && (i_wb_sel[3:2] == 2'b11);

    assign o_fg_color = fg_color_reg;
    assign o_bg_color = bg_color_reg;

    //--------------------------------------------------------------------------
    // Combinational transaction control
    //--------------------------------------------------------------------------

    always_comb begin
        next_state    = state;

        o_txt_wr_en   = 1'b0;
        o_txt_addr    = saved_cell_base_addr;
        o_txt_wr_data = 16'h0000;

        case (state)
            S_IDLE: begin
                if (wb_access) begin
                    if (text_region_hit) begin
                        if (i_wb_we) begin
                            if (lower_cell_write) begin
                                o_txt_wr_en   = 1'b1;
                                o_txt_addr    = cell_base_addr;
                                o_txt_wr_data = i_wb_data[15:0];

                                if (upper_cell_write) begin
                                    next_state = S_TEXT_WR_HI;
                                end else begin
                                    next_state = S_ACK;
                                end
                            end
                            else if (upper_cell_write) begin
                                o_txt_wr_en   = 1'b1;
                                o_txt_addr    = cell_base_addr + 12'd1;
                                o_txt_wr_data = i_wb_data[31:16];
                                next_state    = S_ACK;
                            end
                            else begin
                                // Unsupported byte-only text write.
                                // ACK but do not modify RAM.
                                next_state = S_ACK;
                            end
                        end
                        else begin
                            // Start 32-bit text read.
                            // Issue lower-cell address first.
                            o_txt_addr = cell_base_addr;
                            next_state = S_TEXT_RD_LO;
                        end
                    end
                    else begin
                        // Register or reserved access.
                        next_state = S_ACK;
                    end
                end
            end

            S_TEXT_WR_HI: begin
                o_txt_wr_en   = 1'b1;
                o_txt_addr    = saved_cell_base_addr + 12'd1;
                o_txt_wr_data = saved_hi_wr_data;
                next_state    = S_ACK;
            end

            S_TEXT_RD_LO: begin
                // Lower cell data is available this cycle.
                // Issue upper-cell address.
                o_txt_addr = saved_cell_base_addr + 12'd1;
                next_state = S_TEXT_RD_HI;
            end

            S_TEXT_RD_HI: begin
                // Upper cell data is available this cycle.
                next_state = S_ACK;
            end

            S_ACK: begin
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end

        endcase
    end

    //--------------------------------------------------------------------------
    // Sequential logic
    //--------------------------------------------------------------------------

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state                <= S_IDLE;

            o_wb_ack             <= 1'b0;
            o_wb_data            <= 32'h0000_0000;

            saved_cell_base_addr <= 12'h000;
            saved_hi_wr_data     <= 16'h0000;

            text_rd_lo           <= 16'h0000;

            fg_color_reg         <= 12'hFFF; // white
            bg_color_reg         <= 12'h000; // black
        end
        else begin
            state    <= next_state;
            o_wb_ack <= (next_state == S_ACK);

            //------------------------------------------------------------------
            // Capture new transaction info
            //------------------------------------------------------------------

            if ((state == S_IDLE) && wb_access) begin
                saved_cell_base_addr <= cell_base_addr;
                saved_hi_wr_data     <= i_wb_data[31:16];

                if (i_wb_we) begin
                    o_wb_data <= 32'h0000_0000;

                    if (!text_region_hit) begin
                        case (local_word_addr)

                            REG_FG_COLOR: begin
                                if (i_wb_sel != 4'b0000) begin
                                    fg_color_reg <= i_wb_data[11:0];
                                end
                            end

                            REG_BG_COLOR: begin
                                if (i_wb_sel != 4'b0000) begin
                                    bg_color_reg <= i_wb_data[11:0];
                                end
                            end

                            default: begin
                                // Palette/control not implemented yet.
                            end

                        endcase
                    end
                end
                else begin
                    if (!text_region_hit) begin
                        case (local_word_addr)

                            REG_FG_COLOR: begin
                                o_wb_data <= {20'h00000, fg_color_reg};
                            end

                            REG_BG_COLOR: begin
                                o_wb_data <= {20'h00000, bg_color_reg};
                            end

                            REG_VGA_CTRL: begin
                                o_wb_data <= 32'h0000_0000;
                            end

                            REG_VGA_CURSOR: begin
                                o_wb_data <= 32'h0000_0000;
                            end

                            default: begin
                                o_wb_data <= 32'h0000_0000;
                            end

                        endcase
                    end
                end
            end

            //------------------------------------------------------------------
            // Text RAM read capture
            //------------------------------------------------------------------

            if (state == S_TEXT_RD_LO) begin
                text_rd_lo <= i_txt_rd_data;
            end

            if (state == S_TEXT_RD_HI) begin
                o_wb_data <= {i_txt_rd_data, text_rd_lo};
            end
        end
    end

endmodule: wb_vga_ctrl
