/**
 * @file    MBWB_L.h
 * @brief   Low-level register access API for the MBWB driver library.
 *
 * @author Roy Kravitz (roy.kravitz@pdx.edu) and ChatGPT
 * @copyright Copyright (c) 2026 Roy Kravitz
 * @license MIT
 *
 * @date    16-Jul-2026
 * @version 1.0
 *
 * @detail
 * This header file provides the low-level MMIO register-access operations used
 * by the MicroBlaze/Wishbone (MBWB) peripheral drivers.
 *
 * Two addressing conventions are supported:
 *
 *   - The MBWB_mReadReg() and MBWB_mWriteReg() macros use byte offsets from
 *     a peripheral base address.
 *
 *   - The MBWB_L_readReg() and MBWB_L_writeReg() inline functions use
 *     32-bit Wishbone register indices. The register index is multiplied by
 *     four to form the corresponding byte offset.
 *
 * For example:
 *
 * @code
 * MBWB_L_writeReg(MBWB_BIO_BASEADDR, MBWB_BIO_LEDS_REG, led_value);
 * @endcode
 *
 * is equivalent to:
 *
 * @code
 * Xil_Out32(MBWB_BIO_BASEADDR +
 *           (MBWB_BIO_LEDS_REG << 2U),
 *           led_value);
 * @endcode
 *
 * The 16-bit access operations use byte offsets rather than register indices.
 * They are provided primarily for peripherals such as the VGA text controller,
 * whose text-buffer entries are 16-bit values.
 */
/* SPDX-License-Identifier: MIT */

#ifndef MBWB_L_H
#define MBWB_L_H

#include "MBWB_HW.h"
#include "xil_io.h"
#include "xil_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/* -------------------------------------------------------------------------- */
/*  Generic 32-bit MMIO access macros                                         */
/* -------------------------------------------------------------------------- */

/**
 * @brief Write a 32-bit value to an MMIO register.
 *
 * This macro writes a 32-bit value to an address formed by adding a byte
 * offset to the supplied peripheral base address.
 *
 * @param BaseAddress Peripheral MMIO base address.
 * @param RegOffset   Register byte offset from @p BaseAddress.
 * @param Data        32-bit value to write.
 *
 * @return None.
 */
#define MBWB_mWriteReg(BaseAddress, RegOffset, Data)                       \
    Xil_Out32((UINTPTR)(BaseAddress) + (UINTPTR)(RegOffset), (u32)(Data))

/**
 * @brief Read a 32-bit value from an MMIO register.
 *
 * This macro reads a 32-bit value from an address formed by adding a byte
 * offset to the supplied peripheral base address.
 *
 * @param BaseAddress Peripheral MMIO base address.
 * @param RegOffset   Register byte offset from @p BaseAddress.
 *
 * @return The 32-bit value read from the MMIO register.
 */
#define MBWB_mReadReg(BaseAddress, RegOffset)                              \
    Xil_In32((UINTPTR)(BaseAddress) + (UINTPTR)(RegOffset))

/* -------------------------------------------------------------------------- */
/*  Generic 16-bit MMIO access macros                                         */
/* -------------------------------------------------------------------------- */

/**
 * @brief Write a 16-bit value to an MMIO location.
 *
 * This macro writes a 16-bit value to an address formed by adding a byte
 * offset to the supplied peripheral base address.
 *
 * The AXI-Lite-to-Wishbone bridge generates the appropriate byte-lane select
 * signals for the half-word write.
 *
 * @param BaseAddress Peripheral MMIO base address.
 * @param RegOffset   Byte offset from @p BaseAddress.
 * @param Data        16-bit value to write.
 *
 * @return None.
 */
#define MBWB_mWriteReg16(BaseAddress, RegOffset, Data)                     \
    Xil_Out16((UINTPTR)(BaseAddress) + (UINTPTR)(RegOffset), (u16)(Data))

/**
 * @brief Read a 16-bit value from an MMIO location.
 *
 * This macro reads a 16-bit value from an address formed by adding a byte
 * offset to the supplied peripheral base address.
 *
 * @param BaseAddress Peripheral MMIO base address.
 * @param RegOffset   Byte offset from @p BaseAddress.
 *
 * @return The 16-bit value read from the MMIO location.
 */
