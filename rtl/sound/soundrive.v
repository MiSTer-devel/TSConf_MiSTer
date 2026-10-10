// SOUNDRIVE 1.05 PORTS mode 1
// #0F = left channel A (stereo covox channel 1)
// #1F = left channel B
// #4F = right channel C (stereo covox channel 2)
// #5F = right channel D

// #FB = right channel D + left channel B

module soundrive
(
    input            reset,
    input            clk,
    input            cs,
    input      [7:0] a,
    input      [7:0] di,
    input            wr_n,
    input            iorq_n,
    input            dos,
    output reg [7:0] outa,
    output reg [7:0] outb,
    output reg [7:0] outc,
    output reg [7:0] outd
);


always @(posedge clk) begin
  if (reset || !cs) begin
    outa <= 0;
    outb <= 0;
    outc <= 0;
    outd <= 0;
  end
  else begin
    if (!iorq_n && !wr_n && !dos) begin
      case (a)
      8'h0F: outa <= di;
      8'h1F: outb <= di;
      8'h4F: outc <= di;
      8'h5F: outd <= di;
      8'hFB: begin outd <= di; outb <= di; end
      endcase
    end
  end
end


endmodule
