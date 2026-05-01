module mixer_top #(
    parameter TOKENS = 4,
    parameter CHANNELS = 4,
    parameter NUM_BLOCKS = 1,
    parameter NUM_CLASSES = 10,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter HIDDEN_TOKEN = 8,
    parameter HIDDEN_CHANNEL = 8
)(
    input clk,
    input rst,
    input start,

    input  wire [DATA_WIDTH*TOKENS*CHANNELS-1:0] x_in_flat,

    // Weights for Mixer Blocks
    input  wire [DATA_WIDTH*HIDDEN_TOKEN*TOKENS-1:0] w_token1_flat,
    input  wire [ACC_WIDTH*HIDDEN_TOKEN-1:0]          b_token1_flat,
    input  wire [DATA_WIDTH*TOKENS*HIDDEN_TOKEN-1:0] w_token2_flat,
    input  wire [ACC_WIDTH*TOKENS-1:0]               b_token2_flat,

    input  wire [DATA_WIDTH*HIDDEN_CHANNEL*CHANNELS-1:0] w_chan1_flat,
    input  wire [ACC_WIDTH*HIDDEN_CHANNEL-1:0]           b_chan1_flat,
    input  wire [DATA_WIDTH*CHANNELS*HIDDEN_CHANNEL-1:0] w_chan2_flat,
    input  wire [ACC_WIDTH*CHANNELS-1:0]                 b_chan2_flat,

    // Weights for Head
    input  wire [DATA_WIDTH*NUM_CLASSES*CHANNELS-1:0] w_head_flat,
    input  wire [ACC_WIDTH*NUM_CLASSES-1:0]           b_head_flat,

    output wire [ACC_WIDTH*NUM_CLASSES-1:0] y_out_flat,
    output wire done
);

    wire [DATA_WIDTH*TOKENS*CHANNELS*(NUM_BLOCKS+1)-1:0] stage_data;
    wire [NUM_BLOCKS:0] stage_done;
    wire [NUM_BLOCKS:0] stage_start;

    assign stage_data[0 +: DATA_WIDTH*TOKENS*CHANNELS] = x_in_flat;
    assign stage_start[0] = start;
    assign stage_done[0] = 0;

    genvar b;
    generate
        for (b = 0; b < NUM_BLOCKS; b = b + 1) begin : BLOCKS
            mixer_block #(
                .TOKENS(TOKENS),
                .CHANNELS(CHANNELS),
                .DATA_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH),
                .HIDDEN_TOKEN(HIDDEN_TOKEN),
                .HIDDEN_CHANNEL(HIDDEN_CHANNEL)
            ) blk (
                .clk(clk),
                .rst(rst),
                .start(stage_start[b]),

                .x_flat(stage_data[b*DATA_WIDTH*TOKENS*CHANNELS +: DATA_WIDTH*TOKENS*CHANNELS]),

                .w_token1_flat(w_token1_flat), .b_token1_flat(b_token1_flat),
                .w_token2_flat(w_token2_flat), .b_token2_flat(b_token2_flat),
                
                .w_chan1_flat(w_chan1_flat), .b_chan1_flat(b_chan1_flat),
                .w_chan2_flat(w_chan2_flat), .b_chan2_flat(b_chan2_flat),

                .y_flat(stage_data[(b+1)*DATA_WIDTH*TOKENS*CHANNELS +: DATA_WIDTH*TOKENS*CHANNELS]),
                .done(stage_done[b+1])
            );
            
            assign stage_start[b+1] = stage_done[b+1];
        end
    endgenerate

    // Final Head
    mixer_head #(
        .TOKENS(TOKENS),
        .CHANNELS(CHANNELS),
        .NUM_CLASSES(NUM_CLASSES),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) head_inst (
        .clk(clk),
        .rst(rst),
        .start(stage_done[NUM_BLOCKS]),
        .x_flat(stage_data[NUM_BLOCKS*DATA_WIDTH*TOKENS*CHANNELS +: DATA_WIDTH*TOKENS*CHANNELS]),
        .w_head_flat(w_head_flat),
        .b_head_flat(b_head_flat),
        .y_flat(y_out_flat),
        .done(done)
    );

endmodule
