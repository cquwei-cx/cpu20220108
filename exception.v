`include "defines.vh"

module exception(
   input rst,
   input [5:0] ext_int,
   input ri, break, syscall, overflow, addrErrorSw, addrErrorLw, pcError, eretM,
   input [31:0] cp0_status, cp0_cause, cp0_epc,
   input [31:0] pcM,
   input [31:0] alu_outM,

   output [31:0] except_type,
   output flush_exception,  //是否有异常
   output [31:0] pc_exception,  //pc异常处理地址
   output pc_trap,  //是否trap
   output [31:0] badvaddrM  //pc修正
);

   //INTERUPT
   wire int;
   //             //IE             //EXL            
   assign int =   cp0_status[0] && ~cp0_status[1] && (
                     //IM                 //IP
                  ( |(cp0_status[9:8] & cp0_cause[9:8]) ) ||        //软件中断
                  ( |(cp0_status[15:10] & ext_int) )      ||     //硬件中断
                  (|(cp0_status[30] & cp0_cause[30]))            //计时器中断
   );
   // 全局中断开启,且没有例外在处理,识别软件中断或者硬件中断

   assign except_type =    (int)                   ? `EXC_TYPE_INT :    //中断
                           (addrErrorLw | pcError) ? `EXC_TYPE_ADEL :   //地址错误例外（lw地址 pc错误
                           (ri)                    ? `EXC_TYPE_RI :     //保留指令例外（指令不存在
                           (syscall)               ? `EXC_TYPE_SYS :    //系统调用例外（syscall指令
                           (break)                 ? `EXC_TYPE_BP :     //断点例外（break指令
                           (addrErrorSw)           ? `EXC_TYPE_ADES :   //地址错误例外（sw地址异常
                           (overflow)              ? `EXC_TYPE_OV :     //算数溢出例外
                           (eretM)                 ? `EXC_TYPE_ERET :   //eret指令
                                                     `EXC_TYPE_NOEXC;   //无异常
   //interupt pc address
   assign pc_exception =      (except_type == `EXC_TYPE_NOEXC) ? `ZeroWord:
                           (except_type == `EXC_TYPE_ERET)? cp0_epc :
                           32'hbfc0_0380; //异常处理地址
   assign pc_trap =        (except_type == `EXC_TYPE_NOEXC) ? 1'b0:
                           1'b1; //表示发生异常 处理pc
   assign flush_exception =   (except_type == `EXC_TYPE_NOEXC) ? 1'b0:
                           1'b1; //异常时的清空信号
   assign badvaddrM =      (pcError) ? pcM : alu_outM; //出错时的pc 

   
endmodule
