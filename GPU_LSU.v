module GPU_LSU #(parameter ADDR_WIDTH = 32 , DATA_WIDTH = 32)(
	input clk , rst , start ,
	input reg_wen,           
    input mem_ren,           
    input mem_wen,
    input mem_done ,
    input [ADDR_WIDTH-1:0] reg_addr ,
    input [DATA_WIDTH-1:0] REG_IN , MEM_IN ,
    output reg [ADDR_WIDTH-1:0] mem_addr ,
    output reg [DATA_WIDTH-1:0] LSU_RESULT , MEM_OUT ,
    output reg MEM_REN , MEM_WEN , Done) ;

localparam IDLE = 3'b000 ,
		   READ = 3'b001 ,
		   WRITE= 3'b010 ,
		   WAIT = 3'b011 ,
		   DONE = 3'b100 ;

reg [2:0] state , operation ;


always @(posedge clk or posedge rst) begin
	if (rst) begin
		LSU_RESULT <= 0 ;
		MEM_OUT <= 0 ;
		MEM_REN <= 0 ;
		MEM_WEN <= 0 ;
		Done    <= 0 ;
		mem_addr <= 0 ;
		state   <= IDLE ;
		operation <= IDLE ;
	end
	else  begin
		
		Done    <= 0 ;
		case (state)
			IDLE : begin
				MEM_REN <= 0 ;
				MEM_WEN <= 0 ;
				MEM_OUT <= 0 ;
				mem_addr <= 0 ;
				if (start && reg_wen && mem_ren) begin
					state <= READ ;
					operation <= READ ;
				end
				else begin
					if (start && mem_wen) begin
					state <= WRITE ;
					operation <= WRITE ;
					end
				end
			end
			READ : begin
				MEM_REN <= 1 ;
				mem_addr <= reg_addr ;
				state <= WAIT ;
			end
			WRITE : begin
				MEM_WEN <= 1 ;
				mem_addr <= reg_addr ;
				MEM_OUT <= REG_IN ;
				state <= WAIT ;
			end
			WAIT : begin
				if (mem_done) begin
					MEM_REN <= 0 ;
					MEM_WEN <= 0 ;
					if (operation==READ) begin
						LSU_RESULT <= MEM_IN ;
					end
					state <= DONE ;
					
				end
			end
			DONE : begin
				Done <= 1 ;
				state <= IDLE ;
			end
		endcase
	end
end

endmodule