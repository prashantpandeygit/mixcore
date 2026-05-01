module layernorm #(
    parameter N = 16,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    input  wire [DATA_WIDTH*N-1:0] x_flat,
    // Gamma and Beta are optional, but we include them as flattened ports
    input  wire [DATA_WIDTH*N-1:0] gamma_flat,
    input  wire [DATA_WIDTH*N-1:0] beta_flat,

    output wire [DATA_WIDTH*N-1:0] y_flat,
    output reg  done
);

    wire signed [DATA_WIDTH-1:0] x [0:N-1];
    reg  signed [DATA_WIDTH-1:0] y [0:N-1];

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : PORT_ASSIGN
            assign x[g] = x_flat[DATA_WIDTH*(g+1)-1 : DATA_WIDTH*g];
            assign y_flat[DATA_WIDTH*(g+1)-1 : DATA_WIDTH*g] = y[g];
        end
    endgenerate

    reg signed [ACC_WIDTH-1:0] sum;
    reg signed [ACC_WIDTH-1:0] mean;
    reg [$clog2(N):0] idx;
    
    localparam IDLE = 2'd0;
    localparam SUM  = 2'd1;
    localparam CALC = 2'd2;
    localparam DONE = 2'd3;

    reg [1:0] state;

    reg signed [ACC_WIDTH-1:0] signed_res;
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done  <= 0;
            sum   <= 0;
            idx   <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= SUM;
                        sum   <= 0;
                        idx   <= 0;
                    end
                end

                SUM: begin
                    if (idx < N) begin
                        sum <= sum + x[idx];
                        idx <= idx + 1;
                    end else begin
                        mean <= sum / $signed(N);
                        state <= CALC;
                        idx <= 0;
                    end
                end

                CALC: begin
                    if (idx < N) begin
                        signed_res = x[idx] - mean;
                        if (signed_res > 127) y[idx] <= 127;
                        else if (signed_res < -128) y[idx] <= -128;
                        else y[idx] <= signed_res[DATA_WIDTH-1:0];
                        idx <= idx + 1;
                    end else begin
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
