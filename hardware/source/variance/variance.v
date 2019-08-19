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
//  File Name: variance.v
//  Author   : MDN
// 
//  Description: This module calculates the initial offset values of the 
//  Accelerometer and then subtracts calculated offset value from the 
//  input data, sends normalize data as a output.
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date    |Changes Made:
// V1.0 | MDN           | 04-NOV-13    |Initial version
//-------------------------------------------------------------------------
//  Parameters : 
//-------------------------------------------------------------------------
//   Reuse Issues
//   Reset Strategy   : Asynchronous, active high power on system reset
//   Clock Domains    : i_sys_clk
//   Asynchronous I/F : active high system reset
//   Instantiations   : N/A
//   Other            :     
//-------------------------------------------------------------------------


module  variance( /*AUTOARG*/
                  // Outputs
                  o_variance, o_data_valid, o_mean_value, o_mean_valid,
                  // Inputs
                  i_sys_clk, i_sys_rst, i_data_valid, i_data
                  );
`include "../parameters.h"        
   parameter SUM_WIDTH = DATA_WIDTH + 4;
   
   // Global inputs
   input       i_sys_clk;
   input       i_sys_rst;
   
   //outputs
   output reg [SQR_WIDTH-1:0] o_variance;
   output reg                 o_data_valid;
    output signed[DATA_WIDTH -1 : 0] o_mean_value;
    output                     o_mean_valid;
   
   // Inputs
   input                      i_data_valid;
   input signed [DATA_WIDTH-1:0] i_data;
   
    // Internal signals
    reg signed [SUM_WIDTH:0]      sum_i;
    reg [4:0]                     sample_count_i;
    reg                           rd_en_i;
    wire                          full_i;
    wire                          empty_i;
    wire signed [DATA_WIDTH-1:0]  rddata_i;
    reg signed [DATA_WIDTH-1:0]   mean_value_i;
    wire                          sqr_done_i;
    reg signed [DATA_WIDTH-1:0]   difference_i;
    reg [5:0]                     byte_count_i;
    reg [2:0]                     state_i;
    reg                           data_valid_d1_i;
    reg                           data_valid_d2_i;
    reg                           data_valid_d3_i;
    reg                           sqr_start_i;
    wire [SQR_WIDTH-1:0]          sqr_i;
    reg [SQR_WIDTH +5:0]          sum_variance_i;
    reg                          mean_valid_i;

    assign o_mean_value = mean_value_i;
    assign o_mean_valid = mean_valid_i;
    
  
   //parameters
   parameter IDLE_STATE = 0;
   parameter MEAN_STATE = 1;
   parameter SUMMATION_STATE = 2;
   parameter READ_STATE =3;
   parameter DIFFERENCE_STATE = 4;
   parameter SQUARE_STATE = 5;
   parameter VARIANCE_STATE = 6;

 
   //data valid signal
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         data_valid_d1_i <= 0;
         data_valid_d2_i <= 0;
         data_valid_d3_i <= 0;
      end else begin
         data_valid_d1_i <= i_data_valid;
         data_valid_d2_i <= data_valid_d1_i;
         data_valid_d3_i <= data_valid_d2_i;
      end
   end

    //Sample count
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            sample_count_i <= 0;
        end else if(i_data_valid) begin
            if(sample_count_i == 5'd31)
                sample_count_i <= 0;
            else
                sample_count_i <= sample_count_i + 1;
        end
    end

    //FSM for variance calculation
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            state_i <=IDLE_STATE;
        end else begin
            case(state_i)
                IDLE_STATE:begin
                    if((sample_count_i == 6'd31)&& (i_data_valid))
                        state_i <= MEAN_STATE;
                end
                MEAN_STATE : begin
                    if(data_valid_d1_i)
                        state_i <= READ_STATE;
                end
                SUMMATION_STATE : begin
                    if(byte_count_i == 6'd32)
                        state_i <= VARIANCE_STATE;
                    else
                        state_i <= READ_STATE;
                end
                READ_STATE : begin
                    if(rd_en_i)
                        state_i <= DIFFERENCE_STATE;
                end
                DIFFERENCE_STATE : begin
                    state_i <= SQUARE_STATE;
                end
                SQUARE_STATE : begin
                    if(sqr_done_i) 
                        state_i <= SUMMATION_STATE;
                end
                VARIANCE_STATE : begin
                    state_i <= IDLE_STATE;
                end
                default : state_i <=  IDLE_STATE;
            endcase
        end
    end
    
    //Summation Xn , where n = 32
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            sum_i <= 0;
        end else begin
            if(state_i == DIFFERENCE_STATE)
                sum_i <= 0;
            else if(i_data_valid)
                sum_i <= sum_i + i_data;
        end
    end

   //Mean value Xm = Summation (Xn / n) where n = 32
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         mean_value_i <= 0;
      end else begin
         if(state_i == MEAN_STATE)
           mean_value_i <= sum_i/32;
      end
   end


    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            mean_valid_i <= 0;
        end else begin
            if(state_i == MEAN_STATE)
                mean_valid_i <= 1;
            else
                mean_valid_i <= 0;
        end
    end

    //Read enable to read "n" data from the FIFO to calculate
    //Variance    
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            rd_en_i <= 0;
        end else begin
            case(state_i)
                MEAN_STATE,
                    SUMMATION_STATE: begin
                        rd_en_i <= 1;
                    end
                default : rd_en_i <= 0;
            endcase
        end
    end
    
   //Finding diff -> Xn - Xm  where Xm - mean value of 32 samples
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst)begin
         difference_i <= 0;
      end else begin
         if(state_i == SUMMATION_STATE) begin
            difference_i <= 0;
         end else if(state_i == DIFFERENCE_STATE) begin
            difference_i <= (rddata_i - mean_value_i);
         end
      end
   end                     

   //Counter to count no. of bytes in the window
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         byte_count_i <= 0;
      end else begin
         if(state_i == VARIANCE_STATE)
           byte_count_i <= 0;
         else if(sqr_done_i)
           byte_count_i <= byte_count_i + 1;
      end
   end

   //Start signal for multiplier
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         sqr_start_i <=0;
      end else begin
         if(state_i == SQUARE_STATE)
           sqr_start_i <= 0;
         else if(state_i == DIFFERENCE_STATE)
           sqr_start_i <= 1;
      end
   end

   //summatiom(Xn - Xm) where n = 32, Xm - Mean value calculated
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         sum_variance_i <= 0;
      end else begin
         case(state_i)
           SQUARE_STATE : begin
              if(sqr_done_i)
                sum_variance_i <= sum_variance_i + sqr_i;
           end
           IDLE_STATE:
             sum_variance_i <= 0;
           default : sum_variance_i <= sum_variance_i;
         endcase
      end
   end
    

   //Variance calculation
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         o_variance <= 0;
      end else begin
         if(state_i == VARIANCE_STATE)
           o_variance <= sum_variance_i / 32;
      end
   end

   //Data valid signal
   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         o_data_valid <= 0;
      end else begin
         case(state_i)
           VARIANCE_STATE : begin
              o_data_valid <= 1;
           end
           default : o_data_valid <= 0;
         endcase
      end
   end 

   //FIFO to store 32 data samples
   variance_fifo u_variance_fifo (
                                  // Outputs
                                  .o_RdData                              (rddata_i),
                                  .o_Full                                (full_i),
                                  .o_Empty                               (empty_i),
                                  // Inputs
                                  .i_rst                                 (i_sys_rst),
                                  .i_clk                                 (i_sys_clk),
                                  .i_WrEn                                (i_data_valid),
                                  .i_WrData                              (i_data),
                                  .i_RdEn                                (rd_en_i)
                                  );



   //multiplier (Xn - Xm)^2
   multiplier variance_inst (
                             .i_sys_clk(i_sys_clk),
                             .i_sys_rst(i_sys_rst),
                             .i_multiplicant(difference_i),
                             .i_multiplier(difference_i),
                             .i_start(sqr_start_i),  
                             .o_product(sqr_i),
                             .o_done(sqr_done_i)
                             );
   
   defparam variance_inst.MULTIPLICANT_WIDTH = DATA_WIDTH;
   defparam variance_inst.MULTIPLIER_WIDTH = DATA_WIDTH;
   

endmodule 
