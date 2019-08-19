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
//  Project  : LP3.5K_Lenovo_Context_Detection_Demo_HardIP
//  File Name: parameters.h
// 
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date     |Changes Made:
// V1.0 | MDN           | 24SDEC2013    |Initial design
//-------------------------------------------------------------------------  
//  Description: This file contains the list of parameters.                      
//
// Reuse issues
// Reset strategy   : 
// Clock domains    : 
// Asynchronous IF  : 
// -------------------------------------------------------------------------   

parameter DATA_WIDTH = 11;
parameter BIT_WIDTH = 10;
parameter SQR_WIDTH = 2*(DATA_WIDTH-1);

`ifdef SIM_ONLY

localparam IDLE_THRESHOLD = 2;
localparam WALKING_LOWER_THRESHOLD = 100;
localparam WALKING_UPPER_THRESHOLD = 4500;
localparam RUNNING_LOWER_THRESHOLD = 4500;

`else                          

localparam IDLE_THRESHOLD = 2;
localparam WALKING_LOWER_THRESHOLD = 500;
localparam WALKING_UPPER_THRESHOLD = 4500;
localparam RUNNING_LOWER_THRESHOLD = 4500;

`endif
