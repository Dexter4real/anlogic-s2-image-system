// Team overlay; original lab3 font and Anlogic logo ROM remain unmodified.
module s2_osd #(parameter AUTO_PREVIEW=0)(
 input clk,rst_n,de,hs,vs,input [11:0] x,y,input [23:0] rgb,
 input [1:0] mode,contrast,input [2:0] bright,edge_level,input selected,
 output reg ode,ohs,ovs,output reg [23:0] orgb
);
 wire logo_region=(x<160 && y<160);
 wire [14:0] logo_addr=logo_region ? (({3'b0,y}<<7)+({3'b0,y}<<5)+x) : 15'd0;
 wire [24:0] logo_pixel;
 anlogic_logo_rom logo(.I_addr(logo_addr),.O_pixel(logo_pixel));
 wire text_region=(x>=176 && x<560 && y>=16 && y<80);
 wire [11:0] lx=x-176,ly=y-16;
 wire [4:0] col=lx[8:4];
 wire row=ly[5];
 reg [7:0] ch;
 wire [15:0] bits;
 osd_char_lib font(.I_char(ch),.I_row(ly[4:1]),.O_row_bits(bits));
 reg [7:0] n0,n1,n2,n3;
 reg highlight;
 always @* begin
  case(edge_level)
   0:begin n3="0";n2="0";n1="4";n0="0";end
   1:begin n3="0";n2="0";n1="8";n0="0";end
   2:begin n3="0";n2="1";n1="6";n0="0";end
   3:begin n3="0";n2="3";n1="2";n0="0";end
   default:begin n3="0";n2="6";n1="4";n0="0";end
  endcase
  ch=" ";highlight=0;
  if(!row) begin
   case(col)
    0:ch="M";1:ch="O";2:ch="D";3:ch="E";4:ch=":";
    6:ch=mode==0?"R":mode==1?"E":"E";
    7:ch=mode==0?"A":mode==1?"N":"D";
    8:ch=mode==0?"W":mode==1?"H":"G";
    9:ch=mode==2?"E":" ";
    12:ch=AUTO_PREVIEW?"A":" ";13:ch=AUTO_PREVIEW?"U":" ";
    14:ch=AUTO_PREVIEW?"T":" ";15:ch=AUTO_PREVIEW?"O":" ";
    default:ch=" ";
   endcase
  end else if(mode==1) begin
   case(col)
    0:ch="B";1:ch="R";2:ch=":";
    // M/P denote minus/plus; supported by the reference font.
    3:ch=bright<2?"M":bright>2?"P":" ";
    4:ch=(bright==0 || bright==4)?"3":bright==2?"0":"1";
    5:ch=(bright==0 || bright==4)?"2":bright==2?"0":"6";
    8:ch="C";9:ch="T";10:ch=":";
    11:ch=contrast==0?"0":"1";
    12:ch=contrast==0?"7":contrast==1?"0":"2";
    13:ch=contrast==1?"0":"5";
    default:ch=" ";
   endcase
   highlight=selected ? (col>=8 && col<=13) : (col<=5);
  end else if(mode==2) begin
   case(col)
    0:ch="T";1:ch="H";2:ch=":";3:ch=n3;4:ch=n2;5:ch=n1;6:ch=n0;
    default:ch=" ";
   endcase
   highlight=(col<=6);
  end
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin ode<=0;ohs<=0;ovs<=0;orgb<=0;end
  else begin
   ode<=de;ohs<=hs;ovs<=vs;
   if(!de) orgb<=0;
   else if(logo_region && logo_pixel[24]) orgb<=logo_pixel[23:0];
   else if(text_region) orgb<=bits[15-lx[3:0]] ? (highlight?24'hffff00:24'hffffff) : 24'h101820;
   else orgb<=rgb;
  end
 end
endmodule
