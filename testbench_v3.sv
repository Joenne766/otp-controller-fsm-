`timescale 1ns/1ps

module testbench;

localparam A = 2;
localparam B = 2;
localparam ADDR_WIDTH = $clog2(B);


reg clk = 0;
reg reset = 0;
reg [1:0] mode = 1;
reg [ADDR_WIDTH-1:0] column = 0; 
logic [A-1:0] data_in = 0;
reg writing_successful = 0; 

wire [2*B-1:0] PL;
wire [B-1:0] BL;
wire [A-1:0] WLN;
wire [A-1:0] WLP;
wire PRG;
wire [A-1:0] data_out;
wire read_active;






FSM #(
    .A(A), 
    .B(B)
)dut(
    .clk(clk),
    .reset(reset),
    .mode(mode),
    .column(column),
    .data_in(data_in),
    .writing_successful(writing_successful),
    .PL(PL),
    .BL(BL),
    .WLN(WLN),
    .WLP(WLP),
    .read_active(read_active),
    .data_out(data_out)
);

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, testbench);

    #200 $finish;
end


always #1 clk = ~clk;

endmodule