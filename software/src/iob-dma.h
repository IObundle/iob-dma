#ifndef _DMA_H_
#define _DMA_H_

#include <stdint.h>

#include "iob_dma_swreg.h"

//DMA functions

// Set DMA base address and Verilog parameters
void dma_init(int base_address);

// Reset DMA
void dma_rst();

// Start a DMA transfer
void dma_start_transfer(uint32_t *base_addr, uint32_t size, int direction, uint16_t interface_number);

// Check if DMA is ready for new transfer
uint8_t dma_transfer_ready();

#endif //_DMA_H_
