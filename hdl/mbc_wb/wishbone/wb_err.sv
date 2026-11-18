// wb_err.sv
// Simple Wishbone error slave: always ACKs, returns fixed data

/**
 * @file	wb_err.sv
 * @brief	Wishbone bus peripheral for wb errors
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and CoPilot
 * @date	24-Mar-2026
 * @version	1.0
 *
 * @detail
 * Every wb bus access has to be acknowledged or the wb bus hangs.  This module should be executed whenever there is no address match to a wb access.
 * This module is intended to work w/ axi2wbsp (https://github.com/ZipCPU/wb2axip/blob/master/rtl/axim2wbsp.v)
 */
module wb_err #(
    parameter int DW = 32,
    parameter int AW = 32
)(
    input  logic            i_clk,
    input  logic            i_reset,

    // Wishbone inputs
    input  logic            i_wb_cyc,
    input  logic            i_wb_stb,
    input  logic            i_wb_we,
    input  logic [AW-1:0]   i_wb_addr,
    input  logic [DW-1:0]   i_wb_data,
    input  logic [DW/8-1:0] i_wb_sel,

    // Wishbone outputs
    output logic            o_wb_ack,
    output logic [DW-1:0]   o_wb_data
);

    // recognizable error pattern
    localparam logic [DW-1:0] ERR_VALUE = 32'hDEAD_BEEF;

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            o_wb_ack  <= 1'b0;
            o_wb_data <= ERR_VALUE;
        end else begin
            // ACK whenever cyc+stb are asserted
            o_wb_ack  <= i_wb_cyc && i_wb_stb;
            o_wb_data <= ERR_VALUE;
        end
    end

endmodule : wb_err

