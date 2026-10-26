// ---------------------------------------------------------------------------
// tb_simd_exhaustive.v : exhaustive self-checking testbench.
//
// Drives all 2^16 operand pairs through all 3 operations in both size modes
// (393 216 vectors) into all four variants simultaneously and compares each
// against a golden model written directly from the specification text.
//
// The reserved encoding fn = 2'b11 is also swept; the agreed behaviour is
// C = D = 0 (documented in docs/REPORT.md, since the spec leaves it open).
//
// Icarus :  iverilog -g2012 -o sim rtl/lib/*.v rtl/*.v tb/tb_simd_exhaustive.v
//           vvp sim
// Vivado :  set this module as the simulation top of sim_exhaustive
// ---------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module tb_simd_exhaustive;

    reg  [7:0] A, B;
    reg  [1:0] fn;
    reg        size;

    wire [7:0] C1, D1, C2, D2, C3, D3, C4, D4;

    simd_exec_top #(.VARIANT(1)) u1 (.A(A), .B(B), .fn(fn), .size(size), .C(C1), .D(D1));
    simd_exec_top #(.VARIANT(2)) u2 (.A(A), .B(B), .fn(fn), .size(size), .C(C2), .D(D2));
    simd_exec_top #(.VARIANT(3)) u3 (.A(A), .B(B), .fn(fn), .size(size), .C(C3), .D(D3));
    simd_exec_top #(.VARIANT(4)) u4 (.A(A), .B(B), .fn(fn), .size(size), .C(C4), .D(D4));

    integer errors;
    integer vectors;
    integer ia, ib, ifn, isz;

    reg [7:0] gC, gD;

    // ---------------------------------------------------------------------
    // Golden model - transcribed from the assignment specification, not from
    // any of the implementations.
    // ---------------------------------------------------------------------
    task golden;
        input  [7:0] a;
        input  [7:0] b;
        input  [1:0] f;
        input        s;
        output [7:0] oC;
        output [7:0] oD;
        reg    [15:0] full;
        begin
            oC   = 8'h00;
            oD   = 8'h00;
            full = a * b;
            case ({s, f})
                // ---- 8-bit mode -------------------------------------------
                // "D contains the sum bits after discarding the carry-out,
                //  and all bits of C are zeros"
                3'b0_00 : oD = a + b;
                // "D contains the lower significant bits of the result and C
                //  contains the higher significant bits"
                3'b0_01 : begin oD = full[7:0]; oC = full[15:8]; end
                // "lsb of D reflects the result of comparison while other
                //  bits of D and all the bits of C are zeros"
                3'b0_10 : oD = {7'b0, (a == b)};

                // ---- 4-bit packed mode ------------------------------------
                // "D[3:0] contain the sum bits of A[3:0]+B[3:0] and D[7:4]
                //  contain the sum bits of A[7:4]+B[7:4]"
                3'b1_00 : oD = {(a[7:4] + b[7:4]), (a[3:0] + b[3:0])};
                // "D contains the multiplication of lower nibbles and C
                //  contains the multiplication of upper nibbles"
                3'b1_01 : begin oD = a[3:0] * b[3:0]; oC = a[7:4] * b[7:4]; end
                // "bit 0 and bit 4 of D reflect the equality tests of lower
                //  and upper nibbles, remaining bits zero"
                3'b1_10 : oD = {3'b0, (a[7:4] == b[7:4]),
                                3'b0, (a[3:0] == b[3:0])};

                default : begin oC = 8'h00; oD = 8'h00; end   // fn = 2'b11
            endcase
        end
    endtask

    task check;
        input [8*8-1:0] name;
        input [7:0]     gotC;
        input [7:0]     gotD;
        begin
            if (gotC !== gC || gotD !== gD) begin
                if (errors < 20)
                    $display("FAIL %0s  A=%02h B=%02h fn=%b size=%b : got C=%02h D=%02h  exp C=%02h D=%02h",
                             name, A, B, fn, size, gotC, gotD, gC, gD);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors  = 0;
        vectors = 0;

        $display("=========================================================");
        $display(" Exhaustive verification : 4 variants x 2^16 pairs x 8 modes");
        $display("=========================================================");

        for (isz = 0; isz < 2; isz = isz + 1) begin
            for (ifn = 0; ifn < 4; ifn = ifn + 1) begin
                for (ia = 0; ia < 256; ia = ia + 1) begin
                    for (ib = 0; ib < 256; ib = ib + 1) begin
                        A    = ia;      // truncates to 8 bits
                        B    = ib;
                        fn   = ifn;
                        size = isz;
                        #1;

                        golden(A, B, fn, size, gC, gD);

                        check("V1-naive ", C1, D1);
                        check("V2-shared", C2, D2);
                        check("V3-struct", C3, D3);
                        check("V4-fast  ", C4, D4);

                        vectors = vectors + 1;
                    end
                end
            end
            $display("  ... size=%0d sweep complete (%0d vectors so far, %0d errors)",
                     isz, vectors, errors);
        end

        $display("---------------------------------------------------------");
        $display(" vectors applied : %0d  (x4 variants = %0d comparisons)",
                 vectors, vectors * 4);
        $display(" mismatches      : %0d", errors);
        if (errors == 0)
            $display(" RESULT: *** ALL VARIANTS PASS ***");
        else
            $display(" RESULT: *** %0d FAILURES ***", errors);
        $display("=========================================================");

        if (errors != 0) $fatal(1, "verification failed");
        $finish;
    end

endmodule

`default_nettype wire
