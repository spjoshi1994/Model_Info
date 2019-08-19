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
//  File Name: pedometer.v
//
//  Description: This is the top level file of the Design
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date         |Changes Made:
// V1.0 | MDN           | 05-MAR-2014       |Initial version
//-------------------------------------------------------------------------

module  pedometer ( /*AUTOARG*/
                    // Outputs
                    o_tx,
                    // Inouts
                    io_poola_sensor_scl, io_poola_sensor_sda,
                    // Inputs
                    i_sys_clk, i_rx
                    );
`include "../parameters.h" 
       
    //System clock
    input       i_sys_clk /* synthesis syn_noclockbuf = 1 */;
    
    //Sensor Interface
    inout       io_poola_sensor_scl;
    inout       io_poola_sensor_sda;

    //UART Interface
    output      o_tx;
    input       i_rx;
    
    // Internal wires and registers
    wire        step_intr_ack_i;
    wire        step_intr_i;
    wire        step_detect_i;
    wire        read_data_vld_i;

    wire        poola_sda_oe_n_i;
    wire        poola_scl_oe_n_i;
    
    wire        dev2_i2c_start_i;
    wire        dev2_read_write_n_i;
    wire [7:0]  dev2_slave_address_i;
    wire [7:0]  dev2_read_byte_count_i;
    wire [7:0]  dev2_reg_address_i;
    wire [7:0]  dev2_write_data_i;
    wire [7:0]  dev2_read_data_i;
    wire        dev2_read_data_valid_i;
    wire        dev2_i2c_done_i;
    
    wire        lsosc_clk_i;
    wire        disable_clk_27m_i;
    wire        gated_sys_clk_i;
    reg [2:0]   gated_sys_clk_div_i = 0; //initialized for simulation
    wire        sys_clk_by2_i;
    wire        sys_clk_by8_i;
    wire        calibration_done_pulse_i;
    wire        driving_calibration_done_pulse_i;
    wire        disable_clk_27mhz_prox_i;
    wire [15:0] foot_counter_i;

    wire       rst_i;
    reg [15:0] poweron_reset_count_i = 0; //initialized for simulation
    reg        poweron_reset_n_i = 0; // initialized for simulation
    wire [DATA_WIDTH-1:0] driving_calib_data_i;
    wire                  driving_calib_data_vld_i;
    wire [SQR_WIDTH:0]    variance_data_i;
    wire                  variance_data_vld_i;
    wire [SQR_WIDTH:0]    variance_sma_data_i;
    wire                  variance_sma_data_valid_i;
    wire [DATA_WIDTH- 1:0] mean_sma_data_i;
    wire                  mean_sma_data_valid_i;    
    wire                  calibration_done_i;    wire [7:0]            accel_read_data_i;
    wire                  accel_read_data_valid_i;
    wire                  accel_i2c_done_i;
    wire                  test_rst;
    wire                  send_isr_i;
    wire [DATA_WIDTH-1:0] driving_sma_data8_i;
    wire                  driving_sma_data8_valid_i;
    wire [10:0]           step_count_lower_threshold_i; // Set thershold depending on the action
    wire [10:0]           step_count_upper_threshold_i;
    wire                  accel_sensor_i2c_done_i;
    wire [7:0]            accel_sensor_read_data_i;
    wire                  accel_sensor_read_data_valid_i;
    wire                  reset_i;
    wire [DATA_WIDTH-1:0] mean_value_i;
    wire                  mean_valid_i;
    
`ifdef SIM_ONLY
   assign accel_sensor_i2c_done_i = accel_i2c_done_i;
   assign accel_sensor_read_data_i = accel_read_data_i;
   assign accel_sensor_read_data_valid_i = accel_read_data_valid_i;
   assign reset_i = test_rst;
