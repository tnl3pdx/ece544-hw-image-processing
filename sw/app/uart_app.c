/* =============================================================================
 *  uart_app.c  -  ECE 544 Hardware Image Processor: UART / FreeRTOS application
 * =============================================================================
 *
 *  PURPOSE
 *  -------
 *  Runs on the MicroBlaze under FreeRTOS. It bridges the host PC (Python tool
 *  or PowerShell) and the image-processor hardware (HIP) over the UART
 *  (AXI UARTLite, 115200 8N1).
 *
 *  TASK ARCHITECTURE
 *  -----------------
 *    UART RX  -> [vRxTask] parser -+-- COMMAND -> xCmdQueue  -> [vCmdTask]
 *                                  +-- DATA    -> xDataQueue -> [vDataTask]
 *    [vCmdTask]  updates settings, writes HIP registers, queues RESPONSE
 *    [vDataTask] runs the chunk through the pipeline, queues DATA reply
 *    all replies -> xTxQueue -> [vTxTask] -> UART TX (the only UART writer)
 *
 *  FRAME FORMAT (both directions)
 *  ------------------------------
 *    | SYNC 0xA5 | TYPE | LEN_LO | LEN_HI | PAYLOAD (LEN bytes) | CHECKSUM |
 *    CHECKSUM = XOR of TYPE, LEN_LO, LEN_HI and every PAYLOAD byte.
 *    TYPE: 0x01 COMMAND, 0x02 DATA, 0x03 RESPONSE
 *
 *  COMMANDS (payload = [OPCODE][ARGS])
 *    0x01 PING            no args            reply [01][00]
 *    0x10 SET_THRESHOLD   1 arg  (0..255)    reply [10][status]
 *    0x11 SET_RGB         3 args (R, G, B)   reply [11][status]
 *    0x12 SET_ALGORITHM   1 arg  (0..3)      reply [12][status]
 *
 *  RESPONSE payload = [OPCODE][STATUS]
 *    STATUS 0x00 OK, 0x01 BAD_LENGTH, 0x02 UNKNOWN_OPCODE, 0x03 BAD_ARG,
 *           0x04 HW_ERROR (DMA timed out or failed)
 *    OPCODE 0x20 is used only for a failed DATA chunk.
 *
 *  DATA payload = raw pixel bytes. The DATA reply has the same length.
 *
 *  BUILD-TIME SWITCHES (edit these, then Clean + Build)
 *  ----------------------------------------------------
 *    HIP_PRESENT       0: settings are stored but not written to hardware.
 *                      1: settings are written to HIP registers at 0x80020000.
 *    HIP_DMA_ENABLE    0: DATA chunks pass through unchanged (no DMA used).
 *                      1: DATA chunks go MicroBlaze -> FSL -> DMA -> DDR ->
 *                         DMA -> FSL -> MicroBlaze. Needs the axidma driver
 *                         in the freertos BSP.
 *    UART_BOOT_BANNER  1: sends "ECE544 uart_app ready" once at startup.
 *                      Lets you confirm UART transmit without any script.
 *
 *  UART ACCESS
 *  -----------
 *    Polled through xuartlite_l.h macros, which take the base address
 *    directly. No driver instance or XUartLite_Initialize() is needed.
 *
 *  TIMING
 *  ------
 *    RX drains up to 16 bytes (UARTLite FIFO depth) per pass, then yields one
 *    tick. configTICK_RATE_HZ must be 1000 or higher.
 *
 *  CONCURRENCY
 *    xSettingsMutex protects the settings copy.
 *    xHwMutex serialises HIP register writes and DMA transfers, so a settings
 *    change never happens in the middle of a chunk.
 * =============================================================================
 */

/* -------------------------------------------------------------------------- */
/*  Build-time switches                                                       */
/* -------------------------------------------------------------------------- */

#define HIP_PRESENT             0
#define HIP_DMA_ENABLE          0
#define UART_BOOT_BANNER        1

/* -------------------------------------------------------------------------- */
/*  Includes                                                                  */
/* -------------------------------------------------------------------------- */

#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "xparameters.h"
#include "xstatus.h"
#include "xuartlite_l.h"

#if HIP_PRESENT
#include "xil_io.h"
#endif

#if HIP_DMA_ENABLE
#include "xaxidma.h"
#include "mb_interface.h"
#endif

