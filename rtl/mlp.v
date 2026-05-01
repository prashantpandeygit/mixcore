module mlp #(
    parameter IN_SIZE = 16,
    parameter HIDDEN_SIZE = 32,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    input  wire [DATA_WIDTH*IN_SIZE-1:0] x_flat,
    
    input  wire [DATA_WIDTH*HIDDEN_SIZE*IN_SIZE-1:0] w1_flat,
    input  wire [ACC_WIDTH*HIDDEN_SIZE-1:0]          b1_flat,
    
    input  wire [DATA_WIDTH*IN_SIZE*HIDDEN_SIZE-1:0] w2_flat,
    input  wire [ACC_WIDTH*IN_SIZE-1:0]               b2_flat,

    output wire [DATA_WIDTH*IN_SIZE-1:0] y_flat,
    output reg  done
);

    reg  signed [DATA_WIDTH-1:0] y [0:IN_SIZE-1];
    genvar g;
    generate
        for (g = 0; g < IN_SIZE; g = g + 1) begin : Y_ASSIGN
            assign y_flat[DATA_WIDTH*(g+1)-1 : DATA_WIDTH*g] = y[g];
        end
    endgenerate

    // State machine
    localparam IDLE   = 2'd0;
    localparam LAYER1 = 2'd1;
    localparam LAYER2 = 2'd2;
    localparam DONE   = 2'd3;

    reg [1:0] state;
    
    // Intermediate storage
    reg signed [DATA_WIDTH-1:0] hidden [0:HIDDEN_SIZE-1];
    wire [DATA_WIDTH*HIDDEN_SIZE-1:0] hidden_flat;
    generate
        for (g = 0; g < HIDDEN_SIZE; g = g + 1) begin : HIDDEN_ASSIGN
            assign hidden_flat[DATA_WIDTH*(g+1)-1 : DATA_WIDTH*g] = hidden[g];
        end
    endgenerate

    // Linear layer signals
    reg  lin_start;
    wire [ACC_WIDTH*HIDDEN_SIZE-1:0] y1_flat;
    wire signed [ACC_WIDTH-1:0] y1 [0:HIDDEN_SIZE-1];
    generate
        for (g = 0; g < HIDDEN_SIZE; g = g + 1) begin : Y1_DECODE
            assign y1[g] = y1_flat[ACC_WIDTH*(g+1)-1 : ACC_WIDTH*g];
        end
    endgenerate

    wire done1;
    linear #(.IN_SIZE(IN_SIZE), .OUT_SIZE(HIDDEN_SIZE), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) l1 (
        .clk(clk), .rst(rst), .start(state == LAYER1 && lin_start),
        .x_flat(x_flat), .w_flat(w1_flat), .b_flat(b1_flat), .y_flat(y1_flat), .done(done1)
    );

    wire [ACC_WIDTH*IN_SIZE-1:0] y2_flat;
    wire signed [ACC_WIDTH-1:0] y2 [0:IN_SIZE-1];
    generate
        for (g = 0; g < IN_SIZE; g = g + 1) begin : Y2_DECODE
            assign y2[g] = y2_flat[ACC_WIDTH*(g+1)-1 : ACC_WIDTH*g];
        end
    endgenerate

    wire done2;
    linear #(.IN_SIZE(HIDDEN_SIZE), .OUT_SIZE(IN_SIZE), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) l2 (
        .clk(clk), .rst(rst), .start(state == LAYER2 && lin_start),
        .x_flat(hidden_flat), .w_flat(w2_flat), .b_flat(b2_flat), .y_flat(y2_flat), .done(done2)
    );

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            lin_start <= 0;
            for (i=0; i<HIDDEN_SIZE; i=i+1) hidden[i] <= 0;
            for (i=0; i<IN_SIZE; i=i+1) y[i] <= 0;
        end else begin
            lin_start <= 0;
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LAYER1;
                        lin_start <= 1;
                    end
                end
                LAYER1: begin
                    if (done1) begin
                        // ReLU and Saturated Quantization
                        for (i = 0; i < HIDDEN_SIZE; i = i + 1) begin
                            // y1 is signed ACC_WIDTH. For hidden, we use 8-bit.
                            // We assume 8-bit is -128 to 127. 
                            // ReLU makes it 0 to 127.
                            if (y1[i] > 127) hidden[i] <= 127;
                            else if (y1[i] < 0) hidden[i] <= 0;
                            else hidden[i] <= y1[i][DATA_WIDTH-1:0];
                        end
                        state <= LAYER2;
                        lin_start <= 1;
                    end
                end
                LAYER2: begin
                    if (done2) begin
                        // Saturated Quantization for final output
                        for (i = 0; i < IN_SIZE; i = i + 1) begin
                            if (y2[i] > 127) y[i] <= 127;
                            else if (y2[i] < -128) y[i] <= -128;
                            else y[i] <= y2[i][DATA_WIDTH-1:0];
                        end
                        state <= DONE;
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
