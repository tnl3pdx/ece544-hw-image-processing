/**
 * @file    MBWB_VGA.c
 * @brief   Implementation of the MBWB Wishbone text-mode VGA driver.
 *
 * @author Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date    18-Jul-2026
 * @version 1.0
 *
 * @detail
 * This file implements the public API for the MicroBlaze/Wishbone (MBWB)
 * text-mode VGA peripheral.
 *
 * The controller provides an 80-column by 30-row text display. Each display
 * cell is represented by a packed 16-bit value containing an eight-bit
 * CP437/ASCII character and an eight-bit software attribute.
 *
 * The driver maintains the current cursor position and character attribute in
 * software. Global foreground and background colors are stored in VGA hardware
 * registers. Hardware-cursor and palette-RAM functions are retained as stubs
 * until the corresponding hardware support is implemented.
 */
 /* SPDX-License-Identifier: MIT */
 

#include "MBWB_VGA.h"

#include <stdarg.h>
#include <stddef.h>

/* -------------------------------------------------------------------------- */
/*  Private driver state                                                      */
/* -------------------------------------------------------------------------- */

/** @brief Base address of the VGA peripheral. */
static UINTPTR MBWB_VGA_BaseAddress = MBWB_VGA_BASEADDR;

/** @brief Current zero-based software cursor row. */
static u32 MBWB_VGA_CursorRow = 0U;

/** @brief Current zero-based software cursor column. */
static u32 MBWB_VGA_CursorCol = 0U;

/** @brief Attribute applied to newly written text cells. */
static u8 MBWB_VGA_CurrentAttribute = MBWB_VGA_DEFAULT_ATTR;

/* -------------------------------------------------------------------------- */
/*  Private helper-function prototypes                                        */
/* -------------------------------------------------------------------------- */

static u32 MBWB_VGA_cellIndex(u32 Row, u32 Col);
static u32 MBWB_VGA_cellOffset(u32 Row, u32 Col);
static void MBWB_VGA_writeCell(u32 Row, u32 Col, u16 Cell);
static void MBWB_VGA_writeCells2(u32 CellIndex, u16 Cell0, u16 Cell1);
static void MBWB_VGA_advanceCursor(void);
static void MBWB_VGA_putUnsigned(u32 Value, u32 Base, bool Uppercase, u32 Width, char PadChar);
static void MBWB_VGA_putSigned(s32 Value, u32 Width, char PadChar);
static u32 MBWB_VGA_strlen(const char *String);

/* -------------------------------------------------------------------------- */
/*  Initialization                                                            */
/* -------------------------------------------------------------------------- */

/***** MBWB_VGA_initialize() - Initialize the MBWB VGA driver. *****/
int MBWB_VGA_initialize(UINTPTR BaseAddress)
{
    MBWB_VGA_BaseAddress      = BaseAddress;
    MBWB_VGA_CursorRow        = 0U;
    MBWB_VGA_CursorCol        = 0U;
    MBWB_VGA_CurrentAttribute = MBWB_VGA_DEFAULT_ATTR;

    MBWB_VGA_setColors(MBWB_VGA_DEFAULT_FG, MBWB_VGA_DEFAULT_BG);

    return XST_SUCCESS;
}

/* -------------------------------------------------------------------------- */
/*  Screen operations                                                         */
/* -------------------------------------------------------------------------- */

/***** MBWB_VGA_clear() - Clear the complete VGA text display. *****/
void MBWB_VGA_clear(void)
{
    u32 CellIndex;
    const u16 BlankCell = MBWB_VGA_CELL(MBWB_VGA_SPACE_CHAR,
                                         MBWB_VGA_CurrentAttribute);

    for (CellIndex = 0U;
         CellIndex < MBWB_VGA_NUM_CELLS;
         CellIndex += 2U)
    {
        MBWB_VGA_writeCells2(CellIndex, BlankCell, BlankCell);
    }

    MBWB_VGA_home();
}

/***** MBWB_VGA_fill() - Fill the complete VGA text display with one character. *****/
void MBWB_VGA_fill(char Character)
{
    u32 CellIndex;
    const u16 Cell = MBWB_VGA_CELL(Character, MBWB_VGA_CurrentAttribute);

    for (CellIndex = 0U;
         CellIndex < MBWB_VGA_NUM_CELLS;
         CellIndex += 2U)
    {
        MBWB_VGA_writeCells2(CellIndex, Cell, Cell);
    }

    MBWB_VGA_home();
}

/* -------------------------------------------------------------------------- */
/*  Software cursor operations                                                */
/* -------------------------------------------------------------------------- */

