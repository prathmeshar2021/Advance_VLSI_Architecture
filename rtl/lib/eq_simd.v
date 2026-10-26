// ---------------------------------------------------------------------------
// eq_simd.v : nibble-wise equality comparator.
//
// The 8-bit compare is just the AND of the two nibble compares, so the SIMD
// version costs one extra AND gate over a plain 8-bit comparator.
// ---------------------------------------------------------------------------
`default_nettype none

module eq_simd (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire       eq_lo,   // A[3:0] == B[3:0]
    output wire       eq_hi,   // A[7:4] == B[7:4]
    output wire       eq_all   // A == B
);
    wire [7:0] xnor_ab = ~(a ^ b);

    assign eq_lo  = &xnor_ab[3:0];
    assign eq_hi  = &xnor_ab[7:4];
    assign eq_all = eq_lo & eq_hi;
endmodule

`default_nettype wire
