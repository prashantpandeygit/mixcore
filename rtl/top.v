module mixer_top #(
    parameter TOKENS = 4,
    parameter CHANNELS = 4,
    parameter NUM_BLOCKS = 2,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input clk,
    input rst,
    input start,

    input  signed [DATA_WIDTH-1:0] x_in [0:TOKENS-1][0:CHANNELS-1],

    input  signed [DATA_WIDTH-1:0] w_token [0:TOKENS-1][0:TOKENS-1],
    input  signed [DATA_WIDTH-1:0] w_channel [0:CHANNELS-1][0:CHANNELS-1],

    input  signed [ACC_WIDTH-1:0] b_token [0:TOKENS-1],
    input  signed [ACC_WIDTH-1:0] b_channel [0:CHANNELS-1],

    output signed [ACC_WIDTH-1:0] y_out [0:TOKENS-1][0:CHANNELS-1],
    output done
);

wire signed [ACC_WIDTH-1:0] stage [0:NUM_BLOCKS][0:TOKENS-1][0:CHANNELS-1];
wire done_w [0:NUM_BLOCKS];

assign stage[0] = x_in;

genvar b;
generate
    for (b = 0; b < NUM_BLOCKS; b = b + 1) begin : BLOCKS

        mixer_block #(
            .TOKENS(TOKENS),
            .CHANNELS(CHANNELS)
        ) blk (
            .clk(clk),
            .rst(rst),
            .start(b == 0 ? start : done_w[b]),

            .x(stage[b]),

            .w_token(w_token),
            .w_channel(w_channel),
            .b_token(b_token),
            .b_channel(b_channel),

            .y(stage[b+1]),
            .done(done_w[b+1])
        );

    end
endgenerate

assign y_out = stage[NUM_BLOCKS];
assign done  = done_w[NUM_BLOCKS];

endmodule
