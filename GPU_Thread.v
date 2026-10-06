module GPU_Thread #(parameter DATA_WIDTH = 32 , DEPTH = 16 , ADDR_WIDTH = 32 , BLOCK_DIM = 8 , no_thread = 64 , no_blocks = 8)(
	input clk , rst , 
	input [$clog2(DEPTH)-1:0] A_address , B_address , C_address ,
	input [5:0] THREAD_ID ,
	input [2:0] BLOCK_ID ,

	input alu_start , alu_cmp , alu_arth ,
	input [1:0] ALU_OP,
	output ALU_DONE ,
	output [2:0] ALU_NZP ,

	input [1:0] reg_input_mux ,
	input [7:0] IMMEDIATE ,
	input lsu_start ,
	input reg_wen,           
    input mem_ren,           
    input mem_wen,
    input mem_done ,
    input [DATA_WIDTH-1:0] MEM_IN ,
    output [ADDR_WIDTH-1:0] mem_addr ,
    output [DATA_WIDTH-1:0] MEM_OUT ,
    output MEM_REN , MEM_WEN , LSU_DONE 



	) ;

wire signed  [DATA_WIDTH-1:0] C ;
wire signed [DATA_WIDTH-1:0] A , B ;
wire signed  [DATA_WIDTH-1:0] ALU_RESULT , LSU_RESULT  , MUX_RESULT ;

MUX mux(.ALU_RESULT(ALU_RESULT),.LSU_RESULT(LSU_RESULT),.IMMEDIATE(IMMEDIATE),.sel(reg_input_mux),.C(MUX_RESULT)) ;

GPU_Reg_File RF (.clk(clk),.rst(rst),.wen(reg_wen),.A_address(A_address),.B_address(B_address),.C_address(C_address),
	             .THREAD_ID(THREAD_ID),.C(MUX_RESULT),.A(A),.B(B),.BLOCK_ID(BLOCK_ID)) ;

GPU_ALU alu (.clk(clk),.rst(rst),.start(alu_start),.ALU_CMP(alu_cmp),.ALU_ARTH(alu_arth),.A(A),.B(B),.ALU_OP(ALU_OP),.RESULT(ALU_RESULT),
	         .NZP(ALU_NZP),.DONE(ALU_DONE)) ;

GPU_LSU lsu (.clk(clk),.rst(rst),.start(lsu_start),.reg_wen(reg_wen),.mem_ren(mem_ren),.mem_wen(mem_wen),.mem_done(mem_done),
	         .reg_addr(A),.REG_IN(B),.MEM_IN(MEM_IN),.mem_addr(mem_addr),.LSU_RESULT(LSU_RESULT),.MEM_OUT(MEM_OUT),.MEM_REN(MEM_REN),
	         .MEM_WEN(MEM_WEN),.Done(LSU_DONE)) ;

endmodule
