module matmul #(
    parameter N = 16,              // vector size
    parameter DATA_WIDTH = 8,      // INT8
    parameter ACC_WIDTH = 32       // accumulator
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    input  wire signed [DATA_WIDTH-1:0] x [0:N-1],
    input  wire signed [DATA_WIDTH-1:0] w [0:N-1],

    output reg  signed [ACC_WIDTH-1:0] y,
    output reg  done
);

integer i;

reg signed [ACC_WIDTH-1:0] acc;
reg [$clog2(N):0] idx;
reg running;

always @(posedge clk) begin
    if (rst) begin
        acc <= 0;
        idx <= 0;
        running <= 0;
        done <= 0;
        y <= 0;
    end else begin
        if (start && !running) begin
            acc <= 0;
            idx <= 0;
            running <= 1;
            done <= 0;
        end else if (running) begin
            acc <= acc + x[idx] * w[idx];
            idx <= idx + 1;

            if (idx == N-1) begin
                running <= 0;
                y <= acc + x[idx] * w[idx];
                done <= 1;
            end
        end else begin
            done <= 0;
        end
    end
end

endmodule
