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
//  Project  : LP3.5K_Pedometer_with_BLE_interface
//  File Name: I2C_master_top.v
// 
//  Description: Top module of the I2C master controller
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date    |Changes Made:
// V1.0 | MDN           | 03-Nov-12    |Initial version                             
//-------------------------------------------------------------------------
  
module	I2C_master_top	(
			 // Global inputs
			 i_sys_clk, i_sys_rst,                         
			 /*AUTOARG*/
			 // Outputs
			 o_scl_oe_n, o_sda_oe_n, o_start_ack, o_i2c_busy, o_tx_done, o_rx_done,
			 o_rxfifo_wrdata, o_rxfifo_wren, o_txfifo_rden,
			 // Inputs
			 i_scl_divcnt, i_byte_cnt, i_start_reg, i_abort_reg, i_adr_mode, i_rw_mode,
			 i_ack_mode, i_scl, i_sda, i_slave_addr, i_txfifo_rddata
			 );

   // Parameters
   parameter BUS_ADDR74 = 8'b0001_0000; // Keep MS 4 bits of the parameter same as the parameter definition of the I2C hard IP instance
   parameter I2C_SLAVE_INIT_ADDR = "0b1111100001"; // I2C slave address
   parameter BUS_ADDR74_STRING = "0b0001"; // I2C hard IP address MS 4 bits

   // Global inputs
   input	i_sys_clk;
   input 	i_sys_rst;

   // Outputs
   output 	o_scl_oe_n;
   output 	o_sda_oe_n;
   //	register control out
   output 	o_start_ack;
   //	I2C status output
   output 	o_i2c_busy;
   output 	o_tx_done;
   output 	o_rx_done;
   output [7:0] o_rxfifo_wrdata;
   output       o_rxfifo_wren;
   output       o_txfifo_rden;

   // Inputs
   //	register control in
   input [10:0] i_scl_divcnt;
   input [7:0] 	i_byte_cnt;
   input        i_start_reg;
   input        i_abort_reg; 
   input        i_adr_mode;
   input        i_rw_mode;
   input        i_ack_mode;
   input 	i_scl;
   input        i_sda;
   //	I2C bus output wire
   input [9:0] 	i_slave_addr;
   input [7:0] 	i_txfifo_rddata;
   
   // Internal signals
   wire [7:0] 	address_i;
   wire [7:0] 	txdata_i;
   wire [7:0] 	rxdata_i;
   wire         strobe_i;
   wire         strobe_ack_i;
   wire         wr_n_i;
   wire         intr_i;

   wire         sda_out_i;
   wire         sda_oe_i;
   wire         scl_out_i;
   wire         scl_oe_i;  
   wire [7:0] 	address_int_i;
   
   assign address_int_i = address_i | BUS_ADDR74;
   assign o_sda_oe_n = (sda_oe_i)?sda_out_i:1'b1;
   assign o_scl_oe_n = (scl_oe_i)?scl_out_i:1'b1;

   //Instantiation of I2C master control FSM
   i2c_master_cntrl_fsm u_i2c_master_cntrl_fsm (
                                                // Global inputs
                                                .i_sys_clk         (i_sys_clk),
                                                .i_sys_rst         (i_sys_rst),
                                                // Outputs
                                                .o_start_ack       (o_start_ack),
                                                .o_i2c_busy        (o_i2c_busy),
                                                .o_tx_done         (o_tx_done),
                                                .o_rx_done         (o_rx_done),
                                                .o_rxfifo_wren     (o_rxfifo_wren),
                                                .o_rxfifo_data     (o_rxfifo_wrdata[7:0]),
                                                .o_txfifo_rden     (o_txfifo_rden),
                                                .o_address         (address_i[7:0]),
                                                .o_txdata          (txdata_i[7:0]),
                                                .o_strobe          (strobe_i),
                                                .o_wr_n            (wr_n_i),
                                                // Inputs
                                                .i_slave_addr      (i_slave_addr[9:0]),
                                                .i_byte_cnt        (i_byte_cnt[7:0]),
                                                .i_clk_div_count   ({1'b0,i_scl_divcnt[10:1]}),
                                                .i_start           (i_start_reg),
                                                .i_ack_mode        (i_ack_mode),
                                                .i_rw_mode         (i_rw_mode),
                                                .i_txfifo_rddata   (i_txfifo_rddata[7:0]),
                                                .i_intr            (intr_i),
                                                .i_rxdata          (rxdata_i[7:0]),
                                                .i_strobe_ack      (strobe_ack_i));


   
   //`define SIM

`ifdef SIM
   i2c_ip u_i2c_ip (
                    .sda_out        (sda_out_i),
                    .sda_oe         (sda_oe_i),
                    .scl_out        (scl_out_i),
                    .scl_oe_i       (scl_oe_i),
                    .sb_dat_o       (rxdata_i),
                    .sb_ack_o       (strobe_ack_i),
                    .i2c_irq        (intr_i),
                    .i2c_wkup       (1'b1),
                    .SB_ID          (4'b0000),
                    .ADDR_LSB_USR   (2'b00),
                    .i2c_rst_async  (i_sys_rst),
                    .sda_in         (i_sda),
                    .scl_in         (i_scl),
                    .del_clk        (i_sys_clk),
                    .sb_clk_i       (i_sys_clk),
                    .sb_we_i        (wr_n_i),
                    .sb_stb_i       (strobe_i),
                    .sb_adr_i       (address_i),
                    .sb_dat_i       (txdata_i),
                    .scan_test_mode (1'b0)
                    );
`else
   SB_I2C u_sb_i2c(
                   //Inputs
 		   .SBCLKI	  (i_sys_clk),     
 		   .SBRWI	  (wr_n_i),     
 		   .SBSTBI	  (strobe_i),     
 		   .SBADRI7  (address_int_i[7]),      
 		   .SBADRI6  (address_int_i[6]),      
 		   .SBADRI5  (address_int_i[5]),      
 		   .SBADRI4  (address_int_i[4]),      
 		   .SBADRI3  (address_int_i[3]),      
 		   .SBADRI2  (address_int_i[2]),      
 		   .SBADRI1  (address_int_i[1]),      
 		   .SBADRI0  (address_int_i[0]),      
 		   .SBDATI7  (txdata_i[7]),      
 		   .SBDATI6  (txdata_i[6]),      
 		   .SBDATI5  (txdata_i[5]),      
 		   .SBDATI4  (txdata_i[4]),      
 		   .SBDATI3  (txdata_i[3]),      
 		   .SBDATI2  (txdata_i[2]),      
 		   .SBDATI1  (txdata_i[1]),      
 		   .SBDATI0  (txdata_i[0]),      
 		   .SCLI	  (i_scl),     
 		   .SDAI	  (i_sda),
                   //Outputs
 		   .SBDATO7  (rxdata_i[7]),      
 		   .SBDATO6  (rxdata_i[6]),      
 		   .SBDATO5  (rxdata_i[5]),      
 		   .SBDATO4  (rxdata_i[4]),      
 		   .SBDATO3  (rxdata_i[3]),      
 		   .SBDATO2  (rxdata_i[2]),      
 		   .SBDATO1  (rxdata_i[1]),      
 		   .SBDATO0  (rxdata_i[0]),      
 		   .SBACKO	  (strobe_ack_i),     
 		   .I2CIRQ	  (intr_i),     
 		   .SCLO	  (scl_out_i),     
 		   .SCLOE	  (scl_oe_i),     
 		   .SDAO	  (sda_out_i),     
 		   .SDAOE	  (sda_oe_i)
                   );

   defparam u_sb_i2c.I2C_SLAVE_INIT_ADDR =  I2C_SLAVE_INIT_ADDR;
   defparam u_sb_i2c.BUS_ADDR74 = BUS_ADDR74_STRING;
`endif  
   
endmodule
