module mixer_head #(
    parameter TOKENS = 4,
    parameter CHANNELS = 4,
    parameter NUM_CLASSES = 10,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input clk,
    input rst,
    input start,

    input  wire [DATA_WIDTH*TOKENS*CHANNELS-1:0] x_flat,
    input  wire [DATA_WIDTH*NUM_CLASSES*CHANNELS-1:0] w_head_flat,
    input  wire [ACC_WIDTH*NUM_CLASSES-1:0]           b_head_flat,

    output wire [ACC_WIDTH*NUM_CLASSES-1:0] y_flat,
    output reg  done
);

    wire signed [DATA_WIDTH-1:0] x [0:TOKENS-1][0:CHANNELS-1];
    genvar g, h;
    generate
        for (g = 0; g < TOKENS; g = g + 1) begin : X_EXTRACT
            for (h = 0; h < CHANNELS; h = h + 1) begin
                assign x[g][h] = x_flat[DATA_WIDTH*(g*CHANNELS + h + 1)-1 : DATA_WIDTH*(g*CHANNELS + h)];
            end
        end
    endgenerate

    // Global Average Pooling
    reg signed [ACC_WIDTH-1:0] pool [0:CHANNELS-1];
    reg [DATA_WIDTH*CHANNELS-1:0] pool_flat;
    integer i, j;
    
    always @(*) begin
        for (j = 0; j < CHANNELS; j = j + 1) begin
            if (pool[j] > 127) pool_flat[DATA_WIDTH*j +: DATA_WIDTH] = 127;
            else if (pool[j] < -128) pool_flat[DATA_WIDTH*j +: DATA_WIDTH] = -128;
            else pool_flat[DATA_WIDTH*j +: DATA_WIDTH] = pool[j][DATA_WIDTH-1:0];
        end
    end

    localparam IDLE = 2'd0;
    localparam POOL = 2'd1;
    localparam HEAD = 2'd2;
    localparam DONE = 2'd3;

    reg [1:0] state;
    reg [$clog2(TOKENS):0] t_idx;
    
    reg head_start;
    wire head_done;

    linear #(.IN_SIZE(CHANNELS), .OUT_SIZE(NUM_CLASSES), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) head_lin (
        .clk(clk), .rst(rst), .start(head_start),
        .x_flat(pool_flat), .w_flat(w_head_flat), .b_flat(b_head_flat),
        .y_flat(y_flat), .done(head_done)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done  <= 0;
            t_idx <= 0;
            head_start <= 0;
            for (i=0; i<CHANNELS; i=i+1) pool[i] <= 0;
        end else begin
            head_start <= 0;
            done <= 0;
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= POOL;
                        t_idx <= 0;
                        for (i=0; i<CHANNELS; i=i+1) pool[i] <= 0;
                    end
                end
                POOL: begin
                    if (t_idx < TOKENS) begin
                        for (i=0; i<CHANNELS; i=i+1) begin
                            pool[i] <= pool[i] + x[t_idx][i];
                        end
                        t_idx <= t_idx + 1;
                    end else begin
                        for (i=0; i<CHANNELS; i=i+1) begin
                            pool[i] <= pool[i] / TOKENS;
                        end
                        state <= HEAD;
                        head_start <= 1;
                    end
                end
                HEAD: begin
                    if (head_done) begin
                        state <= DONE;
                    end
                end
                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