/* -------------------------------------------------------------------------- */
/*  Hardware constants                                                        */
/* -------------------------------------------------------------------------- */

#define UART_BASEADDR           XPAR_AXI_UARTLITE_0_BASEADDR

/* HIP control registers on the AXI-Lite -> Wishbone aperture (region 2). */
#define HIP_WB_BASEADDR         0x80020000U
#define HIP_REG_CTRL            (HIP_WB_BASEADDR + 0x00U)
#define HIP_REG_THRESHOLD       (HIP_WB_BASEADDR + 0x04U)
#define HIP_REG_RGB             (HIP_WB_BASEADDR + 0x08U)
#define HIP_CTRL_ALGO_SHIFT     2u
#define HIP_CTRL_ALGO_MASK      (0x7u << HIP_CTRL_ALGO_SHIFT)

/* DMA and FSL settings (used only when HIP_DMA_ENABLE is 1). */
#define HIP_DDR_ADDR            0x80000000U   /* DDR address as seen by the DMA */
#define HIP_FSL_ID              0
#define DMA_TIMEOUT_LOOPS       1000000UL

/* -------------------------------------------------------------------------- */
/*  Protocol constants                                                        */
/* -------------------------------------------------------------------------- */

#define FRAME_SYNC              0xA5u
#define FRAME_CMD               0x01u
#define FRAME_DATA              0x02u
#define FRAME_RESP              0x03u

#define MAX_PAYLOAD             256u
#define WIRE_MAX                (MAX_PAYLOAD + 5u)  /* sync+type+len(2)+payload+chk */

#define OP_PING                 0x01u
#define OP_SET_THRESHOLD        0x10u
#define OP_SET_RGB              0x11u
#define OP_SET_ALGORITHM        0x12u
#define OP_DATA                 0x20u   /* pseudo-opcode for failed DATA replies */

#define ST_OK                   0x00u
#define ST_BAD_LENGTH           0x01u
#define ST_UNKNOWN_OPCODE       0x02u
#define ST_BAD_ARG              0x03u
#define ST_HW_ERROR             0x04u

#define ALGO_PASSTHROUGH        0u
#define ALGO_GREYSCALE          1u
#define ALGO_THRESHOLD          2u
#define ALGO_SOBEL              3u
#define ALGO_MAX                ALGO_SOBEL

/* -------------------------------------------------------------------------- */
/*  Task configuration                                                        */
/* -------------------------------------------------------------------------- */

#define TASK_STACK_WORDS        1024u
#define PRIO_RX                 3u   /* must keep up with incoming bytes */
#define PRIO_CMD                2u
#define PRIO_DATA               2u
#define PRIO_TX                 2u

#define CMD_QUEUE_LEN           4u
#define DATA_QUEUE_LEN          4u
#define TX_QUEUE_LEN            8u

/* -------------------------------------------------------------------------- */
/*  Types                                                                     */
/* -------------------------------------------------------------------------- */

/* A complete, checksum-verified frame (payload only). */
typedef struct {
    uint8_t  type;
    uint16_t len;
    uint8_t  data[MAX_PAYLOAD];
} frame_t;

/* A fully encoded frame ready to be written to the UART byte by byte. */
typedef struct {
    uint16_t n;                 /* number of valid bytes in b[] */
    uint8_t  b[WIRE_MAX];
} wire_t;

/* Image-processing settings. Written by vCmdTask, read by vDataTask. */
typedef struct {
    uint8_t threshold;
    uint8_t rgb[3];             /* R, G, B weights */
    uint8_t algorithm;
} hip_settings_t;

/* Frame-parser states. */
typedef enum {
    PS_SYNC,
    PS_TYPE,
    PS_LEN_LO,
    PS_LEN_HI,
    PS_PAYLOAD,
    PS_CHECKSUM
} parse_state_t;

typedef struct {
    parse_state_t state;
    uint8_t       type;
    uint8_t       len_lo;
    uint8_t       calc;         /* running XOR checksum */
    uint16_t      len;
    uint16_t      idx;
    frame_t       frame;        /* filled in when a complete frame is found */
} parser_t;

/* -------------------------------------------------------------------------- */
/*  Global objects                                                            */
/* -------------------------------------------------------------------------- */

