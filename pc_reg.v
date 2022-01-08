module pc_reg(  
    input clk,rst,stallF,
    input wire branchD,
    input wire branchM,
    input wire pre_right,
    input wire actual_takeM,
    input wire pred_takeD,

    input wire pc_trapM,   //是否发生异常
    input wire jumpD,
    input wire jump_conflictD,
    input wire jump_conflictE,
    input wire [31:0] pc_exceptionM,            //异常的跳转地址
    input wire [31:0] pc_plus4E,              //预测跳，实际不跳 将pc_next指向branch指令的PC+8（注：pc_plus4E等价于branch指令的PC+8） //可以保证延迟槽指令不会被flush，故plush_4E存在
    input wire [31:0] pc_branchM,              //预测不跳，实际跳转 将pc_next指向pc_branchD传到M阶段的值
    input wire [31:0] pc_jumpE,               //jump冲突，在E阶段 （E阶段rs的值）
    input wire [31:0] pc_jumpD,                 //D阶段jump不冲突跳转的地址（rs寄存器或立即数）
    input wire [31:0] pc_branchD,               //D阶段  预测跳转的跳转地址（PC+offset）
    input wire [31:0] pc_plus4F,                 //下一条指令的地址
    output reg [31:0] pc
    );
    wire [31:0] next_pc;
    reg [2:0] pick;
    always @(*) begin
        if(pc_trapM) //发生异常
            pick = 3'b000;
        else 
        if(branchM & ~pre_right & ~actual_takeM)  //预测跳  实际不挑 pc+8 pick=001
            pick = 3'b001;
        else if(branchM & ~pre_right & actual_takeM)   //预测不跳  实际跳 pc_branchM pick=010
            pick = 3'b010;
        else if(jump_conflictE)  //jump冲突 pc_jumpE pick=011
            pick = 3'b011;
            //next_pc = pc_jumpE;
        else if(jumpD & ~jump_conflictD) //jump不冲突 pc_jumpD pick=100
            pick = 3'b100;
        else if(branchD & ~branchM & pred_takeD || branchD & branchM & pre_right & pred_takeD) 
            // M阶段不是分支 该条是分支 D预测跳转 || 两跳均是分支 M预测正确 D预测跳转  ,pc=D阶段  预测跳转的跳转地址（PC+offset）
            pick = 3'b101;
        else
            pick = 3'b110;
    end

    assign next_pc = pick[2] ? (pick[1] ? (pick[0] ? 32'b0 : pc_plus4F):        //111:110
                                           (pick[0]? pc_branchD : pc_jumpD)):   //101:100
                               (pick[1] ? (pick[0] ? pc_jumpE : pc_branchM):    //011:010
                                          (pick[0] ? pc_plus4E : pc_exceptionM));//001:000 //发生异常时pc跳转至异常处理地址

    always @(posedge clk) begin
        if(rst) begin
            pc<=32'hbfc0_0000; //起始地址
        end
        else if(~stallF) begin
            pc<=next_pc;
        end
    end
endmodule