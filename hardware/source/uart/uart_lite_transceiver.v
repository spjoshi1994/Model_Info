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
//  File Name: uart_lite_transceiver.v
//  Author   : MDN
//-------------------------------------------------------------------------
//  Code Revision History :
//  Ver: | Author        | Mod. Date    |Changes Made:
//  V1.0 | MDN           | 01-FEB-2013  |
//-------------------------------------------------------------------------
//  Description:Top level module instantiating the master controller, Rx and 
//  Tx fsm
//-------------------------------------------------------------------------
//  Parameters :none                           
//-------------------------------------------------------------------------
//  Reuse Issues
//   Reset Strategy   : Asynchronous, active high system level reset
//   Clock Domains    : i_clk
//   Asynchronous I/F : i_rst
//   Instantiations   : UART Master Controller, UART Tx FSM ,UART Tx FSM
//   Other            : N/A
//-------------------------------------------------------------------------


`timescale 1 ns / 1 ps

module uart_lite_transceiver(
                             // System clock 
                             // asynchronous active high reset 
                             input wire        i_clk,
                             input wire        i_rst,
                             input wire        i_rx_clk,
                             // Register set                     
                             input  wire [7:0] i_line_cntrl_reg,
                             output wire [3:0] o_line_status_reg,
                             input  wire [7:0] i_divisor_latch_lsb,
                             input  wire [7:0] i_divisor_latch_msb,
                             input wire        i_rst_divisor,
                             //Tx & Rx data lines
                             input wire        i_tx_start,
                             input  wire [7:0] i_tx_data,
                             output wire       o_rx_data_valid,
                             output wire [7:0] o_rx_data,
                             //Clear register signals
                             input wire        i_clear_linestatusreg,
                             input wire        i_clear_rxdataready,
                             //Interrupt line
                             output wire       o_intr,
                             output wire       o_baudout,     
                             output wire       o_tsr_empty,
                             //tp
                             output  wire o_rx_sample_en,
                             //SERIAL IO Lines
                             input  wire       i_serial_data,
                             output wire       o_serial_data  
                             );


    //Internal signals    
    wire                                  stop_bit_15;
    wire                                  stop_bit_2;
    wire                                  parity_en;
    wire                                  parity_even;
    wire [1:0]                            no_of_data_bits;              
    wire                                  break_interrupt;
    wire                                  parity_error;
    wire                                  framing_error;
    wire                                  rx_data_ready;  
    wire                                  stick_parity_en;
    wire                                  break_control;
    wire                                  tx_en;
    wire                                  tx_en_div2;
    wire                                  tx_en_stop; 

    //Test
    wire                                  rx_sample_en_i; 
    
    assign o_rx_sample_en = rx_sample_en_i;//tx_en;
    
    ////////////////////////////////////////////////////////////////////
    // UART Master Controller
    ////////////////////////////////////////////////////////////////////   
    uart_master_controller uart_master_controller(
                                                  //Clk & RST
                                                  .i_clk                    (i_clk),
                                                  .i_rst                    (i_rst),
                                                  //Register set
                                                  .i_line_cntrl_reg         (i_line_cntrl_reg),                    
                                                  .o_line_status_reg        (o_line_status_reg),  
                                                  .i_divisor_latch_lsb      (i_divisor_latch_lsb),
                                                  .i_divisor_latch_msb      (i_divisor_latch_msb),
                                                  .i_rst_divisor            (i_rst_divisor),  
                                                  //Tx & Rx FSM Control
                                                  .o_break_control          (break_control),
                                                  .o_stop_bit_15            (stop_bit_15),  
                                                  .o_stop_bit_2             (stop_bit_2),    
                                                  .o_parity_en              (parity_en),     
                                                  .o_parity_even            (parity_even),   
                                                  .o_no_of_data_bits        (no_of_data_bits),
                                                  .o_stick_parity_en        (stick_parity_en),
                                                  //Tx FSM Controls
                                                  .o_tx_en                  (tx_en),
                                                  .o_tx_en_div2             (tx_en_div2),
                                                  .i_tx_en_stop             (tx_en_stop),
                                                  //Rx FSM status 
                                                  .i_parity_error           (parity_error),  
                                                  .i_framing_error          (framing_error), 
                                                  .i_rx_data_ready          (rx_data_ready), 
                                                  .i_break_interrupt        (break_interrupt),           
                                                  //CPU Interrupt 
                                                  .o_intr                   (o_intr),
                                                  .o_baudout                (o_baudout)
                                                  );

    ////////////////////////////////////////////////////////////////////
    // UART Tx FSM
    ////////////////////////////////////////////////////////////////////
    uart_tx_fsm uart_tx_fsm(
                            //CLK & RST
                            .i_clk             (i_clk),
                            .i_rst             (i_rst),
                            //Tx Data from CPU
                            .i_tx_data         (i_tx_data),
                            //Tx FSM Control signal from UART Controller block                               
                            .i_start_tx        (i_tx_start),
                            .i_break_control   (break_control),
                            .i_stop_bit_15     (stop_bit_15),     
                            .i_stop_bit_2      (stop_bit_2),    
                            .i_parity_even     (parity_even),      
                            .i_parity_en       (parity_en),
                            .i_no_of_data_bits (no_of_data_bits),
                            .i_stick_parity_en (stick_parity_en),
                            .o_tsr_empty       (o_tsr_empty),  
                            .i_tx_en           (tx_en),
                            .i_tx_en_div2      (tx_en_div2),
                            .o_tx_en_stop      (tx_en_stop),                          
                            //Serial data out to MODEM
                            .o_serial_data     (o_serial_data)
                            );

    ////////////////////////////////////////////////////////////////////
    // UART Rx FSM
    ////////////////////////////////////////////////////////////////////
    uart_rx_fsm uart_rx_fsm(
                            //CLK & RST
                            .i_clk                 (i_clk),             
                            .i_rst                 (i_rst),
                            .i_rx_clk              (i_rx_clk),
                            //Rx control and configuration signal from UART Master
                            .i_parity_even         (parity_even),
                            .i_parity_en           (parity_en), 
                            .i_no_of_data_bits     (no_of_data_bits),
                            .i_stick_parity_en     (stick_parity_en),
                            .i_clear_linestatusreg (i_clear_linestatusreg),
                            .i_clear_rxdataready   (i_clear_rxdataready),
                            //Rx data and data valid to CPU
                            .o_rx_data_valid       (o_rx_data_valid),
                            .o_rx_data             (o_rx_data),
                            //Rx FSM status to UART Controller
                            .o_parity_error        (parity_error),  
                            .o_framing_error       (framing_error),
                            .o_break_interrupt     (break_interrupt),
                            .o_rx_data_ready       (rx_data_ready),
                            // tp
                            .o_rx_sample_en (rx_sample_en_i),//o_rx_sample_en),
                            //Input serial data line from MODEM
                            .i_serial_data         (i_serial_data)
                            );

endmodule


