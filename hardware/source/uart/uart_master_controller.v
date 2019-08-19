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
//  File Name: uart_master_controller.v
//  Author   : MDN
//-------------------------------------------------------------------------
//  Code Revision History :
//  Ver: | Author        | Mod. Date    |Changes Made:
//  V1.0 | MDN           | 01-FEB-2014  |
//-------------------------------------------------------------------------
//  Description : This module has the following functions :
//  1.Register set interface : Decodes the information on the register ports and 
//  generates the control signals to execute the required operations
//  2.Tx Control FSM : This generates the control signals to start the Trasmit process
//  3.Rx Control FSM : This generates the control signals to start the Recieve process
//  4.Interrupt generation
//-------------------------------------------------------------------------
//  Parameters :none                           
//-------------------------------------------------------------------------
//  Reuse Issues
//   Reset Strategy   : Asynchronous, active high system level reset
//   Clock Domains    : i_clk
//   Asynchronous I/F : i_rst
//   Instantiations   : none
//   Other            : N/A
//-------------------------------------------------------------------------
module uart_master_controller(
                              // System clock 
                              // asynchronous active high reset 
                              input wire         i_clk,
                              input wire         i_rst,
                              // Register set                     
                              input  wire [7:0]  i_line_cntrl_reg,
                              output reg  [3:0]  o_line_status_reg,
                              input  wire [7:0]  i_divisor_latch_lsb,
                              input  wire [7:0]  i_divisor_latch_msb,
                              input wire         i_rst_divisor, 
                              output wire        o_break_control,
                              //Tx & Rx  FSM Configurations
                              output wire        o_stop_bit_15,
                              output wire        o_stop_bit_2,
                              output wire        o_parity_en,                          
                              output wire        o_parity_even,
                              output wire [1:0]  o_no_of_data_bits,
                              output wire        o_stick_parity_en,
                              //Tx FSM Controls
                              output reg        o_tx_en,
                              output reg        o_tx_en_div2,
                              input wire        i_tx_en_stop,                                                                                        
                              //Rx FSM Inputs
                              input wire         i_parity_error,
                              input wire         i_framing_error,
                              input wire         i_rx_data_ready,                          
                              //rx FSM Status
                              input wire         i_break_interrupt,
                              //Interrupt line
                              output reg         o_intr,
                              output reg         o_baudout
                              );

    //Internal signals 
    reg [1:0]                                  no_of_data_bits;
    reg                                        stop_bit; 
    reg [7:0]                                  divisor_latch_msb;
    reg [7:0]                                  divisor_latch_lsb;
    wire [19:0]                                counter_value; 
    reg                                        stop_bit_15;
    reg                                        stop_bit_2;
    reg                                        parity_en;
    reg                                        parity_even;
    reg                                        stick_parity_en;
    reg                                        break_control;   
    reg                                        interrupt_en;       
    
    //////////////////////////////////////////////////////////////////
    //Register set interface logic
    //////////////////////////////////////////////////////////////////
    
    /////////////////////////////////////
    //Line control register decode logic
    ////////////////////////////////////
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin 
            no_of_data_bits <= 2'b0;
            stop_bit <= 1'b0;
            parity_en <= 1'b0;
            parity_even <= 1'b0;
            stick_parity_en <= 1'b0;
            break_control <= 1'b0;
            interrupt_en  <= 1'b0;
        end else begin
            no_of_data_bits <= i_line_cntrl_reg[1:0];
            stop_bit <= i_line_cntrl_reg[2];
            parity_en <= i_line_cntrl_reg[3];
            parity_even <= i_line_cntrl_reg[4];
            stick_parity_en <= i_line_cntrl_reg[5];
            break_control   <= i_line_cntrl_reg[6];
            interrupt_en    <= i_line_cntrl_reg[7];
        end
    end

    //Number stop bits decode logic
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            stop_bit_15  <= 1'b0;
            stop_bit_2   <= 1'b0;
        end else begin
            if (stop_bit == 1'b0) begin
                stop_bit_15  <= 1'b0;
                stop_bit_2   <= 1'b0;
            end else if (stop_bit == 1'b1 && no_of_data_bits == 2'b0) begin
                stop_bit_15 <= 1'b1;
                stop_bit_2   <= 1'b0;
            end else if (stop_bit == 1'b1 && no_of_data_bits != 2'b0) begin    
                stop_bit_15  <= 1'b0;
                stop_bit_2   <= 1'b1;
            end 
        end
    end // always @ (posedge i_clk or posedge i_rst)

    assign o_stop_bit_2 = stop_bit_2;
    assign o_stop_bit_15 = stop_bit_15;
    assign o_parity_en   = parity_en;
    assign o_parity_even  = parity_even;
    assign o_no_of_data_bits = no_of_data_bits;
    assign o_stick_parity_en = stick_parity_en;
    assign o_break_control = break_control;
  
    //////////////////////////////////////////////////////////////////
    //Interrupt generation logic
    //Depeding on the Interrupt enable - Interrupts are generated 
    //The interrupt is then Identified and the corresponding bit is set
    //in the Interrupt ID register
    //Input Signals from Rx FSM Block - i_parity_error, i_framing_error, 
    // i_break_interrup      
    //////////////////////////////////////////////////////////////////

    //Interrupt generation
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            o_intr <= 1'b0;
        end else begin
            if (interrupt_en) begin
                o_intr <= i_parity_error || i_framing_error || i_break_interrupt;            
            end else
                o_intr <= 1'b0;
        end     
    end // always @ (posedge i_clk or posedge i_rst)    
   

    //Line Status register
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            o_line_status_reg <= 4'b0;
        end else begin
            o_line_status_reg[0] <= i_rx_data_ready; 
            o_line_status_reg[1] <= i_parity_error;
            o_line_status_reg[2] <= i_framing_error;
            o_line_status_reg[3] <= i_break_interrupt;
        end        
    end
     
    //synchronizers
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            divisor_latch_msb <= 8'b0;
            divisor_latch_lsb <= 8'b0;
        end else begin
            divisor_latch_msb <= i_divisor_latch_msb;
            divisor_latch_lsb <= i_divisor_latch_lsb;
        end
    end

    //Divisor value == Divisor Latch/16
    assign counter_value = !i_rst_divisor ? {divisor_latch_msb, divisor_latch_lsb, 4'b000} : 0;
    
    //The logic here is used for generatin the Tx En signal for the required baud rate
    reg [19:0] sampling_counter; 
    wire [19:0] sampling_counter_div2;
    wire [19:0] sampling_counter_div4;

    //Divide by 2
    assign sampling_counter_div2 = {1'b0, counter_value[19:1]};
    //Divide by 4 for generating 0.5 stop bit 
    assign sampling_counter_div4 = {2'b0, counter_value[19:2]};
           
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            sampling_counter <= 0;
            o_tx_en <= 1'b0; 
        end else begin
            if(i_tx_en_stop) begin
                //Reset sampling counter
                sampling_counter <= 0;
                o_tx_en <= 1'b0; 
            end else begin
                //Sampling counter
                if(sampling_counter[19:16] == counter_value[19:16] &
                   sampling_counter[15:12] == counter_value[15:12] &
                   sampling_counter[11:8] == counter_value[11:8] &
                   sampling_counter[7:4] == counter_value[7:4] &
                   sampling_counter[3:0] == counter_value[3:0]) begin
                    sampling_counter [19:16] <= 4'b0000;
                    sampling_counter [15:12] <= 4'b0000;   
                    sampling_counter [11:8] <= 4'b0000;
                    sampling_counter [7:4] <= 4'b0000;         
                    sampling_counter [3:0] <= 4'b0000;
                    o_tx_en <= 1'b1; 
                end else begin 
                    sampling_counter <= sampling_counter + 1'b1;
                    o_tx_en <= 1'b0; 
                end 
            end
        end
    end 
    
    //Tx enable signal generation for Tx of 1.5 stop bit
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            o_tx_en_div2 <= 1'b0;
        end else begin
             if(i_tx_en_stop) begin
                //Reset sampling counter
               // sampling_counter <= 0;
                o_tx_en_div2 <= 1'b0;
             end else begin
                 if(sampling_counter[19:16] == sampling_counter_div2[19:16] &
                    sampling_counter[15:12] == sampling_counter_div2[15:12] &
                    sampling_counter[11:8] == sampling_counter_div2[11:8] &
                    sampling_counter[7:4] == sampling_counter_div2[7:4] & 
                    sampling_counter[3:0] == sampling_counter_div2[3:0]) begin
                     o_tx_en_div2 <= 1'b1; 
                 end else begin 
                     o_tx_en_div2 <= 1'b0;
                 end
             end
        end
    end

    wire [15:0] divisor_latch_div2;
    reg [15:0]  baud_counter;
    wire [15:0] divisor_latch;
    
    assign divisor_latch = {divisor_latch_msb, divisor_latch_lsb};
        
    assign divisor_latch_div2 = {1'b0, divisor_latch[15:1]};
    
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            baud_counter <= 0;
            o_baudout <= 0;
        end else begin
            if(i_rst_divisor) begin
                baud_counter <= 0;
            end else begin
                if(baud_counter == divisor_latch) begin
                    baud_counter <= 0;
                end else begin
                    baud_counter <= baud_counter + 1;
                end
                //Divide by 16 logic
                if(baud_counter < divisor_latch_div2) begin
                    o_baudout <= 1'b0;
                end else begin
                    o_baudout <= 1'b1;
                end
            end
        end 
    end
    
endmodule



