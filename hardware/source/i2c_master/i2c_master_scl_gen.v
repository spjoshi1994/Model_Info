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
//  File Name: i2c_master_scl_gen.v
// 
//  Description: I2C clock generation module. This supports clock stretching
//  by the salve device.
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date    |Changes Made:
// V1.0 | MDN           | 03-Nov-12    |Initial version                             
//-------------------------------------------------------------------------
  
`timescale 1 ns / 1 ps

module i2c_master_scl_gen(
    // Global inputs
    i_sys_clk, i_sys_rst,
    /*AUTOARG*/
    // Outputs
    o_scl_configured, o_scl_address, o_scl_txdata, o_scl_strobe, o_scl_wr_n,
    // Inputs
    i_configure_scl, i_clk_div_factor, i_scl_strobe_ack
    );

    // Parameters
    // FSM states
    parameter IDLE     = 0;
    parameter STATE_1  = 1;
    parameter STATE_2  = 2;
    parameter STATE_3  = 3;

    // Global inputs
    input          i_sys_clk;
    input          i_sys_rst;

    // Outputs
    output         o_scl_configured;
    output [7:0]   o_scl_address;
    output [7:0]   o_scl_txdata;
    output         o_scl_strobe;
    output         o_scl_wr_n;

    // Inputs
    input          i_configure_scl;
    input [10:0]   i_clk_div_factor;
    input          i_scl_strobe_ack;

    // Internal signals
    reg [4:0]      state_i;
    wire           terminate_strobe_i;
    wire           switch_state_i;
    reg [3:0]      cycle_count_i;
    reg [7:0]      address_i;
    reg [7:0]      tx_data_i;
    reg            strobe_i;
    reg            wr_n_i;

    assign o_scl_address = address_i;
    assign o_scl_txdata  = tx_data_i;
    assign o_scl_strobe  = strobe_i;
    assign o_scl_wr_n    = wr_n_i;
    assign o_scl_configured = (state_i == STATE_3);
    
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
                    if(i_configure_scl)begin 
                        state_i <= STATE_1;
                    end
                    tx_data_i <= 0;
                    address_i <= 0;
                    strobe_i <= 0;
                    wr_n_i <= 0;
                end

                //Write Clock prescale register LSB
                STATE_1:begin 
                    if(switch_state_i)begin
                        state_i <= STATE_2;
                    end
                    tx_data_i <= i_clk_div_factor[7:0];
                    address_i <= 8'b0000_1010;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                //Write Clock prescale register MSB
                STATE_2:begin 
                    if(switch_state_i)begin
                        state_i <= STATE_3;
                    end
                    tx_data_i <= {5'd0, i_clk_div_factor[10:8]};
                    address_i <= 8'b0000_1011;
                    wr_n_i <= 1'b1;
                    
                    if(terminate_strobe_i)begin
                        strobe_i <= 1'b0;
                    end else begin
                        strobe_i <= 1'b1;
                    end
                end

                STATE_3:begin 
                    if(~i_configure_scl)begin
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

