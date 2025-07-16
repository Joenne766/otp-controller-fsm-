module FSM #(
    //parameter of the FSM
    parameter A = 2,                  
    parameter B = 2,         
    parameter COLUMN_ADDRESS = $clog2(B),
    //parameter of the modes
    parameter MODE_READING = 2'b00,
    parameter MODE_WRITING = 2'b01,
    parameter MODE_IDLE = 2'b10,
    //parameter of the voltage levels
    parameter BL_V_GND = 1'b0,
    parameter BL_V_MID = 1'b1,
    parameter PL_V_GND = 2'b00,
    parameter PL_V_MID = 2'b01,
    parameter PL_V_READ = 2'b10,
    parameter PL_V_HIGH = 2'b11,
    parameter WLN_V_MID = 1'b0,         //WLN_V_MID für 5 V
    parameter WLN_V_GND = 1'b1,
    parameter WLP_V_HIGH = 1'b0,        //WLP_V_HIGH für 10 V
    parameter WLP_V_MID = 1'b1,         //WLP_V_MID für 5 V
    //parameter of the read_active output
    parameter READ_NOT_ACTIVE = 1'b0,
    parameter READ_ACTIVE = 1'b1,
    //parameter of the writing_sucessful input
    parameter WRITING_NOT_SUCCESSFUL = 1'b0,
    parameter WRITING_SUCCESSFUL = 1'b1
)(
    input clk,
    input reset,
    input [1:0] mode,
    input [COLUMN_ADDRESS-1:0] column,
    input [A-1:0] data_in, 
    input writing_successful, 
    output [2*B-1:0] PL, 
    output [B-1:0] BL,
    output [A-1:0] WLN,
    output [A-1:0] WLP,
    output read_active,
    output [A-1:0] data_out
);

    localparam [4:0]
                IDLE = 0,
                FIND_FIRST_BIT = 1,
                WRITING_COLLECT_DATA = 2,
                WRITING_COMPARE_DATA = 3,
                WRITE_STEP_1 = 4,
                WRITE_STEP_2 = 5,
                WRITE_STEP_3 = 6,
                WRITE_STEP_4 = 7,
                WRITE_STEP_5 = 8,
                WRITE_STEP_6 = 9,
                WRITE_NEXT_ROW_STEP_1 = 10,
                WRITE_NEXT_ROW_STEP_2 = 11,
                WRITE_NEXT_ROW_STEP_3 = 12,
                WRITE_NEXT_ROW_STEP_4 = 13,
                WRITING_FINISHED_Q = 14,
                POWER_DOWN_STEP_1 = 15,
                POWER_DOWN_STEP_2 = 16,
                POWER_DOWN_STEP_3 = 17,
                POWER_DOWN_STEP_4 = 18,
                PREPARE_READING = 19,
                READ_STEP_2 = 20,
                READ_STEP_3 = 21,
                READING_FINISHED_Q = 22,
                READING_POSSIBLE = 23,
                PREPARE_WRITING = 24;
    
    reg [4:0] state;
    reg [2*B-1:0] PL_reg;          
    reg [B-1:0] BL_reg;       
    reg [A-1:0] WLN_reg;
    reg [A-1:0] WLP_reg;
    reg read_active_reg;
    reg [A-1:0] data_out_reg;
    reg [A-1:0] data_in_reg;
    reg [B-1:0] BL_reg_WRITE_STEP_2;
    reg [2*B-1:0] PL_reg_WRITE_STEP_2;
    reg [A-1:0] data_out_reg_in_progress;
    assign BL = BL_reg;
    assign PL = PL_reg;
    assign WLN = WLN_reg;
    assign WLP = WLP_reg;
    assign read_active = read_active_reg;
    assign data_out = data_out_reg;
    
    //intern signals
    reg [$clog2(A):0] counter;
    reg [$clog2(A):0] write_row;
    reg [$clog2(A):0] read_row;

    initial begin
        $display ("Starting FSM"); 
    end
    
    //prepare for-loop for WRITE_STEP_2
    integer i;
    always@(*) begin
        BL_reg_WRITE_STEP_2 = BL_reg;
        PL_reg_WRITE_STEP_2 = PL_reg;
        //set BL & PL of unselected cells to 5 V
        for(i = 0; i <= B-1; i = i + 1) begin
            if(i != column) begin
                BL_reg_WRITE_STEP_2[i] = BL_V_MID;
                PL_reg_WRITE_STEP_2[2*i +: 2] = PL_V_MID;
            end
        end
    end
    
    
    always@(posedge clk) begin
        if (reset) begin
            counter <= 0;
            state <= IDLE;
        end else begin
            case (state)
        
                IDLE: begin
                    $display ("state = IDLE");
                    //set default conditions
                    BL_reg <= {B{BL_V_GND}};
                    PL_reg <= {B{PL_V_GND}};
                    WLN_reg <= {A{WLN_V_GND}};
                    WLP_reg <= {A{WLP_V_MID}};
                    read_active_reg <= READ_NOT_ACTIVE;
                    write_row <= 0;
                    //next state
                    if(mode == MODE_READING) begin
                        state <= READ_STEP_2;
                    end else if(mode == MODE_WRITING) begin
                        state <= PREPARE_WRITING;
                    end else if(mode == MODE_IDLE) begin
                        state <= IDLE;
                    end else begin
                        $display("WARNUNG: Ungültiger mode = %b", mode);
                    end
                end
                
                PREPARE_WRITING: begin
                    $display("state = PREPARE_WRITING");
                    counter <= 0;
                    //next state
                    state <= WRITING_COMPARE_DATA;
                end
                
                WRITING_COLLECT_DATA: begin
                    $display("state = WRITING_COLLECT_DATA");
                    data_in_reg <= data_in;
                    //next state
                    state <= WRITING_COMPARE_DATA;
                end
                
                WRITING_COMPARE_DATA: begin
                    $display("state = WRITING_COMPARE_DATA");
                    //next state
                    if(data_in_reg == data_in) begin
                        state <= FIND_FIRST_BIT;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                FIND_FIRST_BIT: begin
                    $display("state = FIND_FIRST_BIT");
                    //select the correct write_row (in case beginning bits are 0)
                    if(counter >= A) begin
                        write_row <= 0;
                        //all Bits are "zero", back to IDLE
                        state <= IDLE;
                    end else if(data_in_reg[counter] == 1'b1) begin
                        write_row <= counter;
                        //first "one" was found
                        state <= WRITE_STEP_1;
                    end else begin
                        //no "one" was found yet
                        counter <= counter + 1;
                        state <= FIND_FIRST_BIT;
                    end
                end
                
                WRITE_STEP_1: begin
                    $display ("state = WRITE_STEP_1");
                    //1. set all WLN to 5 V
                    WLN_reg <= {A{WLN_V_MID}};
                    //next state
                    state <= WRITE_STEP_2;
                end
                
                WRITE_STEP_2: begin
                    $display ("state = WRITE_STEP_2");
                    //2. set BL and PL of unselected cells to 5 V
                    BL_reg <= BL_reg_WRITE_STEP_2;
                    PL_reg <= PL_reg_WRITE_STEP_2;
                    //next state
                    state <= WRITE_STEP_3;
                end
                
                WRITE_STEP_3: begin
                    $display ("state = WRITE_STEP_3");
                    //3. resetting all WLN to 0 V
                    WLN_reg <= {A{WLN_V_GND}};
                    //next state
                    state <= WRITE_STEP_4;
                end
                
                WRITE_STEP_4: begin
                    $display ("state = WRITE_STEP_4");
                    //4. set PL of selected cells to 10 V
                    PL_reg[column*2+:2] <= PL_V_HIGH;
                    //next state
                    state <= WRITE_STEP_5;
                end
                
                WRITE_STEP_5: begin
                    $display ("state = WRITE_STEP_5");
                    //5. set WLP of selected cells to 10 V
                    WLP_reg[write_row] <= WLP_V_HIGH;
                    //next state
                    state <= WRITE_STEP_6;
                end
                
                WRITE_STEP_6: begin
                    $display ("state = WRITE_STEP_6");
                    //6. set WLN of selected cells to 5 V
                    WLN_reg[write_row] <= WLN_V_MID;
                    if(write_row + 1 <= A - 1) begin
                        //choose next write_row
                        write_row <= write_row + 1;
                        //next state
                        state <= WRITE_NEXT_ROW_STEP_1;
                    end else begin
                        //writing finished
                        write_row <= 0;
                        //next state
                        state <= POWER_DOWN_STEP_1;
                    end
                end
                
                WRITE_NEXT_ROW_STEP_1: begin
                    $display ("state = WRITE_NEXT_ROW_STEP_1");
                    //set WLN of previous selected cell to 0 V
                    WLN_reg[write_row-1] <= WLN_V_GND;
                    //next state
                    state <= WRITE_NEXT_ROW_STEP_2;
                end
                
                WRITE_NEXT_ROW_STEP_2: begin
                    $display ("state = WRITE_NEXT_ROW_STEP_2");
                    //set WLP of previous selected cell to 5 V
                    WLP_reg[write_row-1] <= WLP_V_MID;
                    //next state
                    state <= WRITE_NEXT_ROW_STEP_3;
                end
                
                WRITE_NEXT_ROW_STEP_3: begin
                    $display ("state = WRITE_NEXT_ROW_STEP_3");
                    //set WLP of selected cell to 10 V
                    WLP_reg[write_row] <= WLP_V_HIGH;
                    //next state
                    state <= WRITE_NEXT_ROW_STEP_4;
                end
                
                WRITE_NEXT_ROW_STEP_4: begin
                    $display ("state = WRITE_NEXT_ROW_STEP_4");
                    //set WLN of selected cell to 5 V
                    WLN_reg[write_row] <= WLN_V_MID;
                    //next state
                    state <= WRITING_FINISHED_Q;
                end
                
                WRITING_FINISHED_Q: begin
                    $display ("state = WRITING_FINISHED_Q");
                    //next state
                    if(write_row >= A-1) begin
                        //writing is finished, beginning to power down
                        state <= POWER_DOWN_STEP_1;
                    end else begin
                        //writing not finished
                        //select next write_row
                        write_row <= write_row + 1;
                        //next state
                        state <= WRITE_NEXT_ROW_STEP_1;
                    end
                end
                
                POWER_DOWN_STEP_1: begin 
                    $display ("state = POWER_DOWN_STEP_1");
                    //set WLN of selected cell to 0 V
                    WLN_reg[write_row] <= WLN_V_GND;
                    //next state
                    state <= POWER_DOWN_STEP_2;
                end
                
                POWER_DOWN_STEP_2: begin
                    $display ("state = POWER_DOWN_STEP_2");
                    //set WLP of selected cell to 5 V
                    WLP_reg[write_row] <= WLP_V_MID;
                    //next state
                    state <= POWER_DOWN_STEP_3;
                end
                
                POWER_DOWN_STEP_3: begin
                    $display ("state = POWER_DOWN_STEP_3");
                    //set PL and BL of selected cells to 0 V
                    PL_reg[2*column+:2] <= PL_V_GND;
                    BL_reg[column] <= BL_V_GND;
                    //next state
                    state <= POWER_DOWN_STEP_4;
                end
                
                POWER_DOWN_STEP_4: begin
                    $display ("state = POWER_DOWN_STEP_4");
                    //set PL and BL of unselected cells to 0 V
                    //since PL and BL of selected cells are already at 0 V, all
                    //PL and BL are set to 0 V
                    PL_reg <= {B{PL_V_GND}};
                    BL_reg <= {B{BL_V_GND}};
                    //next state
                    state <= IDLE;
                end
                
                PREPARE_READING: begin
                    $display ("state = PREPARE_READING");
                    read_row <= 0;
                    //next state
                    state <= IDLE;
                end
                
                READ_STEP_2: begin
                    $display ("state = READ_STEP_2");
                    //set Powerline from selected cell to 1.8 V
                    PL_reg[2*column+:2] <= PL_V_READ;
                    //next state
                    state <= READ_STEP_3;
                end
                
                READ_STEP_3: begin
                    $display ("state = READ_STEP_3");
                    //set WLN of the selected cells to 5 V
                    WLN_reg[read_row] <= WLN_V_MID;
                    //next state
                    state <= READING_FINISHED_Q;
                end
                
                READING_FINISHED_Q: begin
                    $display ("state = READING_FINISHED_Q");
                    

            endcase
        
        end
    end
    
    
endmodule




module tb;

    reg clk = 0;
    reg reset = 0;
    reg [1:0] mode = 2'b01;
    reg [2:0] column = 0;
    reg [8-1:0] data_in = 8'b10101110;
    reg writing_successful = 0;

    wire [2*8-1:0] PL;
    wire [8-1:0] BL;
    wire [8-1:0] WLN;
    wire [8-1:0] WLP;
    wire read_active;
    wire [8-1:0] data_out;
    

    FSM #(.A(8), .B(8)) dut(
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
    
    always #1 clk = ~clk;
    
    initial begin
        $display("Starte Testbench");
        reset = 1;
        #2 reset = 0;
        #50 $finish;
    end
    
endmodule