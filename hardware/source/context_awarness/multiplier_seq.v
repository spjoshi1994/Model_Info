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
//  File Name : multiplier_seq.v
//  Author    : MDN
//
//--------------------------------------------------------------------------
//  Code Revision History :
//  Ver:         | Author       | Mod. Date    |Changes Made:
//  V1.0         | MDN          | 24-DEC-2013  |  
//                            
//--------------------------------------------------------------------------
//  Description: This module performs multilpication based on serial 
//  multiplication algorithm
//--------------------------------------------------------------------------
//  Parameters : MULTIPLIER_WIDTH=8
//               MULTIPLICAND_WIDTH=8
//               TWOSCOMP=0
//               OURPUTREGISTERD=0
//--------------------------------------------------------------------------
//  Reuse Issues
//   Reset Strategy   : Asynchronous, active high power on reset 
//   Clock Domains    : i_clk
//   Asynchronous I/F : i_rst,i_start
//   Instantiations   : none
//   Other            :     
//--------------------------------------------------------------------------  
module multiplier_seq(//global inputs
                      i_clk,i_rst,
                      //outputs
                      o_product,o_done,
                      //input
                      i_multiplicant,i_multiplier,i_start
                      );

   //parameter declarations
   parameter MULTIPLICANT_WIDTH =8;       //width for multiplicant
   parameter MULTIPLIER_WIDTH =8;        //width for multiplier
   parameter TWOSCOMP=0;            //'1'=signed multiplication and '0'=unsigned multiplication
   parameter OUTPUTREGISTERED=0;     //'0'=unregistered product and '1'=registered product
   parameter PRODUCT_WIDTH =(MULTIPLICANT_WIDTH+MULTIPLIER_WIDTH);   //width of the product  
   parameter NPOWER = 6;                                           //multiplier width<=2**NPOWER
   parameter NULL_VECTOR_S = 32'h00000000;               //used to fill the upper part of product register with zero at the begining of multiplication
   parameter S0= 2'd0;
   parameter S1= 2'd1;
   parameter S2= 2'd2;
   
   //global inputs
    input i_clk;
    input i_rst;

   //outputs
    output reg [PRODUCT_WIDTH-1:0] o_product;
    output                         o_done;

   //input                       
    input [MULTIPLICANT_WIDTH-1:0] i_multiplicant;
    input [MULTIPLIER_WIDTH-1:0]   i_multiplier;
    input                          i_start;      //indicates start of multiplication
   

   // reg and wire declarations
    reg                            o_done; 
    wire                           sign_i;      //sign product
    reg [PRODUCT_WIDTH-1:0]        product_i; 
    reg [NPOWER-1:0]               count_i;       
    reg                            add_i;
    reg                            shr_i;
    reg                            done_i;
    reg                            start_i;
    reg [1:0]                      state=2'b00;
    reg [1:0]                      nextstate=2'b00;
    reg [MULTIPLICANT_WIDTH-1:0]   multiplicant_i;
    reg [MULTIPLIER_WIDTH-1:0]     multiplier_i;

   //sign products  
   assign      sign_i = i_multiplicant[MULTIPLICANT_WIDTH-1] ^ i_multiplier[MULTIPLIER_WIDTH-1]; 

   //converting signed inputs to unsigned for signed multiplication      
   generate
       if(TWOSCOMP==1) 
         always@(posedge i_clk or posedge i_rst) begin   
             if(i_rst==1) begin
                 multiplicant_i<= 0;
                 multiplier_i <= 0;
                 start_i <= 0; 
             end
             else begin 
                 start_i <= i_start; 
                 if(i_start==1) begin 
                     multiplicant_i <=rectify_multcnd(i_multiplicant);  //calling the function to convert signed multiplicant to unsigned
                     multiplier_i <=rectify_mulplr(i_multiplier);       //calling the function to convert signed multiplier to unsigned
                 end 
             end
         end    
endgenerate 

   //passing the inputs for unsigned multilication
   generate
       if(TWOSCOMP==0)
         always@(i_multiplicant,i_multiplier, i_start)
           begin 
               multiplicant_i<=i_multiplicant;
               multiplier_i<=i_multiplier;
               start_i <=i_start; 
           end 
