// ---------------------------------------------------------------------------
// add_simd_csel.v : SIMD-breakable 8-bit adder, carry-select flavour.
//
// Same function as add_simd_rca but the high nibble is evaluated for both
// possible carry-ins in parallel and selected afterwards.  This keeps the
// nibble-breaking AND gate OFF the critical path: it only feeds the select
// line of the output mux, which settles while the two speculative nibble
// sums are still being computed.
// ---------------------------------------------------------------------------
`default_nettype none

module add_simd_csel (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       size,
    output wire [7:0] sum
);
    wire       c_lo;
    wire [3:0] hi_c0, hi_c1;
    wire       c_mid;

    adder_ks #(.W(4)) u_lo (
        .a(a[3:0]), .b(b[3:0]), .cin(1'b0),
        .sum(sum[3:0]), .cout(c_lo)
    );

    // speculative high-nibble sums, computed in parallel with the low nibble
    adder_ks #(.W(4)) u_hi0 (
        .a(a[7:4]), .b(b[7:4]), .cin(1'b0), .sum(hi_c0), .cout()
    );
    adder_ks #(.W(4)) u_hi1 (
        .a(a[7:4]), .b(b[7:4]), .cin(1'b1), .sum(hi_c1), .cout()
    );

    assign c_mid    = c_lo & ~size;
    assign sum[7:4] = c_mid ? hi_c1 : hi_c0;
endmodule

`default_nettype wire
