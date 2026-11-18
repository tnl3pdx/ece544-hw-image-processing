/**
 * @file    wb_boardio.sv
 * @brief   Generic Wishbone board I/O peripheral
 *
 * @author  Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date    02-Jul-2026
 * @version 2.0
 *
 * @details
 * Generic Wishbone peripheral providing access to the user I/O resources
 * found on Digilent and RealDigital FPGA development boards.  The peripheral is intended to
 * be board independent through the use of configurable parameters that
 * specify the number of switches, pushbuttons, LEDs, and RGB LEDs.
 *
 * Features
 * --------
 * - Parameterized number of switches
 * - Parameterized number of pushbuttons
 * - Parameterized number of discrete LEDs
 * - Parameterized number of RGB LEDs
 * - RGB LEDs driven by one rgbPWM instance per RGB LED
 * - Change-detect interrupt generation for switches and buttons
 * - Self-describing BOARD_CONFIG register
 * - Byte-select aware Wishbone interface
 *
 * The BOARD_IN register reflects the synchronized state of the board inputs.
 * Whenever any enabled switch or pushbutton changes state, the corresponding
 * bit in IRQ_STATUS is set.  IRQ_STATUS is a write-one-to-clear (W1C)
 * register.  irq_boardio is asserted whenever an enabled status bit is set.
 *
 * Register Map
 * ------------
 *
 * Byte
 * Offset  Register         Access   Description
 * ------  ---------------  ------   ------------------------------------------
 * 0x00    BOARD_IN         RO       Board inputs
 *                                  bits[31 -: NUM_BTNS]      Buttons
 *                                  bits[15 -: NUM_SWITCHES]  Switches
 *
 * 0x04    LEDS             RW       bits[0 +: NUM_LEDS] drive LEDs
 *
 * 0x08    IRQ_ENABLE       RW       Interrupt enable bits matching BOARD_IN
 *
 * 0x0C    IRQ_STATUS       W1C      Sticky interrupt status bits matching
 *                                  BOARD_IN bit positions
 *
 * 0x10    BOARD_ID         RO       Peripheral identification constant
 *
 * 0x14    BOARD_CONFIG     RO       Peripheral configuration
 *                                  bits[31:24] NUM_RGBLEDS
 *                                  bits[23:16] NUM_LEDS
 *                                  bits[15:8]  NUM_BTNS
 *                                  bits[7:0]   NUM_SWITCHES
 *
 * 0x20    RGB_CONTROL0     RW       RGB LED 0 control register
 * 0x24    RGB_CONTROL1     RW       RGB LED 1 control register
 *          ...
 *                                  One control register per RGB LED
 *
 * RGB_CONTROL format
 * ------------------
 * bit[31]      Enable
 * bits[23:16]  Red intensity
 * bits[15:8]   Green intensity
 * bits[7:0]    Blue intensity
 *
 * 0x40    RGB_COUNT0       RO       RGB LED 0 PWM counter/debug
 * 0x44    RGB_COUNT1       RO       RGB LED 1 PWM counter/debug
 *          ...
 *                                  One counter register per RGB LED
 *
 * Notes
 * -----
 * -	BOARD_IN, BOARD_ID, and BOARD_CONFIG are read-only registers.
 * 	Writes to these registers are accepted by the Wishbone interface
 * 	but ignored by the peripheral.

 * -	The RGB register banks scale automatically with NUM_RGBLEDS.
 *
 * -	BOARD_CONFIG allows software to discover the implemented hardware
 * 	configuration at run time without requiring driver recompilation.
 */
 // SPDX-License-Identifier: MIT
 
