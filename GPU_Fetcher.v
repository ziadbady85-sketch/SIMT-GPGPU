module GPU_Fetcher #(parameter PC_WIDTH = 8 , INST_WIDTH = 16)(
	input clk , rst , en ,
	input [PC_WIDTH-1:0] PC ,
	input [INST_WIDTH-1:0] INST_IN ,
	output reg [INST_WIDTH-1:0] INST_OUT ,
	output reg ren ,
	output reg [PC_WIDTH-1:0] r_addr ,
	output reg INST_VALID ) ;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		ren <= 0 ;
		r_addr <= 0 ;
		INST_VALID <= 0 ; 
		INST_OUT <= 0 ;
		
	end
	else if (en) begin
		ren <= 1 ;
		r_addr <= PC ;
		INST_OUT <= INST_IN ;
		INST_VALID <= 1 ;
	end
	else begin
		ren <= 0 ;
		INST_VALID <= 0 ;
	end
end

endmodule
