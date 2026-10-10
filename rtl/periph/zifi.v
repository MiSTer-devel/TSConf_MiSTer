module zifi
(
  input              clk,
  input              rst,

  input  wire [ 7:0] din,
  output reg  [ 7:0] dout,
  output reg         dataout = 0,
  input  wire [15:0] a,

  input              iord,
  input              iord_s,
  input              iowr_s,

  input              rx,
  output             tx
);

  /*--------------------------------------------------------------------------------
  https://github.com/HackerVBI/ZiFi/blob/master/_esp/upd1/README!!__eRS232.txt

  Address         Mode Name Description
  0x00EF..0xBFEF  R    DR   Data register (ZIFI or RS232).
                            Get byte from input FIFO.
                            Input FIFO must not be empty (xx_IFR > 0).
  0x00EF..0xBFEF  W    DR   Data register (ZIFI or RS232).
                            Put byte into output FIFO.
                            Output FIFO must not be full (xx_OFR > 0).

  Address Mode Name   Description
  0xC0EF  R    ZF_IFR ZIFI Input FIFO Used Register. Switch DR to ZIFI FIFO.
                      0 - input FIFO is empty, 191 - input FIFO contain 191 or more bytes.
  0xC1EF  R    ZF_OFR ZIFI Output FIFO Free Register. Switch DR to ZIFI FIFO.
                      0 - output FIFO is full, 191 - output FIFO free 191 or more bytes.
  0xC2EF  R    RS_IFR RS232 Input FIFO Used Register. Switch DR to RS232 FIFO.
                      0 - input FIFO is empty, 191 - input FIFO contain 191 or more bytes.
  0xC3EF  R    RS_OFR RS232 Output FIFO Free Register. Switch DR to RS232 FIFO.
                      0 - output FIFO is full, 191 - output FIFO free 191 or more bytes.

  Address Mode Name   Description
  0xC7EF  W    CR     Command register. Command set depends on API mode selected.

    All mode commands:
      Code     Command      Description
      000000oi Clear ZIFI FIFOs
              i: 1 - clear input ZIFI FIFO,
              o: 1 - clear output ZIFI FIFO.
      000001oi Clear RS232 FIFOs
              i: 1 - clear input RS232 FIFO,
              o: 1 - clear output RS232 FIFO.
      11110mmm Set API mode or disable API:
                0     API disabled.
                1     transparent: all data is sent/received to/from external UART directly.
                2..7  reserved.
      11111111 Get Version  Returns highest supported API version. ER=0xFF - no API available.

  Address Mode Name Description
  0xC7EF  R    ER   Error register - command execution result code. Depends on command issued.

    All mode responses:
      Code Description
      0x00 OK - no error.
      0xFF REJ - command rejected.

  --------------------------------------------------------------------------------*/


  localparam DR = 16'h??EF;
  localparam ZF_IFR = 16'hC0EF;
  localparam ZF_OFR = 16'hC1EF;
  localparam RS_IFR = 16'hC2EF;
  localparam RS_OFR = 16'hC3EF;
  localparam CR = 16'hC7EF;
  localparam ER = 16'hC7EF;

  reg [7:0] er;
  reg zifi_en;

  always @(posedge clk) begin
    dataout <= dataout & iord;
    fifo_rx_rdreq <= 1'b0;
    fifo_tx_wrreq <= 1'b0;
    fifo_rx_sclr <= 1'b0;
    fifo_tx_sclr <= 1'b0;

    if (iord_s) begin
      casez (a)
      ZF_IFR: begin
        dataout <= 1'b1;
        dout <= rx_busy? 8'd0 : ((fifo_rx_usedw < 191)? fifo_rx_usedw[7:0] : 8'd191);
        zifi_en <= 1'b1;
      end
      ZF_OFR: begin
        dataout <= 1'b1;
        dout <= (fifo_tx_freew < 191)? fifo_tx_freew[7:0] : 8'd191;
        zifi_en <= 1'b1;
      end
      RS_IFR: begin
        dataout <= 1'b1;
        dout <= 8'd0;
        zifi_en <= 1'b0;
      end
      RS_OFR: begin
        dataout <= 1'b1;
        dout <= 8'd191;
        zifi_en <= 1'b0;
      end
      ER: begin
        dataout <= 1'b1;
        dout <= er;
      end
      DR: begin
        dataout <= 1'b1;
        dout <= fifo_rx_q;
        fifo_rx_rdreq <= zifi_en;
      end
      endcase
    end

    if (iowr_s) begin
      casez (a)
      CR: begin
        casez (din)
        8'b000000??: begin
          fifo_rx_sclr <= din[0];
          fifo_tx_sclr <= din[1];
          er <= 8'h00;
        end
        8'b000001??: begin
          er <= 8'h00;
        end
        8'b11110???: begin
          er <= 8'h00;
        end
        8'b11111111: begin
          er <= 8'h01;
        end
        default: begin
          er <= 8'hFF;
        end
        endcase
      end
      DR: begin
        fifo_tx_data <= din;
        fifo_tx_wrreq <= zifi_en;
      end
      endcase
    end

  end


  // workarround to fix random hang of zifi.spg (a2cfe54), which is always doing 191-bytes-inir (see fifo_inir function)
  reg [19:0] rx_busy_cnt = 0;
  reg rx_busy = 0;
  always @(posedge clk) begin
    if (fifo_rx_wrreq)
      rx_busy_cnt <= 1'd1;
    else if (rx_busy_cnt)
      rx_busy_cnt <= rx_busy_cnt + 1'd1;
    rx_busy <= (fifo_rx_wrreq || rx_busy_cnt) && fifo_rx_usedw < 191;
  end


  wire [7:0] fifo_rx_data;
  wire fifo_rx_wrreq;
  reg fifo_rx_rdreq;
  reg fifo_rx_sclr;
  wire [7:0] fifo_rx_q;
  wire [12:0] fifo_rx_usedw;
  scfifo
  #(
    .lpm_width(8),
    .lpm_widthu(13),
    .lpm_numwords(8192),
    .lpm_showahead("ON"),
    .overflow_checking("ON"),
    .underflow_checking("ON"),
    .add_ram_output_register("OFF")
  )
  fifo_rx
  (
    .clock(clk),
    .data(fifo_rx_data),
    .wrreq(fifo_rx_wrreq),
    .rdreq(fifo_rx_rdreq),
    .sclr(rst | fifo_rx_sclr),
    .q(fifo_rx_q),
    .usedw(fifo_rx_usedw)
  );


  reg [7:0] fifo_tx_data;
  reg fifo_tx_wrreq;
  wire fifo_tx_rdreq;
  reg fifo_tx_sclr;
  wire [7:0] fifo_tx_q;
  wire [7:0] fifo_tx_usedw;
  wire [7:0] fifo_tx_freew = 8'h255 - fifo_tx_usedw;
  wire fifo_tx_empty;
  reg fifo_tx_empty_r;
  always @(posedge clk)
    fifo_tx_empty_r <= fifo_tx_empty;
  scfifo
  #(
    .lpm_width(8),
    .lpm_widthu(8),
    .lpm_numwords(256),
    .lpm_showahead("ON"),
    .overflow_checking("ON"),
    .underflow_checking("ON"),
    .add_ram_output_register("OFF")
  )
  fifo_tx
  (
    .clock(clk),
    .data(fifo_tx_data),
    .wrreq(fifo_tx_wrreq),
    .rdreq(fifo_tx_rdreq),
    .sclr(rst | fifo_tx_sclr),
    .q(fifo_tx_q),
    .usedw(fifo_tx_usedw),
    .empty(fifo_tx_empty)
  );


  uart_rx #(.CLKS_PER_BIT(28_000_000/115200)) uart_rx
  (
    .i_Clock(clk),
    .i_Rx_Serial(rx),
    .o_Rx_DV(fifo_rx_wrreq),
    .o_Rx_Byte(fifo_rx_data)
  );


  wire tx_busy;
  reg tx_busy_r;
  always @(posedge clk)
    tx_busy_r <= tx_busy;
  assign fifo_tx_rdreq = tx_busy && !tx_busy_r;
  uart_tx #(.CLKS_PER_BIT(28_000_000/115200)) uart_tx
  (
    .i_Clock(clk),
    .i_Tx_DV(!fifo_tx_empty_r),
    .i_Tx_Byte(fifo_tx_q),
    .o_Tx_Active(tx_busy),
    .o_Tx_Serial(tx),
    .o_Tx_Done()
  );


endmodule
