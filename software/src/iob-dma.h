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
                        uint32_t length, uint32_t burst_len,
                        uint32_t src_burst_type, uint32_t dst_burst_type);

// Check if DMA is busy
uint8_t dma_busy();

#endif //_IOB_DMA_H_
