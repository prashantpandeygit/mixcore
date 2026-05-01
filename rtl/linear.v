module linear #(
    parameter IN_SIZE = 16,
    parameter OUT_SIZE = 16,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    input  wire [DATA_WIDTH*IN_SIZE-1:0] x_flat,
    input  wire [DATA_WIDTH*OUT_SIZE*IN_SIZE-1:0] w_flat,
    input  wire [ACC_WIDTH*OUT_SIZE-1:0] b_flat,

    output wire [ACC_WIDTH*OUT_SIZE-1:0] y_flat,
    output reg  done
);

    reg [ACC_WIDTH-1:0] y [0:OUT_SIZE-1];
    wire [ACC_WIDTH-1:0] b [0:OUT_SIZE-1];

    genvar g;
    generate
        for (g = 0; g < OUT_SIZE; g = g + 1) begin : Y_B_ASSIGN
            assign y_flat[ACC_WIDTH*(g+1)-1 : ACC_WIDTH*g] = y[g];
            assign b[g] = b_flat[ACC_WIDTH*(g+1)-1 : ACC_WIDTH*g];
        end
    endgenerate

    wire [ACC_WIDTH-1:0] mm_y;
    wire mm_done;
    reg  mm_start;

    reg [$clog2(OUT_SIZE):0] row_idx;
    reg [1:0] state;
    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE = 2'd2;

    // wire to slice the weight matrix
    // multiplexer logic
    reg [DATA_WIDTH*IN_SIZE-1:0] current_w_slice;
    integer i;
    always @(*) begin
        current_w_slice = 0;
        for (i = 0; i < OUT_SIZE; i = i + 1) begin
            if (row_idx == i) begin
                current_w_slice = w_flat[DATA_WIDTH*IN_SIZE*i +: DATA_WIDTH*IN_SIZE];
            end
        end
    end

    matmul #(
        .N(IN_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) mm (
        .clk(clk),
        .rst(rst),
        .start(mm_start),
        .x_flat(x_flat),
        .w_flat(current_w_slice),
        .y(mm_y),
        .done(mm_done)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            row_idx <= 0;
            mm_start <= 0;
            done <= 0;
            for (i = 0; i < OUT_SIZE; i = i+1) y[i] <= 0;
        end else begin
            mm_start <= 0;
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        row_idx <= 0;
                        state <= COMPUTE;
                        mm_start <= 1;
                    end
                end
                COMPUTE: begin
                    if (mm_done) begin
                        y[row_idx] <= mm_y + b[row_idx];
                        if (row_idx == OUT_SIZE - 1) begin
                            state <= DONE;
                        end else begin
                            row_idx <= row_idx + 1;
                            mm_start <= 1;
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
