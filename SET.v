module SET ( clk , rst, en, central, radius, busy, valid, candidate );

input clk, rst;
input en;
input [15:0] central;   // [15:8]: X([15:12]),Y([11:8]) of circle A. [7:0]: X([7:4]),Y([3:0]) of circle B
input [7:0] radius;
output reg busy,valid;
output [3:0] candidate;
//
wire [15:0] sqrInput;      // if en -> square input is R
wire [15:0] dot_dist;
wire [7:0] sqrOutput [0:3]; 
wire toR,OofR,inC;
wire [3:0] _candidate; 
reg [1:0] states,statesN;
reg busyN;
wire fin0;
reg fin [0:3];
reg start [0:3];
reg k [0:1];
reg realEn;
reg [15:0] centralR,centralRN;
reg [7:0] radiusR,radiusRN;
wire stateChange [0:2];
wire busyChange [0:1];

// assign
assign sqrInput = (realEn)?{radiusR[7:4],4'b0,radiusR[3:0],4'b0}:dot_dist;
assign candidate = (valid)?_candidate:4'b0;
assign stateChange[0] = (states==2'b01 & !rst)?1'b1:1'b0;
assign stateChange[1] = (states==2'b10 & realEn)?1'b1:1'b0;
assign stateChange[2] = (states==2'b11 & fin[3])?1'b1:1'b0;
assign busyChange[0] = (states==2'b11)?1'b1:1'b0;
assign busyChange[1] = (states==2'b10)?1'b1:1'b0;
// module
Square sqr(
    .x1(sqrInput[15:12]), .y1(sqrInput[11:8]), .x2(sqrInput[7:4]), .y2(sqrInput[3:0]), 
    .isR(realEn), .s_x1(sqrOutput[0]), .s_x2(sqrOutput[2]), .s_y1(sqrOutput[1]), .s_y2(sqrOutput[3]), .toR(toR), .OutofR(OofR), .clk(clk)
);

compareSquare csq(
    .x1(sqrOutput[0]), .x2(sqrOutput[2]), .y1(sqrOutput[1]), .y2(sqrOutput[3]), .isR(toR), .inCircle(inC), .clk(clk), .OutofR(OofR)
);

counter Counter(
    .inCircle(inC), .clk(clk), .total(_candidate), .reset(rst), .en(start[3])
);

control ctrl(
    .c1(centralR[15:8]), .c2(centralR[7:0]), .enEdge(realEn), .x1(dot_dist[15:12]), .x2(dot_dist[7:4]), .y1(dot_dist[11:8]),
    .y2(dot_dist[3:0]), .clk(clk), .fin(fin0)
);


integer i;
always @(*) begin
    k[0] = fin0;
    k[1] = en;
    centralRN = central;
    radiusRN = radius;
    statesN = states;
    busyN = busy;

end
always @(posedge clk) begin 
    realEn <= k[1];
    centralR <= centralRN;
    radiusR <= radiusRN;
    fin[0] <= k[0];
    start[0] <= k[1];
end
always @(posedge clk or posedge rst) begin
    
    if (rst) begin
        for (i = 1;i<4;i = i+1) begin
            fin[i] <= 1'b0;
            start[i] <= 1'b0;
        end
        // if (fin[3]==1'b1) valid <= 1'b1;
        // else if (states == 2'b11) busy <= 1'b1;
        // else if (states == 2'b10) busy <= 1'b0;
    end
    else begin
        for (i = 1;i<4;i=i+1) begin
            fin[i] <= fin[i-1];
            start[i] <= start[i-1];
        end    
    end
    
end
always @(posedge clk) begin
    if (fin[3]) valid <= 1'b1;
    else valid <= 1'b0;
end

always @(busyChange[0] or busyChange[1]) begin
    if (busyChange[0]) busy <= 1'b1;
    else if (busyChange[1]) busy <= 1'b0;    
    else busy <= busyN;
end
// state

always @(posedge clk) begin
    if (rst) states<=2'b01;
    else if (stateChange[0])   states <= 2'b10;
    else if (stateChange[1])   states <= 2'b11;
    else if (stateChange[2]) states <= 2'b10;
    else states <= statesN;
end

endmodule

module Square(
    x1,
    y1,
    x2,
    y2,
    isR,
    s_x1,
    s_x2,
    s_y1,
    s_y2,
    toR,
    OutofR,
    clk
);
// isR: calculate radius, toR: give radius
// x1: the x dist between new dot and C1_x
// x12: the square of x1
input [3:0] x1,x2,y1,y2;
input isR,clk;
output reg [7:0] s_x1,s_x2,s_y1,s_y2;
output reg toR,OutofR;
reg OutofRNext;
reg [7:0] x12,x22,y12,y22;
reg [3:0] r1,r2,r1Next,r2Next;
reg toRNext;
always @(*) begin
    x12 = x1*x1;
    x22 = x2*x2;
    y12 = y1*y1;
    y22 = y2*y2;
    OutofRNext = 1'b0;
    if ((x1 > r1 || y1 > r1 || x2 > r2 || y2 > r2) &!isR) begin
        x12 = 8'b0;
        x22 = 8'b0;
        y12 = 8'b0;
        y22 = 8'b0;
        OutofRNext = 1'b1;
    end
end
always @(*) begin
    if (isR) begin
        r1Next = x1;
        r2Next = x2;
        toRNext = 1'b1;
    end
    else begin
        r1Next = r1;
        r2Next = r2;
        toRNext = 1'b0;
    end
end
always @(posedge clk) begin
    r1 <= r1Next;
    r2 <= r2Next;
    toR <= toRNext;
    s_x1 <= x12;
    s_x2 <= x22;
    s_y1 <= y12;
    s_y2 <= y22;
    OutofR <= OutofRNext;
end
endmodule

module compareSquare(
    x1,
    x2,
    y1,
    y2,
    isR,
    inCircle,
    clk,
    OutofR
);
// x1: square of dist x between new dot x and C1_x
// isR: input of square of radius from x1, y1
input [7:0] x1, x2, y1, y2;
input isR,OutofR,clk;
output reg inCircle;
reg [7:0] s_r1, s_r2;
reg [7:0] s_r1Next,s_r2Next;
reg inCircleNext;
always @(*) begin
    if (isR) begin
        s_r1Next = x1;
        s_r2Next = x2;
    end
    else begin
        s_r1Next = s_r1;
        s_r2Next = s_r2;
    end 
end
always @(*) begin
    if (OutofR) inCircleNext = 1'b0;
    else if ((x1 + y1) > s_r1 || (x2 + y2) > s_r2) inCircleNext = 1'b0;
    else inCircleNext = 1'b1;
end
always @(posedge clk ) begin
    s_r1 <= s_r1Next;
    s_r2 <= s_r2Next;
    inCircle <= inCircleNext;
end
endmodule

module counter(
    inCircle,
    clk,
    total,
    reset,
    en
);
input reset,inCircle,clk,en;
output reg [3:0] total;
reg [3:0] totalNext;
wire totalChange = reset|en;
always @(posedge clk) begin
    if (totalChange) total <= 4'b0;
    else total <= total + {3'b0,inCircle}; 
end
endmodule
// latch here: c1Next, c2Next, fin
module control(
    c1,
    c2,
    enEdge,
    x1,
    y1,
    x2,
    y2,
    clk,
    fin
);
// input [3:0] left, right, up, down;
input clk, enEdge;
input [7:0] c1, c2;
output reg [3:0] x1,x2,y1,y2;
output reg fin;
// reg [3:0] Eleft, Eright,Eup,Edown;
reg [3:0] xNow, yNow,xNext,yNext;
wire [3:0] x1Next,x2Next,y1Next,y2Next;
reg [7:0] _c1, _c2;
// always @(*) begin
//     if (Eleft > Eright || Edown > Eup)  fin = 1'b1;
//     else if (xNow==Eright && yNow== Eup) fin = 1'b1;
//     else fin = 1'b0;
// end
reg [7:0] c1Next, c2Next;
assign x1Next = (xNow > _c1[7:4])?(xNow - _c1[7:4]):(_c1[7:4] - xNow);
assign x2Next = (xNow > _c2[7:4])?(xNow - _c2[7:4]):(_c2[7:4] - xNow);
assign y1Next = (yNow > _c1[3:0])?(yNow - _c1[3:0]):(_c1[3:0] - yNow);
assign y2Next = (yNow > _c2[3:0])?(yNow - _c2[3:0]):(_c2[3:0] - yNow);
always @(*) begin
    c1Next = _c1;
    c2Next = _c2;
    if(enEdge) begin
    c1Next = c1;
    c2Next = c2;
    xNext = 4'd0;
    yNext = 4'd0;
    fin = 1'b0;
    end
    else if (xNow == 4'd9) begin
        if (yNow == 4'd9) begin
            fin = 1'b1;
            xNext = 4'b0;
            yNext = 4'b0;
        end
        else begin
            fin = 1'b0;
            xNext = 4'b0;
            yNext = yNow + 1;  
        end
    end
    else begin
        fin = 1'b0;
        xNext = xNow + 1;
        yNext = yNow;
    end
 

end
always @( posedge clk ) begin
        xNow <= xNext;
        yNow <= yNext;
        _c1 <= c1Next;
        _c2 <= c2Next;
        x1 <= x1Next;
        y1 <= y1Next;
        x2 <= x2Next;
        y2 <= y2Next;

end
endmodule

