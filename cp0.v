`timescale 1ns / 1ps

`include "defines.vh"
module cp0(
      input clk,rst,
      input en,  //是否发生异常
      input we_i, //写使能
      
      input [4:0] waddr_i, //rdM
      input [4:0] raddr_i, //rdM
      input [31:0] data_i, //rt value
      output wire [31:0] data_o, //读出的寄存器值


      input [31:0] except_type_i, // 异常类型
      input [31:0] current_inst_addr_i, //pcM
      input        is_in_delayslot_i,  //是否在延迟槽
      input [31:0] badvaddr_i,  // 出错的虚地址

      output reg [31:0] status_o,  //status寄存器
      output reg [31:0] cause_o,  //cause寄存器
      output reg [31:0] epc_o  //epc寄存器
      
   );
    reg [31:0] badvaddr_o;
    reg [31:0] count_o; //count寄存器
    reg [31:0] compare_o; //compare寄存器
   //write
   always @(posedge clk) begin
      if(rst) begin
        badvaddr_o <=         `ZeroWord;
        count_o <=           `ZeroWord;
        compare_o <=         `ZeroWord;  //初始化 count compare为0
        status_o <=          32'b000000000_1_000000_00000000_000000_0_0; //22位为1  其余为0
        cause_o <=           32'b0_0_000000000000000_00000000_0_00000_00;  //初始全0
        epc_o <=             `ZeroWord; 
        //  timer_int_o <=       `InterruptNotAssert; //是否产生中断
      end

      else begin
        // count++
        count_o <= count_o + 1;
        // count与compare相等时产生中断 (计时器中断)
        if(compare_o != 32'b0 && count_o == compare_o) begin
            cause_o[30] <= `InterruptAssert;
        end

        // mtc0指令
        if(we_i) begin
            case (waddr_i)  //rd指定存储器  （暂不支持sel）  然后把rt的内容存入
               `CP0_REG_COUNT:begin 
                  count_o <= data_i;
               end
               `CP0_REG_COMPARE:begin 
                  compare_o <= data_i;
                  cause_o[30] <= `InterruptNotAssert;
               end
               `CP0_REG_STATUS:begin 
                  status_o[0] <= data_i[0];  //全局中断使能：0-屏蔽 1-使能
                  status_o[15:8] <= data_i[15:8];  //中断屏蔽位：每一位控制一个中断的使能
               end
               `CP0_REG_CAUSE:begin  //仅有9-8位可写
                  cause_o[9:8] <= data_i[9:8]; //待处理软件中断标识 每一位对应软件中断
               end
               `CP0_REG_EPC:begin 
                  epc_o <= data_i;  //例外程序计数器
               end
            endcase
        end

        // 写cp0时序逻辑
        // 如果发生异常  判断其类型
        if(en) begin
            case (except_type_i)
                //中断
               `EXC_TYPE_INT: begin 
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        //处于延迟槽 将上一条地址存入epc
                        epc_o <= current_inst_addr_i - 4;
                        //BD域 标识在延迟槽中
                        cause_o[31] <= 1'b1;
                    end else begin 
                        //不处于延迟槽 将该条地址存入epc
                        epc_o <= current_inst_addr_i;
                        //BD域 标识不在延迟槽中
                        cause_o[31] <= 1'b0;
                    end
                    // 发生中断 EXL域置1 ExcCode域存入例外编码
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= `EXC_CODE_INT;
               end

                // 地址错例外（地址 pc错误
               `EXC_TYPE_ADEL: begin 
                  if(is_in_delayslot_i == `InDelaySlot) begin
                     epc_o <= current_inst_addr_i - 4;
                     cause_o[31] <= 1'b1;
                  end else begin 
                     epc_o <= current_inst_addr_i;
                     cause_o[31] <= 1'b0;
                  end
                  status_o[1] <= 1'b1;
                  cause_o[6:2] <= `EXC_CODE_ADEL;
                  //出错的虚地址
                  badvaddr_o <= badvaddr_i;
               end

               // 地址错例外（写内存
               `EXC_TYPE_ADES: begin
                  if(is_in_delayslot_i == `InDelaySlot) begin
                     epc_o <= current_inst_addr_i - 4;
                     cause_o[31] <= 1'b1;
                  end else begin 
                     epc_o <= current_inst_addr_i;
                     cause_o[31] <= 1'b0;
                  end
                  status_o[1] <= 1'b1;
                  cause_o[6:2] <= `EXC_CODE_ADES;
                  //出错的虚地址
                  badvaddr_o <= badvaddr_i;
               end
                
               // 系统调用例外
               `EXC_TYPE_SYS: begin
                  if(is_in_delayslot_i == `InDelaySlot) begin
                     epc_o <= current_inst_addr_i - 4;
                     cause_o[31] <= 1'b1;
                  end else begin 
                     epc_o <= current_inst_addr_i;
                     cause_o[31] <= 1'b0;
                  end
                  status_o[1] <= 1'b1;
                  cause_o[6:2] <= `EXC_CODE_SYS;
               end

               // 断点例外
               `EXC_TYPE_BP: begin
                  if(is_in_delayslot_i == `InDelaySlot) begin
                     epc_o <= current_inst_addr_i - 4;
                     cause_o[31] <= 1'b1;
                  end else begin 
                     epc_o <= current_inst_addr_i;
                     cause_o[31] <= 1'b0;
                  end
                  status_o[1] <= 1'b1;
                  cause_o[6:2] <= `EXC_CODE_BP;
               end

               // 保留指令例外
               `EXC_TYPE_RI: begin 
                  if(is_in_delayslot_i == `InDelaySlot) begin
                     epc_o <= current_inst_addr_i - 4;
                     cause_o[31] <= 1'b1;
                  end else begin 
                     epc_o <= current_inst_addr_i;
                     cause_o[31] <= 1'b0;
                  end
                  status_o[1] <= 1'b1;
                  cause_o[6:2] <= `EXC_CODE_RI;
               end
               
               // 算数溢出例外
               `EXC_TYPE_OV: begin
                  if(is_in_delayslot_i == `InDelaySlot) begin
                     epc_o <= current_inst_addr_i - 4;
                     cause_o[31] <= 1'b1;
                  end else begin 
                     epc_o <= current_inst_addr_i;
                     cause_o[31] <= 1'b0;
                  end
                  status_o[1] <= 1'b1;
                  cause_o[6:2] <= `EXC_CODE_OV;
               end
               
               //处理完成时 返回中断  EXL域赋0
               `EXC_TYPE_ERET: begin
                  status_o[1] <= 1'b0;
               end
            endcase
         end
      end
   end

   //read
   // 读cp0组合逻辑
   wire count, compare, status, cause, epc, prid, config1, badvaddr;
   // 确定寄存器
   assign count    = (~rst & ~(|( raddr_i ^ `CP0_REG_COUNT     )));
   assign compare  = (~rst & ~(|( raddr_i ^ `CP0_REG_COMPARE   )));
   assign status   = (~rst & ~(|( raddr_i ^ `CP0_REG_STATUS    )));
   assign cause    = (~rst & ~(|( raddr_i ^ `CP0_REG_CAUSE     )));
   assign epc      = (~rst & ~(|( raddr_i ^ `CP0_REG_EPC       )));
   assign badvaddr = (~rst & ~(|( raddr_i ^ `CP0_REG_BADVADDR  )));


    // 读出相应寄存器
   assign data_o = ( {32{rst}     } & 32'd0 )
                 | ( {32{count}   } & count_o )
                 | ( {32{compare} } & compare_o )
                 | ( {32{status}  } & status_o )
                 | ( {32{cause}   } & cause_o )
                 | ( {32{epc}     } & epc_o )
                  | ( {32{badvaddr}} & badvaddr_o )
                 ;
endmodule