static QueueHandle_t     xCmdQueue;
static QueueHandle_t     xDataQueue;
static QueueHandle_t     xTxQueue;
static SemaphoreHandle_t xSettingsMutex;
static SemaphoreHandle_t xHwMutex;

#if HIP_DMA_ENABLE
static XAxiDma           xDma;
#endif

static hip_settings_t    xSettings = { 128u, { 1u, 1u, 1u }, ALGO_PASSTHROUGH };

/* Counts frames dropped because a queue was full. */
static volatile uint32_t ulDroppedFrames = 0;

/* Task prototypes */
static void vRxTask(void *pvParameters);
static void vCmdTask(void *pvParameters);
static void vDataTask(void *pvParameters);
static void vTxTask(void *pvParameters);

/* -------------------------------------------------------------------------- */
/*  HIP access                                                                */
/* -------------------------------------------------------------------------- */

/*
 * Write the settings to the HIP control registers.
 * Caller must hold xHwMutex.
 */
static void hip_write_settings(const hip_settings_t *s)
{
#if HIP_PRESENT
    uint32_t rgb;
    uint32_t ctrl;

    rgb  = ((uint32_t)s->rgb[0])       |
           ((uint32_t)s->rgb[1] << 8)  |
           ((uint32_t)s->rgb[2] << 16);

    ctrl = ((uint32_t)s->algorithm << HIP_CTRL_ALGO_SHIFT) & HIP_CTRL_ALGO_MASK;

    Xil_Out32(HIP_REG_THRESHOLD, (uint32_t)s->threshold);
    Xil_Out32(HIP_REG_RGB, rgb);
    Xil_Out32(HIP_REG_CTRL, ctrl);
#else
    (void)s;   /* HIP not in the bitstream yet: keep settings, skip the write */
#endif
}

/*
 * Copy the current settings and write them to the HIP.
 * Takes both mutexes, in order: settings first, then hardware.
 */
static void hip_apply_current_settings(void)
{
    hip_settings_t snap;

    xSemaphoreTake(xSettingsMutex, portMAX_DELAY);
    snap = xSettings;
    xSemaphoreGive(xSettingsMutex);

    xSemaphoreTake(xHwMutex, portMAX_DELAY);
    hip_write_settings(&snap);
    xSemaphoreGive(xHwMutex);
}

#if HIP_DMA_ENABLE

