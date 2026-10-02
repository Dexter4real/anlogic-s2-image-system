`timescale 1ns/1ps
module tb_controls;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,commit=0;reg [3:0] press=0,keys=15;
 wire [1:0] mode,contrast;wire [2:0] bright,edge_level;wire selected;
 wire [3:0] keypress;
 s2_controls dut(clk,rst,commit,press,mode,bright,contrast,edge_level,selected);
 s2_keys #(.STABLE_CYCLES(4)) kd(clk,rst,keys,keypress);
 integer pulses=0,i;
 always @(posedge clk) if(keypress[0]) pulses=pulses+1;
 task step;input [3:0] p;input f;
 begin @(negedge clk);press=p;commit=f;@(posedge clk);#1;end endtask
 task frame;begin step(0,1);step(0,0);end endtask
 initial begin
  step(0,0);rst=1;step(0,0);
  if(mode!=0||bright!=2||contrast!=1||edge_level!=2) $fatal(1,"reset");
  step(1,0);step(0,0);if(mode!=0) $fatal(1,"midframe changed");frame();
  if(mode!=1) $fatal(1,"mode commit");
  for(i=0;i<8;i=i+1)step(8,0);frame();if(bright!=4) $fatal(1,"brightness max");
  for(i=0;i<8;i=i+1)step(4,0);frame();if(bright!=0) $fatal(1,"brightness min");
  step(2,0);for(i=0;i<6;i=i+1)step(8,0);frame();
  if(!selected||contrast!=2) $fatal(1,"contrast select/max");
  for(i=0;i<6;i=i+1)step(4,0);frame();if(contrast!=0) $fatal(1,"contrast min");
  step(1,1);step(0,0);if(mode!=1) $fatal(1,"same edge priority");frame();if(mode!=2) $fatal(1,"edge mode");
  for(i=0;i<7;i=i+1)step(8,0);frame();if(edge_level!=4) $fatal(1,"edge max");
  for(i=0;i<7;i=i+1)step(4,0);frame();if(edge_level!=0) $fatal(1,"edge min");
  step(1,0);frame();step(8,0);frame();if(mode!=0||bright!=0) $fatal(1,"raw no-op");
  step(1,0);frame();if(mode!=1||contrast!=0||bright!=0) $fatal(1,"restore settings");
  step(12,0);frame();if(contrast!=0) $fatal(1,"plus/minus cancel");
  // Bouncing, sustained press, release and a second press.
  for(i=0;i<6;i=i+1)begin @(negedge clk);keys[0]=~keys[0];end
  keys=15;repeat(12)step(0,0);if(pulses!=0) $fatal(1,"bounce");
  keys=14;repeat(20)step(0,0);if(pulses!=1) $fatal(1,"held key repeats");
  keys=15;repeat(12)step(0,0);keys=14;repeat(12)step(0,0);if(pulses!=2) $fatal(1,"repress");
  rst=0;step(0,0);rst=1;step(0,0);if(mode!=0||bright!=2||contrast!=1||edge_level!=2) $fatal(1,"restart defaults");
  $display("PASS controls: frame commit, ranges, priority, persistence, reset, debounce");$finish;
 end
endmodule
