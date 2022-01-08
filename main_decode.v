`include "defines.vh"


module main_decode(

    input             clk, rst,
    input wire [31:0] instrD,

	input wire        stallE, stallM, stallW,
	input wire        flushE, flushM, flushW,

    //ID
	// output wire is_multD,
    output wire       sign_extD,          //立即数是否为符号扩展
    //EX
    output reg [1 :0] reg_dstE,     	//写寄存器选择  00-> rd, 01-> rt, 10-> 写$ra
    output reg        alu_imm_selE,        //alu srcb选择 0->rd2E, 1->immE
    output reg        reg_write_enE,     //寄存器写使能
	output reg        hilo_wenE,
	//MEM
	output reg        mem_read_enM, mem_write_enM, //mem读写使能
	output reg        reg_write_enM,		//写寄存器堆使能
    output reg        mem_to_regM,        //result选择 0->alu_out, 1->read_data
	output reg        hilo_to_regM,			// 00--alu_outM; 01--hilo_o; 10 11--rdataM;
	output reg        riM,
	output reg        breakM, syscallM, eretM,
	output reg        cp0_wenM,   //写cp0
	output reg        cp0_to_regM,  //读cp0
	output wire		  is_mfcM   //为mfc0
    );
    reg  [6:0] sigs; //控制信号 7bits
    wire [1:0] reg_dstD;
    wire       reg_write_enD,alu_imm_selD,mem_to_regD, mem_read_enD, mem_write_enD;
    reg        mem_to_regE, mem_read_enE, mem_write_enE;
    
	wire       hilo_wenD; 
	wire       hilo_to_regD;
	reg        hilo_to_regE;

	wire 	   breakD, syscallD;
	reg 	   breakE, syscallE;
	wire 	   eretD;
	reg 	   eretE;
	reg        riD, riE;

	wire		cp0_wenD;
	reg        cp0_wenE;
	wire       cp0_to_regD;
	reg        cp0_to_regE;

	reg 		is_mfcD;
	wire 		is_mfcE;
	
	


    wire [4:0] rs,rt;
    wire [5:0] opcode;
    wire [5:0] funct;

    assign {reg_write_enD, reg_dstD, alu_imm_selD,mem_to_regD, mem_read_enD, mem_write_enD} = sigs;
    
    assign opcode = instrD[31:26];  //操作码
    assign rs = instrD[25:21];  //rs
    assign rt = instrD[20:16];  //rt
    assign funct = instrD[5:0];  //funct


	// assign is_multD = (~(|opcode) & ~(|(funct[5:1] ^ 5'b01100)));
    // 容易判断的信号
	assign sign_extD = |(opcode[5:2] ^ 4'b0011);		            //andi, xori, lui, ori（op[5:2]=0011）为无符号拓展--0，其它为有符号拓展--1
	
    assign hilo_wenD = ~(|( opcode ^ `EXE_R_TYPE )) & ( 	~(|(funct[5:2] ^ 4'b0110)) 			// div divu mult multu 	
							| 	( ~(|(funct[5:2] ^ 4'b0100)) & funct[0])); //mthi mtlo
						
	assign hilo_to_regD = ~(|(opcode ^ `EXE_R_TYPE)) & (~(|(funct[5:2] ^ 4'b0100)) & ~funct[0]);
														// 00--alu_outM; 01--hilo_o; 10 11--rdataM;


	// cp0写使能：为MTC0指令
	assign cp0_wenD = ~(|(opcode ^ `EXE_ERET_MFTC)) & ~(|(rs ^ `EXE_MTC0));
	// 读cp0：为MFC0指令
	assign cp0_to_regD = ~(|(opcode ^ `EXE_ERET_MFTC)) & ~(|(rs ^ `EXE_MFC0));
	
	// 判断是否为break syscall eret
	assign breakD = ~(|(opcode ^ `EXE_R_TYPE)) & ~(|(funct ^ `EXE_BREAK));
	assign syscallD = ~(|(opcode ^ `EXE_R_TYPE)) & ~(|(funct ^ `EXE_SYSCALL));
	// eret的32位固定
	assign eretD = ~(|(instrD ^ {`EXE_ERET_MFTC, `EXE_ERET}));

    	always @(*) begin
		riD = 1'b0;
		is_mfcD = 1'b0;
		case(opcode)
			// R type

            `EXE_R_TYPE:
            // R型指令继续看funct
				case(funct)		
					`EXE_JR, `EXE_MULT, `EXE_MULTU, `EXE_DIV, `EXE_DIVU, `EXE_MTHI, `EXE_MTLO,
					// 自陷指令 2条 op为000000
					`EXE_SYSCALL, `EXE_BREAK
					: begin
                        sigs = 7'b0_00_0_000;  //跳转指令 信号为0
					end
					// 算数运算指令 10条
					`EXE_ADD,`EXE_ADDU,`EXE_SUB,`EXE_SUBU,`EXE_SLTU,`EXE_SLT ,
					`EXE_AND,`EXE_NOR, `EXE_OR, `EXE_XOR,
					// 移位指令 6条
					`EXE_SLLV, `EXE_SLL, `EXE_SRAV, `EXE_SRA, `EXE_SRLV, `EXE_SRL,
					`EXE_MFHI, `EXE_MFLO  //写入HILO寄存器 
					: begin
                        sigs = 7'b1_00_0_000;  //算数运算指令
					end
					`EXE_JALR
					: begin
                        sigs = 7'b1_10_0_000;  //jalr指令需要将分支之后的pc存入rd中
					end
					//不属于任何指令
					default: begin
						riD  =  1'b1;
                        sigs = 7'b1_00_0_000;
					end
				endcase

			// I type

			// 算数运算指令
			// 逻辑运算 8条
			`EXE_ADDI, `EXE_SLTI, `EXE_SLTIU, `EXE_ADDIU, `EXE_ANDI, `EXE_LUI, `EXE_XORI, `EXE_ORI
			: begin
				sigs = 7'b1_01_1_000;  //I型信号：写回rs 操作立即数 不访存
			end

			//  B族指令 8条
			`EXE_BEQ, `EXE_BNE, `EXE_BLEZ, `EXE_BGTZ
			: begin
                sigs = 7'b0_00_0_000; 
			end
			// 分支指令：BGEZ BLTZ BGEZAL BLTZAL
			`EXE_BRANCHS: begin
				case(rt[4:1])
					// BGEZAL BLTZAL rt:10001 10000
					// 无论转移与否 需要将延迟槽后pc保存至31号寄存器
					4'b1000: begin
                        sigs = 7'b1_10_0_000;
					end
					// BLTZ rt:00000
					4'b0000: begin
                        sigs = 7'b0_00_0_000;
					end
					// 不属于任何指令
					default:begin
						riD  =  1'b1;
                        sigs = 7'b0_00_0_000;
					end
				endcase
			end
			
			// 访存指令 8条
			`EXE_LW, `EXE_LB, `EXE_LBU, `EXE_LH, `EXE_LHU: begin
                sigs = 7'b1_01_1_1_1_0; //读mem
			end
			`EXE_SW, `EXE_SB, `EXE_SH: begin
                sigs = 7'b0_00_1_0_0_1; //写mem
			end
	
			//  J type 2条

			`EXE_J: begin
                sigs = 7'b0_00_0_000;
			end
			// 需将延迟槽后pc保存至31号寄存器
			`EXE_JAL: begin
                sigs = 7'b1_10_0_000;
			end
			
			// 3条特权指令
			`EXE_ERET_MFTC:begin
				case(instrD[25:21])
					`EXE_MTC0: begin
                        sigs = 7'b0;
					end
					`EXE_MFC0: begin
                        sigs = 7'b1_01_0_000;
						is_mfcD = 1'b1;
					end
					default: begin
						riD  =  |(instrD[25:0] ^ `EXE_ERET);  //为eret指令：0  不为eret指令：1
                        sigs = 7'b0;
					end
				endcase
			end
			
			// 不属于任何指令
			default: begin
				riD  =  1;
                sigs = 7'b0;
			end
		endcase
	end

	// pipeline
    // ID-EX flow
    always@(posedge clk) begin
		if(rst | flushE) begin
			reg_dstE		<= 0; 
			alu_imm_selE	<= 0;
			mem_read_enE	<= 0;
			mem_write_enE	<= 0;
			reg_write_enE	<= 0;
			mem_to_regE		<= 0;
			hilo_wenE		<= 0;
			hilo_to_regE	<= 0;
			riE				<= 0;
			breakE			<= 0;
			syscallE		<= 0;
			eretE			<= 0;
			cp0_wenE		<= 0;
			cp0_to_regE		<= 0;
			is_mfcE			<= 0;
		end
		else if(~stallE)begin
			reg_dstE		<= reg_dstD 		; 
			alu_imm_selE	<= alu_imm_selD 	;
			mem_read_enE	<= mem_read_enD		;
			mem_write_enE	<= mem_write_enD	;
			reg_write_enE	<= reg_write_enD 	;
			mem_to_regE		<= mem_to_regD 		;
			hilo_wenE		<= hilo_wenD		;
			hilo_to_regE	<= hilo_to_regD		;
			riE				<= riD				;
			breakE			<= breakD			;
			syscallE		<= syscallD			;
			eretE			<= eretD			;
			cp0_wenE		<= cp0_wenD			;
			cp0_to_regE		<= cp0_to_regD		;
			is_mfcE			<= is_mfcD			;
		end
    end

	// EX-MEM flow
    always@(posedge clk) begin
		if(rst | flushM) begin
			mem_read_enM	<= 0;
			mem_write_enM	<= 0;
			reg_write_enM	<= 0;
			mem_to_regM		<= 0;
			hilo_to_regM	<= 0;
			riM				<= 0;
			breakM			<= 0;
			syscallM		<= 0;
			eretM			<= 0;
			cp0_wenM		<= 0;
			cp0_to_regM		<= 0;
			is_mfcM			<= 0;
		end
		else if(~stallM) begin
			mem_read_enM	<= mem_read_enE		;
			mem_write_enM	<= mem_write_enE	;
			reg_write_enM	<= reg_write_enE 	;
			mem_to_regM		<= mem_to_regE 		;
			hilo_to_regM	<= hilo_to_regE		;
			riM				<= riE				;
			breakM			<= breakE			;
			syscallM		<= syscallE			;
			eretM			<= eretE			;
			cp0_wenM		<= cp0_wenE			;
			cp0_to_regM		<= cp0_to_regE		;
			is_mfcM			<= is_mfcE			;
		end
    end
endmodule

