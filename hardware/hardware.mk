ifeq ($(filter DMA, $(HW_MODULES)),)

MEM_DIR ?= $(DMA_DIR)/submodules/MEM
LIB_DIR ?=$(DMA_DIR)/submodules/LIB

#add itself to HW_MODULES list
HW_MODULES+=DMA

DMA_SRC_DIR = $(DMA_DIR)/hardware/src

INCLUDE += $(incdir)$(LIB_DIR)/hardware/include

#DMA HARDWARE

# sources
VSRC+=$(DMA_SRC_DIR)/iob_dma.v

endif
