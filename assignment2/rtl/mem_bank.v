// ===========================================================================
// mem_bank.v  --  one independently addressable memory bank
//
// MEL G624 Advanced VLSI Architectures, Assignment 2
//
// A single word-addressable bank that models a real access latency: once an
// access (read or write) is latched, the bank is BUSY for ACCESS_CYCLES
// (= 6) processor clock cycles and cannot accept another access during that
// time.  The data read out is presented on a built-in 32-bit output register.
//
// Interface (all synchronous to clk):
//   bank_enable : the memory system asserts this to latch a new access on the
//                 next rising edge.  The system only asserts it when the bank
//                 can actually take the access (see accept_ok), so the bank
//                 trusts it.
//   rw_bar      : 1 = read, 0 = write.
//   addr        : 10-bit word (row) address inside this bank.
//   wdata       : 32-bit write data.
//
//   accept_ok   : combinational flag - the bank is free (or frees itself on
//                 the coming edge), so an access presented now would be taken.
//                 The memory system uses this to decide stall.
//   rdata       : output register, holds the data of the last completed read.
//   done        : one-cycle pulse when an access completes (6 cycles after it
//                 was latched).
//   done_rw     : type of the access that just completed (1 read / 0 write).
// ===========================================================================
`default_nettype none

module mem_bank #(
    parameter integer ADDR_W        = 10,   // 1024 words per bank
    parameter integer DATA_W        = 32,
    parameter integer ACCESS_CYCLES = 6,    // bank busy time in clk cycles
    parameter integer BANK_ID       = 0,    // which bank this is (for init data)
    parameter integer BANK_COUNT    = 8     // total banks (for init data)
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              bank_enable,
    input  wire              rw_bar,
    input  wire [ADDR_W-1:0] addr,
    input  wire [DATA_W-1:0] wdata,
    output wire              accept_ok,
    output reg  [DATA_W-1:0] rdata,
    output reg               done,
    output reg               done_rw
);
    // width of the busy counter (needs to hold 0..ACCESS_CYCLES)
    localparam integer CW = $clog2(ACCESS_CYCLES + 1);

    reg [CW-1:0]     busy;      // cycles left until the bank is free (0 = idle)
    reg [ADDR_W-1:0] a_addr;    // address of the access currently in flight
    reg [DATA_W-1:0] a_wdata;   // write data   "        "        "
    reg              a_rw;      // type         "        "        "

    reg [DATA_W-1:0] mem [0:(1<<ADDR_W)-1];   // the storage array

    // The in-flight access reaches its final (6th) cycle when busy == 1: on
    // this edge it completes, and the bank may immediately take a new access.
    wire completing = (busy == {{(CW-1){1'b0}}, 1'b1});

    // The bank can latch a new access on the coming edge if it is idle (busy
    // == 0) or finishing on that same edge (busy == 1).  Exposed to the
    // system so it can raise stall when busy >= 2.
    assign accept_ok = (busy <= {{(CW-1){1'b0}}, 1'b1});

    // -----------------------------------------------------------------------
    // Memory initialisation (simulation model only).
    // The global word address of row r in this bank, under low-order
    // interleaving, is  W = r*BANK_COUNT + BANK_ID.  Each location is seeded
    // with 0xC0DE_0000 | W so a read returns an easily recognised value and
    // the testbench can check both data and completion order.
    // -----------------------------------------------------------------------
    integer g;
    initial begin
        for (g = 0; g < (1<<ADDR_W); g = g + 1)
            mem[g] = 32'hC0DE_0000 | (g*BANK_COUNT + BANK_ID);
    end

    always @(posedge clk) begin
        if (rst) begin
            busy    <= {CW{1'b0}};
            done    <= 1'b0;
            done_rw <= 1'b0;
            rdata   <= {DATA_W{1'b0}};
        end else begin
            // ---- completion of the access that is finishing this edge ------
            if (completing) begin
                done    <= 1'b1;
                done_rw <= a_rw;
                if (a_rw) rdata        <= mem[a_addr];   // read : present data
                else      mem[a_addr]  <= a_wdata;       // write: commit now
            end else begin
                done <= 1'b0;
            end

            // ---- acceptance of a new access (may share the completion edge) -
            if (bank_enable) begin
                a_addr  <= addr;
                a_wdata <= wdata;
                a_rw    <= rw_bar;
                busy    <= ACCESS_CYCLES[CW-1:0];
            end else if (busy != {CW{1'b0}}) begin
                busy <= busy - 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
