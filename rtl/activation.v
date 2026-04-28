module activation #(
    parameter DATA_WIDTH = 32
)(
    input  wire signed [DATA_WIDTH-1:0] x,
    output wire signed [DATA_WIDTH-1:0] y
);

assign y = (x > 0) ? x : 0;

endmodule
