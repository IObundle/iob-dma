`timescale 1ns / 1ps

`include "iob_dma_conf.vh"
`include "iob_dma_swreg_def.vh"

module iob_dma #(
   `include "iob_dma_params.vs"
) (
   `include "iob_dma_io.vs"
);

   //BLOCK Register File & Configuration control and status register file.
   `include "iob_dma_swreg_inst.vs"

   // External memory interfaces
   wire                  write_fifo_mem_clk;
   wire                  write_fifo_mem_w_en;
   wire [ AXI_LEN_W-1:0] write_fifo_mem_w_addr;
   wire [AXI_DATA_W-1:0] write_fifo_mem_w_data;
   wire                  write_fifo_mem_r_en;
   wire [ AXI_LEN_W-1:0] write_fifo_mem_r_addr;
   wire [AXI_DATA_W-1:0] write_fifo_mem_r_data;

   wire                  read_fifo_mem_clk;
   wire                  read_fifo_mem_w_en;
   wire [ AXI_LEN_W-1:0] read_fifo_mem_w_addr;
   wire [AXI_DATA_W-1:0] read_fifo_mem_w_data;
   wire                  read_fifo_mem_r_en;
   wire [ AXI_LEN_W-1:0] read_fifo_mem_r_addr;
   wire [AXI_DATA_W-1:0] read_fifo_mem_r_data;

   wire                  dst_busy;
   wire                  src_busy;
   wire [LENGTH_W-1:0]   dst_buf_level;

   wire [AXI_DATA_W-1:0] dma_data;
   wire                  dma_valid;
   wire                  dma_ready;

   assign soft_reset_ready_wr = 1'b1;
   assign start_ready_wr      = 1'b1;
   assign busy_rd             = src_busy | dst_busy;

   iob_axi_m #(
      .AXI_ADDR_W(AXI_ADDR_W),
      .AXI_LEN_W (AXI_LEN_W),
      .AXI_DATA_W(AXI_DATA_W),
      .AXI_ID_W  (AXI_ID_W),
      .WLENGTH_W(LENGTH_W),
      .RLENGTH_W(LENGTH_W)
   ) axi_m_inst (
      `include "clk_en_rst_s_s_portmap.vs"
      .rst_i(soft_reset_wen_wr),

      // AXI manager destination path
      .w_addr_i          (dst_addr_wr),
      .w_length_i        (length_wr),
      .w_start_transfer_i(start_wen_wr),
      .w_max_len_i       (burstlen_wr),
      .w_burst_type_i    (dst_burst_type_wr),
      .w_remaining_data_o(buf_level_rd),
      .w_busy_o          (dst_busy),

      // AXI manager source path
      .r_addr_i          (src_addr_wr),
      .r_length_i        (length_wr),
      .r_start_transfer_i(start_wen_wr),
      .r_max_len_i       (burstlen_wr),
      .r_burst_type_i    (src_burst_type_wr),
      .r_remaining_data_o(),
      .r_busy_o          (src_busy),

      // Internal data path: source read stream to destination write stream
      .axis_in_data_i (dma_data),
      .axis_in_valid_i(dma_valid),
      .axis_in_ready_o(dma_ready),

      .axis_out_data_o (dma_data),
      .axis_out_valid_o(dma_valid),
      .axis_out_ready_i(dma_ready),

      .w_ext_mem_clk_o   (write_fifo_mem_clk),
      .w_ext_mem_w_en_o  (write_fifo_mem_w_en),
      .w_ext_mem_w_addr_o(write_fifo_mem_w_addr),
      .w_ext_mem_w_data_o(write_fifo_mem_w_data),
      .w_ext_mem_r_en_o  (write_fifo_mem_r_en),
      .w_ext_mem_r_addr_o(write_fifo_mem_r_addr),
      .w_ext_mem_r_data_i(write_fifo_mem_r_data),

      .r_ext_mem_clk_o   (read_fifo_mem_clk),
      .r_ext_mem_w_en_o  (read_fifo_mem_w_en),
      .r_ext_mem_w_addr_o(read_fifo_mem_w_addr),
      .r_ext_mem_w_data_o(read_fifo_mem_w_data),
      .r_ext_mem_r_en_o  (read_fifo_mem_r_en),
      .r_ext_mem_r_addr_o(read_fifo_mem_r_addr),
      .r_ext_mem_r_data_i(read_fifo_mem_r_data),

      `include "axi_m_m_portmap.vs"
   );

   iob_ram_2p #(
      .DATA_W(AXI_DATA_W),
      .ADDR_W(AXI_LEN_W)
   ) w_ext_memory (
      .clk_i   (write_fifo_mem_clk),
      .w_en_i  (write_fifo_mem_w_en),
      .w_data_i(write_fifo_mem_w_data),
      .w_addr_i(write_fifo_mem_w_addr),
      .r_en_i  (write_fifo_mem_r_en),
      .r_data_o(write_fifo_mem_r_data),
      .r_addr_i(write_fifo_mem_r_addr)
   );

   iob_ram_2p #(
      .DATA_W(AXI_DATA_W),
      .ADDR_W(AXI_LEN_W)
   ) r_ext_memory (
      .clk_i   (read_fifo_mem_clk),
      .w_en_i  (read_fifo_mem_w_en),
      .w_data_i(read_fifo_mem_w_data),
      .w_addr_i(read_fifo_mem_w_addr),
      .r_en_i  (read_fifo_mem_r_en),
      .r_data_o(read_fifo_mem_r_data),
      .r_addr_i(read_fifo_mem_r_addr)
   );

endmodule
