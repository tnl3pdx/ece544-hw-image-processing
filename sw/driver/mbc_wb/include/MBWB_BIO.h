/**
 * @file    MBWB_BIO.h
 * @brief   Public API for the MBWB Board I/O peripheral driver.
 *
 * @author Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date    28-Jul-2026
 * @version 1.1
 *
 * @detail
 * This header file defines the public API for the MicroBlaze/Wishbone
 * (MBWB) Board I/O peripheral.
 *
 * The Board I/O peripheral provides access to:
 *   - 16 slide switches
 *   - 5 pushbuttons
 *   - 16 discrete LEDs
 *   - 2 RGB LEDs
 *   - Switch and pushbutton change interrupts
 *   - Board identification and configuration registers
 *
 * The RGB LEDs are controlled using one packed 32-bit value:
 *
 *   - Bit [31]     : RGB LED enable
 *   - Bits [30:24] : Reserved
 *   - Bits [23:16] : Red PWM duty cycle
 *   - Bits [15:8]  : Green PWM duty cycle
 *   - Bits [7:0]   : Blue PWM duty cycle
 *
 * RGB duty-cycle values range from 0 to 255. The
 * MBWB_BIO_RGB_VALUE() macro may be used to construct an RGB control value.
 *
 * The Board I/O register map and peripheral base address are defined in
 * MBWB_HW.h. Low-level register access functions are defined in MBWB_L.h.
 */
 /* SPDX-License-Identifier: MIT */

#ifndef MBWB_BIO_H
#define MBWB_BIO_H

#include "MBWB_L.h"
#include "xil_types.h"
#include "xstatus.h"

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* -------------------------------------------------------------------------- */
/*  Board I/O field definitions                                               */
/* -------------------------------------------------------------------------- */

/**
 * @brief Mask for the switch field in the BOARD_IN register.
 *
 * The 16 slide switches occupy bits [15:0] of the BOARD_IN register.
 */
#define MBWB_BIO_SWITCH_MASK          0x0000FFFFU

/**
 * @brief Shift applied to the switch field in the BOARD_IN register.
 */
#define MBWB_BIO_SWITCH_SHIFT         0U

/**
 * @brief Mask for the pushbutton field in the BOARD_IN register.
 *
 * The five pushbuttons occupy bits [20:16] of the BOARD_IN register.
 */
#define MBWB_BIO_BUTTON_MASK   0xF8000000U

/**
 * @brief Shift applied to the pushbutton field in the BOARD_IN register.
 */
#define MBWB_BIO_BUTTON_SHIFT  27U

/**
 * @brief Mask for the LED output field in the LEDS register.
 */
#define MBWB_BIO_LED_MASK             0x0000FFFFU

/* -------------------------------------------------------------------------- */
/*  RGB LED control-value definitions                                         */
/* -------------------------------------------------------------------------- */

/**
 * @brief Construct a packed RGB LED control value.
 *
 * @param Enable  Nonzero to enable the RGB LED; zero to disable it.
 * @param Red     Red PWM duty cycle in the range 0 through 255.
 * @param Green   Green PWM duty cycle in the range 0 through 255.
 * @param Blue    Blue PWM duty cycle in the range 0 through 255.
 *
 * @return A packed 32-bit RGB LED control value.
 */
#define MBWB_BIO_RGB_VALUE(Enable, Red, Green, Blue)                       \
    (((Enable) != 0U ? MBWB_BIO_RGB_ENABLE_MASK : 0U) |                   \
     ((((u32)(Red))   & MBWB_BIO_RGB_COMPONENT_MASK)                      \
        << MBWB_BIO_RGB_RED_SHIFT) |                                      \
     ((((u32)(Green)) & MBWB_BIO_RGB_COMPONENT_MASK)                      \
        << MBWB_BIO_RGB_GREEN_SHIFT) |                                    \
     ((((u32)(Blue))  & MBWB_BIO_RGB_COMPONENT_MASK)                      \
        << MBWB_BIO_RGB_BLUE_SHIFT))

/**
 * @brief RGB LED disabled.
 */
#define MBWB_BIO_RGB_OFF              0x00000000U

/**
 * @brief Full-intensity red.
 */
