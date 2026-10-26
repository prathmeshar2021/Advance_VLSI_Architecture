// ---------------------------------------------------------------------------
// add_simd_rca.v : SIMD-breakable 8-bit adder, ripple-carry flavour.
//
//   size = 0 -> one 8-bit add,  sum = A + B      (carry-out discarded)
//   size = 1 -> two 4-bit adds, sum = {A[7:4]+B[7:4], A[3:0]+B[3:0]}
//
// The ENTIRE cost of SIMD support here is the single AND gate on the carry
// that crosses the nibble boundary.  Nothing else is duplicated.
// ---------------------------------------------------------------------------
`default_nettype none

module add_simd_rca (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       size,
    output wire [7:0] sum
);
    wire c_lo;    // carry out of the low nibble
    wire c_mid;   // carry actually injected into the high nibble

    adder_rca #(.W(4)) u_lo (
        .a(a[3:0]), .b(b[3:0]), .cin(1'b0),
        .sum(sum[3:0]), .cout(c_lo)
    );

    // the one gate that breaks the carry chain
    assign c_mid = c_lo & ~size;

    adder_rca #(.W(4)) u_hi (
        .a(a[7:4]), .b(b[7:4]), .cin(c_mid),
        .sum(sum[7:4]), .cout(/* discarded per spec */)
    );
endmodule

`default_nettype wire
