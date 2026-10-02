// Display adapter. The official video_out read datapath has two sampled edges
// from read request to RGB availability at a downstream sequential consumer.
// This assumption is separately checked with the original RTL + FIFO model.
module s2_mixer #(parameter WIDTH=1280,HEIGHT=720,DEFAULT_MODE=0,AUTO_PREVIEW=0,
 parameter KEY_CYCLES=750000)(
 input I_clk,I_rst_n,I_video_vsync,I_video_hsync,I_video_de,I_video_user,I_video_last,
 input [23:0] I_video_rd_data,input [3:0] I_keys_n,
 output O_video_rd_en,O_hdmi_vsync,O_hdmi_hsync,O_hdmi_de,
 output [23:0] O_hdmi_data
);
 assign O_video_rd_en=I_video_de;
 reg [1:0] dd,hd,vd;
 reg prev_vs;
 wire commit_frame=vd[1] && !prev_vs;
 reg [11:0] x,y;
 wire [3:0] press;
 reg [6:0] frame_count;
 reg [3:0] preview_press;
 wire [3:0] effective_press=AUTO_PREVIEW ? preview_press : press;
 wire [1:0] mode,contrast;wire [2:0] bright,edge_level;wire selected;
 s2_keys #(.STABLE_CYCLES(KEY_CYCLES)) keys(I_clk,I_rst_n,I_keys_n,press);
 s2_controls #(.DEFAULT_MODE(DEFAULT_MODE)) controls(I_clk,I_rst_n,commit_frame,effective_press,mode,bright,contrast,edge_level,selected);
 always @(posedge I_clk or negedge I_rst_n) begin
  if(!I_rst_n) begin dd<=0;hd<=0;vd<=0;prev_vs<=0;x<=0;y<=0;frame_count<=0;preview_press<=0;end
  else begin
   dd<={dd[0],I_video_de};hd<={hd[0],I_video_hsync};vd<={vd[0],I_video_vsync};prev_vs<=vd[1];
   preview_press<=0;
   if(commit_frame) begin
    x<=0;y<=0;
    if(frame_count==119) begin frame_count<=0;preview_press<=1;end
    else begin
     frame_count<=frame_count+1'b1;
     // Exercise real parameter logic too; neutral enhancement alone is invisible.
     if(mode==1) begin
      if(frame_count==29 || frame_count==39 || frame_count==69) preview_press<=8;
      if(frame_count==59 || frame_count==79) preview_press<=2;
      if(frame_count==99) preview_press<=4;
     end
     if(mode==2 && frame_count==59) preview_press<=4;
    end
   end else if(dd[1]) begin
    if(x==WIDTH-1) begin x<=0;y<=y==HEIGHT-1?0:y+1'b1;end
    else x<=x+1'b1;
   end
  end
 end
 wire pd,ph,pv;wire [11:0] px,py;wire [23:0] prgb;
 wire [1:0] pm,pc;wire [2:0] pb,pe;wire ps;
 s2_pixels #(.WIDTH(WIDTH)) pixels(I_clk,I_rst_n,dd[1],hd[1],vd[1],x,y,I_video_rd_data,
  mode,contrast,bright,edge_level,selected,pd,ph,pv,px,py,prgb,pm,pc,pb,pe,ps);
 s2_osd #(.AUTO_PREVIEW(AUTO_PREVIEW)) osd(I_clk,I_rst_n,pd,ph,pv,px,py,prgb,pm,pc,pb,pe,ps,
  O_hdmi_de,O_hdmi_hsync,O_hdmi_vsync,O_hdmi_data);
endmodule
