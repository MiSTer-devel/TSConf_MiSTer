/*

  -----------------------------------------------------------------------------
   General Sound
  -----------------------------------------------------------------------------
   18.08.2018	Reworked first verilog version
   19.08.2018	Produce proper signed output
   20.08.2018	Use external SDR/DDR RAM for page 2 and up
   21.05.2020	Use external SDR/DDR RAM for all ROM/RAM

   CPU: Z80 @ 28MHz
   ROM: 32K
   RAM: up to 4096KB
   INT: 37.5KHz

   #xxBB Command register - регистр команд, доступный для записи
   #xxBB Status register - регистр состояния, доступный для чтения
  		bit 7 флаг данных
  		bit <6:1> Не определен
  		bit 0 флаг команд. Этот регистр позволяет определить состояние GS, в частности можно ли прочитать или записать очередной байт данных, или подать очередную команду, и т.п.
   #xxB3 Data register - регистр данных, доступный для записи. В этот регистр Спектрум записывает данные, например, это могут быть аргументы команд.
   #xxB3 Output register - регистр вывода, доступный для чтения. Из этого регистра Спектрум читает данные, идущие от GS

   Внутренние порта:
   #xx00 "расширенная память" - регистр доступный для записи
  		bit <3:0> переключают страницы по 32Kb, страница 0 - ПЗУ
  		bit <7:0> не используются

   порты 1 - 5 "обеспечивают связь с SPECTRUM'ом"
   #xx01 чтение команды General Sound'ом
  		bit <7:0> код команды
   #xx02 чтение данных General Sound'ом
  		bit <7:0> данные
   #xx03 запись данных General Sound'ом для SPECTRUM'a
  		bit <7:0> данные
   #xx04 чтение слова состояния General Sound'ом
  		bit 0 флаг команд
  		bit 7 флаг данных
   #xx05 сбрасывает бит D0 (флаг команд) слова состояния

   порты 6 - 9 "регулировка громкости" в каналах 1 - 4
   #xx06 "регулировка громкости" в канале 1
  		bit <5:0> громкость
  		bit <7:6> не используются
   #xx07 "регулировка громкости" в канале 2
  		bit <5:0> громкость
  		bit <7:6> не используются
   #xx08 "регулировка громкости" в канале 3
  		bit <5:0> громкость
  		bit <7:6> не используются
   #xx09 "регулировка громкости" в канале 4
  		bit <5:0> громкость
  		bit <7:6> не используются

   #xx0A устанавливает бит 7 слова состояния не равным биту 0 порта #xx00
   #xx0B устанавливает бит 0 слова состояния равным биту 5 порта #xx06

  Распределение памяти
  #0000 - #3FFF  -  первые 16Kb ПЗУ
  #4000 - #7FFF  -  первые 16Kb первой страницы ОЗУ
  #8000 - #FFFF  -  листаемые страницы по 32Kb
                    страница 0  - ПЗУ,
                    страница 1  - первая страница ОЗУ
                    страницы 2... ОЗУ

  Данные в каналы заносятся при чтении процессором ОЗУ по адресам  #6000 - #7FFF автоматически.

*/

module gs
(
	input         RESET,
	input         CLK,
	input         CE,

	input         A,
	input   [7:0] DI,
	output  [7:0] DO,
	input         CS_n, 
	input         WR_n,
	input         RD_n,

	output [20:0] MEM_ADDR,
	output  [7:0] MEM_DI,
	input   [7:0] MEM_DO,
	output        MEM_RD,
	output        MEM_WR,
	input         MEM_WAIT,
	output        MEM_ROM,

	output signed [14:0] OUT_A,
	output signed [14:0] OUT_B,
	output signed [14:0] OUT_C,
	output signed [14:0] OUT_D
);

parameter INT_DIV = 291;

