/**
 * @file    MBWB_SSEG.h
 * @brief   Public API for the MBWB seven-segment display driver.
 *
 * @author Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date    16-Jul-2026
 * @version 1.0
 *
 * @detail
 * This header file defines the public API for the MicroBlaze/Wishbone
 * (MBWB) seven-segment display peripheral.
 *
 * The seven-segment display contains eight digits divided into two banks:
 *
 *   - Lower bank: digits 0 through 3
 *   - Upper bank: digits 4 through 7
 *
 * Each display bank is a 32-bit register containing four bytes. Each byte contains a 5-bit character code in bits [4:0],
 * a decimal point in bit 5, and bits [7:6] are reserved. 
 *
 * The driver provides:
 *
 *   - Raw bank-level register access
 *   - Individual digit updates
 *   - Individual decimal-point control
 *   - Four-digit bank updates
 *   - 16-bit hexadecimal display
 *   - 32-bit hexadecimal display
 *   - 32-bit decimal display
 *
 * The seven-segment register map and peripheral base address are defined in
 * MBWB_HW.h. Low-level register access functions are defined in MBWB_L.h.
 */
/* SPDX-License-Identifier: MIT */

#ifndef MBWB_SSEG_H
#define MBWB_SSEG_H

#include "MBWB_L.h"
#include "xil_types.h"
#include "xstatus.h"

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* -------------------------------------------------------------------------- */
/*  Seven-segment field definitions                                           */
/* -------------------------------------------------------------------------- */

/**
 * @brief Number of digits in one seven-segment display bank.
 */
#define MBWB_SSEG_DIGITS_PER_BANK     4U

/**
 * @brief Total number of seven-segment display digits.
 */
#define MBWB_SSEG_NUM_DIGITS          8U

/**
 * @brief Mask for one encoded seven-segment character.
 */
#define MBWB_SSEG_CHAR_MASK           0x1FU

/**
 * @brief Number of bits used by one encoded character.
 */
#define MBWB_SSEG_CHAR_WIDTH          5U

/**
 * @brief Mask for the four decimal-point bits in a display bank.
 */
#define MBWB_SSEG_DP_MASK             0x0FU

/**
 * @brief Each 5-bit character code is written to an 8-bit field in the Digits register.
 */
 #define MBWB_SSEG_CHAR_STRIDE  8U

/* -------------------------------------------------------------------------- */
/*  Typedefs and enumerations                                                 */
/* -------------------------------------------------------------------------- */

/**
 * @brief Seven-segment display bank identifiers.
 */
typedef enum
{
    MBWB_SSEG_LO = 0,
    MBWB_SSEG_HI
} MBWB_SSEG_banks_t;

/**
 * @brief Seven-segment digit identifiers.
 */
typedef enum
{
    MBWB_SSEG_DIGIT0 = 0,
    MBWB_SSEG_DIGIT1,
    MBWB_SSEG_DIGIT2,
    MBWB_SSEG_DIGIT3,
    MBWB_SSEG_DIGIT4,
    MBWB_SSEG_DIGIT5,
    MBWB_SSEG_DIGIT6,
    MBWB_SSEG_DIGIT7
} MBWB_SSEG_digits_t;

/**
 * @brief Encoded character values supported by the seven-segment peripheral.
 *
 * The numeric values correspond directly to the character codes expected by
 * the hardware.
 */
