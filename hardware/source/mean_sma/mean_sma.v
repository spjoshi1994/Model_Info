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
//  Project  : LP3.5K_Lenovo_Context_Detection_Demo_HardIP
//  File Name: variance_sma.v
//  Author   : MDN
//-------------------------------------------------------------------------
//  Code Revision History :
//  Ver: | Author        | Mod. Date    |Changes Made:
//  V1.0 | MDN           | 24-07-2013   |
//-------------------------------------------------------------------------
//  Description:This module gives out average of four successive input 
//  accelerometer data along z-axis. Window length defined here is 4.
//-------------------------------------------------------------------------
//  Parameters :WINDOW_LENGTH = 4
//              DATA_WIDTH    = 16
//              MSB_FIRST     = 0
//              BITWIDTH      = 16                           
//-------------------------------------------------------------------------
//  Reuse Issues
//   Reset Strategy   : Asynchronous, active high system level reset
//   Clock Domains    : i_sys_clk
//   Asynchronous I/F : i_sys_rst
//   Instantiations   : fifo
//   Other            : N/A
//-------------------------------------------------------------------------

`timescale 1ns/1ps

module mean_sma (/*AUTOARG*/
                     // Outputs
                     o_sma_data, o_sma_data_valid,
                     // Inputs
                     i_sys_clk, i_sys_rst, i_input_data, i_data_valid
                     );
`include "../parameters.h"        
   parameter WINDOW_LENGTH = 4;
   parameter WINDOW_LENGTH_SHIFT = $clog2(WINDOW_LENGTH);
   parameter SUM_LENGTH = $clog2(WINDOW_LENGTH) + 32;
   parameter MSB_FIRST = 0;
   
    // Global inputs
    input            i_sys_clk;
    input            i_sys_rst;
     
    // Outputs
    output reg signed [DATA_WIDTH-1:0] o_sma_data;
    output reg                        o_sma_data_valid;
     
    // Inputs
    input signed [DATA_WIDTH-1:0]      i_input_data;
    input                             i_data_valid;

    //Internal signal
    wire                              full_i;
    wire                              empty_i;
    reg [1:0]                         byte_count_i;
    reg                               sma_data_valid_i;
    reg [16 - 1 : 0]           shift_z_data_valid_i;
    reg signed [DATA_WIDTH - 1 : 0]    sma_i;
    reg signed [SUM_LENGTH - 1 : 0]   sum_i;
    wire [DATA_WIDTH -1:0]             rddata_i;
    reg signed [DATA_WIDTH - 1 : 0]    first_sample_i;
    reg signed [DATA_WIDTH - 1 : 0]    data_sample_i;
    wire                              sma_rd_en_i;
    reg [2:0]                         sma_sample_count_i;
    reg                               start_sma_i;
    reg                               d1_start_sma_i;
    wire                              sma_wren_i;
    wire                              wr_en_i;
    wire                              rd_en_i;
    reg                               d1_rd_en_i;
    reg                               data_valid_d1_i;
    reg [2:0]                         sample_count_i;
    reg                               enable_sma_output_i;
    reg signed [10:0]                 sample_data_i;

   //Loading valid data samples in to 32 bit register 
   always @ (posedge i_sys_clk or posedge i_sys_rst) begin
      if (i_sys_rst) begin
         data_sample_i <= 0;
      end else begin
         if (i_data_valid) begin
            data_sample_i <= i_input_data;
         end               
      end                   
   end  

   //sample count updates for every word
   //Enables sma clculation when sample count exceeds Window length
   always @ (posedge i_sys_clk or posedge i_sys_rst) begin
      if (i_sys_rst) begin
         sample_count_i <= 0;
         data_valid_d1_i <= 0;
         enable_sma_output_i <= 0;
      end else begin
         data_valid_d1_i <= i_data_valid;
         if (data_valid_d1_i) begin
            sample_count_i <= sample_count_i + 1;
         end

         if(sample_count_i > WINDOW_LENGTH)begin
            enable_sma_output_i <= 1;
         end
      end
   end

   //Generating data valid for z - axis data
   always @ (posedge i_sys_clk or posedge i_sys_rst) begin
      if (i_sys_rst) begin
         sma_data_valid_i <= 1'b0;
      end else begin
         sma_data_valid_i <= i_data_valid;
      end
   end

   always @ (posedge i_sys_clk or posedge i_sys_rst) begin
      if (i_sys_rst) begin
         shift_z_data_valid_i <= 16'b0;
      end else begin
         shift_z_data_valid_i <= {shift_z_data_valid_i[14:0], sma_data_valid_i};
      end
   end

    
   always @ (posedge i_sys_clk or posedge i_sys_rst) begin
      if (i_sys_rst) begin
         sma_sample_count_i <= 3'b00;
      end else begin
         if (sma_data_valid_i) begin
            sma_sample_count_i <= sma_sample_count_i + 1'b1;
         end
      end
   end

   
   always @ (posedge i_sys_clk or posedge i_sys_rst) begin
      if (i_sys_rst) begin
         start_sma_i <= 1'b0;
      end else begin
         if (sma_sample_count_i == 3'b011 && sma_data_valid_i)
           start_sma_i <= 1'b1;
      end
   end

   //Registering start_z_sma_i signal
   always @ (posedge i_sys_clk or posedge i_sys_rst) begin
      if (i_sys_rst) begin
         d1_start_sma_i <= 1'b0;
      end else begin
         d1_start_sma_i <= start_sma_i;
      end
   end

   mean_sma_fifo u_mean_sma_fifo (
                                     // Outputs
                                     .o_RdData                              (rddata_i),
                                     .o_Full                                (full_i),
                                     .o_Empty                               (empty_i),
                                     // Inputs
                                     .i_rst                                 (i_sys_rst),
                                     .i_clk                                 (i_sys_clk),
                                     .i_WrEn                                (wr_en_i),
                                     .i_WrData                              (i_input_data),
                                     .i_RdEn                                (rd_en_i)
                                     );

    /*
     * Write the incoming data stream into FIFO. These data are read after 
     * 4 samples have arrived.
     */
    assign sma_wren_i = i_data_valid; 
    assign wr_en_i =  sma_wren_i;

    /*
     * Read Enable logic
     */
    
    assign sma_rd_en_i = (sma_data_valid_i && start_sma_i);
    assign rd_en_i = sma_rd_en_i;

    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            d1_rd_en_i <= 1'b0;
        end else begin
            d1_rd_en_i <= rd_en_i;
        end
    end

    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            first_sample_i <= 'b0;
        end else begin
            if (d1_rd_en_i) begin
                first_sample_i <= rddata_i;
            end
        end                      
    end                         

    /*
     * SMA Filtering
     * ----------------------
     * sum_new = sum_old - first_sample + data_sample
     * sma = sum_new / 4
     * 
     */
   
    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            sum_i <= 'b0;
        end else begin
            if (shift_z_data_valid_i[2]) begin
                sum_i <= sum_i + data_sample_i - first_sample_i;
            end
        end
    end

   
    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            sma_i <= 0;
        end else begin
            if (shift_z_data_valid_i[3]) begin
                sma_i <= sum_i >>> WINDOW_LENGTH_SHIFT;
            end
        end
    end

    //32 bit SMA data 
    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            o_sma_data <= 0;
        end else begin
            if (shift_z_data_valid_i[5]) begin
                o_sma_data <= sma_i;
            end
        end
    end

    //Depending on BITWIDTH, sma data valid signal is generated
    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            o_sma_data_valid <= 1'b0;
        end else begin
            if (shift_z_data_valid_i[4]) begin
                o_sma_data_valid <= enable_sma_output_i;
            end else begin
                o_sma_data_valid <= 1'b0;
            end
        end
    end 

   
  
endmodule
