/**
 * @file    MBWB_BIO.c
 * @brief   Implementation of the MBWB Board I/O peripheral driver.
 *
 * @author Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date    16-Jul-2026
 * @version 1.0
 *
 * @detail
 * This file implements the public API for the MicroBlaze/Wishbone
 * (MBWB) Board I/O peripheral.
 *
 * The Board I/O peripheral provides access to (the "superset" of the boards we support:
 *   - 16 slide switches
 *   - 5 pushbuttons  (4 on the RD Boolean Board)
 *   - 16 discrete LEDs
 *   - 2 RGB LEDs
 *   - Board I/O interrupt control and status
 *   - Board identification and configuration registers
 *
 * Register addresses and field definitions are provided by MBWB_HW.h and
 * MBWB_BIO.h. Hardware access is performed using the low-level Wishbone
 * register-index functions declared in MBWB_L.h.
 */
/* SPDX-License-Identifier: MIT */

#include "MBWB_BIO.h"

/* -------------------------------------------------------------------------- */
/*  Private variables                                                         */
/* -------------------------------------------------------------------------- */

/**
 * @brief Base address of the Board I/O peripheral.
 *
 * The standard MBWB Board I/O address is used by default. A different address
 * may be selected by calling MBWB_BIO_initialize().
 */
static UINTPTR MBWB_BIO_BaseAddress = MBWB_BIO_BASEADDR;

/* -------------------------------------------------------------------------- */
/*  Private helper-function prototypes                                        */
/* -------------------------------------------------------------------------- */

static bool MBWB_BIO_isValidButton(MBWB_BIO_btns_t Button);
static bool MBWB_BIO_isValidRGBLED(MBWB_BIO_rgbleds_t LED);
static u32 MBWB_BIO_getRGBRegister(MBWB_BIO_rgbleds_t LED);

/* -------------------------------------------------------------------------- */
/*  Initialization                                                            */
/* -------------------------------------------------------------------------- */

/***** MBWB_BIO_initialize() - Initializes the Board IO driver *****/
int MBWB_BIO_initialize(UINTPTR BaseAddress)
{
    MBWB_BIO_BaseAddress = BaseAddress;

    return XST_SUCCESS;
}

/* -------------------------------------------------------------------------- */
/*  Board input functions                                                     */
/* -------------------------------------------------------------------------- */

/***** MBWB_BIO_getBoardInputs() - returns the value of the switches and buttons *****/
u32 MBWB_BIO_getBoardInputs(void)
{
    return MBWB_L_readReg(MBWB_BIO_BaseAddress,
                          MBWB_BIO_BOARD_IN_REG);
}

/***** MBWB_BIO_getButtons() - returns the values for all the pushbuttons *****/
u8 MBWB_BIO_getButtons(void)
{
    u32 BoardInputs;

    BoardInputs = MBWB_BIO_getBoardInputs();

    return (u8)((BoardInputs & MBWB_BIO_BUTTON_MASK)
                >> MBWB_BIO_BUTTON_SHIFT);
}

/***** MBWB_BIO_getSwitches() - returns the current value of the switches *****/
u16 MBWB_BIO_getSwitches(void)
{
    u32 BoardInputs;

    BoardInputs = MBWB_BIO_getBoardInputs();

    return (u16)((BoardInputs & MBWB_BIO_SWITCH_MASK)
                 >> MBWB_BIO_SWITCH_SHIFT);
}

/***** MBWB_BIO_isPressed() - returns TRUE if the specified button is pressed *****/
bool MBWB_BIO_isPressed(MBWB_BIO_btns_t Button)
{
    u8 ButtonStates;

    if (!MBWB_BIO_isValidButton(Button))
    {
        return false;
    }

    ButtonStates = MBWB_BIO_getButtons();

    return ((ButtonStates >> (u32)Button) & 0x01U) != 0U;
}


/* -------------------------------------------------------------------------- */
/*  Discrete LED functions                                                    */
/* -------------------------------------------------------------------------- */

/***** MBWB_BIO_getLEDs() - returns the current values of the switches *****/
u16 MBWB_BIO_getLEDs(void)
{
    u32 LEDValue;

    LEDValue = MBWB_L_readReg(MBWB_BIO_BaseAddress,
                              MBWB_BIO_LEDS_REG);

    return (u16)(LEDValue & MBWB_BIO_LED_MASK);
}

/***** MBWB_BIO_setLEDs() - sets the LEDs to the specified value *****/
void MBWB_BIO_setLEDs(u16 Value)
{
    MBWB_L_writeReg(MBWB_BIO_BaseAddress,
                    MBWB_BIO_LEDS_REG,
                    (u32)Value & MBWB_BIO_LED_MASK);
}


