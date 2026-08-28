`timescale 1ns/1ps

module tb_async_fifo;

    // =========================================================
    // PARAMETERS
    // =========================================================

    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;

    // =========================================================
    // CLOCKS
    // =========================================================

    reg wr_clk;
    reg rd_clk;

    // =========================================================
    // RESET
    // =========================================================

    reg arst_n;

    // =========================================================
    // WRITE SIGNALS
    // =========================================================

    reg                  wr_en;
    reg [DATA_WIDTH-1:0] wr_data;

    // =========================================================
    // READ SIGNALS
    // =========================================================

    reg                  rd_en;
    wire [DATA_WIDTH-1:0] rd_data;

    // =========================================================
    // WATERMARK THRESHOLDS
    // =========================================================

    reg [4:0] afull_threshold;
    reg [4:0] aempty_threshold;

    // =========================================================
    // FIFO FLAGS
    // =========================================================

    wire full;
    wire empty;
    wire afull;
    wire aempty;

    // =========================================================
    // DUT
    // =========================================================

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

        .afull_threshold(afull_threshold),
        .aempty_threshold(aempty_threshold),

        .full(full),
        .empty(empty),
        .afull(afull),
        .aempty(aempty)

    );

    // =========================================================
    // WRITE CLOCK
    // 10 ns PERIOD
    // =========================================================

    initial begin

        wr_clk = 1'b0;

        forever
            #5 wr_clk = ~wr_clk;

    end

    // =========================================================
    // READ CLOCK
    // 14 ns PERIOD
    // =========================================================

    initial begin

        rd_clk = 1'b0;

        forever
            #7 rd_clk = ~rd_clk;

    end

    // =========================================================
    // VCD WAVEFORM
    // =========================================================

    
    initial begin

    $dumpfile("async_fifo.vcd");

    // Dump complete testbench hierarchy
    $dumpvars(0, tb_async_fifo);

    // Explicitly dump FIFO DUT hierarchy
    $dumpvars(0, tb_async_fifo.dut);

    end
    // =========================================================
    // MAIN TEST
    // =========================================================

    initial begin

        // -----------------------------------------------------
        // INITIAL CONDITIONS
        // -----------------------------------------------------

        arst_n = 1'b0;

        wr_en = 1'b0;
        wr_data = 8'h00;

        rd_en = 1'b0;

        // -----------------------------------------------------
        // WATERMARK CONFIGURATION
        // -----------------------------------------------------

        afull_threshold = 12;

        aempty_threshold = 2;

        // -----------------------------------------------------
        // RESET
        // -----------------------------------------------------

        #25;

        arst_n = 1'b1;

        $display("");
        $display("========================================");
        $display(" RESET RELEASED ");
        $display("========================================");
        $display("");

        // Wait for FIFO to become ready

        #30;

        // -----------------------------------------------------
        // WRITE DATA
        // -----------------------------------------------------

        write_data(8'hA1);
        write_data(8'hA2);
        write_data(8'hA3);
        write_data(8'hA4);
        write_data(8'hA5);
        write_data(8'hA6);
        write_data(8'hA7);
        write_data(8'hA8);

        // -----------------------------------------------------
        // WAIT FOR CDC
        // -----------------------------------------------------

        #60;

        // -----------------------------------------------------
        // READ DATA
        // -----------------------------------------------------

        read_data;
        read_data;
        read_data;
        read_data;

        // -----------------------------------------------------
        // WRITE MORE DATA
        // -----------------------------------------------------

        write_data(8'hB1);
        write_data(8'hB2);
        write_data(8'hB3);
        write_data(8'hB4);

        // -----------------------------------------------------
        // WAIT
        // -----------------------------------------------------

        #60;

        // -----------------------------------------------------
        // READ MORE DATA
        // -----------------------------------------------------

        read_data;
        read_data;
        read_data;
        read_data;
        read_data;
        read_data;
        read_data;
        read_data;

        // -----------------------------------------------------
        // FINAL WAIT
        // -----------------------------------------------------

        #100;

        $display("");
        $display("========================================");
        $display(" PS-04 ASYNC FIFO TEST COMPLETE ");
        $display("========================================");
        $display("");

        $finish;

    end

    // =========================================================
    // WRITE TASK
    // =========================================================

    task write_data;

        input [DATA_WIDTH-1:0] data;

        begin

            @(posedge wr_clk);

            if (!full) begin

                wr_en = 1'b1;

                wr_data = data;

                $display(
                    "%0t : WRITE DATA = %h",
                    $time,
                    data
                );

            end

            else begin

                wr_en = 1'b0;

                $display(
                    "%0t : WRITE BLOCKED - FIFO FULL",
                    $time
                );

            end

            @(posedge wr_clk);

            wr_en = 1'b0;

        end

    endtask

    // =========================================================
    // READ TASK
    // =========================================================

    task read_data;

        begin

            @(posedge rd_clk);

            if (!empty) begin

                rd_en = 1'b1;

                $display(
                    "%0t : READ REQUEST",
                    $time
                );

            end

            else begin

                rd_en = 1'b0;

                $display(
                    "%0t : READ BLOCKED - FIFO EMPTY",
                    $time
                );

            end

            @(posedge rd_clk);

            rd_en = 1'b0;

        end

    endtask

    // =========================================================
    // WRITE DOMAIN MONITOR
    // =========================================================

    always @(posedge wr_clk) begin

        $display(
            "%0t : WR | BIN=%0d GRAY=%b FULL=%b AFULL=%b",
            $time,
            dut.wr_bin,
            dut.wr_gray,
            full,
            afull
        );

    end

    // =========================================================
    // READ DOMAIN MONITOR
    // =========================================================

    always @(posedge rd_clk) begin

        $display(
            "%0t : RD | BIN=%0d GRAY=%b EMPTY=%b AEMPTY=%b DATA=%h",
            $time,
            dut.rd_bin,
            dut.rd_gray,
            empty,
            aempty,
            rd_data
        );

    end

endmodule
