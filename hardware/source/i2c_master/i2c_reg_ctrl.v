//-------------------------------------------------------------------------
//  >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
//-------------------------------------------------------------------------
//  Copyright (c) 2012 by Lattice Semiconductor Corporation      
// 
//-------------------------------------------------------------------------
// Permission:
//
//   Lattice Semiconductor grants permission to use this code for use
//   in synthesis for any Lattice programmable logic product.  Other
//   use of this code, including the selling or duplication of any
//   portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL or Verilog source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Lattice Semiconductor provides no warranty
//   regarding the use or functionality of this code.
//-------------------------------------------------------------------------
//
//    Lattice Semiconductor Corporation
//    5555 NE Moore Court
//    Hillsboro, OR 97124
//    U.S.A
//
//    TEL: 1-800-Lattice (USA and Canada)
//    503-268-8001 (other locations)
//
//    web: http://www.latticesemi.com/
//    email: techsupport@latticesemi.com
// 
//-------------------------------------------------------------------------
// 
//  Project  : LP3.5K_Pedometer_with_BLE_Interface
//  File Name: i2c_reg_ctrl.v
// 
//  Description: This module translates I2C slave register write/read into
//  I2C complaint format. For example register write command to the module
//  would initiate an I2C write command with 2 bytes of data- register 
//  address and the data to be written to that address.
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date    |Changes Made:
// V1.0 | MDN           | 03-Nov-12    |Initial version                             
//-------------------------------------------------------------------------

