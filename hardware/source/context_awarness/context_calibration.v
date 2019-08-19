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
//  File Name: context_calibration.v
//  Author   : MDN
//-------------------------------------------------------------------------
//  Code Revision History :
//  Ver: | Author        | Mod. Date    |Changes Made:
//  V1.0 | MDN           | 24-DEC-2013  |
//-------------------------------------------------------------------------
//  Description:This module seperates x,y,z axis data from the acquired sensor
//  data and removes the magnitude of offset data from the magnitude of 
//  calibrated data.                          
//-------------------------------------------------------------------------
//  Reuse Issues
//   Reset Strategy   : Asynchronous, active high system level reset
//   Clock Domains    : i_sys_clk
//   Asynchronous I/F : i_sys_rst
//   Instantiations   : fifo
//   Other            : N/A
//-------------------------------------------------------------------------

module	context_calibration ( /*AUTOARG*/
                              // Outputs
                              o_calibration_done, o_data, o_data_vld,
                              o_calibration_done_pulse_i,                  
                              // Inputs
                              i_sys_clk, i_sys_rst, i_valid, i_data
                              ); 

`include "../parameters.h"      
`ifdef SIM_ONLY
    parameter INITIAL_SAMPLE = 1;
    localparam TOTAL_SAMPLE = INITIAL_SAMPLE + 2;
