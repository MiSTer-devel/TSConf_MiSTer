
module sdram
(
	// Memory port
	input             clk,
	input             cyc,

	input             curr_cpu,
	input       [1:0] bsel,		// Active HI
	input      [23:0] A,
	input      [15:0] DI,
	output reg [15:0] DO,
	output reg [15:0] DO_cpu,
	input             REQ,
	input             RNW,

	// SDRAM Pin
	inout  reg [15:0] SDRAM_DQ,
	output reg [12:0] SDRAM_A,
	output reg  [1:0] SDRAM_BA,
	output reg        SDRAM_DQML,
	output reg        SDRAM_DQMH,
	output            SDRAM_nCS,
	output            SDRAM_nCAS,
	output            SDRAM_nRAS,
	output            SDRAM_nWE,
	output            SDRAM_CKE 
);
   
reg [2:0] sdr_cmd;

localparam SdrCmd_xx = 3'b111; // no operation
localparam SdrCmd_ac = 3'b011; // activate
localparam SdrCmd_rd = 3'b101; // read
localparam SdrCmd_wr = 3'b100; // write		
localparam SdrCmd_pr = 3'b010; // precharge all
localparam SdrCmd_re = 3'b001; // refresh
localparam SdrCmd_ms = 3'b000; // mode regiser set

always @(posedge clk) begin
	reg  [4:0] state;
	reg        rd;
	reg  [8:0] col;

	case (state)

	// Init
	'h00:	begin
			sdr_cmd <= SdrCmd_pr;		// PRECHARGE
			SDRAM_DQ <= 16'bZZZZZZZZZZZZZZZZ;
			SDRAM_A <= 0;
			SDRAM_BA <= 0;
			SDRAM_DQML <= 1;
			SDRAM_DQMH <= 1;
			state <= state + 1'd1;
		end

	// REFRESH
	'h03, 'h0A: begin
			sdr_cmd <= SdrCmd_re;
			state <= state + 1'd1;
		end

	// LOAD MODE REGISTER
	'h11: begin
			sdr_cmd <= SdrCmd_ms;
			SDRAM_A <= {3'b000, 1'b1, 2'b00, 3'b010, 1'b0, 3'b000};
			state <= state + 1'd1;
		end

	// Idle		
	'h18: begin
			rd <= 0;
			if (rd) begin
				DO <= SDRAM_DQ;
				if (curr_cpu) DO_cpu <= SDRAM_DQ;
			end
			if(cyc) begin
				if (REQ) begin
					sdr_cmd <= SdrCmd_ac;	// ACTIVE
					{SDRAM_A,SDRAM_BA,col} <= A;
					SDRAM_DQML <= ~(bsel[0] | RNW);
					SDRAM_DQMH <= ~(bsel[1] | RNW);
					rd <= RNW;
					state <= state + 1'd1;
				end else begin
					sdr_cmd <= SdrCmd_re;	// REFRESH
					state <= 'h13;
				end
			end
		end

	// Single read/write - with auto precharge
	'h1A: begin
			SDRAM_A <= {4'b0010, col};		// A10 = 1 enable auto precharge; A9..0 = column
			state <= 'h16;
			if (rd) sdr_cmd <= SdrCmd_rd;	// READ
			else begin
				sdr_cmd <= SdrCmd_wr;		// WRITE
				SDRAM_DQ <= DI;
			end
		end

	// NOP
	default:
		begin
			SDRAM_DQ <= 16'bZZZZZZZZZZZZZZZZ;
			sdr_cmd <= SdrCmd_xx;
			state <= state + 1'd1;
		end
	endcase
end

assign SDRAM_CKE  = 1;
assign SDRAM_nCS  = 0;
assign SDRAM_nRAS = sdr_cmd[2];
assign SDRAM_nCAS = sdr_cmd[1];
assign SDRAM_nWE  = sdr_cmd[0];

endmodule
