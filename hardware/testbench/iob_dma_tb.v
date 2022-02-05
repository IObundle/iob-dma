`timescale 1ns / 1ps

`include "axi.vh"

module iob_dma_tb;

   parameter ADDR_W = 24;
   parameter DATA_W = 32;

   parameter AXI_ADDR_W = ADDR_W;
   parameter AXI_DATA_W = DATA_W;

   `define CLK_PER 1000

   // Clock
   reg clk = 1;
   always #(`CLK_PER/2) clk = ~clk;

   // Reset
   reg rst = 0;

   //
   // DMA interface
   //

   // Configuration Native I/F
   reg                  c_valid;
   reg [ADDR_W-1:0]     c_addr;
   reg [DATA_W-1:0]     c_wdata;
   reg [DATA_W/8-1:0]   c_wstrb;
   wire [DATA_W-1:0]    c_rdata;
   wire                 c_ready;

   // A Master I/F
   wire                 a_valid;
   wire [ADDR_W-1:0]    a_addr;
   wire [DATA_W-1:0]    a_wdata;
   wire [DATA_W/8-1:0]  a_wstrb;
   wire [DATA_W-1:0]    a_rdata;
   wire                 a_ready;

   // B Master I/F
   wire                 b_valid;
   wire [ADDR_W-1:0]    b_addr;
   wire [DATA_W-1:0]    b_wdata;
   wire [DATA_W/8-1:0]  b_wstrb;
   wire [DATA_W-1:0]    b_rdata;
   wire                 b_ready;

simple_ram 
   #(
      .DATA_W(DATA_W),
      .ADDR_W(ADDR_W)
   )
   ram_A
   (
      .valid(a_valid),
      .addr(a_addr),
      .wdata(a_wdata),
      .wstrb(a_wstrb),
      .rdata(a_rdata),
      .ready(a_ready),

      .fixed_delay(0),

      .clk(clk),
      .rst(rst)
   );

simple_ram 
   #(
      .DATA_W(DATA_W),
      .ADDR_W(ADDR_W)
   )
   ram_B
   (
      .valid(b_valid),
      .addr(b_addr),
      .wdata(b_wdata),
      .wstrb(b_wstrb),
      .rdata(b_rdata),
      .ready(b_ready),

      .fixed_delay(0),

      .clk(clk),
      .rst(rst)
   );

wire [31:0] fifo_ocupancy;
wire write_full,write_empty;
wire [31:0] wr_data;
reg [31:0] in_rdata;
reg in_ready;

wire [31:0] f_data;
reg f_ready;
wire f_valid;
wire wr_read_en;

reg [31:0] dma_status;

reg direction;
integer i;
   initial begin

`ifdef VCD
      $dumpfile("uut.vcd");
      $dumpvars();
`endif

      // Initial values

      c_valid = 0;
      c_addr = 0;
      c_wdata = 0;
      c_wstrb = 0;

      in_rdata = 0;
      in_ready = 0;

      f_ready = 0;

      rst = 1;

      @(posedge clk) #1;

      rst = 0;

      for(i = 0; i < 10; i = i + 1) begin
         ram_A.mem[i] = (i + 1);
         ram_B.mem[i] = (10 - i);
      end

      $display("A\tB\n");
      for(i = 0; i < 10; i = i +1) begin
         $display("%0d\t%0d\n",ram_A.mem[i],ram_B.mem[i]);
      end

      repeat(10) @(posedge clk) #1;