typedef enum
{
    MBWB_SSEG_CC_0 = 0,
    MBWB_SSEG_CC_1,
    MBWB_SSEG_CC_2,
    MBWB_SSEG_CC_3,
    MBWB_SSEG_CC_4,
    MBWB_SSEG_CC_5,
    MBWB_SSEG_CC_6,
    MBWB_SSEG_CC_7,
    MBWB_SSEG_CC_8,
    MBWB_SSEG_CC_9,
    MBWB_SSEG_CC_A,
    MBWB_SSEG_CC_B,
    MBWB_SSEG_CC_C,
    MBWB_SSEG_CC_D,
    MBWB_SSEG_CC_E,
    MBWB_SSEG_CC_F,
    MBWB_SSEG_CC_SEGa,
    MBWB_SSEG_CC_SEGb,
    MBWB_SSEG_CC_SEGc,
    MBWB_SSEG_CC_SEGd,
    MBWB_SSEG_CC_SEGe,
    MBWB_SSEG_CC_SEGf,
    MBWB_SSEG_CC_SEGg,
    MBWB_SSEG_CC_SPACE,
    MBWB_SSEG_CC_UCH,
    MBWB_SSEG_CC_UCL,
    MBWB_SSEG_CC_UCW,
    MBWB_SSEG_CC_LCL,
    MBWB_SSEG_CC_LCR,
    MBWB_SSEG_CC_LCN,
    MBWB_SSEG_CC_BLANK,
    MBWB_SSEG_CC_BLANK1
} MBWB_SSEG_charcodes_t;

/**
 * @brief Decimal-point masks for one four-digit display bank.
 */
typedef enum
{
    MBWB_SSEG_DP_NONE = 0x0U,
    MBWB_SSEG_DP_0    = 0x1U,
    MBWB_SSEG_DP_1    = 0x2U,
    MBWB_SSEG_DP_2    = 0x4U,
    MBWB_SSEG_DP_3    = 0x8U,
    MBWB_SSEG_DP_ALL  = 0xFU
} MBWB_SSEG_decpts_t;

/* -------------------------------------------------------------------------- */
/*  Initialization                                                            */
/* -------------------------------------------------------------------------- */

/**
 * @brief Initialize the MBWB seven-segment display driver.
 *
 * This function records the base address of the seven-segment peripheral for
 * use by the remaining driver functions.
 *
 * The hardware requires no additional initialization beyond establishing the
 * peripheral base address.
 *
 * @param BaseAddress Base address of the seven-segment peripheral. For the
 *                    standard MBWB platform, use MBWB_SSEG_BASEADDR.
 *
 * @return XST_SUCCESS if the driver was initialized successfully.
 */
int MBWB_SSEG_initialize(UINTPTR BaseAddress);

/* -------------------------------------------------------------------------- */
/*  Raw register access                                                       */
/* -------------------------------------------------------------------------- */

/**
 * @brief Read the raw 32-bit data register for a selected display bank.
 *
 * @param Bank Display bank to read. The value must be MBWB_SSEG_LO or
 *             MBWB_SSEG_HI.
 *
 * @return The raw 32-bit contents of the selected display-bank register.
 */
u32 MBWB_SSEG_getData(MBWB_SSEG_banks_t Bank);

/**
 * @brief Write raw 32-bit data to a selected display bank.
 *
 * This function writes the supplied value directly to the selected bank
 * register without modifying or validating individual character fields.
 *
 * @param Bank Display bank to modify. The value must be MBWB_SSEG_LO or
 *             MBWB_SSEG_HI.
 * @param Data Raw 32-bit value to write to the selected bank.
 *
 * @return None.
 */
void MBWB_SSEG_setData(MBWB_SSEG_banks_t Bank, u32 Data);

/* -------------------------------------------------------------------------- */
/*  Individual digit and decimal-point control                                */
/* -------------------------------------------------------------------------- */

/**
 * @brief Set one seven-segment digit to a specified character.
 *
 * This function determines the appropriate lower or upper display bank from
 * the selected digit, updates only that digit field, and preserves the other
 * digit and decimal-point fields in the register.
 *
 * @param Digit     Digit to modify. The value must be MBWB_SSEG_DIGIT0
 *                  through MBWB_SSEG_DIGIT7.
 * @param Character Character code to display.
 *
 * @return XST_SUCCESS if the digit was updated successfully; otherwise
 *         XST_INVALID_PARAM.
 */
