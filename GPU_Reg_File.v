module GPU_Reg_File #(parameter DATA_WIDTH = 32 , DEPTH = 16 , BLOCK_DIM=8 )(
	input clk , rst , wen ,
	input [$clog2(DEPTH)-1:0] A_address , B_address , C_address ,
	input [2:0] BLOCK_ID ,
	input [5:0] THREAD_ID ,
	input signed  [DATA_WIDTH-1:0] C ,
	output signed [DATA_WIDTH-1:0] A , B 
	) ;


reg signed [DATA_WIDTH-1:0] register [0:DEPTH-1] ;

integer i ;
always @(posedge clk or posedge rst) begin

	register[DEPTH-3] <= {{DATA_WIDTH-6{1'b0}},THREAD_ID} ;
	register[DEPTH-2] <= {{DATA_WIDTH-3{1'b0}},BLOCK_ID}  ;
	register[DEPTH-1] <= BLOCK_DIM ;

	if (rst) begin
		for (i=0 ; i < DEPTH-3 ; i= i + 1) 
			register[i] <= 0 ;
		
	end
	else begin
		if (wen && C_address < DEPTH-3) begin
			register[C_address] <= C ;
		end
	end
end

assign A = register[A_address] ;
assign B = register[B_address] ;

endmodule