`define A_TO_B 0
`define B_TO_A 1

      direction = `A_TO_B;

      set_c_value(0,0); // Address
      set_c_value(2,10 * 4); // Bytes length
      set_c_value(3,direction); // Write
      set_c_value(4,1); // Run

      dma_status = 1;
      while(dma_status[0]) begin
         get_c_value(0,dma_status);
         @(posedge clk) #1;
      end

      repeat (5) @(posedge clk) #1;

      $display("============================\n");

      if(direction)
         $display("A <- B\n");
      else
         $display("A -> B\n");

      $display("A\tB\n");
      for(i = 0; i < 10; i = i +1) begin
         $display("%0d\t%0d\n",ram_A.mem[i],ram_B.mem[i]);
      end

      $finish;
   end

   task set_c_value(input [31:0] address,value);
      begin
         c_valid = 1;
         c_addr = address;
         c_wdata = value;
         c_wstrb = 4'hf;

         while(!c_ready)
            @(posedge clk) #1;

         c_valid = 0;
         c_addr = 0;
         c_wdata = 0;
         c_wstrb = 0;

         @(posedge clk) #1;         
      end
   endtask 

   task get_c_value(input [31:0] address, output [31:0] value);
      begin
         c_valid = 1;
         c_addr = address;
         c_wstrb = 4'h0;

         while(!c_ready)
            @(posedge clk) #1;

         c_valid = 0;
         c_addr = 0;
         c_wdata = 0;
         c_wstrb = 0;

         value = c_rdata;      
      end
   endtask 

   iob_dma
     #(
       .ADDR_W(ADDR_W),
       .DATA_W(DATA_W),
       .LEN_W(8)
       )
   uut
     (
      .clk      (clk),
      .rst      (rst),

      // Configuration Native I/F
      .c_valid(c_valid),
      .c_addr(c_addr),
      .c_wdata(c_wdata),
      .c_wstrb(c_wstrb),
      .c_rdata(c_rdata),
      .c_ready(c_ready),

      // Port A
      .a_valid(a_valid),
      .a_addr(a_addr),
      .a_wdata(a_wdata),
      .a_wstrb(a_wstrb),
      .a_rdata(a_rdata),
      .a_ready(a_ready),

      // Port B
      .b_valid(b_valid),
      .b_addr(b_addr),
      .b_wdata(b_wdata),
      .b_wstrb(b_wstrb),
      .b_rdata(b_rdata),
      .b_ready(b_ready)
      );

endmodule

module simple_ram
   #(
      parameter ADDR_W = 0,
      parameter DATA_W = 0
   )
   (
      input                   valid,
      input [ADDR_W-1:0]      addr,
      input [DATA_W-1:0]      wdata,
      input [DATA_W/8-1:0]    wstrb,
      output reg [DATA_W-1:0] rdata,
      output reg              ready,

      input [1:0]             fixed_delay,

      input                   clk,
      input                   rst
   );

reg [31:0] mem [1023:0];
reg [3:0] counter;

reg seenRequest;

reg [2:0] currentDelay;

always @(posedge clk)
begin
   currentDelay = (fixed_delay + ($urandom % 2));
end

integer i;
always @(posedge clk,posedge rst)
begin
   if(rst) begin
      for(i = 0; i < 1024; i = i + 1)
         mem[i] <= 32'h0;
      rdata <= 0;
      counter <= 0;
      seenRequest <= 0;
   end else begin
      if(valid) begin
         if(|wstrb)
            mem[addr >> 2] <= wdata;
         else
            rdata <= mem[addr >> 2];

         if(!seenRequest) begin
            counter <= currentDelay;
            seenRequest <= 1'b1;
         end
      end

      if(seenRequest)
         if(counter != 0)
            counter <= counter - 1;
         else begin
            seenRequest <= 1'b0;
         end
   end
end

always @*
begin
   ready = 0;
   if(seenRequest & counter == 0)
      ready = 1;
end

endmodule

/*
module fifo_to_master
   #(
      parameter DATA_W = 0
   )
   (
      input [DATA_W-1:0]  data_in,

      output [DATA_W-1:0] data_out,
      output              valid,
      input               ready,

      output              fifo_enable_rd,
      input               fifo_empty,

      input               start,

      input               clk,
      input               rst
      );

wire master_valid;
reg ready_fifo;

assign fifo_enable_rd = (master_valid & !fifo_empty);

always @(posedge clk,posedge rst)
begin
   if(rst)
      ready_fifo <= 1'b0;
   else
      ready_fifo <= fifo_enable_rd; // Fifo always takes one cycle to produce valid data
end

   master_to_master
   #(
      .DATA_W(DATA_W)
   )
   master
   (
      .data_in(data_in),
      .valid_in(master_valid),
      .ready_in(ready_fifo),

      .data_out(data_out),
      .valid_out(valid),
      .ready_out(ready),

      .start(start),
      .last(1'b0),

      .clk(clk),
      .rst(rst)
   );

endmodule

iob_sync_fifo
  #(
    .ADDRESS_WIDTH(4),
    .DATA_WIDTH(32)
    )
  write_buffer
    (
    .rst(rst),
    .clk(clk),
   
    .fifo_ocupancy(fifo_ocupancy), 

    //write port     
    .w_data(in_rdata), 
    .full(write_full),
    .write_en(in_ready),

    //read port
    .r_data(wr_data),
    .empty(write_empty),
    .read_en(wr_read_en)
    );

fifo_to_master 
   #(
      .DATA_W(DATA_W)
   )
   fifo_master
   (
      .data_in(wr_data),

      .data_out(f_data),
      .valid(f_valid),
      .ready(f_ready),

      .fifo_enable_rd(wr_read_en),
      .fifo_empty(write_empty),

      .clk(clk),
      .rst(rst)
   );
*/