/***** MBWB_VGA_setCursor() - Set the software cursor position. *****/
void MBWB_VGA_setCursor(u32 Row, u32 Col)
{
    if (Row < MBWB_VGA_NUM_ROWS)
    {
        MBWB_VGA_CursorRow = Row;
    }

    if (Col < MBWB_VGA_NUM_COLS)
    {
        MBWB_VGA_CursorCol = Col;
    }
}

/***** MBWB_VGA_getCursor() - Get the current software cursor position. *****/
void MBWB_VGA_getCursor(u32 *Row, u32 *Col)
{
    if (Row != NULL)
    {
        *Row = MBWB_VGA_CursorRow;
    }

    if (Col != NULL)
    {
        *Col = MBWB_VGA_CursorCol;
    }
}

/***** MBWB_VGA_home() - Move the software cursor to the home position. *****/
void MBWB_VGA_home(void)
{
    MBWB_VGA_CursorRow = 0U;
    MBWB_VGA_CursorCol = 0U;
}

/* -------------------------------------------------------------------------- */
/*  Text-output operations                                                    */
/* -------------------------------------------------------------------------- */

/***** MBWB_VGA_putChar() - Write one character at the current software cursor position. *****/
void MBWB_VGA_putChar(char Character)
{
    if (Character == '\n')
    {
        MBWB_VGA_CursorCol = 0U;
        MBWB_VGA_CursorRow++;

        if (MBWB_VGA_CursorRow >= MBWB_VGA_NUM_ROWS)
        {
            MBWB_VGA_CursorRow = 0U;
        }

        return;
    }

    if (Character == '\r')
    {
        MBWB_VGA_CursorCol = 0U;
        return;
    }

    MBWB_VGA_writeCell(
        MBWB_VGA_CursorRow,
        MBWB_VGA_CursorCol,
        MBWB_VGA_CELL(Character, MBWB_VGA_CurrentAttribute));

    MBWB_VGA_advanceCursor();
}

/***** MBWB_VGA_putString() - Write a null-terminated string at the current cursor position. *****/
void MBWB_VGA_putString(const char *String)
{
    if (String == NULL)
    {
        return;
    }

    while (*String != '\0')
    {
        MBWB_VGA_putChar(*String);
        String++;
    }
}

/***** MBWB_VGA_printf() - Write formatted text at the current cursor position. *****/
void MBWB_VGA_printf(const char *Format, ...)
{
    va_list Arguments;

    if (Format == NULL)
    {
        return;
    }

    va_start(Arguments, Format);

    while (*Format != '\0')
    {
        if (*Format != '%')
        {
            MBWB_VGA_putChar(*Format);
            Format++;
            continue;
        }

        Format++;

        if (*Format == '%')
        {
            MBWB_VGA_putChar('%');
            Format++;
            continue;
        }

        {
            bool ZeroPad = false;
            u32 Width = 0U;
            char Conversion;

            if (*Format == '0')
            {
                ZeroPad = true;
                Format++;
            }

            while ((*Format >= '0') && (*Format <= '9'))
            {
                Width = (Width * 10U) + (u32)(*Format - '0');
                Format++;
            }

            Conversion = *Format;

            if (Conversion == '\0')
            {
                break;
            }

            switch (Conversion)
            {
                case 'c':
                    MBWB_VGA_putChar((char)va_arg(Arguments, int));
                    break;

                case 's':
                {
                    const char *String = va_arg(Arguments, const char *);
                    const char *DisplayedString =
                        (String == NULL) ? "(null)" : String;
                    u32 Length = MBWB_VGA_strlen(DisplayedString);

                    while (Length < Width)
                    {
                        MBWB_VGA_putChar(' ');
                        Length++;
                    }

                    MBWB_VGA_putString(DisplayedString);
                    break;
                }

                case 'd':
                case 'i':
                    MBWB_VGA_putSigned((s32)va_arg(Arguments, int),
                                       Width,
                                       ZeroPad ? '0' : ' ');
                    break;

                case 'u':
                    MBWB_VGA_putUnsigned(
                        (u32)va_arg(Arguments, unsigned int),
                        10U,
                        false,
                        Width,
                        ZeroPad ? '0' : ' ');
                    break;

                case 'x':
                    MBWB_VGA_putUnsigned(
                        (u32)va_arg(Arguments, unsigned int),
                        16U,
                        false,
                        Width,
                        ZeroPad ? '0' : ' ');
                    break;

                case 'X':
                    MBWB_VGA_putUnsigned(
                        (u32)va_arg(Arguments, unsigned int),
                        16U,
                        true,
                        Width,
                        ZeroPad ? '0' : ' ');
                    break;

                case 'p':
                {
                    const UINTPTR PointerValue =
                        (UINTPTR)va_arg(Arguments, void *);

                    MBWB_VGA_putString("0x");
                    MBWB_VGA_putUnsigned((u32)PointerValue,
                                         16U,
                                         false,
                                         (Width == 0U) ? 8U : Width,
                                         '0');
                    break;
                }

                default:
                    MBWB_VGA_putChar('%');
                    MBWB_VGA_putChar(Conversion);
                    break;
            }

            Format++;
        }
    }

    va_end(Arguments);
}

