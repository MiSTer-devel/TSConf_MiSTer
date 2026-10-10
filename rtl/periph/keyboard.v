module keyboard
(
  input             clk,
  input             reset,
  input       [7:0] a,
  output      [4:0] keyb,
  output reg        key_reset,
  output reg  [7:0] scancode,
  input             scancode_ack,
  input             scancode_clr,
  input             matrix_update,
  input      [10:0] ps2_key,
  input       [2:0] cfg_joystick1,
  input       [2:0] cfg_joystick2,
  input       [7:0] joystick1,
  input       [7:0] joystick2
);

reg [4:0] keys [7:0];
reg [4:0] keys_r [7:0];

wire [4:0] row0 = a[0]? 5'b11111 : keys_r[0];
wire [4:0] row1 = a[1]? 5'b11111 : keys_r[1];
wire [4:0] row2 = a[2]? 5'b11111 : keys_r[2];
wire [4:0] row3 = a[3]? 5'b11111 : keys_r[3];
wire [4:0] row4 = a[4]? 5'b11111 : keys_r[4];
wire [4:0] row5 = a[5]? 5'b11111 : keys_r[5];
wire [4:0] row6 = a[6]? 5'b11111 : keys_r[6];
wire [4:0] row7 = a[7]? 5'b11111 : keys_r[7];
assign keyb = row0 & row1 & row2 & row3 & row4 & row5 & row6 & row7;


reg matrix_update_r;
always @(posedge clk)
  matrix_update_r <= matrix_update;

always @(posedge clk or posedge reset) begin
  integer i;
  if (reset) begin
    for (i = 0; i < 8; i = i + 1)
      keys_r[i] <= 5'b11111;
  end
  else if (matrix_update && !matrix_update_r) begin
    for (i = 0; i < 8; i = i + 1)
      keys_r[i] <= keys[i];
  end
end


wire [15:0] joys = {joystick2, joystick1};
reg [15:0] joys_r = 0;
reg joys_ch = 0;
reg [3:0] joys_chn;

reg strobe = 0;
reg press;
reg [8:0] code;

reg flg = 0;
always @(posedge clk)
  flg <= ps2_key[10];


