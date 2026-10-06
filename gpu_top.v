module gpu_top #(
    parameter NUM_CORES   = 4,
    parameter CORE_THREADS = 16,   // block_in_core * BLOCK_DIM
    parameter TOTAL_THREADS = 64,  // NUM_CORES * CORE_THREADS
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter TOTAL_BLOCKS = 8,
    parameter BLOCK_ID_WIDTH_CORE = 6
) (
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire [$clog2(TOTAL_THREADS)-1:0] thread_count,
    output wire done
);

    // thread enable / identity (whole-chip scale) 
    wire [TOTAL_THREADS-1:0]       thread_en;
    wire [(TOTAL_THREADS*6)-1:0]   thread_id;
    wire [(TOTAL_BLOCKS*3)-1:0]    block_id ;

    Thread_Controller #(.no_thread(TOTAL_THREADS), .no_blocks(8)) u_thread_ctrl (
        .clk(clk), .rst(rst), .start(start),
        .thread_count(thread_count),
        .thread_en(thread_en),
        .block_id(block_id),
        .thread_id(thread_id)
    );

    // shared PC / fetch / decode / schedule 
    wire [7:0]  pc;
    wire        pc_en, fetch_en, branch_taken;
    wire [15:0] inst_out;
    wire        inst_valid;
    wire [15:0] inst_mem_rdata;
    wire        inst_mem_valid;
    wire        fetcher_ren;
    wire [7:0]  fetcher_raddr;

    wire [3:0] a_addr, b_addr, c_addr;
    wire [2:0] decoded_nzp;
    wire [7:0] immediate, branch_target;
    wire       dec_reg_wen, dec_mem_ren, dec_mem_wen, dec_nzp_wen;
    wire [1:0] dec_reg_input_mux, dec_alu_op;
    wire       dec_alu_cmp, dec_alu_arth , dec_branch_en, dec_ret;

    wire [2:0] core_state;
    wire       sched_done;
    wire [TOTAL_THREADS-1:0] reg_wen_out, alu_cmp_out_unused, alu_start_out, lsu_start_out;

    wire alu_done_global, lsu_done_global;
    wire [2:0] alu_nzp_representative; // core0/block0 only — see header note

    GPU_PC #(.WIDTH(8)) u_pc (
        .clk(clk), .rst(rst), .en(pc_en), .branch_taken(branch_taken),
        .branch_target(branch_target), .PC(pc)
    );

    GPU_Fetcher #(.PC_WIDTH(8), .INST_WIDTH(16)) u_fetcher (
        .clk(clk), .rst(rst), .en(fetch_en), .PC(pc),
        .INST_IN(inst_mem_rdata),
        .INST_OUT(inst_out), .ren(fetcher_ren), .r_addr(fetcher_raddr),
        .INST_VALID(inst_valid)
    );

    GPU_INST_MEM #(.WIDTH(16), .DEPTH(256)) u_inst_mem (
        .clk(clk), .rst(rst), .ren(fetcher_ren), .r_addr(fetcher_raddr),
        .INST_OUT(inst_mem_rdata), .valid(inst_mem_valid)
    );

    GPU_Decoder u_decoder (
        .clk(clk), .rst(rst), .core_state(core_state), .instruction(inst_out),
        .A_address(a_addr), .B_address(b_addr), .C_address(c_addr),
        .decoded_nzp(decoded_nzp), .immediate(immediate), .branch_target(branch_target),
        .reg_wen(dec_reg_wen), .mem_ren(dec_mem_ren), .mem_wen(dec_mem_wen),
        .nzp_wen(dec_nzp_wen), .reg_input_mux(dec_reg_input_mux), .ALU_OP(dec_alu_op),
        .ALU_CMP(dec_alu_cmp), .ALU_ARTH(dec_alu_arth) , .branch_en(dec_branch_en), .Ret(dec_ret)
    );

    scheduler #(.no_thread(TOTAL_THREADS)) u_scheduler (
        .clk(clk), .rst(rst), .start(start),
        .mem_ren(dec_mem_ren), .mem_wen(dec_mem_wen), .reg_wen(dec_reg_wen),
        .ALU_CMP(dec_alu_cmp), .Ret(dec_ret), .thread_en(thread_en),
        .INST_Valid(inst_valid), .lsu_done(lsu_done_global), .alu_done(alu_done_global),
        .branch_en(dec_branch_en), .decoded_NZP(decoded_nzp), .ALU_NZP(alu_nzp_representative),
        .reg_input_mux(dec_reg_input_mux),
        .pc_en(pc_en), .fetch_en(fetch_en), .branch_taken(branch_taken),
        .reg_wen_out(reg_wen_out),
        .alu_start_out(alu_start_out), .lsu_start_out(lsu_start_out),
        .core_state(core_state), .done(sched_done)
    );

    assign done = sched_done;

    // per-core <-> per-core-L1 internal wiring 
    wire [ADDR_WIDTH*CORE_THREADS-1:0] c_mem_addr [0:NUM_CORES-1];
    wire [CORE_THREADS-1:0]            c_mem_ren  [0:NUM_CORES-1];
    wire [CORE_THREADS-1:0]            c_mem_wen  [0:NUM_CORES-1];
    wire [DATA_WIDTH*CORE_THREADS-1:0] c_mem_out  [0:NUM_CORES-1];
    wire [CORE_THREADS-1:0]            c_mem_done [0:NUM_CORES-1];
    wire [DATA_WIDTH*CORE_THREADS-1:0] c_mem_in   [0:NUM_CORES-1];

    wire [NUM_CORES-1:0] alu_done_core, lsu_done_core;
    wire [2:0] alu_nzp_core [0:NUM_CORES-1];

    // L1 cache <-> Memory Controller (flat, per NUM_CORES) -
    wire [NUM_CORES-1:0]                  l1_req_valid, l1_wr_valid, l1_resp_valid, l1_wr_ready;
    wire [NUM_CORES*ADDR_WIDTH-1:0]       l1_req_address, l1_wr_address;
    wire [NUM_CORES*DATA_WIDTH-1:0]       l1_wr_data, l1_resp_data;
    wire [TOTAL_THREADS-1:0]              lsu_done_raw;     
    reg  [TOTAL_THREADS-1:0]              lsu_done_sticky;
    
    genvar g;
    generate
        for (g = 0; g < NUM_CORES; g = g + 1) begin : CORES

            GPU_CORE #(.block_in_core(2), .BLOCK_DIM(8)) u_core (
                .clk(clk), .rst(rst),
                .reg_wen(reg_wen_out[g*CORE_THREADS +: CORE_THREADS]),
                .thread_en(thread_en[g*CORE_THREADS +: CORE_THREADS]),
                .A_address(a_addr), .B_address(b_addr), .C_address(c_addr),
                .THREAD_ID(thread_id[g*CORE_THREADS*6 +: CORE_THREADS*6]),
                .BLOCK_ID(block_id[g*BLOCK_ID_WIDTH_CORE +: BLOCK_ID_WIDTH_CORE]),
                .alu_start(alu_start_out[g*CORE_THREADS +: CORE_THREADS]),
                .alu_cmp(dec_alu_cmp),.alu_arth(dec_alu_arth),.ALU_OP(dec_alu_op),
                .ALU_DONE(alu_done_core[g]), .ALU_NZP_OUT(alu_nzp_core[g]),
                .reg_input_mux(dec_reg_input_mux), .IMMEDIATE(immediate),
                .lsu_start(lsu_start_out[g*CORE_THREADS +: CORE_THREADS]),
                .mem_ren(dec_mem_ren), .mem_wen(dec_mem_wen),
                .mem_done(c_mem_done[g]), .MEM_IN(c_mem_in[g]),
                .mem_addr(c_mem_addr[g]), .MEM_OUT(c_mem_out[g]),
                .MEM_REN(c_mem_ren[g]), .MEM_WEN(c_mem_wen[g]),
                .LSU_DONE(lsu_done_core[g])
            );

            l1_cache #(.NUM_DEVICES(CORE_THREADS), .DEV_INDEX_WIDTH(4)) u_l1 (
                .clk(clk), .rst(rst),
                .mem_addr(c_mem_addr[g]), .MEM_REN(c_mem_ren[g]), .MEM_WEN(c_mem_wen[g]),
                .MEM_OUT(c_mem_out[g]),
                .mem_done(c_mem_done[g]), .MEM_IN(c_mem_in[g]),
                .mem_req_valid(l1_req_valid[g]),
                .mem_req_address(l1_req_address[g*ADDR_WIDTH +: ADDR_WIDTH]),
                .mem_resp_valid(l1_resp_valid[g]),
                .mem_resp_data(l1_resp_data[g*DATA_WIDTH +: DATA_WIDTH]),
                .mem_wr_valid(l1_wr_valid[g]),
                .mem_wr_address(l1_wr_address[g*ADDR_WIDTH +: ADDR_WIDTH]),
                .mem_wr_data(l1_wr_data[g*DATA_WIDTH +: DATA_WIDTH]),
                .mem_wr_ready(l1_wr_ready[g])
            );

            assign lsu_done_raw[g*CORE_THREADS +: CORE_THREADS] = c_mem_done[g];

        end
    endgenerate

    assign alu_done_global = &alu_done_core; // AND across all 4 cores

    always @(posedge clk) begin
        if (rst)
            lsu_done_sticky <= {TOTAL_THREADS{1'b0}};
        else if (lsu_done_global)
            lsu_done_sticky <= {TOTAL_THREADS{1'b0}}; // clear for the next WAIT round
        else
            lsu_done_sticky <= lsu_done_sticky | lsu_done_raw;
    end

    assign lsu_done_global = ((lsu_done_sticky | lsu_done_raw) & thread_en) == thread_en;
    assign alu_nzp_representative = alu_nzp_core[0]; // core0/block0 only, see header note

    // Memory Controller + Data Memory 
    wire                   mc_mem_req_valid, mc_mem_resp_valid, mc_mem_wr_valid, mc_mem_wr_ready;
    wire [ADDR_WIDTH-1:0]  mc_mem_req_address, mc_mem_wr_address;
    wire [DATA_WIDTH-1:0]  mc_mem_resp_data, mc_mem_wr_data;

    memory_controller #(.NUM_CACHES(NUM_CORES), .CACHE_INDEX_WIDTH(2)) u_mc (
        .clk(clk), .rst(rst),
        .l1_req_valid(l1_req_valid), .l1_req_address(l1_req_address),
        .l1_resp_valid(l1_resp_valid), .l1_resp_data(l1_resp_data),
        .l1_wr_valid(l1_wr_valid), .l1_wr_address(l1_wr_address), .l1_wr_data(l1_wr_data),
        .l1_wr_ready(l1_wr_ready),
        .mem_req_valid(mc_mem_req_valid), .mem_req_address(mc_mem_req_address),
        .mem_resp_valid(mc_mem_resp_valid), .mem_resp_data(mc_mem_resp_data),
        .mem_wr_valid(mc_mem_wr_valid), .mem_wr_address(mc_mem_wr_address),
        .mem_wr_data(mc_mem_wr_data), .mem_wr_ready(mc_mem_wr_ready)
    );

    data_memory u_data_memory (
        .clk(clk), .rst(rst),
        .mem_req_valid(mc_mem_req_valid), .mem_req_address(mc_mem_req_address),
        .mem_resp_valid(mc_mem_resp_valid), .mem_resp_data(mc_mem_resp_data),
        .mem_wr_valid(mc_mem_wr_valid), .mem_wr_address(mc_mem_wr_address),
        .mem_wr_data(mc_mem_wr_data), .mem_wr_ready(mc_mem_wr_ready)
    );

endmodule
