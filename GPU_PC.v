module GPU_PC #(parameter WIDTH = 8)(
	input clk , rst , en , branch_taken  ,
	input [WIDTH-1:0] branch_target ,
	output reg [WIDTH-1:0] PC ) ;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		PC <= 0 ;	
	end
	else begin
		if (en) begin
			if (branch_taken) begin
				PC <= branch_target ;
			end
			else begin
				PC <= PC + 1 ;
			end
		end
	end
	
end

endmodule
