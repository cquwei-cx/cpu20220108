module mycpu_top(
    input  wire        clk,rst,resetn,
    input  wire [5 :0] ext_int,

    // inst_mem
    output wire        inst_sram_en,  //读使能
    output wire [3 :0] inst_sram_wen,  //写使能
    output wire [31:0] inst_sram_addr,inst_sram_wdata,  //字寻址 写数据
    input  wire [31:0] inst_sram_rdata,  //读数据

    // data_mem
    output wire        data_sram_en,
    output wire [3 :0] data_sram_wen,
    output wire [31:0] data_sram_addr,data_sram_wdata,
    input  wire [31:0] data_sram_rdata,


    output wire [31:0] debug_wb_pc,debug_wb_rf_wdata,
    output wire [3 :0] debug_wb_rf_wen,
    output wire [4 :0] debug_wb_rf_wnum
    );

    wire [31:0] data_addr_temp;
    datapath datapath(
        .clk         (~clk),
        .rst         (~resetn),
        .ext_int     (ext_int),

        .inst_addrF  (inst_sram_addr),
        .inst_enF    (inst_sram_en),
        .instrF      (inst_sram_rdata),


        .mem_enM     (data_sram_en),
        .mem_addrM   (data_addr_temp),
        .mem_rdataM  (data_sram_rdata),
        .mem_wenM    (data_sram_wen),
        .mem_wdataM  (data_sram_wdata),
        .d_cache_stall(1'b0),

        .debug_wb_pc(debug_wb_pc),      
        .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum), 
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );
    assign inst_sram_wen     = 4'b0;
    assign inst_sram_wdata   = 32'b0;
    assign data_sram_addr    = data_addr_temp[31:16]==16'hbfaf ? {3'b0,data_addr_temp[28:0]} : data_addr_temp;
endmodule