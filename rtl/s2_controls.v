// Team implementation. All state belongs to the display pixel clock domain.
module s2_controls #(parameter DEFAULT_MODE=0)(
 input clk, rst_n, frame_commit, input [3:0] press,
 output reg [1:0] mode, output reg [2:0] bright,
 output reg [1:0] contrast, output reg [2:0] edge_level,
 output reg selected
);
 reg [1:0] pending_mode, pending_contrast;
 reg [2:0] pending_bright, pending_edge;
 reg pending_selected;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   pending_mode<=DEFAULT_MODE; mode<=DEFAULT_MODE;
   pending_bright<=2; bright<=2; pending_contrast<=1; contrast<=1;
   pending_edge<=2; edge_level<=2; pending_selected<=0; selected<=0;
  end else begin
   // Priority: mode > select > decrement > increment. No auto-repeat.
   if(press[0]) pending_mode <= pending_mode==2 ? 0 : pending_mode+1'b1;
   else if(press[1] && pending_mode==1) pending_selected<=~pending_selected;
   else if(press[2] ^ press[3]) begin
    if(pending_mode==1 && !pending_selected) begin
     if(press[2] && pending_bright>0) pending_bright<=pending_bright-1'b1;
     if(press[3] && pending_bright<4) pending_bright<=pending_bright+1'b1;
    end
    if(pending_mode==1 && pending_selected) begin
     if(press[2] && pending_contrast>0) pending_contrast<=pending_contrast-1'b1;
     if(press[3] && pending_contrast<2) pending_contrast<=pending_contrast+1'b1;
    end
    if(pending_mode==2) begin
     if(press[2] && pending_edge>0) pending_edge<=pending_edge-1'b1;
     if(press[3] && pending_edge<4) pending_edge<=pending_edge+1'b1;
    end
   end
   // An event on this edge is intentionally applied at the next frame_commit.
   if(frame_commit) begin
    mode<=pending_mode; bright<=pending_bright; contrast<=pending_contrast;
    edge_level<=pending_edge; selected<=pending_selected;
   end
  end
 end
endmodule

module s2_keys #(parameter STABLE_CYCLES=750000)(
 input clk,rst_n,input [3:0] keys_n,output reg [3:0] press
);
 (* async_reg="true" *) reg [3:0] sync1,sync2;
 reg [3:0] stable;
 reg [19:0] count[0:3];
 integer i;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   sync1<=4'hf;sync2<=4'hf;stable<=4'hf;press<=0;
   for(i=0;i<4;i=i+1) count[i]<=0;
  end else begin
   sync1<=keys_n;sync2<=sync1;press<=0;
   for(i=0;i<4;i=i+1) begin
    if(sync2[i]==stable[i]) count[i]<=0;
    else if(count[i]==STABLE_CYCLES-1) begin
     stable[i]<=sync2[i];count[i]<=0;
     if(!sync2[i]) press[i]<=1;
    end else count[i]<=count[i]+1'b1;
   end
  end
 end
endmodule
