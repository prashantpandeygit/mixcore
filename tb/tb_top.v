module tb_top;

parameter TOKENS = 4;
parameter CHANNELS = 4;
parameter HIDDEN_TOKEN = 8;
parameter HIDDEN_CHANNEL = 8;
parameter DATA_WIDTH = 8;
parameter ACC_WIDTH = 32;

reg clk = 0;
always #5 clk = ~clk;

reg rst, start;
reg signed [DATA_WIDTH-1:0] x_in [0:TOKENS-1][0:CHANNELS-1];

reg signed [DATA_WIDTH-1:0] w_token1 [0:HIDDEN_TOKEN-1][0:TOKENS-1];
reg signed [ACC_WIDTH-1:0]  b_token1 [0:HIDDEN_TOKEN-1];
reg signed [DATA_WIDTH-1:0] w_token2 [0:TOKENS-1][0:HIDDEN_TOKEN-1];
reg signed [ACC_WIDTH-1:0]  b_token2 [0:TOKENS-1];

reg signed [DATA_WIDTH-1:0] w_chan1 [0:HIDDEN_CHANNEL-1][0:CHANNELS-1];
reg signed [ACC_WIDTH-1:0]  b_chan1 [0:HIDDEN_CHANNEL-1];
reg signed [DATA_WIDTH-1:0] w_chan2 [0:CHANNELS-1][0:HIDDEN_CHANNEL-1];
reg signed [ACC_WIDTH-1:0]  b_chan2 [0:CHANNELS-1];

parameter NUM_CLASSES = 10;
wire [ACC_WIDTH*NUM_CLASSES-1:0] y_out_flat;
wire done;

// Flattening logic for TB
wire [DATA_WIDTH*TOKENS*CHANNELS-1:0] x_in_flat;
wire [DATA_WIDTH*HIDDEN_TOKEN*TOKENS-1:0] w_token1_flat;
wire [ACC_WIDTH*HIDDEN_TOKEN-1:0] b_token1_flat;
wire [DATA_WIDTH*TOKENS*HIDDEN_TOKEN-1:0] w_token2_flat;
wire [ACC_WIDTH*TOKENS-1:0] b_token2_flat;

wire [DATA_WIDTH*HIDDEN_CHANNEL*CHANNELS-1:0] w_chan1_flat;
wire [ACC_WIDTH*HIDDEN_CHANNEL-1:0] b_chan1_flat;
wire [DATA_WIDTH*CHANNELS*HIDDEN_CHANNEL-1:0] w_chan2_flat;
wire [ACC_WIDTH*CHANNELS-1:0] b_chan2_flat;

genvar g, h;
generate
    for (g = 0; g < TOKENS; g = g + 1) begin
        for (h = 0; h < CHANNELS; h = h + 1) begin
            assign x_in_flat[DATA_WIDTH*(g*CHANNELS + h + 1)-1 : DATA_WIDTH*(g*CHANNELS + h)] = x_in[g][h];
        end
    end
    for (g = 0; g < HIDDEN_TOKEN; g = g + 1) begin
        assign b_token1_flat[ACC_WIDTH*(g+1)-1 : ACC_WIDTH*g] = b_token1[g];
        for (h = 0; h < TOKENS; h = h + 1) begin
            assign w_token1_flat[DATA_WIDTH*(g*TOKENS + h + 1)-1 : DATA_WIDTH*(g*TOKENS + h)] = w_token1[g][h];
        end
    end
    for (g = 0; g < TOKENS; g = g + 1) begin
        assign b_token2_flat[ACC_WIDTH*(g+1)-1 : ACC_WIDTH*g] = b_token2[g];
        for (h = 0; h < HIDDEN_TOKEN; h = h + 1) begin
            assign w_token2_flat[DATA_WIDTH*(g*HIDDEN_TOKEN + h + 1)-1 : DATA_WIDTH*(g*HIDDEN_TOKEN + h)] = w_token2[g][h];
        end
    end
    for (g = 0; g < HIDDEN_CHANNEL; g = g + 1) begin
        assign b_chan1_flat[ACC_WIDTH*(g+1)-1 : ACC_WIDTH*g] = b_chan1[g];
        for (h = 0; h < CHANNELS; h = h + 1) begin
            assign w_chan1_flat[DATA_WIDTH*(g*CHANNELS + h + 1)-1 : DATA_WIDTH*(g*CHANNELS + h)] = w_chan1[g][h];
        end
    end
    for (g = 0; g < CHANNELS; g = g + 1) begin
        assign b_chan2_flat[ACC_WIDTH*(g+1)-1 : ACC_WIDTH*g] = b_chan2[g];
        for (h = 0; h < HIDDEN_CHANNEL; h = h + 1) begin
            assign w_chan2_flat[DATA_WIDTH*(g*HIDDEN_CHANNEL + h + 1)-1 : DATA_WIDTH*(g*HIDDEN_CHANNEL + h)] = w_chan2[g][h];
        end
    end
