/**
 * @file    MBWB_VGA.h
 * @brief   Public API for the MBWB Wishbone text-mode VGA driver.
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
 * (MBWB) text-mode VGA peripheral.
 *
 * The VGA controller provides an 80-column by 30-row text display. Each
 * display cell is represented by a 16-bit value:
 *
 *   - Bits [7:0]  : CP437/ASCII character code
 *   - Bits [15:8] : Character attribute
 *
 * The current implementation maintains the cursor position in software.
 * Newline and carriage-return processing are handled by the driver.
 *
 * The driver provides:
 *
 *   - Screen clear and fill operations
 *   - Software cursor positioning
 *   - Character and string output
 *   - Limited printf-style formatted output
 *   - Global foreground and background color control
 *   - Software character-attribute control
 *
 * Hardware cursor and palette-RAM support are planned. API declarations for
 * those features are included so that the public interface can remain stable
 * when the corresponding hardware support is implemented.
 *
 * The VGA register map and peripheral base address are defined in MBWB_HW.h.
 * Low-level register access functions are defined in MBWB_L.h.
 */
 /* SPDX-License-Identifier: MIT */

#ifndef MBWB_VGA_H
#define MBWB_VGA_H

#include "MBWB_L.h"
#include "xil_types.h"
#include "xstatus.h"

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* -------------------------------------------------------------------------- */
/*  VGA text-display constants                                                */
/* -------------------------------------------------------------------------- */

/**
 * @brief Number of character columns in the VGA text display.
 */
#define MBWB_VGA_NUM_COLS             80U

/**
 * @brief Number of character rows in the VGA text display.
 */
#define MBWB_VGA_NUM_ROWS             30U

/**
 * @brief Total number of character cells in the VGA text display.
 */
#define MBWB_VGA_NUM_CELLS            \
    (MBWB_VGA_NUM_COLS * MBWB_VGA_NUM_ROWS)

/**
 * @brief Default software attribute assigned to newly written characters.
 */
#define MBWB_VGA_DEFAULT_ATTR         0x00U

/**
 * @brief Default 12-bit foreground color.
 *
 * The value 0xFFF represents full-intensity white in 4-bit-per-component
 * RGB format.
 */
#define MBWB_VGA_DEFAULT_FG           0x0FFFU

/**
 * @brief Default 12-bit background color.
 *
 * The value 0x000 represents black in 4-bit-per-component RGB format.
 */
#define MBWB_VGA_DEFAULT_BG           0x0000U

/**
 * @brief Mask for a 12-bit VGA color value.
 */
#define MBWB_VGA_COLOR_MASK           0x0FFFU

/**
 * @brief Space character used when clearing the text display.
 */
#define MBWB_VGA_SPACE_CHAR           0x20U

/* -------------------------------------------------------------------------- */
/*  VGA text-cell construction                                                */
/* -------------------------------------------------------------------------- */

/**
 * @brief Construct a packed 16-bit VGA text-cell value.
 *
 * @param Character Character code placed in bits [7:0].
 * @param Attribute Character attribute placed in bits [15:8].
 *
 * @return A packed 16-bit VGA text-cell value.
 */
#define MBWB_VGA_CELL(Character, Attribute)                                \
    ((u16)((((u16)(Attribute) & 0x00FFU) << 8U) |                         \
           ((u16)(Character) & 0x00FFU)))

/* -------------------------------------------------------------------------- */
/*  Initialization                                                            */
/* -------------------------------------------------------------------------- */

/**
 * @brief Initialize the MBWB VGA driver.
 *
 * This function records the base address of the VGA peripheral, initializes
 * the driver's internal state, selects the default foreground, background,
 * and attribute values, and places the software cursor at row zero, column
 * zero.
 *
 * The function does not necessarily clear the display. Applications should
 * call MBWB_VGA_clear() when a cleared text display is required.
 *
 * @param BaseAddress Base address of the VGA peripheral. For the standard
 *                    MBWB platform, use MBWB_VGA_BASEADDR.
 *
 * @return XST_SUCCESS if the driver was initialized successfully; otherwise
 *         XST_FAILURE.
 */
