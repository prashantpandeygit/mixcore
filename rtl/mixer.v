module mixer_block #(
    parameter TOKENS = 4,
    parameter CHANNELS = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter HIDDEN_TOKEN = 8,
    parameter HIDDEN_CHANNEL = 8
)(
    input clk,
    input rst,
    input start,

    input  wire [DATA_WIDTH*TOKENS*CHANNELS-1:0] x_flat,

    // Weights for Token MLP
    input  wire [DATA_WIDTH*HIDDEN_TOKEN*TOKENS-1:0] w_token1_flat,
    input  wire [ACC_WIDTH*HIDDEN_TOKEN-1:0]          b_token1_flat,
    input  wire [DATA_WIDTH*TOKENS*HIDDEN_TOKEN-1:0] w_token2_flat,
    input  wire [ACC_WIDTH*TOKENS-1:0]               b_token2_flat,

    // Weights for Channel MLP
    input  wire [DATA_WIDTH*HIDDEN_CHANNEL*CHANNELS-1:0] w_chan1_flat,
    input  wire [ACC_WIDTH*HIDDEN_CHANNEL-1:0]           b_chan1_flat,
    input  wire [DATA_WIDTH*CHANNELS*HIDDEN_CHANNEL-1:0] w_chan2_flat,
    input  wire [ACC_WIDTH*CHANNELS-1:0]                 b_chan2_flat,

    output wire [DATA_WIDTH*TOKENS*CHANNELS-1:0] y_flat,
    output reg  done
);

    reg signed [DATA_WIDTH-1:0] x_reg [0:TOKENS-1][0:CHANNELS-1];
    genvar g, h;
    generate
        for (g = 0; g < TOKENS; g = g + 1) begin : Y_GEN
            for (h = 0; h < CHANNELS; h = h + 1) begin
                assign y_flat[DATA_WIDTH*(g*CHANNELS + h + 1)-1 : DATA_WIDTH*(g*CHANNELS + h)] = x_reg[g][h];
            end
        end
    endgenerate

    // Internal states
    localparam IDLE           = 3'd0;
    localparam LN1            = 3'd1;
    localparam TOKEN_MIX      = 3'd2;
    localparam LN2            = 3'd3;
    localparam CHANNEL_MIX    = 3'd4;
    localparam DONE           = 3'd5;

    reg [2:0] state;
    reg [$clog2(TOKENS > CHANNELS ? TOKENS : CHANNELS):0] idx;
    reg mlp_start;
    reg ln_start;
    
    // LayerNorm signals
    wire [DATA_WIDTH*TOKENS-1:0] ln_token_y_flat;
    wire ln_token_done;
    wire [DATA_WIDTH*CHANNELS-1:0] ln_chan_y_flat;
    wire ln_chan_done;

    // MLP Token signals
    reg [DATA_WIDTH*TOKENS-1:0] current_channel_flat;
    wire [DATA_WIDTH*TOKENS-1:0] mlp_token_y_flat;
    wire mlp_token_done;
    
    integer i, j;
    always @(*) begin
        current_channel_flat = 0;
        for (i = 0; i < TOKENS; i = i + 1) begin
            current_channel_flat[DATA_WIDTH*i +: DATA_WIDTH] = x_reg[i][idx < CHANNELS ? idx : 0];
        end
    end

    layernorm #(.N(TOKENS), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) ln_token (
        .clk(clk), .rst(rst), .start(ln_start && state == LN1),
        .x_flat(current_channel_flat), .gamma_flat({(TOKENS){8'h01}}), .beta_flat(0),
        .y_flat(ln_token_y_flat), .done(ln_token_done)
    );

    mlp #(.IN_SIZE(TOKENS), .HIDDEN_SIZE(HIDDEN_TOKEN), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) mlp_token (
        .clk(clk), .rst(rst), .start(mlp_start && state == TOKEN_MIX),
        .x_flat(ln_token_y_flat), 
        .w1_flat(w_token1_flat), .b1_flat(b_token1_flat), 
        .w2_flat(w_token2_flat), .b2_flat(b_token2_flat),
        .y_flat(mlp_token_y_flat), .done(mlp_token_done)
    );

    // MLP Channel signals
    reg [DATA_WIDTH*CHANNELS-1:0] current_token_row_flat;
    wire [DATA_WIDTH*CHANNELS-1:0] mlp_chan_y_flat;
    wire mlp_chan_done;

    always @(*) begin
        current_token_row_flat = 0;
        for (j = 0; j < CHANNELS; j = j + 1) begin
            current_token_row_flat[DATA_WIDTH*j +: DATA_WIDTH] = x_reg[idx < TOKENS ? idx : 0][j];
        end
    end

    layernorm #(.N(CHANNELS), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) ln_chan (
        .clk(clk), .rst(rst), .start(ln_start && state == LN2),
        .x_flat(current_token_row_flat), .gamma_flat({(CHANNELS){8'h01}}), .beta_flat(0),
        .y_flat(ln_chan_y_flat), .done(ln_chan_done)
    );

    mlp #(.IN_SIZE(CHANNELS), .HIDDEN_SIZE(HIDDEN_CHANNEL), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) mlp_chan (
        .clk(clk), .rst(rst), .start(mlp_start && state == CHANNEL_MIX),
        .x_flat(ln_chan_y_flat), 
        .w1_flat(w_chan1_flat), .b1_flat(b_chan1_flat), 
        .w2_flat(w_chan2_flat), .b2_flat(b_chan2_flat),
        .y_flat(mlp_chan_y_flat), .done(mlp_chan_done)
    );

    wire signed [DATA_WIDTH-1:0] mlp_token_y [0:TOKENS-1];
    wire signed [DATA_WIDTH-1:0] mlp_chan_y [0:CHANNELS-1];
    generate
        for (g = 0; g < TOKENS; g = g + 1) assign mlp_token_y[g] = mlp_token_y_flat[DATA_WIDTH*(g+1)-1 : DATA_WIDTH*g];
        for (h = 0; h < CHANNELS; h = h + 1) assign mlp_chan_y[h] = mlp_chan_y_flat[DATA_WIDTH*(h+1)-1 : DATA_WIDTH*h];
    endgenerate

    reg signed [ACC_WIDTH-1:0] res;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done  <= 0;
            idx   <= 0;
            mlp_start <= 0;
            ln_start <= 0;
            for (i=0; i<TOKENS; i=i+1) for (j=0; j<CHANNELS; j=j+1) x_reg[i][j] <= 0;
        end else begin
            mlp_start <= 0;
            ln_start  <= 0;
            done      <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        for (i = 0; i < TOKENS; i = i + 1) begin
                            for (j = 0; j < CHANNELS; j = j + 1) begin
                                x_reg[i][j] <= x_flat[DATA_WIDTH*(i*CHANNELS + j) +: DATA_WIDTH];
                            end
                        end
                        state <= LN1;
                        idx   <= 0;
                        ln_start <= 1;
                    end
                end

                LN1: begin
                    if (ln_token_done) begin
                        state <= TOKEN_MIX;
                        mlp_start <= 1;
                    end
                end

                TOKEN_MIX: begin
                    if (mlp_token_done) begin
                        for (i = 0; i < TOKENS; i = i + 1) begin
                            res = x_reg[i][idx] + mlp_token_y[i];
                            if (res > 127) x_reg[i][idx] <= 127;
                            else if (res < -128) x_reg[i][idx] <= -128;
                            else x_reg[i][idx] <= res[DATA_WIDTH-1:0];
                        end
                        
                        if (idx == CHANNELS - 1) begin
                            state <= LN2;
                            idx   <= 0;
                            ln_start <= 1;
                        end else begin
                            idx <= idx + 1;
                            state <= LN1;
                            ln_start <= 1;
                        end
                    end
                end

                LN2: begin
                    if (ln_chan_done) begin
                        state <= CHANNEL_MIX;
                        mlp_start <= 1;
                    end
                end

                CHANNEL_MIX: begin
                    if (mlp_chan_done) begin
                        for (j = 0; j < CHANNELS; j = j + 1) begin
                            res = x_reg[idx][j] + mlp_chan_y[j];
                            if (res > 127) x_reg[idx][j] <= 127;
                            else if (res < -128) x_reg[idx][j] <= -128;
                            else x_reg[idx][j] <= res[DATA_WIDTH-1:0];
                        end

                        if (idx == TOKENS - 1) begin
                            state <= DONE;
                        end else begin
                            idx <= idx + 1;
                            state <= LN2;
                            ln_start <= 1;
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
