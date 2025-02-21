#!/usr/bin/env python3

import os

from iob_module import iob_module

# Submodules
from iob_reg import iob_reg
from iob_reg_e import iob_reg_e
from axis2axi import axis2axi
from iob_mux import iob_mux
from iob_demux import iob_demux
from iob_ram_2p import iob_ram_2p


class iob_dma(iob_module):
    name = 'iob_dma'
    version = "V0.10"
    flows = "sim emb"
    setup_dir = os.path.dirname(__file__)

    @classmethod
    def _create_submodules_list(cls):
        ''' Create submodules list with dependencies of this module
        '''
        super()._create_submodules_list([
            {"interface": "iob_s_port"},
            {"interface": "iob_s_portmap"},
            {"interface": "axi_m_port"},
            iob_reg,
            iob_reg_e,
            axis2axi,
            iob_mux,
            iob_demux,
            (iob_ram_2p, {"purpose": "simulation"}),
            (iob_ram_2p, {"purpose": "fpga"}),
        ])

    @classmethod
    def _setup_confs(cls):
        super()._setup_confs([
            # Macros

            # Parameters
            # IOb-native (swreg) interface
            {'name':'DATA_W',      'type':'P', 'val':'32', 'min':'NA', 'max':'32', 'descr':"Data bus width"},
            {'name':'ADDR_W',      'type':'P', 'val':'`IOB_DMA_SWREG_ADDR_W', 'min':'NA', 'max':'NA', 'descr':"Address bus width"},
            # External memory interface
            {
                "name": "AXI_ID_W",
                "type": "P",
                "val": "0",
                "min": "1",
                "max": "32",
                "descr": "AXI ID bus width",
            },
            {
                "name": "AXI_ADDR_W",
                "type": "P",
                "val": "24",
                "min": "1",
                "max": "32",
                "descr": "AXI address bus width",
            },
            {
                "name": "AXI_DATA_W",
                "type": "P",
                "val": "DATA_W",
                "min": "1",
                "max": "32",
                "descr": "AXI data bus width",
            },
            {
                "name": "AXI_LEN_W",
                "type": "P",
                "val": "4",
                "min": "1",
                "max": "4",
                "descr": "AXI burst length width",
            },
            {
                "name": "BURST_W",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "8",
                "descr": "AXI burst width",
            },
            {
                "name": "BUFFER_W",
                "type": "P",
                "val": "1",  # BURST_W+1
                "min": "0",
                "max": "32",
                "descr": "Buffer size",
            },
            {
                "name": "MEM_ADDR_OFFSET",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "NA",
                "descr": "Offset of memory address",
            },
            # AXI Stream interface (for cores)
            {
                "name": "TDATA_W",
                "type": "P",
                "val": "32",
                "min": "NA",
                "max": "DATA_W",
                "descr": "Width of tdata interface (can be up to DATA_W)",
            },
            {
                "name": "N_INPUTS",
                "type": "P",
                "val": "1",
                "min": "NA",
                "max": "32",
                "descr": "Number of AXI Stream input interfaces (to tranfer from core to memory)",
            },
            {
                "name": "N_OUTPUTS",
                "type": "P",
                "val": "1",
                "min": "NA",
                "max": "32",
                "descr": "Number of AXI Stream output interfaces (to transfer from memory to core)",
            },
        ])

    @classmethod
    def _setup_ios(cls):
        cls.ios += [
            {'name': 'iob_s_port', 'descr':'CPU native interface', 'ports': [
            ]},
            {'name': 'general', 'descr':'GENERAL INTERFACE SIGNALS', 'ports': [
                {'name':"clk_i" , 'type':"I", 'n_bits':'1', 'descr':"System clock input"},
                {'name':"arst_i", 'type':"I", 'n_bits':'1', 'descr':"System reset, asynchronous and active high"},
                {'name':"cke_i", 'type':"I", 'n_bits':'1', 'descr':"System clock enable signal."},
            ]},
            {'name': 'axi_m_port', 'descr':'AXI master interface for external memory.', 'ports': []},
            {
                "name": "dma_input",
                "descr": "AXI Stream DMA input interface.",
                "ports": [
                    {
                        "name": "tdata_i",
                        "type": "I",
                        "n_bits": "TDATA_W*N_INPUTS",
                        "descr": "TData input interface",
                    },
                    {
                        "name": "tvalid_i",
                        "type": "I",
                        "n_bits": "N_INPUTS",
                        "descr": "TValid input interface",
                    },
                    {
                        "name": "tready_o",
                        "type": "O",
                        "n_bits": "N_INPUTS",
                        "descr": "TReady output interface",
                    },
                ],
            },
            {
                "name": "dma_output",
                "descr": "AXI Stream DMA output interface.",
                "ports": [
                    {
                        "name": "tdata_o",
                        "type": "O",
                        "n_bits": "TDATA_W*N_OUTPUTS",
                        "descr": "TData output interface",
                    },
                    {
                        "name": "tvalid_o",
                        "type": "O",
                        "n_bits": "N_OUTPUTS",
                        "descr": "TValid output interface",
                    },
                    {
                        "name": "tready_i",
                        "type": "I",
                        "n_bits": "N_OUTPUTS",
                        "descr": "TReady input interface",
                    },
                ],
            },
        ]

    @classmethod
    def _setup_regs(cls):
        cls.regs += [
            {'name': 'dma', 'descr':'DMA software accessible registers.', 'regs': [
                {
                    "name": "SOFT_RESET",
                    "type": "W",
                    "n_bits": 1,
                    "rst_val": 0,
                    "log2n_items": 0,
                    "autoreg": True,
                    "descr": "Software reset. Writing 1 will reset the DMA module. Needs to be set back to 0.",
                },
                {
                    "name": "BASE_ADDR",
                    "type": "W",
                    "n_bits": 32,
                    "rst_val": 0,
                    "log2n_items": 0,
                    "autoreg": True,
                    "descr": "Base address of memory block to start the transfer",
                },
                {
                    "name": "TRANSFER_SIZE",
                    "type": "W",
                    "n_bits": 32,
                    "rst_val": 0,
                    "log2n_items": 0,
                    "autoreg": True,
                    "descr": "Amount of bytes to transfer from/to memory block. Writing to this register will start the transfer. The other configuration registers should be set first: BASE_ADDR, DIRECTION, INTERFACE_NUM.",
                },
                {
                    "name": "DIRECTION",
                    "type": "W",
                    "n_bits": 1,
                    "rst_val": 0,
                    "log2n_items": 0,
                    "autoreg": True,
                    "descr": "Transfer direction: 0:from memory to core, 1:from core to memory",
                },
                {
                    "name": "INTERFACE_NUM",
                    "type": "W",
                    "n_bits": 16,
                    "rst_val": 0,
                    "log2n_items": 0,
                    "autoreg": True,
                    "descr": "Interface number to tranfer data from/to.",
                },
                {
                    "name": "READY_R",
                    "type": "R",
                    "n_bits": 1,
                    "rst_val": 0,
                    "log2n_items": 0,
                    "autoreg": True,
                    "descr": "Ready for read transfer from memory.",
                },
                {
                    "name": "READY_W",
                    "type": "R",
                    "n_bits": 1,
                    "rst_val": 0,
                    "log2n_items": 0,
                    "autoreg": True,
                    "descr": "Ready for write transfer to memory.",
                },
            ]}
        ]

    @classmethod
    def _setup_block_groups(cls):
        cls.block_groups += []
