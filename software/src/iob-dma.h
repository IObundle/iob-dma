#ifndef _IOB_DMA_H_
#define _IOB_DMA_H_

#include <stdint.h>

#include "iob_dma_swreg.h"

// DMA functions

#define DMA_BURST_TYPE_FIXED 0u
#define DMA_BURST_TYPE_INCR  1u

// Set DMA base address and Verilog parameters
void dma_init(int base_address);

// Start a DMA source-to-destination transfer
void dma_start_transfer(uint32_t *src_addr, uint32_t *dst_addr,
                        uint32_t transf_length, uint32_t burst_len,
                        uint32_t src_burst_type, uint32_t dst_burst_type,
                        uint8_t src_dma_req_en, uint8_t dst_dma_req_en);

// Check if DMA is busy
uint8_t dma_busy();

// Get sticky AXI response status (OKAY=0, EXOKAY=1, SLVERR=2, DECERR=3)
uint8_t dma_get_r_resp();
uint8_t dma_get_w_resp();

// Clear sticky AXI response status CSRs
void dma_clear_r_resp();
void dma_clear_w_resp();

#endif //_IOB_DMA_H_
