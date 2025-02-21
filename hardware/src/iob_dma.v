`timescale 1ns / 1ps

`include "iob_dma_conf.vh"
`include "iob_dma_swreg_def.vh"

`define SEL_BITS(N) ($clog2(N)+($clog2(N)==0))-1:0

module iob_dma #(
   `include "iob_dma_params.vs"
) (
   `include "iob_dma_io.vs"
);

   //BLOCK Register File & Configuration control and status register file.
   `include "iob_dma_swreg_inst.vs"

   wire [AXI_ADDR_W-1:0] internal_axi_awaddr_o;
   wire [AXI_ADDR_W-1:0] internal_axi_araddr_o;

   assign axi_awaddr_o = internal_axi_awaddr_o + MEM_ADDR_OFFSET;
   assign axi_araddr_o = internal_axi_araddr_o + MEM_ADDR_OFFSET;

   // External memory interfaces
   wire                  ext_mem_clk;
   wire [         1-1:0] ext_mem_w_en;
   wire [AXI_DATA_W-1:0] ext_mem_w_data;
   wire [  BUFFER_W-1:0] ext_mem_w_addr;
   wire [         1-1:0] ext_mem_r_en;
   wire [  BUFFER_W-1:0] ext_mem_r_addr;
   wire [AXI_DATA_W-1:0] ext_mem_r_data;

   // AXIS In
   wire [AXI_DATA_W-1:0] axis_in_data;
   wire [         1-1:0] axis_in_valid;
   wire [         1-1:0] axis_in_ready;

   // AXIS Out
   wire [AXI_DATA_W-1:0] axis_out_data;
   wire [         1-1:0] axis_out_valid;
   wire [         1-1:0] axis_out_ready;

   // Mux between AXIS Inptus
   iob_mux #(
      .DATA_W(TDATA_W),
      .N     (N_INPUTS)
   ) tdata_in_mux (
      .sel_i (INTERFACE_NUM_wr[`SEL_BITS(N_INPUTS)]),
      .data_i(tdata_i),
      .data_o(axis_in_data)
   );

   iob_mux #(
      .DATA_W(1),
      .N     (N_INPUTS)
   ) tvalid_in_mux (
      .sel_i (INTERFACE_NUM_wr[`SEL_BITS(N_INPUTS)]),
      .data_i(tvalid_i),
      .data_o(axis_in_valid)
   );

   wire receive_enabled;
   iob_demux #(
      .DATA_W(1),
      .N     (N_INPUTS)
   ) tready_in_demux (
      .sel_i (INTERFACE_NUM_wr[`SEL_BITS(N_INPUTS)]),
      .data_i(axis_in_ready & receive_enabled),        // Stop ready feedback if not receiving
      .data_o(tready_o)
   );

   // Demux between AXIS Outputs
   iob_demux #(
      .DATA_W(TDATA_W),
      .N     (N_OUTPUTS)
   ) tdata_out_demux (
      .sel_i (INTERFACE_NUM_wr[`SEL_BITS(N_OUTPUTS)]),
      .data_i(axis_out_data),
      .data_o(tdata_o)
   );

   iob_demux #(
      .DATA_W(1),
      .N     (N_OUTPUTS)
   ) tvalid_out_demux (
      .sel_i (INTERFACE_NUM_wr[`SEL_BITS(N_OUTPUTS)]),
      .data_i(axis_out_valid),
      .data_o(tvalid_o)
   );

   iob_mux #(
      .DATA_W(1),
      .N     (N_OUTPUTS)
   ) tready_out_mux (
      .sel_i (INTERFACE_NUM_wr[`SEL_BITS(N_OUTPUTS)]),
      .data_i(tready_i),
      .data_o(axis_out_ready)
   );

   wire BASE_ADDR_wen_wr = (iob_valid_i & iob_ready_o) & ((|iob_wstrb_i) & iob_addr_i==`IOB_DMA_BASE_ADDR_ADDR);
   wire TRANSFER_SIZE_wen_wr = (iob_valid_i & iob_ready_o) & ((|iob_wstrb_i) & iob_addr_i==`IOB_DMA_TRANSFER_SIZE_ADDR);

   // Create a 1 clock pulse when new value is written to BASE_ADDR
   reg base_addr_wen_delay_1;
   reg base_addr_wen_delay_2;
   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) begin
         base_addr_wen_delay_1 <= 0;
         base_addr_wen_delay_2 <= 0;
      end else begin
         base_addr_wen_delay_1 <= BASE_ADDR_wen_wr;
         base_addr_wen_delay_2 <= base_addr_wen_delay_1;
      end
   end
   wire base_addr_wen_pulse = base_addr_wen_delay_1 && ~base_addr_wen_delay_2;

   // Create a 1 clock pulse when new value is written to TRANSFER_SIZE
   reg  transfer_size_wen_delay_1;
   reg  transfer_size_wen_delay_2;
   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) begin
         transfer_size_wen_delay_1 <= 0;
         transfer_size_wen_delay_2 <= 0;
      end else begin
         transfer_size_wen_delay_1 <= TRANSFER_SIZE_wen_wr;
         transfer_size_wen_delay_2 <= transfer_size_wen_delay_1;
      end
   end
   wire          transfer_size_wen_pulse = transfer_size_wen_delay_1 && ~transfer_size_wen_delay_2;

   wire [32-1:0] receive_transfer_size;
   iob_reg_re #(
      .DATA_W (32),
      .RST_VAL(0)
   ) receive_transfer_size_reg (
      `include "clk_en_rst_s_s_portmap.vs"
      .rst_i (SOFT_RESET_wr),
      .en_i  ((DIRECTION_wr == 1 ? 1'b1 : 1'b0) & transfer_size_wen_delay_1),
      .data_i(TRANSFER_SIZE_wr),
      .data_o(receive_transfer_size)
   );

   // Count number of words read via AXI Stream in
   wire [32-1:0] axis_in_cnt_o;
   iob_counter #(
      .DATA_W (32),
      .RST_VAL(0)
   ) axis_in_cnt (
      `include "clk_en_rst_s_s_portmap.vs"
      .rst_i (((DIRECTION_wr == 1 ? 1'b1 : 1'b0) & transfer_size_wen_delay_1) | SOFT_RESET_wr),
      .en_i  (axis_in_valid & axis_in_ready & receive_enabled),
      .data_o(axis_in_cnt_o)
   );
   assign receive_enabled = axis_in_cnt_o != receive_transfer_size;
   wire transfer_complete;
   assign READY_W_rd = ~receive_enabled & transfer_complete;

   axis2axi #(
      .AXI_ADDR_W(AXI_ADDR_W),
      .AXI_DATA_W(AXI_DATA_W),
      .AXI_LEN_W (AXI_LEN_W),
      .AXI_ID_W  (AXI_ID_W),
      .BURST_W   (BURST_W),
      .BUFFER_W  (BUFFER_W)
   ) axis2axi_inst (
      // Configuration (AXIS In)
      .config_in_addr_i (BASE_ADDR_wr[AXI_ADDR_W-1:0]),
      .config_in_valid_i(base_addr_wen_pulse),
      .config_in_ready_o(transfer_complete),

      // Configuration (AXIS Out)
      .config_out_addr_i(BASE_ADDR_wr[AXI_ADDR_W-1:0]),
      .config_out_length_i(TRANSFER_SIZE_wr[AXI_ADDR_W-1:0]), // Will start new transfer when a new size is set
      .config_out_valid_i(transfer_size_wen_pulse && (DIRECTION_wr == 0 ? 1'b1 : 1'b0)),
      .config_out_ready_o(READY_R_rd),

      // AXIS In
      .axis_in_data_i(axis_in_data),
      .axis_in_valid_i(axis_in_valid & receive_enabled), // Stop new valid values if receive is complete
      .axis_in_ready_o(axis_in_ready),

      // AXIS Out
      .axis_out_data_o (axis_out_data),
      .axis_out_valid_o(axis_out_valid),
      .axis_out_ready_i(axis_out_ready),

      // AXI master interface
      // Can't use generated include, because of `internal_axi_*addr_o` signals.
      //include "axi_m_m_portmap.vs"
      .axi_awid_o(axi_awid_o),  //Address write channel ID.
      .axi_awaddr_o(internal_axi_awaddr_o),  //Address write channel address.
      .axi_awlen_o(axi_awlen_o),  //Address write channel burst length.
      .axi_awsize_o(axi_awsize_o), //Address write channel burst size. This signal indicates the size of each transfer in the burst.
      .axi_awburst_o(axi_awburst_o),  //Address write channel burst type.
      .axi_awlock_o(axi_awlock_o),  //Address write channel lock type.
      .axi_awcache_o(axi_awcache_o), //Address write channel memory type. Set to 0000 if master output; ignored if slave input.
      .axi_awprot_o(axi_awprot_o), //Address write channel protection type. Set to 000 if master output; ignored if slave input.
      .axi_awqos_o(axi_awqos_o),  //Address write channel quality of service.
      .axi_awvalid_o(axi_awvalid_o),  //Address write channel valid.
      .axi_awready_i(axi_awready_i),  //Address write channel ready.
      .axi_wdata_o(axi_wdata_o),  //Write channel data.
      .axi_wstrb_o(axi_wstrb_o),  //Write channel write strobe.
      .axi_wlast_o(axi_wlast_o),  //Write channel last word flag.
      .axi_wvalid_o(axi_wvalid_o),  //Write channel valid.
      .axi_wready_i(axi_wready_i),  //Write channel ready.
      .axi_bid_i(axi_bid_i),  //Write response channel ID.
      .axi_bresp_i(axi_bresp_i),  //Write response channel response.
      .axi_bvalid_i(axi_bvalid_i),  //Write response channel valid.
      .axi_bready_o(axi_bready_o),  //Write response channel ready.
      .axi_arid_o(axi_arid_o),  //Address read channel ID.
      .axi_araddr_o(internal_axi_araddr_o),  //Address read channel address.
      .axi_arlen_o(axi_arlen_o),  //Address read channel burst length.
      .axi_arsize_o(axi_arsize_o), //Address read channel burst size. This signal indicates the size of each transfer in the burst.
      .axi_arburst_o(axi_arburst_o),  //Address read channel burst type.
      .axi_arlock_o(axi_arlock_o),  //Address read channel lock type.
      .axi_arcache_o(axi_arcache_o), //Address read channel memory type. Set to 0000 if master output; ignored if slave input.
      .axi_arprot_o(axi_arprot_o), //Address read channel protection type. Set to 000 if master output; ignored if slave input.
      .axi_arqos_o(axi_arqos_o),  //Address read channel quality of service.
      .axi_arvalid_o(axi_arvalid_o),  //Address read channel valid.
      .axi_arready_i(axi_arready_i),  //Address read channel ready.
      .axi_rid_i(axi_rid_i),  //Read channel ID.
      .axi_rdata_i(axi_rdata_i),  //Read channel data.
      .axi_rresp_i(axi_rresp_i),  //Read channel response.
      .axi_rlast_i(axi_rlast_i),  //Read channel last word.
      .axi_rvalid_i(axi_rvalid_i),  //Read channel valid.
      .axi_rready_o(axi_rready_o),  //Read channel ready.

      // External memory interfaces
      .ext_mem_clk_o   (ext_mem_clk),
      .ext_mem_w_en_o  (ext_mem_w_en),
      .ext_mem_w_data_o(ext_mem_w_data),
      .ext_mem_w_addr_o(ext_mem_w_addr),
      .ext_mem_r_en_o  (ext_mem_r_en),
      .ext_mem_r_addr_o(ext_mem_r_addr),
      .ext_mem_r_data_i(ext_mem_r_data),

      // General signals interface
      .clk_i (clk_i),
      .cke_i (cke_i),
      .rst_i (SOFT_RESET_wr),
      .arst_i(arst_i)
   );

   iob_ram_2p #(
      .DATA_W(AXI_DATA_W),
      .ADDR_W(BUFFER_W)
   ) axis2axi_memory (
      .clk_i   (ext_mem_clk),
      .w_en_i  (ext_mem_w_en),
      .w_data_i(ext_mem_w_data),
      .w_addr_i(ext_mem_w_addr),
      .r_en_i  (ext_mem_r_en),
      .r_data_o(ext_mem_r_data),
      .r_addr_i(ext_mem_r_addr)
   );

endmodule
