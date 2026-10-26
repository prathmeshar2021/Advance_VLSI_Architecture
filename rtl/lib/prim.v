// ---------------------------------------------------------------------------
// prim.v : primitive 1-bit adder cells
// MEL G624 Advanced VLSI Architectures - Assignment 1
// ---------------------------------------------------------------------------
`default_nettype none

// Full adder : 3 -> 2 compressor
module fa (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);
    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));
endmodule

// Half adder : 2 -> 2 compressor
module ha (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire cout
);
    assign sum  = a ^ b;
    assign cout = a & b;
endmodule

`default_nettype wire
