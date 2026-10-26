// ---------------------------------------------------------------------------
// adder_ks.v : parameterised Kogge-Stone parallel-prefix adder
//
// Carry-in is folded into the generate term of bit 0, which is legal because
// the prefix operator "o" is associative:
//     G[i:0] = g_i + p_i*(g_(i-1) + ... + p_1*(g_0 + p_0*cin))
// so pre-loading g_0' = g_0 + p_0*cin yields the correct carry at every bit
// position without spending an extra prefix level on the carry-in.
//
// Logic depth = ceil(log2(W)) prefix levels + 1 XOR.
//
// The prefix network is held in flat vectors (not unpacked arrays) so that the
// source elaborates identically in Vivado, XSim, Icarus and Yosys.
// ---------------------------------------------------------------------------
`default_nettype none

module adder_ks #(
    parameter W = 16
) (
    input  wire [W-1:0] a,
    input  wire [W-1:0] b,
    input  wire         cin,
    output wire [W-1:0] sum,
    output wire         cout
);
    localparam integer LEVELS = (W <= 1) ? 1 : $clog2(W);

    wire [W-1:0] p0 = a ^ b;   // bit propagate (also the half sum)
    wire [W-1:0] g0 = a & b;   // bit generate

    // Level-0 prefix terms, carry-in folded into bit 0.
    wire [W-1:0] Gin;
    wire [W-1:0] Pin;
    assign Gin = g0 | ((p0 & {{(W-1){1'b0}}, cin}));
    assign Pin = p0;

    // Flat prefix network: level k occupies bits [k*W +: W].
    wire [(LEVELS+1)*W-1:0] Gn;
    wire [(LEVELS+1)*W-1:0] Pn;

    assign Gn[0 +: W] = Gin;
    assign Pn[0 +: W] = Pin;

    genvar k, i;
    generate
        for (k = 0; k < LEVELS; k = k + 1) begin : g_level
            for (i = 0; i < W; i = i + 1) begin : g_node
                if (i >= (1 << k)) begin : g_combine
                    // (G,P) o (G',P') = (G + P*G', P*P')
                    assign Gn[(k+1)*W + i] = Gn[k*W + i] |
                                             (Pn[k*W + i] & Gn[k*W + i - (1 << k)]);
                    assign Pn[(k+1)*W + i] = Pn[k*W + i] &
                                              Pn[k*W + i - (1 << k)];
                end else begin : g_pass
                    assign Gn[(k+1)*W + i] = Gn[k*W + i];
                    assign Pn[(k+1)*W + i] = Pn[k*W + i];
                end
            end
        end
    endgenerate

    // Carry into bit i is the group generate spanning bits [i-1:0].
    wire [W-1:0] cbit;
    assign cbit[0] = cin;
    generate
        for (i = 1; i < W; i = i + 1) begin : g_carry
            assign cbit[i] = Gn[LEVELS*W + i - 1];
        end
    endgenerate

    assign sum  = p0 ^ cbit;
    assign cout = Gn[LEVELS*W + W - 1];
endmodule

`default_nettype wire
