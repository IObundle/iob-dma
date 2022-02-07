`timescale 1ns / 1ps

`include "axi.vh"

module iob_dma_tb;

parameter ADDR_W = 24;
parameter DATA_W = 32;

parameter AXI_ADDR_W = ADDR_W;
parameter AXI_DATA_W = DATA_W;

`define CLK_PER 1000

`define A_TO_B 0
`define B_TO_A 1

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

reg [2:0] fixed_A_delay;
reg [2:0] fixed_B_delay;
reg use_random_A_delay;
reg use_random_B_delay;

reg [2:0] ram_A_delay;
reg [2:0] ram_B_delay;

always @(posedge clk,posedge rst)
begin
   if(rst) begin
      ram_A_delay <= 0;
      ram_B_delay <= 0;
   end else begin
      ram_A_delay <= fixed_A_delay + (use_random_A_delay ? ($urandom % 3) : 0);
      ram_B_delay <= fixed_B_delay + (use_random_B_delay ? ($urandom % 3) : 0);
   end
end

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

      .variable_delay(ram_A_delay),

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

      .variable_delay(ram_B_delay),

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

reg direction;
integer i;

reg [31:0] tests_made;
integer v1,v2,v3,v4,v5,v6,v7,v8;
   
   initial begin
`ifdef VCD
      $dumpfile("uut.vcd");
      $dumpvars();
