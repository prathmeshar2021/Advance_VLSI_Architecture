// ---------------------------------------------------------------------------
// mult_simd_array.v : 8x8 SIMD-splittable multiplier, shift-and-add array.
//
// THE KEY IDEA OF THIS ASSIGNMENT
// ------------------------------
// Write A = 16*AH + AL and B = 16*BH + BL.  Then
//
//     A*B = 256*(AH*BH) + 16*(AH*BL + AL*BH) + (AL*BL)
//                          \_______ cross terms _______/
//
// If the two cross terms are forced to zero, what is left is
//
//     256*(AH*BH) + (AL*BL)
//
// and because AL*BL <= 225 < 256 the two surviving terms occupy DISJOINT bit
// ranges.  The 16-bit product therefore degenerates to the bit concatenation
//
//     p = { AH*BH , AL*BL }  =  { C , D }
//
// which is exactly the packed 4-bit SIMD result the specification asks for.
//
// So a single 8x8 multiplier serves both modes with no duplicated datapath and
// no output multiplexer: the only cost is that the 32 partial-product AND
// gates belonging to cross terms gain a third input, ~size.  Both modes read
// their results off the very same product wires.
// ---------------------------------------------------------------------------
`default_nettype none

module mult_simd_array (
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    input  wire        size,    // 0 = 8x8, 1 = two independent 4x4
    output wire [15:0] p
);
    wire nsize = ~size;

    // ---- gated partial products: ppf[j*8 + i] = a[i] & b[j] -----------------
    wire [63:0] ppf;

    genvar i, j;
    generate
        for (j = 0; j < 8; j = j + 1) begin : g_pp_row
            for (i = 0; i < 8; i = i + 1) begin : g_pp_bit
                if (((i < 4) && (j >= 4)) || ((i >= 4) && (j < 4))) begin : g_cross
                    // cross term - killed in 4-bit SIMD mode
                    assign ppf[j*8 + i] = a[i] & b[j] & nsize;
                end else begin : g_native
                    // belongs to AL*BL or AH*BH - always live
                    assign ppf[j*8 + i] = a[i] & b[j];
                end
            end
        end
    endgenerate

    // ---- accumulation --------------------------------------------------
    // acc_j (9 bits) = (acc_{j-1} >> 1) + pp_row_j ,  p[j] = acc_j[0]
    // One 8-bit ripple-carry adder per row; seven adders in total.
    wire [8*9-1:0] accf;

    assign accf[0 +: 9] = {1'b0, ppf[0 +: 8]};   // row 0 needs no adder

    generate
        for (j = 1; j < 8; j = j + 1) begin : g_row
            wire [7:0] rsum;
            wire       rcout;
            adder_rca #(.W(8)) u_row (
                .a    (accf[(j-1)*9 + 1 +: 8]),   // acc_{j-1} >> 1
                .b    (ppf[j*8 +: 8]),
                .cin  (1'b0),
                .sum  (rsum),
                .cout (rcout)
            );
            assign accf[j*9 +: 9] = {rcout, rsum};
        end
    endgenerate

    generate
        for (j = 0; j < 8; j = j + 1) begin : g_p_low
            assign p[j] = accf[j*9];
        end
    endgenerate

    assign p[15:8] = accf[7*9 + 1 +: 8];
endmodule

`default_nettype wire