/* Set up the AXI DMA in simple (non-scatter-gather) polled mode. */
static int hip_dma_init(void)
{
    XAxiDma_Config *cfg;

#ifndef SDT
    cfg = XAxiDma_LookupConfig(XPAR_AXIDMA_0_DEVICE_ID);
#else
    cfg = XAxiDma_LookupConfig(XPAR_XAXIDMA_0_BASEADDR);
#endif
    if (cfg == NULL) {
        return XST_FAILURE;
    }

    if (XAxiDma_CfgInitialize(&xDma, cfg) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    if (XAxiDma_HasSg(&xDma)) {
        return XST_FAILURE;          /* scatter-gather is not supported here */
    }

    XAxiDma_IntrDisable(&xDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&xDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    return XST_SUCCESS;
}

/* Wait for a DMA channel to go idle, or give up after DMA_TIMEOUT_LOOPS. */
static int hip_dma_wait(int direction)
{
    uint32_t t;

    for (t = 0; t < DMA_TIMEOUT_LOOPS; t++) {
        if (!XAxiDma_Busy(&xDma, direction)) {
            return XST_SUCCESS;
        }
    }
    return XST_FAILURE;
}

/*
 * Run one chunk through the HIP using the DMA loop:
 *   1. arm S2MM (DMA writes what comes out of the HIP into DDR)
 *   2. push the chunk into the HIP as 32-bit words over FSL, TLAST on the last
 *   3. wait for S2MM to finish
 *   4. arm MM2S (DMA reads the processed data back out of DDR)
 *   5. read the words back over FSL and unpack them into the chunk
 * The chunk is processed in place. Caller must hold xHwMutex.
 * len must be a multiple of 4 and non-zero (checked by the caller).
 * Bytes are packed big-endian within each word; pack and unpack are symmetric,
 * so a passthrough returns the original bytes exactly.
 */
static int hip_process_chunk(uint8_t *data, uint16_t len)
{
    uint32_t nbytes = (uint32_t)len;
    uint32_t nwords = nbytes / 4u;
    uint32_t i;
    uint32_t w;
    int      status;

    status = XAxiDma_SimpleTransfer(&xDma, (UINTPTR)HIP_DDR_ADDR,
                                    nbytes, XAXIDMA_DEVICE_TO_DMA);
    if (status != XST_SUCCESS) {
        return status;
    }

    for (i = 0; i < nwords; i++) {
        w = ((uint32_t)data[4u * i]      << 24) |
            ((uint32_t)data[4u * i + 1u] << 16) |
            ((uint32_t)data[4u * i + 2u] << 8)  |
             (uint32_t)data[4u * i + 3u];

        if (i == nwords - 1u) {
            cputfsl(w, HIP_FSL_ID);      /* TLAST = 1 */
        } else {
            putfsl(w, HIP_FSL_ID);       /* TLAST = 0 */
        }
    }

    if (hip_dma_wait(XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    status = XAxiDma_SimpleTransfer(&xDma, (UINTPTR)HIP_DDR_ADDR,
                                    nbytes, XAXIDMA_DMA_TO_DEVICE);
    if (status != XST_SUCCESS) {
        return status;
    }

    for (i = 0; i < nwords; i++) {
        getfsl(w, HIP_FSL_ID);
        data[4u * i]      = (uint8_t)(w >> 24);
        data[4u * i + 1u] = (uint8_t)(w >> 16);
        data[4u * i + 2u] = (uint8_t)(w >> 8);
        data[4u * i + 3u] = (uint8_t)(w);
    }

    if (hip_dma_wait(XAXIDMA_DMA_TO_DEVICE) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    return XST_SUCCESS;
}

#else

/*
 * DMA disabled: the chunk passes through unchanged.
 * Used to test the UART protocol on its own.
 */
static int hip_process_chunk(uint8_t *data, uint16_t len)
{
    (void)data;
    (void)len;
    return XST_SUCCESS;
}

#endif

/* -------------------------------------------------------------------------- */
/*  Boot banner (raw text, sent once before the scheduler starts)             */
/* -------------------------------------------------------------------------- */

#if UART_BOOT_BANNER
static void uart_send_raw(const char *s)
{
    while (*s != '\0') {
        XUartLite_SendByte(UART_BASEADDR, (uint8_t)*s);
        s++;
    }
}
#endif

/* -------------------------------------------------------------------------- */
/*  Frame encoding (transmit side)                                            */
/* -------------------------------------------------------------------------- */

/*
 * Build a wire frame from a type and payload, and queue it for the TX task.
 * Safe to call from any task.
 */
static void queue_wire(uint8_t type, const uint8_t *payload, uint16_t len)
{
    wire_t   w;
    uint8_t  chk;
    uint16_t i;

    chk = type ^ (uint8_t)(len & 0xFFu) ^ (uint8_t)(len >> 8);

    w.b[0] = FRAME_SYNC;
    w.b[1] = type;
    w.b[2] = (uint8_t)(len & 0xFFu);
    w.b[3] = (uint8_t)(len >> 8);

    for (i = 0; i < len; i++) {
        w.b[4u + i] = payload[i];
        chk ^= payload[i];
    }

    w.b[4u + len] = chk;
    w.n = (uint16_t)(len + 5u);

    xQueueSend(xTxQueue, &w, portMAX_DELAY);
}

/* Send a RESPONSE frame: payload = [opcode][status]. */
static void queue_response(uint8_t opcode, uint8_t status)
{
    uint8_t p[2];

    p[0] = opcode;
    p[1] = status;
    queue_wire(FRAME_RESP, p, 2u);
}

/* -------------------------------------------------------------------------- */
/*  Frame parsing (receive side)                                              */
/* -------------------------------------------------------------------------- */

/*
 * Feed one received byte into the parser.
 * Returns 1 when a complete, checksum-valid frame is ready in p->frame.
 *
 * Errors drop the current frame and return to PS_SYNC. The next 0xA5 starts a
 * new frame, so the parser recovers without a reset.
 */
static int parser_feed(parser_t *p, uint8_t b)
{
    switch (p->state) {

    case PS_SYNC:
        if (b == FRAME_SYNC) {
            p->state = PS_TYPE;
        }
        break;

    case PS_TYPE:
        p->type  = b;
        p->calc  = b;
        p->state = PS_LEN_LO;
        break;

    case PS_LEN_LO:
        p->len_lo = b;
        p->calc  ^= b;
        p->state  = PS_LEN_HI;
        break;

    case PS_LEN_HI:
        p->calc ^= b;
        p->len = (uint16_t)(p->len_lo | ((uint16_t)b << 8));
        if (p->len > MAX_PAYLOAD) {
            p->state = PS_SYNC;          /* impossible length: drop */
            break;
        }
        p->idx   = 0;
        p->state = (p->len == 0u) ? PS_CHECKSUM : PS_PAYLOAD;
        break;

    case PS_PAYLOAD:
        p->frame.data[p->idx++] = b;
        p->calc ^= b;
        if (p->idx >= p->len) {
            p->state = PS_CHECKSUM;
        }
        break;

    case PS_CHECKSUM:
        p->state = PS_SYNC;
        if (b == p->calc) {
            p->frame.type = p->type;
            p->frame.len  = p->len;
            return 1;
        }
        /* Bad checksum: drop the frame. */
        break;

    default:
        p->state = PS_SYNC;
        break;
    }

    return 0;
}

/* Route a complete frame to the right queue. Never blocks the RX task. */
static void route_frame(const frame_t *f)
{
    BaseType_t sent = pdFAIL;

    if (f->type == FRAME_CMD) {
        sent = xQueueSend(xCmdQueue, f, 0);
    } else if (f->type == FRAME_DATA) {
        sent = xQueueSend(xDataQueue, f, 0);
    }

    if (sent != pdPASS) {
        ulDroppedFrames++;
    }
}

/* -------------------------------------------------------------------------- */
/*  Tasks                                                                     */
/* -------------------------------------------------------------------------- */

/*
 * RX task: drains the UART receive FIFO and feeds bytes into the parser.
 * Polled, so it yields one tick whenever no data is waiting.
 */
static void vRxTask(void *pvParameters)
{
    static parser_t xParser;     /* static: keeps the parser buffer off the stack */
    int i;

    (void)pvParameters;
    xParser.state = PS_SYNC;

    for (;;) {
        /* Read at most one FIFO's worth per pass, so other tasks still run. */
        for (i = 0; i < 16 && !XUartLite_IsReceiveEmpty(UART_BASEADDR); i++) {
            uint8_t b = XUartLite_RecvByte(UART_BASEADDR);
            if (parser_feed(&xParser, b)) {
                route_frame(&xParser.frame);
            }
        }
        vTaskDelay(1);
    }
}

/*
 * COMMAND task: applies settings changes and sends a RESPONSE for every
 * command, including unknown opcodes and bad lengths.
 */
static void vCmdTask(void *pvParameters)
{
    frame_t f;
    uint8_t op;
    uint8_t status;

    (void)pvParameters;

    for (;;) {
        xQueueReceive(xCmdQueue, &f, portMAX_DELAY);

        op     = 0u;
        status = ST_OK;

        if (f.len < 1u) {
            status = ST_BAD_LENGTH;
        } else {
            op = f.data[0];

            switch (op) {

            case OP_PING:
                if (f.len != 1u) {
                    status = ST_BAD_LENGTH;
                }
                break;

            case OP_SET_THRESHOLD:
                if (f.len != 2u) {
                    status = ST_BAD_LENGTH;
                    break;
                }
                xSemaphoreTake(xSettingsMutex, portMAX_DELAY);
                xSettings.threshold = f.data[1];
                xSemaphoreGive(xSettingsMutex);
                hip_apply_current_settings();
                break;

            case OP_SET_RGB:
                if (f.len != 4u) {
                    status = ST_BAD_LENGTH;
                    break;
                }
                xSemaphoreTake(xSettingsMutex, portMAX_DELAY);
                xSettings.rgb[0] = f.data[1];
                xSettings.rgb[1] = f.data[2];
                xSettings.rgb[2] = f.data[3];
                xSemaphoreGive(xSettingsMutex);
                hip_apply_current_settings();
                break;

            case OP_SET_ALGORITHM:
                if (f.len != 2u) {
                    status = ST_BAD_LENGTH;
                    break;
                }
                if (f.data[1] > ALGO_MAX) {
                    status = ST_BAD_ARG;
                    break;
                }
                xSemaphoreTake(xSettingsMutex, portMAX_DELAY);
                xSettings.algorithm = f.data[1];
                xSemaphoreGive(xSettingsMutex);
                hip_apply_current_settings();
                break;

            default:
                status = ST_UNKNOWN_OPCODE;
                break;
            }
        }

        queue_response(op, status);
    }
}

/*
 * DATA task: runs each pixel chunk through the pipeline and sends it back.
 * The settings snapshot is taken under xSettingsMutex. The hardware is held
 * under xHwMutex for the whole chunk.
 */
static void vDataTask(void *pvParameters)
{
    frame_t        f;
    hip_settings_t snap;
    int            rc;

    (void)pvParameters;

    for (;;) {
        xQueueReceive(xDataQueue, &f, portMAX_DELAY);

#if HIP_DMA_ENABLE
        /* The DMA moves whole 32-bit words, so the chunk must be 4-byte aligned. */
        if (f.len == 0u || (f.len & 3u) != 0u) {
            queue_response(OP_DATA, ST_BAD_LENGTH);
            continue;
        }
#endif

        xSemaphoreTake(xSettingsMutex, portMAX_DELAY);
        snap = xSettings;
        xSemaphoreGive(xSettingsMutex);

        xSemaphoreTake(xHwMutex, portMAX_DELAY);
        hip_write_settings(&snap);
        rc = hip_process_chunk(f.data, f.len);
        xSemaphoreGive(xHwMutex);

        if (rc == XST_SUCCESS) {
            queue_wire(FRAME_DATA, f.data, f.len);
        } else {
            queue_response(OP_DATA, ST_HW_ERROR);
        }
    }
}

/*
 * TX task: the only task that writes to the UART transmitter.
 * XUartLite_SendByte waits while the TX FIFO is full, so no bytes are lost.
 */
static void vTxTask(void *pvParameters)
{
    wire_t   w;
    uint16_t i;

    (void)pvParameters;

    for (;;) {
        xQueueReceive(xTxQueue, &w, portMAX_DELAY);
        for (i = 0; i < w.n; i++) {
            XUartLite_SendByte(UART_BASEADDR, w.b[i]);
        }
    }
}

/* -------------------------------------------------------------------------- */
/*  Application entry point                                                   */
/* -------------------------------------------------------------------------- */

int main(void)
{
#if HIP_DMA_ENABLE
    int status;

    status = hip_dma_init();
    configASSERT(status == XST_SUCCESS);
    (void)status;
#endif

    xCmdQueue      = xQueueCreate(CMD_QUEUE_LEN,  sizeof(frame_t));
    xDataQueue     = xQueueCreate(DATA_QUEUE_LEN, sizeof(frame_t));
    xTxQueue       = xQueueCreate(TX_QUEUE_LEN,   sizeof(wire_t));
    xSettingsMutex = xSemaphoreCreateMutex();
    xHwMutex       = xSemaphoreCreateMutex();

    configASSERT(xCmdQueue);
    configASSERT(xDataQueue);
    configASSERT(xTxQueue);
    configASSERT(xSettingsMutex);
    configASSERT(xHwMutex);

    /* Push the default settings to the HIP (no-op while HIP_PRESENT is 0). */
    hip_apply_current_settings();

#if UART_BOOT_BANNER
    /* Raw text, sent before any task runs. Contains no 0xA5, so the parser
       on the PC side skips it. */
    uart_send_raw("\r\nECE544 uart_app ready\r\n");
#endif

    configASSERT(xTaskCreate(vRxTask,   "RX",   TASK_STACK_WORDS, NULL, PRIO_RX,   NULL) == pdPASS);
    configASSERT(xTaskCreate(vCmdTask,  "CMD",  TASK_STACK_WORDS, NULL, PRIO_CMD,  NULL) == pdPASS);
    configASSERT(xTaskCreate(vDataTask, "DATA", TASK_STACK_WORDS, NULL, PRIO_DATA, NULL) == pdPASS);
    configASSERT(xTaskCreate(vTxTask,   "TX",   TASK_STACK_WORDS, NULL, PRIO_TX,   NULL) == pdPASS);

    vTaskStartScheduler();

    /* Only reached if the scheduler could not start (heap too small). */
    for (;;) {
    }
}