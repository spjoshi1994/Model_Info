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
//  Project  : LP3.5K_Pedometer_with_BLE_Interface
//  File Name: uart_top.v
//  Author   : MDN
//-------------------------------------------------------------------------
//  Code Revision History :
//  Ver: | Author        | Mod. Date    |Changes Made:
//  V1.0 | MDN           | 01-FEB-2014  |
//-------------------------------------------------------------------------
// Description : This is the top level file of the UART Design
//
//-------------------------------------------------------------------------
//  Parameters :none                           
//-------------------------------------------------------------------------
//  Reuse Issues
//   Reset Strategy   : Asynchronous, active high system level reset
//   Clock Domains    : i_sys_clk
//   Asynchronous I/F : i_sys_rst
//   Instantiations   : uart_lite_transceiver, uart_reg_fsm
//   Other            : N/A
//-------------------------------------------------------------------------
module uart_top (/*AUTOARG*/
                 // Outputs
                 o_tx,
                 // Inputs
                 i_sys_clk, i_sys_rst, i_ready, i_step_intr, i_foot_counter, i_rx,
                 i_send_isr
                 );                 
    //Global Inputs
    input                           i_sys_clk;
    input                           i_sys_rst;

    //Interrupt from sensor data
    input                           i_ready;
    input                           i_step_intr;
    input [15:0]                    i_foot_counter;
    input                           i_rx;
    input                           i_send_isr;
    output                          o_tx;
    
    //internal signals
    wire                            tsr_empty_i;  
    wire                            tx_start_i; 
    wire [7:0]                      tx_data_i;
    wire                            rx_data_valid_i;
    wire [7:0]                      rx_data_i; 
    wire                            rst_divisor_i;
    
    wire                            pll_18M_clk_i;
    wire                            sys_clk_i;
    wire                            clear_linestatusreg_i;
    wire                            clear_rxdataready_i;
    
    wire                            rx_clk_i;
    wire [3:0]                      line_status_reg_i;
    wire                            intr_i;
    parameter LINE_CNRTL_REG = 8'h03;
    parameter DIVISOR_LATCH_LSB = 8'd176;//8'd120;
    parameter DIVISOR_LATCH_MSB = 8'h00;

   //Module to control  master controller,Rx and Tx module
   uart_lite_transceiver u_uart_lite_transceiver (
                                                  .i_clk                (i_sys_clk),
                                                  .i_rst                (i_sys_rst),
                                                  .i_rx_clk             (rx_clk_i),
                                                  .i_line_cntrl_reg     (LINE_CNRTL_REG),
                                                  .o_line_status_reg    (line_status_reg_i),
                                                  .i_divisor_latch_lsb  (DIVISOR_LATCH_LSB),
                                                  .i_divisor_latch_msb  (DIVISOR_LATCH_MSB),
                                                  .i_rst_divisor        (rst_divisor_i),
                                                  .i_tx_start           (tx_start_i),
                                                  .i_tx_data            (tx_data_i),
                                                  .o_rx_data_valid      (rx_data_valid_i),
                                                  .o_rx_data            (rx_data_i),
                                                  .i_clear_linestatusreg(clear_linestatusreg_i),
                                                  .i_clear_rxdataready  (clear_rxdataready_i),
                                                  .o_intr               (intr_i),
                                                  .o_baudout            (rx_clk_i),
                                                  .o_tsr_empty          (tsr_empty_i),
                                                  .i_serial_data        (i_rx),
                                                  .o_serial_data        (o_tx)
                                                  );

    //Module to send isr bit to uart Tx module
    uart_reg_fsm u_uart_reg_fsm(
                                // outputs
                                .o_tx_start            (tx_start_i),
                                .o_tx_data             (tx_data_i),
                                // inputs
                                .i_sys_clk             (i_sys_clk),
                                .i_sys_rst             (i_sys_rst),
                                .i_tsr_empty           (tsr_empty_i),
                                .i_rx_data             (rx_data_i),
                                .i_rx_data_valid       (rx_data_valid_i),
                                .i_ready               (i_ready),
                                .i_step_intr           (i_step_intr),
                                .i_foot_counter        (i_foot_counter),
                                .i_send_isr            (i_send_isr)
                                );
    
    
    assign rst_divisor_i = 0;
   
   
endmodule
