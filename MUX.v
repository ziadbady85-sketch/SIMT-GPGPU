module MUX #(parameter DATA_WIDTH = 32)(
	input signed [DATA_WIDTH-1:0] ALU_RESULT , LSU_RESULT ,
	input signed [7:0] IMMEDIATE ,
	input [1:0] sel ,
	output signed [DATA_WIDTH-1:0] C );

assign C = (sel==0)? ALU_RESULT :
           (sel==1)? LSU_RESULT : 
           (sel==2)? {{DATA_WIDTH-8{1'b0}} ,IMMEDIATE}  : 0 ;

endmodule