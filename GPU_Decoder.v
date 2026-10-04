module GPU_Decoder #(parameter INST_WIDTH = 16 , OP_WIDTH = 4 , REG_COUNT = 16 ,
	                           REG_ADDR = 4 , DATA_WIDTH = 8 , PC_WIDTH = 8 ,
	                           NZP = 3 , CORE_STATE = 3 , DECODE = 2) (
    input  clk, rst ,
    input [CORE_STATE-1:0] core_state,
    input [INST_WIDTH-1:0] instruction,
    
    output reg [REG_ADDR-1:0] A_address,
    output reg [REG_ADDR-1:0] B_address,
    output reg [REG_ADDR-1:0] C_address,
    output reg [NZP-1:0] decoded_nzp,
    output reg [DATA_WIDTH-1:0] immediate, branch_target ,
    
    output reg reg_wen,           
    output reg mem_ren,           
    output reg mem_wen,        
    output reg nzp_wen,           
    output reg [1:0] reg_input_mux ,
    output reg [1:0] ALU_OP,   
    output reg ALU_CMP,         
    output reg branch_en,      

    
    output reg Ret
);
    localparam NOP = 4'b0000,
        	   BRnzp = 4'b0001,
        	   CMP = 4'b0010,
        	   ADD = 4'b0011,
        	   SUB = 4'b0100,
        	   MUL = 4'b0101,
        	   DIV = 4'b0110,
        	   LDR = 4'b0111,
        	   STR = 4'b1000,
        	   CONST = 4'b1001,
        	   RET = 4'b1111;

parameter ALU_RESULT = 2'b00 , 
          MEM_RESULT = 2'b01 ,
          IMMEDIATE  = 2'b10 ,
          RESERVED   = 2'b11 ;

    always @(posedge clk or posedge rst) begin 
        if (rst) begin 
            A_address <= 0;
            B_address <= 0;
            C_address <= 0;
            immediate <= 0;
            decoded_nzp <= 0;
            reg_wen <= 0;
            mem_ren <= 0;
            mem_wen <= 0;
            nzp_wen <= 0;
            reg_input_mux <= 0;
            ALU_OP <= 0;
            ALU_CMP <= 0;
            branch_en <= 0;
            branch_target <= 0 ;
            Ret <= 0;
        end else begin 
            if (core_state == DECODE) begin 
                C_address <= instruction[11:8];
                A_address <= instruction[7:4];
                B_address <= instruction[3:0];
                immediate <= instruction[7:0];
                decoded_nzp <= instruction[11:9];

                reg_wen <= 0;
            	mem_ren <= 0;
            	mem_wen <= 0;
            	nzp_wen <= 0;
            	reg_input_mux <= 0;
            	ALU_OP <= 0;
            	ALU_CMP <= 0;
            	branch_en <= 0;
            	branch_target <= 0 ;
            	Ret <= 0;

                case (instruction[15:12])
                    NOP: begin 
                    
                    end
                    BRnzp: begin 
                        branch_en <= 1;
                        branch_target <= instruction[DATA_WIDTH-1:0] ;
                    end
                    CMP: begin 
                        ALU_CMP <= 1;
                        nzp_wen <= 1;
                    end
                    ADD: begin 
                        reg_wen <= 1;
                        reg_input_mux <= ALU_RESULT ;
                        ALU_OP <= 2'b00;
                    end
                    SUB: begin 
                        reg_wen <= 1;
                        reg_input_mux <= ALU_RESULT ;
                        ALU_OP <= 2'b01;
                    end
                    MUL: begin 
                        reg_wen <= 1;
                        reg_input_mux <= ALU_RESULT;
                        ALU_OP <= 2'b10;
                    end
                    DIV: begin 
                        reg_wen <= 1;
                        reg_input_mux <= ALU_RESULT ;
                        ALU_OP <= 2'b11;
                    end
                    LDR: begin 
                        reg_wen <= 1;
                        reg_input_mux <= MEM_RESULT ;
                        mem_ren <= 1;
                    end
                    STR: begin 
                        mem_wen <= 1;
                    end
                    CONST: begin 
                        reg_wen <= 1;
                        reg_input_mux <= IMMEDIATE ;
                    end
                    RET: begin 
                        Ret <= 1;
                    end
                endcase
            end
        end
    end
endmodule
