/**
 * @file    MBWB_SSEG.c
 * @brief   Implementation of the MBWB seven-segment display driver.
 *
 * @author Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date    28-Jul-2026
 * @version 1.2
 *
 * @detail
 * This file implements the public API for the MicroBlaze/Wishbone
 * (MBWB) seven-segment display peripheral.
 *
 * The eight display digits are divided into two banks:
 *
 *   - Lower bank: digits 0 through 3
 *   - Upper bank: digits 4 through 7
 *
 * Each display-bank register contains four five-bit character codes.
 * Each character occupies the low five bits of an eight-bit register
 * lane:
 *
 *   - Digit0: bits [4:0]
 *   - Digit1: bits [12:8]
 *   - Digit2: bits [20:16]
 *   - Digit3: bits [28:24]
 *
 * Decimal-point control is embedded in each digit byte:
 *
 *   - Bit 5 controls the decimal point for that digit.
 *   - Bits [7:6] are unused.
 *
 * Register definitions are provided by MBWB_HW.h. Hardware access is
 * performed using the low-level Wishbone register-index functions declared
 * in MBWB_L.h.
 */
/* SPDX-License-Identifier: MIT */

#include "MBWB_SSEG.h"

/* -------------------------------------------------------------------------- */
/*  Private constants                                                         */
/* -------------------------------------------------------------------------- */

/**
 * @brief Maximum unsigned decimal value that fits on eight digits.
 */
#define MBWB_SSEG_MAX_U32_DEC          99999999U

/* -------------------------------------------------------------------------- */
/*  Private variables                                                         */
/* -------------------------------------------------------------------------- */

/**
 * @brief Base address of the seven-segment display peripheral.
 *
 * The standard MBWB seven-segment address is used by default. A different
 * address may be selected by calling MBWB_SSEG_initialize().
 */
static UINTPTR MBWB_SSEG_BaseAddress = MBWB_SSEG_BASEADDR;

/* -------------------------------------------------------------------------- */
/*  Private helper-function prototypes                                        */
/* -------------------------------------------------------------------------- */

static bool MBWB_SSEG_isValidBank(MBWB_SSEG_banks_t Bank);
static bool MBWB_SSEG_isValidDigit(MBWB_SSEG_digits_t Digit);
static bool MBWB_SSEG_isValidCharacter(MBWB_SSEG_charcodes_t Character);
static bool MBWB_SSEG_isValidDpMask(MBWB_SSEG_decpts_t DpMask);

static u32 MBWB_SSEG_getBankRegister(MBWB_SSEG_banks_t Bank);
static MBWB_SSEG_banks_t MBWB_SSEG_getDigitBank(MBWB_SSEG_digits_t Digit);
static u32 MBWB_SSEG_getLocalDigit(MBWB_SSEG_digits_t Digit);
static MBWB_SSEG_decpts_t MBWB_SSEG_getDpMask(MBWB_SSEG_banks_t Bank);

/* -------------------------------------------------------------------------- */
/*  Initialization                                                            */
/* -------------------------------------------------------------------------- */

int MBWB_SSEG_initialize(UINTPTR BaseAddress)
{
    MBWB_SSEG_BaseAddress = BaseAddress;

    return XST_SUCCESS;
}

/* -------------------------------------------------------------------------- */
/*  Raw register access                                                       */
/* -------------------------------------------------------------------------- */

/***** MBWB_SSET_getData() - Read the raw 32-bit data register for a selected display bank *****/
u32 MBWB_SSEG_getData(MBWB_SSEG_banks_t Bank)
{
    u32 RegisterIndex;

    if (!MBWB_SSEG_isValidBank(Bank))
    {
        return 0U;
    }

    RegisterIndex = MBWB_SSEG_getBankRegister(Bank);

    return MBWB_L_readReg(MBWB_SSEG_BaseAddress, RegisterIndex);
}

/***** MBWB_SSEG_setData() - Write raw 32-bit data to a selected display bank *****/
void MBWB_SSEG_setData(MBWB_SSEG_banks_t Bank, u32 Data)
{
    u32 RegisterIndex;

    if (!MBWB_SSEG_isValidBank(Bank))
    {
        return;
    }

    RegisterIndex = MBWB_SSEG_getBankRegister(Bank);

    MBWB_L_writeReg(MBWB_SSEG_BaseAddress,
                    RegisterIndex,
                    Data);
}

/* -------------------------------------------------------------------------- */
/*  Individual digit and decimal-point control                                */
/* -------------------------------------------------------------------------- */