/* -------------------------------------------------------------------------- */
/*  Global color operations                                                   */
/* -------------------------------------------------------------------------- */

/***** MBWB_VGA_setColors() - Set the global foreground and background colors. *****/
void MBWB_VGA_setColors(u16 ForegroundColor, u16 BackgroundColor)
{
    MBWB_mWriteReg(MBWB_VGA_BaseAddress,
                   MBWB_VGA_FGCOLOR_OFFSET,
                   (u32)(ForegroundColor & MBWB_VGA_COLOR_MASK));

    MBWB_mWriteReg(MBWB_VGA_BaseAddress,
                   MBWB_VGA_BGCOLOR_OFFSET,
                   (u32)(BackgroundColor & MBWB_VGA_COLOR_MASK));
}

/***** MBWB_VGA_getForegroundColor() - Read the current global foreground color. *****/
u16 MBWB_VGA_getForegroundColor(void)
{
    return (u16)(MBWB_mReadReg(MBWB_VGA_BaseAddress,
                               MBWB_VGA_FGCOLOR_OFFSET) &
                 MBWB_VGA_COLOR_MASK);
}

/***** MBWB_VGA_getBackgroundColor() - Read the current global background color. *****/
u16 MBWB_VGA_getBackgroundColor(void)
{
    return (u16)(MBWB_mReadReg(MBWB_VGA_BaseAddress,
                               MBWB_VGA_BGCOLOR_OFFSET) &
                 MBWB_VGA_COLOR_MASK);
}

/* -------------------------------------------------------------------------- */
/*  Software attribute operations                                             */
/* -------------------------------------------------------------------------- */

/***** MBWB_VGA_setAttribute() - Set the software attribute for newly written text cells. *****/
void MBWB_VGA_setAttribute(u8 Attribute)
{
    MBWB_VGA_CurrentAttribute = Attribute;
}

/***** MBWB_VGA_getAttribute() - Read the current software character attribute. *****/
u8 MBWB_VGA_getAttribute(void)
{
    return MBWB_VGA_CurrentAttribute;
}

/* -------------------------------------------------------------------------- */
/*  Future hardware cursor support                                            */
/* -------------------------------------------------------------------------- */

/***** MBWB_VGA_enableCursor() - Enable or disable the hardware cursor. *****/
void MBWB_VGA_enableCursor(bool Enable)
{
    (void)Enable;

    /* TBD: Write the VGA cursor-enable bit when hardware support exists. */
}

/***** MBWB_VGA_setCursorStyle() - Select the hardware cursor style. *****/
void MBWB_VGA_setCursorStyle(u32 CursorStyle)
{
    (void)CursorStyle;

    /* TBD: Write the VGA cursor-style field when hardware support exists. */
}

/* -------------------------------------------------------------------------- */
/*  Future palette-RAM support                                                */
/* -------------------------------------------------------------------------- */

/***** MBWB_VGA_setPaletteEntry() - Write one foreground or background palette entry. *****/
void MBWB_VGA_setPaletteEntry(bool ForegroundPalette,
                              u32 Index,
                              u16 Color)
{
    (void)ForegroundPalette;
    (void)Index;
    (void)Color;

    /* TBD: Write the selected palette entry when hardware support exists. */
}

/***** MBWB_VGA_getPaletteEntry() - Read one foreground or background palette entry. *****/
u16 MBWB_VGA_getPaletteEntry(bool ForegroundPalette, u32 Index)
{
    (void)ForegroundPalette;
    (void)Index;

    /* TBD: Read the selected palette entry when hardware support exists. */
    return 0U;
}


/* -------------------------------------------------------------------------- */
/*  Private helper-function definitions                                       */
/* -------------------------------------------------------------------------- */

/**
 * @brief Convert a row and column to a linear text-buffer cell index.
 *
 * @param Row Zero-based display row.
 * @param Col Zero-based display column.
 *
 * @return The zero-based linear text-buffer cell index.
 */
static u32 MBWB_VGA_cellIndex(u32 Row, u32 Col)
{
    return (Row * MBWB_VGA_NUM_COLS) + Col;
}

/***** MBWB_VGA_cellOffset() - Convert a row and column to a VGA text-buffer byte offset. *****/
static u32 MBWB_VGA_cellOffset(u32 Row, u32 Col)
{
    return MBWB_VGA_TEXT_BUFFER_OFFSET +
           (MBWB_VGA_cellIndex(Row, Col) * MBWB_VGA_CELL_SIZE);
}

