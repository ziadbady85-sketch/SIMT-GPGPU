module GPU_CORE #(
	parameter DATA_WIDTH = 32 , DEPTH = 16 , ADDR_WIDTH = 32 ,
	parameter BLOCK_DIM = 8 , block_in_core = 2 , BLOCK_ID_WIDTH = 3 , no_thread = 64 , no_blocks = 8 
	
)(
	input clk , rst ,
	input [block_in_core*BLOCK_DIM-1:0] reg_wen ,
	input [block_in_core*BLOCK_DIM-1:0] thread_en ,
	input [$clog2(DEPTH)-1:0] A_address , B_address , C_address ,
	input [(block_in_core*BLOCK_DIM*6)-1:0] THREAD_ID ,
	input [(block_in_core*BLOCK_ID_WIDTH)-1:0] BLOCK_ID ,

	input [block_in_core*BLOCK_DIM-1:0] alu_start ,
	input alu_cmp ,
	input [1:0] ALU_OP ,
	output ALU_DONE ,
	output [2:0] ALU_NZP_OUT ,

	input [1:0] reg_input_mux ,
	input [7:0] IMMEDIATE ,
	input [block_in_core*BLOCK_DIM-1:0] lsu_start ,
	input mem_ren , mem_wen ,
	input [block_in_core*BLOCK_DIM-1:0] mem_done ,
	input [(block_in_core*BLOCK_DIM*DATA_WIDTH)-1:0] MEM_IN ,
	output [block_in_core*BLOCK_DIM*ADDR_WIDTH-1:0] mem_addr ,
	output [(block_in_core*BLOCK_DIM*DATA_WIDTH)-1:0] MEM_OUT ,
	output [block_in_core*BLOCK_DIM-1:0] MEM_REN , MEM_WEN ,
	output LSU_DONE
) ;

wire [BLOCK_DIM-1:0] ALU_DONE_b0, ALU_DONE_b1, LSU_DONE_b0, LSU_DONE_b1;
wire [2:0] ALU_NZP_b1; // block_1's NZP: computed but not usable further up (see header note)

GPU_Block block_0 (
	.clk(clk), .rst(rst),
	.reg_wen(reg_wen[BLOCK_DIM-1:0]),
	.A_address(A_address), .B_address(B_address), .C_address(C_address),
	.THREAD_ID(THREAD_ID[BLOCK_DIM*6-1:0]),.BLOCK_ID(BLOCK_ID[BLOCK_ID_WIDTH-1:0]),
	.alu_start(alu_start[BLOCK_DIM-1:0]), .alu_cmp(alu_cmp),
	.ALU_OP(ALU_OP), .ALU_DONE(ALU_DONE_b0[BLOCK_DIM-1:0]), .ALU_NZP_OUT(ALU_NZP_OUT),
	.reg_input_mux(reg_input_mux), .IMMEDIATE(IMMEDIATE),
	.lsu_start(lsu_start[BLOCK_DIM-1:0]),
	.mem_ren(mem_ren), .mem_wen(mem_wen), .mem_done(mem_done[BLOCK_DIM-1:0]),
	.MEM_IN(MEM_IN[(BLOCK_DIM*DATA_WIDTH)-1:0]),
	.mem_addr(mem_addr[BLOCK_DIM*ADDR_WIDTH-1:0]),
	.MEM_OUT(MEM_OUT[(BLOCK_DIM*DATA_WIDTH)-1:0]),
	.MEM_REN(MEM_REN[BLOCK_DIM-1:0]), .MEM_WEN(MEM_WEN[BLOCK_DIM-1:0]),
	.LSU_DONE(LSU_DONE_b0[BLOCK_DIM-1:0])
) ;

GPU_Block block_1 (
	.clk(clk), .rst(rst),
	.reg_wen(reg_wen[block_in_core*BLOCK_DIM-1:BLOCK_DIM]),
	.A_address(A_address), .B_address(B_address), .C_address(C_address),
	.THREAD_ID(THREAD_ID[block_in_core*BLOCK_DIM*6-1:BLOCK_DIM*6]),.BLOCK_ID(BLOCK_ID[block_in_core*BLOCK_ID_WIDTH-1:BLOCK_ID_WIDTH]),
	.alu_start(alu_start[block_in_core*BLOCK_DIM-1:BLOCK_DIM]), .alu_cmp(alu_cmp),
	.ALU_OP(ALU_OP), .ALU_DONE(ALU_DONE_b1[BLOCK_DIM-1:0]), .ALU_NZP_OUT(ALU_NZP_b1),
	.reg_input_mux(reg_input_mux), .IMMEDIATE(IMMEDIATE),
	.lsu_start(lsu_start[block_in_core*BLOCK_DIM-1:BLOCK_DIM]),
	.mem_ren(mem_ren), .mem_wen(mem_wen),
	.mem_done(mem_done[block_in_core*BLOCK_DIM-1:BLOCK_DIM]),
	.MEM_IN(MEM_IN[(block_in_core*BLOCK_DIM*DATA_WIDTH)-1:BLOCK_DIM*DATA_WIDTH]),
	.mem_addr(mem_addr[block_in_core*BLOCK_DIM*ADDR_WIDTH-1:BLOCK_DIM*ADDR_WIDTH]),
	.MEM_OUT(MEM_OUT[(block_in_core*BLOCK_DIM*DATA_WIDTH)-1:BLOCK_DIM*DATA_WIDTH]),
	.MEM_REN(MEM_REN[block_in_core*BLOCK_DIM-1:BLOCK_DIM]),
	.MEM_WEN(MEM_WEN[block_in_core*BLOCK_DIM-1:BLOCK_DIM]),
	.LSU_DONE(LSU_DONE_b1[BLOCK_DIM-1:0])
) ;

assign ALU_DONE = (({ALU_DONE_b1,ALU_DONE_b0} & thread_en) == thread_en)? 1 : 0 ;
assign LSU_DONE = (({LSU_DONE_b1,LSU_DONE_b0} & thread_en) == thread_en)? 1 : 0 ;

endmodule
