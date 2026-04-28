module tb_linear;

parameter N = 4;

reg clk = 0;
always #5 clk = ~clk;

reg rst, start;

reg signed [7:0] x [0:N-1];
reg signed [7:0] w [0:N-1];
reg signed [31:0] bias;

wire signed [31:0] y;
wire done;

linear #(.N(N)) uut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .x(x),
    .w(w),
    .bias(bias),
    .y(y),
    .done(done)
);

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_linear);
end

initial begin
    rst = 1; start = 0;
    #10 rst = 0;

    x[0]=1; x[1]=2; x[2]=3; x[3]=4;
    w[0]=1; w[1]=1; w[2]=1; w[3]=1;
    bias = 5;

    @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;

    wait(done);

    $display("Result: %d", y); // expect 15
    $finish;
end

endmodule