`endif

      $display("\n");

      // Initial values
      set_randomness(0,0,0,0);

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

      repeat(10) @(posedge clk) #1;

      tests_made = 0;
      if(1) begin // Automatic tests, set to 1 to enable
      for(v1 = 0; v1 < 2; v1 = v1 + 1)
       for(v2 = 0; v2 < 2; v2 = v2 + 1)
        for(v3 = 0; v3 < 2; v3 = v3 + 1)
         for(v4 = 0; v4 < 2; v4 = v4 + 1)
          for(v5 = 0; v5 < 2; v5 = v5 + 1)
           for(v6 = 0; v6 < 2; v6 = v6 + 1)
            for(v7 = 0; v7 < 2; v7 = v7 + 1)
             test_run_no_display(v1 * 10,v2 * 10,20,v3,v4,v5,v6,v7);
      end

      if(0) begin // Manual tests, set to 1 to enable
         test_run(0,0,20,`A_TO_B,0,0,0,0);
      end

      $display("%0d tests completed\n",tests_made);

      repeat (10) @(posedge clk) #1;

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

   task set_randomness(input [2:0] A_fixed_delay,B_fixed_delay,A_random_delay,B_random_delay);
      begin
         fixed_A_delay = A_fixed_delay;
         fixed_B_delay = B_fixed_delay;
         use_random_A_delay = (A_random_delay ? 1'b1 : 1'b0);
         use_random_B_delay = (B_random_delay ? 1'b1 : 1'b0);

         @(posedge clk) #1;
      end
   endtask

   task test_init_memory(input [31:0] a_addr,b_addr,n_values,direction);
      begin
         // Clear memory 
         for(i = 0; i < n_values; i = i + 1) begin
            ram_A.mem[a_addr + i + 1] = 0;
            ram_B.mem[b_addr + i + 1] = 0;
            
            if(direction == `A_TO_B)
               ram_A.mem[a_addr + i + 1] = i + 1;

            if(direction == `B_TO_A)
               ram_B.mem[b_addr + i + 1] = i + 1;
         end

         // Add a canary value to check that only the values we want are transferred
         ram_A.mem[a_addr] = (direction == `A_TO_B ? 8'hde : 0);
         ram_A.mem[a_addr + n_values + 1] = (direction == `A_TO_B ? 8'had : 0);
         ram_B.mem[b_addr] = (direction == `A_TO_B ? 0 : 8'hde);
         ram_B.mem[b_addr + n_values + 1] = (direction == `A_TO_B ? 0 : 8'had);
      end
   endtask

   task test_execute(input [31:0] a_addr,b_addr,n_values,direction);
      reg [31:0] dma_status;
      begin
         tests_made = tests_made + 1;

         set_c_value(0,(a_addr + 1) * 4); // Address A (plus 1 due to canary value)
         set_c_value(1,(b_addr + 1) * 4); // Address B (plus 1 due to canary value)
         set_c_value(2,n_values * 4); // Bytes length
         set_c_value(3,direction); // Write
         set_c_value(4,1); // Run

         get_c_value(0,dma_status);
         while(dma_status[0]) begin
            get_c_value(0,dma_status);
            @(posedge clk) #1;
         end
      end
   endtask

   task test_check_error(input [31:0] a_addr,b_addr,n_values,direction,A_fixed_delay,B_fixed_delay,A_random_delay,B_random_delay);
      string directionString;
      begin         
         if(direction == `A_TO_B)
            directionString = "`A_TO_B";
         else 
            directionString = "`B_TO_A";

         for(i = 0; i < n_values; i = i + 1) begin
            if(ram_A.mem[a_addr + i + 1] != ram_B.mem[b_addr + i + 1]) begin
               $display("Error on test %0d,%0d,%0d,%s,%0d,%0d,%0d,%0d index: %0d, value expected: %0d, value got: %0d",a_addr,b_addr,n_values,directionString,A_fixed_delay,B_fixed_delay,A_random_delay,B_random_delay,i,i + 1,(direction == `A_TO_B ? ram_B.mem[i + 1] : ram_A.mem[i + 1]));
            end
         end
      end
   endtask

   task test_run_no_display(input [31:0] a_addr,b_addr,n_values,direction,A_fixed_delay,B_fixed_delay,A_random_delay,B_random_delay);
      begin
         set_randomness(A_fixed_delay,B_fixed_delay,A_random_delay,B_random_delay);
         test_init_memory(a_addr,b_addr,n_values,direction);
         test_execute(a_addr,b_addr,n_values,direction);
         test_check_error(a_addr,b_addr,n_values,direction,A_fixed_delay,B_fixed_delay,A_random_delay,B_random_delay);
      end
   endtask

   task test_run(input [31:0] a_addr,b_addr,n_values,direction,A_fixed_delay,B_fixed_delay,A_random_delay,B_random_delay);
      begin
         set_randomness(A_fixed_delay,B_fixed_delay,A_random_delay,B_random_delay);

         test_init_memory(a_addr,b_addr,n_values,direction);

         if(direction)
            $display("A  <-\tB\n");
         else
            $display("A  ->\tB\n");

         for(i = 0; i < n_values + 2; i = i +1) begin
            $display("%0x\t%0x\n",ram_A.mem[i],ram_B.mem[i]);
         end

         test_execute(a_addr,b_addr,n_values,direction);

         $display("============================\n");

         if(direction)
            $display("A  <-\tB\n");
         else
            $display("A  ->\tB\n");

         for(i = 0; i < n_values + 2; i = i +1) begin
            $display("%0x\t%0x\n",ram_A.mem[i],ram_B.mem[i]);
         end

         test_check_error(a_addr,b_addr,n_values,direction,A_fixed_delay,B_fixed_delay,A_random_delay,B_random_delay);
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

      input [2:0]             variable_delay,

      input                   clk,
      input                   rst
   );

reg [31:0] mem [1023:0];
reg [2:0] counter;

reg seenRequest;

integer i;
always @(posedge clk,posedge rst)
begin
   if(rst) begin
      for(i = 0; i < 1024; i = i + 1)
         mem[i] <= 32'h0;
      rdata <= 0;
      counter <= 1;
      seenRequest <= 0;
   end else begin
      if(valid) begin
         if(|wstrb)
            mem[addr >> 2] <= wdata;
         else
            rdata <= mem[addr >> 2];
         if(counter == 0)
            counter <= variable_delay;
         else
            counter <= counter - 1;
      end else begin
         counter <= 1;
      end
   end
end

always @*
begin
   ready = 0;
   if(counter == 0)
      ready = 1;
end

endmodule
