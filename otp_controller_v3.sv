//for this module to wok, the memory cell must have the size of at least (A>=2) && (B>=2) (because of state S_WRITE_ERROR_BIT_2)

module FSM #(
    //if not specified, then set A (number of rows) to 2
    parameter A = 2,
    //if not specified, then set B (number of columns) to 2
    B = 2,
    //ADDR_WIDTH = number of bits that are needed to address the columns
    ADDR_WIDTH = $clog2(B)

)(
    input clk, 
    //reset stops all current tasks and brings the FSM back to IDLE (possibly dangerous when currently writing)
    input reset, 
    //mode tells the FSM what to do, possible are reading with MODE_READING, writing with MODE_WRITING, and idle with MODE_IDLE
    input [1:0] mode, 
    //column = the specific address that is used when reading or writing (it is always the whole column that is read or written)
    input [ADDR_WIDTH-1:0] column, 
    //data_in is used for writing, each writing cycle writes one column
    input [A-1:0] data_in, 
    //writing_successful is a signal from the analog circuit part that shows if a cell was written successfully
    input writing_successful,
    //output_read_circuit is the output of the read circuit and shows if the cell was written or not
    input output_read_circuit,
    //PL = powerlines, one powerline for each column, each powerline needs 2 bits
    output [2*B-1:0] PL,
    //BL = bitlines, one bitline for each column, each bitline needs 1 bit
    output [B-1:0] BL,
    output [A-1:0] AT,
    output [A-1:0] FP,
    //PRG must be PRG_READING for reading or PRG_WRITING for writing
    output PRG,
    //data_out is the output of the addressed column after a reading cycle 
    output [A-1:0] data_out,
    //read_active is 1 when you can use the data_out after a reading cycle, else 0
    output read_active
    );

    //parameter of the modes
    localparam MODE_READING = 2'b00;
    localparam MODE_WRITING = 2'b01;
    localparam MODE_IDLE = 2'b10;
    //parameter of the voltage levels
    localparam BL_V_GND = 1'b0;
    localparam BL_V_MID = 1'b1;
    localparam PL_V_MID = 2'b01;
    localparam PL_V_READ = 2'b10;
    localparam PL_V_HIGH = 2'b11;
    localparam AT_V_MID = 1'b0;                
    localparam AT_V_GND = 1'b1;
    localparam FP_V_HIGH = 1'b0;               
    localparam FP_V_MID = 1'b1;           
    //parameter of the read_active output
    localparam READ_NOT_ACTIVE = 1'b0;
    localparam READ_ACTIVE = 1'b1;
    //parameter of the writing_sucessful input
    localparam WRITING_NOT_SUCCESSFUL = 1'b0;
    localparam WRITING_SUCCESSFUL = 1'b1;
    //parameter of the PRG output
    localparam PRG_V_GND = 1'b0;
    localparam PRG_V_D = 1'b1;
    



    localparam [6:0]
        S_STANDBY = 0,
        S_COLLECT_DATA_1 = 1,
        S_COLLECT_DATA_2 = 2,
        S_COMPARE_DATA = 3,
        S_PREPARE_WRITING = 4,
        S_FIND_NEXT_BIT = 9,
        S_WRITING_1 = 10,
        S_WRITING_2 = 11, 
        S_DESELECT_CELL_WRITING_1 = 12,
        S_DESELECT_CELL_WRITING_2 = 13,
        S_POWER_DOWN_1 = 14,
        S_POWER_DOWN_2 = 15,
        S_POWER_DOWN_3 = 5,
        S_WRITING_WAITING_FOR_SIGNAL = 16,
        S_PREPARE_READING_1 = 17,
        S_PREPARE_READING_2 = 18,
        //S_PREPARE_READING_2 = 18,
        //S_PREPARE_READING_3 = 19,
        S_GO_NEXT_CELL = 20,
        S_READING = 21,
        //S_DESELECT_CELL_READING = 22,
        S_READING_POSSIBLE = 23,
        S_NO_FALSE_BITS_Q = 24,
        S_WRITE_ERROR_BIT = 25,
        S_WRITE_ERROR_BIT_1 = 27,
        S_WRITE_ERROR_BIT_2 = 28,
        S_WRITE_ERROR_BIT_3 = 29,
        S_WRITE_ERROR_BIT_4 = 30,
        S_WRITE_ERROR_BIT_5 = 31,
        S_WRITE_ERROR_BIT_6 = 32,
        S_WRITE_ERROR_BIT_7 = 33,
        S_WRITE_ERROR_BIT_8 = 34,
        S_WRITE_ERROR_BIT_9 = 35,
        S_WRITE_ERROR_BIT_10 = 36,
        S_WRITE_ERROR_BIT_11 = 37,
        S_DESELECT_CELL_READING_1 = 38,
        S_DESELECT_CELL_READING_2 = 39;

    reg [5:0] state;
    reg [2*B-1:0] PL_reg;          
    reg [B-1:0] BL_reg;       
    reg [A-1:0] AT_reg;
    reg [A-1:0] FP_reg;
    reg read_active_reg;
    reg [A-1:0] data_out_reg;
    reg [A-1:0] data_in_reg_1;
    reg [A-1:0] data_in_reg_2;
    reg [A-1:0] data_in_reg;
    reg [B-1:0] BL_reg_PREPARE_WRITING_2;
    reg [2*B-1:0] PL_reg_PREPARE_WRITING_2;
    reg PRG_reg;
    reg writing_successful_reg;
    reg [1:0] mode_reg;

    assign BL = BL_reg;
    assign PL = PL_reg;
    assign AT = AT_reg;
    assign FP = FP_reg;
    assign read_active = read_active_reg;
    assign data_out = data_out_reg;
    assign PRG = PRG_reg;

    //intern signals
    reg [$clog2(A):0] counter;
    reg [$clog2(A):0] write_row;
    reg [$clog2(A):0] read_row;

   


   


    always@(posedge clk) begin 
        if (reset) begin
            state <= S_IDLE;
        end else begin
            if(state == S_IDLE) begin
                mode_reg <= mode;
            end
            case (state) 

                S_STANDBY: begin
                    $display ("state = S_STANDBY");
                    //set default conditions
                    //set all BL to V_MID
                    BL_reg <= {B{BL_V_MID}};
                    //set all PL to V_MID
                    PL_reg <= {B{PL_V_MID}};
                    //set all AT to V_GND
                    AT_reg <= {A{AT_V_GND}};
                    //set all FP to V_MID
                    FP_reg <= {A{FP_V_MID}};
                    //set read_active to READ_NOT_ACTIVE
                    read_active_reg <= READ_NOT_ACTIVE;
                    //set PRG to V_D
                    PRG_reg <= PRG_V_D;
                    //set writing_successful to WRITING_NOT_SUCCESSFUL
                    writing_successful_reg <= WRITING_NOT_SUCCESSFUL;
                    //reset internal signals
                    counter <= 0;
                    write_row <= 0;
                    read_row <= 0;
                    data_in_reg_1 <= 0;
                    data_in_reg_2 <= 0;
                    data_in_reg <= 0;
                    data_out_reg <= 0;
                    BL_reg_PREPARE_WRITING_2 <= {B{BL_V_GND}};
                    PL_reg_PREPARE_WRITING_2 <= {B{PL_V_GND}};
                    //next state
                    if(mode == MODE_READING) begin
                        state <= S_PREPARE_READING;
                    end else if(mode == MODE_WRITING) begin
                        state <= S_COLLECT_DATA_1;
                    end else if(mode == MODE_STANDBY) begin
                        state <= S_STANDBY;
                    end else begin
                        $display("WARNUNG: Ungültiger mode = %b", mode);
                    end
                end

                S_COLLECT_DATA_1: begin
                    $display("state = S_COLLECT_DATA_1");
                    data_in_reg_1 <= data_in;
                    //next state
                    state <= S_COLLECT_DATA_2;
                end

                S_COLLECT_DATA_2: begin
                    data_in_reg_2 <= data_in;
                    //next state
                    state <= S_COMPARE_DATA;
                end

                S_COMPARE_DATA: begin
                    $display("state = S_COMPARE_DATA");
                    //next state
                    if(data_in_reg_1 == data_in_reg_2) begin
                        data_in_reg <= data_in_reg_1;
                        state <= S_PREPARE_WRITING_1;
                    end else begin
                        state <= S_COLLECT_DATA_1;
                    end
                end

                S_PREPARE_WRITING: begin
                    $display("state = S_PREPARE_WRITING");
                    //set PL of selected cell to V_HIGH
                    PL_reg[column] <= PL_V_HIGH;
                    //set PRG to writing
                    PRG_reg <= PRG_WRITING;
                    //next state
                    state <= S_PREPARE_WRITING_2;
                end

                S_FIND_NEXT_BIT: begin
                    $display("state = S_FIND_NEXT_BIT");
                    if(counter >= A-1) begin
                        //next state
                        //writing finished
                        state <= S_POWER_DOWN_1;
                    end else if(data_in_reg[counter] == 1'b1) begin
                        //set the correct write_row
                        write_row <= counter;
                        //next state
                        state <= S_WRITING_1;
                    end else begin
                        //look at the next bit
                        counter <= counter + 1;
                        //next state
                        state <= S_FIND_NEXT_BIT;
                    end
                end

                S_WRITING_1: begin
                    $display("state = S_WRITING_1");
                    //set selected WLP to 10 V
                    WLP_reg[write_row] <= WLP_V_HIGH;
                    //next state
                    state <= S_WRITING_2;
                end

                S_WRITING_2: begin
                    //set selected WLN to 5 V
                    WLN_reg[write_row] <= WLN_V_MID;
                    writing_successful_reg <= writing_successful;
                    //next state
                    state <= S_WRITING_WAITING_FOR_SIGNAL;
                end

                S_WRITING_WAITING_FOR_SIGNAL: begin
                    $display("state = S_WRITING_WAITING_FOR_SIGNAL");
                    //next state
                    //only go to S_DESELECT_CELL_WRITING after successful writing
                    if(writing_successful_reg || writing_successful) begin
                        //cell was written correctly
                        state <= S_DESELECT_CELL_WRITING_1;
                    end else begin
                        //cell was not yet written
                        //TODO deal with possible endless loops
                        state <= S_WRITING_2;
                    end
                end

                S_DESELECT_CELL_WRITING_1: begin
                    $display("state = S_DESELECT_CELL_WRITING_1");
                    //set selected WLN to 0 V
                    WLN_reg[write_row] <= WLN_V_GND;
                    //next state
                    state <= S_DESELECT_CELL_WRITING_2;
                end

                S_DESELECT_CELL_WRITING_2: begin
                    //set selected WLP to 5 V
                    WLP_reg[write_row] <= WLP_V_MID;
                    //this cell is finished, go next
                    counter <= counter + 1;
                    //next state 
                    state <= S_FIND_NEXT_BIT;
                end

                S_POWER_DOWN_1: begin
                    $display("state = S_POWER_DOWN_1");
                    //set selected PL/BL to 0 V
                    PL_reg[2*column+:2] <= PL_V_GND;
                    BL_reg[column] <= BL_V_GND;
                    //next state
                    state <= S_POWER_DOWN_2;
                end

                S_POWER_DOWN_2: begin
                    //set unselected PL/BL to 0 V
                    //since PL and BL of selected cells are already at 0 V, all
                    //PL and BL are set to 0 V
                    PL_reg <= {B{PL_V_GND}};
                    BL_reg <= {B{BL_V_GND}};
                    //next state
                    state <= S_PREPARE_READING;
                end

                S_PREPARE_READING: begin
                    $display("state = S_PREPARE_READING");
                    //reset counter
                    counter <= 0;
                    //set selected BL to 5 V
                    BL_reg[column] <= BL_V_MID;
                    //set PRG to 0 V
                    PRG_reg <= PRG_READING;
                    //set selected PL to 1.8 V
                    PL_reg[2*column+:2] <= PL_V_READ;
                    //next state
                    state <= S_GO_NEXT_CELL;
                end

                S_GO_NEXT_CELL: begin
                    $display("state = S_GO_NEXT_CELL");
                    if((read_row >= A-1) && (mode_reg == MODE_READING)) begin
                        //reading is finished
                        //next state
                        state <= S_READING_POSSIBLE;
                    end else if ((read_row >= A-1) && (mode_reg == MODE_WRITING)) begin
                        //proofreading is finished
                        //next state
                        state <= S_NO_FALSE_BITS_Q;
                    end else if (mode_reg == MODE_IDLE) begin
                        $display("ERROR! mode_reg changed");
                    end else begin
                        //reading or proofreading not finished yet
                        //next state
                        state <= S_READING_1;
                    end
                end

                S_READING_1: begin
                    $display("state = S_READING_1");
                    //set selected WLN to 5 V
                    WLN_reg[read_row] <= WLN_V_MID;
                    //next state
                    state <= S_READING_2;
                end

                S_READING_2: begin
                    //save output_read_circuit
                    data_out_reg[read_row] <= output_read_circuit;
                    //next state
                    state <= S_DESELECT_CELL_READING_1;
                end


                S_DESELECT_CELL_READING_1: begin
                    $display("state = S_DESELECT_CELL_READING_1");
                    //set selected WLN to 0 V
                    WLN_reg[read_row] <= WLN_V_GND;
                    //next state
                    state <= S_DESELECT_CELL_READING_2;
                end

                S_DESELECT_CELL_READING_2: begin
                    //next time read the following cell
                    read_row <= read_row + 1;
                    //next state
                    state <= S_GO_NEXT_CELL;
                end

                S_READING_POSSIBLE: begin
                    $display("state = S_READING_POSSIBLE");
                    //reading is now possible
                    read_active_reg <= READ_ACTIVE;
                    //next state
                    state <= S_IDLE;
                end

                S_NO_FALSE_BITS_Q: begin
                    $display("state = S_NO_FALSE_BITS_Q");
                    if(data_out_reg == data_in_reg) begin
                        //everything correct, finish writing algorithm
                        //next state
                        state <= S_IDLE;
                    end else begin
                        //a mistake was found
                        //next state
                        state <= S_WRITE_ERROR_BIT_1;
                    end
                end

                S_WRITE_ERROR_BIT_1: begin
                    $display("state = S_WRITE_ERROR_BIT_1");
                    //set all WLN to 5 V
                    WLN_reg <= {A{WLN_V_MID}};
                    //set PRG to writing mode
                    PRG_reg <= PRG_WRITING;
                    //next state
                    state <= S_WRITE_ERROR_BIT_2;
                end

                S_WRITE_ERROR_BIT_2: begin
                    //set all unselected BL/PL to 5 V
                    BL_reg <= BL_reg_PREPARE_WRITING_2;
                    PL_reg <= PL_reg_PREPARE_WRITING_2;
                    //next state
                    state <= S_WRITE_ERROR_BIT_3;
                end

                S_WRITE_ERROR_BIT_3: begin
                    //set all WLN to 0 V
                    WLN_reg <= {A{WLN_V_GND}};
                    //next state
                    state <= S_WRITE_ERROR_BIT_4;
                end

                S_WRITE_ERROR_BIT_4: begin
                    //set selected PL to 10 V
                    PL_reg[column*2+:2] <= PL_V_HIGH;
                    //next state
                    state <= S_WRITE_ERROR_BIT_5;
                end

                S_WRITE_ERROR_BIT_5: begin
                    //set last WLP to 10 V
                    WLP_reg[A-1] <= WLP_V_HIGH;
                    //next state 
                    state <= S_WRITE_ERROR_BIT_6;
                end

                S_WRITE_ERROR_BIT_6: begin
                    //set last WLN to 5 V
                    WLN_reg[A-1] <= WLN_V_MID;
                    //was writing successful
                    if(writing_successful) begin
                        writing_successful_reg <= writing_successful;
                    end
                    //next state
                    state <= S_WRITE_ERROR_BIT_7;
                end

                S_WRITE_ERROR_BIT_7: begin
                    //next state
                    if(writing_successful_reg || writing_successful) begin
                        //cell was written correctly
                        state <= S_WRITE_ERROR_BIT_8;
                    end else begin
                        //cell was not yet written
                        //TODO deal with possible endless loops
                        state <= S_WRITE_ERROR_BIT_6;
                    end
                end

                S_WRITE_ERROR_BIT_8: begin
                    //set last WLN to 0 V
                    WLN_reg[A-1] <= WLN_V_GND;
                    //next state 
                    state <= S_WRITE_ERROR_BIT_9;
                end

                S_WRITE_ERROR_BIT_9: begin
                    //set last WLP to 5 V
                    WLP_reg[A-1] <= WLP_V_MID;
                    //next state
                    state <= S_WRITE_ERROR_BIT_10;
                end

                S_WRITE_ERROR_BIT_10: begin
                    //set selected PL/BL to 0 V
                    PL_reg[2*column+:2] <= PL_V_GND;
                    BL_reg[column] <= BL_V_GND;
                    //next state
                    state <= S_WRITE_ERROR_BIT_11;
                end

                S_WRITE_ERROR_BIT_11: begin
                    //set other PL/BL to 0 V
                    //since PL and BL of selected cells are already at 0 V, all
                    //PL and BL are set to 0 V
                    PL_reg <= {B{PL_V_GND}};
                    BL_reg <= {B{BL_V_GND}};
                    //next state
                    state <= S_IDLE;
                end









                    

                    









            endcase
        end
    end

endmodule