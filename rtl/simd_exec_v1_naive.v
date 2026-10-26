// ---------------------------------------------------------------------------
// simd_exec_v1_naive.v   --  VARIANT 1 : naive behavioural baseline
//
// MEL G624 Advanced VLSI Architectures, Assignment 1
//
// The obvious first-cut solution: build a SEPARATE functional unit for every
// (operation, size) combination and multiplex the results.  This instantiates
// an 8-bit adder AND two 4-bit adders AND an 8x8 multiplier AND two 4x4
// multipliers AND an 8-bit comparator AND two 4-bit comparators.
//
// It is correct, it is readable, and it is the wrong answer - it pays for
// datapath that is idle in every cycle.  It exists here purely as the
// reference point the optimised variants are measured against.
// ---------------------------------------------------------------------------
`default_nettype none

module simd_exec_v1_naive (
    input  wire [7:0] A,
    input  wire [7:0] B,
    input  wire [1:0] fn,     // 00 add, 01 multiply, 10 equality
    input  wire       size,   // 0 = one 8-bit operand, 1 = two packed 4-bit
    output wire [7:0] C,
    output wire [7:0] D
);
    localparam [1:0] FN_ADD = 2'b00,
                     FN_MUL = 2'b01,
                     FN_EQ  = 2'b10;

    // ---- dedicated 8-bit units -------------------------------------------
    wire [7:0]  add8 = A + B;            // carry-out discarded by truncation
    wire [15:0] mul8 = A * B;
    wire        eq8  = (A == B);

    // ---- dedicated 4-bit units (duplicated hardware) ---------------------
    wire [3:0] add4_lo = A[3:0] + B[3:0];
    wire [3:0] add4_hi = A[7:4] + B[7:4];
    wire [7:0] mul4_lo = A[3:0] * B[3:0];
    wire [7:0] mul4_hi = A[7:4] * B[7:4];
    wire       eq4_lo  = (A[3:0] == B[3:0]);
    wire       eq4_hi  = (A[7:4] == B[7:4]);

    // ---- output multiplexer ----------------------------------------------
    reg [7:0] Cr, Dr;

    always @* begin
        Cr = 8'h00;
        Dr = 8'h00;
        case ({size, fn})
            {1'b0, FN_ADD} : Dr = add8;
            {1'b0, FN_MUL} : begin Dr = mul8[7:0]; Cr = mul8[15:8]; end
            {1'b0, FN_EQ } : Dr = {7'b0, eq8};
            {1'b1, FN_ADD} : Dr = {add4_hi, add4_lo};
            {1'b1, FN_MUL} : begin Dr = mul4_lo; Cr = mul4_hi; end
            {1'b1, FN_EQ } : Dr = {3'b0, eq4_hi, 3'b0, eq4_lo};
            default        : begin Cr = 8'h00; Dr = 8'h00; end  // fn = 2'b11 reserved
        endcase
    end

    assign C = Cr;
    assign D = Dr;
endmodule

`default_nettype wire
