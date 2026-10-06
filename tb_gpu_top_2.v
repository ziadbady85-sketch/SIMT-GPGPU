`timescale 1ns/1ns

module tb_gpu_top_2;

    reg clk;
    reg rst;
    reg start;
    reg stop;
    reg [5:0] thread_count;

    wire done;

    gpu_top uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .stop(stop),
        .thread_count(thread_count),
        .done(done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer cycle_count;
    initial cycle_count = 0;
    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        if (cycle_count > 1000) begin
            $display("TIMEOUT: `done` never asserted after 1000 cycles.");
            $stop;
        end
    end

    initial begin
        rst = 1;
        start = 0;
        stop = 0;
        thread_count = 6'd16;

        repeat (3) @(posedge clk);
        rst = 0;

        //                                        opcode|C(rd) |A(rs) |B(rt)/imm
        uut.u_inst_mem.INST_MEM[0]  = 16'b0000_0000_0000_0000; // NOP
        uut.u_inst_mem.INST_MEM[1]  = 16'b1001_0001_0000_1100; // CONST R1,#12
        uut.u_inst_mem.INST_MEM[2]  = 16'b1001_0010_0000_0101; // CONST R2,#5
        uut.u_inst_mem.INST_MEM[3]  = 16'b0011_0100_0001_0010; // ADD   R4,R1,R2
        uut.u_inst_mem.INST_MEM[4]  = 16'b0100_0101_0001_0010; // SUB   R5,R1,R2
        uut.u_inst_mem.INST_MEM[5]  = 16'b0101_0110_0001_0010; // MUL   R6,R1,R2
        uut.u_inst_mem.INST_MEM[6]  = 16'b0110_0111_0001_0010; // DIV   R7,R1,R2
        uut.u_inst_mem.INST_MEM[7]  = 16'b0010_0000_0001_0010; // CMP   R1,R2
        uut.u_inst_mem.INST_MEM[8]  = 16'b0001_0010_0000_1010; // BRnzp P,#10
        uut.u_inst_mem.INST_MEM[9]  = 16'b1000_0000_0011_0001; // STR R3,R1  (decoy, must be skipped)
        uut.u_inst_mem.INST_MEM[10] = 16'b1001_0011_0110_0100; // CONST R3,#100
        uut.u_inst_mem.INST_MEM[11] = 16'b1000_0000_0011_0100; // STR   R3,R4
        uut.u_inst_mem.INST_MEM[12] = 16'b1001_0011_0110_1000; // CONST R3,#104
        uut.u_inst_mem.INST_MEM[13] = 16'b1000_0000_0011_0101; // STR   R3,R5
        uut.u_inst_mem.INST_MEM[14] = 16'b1001_0011_0110_1100; // CONST R3,#108
        uut.u_inst_mem.INST_MEM[15] = 16'b1000_0000_0011_0110; // STR   R3,R6
        uut.u_inst_mem.INST_MEM[16] = 16'b1001_0011_0111_0000; // CONST R3,#112
        uut.u_inst_mem.INST_MEM[17] = 16'b1000_0000_0011_0111; // STR   R3,R7
        uut.u_inst_mem.INST_MEM[18] = 16'b1001_0011_0110_0100; // CONST R3,#100
        uut.u_inst_mem.INST_MEM[19] = 16'b0111_1000_0011_0000; // LDR   R8,R3
        
        uut.u_inst_mem.INST_MEM[20] = 16'b1111_0000_0000_0000; // RET

        // sentinel for the branch-skip check (word index 0 = byte address 0)
        uut.u_data_memory.mem[0] = 32'hDEAD_BEEF;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait (done == 1'b1);
        stop = 1 ;
        $display("Finished at cycle %0d", cycle_count);
        repeat (4) @(posedge clk);
        $stop;
    end


endmodule