`else
    parameter INITIAL_SAMPLE = 100;  // Initial samples for sensor to stabilize
    localparam TOTAL_SAMPLE = INITIAL_SAMPLE + 256; // total samples
`endif
    
   parameter DISABLE_CALIBRATION = 0;
   
   //Global inputs
   input	i_sys_clk;
   input	i_sys_rst;

   //outputs
   output 	o_calibration_done_pulse_i;
   output reg 	o_calibration_done;
   output reg 	o_data_vld;    
   output reg signed [DATA_WIDTH - 1:0] o_data;
   
   //Inputs        
   input 				i_valid;
   input [7:0] 				i_data;
  
    // Internal signals
    reg [15:0]  sample_count;  
    reg signed [BIT_WIDTH-1:0] xmin;
    reg signed [BIT_WIDTH-1:0] xmax;
    reg signed [BIT_WIDTH-1:0] ymin;
    reg signed [BIT_WIDTH-1:0] ymax;
    reg signed [BIT_WIDTH-1:0] zmin;
    reg signed [BIT_WIDTH-1:0] zmax;

    reg signed [BIT_WIDTH-1:0] x_data_i;
    reg signed [BIT_WIDTH-1:0] y_data_i;
    reg signed [BIT_WIDTH-1:0] z_data_i;
    reg signed [BIT_WIDTH-1:0] mul_data_i;
    reg signed [BIT_WIDTH-1:0] data_i;
    reg signed [DATA_WIDTH-1:0] xoffset_i;
    reg signed [DATA_WIDTH-1:0] yoffset_i;
    reg signed [DATA_WIDTH-1:0] zoffset_i;
    reg [2:0]                   byte_count_i;
    reg                         x_data_vld_i;
    reg                         y_data_vld_i;
    reg                         z_data_vld_i;
    reg [3:0]                   shift_x_data_vld_i;
    reg [3:0]                   shift_y_data_vld_i;
    reg [3:0]                   shift_z_data_vld_i;
    
    wire signed [BIT_WIDTH-1:0] xoffset_c_i;
    wire signed [BIT_WIDTH-1:0] yoffset_c_i;
    wire signed [BIT_WIDTH-1:0] zoffset_c_i;
    reg                         calibration_done_reg_i;
    
    wire [30:0]                 remain_i;
    reg                         sqr_root_done_reg_i;
    reg [3:0]                   mag_state_i;
    wire                        sqr_done_i;
    reg                         off_mag_done_i;
    reg                         mul_start_i;
    wire [SQR_WIDTH-1:0]        sqr_i;
    reg [SQR_WIDTH-1:0]         x_sqr_reg_i;
    reg [SQR_WIDTH-1:0]         y_sqr_reg_i;
    reg [SQR_WIDTH:0]           acc_sum_i;
    reg                         sqr_root_start_i;
    wire                        sqr_root_done_i;
    wire [DATA_WIDTH-1:0]       square_root_i;
    reg [DATA_WIDTH-1:0]        offset_mag_i;
    reg [DATA_WIDTH-1:0]        calib_mag_i;
    reg                         sqr_root_done_d1_i;
    reg [1:0]                   count_i;
    wire                        calibration_done_pulse_i;
   reg [5:0] 			sample_count_i;
    

   //FSM states to calculate Calib_data-Offset_data
    parameter IDLE_STATE = 0;
    parameter OFFSET_MAG_STATE = 1;
    parameter X_STATE = 2;
    parameter Y_STATE = 3;
    parameter Z_STATE = 4;
    parameter SQUARE_ROOT_STATE = 5;
    parameter CALB_MAG_STATE = 6;
    
    
    //Uusing only 10 bit MSB data of the each axis of sensor data
    //data_i <= [15:6]X-axis,[15:6]Y-axis,[15:6]Z-axis, 
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            data_i <= 0;
        end else begin
            if(i_valid)begin
                data_i <= {i_data[7:0], data_i[BIT_WIDTH-1:BIT_WIDTH-2]};
            end
        end
    end

    //Byte count to count no.of bytes in the raw data and
    //seperate x, y and z axis data from the raw data
    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            byte_count_i <= 0;
        end else begin
            if (i_valid) begin
                if (byte_count_i == 8'd05) begin
                    byte_count_i <= 0;
                end else begin
                    byte_count_i <= byte_count_i + 1;
                end
                
            end
        end
    end // always @ (posedge i_sys_clk or posedge i_sys_rst)

  //X, Y and Z axis data from the raw data 
    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            x_data_i <= 0;
            y_data_i <= 0;
            z_data_i <= 0;
        end else begin
            if (x_data_vld_i) begin
                x_data_i <= data_i;
            end else if (y_data_vld_i) begin
                y_data_i <= data_i;
            end else if (z_data_vld_i) begin
                z_data_i <= data_i;
            end
        end
    end

    //Valid signal generation for X, Y and Z axis data
    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            x_data_vld_i <= 0;
            y_data_vld_i <= 0;
            z_data_vld_i <= 0;
        end else begin
            if (byte_count_i == 8'd01 && i_valid) begin
                x_data_vld_i <= 1'b1;
            end else begin
                x_data_vld_i <= 1'b0;
            end
            if (byte_count_i == 8'd03 && i_valid) begin
                y_data_vld_i <= 1'b1;
            end else begin
                y_data_vld_i <= 1'b0;
            end
            if (byte_count_i == 8'd05 && i_valid) begin
                z_data_vld_i <= 1'b1;
            end else begin
                z_data_vld_i <= 1'b0;
            end
        end
    end

    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            shift_x_data_vld_i <= 0;
            shift_y_data_vld_i <= 0;
            shift_z_data_vld_i <= 0;
        end else begin
            shift_x_data_vld_i <= {shift_x_data_vld_i[2:0], x_data_vld_i};
            shift_y_data_vld_i <= {shift_y_data_vld_i[2:0], y_data_vld_i};
            shift_z_data_vld_i <= {shift_z_data_vld_i[2:0], z_data_vld_i};
        end
    end
    
    //Sample count 
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            sample_count <= 0;
        end else begin
            if(z_data_vld_i)begin   // update smaple count for every new set of raw data
                sample_count <= sample_count + 1;
            end
        end
    end

    //calculating max and min value of the sensor data
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            xmin <= 11'h1FF;  // 512
            ymin <= 11'h1FF;
            zmin <= 11'h1FF;
            xmax <= 11'h200;  // -512
            ymax <= 11'h200;
            zmax <= 11'h200;
        end else begin
            if((sample_count > INITIAL_SAMPLE) && (~o_calibration_done))begin
                if (shift_x_data_vld_i[0]) begin
                    if(xmin > x_data_i)begin
                        xmin <= x_data_i;
                    end
                    if(xmax < x_data_i)begin
                        xmax <= x_data_i;
                    end
                end

                if (shift_y_data_vld_i[0]) begin
                    if(ymin > y_data_i)begin
                        ymin <= y_data_i;
                    end
                    if(ymax < y_data_i)begin
                        ymax <= y_data_i;
                    end
                end

                if (shift_z_data_vld_i[0]) begin
                    if(zmin > z_data_i)begin
                        zmin <= z_data_i;
                    end
                    if(zmax < z_data_i)begin
                        zmax <= z_data_i;
                    end
                end
            end
        end
    end
    
   //Calibration done signal generation after initial 100+256
   //samples
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         o_calibration_done <= DISABLE_CALIBRATION;
      end else begin
         if((sample_count > TOTAL_SAMPLE) && z_data_vld_i)begin
            o_calibration_done <= 1;
         end
      end
   end
    
    //Calibration done pulse to indicate the completion of calibration
    //This signal is sent to AP
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            calibration_done_reg_i <= 0;
        end else begin
            calibration_done_reg_i <= o_calibration_done;
        end
    end

    assign calibration_done_pulse_i =  o_calibration_done && ~calibration_done_reg_i;


    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            count_i <= 0;
        end else begin
            if(count_i >= 2)
                count_i <= 2;
            else if(calibration_done_pulse_i)
                count_i <= count_i + 1;
        end
    end

    assign o_calibration_done_pulse_i = (count_i < 2) ? calibration_done_pulse_i : 0;          

   //Calculation average of max and min value
   //offset = (max+min)/2
   always @(posedge i_sys_clk or posedge i_sys_rst)begin
      if(i_sys_rst)begin
         xoffset_i <= 0;
         yoffset_i <= 0;
         zoffset_i <= 0;
      end else begin
         xoffset_i <= (xmax + xmin) >>> 1;
         yoffset_i <= (ymax + ymin) >>> 1;
         zoffset_i <= (zmax + zmin) >>> 1;
      end
   end

    assign xoffset_c_i = (DISABLE_CALIBRATION) ? 0 : xoffset_i[BIT_WIDTH-1:0];
    assign yoffset_c_i = (DISABLE_CALIBRATION) ? 0 : yoffset_i[BIT_WIDTH-1:0];
    assign zoffset_c_i = (DISABLE_CALIBRATION) ? 0 : zoffset_i[BIT_WIDTH-1:0];


    //FSM to calculate square root(X^2 + Y^2 + Z^2)
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst)begin
            mag_state_i <= IDLE_STATE;
        end else begin
            case(mag_state_i)
                IDLE_STATE : begin
                    if(calibration_done_pulse_i)
                        mag_state_i <= OFFSET_MAG_STATE;
                    else
                        mag_state_i <= IDLE_STATE;
                end
                OFFSET_MAG_STATE: begin
                    mag_state_i <= X_STATE;
                end
                X_STATE : begin
                    if(sqr_done_i)
                        mag_state_i <= Y_STATE;
                end
                Y_STATE : begin
                    if(sqr_done_i)
                        mag_state_i <= Z_STATE;
                end
                Z_STATE : begin
                    if(sqr_done_i)
                        mag_state_i <= SQUARE_ROOT_STATE;
                end            
                SQUARE_ROOT_STATE : begin
                    if(sqr_root_done_i)
                        mag_state_i <= CALB_MAG_STATE;
                end
                CALB_MAG_STATE:begin
                    mag_state_i <= X_STATE;
                end
                default: mag_state_i <= IDLE_STATE;
            endcase
        end
    end

    //offset magnitude done signal
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            off_mag_done_i <= 0;
        end else begin
            case(mag_state_i)
                OFFSET_MAG_STATE : begin
                    off_mag_done_i <= 1;
                end
                CALB_MAG_STATE : begin
                    off_mag_done_i <= 0;
                end
                default : off_mag_done_i <= off_mag_done_i;
            endcase
        end
    end

    //X, Y and Z values for multiplier
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            mul_data_i <= 0;
        end else begin
            case(mag_state_i)
                X_STATE : begin
                    if(off_mag_done_i)
                        mul_data_i <= xoffset_c_i;
                    else if(x_data_vld_i)
                        mul_data_i <= x_data_i;
                    else
                        mul_data_i <= mul_data_i;
                end
                Y_STATE : begin
                    if(off_mag_done_i)
                        mul_data_i <= yoffset_c_i;
                    else if(y_data_vld_i)
                        mul_data_i <= y_data_i;
                    else
                        mul_data_i <= mul_data_i;
                end
                Z_STATE : begin
                    if(off_mag_done_i)
                        mul_data_i <= zoffset_c_i;
                    else if(z_data_vld_i)
                        mul_data_i <= z_data_i;
                    else
                        mul_data_i <= mul_data_i;
                end
                default : mul_data_i <= mul_data_i;
            endcase
        end
    end

    //Multiplication start signal
     always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            mul_start_i <= 0;
        end else begin
            case(mag_state_i)
                X_STATE : begin
                    mul_start_i <= x_data_vld_i;
                end
                Y_STATE : begin
                    mul_start_i <= y_data_vld_i;
                end
                Z_STATE : begin
                    mul_start_i <= z_data_vld_i;
                end
                default : mul_start_i <= 0;
            endcase
        end
     end
    
    
    //X,Y,Z -square
    multiplier mul_inst (
                       .i_sys_clk(i_sys_clk),
                       .i_sys_rst(i_sys_rst),
                       .i_multiplicant(mul_data_i),
                       .i_multiplier(mul_data_i),
                       .i_start(mul_start_i),  
                       .o_product(sqr_i),
                       .o_done(sqr_done_i)
                       );
    defparam mul_inst.MULTIPLICANT_WIDTH = DATA_WIDTH-1;
    defparam mul_inst.MULTIPLIER_WIDTH = DATA_WIDTH-1;

    //x_sqr_reg_i=X^2, y_sqr_reg_i=Y^2
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            x_sqr_reg_i <= 0;
            y_sqr_reg_i <= 0;
        end else begin
            case(mag_state_i)
                X_STATE : begin
                    if(sqr_done_i)
                        x_sqr_reg_i <= sqr_i;
                end
                Y_STATE : begin
                    if(sqr_done_i)
                        y_sqr_reg_i <= sqr_i;
                end
                default : y_sqr_reg_i <= y_sqr_reg_i;
            endcase
        end
    end

  

    //acc_sum_i = X^2 + Y^2 +Z^2
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            acc_sum_i <= 0;
        end else begin
            case(mag_state_i)
                Z_STATE : begin
                    if(sqr_done_i)
                        acc_sum_i <= x_sqr_reg_i + y_sqr_reg_i + sqr_i;
                end
                SQUARE_ROOT_STATE : begin
                    acc_sum_i <= acc_sum_i;
                end
                CALB_MAG_STATE : begin
                    acc_sum_i <= 0;
                end
                default : acc_sum_i <= 0;
            endcase
        end
    end
    
    //Start signal to square root
      always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            sqr_root_start_i <= 0;
        end else begin
            case(mag_state_i)
                Z_STATE : begin
                    if(sqr_done_i)
                        sqr_root_start_i <= 1;
                end
                SQUARE_ROOT_STATE: begin
                    sqr_root_start_i <= 0;
                end
                default : sqr_root_start_i <= 0;
            endcase
        end
    end

    
    //Square root(x^2 + y^2 + z^2)
    squareroot u_inst (
                       .i_clk (i_sys_clk),
                       .i_rst (i_sys_rst),
                       .i_integer(acc_sum_i),
                       .i_start(sqr_root_start_i),
                       .o_squareroot(square_root_i),
                       .o_done(sqr_root_done_i),
                       .o_remain(remain_i)
                       );
    
    //offset magnitude
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            offset_mag_i <= 0;
        end else if(off_mag_done_i) begin
            case(mag_state_i)   
                SQUARE_ROOT_STATE:begin
                    if(sqr_root_done_i)
                        offset_mag_i <= square_root_i;
                end
                default : offset_mag_i <= offset_mag_i;
            endcase
        end
    end


     //calibration magnitude
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            calib_mag_i <= 0;
        end else if(~off_mag_done_i) begin
            case(mag_state_i)   
                SQUARE_ROOT_STATE:begin
                    if(sqr_root_done_i)
                        calib_mag_i <= square_root_i;
                end
                default : calib_mag_i <= calib_mag_i;
            endcase
        end
    end
    
    //
    always @(posedge i_sys_clk or posedge i_sys_rst) begin
        if(i_sys_rst) begin
            sqr_root_done_d1_i <= 0;
        end else begin
            sqr_root_done_d1_i <= sqr_root_done_i;
        end
    end
    

  
        
    //normalized data
    //o_data = magnitude of calib data - magnitude of offset data
    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            o_data <= 0;
        end else begin
            if (sqr_root_done_d1_i)begin
                o_data <= calib_mag_i - offset_mag_i; 
            end
        end
    end

    
    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            sqr_root_done_reg_i <= 0;
        end else begin
            sqr_root_done_reg_i <= sqr_root_done_d1_i;
        end
    end
    
    //output valid signal generation
    always @ (posedge i_sys_clk or posedge i_sys_rst) begin
        if (i_sys_rst) begin
            o_data_vld <= 0;
        end else begin
            if (o_calibration_done && sqr_root_done_reg_i) begin
                o_data_vld <= 1;
            end else begin
                o_data_vld <= 0;
            end                 
        end                   
    end 
   
endmodule
