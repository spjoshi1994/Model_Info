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
//  File Name: calibration_sma_fifo.v
//  Author   : MDN
//-------------------------------------------------------------------------
//  Code Revision History :
//  Ver: | Author        | Mod. Date    |Changes Made:
//  V1.0 | MDN           | 24-DEC-2013  |                             
//-------------------------------------------------------------------------
//  Description: 
//   FIFO of depth 64 bytes and width 8 bits
//-------------------------------------------------------------------------
//  Parameters :
//   FIFO_DEPTH       : 64
//   DATA_WIDTH       : 11
//   ADDR_WIDTH       : 6
//-------------------------------------------------------------------------
//  Reuse Issues
//   Reset Strategy   : Asynchronous, active high system level reset
//   Clock Domains    : i_clk
//   Asynchronous I/F : i_rst
//   Instantiations   : N/A
//   Other            :     
//-------------------------------------------------------------------------

module sma_eight_fifo (/*AUTOARG*/
             // Outputs
             o_RdData, o_Full, o_Empty,
             // Inputs
             i_clk, i_RdEn, i_rst, i_WrEn, i_WrData
             ) ;
`include "../parameters.h"        
    //Parameters
    parameter FIFO_DEPTH = 64;
    parameter ADDR_WIDTH = 6;
    
    //Global signals
    input i_clk;
    input i_rst;
    //Outputs
    output reg [DATA_WIDTH - 1 : 0] o_RdData;
    output                          o_Full;
    output                          o_Empty;
    //Inputs
    input                           i_RdEn;
    input                           i_WrEn;
    input [DATA_WIDTH - 1 : 0]      i_WrData;

    //Internal wire/reg declarations
    wire                            o_Full;
    wire                            o_Empty;
    reg [ADDR_WIDTH : 0]            wr_addr_i, wr_addr_d1_i, wr_addr_d2_i;
    reg [ADDR_WIDTH : 0]            rd_addr_i, rd_addr_d1_i, rd_addr_d2_i;
    reg [DATA_WIDTH - 1:0]          FIFO_i[0 : FIFO_DEPTH - 1];
    wire                            wr_en_i;
    wire                            rd_en_i;

    assign wr_en_i = i_WrEn & !o_Full;
    assign rd_en_i = i_RdEn & !o_Empty;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // Write Address
    ////////////////////////////////////////////////////////////////////////////////////////////////
    always @ (posedge(i_rst) or posedge(i_clk))
        begin
            if (i_rst)
                wr_addr_i <= 0;
            else if (wr_en_i)
                wr_addr_i <= wr_addr_i + 1'b1;
        end 
    always @ (posedge i_clk)
        wr_addr_d1_i <= wr_addr_i;
    always @ (posedge i_clk)
        wr_addr_d2_i <= wr_addr_d1_i;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    //  Read Address
    ////////////////////////////////////////////////////////////////////////////////////////////////
    always @ (posedge(i_rst) or posedge(i_clk))
        begin
            if (i_rst)
                rd_addr_i <= 0;
            else if (rd_en_i)
                rd_addr_i <= rd_addr_i + 1'b1;
        end 

    always @ (posedge i_clk)
        rd_addr_d1_i <= rd_addr_i;
    always @ (posedge i_clk)
        rd_addr_d2_i <= rd_addr_d1_i;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    //  FIFO Empty Generation logic. It is asserted if the binary read address is 
    //  equal to the converted binary write address
    ////////////////////////////////////////////////////////////////////////////////////////////////
    assign o_Empty = (wr_addr_d2_i == rd_addr_i) ? 1'b1 : 1'b0; //wr_addr_d2_i
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    // FIFO Full Generation Logic. It is asserted if the MSB of the binary write 
    // address is not equal to the MSB of the converted
    // binary read address and the remaining bits of the 2 addresses are equal
    ////////////////////////////////////////////////////////////////////////////////////////////////
    assign o_Full = ((rd_addr_d2_i[ADDR_WIDTH] != wr_addr_i[ADDR_WIDTH]) && 
                     (rd_addr_d2_i[ADDR_WIDTH - 1 : 0] == wr_addr_i[ADDR_WIDTH - 1 : 0])) ? 1'b1 : 
                    1'b0;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // FIFO Write Data
    ////////////////////////////////////////////////////////////////////////////////////////////////
    always @ (posedge i_clk) begin
        
        if (wr_en_i)
            FIFO_i[wr_addr_i[ADDR_WIDTH - 1 : 0]]  <= i_WrData;
    end
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    // FIFO Read Data
    ////////////////////////////////////////////////////////////////////////////////////////////////
    always @ (posedge i_clk) begin
        if (rd_en_i)
            o_RdData  <= FIFO_i[rd_addr_i[ADDR_WIDTH - 1 : 0]]  ;
    end
    

endmodule 
