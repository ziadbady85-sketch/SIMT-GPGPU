module data_memory #(
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32,
    parameter LINE_WORDS        = 8,
    parameter WORD_CNT_WIDTH    = 3,     // log2(LINE_WORDS)
    parameter BYTE_OFFSET_WIDTH = 2,     // log2(DATA_WIDTH/8)
    parameter MEM_WORDS         = 65536  // capacity in 32-bit words; resize to taste
) (
    input wire clk,
    input wire rst,

    input  wire                   mem_req_valid,
    input  wire [ADDR_WIDTH-1:0]  mem_req_address,
    output reg                    mem_resp_valid,
    output reg  [DATA_WIDTH-1:0]  mem_resp_data,

    input  wire                   mem_wr_valid,
    input  wire [ADDR_WIDTH-1:0]  mem_wr_address,
    input  wire [DATA_WIDTH-1:0]  mem_wr_data,
    output reg                    mem_wr_ready
);

    reg [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];

    localparam R_IDLE  = 1'd0,
               R_BURST = 1'd1;

    reg                       rstate;
    reg [ADDR_WIDTH-1:0]      base_word_addr;
    reg [WORD_CNT_WIDTH-1:0]  rcount;

    always @(posedge clk) begin
        if (rst) begin
            rstate         <= R_IDLE;
            mem_resp_valid <= 1'b0;
        end else begin
            mem_resp_valid <= 1'b0;
            case (rstate)
                R_IDLE: begin
                    if (mem_req_valid) begin
                        base_word_addr <= mem_req_address >> BYTE_OFFSET_WIDTH;
                        rcount         <= {WORD_CNT_WIDTH{1'b0}};
                        rstate         <= R_BURST;
                    end
                end
                R_BURST: begin
                    mem_resp_data  <= mem[base_word_addr + rcount];
                    mem_resp_valid <= 1'b1;
                    if (rcount == LINE_WORDS - 1)
                        rstate <= R_IDLE;
                    else
                        rcount <= rcount + 1'b1;
                end
                default: rstate <= R_IDLE;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            mem_wr_ready <= 1'b0;
        end else begin
            mem_wr_ready <= mem_wr_valid; // one-cycle-later acknowledgment
            if (mem_wr_valid) begin
                mem[mem_wr_address >> BYTE_OFFSET_WIDTH] <= mem_wr_data;
            end
        end
    end

endmodule
