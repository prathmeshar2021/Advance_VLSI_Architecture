// ---------------------------------------------------------------------------
// simd_exec_v2_shared.v  --  VARIANT 2 : resource-shared behavioural
//
// Same behaviour as variant 1, but every 8-bit unit is made to CONTAIN its
// two 4-bit counterparts instead of sitting beside them:
//
//   adder      : one 8-bit add whose nibble-crossing carry is ANDed with ~size
//   multiplier : partial-product decomposition with the cross terms gated off,
//                so the product degenerates to {AH*BH, AL*BL} in SIMD mode
//   comparator : nibble compares ANDed together for the 8-bit result
//
// Still written with the +, * and == operators, so the synthesiser remains
// free to pick its own adder and multiplier architectures.  This variant
// isolates the benefit of SHARING from the benefit of hand-structuring.
// ---------------------------------------------------------------------------
`default_nettype none

module simd_exec_v2_shared (
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

    wire nsize = ~size;

    // ---- shared adder: one carry chain, breakable at the nibble boundary --
    wire [4:0] sum_lo  = {1'b0, A[3:0]} + {1'b0, B[3:0]};
    wire       c_mid   = sum_lo[4] & nsize;
    wire [3:0] sum_hi  = A[7:4] + B[7:4] + c_mid;
    wire [7:0] add_res = {sum_hi, sum_lo[3:0]};

    // ---- shared multiplier: cross partial products gated off in SIMD mode -
    wire [7:0]  pLL  = A[3:0] * B[3:0];
    wire [7:0]  pHH  = A[7:4] * B[7:4];
    wire [7:0]  pLH  = (A[3:0] * B[7:4]) & {8{nsize}};
    wire [7:0]  pHL  = (A[7:4] * B[3:0]) & {8{nsize}};
    wire [8:0]  pmid = pLH + pHL;
    // {pHH,pLL} needs no adder: AL*BL <= 225 cannot carry into bit 8.
    wire [15:0] prod = {pHH, pLL} + {3'b0, pmid, 4'b0};

    // ---- shared comparator -----------------------------------------------
    wire eq_lo  = (A[3:0] == B[3:0]);
    wire eq_hi  = (A[7:4] == B[7:4]);
    wire eq_all = eq_lo & eq_hi;

    wire [7:0] eq_res = size ? {3'b0, eq_hi, 3'b0, eq_lo}
                             : {7'b0,  eq_all};

    // ---- output multiplexer ----------------------------------------------
    reg [15:0] cd;

    always @* begin
        case (fn)
            FN_ADD  : cd = {8'h00, add_res};
            FN_MUL  : cd = prod;             // serves BOTH modes unchanged
            FN_EQ   : cd = {8'h00, eq_res};
            default : cd = 16'h0000;         // fn = 2'b11 reserved
        endcase
    end

    assign C = cd[15:8];
    assign D = cd[7:0];
endmodule

`default_nettype wire
