// ===========================================================================
// tb_mem_system.v  --  testbench for the interleaved memory system
//
// MEL G624 Advanced VLSI Architectures, Assignment 2
//
// Models a simple vector processor that issues one read attempt per cycle and,
// when the memory system raises stall, HOLDS the access and retries it on the
// next cycle (the memory system only rejects and flags; it does not buffer).
//
// It runs the two required test cases back to back:
//   Test 1 : 16 reads to 16 successive words, byte addresses 0,4,8,...,60
//            (unit stride - hits all 8 banks in turn, should never stall)
//   Test 2 : 16 reads with a 16-byte stride, byte addresses 0,16,32,...,240
//            (stride 4 words - every access lands on bank 0 or bank 4, so the
//             two banks are hammered and the stream stalls badly)
//
// For each test it prints a per-cycle transcript, checks the read data and the
// completion order against a golden expectation, and reports the sustained
// initiation rate (words per cycle).
// ===========================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_mem_system;

    localparam integer DATA_W = 32;

    // ---- DUT connections --------------------------------------------------
    reg          clk = 1'b0;
    reg          rst;
    reg          req;
    reg          rw_bar;
    reg  [14:0]  byte_addr;
    reg  [31:0]  wdata;
    wire         stall;
    wire [31:0]  read_data;
    wire         read_complete;
    wire         write_complete;

    mem_system u_dut (
        .clk            (clk),
        .rst            (rst),
        .req            (req),
        .rw_bar         (rw_bar),
        .byte_addr      (byte_addr),
        .wdata          (wdata),
        .stall          (stall),
        .read_data      (read_data),
        .read_complete  (read_complete),
        .write_complete (write_complete)
    );

    always #5 clk = ~clk;          // 100 MHz reference clock

    // ---- free-running cycle counter --------------------------------------
    integer cycle;
    always @(posedge clk) if (rst) cycle <= 0; else cycle <= cycle + 1;

    // ---- golden expectation ----------------------------------------------
    // A read of byte address A returns 0xC0DE_0000 | (A >> 2).
    function [31:0] expected_data;
        input [14:0] a;
        expected_data = 32'hC0DE_0000 | (a >> 2);
    endfunction

    // ---- bookkeeping ------------------------------------------------------
    integer issue_idx;             // next access to issue (0..15)
    integer issue_cycle [0:15];    // cycle each access was accepted
    integer comp_count;            // completions seen so far
    integer stall_count;           // total stalled (rejected) cycles
    integer first_issue_cycle;
    integer last_comp_cycle;
    integer errors;

    reg         running;           // a test is in progress
    reg  [14:0] base;
    integer     stride;

    // one accept/cycle invariant check
    integer dcount, bi;

    // -----------------------------------------------------------------------
    // Processor stimulus: drive req / byte_addr combinationally from state so
    // they are stable at each rising edge; hold the access while stalled.
    // -----------------------------------------------------------------------
    always @* begin
        if (running && issue_idx < 16) begin
            req       = 1'b1;
            rw_bar    = 1'b1;                       // all test accesses are reads
            byte_addr = base + issue_idx*stride;
        end else begin
            req       = 1'b0;
            rw_bar    = 1'b1;
            byte_addr = 15'd0;
        end
        wdata = 32'd0;
    end

    // advance / collect on each rising edge
    always @(posedge clk) begin
        if (!rst && running) begin
            // an attempt that is not stalled is accepted this edge
            if (req && !stall) begin
                issue_cycle[issue_idx] = cycle;
                if (issue_idx == 0) first_issue_cycle = cycle;
                $display("  cyc %0d : ISSUE  read #%0d  byte_addr=0x%03h  (bank %0d, row %0d)",
                         cycle, issue_idx, byte_addr,
                         (byte_addr>>2) & 7, (byte_addr>>5));
                issue_idx = issue_idx + 1;
            end else if (req && stall) begin
                stall_count = stall_count + 1;
                $display("  cyc %0d : STALL  retry byte_addr=0x%03h  (bank %0d busy)",
                         cycle, byte_addr, (byte_addr>>2) & 7);
            end

            // completions (at most one per cycle)
            if (read_complete) begin
                last_comp_cycle = cycle;
                if (read_data !== expected_data(base + comp_count*stride)) begin
                    $display("  cyc %0d : COMPLETE read #%0d data=0x%08h  *** EXPECTED 0x%08h ***",
                             cycle, comp_count, read_data,
                             expected_data(base + comp_count*stride));
                    errors = errors + 1;
                end else begin
                    $display("  cyc %0d : COMPLETE read #%0d data=0x%08h  (ok)",
                             cycle, comp_count, read_data);
                end
                comp_count = comp_count + 1;
            end
        end
    end

    // -----------------------------------------------------------------------
    // defensive check: never more than one bank completing in the same cycle
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            dcount = 0;
            for (bi = 0; bi < 8; bi = bi + 1)
                if (u_dut.b_done[bi]) dcount = dcount + 1;
            if (dcount > 1) begin
                $display("  cyc %0d : *** %0d banks completed in one cycle ***",
                         cycle, dcount);
                errors = errors + 1;
            end
        end
    end

    // -----------------------------------------------------------------------
    // test driver
    // -----------------------------------------------------------------------
    task run_test;
        input [14:0] t_base;
        input integer t_stride;
        input [8*40-1:0] name;
        integer win;
        begin
            // reset to clear all banks between tests
            running = 1'b0;
            rst = 1'b1;
            issue_idx = 0; comp_count = 0; stall_count = 0;
            first_issue_cycle = 0; last_comp_cycle = 0;
            repeat (3) @(posedge clk);
            rst = 1'b0;
            @(negedge clk);

            base = t_base; stride = t_stride;
            $display("");
            $display("==========================================================");
            $display(" %0s : 16 reads, base byte 0x%0h, stride %0d bytes",
                     name, t_base, t_stride);
            $display("==========================================================");

            running = 1'b1;
            // run until all 16 completions arrive
            wait (comp_count == 16);
            @(posedge clk);
            running = 1'b0;

            win = issue_cycle[15] - first_issue_cycle + 1;
            $display("  ----------------------------------------------------");
            $display("  issued 16 reads over cycles %0d..%0d  (%0d cycles)",
                     first_issue_cycle, issue_cycle[15], win);
            $display("  stalls (rejected attempts) : %0d", stall_count);
            $display("  last completion at cycle   : %0d", last_comp_cycle);
            $display("  sustained initiation rate  : %0d/%0d = %0d.%02d words/cycle",
                     16, win, 16/win, (1600/win) % 100);
            $display("");
        end
    endtask

    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_mem_system.vcd");
        $dumpvars(0, tb_mem_system);

        errors = 0;
        req = 0; rw_bar = 1; byte_addr = 0; wdata = 0;
        running = 0; rst = 1; base = 0; stride = 4;
        issue_idx = 0; comp_count = 0; stall_count = 0;

        run_test(15'h0000, 4,  "TEST 1 unit-stride (stride 4B)");
        run_test(15'h0000, 16, "TEST 2 stride 16 bytes");

        $display("==========================================================");
        if (errors == 0)
            $display(" RESULT: all reads returned correct data, in order. PASS");
        else
            $display(" RESULT: %0d error(s). FAIL", errors);
        $display("==========================================================");
        $finish;
    end

    // safety timeout
    initial begin
        #20000;
        $display("TIMEOUT");
        $finish;
    end

endmodule

`default_nettype wire