`else
   assign accel_sensor_i2c_done_i = dev2_i2c_done_i;
   assign accel_sensor_read_data_i = dev2_read_data_i;
   assign accel_sensor_read_data_valid_i = dev2_read_data_valid_i;
   assign reset_i = rst_i;
`endif
   
    
    // Power on reset logic. After switching ON the power, for first
    // 256 cycles the system will be under reset
    always @(posedge sys_clk_by2_i)begin
        if(poweron_reset_count_i == 256)begin
            poweron_reset_count_i <= 256;
        end else begin
            poweron_reset_count_i <= poweron_reset_count_i + 1;
        end
    end

    always @(posedge sys_clk_by2_i)begin
        if(poweron_reset_count_i == 256)begin
            poweron_reset_n_i <= 1;
        end else begin
            poweron_reset_n_i <= 0;
        end
    end

   assign rst_i = ~poweron_reset_n_i;

   //I2C BUS Driver
   assign io_poola_sensor_sda = (!poola_sda_oe_n_i)? 1'b0: 1'bZ;
   assign io_poola_sensor_scl = (!poola_scl_oe_n_i)? 1'b0: 1'bZ;

   // On chip low speed oscillator instantiation
   SB_LFOSC u_SB_LFOSC
     (
      .CLKLFEN     (1'b1),
      .CLKLFPU     (1'b1),
      .CLKLF       (lsosc_clk_i));

   //Clock divide by 2 circuit
   always @(posedge i_sys_clk)begin
      gated_sys_clk_div_i <= gated_sys_clk_div_i + 1;
   end

   SB_GB gb_clk_by2_inst (
                          .USER_SIGNAL_TO_GLOBAL_BUFFER (i_sys_clk), //for 14MHz oscillator, this is actually the incoming clock
                          .GLOBAL_BUFFER_OUTPUT (sys_clk_by2_i));

   SB_GB gb_clk_by8_inst (
                          .USER_SIGNAL_TO_GLOBAL_BUFFER (gated_sys_clk_div_i[1]), //for 14MHz oscillator, this is actually clock divide by 4
                          .GLOBAL_BUFFER_OUTPUT (sys_clk_by8_i));

   

   LSM330DLC_accl u_LSM330DLC_accl (/*-AUTOINST-*/
				    //Global inputs
				    .i_sys_clk                     (sys_clk_by2_i),
                                    .i_sys_rst                     (reset_i),
                                    .i_clk_10khz                   (lsosc_clk_i),
				    //Outputs
                                    .o_intr                        (dev2_intr_i),
                                    .o_disable_clk_27m             (), 
                                    .o_read_data_vld               (read_data_vld_i),
                                    .o_i2c_start                   (dev2_i2c_start_i),
                                    .o_read_write_n                (dev2_read_write_n_i),
                                    .o_slave_address               (dev2_slave_address_i[7:0]),
                                    .o_read_byte_count             (dev2_read_byte_count_i[7:0]),
                                    .o_reg_address                 (dev2_reg_address_i[7:0]),
                                    .o_write_data                  (dev2_write_data_i[7:0]),
                                    //Inputs
                                    .i_step_intr_ack               (step_intr_ack_i),
                                    .i_intr_ack                    (dev1_intr_ack_i),
                                    .i_i2c_done                    (accel_sensor_i2c_done_i),
                                    .i_read_data_valid             (accel_sensor_read_data_valid_i),
                                    .i_read_data                   (accel_sensor_read_data_i)
                                    );
   
   defparam u_LSM330DLC_accl.INTR_EN = 1;
   defparam u_LSM330DLC_accl.INIT_THRESHOLD = 32'h3DA; 
   defparam u_LSM330DLC_accl.INTR_THRESHOLD = 32'h0C8; //50 samples per second
   defparam u_LSM330DLC_accl.CLK_DIV_COUNT =  10'd9;

    //calibration module
    context_calibration calib( //Global Inputs
                               .i_sys_clk                 (sys_clk_by2_i),
                               .i_sys_rst                 (rst_i),
                               // Outputs
                               .o_data                    (driving_calib_data_i),
                               .o_data_vld                (driving_calib_data_vld_i),
                               .o_calibration_done        (calibration_done_i),
                               .o_calibration_done_pulse_i(driving_calibration_done_pulse_i),
                               //Inputs
                               .i_valid                   (accel_sensor_read_data_valid_i),
                               .i_data                    (accel_sensor_read_data_i)
                               ) ;
   
   //SMA Eight Filter 
   sma_eight u_sma8(/*-AUTOINST*/
		     //Global inputs
		    .i_sys_clk          (sys_clk_by2_i),
		    .i_sys_rst          (reset_i),
		    //outputs
		    .o_sma_data8        (driving_sma_data8_i),
		    .o_sma8_data_valid  (driving_sma_data8_valid_i),
		     //Inputs
		    .i_input_data       (driving_calib_data_i),
		    .i_data_valid       (driving_calib_data_vld_i)
		    );

   //Step detection module
   step_detection u_step_detect (/*-AUTOINST-*/
				 //Global Inputs
				 .i_sys_clk                           (sys_clk_by2_i),
				 .i_sys_rst                           (reset_i),
                                 .i_10khz_clk                         (lsosc_clk_i),
				 //Outputs
				 .o_step_detect                       (step_detect_i),
				 .o_foot_counter                      (foot_counter_i),
				 //Inputs
				 .i_norm_data                         (driving_sma_data8_i),
				 .i_data_valid                        (driving_sma_data8_valid_i),
				 .i_sma_data                          (variance_sma_data_i),
                                 .i_mean_value                        (mean_sma_data_i),
                                 .i_mean_valid                        (mean_sma_data_valid_i)
                                 );
    
    //Variance calculation module
    variance u_varia_calc( //Global Inputs
                           .i_sys_clk               (sys_clk_by2_i),
                           .i_sys_rst               (rst_i),
                           //Outputs
                           .o_variance              (variance_data_i),
                           .o_data_valid            (variance_data_vld_i),
                           .o_mean_value            (mean_value_i),
                           .o_mean_valid            (mean_valid_i),
        
			   //Inputs
			   .i_data                  (driving_sma_data8_i),
                           .i_data_valid            (driving_sma_data8_valid_i)
                           );

    //SMA Filter module instantiation 
    variance_sma u_var_sma (/*-AUTOINST-*/
			    //Global Inputs
			    .i_sys_clk                   (sys_clk_by2_i),
                            .i_sys_rst                   (rst_i),
                           
                            // Outputs
                            .o_sma_data                  (variance_sma_data_i),
                            .o_sma_data_valid            (variance_sma_data_valid_i),
	        	    // Inputs
                            .i_input_data                (variance_data_i),
                            .i_data_valid                (variance_data_vld_i)
			    ) ;

    
    //SMA Filter module instantiation 
    mean_sma u_mean_sma (/*-AUTOINST-*/
			 //Global Inputs
			 .i_sys_clk                   (sys_clk_by2_i),
                         .i_sys_rst                   (rst_i),
                         // Outputs
                         .o_sma_data                  (mean_sma_data_i),
                         .o_sma_data_valid            (mean_sma_data_valid_i),
	                 // Inputs
                         .i_input_data                (mean_value_i),
                         .i_data_valid                (mean_valid_i)
			 ) ;
   
    //I2C Master instantiation    
    i2c_reg_ctrl u_i2c_reg_ctrl(/*-AUTOINST-*/
                                // Global inputs
                                .i_sys_clk                           (sys_clk_by2_i),
                                .i_sys_rst                           (rst_i),
                                .i_i2c_hardip_clk                    (sys_clk_by8_i),
                                // Outputs
                                .o_read_data                         (dev2_read_data_i[7:0]),
                                .o_read_data_valid                   (dev2_read_data_valid_i),
                                .o_i2c_done                          (dev2_i2c_done_i),
                                .o_scl_oe_n                          (poola_scl_oe_n_i),
                                .o_sda_oe_n                          (poola_sda_oe_n_i),
                                // Inputs
                                .i_i2c_start                         (dev2_i2c_start_i),
                                .i_read_write_n                      (dev2_read_write_n_i),
                                .i_slave_addr                        (dev2_slave_address_i[7:0]),
                                .i_read_byte_count                   (dev2_read_byte_count_i[7:0]),
                                .i_reg_address                       (dev2_reg_address_i[7:0]),
                                .i_write_data                        (dev2_write_data_i[7:0]),
                                .i_scl                               (io_poola_sensor_scl),
                                .i_sda                               (io_poola_sensor_sda));

    defparam u_i2c_reg_ctrl.CLK_DIV_COUNT = 72; 
    defparam u_i2c_reg_ctrl.I2C_SLAVE_INIT_ADDR = "0b1111100010";
    defparam u_i2c_reg_ctrl.BUS_ADDR74_STRING = "0b0011";
    defparam u_i2c_reg_ctrl.BUS_ADDR74 = 8'b0011_0000;

    
    uart_top u_uart_top(
                        //Global Inputs
                        .i_sys_clk                              (sys_clk_by2_i),
                        .i_sys_rst                              (rst_i),
		        //outputs
                        .o_tx                                   (o_tx),
		        //Inputs 
                        .i_ready                                (driving_calibration_done_pulse_i),
                        .i_step_intr                            (step_detect_i),
                        .i_foot_counter                         (foot_counter_i),
                        .i_rx                                   (i_rx),
                        .i_send_isr                             (send_isr_i)
                        );
   
endmodule // pedometer
 
