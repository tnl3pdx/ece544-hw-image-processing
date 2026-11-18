/**
 * @file    MBWB_HW.h
 * @brief   Hardware definitions for the MBWB SoC driver library.
 *
 * @author Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date    16-Jul-2026
 * @version 1.0
 *
 * @detail
 * This header file defines the memory map for the MicroBlaze/Wishbone (MBWB)
 * embedded-system platform. It contains:
 *   - The AXI-Lite-to-Wishbone MMIO aperture
 *   - Wishbone peripheral base addresses
 *   - Common Wishbone register indices
 *   - Peripheral-specific MMIO register maps
 *   - Custom Wishbone interrupt-controller input assignments
 *
 * The Wishbone subsystem occupies a 256-Kbyte MMIO aperture beginning at the
 * base address exported by the AXI-Lite-to-Wishbone bridge. Address bits
 * [17:16] select one of four 64-Kbyte Wishbone peripheral regions:
 *   - Region 0: Board I/O
 *   - Region 1: Seven-segment display
 *   - Region 2: Error peripheral
 *   - Region 3: VGA text display
 * Each peripheral occupies one 64 KB MMIO region.
 *
 * Except for the VGA controller, MBWB peripherals use 32-bit registers with:
 *
 *      register_address = peripheral_base + (register_index << 2)
 *
 */
/* SPDX-License-Identifier: MIT */

#ifndef MBWB_HW_H
#define MBWB_HW_H

#include "xparameters.h"
#include "xil_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/* -------------------------------------------------------------------------- */
/*  AXI-Lite-to-Wishbone MMIO aperture                                        */
/* -------------------------------------------------------------------------- */

#define MBWB_MMIO_BASEADDR       XPAR_AXLITE2WBSP_0_BASEADDR
#define MBWB_MMIO_HIGHADDR       XPAR_AXLITE2WBSP_0_HIGHADDR
#define MBWB_MMIO_SIZE           0x00040000U

/* -------------------------------------------------------------------------- */
/*  Wishbone peripheral regions                                               */
/* -------------------------------------------------------------------------- */

#define MBWB_BIO_BASEADDR        (MBWB_MMIO_BASEADDR + 0x00000000U)
#define MBWB_SSEG_BASEADDR       (MBWB_MMIO_BASEADDR + 0x00010000U)
#define MBWB_ERR_BASEADDR        (MBWB_MMIO_BASEADDR + 0x00020000U)
#define MBWB_VGA_BASEADDR        (MBWB_MMIO_BASEADDR + 0x00030000U)

#define MBWB_PERIPHERAL_REGION_SIZE  0x00010000U

/* -------------------------------------------------------------------------- */
/*  Common Wishbone register indices                                          */
/* -------------------------------------------------------------------------- */

#define MBWB_REG0   0x00U
#define MBWB_REG1   0x01U
#define MBWB_REG2   0x02U
#define MBWB_REG3   0x03U
#define MBWB_REG4   0x04U
#define MBWB_REG5   0x05U
#define MBWB_REG6   0x06U
#define MBWB_REG7   0x07U
#define MBWB_REG8   0x08U
#define MBWB_REG9   0x09U
#define MBWB_REG10  0x0AU
#define MBWB_REG11  0x0BU
#define MBWB_REG12  0x0CU
#define MBWB_REG13  0x0DU
#define MBWB_REG14  0x0EU
#define MBWB_REG15  0x0FU
#define MBWB_REG16  0x10U

#define MBWB_REG_OFFSET(RegIndex)    ((u32)(RegIndex) << 2U)

/* -------------------------------------------------------------------------- */
/*  Board I/O peripheral register map                                         */
/* -------------------------------------------------------------------------- */

