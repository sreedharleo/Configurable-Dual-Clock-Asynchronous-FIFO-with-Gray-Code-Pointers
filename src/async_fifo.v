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
