include $(DMA_DIR)/hardware/hardware.mk

ifeq ($(VCD),1)
DEFINE+=$(defmacro)VCD
endif

DMA_TB_DIR=$(DMA_DIR)/hardware/simulation/testbench

VSRC+=$(wildcard $(DMA_TB_DIR)/*.v)