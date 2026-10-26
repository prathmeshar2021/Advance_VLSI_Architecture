// ---------------------------------------------------------------------------
// simd_exec_timed.v : register-to-register wrapper used for timing closure.
//
// The execution stage itself is pure combinational logic, so a static timing
// tool has no clock to measure it against.  Sandwiching it between input and
// output flops reproduces how the block actually sits in a pipeline and lets
// Vivado (or OpenSTA) report a genuine Fmax instead of an unconstrained path.
//
// Synthesise THIS module when you want frequency numbers; synthesise
// simd_exec_top when you want the pure combinational gate count.
// ---------------------------------------------------------------------------
`default_nettype none

module simd_exec_timed #(
    parameter integer VARIANT = 4
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] A_in,
    input  wire [7:0] B_in,
    input  wire [1:0] fn_in,
    input  wire       size_in,
    output reg  [7:0] C_out,
    output reg  [7:0] D_out
);
    reg  [7:0] A_q, B_q;
    reg  [1:0] fn_q;
    reg        size_q;
    wire [7:0] C_w, D_w;

    simd_exec_top #(.VARIANT(VARIANT)) u_exec (
        .A(A_q), .B(B_q), .fn(fn_q), .size(size_q), .C(C_w), .D(D_w)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            A_q    <= 8'h00;
            B_q    <= 8'h00;
            fn_q   <= 2'b00;
            size_q <= 1'b0;
            C_out  <= 8'h00;
            D_out  <= 8'h00;
        end else begin
            A_q    <= A_in;
            B_q    <= B_in;
            fn_q   <= fn_in;
            size_q <= size_in;
            C_out  <= C_w;
            D_out  <= D_w;
        end
    end
endmodule

`default_nettype wire
