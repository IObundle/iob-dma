/* PC Emulation of PFSM peripheral */

#include <stdint.h>
#include <stdio.h>

#include "iob-dma.h"

static uint32_t base;
void IOB_DMA_INIT_BASEADDR(uint32_t addr) {
	base = addr;
}

void dma_start_transfer(uint32_t *src_addr, uint32_t *dst_addr, uint32_t transf_length, uint32_t burst_len, uint32_t src_burst_type, uint32_t dst_burst_type){
}

uint8_t dma_busy(){
    return 0;
}

uint8_t dma_get_r_resp(){
	return 0;
}

uint8_t dma_get_w_resp(){
	return 0;
}

void dma_clear_r_resp(){
}

void dma_clear_w_resp(){
}
