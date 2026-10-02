// Team RGB888 processor: fixed-rate display stream, no ready/backpressure.
// Output at edge n+4 for input sampled at edge n. Bubbles keep their position.
module s2_pixels #(parameter WIDTH=1280)(
 input clk,rst_n,input de,hs,vs,input [11:0] x,y,input [23:0] rgb,
 input [1:0] mode,contrast,input [2:0] bright,edge_level,input selected,
 output reg ode,ohs,ovs,output reg [11:0] ox,oy,output reg [23:0] orgb,
 output reg [1:0] omode,ocontrast,output reg [2:0] obright,oedge,
 output reg oselected
);
 function [7:0] enhance;
  input [7:0] c;input [2:0] b;input [1:0] k;
  reg signed [11:0] v,t;
  begin
   v=$signed({1'b0,c})-12'sd128;
   case(k)
    0:t=(v<<<1)+v;
    2:t=(v<<<2)+v;
    default:t=v<<<2;
   endcase
   // Arithmetic shift = floor division, including negative values.
   t=(t>>>2)+12'sd128+($signed({1'b0,b})-12'sd2)*12'sd16;
   enhance=t<0 ? 8'd0 : (t>255 ? 8'd255 : t[7:0]);
  end
 endfunction
 function [10:0] threshold;
  input [2:0] e;
  begin case(e)
   0:threshold=40;1:threshold=80;2:threshold=160;3:threshold=320;default:threshold=640;
  endcase end
 endfunction
 reg [23:0] raw_d[0:3],enh_d[0:3];
 reg [11:0] xd[0:3],yd[0:3];
 reg [1:0] md[0:3],cd[0:3];reg [2:0] bd[0:3],ed[0:3];
 reg [3:0] dd,hd,vd,sd;
 reg [7:0] gray0,gray1,top1,mid1;
 wire [9:0] luminance={2'b0,rgb[23:16]}+{1'b0,rgb[15:8],1'b0}+{2'b0,rgb[7:0]};
 // TD chooses the memory implementation. Its RAM_STYLE does not accept "block".
 // Keep read-before-write RTL semantics; never assume inferred ERAM usage.
 reg [7:0] line1[0:WIDTH-1];
 reg [7:0] line2[0:WIDTH-1];
 reg [7:0] t2,t1,m2,m1,b2,b1;
 reg signed [11:0] gx,gy;
 reg [11:0] mag;
 reg window2,window3;
 wire signed [11:0] a=$signed({1'b0,top1})-$signed({1'b0,t2});
 wire signed [11:0] b=$signed({1'b0,mid1})-$signed({1'b0,m2});
 wire signed [11:0] c=$signed({1'b0,gray1})-$signed({1'b0,b2});
 wire signed [11:0] d=$signed({1'b0,t2})-$signed({1'b0,b2});
 wire signed [11:0] e=$signed({1'b0,t1})-$signed({1'b0,b1});
 wire signed [11:0] f=$signed({1'b0,top1})-$signed({1'b0,gray1});
 integer i;
 // Synchronous RAM reads; never reset RAM arrays into thousands of registers.
 always @(posedge clk) begin
  if(rst_n && dd[0]) begin
   top1<=line2[xd[0]];mid1<=line1[xd[0]];
   line1[xd[0]]<=gray0;
  end
  if(rst_n && dd[1]) line2[xd[1]]<=mid1;
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   dd<=0;hd<=0;vd<=0;sd<=0;gray0<=0;gray1<=0;
   t2<=0;t1<=0;m2<=0;m1<=0;b2<=0;b1<=0;gx<=0;gy<=0;mag<=0;
   window2<=0;window3<=0;ode<=0;ohs<=0;ovs<=0;ox<=0;oy<=0;orgb<=0;
   omode<=0;ocontrast<=1;obright<=2;oedge<=2;oselected<=0;
   for(i=0;i<4;i=i+1) begin
    raw_d[i]<=0;enh_d[i]<=0;xd[i]<=0;yd[i]<=0;md[i]<=0;cd[i]<=1;bd[i]<=2;ed[i]<=2;
   end
  end else begin
   dd<={dd[2:0],de};hd<={hd[2:0],hs};vd<={vd[2:0],vs};sd<={sd[2:0],selected};
   raw_d[0]<=rgb;enh_d[0]<={enhance(rgb[23:16],bright,contrast),enhance(rgb[15:8],bright,contrast),enhance(rgb[7:0],bright,contrast)};
   xd[0]<=x;yd[0]<=y;md[0]<=mode;cd[0]<=contrast;bd[0]<=bright;ed[0]<=edge_level;
   gray0<=luminance[9:2];gray1<=gray0;
   for(i=1;i<4;i=i+1) begin
    raw_d[i]<=raw_d[i-1];enh_d[i]<=enh_d[i-1];xd[i]<=xd[i-1];yd[i]<=yd[i-1];
    md[i]<=md[i-1];cd[i]<=cd[i-1];bd[i]<=bd[i-1];ed[i]<=ed[i-1];
   end
   if(dd[1]) begin
    if(xd[1]==0) begin t2<=0;m2<=0;b2<=0;end
    else begin t2<=t1;m2<=m1;b2<=b1;end
    t1<=top1;m1<=mid1;b1<=gray1;
   end
   gx<=a+(b<<<1)+c;gy<=d+(e<<<1)+f;
   window2<=dd[1] && xd[1]>=2 && yd[1]>=2;
   mag<=(gx<0 ? -gx : gx)+(gy<0 ? -gy : gy);
   window3<=window2;
   ode<=dd[3];ohs<=hd[3];ovs<=vd[3];ox<=xd[3];oy<=yd[3];
   omode<=md[3];ocontrast<=cd[3];obright<=bd[3];oedge<=ed[3];oselected<=sd[3];
   if(!dd[3]) orgb<=0;
   else case(md[3])
    1:orgb<=enh_d[3];
    2:orgb<=(window3 && mag>=threshold(ed[3])) ? 24'hffffff : 24'h000000;
    default:orgb<=raw_d[3];
   endcase
  end
 end
endmodule
