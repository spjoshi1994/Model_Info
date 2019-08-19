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
//  File Name: uart_reg_fsm.v
//  Author   : MDN
//-------------------------------------------------------------------------
//  Code Revision History :
//  Ver: | Author        | Mod. Date    |Changes Made:
//  V1.0 | MDN           | 01-FEB-2014  |
//-------------------------------------------------------------------------
//  Description : FSM to send ISR bit to UART Tx module
//-------------------------------------------------------------------------
//  Parameters :none                           
//-------------------------------------------------------------------------
//  Reuse Issues
//   Reset Strategy   : Asynchronous, active high system level reset
//   Clock Domains    : i_sys_clk
//   Asynchronous I/F : i_sys_rst
//   Instantiations   : none
//   Other            : N/A
//-------------------------------------------------------------------------
module uart_reg_fsm (/*AUTOARG*/
                     // Outputs
                     o_tx_start, o_tx_data,
                     // Inputs
                     i_sys_clk, i_sys_rst, i_ready, i_step_intr, i_send_isr, i_foot_counter,
                     i_rx_data, i_rx_data_valid, i_tsr_empty
                     );


    //System level Inputs
    input i_sys_clk;
    input i_sys_rst;

    //interrupt from sensor data
    input i_ready;
    input i_step_intr;
    input i_send_isr;
    input [15:0] i_foot_counter;
    
    //Interface with UART
    input wire [7:0] i_rx_data;
    input wire       i_rx_data_valid;
    output           o_tx_start;
    output reg [7:0] o_tx_data;
    input wire       i_tsr_empty;
   
    reg [7:0]        isr_i;
    reg [7:0]        auto_isr_i;
    reg              intr_ap_i;
    reg [11:0]       intr_count_i; 
    reg [3:0]        state_i;
    reg              tx_start_i;
    wire             isr_read_i;
    wire             tsr_empty_pulse_i;
    reg              tsr_empty_reg_i;
    reg              isr_send_reg_i;
    wire             isr_send_pulse_i;

    parameter  IDLE_STATE = 0;
    parameter  SEND_ISR = 1;
    parameter  RESET_TX_START = 2;  
    parameter  STEP_COUNT_STATE = 3;
    parameter  SEND_STEP_COUNT_LSB = 4;
    parameter  RESET_TX_START_STEP_LSB =5;
    parameter  SEND_STEP_COUNT_MSB = 6;
    parameter  RESET_TX_START_STEP_MSB = 7;
    parameter  RESET_ISR_STATE = 8;
   
   assign o_tx_start =  tx_start_i;
   
   /*
    * Processor interrupt mechanism
    */
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst )begin
         isr_i <= 0;
      end else begin
         if(state_i == RESET_ISR_STATE)begin
            isr_i <= 8'h00;
         end
         
         if(i_step_intr)
           isr_i[3] <= 1;
         
         if(i_ready) begin         //0x0010
            isr_i[4] <= 1;       //ready after calubration is done
            isr_i[6] <= 0;
         end
      end
   end                           

   //interrupt to AP              
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         intr_ap_i <= 0;
      end else begin
         if(i_ready || i_step_intr )begin
            intr_ap_i <= 1;
         end else begin
            intr_ap_i <= 0;
         end
      end
   end
   

    //Interrupt counter to reset o_int
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            intr_count_i <= 0;
        end else begin
            if(intr_ap_i)begin
                intr_count_i <= intr_count_i + 1;
            end else begin
                intr_count_i <= 0;
            end
        end
    end
   
   //FSM to send data 
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         state_i <= IDLE_STATE;
      end else begin
         case(state_i)
	   
           IDLE_STATE : begin
              if(intr_ap_i)
                state_i <= SEND_ISR;
           end
           SEND_ISR : begin
              state_i <= RESET_TX_START;
           end
           RESET_TX_START : begin
              if(tsr_empty_pulse_i)
                state_i <= STEP_COUNT_STATE;
           end
           STEP_COUNT_STATE : begin
              if(isr_i[3] == 1)
                state_i <= SEND_STEP_COUNT_LSB;
              else
                state_i <= RESET_ISR_STATE;
           end
           SEND_STEP_COUNT_LSB : begin
              state_i <= RESET_TX_START_STEP_LSB;
           end
           RESET_TX_START_STEP_LSB : begin
              if(tsr_empty_pulse_i)
                state_i <= SEND_STEP_COUNT_MSB;
           end
           SEND_STEP_COUNT_MSB : begin
              state_i <= RESET_TX_START_STEP_MSB;
           end
           RESET_TX_START_STEP_MSB : begin
              if(tsr_empty_pulse_i)
                state_i <= RESET_ISR_STATE;
           end
           RESET_ISR_STATE : begin
              state_i <= IDLE_STATE;
           end
           
           default : state_i <= IDLE_STATE;
         endcase
      end
   end

   //tsr_empty pulse generation
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         tsr_empty_reg_i <= 0;
      end else begin
         tsr_empty_reg_i <= i_tsr_empty;
      end
   end
   
   assign tsr_empty_pulse_i = i_tsr_empty && (~tsr_empty_reg_i);

   //tx_start_i generation
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         tx_start_i <= 0;
      end else begin
         case(state_i)
           SEND_ISR,
             SEND_STEP_COUNT_LSB,
             SEND_STEP_COUNT_MSB : begin
                if(i_tsr_empty)
                  tx_start_i <= 1;
                else
                  tx_start_i <= 0;
             end
           default :begin
              if(i_tsr_empty)
                tx_start_i <= isr_send_pulse_i;
           end             
         endcase
      end
   end

   //o_tx_data
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin           
         o_tx_data <= 0;
      end else begin
         case(state_i)
	   
           SEND_ISR : begin
              o_tx_data <= isr_i;
           end
           SEND_STEP_COUNT_LSB : begin
              o_tx_data <= i_foot_counter[7:0];
           end
           SEND_STEP_COUNT_MSB : begin
              o_tx_data <= i_foot_counter[15:8];
           end            
           default: begin
              o_tx_data <= auto_isr_i;
           end
         endcase
      end
   end

   //To send ISR bit for every 10 sec
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         auto_isr_i <= 0;
      end else begin
         case(state_i)
           SEND_ISR :  begin
              auto_isr_i <= isr_i;
           end
           default :
             auto_isr_i <= auto_isr_i;
         endcase
      end
   end

   // pulse generating for tx start signal
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst) begin
         isr_send_reg_i <= 0;
      end else begin
         isr_send_reg_i <= i_send_isr;
      end
   end

   assign isr_send_pulse_i = i_send_isr && ~isr_send_reg_i;
   
   
   
   // Beginning of automatic ASCII enum decoding
   reg [247:0]         state_ascii_i;// Decode of uart_gsm_bridge_fsm_i
   always @(state_i) begin
      case ({state_i})
        IDLE_STATE:                      state_ascii_i = "idle_state";
        SEND_ISR:                        state_ascii_i = "send_isr";
        RESET_TX_START:                  state_ascii_i = "reset_tx_start";
        STEP_COUNT_STATE:                state_ascii_i = "step_count_state";
        SEND_STEP_COUNT_LSB:             state_ascii_i = "send_step_count_lsb";
        RESET_TX_START_STEP_LSB:         state_ascii_i = "reset_tx_start_step_lsb";
        SEND_STEP_COUNT_MSB:             state_ascii_i = "send_step_count_msb";
        RESET_TX_START_STEP_MSB:         state_ascii_i = "reset_tx_start_step_msb";
        RESET_ISR_STATE:                 state_ascii_i = "reset_isr_state";
        default:                         state_ascii_i = "%Error";
      endcase
   end

endmodule