/***** MBWB_SSEG_setDigit() - Set one seven-segment digit to a specified character *****/
int MBWB_SSEG_setDigit(MBWB_SSEG_digits_t Digit,
                       MBWB_SSEG_charcodes_t Character)
{
    MBWB_SSEG_banks_t Bank;
    u32 LocalDigit;
    u32 Shift;
    u32 Data;

    if (!MBWB_SSEG_isValidDigit(Digit) ||
        !MBWB_SSEG_isValidCharacter(Character))
    {
        return XST_INVALID_PARAM;
    }

    Bank       = MBWB_SSEG_getDigitBank(Digit);
    LocalDigit = MBWB_SSEG_getLocalDigit(Digit);
    Shift      = LocalDigit * MBWB_SSEG_CHAR_STRIDE;

    Data = MBWB_SSEG_getData(Bank);

    /*
     * Clear only the selected 5-bit character field and then insert the
     * new hardware character code. The decimal-point bit is preserved.
     */
    Data &= ~(MBWB_SSEG_CHAR_MASK << Shift);
    Data |= (((u32)Character & MBWB_SSEG_CHAR_MASK) << Shift);

    MBWB_SSEG_setData(Bank, Data);

    return XST_SUCCESS;
}

/***** MBWB_SSEG_setDecimalPoint() - Enable or disable the decimal point for one digit *****/
int MBWB_SSEG_setDecimalPoint(MBWB_SSEG_digits_t Digit, bool Enable)
{
    MBWB_SSEG_banks_t Bank;
    u32 LocalDigit;
    u32 Shift;
    u32 Data;
    u32 DecimalPointMask;

    if (!MBWB_SSEG_isValidDigit(Digit))
    {
        return XST_INVALID_PARAM;
    }

    Bank       = MBWB_SSEG_getDigitBank(Digit);
    LocalDigit = MBWB_SSEG_getLocalDigit(Digit);

    /*
     * Each digit occupies one byte. The decimal point is bit 5
     * of that digit's byte.
     */
    Shift = (LocalDigit * MBWB_SSEG_CHAR_STRIDE) + 5U;
    DecimalPointMask = 1U << Shift;

    Data = MBWB_SSEG_getData(Bank);

    if (Enable)
    {
        Data |= DecimalPointMask;
    }
    else
    {
        Data &= ~DecimalPointMask;
    }

    MBWB_SSEG_setData(Bank, Data);

    return XST_SUCCESS;
}


/* -------------------------------------------------------------------------- */
/*  Bank-level display functions                                              */
/* -------------------------------------------------------------------------- */

/***** MBWB_SSEG_setAllDigits()-Set all four digits and decimal points in one display bank *****/
int MBWB_SSEG_setAllDigits(MBWB_SSEG_banks_t Bank,
                           MBWB_SSEG_charcodes_t Digit3,
                           MBWB_SSEG_charcodes_t Digit2,
                           MBWB_SSEG_charcodes_t Digit1,
                           MBWB_SSEG_charcodes_t Digit0,
                           MBWB_SSEG_decpts_t DpMask)
{
    u32 Data;

    if (!MBWB_SSEG_isValidBank(Bank)        ||
        !MBWB_SSEG_isValidCharacter(Digit3) ||
        !MBWB_SSEG_isValidCharacter(Digit2) ||
        !MBWB_SSEG_isValidCharacter(Digit1) ||
        !MBWB_SSEG_isValidCharacter(Digit0) ||
        !MBWB_SSEG_isValidDpMask(DpMask))
    {
        return XST_INVALID_PARAM;
    }

    Data  = ((u32)Digit0 & MBWB_SSEG_CHAR_MASK);
    Data |= ((DpMask & 0x01U) != 0U) ? (1U << 5U) : 0U;

    Data |= ((u32)Digit1 & MBWB_SSEG_CHAR_MASK) << 8U;
    Data |= ((DpMask & 0x02U) != 0U) ? (1U << 13U) : 0U;

    Data |= ((u32)Digit2 & MBWB_SSEG_CHAR_MASK) << 16U;
    Data |= ((DpMask & 0x04U) != 0U) ? (1U << 21U) : 0U;

    Data |= ((u32)Digit3 & MBWB_SSEG_CHAR_MASK) << 24U;
    Data |= ((DpMask & 0x08U) != 0U) ? (1U << 29U) : 0U;

    MBWB_SSEG_setData(Bank, Data);

    return XST_SUCCESS;
}

