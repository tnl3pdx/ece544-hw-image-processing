/**
 * @file sync_reset.sv
 * @brief Active-high reset synchronizer.
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date	03-May-2026
 * @version	1.0
 *
 * @detail
 * This module synchronizes the deassertion of an active-high reset into a
 * target clock domain.
 *
 * Reset behavior:
 *   - arst asserts the output reset asynchronously when high
 *   - srst remains asserted for STAGES clock cycles after reset is
 *     deasserted
 *   - srst deasserts synchronously to clk
 *
 * This matches the Wishbone-style convention used in this project:
 *
 *   reset asserted   = 1'b1
 *   reset deasserted = 1'b0
 *
 * This is the active-high equivalent of the common Cliff Cummings reset
 * synchronizer pattern: asynchronous assertion, synchronous deassertion.
 */
 // SPDX-License-Identifier: MIT

`default_nettype wire

module sync_reset #(
    parameter int STAGES = 2
) (
    input  logic clk,
    input  logic arst,	// asynchronous active-high reset input
    output logic srst	// synchronized active-high reset output
);

    //--------------------------------------------------------------------------
    // Parameter check
    //--------------------------------------------------------------------------

    initial begin
        if (STAGES < 2) begin
            $error("sync_reset: STAGES must be >= 2");
        end
    end

    //--------------------------------------------------------------------------
    // Synchronizer shift register
    //--------------------------------------------------------------------------

    logic [STAGES-1:0] reset_pipe;

    always_ff @(posedge clk or posedge arst) begin
        if (arst) begin
            reset_pipe <= '1;
        end
        else begin
            reset_pipe <= {reset_pipe[STAGES-2:0], 1'b0};
        end
    end

    assign srst = reset_pipe[STAGES-1];

endmodule: sync_reset

