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
//  File Name: LSM330DLC_accl.v
//
//  Description: This module configures the LSM330 sensor and reads
//  acquired data from the sensor. 
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date    |Changes Made:
// V1.0 | MDN           | 06-MAR-13    |Initial version
//-------------------------------------------------------------------------

module  LSM330DLC_accl ( /*AUTOARG*/
			 // Outputs
			 o_disable_clk_27m,o_read_data_vld,
			 o_i2c_start,o_read_write_n,o_slave_address,o_read_byte_count,o_reg_address,o_write_data,
			 o_intr,
			 // Inputs
			 i_sys_clk, i_sys_rst, i_clk_10khz, i_step_intr_ack,
			 i_read_data,i_read_data_valid,i_i2c_done,i_intr_ack
			 );
  //Global inputs
   input       i_sys_clk;
   input       i_sys_rst;
   input       i_clk_10khz;
    
   //Inputs
   input 	i_step_intr_ack;
   input 	i_intr_ack;
   input [7:0] 	i_read_data;
   input 	i_read_data_valid;
   input 	i_i2c_done;

   //Outputs
   output reg 	o_i2c_start;
   output reg 	o_read_write_n;
   output [7:0] o_slave_address;
   output reg [7:0] o_read_byte_count;
   output reg [7:0] o_reg_address;
   output reg [7:0] o_write_data;
   output 	    o_intr;
   output 	    o_disable_clk_27m;
   output  reg 	    o_read_data_vld;

  

    reg [3:0]    /*synopsys enum state_info*/ sensor_state_i;/*synopsys enum state_vector sensor_state_i*/
    parameter [3:0] /* synopsys enum state_info*/
        IDLE                       = 0,
        READ_CALIBRATION           = 1,
        WAIT_FOR_CALIBRATION_BYTE  = 2,
        CTRL_REG1_A                = 3,
        CTRL_REG4_A                = 4,
        DATA_ACQUIRE               = 5,
        READ_ACCEL_VALUE           = 6,
        WAIT_FOR_ACCEL_VALUE       = 7,
        REG_DATA_STATE             = 8,
        WAIT_STATE                 = 9,
        ZERO_CROSS_DETECT          = 10,
        UPDATE_VALUE               = 11,
        MAX_VALUE_DETECT           = 12,
        STEP_DETECT                = 13,
        WAIT_42ms_STATE            = 14;

    parameter INTR_THRESHOLD = 32'h300000;
    parameter INIT_THRESHOLD = 32'h28_A640;
    parameter DURATION_42_MS = 9'h128; // This is no longer 42ms as the constant says. 
    parameter RDID_EN = 0;
    parameter SENSOR_BYTE_COUNT = 6;
    parameter INTERRUPT_COUNT = 8'd01;
    parameter I2C_SLAVE_ADDRESS = 8'h19;
    parameter INTR_EN = 1;
    parameter [10:0] CLK_DIV_COUNT = 72;

    /*
     * LSM330DLC Register Data
     */
    parameter CTRL_REG1_DATA1 = 8'h00;
    parameter CTRL_REG1_DATA2 = 8'hC2;
    parameter CTRL_REG2_DATA  = 8'h07;
    parameter INTR_CTRL_REG1_DATA1 = 8'h30;  // Intr latches till it is cleared by reading INT_REL
    parameter INTR_CTRL_REG1_DATA2 = 8'h38;  // Intr is a pulse of 0.03 - 0.05 ms
    parameter INTR_CTRL_REG2_DATA  = 8'h3F;
    parameter WAKEUP_TIMER_DATA    = 8'h0A;  // Time for which motion should persist to be recognized as motion by the sensor
    parameter WAKUP_THRESHOLD_DATA = 8'h04;
   
   //Wire and registers declaration
   wire 	 init_time_i;
   wire 	 timeout_i;
   wire 	 rst_i;
   wire 	 trig_acquisition_i;
   reg [23:0] 	 time_counter_i;
   reg [3:0] 	 interrupt_counter_i;
   reg 		 data_valid_i;
   reg [2:0] 	 i2c_read_byte_cnt_i ;
   reg 		 sensor_intr_i;
   reg 		 data_valid_reg_i;
   reg [7:0] 	 wait_42ms_cnt_i;
   reg 		 d1_wait_42ms_done_i;
   reg 		 wait_42ms_done_i;
   reg 		 disable_clk_27m_during_time_count_i;
   reg 		 disable_clk_27m_during_wait_count_i;
   reg [3:0] 	 timeout_cnt_i;
   reg [2:0] 	 byte_count_i;  
   reg [7:0] 	 word_count_i;
   reg 		 data_acquire_state_i;
   reg 		 data_acquire_state_int_i;
   reg 		 d1_data_acquire_state_int_i;
   reg 		 idle_state_i;
   reg 		 idle_state_int_i;
   reg 		 d1_idle_state_int_i;
   reg 		 wait_42ms_state_i;
   reg 		 wait_42ms_state_int_i;
   reg 		 d1_wait_42ms_state_int_i;
   reg 		 o_intr;

    assign rst_i = i_sys_rst ;
    assign o_slave_address = I2C_SLAVE_ADDRESS;

    // trigger signal to data aquire
    assign trig_acquisition_i = sensor_intr_i; //&& ~o_intr;

    always @(posedge i_sys_clk or posedge rst_i)begin
        if(rst_i)begin
            sensor_intr_i <= 0;
        end else begin
            if(sensor_state_i == DATA_ACQUIRE)begin
                if(time_counter_i[9:1] == INTR_THRESHOLD[9:1])begin
                    sensor_intr_i <= 1;
                end else begin
                    sensor_intr_i <= 0;
                end
            end else begin
                sensor_intr_i <= 0;
            end
        end
    end

    // State indicator flags
    always @(posedge i_sys_clk or posedge rst_i)begin
        if(rst_i)begin
            data_acquire_state_int_i <= 0;
            idle_state_int_i <= 0;
            wait_42ms_state_int_i <= 0;
        end else begin
            data_acquire_state_int_i <= (sensor_state_i == DATA_ACQUIRE);
            idle_state_int_i <= (sensor_state_i == IDLE);
            wait_42ms_state_int_i <= (sensor_state_i == WAIT_42ms_STATE);
        end
    end

    // State indicator flags are double registered in 10kHz clock domain
    always @(posedge i_clk_10khz or posedge rst_i)begin
        if(rst_i)begin
            d1_data_acquire_state_int_i <= 0;
            data_acquire_state_i <= 0;
            d1_idle_state_int_i <= 0;
            idle_state_i <= 0;
            d1_wait_42ms_state_int_i <= 0;
            wait_42ms_state_i <= 0;
        end else begin
            d1_data_acquire_state_int_i <= data_acquire_state_int_i;
            data_acquire_state_i <= d1_data_acquire_state_int_i;
            d1_idle_state_int_i <= idle_state_int_i;
            idle_state_i <= d1_idle_state_int_i;
            d1_wait_42ms_state_int_i <= wait_42ms_state_int_i;
            wait_42ms_state_i <= d1_wait_42ms_state_int_i;
        end
    end


    // Time counter is run on 10KHz clock as during wait time the
    // system clock is stalled
    always @(posedge i_clk_10khz or posedge rst_i)begin
        if(rst_i)begin
            time_counter_i <= 0; 
        end else begin
            if(idle_state_i)begin
                time_counter_i <= time_counter_i + 1;
            end else if(data_acquire_state_i)begin
                if(time_counter_i[9:1] == INTR_THRESHOLD[9:1])begin
                    time_counter_i <= INTR_THRESHOLD;
                end else begin
                    time_counter_i <= time_counter_i + 1;
                end
            end else begin
                time_counter_i <= 0;
            end
        end
    end

    // Input system clock is disabled during waiting time
    always @(posedge i_clk_10khz or posedge rst_i)begin
        if(rst_i)begin
            disable_clk_27m_during_time_count_i <= 0;
        end else begin
            if(init_time_i || ((data_acquire_state_i) && (time_counter_i[9:1] == INTR_THRESHOLD[9:1])))begin
                disable_clk_27m_during_time_count_i <= 0;
            end else if(time_counter_i == 1)begin
                disable_clk_27m_during_time_count_i <= 1;
            end
        end
    end

    // Input system clock is gated during initial waiting time or
    // during wait time after data acquisition till next trigger
    // occurs.
    assign o_disable_clk_27m = disable_clk_27m_during_wait_count_i || disable_clk_27m_during_time_count_i;

    assign init_time_i = (time_counter_i > INIT_THRESHOLD);

    // State machine to drive sensor configuration/data acquisition sequence
    always @(posedge i_sys_clk or posedge rst_i)begin
        if(rst_i)begin
            sensor_state_i <= IDLE;
        end else begin
            case(sensor_state_i)
                IDLE: begin
                    if(init_time_i)begin
                        if(RDID_EN)begin
                            sensor_state_i <= READ_CALIBRATION;
                        end else begin
                            sensor_state_i <= CTRL_REG1_A;
                        end
                    end
                end

                READ_CALIBRATION:begin
                    if(word_count_i < 1)begin
                        sensor_state_i <= WAIT_FOR_CALIBRATION_BYTE;
                    end else begin
                        sensor_state_i <= CTRL_REG1_A;
                    end
                end

                WAIT_FOR_CALIBRATION_BYTE:begin
                    if(i_i2c_done)begin
                        sensor_state_i <= READ_CALIBRATION;
                    end
                end

                CTRL_REG1_A:begin
                    if(i_i2c_done)begin
                        sensor_state_i <= CTRL_REG4_A;
                    end
                end

                CTRL_REG4_A:begin
                    if(i_i2c_done)begin
                        sensor_state_i <= DATA_ACQUIRE;
                    end
                end

                DATA_ACQUIRE:begin
                    if(trig_acquisition_i)begin
                        sensor_state_i <= READ_ACCEL_VALUE;
                    end
                end

                READ_ACCEL_VALUE:begin
                    if(word_count_i < 1)begin
                        sensor_state_i <= WAIT_FOR_ACCEL_VALUE;
                    end else begin
                        sensor_state_i <= DATA_ACQUIRE;
                    end
                end

                WAIT_FOR_ACCEL_VALUE:begin
                    if(i_i2c_done) begin
                        sensor_state_i <= DATA_ACQUIRE;
                    end else begin
                        sensor_state_i <= WAIT_FOR_ACCEL_VALUE;
                    end
                end
             
            endcase
        end
    end


      // intr
    always @(posedge i_sys_clk or posedge i_sys_rst)begin
        if(i_sys_rst)begin
            o_intr <= 0;
        end else begin
            if(i_intr_ack)begin
                o_intr <= 0;
            end else if(sensor_state_i == REG_DATA_STATE && word_count_i >= 1)begin
                o_intr <= INTR_EN;
            end
        end
    end

  


    always @(posedge i_sys_clk or posedge rst_i)begin
        if(rst_i)
            i2c_read_byte_cnt_i <= 0;
        else begin
            case(sensor_state_i)
                WAIT_FOR_ACCEL_VALUE : begin
                    if(i_read_data_valid)
                        i2c_read_byte_cnt_i <= i2c_read_byte_cnt_i + 1;
                end

                DATA_ACQUIRE :
                    i2c_read_byte_cnt_i <= 0;

            endcase
        end
    end

  
   // i2c_start_i
   always @(posedge i_sys_clk or posedge rst_i)begin
      if(rst_i)begin
         o_i2c_start <= 0;
      end else begin
         o_i2c_start <= 0;
         case (sensor_state_i)
           IDLE: begin
              if(init_time_i)begin
                 if(~RDID_EN)begin
                    o_i2c_start <= 1;
                 end
              end
           end

           READ_CALIBRATION:begin
              o_i2c_start <= 1;
           end

           CTRL_REG1_A:begin
              if(i_i2c_done)begin
                 o_i2c_start <= 1;
              end
           end

           READ_ACCEL_VALUE:begin
              if(word_count_i < 1)begin
                 o_i2c_start <= 1;
              end
           end
         endcase 
        end 
     end 
   
   // read_write_n_i
   always @(posedge i_sys_clk or posedge rst_i)begin
      if(rst_i)begin
         o_read_write_n <= 0;
      end else begin
         case (sensor_state_i)
           IDLE: begin
              if(init_time_i)begin
                 if(RDID_EN)begin
                    o_read_write_n <= 1;
                 end else begin
                    o_read_write_n <= 0;
                 end
              end
           end

           READ_CALIBRATION:begin
              if(word_count_i >= 1)begin
                 o_read_write_n <= 0;
              end
           end

           DATA_ACQUIRE:begin
              o_read_write_n <= 1;
           end
	 endcase
      end
   end

   // read_byte_count_i
   always @(posedge i_sys_clk or posedge rst_i)begin
      if(rst_i)begin
         o_read_byte_count <= 0;
      end else begin
         if (sensor_state_i == READ_CALIBRATION || sensor_state_i == WAIT_FOR_CALIBRATION_BYTE)begin
            o_read_byte_count <= 2;
         end else begin
            o_read_byte_count <= SENSOR_BYTE_COUNT;
         end
      end
   end

   // o_reg_address
   always @(posedge i_sys_clk or posedge rst_i)begin
      if(rst_i)begin
         o_reg_address <= 0;
      end else begin
         case (sensor_state_i)
           IDLE: begin
              if(init_time_i)begin
                 if(RDID_EN)begin
                    o_reg_address <= 0;
                 end else begin
                    o_reg_address <= 8'h20;
                 end
              end
           end

           READ_CALIBRATION:begin
              if(word_count_i >= 1)begin
                 o_reg_address <= 8'h20;
              end
           end

           CTRL_REG1_A:begin
              if(i_i2c_done)begin
                 o_reg_address <= 8'h23;
              end
           end

           DATA_ACQUIRE:begin
              o_reg_address <= 8'hA8;
           end
         endcase
      end 
   end
   

   // o_write_data
   always @ (posedge i_sys_clk or posedge rst_i)begin
      if(rst_i)begin
         o_write_data <= 0;
      end else begin
         case(sensor_state_i)
           IDLE: begin
              o_write_data <= 8'h57;
           end

           CTRL_REG1_A:begin
              if(i_i2c_done)begin
                 o_write_data <= 8'h08;
              end
           end
	 endcase
      end 
   end 
    

  //word_count_i
   always @(posedge i_sys_clk or posedge rst_i)begin
      if(rst_i)begin
         word_count_i <= 0;
      end else begin
         case (sensor_state_i)
           IDLE: begin
              word_count_i <= 0;
           end

           WAIT_FOR_CALIBRATION_BYTE:begin
              if(i_i2c_done)begin
                 word_count_i <= word_count_i + 1;
              end
           end

           DATA_ACQUIRE:begin
              word_count_i <= 0;
           end

           WAIT_FOR_ACCEL_VALUE:begin
              if(i_i2c_done)begin
                 word_count_i <= word_count_i + 1;
              end
           end
         endcase
      end 
   end 
    

   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         byte_count_i <= 0;
      end else if(i_read_data_valid)begin
         if(byte_count_i == 3'b101)
           byte_count_i <= 0;
         else
           byte_count_i <= byte_count_i + 1;
      end
   end

   always @(posedge i_sys_clk or posedge i_sys_rst) begin
      if(i_sys_rst) begin
         o_read_data_vld <= 0;
      end else begin
         if(byte_count_i == 3'b001 && i_read_data_valid)
           o_read_data_vld <= 1;
         else
           o_read_data_vld <= 0;
      end
   end                   
endmodule


// Local Variables:
// verilog-library-directories:("." "../i2c_master/" "../spi_master/")
// End:
