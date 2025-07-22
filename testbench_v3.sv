`timescale 1ns/1ps

module testbench;

localparam A = 2;
localparam B = 2;
localparam ADDR_WIDTH = $clog2(B);


reg clk = 0;
reg reset = 0;
reg [1:0] mode = 2;
reg [ADDR_WIDTH-1:0] column = 0; 
reg [A-1:0] data_in = 2'b11;
reg writing_successful = 1; 

wire [2*B-1:0] PL;
wire [B-1:0] BL;
wire [A-1:0] WLN;
wire [A-1:0] WLP;
wire PRG;
wire [A-1:0] data_out;
wire read_active;
wire output_read_circuit;



   //parameter of the modes
    localparam MODE_READING = 2'b00;
    localparam MODE_WRITING = 2'b01;
    localparam MODE_IDLE = 2'b10;
    //parameter of the voltage levels
    localparam BL_V_GND = 1'b0;
    localparam BL_V_MID = 1'b1;
    localparam [1:0] PL_V_GND = 2'b00;
    localparam PL_V_MID = 2'b01;
    localparam PL_V_READ = 2'b10;
    localparam PL_V_HIGH = 2'b11;
    localparam WLN_V_MID = 1'b0;                //WLN_V_MID für 5 V
    localparam WLN_V_GND = 1'b1;
    localparam WLP_V_HIGH = 1'b0;               //WLP_V_HIGH für 10 V
    localparam WLP_V_MID = 1'b1;                //WLP_V_MID für 5 V
    //parameter of the read_active output
    localparam READ_NOT_ACTIVE = 1'b0;
    localparam READ_ACTIVE = 1'b1;
    //parameter of the writing_sucessful input
    localparam WRITING_NOT_SUCCESSFUL = 1'b0;
    localparam WRITING_SUCCESSFUL = 1'b1;
    //parameter of the PRG output
    localparam PRG_READING = 1'b0;
    localparam PRG_WRITING = 1'b1;




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
    .output_read_circuit(output_read_circuit),
    .PL(PL),
    .BL(BL),
    .WLN(WLN),
    .WLP(WLP),
    .read_active(read_active),
    .data_out(data_out),
    .PRG(PRG)
);

integer i, j;
always@(negedge clk) begin
    for(i = 0; i <= A-1; i = i + 1) begin
        for(j = 0; j <= B-1; j = j + 1) begin
            //test if currently writing
            if((PRG == PRG_WRITING) && (WLP[i] == WLP_V_HIGH) && (WLN[i] == WLN_V_MID) && (BL[j] == BL_V_GND) && (PL[j*2+:2] == PL_V_HIGH)) begin
                $display("cell [%0d][%0d] was written", i, j);
            end
            //test if currently reading
            if((PRG == PRG_READING) && (WLP[i] == WLP_V_MID) && (WLN[i] == WLN_V_MID) && (BL[j] == BL_V_MID) && (PL[j*2+:2] == PL_V_READ)) begin
                $display("cell [%0d][%0d] was read", i, j);
            end
        end
    end
end

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, testbench);

    $display("testbench 1 begins");

    reset = 1;
    #2;
    reset = 0;
    #10; 
    mode = MODE_WRITING;
    #5;
    mode = MODE_IDLE;



    #200 $finish;
end


always #1 clk = ~clk;

endmodule