/***** MBWB_SSEG_putU16Hex() - Display a 16-bit hexadecimal value on one display bank *****/
int MBWB_SSEG_putU16Hex(MBWB_SSEG_banks_t Bank, u16 Data)
{
    MBWB_SSEG_decpts_t DpMask;

    if (!MBWB_SSEG_isValidBank(Bank))
    {
        return XST_INVALID_PARAM;
    }

    /*
     * Preserve the current decimal-point state while replacing the four
     * character codes.
     */
    DpMask = MBWB_SSEG_getDpMask(Bank);

    return MBWB_SSEG_setAllDigits(
        Bank,
        (MBWB_SSEG_charcodes_t)((Data >> 12U) & 0x0FU),
        (MBWB_SSEG_charcodes_t)((Data >>  8U) & 0x0FU),
        (MBWB_SSEG_charcodes_t)((Data >>  4U) & 0x0FU),
        (MBWB_SSEG_charcodes_t)( Data         & 0x0FU),
        DpMask);
}

/***** MBWB_SSET_putU32Hex() - Display a 32-bit hexadecimal value across all eight digits *****/
int MBWB_SSEG_putU32Hex(u32 Data)
{
    int Status;

    Status = MBWB_SSEG_putU16Hex(
        MBWB_SSEG_LO,
        (u16)(Data & 0x0000FFFFU));

    if (Status != XST_SUCCESS)
    {
        return Status;
    }

    return MBWB_SSEG_putU16Hex(
        MBWB_SSEG_HI,
        (u16)((Data >> 16U) & 0x0000FFFFU));
}

/***** MBWB_SSEG_putU32Dec() - Display a 32-bit unsigned decimal value across all eight digits *****/
int MBWB_SSEG_putU32Dec(u32 Data, bool Trim)
{
    MBWB_SSEG_charcodes_t Digits[MBWB_SSEG_NUM_DIGITS];
    MBWB_SSEG_decpts_t DpLo;
    MBWB_SSEG_decpts_t DpHi;
    u32 Temp;
    u32 Index;
    int Status;

    /*
     * Eight decimal digits can display values only through 99,999,999.
     * Reject larger values rather than silently truncating the most
     * significant digits.
     */
    if (Data > MBWB_SSEG_MAX_U32_DEC)
    {
        return XST_INVALID_PARAM;
    }

    Temp = Data;

    for (Index = 0U; Index < MBWB_SSEG_NUM_DIGITS; ++Index)
    {
        Digits[Index] = (MBWB_SSEG_charcodes_t)(Temp % 10U);
        Temp /= 10U;
    }

    /*
     * Replace leading zeroes with blanks, but always leave Digit0 visible.
     * Consequently, a value of zero is displayed as a single zero.
     */
    if (Trim)
    {
        for (Index = MBWB_SSEG_NUM_DIGITS - 1U; Index > 0U; --Index)
        {
            if (Digits[Index] == MBWB_SSEG_CC_0)
            {
                Digits[Index] = MBWB_SSEG_CC_BLANK;
            }
            else
            {
                break;
            }
        }
    }

    /*
     * Preserve the current decimal-point state in both display banks.
     */
    DpLo = MBWB_SSEG_getDpMask(MBWB_SSEG_LO);
    DpHi = MBWB_SSEG_getDpMask(MBWB_SSEG_HI);

    Status = MBWB_SSEG_setAllDigits(
        MBWB_SSEG_LO,
        Digits[3],
        Digits[2],
        Digits[1],
        Digits[0],
        DpLo);

    if (Status != XST_SUCCESS)
    {
        return Status;
    }

    return MBWB_SSEG_setAllDigits(
        MBWB_SSEG_HI,
        Digits[7],
        Digits[6],
        Digits[5],
        Digits[4],
        DpHi);
}


/* -------------------------------------------------------------------------- */
/*  Private helper functions                                                  */
/* -------------------------------------------------------------------------- */

/**
 * @brief Determine whether a display-bank identifier is valid.
 *
 * @param Bank Display-bank identifier to validate.
 *
 * @return true if @p Bank is MBWB_SSEG_LO or MBWB_SSEG_HI;
 *         otherwise false.
 */
 
static bool MBWB_SSEG_isValidBank(MBWB_SSEG_banks_t Bank)
{
    return (Bank == MBWB_SSEG_LO) ||
           (Bank == MBWB_SSEG_HI);
}

