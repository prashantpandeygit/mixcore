module tb_matmul;

parameter N = 4;

reg clk = 0;
always #5 clk = ~clk;

reg rst;
reg start;

reg signed [7:0] x [0:N-1];
reg signed [7:0] w [0:N-1];

wire signed [31:0] y;
wire done;

matmul #(.N(N)) uut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .x(x),
    .w(w),
    .y(y),
    .done(done)
);

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_matmul);
end

initial begin
    rst = 1;
    start = 0;

    #10 rst = 0;

    // Example vectors
    x[0]=1; x[1]=2; x[2]=3; x[3]=4;
    w[0]=1; w[1]=1; w[2]=1; w[3]=1;

    #10 start = 1;
    #10 start = 0;

    wait(done);

    $display("Result: %d", y); // 10
    $finish;
end

endmodule