endgenerate             
   
   
   //converting signed multiplicant input to unsigned  
   function [MULTIPLICANT_WIDTH-1:0]rectify_multcnd;    
       input [MULTIPLICANT_WIDTH-1:0]multiplicant;
       reg [MULTIPLICANT_WIDTH-1:0]  rec_v;
       begin
           if((multiplicant[MULTIPLICANT_WIDTH-1])==1)
             rec_v=~(multiplicant);
           else
             rec_v=multiplicant;
           rectify_multcnd=(rec_v+(multiplicant[MULTIPLICANT_WIDTH-1]));
       end
   endfunction

   //converting signed multiplier input to unsigned                
   function [MULTIPLIER_WIDTH-1:0]rectify_mulplr;       
       input [MULTIPLIER_WIDTH-1:0]multiplier;
       reg [MULTIPLIER_WIDTH-1:0]  rec_v;
       begin
           if((multiplier[MULTIPLIER_WIDTH-1])==1)
             rec_v=~(multiplier);
           else
             rec_v=multiplier;
           rectify_mulplr=(rec_v+(multiplier[MULTIPLIER_WIDTH-1]));
       end
   endfunction     
   
   //Serial Multiplication  
   always@(posedge i_clk or posedge i_rst) 
     begin
         if(i_rst==1)
           product_i<=0;
         else begin 
             if(start_i==1) begin 
                 product_i <= {NULL_VECTOR_S[MULTIPLICANT_WIDTH-1:0], multiplier_i};  //Load multiplier
             end else if (add_i==1)
               product_i<= {{1'b0, product_i[PRODUCT_WIDTH-1:MULTIPLIER_WIDTH]} +     //add the multiplicant and then shift
                            {1'b0,multiplicant_i}, product_i[MULTIPLIER_WIDTH-1:1]};
             else if (shr_i==1)
               product_i<= {1'b0 , product_i[PRODUCT_WIDTH-1:1]};                    //shift
         end 
     end 
   
   //Control FSM
   //controlling the states based on the counter value  
   always@(posedge i_clk or posedge i_rst)
     begin
         if(i_rst==1)begin
             state<=S0;
             count_i<=0;
         end else begin
             state<=nextstate;
             if(state==S1) begin
                 count_i<=count_i-1;    
             end 
             else if (state==S0)        begin 
                 count_i<=(MULTIPLIER_WIDTH);
             end
         end 
     end 
   
   //Generating the controlling signals add_i and shr_i to control multiplication  
   always@(state,start_i,count_i,product_i)
     begin                                                        
         case (state) 
           S0 :begin 
               if (!TWOSCOMP) begin 
                   add_i <= product_i[0]; 
                   shr_i <= ~product_i[0];
               end
               else begin
                   add_i <= 0;
                   shr_i <= 0;
               end
               if  (start_i==1) 
                 nextstate <= S1; 
               else 
                 nextstate <= S0;
           end 
           S1:begin
               add_i <= product_i[0]; 
               shr_i <= ~product_i[0];
               if ((count_i==1 && !TWOSCOMP) || (count_i==0 && TWOSCOMP))
                 nextstate <= S2; 
               else 
                 nextstate <= S1; 
           end              
           S2 :begin  
               add_i <= 0;
               shr_i <= 0;
               nextstate <= S0;
           end
           default:begin
               add_i <= 0;
               shr_i <= 0;                                           
               nextstate <= S0;
           end
         endcase         
     end

   //generating done_i signal to indicate end of multiplication  
   always@(posedge i_clk or posedge i_rst) begin        
       if(i_rst==1) begin
           done_i <= 0;
       end else  begin 
           done_i <= (count_i == 1) ? 1'b1 : 1'b0;
       end 
   end 


   //assigning the product of signed multiplication to registered output
   generate
       if(TWOSCOMP==1 && OUTPUTREGISTERED == 1)
         always@(posedge i_clk or posedge i_rst) begin  
             if(i_rst==1) begin
                 o_product <= 0;
                 o_done <= 0;
             end else  begin 
                 o_done <= done_i;
                 if(sign_i ==1) begin 
                     o_product<=((~(product_i)) + 1); 
                 end   else  begin 
                     o_product<=product_i; 
                 end 
             end 
         end  

   //assigning the product of signed multiplication to unregistered output
   if(TWOSCOMP==1 && OUTPUTREGISTERED == 0)      
     always@(state,product_i,count_i,sign_i,done_i) begin        
         o_done <= done_i;
         if(sign_i ==1) begin 
             o_product<=((~(product_i)) + 1); 
         end  else begin  
             o_product<=product_i; 
         end 
     end  
endgenerate

   //assigning the product of unsigned multiplication to the output  
   generate
       if(TWOSCOMP==0) 
         always@(done_i,product_i)
           begin 
               o_product <=product_i;
               o_done <= done_i;        
           end
endgenerate 
   
endmodule // multiplier