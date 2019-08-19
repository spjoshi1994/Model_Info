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
//  File Name: i2c_master_byte_tx_fsm.v
// 
//  Description: I2C byte transmission state machine
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date    |Changes Made:
// V1.0 | MDN           | 03-Nov-12    |Initial version                             
//-------------------------------------------------------------------------
  

`timescale 1 ns / 1 ps

module i2c_master_byte_tx_fsm(
			      // Global inputs
			      i_sys_clk, i_sys_rst,
			      /*AUTOARG*/
			      // Outputs
			      o_tx_rden, o_byte_tx_done, o_bytetx_address, o_bytetx_txdata,
			      o_bytetx_strobe, o_bytetx_wr_n,
			      // Inputs
			      i_tx_data, i_tx_en, i_ack_mode, i_intr, i_bytetx_strobe_ack,
			      i_bytetx_rxdata
			      );
   
   // Parameters
   // FSM states
   parameter IDLE     = 0;
   parameter STATE_1  = 1;
   parameter STATE_2  = 2;
   parameter STATE_3  = 3;
   parameter STATE_4  = 4;
   parameter STATE_5  = 5;
   parameter STATE_6  = 6;
   parameter STATE_7  = 7;
   parameter STATE_8  = 8;
   parameter STATE_9  = 9;
   parameter STATE_10  = 10;

   // Global inputs
   input          i_sys_clk;
   input          i_sys_rst;

   // Outputs
   output         o_tx_rden;
   output         o_byte_tx_done;
   output [7:0]   o_bytetx_address;
   output [7:0]   o_bytetx_txdata;
   output         o_bytetx_strobe;
   output         o_bytetx_wr_n;

   //Inputs
   input [7:0] 	  i_tx_data;
   input          i_tx_en;
   input          i_ack_mode;
   input          i_intr;
   input          i_bytetx_strobe_ack;
   input [7:0] 	  i_bytetx_rxdata;

   // Internal signals
   reg [4:0] 	  state_i;
   wire           terminate_strobe_i;
   wire           switch_state_i;
   reg [3:0] 	  cycle_count_i;
   reg [7:0] 	  rxdata_i;
   reg [7:0] 	  address_i;
   reg [7:0] 	  tx_data_i;
   reg            strobe_i;
   reg            wr_n_i;

   assign o_bytetx_address = address_i;
   assign o_bytetx_txdata  = tx_data_i;
   assign o_bytetx_strobe  = strobe_i;
   assign o_bytetx_wr_n    = wr_n_i;

   assign o_tx_rden = (state_i == IDLE && i_tx_en);
   assign o_byte_tx_done = (state_i == STATE_5);
   
   // State machine to drive system interface bus
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         state_i <= IDLE;
         tx_data_i <= 0;
         address_i <= 0;
         strobe_i <= 0;
         wr_n_i <= 0;
      end else begin
         case(state_i)
           // Waiting for external trigger to start with configuration sequence                
           IDLE:begin
              if(i_tx_en)begin 
                 state_i <= STATE_7; // Change this to STATE_6 for using interrupt
              end
              tx_data_i <= 0;
              address_i <= 0;
              strobe_i <= 0;
              wr_n_i <= 0;
           end

           // Wait for interrupt
           STATE_6:begin
              if(i_intr)begin
                 state_i <= STATE_1;
              end
           end
           
           //Read status register to check if current transaction is complete
           STATE_7:begin 
              if(switch_state_i)begin
                 state_i <= STATE_8;
              end
              tx_data_i <= 8'b1001_0000; // Don't care
              address_i <= 8'b0000_1100; // Status register
              wr_n_i <= 1'b0; //read
              
              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           //Check if current transaction is complete
           STATE_8:begin
              if(!(rxdata_i[7] & rxdata_i[6]))begin
                 state_i <= STATE_1;
              end else begin
                 state_i <= STATE_7;
              end
           end

           //Read interrupt status register to check if TXRDY
           STATE_1:begin 
              if(switch_state_i)begin
                 state_i <= STATE_2;
              end
              tx_data_i <= 8'b1001_0000; // Don't care
              address_i <= 8'b0000_0110; // Status register
              wr_n_i <= 1'b0; //read
              
              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           //Check if TXRDY is high
           STATE_2:begin
              if(rxdata_i[2] == 1)begin
                 state_i <= STATE_3;
              end else begin
                 state_i <= STATE_6; // If tx was not ready wait for interrupt
              end
           end

           //Write txdata to tx register
           STATE_3:begin 
              if(switch_state_i)begin
                 state_i <= STATE_4;
              end
              tx_data_i <= i_tx_data;
              address_i <= 8'b0000_1101;
              wr_n_i <= 1'b1;
              
              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           //Write command register to send a byte
           STATE_4:begin 
              if(switch_state_i)begin
                 state_i <= STATE_9;
              end
              tx_data_i <= 8'b0001_0000;
              address_i <= 8'b0000_1001;
              wr_n_i <= 1'b1;
              
              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           //Read status register to check if transaction in progress
           STATE_9:begin 
              if(switch_state_i)begin
                 state_i <= STATE_10;
              end
              tx_data_i <= 8'b1001_0000; // Don't care
              address_i <= 8'b0000_1100; // Status register
              wr_n_i <= 1'b0; //read
              
              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           //Check if BUSY and TIP are 1
           STATE_10:begin
              if((rxdata_i[7] & rxdata_i[6]))begin // to make sure that start gen relieves the control only after making sure the transaction has started
                 state_i <= STATE_5;
              end else begin
                 state_i <= STATE_9;
              end
           end
           
           
           //return to IDLE
           STATE_5:begin 
              state_i <= IDLE;
           end
         endcase
      end
   end

   assign switch_state_i = (cycle_count_i == 2);
   assign terminate_strobe_i = (cycle_count_i > 1);
   
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         rxdata_i <= 0;
      end else begin
         if(cycle_count_i == 2) begin
            rxdata_i <= i_bytetx_rxdata;
         end
      end
   end

   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         cycle_count_i <= 0;
      end else begin
         if((state_i == IDLE) || (state_i == STATE_2)|| (state_i == STATE_6) || 
            (state_i == STATE_8) || (state_i == STATE_10) || switch_state_i) begin
            cycle_count_i <= 0;
         end else begin
            cycle_count_i <= cycle_count_i + 1;
         end
      end
   end

endmodule
