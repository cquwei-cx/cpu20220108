`include "defines.vh"

module mem_control(
    input wire [31:0] instrM,
    input wire [31:0] addr,  //访存地址

    input wire [31:0] data_wdataM, //要写的数据
    output wire [31:0] mem_wdataM,  //真正写数据
    output wire [3:0] mem_wenM,  //写使能

    input wire [31:0] mem_rdataM, //内存读出
    output wire [31:0] data_rdataM,  // 实际读出

    output wire addr_error_sw, addr_error_lw
);
    wire [3:0] mem_byte_wen;
    wire [5:0] op_code;

    wire instr_lw, instr_lh, instr_lb, instr_sw, instr_sh, instr_sb, instr_lhu, instr_lbu;
    wire addr_W0, addr_B2, addr_B1, addr_B3;
    

    assign op_code = instrM[31:26];

    // 根据addr后两位选取读的位置
    assign addr_W0 = ~(|(addr[1:0] ^ 2'b00));
    assign addr_B2 = ~(|(addr[1:0] ^ 2'b10));
    assign addr_B1 = ~(|(addr[1:0] ^ 2'b01));
    assign addr_B3 = ~(|(addr[1:0] ^ 2'b11));

    // 判断是否为各种访存指令
    assign instr_lw = ~(|(op_code ^ `EXE_LW));
    assign instr_lb = ~(|(op_code ^ `EXE_LB));
    assign instr_lh = ~(|(op_code ^ `EXE_LH));
    assign instr_lbu = ~(|(op_code ^ `EXE_LBU));
    assign instr_lhu = ~(|(op_code ^ `EXE_LHU));
    assign instr_sw = ~(|(op_code ^ `EXE_SW)); 
    assign instr_sh = ~(|(op_code ^ `EXE_SH));
    assign instr_sb = ~(|(op_code ^ `EXE_SB));

    // 地址异常
    assign addr_error_sw = (instr_sw & ~addr_W0)
                        | (  instr_sh & ~(addr_W0 | addr_B2));
    assign addr_error_lw = (instr_lw & ~addr_W0)
                        | (( instr_lh | instr_lhu ) & ~(addr_W0 | addr_B2));

// wdata  and  byte_wen
    assign mem_wenM = ( {4{( instr_sw & addr_W0 )}} & 4'b1111)          //写字  
                        | ( {4{( instr_sh & addr_W0  )}} & 4'b0011)     //写半字 低位
                        | ( {4{( instr_sh & addr_B2  )}} & 4'b1100)     //写半字 高位
                        | ( {4{( instr_sb & addr_W0  )}} & 4'b0001)     //写字节 四个字节
                        | ( {4{( instr_sb & addr_B1  )}} & 4'b0010)
                        | ( {4{( instr_sb & addr_B2  )}} & 4'b0100)
                        | ( {4{( instr_sb & addr_B3  )}} & 4'b1000);


// data ram 按字寻址
    assign mem_wdataM =   ({ 32{instr_sw}} & data_wdataM)               //
                        | ( {32{instr_sh}}  & {2{data_wdataM[15:0]} })  // 低位高位均为数据 具体根据操作
                        | ( {32{instr_sb}}  & {4{data_wdataM[7:0]}  }); //
// rdata   
    assign data_rdataM =  ( {32{instr_lw}}   & mem_rdataM)                                                  //lw 直接读取字
                        | ( {32{ instr_lh   & addr_W0}}  & { {16{mem_rdataM[15]}},  mem_rdataM[15:0]    })  //lh 分别从00 10开始读半字 读取后进行符号扩展
                        | ( {32{ instr_lh   & addr_B2}}  & { {16{mem_rdataM[31]}},  mem_rdataM[31:16]   })
                        | ( {32{ instr_lhu  & addr_W0}}  & {  16'b0,                mem_rdataM[15:0]    })  //lhb 分别从00 10开始读半字 读取后进行0扩展
                        | ( {32{ instr_lhu  & addr_B2}}  & {  16'b0,                mem_rdataM[31:16]   })
                        | ( {32{ instr_lb   & addr_W0}}  & { {24{mem_rdataM[7]}},   mem_rdataM[7:0]     })  //lb 分别从00 01 10 11开始取bytes 读取后进行符号扩展
                        | ( {32{ instr_lb   & addr_B1}}  & { {24{mem_rdataM[15]}},  mem_rdataM[15:8]    })
                        | ( {32{ instr_lb   & addr_B2}}  & { {24{mem_rdataM[23]}},  mem_rdataM[23:16]   })
                        | ( {32{ instr_lb   & addr_B3}}  & { {24{mem_rdataM[31]}},  mem_rdataM[31:24]   })
                        | ( {32{ instr_lbu  & addr_W0}}  & {  24'b0 ,               mem_rdataM[7:0]     })  //lbu 分别从00 01 10 11开始取bytes 读取后进行0扩展
                        | ( {32{ instr_lbu  & addr_B1}}  & {  24'b0 ,               mem_rdataM[15:8]    })
                        | ( {32{ instr_lbu  & addr_B2}}  & {  24'b0 ,               mem_rdataM[23:16]   })
                        | ( {32{ instr_lbu  & addr_B3}}  & {  24'b0 ,               mem_rdataM[31:24]   });
endmodule
