/**
 * @file	font_rom.sv
 * @brief	CP437 8x16 VGA font ROM.
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @date	29-Apr-2026
 * @version	1.0
 *
 * @detail
 * ROM organization:
 *   256 glyphs × 16 rows/glyph = 4096 entries
 *
 * Address:
 *   {i_char_code[7:0], i_glyph_y[3:0]}
 *
 * Data:
 *   o_glyph_row[7:0]
 *
 * Bit convention:
 *   o_glyph_row[7] = leftmost pixel
 *   o_glyph_row[0] = rightmost pixel
 *
 * Timing:
 *   Synchronous registered read.
 *   The output row is valid one clock after the input address is applied.
 */

`default_nettype wire

module font_rom #(
    parameter string INIT_FILE = "font_rom_cp437_8x16.mem"
) (
    input  logic       i_clk,

    input  logic [7:0] i_char_code,
    input  logic [3:0] i_glyph_y,

    output logic [7:0] o_glyph_row
);

    //--------------------------------------------------------------------------
    // ROM storage
    //--------------------------------------------------------------------------

    (* rom_style = "block" *)
    logic [7:0] rom [0:4095];

    //--------------------------------------------------------------------------
    // ROM initialization
    //--------------------------------------------------------------------------

    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, rom);
        end
    end

    //--------------------------------------------------------------------------
    // Synchronous read
    //--------------------------------------------------------------------------

    always_ff @(posedge i_clk) begin
        o_glyph_row <= rom[{i_char_code, i_glyph_y}];
    end

endmodule: font_rom