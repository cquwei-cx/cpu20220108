module jump_control (
    input wire [31:0] instrD,
    input wire [31:0] pc_plus4D,
    input wire [31:0] rd1D,
    input wire reg_write_enE, reg_write_enM,
    input wire [4:0] reg_writeE, reg_writeM,

    output wire jumpD,          
    output wire jump_conflictD, 
    output wire [31:0] pc_jumpD        
);
    wire jr, j;
    wire [4:0] rsD;
    assign rsD = instrD[25:21];
    assign jr = ~(|instrD[31:26]) & ~(|(instrD[5:1] ^ 5'b00100)); //判断jr, jalr
    assign j = ~(|(instrD[31:27] ^ 5'b00001));                   //判断j, jal
    assign jumpD = jr | j; //需要jump

    // jump冲突 在E阶段或M阶段需要写回rsD（jr指令跳转目标为rs中的值
    assign jump_conflictD = jr &&
                            ((reg_write_enE && rsD == reg_writeE) ||          
                            (reg_write_enM && rsD == reg_writeM));
    
    wire [31:0] pc_jump_immD;
    assign pc_jump_immD = {pc_plus4D[31:28], instrD[25:0], 2'b00}; //instr_index左移2位 与pc+4高四位拼接

    assign pc_jumpD = j ?  pc_jump_immD : rd1D; //j 和 jr的跳转目标  立即数：寄存器的值
endmodule