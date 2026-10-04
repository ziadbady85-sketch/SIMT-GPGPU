module memory_controller #(
    parameter NUM_CACHES        = 4,
    parameter CACHE_INDEX_WIDTH = 2,   // log2(NUM_CACHES)
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32,
    parameter LINE_WORDS        = 8,
    parameter WORD_CNT_WIDTH    = 3    // log2(LINE_WORDS)
) (
    input wire clk,
    input wire rst,

    
    input  wire [NUM_CACHES-1:0]              l1_req_valid,
    input  wire [(NUM_CACHES*ADDR_WIDTH)-1:0] l1_req_address,
    output reg  [NUM_CACHES-1:0]              l1_resp_valid,
    output reg  [(NUM_CACHES*DATA_WIDTH)-1:0] l1_resp_data,

    input  wire [NUM_CACHES-1:0]              l1_wr_valid,
    input  wire [(NUM_CACHES*ADDR_WIDTH)-1:0] l1_wr_address,
    input  wire [(NUM_CACHES*DATA_WIDTH)-1:0] l1_wr_data,
    output reg  [NUM_CACHES-1:0]              l1_wr_ready,

    output reg                   mem_req_valid,
    output reg  [ADDR_WIDTH-1:0] mem_req_address,
    input  wire                  mem_resp_valid,
    input  wire [DATA_WIDTH-1:0] mem_resp_data,

    output reg                   mem_wr_valid,
    output reg  [ADDR_WIDTH-1:0] mem_wr_address,
    output reg  [DATA_WIDTH-1:0] mem_wr_data,
    input  wire                  mem_wr_ready
);

    localparam IDLE         = 3'd0,
               READ_FORWARD = 3'd1,
               READ_BURST   = 3'd2,
               WRITE_BURST  = 3'd3;

    reg [2:0] state;

    reg [CACHE_INDEX_WIDTH-1:0] granted_cache;   // which L1 cache owns the in-flight transaction
    reg [ADDR_WIDTH-1:0]        latched_req_address;

    wire [NUM_CACHES-1:0] cache_pending = l1_req_valid | l1_wr_valid;

    reg                          arb_found;
    reg [CACHE_INDEX_WIDTH-1:0]  arb_cache;
    reg [CACHE_INDEX_WIDTH-1:0]  last_served;
    integer k;
    reg [CACHE_INDEX_WIDTH-1:0]  cand;

    always @(*) begin
        arb_found = 1'b0;
        arb_cache = {CACHE_INDEX_WIDTH{1'b0}};
        for (k = 1; k <= NUM_CACHES; k = k + 1) begin
            cand = (last_served + k) % NUM_CACHES;
            if (!arb_found && cache_pending[cand]) begin
                arb_found = 1'b1;
                arb_cache = cand;
            end
        end
    end

    reg [WORD_CNT_WIDTH-1:0] word_count;

    always @(posedge clk) begin
        if (rst) begin
            state         <= IDLE;
            last_served   <= {CACHE_INDEX_WIDTH{1'b0}};
            mem_req_valid <= 1'b0;
            mem_wr_valid  <= 1'b0;
            l1_resp_valid <= {NUM_CACHES{1'b0}};
            l1_wr_ready   <= {NUM_CACHES{1'b0}};
        end else begin
            
            l1_resp_valid <= {NUM_CACHES{1'b0}};
            l1_wr_ready   <= {NUM_CACHES{1'b0}};

            case (state)

                
                IDLE: begin
                    if (arb_found) begin
                        granted_cache <= arb_cache;
                        last_served   <= arb_cache;
                        if (l1_req_valid[arb_cache]) begin
                            // read-fill request: the requesting cache only
                            // pulses l1_req_valid for one cycle, so latch
                            // its address now before it disappears
                            latched_req_address <= l1_req_address[arb_cache*ADDR_WIDTH +: ADDR_WIDTH];
                            state                <= READ_FORWARD;
                        end else begin
                            // write-back: the cache HOLDS l1_wr_valid/
                            // address/data steady until it sees
                            // l1_wr_ready, so nothing needs latching here
                            word_count <= {WORD_CNT_WIDTH{1'b0}};
                            state      <= WRITE_BURST;
                        end
                    end
                end

                READ_FORWARD: begin
                    mem_req_address <= latched_req_address;
                    mem_req_valid   <= 1'b1;
                    word_count      <= {WORD_CNT_WIDTH{1'b0}};
                    state           <= READ_BURST;
                end

                READ_BURST: begin
                    mem_req_valid <= 1'b0; // one-cycle request pulse was enough
                    if (mem_resp_valid) begin
                        l1_resp_valid[granted_cache] <= 1'b1;
                        l1_resp_data[granted_cache*DATA_WIDTH +: DATA_WIDTH] <= mem_resp_data;
                        if (word_count == LINE_WORDS - 1)
                            state <= IDLE;
                        else
                            word_count <= word_count + 1'b1;
                    end
                end

                
                WRITE_BURST: begin
                    mem_wr_valid   <= l1_wr_valid[granted_cache];
                    mem_wr_address <= l1_wr_address[granted_cache*ADDR_WIDTH +: ADDR_WIDTH];
                    mem_wr_data    <= l1_wr_data[granted_cache*DATA_WIDTH +: DATA_WIDTH];
                    if (mem_wr_ready) begin
                        l1_wr_ready[granted_cache] <= 1'b1;
                        if (word_count == LINE_WORDS - 1) begin
                            mem_wr_valid <= 1'b0;
                            state        <= IDLE;
                        end else begin
                            word_count <= word_count + 1'b1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