#define MBWB_BIO_RGB_RED              MBWB_BIO_RGB_VALUE(1U, 255U,   0U,   0U)

/**
 * @brief Full-intensity green.
 */
#define MBWB_BIO_RGB_GREEN            MBWB_BIO_RGB_VALUE(1U,   0U, 255U,   0U)

/**
 * @brief Full-intensity blue.
 */
#define MBWB_BIO_RGB_BLUE             MBWB_BIO_RGB_VALUE(1U,   0U,   0U, 255U)

/**
 * @brief Full-intensity yellow.
 */
#define MBWB_BIO_RGB_YELLOW           MBWB_BIO_RGB_VALUE(1U, 255U, 255U,   0U)

/**
 * @brief Full-intensity aqua/cyan.
 */
#define MBWB_BIO_RGB_AQUA             MBWB_BIO_RGB_VALUE(1U,   0U, 255U, 255U)

/**
 * @brief Full-intensity magenta.
 */
#define MBWB_BIO_RGB_MAGENTA          MBWB_BIO_RGB_VALUE(1U, 255U,   0U, 255U)

/**
 * @brief Full-intensity white.
 */
#define MBWB_BIO_RGB_WHITE            MBWB_BIO_RGB_VALUE(1U, 255U, 255U, 255U)

/* -------------------------------------------------------------------------- */
/*  Typedefs and enumerations                                                 */
/* -------------------------------------------------------------------------- */

/**
 * @brief Pushbutton identifiers.
 */
typedef enum
{
    MBWB_BIO_BTN0 = 0,
    MBWB_BIO_BTN1,
    MBWB_BIO_BTN2,
    MBWB_BIO_BTN3,
    MBWB_BIO_BTN4
} MBWB_BIO_btns_t;

/**
 * @brief RGB LED identifiers.
 */
typedef enum
{
    MBWB_BIO_RGB1 = 0,
    MBWB_BIO_RGB2
} MBWB_BIO_rgbleds_t;

/* -------------------------------------------------------------------------- */
/*  Initialization                                                            */
/* -------------------------------------------------------------------------- */

/**
 * @brief Initialize the MBWB Board I/O driver.
 *
 * This function records the base address of the Board I/O peripheral for use
 * by the remaining driver functions.
 *
 * The Board I/O hardware requires no direction-register configuration because
 * the switch, pushbutton, LED, and RGB LED signal directions are fixed in the
 * Wishbone peripheral.
 *
 * @param BaseAddress Base address of the Board I/O peripheral. For the
 *                    standard MBWB platform, use MBWB_BIO_BASEADDR.
 *
 * @return XST_SUCCESS if the driver was initialized successfully.
 */
int MBWB_BIO_initialize(UINTPTR BaseAddress);

/* -------------------------------------------------------------------------- */
/*  Board input functions                                                     */
/* -------------------------------------------------------------------------- */

/**
 * @brief Read the raw Board I/O input register.
 *
 * The BOARD_IN register contains the current switch and pushbutton states.
 * No masking or field extraction is performed.
 *
 * @return The raw 32-bit contents of the BOARD_IN register.
 */
u32 MBWB_BIO_getBoardInputs(void);

/**
 * @brief Read the five pushbuttons.
 *
 * The pushbutton field is extracted from the BOARD_IN register and returned
 * as a right-justified value.
 *
 * @return A five-bit value containing the current pushbutton states.
 *         Bit 0 corresponds to BTN0 and bit 4 corresponds to BTN4.
 */
u8 MBWB_BIO_getButtons(void);

/**
 * @brief Read the 16 slide switches.
 *
 * The switch field is extracted from the BOARD_IN register and returned as
 * a right-justified value.
 *
 * @return A 16-bit value containing the current slide-switch states.
 */
u16 MBWB_BIO_getSwitches(void);

/**
 * @brief Determine whether a selected pushbutton is pressed.
 *
 * This function reads the current pushbutton state and tests the bit
 * corresponding to the selected pushbutton.
 *
 * @param Button Pushbutton to test. The value must be one of
 *               MBWB_BIO_BTN0 through MBWB_BIO_BTN4.
 *
 * @return true if the selected pushbutton is pressed; otherwise false.
 */
bool MBWB_BIO_isPressed(MBWB_BIO_btns_t Button);

