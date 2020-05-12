
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
	output            SDRAM_DQML,
	output            SDRAM_DQMH,
	output            SDRAM_nCS,
	output            SDRAM_nCAS,
	output            SDRAM_nRAS,
	output            SDRAM_nWE,
	output            SDRAM_CKE,
	output            SDRAM_CLK
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
	reg  [1:0] dqm;
	reg [15:0] data;
	reg [23:0] Ar;
	reg        rq;

	sdr_cmd <= SdrCmd_xx;
	data <= SDRAM_DQ;
	SDRAM_DQ <= 16'bZ;
	state <= state + 1'd1;

	case (state)

	// Init
	0:	begin
			sdr_cmd <= SdrCmd_pr;		// PRECHARGE
			SDRAM_A <= 0;
			SDRAM_BA <= 0;
		end

	// REFRESH
	3,10: begin
			sdr_cmd <= SdrCmd_re;
		end

	// LOAD MODE REGISTER
	17: begin
			sdr_cmd <= SdrCmd_ms;
			SDRAM_A <= {3'b000, 1'b1, 2'b00, 3'b010, 1'b0, 3'b000};
		end

	// Idle
	24: begin
			if (rd) begin
				DO <= data;
				if (curr_cpu) DO_cpu <= data;
			end

			state <= state;
			Ar <= A;
			dqm <= RNW ? 2'b00 : ~bsel;
			rd <= 0;

			if(cyc) begin
				rq <= REQ;
				rd <= REQ & RNW;
				state <= state + 1'd1;
			end
		end

	// Start
	25: begin
			if (rq) begin
				{SDRAM_A,SDRAM_BA,col} <= Ar;
				sdr_cmd <= SdrCmd_ac;
			end else begin
				sdr_cmd <= SdrCmd_re;
				state <= 19;
			end
		end

	// Single read/write - with auto precharge
	27: begin
			SDRAM_A <= {dqm, 2'b10, col};
			state <= 21;
			if (rd) sdr_cmd <= SdrCmd_rd;
			else begin
				sdr_cmd <= SdrCmd_wr;
				SDRAM_DQ <= DI;
				state <= 22;
			end
		end

	endcase
end

assign SDRAM_CKE  = 1;
assign SDRAM_nCS  = 0;
assign SDRAM_nRAS = sdr_cmd[2];
assign SDRAM_nCAS = sdr_cmd[1];
assign SDRAM_nWE  = sdr_cmd[0];
assign SDRAM_DQML = SDRAM_A[11];
assign SDRAM_DQMH = SDRAM_A[12];

altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);

endmodule
