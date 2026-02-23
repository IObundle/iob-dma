# iob-dma

DMA for IObundle SoCs with:

- **1 AXI manager data interface** (memory source/destination path)
- **1 AXI-Lite subordinate control interface** (register programming and status)

This repository contains the hardware module, software driver, and integration support files for simulation/embedding flows.

## Overview

`iob-dma` moves data from an AXI-full source address range to an AXI-full destination address range under software control.
Software configures source/destination addresses, transfer length, burst length, and source/destination burst types through the control registers, then starts source-to-destination DMA operations.

Supported burst types are `DMA_BURST_TYPE_FIXED` (0) and `DMA_BURST_TYPE_INCR` (1) for both source and destination paths.

## DMA Operation

- The DMA reads data from AXI source address space and writes it to AXI destination address space.
- The internal datapath connects read-side output to write-side input, so no external AXI-Stream interface is required.
- A single `start` triggers both source read and destination write paths.
- `busy` remains high while the transfer is in progress.

Example programming sequence:

```c
dma_init(DMA_BASEADDR);
dma_start_transfer(src_addr, dst_addr, length_words, burstlen_words,
				   DMA_BURST_TYPE_INCR, DMA_BURST_TYPE_FIXED);
while (dma_busy()) {
	// wait
}
```

## Main Interfaces

### AXI manager data interface

- Used for DMA transfers between AXI-full source and destination memory regions.
- Configurable address, burst length, ID, and data width parameters.

### AXI-Lite subordinate control interface

- Used by CPU/software to configure and monitor the DMA.
- Exposes control/status registers for source and destination addressing plus shared transfer control/status.

## Register-Level Control

The DMA exposes source and destination address/burst-type registers, plus shared transfer control/status fields:

- Source address: `src_addr`
- Destination address: `dst_addr`
- Source transfer fields: `src_addr`, `src_burst_type`
- Destination transfer fields: `dst_addr`, `dst_burst_type`
- Shared transfer fields: `length`, `burstlen`, `start`, `busy`, `buf_level`
- `soft_reset`

Typical sequence:

1. Program `src_addr` and `dst_addr`.
2. Program `length`, `burstlen`, `src_burst_type`, and `dst_burst_type`.
3. Trigger `start`.
4. Poll `busy` until transfer completes.

## Software API

Driver files are available in `software/src/`:

- `iob-dma.h`
- `iob-dma.c`

Exposed helper functions:

- `dma_init(...)`: initializes the DMA base address.
- `dma_start_transfer(...)`: starts a source-to-destination transfer.
- `dma_busy(...)`: reports transfer progress.

```c
void dma_init(int base_address);
void dma_start_transfer(uint32_t *src_addr, uint32_t *dst_addr,
						uint32_t length, uint32_t burstlen,
						uint32_t src_burst_type, uint32_t dst_burst_type);
uint8_t dma_busy();
```

## Repository Structure

- `iob_dma.py`: DMA description and configurable parameters
- `hardware/src/iob_dma.v`: top-level RTL
- `software/src/`: C driver and software support
