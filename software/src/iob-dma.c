#include "iob-dma.h"

// DMA functions

// Set DMA interface base address
void dma_init(int base_address){
  IOB_DMA_INIT_BASEADDR(base_address);
}

// Start a DMA transfer from source to destination.
void dma_start_transfer(uint32_t *src_addr, uint32_t *dst_addr, uint32_t transf_length, 
                        uint32_t burst_len, uint32_t src_burst_type, uint32_t dst_burst_type, 
                        uint8_t src_dma_req_en, uint8_t dst_dma_req_en){
  src_burst_type = (src_burst_type == DMA_BURST_TYPE_FIXED) ? DMA_BURST_TYPE_FIXED : DMA_BURST_TYPE_INCR;
  dst_burst_type = (dst_burst_type == DMA_BURST_TYPE_FIXED) ? DMA_BURST_TYPE_FIXED : DMA_BURST_TYPE_INCR;
  IOB_DMA_SET_src_addr((uint32_t)src_addr);
  IOB_DMA_SET_dst_addr((uint32_t)dst_addr);
  IOB_DMA_SET_transf_length(transf_length);
  IOB_DMA_SET_burstlen(burst_len);
  IOB_DMA_SET_src_burst_type(src_burst_type);
  IOB_DMA_SET_dst_burst_type(dst_burst_type);
  IOB_DMA_SET_r_dma_req_en(src_dma_req_en);
  IOB_DMA_SET_w_dma_req_en(dst_dma_req_en);
  IOB_DMA_SET_start(1);
}

// Check if DMA is busy
uint8_t dma_busy(){
  return IOB_DMA_GET_busy();
}

uint8_t dma_get_r_resp(){
  return (uint8_t)IOB_DMA_GET_r_resp();
}

uint8_t dma_get_w_resp(){
  return (uint8_t)IOB_DMA_GET_w_resp();
}

void dma_clear_r_resp(){
  IOB_DMA_SET_r_resp_clear(1);
}

void dma_clear_w_resp(){
  IOB_DMA_SET_w_resp_clear(1);
}