/***** MBWB_VGA_writeCell() - Write one packed 16-bit text cell to the VGA text buffer. *****/
static void MBWB_VGA_writeCell(u32 Row, u32 Col, u16 Cell)
{
    if ((Row >= MBWB_VGA_NUM_ROWS) || (Col >= MBWB_VGA_NUM_COLS))
    {
        return;
    }

    MBWB_mWriteReg16(MBWB_VGA_BaseAddress,
                     MBWB_VGA_cellOffset(Row, Col),
                     Cell);
}

/**
 * @brief Convert a row and column to a VGA text-buffer byte offset.
 *
 * @param Row Zero-based display row.
 * @param Col Zero-based display column.
 *
 * @return The byte offset of the selected text cell from the VGA peripheral
 *         base address.
 */
static void MBWB_VGA_writeCells2(u32 CellIndex, u16 Cell0, u16 Cell1)
{
    u32 ByteOffset;
    u32 PackedCells;

    if (((CellIndex & 0x1U) != 0U) ||
        ((CellIndex + 1U) >= MBWB_VGA_NUM_CELLS))
    {
        return;
    }

    ByteOffset = MBWB_VGA_TEXT_BUFFER_OFFSET +
                 (CellIndex * MBWB_VGA_CELL_SIZE);

    PackedCells = ((u32)Cell1 << 16U) | (u32)Cell0;

    MBWB_mWriteReg(MBWB_VGA_BaseAddress, ByteOffset, PackedCells);
}

/**
 * @brief Advance the software cursor to the next display position.
 *
 * The cursor advances by one column, wraps to the next row at the right edge,
 * and wraps to the home position after the bottom-right display cell.
 *
 * @return None.
 */
static void MBWB_VGA_advanceCursor(void)
{
    MBWB_VGA_CursorCol++;

    if (MBWB_VGA_CursorCol >= MBWB_VGA_NUM_COLS)
    {
        MBWB_VGA_CursorCol = 0U;
        MBWB_VGA_CursorRow++;
    }

    if (MBWB_VGA_CursorRow >= MBWB_VGA_NUM_ROWS)
    {
        MBWB_VGA_CursorRow = 0U;
    }
}

/**
 * @brief Write an unsigned integer using the requested base and field format.
 *
 * @param Value     Unsigned value to display.
 * @param Base      Numeric base in the range 2 through 16.
 * @param Uppercase true to use uppercase hexadecimal digits; false to use
 *                  lowercase digits.
 * @param Width     Minimum output-field width.
 * @param PadChar   Character used to pad the field on the left.
 *
 * @return None.
 */
static void MBWB_VGA_putUnsigned(u32 Value,
                                 u32 Base,
                                 bool Uppercase,
                                 u32 Width,
                                 char PadChar)
{
    char Buffer[33];
    u32 NumDigits = 0U;
    const char *DigitCharacters = Uppercase
        ? "0123456789ABCDEF"
        : "0123456789abcdef";

    if ((Base < 2U) || (Base > 16U))
    {
        return;
    }

    if (Value == 0U)
    {
        Buffer[NumDigits] = '0';
        NumDigits++;
    }
    else
    {
        while ((Value != 0U) && (NumDigits < (u32)sizeof(Buffer)))
        {
            Buffer[NumDigits] = DigitCharacters[Value % Base];
            NumDigits++;
            Value /= Base;
        }
    }

    while (NumDigits < Width)
    {
        MBWB_VGA_putChar(PadChar);
        Width--;
    }

    while (NumDigits > 0U)
    {
        NumDigits--;
        MBWB_VGA_putChar(Buffer[NumDigits]);
    }
}

/**
 * @brief Write a signed decimal integer using the requested field format.
 *
 * @param Value   Signed value to display.
 * @param Width   Minimum output-field width, including a minus sign.
 * @param PadChar Character used to pad the field on the left.
 *
 * @return None.
 */
static void MBWB_VGA_putSigned(s32 Value, u32 Width, char PadChar)
{
    u32 Magnitude;

    if (Value < 0)
    {
        MBWB_VGA_putChar('-');

        /* Unsigned subtraction avoids overflow for the most-negative s32. */
        Magnitude = 0U - (u32)Value;

        if (Width > 0U)
        {
            Width--;
        }
    }
    else
    {
        Magnitude = (u32)Value;
    }

    MBWB_VGA_putUnsigned(Magnitude, 10U, false, Width, PadChar);
}

/***** MBWB_VGA_strlen() - Determine the length of a null-terminated string. *****/
static u32 MBWB_VGA_strlen(const char *String)
{
    u32 Length = 0U;

    if (String == NULL)
    {
        return 0U;
    }

    while (String[Length] != '\0')
    {
        Length++;
    }

    return Length;
}
