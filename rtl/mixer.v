module mixer_block #(
    parameter N = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    input  wire signed [DATA_WIDTH-1:0] x [0:N-1],

    input  wire signed [DATA_WIDTH-1:0] w1 [0:N-1],
    input  wire signed [DATA_WIDTH-1:0] w2 [0:N-1],
    input  wire signed [ACC_WIDTH-1:0] b1,
    input  wire signed [ACC_WIDTH-1:0] b2,

    output reg  signed [ACC_WIDTH-1:0] y,
    output reg  done
);

wire signed [ACC_WIDTH-1:0] l1_out;
wire l1_done;

wire signed [ACC_WIDTH-1:0] act_out;

wire signed [ACC_WIDTH-1:0] l2_out;
wire l2_done;

reg l1_start, l2_start;
reg busy;

// Linear 1
linear #(.N(N)) l1 (
    .clk(clk),
    .rst(rst),
    .start(l1_start),
    .x(x),
    .w(w1),
    .bias(b1),
    .y(l1_out),
    .done(l1_done)
);

// Activation
activation act (
    .x(l1_out),
    .y(act_out)
);

// Linear 2 (reuse activation output as vector input replicated)
wire signed [DATA_WIDTH-1:0] act_vec [0:N-1];

genvar i;
generate
    for (i = 0; i < N; i = i + 1) begin
        assign act_vec[i] = act_out[DATA_WIDTH-1:0];
    end
endgenerate

linear #(.N(N)) l2 (
    .clk(clk),
    .rst(rst),
    .start(l2_start),
    .x(act_vec),
    .w(w2),
    .bias(b2),
    .y(l2_out),
    .done(l2_done)
);

always @(posedge clk) begin
    if (rst) begin
        l1_start <= 0;
        l2_start <= 0;
        done <= 0;
        busy <= 0;
        y <= 0;
    end else begin
        l1_start <= 0;
        l2_start <= 0;
        done <= 0;

        if (start && !busy) begin
            l1_start <= 1;
            busy <= 1;
        end

        if (l1_done) begin
            l2_start <= 1;
        end

        if (l2_done) begin
            y <= l2_out;
            done <= 1;
            busy <= 0;
        end
    end
end

endmodule
