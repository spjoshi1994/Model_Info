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
//  File Name: step_detection.v
//  Author   : MDN
//-------------------------------------------------------------------------
//  Code Revision History :
//  Ver: | Author        | Mod. Date    |Changes Made:
//  V1.0 | MDN           | 05-MAR-2014  |
//-------------------------------------------------------------------------
//  Description:  The data read is processed for preset
//  thresholds for ZCD and subsequenctly step detection.                        
//-------------------------------------------------------------------------
//  Reuse Issues
//   Reset Strategy   : Asynchronous, active high system level reset
//   Clock Domains    : i_sys_clk
//   Asynchronous I/F : i_sys_rst
//   Instantiations   : fifo
//   Other            : N/A
//-------------------------------------------------------------------------

module step_detection ( /*AUTOARG*/
                        // Outputs
                        o_foot_counter, o_step_detect,
                        // Inputs
                        i_sys_clk, i_sys_rst, i_10khz_clk, i_mean_value, i_mean_valid, i_data_valid,
                        i_sma_data, i_norm_data
                        );
`include "../parameters.h"
    //Global inputs
    input       i_sys_clk;
    input       i_sys_rst;
    input       i_10khz_clk;
    
    // Device interrupt interface
    input signed [DATA_WIDTH-1:0] i_mean_value;
    input                         i_mean_valid;
    input                         i_data_valid;
    input signed [SQR_WIDTH-1 :0] i_sma_data;
    input signed [10:0]           i_norm_data;
    output reg [15:0]             o_foot_counter;
    output                        o_step_detect;
    //internal signals
    reg                           step_detect_i;
    reg [15:0]                    time_counter_i;
    reg [5:0]                     step_count_i;
    reg                           step_en_i;
    reg signed [7:0]              step_count_lower_threshold_i;
    reg signed [7:0]              step_count_upper_threshold_i;
    reg signed [SQR_WIDTH -1:0]   sample_data_i;
    reg signed [SQR_WIDTH -1:0]   sample_data_reg_d1_i;
     reg signed [SQR_WIDTH -1:0]   sample_data_reg_d2_i;
    reg signed [SQR_WIDTH -1 :0]   var_diff_i;
    
   
   reg [2:0] 	       /*synopsys enum state_info*/ sensor_state_i;/*synopsys enum state_vector sensor_state_i*/
   parameter [2:0] /* synopsys enum state_info*/
		STATE_0                    = 0,
		STATE_1                    = 1,
		STATE_2                    = 2,
		STATE_3                    = 3;
endmodule 

