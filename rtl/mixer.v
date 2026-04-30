module mixer_block #(
    parameter TOKENS = 4,
    parameter CHANNELS = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input clk,
    input rst,
    input start,

    input  signed [DATA_WIDTH-1:0] x [0:TOKENS-1][0:CHANNELS-1],

    input  signed [DATA_WIDTH-1:0] w_token [0:TOKENS-1][0:TOKENS-1],
    input  signed [DATA_WIDTH-1:0] w_channel [0:CHANNELS-1][0:CHANNELS-1],

    input  signed [ACC_WIDTH-1:0] b_token [0:TOKENS-1],
    input  signed [ACC_WIDTH-1:0] b_channel [0:CHANNELS-1],

    output reg signed [ACC_WIDTH-1:0] y [0:TOKENS-1][0:CHANNELS-1],
    output reg done
);

// intermediate storage
reg signed [ACC_WIDTH-1:0] token_out [0:TOKENS-1][0:CHANNELS-1];
reg signed [ACC_WIDTH-1:0] channel_out [0:TOKENS-1][0:CHANNELS-1];

integer i, j, k;

always @(posedge clk) begin
    if (rst) begin
        done <= 0;
    end else if (start) begin

        // token mixing
        for (j = 0; j < CHANNELS; j = j + 1) begin
            for (i = 0; i < TOKENS; i = i + 1) begin
                token_out[i][j] = 0;
                for (k = 0; k < TOKENS; k = k + 1) begin
                    token_out[i][j] = token_out[i][j] + x[k][j] * w_token[i][k];
                end
                token_out[i][j] = token_out[i][j] + b_token[i];
            end
        end

        // channel mixing
        for (i = 0; i < TOKENS; i = i + 1) begin
            for (j = 0; j < CHANNELS; j = j + 1) begin
                channel_out[i][j] = 0;
                for (k = 0; k < CHANNELS; k = k + 1) begin
                    channel_out[i][j] = channel_out[i][j] + token_out[i][k] * w_channel[j][k];
                end
                channel_out[i][j] = channel_out[i][j] + b_channel[j];

                // ReLU
                if (channel_out[i][j] < 0)
                    y[i][j] = 0;
                else
                    y[i][j] = channel_out[i][j];
            end
        end

        done <= 1;
    end else begin
        done <= 0;
    end
end

endmodule
