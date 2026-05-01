module matmul #(
    parameter N = 16,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    input  wire [DATA_WIDTH*N-1:0] x_flat,
    input  wire [DATA_WIDTH*N-1:0] w_flat,

    output reg  signed [ACC_WIDTH-1:0] y,
    output reg  done
);

    wire signed [DATA_WIDTH-1:0] x [0:N-1];
    wire signed [DATA_WIDTH-1:0] w [0:N-1];

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : ARRAY_ASSIGN
            assign x[i] = x_flat[DATA_WIDTH*(i+1)-1 : DATA_WIDTH*i];
            assign w[i] = w_flat[DATA_WIDTH*(i+1)-1 : DATA_WIDTH*i];
        end
    endgenerate

    reg signed [ACC_WIDTH-1:0] products [0:N-1];
    reg [1:0] state;
    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE = 2'd2;

    integer j;
    reg signed [ACC_WIDTH-1:0] sum;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            y <= 0;
            done <= 0;
            sum <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                COMPUTE: begin
                    // parallel multiplication and combinatorial sum
                    sum = 0;
                    for (j = 0; j < N; j = j + 1) begin
                        sum = sum + x[j] * w[j];
                    end
                    y <= sum;
                    state <= DONE;
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