`default_nettype wire

module wb_boardio #(
    parameter int DW = 32,
    parameter int AW = 32,

    // defaults for the Zybo board, YMMV for different boards
    // change the parameters to your target FPGA board when you
    // instantiate it in wb_subsystem.sv
    parameter int NUM_LEDS     = 4,
    parameter int NUM_SWITCHES = 4,
    parameter int NUM_BTNS     = 4,
    parameter int NUM_RGBLEDS  = 2,
    parameter bit [31:0] BOARD_ID = "Zybo"
)(
    input  logic                       i_clk,
    input  logic                       i_reset,

    input  logic                       i_wb_cyc,
    input  logic                       i_wb_stb,
    input  logic                       i_wb_we,
    input  logic [AW-1:0]              i_wb_addr,
    input  logic [DW-1:0]              i_wb_data,
    input  logic [DW/8-1:0]            i_wb_sel,

    output logic                       o_wb_ack,
    output logic [DW-1:0]              o_wb_data,

    input  logic [NUM_SWITCHES-1:0]    sw,
    input  logic [NUM_BTNS-1:0]        btns,
    output logic [NUM_LEDS-1:0]        leds,
    output logic [NUM_RGBLEDS-1:0][2:0] rgb,

    output logic                       irq_boardio
);

    // ------------------------------------------------------------
    // Register layout
    // ------------------------------------------------------------
    localparam int REG_BOARD_IN     = 5'h00; // 0x00
    localparam int REG_LEDS         = 5'h01; // 0x04
    localparam int REG_IRQ_ENABLE   = 5'h02; // 0x08
    localparam int REG_IRQ_STATUS   = 5'h03; // 0x0C
    localparam int REG_BOARD_ID     = 5'h04; // 0x10
    localparam int REG_BOARD_CONFIG = 5'h05; // 0x14

    localparam int REG_RGB_CTRL_BASE  = 5'h08; // 0x20
    localparam int REG_RGB_COUNT_BASE = 5'h10; // 0x40

    // BOARD_CONFIG:
    // [31:24] NUM_RGBLEDS
    // [23:16] NUM_LEDS
    // [15:8]  NUM_BTNS
    // [7:0]   NUM_SWITCHES
    localparam logic [31:0] BOARD_CONFIG_VALUE = {
        8'(NUM_RGBLEDS),
        8'(NUM_LEDS),
        8'(NUM_BTNS),
        8'(NUM_SWITCHES)
    };

    logic [4:0] addr_word;
    assign addr_word = i_wb_addr[6:2];

    // ------------------------------------------------------------
    // Field layout within BOARD_IN / IRQ registers
    // ------------------------------------------------------------
    localparam int BTN_MSB = 31;
    localparam int SW_MSB  = 15;
    localparam int LED_LSB = 0;

    localparam logic [31:0] BTN_MASK =
        (NUM_BTNS == 0) ? 32'h0000_0000 :
        ((32'hFFFF_FFFF >> (32 - NUM_BTNS)) << (BTN_MSB - NUM_BTNS + 1));

    localparam logic [31:0] SW_MASK =
        (NUM_SWITCHES == 0) ? 32'h0000_0000 :
        ((32'hFFFF_FFFF >> (32 - NUM_SWITCHES)) << (SW_MSB - NUM_SWITCHES + 1));

    localparam logic [31:0] LED_MASK =
        (NUM_LEDS == 0) ? 32'h0000_0000 :
        (32'hFFFF_FFFF >> (32 - NUM_LEDS));

    localparam logic [31:0] INPUT_VALID_MASK = BTN_MASK | SW_MASK;

    // ------------------------------------------------------------
    // Board input synchronizers
    // ------------------------------------------------------------
    logic [NUM_SWITCHES-1:0] sw_meta;
    logic [NUM_SWITCHES-1:0] sw_sync;

    logic [NUM_BTNS-1:0] btn_meta;
    logic [NUM_BTNS-1:0] btn_sync;

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            sw_meta  <= '0;
            sw_sync  <= '0;
            btn_meta <= '0;
            btn_sync <= '0;
        end else begin
            sw_meta  <= sw;
            sw_sync  <= sw_meta;
            btn_meta <= btns;
            btn_sync <= btn_meta;
        end
    end

    // ------------------------------------------------------------
    // Packed board input register
    //
    // BOARD_IN:
    //   bits[31 -: NUM_BTNS]     buttons
    //   bits[15 -: NUM_SWITCHES] switches
    // ------------------------------------------------------------
    logic [31:0] board_inputs;

    always_comb begin
        board_inputs = '0;
        board_inputs[BTN_MSB -: NUM_BTNS]     = btn_sync;
        board_inputs[SW_MSB  -: NUM_SWITCHES] = sw_sync;
    end

    // ------------------------------------------------------------
    // Registers
    // ------------------------------------------------------------
    logic [31:0] leds_reg;
    logic [31:0] irq_enable;
    logic [31:0] irq_status;
    logic [31:0] board_inputs_dly;

    logic [31:0] rgb_control [NUM_RGBLEDS];
    logic [31:0] rgb_count   [NUM_RGBLEDS];

    assign leds = leds_reg[LED_LSB +: NUM_LEDS];

    // ------------------------------------------------------------
    // Change detection
    // ------------------------------------------------------------
    logic [31:0] change_mask;
    assign change_mask = (board_inputs ^ board_inputs_dly) & INPUT_VALID_MASK;

    logic [31:0] irq_w1c_mask;
    assign irq_w1c_mask = i_wb_data & expand_sel(i_wb_sel);

    assign irq_boardio = |(irq_status & irq_enable & INPUT_VALID_MASK);

    // ------------------------------------------------------------
    // Register write/status logic
    // ------------------------------------------------------------
    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            leds_reg         <= 32'h0000_F50A & LED_MASK;
            board_inputs_dly <= '0;
            irq_enable       <= '0;
            irq_status       <= '0;

            /*
            for (int i = 0; i < NUM_RGBLEDS; i++) begin
                rgb_control[i] <= 32'h8000_0707;
            end
            */
            rgb_control[0] = 32'h8000_0707;  // light cyan (aqua0
            rgb_control[1] = 32'h80FF_00FF;  // magenta
        end else begin
            board_inputs_dly <= board_inputs;
            irq_status       <= (irq_status | change_mask) & INPUT_VALID_MASK;

            if (i_wb_cyc && i_wb_stb && i_wb_we) begin
                unique case (addr_word)
                    REG_BOARD_IN: begin
                    	// Read-only register
                        // Writes acknowledged but ignored.
                    end
                    
    		    REG_BOARD_ID,
    		    REG_BOARD_CONFIG: begin
        		// Read-only registers.
        		// Writes are acknowledged but ignored.
    		    end

                    REG_LEDS: begin
                        leds_reg <= apply_sel(leds_reg, i_wb_data, i_wb_sel) & LED_MASK;
                    end

                    REG_IRQ_ENABLE: begin
                        irq_enable <= apply_sel(irq_enable, i_wb_data, i_wb_sel) &
                                      INPUT_VALID_MASK;
                    end

                    REG_IRQ_STATUS: begin
                        irq_status <= ((irq_status | change_mask) & ~irq_w1c_mask) &
                                      INPUT_VALID_MASK;
                    end

                    default: begin
                        if ((addr_word >= REG_RGB_CTRL_BASE) &&
                            (addr_word <  REG_RGB_CTRL_BASE + NUM_RGBLEDS)) begin
                            rgb_control[addr_word - REG_RGB_CTRL_BASE] <=
                                apply_sel(
                                    rgb_control[addr_word - REG_RGB_CTRL_BASE],
                                    i_wb_data,
                                    i_wb_sel
                                );
                        end
                    end
                endcase
            end
        end
    end

    // ------------------------------------------------------------
    // Read mux
    // ------------------------------------------------------------
    always_comb begin
        o_wb_data = '0;

        unique case (addr_word)
            REG_BOARD_IN: begin
                o_wb_data = board_inputs & INPUT_VALID_MASK;
            end

            REG_LEDS: begin
                o_wb_data = leds_reg & LED_MASK;
            end

            REG_IRQ_ENABLE: begin
                o_wb_data = irq_enable & INPUT_VALID_MASK;
            end

            REG_IRQ_STATUS: begin
                o_wb_data = irq_status & INPUT_VALID_MASK;
            end

            REG_BOARD_ID: begin
                o_wb_data = BOARD_ID;
            end

            REG_BOARD_CONFIG: begin
                o_wb_data = BOARD_CONFIG_VALUE;
            end

            default: begin
                if ((addr_word >= REG_RGB_CTRL_BASE) &&
                    (addr_word <  REG_RGB_CTRL_BASE + NUM_RGBLEDS)) begin
                    o_wb_data = rgb_control[addr_word - REG_RGB_CTRL_BASE];
                end else if ((addr_word >= REG_RGB_COUNT_BASE) &&
                             (addr_word <  REG_RGB_COUNT_BASE + NUM_RGBLEDS)) begin
                    o_wb_data = rgb_count[addr_word - REG_RGB_COUNT_BASE];
                end else begin
                    o_wb_data = '0;
                end
            end
        endcase
    end

    // ------------------------------------------------------------
    // ACK generation, single-cycle response
    // ------------------------------------------------------------
    always_ff @(posedge i_clk) begin
        if (i_reset)
            o_wb_ack <= 1'b0;
        else
            o_wb_ack <= i_wb_cyc && i_wb_stb && !o_wb_ack;
    end

    // ------------------------------------------------------------
    // RGB PWM instances
    // ------------------------------------------------------------
    generate
        genvar g;

        for (g = 0; g < NUM_RGBLEDS; g++) begin : GEN_RGB_PWM
            rgbPWM #(
                .USE_DIVIDER  (1'b1),
                .DIVIDE_COUNT (5000),
                .POLARITY     (1'b1),
                .MAX_COUNT    (256)
            ) RGB_PWM_INST (
                .clk        (i_clk),
                .reset      (i_reset),
                .controlReg (rgb_control[g]),
                .rgbRED     (rgb[g][2]),
                .rgbGREEN   (rgb[g][1]),
                .rgbBLUE    (rgb[g][0]),
                .clkPWM     (),
                .pwmcount   (rgb_count[g])
            );
        end
    endgenerate

    // ------------------------------------------------------------
    // Byte-select helpers
    // ------------------------------------------------------------
    function automatic logic [DW-1:0] apply_sel(
        input logic [DW-1:0]     old_val,
        input logic [DW-1:0]     new_val,
        input logic [DW/8-1:0]   sel
    );
        logic [DW-1:0] result;

        result = old_val;

        for (int i = 0; i < DW/8; i++) begin
            if (sel[i])
                result[i*8 +: 8] = new_val[i*8 +: 8];
        end

        return result;
    endfunction

    function automatic logic [DW-1:0] expand_sel(
        input logic [DW/8-1:0] sel
    );
        logic [DW-1:0] mask;

        mask = '0;

        for (int i = 0; i < DW/8; i++) begin
            if (sel[i])
                mask[i*8 +: 8] = 8'hFF;
        end

        return mask;
    endfunction

endmodule : wb_boardio

