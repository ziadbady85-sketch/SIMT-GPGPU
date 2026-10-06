module GPU_ALU #(
    parameter DATA_WIDTH = 32
)(
	input clk , rst , start , ALU_CMP , ALU_ARTH ,
    input  signed [DATA_WIDTH-1:0] A,
    input  signed [DATA_WIDTH-1:0] B,
    input [1:0] ALU_OP,
    output reg signed  [DATA_WIDTH-1:0] RESULT,
    output reg [2:0] NZP ,
    output DONE
);

    localparam ALU_ADD = 2'b00;
    localparam ALU_SUB = 2'b01;
    localparam ALU_MUL = 2'b10;
    localparam ALU_DIV = 2'b11;

    localparam ALU_XOR  = 2'b00;
    localparam ALU_XNOR = 2'b01;
    localparam ALU_NAND = 2'b10;
    localparam ALU_NOR  = 2'b11;

    localparam IDLE = 0 ;
    localparam WORK = 1 ;

    reg state ;

    always @(posedge clk or posedge rst) begin
    	if (rst) begin
    		RESULT   <= {DATA_WIDTH{1'b0}};
     	    state    <= IDLE ;
            NZP      <= 0 ;
    		
    	end
    	else if (start) begin
    		state <= WORK ;

            if (ALU_CMP) begin
                NZP <= {(A - B < 0), (A - B == 0), (A - B > 0)} ;
            end

     	    else begin
                NZP <= 0 ;
                if (ALU_ARTH) begin
                    
    		    case (ALU_OP)
	       
        	          ALU_ADD: begin
        	              RESULT <= A + B;
        	          end
	       
        	          ALU_SUB: begin
        	              RESULT <= A - B;
        	          end
	       
        	          ALU_MUL: begin
        	              RESULT <= A * B;
        	          end
	       
        	          ALU_DIV: begin
        	              if (B != 0)
        	                  RESULT <= A / B;
        	              else
        	                  RESULT <= {DATA_WIDTH{1'b0}};
        
        	          end
        	          
	       
        	          default: begin
        	              RESULT <= {DATA_WIDTH{1'b0}};
        	          end
	   
        	      endcase
                end
                else begin
                    case (ALU_OP)
           
                      ALU_XOR: begin
                          RESULT <= A ^ B;
                      end
           
                      ALU_XNOR: begin
                          RESULT <= A ~^ B;
                      end
           
                      ALU_NAND: begin
                          RESULT <= ~(A & B);
                      end
           
                      ALU_NOR: begin
                          
                          RESULT <= ~(A | B);
                          
                      end
                      
           
                      default: begin
                          RESULT <= {DATA_WIDTH{1'b0}};
                      end
       
                  endcase
                end
            end
        end
        else begin
        	state <= IDLE ;
        end
	

    end
  

assign DONE = (state==WORK)? 1'b1 : 1'b0 ;
endmodule