int MBWB_VGA_initialize(UINTPTR BaseAddress);

/* -------------------------------------------------------------------------- */
/*  Screen operations                                                         */
/* -------------------------------------------------------------------------- */

/**
 * @brief Clear the complete VGA text display.
 *
 * This function fills all text cells with space characters using the current
 * software attribute and then returns the software cursor to row zero,
 * column zero.
 *
 * @return None.
 */
void MBWB_VGA_clear(void);

/**
 * @brief Fill the complete VGA text display with one character.
 *
 * Each text cell is written with the supplied character and the current
 * software attribute. The software cursor is returned to row zero, column
 * zero after the screen has been filled.
 *
 * @param Character Character used to fill every display cell.
 *
 * @return None.
 */
void MBWB_VGA_fill(char Character);

/* -------------------------------------------------------------------------- */
/*  Software cursor operations                                                */
/* -------------------------------------------------------------------------- */

/**
 * @brief Set the software cursor position.
 *
 * The cursor identifies the display cell that will receive the next character
 * written by MBWB_VGA_putChar(), MBWB_VGA_putString(), or MBWB_VGA_printf().
 *
 * @param Row Row index in the range 0 through MBWB_VGA_NUM_ROWS - 1.
 * @param Col Column index in the range 0 through MBWB_VGA_NUM_COLS - 1.
 *
 * @return None.
 */
void MBWB_VGA_setCursor(u32 Row, u32 Col);

/**
 * @brief Get the current software cursor position.
 *
 * @param Row Pointer to a variable that receives the current row index.
 * @param Col Pointer to a variable that receives the current column index.
 *
 * @return None.
 */
void MBWB_VGA_getCursor(u32 *Row, u32 *Col);

/**
 * @brief Move the software cursor to the home position.
 *
 * The home position is row zero, column zero.
 *
 * @return None.
 */
void MBWB_VGA_home(void);

/* -------------------------------------------------------------------------- */
/*  Text-output operations                                                    */
/* -------------------------------------------------------------------------- */

/**
 * @brief Write one character at the current software cursor position.
 *
 * Ordinary characters are written using the current software attribute. After
 * a character is written, the cursor advances to the next display position.
 *
 * The following control characters are handled specially:
 *
 *   - '\n' moves the cursor to column zero of the next row.
 *   - '\r' moves the cursor to column zero of the current row.
 *
 * Cursor behavior at the bottom-right corner is determined by the driver
 * implementation.
 *
 * @param Character Character to write.
 *
 * @return None.
 */
void MBWB_VGA_putChar(char Character);

/**
 * @brief Write a null-terminated string at the current cursor position.
 *
 * Characters are written sequentially using MBWB_VGA_putChar(). Newline and
 * carriage-return characters are therefore processed using the same rules as
 * individual character output.
 *
 * @param String Pointer to the null-terminated string to write.
 *
 * @return None.
 */
void MBWB_VGA_putString(const char *String);

/**
 * @brief Write formatted text at the current cursor position.
 *
 * This function supports a limited subset of printf-style conversion
 * specifiers:
 *
 *   - %c : character
 *   - %s : null-terminated string
 *   - %d : signed decimal integer
 *   - %i : signed decimal integer
 *   - %u : unsigned decimal integer
 *   - %x : unsigned hexadecimal integer using lowercase digits
 *   - %X : unsigned hexadecimal integer using uppercase digits
 *   - %p : pointer value
 *   - %% : percent character
 *
 * Integer field width and zero padding may be supported by the implementation.
 * Floating-point conversions are not supported.
 *
 * @param Format Pointer to the null-terminated format string.
 * @param ...    Arguments corresponding to the format conversions.
 *
 * @return None.
 */
