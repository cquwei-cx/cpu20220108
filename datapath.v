`timescale 1ns / 1ps
module datapath (
    input wire       clk, 
    input wire       rst,
    input wire  [5 :0] ext_int,
    
    //inst
    output wire [31:0] inst_addrF,  //指令地址
    output wire        inst_enF,  //使能
    input wire  [31:0] instrF,  //注：instr ram时钟取反

    //data
    output wire mem_enM,                    
    output wire [31:0] mem_addrM,     //读/写地址
    input  wire [31:0] mem_rdataM,    //读数据
    output wire [3 :0] mem_wenM,      //写使能
    output wire [31:0] mem_wdataM,    //写数据
    input wire         d_cache_stall,

    //debug
    output wire [31:0] debug_wb_pc,      
    output wire [3 :0] debug_wb_rf_wen,
    output wire [4 :0] debug_wb_rf_wnum, 
    output wire [31:0] debug_wb_rf_wdata
);


// 变量声明
// IF阶段
    wire [31:0] pcF, pc_next, pc_plus4F;    //pc
    wire [31:0] instrF_4;                   //instrF末尾为2'b00
    
    wire pc_errorF;  // pc错误
    wire pcerrorD, pcerrorE, pcerrorM; 

    wire F_change; // 此时的D阶段（即上一条指令）是否为跳转指令

// ID阶段
    wire [31:0] instrD;  //指令
    wire [4 :0] rsD, rtD, rdD, saD;  //rs rt rd 寄存器标号
    wire [31:0] pcD, pc_plus4D;  //pc

    wire [31:0] rd1D, rd2D, immD, pc_branchD, pc_jumpD;  //寄存器读出数据 立即数 pc分支 跳转
    wire        sign_extD, pred_takeD, branchD, jumpD;  //立即数扩展 分支预测 branch jump信号
    wire        flush_pred_failedM;  //分支预测失败
    wire [4 :0] alu_controlD;  // alu控制

    wire        jump_conflictD;  //jump冲突
    wire [4 :0] branch_judge_controlD; //分支判断控制
    
    wire        is_in_delayslot_iD;//指令是否在延迟槽



// EX阶段
    wire [31:0] pcE, pc_plus4E ,rd1E, rd2E, mem_wdataE, immE; //pc pc+4 寄存器值 写内存值 立即数
    wire [4 :0] rsE, rtE, rdE, saE;  //寄存器号
    wire        pred_takeE;  //分支预测
    wire [1 :0] reg_dstE;  //写回选择信号, 00-> rd, 01-> rt, 10-> 写$ra
    wire [4 :0] alu_controlE;  //alu控制信号

    wire [31:0] src_aE, src_bE; //alu输入（操作数
    wire [63:0] alu_outE; //alu输出
    wire        alu_imm_selE;  //alu srcb选择 0->rd2E, 1->immE
    wire [4 :0] reg_writeE; //写寄存器号
    wire        branchE; //分支信号
    wire [31:0] pc_branchE;  //分支跳转pc

    wire [31:0] instrE;
    wire [31:0] pc_jumpE;  //jump pc
    wire        jump_conflictE; //jump冲突
    wire        reg_write_enE; //写寄存器信号
    wire        alu_stallE;  //aluzant
    wire [31:0] rs_valueE, rt_valueE;  //rs rt寄存器的值
    
    wire        flush_jump_confilctE;  //jump冲突
    wire        jumpE; //jump信号
    wire        actual_takeE;  //分支预测 实际结果
    wire [4 :0] branch_judge_controlE; //分支判断控制

    // 异常处理信号
    wire        is_in_delayslot_iE; //是否处于延迟槽
    wire        overflowE; //溢出

// MEM阶段
    wire [31:0] pcM;  // pc
    wire [31:0] alu_outM; //alu输出
    wire [4:0] reg_writeM; //写寄存器号
    wire [31:0] instrM;  //指令
    wire        mem_read_enM; //读内存
    wire        mem_write_enM; //写内存
    wire        reg_write_enM;  //寄存器写
    wire        mem_to_regM;  //写回寄存器选择信号
    wire [31:0] resultM;  // mem out
    wire        actual_takeM;  //分支预测 真实结果
    wire        pre_right;  // 预测正确
    wire        pred_takeM; // 预测
    wire        branchM; // 分支信号
    wire [31:0] pc_branchM; //分支跳转地址

    wire [31:0] mem_ctrl_rdataM; 

    wire        hilo_wenE;  //hilo写使能
    wire [63:0] hilo_oM;  //hilo输出
    wire        hilo_to_regM; 

    wire [4:0] rdM;
    wire [31:0] rt_valueM;

    wire		  is_mfcM;

    //异常处理信号 exception
    wire        riM;  //指令不存在
    wire        breakM; //break指令
    wire        syscallM; //syscall指令
    wire        eretM; //eretM指令
    wire        overflowM;  //算数溢出
    wire        addrErrorLwM, addrErrorSwM; //访存指令异常
    wire        pcErrorM;  //pc异常

    // cp0
    wire [31:0] except_typeM;  // 异常类型
    wire [31:0] cp0_statusM;  //status值
    wire [31:0] cp0_causeM;  //cause值
    wire [31:0] cp0_epcM;  //epc值
    wire        flush_exceptionM;  // 发生异常时需要刷新流水线
    wire [31:0] pc_exceptionM; //异常处理的地址0xbfc0_0380，若为eret指令 则为返回地址
    wire        pc_trapM; // 发生异常时pc特殊处理
    wire [31:0] badvaddrM;
    wire        is_in_delayslot_iM;
    wire        cp0_to_regM;
    wire        cp0_wenM;
    
//Write back
    wire [31:0] pcW;  //pc
    wire        reg_write_enW;  //写寄存器
    wire [31:0] alu_outW;  //alu输出
    wire [4 :0] reg_writeW;  //写寄存器号
    wire [31:0] resultW;  // 写入寄存器的result

    wire [31:0] cp0_statusW, cp0_causeW, cp0_epcW, cp0_data_oW;

// stall
    wire stallF, stallD, stallE, stallM, stallW;  //流水线暂停
    wire flushF, flushD, flushE, flushM, flushW;  //流水线刷新
    wire [1:0] forward_aE, forward_bE;  //数据前推片选信号

    //debug signal
    assign debug_wb_pc          = pcM;
    assign debug_wb_rf_wen      = {4{reg_write_enM & ~d_cache_stall & ~flush_exceptionM }};//
    assign debug_wb_rf_wnum     = reg_writeM;
    assign debug_wb_rf_wdata    = resultM;

    assign inst_addrF = pcF; //F阶段地址
    assign inst_enF = ~stallF & ~pc_errorF & ~flush_pred_failedM; // 指令读使能：一切正常
    assign pc_errorF = pcF[1:0] == 2'b0 ? 1'b0 : 1'b1; //pc最后两位不是0 则pc错误


    // main decode
    main_decode main_decode0(
        .clk(clk), .rst(rst),
        .instrD(instrD),
        
        .stallE(stallE), .stallM(stallM), .stallW(stallW),
        .flushE(flushE), .flushM(flushM), .flushW(flushW),
        //ID
        .sign_extD(sign_extD),
        //EX
        .reg_dstE(reg_dstE),
        .alu_imm_selE(alu_imm_selE),
        .reg_write_enE(reg_write_enE),
        .hilo_wenE(hilo_wenE),
        //MEM
        .mem_read_enM(mem_read_enM),
        .mem_write_enM(mem_write_enM),
        .reg_write_enM(reg_write_enM),
        .mem_to_regM(mem_to_regM),
        .hilo_to_regM(hilo_to_regM),
        .riM(riM),
        .breakM(breakM),
        .syscallM(syscallM),
        .eretM(eretM),
        .cp0_wenM(cp0_wenM),
        .cp0_to_regM(cp0_to_regM),
        .is_mfcM(is_mfcM)
    );


    // alu decode
    alu_decode alu_decode0(
        .instrD(instrD),

        .alu_controlD(alu_controlD),
        .branch_judge_controlD(branch_judge_controlD)
    );

    // hazard 冒险控制
    hazard hazard0(
        .d_cache_stall(d_cache_stall),
        .alu_stallE(alu_stallE),

        .flush_jump_confilctE   (flush_jump_confilctE),
        .flush_pred_failedM     (flush_pred_failedM),
        .flush_exceptionM       (flush_exceptionM),

        .rsE(rsE),
        .rtE(rtE),
        .reg_write_enM(reg_write_enM),
        .reg_write_enW(reg_write_enW),
        .reg_writeM(reg_writeM),
        .reg_writeW(reg_writeW),
        .mem_read_enM(mem_read_enM),

        .stallF(stallF), .stallD(stallD), .stallE(stallE), .stallM(stallM), .stallW(stallW),
        .flushF(flushF), .flushD(flushD), .flushE(flushE), .flushM(flushM), .flushW(flushW),
        .forward_aE(forward_aE), .forward_bE(forward_bE)
    );


// Instruction Fetch
    // pc+4
    assign pc_plus4F = pcF + 4;

    // pc reg
    pc_reg pc_reg0(
        .clk(clk),
        .rst(rst),
        .stallF(stallF),
        .branchD(branchD),
        .branchM(branchM),
        .pre_right(pre_right),
        .actual_takeM(actual_takeM),
        .pred_takeD(pred_takeD),
        .pc_trapM(pc_trapM),
        .jumpD(jumpD),
        .jump_conflictD(jump_conflictD),
        .jump_conflictE(jump_conflictE),

        .pc_exceptionM(pc_exceptionM),
        .pc_plus4E(pc_plus4E),
        .pc_branchM(pc_branchM),
        .pc_jumpE(pc_jumpE),
        .pc_jumpD(pc_jumpD),
        .pc_branchD(pc_branchD),
        .pc_plus4F(pc_plus4F),

        .pc(pcF)
    );


    assign instrF_4 = ({32{~(|(pcF[1:0] ^ 2'b00))}} & instrF);  //低2位一定为00 不为0则inst清0
    assign F_change = branchD | jumpD; //F阶段得到此时d阶段是否为跳转指令

// Decode
    assign rsD = instrD[25:21];
    assign rtD = instrD[20:16];
    assign rdD = instrD[15:11];
    assign saD = instrD[10:6]; //sra srl 指令用到sa立即数

    //F->D pipeline
    F_to_D F_to_D(
        .clk(clk), .rst(rst),
        .stallD(stallD),
        .flushD(flushD),

        .pcF(pcF),
        .pc_plus4F(pc_plus4F),
        .instrF(instrF_4),
        .F_change(F_change), //上一条指令是跳转
        
        .pcD(pcD),
        .pc_plus4D(pc_plus4D),
        .instrD(instrD),
        .is_in_delayslot_iD(is_in_delayslot_iD)  //处于延迟槽
    );

    //use for debug
    // 指令转化为ascii码
    wire [44:0] ascii;
    inst_ascii_decoder inst_ascii_decoder0(
        .instr(instrD),
        .ascii(ascii)
    );
    // 立即数扩展   1-有符号扩展 0-无符号扩展
    assign immD = sign_extD ? {{16{instrD[15]}}, instrD[15:0]}:
                                {16'b0, instrD[15:0]};


    // 分支跳转  立即数左移2 + pc+4
    assign pc_branchD = {immD[29:0], 2'b00} + pc_plus4D;

    //寄存器堆    
    regfile regfile(
        .clk(clk),
        .stallW(stallW),
        .we3(reg_write_enM & ~flush_exceptionM),//
        .ra1(rsD), .ra2(rtD), .wa3(reg_writeM), 
        .wd3(resultM),

        .rd1(rd1D), .rd2(rd2D)
    );

    //分支预测器
    branch_predict branch_predict0(
        .clk(clk), .rst(rst),

        .flushD(flushD),
        .stallD(stallD),

        .instrD(instrD),
        .immD(immD),
        .pcF(pcF),
        .pcM(pcM),
        .branchM(branchM),
        .actual_takeM(actual_takeM),

        .branchD(branchD),
        .branchL_D(),
        .pred_takeD(pred_takeD)
    );

    // jump指令控制
    jump_control jump_control(
        .instrD(instrD),
        .pc_plus4D(pc_plus4D),
        .rd1D(rd1D),
        .reg_write_enE(reg_write_enE), .reg_write_enM(reg_write_enM),
        .reg_writeE(reg_writeE), .reg_writeM(reg_writeM),

        .jumpD(jumpD),                      //是jump类指令(j, jr)
        .jump_conflictD(jump_conflictD),    //jr rs寄存器发生冲突
        .pc_jumpD(pc_jumpD)                 //D阶段最终跳转地址
    );

    // D->E pipeline
    D_to_E D_to_E(
        .clk(clk),
        .rst(rst),
        .stallE(stallE),
        .flushE(flushE),

        .pcD(pcD),
        .rsD(rsD), .rd1D(rd1D), .rd2D(rd2D),
        .rtD(rtD), .rdD(rdD),
        .immD(immD),
        .pc_plus4D(pc_plus4D),
        .instrD(instrD),
        .branchD(branchD),
        .pred_takeD(pred_takeD),
        .pc_branchD(pc_branchD),
        .jump_conflictD(jump_conflictD),
        .is_in_delayslot_iD(is_in_delayslot_iD),
        .saD(saD),
        .alu_controlD(alu_controlD),
        .jumpD(jumpD),
        .branch_judge_controlD(branch_judge_controlD),
        
        .pcE(pcE),
        .rsE(rsE), .rd1E(rd1E), .rd2E(rd2E),
        .rtE(rtE), .rdE(rdE),
        .immE(immE),
        .pc_plus4E(pc_plus4E),
        .instrE(instrE),
        .branchE(branchE),
        .pred_takeE(pred_takeE),
        .pc_branchE(pc_branchE),
        .jump_conflictE(jump_conflictE),
        .is_in_delayslot_iE(is_in_delayslot_iE),
        .saE(saE),
        .alu_controlE(alu_controlE),
        .jumpE(jumpE),
        .branch_judge_controlE(branch_judge_controlE)      
    );


    //ALU
    ALU alu0(
        .clk(clk),
        .rst(rst),
        .flushE(flushE),
        .src_aE(src_aE), .src_bE(src_bE),
        .alu_controlE(alu_controlE),
        .sa(saE),
        .hilo(hilo_oM),

        .div_stallE(alu_stallE),
        .alu_outE(alu_outE),
        .overflowE(overflowE)
    );

    mux4 #(5) mux4_regdst(
        rdE,                                //
        rtE,                                //
        5'd31,                              //
        5'b0,                               //
        reg_dstE,                           //
        reg_writeE                          //选择writeback寄存器
    );

    mux4 #(32) mux4_forward_aE(
        rd1E,                               //
        resultM,                            //
        resultW,                            //
        pc_plus4D,                          // 执行jalr，jal指令；写入到$ra寄存器的数据（跳转指令对应延迟槽指令的下一条指令的地址即PC+8） //可以保证延迟槽指令不会被flush，故plush_4D存在
        {2{jumpE | branchE}} | forward_aE,  // 当ex阶段是jal或者jalr指令，或者bxxzal时，jumpE | branchE== 1；选择pc_plus4D；其他时候为数据前推

        src_aE
    );
    mux4 #(32) mux4_forward_bE(
        rd2E,                               //
        resultM,                            //
        resultW,                            // 
        immE,                               //立即数
        {2{alu_imm_selE}} | forward_bE,     //main_decoder产生alu_imm_selE信号，表示alu第二个操作数为立即数

        src_bE
    );

    mux4 #(32) mux4_rs_valueE(rd1E, resultM, resultW, 32'b0, forward_aE, rs_valueE); //数据前推后的rs寄存器的值
    mux4 #(32) mux4_rt_valueE(rd2E, resultM, resultW, 32'b0, forward_bE, rt_valueE); //数据前推后的rt寄存器的值

    //计算branch结果 得到真实是否跳转
    branch_check branch_check(
        .branch_judge_controlE(branch_judge_controlE),
        .src_aE(rs_valueE),
        .src_bE(rt_valueE),
        .actual_takeE(actual_takeE)
    );

    assign pc_jumpE = rs_valueE; //jr指令 跳转到rs的值
    assign flush_jump_confilctE = jump_conflictE;

    // E->M pipeline
    E_to_M E_to_M(
        .clk(clk),
        .rst(rst),
        .stallM(stallM),
        .flushM(flushM),

        .pcE(pcE),
        .alu_outE(alu_outE),
        .rt_valueE(rt_valueE),
        .reg_writeE(reg_writeE),
        .instrE(instrE),
        .branchE(branchE),
        .pred_takeE(pred_takeE),
        .pc_branchE(pc_branchE),
        .overflowE(overflowE),
        .is_in_delayslot_iE(is_in_delayslot_iE),
        .rdE(rdE),
        .actual_takeE(actual_takeE),

        .pcM(pcM),
        .alu_outM(alu_outM),
        .rt_valueM(rt_valueM),
        .reg_writeM(reg_writeM),
        .instrM(instrM),
        .branchM(branchM),
        .pred_takeM(pred_takeM),
        .pc_branchM(pc_branchM),
        .overflowM(overflowM),
        .is_in_delayslot_iM(is_in_delayslot_iM),
        .rdM(rdM),
        .actual_takeM(actual_takeM)
    );

    assign mem_addrM = alu_outM;
    assign mem_enM = (mem_read_enM | mem_write_enM) ; //读或者写

    // mem读写控制
    mem_control mem_control(
        .instrM(instrM),
        .addr(alu_outM),
    
        .data_wdataM(rt_valueM),    //原始的wdata
        .mem_wdataM(mem_wdataM),    //新的wdata
        .mem_wenM(mem_wenM),

        .mem_rdataM(mem_rdataM),    
        .data_rdataM(mem_ctrl_rdataM),

        .addr_error_sw(addrErrorSwM),
        .addr_error_lw(addrErrorLwM)  
    );

    // hilo寄存器
    hilo hilo(
        .clk(clk),
        .rst(rst),
        .instrM(instrM),    // 用于识别mfhi，mflo，决定输出；
        .we(hilo_wenE & ~flush_exceptionM),     // both write lo and hi 
        .hilo_in(alu_outE),

        .hilo_out(hilo_oM)
    );

    assign pcErrorM = |(pcM[1:0] ^ 2'b00);  //后两位不是00

    //异常处理
    exception exception(
        .rst(rst),
        .ext_int(ext_int),
        .ri(riM), .break(breakM), .syscall(syscallM), .overflow(overflowM), .addrErrorSw(addrErrorSwM), .addrErrorLw(addrErrorLwM), .pcError(pcErrorM), .eretM(eretM),
        .cp0_status(cp0_statusW), .cp0_cause(cp0_causeW), .cp0_epc(cp0_epcW),
        .pcM(pcM),
        .alu_outM(alu_outM),

        .except_type(except_typeM),
        .flush_exception(flush_exceptionM),
        .pc_exception(pc_exceptionM),
        .pc_trap(pc_trapM),
        .badvaddrM(badvaddrM)
    );

    // cp0寄存器
    cp0 cp0(
        .clk(clk),
        .rst(rst),
        
        .en(flush_exceptionM),
        .we_i(cp0_wenM),

        .waddr_i(rdM),
        .raddr_i(rdM),
        .data_i(rt_valueM),
        .data_o(cp0_data_oW),

        .except_type_i(except_typeM),
        .current_inst_addr_i(pcM),
        .is_in_delayslot_i(is_in_delayslot_iM),
        .badvaddr_i(badvaddrM),

        .status_o(cp0_statusW),
        .cause_o(cp0_causeW),
        .epc_o(cp0_epcW)
    );

    mux4 #(32) mux4_mem_to_reg(alu_outM, mem_ctrl_rdataM, hilo_oM, cp0_data_oW, {hilo_to_regM, mem_to_regM} | {2{is_mfcM}}, resultM);
   
    //分支预测结果
    assign pre_right = ~(pred_takeM ^ actual_takeM); 
    assign flush_pred_failedM = ~pre_right;

// M->W pipeline
    M_to_W M_to_W(
        .clk(clk),
        .rst(rst),
        .stallW(stallW),

        .pcM(pcM),
        .alu_outM(alu_outM),
        .reg_writeM(reg_writeM),
        .reg_write_enM(reg_write_enM),
        .resultM(resultM),


        .pcW(pcW),
        .alu_outW(alu_outW),
        .reg_writeW(reg_writeW),
        .reg_write_enW(reg_write_enW),
        .resultW(resultW)
    );

endmodule
