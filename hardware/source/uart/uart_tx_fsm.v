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
//  File Name: uart_tx_fsm.v
//  Author   : MDN
//-------------------------------------------------------------------------
//  Code Revision History :
//  Ver: | Author        | Mod. Date    |Changes Made:
//  V1.0 | MDN           | 01-FEB-2014  |
//-------------------------------------------------------------------------
// Description :
// a.Waits for the start operations signal from the UART Master Controller block
// b.Generates the start signal on the o_serial_data line
// c.Serializes the CPU data and sends it to the MODEM
// d.Adds a parity bit if required
// e.Adds the required number of stop bits
// f.Waits for another pulse on the i_start_tx before begining a fresh operation 
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
module uart_tx_fsm(
                   // System clock
                   // asynchronous active high reset 
                   input wire        i_clk,
                   input wire        i_rst,
                   //Tx data from CPU    
                   input wire [7:0]  i_tx_data,
                   //Tx FSM Control signal from Master Controller
                   input wire        i_start_tx,
                   input wire        i_break_control,
                   input wire        i_tx_en,
                   input wire        i_tx_en_div2,
                   output reg        o_tx_en_stop,
                   //Tx configurations from Master Controller                  
                   input wire        i_stop_bit_15,
                   input wire        i_stop_bit_2,
                   input wire        i_parity_even,
                   input wire        i_parity_en,               
                   input wire [1:0]  i_no_of_data_bits,  
                   input wire        i_stick_parity_en,
                   //Transmit shift register empty
                   output wire       o_tsr_empty,
                   //Serial data out to MODEM    
                   output wire       o_serial_data
                   );
    
    parameter [3:0]/*synopsys enum state_info*/ IDLE_STATE        = 4'b0000,
                   START_GEN_STATE   = 4'b1101,
                   Tx_1BIT_STATE     = 4'b0001,
                   Tx_2BIT_STATE     = 4'b0010,
                   Tx_3BIT_STATE     = 4'b0011,
                   Tx_4BIT_STATE     = 4'b0100,
                   Tx_5BIT_STATE     = 4'b0101,
                   Tx_6BIT_STATE     = 4'b0110,
                   Tx_7BIT_STATE     = 4'b0111,
                   Tx_8BIT_STATE     = 4'b1000,
                   ADD_PARITY_STATE  = 4'b1001,
                   STOP_GEN1_STATE   = 4'b1010,
                   STOP_GEN15_STATE  = 4'b1011,
                   STOP_GEN2_STATE   = 4'b1100;
    
    //Internal signals 
    reg [3:0]                        /*synopsys- enum state_info*/  state; /*synopsys enum state_vector state*/    
    reg                              start_tx;
    reg [7:0]                        tx_data;
    reg                              parity_bit;
    reg                              check_bit;  
    reg                              serial_data;
    reg                              break_control_en;
    reg                              tsr_empty;
        
    //synchronizer
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin          
            start_tx        <= 1'b0;         
        end else begin          
            start_tx        <= i_start_tx;          
        end 
    end // always @ (posedge i_clk or posedge i_rst)

    always@(posedge i_clk or posedge i_rst) begin
         if(i_rst) begin
             tx_data <= 8'b0000_0000;
         end else begin
             if(i_start_tx) begin
                 tx_data <= i_tx_data;
             end
         end
    end
    
    assign o_tsr_empty = tsr_empty;

    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst)  begin
            tsr_empty <= 1'b1;       
        end else begin
            case(state)
                START_GEN_STATE :
                    if(i_tx_en)
                        tsr_empty <= 1'b0;
                
                IDLE_STATE :
                    tsr_empty <= 1'b1;
                
                default :
                    tsr_empty <= tsr_empty;
             endcase
        end
    end // @ (posedge i_clk or posedge i_rst) 
         
    ////////////////////////////////////////////////////////////////
    // UART Tx FSM
    ////////////////////////////////////////////////////////////////
    
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            state <= IDLE_STATE; 
            serial_data <= 1'b1;  
        end else begin
            case(state)
                //Wait for start_tx signal from UART Master Controller to begin 
                IDLE_STATE   : 
                    if(start_tx) begin
                        state <= START_GEN_STATE;
                        serial_data <= 1'b1;
                    end    
                
                START_GEN_STATE :
                    if(i_tx_en) begin
                        state <= Tx_1BIT_STATE;
                        serial_data <= 1'b0;
                    end    
                
                Tx_1BIT_STATE     : 
                    if(i_tx_en) begin
                        state <= Tx_2BIT_STATE;
                        serial_data <= tx_data[0];
                    end    
                
                
                Tx_2BIT_STATE     : 
                    if(i_tx_en) begin
                        state <= Tx_3BIT_STATE;
                        serial_data <= tx_data[1];
                    end 
                
                Tx_3BIT_STATE     :
                    if(i_tx_en) begin
                        state <= Tx_4BIT_STATE;
                        serial_data <= tx_data[2];
                    end
                
                Tx_4BIT_STATE     : 
                    if(i_tx_en) begin
                        state <= Tx_5BIT_STATE;
                        serial_data <= tx_data[3];
                    end
                
                //Check for no of bits in operation
                //If 5 bits, then check if parity is required else go to stop state                      
                Tx_5BIT_STATE     :
                    if(i_tx_en) begin
                        serial_data <= tx_data[4];                                      
                        if(i_no_of_data_bits == 2'b00) begin
                            if (i_parity_en) begin
                                state <= ADD_PARITY_STATE;
                            end else begin
                                state <= STOP_GEN1_STATE;
                            end 
                        end else begin
                            state <= Tx_6BIT_STATE;    
                        end
                    end // if (i_tx_en)
                
                //Check for no of bits in operation
                //If 6 bits, then check if parity is required else go to stop state 
                Tx_6BIT_STATE     :
                    if(i_tx_en) begin
                        serial_data <= tx_data[5];                                                                         
                        if(i_no_of_data_bits == 2'b01) begin
                            if (i_parity_en) begin
                                state <= ADD_PARITY_STATE;
                            end else begin
                                state <= STOP_GEN1_STATE;
                            end 
                        end else begin
                            state <= Tx_7BIT_STATE;
                        end
                    end // if (i_tx_en)
                
                //Check for no of bits in operation
                //If 7 bits, then check if parity is required else go to stop state                    
                Tx_7BIT_STATE     :                    
                    if(i_tx_en) begin
                        serial_data <= tx_data[6];                                                                         
                        if(i_no_of_data_bits == 2'b10) begin
                            if (i_parity_en) begin
                                state <= ADD_PARITY_STATE;
                            end else begin
                                state <= STOP_GEN1_STATE;
                            end 
                        end else begin
                            state <= Tx_8BIT_STATE;                                      
                        end
                    end
                
                //Check if parity is required else go to stop state
                Tx_8BIT_STATE     :
                    if(i_tx_en) begin
                        serial_data <= tx_data[7];
                        if (i_parity_en) begin
                            state <= ADD_PARITY_STATE;
                        end else begin
                            state <= STOP_GEN1_STATE;
                        end
                    end   
                
                ADD_PARITY_STATE  :
                    if(i_tx_en) begin
                        serial_data <= parity_bit;
                        state <= STOP_GEN1_STATE;
                    end     
                
                //Check for no of stop bits required and proceed  
                STOP_GEN1_STATE   :
                    begin
                        if(i_tx_en) begin
                            serial_data <= 1'b1;
                            if (i_stop_bit_15) begin
                                state <= STOP_GEN15_STATE;
                            end else if(i_stop_bit_2) begin
                                state <= STOP_GEN2_STATE;
                            end else begin
                                state <= IDLE_STATE;
                            end
                        end   
                    end // case: STOP_GEN1_STATE
                
                STOP_GEN15_STATE :
                    if(i_tx_en_div2) begin
                        serial_data <= 1'b1;
                        state <= IDLE_STATE;
                    end    
                
                STOP_GEN2_STATE   :
                    if(i_tx_en) begin
                        serial_data <= 1'b1;
                        state <= IDLE_STATE; 
                    end    
                
                default           : 
                    state <= IDLE_STATE; 
                
                
            endcase
        end
    end // always @ (posedge i_clk or posedge i_rst)

   //////////////////////////////////////////////////////////
   //Baud rate clock generation logic
   /////////////////////////////////////////////////////////
   
    always @(posedge i_clk or posedge i_rst) begin 
        if(i_rst) begin
            break_control_en <= 1'b0;
        end else begin
            if (state == START_GEN_STATE) begin
                if(i_break_control) 
                    break_control_en <= 1'b1;
                else
                    break_control_en <= 1'b0;
            end
        end // else: !if(i_rst)
    end // always @ (posedge i_clk or posedge i_rst)
        
    assign o_serial_data = (!break_control_en) ? serial_data : 1'b0;
    
    ////////////////////////////////////////////////////////// 
    //Tx enable logic
    //enable stopped when in Idle state and enabled once Tx_start is issued by master controller
    ////////////////////////////////////////////////////////// 
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            o_tx_en_stop  <= 1'b0;
        end else begin
            case (state) 
                IDLE_STATE : begin
                    o_tx_en_stop <= 1'b1;
                end
                default : begin
                    o_tx_en_stop <= 1'b0;
                end
            endcase // case (state)
        end
    end // always @ (posedge i_clk or posedge i_rst)  

    /////////////////////////////////////////////////////////////////////////////
    // Parity bit determinatin 
    /////////////////////////////////////////////////////////////////////////////

    always @(posedge i_clk or posedge i_rst)
        begin
            if(i_rst) 
                check_bit <= 1'b0;
            else 
                begin
                    case(i_no_of_data_bits)
                        //5 bit tx data..
                        2'b00 :
                            check_bit <= ^(tx_data[4:0]);
                        //6 bit tx data..
                        2'b01 :
                            check_bit <= ^(tx_data[5:0]);
                        //7 bit tx data..
                        2'b10 :
                            check_bit <= ^(tx_data[6:0]);
                        //8 bit tx data..
                        2'b11 :
                            check_bit <= ^(tx_data);           
                    endcase
                end
        end // always @ (posedge i_clk or posedge i_rst)

    always @(posedge i_clk or posedge i_rst)
        begin
            if(i_rst) begin 
                parity_bit <= 1'b0;
            end else begin
                if(i_parity_even & !i_stick_parity_en) 
                    parity_bit <= check_bit;
                else if(!i_parity_even & !i_stick_parity_en)
                    parity_bit <= !check_bit;
                else if(i_parity_even & i_stick_parity_en)
                    parity_bit <= 1'b0;
                else 
                    parity_bit <= 1'b1;
            end
        end // always @ (posedge i_clk or posedge start_tx)
    
    
    /*AUTOASCIIENUM("state" "state_ASCII")*/
    // Beginning of automatic ASCII enum decoding
    reg [127:0]          state_ASCII;            // Decode of state
    always @(state) begin
        case ({state})
            IDLE_STATE:       state_ASCII = "idle_state      ";
            START_GEN_STATE:  state_ASCII = "start_gen_state ";
            Tx_1BIT_STATE:    state_ASCII = "tx_1bit_state   ";
            Tx_2BIT_STATE:    state_ASCII = "tx_2bit_state   ";
            Tx_3BIT_STATE:    state_ASCII = "tx_3bit_state   ";
            Tx_4BIT_STATE:    state_ASCII = "tx_4bit_state   ";
            Tx_5BIT_STATE:    state_ASCII = "tx_5bit_state   ";
            Tx_6BIT_STATE:    state_ASCII = "tx_6bit_state   ";
            Tx_7BIT_STATE:    state_ASCII = "tx_7bit_state   ";
            Tx_8BIT_STATE:    state_ASCII = "tx_8bit_state   ";
            ADD_PARITY_STATE: state_ASCII = "add_parity_state";
            STOP_GEN1_STATE:  state_ASCII = "stop_gen1_state ";
            STOP_GEN15_STATE: state_ASCII = "stop_gen15_state";
            STOP_GEN2_STATE:  state_ASCII = "stop_gen2_state ";
            default:          state_ASCII = "%Error          ";
        endcase
    end
    // End of automatics

endmodule // uart_tx_fsm


