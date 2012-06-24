/***************************************************************************************************
** fpga_nes/src/cpu/apu/apu.v
*
*  Copyright (c) 2012, Brian Bennett
*  All rights reserved.
*
*  Redistribution and use in source and binary forms, with or without modification, are permitted
*  provided that the following conditions are met:
*
*  1. Redistributions of source code must retain the above copyright notice, this list of conditions
*     and the following disclaimer.
*  2. Redistributions in binary form must reproduce the above copyright notice, this list of
*     conditions and the following disclaimer in the documentation and/or other materials provided
*     with the distribution.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
*  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
*  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
*  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
*  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
*  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
*  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
*  Audio Processing Unit.
***************************************************************************************************/

module apu
(
  input  wire        clk_in,    // system clock signal
  input  wire        rst_in,    // reset signal
  input  wire        mute_in,   // disable all audio
  input  wire [15:0] a_in,      // addr input bus
  input  wire [7:0]  d_in,      // data input bus
  input  wire        r_nw_in,   // read/write select
  output wire        audio_out  // pwm audio output
);

localparam [15:0] FRAME_COUNTER_CNTL_MMR_ADDR = 16'h4017;

// CPU cycle pulse.  Ideally this would be generated in rp2a03 and shared by the apu and cpu.
reg  [5:0] q_clk_cnt;
wire [5:0] d_clk_cnt;
wire       cpu_cycle_pulse;
wire       apu_cycle_pulse;
wire       e_pulse;
wire       l_pulse;
wire       f_pulse;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_clk_cnt <= 6'h00;
      end
    else
      begin
        q_clk_cnt <= d_clk_cnt;
      end
  end

assign d_clk_cnt       = (q_clk_cnt == 6'h37) ? 6'h00 : q_clk_cnt + 6'h01;
assign cpu_cycle_pulse = (q_clk_cnt == 6'h00);


apu_div_const #(.PERIOD_BITS(1),
                .PERIOD(1)) apu_div_gen_apu_pulse(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .pulse_in(cpu_cycle_pulse),
  .pulse_out(apu_cycle_pulse)
);

wire [1:0] frame_counter_mode;
wire       frame_counter_mode_wr;

apu_frame_counter apu_frame_counter_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .apu_cycle_pulse_in(apu_cycle_pulse),
  .mode_in(frame_counter_mode),
  .mode_wr_in(frame_counter_mode_wr),
  .e_pulse_out(e_pulse),
  .l_pulse_out(l_pulse),
  .f_pulse_out(f_pulse)
);

assign frame_counter_mode    = d_in[7:6];
assign frame_counter_mode_wr = ~r_nw_in && (a_in == FRAME_COUNTER_CNTL_MMR_ADDR);

wire noise;

apu_noise apu_noise_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .apu_cycle_pulse_in(apu_cycle_pulse),
  .noise_out(noise)
);

assign audio_out = (mute_in) ? 1'b0 : noise;

endmodule