// port #xxBB : #xxB3
assign DO = A ? {flag_data, 6'b111111, flag_cmd} : port_03;

// CPU
reg         int_n;
wire        cpu_m1_n;
wire        cpu_mreq_n;
wire        cpu_iorq_n;
wire        cpu_rd_n;
wire        cpu_wr_n;
wire [15:0] cpu_a_bus;
wire  [7:0] cpu_do_bus;

T80pa CPU
(
	.RESET_n(~RESET),
	.CLK(CLK),
	.CEN_p(CE & ~MEM_WAIT),
	.INT_n(int_n),
	.M1_n(cpu_m1_n),
	.MREQ_n(cpu_mreq_n),
	.IORQ_n(cpu_iorq_n),
	.RD_n(cpu_rd_n),
	.WR_n(cpu_wr_n),
	.A(cpu_a_bus),
	.DO(cpu_do_bus),
	.DI(cpu_di_bus)
);

// INT#
always @(posedge CLK) begin
	reg [9:0] cnt;

	if (RESET) begin
		cnt <= 0;
		int_n <= 1;
	end else if(CE) begin
		cnt <= cnt + 1'b1;
		if (cnt == INT_DIV) begin // 37.48kHz
			cnt <= 0;
			int_n <= 0;
		end
	end

	if (~cpu_iorq_n & ~cpu_m1_n) int_n <= 1;
end


reg flag_data;
reg flag_cmd;
always @(posedge CLK) begin
	if (~cpu_iorq_n & cpu_m1_n) begin
		case(cpu_a_bus[3:0])
			'h2: flag_data <= 0;
			'h3: flag_data <= 1;
			'h5: flag_cmd <= 0;
			'hA: flag_data <= ~port_00[0];
			'hB: flag_cmd <= port_09[5];
		endcase
	end
	if (~CS_n) begin
		if (~A & ~RD_n) flag_data <= 0;
		if (~A & ~WR_n) flag_data <= 1;
		if ( A & ~WR_n) flag_cmd <= 1;
	end
end


reg [7:0] port_BB;
reg [7:0] port_B3;
always @(posedge CLK) begin
	if (RESET) begin
		port_BB <= 0;
		port_B3 <= 0;
	end
	else if (~CS_n && ~WR_n) begin
		if(A) port_BB <= DI;
		else  port_B3 <= DI;
	end
end

reg [5:0] port_00;
reg [7:0] port_03;
reg signed [6:0] port_06, port_07, port_08, port_09;
reg signed [7:0] ch_a, ch_b, ch_c, ch_d;

always @(posedge CLK) begin
	if (RESET) begin
		port_00 <= 0;
		port_03 <= 0;
	end
	else begin
		if (~cpu_iorq_n & ~cpu_wr_n) begin
			case(cpu_a_bus[3:0])
				0: port_00 <= cpu_do_bus[5:0];
				3: port_03 <= cpu_do_bus;
				6: port_06 <= cpu_do_bus[5:0];
				7: port_07 <= cpu_do_bus[5:0];
				8: port_08 <= cpu_do_bus[5:0];
				9: port_09 <= cpu_do_bus[5:0];
			endcase
		end

		if (~cpu_mreq_n && ~cpu_rd_n && cpu_a_bus[15:13] == 3 && ~MEM_WAIT) begin
			case(cpu_a_bus[9:8])
				0: ch_a <= {~MEM_DO[7],MEM_DO[6:0]};
				1: ch_b <= {~MEM_DO[7],MEM_DO[6:0]};
				2: ch_c <= {~MEM_DO[7],MEM_DO[6:0]};
				3: ch_d <= {~MEM_DO[7],MEM_DO[6:0]};
			endcase
		end
	end
end

wire [7:0] cpu_di_bus =
	(~cpu_mreq_n && ~cpu_rd_n)                        ? MEM_DO  :
	(~cpu_iorq_n && ~cpu_rd_n && cpu_a_bus[3:0] == 1) ? port_BB :
	(~cpu_iorq_n && ~cpu_rd_n && cpu_a_bus[3:0] == 2) ? port_B3 :
	(~cpu_iorq_n && ~cpu_rd_n && cpu_a_bus[3:0] == 4) ? {flag_data, 6'b111111, flag_cmd} :
	8'hFF;


wire [5:0] page_addr = cpu_a_bus[15] ? port_00 : cpu_a_bus[14];

assign MEM_ADDR = {page_addr, &cpu_a_bus[15:14], cpu_a_bus[13:0]};
assign MEM_RD   = ~cpu_rd_n & ~cpu_mreq_n;
assign MEM_WR   = ~cpu_wr_n & ~cpu_mreq_n & ~MEM_ROM;
assign MEM_DI   = cpu_do_bus;
assign MEM_ROM  = ~|page_addr;


reg signed [14:0] out_a, out_b, out_c, out_d;
always @(posedge CLK) begin
	if (CE) begin
		out_a <= ch_a * port_06;
		out_b <= ch_b * port_07;
		out_c <= ch_c * port_08;
		out_d <= ch_d * port_09;
	end
end

assign OUT_A = out_a;
assign OUT_B = out_b;
assign OUT_C = out_c;
assign OUT_D = out_d;

endmodule
