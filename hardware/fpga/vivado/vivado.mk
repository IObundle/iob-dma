FPGA_OBJ=dma_axi.edif
FPGA_LOG=vivado.log

CLKBUF_WRAPPER:=xilinx
CONSTRAINTS:=$(wildcard *.xdc)

FPGA_SERVER=$(VIVADO_SERVER)
FPGA_USER=$(VIVADO_USER)

include ../../fpga.mk

post-build: