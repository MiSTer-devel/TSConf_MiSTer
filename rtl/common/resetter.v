`include "tune.v"

// Asynchronous assertion catches reset pulses shorter than a clock period.
// Deassertion is synchronized to avoid releasing logic near a clock edge.
module resetter
(
  input  wire clk,
  input  wire rst_in_n,      // external asynchronous reset
  output wire rst_out_n      // synchronized reset
);

  (* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
  reg [1:0] rst_sync;

  always @(posedge clk or negedge rst_in_n)
    if (!rst_in_n)
      rst_sync <= 2'b00;
    else
      rst_sync <= {rst_sync[0], 1'b1};

  assign rst_out_n = rst_sync[1];

endmodule
