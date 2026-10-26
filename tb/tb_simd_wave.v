// ---------------------------------------------------------------------------
// tb_simd_wave.v : short, waveform-oriented testbench.
//
// Purpose is to produce a SHORT, READABLE waveform in the Vivado simulator
// (or GTKWave) that demonstrates every operating mode, rather than to prove
// correctness - tb_simd_exhaustive.v does that.
//
// Each stimulus is held for 10 ns and labelled in the transcript, and the
// directed sequence deliberately applies the SAME operand pair with size=0
// and then size=1 so the SIMD split is visible side by side in the waveform.
//
// Default simulation top for the Vivado project.
// ---------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module tb_simd_wave;

    localparam integer STEP = 10;

    localparam [1:0] FN_ADD = 2'b00,
                     FN_MUL = 2'b01,
                     FN_EQ  = 2'b10;

    reg  [7:0] A, B;
    reg  [1:0] fn;
    reg        size;

    // all four variants run side by side so the waveform shows them agreeing
    wire [7:0] C1, D1, C2, D2, C3, D3, C4, D4;

    simd_exec_top #(.VARIANT(1)) u1 (.A(A), .B(B), .fn(fn), .size(size), .C(C1), .D(D1));
    simd_exec_top #(.VARIANT(2)) u2 (.A(A), .B(B), .fn(fn), .size(size), .C(C2), .D(D2));
    simd_exec_top #(.VARIANT(3)) u3 (.A(A), .B(B), .fn(fn), .size(size), .C(C3), .D(D3));
    simd_exec_top #(.VARIANT(4)) u4 (.A(A), .B(B), .fn(fn), .size(size), .C(C4), .D(D4));

    integer errors;

    // -----------------------------------------------------------------
    task apply;
        input [8*24-1:0] label;
        input [7:0]      a_in;
        input [7:0]      b_in;
        input [1:0]      f_in;
        input            s_in;
        begin
            A = a_in; B = b_in; fn = f_in; size = s_in;
            #STEP;
            $display("%-24s A=%02h B=%02h fn=%b size=%b -> C=%02h D=%02h",
                     label, A, B, fn, size, C4, D4);
            if ({C1,D1} !== {C4,D4} || {C2,D2} !== {C4,D4} || {C3,D3} !== {C4,D4}) begin
                $display("   *** VARIANT DISAGREEMENT: v1=%02h_%02h v2=%02h_%02h v3=%02h_%02h v4=%02h_%02h",
                         C1,D1, C2,D2, C3,D3, C4,D4);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
`ifdef DUMP_VCD
        $dumpfile("tb_simd_wave.vcd");
        $dumpvars(0, tb_simd_wave);
`endif
        errors = 0;
        A = 0; B = 0; fn = 0; size = 0;
        #STEP;

        $display("");
        $display("=== 8-BIT MODE (size=0) =============================");
        apply("add  8b  no carry",   8'h12, 8'h34, FN_ADD, 1'b0);  // D=46
        apply("add  8b  carry out",  8'hF0, 8'h20, FN_ADD, 1'b0);  // D=10, carry lost
        apply("add  8b  max",        8'hFF, 8'hFF, FN_ADD, 1'b0);  // D=FE
        apply("mul  8b  small",      8'h03, 8'h05, FN_MUL, 1'b0);  // C=00 D=0F
        apply("mul  8b  max",        8'hFF, 8'hFF, FN_MUL, 1'b0);  // C=FE D=01
        apply("mul  8b  0x80*0x02",  8'h80, 8'h02, FN_MUL, 1'b0);  // C=01 D=00
        apply("eq   8b  equal",      8'h5A, 8'h5A, FN_EQ,  1'b0);  // D=01
        apply("eq   8b  differ",     8'h5A, 8'h5B, FN_EQ,  1'b0);  // D=00

        $display("");
        $display("=== 4-BIT PACKED MODE (size=1) ======================");
        apply("add  4b  no carry",   8'h12, 8'h34, FN_ADD, 1'b1);  // D=46
        apply("add  4b  lo carry",   8'h1F, 8'h11, FN_ADD, 1'b1);  // D=20 (no bleed)
        apply("add  4b  both carry", 8'hFF, 8'hFF, FN_ADD, 1'b1);  // D=EE
        apply("mul  4b  3x5 / 2x4",  8'h23, 8'h45, FN_MUL, 1'b1);  // C=08 D=0F
        apply("mul  4b  max",        8'hFF, 8'hFF, FN_MUL, 1'b1);  // C=E1 D=E1
        apply("eq   4b  both equal", 8'h77, 8'h77, FN_EQ,  1'b1);  // D=11
        apply("eq   4b  lo only",    8'h37, 8'h57, FN_EQ,  1'b1);  // D=01
        apply("eq   4b  hi only",    8'h73, 8'h75, FN_EQ,  1'b1);  // D=10

        $display("");
        $display("=== SAME OPERANDS, SIZE TOGGLED =====================");
        $display("    (shows the carry chain and the cross products");
        $display("     being broken by the size input)");
        apply("add  0x3F+0x11 8b",   8'h3F, 8'h11, FN_ADD, 1'b0);  // D=50
        apply("add  0x3F+0x11 4b",   8'h3F, 8'h11, FN_ADD, 1'b1);  // D=40
        apply("mul  0x33*0x22 8b",   8'h33, 8'h22, FN_MUL, 1'b0);  // C=06 D=C6
        apply("mul  0x33*0x22 4b",   8'h33, 8'h22, FN_MUL, 1'b1);  // C=06 D=06

        $display("");
        $display("=== RESERVED ENCODING fn=2'b11 ======================");
        apply("reserved 8b",         8'hAA, 8'h55, 2'b11,  1'b0);  // C=00 D=00
        apply("reserved 4b",         8'hAA, 8'h55, 2'b11,  1'b1);  // C=00 D=00

        $display("");
        if (errors == 0)
            $display("tb_simd_wave: all four variants agree on every stimulus.");
        else
            $display("tb_simd_wave: *** %0d DISAGREEMENTS ***", errors);
        $display("");

        #(STEP*2);
        $finish;
    end

endmodule

`default_nettype wire
