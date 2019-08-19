//------------------------------------------------------------------------------
//  >>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<<<
//------------------------------------------------------------------------------
//         Copyright (c) 2012 by Lattice Semiconductor Corporation      
// 
//------------------------------------------------------------------------------
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
//   It is the user's responsi+bility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Lattice Semiconductor provides no warranty
//   regarding the use or functionality of this code.
//
//------------------------------------------------------------------------------
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
//-------------------------------------------------------------------------------
//  Project   : LP3.5K_Pedometer_with_BLE_Interface
//  File Name : squareroot.v
//  Author    : MDN
//
//-------------------------------------------------------------------------------
//  Code Revision History :
//  Ver:         | Author       | Mod. Date    |Changes Made:
//  V1.0         | MDN          | 23-DEC-2013  |  
//                            
//-------------------------------------------------------------------------------
// Description:  module for calculating square root
// Initialization input,quotient (the result of squared root), and remainder. 
// Beginning at the binary point, divide the input into groups of two digits in
// both direction.Beginning on the left (most significant bit),select the first 
// group of digits (If n is odd then the first groups is one digit, and vice versa).
// Choose '1' squared, and then subtract.Fist developed root is '1' if the result 
// of subtract is positive, and vice versa is '0'. 
// 1) Shift the input by two bits, subtract guess squared with append 01.
// Nth-bit squared is '1' if the result of subtract is positive, and Because of 
// subtract operation is done else Nth-bit squared is '0',and do not subtract.
// Above step i.e(1) is repeated until end group of two digits.
//--------------------------------------------------------------------------------
//  Parameters : INTEGER_WIDTH=SQR_WIDTH +1; 
//--------------------------------------------------------------------------------
//  Reuse Issues
//   Reset Strategy   : Asynchronous, active high power on reset 
//   Clock Domains    : i_clk
//   Asynchronous I/F : i_rst
//   Instantiations   : none
//   Other            :     
//-------------------------------------------------------------------------------- 
module squareroot(//global inputs
		  i_clk,i_rst,
		  //outputs
		  o_squareroot,o_done,o_remain,
		  //inputs
		  i_integer,i_start
		  );
   `include "../parameters.h"
   //parameter declaration
   parameter INTEGER_WIDTH=SQR_WIDTH +1;   //width of the number whose square root must be found	 
   localparam IDLE=2'b00;
   localparam SHIFTCOMPARE=2'b01;
   localparam RESULTGENERATE=2'b10;
   localparam NPOWER=6;                 //width of the counter used to keep tract of iterations
   
   //global inputs  
   input i_clk;
   input i_rst;

   //outputs
   output reg [((INTEGER_WIDTH-1)/2):0] o_squareroot;      //square root of the givien number 
   output reg 				o_done;            //indicates end of division 
   output reg [INTEGER_WIDTH:0] 	o_remain;          //holds the value of the remainder
   
   //input
   input [INTEGER_WIDTH-1:0] 		i_integer;             //integer part of the number whose square root must be found    
   input 				i_start;             //indicates start of square root division

   //reg declaration 
   reg [INTEGER_WIDTH-1:0] 		number_i;          //holds the input value 
   reg [INTEGER_WIDTH-1:0] 		accumulator_i;     //used to hold the input values for shift
   reg [NPOWER-1:0] 			count_i;         //used to keep the count of iterations
   reg [1:0] 				state;
   reg [1:0] 				nextstate;
   reg 					start_i;            //indicates start of squareroot division
   reg 					done_i;             //indicates end of squareroot division
   reg [INTEGER_WIDTH:0] 		r_i;               //holds the partial input for subtraction
   reg [INTEGER_WIDTH:0] 		test_i;           //holds the partial remainder
   reg [INTEGER_WIDTH:0] 		remain_i;        //holds the remainder
   reg [INTEGER_WIDTH:0] 		left_i;         //holds the value to be subtracted from the partial input
   reg [((INTEGER_WIDTH-1)/2):0] 	quot_i;         //holds the squareroot of the given number
   
   //passing the inputs to square root division   
   always@(i_integer,i_start)
     begin 
	start_i<=i_start;
	number_i<=i_integer;
     end 
   
   //non-restoring square root division  
   always@(posedge i_clk or posedge i_rst)
     begin
	if(i_rst==1)begin
	   quot_i<=0;
	   remain_i<=0;
      	   accumulator_i<=0;
	end	else begin                  
	   if(start_i==1)begin 
	      quot_i<=0;                          //initial value of quotient set to zero 
	      remain_i<=0;                       //inintial value of remainder set to zero	 
	      accumulator_i<=(number_i);     //load the input to the accumulator
	   end
	   else begin
	      if(INTEGER_WIDTH%2==1 && count_i==((INTEGER_WIDTH+1)/2))
		accumulator_i<=(accumulator_i<<1);      //shift the accumulator by 1 bit position for first iteration if the no.of bits are odd	 
	      else begin 
		 accumulator_i<=(accumulator_i<<2);     //shift the accumulator by 2 bit position if the no.of bits are even and rest of the iteration 
	      end 
	      remain_i<=test_i;                        // remainder from the previous test is used as remainder for current iteration
	      if(left_i<=r_i)begin 
		 quot_i<=((quot_i<<1)|1'b1);         //shift the quotient if subtraction is performed and append '1' to LSB of the quotient reg
	      end else if(left_i>=r_i)begin 
                 quot_i<=((quot_i<<1)|1'b0);        //shift the quotient if the subtraction is not done and append '0' to LSB of the quotient reg
	      end 
	   end 										 
	end 
     end
   
   //deciding the inputs for the subtraction to determine the quotient 
   always@(accumulator_i,quot_i,remain_i,count_i)
     begin 	
	if(INTEGER_WIDTH%2==1 && count_i==((INTEGER_WIDTH+1)/2))
	  r_i<=(remain_i<<2)|((accumulator_i[INTEGER_WIDTH-1])& 2'b11);  //shifting the value of the input to partial input reg for subtraction 
	else  begin 
	   r_i<=(remain_i<<2)|((accumulator_i[INTEGER_WIDTH-1:INTEGER_WIDTH-2])& 2'b11);  //shifting the value of the input to partial input reg for subtraction
	end 
	left_i<=((quot_i<<2)|2'b01);                       
     end
   
   //generating the remainder for next iteration   
   always@(r_i,left_i)
     begin
	if(left_i<=r_i)begin 
	   test_i<=r_i-left_i;      
	end else begin 
	   test_i<=r_i;           
	end
     end
   
   //Control of states for division  
   always@(posedge i_clk or posedge i_rst)      
     begin
	if (i_rst==1) begin      
	   state<=IDLE; 
	   count_i<=0;             
	end  else begin     
	   state <= nextstate;   
	   if (state==SHIFTCOMPARE)
	     count_i <= count_i - 1;
	   else if (state==IDLE) 
	     count_i <= ((INTEGER_WIDTH+1)/2);        //holds the value of No.of iteration to be taken 
	end
     end	   
   
   //Keeps the count of no.of iteration to be takenplace and generates done signal to indicate end of division to generate the square root value   
   always@(state,start_i,count_i)
     begin  
	case (state)
	  IDLE :begin 
	     done_i<=0;
	     if (start_i==1)
	       nextstate <= SHIFTCOMPARE; 
	     else 
	       nextstate <= IDLE;
	  end 
	  SHIFTCOMPARE : begin
	     done_i<=0;
	     if ((count_i==1))
	       nextstate <= RESULTGENERATE; // Done 
	     else 
	       nextstate <= SHIFTCOMPARE;// Next shift & compare
	  end
	  RESULTGENERATE : begin
	     done_i<=1'b1;              //indicates end of dividion,ready fot new input value
      	     nextstate <= IDLE; 
	  end 
	  default: begin
	       done_i<=0;
	     nextstate <=IDLE;              
	  end
	endcase
     end 

   //assigning the result to the output	
   always@(quot_i,remain_i,done_i)
     begin
	o_done<=done_i;               //indicates completion of division
	o_squareroot<=quot_i;         //contains the squareroot 
	o_remain<=remain_i;           //contains the remanider
     end 
endmodule // squareroot























   
   
   
