`include "defines.vh"
module ALU (
    input wire clk, rst,
    input wire flushE,
    input wire [31:0] src_aE, src_bE,  //操作数
    input wire [4:0] alu_controlE,  //alu 控制信号
    input wire [4:0] sa, //sa值
    input wire [63:0] hilo,  //hilo值

    output wire div_stallE,
    output wire [63:0] alu_outE, //alu输出
    output wire overflowE//算数溢出
);
    wire [63:0] alu_out_div; //乘除法结果
    reg [63:0] alu_out_mul;
    wire mul_sign; //乘法符号
    wire mul_valid;  // 为乘法
    wire div_sign; //除法符号
	wire div_vaild;  //为除法
	wire ready;
    reg [31:0] alu_out_simple; // 普通运算结果
    reg carry_bit;  //进位 判断溢出
    //写硬综好累:(

    //乘法信号
	assign mul_sign = (alu_controlE == `ALU_SIGNED_MULT);
    assign mul_valid = (alu_controlE == `ALU_SIGNED_MULT) | (alu_controlE == `ALU_UNSIGNED_MULT);

    //aluout
    assign alu_outE = ({64{div_vaild}} & alu_out_div)
                    | ({64{mul_valid}} & alu_out_mul)
                    | ({64{~mul_valid & ~div_vaild}} & {32'b0, alu_out_simple})
                    | ({64{(alu_controlE == `ALU_MTHI)}} & {src_aE, hilo[31:0]}) // 若为mthi/mtlo 直接取Hilo的低32位和高32位
                    | ({64{(alu_controlE == `ALU_MTLO)}} & {hilo[63:32], src_aE});
    // 为加减 且溢出位与最高位不等时 算数溢出
    assign overflowE = (alu_controlE==`ALU_ADD || alu_controlE==`ALU_SUB) & (carry_bit ^ alu_out_simple[31]);

    // 算数操作及对应运算
    always @(*) begin
        carry_bit = 0; //溢出位取0
        case(alu_controlE)
            `ALU_AND:       alu_out_simple = src_aE & src_bE;
            `ALU_OR:        alu_out_simple = src_aE | src_bE;
            `ALU_NOR:       alu_out_simple =~(src_aE | src_bE);
            `ALU_XOR:       alu_out_simple = src_aE ^ src_bE;

            `ALU_ADD:       {carry_bit, alu_out_simple} = {src_aE[31], src_aE} + {src_bE[31], src_bE};
            `ALU_ADDU:      alu_out_simple = src_aE + src_bE;
            `ALU_SUB:       {carry_bit, alu_out_simple} = {src_aE[31], src_aE} - {src_bE[31], src_bE};
            `ALU_SUBU:      alu_out_simple = src_aE - src_bE;

            `ALU_SIGNED_MULT:alu_out_mul = $signed(src_aE) * $signed(src_bE); //乘法
            `ALU_UNSIGNED_MULT:alu_out_mul = src_aE * src_bE; 

            `ALU_SLT:       alu_out_simple = $signed(src_aE) < $signed(src_bE); //有符号比较
            `ALU_SLTU:      alu_out_simple = src_aE < src_bE; //无符号比较

            `ALU_SLL:       alu_out_simple = src_bE << src_aE[4:0]; //移位src a
            `ALU_SRL:       alu_out_simple = src_bE >> src_aE[4:0];
            `ALU_SRA:       alu_out_simple = $signed(src_bE) >>> src_aE[4:0];

            `ALU_SLL_SA:    alu_out_simple = src_bE << sa; //移位sa
            `ALU_SRL_SA:    alu_out_simple = src_bE >> sa;
            `ALU_SRA_SA:    alu_out_simple = $signed(src_bE) >>> sa;

            `ALU_LUI:       alu_out_simple = {src_bE[15:0], 16'b0}; //取高16位
            `ALU_DONOTHING: alu_out_simple = src_aE;  // do nothing

            default:    alu_out_simple = 32'b0;
        endcase
    end

    // 除法
	assign div_sign = (alu_controlE == `ALU_SIGNED_DIV);
	assign div_vaild = (alu_controlE == `ALU_SIGNED_DIV || alu_controlE == `ALU_UNSIGNED_DIV);

	div div(
		.clk(~clk),
		.rst(rst),
        .flush(flushE),
		.a(src_aE),  //divident
		.b(src_bE),  //divisor
		.valid(div_vaild),
		.sign(div_sign),   //1 signed

		// .ready(ready),
		.div_stall(div_stallE),
		.result(alu_out_div)
	);




endmodule