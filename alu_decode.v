`include "defines.vh"

module alu_decode(
	input wire [31:0] instrD,
	
    output reg [4:0] alu_controlD,
	output reg [4:0] branch_judge_controlD
    );
	
    wire [5:0] opcode;
	wire [4:0] rs, rt;
	wire [5:0] funct;

    assign opcode = instrD[31:26];
    assign rs = instrD[25:21];
    assign rt = instrD[20:16];
    assign funct = instrD[5:0];
    
	always @* begin
		case(opcode)
            // R型指令
			`EXE_R_TYPE: 
				case(funct)
					//算数和逻辑运算
					`EXE_AND:   	alu_controlD <= `ALU_AND; //1
					`EXE_OR:    	alu_controlD <= `ALU_OR;
					`EXE_XOR:   	alu_controlD <= `ALU_XOR;
					`EXE_NOR:   	alu_controlD <= `ALU_NOR;

					`EXE_ADD:   	alu_controlD <= `ALU_ADD;	//4
					`EXE_SUB:   	alu_controlD <= `ALU_SUB;
					`EXE_ADDU:  	alu_controlD <= `ALU_ADDU;
					`EXE_SUBU:  	alu_controlD <= `ALU_SUBU;
					`EXE_SLT:   	alu_controlD <= `ALU_SLT;
					`EXE_SLTU:  	alu_controlD <= `ALU_SLTU;
					
                    //div and mul
					`EXE_DIV:   	alu_controlD <= `ALU_SIGNED_DIV;
					`EXE_DIVU:  	alu_controlD <= `ALU_UNSIGNED_DIV;
					`EXE_MULT:  	alu_controlD <= `ALU_SIGNED_MULT;
					`EXE_MULTU: 	alu_controlD <= `ALU_UNSIGNED_MULT;

					//移位指令
					`EXE_SLL:   	alu_controlD <= `ALU_SLL_SA;	//2
					`EXE_SRL:   	alu_controlD <= `ALU_SRL_SA;
					`EXE_SRA:   	alu_controlD <= `ALU_SRA_SA;
					`EXE_SLLV:  	alu_controlD <= `ALU_SLL;
					`EXE_SRLV:  	alu_controlD <= `ALU_SRL;
					`EXE_SRAV:  	alu_controlD <= `ALU_SRA;

					//hilo
					`EXE_MTHI:  	alu_controlD <= `ALU_MTHI;
					`EXE_MTLO:  	alu_controlD <= `ALU_MTLO;
					default:    	alu_controlD <= `ALU_DONOTHING;
				endcase
			//I type
			`EXE_ADDI: 	alu_controlD <= `ALU_ADD;
			`EXE_ADDIU: alu_controlD <= `ALU_ADDU;
			`EXE_SLTI: 	alu_controlD <= `ALU_SLT;
			`EXE_SLTIU: alu_controlD <= `ALU_SLTU;
			`EXE_ANDI: 	alu_controlD <= `ALU_AND;
			`EXE_XORI: alu_controlD <= `ALU_XOR;
			`EXE_LUI: 	alu_controlD <= `ALU_LUI;
			`EXE_ORI: alu_controlD <= `ALU_OR;
			//memory
			`EXE_LW, `EXE_LB, `EXE_LBU, `EXE_LH, `EXE_LHU, `EXE_SW, `EXE_SB, `EXE_SH:
						alu_controlD <= `ALU_ADDU;
			default:
						alu_controlD <= `ALU_DONOTHING;
		endcase
	end

	// branch_judge控制信号
    // 各种branch指令相关的alu操作
	always @(*) begin
		case(opcode)
			`EXE_BEQ:
                branch_judge_controlD <= `ALU_EQ;
            `EXE_BGTZ:
                branch_judge_controlD <= `ALU_GTZ;
            `EXE_BLEZ:   
                branch_judge_controlD <= `ALU_LEZ;
            `EXE_BNE:
                branch_judge_controlD <= `ALU_NEQ;
            `EXE_BRANCHS:   //bltz, bltzal, bgez, bgezal
                case(rt)
                    `EXE_BLTZ, `EXE_BLTZAL:      
                        branch_judge_controlD <= `ALU_LTZ;
                    `EXE_BGEZ, `EXE_BGEZAL: 
                        branch_judge_controlD <= `ALU_GEZ;
                    default:
                        branch_judge_controlD <= `ALU_DONOTHING; 
                endcase
			default:
						branch_judge_controlD <= `ALU_DONOTHING;
		endcase	
	end
endmodule

