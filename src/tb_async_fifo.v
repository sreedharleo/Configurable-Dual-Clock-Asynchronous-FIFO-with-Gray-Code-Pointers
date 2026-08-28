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
