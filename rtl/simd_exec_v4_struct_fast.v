// ---------------------------------------------------------------------------
// simd_exec_v4_struct_fast.v  --  VARIANT 4 : structural, speed-oriented
//
// Identical function and identical sharing scheme to variant 3, with every
// carry-propagate structure replaced by a logarithmic-depth one:
//
//   adder      : add_simd_csel    - carry-select high nibble, so the gate that
//                                   breaks the carry chain sits off the
//                                   critical path (it only drives a mux select)
//   multiplier : mult_simd_dadda  - Dadda compressor tree (35 FA + 7 HA)
//                                   followed by a 16-bit Kogge-Stone adder
//   comparator : eq_simd          - unchanged, already a shallow AND tree
//
// This is the maximum-speed design point.
// ---------------------------------------------------------------------------
`default_nettype none

module simd_exec_v4_struct_fast (
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

    add_simd_csel u_add (
        .a(A), .b(B), .size(size), .sum(add_res)
    );

    mult_simd_dadda u_mul (
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
