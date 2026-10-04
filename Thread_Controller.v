module Thread_Controller #(
    parameter no_thread = 64,
    parameter no_blocks = 8
)(
    input clk,
    input rst,
    input start,
    input [$clog2(no_thread)-1:0] thread_count,
    output [no_thread-1:0] thread_en,
    output [(no_blocks*$clog2(no_blocks))-1:0] block_id ,
    output [(no_thread*$clog2(no_thread))-1:0] thread_id
);

localparam THREAD_ID_WIDTH = $clog2(no_thread);
localparam THREAD_COUNT_WIDTH = $clog2(no_thread);
localparam BLOCK_ID_WIDTH = $clog2(no_blocks);

reg [THREAD_COUNT_WIDTH-1:0] thread_count_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        thread_count_reg <= 0;
    end
    else if (start) begin
        thread_count_reg <= thread_count;
    end
end

assign thread_en = (thread_count_reg == 0) ?
                   {no_thread{1'b0}} :
                   ({no_thread{1'b1}} >> (no_thread - thread_count_reg));



generate
    genvar i , b ;

    for (i = 0; i < no_thread; i = i + 1) begin : THREAD_ID_GEN
        assign thread_id[i*THREAD_ID_WIDTH +: THREAD_ID_WIDTH] = i;
    end
    for (b = 0; b < no_blocks; b = b + 1) begin : BLOCK_ID_GEN
        assign block_id[b*BLOCK_ID_WIDTH +: BLOCK_ID_WIDTH] = b;
    end

endgenerate


endmodule