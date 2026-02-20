/* PC Emulation of PFSM peripheral */

#include <stdint.h>
#include <stdio.h>

#include "iob-dma.h"

static uint32_t base;
void IOB_DMA_INIT_BASEADDR(uint32_t addr) {
	base = addr;
}

void dma_start_transfer(uint32_t *src_addr, uint32_t *dst_addr, uint32_t length, uint32_t burst_len){
}

uint8_t dma_busy(){
    return 0;
}
