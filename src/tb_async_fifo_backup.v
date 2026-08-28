`timescale 1ns/1ps

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input  wire                  wr_clk,
    input  wire                  rd_clk,
    input  wire                  arst_n,

    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,

    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,

    input  wire [4:0]            afull_threshold,
    input  wire [4:0]            aempty_threshold,

    output reg                   full,
    output reg                   empty,
    output reg                   afull,
    output reg                   aempty
);

    // =========================================================
    // PARAMETERS
    // =========================================================

    localparam ADDR_WIDTH = $clog2(DEPTH);
    localparam PTR_WIDTH  = ADDR_WIDTH + 1;

    // =========================================================
    // FIFO MEMORY
    // =========================================================

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // =========================================================
    // WRITE POINTER
    // =========================================================

    reg [PTR_WIDTH-1:0] wr_bin;
    reg [PTR_WIDTH-1:0] wr_gray;

    reg [PTR_WIDTH-1:0] wr_bin_next;
    reg [PTR_WIDTH-1:0] wr_gray_next;

    wire write_do;

    assign write_do = wr_en && !full;

    // Binary and Gray-code next-state logic
    always @(*) begin

        wr_bin_next = wr_bin + write_do;

        wr_gray_next =
            wr_bin_next ^ (wr_bin_next >> 1);

    end

    // =========================================================
    // READ POINTER
    // =========================================================

    reg [PTR_WIDTH-1:0] rd_bin;
    reg [PTR_WIDTH-1:0] rd_gray;

    reg [PTR_WIDTH-1:0] rd_bin_next;
    reg [PTR_WIDTH-1:0] rd_gray_next;

    wire read_do;

    assign read_do = rd_en && !empty;

    // Binary and Gray-code next-state logic
    always @(*) begin

        rd_bin_next = rd_bin + read_do;

        rd_gray_next =
            rd_bin_next ^ (rd_bin_next >> 1);

    end

    // =========================================================
    // READ POINTER SYNCHRONIZER
    // READ DOMAIN -> WRITE DOMAIN
    //
    // Two flip-flops reduce metastability propagation.
    // =========================================================

    reg [PTR_WIDTH-1:0] rd_gray_sync1;
    reg [PTR_WIDTH-1:0] rd_gray_sync2;

    always @(posedge wr_clk or negedge arst_n) begin

        if (!arst_n) begin

            rd_gray_sync1 <= {PTR_WIDTH{1'b0}};
            rd_gray_sync2 <= {PTR_WIDTH{1'b0}};

        end
        else begin

            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;

        end

    end

    // =========================================================
    // WRITE POINTER SYNCHRONIZER
    // WRITE DOMAIN -> READ DOMAIN
    //
    // Two flip-flops reduce metastability propagation.
    // =========================================================

    reg [PTR_WIDTH-1:0] wr_gray_sync1;
    reg [PTR_WIDTH-1:0] wr_gray_sync2;

    always @(posedge rd_clk or negedge arst_n) begin

        if (!arst_n) begin

            wr_gray_sync1 <= {PTR_WIDTH{1'b0}};
            wr_gray_sync2 <= {PTR_WIDTH{1'b0}};

        end
        else begin

            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;

        end

    end

    // =========================================================
    // GRAY -> BINARY FUNCTION
    // =========================================================

    function [PTR_WIDTH-1:0] gray_to_binary;

        input [PTR_WIDTH-1:0] gray;

        integer i;

        begin

            gray_to_binary[PTR_WIDTH-1] =
                gray[PTR_WIDTH-1];

            for (i = PTR_WIDTH-2; i >= 0; i = i - 1) begin

                gray_to_binary[i] =
                    gray_to_binary[i+1] ^ gray[i];

            end

        end

    endfunction

    // =========================================================
    // SYNCHRONIZED POINTERS IN BINARY
    // =========================================================

    wire [PTR_WIDTH-1:0] rd_bin_sync;
    wire [PTR_WIDTH-1:0] wr_bin_sync;

    assign rd_bin_sync =
        gray_to_binary(rd_gray_sync2);

    assign wr_bin_sync =
        gray_to_binary(wr_gray_sync2);

    // =========================================================
    // FULL DETECTION
    //
    // FIFO is full when the next write Gray pointer equals
    // the synchronized read pointer with the two MSBs inverted.
    //
    // For DEPTH = 16:
    // PTR_WIDTH = 5
    //
    // =========================================================

    wire [PTR_WIDTH-1:0] full_compare;

    assign full_compare = {
        ~rd_gray_sync2[PTR_WIDTH-1:
                       PTR_WIDTH-2],
         rd_gray_sync2[PTR_WIDTH-3:0]
    };

    wire full_next;

    assign full_next =
        (wr_gray_next == full_compare);

    // =========================================================
    // EMPTY DETECTION
    //
    // FIFO is empty when the next read Gray pointer equals
    // the synchronized write Gray pointer.
    // =========================================================

    wire empty_next;

    assign empty_next =
        (rd_gray_next == wr_gray_sync2);

    // =========================================================
    // FIFO OCCUPANCY
    //
    // These counts are local-domain estimates based on the
    // synchronized pointer from the opposite clock domain.
    // =========================================================

    wire [PTR_WIDTH-1:0] write_count;
    wire [PTR_WIDTH-1:0] read_count;

    assign write_count =
        wr_bin - rd_bin_sync;

    assign read_count =
        wr_bin_sync - rd_bin;

    // =========================================================
    // ALMOST FULL
    //
    // Current implementation:
    // AFULL becomes active when occupancy reaches or exceeds
    // the programmed threshold.
    //
    // Example:
    // threshold = 12
    // occupancy >= 12 -> AFULL = 1
    //
    // =========================================================

    wire afull_next;

    assign afull_next =
        (write_count >= afull_threshold);

    // =========================================================
    // ALMOST EMPTY
    //
    // AEMPTY becomes active when the number of stored entries
    // is less than or equal to the programmed threshold.
    //
    // Example:
    // threshold = 2
    // occupancy <= 2 -> AEMPTY = 1
    //
    // =========================================================

    wire aempty_next;

    assign aempty_next =
        (read_count <= aempty_threshold);

    // =========================================================
    // WRITE DOMAIN
    //
    // Updates:
    //   - write binary pointer
    //   - write Gray pointer
    //   - FULL flag
    //   - AFULL flag
    // =========================================================

    always @(posedge wr_clk or negedge arst_n) begin

        if (!arst_n) begin

            wr_bin  <= {PTR_WIDTH{1'b0}};
            wr_gray <= {PTR_WIDTH{1'b0}};

            full  <= 1'b0;
            afull <= 1'b0;

        end
        else begin

            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;

            full  <= full_next;
            afull <= afull_next;

        end

    end

    // =========================================================
    // READ DOMAIN
    //
    // IMPORTANT:
    // rd_data is assigned ONLY HERE.
    //
    // This eliminates the previous Yosys multiple-driver
    // warning.
    // =========================================================

    always @(posedge rd_clk or negedge arst_n) begin

        if (!arst_n) begin

            rd_bin  <= {PTR_WIDTH{1'b0}};
            rd_gray <= {PTR_WIDTH{1'b0}};

            empty  <= 1'b1;
            aempty <= 1'b1;

            rd_data <= {DATA_WIDTH{1'b0}};

        end
        else begin

            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;

            empty  <= empty_next;
            aempty <= aempty_next;

            // FIFO memory read
            if (read_do) begin

                rd_data <= mem[rd_bin[ADDR_WIDTH-1:0]];

            end

        end

    end

    // =========================================================
    // MEMORY WRITE
    //
    // Memory is written only in the write clock domain.
    // =========================================================

    always @(posedge wr_clk) begin

        if (write_do) begin

            mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;

        end

    end

endmodule
`timescale 1ns/1ps

