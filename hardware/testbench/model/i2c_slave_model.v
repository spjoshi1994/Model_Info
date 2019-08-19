//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2009, SiliconBlue Technologies, Inc.
//////////////////////////////////////////////////////////////////////////////
//
// Filename: i2c_slave_model.v
// Revision: 12/20/2009
// Contact:  eric@siliconbluetech.com + Wilson
// Purpose:  This is a model of an I2C Device.  Thanks, Richard and John!
//
//////////////////////////////////////////////////////////////////////////////
//
// SILICONBLUE TECHNOLOGIES PROVIDES THIS APPLICATION NOTE TO YOU “AS-IS”.
// ALL WARRANTIES, REPRESENTATIONS, OR GUARANTEES OF ANY KIND (WHETHER
// EXPRESS, IMPLIED, OR STATUTORY) INCLUDING, WITHOUT LIMITATION, WARRANTIES
// OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR A PARTICULAR PURPOSE,
// ARE SPECIFICALLY DISCLAIMED.
//
// LIMITATION OF LIABILITY: SUBJECT TO APPLICABLE LAWS: (1) IN NO EVENT WILL
// SILICONBLUE TECHNOLOGIES OR ITS LICENSORS BE LIABLE FOR ANY LOSS OF DATA,
// LOST PROFITS, COST OF PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, OR FOR
// ANY SPECIAL, INCIDENTAL, CONSEQUENTIAL OR INDIRECT DAMAGES ARISING FROM
// THE USE OR IMPLEMENTATION OF THE APPLICATION NOTE, IN WHOLE OR IN PART,
// HOWEVER CAUSED AND UNDER ANY THEORY OF LIABILITY; (2) THIS LIMITATION WILL
// APPLY EVEN IF SILICONBLUE TECHNOLOGIES HAS BEEN ADVISED OF THE POSSIBILITY
// OF SUCH DAMAGES; (3) THIS LIMITATION SHALL APPLY NOTWITHSTANDING THE
// FAILURE OF THE ESSENTIAL PURPOSE OF ANY LIMITED REMEDIES HEREIN.
//
//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2009, SiliconBlue Technologies, Inc.
//////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////
//
// EJC: Made numberous changes to support my verification needs.
// WKY: Added support for not my slave address
//
//////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE rev.B2 compliant synthesizable I2C Slave model    ////
////                                                             ////
////                                                             ////
////  Authors: Richard Herveille (richard@asics.ws) www.asics.ws ////
////           John Sheahan (jrsheahan@optushome.com.au)         ////
////                                                             ////
////  Downloaded from: http://www.opencores.org/projects/i2c/    ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2001,2002 Richard Herveille                   ////
////                         richard@asics.ws                    ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
 
//  CVS Log
//
//  $Id: i2c_slave_model.v,v 1.7 2006-09-04 09:08:51 rherveille Exp $
//
//  $Date: 2006-09-04 09:08:51 $
//  $Revision: 1.7 $
//  $Author: rherveille $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//               $Log: not supported by cvs2svn $
//               Revision 1.6  2005/02/28 11:33:48  rherveille
//               Fixed Tsu:sta timing check.
//               Added Thd:sta timing check.
//
//               Revision 1.5  2003/12/05 11:05:19  rherveille
//               Fixed slave address MSB='1' bug
//
//               Revision 1.4  2003/09/11 08:25:37  rherveille
//               Fixed a bug in the timing section. Changed 'tst_scl' into 'tst_sto'.
//
//               Revision 1.3  2002/10/30 18:11:06  rherveille
//               Added timing tests to i2c_model.
//               Updated testbench.
//
//               Revision 1.2  2002/03/17 10:26:38  rherveille
//               Fixed some race conditions in the i2c-slave model.
//               Added debug information.
//               Added headers.
//
 