module	i2c_reg_ctrl ( 
		       // Global inputs
		       i_sys_clk, i_sys_rst, i_i2c_hardip_clk,                      
		       /*AUTOARG*/
		       // Outputs
		       o_read_data, o_read_data_valid, o_i2c_done, o_scl_oe_n, o_sda_oe_n,
		       // Inputs
		       i_i2c_start, i_read_write_n, i_slave_addr, i_read_byte_count, i_reg_address,
		       i_write_data, i_scl, i_sda
		       );

   // Parameters
   parameter CLK_DIV_COUNT = 72; // For clk = 25MHz, div count of 64 gives 390kHz

   parameter I2C_SLAVE_INIT_ADDR = "0b1111100001"; // I2C slave initialization address
   parameter BUS_ADDR74_STRING = "0b0001";  // I2C hardIP address upper 4 bits
   parameter BUS_ADDR74 = 8'b0001_0000; // I2C hard IP address

   // FSM states  
   parameter IDLE = 0;
   parameter SEND_I2C_READ_ADDRESS = 1;
   parameter WAIT_FOR_READ_BYTES = 2;
   parameter SEND_I2C_WRITE_ADDRESS = 3;
   parameter SEND_REG_WRITE_DATA = 4;
   
   // Global inputs  
   input	i_sys_clk;
   input	i_sys_rst;

   input 	i_i2c_hardip_clk;

   // Outputs
   output [7:0] o_read_data;
   output       o_read_data_valid;
   output reg   o_i2c_done;
   output       o_scl_oe_n;
   output       o_sda_oe_n;

   // Inputs  
   input        i_i2c_start;
   input        i_read_write_n;
   input [7:0] 	i_slave_addr;
   input [7:0] 	i_read_byte_count;
   input [7:0] 	i_reg_address;
   input [7:0] 	i_write_data;
   input        i_scl;
   input        i_sda;

   // Internal signals
   reg [4:0] 	i2c_state_i;
   reg [7:0] 	byte_cnt_i;
   reg          start_reg_i;
   reg          rw_mode_i;
   reg [7:0] 	txfifo_rddata_i;
   wire         start_ack_i;
   wire         tx_done_i;
   wire         rx_done_i;
   wire         txfifo_rden_i;
   reg          d1_txfifo_rden_i;
   wire         txfifo_rden_pulse_i;
   wire         i2c_busy_i;

   wire         read_data_valid_i;
   reg          d1_read_data_valid_i;
   
   /*
    * State machine to control i2c read/write
    */

   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         i2c_state_i <= IDLE;
      end else begin
         case (i2c_state_i)
           IDLE:begin
              if(i_i2c_start)begin
                 if(i_read_write_n)begin
                    i2c_state_i <= SEND_I2C_READ_ADDRESS;
                 end else begin
                    i2c_state_i <= SEND_I2C_WRITE_ADDRESS;
                 end
              end
           end

           SEND_I2C_READ_ADDRESS:begin
              if(tx_done_i)begin // For repeated start
                 i2c_state_i <= WAIT_FOR_READ_BYTES;
              end
           end

           WAIT_FOR_READ_BYTES:begin
              if(~i2c_busy_i)begin
                 i2c_state_i <= IDLE;
              end
           end

           SEND_I2C_WRITE_ADDRESS:begin
              if(txfifo_rden_pulse_i)begin
                 i2c_state_i <= SEND_REG_WRITE_DATA;
              end
           end

           SEND_REG_WRITE_DATA: begin
              if(~i2c_busy_i)begin
                 i2c_state_i <= IDLE;
              end
           end
         endcase
      end
   end

   // i2c_done
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         o_i2c_done <= IDLE;
      end else begin
         case (i2c_state_i)
           IDLE: begin
              o_i2c_done <= 0;
           end

           WAIT_FOR_READ_BYTES:begin
              if(~i2c_busy_i)begin
                 o_i2c_done <= 1;
              end
           end

           SEND_REG_WRITE_DATA: begin
              if(~i2c_busy_i)begin
                 o_i2c_done <= 1;
              end
           end
         endcase
      end
   end
   
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         start_reg_i <= 0;
      end else begin
         case (i2c_state_i)
           IDLE: begin
              start_reg_i <= 0;                    
              if(i_i2c_start)begin
                 start_reg_i <= 1;
              end
           end

           WAIT_FOR_READ_BYTES:begin
              if(start_ack_i)begin
                 start_reg_i <= 0;
              end
           end

           SEND_I2C_WRITE_ADDRESS:begin
              if(start_ack_i)begin
                 start_reg_i <= 0;
              end
           end
         endcase
      end
   end

   // Byte count
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         byte_cnt_i <= 0;
      end else begin
         case (i2c_state_i)
           IDLE: begin
              if(i_i2c_start)begin
                 if(i_read_write_n)begin
                    byte_cnt_i <= 1;
                 end else begin
                    byte_cnt_i <= 2;
                 end
              end
           end

           SEND_I2C_READ_ADDRESS:begin
              if(tx_done_i)begin
                 byte_cnt_i <= i_read_byte_count;
              end
           end
         endcase
      end
   end

   
   // rw mode
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         rw_mode_i <= 0;
      end else begin
         case (i2c_state_i)
           IDLE: begin
              if(i_i2c_start)begin
                 rw_mode_i <= 0;
              end
           end

           SEND_I2C_READ_ADDRESS:begin
              if(tx_done_i)begin
                 rw_mode_i <= 1;
              end
           end

           WAIT_FOR_READ_BYTES:begin
              if(rx_done_i)begin
                 rw_mode_i <= 0;
              end
           end
         endcase
      end
   end


   //txfifo_rddata
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         txfifo_rddata_i <= 0;
      end else begin
         case (i2c_state_i)
           IDLE: begin
              txfifo_rddata_i <= i_reg_address;
           end

           SEND_REG_WRITE_DATA: begin
              if(txfifo_rden_pulse_i)begin
                 txfifo_rddata_i <= i_write_data;
              end
           end
         endcase
      end
   end


   //read_data_valid is rising pulse of read_data_valid from the i2c_master
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         d1_read_data_valid_i <= 0;
      end else begin
         d1_read_data_valid_i <= read_data_valid_i;
      end
   end

   assign o_read_data_valid = read_data_valid_i & ~ d1_read_data_valid_i;


   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         d1_txfifo_rden_i <= 0;
      end else begin
         d1_txfifo_rden_i <= txfifo_rden_i;
      end
   end

   assign txfifo_rden_pulse_i = txfifo_rden_i & ~ d1_txfifo_rden_i;
   
   //Instantiation of I2C Master control FSM
   I2C_master_top u_I2C_master_top (/*-AUTOINST-*/
                                    // Global inputs
                                    .i_sys_clk                         (i_i2c_hardip_clk), //Slower clock than i_sys_clk
                                    .i_sys_rst                         (i_sys_rst),                             
                                    // Outputs
                                    .o_scl_oe_n                        (o_scl_oe_n),
                                    .o_sda_oe_n                        (o_sda_oe_n),
                                    .o_start_ack                       (start_ack_i),
                                    .o_i2c_busy                        (i2c_busy_i),
                                    .o_tx_done                         (tx_done_i),
                                    .o_rx_done                         (rx_done_i),
                                    .o_rxfifo_wrdata                   (o_read_data[7:0]),
                                    .o_rxfifo_wren                     (read_data_valid_i),
                                    .o_txfifo_rden                     (txfifo_rden_i),
                                    // Inputs
                                    .i_scl                             (i_scl),
                                    .i_sda                             (i_sda),
                                    .i_scl_divcnt                      (CLK_DIV_COUNT[10:0]),
                                    .i_byte_cnt                        (byte_cnt_i[7:0]),
                                    .i_start_reg                       (start_reg_i),
                                    .i_abort_reg                       (1'b0),// Not used
                                    .i_adr_mode                        (1'b0), // tied to 7 bit address mode
                                    .i_rw_mode                         (rw_mode_i),
                                    .i_ack_mode                        (1'b0), // tied
                                    .i_slave_addr                      ({2'b00, i_slave_addr[7:0]}),
                                    .i_txfifo_rddata                   (txfifo_rddata_i[7:0]));

   defparam u_I2C_master_top.I2C_SLAVE_INIT_ADDR = I2C_SLAVE_INIT_ADDR;
   defparam u_I2C_master_top.BUS_ADDR74_STRING = BUS_ADDR74_STRING;
   defparam u_I2C_master_top.BUS_ADDR74 = BUS_ADDR74;

endmodule //i2c_reg_ctrl

// Local Variables:
// verilog-library-directories:("." "../i2c_master/" "../spi_master/")
// End:

