module l1_cache #(
    parameter NUM_DEVICES       = 16,
    parameter DEV_INDEX_WIDTH   = 4,   // log2(NUM_DEVICES)
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32,
    parameter LINE_WORDS        = 8,
    parameter NUM_LINES         = 128,
    parameter BYTE_OFFSET_WIDTH = 2,   // log2(DATA_WIDTH/8)
    parameter WORD_OFFSET_WIDTH = 3,   // log2(LINE_WORDS)
    parameter INDEX_WIDTH       = 7,   // log2(NUM_LINES)
    parameter TAG_WIDTH         = ADDR_WIDTH - BYTE_OFFSET_WIDTH - WORD_OFFSET_WIDTH - INDEX_WIDTH,
    parameter LINE_ALIGN_WIDTH  = BYTE_OFFSET_WIDTH + WORD_OFFSET_WIDTH
) (
    input wire clk,
    input wire rst,

    input  wire [(NUM_DEVICES*ADDR_WIDTH)-1:0] mem_addr,
    input  wire [NUM_DEVICES-1:0]              MEM_REN,
    input  wire [NUM_DEVICES-1:0]              MEM_WEN,
    input  wire [(NUM_DEVICES*DATA_WIDTH)-1:0] MEM_OUT,
    output reg  [NUM_DEVICES-1:0]              mem_done,
    output reg  [(NUM_DEVICES*DATA_WIDTH)-1:0] MEM_IN,

    output reg                   mem_req_valid,
    output reg  [ADDR_WIDTH-1:0] mem_req_address,   
    input  wire                  mem_resp_valid,     
    input  wire [DATA_WIDTH-1:0] mem_resp_data,

    output reg                   mem_wr_valid,
    output reg  [ADDR_WIDTH-1:0] mem_wr_address,
    output reg  [DATA_WIDTH-1:0] mem_wr_data,
    input  wire                  mem_wr_ready        
);

    reg                  valid      [0:NUM_LINES-1];
    reg                  dirty      [0:NUM_LINES-1];
    reg [TAG_WIDTH-1:0]  tag_array  [0:NUM_LINES-1];
    reg [DATA_WIDTH-1:0] data_array [0:NUM_LINES-1][0:LINE_WORDS-1];

    // ---------------- FSM ----------------
    localparam IDLE             = 3'd0,
               CHECK             = 3'd1,
               RESPOND           = 3'd2,
               WRITEBACK_REQUEST = 3'd3,
               WRITEBACK         = 3'd4,
               MEM_REQUEST       = 3'd5,
               MEM_WAIT          = 3'd6,
               FILL              = 3'd7;

    reg [2:0] state;

    reg [DEV_INDEX_WIDTH-1:0] granted_dev;     // POSITION of the granted device (0..15)
    reg [ADDR_WIDTH-1:0]      granted_address;
    reg                       granted_is_write;
    reg [DATA_WIDTH-1:0]      granted_write_data;

    wire [TAG_WIDTH-1:0]         req_tag         = granted_address[ADDR_WIDTH-1 -: TAG_WIDTH];
    wire [INDEX_WIDTH-1:0]       req_index       = granted_address[BYTE_OFFSET_WIDTH+WORD_OFFSET_WIDTH +: INDEX_WIDTH];
    wire [WORD_OFFSET_WIDTH-1:0] req_word_offset = granted_address[BYTE_OFFSET_WIDTH +: WORD_OFFSET_WIDTH];

    wire hit           = valid[req_index] && (tag_array[req_index] == req_tag);
    wire victim_dirty  = valid[req_index] && dirty[req_index];
    wire [TAG_WIDTH-1:0] victim_tag = tag_array[req_index];

    reg                       arb_found;
    reg [DEV_INDEX_WIDTH-1:0] arb_dev;
    reg [DEV_INDEX_WIDTH-1:0] last_served;
    integer k;
    reg [DEV_INDEX_WIDTH-1:0] cand;

    always @(*) begin
        arb_found = 1'b0;
        arb_dev   = {DEV_INDEX_WIDTH{1'b0}};
        for (k = 1; k <= NUM_DEVICES; k = k + 1) begin
            cand = (last_served + k) % NUM_DEVICES;
            if (!arb_found && (MEM_REN[cand] || MEM_WEN[cand])) begin
                arb_found = 1'b1;
                arb_dev   = cand;
            end
        end
    end

    reg [WORD_OFFSET_WIDTH-1:0] fill_count;
    reg [WORD_OFFSET_WIDTH-1:0] wb_count;

    integer d;

    always @(posedge clk) begin
        if (rst) begin
            state           <= IDLE;
            last_served     <= {DEV_INDEX_WIDTH{1'b0}};
            mem_req_valid   <= 1'b0;
            mem_wr_valid    <= 1'b0;
            fill_count      <= {WORD_OFFSET_WIDTH{1'b0}};
            wb_count        <= {WORD_OFFSET_WIDTH{1'b0}};
            mem_done        <= {NUM_DEVICES{1'b0}};
            MEM_IN          <= {(NUM_DEVICES*DATA_WIDTH){1'b0}};
            for (d = 0; d < NUM_LINES; d = d + 1) begin
                valid[d] <= 1'b0;
                dirty[d] <= 1'b0;
            end
        end else begin
            mem_done <= {NUM_DEVICES{1'b0}};

            case (state)

                IDLE: begin
                    if (arb_found) begin
                        granted_dev         <= arb_dev;
                        granted_address     <= mem_addr[arb_dev*ADDR_WIDTH +: ADDR_WIDTH];
                        granted_is_write    <= MEM_WEN[arb_dev];
                        granted_write_data  <= MEM_OUT[arb_dev*DATA_WIDTH +: DATA_WIDTH];
                        last_served         <= arb_dev;
                        state               <= CHECK;
                    end
                end

                CHECK: begin
                    if (hit) begin
                        state <= RESPOND;
                    end else if (victim_dirty) begin
                        state <= WRITEBACK_REQUEST;
                    end else begin
                        fill_count <= {WORD_OFFSET_WIDTH{1'b0}};
                        state      <= MEM_REQUEST;
                    end
                end

                RESPOND: begin
                    mem_done[granted_dev] <= 1'b1;
                    if (granted_is_write) begin
                        data_array[req_index][req_word_offset] <= granted_write_data;
                        dirty[req_index] <= 1'b1;
                    end else begin
                        MEM_IN[granted_dev*DATA_WIDTH +: DATA_WIDTH] <= data_array[req_index][req_word_offset];
                    end
                    state <= IDLE;
                end

                WRITEBACK_REQUEST: begin
                    wb_count <= {WORD_OFFSET_WIDTH{1'b0}};
                    state    <= WRITEBACK;
                end

                WRITEBACK: begin
                    mem_wr_valid   <= 1'b1;
                    mem_wr_address <= {victim_tag, req_index, wb_count, {BYTE_OFFSET_WIDTH{1'b0}}};
                    mem_wr_data    <= data_array[req_index][wb_count];
                    if (mem_wr_ready) begin
                        if (wb_count == LINE_WORDS - 1) begin
                            mem_wr_valid <= 1'b0;
                            fill_count   <= {WORD_OFFSET_WIDTH{1'b0}};
                            state        <= MEM_REQUEST;
                        end else begin
                            wb_count <= wb_count + 1'b1;
                        end
                    end
                end

                MEM_REQUEST: begin
                    mem_req_address <= {granted_address[ADDR_WIDTH-1:LINE_ALIGN_WIDTH],
                                         {LINE_ALIGN_WIDTH{1'b0}}};
                    mem_req_valid   <= 1'b1;
                    state           <= MEM_WAIT;
                end

                MEM_WAIT: begin
                    mem_req_valid <= 1'b0;
                    if (mem_resp_valid) begin
                        data_array[req_index][fill_count] <= mem_resp_data;
                        if (fill_count == LINE_WORDS - 1)
                            state <= FILL;
                        else
                            fill_count <= fill_count + 1'b1;
                    end
                end

                FILL: begin
                    valid[req_index]     <= 1'b1;
                    dirty[req_index]     <= 1'b0;
                    tag_array[req_index] <= req_tag;
                    state                <= RESPOND;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
