/**
 * @file	wb_mux.sv
 * @brief	Wishbone bus mux for 3 wishbone bus devices and an Error device
 *
 * @author	Roy Kravitz (roy.kravitz@pdx.edu) and CoPilot
 * @date	28-Apr-2026
 * @version	2.0
 *
 * @detail
 * creates/ multiplexes signals for 3 custom wishbone peripherals and an wb_err peripheral which 
 * will generate an ACK if no other peripheral replied. The wb_err peripheral is needed because
 * the WB Bus will hang on an access that isn't ACK/NAK'd.
 *
 * i_wb_addr[15:14] are used to select each peripheral.  Each peripheral has a MMIO register/data
 * space of 64KB although there will be many many less MMIO registers for a typical peripheral.
 * This module is intended to work w/ axi2wbsp
 *(https://github.com/ZipCPU/wb2axip/blob/master/rtl/axim2wbsp.v)
 *
 * @note must be expanded if more than 3 (plus wb_err) peripherals are implemented
 */

`default_nettype wire

module wb_mux #(
    parameter int DW = 32,
    parameter int AW = 32
)(
    input  logic            i_clk,
    input  logic            i_reset,

    // Wishbone master input from axilite2wbsp AXI to Wishbone Bus bridge
    input  logic            i_wb_cyc,
    input  logic            i_wb_stb,
    input  logic            i_wb_we,
    input  logic [AW-1:0]   i_wb_addr,
    input  logic [DW-1:0]   i_wb_data,
    input  logic [DW/8-1:0] i_wb_sel,

    // Slave 0 (RGB LEDs)
    output logic            o_s0_cyc,
    output logic            o_s0_stb,
    output logic            o_s0_we,
    output logic [AW-1:0]   o_s0_addr,
    output logic [DW-1:0]   o_s0_data,
    output logic [DW/8-1:0] o_s0_sel,
    input  logic            i_s0_ack,
    input  logic [DW-1:0]   i_s0_data,

    // Slave 1 (Seven-seg)
    output logic            o_s1_cyc,
    output logic            o_s1_stb,
    output logic            o_s1_we,
    output logic [AW-1:0]   o_s1_addr,
    output logic [DW-1:0]   o_s1_data,
    output logic [DW/8-1:0] o_s1_sel,
    input  logic            i_s1_ack,
    input  logic [DW-1:0]   i_s1_data,

    // Slave 2 (wb_err)
    output logic            o_err_cyc,
    output logic            o_err_stb,
    output logic            o_err_we,
    output logic [AW-1:0]   o_err_addr,
    output logic [DW-1:0]   o_err_data,
    output logic [DW/8-1:0] o_err_sel,
    input  logic            i_err_ack,
    input  logic [DW-1:0]   i_err_data,

    // Slave 3 (vga)
    output logic 	    o_s3_cyc,
    output logic            o_s3_stb,
    output logic            o_s3_we,
    output logic [AW-1:0]   o_s3_addr,
    output logic [DW-1:0]   o_s3_data,
    output logic [DW/8-1:0] o_s3_sel,
    input  logic            i_s3_ack,
    input  logic [DW-1:0]   i_s3_data,

    // Muxed output to master
    output logic            o_wb_ack,
    output logic [DW-1:0]   o_wb_data
);

    // Decode 4 KB regions using address bits [15:14]
    logic [1:0] region;
    assign region = i_wb_addr[17:16];

    // Drive all slave address/data lines
    assign o_s0_addr = i_wb_addr;
    assign o_s1_addr = i_wb_addr;
    assign o_err_addr = i_wb_addr;
	assign o_s3_addr = i_wb_addr;

    assign o_s0_data = i_wb_data;
    assign o_s1_data = i_wb_data;
    assign o_err_data = i_wb_data;
	assign o_s3_data = i_wb_data;		

    assign o_s0_sel = i_wb_sel;
    assign o_s1_sel = i_wb_sel;
    assign o_err_sel = i_wb_sel;
	assign o_s3_sel = i_wb_sel;

    // Generate cyc/stb/we per slave
    assign o_s0_cyc = i_wb_cyc && (region == 2'b00);
    assign o_s0_stb = i_wb_stb && (region == 2'b00);
    assign o_s0_we  = i_wb_we;

    assign o_s1_cyc = i_wb_cyc && (region == 2'b01);
    assign o_s1_stb = i_wb_stb && (region == 2'b01);
    assign o_s1_we  = i_wb_we;

    // Error slave
    assign o_err_cyc = i_wb_cyc && (region == 2'b10);
    assign o_err_stb = i_wb_stb && (region == 2'b10);
    assign o_err_we  = i_wb_we;

	assign o_s3_cyc = i_wb_cyc && (region == 2'b11);
    assign o_s3_stb = i_wb_stb && (region == 2'b11);
    assign o_s3_we  = i_wb_we;

    // ACK mux
    always_comb begin
        case (region)
            2'b00: o_wb_ack = i_s0_ack;
            2'b01: o_wb_ack = i_s1_ack;
			2'b11: o_wb_ack = i_s3_ack;
            default: o_wb_ack = i_err_ack;
        endcase
    end

    // Data mux
    always_comb begin
        case (region)
            2'b00: o_wb_data = i_s0_data;
            2'b01: o_wb_data = i_s1_data;
			2'b11: o_wb_data = i_s3_data;
            default: o_wb_data = i_err_data;
        endcase
    end

endmodule : wb_mux