always @(posedge clk) begin
  strobe <= 1'b0;

  if (joys[15] != joys_r[15]) {joys_ch, joys_chn} <= {1'b1, 4'd15};
  if (joys[14] != joys_r[14]) {joys_ch, joys_chn} <= {1'b1, 4'd14};
  if (joys[13] != joys_r[13]) {joys_ch, joys_chn} <= {1'b1, 4'd13};
  if (joys[12] != joys_r[12]) {joys_ch, joys_chn} <= {1'b1, 4'd12};
  if (joys[11] != joys_r[11]) {joys_ch, joys_chn} <= {1'b1, 4'd11};
  if (joys[10] != joys_r[10]) {joys_ch, joys_chn} <= {1'b1, 4'd10};
  if (joys[9]  != joys_r[9])  {joys_ch, joys_chn} <= {1'b1, 4'd9};
  if (joys[8]  != joys_r[8])  {joys_ch, joys_chn} <= {1'b1, 4'd8};
  if (joys[7]  != joys_r[7])  {joys_ch, joys_chn} <= {1'b1, 4'd7};
  if (joys[6]  != joys_r[6])  {joys_ch, joys_chn} <= {1'b1, 4'd6};
  if (joys[5]  != joys_r[5])  {joys_ch, joys_chn} <= {1'b1, 4'd5};
  if (joys[4]  != joys_r[4])  {joys_ch, joys_chn} <= {1'b1, 4'd4};
  if (joys[3]  != joys_r[3])  {joys_ch, joys_chn} <= {1'b1, 4'd3};
  if (joys[2]  != joys_r[2])  {joys_ch, joys_chn} <= {1'b1, 4'd2};
  if (joys[1]  != joys_r[1])  {joys_ch, joys_chn} <= {1'b1, 4'd1};
  if (joys[0]  != joys_r[0])  {joys_ch, joys_chn} <= {1'b1, 4'd0};

  // MiSTer toggles ps2_key[10] on every event, both press and release.
  if (ps2_key[10] != flg) begin
    strobe <= 1'b1;
    {press, code} <= ps2_key[9:0];
  end
  else if (joys_ch) begin
    joys_ch <= 1'b0;
    joys_r[joys_chn] <= joys[joys_chn];
    case (cfg_joystick1)
    3'b001: begin // Sinclair 1
      case (joys_chn)
      0:  {strobe, press, code} <= {1'b1, joys[0 ], 9'h3d};  // Right  | 7
      1:  {strobe, press, code} <= {1'b1, joys[1 ], 9'h36};  // Left   | 6
      2:  {strobe, press, code} <= {1'b1, joys[2 ], 9'h3e};  // Down   | 8
      3:  {strobe, press, code} <= {1'b1, joys[3 ], 9'h46};  // Up     | 9
      4:  {strobe, press, code} <= {1'b1, joys[4 ], 9'h45};  // Fire 1 | 0
      5:  {strobe, press, code} <= {1'b1, joys[5 ], 9'h3a};  // Fire 2 | m
      6:  {strobe, press, code} <= {1'b1, joys[6 ], 9'h31};  // Fire 3 | n
      7:  {strobe, press, code} <= {1'b1, joys[7 ], 9'h32};  // Fire 4 | b
      endcase
    end
    3'b010: begin // Sinclair 2
      case (joys_chn)
      0:  {strobe, press, code} <= {1'b1, joys[0 ], 9'h1e};  // Right  | 2
      1:  {strobe, press, code} <= {1'b1, joys[1 ], 9'h16};  // Left   | 1
      2:  {strobe, press, code} <= {1'b1, joys[2 ], 9'h26};  // Down   | 3
      3:  {strobe, press, code} <= {1'b1, joys[3 ], 9'h25};  // Up     | 4
      4:  {strobe, press, code} <= {1'b1, joys[4 ], 9'h2e};  // Fire 1 | 5
      5:  {strobe, press, code} <= {1'b1, joys[5 ], 9'h1a};  // Fire 2 | z
      6:  {strobe, press, code} <= {1'b1, joys[6 ], 9'h22};  // Fire 3 | x
      7:  {strobe, press, code} <= {1'b1, joys[7 ], 9'h21};  // Fire 4 | c
      endcase
    end
    3'b011: begin // Cursor
      case (joys_chn)
      0:  {strobe, press, code} <= {1'b1, joys[0 ], 9'h174}; // Right  | Right
      1:  {strobe, press, code} <= {1'b1, joys[1 ], 9'h16b}; // Left   | Left
      2:  {strobe, press, code} <= {1'b1, joys[2 ], 9'h172}; // Down   | Down
      3:  {strobe, press, code} <= {1'b1, joys[3 ], 9'h175}; // Up     | Up
      4:  {strobe, press, code} <= {1'b1, joys[4 ], 9'h5a};  // Fire 1 | Enter
      5:  {strobe, press, code} <= {1'b1, joys[5 ], 9'h0d};  // Fire 2 | Tab / break
      6:  {strobe, press, code} <= {1'b1, joys[6 ], 9'h29};  // Fire 3 | Space
      7:  {strobe, press, code} <= {1'b1, joys[7 ], 9'h76};  // Fire 4 | Esc / not mapped
      endcase
    end
    3'b100: begin // QAOPM
      case (joys_chn)
      0:  {strobe, press, code} <= {1'b1, joys[0 ], 9'h4d};  // Right  | p
      1:  {strobe, press, code} <= {1'b1, joys[1 ], 9'h44};  // Left   | o
      2:  {strobe, press, code} <= {1'b1, joys[2 ], 9'h1c};  // Down   | a
      3:  {strobe, press, code} <= {1'b1, joys[3 ], 9'h15};  // Up     | q
      4:  {strobe, press, code} <= {1'b1, joys[4 ], 9'h3a};  // Fire 1 | m
      5:  {strobe, press, code} <= {1'b1, joys[5 ], 9'h29};  // Fire 2 | Space
      6:  {strobe, press, code} <= {1'b1, joys[6 ], 9'h31};  // Fire 3 | n
      7:  {strobe, press, code} <= {1'b1, joys[7 ], 9'h32};  // Fire 4 | b
      endcase
    end
    endcase
    case (cfg_joystick2)
    3'b001: begin // Sinclair 1
      case (joys_chn)
      8:  {strobe, press, code} <= {1'b1, joys[8 ], 9'h3d};  // Right  | 7
      9:  {strobe, press, code} <= {1'b1, joys[9 ], 9'h36};  // Left   | 6
      10: {strobe, press, code} <= {1'b1, joys[10], 9'h3e};  // Down   | 8
      11: {strobe, press, code} <= {1'b1, joys[11], 9'h46};  // Up     | 9
      12: {strobe, press, code} <= {1'b1, joys[12], 9'h45};  // Fire 1 | 0
      13: {strobe, press, code} <= {1'b1, joys[13], 9'h3a};  // Fire 2 | m
      14: {strobe, press, code} <= {1'b1, joys[14], 9'h31};  // Fire 3 | n
      15: {strobe, press, code} <= {1'b1, joys[15], 9'h32};  // Fire 4 | b
      endcase
    end
    3'b010: begin // Sinclair 2
      case (joys_chn)
      8:  {strobe, press, code} <= {1'b1, joys[8 ], 9'h1e};  // Right  | 2
      9:  {strobe, press, code} <= {1'b1, joys[9 ], 9'h16};  // Left   | 1
      10: {strobe, press, code} <= {1'b1, joys[10], 9'h26};  // Down   | 3
      11: {strobe, press, code} <= {1'b1, joys[11], 9'h25};  // Up     | 4
      12: {strobe, press, code} <= {1'b1, joys[12], 9'h2e};  // Fire 1 | 5
      13: {strobe, press, code} <= {1'b1, joys[13], 9'h1a};  // Fire 2 | z
      14: {strobe, press, code} <= {1'b1, joys[14], 9'h22};  // Fire 3 | x
      15: {strobe, press, code} <= {1'b1, joys[15], 9'h21};  // Fire 4 | c
      endcase
    end
    3'b011: begin // Cursor
      case (joys_chn)
      8:  {strobe, press, code} <= {1'b1, joys[8 ], 9'h174}; // Right  | Right
      9:  {strobe, press, code} <= {1'b1, joys[9 ], 9'h16b}; // Left   | Left
      10: {strobe, press, code} <= {1'b1, joys[10], 9'h172}; // Down   | Down
      11: {strobe, press, code} <= {1'b1, joys[11], 9'h175}; // Up     | Up
      12: {strobe, press, code} <= {1'b1, joys[12], 9'h5a};  // Fire 1 | Enter
      13: {strobe, press, code} <= {1'b1, joys[13], 9'h0d};  // Fire 2 | Tab / break
      14: {strobe, press, code} <= {1'b1, joys[14], 9'h29};  // Fire 3 | Space
      15: {strobe, press, code} <= {1'b1, joys[15], 9'h76};  // Fire 4 | Esc / not mapped
      endcase
    end
    3'b100: begin // QAOPM
      case (joys_chn)
      8:  {strobe, press, code} <= {1'b1, joys[8 ], 9'h4d};  // Right  | p
      9:  {strobe, press, code} <= {1'b1, joys[9 ], 9'h44};  // Left   | o
      10: {strobe, press, code} <= {1'b1, joys[10], 9'h1c};  // Down   | a
      11: {strobe, press, code} <= {1'b1, joys[11], 9'h15};  // Up     | q
      12: {strobe, press, code} <= {1'b1, joys[12], 9'h3a};  // Fire 1 | m
      13: {strobe, press, code} <= {1'b1, joys[13], 9'h29};  // Fire 2 | Space
      14: {strobe, press, code} <= {1'b1, joys[14], 9'h31};  // Fire 3 | n
      15: {strobe, press, code} <= {1'b1, joys[15], 9'h32};  // Fire 4 | b
      endcase
    end
    endcase
  end