/* -------------------------------------------------------------------------- */
/*  Discrete LED functions                                                    */
/* -------------------------------------------------------------------------- */

/**
 * @brief Read the current discrete LED output value.
 *
 * @return A 16-bit value containing the current states of LED[15:0].
 */
u16 MBWB_BIO_getLEDs(void);

/**
 * @brief Set the 16 discrete LED outputs.
 *
 * @param Value New LED output value. Bit 0 controls LED0 and bit 15 controls
 *              LED15.
 *
 * @return None.
 */
void MBWB_BIO_setLEDs(u16 Value);

/* -------------------------------------------------------------------------- */
/*  RGB LED functions                                                         */
/* -------------------------------------------------------------------------- */

/**
 * @brief Read the packed control value for a selected RGB LED.
 *
 * The returned value uses the following format:
 *
 *   - Bit [31]     : RGB LED enable
 *   - Bits [30:24] : Reserved
 *   - Bits [23:16] : Red PWM duty cycle
 *   - Bits [15:8]  : Green PWM duty cycle
 *   - Bits [7:0]   : Blue PWM duty cycle
 *
 * @param LED RGB LED to read. The value must be MBWB_BIO_RGB1 or
 *            MBWB_BIO_RGB2.
 *
 * @return The packed 32-bit RGB LED control value.
 */
u32 MBWB_BIO_getRGB(MBWB_BIO_rgbleds_t LED);

/**
 * @brief Set the packed control value for a selected RGB LED.
 *
 * Use MBWB_BIO_RGB_VALUE() to construct an arbitrary RGB value, or use one
 * of the predefined color constants such as MBWB_BIO_RGB_AQUA or
 * MBWB_BIO_RGB_MAGENTA.
 *
 * @param LED   RGB LED to modify. The value must be MBWB_BIO_RGB1 or
 *              MBWB_BIO_RGB2.
 * @param Value Packed 32-bit RGB LED control value.
 *
 * @return None.
 */
void MBWB_BIO_setRGB(MBWB_BIO_rgbleds_t LED, u32 Value);

/* -------------------------------------------------------------------------- */
/*  Interrupt functions                                                       */
/* -------------------------------------------------------------------------- */

/**
 * @brief Read the Board I/O interrupt-enable register.
 *
 * @return The current 32-bit contents of the IRQ_ENABLE register.
 */
u32 MBWB_BIO_getInterruptEnable(void);

/**
 * @brief Write the Board I/O interrupt-enable register.
 *
 * The interpretation of each enable bit is defined by the Board I/O hardware.
 *
 * @param Mask Interrupt-enable mask to write to the IRQ_ENABLE register.
 *
 * @return None.
 */
void MBWB_BIO_setInterruptEnable(u32 Mask);

/**
 * @brief Read the Board I/O interrupt-status register.
 *
 * @return The current 32-bit contents of the IRQ_STATUS register.
 */
u32 MBWB_BIO_getInterruptStatus(void);

/**
 * @brief Clear selected Board I/O interrupt-status bits.
 *
 * The IRQ_STATUS register uses write-one-to-clear semantics. A one written to
 * a status bit clears that bit; a zero leaves the corresponding bit unchanged.
 *
 * @param Mask Mask identifying the interrupt-status bits to clear.
 *
 * @return None.
 */
void MBWB_BIO_clearInterruptStatus(u32 Mask);

/* -------------------------------------------------------------------------- */
/*  Board identification and configuration                                    */
/* -------------------------------------------------------------------------- */

/**
 * @brief Read the Board I/O peripheral identification register.
 *
 * @return The 32-bit contents of the BOARD_ID register.
 */
u32 MBWB_BIO_getBoardID(void);

/**
 * @brief Read the Board I/O peripheral configuration register.
 *
 * The BOARD_CONFIG register reports the hardware configuration of the
 * synthesized Board I/O peripheral, including the implemented numbers of
 * switches, buttons, LEDs, and RGB LEDs.
 *
 * @return The 32-bit contents of the BOARD_CONFIG register.
 */
u32 MBWB_BIO_getBoardConfig(void);

#ifdef __cplusplus
}
#endif

#endif /* MBWB_BIO_H */
