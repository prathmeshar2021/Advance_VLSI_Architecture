// ---------------------------------------------------------------------------
// simd_exec_top.v : thin selector wrapper around the four design variants.
//
// VARIANT = 1  naive behavioural          (duplicated datapath, baseline)
//           2  shared behavioural         (gated carry + gated cross products)
//           3  structural ripple/array    (minimum area)
//           4  structural carry-select/Dadda (maximum speed)
//
// Only the selected variant is elaborated; the generate-if prunes the rest.
// Keeping one common top lets a single testbench, a single XDC and a single
// set of Vivado runs cover every design point - change the parameter (or pass
// -generic VARIANT=n to synth_design) and nothing else moves.
// ---------------------------------------------------------------------------
`default_nettype none

module simd_exec_top #(
    parameter integer VARIANT = 4
) (
    input  wire [7:0] A,
    input  wire [7:0] B,
    input  wire [1:0] fn,     // 00 add, 01 multiply, 10 equality, 11 reserved
    input  wire       size,   // 0 = one 8-bit operand, 1 = two packed 4-bit
    output wire [7:0] C,
    output wire [7:0] D
);
    generate
        if (VARIANT == 1) begin : g_v1
            simd_exec_v1_naive u_dut (
                .A(A), .B(B), .fn(fn), .size(size), .C(C), .D(D));
        end
        else if (VARIANT == 2) begin : g_v2
            simd_exec_v2_shared u_dut (
                .A(A), .B(B), .fn(fn), .size(size), .C(C), .D(D));
        end
        else if (VARIANT == 3) begin : g_v3
            simd_exec_v3_struct_rca u_dut (
                .A(A), .B(B), .fn(fn), .size(size), .C(C), .D(D));
        end
        else begin : g_v4
            simd_exec_v4_struct_fast u_dut (
                .A(A), .B(B), .fn(fn), .size(size), .C(C), .D(D));
        end
    endgenerate
endmodule

`default_nettype wire