/**
 * @brief Determine whether a seven-segment digit identifier is valid.
 *
 * @param Digit Digit identifier to validate.
 *
 * @return true if @p Digit identifies one of the eight display digits;
 *         otherwise false.
 */
static bool MBWB_SSEG_isValidDigit(MBWB_SSEG_digits_t Digit)
{
    return ((u32)Digit < MBWB_SSEG_NUM_DIGITS);
}

/**
 * @brief Determine whether a seven-segment character code is valid.
 *
 * @param Character Character code to validate.
 *
 * @return true if @p Character is one of the character codes defined by
 *         MBWB_SSEG_charcodes_t; otherwise false.
 */
static bool MBWB_SSEG_isValidCharacter(MBWB_SSEG_charcodes_t Character)
{
    return ((u32)Character <= (u32)MBWB_SSEG_CC_BLANK1);
}

/**
 * @brief Determine whether a decimal-point mask is valid.
 *
 * A valid decimal-point mask contains only the four bits assigned to the
 * digits in one display bank.
 *
 * @param DpMask Decimal-point mask to validate.
 *
 * @return true if @p DpMask contains no bits outside MBWB_SSEG_DP_MASK;
 *         otherwise false.
 */
static bool MBWB_SSEG_isValidDpMask(MBWB_SSEG_decpts_t DpMask)
{
    return (((u32)DpMask & ~MBWB_SSEG_DP_MASK) == 0U);
}

/**
 * @brief Get the data-register index for a selected display bank.
 *
 * @param Bank Display bank whose register index is required.
 *
 * @return MBWB_SSEG_DIGITS_LO_REG for MBWB_SSEG_LO, or
 *         MBWB_SSEG_DIGITS_HI_REG for MBWB_SSEG_HI.
 */
static u32 MBWB_SSEG_getBankRegister(MBWB_SSEG_banks_t Bank)
{
    return (Bank == MBWB_SSEG_LO)
           ? MBWB_SSEG_DIGITS_LO_REG
           : MBWB_SSEG_DIGITS_HI_REG;
}

/**
 * @brief Determine the display bank containing a selected digit.
 *
 * Digits 0 through 3 are assigned to the lower bank. Digits 4 through 7
 * are assigned to the upper bank.
 *
 * @param Digit Digit whose display bank is required.
 *
 * @return MBWB_SSEG_LO if @p Digit is in the lower bank;
 *         otherwise MBWB_SSEG_HI.
 */
static MBWB_SSEG_banks_t MBWB_SSEG_getDigitBank(MBWB_SSEG_digits_t Digit)
{
    return ((u32)Digit < MBWB_SSEG_DIGITS_PER_BANK)
           ? MBWB_SSEG_LO
           : MBWB_SSEG_HI;
}

/**
 * @brief Convert a global digit identifier to a bank-local digit index.
 *
 * The returned value is in the range 0 through 3 and identifies the digit's
 * position within its lower or upper display bank.
 *
 * @param Digit Global digit identifier.
 *
 * @return The corresponding zero-based digit index within the selected bank.
 */
static u32 MBWB_SSEG_getLocalDigit(MBWB_SSEG_digits_t Digit)
{
    return (u32)Digit % MBWB_SSEG_DIGITS_PER_BANK;
}

/**
 * @brief Read the decimal-point mask for a selected display bank.
 *
 * This function reads the selected display-bank register and extracts bit 5
 * from each of its four digit bytes. The four decimal-point states are returned
 * as a right-justified mask in which bit 0 corresponds to the least-significant
 * digit in the bank.
 *
 * @param Bank Display bank whose decimal-point mask is to be read.
 *
 * @return Decimal-point enables as a right-justified four-bit mask.
 */
static MBWB_SSEG_decpts_t MBWB_SSEG_getDpMask(MBWB_SSEG_banks_t Bank)
{
    u32 Data;
    u32 LocalDigit;
    u32 Shift;
    u32 DpMask;

    Data = MBWB_SSEG_getData(Bank);
    DpMask = 0U;

    for (LocalDigit = 0U;
         LocalDigit < MBWB_SSEG_DIGITS_PER_BANK;
         ++LocalDigit)
    {
        Shift = (LocalDigit * MBWB_SSEG_CHAR_STRIDE) + 5U;

        if ((Data & (1U << Shift)) != 0U)
        {
            DpMask |= 1U << LocalDigit;
        }
    }

    return (MBWB_SSEG_decpts_t)DpMask;
}
