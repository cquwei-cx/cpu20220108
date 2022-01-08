module hazard (
    input wire d_cache_stall,
    input wire alu_stallE,

    input wire flush_jump_confilctE, flush_pred_failedM, flush_exceptionM,

    input wire [4:0] rsE,
    input wire [4:0] rtE,  //寄存器序号
    input wire reg_write_enM,
    input wire reg_write_enW,  //写寄存器信号
    input wire [4:0] reg_writeM,
    input wire [4:0] reg_writeW,  //写寄存器序号

    input wire mem_read_enM,   //读mem信号
    
    output wire stallF, stallD, stallE, stallM, stallW,
    output wire flushF, flushD, flushE, flushM, flushW,  //流水线控制

    output wire [1:0] forward_aE, forward_bE //00-> NONE, 01-> MEM, 10-> WB (LW instr)
);
    // 数据冒险，前推片选信号
    assign forward_aE = rsE != 0 && reg_write_enM && (rsE == reg_writeM) ? 2'b01 :
                        rsE != 0 && reg_write_enW && (rsE == reg_writeW) ? 2'b10 :
                        2'b00;
    assign forward_bE = reg_write_enM && (rtE == reg_writeM) ? 2'b01 :
                        reg_write_enW && (rtE == reg_writeW) ? 2'b10 :
                        2'b00;
    
    assign stallF = ~flush_exceptionM & (d_cache_stall | alu_stallE);//
    assign stallD = d_cache_stall | alu_stallE;
    assign stallE = d_cache_stall | alu_stallE;
    assign stallM = d_cache_stall;
    assign stallW = d_cache_stall;              // 不暂停,会减少jr等指令冲突;

    assign flushF = 1'b0;
    assign flushD = flush_exceptionM | flush_pred_failedM | (flush_jump_confilctE & ~d_cache_stall); //       //EX: jr(冲突), MEM: lw这种情况时，flush_jump_confilctE会导致暂停在D阶段jr的延迟槽指令消失
    assign flushE = flush_exceptionM | (flush_pred_failedM & ~alu_stallE);//  //EX: div, MEM: beq, beq预测失败，要flush D和E，但由于div暂停在E，因此只需要flushD就可以了
    assign flushM = flush_exceptionM | alu_stallE;// 
    assign flushW = 1'b0;
endmodule
