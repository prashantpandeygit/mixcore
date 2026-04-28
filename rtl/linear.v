module linear #(
    parameter N = 16,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    input  wire signed [DATA_WIDTH-1:0] x [0:N-1],
    input  wire signed [DATA_WIDTH-1:0] w [0:N-1],
    input  wire signed [ACC_WIDTH-1:0] bias,

    output reg  signed [ACC_WIDTH-1:0] y,
    output reg  done
);

wire signed [ACC_WIDTH-1:0] mm_y;
wire mm_done;

reg mm_start;
reg busy;

matmul #(
    .N(N),
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH)
) mm (
    .clk(clk),
    .rst(rst),
    .start(mm_start),
    .x(x),
    .w(w),
    .y(mm_y),
    .done(mm_done)
);

always @(posedge clk) begin
    if (rst) begin
        mm_start <= 0;
        busy <= 0;
        done <= 0;
        y <= 0;
    end else begin
        // default signals
        mm_start <= 0;
        done <= 0;

        // start condition
        if (start && !busy) begin
            mm_start <= 1;   // 1-cycle pulse
            busy <= 1;
        end

        // completion
        if (mm_done && busy) begin
            y <= mm_y + bias;
            done <= 1;
            busy <= 0;
        end
    end
end

endmodule
