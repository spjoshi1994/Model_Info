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
//  Project  : LP3.5K_Lenovo_Tap_Pedometer_MotionDetect_Demo_HardIP
//  File Name: tap_pedometer_tb.v
//
// Description: This testbench is created to drive the stimulus to DUT. This
//              consists of
//              1. Reset and clock generation logic
//              2. i2c slave model
//              3. Dummy SPI slave model
//              4. Processor interrupt handler tasks
//              5. SPI tasks to drive processor interface
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date    |Changes Made:
// V1.0 | MDN           | 03-Nov-12    |Initial version
// V1.1 | MDN           | 06-Nov-12    |Interrupt sensing is changed
//      |               |              |from rising edge to falling edge
//-------------------------------------------------------------------------

`timescale 1ns/1ns
module	pedometer_tb();
    
    parameter tSysClkPeriod = 37;//20;
    parameter i2c_slave_clk_period = 1463;
    parameter tSysRstPeriod = 20000;//10800;
   
    tri1                sensor3_scl;
    tri1                sensor3_sda; 
    wire                i_rx;
    wire                proc_intr;
    reg                 sensor3_interrupt;
    reg [7:0]           intr_gen_counter_i;
   reg 			rst_i;
   
    reg [7:0]           isr;
    reg                 load_data_i=0;
    reg                 test_rst;
   
`include "./include/global.v"
    
    
    // Clock and reset generation
    initial begin
        tb_clk = 1'b0;
        forever #(tSysClkPeriod/2) tb_clk = ~tb_clk;
    end


    initial begin
        i2c_slave_clk = 1'b0;
        forever #(i2c_slave_clk_period) i2c_slave_clk = ~i2c_slave_clk;
    end

    
    initial begin
        rst_n <= 1'b0;
        #tSysRstPeriod;
        rst_n <= 1'b1;
    end
    
    wire                o_spi_miso;             
    wire 		o_tx;

    initial begin
        test_rst<=1'b1;
        #10;
        test_rst<=1'b0;
    end
    
    

    pedometer DUT (/*-AUTOINST-*/
                   .io_poola_sensor_scl             (sensor3_scl),
                   .io_poola_sensor_sda             (sensor3_sda),
                   .i_sys_clk                       (tb_clk),
		   .o_tx                            (o_tx),
		   .i_rx                            (i_rx)
                   );
     defparam DUT.u_LSM330DLC_accl.INTR_EN = DEV3_INTR_EN;
    defparam DUT.u_LSM330DLC_accl.INIT_THRESHOLD = DEV3_INIT_THRESHOLD;
    defparam DUT.u_LSM330DLC_accl.INTR_THRESHOLD = DEV3_INTR_THRESHOLD;
    defparam DUT.u_LSM330DLC_accl.INTERRUPT_COUNT = DEV3_INTR_COUNT;
    defparam DUT.u_LSM330DLC_accl.I2C_SLAVE_ADDRESS = DEV3_I2C_SLAVE_ADDRESS;

            `ifndef SBTSIM					 
    
    defparam DUT.u_LSM330DLC_accl.INTR_EN = DEV3_INTR_EN;
    defparam DUT.u_LSM330DLC_accl.INIT_THRESHOLD = DEV3_INIT_THRESHOLD;
    defparam DUT.u_LSM330DLC_accl.INTR_THRESHOLD = DEV3_INTR_THRESHOLD;
    defparam DUT.u_LSM330DLC_accl.INTERRUPT_COUNT = DEV3_INTR_COUNT;
    defparam DUT.u_LSM330DLC_accl.I2C_SLAVE_ADDRESS = DEV3_I2C_SLAVE_ADDRESS;
            `endif

            `ifdef DEV3
    i2c_slave_model sensor3(
                            .scl (sensor3_scl),
                            .sda (sensor3_sda),
                            .no_ack (1'b0),
                            .atn (/*open*/)
                            );
    defparam sensor3.I2C_ADR = I2C_SLAVE_0;

            `endif

            `ifdef DEV1
    i2c_slave_model sensor1(
                            .scl (sensor1_scl),
                            .sda (sensor1_sda),
                            .no_ack (1'b0),
                            .atn (/*open*/)
                            );
    defparam sensor1.I2C_ADR = I2C_SLAVE_1;

            `endif

            `ifndef DEV3
    assign sensor3_scl = 1'bz;
    assign sensro3_sda = 1'bz;
            `endif

            `ifndef DEV3
    assign sensor1_scl = 1'bz;
    assign sensro1_sda = 1'bz;
            `endif

    //------------------------------------------------------------
    //I2C bypassed in simulation to reduce simulation time
    //------------------------------------------------------------
    integer             x, j, n, file_ptr;
    reg [7:0]           i2c_rd_data_i;
    reg [7:0]           accel_read_data_i;
    reg                 accel_i2c_done_i;
    reg                 accel_read_data_valid_i;

    wire [15:0]         data;

    assign data = 16'hF7A0;
    
    assign DUT.accel_read_data_i = i2c_rd_data_i;
    assign DUT.accel_read_data_valid_i = accel_read_data_valid_i;
    assign DUT.accel_i2c_done_i = accel_i2c_done_i;
    assign DUT.test_rst = test_rst;
    
    initial begin
        #10000;
        x = 0;
        file_ptr = $fopen("../../testbench/model/walking_raw.txt", "r");
        while (x != -1) begin
            #10000;
            for (j=0; j<6; j=j+1) begin
                x = $fscanf(file_ptr, " %h:\n", i2c_rd_data_i);
                accel_read_data_i = i2c_rd_data_i;
                for (n=0; n<10; n=n+1) 
                    @ (posedge tb_clk);
                
                @ (posedge tb_clk);
                accel_read_data_valid_i = 1;
                @ (posedge tb_clk);
                // @ (posedge tb_clk);
                accel_read_data_valid_i = 0;
                @ (posedge tb_clk);
            end
            @ (posedge tb_clk);
            accel_i2c_done_i = 1;
            @ (posedge tb_clk);
            //  @ (posedge tb_clk);
            accel_i2c_done_i = 0;
            @ (posedge tb_clk);
        end 
        $fclose (file_ptr);
    end

endmodule 
