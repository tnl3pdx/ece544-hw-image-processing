#include "xparameters.h"
#include "xaxidma.h"
#include "xil_printf.h"
#include "mb_interface.h"

/* --- User Configuration ------------------------------------------------- */
#define DDR_TEST_ADDR   0x80000000U          /* Must match Vivado Address Editor */
#define NUM_WORDS       64                   /* Number of 32-bit words to test   */
#define NUM_BYTES       (NUM_WORDS * 4U)     /* Total transfer size in bytes     */
#define AXIS_LINK_ID    0                    /* MicroBlaze M0_AXIS / S0_AXIS     */
/* ------------------------------------------------------------------------ */

static XAxiDma AxiDma;
static u32 tx_buf[NUM_WORDS];
static u32 rx_buf[NUM_WORDS];

int main(void)
{
    XAxiDma_Config *CfgPtr;
    int Status;
    u32 i;
    u32 errors = 0;

    xil_printf("\r\n====================================================\r\n");
    xil_printf("        AXI DMA Stream <-> DDR Loopback Test        \r\n");
    xil_printf("====================================================\r\n");

    /* 1. Initialize AXI DMA (supports both Vitis Classic and Vitis Unified/SDT) */
#ifndef SDT
    CfgPtr = XAxiDma_LookupConfig(XPAR_AXIDMA_0_DEVICE_ID);
#else
    CfgPtr = XAxiDma_LookupConfig(XPAR_XAXIDMA_0_BASEADDR);
#endif
    if (!CfgPtr) {
        xil_printf("ERROR: No AXI DMA config found.\r\n");
        return XST_FAILURE;
    }

    Status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: AXI DMA initialization failed (%d).\r\n", Status);
        return XST_FAILURE;
    }

    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("ERROR: DMA is in Scatter-Gather mode. Disable SG in Vivado.\r\n");
        return XST_FAILURE;
    }

    /* Disable interrupts for simple polling test */
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    /* 2. Prepare test pattern and clear receive buffer */
    for (i = 0; i < NUM_WORDS; i++) {
        tx_buf[i] = 0xA5000000U | i;
        rx_buf[i] = 0x00000000U;
    }

    /* ====================================================================
     * PHASE 1: WRITE TO DDR (MicroBlaze M0_AXIS -> DMA S2MM -> DDR)
     * ==================================================================== */
    xil_printf("[1/3] Writing %u words (%u bytes) to DDR @ 0x%08X...\r\n",
               NUM_WORDS, NUM_BYTES, DDR_TEST_ADDR);

    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)DDR_TEST_ADDR,
                                    NUM_BYTES, XAXIDMA_DEVICE_TO_DMA);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: S2MM SimpleTransfer failed (%d).\r\n", Status);
        return XST_FAILURE;
    }

    /* Option 1: Single loop asserting TLAST on the final word */
    for (i = 0; i < NUM_WORDS; i++) {
        if (i == NUM_WORDS - 1) {
            cputfsl(tx_buf[i], AXIS_LINK_ID);   /* TLAST = 1 */
        } else {
            putfsl(tx_buf[i], AXIS_LINK_ID);    /* TLAST = 0 */
        }
    }

    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA)) {
        /* Wait for S2MM completion */
    }
    xil_printf("      -> S2MM write complete.\r\n");

    /* ====================================================================
     * PHASE 2: READ FROM DDR (DDR -> DMA MM2S -> MicroBlaze S0_AXIS)
     * ==================================================================== */
    xil_printf("[2/3] Reading %u words (%u bytes) from DDR @ 0x%08X...\r\n",
               NUM_WORDS, NUM_BYTES, DDR_TEST_ADDR);

    Status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)DDR_TEST_ADDR,
                                    NUM_BYTES, XAXIDMA_DMA_TO_DEVICE);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: MM2S SimpleTransfer failed (%d).\r\n", Status);
        return XST_FAILURE;
    }

    for (i = 0; i < NUM_WORDS; i++) {
        u32 word;
        getfsl(word, AXIS_LINK_ID);
        rx_buf[i] = word;
    }

    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) {
        /* Wait for MM2S completion */
    }
    xil_printf("      -> MM2S read complete.\r\n\r\n");

    /* ====================================================================
     * PHASE 3: PRINT & VERIFY DATA
     * ==================================================================== */
    xil_printf("[3/3] Verification Results:\r\n");
    xil_printf("----------------------------------------------------\r\n");
    xil_printf(" Idx |   Sent (TX)  | Received (RX) |  Status\r\n");
    xil_printf("-----+--------------+---------------+---------------\r\n");

    for (i = 0; i < NUM_WORDS; i++) {
        if (rx_buf[i] == tx_buf[i]) {
            xil_printf(" %3u |  0x%08X  |  0x%08X   |  PASS\r\n",
                       i, tx_buf[i], rx_buf[i]);
        } else {
            xil_printf(" %3u |  0x%08X  |  0x%08X   |  FAIL <--\r\n",
                       i, tx_buf[i], rx_buf[i]);
            errors++;
        }
    }

    xil_printf("====================================================\r\n");
    if (errors == 0) {
        xil_printf(" RESULT: PASSED (%u / %u words matched)\r\n", NUM_WORDS, NUM_WORDS);
        xil_printf("====================================================\r\n");
        return XST_SUCCESS;
    } else {
        xil_printf(" RESULT: FAILED (%u mismatches out of %u words)\r\n", errors, NUM_WORDS);
        xil_printf("====================================================\r\n");
        return XST_FAILURE;
    }
}