endgenerate

mixer_top #(
    .TOKENS(TOKENS),
    .CHANNELS(CHANNELS),
    .NUM_CLASSES(NUM_CLASSES),
    .HIDDEN_TOKEN(HIDDEN_TOKEN),
    .HIDDEN_CHANNEL(HIDDEN_CHANNEL)
) uut (
    .clk(clk), .rst(rst), .start(start),
    .x_in_flat(x_in_flat),
    .w_token1_flat(w_token1_flat), .b_token1_flat(b_token1_flat),
    .w_token2_flat(w_token2_flat), .b_token2_flat(b_token2_flat),
    .w_chan1_flat(w_chan1_flat), .b_chan1_flat(b_chan1_flat),
    .w_chan2_flat(w_chan2_flat), .b_chan2_flat(b_chan2_flat),
    .w_head_flat({(DATA_WIDTH*NUM_CLASSES*CHANNELS){1'b0}}),
    .b_head_flat({(ACC_WIDTH*NUM_CLASSES){1'b0}}),
    .y_out_flat(y_out_flat), .done(done)
);

initial begin
    $dumpfile("mixer.vcd");
    $dumpvars(0, tb_top);
end

integer i, j;
wire signed [ACC_WIDTH-1:0] y_head_out [0:NUM_CLASSES-1];
generate
    for (g = 0; g < NUM_CLASSES; g = g + 1) begin
        assign y_head_out[g] = y_out_flat[ACC_WIDTH*(g+1)-1 : ACC_WIDTH*g];
    end
endgenerate

initial begin
    rst = 1; start = 0;
    #20 rst = 0;

    // Load reference data
    x_in[0][0] = -4; x_in[0][1] = 9; x_in[0][2] = 4; x_in[0][3] = 0;
    x_in[1][0] = -3; x_in[1][1] = -4; x_in[1][2] = 8; x_in[1][3] = 0;
    x_in[2][0] = 0; x_in[2][1] = -7; x_in[2][2] = -3; x_in[2][3] = -8;
    x_in[3][0] = -9; x_in[3][1] = 1; x_in[3][2] = -5; x_in[3][3] = -9;

    w_token1[0][0] = 1; w_token1[0][1] = 1; w_token1[0][2] = -2; w_token1[0][3] = -2;
    w_token1[1][0] = 1; w_token1[1][1] = -1; w_token1[1][2] = -1; w_token1[1][3] = -2;
    w_token1[2][0] = 1; w_token1[2][1] = -2; w_token1[2][2] = -2; w_token1[2][3] = 0;
    w_token1[3][0] = 0; w_token1[3][1] = 0; w_token1[3][2] = -1; w_token1[3][3] = 1;
    w_token1[4][0] = 1; w_token1[4][1] = 1; w_token1[4][2] = 1; w_token1[4][3] = 0;
    w_token1[5][0] = -1; w_token1[5][1] = -1; w_token1[5][2] = 0; w_token1[5][3] = -1;
    w_token1[6][0] = 0; w_token1[6][1] = 1; w_token1[6][2] = 0; w_token1[6][3] = 1;
    w_token1[7][0] = 1; w_token1[7][1] = -2; w_token1[7][2] = 0; w_token1[7][3] = -2;

    b_token1[0] = -3; b_token1[1] = 1; b_token1[2] = -1; b_token1[3] = 3;
    b_token1[4] = 1; b_token1[5] = -4; b_token1[6] = -2; b_token1[7] = 3;

    w_token2[0][0] = 1; w_token2[0][1] = -1; w_token2[0][2] = -1; w_token2[0][3] = -1; w_token2[0][4] = -2; w_token2[0][5] = -1; w_token2[0][6] = -2; w_token2[0][7] = -1;
    w_token2[1][0] = 1; w_token2[1][1] = 1; w_token2[1][2] = 0; w_token2[1][3] = 1; w_token2[1][4] = 0; w_token2[1][5] = 1; w_token2[1][6] = -2; w_token2[1][7] = 1;
    w_token2[2][0] = 0; w_token2[2][1] = 0; w_token2[2][2] = -1; w_token2[2][3] = -2; w_token2[2][4] = 1; w_token2[2][5] = -1; w_token2[2][6] = 1; w_token2[2][7] = 1;
    w_token2[3][0] = -1; w_token2[3][1] = -1; w_token2[3][2] = -1; w_token2[3][3] = -1; w_token2[3][4] = -1; w_token2[3][5] = 1; w_token2[3][6] = -1; w_token2[3][7] = -2;

    b_token2[0] = -4; b_token2[1] = 4; b_token2[2] = -4; b_token2[3] = 4;

    w_chan1[0][0] = -1; w_chan1[0][1] = 1; w_chan1[0][2] = -1; w_chan1[0][3] = 0;
    w_chan1[1][0] = 1; w_chan1[1][1] = 0; w_chan1[1][2] = 1; w_chan1[1][3] = -1;
    w_chan1[2][0] = 0; w_chan1[2][1] = 1; w_chan1[2][2] = -2; w_chan1[2][3] = -1;
    w_chan1[3][0] = 1; w_chan1[3][1] = -2; w_chan1[3][2] = 1; w_chan1[3][3] = -2;
    w_chan1[4][0] = -1; w_chan1[4][1] = 0; w_chan1[4][2] = -2; w_chan1[4][3] = 1;
    w_chan1[5][0] = -1; w_chan1[5][1] = -2; w_chan1[5][2] = 1; w_chan1[5][3] = 1;
    w_chan1[6][0] = 1; w_chan1[6][1] = -2; w_chan1[6][2] = -2; w_chan1[6][3] = -2;
    w_chan1[7][0] = 0; w_chan1[7][1] = -2; w_chan1[7][2] = -2; w_chan1[7][3] = -2;

    b_chan1[0] = 1; b_chan1[1] = 3; b_chan1[2] = 2; b_chan1[3] = -5;
    b_chan1[4] = 2; b_chan1[5] = 2; b_chan1[6] = -3; b_chan1[7] = -5;

    w_chan2[0][0] = 1; w_chan2[0][1] = 0; w_chan2[0][2] = 0; w_chan2[0][3] = -2; w_chan2[0][4] = 0; w_chan2[0][5] = -2; w_chan2[0][6] = -1; w_chan2[0][7] = 0;
    w_chan2[1][0] = -1; w_chan2[1][1] = -2; w_chan2[1][2] = 1; w_chan2[1][3] = 0; w_chan2[1][4] = -2; w_chan2[1][5] = 1; w_chan2[1][6] = 1; w_chan2[1][7] = -1;
    w_chan2[2][0] = -2; w_chan2[2][1] = 1; w_chan2[2][2] = 0; w_chan2[2][3] = 0; w_chan2[2][4] = -1; w_chan2[2][5] = 1; w_chan2[2][6] = -2; w_chan2[2][7] = 0;
    w_chan2[3][0] = 1; w_chan2[3][1] = 1; w_chan2[3][2] = -1; w_chan2[3][3] = 0; w_chan2[3][4] = 0; w_chan2[3][5] = -2; w_chan2[3][6] = 0; w_chan2[3][7] = -2;

    b_chan2[0] = -3; b_chan2[1] = -5; b_chan2[2] = -1; b_chan2[3] = 4;

    #50 start = 1;
    #10 start = 0;

    fork
        begin
            wait(done);
            #50;
            $display("Final Class Scores:");
            for (i = 0; i < NUM_CLASSES; i = i + 1) begin
                $display("Class %d: %d", i, y_head_out[i]);
            end
            $finish;
        end
        begin
            #100000; // timeout
            $display("TIMEOUT at time %t", $time);
            $finish;
        end
    join

end

endmodule