/* -------------------------------------------------------------------------- */
/*  RGB LED functions                                                         */
/* -------------------------------------------------------------------------- */

/***** MBWB_BIO_getRGB() - returns the enable and PWM values for the selected RGB LED *****/
u32 MBWB_BIO_getRGB(MBWB_BIO_rgbleds_t LED)
{
    u32 RegisterIndex;

    if (!MBWB_BIO_isValidRGBLED(LED))
    {
        return MBWB_BIO_RGB_OFF;
    }

    RegisterIndex = MBWB_BIO_getRGBRegister(LED);

    return MBWB_L_readReg(MBWB_BIO_BaseAddress,
                          RegisterIndex);
}

/***** MBWB_BIO_setRGB() - sets the enable bit and duty cycles for the selected RGB LED *****/
void MBWB_BIO_setRGB(MBWB_BIO_rgbleds_t LED, u32 Value)
{
    u32 RegisterIndex;

    if (!MBWB_BIO_isValidRGBLED(LED))
    {
        return;
    }

    RegisterIndex = MBWB_BIO_getRGBRegister(LED);

    MBWB_L_writeReg(MBWB_BIO_BaseAddress,
                    RegisterIndex,
                    Value);
}

/* -------------------------------------------------------------------------- */
/*  Interrupt functions                                                       */
/* -------------------------------------------------------------------------- */

/***** MBWB_BIO_getInterruptEnable() - returns the current Wishbone IRQ Enable register *****/
u32 MBWB_BIO_getInterruptEnable(void)
{
    return MBWB_L_readReg(MBWB_BIO_BaseAddress,
                          MBWB_BIO_IRQ_ENABLE_REG);
}

/***** MBWB_BIO_setInterruptEnable() - sets the Wishbone IRQ Enable register *****/
void MBWB_BIO_setInterruptEnable(u32 Mask)
{
    MBWB_L_writeReg(MBWB_BIO_BaseAddress,
                    MBWB_BIO_IRQ_ENABLE_REG,
                    Mask);
}

/***** MBWB_BIO_getInterruptStatus() - returns the Interrupt pending register (can be used for polling) *****/
u32 MBWB_BIO_getInterruptStatus(void)
{
    return MBWB_L_readReg(MBWB_BIO_BaseAddress,
                          MBWB_BIO_IRQ_STATUS_REG);
}

/***** MBWB_BIO_clearInterruptStatus() - write a 1 to clear the Interrupt pending bit *****/
void MBWB_BIO_clearInterruptStatus(u32 Mask)
{
    MBWB_L_writeReg(MBWB_BIO_BaseAddress,
                    MBWB_BIO_IRQ_STATUS_REG,
                    Mask);
}


/* -------------------------------------------------------------------------- */
/*  Board identification and configuration                                    */
/* -------------------------------------------------------------------------- */

/***** MBWB_BIO_getBoardID() - returns the Board ID as a 32-bit ASCII board identifier *****/
u32 MBWB_BIO_getBoardID(void)
{
    return MBWB_L_readReg(MBWB_BIO_BaseAddress,
                          MBWB_BIO_BOARD_ID_REG);
}

/***** MBWB_BIO_getBoardConfig() - returns board configuration (# LEDs, etc) *****/
u32 MBWB_BIO_getBoardConfig(void)
{
    return MBWB_L_readReg(MBWB_BIO_BaseAddress,
                          MBWB_BIO_BOARD_CONFIG_REG);
}


/* -------------------------------------------------------------------------- */
/*  Private helper functions                                                  */
/* -------------------------------------------------------------------------- */

/**
 * @brief MBWB_BIO_isValidButton()
 *
 * Checks if the specified button exists on the board
 *
 * @return TRUE if the button is a valid button
 */
static bool MBWB_BIO_isValidButton(MBWB_BIO_btns_t Button)
{
    return ((u32)Button <= (u32)MBWB_BIO_BTN4);
}

/**
 * @brief MBWB_BIO_isValidRGB()
 *
 * Checks if the specified RGB LED exists on the board
 *
 * @return TRUE if the RGB LED exists on the board
 */
static bool MBWB_BIO_isValidRGBLED(MBWB_BIO_rgbleds_t LED)
{
    return (LED == MBWB_BIO_RGB1) ||
           (LED == MBWB_BIO_RGB2);
}

/**
 * @brief MBWB_BIO_getRGBRegister()
 *
 * Returns the RGB control register for the selected RGB LED
 *
 * @return RGB control register contents for selected RGB LED
 */
static u32 MBWB_BIO_getRGBRegister(MBWB_BIO_rgbleds_t LED)
{

    return MBWB_BIO_RGB_CONTROL_BASE_REG + (u32)LED;
}


