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
//  File Name: i2c_master_byte_rx_fsm.v
// 
//  Description: I2C byte reception state machine
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date    |Changes Made:
// V1.0 | MDN           | 03-Nov-12    |Initial version                             
//-------------------------------------------------------------------------
  

`timescale 1 ns / 1 ps

module i2c_master_byte_rx_fsm(
			      // Global inputs
			      i_sys_clk, i_sys_rst,                              
			      /*AUTOARG*/
			      // Outputs
			      o_rx_wren, o_rx_data, o_byte_rx_done, o_byterx_address, o_byterx_txdata,
			      o_byterx_strobe, o_byterx_wr_n,
			      // Inputs
			      i_ack_mode, i_rx_en, i_intr, i_byterx_strobe_ack, i_byterx_rxdata
			      );
   
   // Parameters
   // FSM states
   parameter IDLE     = 0;
   parameter STATE_1  = 1 ;
   parameter STATE_2  = 2 ;
   parameter STATE_3  = 3 ;
   parameter STATE_4  = 4 ;
   parameter STATE_5  = 5 ;
   parameter STATE_6  = 6 ;
   parameter STATE_7  = 7 ;
   parameter STATE_8  = 8 ;
   parameter STATE_9  = 9 ;
   parameter STATE_10  = 10 ;

   // Global inputs
   input          i_sys_clk;
   input          i_sys_rst;
   
   // Outputs
   output         o_rx_wren;
   output [7:0]   o_rx_data;
   output         o_byte_rx_done;
   output [7:0]   o_byterx_address;
   output [7:0]   o_byterx_txdata;
   output         o_byterx_strobe;
   output         o_byterx_wr_n;

   // Inputs
   input          i_ack_mode;
   input          i_rx_en;
   input          i_intr;
   input          i_byterx_strobe_ack;
   input [7:0] 	  i_byterx_rxdata;

   // Internal signals
   reg [4:0] 	  state_i;
   wire           terminate_strobe_i;
   wire           switch_state_i;
   reg [3:0] 	  cycle_count_i;
   reg [7:0] 	  address_i;
   reg [7:0] 	  tx_data_i;
   reg            strobe_i;
   reg            wr_n_i;
   reg [7:0] 	  rxdata_i;


   assign o_byterx_address = address_i;
   assign o_byterx_txdata  = tx_data_i;
   assign o_byterx_strobe  = strobe_i;
   assign o_byterx_wr_n    = wr_n_i;

   assign o_rx_wren = (state_i == STATE_9);
   assign o_rx_data = rxdata_i;
   assign o_byte_rx_done = (state_i == STATE_9);
   
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
              if(i_rx_en)begin 
                 state_i <= STATE_1;
              end
              tx_data_i <= 0;
              address_i <= 0;
              strobe_i <= 0;
              wr_n_i <= 0;
           end

           //Read status register to check if on going transaction is complete
           STATE_1:begin 
              if(switch_state_i)begin
                 state_i <= STATE_2;
              end
              tx_data_i <= 8'b0001_0000; // Don't care
              address_i <= 8'b0000_1100;
              wr_n_i <= 1'b0; //read
              
              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           //Check if on going r/w is complete
           STATE_2:begin
              if(!(rxdata_i[7] && rxdata_i[6]))begin
                 state_i <= STATE_3;
              end else begin
                 state_i <= STATE_1;
              end
           end

           //Write command register with read command
           STATE_3:begin 
              if(switch_state_i)begin
                 state_i <= STATE_4;
              end
              tx_data_i <= {4'b0010, i_ack_mode, 3'b010}; // Read command with buffer disabled
              address_i <= 8'b0000_1001;
              wr_n_i    <= 1'b1;
              
              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           //Read status register to check if the transaction started
           // ** This was necessary as there is a latency before the
           // command is actually executed
           STATE_4:begin 
              if(switch_state_i)begin
                 state_i <= STATE_5;
              end
              tx_data_i <= 8'b0001_0000; // Don't care
              address_i <= 8'b0000_1100;
              wr_n_i <= 1'b0; //read
              
              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           //Check if transaction started
           STATE_5:begin
              if((rxdata_i[7] && rxdata_i[6]))begin
                 state_i <= STATE_6;
              end else begin
                 state_i <= STATE_4;
              end
           end

           //Read status register to check if on going transaction is complete
           STATE_6:begin 
              if(switch_state_i)begin
                 state_i <= STATE_7;
              end
              tx_data_i <= 8'b0001_0000; // Don't care
              address_i <= 8'b0000_1100;
              wr_n_i <= 1'b0; //read
              
              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           //Check if on going r/w is complete (TRRDY)
           STATE_7:begin
              if((rxdata_i[6] && rxdata_i[2]))begin
                 state_i <= STATE_8;
              end else begin
                 state_i <= STATE_6;
              end
           end
           
           //Read data from the RXDR
           STATE_8:begin 
              if(switch_state_i)begin
                 state_i <= STATE_9;
              end
              tx_data_i <= 0; //Don't care
              address_i <= 8'b0000_1110;
              wr_n_i <= 1'b0; //read
              
              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           //return to IDLE
           STATE_9:begin 
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
            rxdata_i <= i_byterx_rxdata;
         end
      end
   end

   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         cycle_count_i <= 0;
      end else begin
         if((state_i == IDLE) || (state_i == STATE_2)|| 
            (state_i == STATE_5) || (state_i == STATE_7) ||
            (state_i == STATE_9) || switch_state_i) begin
            cycle_count_i <= 0;
         end else begin
            cycle_count_i <= cycle_count_i + 1;
         end
      end
   end

endmodule

