// ===========================================================================
// mem_system.v  --  high-bandwidth interleaved data memory system
//
// MEL G624 Advanced VLSI Architectures, Assignment 2
//
// Eight independent memory banks, each with a 6-cycle access time, arranged
// so the processor can (ideally) start one 32-bit word access every clock
// cycle.  The trick is LOW-ORDER INTERLEAVING: consecutive words live in
// consecutive banks, so a unit-stride stream touches a given bank only once
// every 8 cycles - longer than the 6-cycle bank busy time - and never stalls.
//
// Processor-side interface (big-endian, byte addressable, always a 4-byte
// aligned word access):
//   req           : the processor is attempting an access this cycle.
//   rw_bar        : 1 = read, 0 = write.
//   byte_addr     : byte address of the word (bits [1:0] are 0, aligned).
//   wdata         : 32-bit write data.
//
//   stall         : high when this cycle's attempt hit a busy bank and was
//                   rejected.  The processor must hold the access and retry.
//   read_data     : data of the read that completed this cycle.
//   read_complete : one-cycle pulse, a read finished (read_data valid).
//   write_complete: one-cycle pulse, a write finished.
//
// Address decode (BANKS = 8, 1024 words/bank -> 13-bit word address):
//   word_addr = byte_addr[14:2]
//   bank_sel  = word_addr[2:0]   = byte_addr[4:2]     (low-order interleave)
//   row_addr  = word_addr[12:3]  = byte_addr[14:5]
//
// Completion order: the system accepts at most one access per cycle and every
// access has the same fixed 6-cycle latency, so completions naturally emerge
// in the exact order the accesses were issued - no reorder buffer is needed.
// ===========================================================================
`default_nettype none

module mem_system #(
    parameter integer BANKS         = 8,
    parameter integer BANK_ADDR_W   = 10,
    parameter integer DATA_W        = 32,
    parameter integer ACCESS_CYCLES = 6,
    // byte address width is derived: 2 offset + log2(BANKS) bank + row bits.
    // Declared here (not as a body localparam) so it can size the port below.
    parameter integer BYTE_ADDR_W   = $clog2(BANKS) + BANK_ADDR_W + 2
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     req,
    input  wire                     rw_bar,
    input  wire [BYTE_ADDR_W-1:0]   byte_addr,
    input  wire [DATA_W-1:0]        wdata,
    output wire                     stall,
    output reg  [DATA_W-1:0]        read_data,
    output reg                      read_complete,
    output reg                      write_complete
);
    localparam integer BANK_SEL_W   = $clog2(BANKS);                 // 3
    localparam integer WORD_ADDR_W  = BANK_SEL_W + BANK_ADDR_W;      // 13

    // ---- address decode ---------------------------------------------------
    wire [WORD_ADDR_W-1:0]  word_addr = byte_addr[BYTE_ADDR_W-1:2];
    wire [BANK_SEL_W-1:0]   bank_sel  = word_addr[BANK_SEL_W-1:0];
    wire [BANK_ADDR_W-1:0]  row_addr  = word_addr[WORD_ADDR_W-1:BANK_SEL_W];

    // ---- per-bank signals -------------------------------------------------
    wire [BANKS-1:0]        b_accept_ok;
    wire [BANKS-1:0]        b_done;
    wire [BANKS-1:0]        b_done_rw;
    wire [DATA_W-1:0]       b_rdata [0:BANKS-1];
    reg  [BANKS-1:0]        b_enable;

    // One-hot enable: assert only the selected bank, and only if it can take
    // the access.  A rejected attempt (selected bank busy) raises stall.
    integer e;
    always @* begin
        b_enable = {BANKS{1'b0}};
        if (req && b_accept_ok[bank_sel])
            b_enable[bank_sel] = 1'b1;
    end

    assign stall = req & ~b_accept_ok[bank_sel];

    // ---- bank instances ---------------------------------------------------
    genvar b;
    generate
        for (b = 0; b < BANKS; b = b + 1) begin : g_bank
            mem_bank #(
                .ADDR_W        (BANK_ADDR_W),
                .DATA_W        (DATA_W),
                .ACCESS_CYCLES (ACCESS_CYCLES),
                .BANK_ID       (b),
                .BANK_COUNT    (BANKS)
            ) u_bank (
                .clk         (clk),
                .rst         (rst),
                .bank_enable (b_enable[b]),
                .rw_bar      (rw_bar),
                .addr        (row_addr),
                .wdata       (wdata),
                .accept_ok   (b_accept_ok[b]),
                .rdata       (b_rdata[b]),
                .done        (b_done[b]),
                .done_rw     (b_done_rw[b])
            );
        end
    endgenerate

    // ---- completion collection -------------------------------------------
    // At most one bank completes per cycle (one accept/cycle, fixed latency),
    // so a simple OR / priority pick is exact and preserves issue order.
    integer i;
    always @* begin
        read_data      = {DATA_W{1'b0}};
        read_complete  = 1'b0;
        write_complete = 1'b0;
        for (i = 0; i < BANKS; i = i + 1) begin
            if (b_done[i]) begin
                if (b_done_rw[i]) begin
                    read_complete = 1'b1;
                    read_data     = b_rdata[i];
                end else begin
                    write_complete = 1'b1;
                end
            end
        end
    end
endmodule

`default_nettype wire