void MBWB_VGA_printf(const char *Format, ...);

/* -------------------------------------------------------------------------- */
/*  Global color operations                                                   */
/* -------------------------------------------------------------------------- */

/**
 * @brief Set the global foreground and background colors.
 *
 * Colors are represented as 12-bit RGB values in 0xRGB format. Each component
 * occupies four bits:
 *
 *   - Bits [11:8] : Red
 *   - Bits [7:4]  : Green
 *   - Bits [3:0]  : Blue
 *
 * Only the least significant 12 bits of each argument are used.
 *
 * @param ForegroundColor New 12-bit foreground color.
 * @param BackgroundColor New 12-bit background color.
 *
 * @return None.
 */
void MBWB_VGA_setColors(u16 ForegroundColor, u16 BackgroundColor);

/**
 * @brief Read the current global foreground color.
 *
 * @return The current 12-bit foreground color in 0xRGB format.
 */
u16 MBWB_VGA_getForegroundColor(void);

/**
 * @brief Read the current global background color.
 *
 * @return The current 12-bit background color in 0xRGB format.
 */
u16 MBWB_VGA_getBackgroundColor(void);

/* -------------------------------------------------------------------------- */
/*  Software attribute operations                                             */
/* -------------------------------------------------------------------------- */

/**
 * @brief Set the software attribute for newly written text cells.
 *
 * The attribute is placed in bits [15:8] of each text cell written after this
 * function is called.
 *
 * The current VGA hardware may ignore the attribute field. The software API
 * is retained so application code will not need to change when palette and
 * per-character attribute support are implemented.
 *
 * @param Attribute New eight-bit software character attribute.
 *
 * @return None.
 */
void MBWB_VGA_setAttribute(u8 Attribute);

/**
 * @brief Read the current software character attribute.
 *
 * @return The eight-bit attribute applied to newly written text cells.
 */
u8 MBWB_VGA_getAttribute(void);

/* -------------------------------------------------------------------------- */
/*  Future hardware cursor support                                            */
/* -------------------------------------------------------------------------- */

/**
 * @brief Enable or disable the hardware cursor.
 *
 * This function is reserved for future hardware-cursor support.
 *
 * @param Enable true to enable the hardware cursor; false to disable it.
 *
 * @return None.
 */
void MBWB_VGA_enableCursor(bool Enable);

/**
 * @brief Select the hardware cursor style.
 *
 * This function is reserved for future hardware-cursor support. The encoding
 * of cursor styles will be defined by the VGA hardware implementation.
 *
 * @param CursorStyle Hardware cursor-style value.
 *
 * @return None.
 */
void MBWB_VGA_setCursorStyle(u32 CursorStyle);

/* -------------------------------------------------------------------------- */
/*  Future palette-RAM support                                                */
/* -------------------------------------------------------------------------- */

/**
 * @brief Write one foreground or background palette entry.
 *
 * This function is reserved for future palette-RAM support.
 *
 * @param ForegroundPalette true to access the foreground palette; false to
 *                          access the background palette.
 * @param Index             Palette index in the range 0 through 15.
 * @param Color             12-bit RGB color in 0xRGB format.
 *
 * @return None.
 */
void MBWB_VGA_setPaletteEntry(bool ForegroundPalette,
                              u32 Index,
                              u16 Color);

/**
 * @brief Read one foreground or background palette entry.
 *
 * This function is reserved for future palette-RAM support.
 *
 * @param ForegroundPalette true to access the foreground palette; false to
 *                          access the background palette.
 * @param Index             Palette index in the range 0 through 15.
 *
 * @return The selected 12-bit palette color in 0xRGB format.
 */
u16 MBWB_VGA_getPaletteEntry(bool ForegroundPalette, u32 Index);

#ifdef __cplusplus
}
#endif

#endif /* MBWB_VGA_H */


