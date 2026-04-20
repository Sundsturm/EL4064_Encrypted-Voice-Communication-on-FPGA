
module Mult128 #(
    parameter   WIDTH = 16
)(
    input   signed  [WIDTH-1:0] di_re,
    input   signed  [WIDTH-1:0] di_im,
    output  signed  [WIDTH-1:0] do_re,
    output  signed  [WIDTH-1:0] do_im
);

assign do_re = di_re * 128;
assign do_im = di_im * 128;

endmodule