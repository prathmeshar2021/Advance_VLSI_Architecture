// wavegen_tb.v : figure-only testbench. Not part of the submission.
// Runs the two test cases and writes per-cycle signal values to CSV files so
// the report's Vivado-style waveform figures are drawn from the exact same
// simulation as the results transcript.
`timescale 1ns/1ps
module wavegen_tb;
    reg          clk = 0;
    reg          rst, req, rw_bar;
    reg  [14:0]  byte_addr;
    reg  [31:0]  wdata;
    wire         stall;
    wire [31:0]  read_data;
    wire         read_complete, write_complete;

    mem_system u_dut (
        .clk(clk), .rst(rst), .req(req), .rw_bar(rw_bar),
        .byte_addr(byte_addr), .wdata(wdata), .stall(stall),
        .read_data(read_data), .read_complete(read_complete),
        .write_complete(write_complete));

    always #5 clk = ~clk;
    integer cycle; always @(posedge clk) if (rst) cycle<=0; else cycle<=cycle+1;

    integer issue_idx, comp_count;
    reg running; reg [14:0] base; integer stride; integer fh;

    always @* begin
        if (running && issue_idx < 16) begin
            req = 1; rw_bar = 1; byte_addr = base + issue_idx*stride;
        end else begin req = 0; rw_bar = 1; byte_addr = 0; end
        wdata = 0;
    end

    always @(posedge clk) begin
        if (!rst && running) begin
            if (cycle >= 1 && cycle <= 20)
                $fwrite(fh, "%0d,%0d,%0d,%0d,%0d,%0d,%08h\n",
                        cycle, req, stall, byte_addr, (byte_addr>>2)&7,
                        read_complete, read_data);
            if (req && !stall) issue_idx = issue_idx + 1;
            if (read_complete) comp_count = comp_count + 1;
        end
    end

    task run_test; input [14:0] b; input integer s; input [8*32:1] fname;
        begin
            running=0; rst=1; issue_idx=0; comp_count=0;
            repeat(3) @(posedge clk); rst=0; @(negedge clk);
            fh=$fopen(fname,"w");
            $fwrite(fh,"cycle,req,stall,byte_addr,bank,read_complete,read_data\n");
            base=b; stride=s; running=1;
            wait(comp_count==16); @(posedge clk); running=0; $fclose(fh);
        end
    endtask

    initial begin
        req=0; rw_bar=1; byte_addr=0; wdata=0; running=0; rst=1;
        base=0; stride=4; issue_idx=0; comp_count=0;
        run_test(15'h0, 4,  "sim/wave_test1.csv");
        run_test(15'h0, 16, "sim/wave_test2.csv");
        $finish;
    end
endmodule
