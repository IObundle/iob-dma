`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "axi.vh"

`define ADDRESS_A 0
`define ADDRESS_B 1
`define LENGTH 2    // In bytes, 0 is not valid and will  
`define DIRECTION 3
`define RUN 4

`define STATUS 0

`define CONF_ADDR_W 1

`define READ  0
`define WRITE 1

`define A_TO_B 0
`define B_TO_A 1

// Native to native streaming 
module iob_dma 
   #(
      parameter ADDR_W = 0,
      parameter DATA_W = 0,
      parameter LEN_W = 0
   )(
      // Configuration Native Slave I/F
      input                   c_valid,
      input [ADDR_W-1:0]      c_addr,
      input [DATA_W-1:0]      c_wdata,
      input [DATA_W/8-1:0]    c_wstrb,
      output reg [DATA_W-1:0] c_rdata,
      output reg              c_ready,

      // Port A Master Native I/F
      output [ADDR_W-1:0]     a_addr,
      output                  a_valid,
      output [DATA_W-1:0]     a_wdata,
      output [DATA_W/8-1:0]   a_wstrb,
      input [DATA_W-1:0]      a_rdata,
      input                   a_ready,

      // Port B Master Native I/F
      output [ADDR_W-1:0]     b_addr,
      output                  b_valid,
      output [DATA_W-1:0]     b_wdata,
      output [DATA_W/8-1:0]   b_wstrb,
      input [DATA_W-1:0]      b_rdata,
      input                   b_ready,

      input                   clk,
      input                   rst
   );

   // Configuration state
   reg [ADDR_W-1:0] address_a,address_b;
   reg [LEN_W-1:0] length;
   reg direction;
   reg run;

   wire running;

   // Configuration
   always @(posedge clk,posedge rst)
   begin
      if(rst) begin
         address_a <= 0;
         address_b <= 0;
         length <= 0;
         direction <= 0;
         run <= 0;
         c_ready <= 0;
      end else begin
         run <= 0;
         c_ready <= c_valid;

         if(c_valid & |c_wstrb) begin
            case(c_addr)
               `ADDRESS_A: address_a <= c_wdata;
               `ADDRESS_B: address_b <= c_wdata;
               `LENGTH:    length    <= c_wdata;
               `DIRECTION: direction <= c_wdata;
               `RUN:       run       <= c_wdata;
            endcase
         end

         if(c_valid & !(|c_wstrb)) begin
            case(c_addr)
               `STATUS: c_rdata <= {31'h0,running};
            endcase
         end
      end
   end

   // Global state
   reg [2:0] state;
   reg [7:0] counter;

   localparam WAIT_RUN = 0,START = 1;

   wire last = (counter == 0);

   // Global
   always @(posedge clk,posedge rst)
   begin
      if(rst) begin
         state <= 0;
         counter <= 0;
      end else begin
         case(state)
            WAIT_RUN: begin
               if(run) begin
                  state <= START;
                  counter <= (length - 1) >> 2;
               end
            end
            START: begin
               if(read_ready & !last) begin
                  counter <= counter - 1;
               end

               if(last & !running) begin
                  state <= WAIT_RUN;
               end
            end
         endcase
      end 
   end

   wire a_to_b_valid_in;
   wire a_to_b_valid_out;
   wire b_to_a_valid_in;
   wire b_to_a_valid_out;

   wire running_a_to_b,running_b_to_a;

   assign running = (running_a_to_b | running_b_to_a);

   master_to_master
   #(
      .DATA_W(DATA_W),
      .ADDR_W(ADDR_W)
   )
   a_to_b
   (
      .valid_in(a_to_b_valid_in),
      .data_in(a_rdata),
      .ready_in(a_ready & (direction == `A_TO_B)),

      .valid_out(a_to_b_valid_out),
      .data_out(b_wdata),
      .ready_out(b_ready & (direction == `A_TO_B)),

      .start(run & (direction == `A_TO_B)),
      .last(last),

      .running(running_a_to_b),

      .clk(clk),
      .rst(rst)
   );

   master_to_master
   #(
      .DATA_W(DATA_W),
      .ADDR_W(ADDR_W)
   )
   b_to_a
   (
      .valid_in(b_to_a_valid_in),
      .data_in(b_rdata),
      .ready_in(b_ready & (direction == `B_TO_A)),

      .valid_out(b_to_a_valid_out),
      .data_out(a_wdata),
      .ready_out(a_ready & (direction == `B_TO_A)),

      .start(run & (direction == `B_TO_A)),
      .last(last),

      .running(running_b_to_a),

      .clk(clk),
      .rst(rst)
   );

   assign a_valid = ((direction == `A_TO_B) ? a_to_b_valid_in  : b_to_a_valid_out);
   assign b_valid = ((direction == `A_TO_B) ? a_to_b_valid_out : b_to_a_valid_in);

   wire read_valid = ((direction == `A_TO_B) ? a_valid : b_valid);
   wire read_ready = ((direction == `A_TO_B) ? a_ready : b_ready);

   wire write_valid = ((direction == `A_TO_B) ? b_valid : a_valid);
   wire write_ready = ((direction == `A_TO_B) ? b_ready : a_ready);

   wire [ADDR_W-1:0] read_addr;
   wire [ADDR_W-1:0] write_addr;
   wire [DATA_W/8-1:0] write_wstrb;

   wire [ADDR_W-1:0] read_addr_start = ((direction == `A_TO_B) ? address_a : address_b);
   wire [ADDR_W-1:0] write_addr_start = ((direction == `A_TO_B) ? address_b : address_a);

   master_to_master_address_strobe_gen
      #(
         .DATA_W(DATA_W),
         .ADDR_W(ADDR_W)
      )
      address_gen
      (
         .read_addr_start(read_addr_start),
         .write_addr_start(write_addr_start),

         .read_valid(read_valid),
         .read_ready(read_ready),
         .read_addr(read_addr),

         .write_valid(write_valid),
         .write_ready(write_ready),
         .write_addr(write_addr),
         .write_wstrb(write_wstrb),

         .start(run),

         .clk(clk),
         .rst(rst)
      );

   assign a_addr = ((direction == `A_TO_B) ? read_addr : write_addr);
   assign b_addr = ((direction == `A_TO_B) ? write_addr : read_addr);

   assign a_wstrb = ((direction == `A_TO_B) ? 4'h0 : write_wstrb);
   assign b_wstrb = ((direction == `A_TO_B) ? write_wstrb : 4'h0);

endmodule

module master_to_master
   #(
     parameter DATA_W = 0,
     parameter ADDR_W = 0
   )
   (
      input [DATA_W-1:0]        data_in,
      output reg                valid_in,
      input                     ready_in,

      output reg [DATA_W-1:0]   data_out,
      output reg                valid_out,
      input                     ready_out,

      input                     start,
      input                     last,

      output                    running,

      input                     clk,
      input                     rst
   );

   reg [31:0] data;
   reg data_valid;

   reg [31:0] stored_data;
   reg stored_data_valid;

   reg runningRead;
   reg runningWrite;

   assign running = (runningRead | runningWrite);

   always @(posedge clk,posedge rst)
   begin
      if(rst) begin
         data <= 0;
         data_valid <= 0;
         stored_data <= 0;
         stored_data_valid <= 0;

         runningRead <= 0;
         runningWrite <= 0;
      end else begin
         if(start) begin
            runningRead <= 1'b1;
            runningWrite <= 1'b1;
         end

         // Data valid set
         if(ready_in & ready_out & !stored_data_valid) begin
            data <= data_in;
            data_valid <= 1'b1;
         end
         if(ready_in & !stored_data_valid & !data_valid) begin
            data <= data_in;
            data_valid <= 1'b1;
         end

         // Data valid set from stored
         if(stored_data_valid & data_valid & ready_out) begin
            data <= stored_data;
            data_valid <= 1'b1;
         end

         // Data stored set
         if(stored_data_valid & data_valid & ready_in) begin
            stored_data <= data_in;
            stored_data_valid <= 1'b1;
         end
         if(data_valid & ready_in & !ready_out) begin
            stored_data <= data_in;
            stored_data_valid <= 1'b1;                
         end

         // Data valid unset
         if(data_valid & !ready_in & ready_out & !stored_data_valid)
            data_valid <= 1'b0;

         // Data stored unset
         if(stored_data_valid & data_valid & !ready_in & ready_out)
            stored_data_valid <= 1'b0;

         if(runningRead) begin
            if(ready_in & last)
               runningRead <= 1'b0;
         end

         if(runningWrite) begin
            if(!runningRead & !data_valid & !stored_data_valid)
               runningWrite <= 1'b0;
         end
      end
   end

   always @*
   begin
      valid_in = 1'b0;
      valid_out = 1'b0;
      data_out = data; // Default data out (most likely to occur)

      // Valid in
      if(runningRead) begin
         if(!stored_data_valid & !data_valid)
            valid_in = 1'b1;
         if(ready_out)
            valid_in = 1'b1;
         if(!ready_in & !stored_data_valid)
            valid_in = 1'b1;

         if(ready_in & last)
            valid_in = 1'b0;

      end else begin
         valid_in = 1'b0;
      end

      if(runningWrite) begin
         if(ready_in & ready_out & !stored_data_valid)
            data_out = data_in;
         if(ready_in & !stored_data_valid & !data_valid)
            data_out = data_in;

         if(stored_data_valid & data_valid & !ready_in & ready_out)
            data_out = stored_data;

         if(ready_in)
            valid_out = 1'b1;
         if(stored_data_valid)
            valid_out = 1'b1;
         if(data_valid & !ready_out)
            valid_out = 1'b1;
      end else begin
         valid_out = 1'b0;
      end
   end

