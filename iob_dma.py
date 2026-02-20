#!/usr/bin/env python3

import os

from iob_module import iob_module

# Submodules
from iob_axi_m import iob_axi_m
from iob_ram_2p import iob_ram_2p

class iob_dma(iob_module):
    name = "iob_dma"
    version = "V0.20"
    flows = "sim emb"
    setup_dir = os.path.dirname(__file__)

    @classmethod
    def _create_submodules_list(cls):
        """Create submodules list with dependencies of this module"""
        super()._create_submodules_list(
            [
                {"interface": "clk_en_rst_s_port"},
                {"interface": "clk_en_rst_s_s_portmap"},
                {"interface": "iob_s_port"},
                {"interface": "iob_s_portmap"},
                {"interface": "axi_m_port"},
                {"interface": "axi_m_m_portmap"},
                iob_axi_m,
                iob_ram_2p,
            ]
        )

    @classmethod
    def _setup_confs(cls):
        super()._setup_confs(
            [
                # CSR interface
                {
                    "name": "DATA_W",
                    "type": "F",
                    "val": "32",
                    "min": "NA",
                    "max": "32",
                    "descr": "Data bus width",
                },
                {
                    "name": "ADDR_W",
                    "type": "F",
                    "val": "`IOB_DMA_SWREG_ADDR_W",
                    "min": "NA",
                    "max": "NA",
                    "descr": "Address bus width",
                },
                # AXI interface
                {
                    "name": "AXI_ADDR_W",
                    "type": "P",
                    "val": "24",
                    "min": "1",
                    "max": "32",
                    "descr": "AXI address bus width",
                },
                {
                    "name": "AXI_LEN_W",
                    "type": "P",
                    "val": "8",
                    "min": "1",
                    "max": "8",
                    "descr": "AXI burst length width",
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
                    "name": "AXI_ID_W",
                    "type": "P",
                    "val": "1",
                    "min": "NA",
                    "max": "NA",
                    "descr": "AXI ID width",
                },
                {
                    "name": "LENGTH_W",
                    "type": "P",
                    "val": "12",
                    "min": "1",
                    "max": "AXI_ADDR_W",
                    "descr": "Transfer length width",
                },
            ]
        )

    @classmethod
    def _setup_ios(cls):
        cls.ios += [
            {"name": "axil_s_port", "descr": "AXI-Lite subordinate CSRs interface", "ports": []},
            {
                "name": "general",
                "descr": "General system signals",
                "ports": [
                    {
                        "name": "clk_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "System clock input",
                    },
                    {
                        "name": "arst_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "System reset, asynchronous and active high",
                    },
                    {
                        "name": "cke_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "System clock enable signal.",
                    },
                ],
            },
            {
                "name": "axi_m_port",
                "descr": "AXI manager interface for external memory.",
                "ports": [],
            },
        ]

    @classmethod
    def _setup_regs(cls):
        cls.regs += [
            {
                "name": "general",
                "descr": "DMA general software accessible registers.",
                "regs": [
                    {
                        "name": "soft_reset",
                        "type": "W",
                        "n_bits": 1,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Soft reset: writing any value to this register resets DMA.",
                    },
                ],
            },
            {
                "name": "transfer_config",
                "descr": "DMA transfer software accessible registers.",
                "regs": [
                    {
                        "name": "src_addr",
                        "type": "W",
                        "n_bits": "AXI_ADDR_W",
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "Source start address.",
                    },
                    {
                        "name": "dst_addr",
                        "type": "W",
                        "n_bits": "AXI_ADDR_W",
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "Destination start address.",
                    },
                    {
                        "name": "length",
                        "type": "W",
                        "n_bits": "LENGTH_W",
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "Transfer length in words.",
                    },
                    {
                        "name": "busy",
                        "type": "R",
                        "n_bits": 1,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "DMA busy: high while a transfer is ongoing.",
                    },
                    {
                        "name": "start",
                        "type": "W",
                        "n_bits": 1,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": False,
                        "descr": "Start transfer: writing any value starts the DMA transfer.",
                    },
                    {
                        "name": "burstlen",
                        "type": "W",
                        "n_bits": "(AXI_LEN_W+1)",
                        "rst_val": 16,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "AXI burst length for transfers.",
                    },
                    {
                        "name": "buf_level",
                        "type": "R",
                        "n_bits": "LENGTH_W",
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "Number of words left in the current DMA transfer.",
                    },
                ],
            },
        ]

    @classmethod
    def _setup_block_groups(cls):
        cls.block_groups += []
