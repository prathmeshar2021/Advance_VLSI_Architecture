// ---------------------------------------------------------------------------
// simd_exec_v3_struct_rca.v  --  VARIANT 3 : structural, area-oriented
//
// The sharing scheme of variant 2, but now every arithmetic block is built
// explicitly out of gates and full adders rather than left to the synthesiser:
//
//   adder      : add_simd_rca     - two 4-bit ripple chains + 1 breaking gate
//   multiplier : mult_simd_array  - gated partial products, shift-and-add
//   comparator : eq_simd          - XNOR + AND reduction
//
// This is the minimum-area design point: ripple carry everywhere, no
// speculation, no prefix network.
// ---------------------------------------------------------------------------
`default_nettype none

module simd_exec_v3_struct_rca (
    input  wire [7:0] A,
    input  wire [7:0] B,
    input  wire [1:0] fn,
    input  wire       size,
    output wire [7:0] C,
    output wire [7:0] D
);
    localparam [1:0] FN_ADD = 2'b00,
                     FN_MUL = 2'b01,
                     FN_EQ  = 2'b10;

    wire [7:0]  add_res;
    wire [15:0] prod;
    wire        eq_lo, eq_hi, eq_all;

    add_simd_rca u_add (
        .a(A), .b(B), .size(size), .sum(add_res)
    );

    mult_simd_array u_mul (
        .a(A), .b(B), .size(size), .p(prod)
    );

    eq_simd u_eq (
        .a(A), .b(B), .eq_lo(eq_lo), .eq_hi(eq_hi), .eq_all(eq_all)
    );

    wire [7:0] eq_res = size ? {3'b0, eq_hi, 3'b0, eq_lo}
                             : {7'b0,  eq_all};

    reg [15:0] cd;

    always @* begin
        case (fn)
            FN_ADD  : cd = {8'h00, add_res};
            FN_MUL  : cd = prod;
            FN_EQ   : cd = {8'h00, eq_res};
            default : cd = 16'h0000;
        endcase
    end

    assign C = cd[15:8];
    assign D = cd[7:0];
endmodule

`default_nettype wire