endmodule

module master_to_master_address_strobe_gen
   #( 
      parameter DATA_W = 0,
      parameter ADDR_W = 0
   )
   (
      input [ADDR_W-1:0]          read_addr_start,
      input [ADDR_W-1:0]          write_addr_start,

      input                       read_valid,
      input                       read_ready,
      output reg [ADDR_W-1:0]     read_addr,

      input                       write_valid,
      input                       write_ready,
      output reg [ADDR_W-1:0]     write_addr,
      output reg [DATA_W/8-1:0]   write_wstrb,

      input                       start,

      input                       clk,
      input                       rst
   );

   reg [ADDR_W-1:0] read_addr_reg,write_addr_reg;

   always @(posedge clk,posedge rst)
   begin
      if(rst) begin
         read_addr_reg <= 0;
         write_addr_reg <= 0;
      end else begin
         if(start) begin
            read_addr_reg <= read_addr_start;
            write_addr_reg <= write_addr_start;
         end

         if(read_ready)
            read_addr_reg <= read_addr_reg + 4;

         if(write_ready)
            write_addr_reg <= write_addr_reg + 4;
      end
   end

   always @*
   begin
      read_addr = read_addr_reg;
      write_addr = write_addr_reg;

      write_wstrb = 4'hf;

      if(read_ready)
         read_addr = read_addr_reg + 4;

      if(write_ready)
         write_addr = write_addr_reg + 4;
   end

endmodule
