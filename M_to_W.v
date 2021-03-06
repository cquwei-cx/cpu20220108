module M_to_W (
    input wire clk, rst,
    input wire stallW,
    input wire [31:0] pcM,
    input wire [31:0] alu_outM,
    input wire [4:0] reg_writeM,
    input wire reg_write_enM,
    input wire [31:0] mem_rdataM,
    input wire [31:0] resultM,


    output reg [31:0] pcW,
    output reg [31:0] alu_outW,
    output reg [4:0] reg_writeW,
    output reg reg_write_enW,
    output reg [31:0] mem_rdataW,
    output reg [31:0] resultW
);
    always @(posedge clk) begin
        if(rst) begin
            pcW <= 0;
            alu_outW <= 0;
            reg_writeW <= 0;
            reg_write_enW <= 0;
            mem_rdataW <= 0;
            resultW <= 0;
        end
        else if(~stallW) begin
            pcW <= pcM;
            alu_outW <= alu_outM;
            reg_writeW <= reg_writeM;
            reg_write_enW <= reg_write_enM;
            mem_rdataW <= mem_rdataM;
            resultW <= resultM;
        end
    end
endmodule