end


reg c [0:255];

always @(posedge clk or posedge reset) begin
  integer i;
  if (reset) begin
    for (i = 0; i < 256; i = i + 1)
      c[i] <= 1'b1;
  end
  else if (strobe) begin
    c[code[7:0]] <= ~press;
  end
end

always @* begin
  key_reset  <= ~c['h78];

  keys[0][0] <= c['h12]&c['h6b]&c['h72]&c['h75]&c['h74]&c['h66]&c['h58]&c['h0d]&c['h0e]&c['h7d]&c['h7a]&c['h71]&c['h5d]; // CAPS SHIFT <= Lshift & Left & Down & Up & Right & Backspace & Caps & Tab & ` & PgUp & PgDn & Del & \
  keys[0][1] <= c['h1a]&c['h4c];         // Z & ;
  keys[0][2] <= c['h22];                 // X
  keys[0][3] <= c['h21]&c['h4a];         // C & ?
  keys[0][4] <= c['h2a];                 // V
  keys[1][0] <= c['h1c];                 // A
  keys[1][1] <= c['h1b];                 // S
  keys[1][2] <= c['h23];                 // D
  keys[1][3] <= c['h2b];                 // F
  keys[1][4] <= c['h34];                 // G
  keys[2][0] <= c['h15]&c['h6c];         // Q & Home
  keys[2][1] <= c['h1d]&c['h70];         // W & Ins
  keys[2][2] <= c['h24]&c['h69];         // E
  keys[2][3] <= c['h2d];                 // R
  keys[2][4] <= c['h2c];                 // T
  keys[3][0] <= c['h16]&c['h0e];         // 1 & ` (EDIT)
  keys[3][1] <= c['h1e]&c['h58];         // 2 & Caps Lock
  keys[3][2] <= c['h26]&c['h7d];         // 3 & PgUp
  keys[3][3] <= c['h25]&c['h7a];         // 4 & PgDn
  keys[3][4] <= c['h2e]&c['h6b];         // 5 & Left
  keys[4][0] <= c['h45]&c['h66];         // 0 & Backspace
  keys[4][1] <= c['h46]&c['h5b]&c['h71]; // 9 & ] & Del
  keys[4][2] <= c['h3e]&c['h74]&c['h54]; // 8 & Right & [
  keys[4][3] <= c['h3d]&c['h75];         // 7 & Up
  keys[4][4] <= c['h36]&c['h72];         // 6 & Down
  keys[5][0] <= c['h4d]&c['h52];         // P & "
  keys[5][1] <= c['h44];                 // O
  keys[5][2] <= c['h43];                 // I
  keys[5][3] <= c['h3c];                 // U
  keys[5][4] <= c['h35];                 // Y
  keys[6][0] <= c['h5a];                 // Enter
  keys[6][1] <= c['h4b];                 // L
  keys[6][2] <= c['h42]&c['h55];         // K & +
  keys[6][3] <= c['h3b]&c['h4e];         // J & -
  keys[6][4] <= c['h33];                 // H
  keys[7][0] <= c['h29]&c['h0d];         // Space & Tab
  keys[7][1] <= c['h59]&c['h49]&c['h4e]&c['h41]&c['h4c]&c['h52]&c['h5d]&c['h55]&c['h54]&c['h5b]&c['h4a]&c['h6c]&c['h69]&c['h70]; // SYMBOL SHIFT <= Rhift & . & - & , & ; & " & \ & + & ( & ) & ? & Home & End & Ins
  keys[7][2] <= c['h3a]&c['h49];         // M & .
  keys[7][3] <= c['h31]&c['h41];         // N & ,
  keys[7][4] <= c['h32];                 // B
end


reg fifo_rdreq;
wire [9:0] fifo_q;
wire fifo_empty;
scfifo
#(
  .lpm_width(10),
  .lpm_widthu(6),
  .lpm_numwords(64),
  .lpm_showahead("OFF"),
  .overflow_checking("ON"),
  .underflow_checking("OFF"),
  .add_ram_output_register("ON")
)
fifo_scancodes
(
  .clock(clk),
  .data({~press, code}),
  .wrreq(strobe),
  .rdreq(fifo_rdreq),
  .sclr(scancode_clr),
  .q(fifo_q),
  .empty(fifo_empty)
);

reg [1:0] step = 0;
always @(posedge clk) begin
  fifo_rdreq <= 0;
  scancode <= 0;

  case (step)

  2'd0: begin
    if (!fifo_empty) begin
      fifo_rdreq <= 1'b1;
      step <= 2'd1;
    end
  end

  2'd1: begin
    if (fifo_q[8])
      scancode <= 8'hE0;
    else if (fifo_q[9])
      scancode <= 8'hF0;
    else
      scancode <= fifo_q[7:0];
    if (scancode_ack)
      step <= (fifo_q[8] || fifo_q[9])? 2'd2 : 2'd0;
  end

  2'd2: begin
    if (fifo_q[9] && fifo_q[8])
      scancode <= 8'hF0;
    else
      scancode <= fifo_q[7:0];
    if (scancode_ack)
      step <= (fifo_q[8] && fifo_q[9])? 2'd3 : 2'd0;
  end

  2'd3: begin
    scancode <= fifo_q[7:0];
    if (scancode_ack)
      step <= 0;
  end

  endcase

  if (scancode_clr)
    step <= 0;
end


endmodule