module tb_async_fifo;

    // ============================================================
    // PARAMETERS
    // ============================================================

    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 16;
    parameter ADDR_WIDTH = 4;
    parameter PTR_WIDTH  = ADDR_WIDTH + 1;

    // ============================================================
    // CLOCK AND RESET
    // ============================================================

    reg wr_clk;
    reg rd_clk;
    reg arst_n;

    // ============================================================
    // WRITE INTERFACE
    // ============================================================

    reg                  wr_en;
    reg [DATA_WIDTH-1:0] wr_data;

    // ============================================================
    // READ INTERFACE
    // ============================================================

    reg                  rd_en;
    wire [DATA_WIDTH-1:0] rd_data;

    // ============================================================
    // FIFO FLAGS
    // ============================================================

    wire full;
    wire empty;
    wire afull;
    wire aempty;

    // ============================================================
    // PROGRAMMABLE WATERMARK THRESHOLDS
    // ============================================================

    reg [PTR_WIDTH-1:0] afull_threshold;
    reg [PTR_WIDTH-1:0] aempty_threshold;

    // ============================================================
    // DUT
    // ============================================================

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
        ) dut (

        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .arst_n(arst_n),

        .wr_en(wr_en),
        .wr_data(wr_data),

        .rd_en(rd_en),
        .rd_data(rd_data),

        .full(full),
        .empty(empty),

        .afull(afull),
        .aempty(aempty),

        .afull_threshold(afull_threshold),
        .aempty_threshold(aempty_threshold)
    );

    // ============================================================
    // CLOCK GENERATION
    // ============================================================

    // Write clock = 10 ns period
    always #5 wr_clk = ~wr_clk;

    // Read clock = 14 ns period
    // Different frequency and phase
    always #7 rd_clk = ~rd_clk;

    // ============================================================
    // TEST COUNTERS
    // ============================================================

    integer errors;
    integer writes;
    integer reads;

    // ============================================================
    // EXPECTED DATA QUEUE
    // ============================================================

    reg [DATA_WIDTH-1:0] expected_queue [0:DEPTH*4-1];

    integer q_write;
    integer q_read;

    // ============================================================
    // WRITE SCOREBOARD
    // ============================================================

    always @(posedge wr_clk) begin

        if (!arst_n) begin

            q_write <= 0;
            writes  <= 0;

        end
        else begin

            if (wr_en && !full) begin

                expected_queue[q_write] <= wr_data;

                q_write <= q_write + 1;

                writes <= writes + 1;

                $display(
                    "[WRITE] time=%0t data=%h full=%b afull=%b",
                    $time,
                    wr_data,
                    full,
                    afull
                );

            end

        end

    end

    // ============================================================
    // READ SCOREBOARD
    // ============================================================

    always @(posedge rd_clk) begin

        if (!arst_n) begin

            q_read <= 0;
            reads  <= 0;

        end
        else begin

            if (rd_en && !empty) begin

                #1;

                if (rd_data !== expected_queue[q_read]) begin

                    $display(
                        "[ERROR] time=%0t expected=%h received=%h",
                        $time,
                        expected_queue[q_read],
                        rd_data
                    );

                    errors = errors + 1;

                end
                else begin

                    $display(
                        "[READ PASS] time=%0t data=%h empty=%b aempty=%b",
                        $time,
                        rd_data,
                        empty,
                        aempty
                    );

                end

                q_read <= q_read + 1;

                reads <= reads + 1;

            end

        end

    end

    // ============================================================
    // RESET TASK
    // ============================================================

    task reset_fifo;

        begin

            $display("");
            $display("==============================================");
            $display("RESET TEST");
            $display("==============================================");

            arst_n = 0;

            wr_en  = 0;
            rd_en  = 0;

            wr_data = 0;

            #40;

            arst_n = 1;

            #30;

            $display(
                "[RESET COMPLETE] full=%b empty=%b afull=%b aempty=%b",
                full,
                empty,
                afull,
                aempty
            );

            if (empty !== 1'b1) begin

                $display("[ERROR] FIFO should be EMPTY after reset");

                errors = errors + 1;

            end
            else begin

                $display("[PASS] FIFO EMPTY after reset");

            end

        end

    endtask

    // ============================================================
    // WRITE ONE DATA
    // ============================================================

    task write_one;

        input [DATA_WIDTH-1:0] data;

        begin

            @(negedge wr_clk);

            if (!full) begin

                wr_en   = 1;
                wr_data = data;

                @(negedge wr_clk);

                wr_en = 0;

            end
            else begin

                $display(
                    "[INFO] Write blocked because FIFO is FULL"
                );

            end

        end

    endtask

    // ============================================================
    // READ ONE DATA
    // ============================================================

    task read_one;

        begin

            @(negedge rd_clk);

            if (!empty) begin

                rd_en = 1;

                @(negedge rd_clk);

                rd_en = 0;

            end
            else begin

                $display(
                    "[INFO] Read blocked because FIFO is EMPTY"
                );

            end

        end

    endtask

    // ============================================================
    // TEST 1
    // NORMAL WRITE / READ
    // ============================================================

    task normal_test;

        integer i;

        begin

            $display("");
            $display("==============================================");
            $display("TEST 1 : NORMAL WRITE / READ");
            $display("==============================================");

            for (i = 0; i < 8; i = i + 1) begin

                write_one(8'hA0 + i);

            end

            #100;

            for (i = 0; i < 8; i = i + 1) begin

                read_one();

            end

            #150;

        end

    endtask

    // ============================================================
    // TEST 2
    // FILL FIFO COMPLETELY
    // ============================================================

    task full_test;

        integer i;

        begin

            $display("");
            $display("==============================================");
            $display("TEST 2 : FULL BOUNDARY");
            $display("==============================================");

            // Reset before full test

            arst_n = 0;

            #30;

            arst_n = 1;

            #30;

            // Write DEPTH entries

            for (i = 0; i < DEPTH; i = i + 1) begin

                write_one(8'h10 + i);

            end

            // Allow pointer synchronization

            #150;

            $display(
                "[FULL CHECK] full=%b afull=%b",
                full,
                afull
            );

            if (full === 1'b1) begin

                $display("[PASS] FIFO FULL flag asserted");

            end
            else begin

                $display("[ERROR] FIFO FULL flag NOT asserted");

                errors = errors + 1;

            end

            // Try one additional write

            $display("[FULL TEST] Attempting write while FULL");

            write_one(8'hFF);

            #50;

        end

    endtask

    // ============================================================
    // TEST 3
    // EMPTY BOUNDARY
    // ============================================================

    task empty_test;

        integer i;

        begin

            $display("");
            $display("==============================================");
            $display("TEST 3 : EMPTY BOUNDARY");
            $display("==============================================");

            // Read all existing data

            for (i = 0; i < DEPTH; i = i + 1) begin

                read_one();

            end

            #150;

            $display(
                "[EMPTY CHECK] empty=%b aempty=%b",
                empty,
                aempty
            );

            if (empty === 1'b1) begin

                $display("[PASS] FIFO EMPTY flag asserted");

            end
            else begin

                $display("[ERROR] FIFO EMPTY flag NOT asserted");

                errors = errors + 1;

            end

            // Attempt read while empty

            $display("[EMPTY TEST] Attempting read while EMPTY");

            read_one();

            #50;

        end

    endtask

    // ============================================================
    // TEST 4
    // AFULL WATERMARK
    // ============================================================

    task afull_test;

        integer i;

        begin

            $display("");
            $display("==============================================");
            $display("TEST 4 : AFULL WATERMARK");
            $display("==============================================");

            // Reset

            arst_n = 0;

            #30;

            arst_n = 1;

            #30;

            // AFULL when FIFO reaches 12 entries

            afull_threshold = 12;

            aempty_threshold = 2;

            $display(
                "[CONFIG] AFULL_THRESHOLD=%0d",
                afull_threshold
            );

            // Write 12 entries

            for (i = 0; i < 12; i = i + 1) begin

                write_one(8'h50 + i);

            end

            #150;

            $display(
                "[AFULL CHECK] afull=%b",
                afull
            );

            if (afull === 1'b1) begin

                $display("[PASS] AFULL asserted at threshold");

            end
            else begin

                $display("[ERROR] AFULL not asserted");

                errors = errors + 1;

            end

        end

    endtask

    // ============================================================
    // TEST 5
    // AEMPTY WATERMARK
    // ============================================================

    task aempty_test;

        integer i;

        begin

            $display("");
            $display("==============================================");
            $display("TEST 5 : AEMPTY WATERMARK");
            $display("==============================================");

            // Read until only 2 entries remain

            for (i = 0; i < 10; i = i + 1) begin

                read_one();

            end

            #150;

            $display(
                "[AEMPTY CHECK] aempty=%b",
                aempty
            );

            if (aempty === 1'b1) begin

                $display("[PASS] AEMPTY asserted");

            end
            else begin

                $display("[ERROR] AEMPTY not asserted");

                errors = errors + 1;

            end

        end

    endtask

    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin

        // Initial values

        wr_clk = 0;
        rd_clk = 0;

        arst_n = 0;

        wr_en = 0;
        rd_en = 0;

        wr_data = 0;

        afull_threshold = 12;
        aempty_threshold = 2;

        errors = 0;
        writes = 0;
        reads = 0;

        q_write = 0;
        q_read = 0;

        // Reset

        reset_fifo();

        // Test 1

        normal_test();

        // Test 2

        full_test();

        // Test 3

        empty_test();

        // Test 4

        afull_test();

        // Test 5

        aempty_test();

        // Allow final operations

        #300;

        // ========================================================
        // FINAL RESULT
        // ========================================================

        $display("");
        $display("==============================================");
        $display("        PS-04 ASYNC FIFO FINAL RESULT");
        $display("==============================================");

        $display("Total writes = %0d", writes);
        $display("Total reads  = %0d", reads);
        $display("Total errors = %0d", errors);

        if (errors == 0) begin

            $display("");
            $display("**************************************");
            $display("       ALL TESTS PASSED");
            $display("**************************************");
            $display("");

        end
        else begin

            $display("");
            $display("**************************************");
            $display("       TEST FAILED");
            $display("       Errors = %0d", errors);
            $display("**************************************");
            $display("");

        end

        $finish;

    end

    // ============================================================
    // VCD WAVEFORM
    // ============================================================

    initial begin

        $dumpfile("async_fifo.vcd");

        $dumpvars(0, tb_async_fifo);

    end

endmodule