int MBWB_SSEG_setDigit(MBWB_SSEG_digits_t Digit,
                       MBWB_SSEG_charcodes_t Character);

/**
 * @brief Enable or disable the decimal point for one digit.
 *
 * This function determines the appropriate lower or upper display bank from
 * the selected digit, updates only the corresponding decimal-point bit, and
 * preserves the remaining register fields.
 *
 * @param Digit  Digit whose decimal point is to be modified. The value must be
 *               MBWB_SSEG_DIGIT0 through MBWB_SSEG_DIGIT7.
 * @param Enable true to illuminate the decimal point; false to turn it off.
 *
 * @return XST_SUCCESS if the decimal point was updated successfully;
 *         otherwise XST_INVALID_PARAM.
 */
int MBWB_SSEG_setDecimalPoint(MBWB_SSEG_digits_t Digit, bool Enable);

/* -------------------------------------------------------------------------- */
/*  Bank-level display functions                                              */
/* -------------------------------------------------------------------------- */

/**
 * @brief Set all four digits and decimal points in one display bank.
 *
 * The four character values are packed into the selected bank register along
 * with the supplied decimal-point mask.
 *
 * @param Bank   Display bank to modify. The value must be MBWB_SSEG_LO or
 *               MBWB_SSEG_HI.
 * @param Digit3 Character code for the most significant digit in the bank.
 * @param Digit2 Character code for the next digit.
 * @param Digit1 Character code for the next digit.
 * @param Digit0 Character code for the least significant digit in the bank.
 * @param DpMask Four-bit decimal-point mask. Bit 0 controls Digit0 and bit 3
 *               controls Digit3.
 *
 * @return XST_SUCCESS if the bank was updated successfully; otherwise
 *         XST_INVALID_PARAM.
 */
int MBWB_SSEG_setAllDigits(MBWB_SSEG_banks_t Bank,
                           MBWB_SSEG_charcodes_t Digit3,
                           MBWB_SSEG_charcodes_t Digit2,
                           MBWB_SSEG_charcodes_t Digit1,
                           MBWB_SSEG_charcodes_t Digit0,
                           MBWB_SSEG_decpts_t DpMask);

/**
 * @brief Display a 16-bit hexadecimal value on one display bank.
 *
 * Each hexadecimal nibble is converted to the corresponding hardware character
 * code and displayed on one of the four digits in the selected bank.
 *
 * @param Bank Display bank to use. The value must be MBWB_SSEG_LO or
 *             MBWB_SSEG_HI.
 * @param Data 16-bit value to display.
 *
 * @return XST_SUCCESS if the value was displayed successfully; otherwise
 *         XST_INVALID_PARAM.
 */
int MBWB_SSEG_putU16Hex(MBWB_SSEG_banks_t Bank, u16 Data);

/**
 * @brief Display a 32-bit hexadecimal value across all eight digits.
 *
 * The most significant 16 bits are displayed on the upper bank and the least
 * significant 16 bits are displayed on the lower bank.
 *
 * @param Data 32-bit value to display.
 *
 * @return XST_SUCCESS if the value was displayed successfully.
 */
int MBWB_SSEG_putU32Hex(u32 Data);

/**
 * @brief Display a 32-bit unsigned decimal value across all eight digits.
 *
 * The value is converted to decimal digits and displayed across the complete
 * eight-digit display.
 *
 * Because eight decimal digits can represent values only through 99,999,999,
 * values larger than this range require an implementation-defined policy such
 * as truncation or error reporting.
 *
 * @param Data 32-bit unsigned value to display.
 * @param Trim true to blank leading zeroes; false to display leading zeroes.
 *
 * @return XST_SUCCESS if the value was displayed successfully; otherwise an
 *         appropriate error code.
 */
int MBWB_SSEG_putU32Dec(u32 Data, bool Trim);

#ifdef __cplusplus
}
#endif

#endif /* MBWB_SSEG_H */
