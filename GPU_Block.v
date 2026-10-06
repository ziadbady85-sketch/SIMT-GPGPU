module GPU_Block 
#(parameter DATA_WIDTH = 32 , DEPTH = 16 , ADDR_WIDTH = 32 , BLOCK_DIM = 8 , no_thread = 64 ,  no_blocks = 8 )(
	input clk , rst , 
	input [$clog2(DEPTH)-1:0] A_address , B_address , C_address ,
	input [(BLOCK_DIM*6)-1:0] THREAD_ID ,
	input [2:0] BLOCK_ID ,

	

	input [BLOCK_DIM-1:0] alu_start ,
	input alu_cmp , alu_arth ,
	input [1:0] ALU_OP,
	output [2:0] ALU_NZP_OUT ,

	input [1:0] reg_input_mux ,
	input [7:0] IMMEDIATE ,
	input [BLOCK_DIM-1:0] lsu_start ,
	input [BLOCK_DIM-1:0] reg_wen,           
    input mem_ren,           
    input mem_wen,
    input [BLOCK_DIM-1:0] mem_done ,
    input [(BLOCK_DIM*DATA_WIDTH)-1:0] MEM_IN ,
    output [(BLOCK_DIM*ADDR_WIDTH)-1:0] mem_addr ,
    output [(BLOCK_DIM*DATA_WIDTH)-1:0] MEM_OUT ,
    output [BLOCK_DIM-1:0] MEM_REN , MEM_WEN ,
    output [BLOCK_DIM-1:0] LSU_DONE , ALU_DONE

	) ;

wire signed  [DATA_WIDTH-1:0] MUX_RESULT ;
wire [(3*BLOCK_DIM)-1:0] ALU_NZP ;

generate
	genvar i;
	for (i = 0; i < BLOCK_DIM; i = i + 1)
	begin:thread_loop
		GPU_Thread thread (.clk(clk),.rst(rst),.reg_wen(reg_wen[i]),.A_address(A_address),.B_address(B_address),.C_address(C_address),
	             		   				   .THREAD_ID(THREAD_ID[i*6+:6]),.alu_start(alu_start[i]),.alu_cmp(alu_cmp),.alu_arth(alu_arth),.ALU_OP(ALU_OP),
	             		   				   .ALU_DONE(ALU_DONE[i]),.ALU_NZP(ALU_NZP[i*3+:3]),.reg_input_mux(reg_input_mux),
	             		   				   .IMMEDIATE(IMMEDIATE),.lsu_start(lsu_start[i]),.mem_ren(mem_ren),.BLOCK_ID(BLOCK_ID),
	             		   				   .mem_wen(mem_wen),.mem_done(mem_done[i]),.MEM_IN(MEM_IN[i*DATA_WIDTH+:DATA_WIDTH]),
	             		   				   .mem_addr(mem_addr[i*ADDR_WIDTH+:ADDR_WIDTH]),.MEM_OUT(MEM_OUT[i*DATA_WIDTH+:DATA_WIDTH]),
	             		   				   .MEM_REN(MEM_REN[i]),.MEM_WEN(MEM_WEN[i]),.LSU_DONE(LSU_DONE[i])) ;
	end
endgenerate

assign ALU_NZP_OUT = ALU_NZP[2:0] ;

endmodule
