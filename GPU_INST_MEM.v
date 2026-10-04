module GPU_INST_MEM #(parameter WIDTH = 16 , DEPTH = 256 )(
	input clk , rst , ren ,
	input [$clog2(DEPTH)-1:0] r_addr ,
	output reg  [WIDTH-1:0] INST_OUT , 
	output reg valid) ;

reg [WIDTH-1:0] INST_MEM [0:DEPTH-1] ;

integer i ;
always @(posedge clk or posedge rst) begin
	if (rst) begin
		for (i=0 ; i < DEPTH ; i = i + 1 ) begin
			INST_MEM[i] <= 0 ;
		end
	end
end

always @(*) begin
	if (ren) begin
		INST_OUT = INST_MEM[r_addr] ; 
		valid = 1 ;
	end
	else begin
		valid = 0 ;
	end
end
endmodule
