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
//  File Name: global.v
// 
//  Description: This consists of global declaration and constant parameters
//  used in the testbench.
//
//  Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author        | Mod. Date    |Changes Made:
// V1.0 | MDN           | 05-Mar-14    |Initial version                             
//-------------------------------------------------------------------------

/*****************************************************************************
  Global declarations
 *****************************************************************************/
//`define LOG     // Enables processor interrupt handler log
//`define VERBOSE  // Enables status message in i2c slave model

//`define VARDATA // This enables varying data from i2c slave model
`define FROM_FILE

//Comment the follwing line during RTL simulation
`define SBTSIM


//Uncomment following defines to enable the i2c slave model

//`define DEV0
//`define DEV1
`define DEV3
//`define DEV4

parameter CPOL = 1;
parameter CPHA = 1;
parameter SPI_WAIT_COUNT = 2;


reg [7:0] fifo_data;

reg proc_sclk = CPOL;
reg proc_csn  = 1;
wire proc_sdi;
reg proc_sdo = 0;

reg [7:0] version;
reg tb_clk;
reg rst_n;

reg [7:0] miso_fall;
reg [7:0] miso_rise;


/*****************************************************************************
  Constant parameters
 *****************************************************************************/
// Device0: BMP085 Pressure sensor
// Device1: LSM303 Compass
// Device2: MPU 3050 Gyroscope
// Device3: KXUD9 Accelerometer
// Device4: ISL29003 Light sensor

parameter ISR_WAIT_COUNT = 500;
parameter SPI_CLK_PERIOD = 60; //in ns, 25MHz

parameter INTE = 8'h1F;

//Setting to 1 will enable interrupt
parameter DEV0_INTR_EN = 1;
parameter DEV1_INTR_EN = 1;
parameter DEV2_INTR_EN = 1;
parameter DEV3_INTR_EN = 1;
parameter DEV4_INTR_EN = 1;

parameter I2C_SLAVE_0 = 7'h19;
parameter I2C_SLAVE_1 = 7'h39;
parameter I2C_SLAVE_2 = 7'h19;
parameter I2C_SLAVE_4 = 7'h44;
parameter I2C_SLAVE_5 = 7'h6B;


parameter DEV0_INIT_THRESHOLD = 32;
parameter DEV0_INTR_THRESHOLD = 1024;
parameter DEV2_INIT_THRESHOLD = 32;
parameter DEV2_INTR_THRESHOLD = 1024;
parameter DEV3_INIT_THRESHOLD = 32;
parameter DEV3_INTR_THRESHOLD = 32;
parameter DEV4_INTR_THRESHOLD = 1024;


parameter CS_POLARITY = 0;

parameter READ = 1'd1;
parameter WRITE = 1'd0;
parameter AD_VERSION = 6'd0;
parameter AD_ISR = 6'd3;
parameter BYTE_SEL = 1'b1;


parameter DEV0 = 3'd0;
parameter DEV1 = 3'd1;
parameter DEV2 = 3'd2;
parameter DEV3 = 3'd3;
parameter DEV4 = 3'd4;
parameter COMMON = 3'd0;

// Specifies the length of calibration bytes to read for each sensor
parameter DEV0_CALIB_COUNT = 22;
parameter DEV1_CALIB_COUNT = 2; 
parameter DEV2_CALIB_COUNT = 2;
parameter DEV3_CALIB_COUNT = 2;
parameter DEV4_CALIB_COUNT = 2;

// Specifies the length of data bytes to read for each sensor
parameter DEV0_DATA_COUNT = 4;
parameter DEV1_DATA_COUNT = 2;
parameter DEV2_DATA_COUNT = 8;
parameter DEV3_DATA_COUNT = 6;
parameter DEV4_DATA_COUNT = 2;

parameter DEV3_INTR_COUNT = 1;
parameter DEV3_I2C_SLAVE_ADDRESS = 8'h19;

reg i2c_slave_clk;
