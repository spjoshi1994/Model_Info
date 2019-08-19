//-------------------------------------------------------------------------
//  >>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<<<
//-------------------------------------------------------------------------
//         Copyright (c) 2012 by Lattice Semiconductor Corporation      
// 
//-------------------------------------------------------------------------
// Permission:
//
//   Lattice Semiconductor grants permission to use this code for use
//   in synthesis for any Lattice programmable logic product.Other
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
//
//-------------------------------------------------------------------------
//   Lattice Semiconductor Corporation
//   5555 NE Moore Court
//   Hillsboro, OR 97124
//   U.S.A
//
//   TEL: 1-800-Lattice (USA and Canada)
//   503-268-8001 (other locations)
//
//   web: http://www.latticesemi.com/
//   email: techsupport@latticesemi.com
//
// -------------------------------------------------------------------------
//  Project   : LP3.5K_Pedometer_with_BLE_Interface
//  File Name : multiplier.v
//  Author    : MDN
//
//--------------------------------------------------------------------------
//  Code Revision History :
//  Ver:         | Author       | Mod. Date    |Changes Made:
//  V1.0         | MDN          | 24-DEC-2013   |  
//                            
//--------------------------------------------------------------------------
//  Description:  Top module for multiplier
//--------------------------------------------------------------------------
//  Parameters : MULTIPLIER_WIDTH=16
//               MULTIPLICAND_WIDTH=DATA_WIDTH-1
//               TWOSCOMP=1
//               OURPUTREGISTERD=0
//--------------------------------------------------------------------------
//  Reuse Issues
//   Reset Strategy   : Asynchronous, active high power on reset 
//   Clock Domains    : i_clk
//   Asynchronous I/F : i_rst,i_start
//   Instantiations   : none
//   Other            :     
//--------------------------------------------------------------------------  
module multiplier(//global inputs
		  i_sys_clk,i_sys_rst,
		  //outputs
		  o_product,o_done,
		  //input
		  i_multiplicant,i_multiplier,i_start
		  );
`include "../parameters.h"
    //parameter declarations
    parameter MULTIPLICANT_WIDTH = 16;       //width for multiplicant
    parameter MULTIPLIER_WIDTH =DATA_WIDTH-1;        //width for multiplier
    parameter TWOSCOMP=1;                  //'1'=signed multiplication and '0'=unsigned multiplication 
    parameter OUTPUTREGISTERED=0;         //'1'=registered output and '0'=unregistered output
    parameter PRODUCT_WIDTH =(MULTIPLICANT_WIDTH+MULTIPLIER_WIDTH);   //width of the product  
    
    //global inputs
    input i_sys_clk;
    input i_sys_rst;

    //outputs
    output [PRODUCT_WIDTH-1:0] o_product;
    output                     o_done;             //indicates end of multiplication

    //input			 
    input [MULTIPLICANT_WIDTH-1:0] i_multiplicant;
    input [MULTIPLIER_WIDTH-1:0]   i_multiplier;
    input                          i_start;      //indicates start of multiplication
    
   //passing the parameters and inputs to the sequential multiplier  
   generate
       if(MULTIPLIER_WIDTH <= MULTIPLICANT_WIDTH)  begin
           multiplier_seq #(MULTIPLICANT_WIDTH, MULTIPLIER_WIDTH,TWOSCOMP,OUTPUTREGISTERED) 
           UUT 
             (
              .i_clk(i_sys_clk),
              .i_rst(i_sys_rst),
              .i_multiplicant(i_multiplicant),
              .i_multiplier(i_multiplier),
              .i_start(i_start),  
              .o_product(o_product),
              .o_done(o_done)
              );
           
       end
   endgenerate

   //passing of swapped parameter and inputs to sequential multipier
   generate
       if(MULTIPLIER_WIDTH > MULTIPLICANT_WIDTH)  begin
           multiplier_seq #(MULTIPLIER_WIDTH, MULTIPLICANT_WIDTH, TWOSCOMP, OUTPUTREGISTERED) 
           UUT 
             (
              .i_clk(i_sys_clk),
              .i_rst(i_sys_rst),
              .i_multiplicant(i_multiplier),
              .i_multiplier(i_multiplicant),
              .i_start(i_start),  
              .o_product(o_product),
              .o_done(o_done)
              );
           
       end
   endgenerate

endmodule // multiplier