`timescale 1 ns / 1 ps
 
module i2c_slave_model
    #(
      parameter I2C_ADR = 7'b001_1001
      )
    (
     input wire scl,
     inout wire sda,
     input wire no_ack,
    // input      pattern_start,
    // output reg pattern_end,
     output wire atn
    
   );

  // generate interrupt
  event request_attention;
  event service_completed;
  reg atn_reg;
    wire pattern_start;
    reg  pattern_end;
  always
  begin
    atn_reg <= 1'bz;
    @(request_attention);
    atn_reg <= 1'b0;
    @(service_completed);
  end
  assign atn = atn_reg;

  reg [7:0] mem [15:0];
            
  initial
  begin
    mem[0] = 0;
    mem[1] = 0;
    mem[2] = 0;
    mem[3] = 0;
    mem[4] = 0;
    mem[5] = 0;
    mem[6] = 0;
    mem[7] = 0;
    mem[8] = 0;
    mem[9] = 0;
    mem[10] = 0;
    mem[11] = 0;
    mem[12] = 0;
    mem[13] = 0;
    mem[14] = 0;
    mem[15] = 0;
  end

  reg [7:0] mem_do = 8'h00;
  reg [7:0] temp = 8'h00;
  reg [3:0] mem_addr = 4'b0000;

  reg sta;
  reg d_sta;
  reg sto;
  reg [7:0] sr;
  reg rw;

  reg [7:0] td = 21;  // Test data
 
  wire my_adr;
  wire i2c_reset;
  reg [2:0] bit_cnt;
  wire acc_done;
  reg ld;
  reg sda_o;
  wire sda_dly;
  integer file_ptr, x=-1;
    reg [7:0] acc_data;
    reg [7:0] reg_addr;
    
  parameter idle = 3'b000;
  parameter slave_ack = 3'b001;
  parameter data = 3'b010;
  parameter data_ack = 3'b011;
  parameter not_mine = 3'b111;

    reg [2:0] state;
    reg [2:0] data_count_i = 0;
    
    initial begin
       // @ (posedge pattern_start);
        @ (acc_done && my_adr);
        file_ptr = $fopen("../../testbench/model/walking_raw.txt", "r");
       
        x = 0;
        wait (x == -1);
        $fclose (file_ptr);
        pattern_end = 1;
        #1;
        pattern_end = 0;

    end

  initial
  begin
    sda_o = 1'b1;
    state = idle;
  end

  // generate shift register
  always @(posedge scl) sr <= #1 {sr[6:0],sda};

  // detect my_address
  assign my_adr = (sr[7:5] == I2C_ADR[6:4]);

  // generate bit-counter
  always @(posedge scl)
  begin
    if(ld) bit_cnt <= #1 3'b111;
    else bit_cnt <= #1 bit_cnt - 3'h1;
  end

  // generate access done signal
  assign acc_done = !(|bit_cnt);

  // generate delayed version of sda
  assign #1 sda_dly = sda;

  // detect start condition
  always @(negedge sda)
  begin
    if(scl)
    begin
      sta <= #1 1'b1;
      d_sta <= #1 1'b0;
      sto <= #1 1'b0;
        `ifdef VERBOSE
      $display();
      $display("     Note: i2c_slave_model %h detected start condition.", I2C_ADR);
        `endif
    end
    else sta <= #1 1'b0;
  end

  always @(posedge scl) d_sta <= #1 sta;

  // detect stop condition
  always @(posedge sda)
  begin
    if(scl)
    begin
      sta <= #1 1'b0;
      sto <= #1 1'b1;
        `ifdef VERBOSE
      $display("     Note: i2c_slave_model %h detected stop condition.", I2C_ADR);
      $display();
        `endif
    end
    else sto <= #1 1'b0;
  end

  // generate i2c_reset signal
  assign i2c_reset = sta || sto;

  // generate statemachine
  always @(negedge scl or posedge sto)
  begin
    if (sto || (sta && !d_sta))
    begin
      state <= #1 idle;
      sda_o <= #1 1'b1;
      ld <= #1 1'b1;
    end
    else
    begin
      sda_o <= #1 1'b1;
      ld <= #1 1'b0;
      case(state)
	  idle:
          if (acc_done && !my_adr)   // Not mine, ignore until next one
            state <= #1 not_mine;
          else if (acc_done && my_adr)
          begin
            state <= #1 slave_ack;
            rw <= #1 sr[0];
            mem_addr <= #1 sr[4:1];
            sda_o <= #1 no_ack;   
            #2;
              `ifdef VERBOSE
            if (rw) $display("     Note: i2c_slave_model %h claimed rd cmd", I2C_ADR);
            if (!rw) $display("     Note: i2c_slave_model %h claimed wr cmd", I2C_ADR);
              `endif

              
            if (rw)
            begin
                if (reg_addr == 8'hA8) begin
                    if (x != -1) begin
                        x = $fscanf(file_ptr, " %h:\n", acc_data);                
                        mem_do <= #1 acc_data; //mem[mem_addr];
                        temp <= #1 acc_data;
                    end else
                        mem_do <= 0;
                        temp <= 0;
                end
                
                //$fclose(file_ptr);
                
//              td <= td + 1'b1;
              //#2 $display("     Note: i2c_slave_model %h fetched rd data 20", I2C_ADR);
            end
          end
 	  slave_ack:
          begin
            if (rw)
            begin
              state <= #1 data;
              sda_o <= #1 mem_do[7];
            end
            else state <= #1 data;
            ld    <= #1 1'b1;
          end
        data: begin
            if (rw) sda_o <= #1 mem_do[7];
            if(acc_done) begin
                state <= #1 data_ack;              mem_addr <= #2 mem_addr + 8'h1;
                sda_o <= #1 rw || no_ack;  // *** Wilson
                if (rw) begin
              `ifdef VARDATA
                    td <= #2 td + 1'b1;
              `endif
                    mem_do <= 0;
                    if (data_count_i == 5)
                        data_count_i <= 0;
                    else
                        data_count_i <= data_count_i + 1;
                end
                
                if (!rw)begin
                    mem[mem_addr] <= #1 sr;
                    reg_addr <= sr[7:0];
              `ifdef VERBOSE
                    #2 $display("     Note: i2c_slave_model %h stored wr data %x.", I2C_ADR, sr);
              `endif
                end
            end
        end
        data_ack: begin
            -> service_completed;
            ld <= #1 1'b1;
            if (rw)
                if(sr[0]) begin
                    state <= #1 idle;
                    sda_o <= #1 1'b1;
                end else begin
                    if (reg_addr == 8'hA8) begin
                        if (x != -1) begin
                            x = $fscanf(file_ptr, " %h:\n", acc_data);
                            mem_do <= #1 acc_data;
                        end else
                            mem_do <= 0;
                    end
                    state <= #1 data;
                    sda_o <= #1 acc_data[7];
                end
            else begin
                state <= #1 data;
                sda_o <= #1 1'b1;
            end
        end
      endcase
    end
  end

  // read data from memory
  always @(posedge scl) if(!acc_done && rw) mem_do <= #1 {mem_do[6:0], 1'b1};

  reg [7:0] mem_do_reg = 8'h00;  
  //register mem_do for display. Fix for the bug, which was displaying an
  //extra fetch in the output 
  always @(posedge scl) mem_do_reg <= mem_do;
                  `ifdef VERBOSE
  always @(negedge scl)
     if ((rw == 1)&& (state == data) && (bit_cnt == 7))
         #5 $display("     Note: i2c_slave_model %h fetched rd data %x", I2C_ADR, mem_do_reg);
         `endif
  

  // generate tri-states
  assign sda = sda_o ? 1'bz : 1'b0;

endmodule