#define MBWB_mReadReg16(BaseAddress, RegOffset)                            \
    Xil_In16((UINTPTR)(BaseAddress) + (UINTPTR)(RegOffset))

/* -------------------------------------------------------------------------- */
/*  Wishbone 32-bit register-index access functions                           */
/* -------------------------------------------------------------------------- */

/**
 * @brief Write a 32-bit Wishbone peripheral register.
 *
 * The supplied register number is a 32-bit word index rather than a byte
 * offset. The function converts the register index to a byte offset using:
 *
 * @code
 * byte_offset = RegIndex << 2
 * @endcode
 *
 * The common register indices MBWB_REG0 through MBWB_REG7 and the
 * peripheral-specific register definitions in MBWB_HW.h may be passed as
 * @p RegIndex.
 *
 * @param BaseAddress Base address of the target Wishbone peripheral.
 * @param RegIndex    Zero-based 32-bit register word index.
 * @param Data        32-bit value to write to the register.
 *
 * @return None.
 */
static inline void MBWB_L_writeReg(UINTPTR BaseAddress,
                                   u32 RegIndex,
                                   u32 Data)
{
    Xil_Out32(BaseAddress + (UINTPTR)MBWB_REG_OFFSET(RegIndex), Data);
}

/**
 * @brief Read a 32-bit Wishbone peripheral register.
 *
 * The supplied register number is a 32-bit word index rather than a byte
 * offset. The function converts the register index to a byte offset using:
 *
 * @code
 * byte_offset = RegIndex << 2
 * @endcode
 *
 * The common register indices MBWB_REG0 through MBWB_REG7 and the
 * peripheral-specific register definitions in MBWB_HW.h may be passed as
 * @p RegIndex.
 *
 * @param BaseAddress Base address of the target Wishbone peripheral.
 * @param RegIndex    Zero-based 32-bit register word index.
 *
 * @return The 32-bit value read from the specified Wishbone register.
 */
static inline u32 MBWB_L_readReg(UINTPTR BaseAddress, u32 RegIndex)
{
    return Xil_In32(BaseAddress + (UINTPTR)MBWB_REG_OFFSET(RegIndex));
}

/* -------------------------------------------------------------------------- */
/*  Wishbone 16-bit byte-offset access functions                              */
/* -------------------------------------------------------------------------- */

/**
 * @brief Write a 16-bit value to a Wishbone MMIO location.
 *
 * Unlike MBWB_L_writeReg(), this function accepts a byte offset rather than
 * a 32-bit register index. It is intended for half-word-oriented memory
 * regions such as the VGA text buffer.
 *
 * The AXI-Lite-to-Wishbone bridge generates the appropriate byte-lane select
 * signals for the half-word write.
 *
 * @param BaseAddress Base address of the target Wishbone peripheral.
 * @param ByteOffset  Byte offset of the target half-word from
 *                    @p BaseAddress.
 * @param Data        16-bit value to write.
 *
 * @return None.
 */
static inline void MBWB_L_writeReg16(UINTPTR BaseAddress,
                                     u32 ByteOffset,
                                     u16 Data)
{
    Xil_Out16(BaseAddress + (UINTPTR)ByteOffset, Data);
}

/**
 * @brief Read a 16-bit value from a Wishbone MMIO location.
 *
 * Unlike MBWB_L_readReg(), this function accepts a byte offset rather than
 * a 32-bit register index. It is intended for half-word-oriented memory
 * regions such as the VGA text buffer.
 *
 * @param BaseAddress Base address of the target Wishbone peripheral.
 * @param ByteOffset  Byte offset of the target half-word from
 *                    @p BaseAddress.
 *
 * @return The 16-bit value read from the specified Wishbone MMIO location.
 */
static inline u16 MBWB_L_readReg16(UINTPTR BaseAddress, u32 ByteOffset)
{
    return Xil_In16(BaseAddress + (UINTPTR)ByteOffset);
}

#ifdef __cplusplus
}
#endif

#endif /* MBWB_L_H */
