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
//  File Name: i2c_master_cntrl_fsm.v
// 
//  Description: I2C master controller state machine
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date    |Changes Made:
// V1.0 | MDN           | 03-Nov-12    |Initial version                             
//-------------------------------------------------------------------------
  

`timescale 1 ns / 1 ps

module i2c_master_cntrl_fsm(
			    // Global inputs
			    i_sys_clk, i_sys_rst,
			    /*AUTOARG*/
			    // Outputs
			    o_start_ack, o_i2c_busy, o_tx_done, o_rx_done, o_rxfifo_wren, o_rxfifo_data,
			    o_txfifo_rden, o_address, o_txdata, o_strobe, o_wr_n,
			    // Inputs
			    i_slave_addr, i_byte_cnt, i_clk_div_count, i_start, i_rw_mode, i_ack_mode,
			    i_txfifo_rddata, i_intr, i_rxdata, i_strobe_ack
			    );

   // Parameters
   // FSM states
   parameter [3:0] IDLE_STATE        = 4'b0000;
   parameter [3:0] I2C_INIT_STATE    = 4'b1010;
   parameter [3:0] WAIT_FOR_START    = 4'b1011;
   parameter [3:0] CHECK_FOR_BUSY    = 4'b0001;
   parameter [3:0] SCL_EN_STATE      = 4'b0010;
   parameter [3:0] START_STATE       = 4'b0011;
   parameter [3:0] SLVADR_MSB_STATE  = 4'b0100;
   parameter [3:0] SLVADR_LSB_STATE  = 4'b0101;
   parameter [3:0] TX_STATE          = 4'b0110;
   parameter [3:0] RX_STATE          = 4'b0111;
   parameter [3:0] CHECK_FOR_RSTART  = 4'b1000;
   parameter [3:0] STOP_STATE        = 4'b1001;

   parameter ADRMODE_7BIT  = 1'b0;  // 8 bit address mode
   parameter ADRMODE_10BIT = 1'b1;  // 10 bit address mode
   parameter WRITEMODE     = 1'b0;  // write mode
   parameter READMODE      = 1'b1;  // read mode

   // Global inputs
   input          i_sys_clk;
   input          i_sys_rst;

   // Outputs
   output reg     o_start_ack;
   // Status signals
   output reg     o_i2c_busy;
   output reg     o_tx_done;
   output reg     o_rx_done;
   // Rx FIFO write interface
   output         o_rxfifo_wren;   
   output [7:0]   o_rxfifo_data;                    
   // Tx FIFO read interface
   output         o_txfifo_rden;
   // I2C hard IP system configuration interface
   output [7:0]   o_address;
   output [7:0]   o_txdata;
   output         o_strobe;
   output         o_wr_n;

   // Inputs
   input [9:0] 	  i_slave_addr;                
   // Configuration signals
   input [7:0] 	  i_byte_cnt;
   input [10:0]   i_clk_div_count;
   input          i_start;
   input          i_rw_mode;
   input          i_ack_mode;
   input [7:0] 	  i_txfifo_rddata;
   input          i_intr;
   input [7:0] 	  i_rxdata;
   input          i_strobe_ack;
   
   // Internal signals
   reg [3:0] 	  state_i;
   reg [7:0] 	  byte_count_i;
   wire           tx_complete_i;
   wire           rx_complete_i;
   
   wire           i2c_init_done_i;
   reg            i2c_init_en_i;
   wire [7:0] 	  init_address_i;  
   wire [7:0] 	  init_txdata_i;   
   wire           init_strobe_i;        
   wire           init_wr_n_i;          
   wire [7:0] 	  byterx_address_i;  
   wire [7:0] 	  byterx_txdata_i;   
   wire           byterx_strobe_i;        
   wire           byterx_wr_n_i;
   reg            send_rx_cmd_i;
   wire           byte_rx_done_i;
   wire           byte_tx_done_i;
   reg            send_tx_cmd_i;
   wire [7:0] 	  bytetx_address_i;  
   wire [7:0] 	  bytetx_txdata_i;   
   wire           bytetx_strobe_i;        
   wire           bytetx_wr_n_i;
   wire           scl_configured_i;
   reg            configure_scl_i;
   wire [7:0] 	  scl_address_i;  
   wire [7:0] 	  scl_txdata_i;   
   wire           scl_strobe_i;        
   wire           scl_wr_n_i;
   wire [7:0] 	  start_address_i;  
   wire [7:0] 	  start_txdata_i;   
   wire           start_strobe_i;        
   wire           start_wr_n_i;
   reg            start_gen_en_i;
   wire           start_gen_ack_i;
   wire           stop_gen_ack_i;
   reg            stop_gen_en_i;
   wire [7:0] 	  stop_address_i;  
   wire [7:0] 	  stop_txdata_i;   
   wire           stop_strobe_i;        
   wire           stop_wr_n_i;
   wire           last_byte_i;
   wire           ack_mode_i;

   ////////////////////////////////////////////////////////////////
   // I2C master control FSM
   ////////////////////////////////////////////////////////////////
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst)begin
         state_i <= IDLE_STATE;
      end else begin
         case(state_i)
           IDLE_STATE:begin
	      state_i <= I2C_INIT_STATE;
           end

           I2C_INIT_STATE:begin
              if(i2c_init_done_i)begin
		 state_i <= WAIT_FOR_START;
              end
           end

           WAIT_FOR_START:begin
              if(i_start)begin
		 state_i <= SCL_EN_STATE;
              end
           end
           
           SCL_EN_STATE:begin // Configures the clock div factor 
              if(scl_configured_i)begin
		 state_i <= START_STATE;
              end
           end

           START_STATE:begin
              if(start_gen_ack_i)begin
                 if(i_rw_mode == READMODE)begin
		    state_i <= RX_STATE;
                 end else begin
		    state_i <= TX_STATE;
                 end
              end
	   end
           
           TX_STATE: begin // I2C tx state
	      if(byte_tx_done_d1) begin
                 if(tx_complete_i == 1) begin
		    state_i <= CHECK_FOR_RSTART;
                 end else begin
                    state_i <= TX_STATE;
                 end
              end
	   end

           RX_STATE: begin // I2C rx state
	      if(byte_rx_done_d1) begin
                 if(rx_complete_i)begin
                    state_i <= CHECK_FOR_RSTART;
                 end else begin
                    state_i <= RX_STATE;
                 end
              end
	   end

           CHECK_FOR_RSTART:begin
              if(i_start)begin
                 state_i <= START_STATE;
              end else begin
                 state_i <= STOP_STATE;
              end
           end
           
           STOP_STATE: begin
	      if(stop_gen_ack_i)begin
		 state_i <= WAIT_FOR_START;
              end
	   end
           
           default:  state_i <= WAIT_FOR_START;
         endcase
      end
   end

   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         i2c_init_en_i <= 1'b0;
      end else begin
	 if(state_i == I2C_INIT_STATE) begin
            i2c_init_en_i <= 1;
         end else begin
            i2c_init_en_i <= 0;
         end
      end
   end

   ////////////////////////////////////////////////////////////////
   // START and STOP condition generation enables
   ////////////////////////////////////////////////////////////////

   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         start_gen_en_i <= 1'b0;
      end else begin
	 if(state_i == START_STATE) begin
            start_gen_en_i <= 1'b1;
         end else begin
            start_gen_en_i <= 1'b0;
         end
      end
   end

   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         stop_gen_en_i <= 1'b0;
      end else begin
         if(state_i == STOP_STATE)begin
            stop_gen_en_i <= 1;
         end else begin
            stop_gen_en_i <= 0;
         end
      end
   end

   ////////////////////////////////////////////////////////////////
   // SCL enable
   ////////////////////////////////////////////////////////////////
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         configure_scl_i <= 1'b0;
      end else begin
	 if  (state_i == SCL_EN_STATE) begin
            configure_scl_i <= 1;
         end else begin
            configure_scl_i <= 0;
         end
      end
   end

   ////////////////////////////////////////////////////////////////
   // Byte counter
   ////////////////////////////////////////////////////////////////
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         byte_count_i <= 7'b0;
      end else begin
	 if(((state_i == TX_STATE) && byte_tx_done_i) ||
            ((state_i == RX_STATE) && byte_rx_done_i))begin
            byte_count_i <= byte_count_i + 1;
         end else if(state_i == START_STATE)begin
            byte_count_i <= 0;
         end
      end
   end

   assign tx_complete_i = (byte_count_i == i_byte_cnt) && (state_i == TX_STATE);
   assign rx_complete_i = (byte_count_i == i_byte_cnt) && (state_i == RX_STATE);
   assign last_byte_i = (byte_count_i == (i_byte_cnt - 1));
   assign ack_mode_i = (last_byte_i && (state_i == RX_STATE))? ~i_ack_mode : i_ack_mode;

   ////////////////////////////////////////////////////////////////
   // TX FIFO read interface
   ////////////////////////////////////////////////////////////////
   reg byte_tx_done_d1;
   
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         byte_tx_done_d1 <= 1'b0;
      end else begin
         byte_tx_done_d1 <= byte_tx_done_i;
      end
   end

   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         send_tx_cmd_i <= 1'b0;
      end else begin
         if(state_i == START_STATE) begin
            send_tx_cmd_i <= (~i_rw_mode && start_gen_ack_i);
         end else if(state_i == TX_STATE) begin
            if(byte_tx_done_d1 && ~tx_complete_i)begin
               send_tx_cmd_i <= 1;
            end else begin
               send_tx_cmd_i <= 0;
            end
         end else begin
            send_tx_cmd_i <= 1'b0;
         end
      end
   end


   ////////////////////////////////////////////////////////////////
   // RX FIFO write interface
   ////////////////////////////////////////////////////////////////
   reg byte_rx_done_d1;
   
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         byte_rx_done_d1 <= 1'b0;
      end else begin
         byte_rx_done_d1 <= byte_rx_done_i;
      end
   end
   
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         send_rx_cmd_i <= 1'b0;
      end else begin
         if(state_i == START_STATE) begin
            send_rx_cmd_i <= (i_rw_mode && start_gen_ack_i);
         end else if(state_i == RX_STATE) begin
            if(byte_rx_done_d1 && ~rx_complete_i)begin
               send_rx_cmd_i <= 1;
            end else begin
               send_rx_cmd_i <= 0;
            end
         end else begin
            send_rx_cmd_i <= 1'b0;
         end
      end
   end

   ////////////////////////////////////////////////////////////////
   // Status signal generation
   ////////////////////////////////////////////////////////////////

   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         o_start_ack <= 1'b0;
      end else begin
         if(state_i == START_STATE)begin
            o_start_ack <= 1;
         end else begin
            o_start_ack <= 0;
         end
      end
   end

   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         o_tx_done <= 1'b0;
      end else begin 
         if((state_i == TX_STATE) &&  tx_complete_i) begin
            o_tx_done <= 1;
         end else begin
            o_tx_done <= 0;
         end
      end
   end
   
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         o_rx_done <= 1'b0;
      end else begin 
         if((state_i == RX_STATE) &&  rx_complete_i) begin
            o_rx_done <= 1;
         end else begin
            o_rx_done <= 0;
         end
      end
   end
   
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         o_i2c_busy <= 1'b0;
      end else begin
	 if(state_i == WAIT_FOR_START)begin
            o_i2c_busy <= 1'b0;
         end else begin
            o_i2c_busy <= 1'b1;
         end
      end
   end

   // SCI drivers for I2C IP
   assign o_address = init_address_i | byterx_address_i | bytetx_address_i | scl_address_i | start_address_i | stop_address_i;
   assign o_txdata = init_txdata_i | byterx_txdata_i | bytetx_txdata_i | scl_txdata_i | start_txdata_i | stop_txdata_i;
   assign o_strobe = init_strobe_i | byterx_strobe_i | bytetx_strobe_i | scl_strobe_i | start_strobe_i | stop_strobe_i;
   assign o_wr_n = init_wr_n_i | byterx_wr_n_i | bytetx_wr_n_i | scl_wr_n_i | start_wr_n_i | stop_wr_n_i;

  //I2C initialization module
   i2c_init u_i2c_init(
                       // Global inputs
                       .i_sys_clk                       (i_sys_clk),
                       .i_sys_rst                       (i_sys_rst),
                       // Outputs
                       .o_i2c_init_done                 (i2c_init_done_i),
                       .o_init_address                  (init_address_i[7:0]),
                       .o_init_txdata                   (init_txdata_i[7:0]),
                       .o_init_strobe                   (init_strobe_i),
                       .o_init_wr_n                     (init_wr_n_i),          
                       // Inputs
                       .i_i2c_init                      (i2c_init_en_i),
                       .i_init_strobe_ack               (i_strobe_ack));
   
   //I2C Reception module initiantion
   i2c_master_byte_rx_fsm u_i2c_master_byte_rx_fsm(
                                                   // Global inputs
                                                   .i_sys_clk            (i_sys_clk),
                                                   .i_sys_rst            (i_sys_rst),
                                                   // Outputs
                                                   .o_rx_wren            (o_rxfifo_wren),
                                                   .o_rx_data            (o_rxfifo_data[7:0]),
                                                   .o_byte_rx_done       (byte_rx_done_i),
                                                   .o_byterx_address     (byterx_address_i[7:0]),
                                                   .o_byterx_txdata      (byterx_txdata_i[7:0]),
                                                   .o_byterx_strobe      (byterx_strobe_i),
                                                   .o_byterx_wr_n        (byterx_wr_n_i),
                                                   // Inputs
                                                   .i_ack_mode           (ack_mode_i),
                                                   .i_rx_en              (send_rx_cmd_i),
                                                   .i_intr               (i_intr),
                                                   .i_byterx_strobe_ack  (i_strobe_ack),
                                                   .i_byterx_rxdata      (i_rxdata[7:0]));

   //I2C transmission module initiation
   i2c_master_byte_tx_fsm u_i2c_master_byte_tx_fsm(
                                                   // Global inputs
                                                   .i_sys_clk            (i_sys_clk),
                                                   .i_sys_rst            (i_sys_rst),
                                                   // Outputs
                                                   .o_tx_rden            (o_txfifo_rden),
                                                   .o_byte_tx_done       (byte_tx_done_i),
                                                   .o_bytetx_address     (bytetx_address_i[7:0]),
                                                   .o_bytetx_txdata      (bytetx_txdata_i[7:0]),
                                                   .o_bytetx_strobe      (bytetx_strobe_i),
                                                   .o_bytetx_wr_n        (bytetx_wr_n_i),
                                                   // Inputs
                                                   .i_ack_mode           (ack_mode_i),
                                                   .i_tx_data            (i_txfifo_rddata[7:0]),
                                                   .i_tx_en              (send_tx_cmd_i),
                                                   .i_intr               (i_intr),
                                                   .i_bytetx_strobe_ack  (i_strobe_ack),
                                                   .i_bytetx_rxdata      (i_rxdata[7:0]));

   //I2C clock generation module initiation
   i2c_master_scl_gen u_i2c_master_scl_gen(
                                           // Global inputs
                                           .i_sys_clk            (i_sys_clk),
                                           .i_sys_rst            (i_sys_rst),
                                           // Outputs
                                           .o_scl_configured     (scl_configured_i),
                                           .o_scl_address        (scl_address_i[7:0]),
                                           .o_scl_txdata         (scl_txdata_i[7:0]),
                                           .o_scl_strobe         (scl_strobe_i),
                                           .o_scl_wr_n           (scl_wr_n_i),
                                           // Inputs
                                           .i_configure_scl      (configure_scl_i),
                                           .i_clk_div_factor     (i_clk_div_count[10:0]),
                                           .i_scl_strobe_ack     (i_strobe_ack));
   //I2C start generation module initiation
   i2c_master_start_gen u_i2c_master_start_gen(
                                               // Global inputs
                                               .i_sys_clk        (i_sys_clk),
                                               .i_sys_rst        (i_sys_rst),
                                               // Outputs
                                               .o_start_gen_ack  (start_gen_ack_i),
                                               .o_start_address  (start_address_i[7:0]),
                                               .o_start_txdata   (start_txdata_i[7:0]),
                                               .o_start_strobe   (start_strobe_i),
                                               .o_start_wr_n     (start_wr_n_i),
                                               // Inputs
                                               .i_start_gen_en   (start_gen_en_i),
                                               .i_slave_address  (i_slave_addr[7:0]),
                                               .i_rw_mode        (i_rw_mode),
                                               .i_start_strobe_ack(i_strobe_ack),
                                               .i_start_rxdata   (i_rxdata[7:0]));
   //I2C end generation module initiation
   i2c_master_stop_gen u_i2c_master_stop_gen(
                                             // Global inputs
                                             .i_sys_clk          (i_sys_clk),
                                             .i_sys_rst          (i_sys_rst),
                                             // Outputs
                                             .o_stop_gen_ack     (stop_gen_ack_i),
                                             .o_stop_address     (stop_address_i[7:0]),
                                             .o_stop_txdata      (stop_txdata_i[7:0]),
                                             .o_stop_strobe      (stop_strobe_i),
                                             .o_stop_wr_n        (stop_wr_n_i),
                                             // Inputs
                                             .i_stop_gen_en      (stop_gen_en_i),
                                             .i_stop_rxdata      (i_rxdata[7:0]));

endmodule
