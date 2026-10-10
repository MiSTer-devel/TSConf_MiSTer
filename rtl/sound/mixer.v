module mixer
(
   input               CLK,
   input               ACB,
   input               BOOST,

   input         [7:0] PSG_CH_A_0, // 0..255
   input         [7:0] PSG_CH_B_0, // 0..255
   input         [7:0] PSG_CH_C_0, // 0..255
   input signed [15:0] OPN_0,      // -32768..32767
   input         [7:0] PSG_CH_A_1, // 0..255
   input         [7:0] PSG_CH_B_1, // 0..255
   input         [7:0] PSG_CH_C_1, // 0..255
   input signed [15:0] OPN_1,      // -32768..32767
   input signed [14:0] GS_A,       // -8064..8001
   input signed [14:0] GS_B,       // -8064..8001
   input signed [14:0] GS_C,       // -8064..8001
   input signed [14:0] GS_D,       // -8064..8001
   input         [7:0] COVOX_A,    // 0..255
   input         [7:0] COVOX_B,    // 0..255
   input         [7:0] COVOX_C,    // 0..255
   input         [7:0] COVOX_D,    // 0..255
   input         [7:0] SAA_L,      // 0..255
   input         [7:0] SAA_R,      // 0..255
   input signed [15:0] OPL_L,      // -32768..32767
   input signed [15:0] OPL_R,      // -32768..32767
   input               BEEPER,     // 0..1
   input               TAPE_OUT,   // 0..1
   input               TAPE_IN,    // 0..1

   output signed [15:0] SOUND_L,
   output signed [15:0] SOUND_R
);

reg  [8:0] psg_a, psg_b, psg_c;
reg [11:0] psg_l, psg_r;
always @(posedge CLK) begin
   psg_a <=                                 // 0..510
       {1'b0, PSG_CH_A_1} +                 // 0..255
       {1'b0, PSG_CH_A_0} ;                 // 0..255
   psg_b <=                                 // 0..510
       {1'b0, PSG_CH_B_1} +                 // 0..255
       {1'b0, PSG_CH_B_0} ;                 // 0..255
   psg_c <=                                 // 0..510
       {1'b0, PSG_CH_C_1} +                 // 0..255
       {1'b0, PSG_CH_C_0} ;                 // 0..255
   psg_l <=                                 // 0..1530
       {2'b00, psg_a, 1'b0} +               // 0..1020
       {3'b000, ACB ? psg_c : psg_b};       // 0..510
   psg_r <=                                 // 0..1530
       {2'b00, ACB ? psg_b : psg_c, 1'b0} + // 0..1020
       {3'b000, ACB ? psg_c : psg_b};       // 0..510
end

reg signed [16:0] opn_s;
always @(posedge CLK) begin
   opn_s <=                                 // -65536..65534
       OPN_0 +                              // -32768..32767
       OPN_1 ;                              // -32768..32767
end

reg signed [15:0] gs_l, gs_r;
always @(posedge CLK) begin
   gs_l <=                                  // -16128..16002
       GS_A +                               // -8064..8001
       GS_B ;                               // -8064..8001
   gs_r <=                                  // -16128..16002
       GS_C +                               // -8064..8001
       GS_D ;                               // -8064..8001
end

reg [8:0] covox_l, covox_r;
always @(posedge CLK) begin
   covox_l <=                               // 0..510
       COVOX_A +                            // 0..255
       COVOX_B ;                            // 0..255
   covox_r <=                               // 0..510
       COVOX_C +                            // 0..255
       COVOX_D ;                            // 0..255
end

reg signed [20:0] mix_l, mix_r;
always @(posedge CLK) begin
   mix_l <=                                                // -261120..648322
       $signed({3'b0,            psg_l,          6'b0 }) + // 0..97920
       $signed({{3{opn_s[16]}},  opn_s,          1'b0 }) + // -131072..131068
       $signed({{3{gs_l[15]}},   gs_l,           2'b0 }) + // -64512..64008
       $signed({4'b0,            covox_l,        8'b0 }) + // 0..130560
       $signed({4'b0,            SAA_L,          9'b0 }) + // 0..130560
       $signed({{4{OPL_L[15]}},  OPL_L,          1'b0 }) + // -65536..65534
       $signed({6'b0, BEEPER, TAPE_OUT, TAPE_IN, 12'b0}) ; // 0..28672
   mix_r <=                                                // -261120..648322
       $signed({3'b0,            psg_r,          6'b0 }) + // 0..97920
       $signed({{3{opn_s[16]}},  opn_s,          1'b0 }) + // -131072..131068
       $signed({{3{gs_r[15]}},   gs_r,           2'b0 }) + // -64512..64008
       $signed({4'b0,            covox_r,        8'b0 }) + // 0..130560
       $signed({4'b0,            SAA_R,          9'b0 }) + // 0..130560
       $signed({{4{OPL_R[15]}},  OPL_R,          1'b0 }) + // -65536..65534
       $signed({6'b0, BEEPER, TAPE_OUT, TAPE_IN, 12'b0}) ; // 0..28672
end

wire signed [21:0] ac_l, ac_r;
dc_blocker dc_blocker_l(CLK, mix_l, ac_l);
dc_blocker dc_blocker_r(CLK, mix_r, ac_r);

wire signed [15:0] compressed_l, compressed_r;
compressor compressor_l(CLK, ac_l, compressed_l);
compressor compressor_r(CLK, ac_r, compressed_r);

assign SOUND_L = BOOST ? compressed_l : mix_l[20:5];
assign SOUND_R = BOOST ? compressed_r : mix_r[20:5];

endmodule



module dc_blocker
(
	input                     clk,
	input signed       [20:0] inp,
	output reg signed  [21:0] out
);

reg signed [40:0] dc = 0;
always @(posedge clk) begin
	dc <= dc + inp - (dc >>> 20);
	out <= {inp[20], inp} - {dc[40], dc[40:20]};
end

endmodule



module compressor
(
	input                    clk,
	input signed      [21:0] inp,
	output reg signed [15:0] out
);

localparam [21:0] X8  = ((22'd32767 * 22'd15) / 22'd127) + 22'd1;
localparam [21:0] B8  = X8 * 22'd8;

reg [21:0] magnitude;
reg        negative;
always @(posedge clk) begin
	magnitude <= inp[21] ? -inp : inp;
	negative <= inp[21];
end

reg        above_knee;
reg [22:0] boosted;
reg [22:0] delta;
reg        negative_d;
always @(posedge clk) begin
	negative_d <= negative;
	above_knee <= magnitude >= (X8 << 4);
	boosted <= (magnitude + 22'd1) >> 1;
	delta <= {1'b0, magnitude} - {1'b0, (X8 << 4)} + 23'd128;
end

reg [22:0] compressed;
reg        compressed_negative;
always @(posedge clk) begin
	compressed <= above_knee ? (delta >> 8) + B8 : boosted;
	compressed_negative <= negative_d;
end

always @(posedge clk) begin
	if(compressed > 23'd32767)
		out <= compressed_negative ? -16'sd32767 : 16'sd32767;
	else
		out <= compressed_negative ? -$signed(compressed[15:0]) : $signed(compressed[15:0]);
end

endmodule
