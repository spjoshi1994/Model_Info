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
//  Project  : LP3.5K_Pedometer_With_BLE_Interface
//  File Name: i2c_init.v
//
//  Description: I2C Initialization module
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date    |Changes Made:
// V1.0 | MDN           | 22-Apr-13    |Initial version
//-------------------------------------------------------------------------


`timescale 1 ns / 1 ps

module i2c_init(
		// Global inputs
		i_sys_clk, i_sys_rst,
		/*AUTOARG*/
		// Outputs
		o_i2c_init_done, o_init_address, o_init_txdata, o_init_strobe, o_init_wr_n,
		// Inputs
		i_init_strobe_ack, i_i2c_init
		);

   // Parameters
   // FSM states
   parameter IDLE     = 0;
   parameter STATE_1  = 1;
   parameter STATE_2  = 2;
   parameter STATE_3  = 3;

   // Global inputs
   input  i_sys_clk;  // system clock input
   input  i_sys_rst;  // active high reset input

   // Outputs
   output o_i2c_init_done;
   output [7:0] o_init_address;
   output [7:0] o_init_txdata;
   output       o_init_strobe;
   output       o_init_wr_n;

   // Inputs
   input        i_init_strobe_ack;
   input        i_i2c_init;

   // Internal signals
   reg [4:0] 	state_i;
   wire         terminate_strobe_i;
   wire         switch_state_i;
   reg [3:0] 	cycle_count_i;
   reg [7:0] 	address_i;
   reg [7:0] 	tx_data_i;
   reg          strobe_i;
   reg          wr_n_i;


   assign o_init_address = address_i;
   assign o_init_txdata  = tx_data_i;
   assign o_init_strobe  = strobe_i;
   assign o_init_wr_n    = wr_n_i;
   assign o_i2c_init_done = (state_i == STATE_3);

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
              if(i_i2c_init)begin
                 state_i <= STATE_1;
              end
              tx_data_i <= 0;
              address_i <= 0;
              strobe_i <= 0;
              wr_n_i <= 0;
           end

           //Write interrut control register
           // Enabled interrupt for TRRDY0
           STATE_1:begin
              if(switch_state_i)begin
                 state_i <= STATE_2;
              end
              tx_data_i <= 8'b1000_0100;
              address_i <= 8'b0000_0111;
              wr_n_i <= 1'b1;

              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           // Enable I2C core
           STATE_2:begin
              if(switch_state_i)begin
                 state_i <= STATE_3;
              end
              tx_data_i <= 8'b1000_0000;
              address_i <= 8'b0000_1000;
              wr_n_i <= 1'b1;

              if(terminate_strobe_i)begin
                 strobe_i <= 1'b0;
              end else begin
                 strobe_i <= 1'b1;
              end
           end

           STATE_3:begin
              if(~i_i2c_init)begin
                 state_i <= IDLE;
              end
           end
         endcase
      end
   end

   assign switch_state_i = (cycle_count_i == 2);
   assign terminate_strobe_i = (cycle_count_i > 1);

   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         cycle_count_i <= 0;
      end else begin
         if((state_i == IDLE) || switch_state_i) begin
            cycle_count_i <= 0;
         end else begin
            cycle_count_i <= cycle_count_i + 1;
         end
      end
   end


endmodule

