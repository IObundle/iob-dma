#include "iob-dma.h"

// DMA functions

// Set DMA interface base address
void dma_init(int base_address){
  IOB_DMA_INIT_BASEADDR(base_address);
}

// Start a DMA transfer from source to destination.
void dma_start_transfer(uint32_t *src_addr, uint32_t *dst_addr, uint32_t length, uint32_t burst_len){
  IOB_DMA_SET_src_addr((uint32_t)src_addr);
  IOB_DMA_SET_dst_addr((uint32_t)dst_addr);
  IOB_DMA_SET_length(length);
  IOB_DMA_SET_burstlen(burst_len);
  IOB_DMA_SET_start(1);
}

// Check if DMA is busy
uint8_t dma_busy(){
  return IOB_DMA_GET_busy();
}

