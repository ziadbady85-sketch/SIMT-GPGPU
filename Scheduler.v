module scheduler #(
    parameter NZP = 3 ,  ALU_WIDTH = 32 , no_thread = 64
) (
    input clk , rst , start , stop ,
    input mem_ren , mem_wen , reg_wen , ALU_CMP , Ret ,
    input [no_thread-1:0] thread_en , 

    input INST_Valid , lsu_done , alu_done , branch_en , 
    input [NZP-1:0] decoded_NZP , ALU_NZP ,
    input [1:0] reg_input_mux ,

    output reg pc_en , fetch_en , branch_taken ,

    output reg [no_thread-1:0] reg_wen_out , alu_start_out , lsu_start_out ,

    output reg [2:0] core_state,
    output reg done
);

reg alu_start_reg , lsu_start_reg ;

    localparam IDLE = 3'b000, 
               FETCH = 3'b001,   
               DECODE = 3'b010,    
               REQUEST = 3'b011,
               WAIT = 3'b100,        
               EXECUTE = 3'b101,    
               UPDATE = 3'b110,   
               DONE = 3'b111;


parameter ALU_RESULT = 2'b00 , 
          MEM_RESULT = 2'b01 ,
          IMMEDIATE  = 2'b10 ,
          RESERVED   = 2'b11 ;


    always @(posedge clk) begin 
        if (rst) begin
            core_state <= IDLE;
            branch_taken <= 0 ;
            fetch_en <= 0 ;
            reg_wen_out <= 0 ;
            alu_start_out <= 0 ;
            lsu_start_out <= 0 ;
            alu_start_reg <= 0 ;
            lsu_start_reg <= 0 ;
            pc_en <= 0 ;
            done <= 0 ;
        end 
        else begin 
            branch_taken <= 0 ;
            fetch_en <= 0 ;
            alu_start_out <= 0 ;
            lsu_start_out <= 0 ;
            pc_en <= 0 ;
            done <= 0 ;
            reg_wen_out <= (reg_wen)? thread_en : 0 ;
            case (core_state)
                IDLE: begin
                    if (start) begin 
                        core_state <= FETCH;
                    end
                end
                FETCH: begin 
                    fetch_en <= 1 ;
                    if (INST_Valid) begin 
                        core_state <= DECODE;
                    end
                end
                DECODE: begin
                    core_state <= REQUEST;
                end
                REQUEST: begin 
                    if (mem_wen || mem_ren) begin
                        lsu_start_out <= thread_en ;
                        lsu_start_reg <= 1 ;
                    end
                    else if ((reg_wen && reg_input_mux==ALU_RESULT) || ALU_CMP ) begin
                        alu_start_out <= thread_en ;
                        alu_start_reg <= 1 ;
                    end
                    else begin
                        alu_start_reg <= 0 ;
                        lsu_start_reg <= 0 ;
                    end
                    
                    core_state <= WAIT ;
                end
                WAIT: begin
                    if (alu_start_reg || lsu_start_reg) begin
                        if (alu_done || lsu_done) begin
                            core_state <= EXECUTE ;
                        end
                    end
                    else begin
                        core_state <= EXECUTE ;
                    end
                end
                EXECUTE: begin
                    core_state <= UPDATE;
                end
                UPDATE: begin 
                    if (Ret) begin 
                        done <= 1;
                        core_state <= DONE;
                    end else begin 
                        pc_en <= 1 ;
                        if (branch_en) begin
                            if (decoded_NZP == ALU_NZP) begin
                                branch_taken <= 1 ; 
                            end
                        end
                        core_state <= FETCH;
                    end
                end
                DONE: begin 
                    if (stop) begin
                        core_state <= IDLE ;
                    end
                    else if(start) begin
                        core_state <= FETCH ;
                    end
                end

            endcase
        end
    end
endmodule