#define MBWB_BIO_BOARD_IN_REG         MBWB_REG0  // byte offset 0x00
#define MBWB_BIO_LEDS_REG             MBWB_REG1  // byte offset 0x04 
#define MBWB_BIO_IRQ_ENABLE_REG       MBWB_REG2  // byte offset 0x08 
#define MBWB_BIO_IRQ_STATUS_REG       MBWB_REG3  // byte offset 0x0C 
#define MBWB_BIO_BOARD_ID_REG         MBWB_REG4  // byte offset 0x10
#define MBWB_BIO_BOARD_CONFIG_REG     MBWB_REG5  // byte offset 0x14

#define MBWB_BIO_RGB_CONTROL_BASE_REG MBWB_REG8  // byte offset 0x20
#define MBWB_BIO_RGB_COUNT_BASE_REG   MBWB_REG16 // byte offset 0x40

#define MBWB_BIO_RGB_CONTROL_REG(Index) \
    (MBWB_BIO_RGB_CONTROL_BASE_REG + (u32)(Index))

#define MBWB_BIO_RGB_COUNT_REG(Index) \
    (MBWB_BIO_RGB_COUNT_BASE_REG + (u32)(Index))

/* RGB LED control-register fields. */
#define MBWB_BIO_RGB_ENABLE_MASK     0x80000000U
#define MBWB_BIO_RGB_RED_SHIFT       16U
#define MBWB_BIO_RGB_GREEN_SHIFT     8U
#define MBWB_BIO_RGB_BLUE_SHIFT      0U
#define MBWB_BIO_RGB_COMPONENT_MASK  0x000000FFU

/* -------------------------------------------------------------------------- */
/*  Seven-segment display peripheral register map                             */
/* -------------------------------------------------------------------------- */

#define MBWB_SSEG_ENABLES_REG        MBWB_REG0
#define MBWB_SSEG_DIGITS_LO_REG      MBWB_REG1
#define MBWB_SSEG_DIGITS_HI_REG      MBWB_REG2
#define MBWB_SSEG_RESERVED_REG       MBWB_REG3

/* -------------------------------------------------------------------------- */
/*  Error peripheral register map                                             */
/* -------------------------------------------------------------------------- */

#define MBWB_ERR_REG0                MBWB_REG0
#define MBWB_ERR_REG1                MBWB_REG1
#define MBWB_ERR_REG2                MBWB_REG2
#define MBWB_ERR_REG3                MBWB_REG3

/* -------------------------------------------------------------------------- */
/*  VGA text-display memory map                                               */
/* -------------------------------------------------------------------------- */

#define MBWB_VGA_COLUMNS             80U
#define MBWB_VGA_ROWS                30U
#define MBWB_VGA_CELL_SIZE           2U
#define MBWB_VGA_TEXT_BUFFER_SIZE    0x000012C0U

#define MBWB_VGA_TEXT_BUFFER_OFFSET  0x00000000U
#define MBWB_VGA_FG_PALETTE_OFFSET   0x00002000U
#define MBWB_VGA_BG_PALETTE_OFFSET   0x00002040U
#define MBWB_VGA_CTL_STATUS_OFFSET   0x00003000U
#define MBWB_VGA_CURSOR_OFFSET       0x00003004U
#define MBWB_VGA_FGCOLOR_OFFSET      0x00003010U
#define MBWB_VGA_BGCOLOR_OFFSET      0x00003014U

/* -------------------------------------------------------------------------- */
/*  AXI interrupt-controller input assignments                                */
/* -------------------------------------------------------------------------- */

/*
 * These interrupt IDs must match the bit positions of the interrupt sources
 * connected to the AXI Interrupt Controller in the Vivado block design.
 * Timer interrupt IDs are generated in xparameters.h. The Wishbone interrupt
 * inputs are external signals and therefore require MBWB-specific constants.
 */
#define MBWB_BIO_INTERRUPT_ID        2U
#define MBWB_RESERVED_INTERRUPT_ID   3U

#ifdef __cplusplus
}
#endif

#endif /* MBWB_HW_H */
