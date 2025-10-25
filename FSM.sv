module FSM #(
    //if not specified, then set A (number of rows) to 3
    parameter A = 3,
    //if not specified, then set B (number of columns) to 2
    B = 2,
    //ADDR_WIDTH = number of bits that are needed to address the columns
    ADDR_WIDTH = $clog2(B)

)(
    input clk, 
    //reset stops all current tasks and brings the FSM back to S_STANDBY (first it goes over 
    // S_POWER_DOWN_RESET_1 and S_POWER_DOWN_RESET_2 and then it goes to S_STANDBY)
    input reset, 
    //mode tells the FSM what to do, possible are reading with MODE_READING, writing with 
    //MODE_WRITING, and idle with MODE_IDLE
    input [1:0] mode, 
    //column = the specific address that is used when reading or writing (it is always the whole 
    //column that is read or written)
    input [ADDR_WIDTH-1:0] column, 
    //data_in is used for writing, each writing cycle writes one column
    input [A-2:0] data_in, 
    //writing_successful is a signal from the analog circuit part that shows if a cell was 
    //written successfully
    input writing_successful,
    //output_read_circuit is the output of the read circuit and shows if the cell was written or not
    input output_read_circuit,
    //PL = powerlines, one powerline for each column, each powerline needs 2 bits
    output [2*B-1:0] PL,
    //BL = bitlines, one bitline for each column, each bitline needs 1 bit
    output [B-1:0] BL,
    output [A-1:0] AT,
    output [A-1:0] FP,
    //PRG must be PRG_READING for reading or PRG_WRITING for writing (or PRG_IDLE)
    output PRG,
    //data_out is the output of the addressed column after a reading cycle 
    output [A-1:0] data_out,
    //read_active is 1 when it is possible to use the data_out after a reading cycle, else 0
    output read_active, 
    //done = 1 when finished (for 1 tact), 0 when not finished
    output done
    );

    //parameter of the modes
    localparam MODE_READING = 2'b00;
    localparam MODE_WRITING = 2'b01;
    localparam MODE_IDLE = 2'b10;
    //parameter of the voltage levels
    localparam BL_V_GND = 1'b0;
    localparam BL_V_MID = 1'b1;
    localparam PL_V_READ = 2'b00;
    localparam PL_V_MID = 2'b01;
    localparam PL_V_HIGH = 2'b11;
    localparam AT_V_GND = 1'b0;
    localparam AT_V_MID = 1'b1;
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
    //parameter of done
    localparam DONE = 1'b1;
    localparam NOT_DONE = 1'b0;
    



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
        S_GO_NEXT_CELL = 20,
        S_READING_1 = 21,
        S_READING_2 = 22,
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
        S_DESELECT_CELL_READING_2 = 39,
        S_POWER_DOWN_RESET_1 = 40,
        S_POWER_DOWN_RESET_2 = 41,
        S_FIND_NEXT_FALSE_BIT = 42,
        S_WRITE_FALSE_BIT_1 = 43,
        S_WRITE_FALSE_BIT_2 = 44,
        S_WRITE_FALSE_BIT_3 = 45,
        S_WRITE_FALSE_BIT_4 = 46,
        S_WRITE_FALSE_BIT_5 = 47,
        S_WRITE_FALSE_BIT_6 = 48,
        S_WRITE_FALSE_BIT_7 = 49,
        S_WRITE_FALSE_BIT_8 = 50,
        S_WRITE_FALSE_BIT_9 = 51,
        S_WRITE_FALSE_BIT_10 = 52,
        S_WRITE_FALSE_BIT_11 = 53;

    reg [5:0] state;
    reg [2*B-1:0] PL_reg;          
    reg [B-1:0] BL_reg;       
    reg [A-1:0] AT_reg;
    reg [A-1:0] FP_reg;
    reg read_active_reg;
    reg [A-1:0] data_out_reg;
    //data_in_reg_1 and data_in_reg_2 are set in COLLECT_DATA to data_in and compared with each other
    //in COMPARE_DATA. If they are the same, then data_in_reg will be set. 
    reg [A-2:0] data_in_reg_1;
    reg [A-2:0] data_in_reg_2;
    reg [A-2:0] data_in_reg;
    reg [B-1:0] BL_reg_PREPARE_WRITING_2;
    reg [2*B-1:0] PL_reg_PREPARE_WRITING_2;
    reg PRG_reg;
    reg writing_successful_reg;
    reg [1:0] mode_reg;
    reg done_reg;

    assign BL = BL_reg;
    assign PL = PL_reg;
    assign AT = AT_reg;
    assign FP = FP_reg;
    assign read_active = read_active_reg;
    assign data_out = data_out_reg;
    assign PRG = PRG_reg;
    assign done = done_reg;

    //intern signals
    reg [$clog2(A):0] counter;
    reg [8:0] counter_waiting_for_signal;
    reg [$clog2(A):0] write_row;
    reg [$clog2(A):0] read_row;
    //column_reg is only updated in S_STANDBY to column_reg <= column. it is then 
    //used in writing or reading cycles so
    //that a change in the column is not possible while already reading/writing
    reg [$clog2(B)-1:0] column_reg;
    //mistake_was_found_reg is used in S_FIND_NEXT_FALSE_BIT and S_WRITE_FALSE_BIT
    reg mistake_was_found_reg;

   


   


    always@(posedge clk) begin 
        if (reset) begin
            mode_reg <= MODE_IDLE;
            state <= S_POWER_DOWN_RESET_1;
        end else begin
            

            case (state) 

                S_STANDBY: begin
                    mode_reg <= mode;
                    column_reg <= column;
                    //set default conditions
                    //set all BL to V_MID
                    BL_reg <= {B{BL_V_GND}};        
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
                    //set done to 0
                    done_reg <= NOT_DONE;
                    //reset internal signals
                    counter_waiting_for_signal <= 0;
                    counter <= 0;
                    write_row <= 0;
                    read_row <= 0;
                    data_in_reg_1 <= 0;
                    data_in_reg_2 <= 0;
                    data_in_reg <= 0;
                    data_out_reg <= 0;
                    BL_reg_PREPARE_WRITING_2 <= {B{BL_V_GND}};
                    PL_reg_PREPARE_WRITING_2 <= {B{PL_V_MID}};
                    done_reg <= 0;
                    mistake_was_found_reg <= 0;
                    //next state
                    if(mode == MODE_READING) begin
                        state <= S_PREPARE_READING_1;
                    end else if(mode == MODE_WRITING) begin
                        state <= S_COLLECT_DATA_1;
                    end else if(mode == MODE_IDLE) begin
                        state <= S_STANDBY;
                    end else begin
                        //$display("WARNUNG: Ungültiger mode = %b", mode);
                    end
                end

                S_COLLECT_DATA_1: begin
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
                    //next state
                    if(data_in_reg_1 == data_in_reg_2) begin
                        data_in_reg <= data_in_reg_1;
                        state <= S_PREPARE_WRITING;
                    end else begin
                        state <= S_COLLECT_DATA_1;
                    end
                end

                S_PREPARE_WRITING: begin
                    //set PL of selected cell to PL_V_HIGH      
                    PL_reg[column_reg*2+:2] <= PL_V_HIGH;
                    //set PRG to writing
                    PRG_reg <= PRG_V_D;
                    //next state
                    state <= S_FIND_NEXT_BIT;
                end

                S_FIND_NEXT_BIT: begin
                    if(counter >= A-1) begin        
                        //writing finished
                        //next state
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
                    //set FP from selected cell to FP_V_HIGH
                    FP_reg[write_row] <= FP_V_HIGH;
                    //next state
                    state <= S_WRITING_2;
                end

                S_WRITING_2: begin
                    //set AT of selected cell to AT_V_MID
                    AT_reg[write_row] <= AT_V_MID;
                    //set BL of selected cell to BL_V_MID
                    BL_reg[column_reg] <= BL_V_MID;
                    //save writing_successful
                    writing_successful_reg <= writing_successful;
                    //next state
                    state <= S_WRITING_WAITING_FOR_SIGNAL;
                end

                S_WRITING_WAITING_FOR_SIGNAL: begin
                    writing_successful_reg <= writing_successful;
                    //next state
                    //only go to S_DESELECT_CELL_WRITING after successful writing           
                    if(writing_successful_reg || writing_successful) begin
                        //cell was written correctly
                        //reset counter_waiting_for_signal
                        counter_waiting_for_signal <= 0;
                        //next state
                        state <= S_DESELECT_CELL_WRITING_1;
                    end else begin
                        //cell was not yet written
                        //deal with possible endless loops
                        if(counter_waiting_for_signal>300) begin
                            //something went wrong, back to S_STANDBY
                            done_reg <= DONE;
                            //next state
                            state <= S_STANDBY;
                        end else begin
                            
                            //wait longer
                            state <= S_WRITING_2;
                            counter_waiting_for_signal <= counter_waiting_for_signal + 1;
                        end
                        
                    end 
                end

                S_DESELECT_CELL_WRITING_1: begin
                    //set AT of selected cell to AT_V_GND
                    AT_reg[write_row] <= AT_V_GND;
                    //next state
                    state <= S_DESELECT_CELL_WRITING_2;
                end

                S_DESELECT_CELL_WRITING_2: begin
                    //set FP of selected cell to FP_V_MID
                    FP_reg[write_row] <= FP_V_MID;
                    //this cell is finished, go next
                    counter <= counter + 1;
                    //next state 
                    state <= S_FIND_NEXT_BIT;
                end

                S_POWER_DOWN_1: begin
                    //set selected BL to BL_V_GND
                    BL_reg[column_reg] <= BL_V_GND;
                    //next state
                    state <= S_POWER_DOWN_2;
                end

                S_POWER_DOWN_2: begin
                    //set selected PL to PL_V_MID
                    PL_reg[column_reg*2+:2] <= PL_V_MID;
                    //next state
                    state <= S_POWER_DOWN_3;
                end

                S_POWER_DOWN_3: begin
                    //set default conditions again
                    //set all BL to V_GND
                    BL_reg <= {B{BL_V_GND}};                
                    //set all PL to V_MID
                    PL_reg <= {B{PL_V_MID}};
                    //set all AT to V_GND
                    AT_reg <= {A{AT_V_GND}};
                    //set all FP to V_MID
                    FP_reg <= {A{FP_V_MID}};
                    //next state
                    state <= S_PREPARE_READING_1;
                end

                S_PREPARE_READING_1: begin
                    //reset counter
                    counter <= 0;
                    //set PRG to PRG_V_GND
                    PRG_reg <= PRG_V_GND;
                    //set PL of selected cell to PL_V_READ
                    PL_reg[2*column_reg+:2] <= PL_V_READ;
                    //next state
                    state <= S_PREPARE_READING_2;           
                end

                S_PREPARE_READING_2: begin
                    //set BL of selected cell to BL_V_MID
                    BL_reg[column_reg] <= BL_V_MID;
                    //next state
                    state <= S_GO_NEXT_CELL;
                end

                S_GO_NEXT_CELL: begin
                    if((read_row >= A) && (mode_reg == MODE_READING)) begin
                        //reading is finished
                        //since the ERROR_BIT must be also read, read_row is read from 0 to A-1
                        //next state
                        state <= S_READING_POSSIBLE;
                    end else if ((read_row >= A-1) && (mode_reg == MODE_WRITING)) begin
                        //proofreading is finished
                        //since the ERROR_BIT must not be read while proofreading, read_row is read 
                        //from 0 to A-2
                        //next state
                        state <= S_NO_FALSE_BITS_Q;
                    end else if (mode_reg == MODE_IDLE) begin
                        //error: it should not be possible to change mode_reg outside of S_STANDBY
                        //$display("ERROR! mode_reg changed");
                    end else begin
                        //reading or proofreading not finished yet
                        //next state
                        state <= S_READING_1;
                    end
                end

                S_READING_1: begin
                    //set AT of selected cell to AT_V_MID
                    AT_reg[read_row] <= AT_V_MID;
                    //next state
                    state <= S_READING_2;
                end

                S_READING_2: begin
                    //save output_read_circuit in data_out_reg
                    data_out_reg[read_row] <= output_read_circuit;
                    //next state
                    state <= S_DESELECT_CELL_READING_1;
                end


                S_DESELECT_CELL_READING_1: begin
                    //set AT of selected cell to AT_V_GND
                    AT_reg[read_row] <= AT_V_GND;
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
                    //reading is now possible
                    read_active_reg <= READ_ACTIVE;
                    //set done to DONE
                    done_reg <= DONE;
                    //next state
                    state <= S_STANDBY;
                end

                S_NO_FALSE_BITS_Q: begin
                    if(data_out_reg[A-2:0] == data_in_reg) begin       
                        //everything correct, finish writing algorithm
                        //set done to DONE
                        done_reg <= DONE;
                        //next state
                        state <= S_STANDBY;
                    end else begin
                        //a mistake was found
                        //reset counter because it is used in the next state
                        counter <= 0;
                        //next state
                        state <= S_FIND_NEXT_FALSE_BIT;
                    end
                end

                S_FIND_NEXT_FALSE_BIT: begin
                    if(counter >= A-1) begin        
                        //fixing process is finished
                        //if there is a mistake -> next state = S_WRITE_ERROR_BIT
                        //if everything is now fine -> next state = S_STANDBY
                        $display("fixing finished");
                        if(mistake_was_found_reg) begin
                            state <= S_WRITE_ERROR_BIT_1;
                        end else begin
                            done_reg <= DONE;
                            state <= S_STANDBY;
                        end
                    end else if(data_in_reg[counter] != data_out_reg[counter]) begin
                        //if the previously read row with the index 'counter' in data_out_reg is  
                        //different from the expected data_in_reg[counter]
                        if(data_in_reg[counter] == 1'b1) begin
                            //and it is also fixable (data_in_reg[counter] is 1 and 
                            //data_out_reg[counter] is 0)
                            //then fix it and go to S_WRITE_FALSE_BIT
                            //set the correct write_row
                            write_row <= counter;
                            //next state
                            state <= S_WRITE_FALSE_BIT_1;
                        end else begin
                            //if it is not fixable (the bit was written as 1, which cannot be reverted) just 
                            //go to the next bit and set mistake_was_found_reg to 1
                            mistake_was_found_reg <= 1;
                            //look at the next bit
                            counter <= counter + 1;
                            //next state
                            state <= S_FIND_NEXT_FALSE_BIT;
                        end
                    end else begin
                        //everything correct with the current bit with the index 'counter'
                        //look at the next bit
                        counter <= counter + 1;
                        //next state
                        state <= S_FIND_NEXT_FALSE_BIT;
                    end
                end

                S_WRITE_FALSE_BIT_1: begin
                    //set default conditions again
                    //set all BL to V_MID
                    BL_reg <= {B{BL_V_GND}};                
                    //set all PL to V_MID
                    PL_reg <= {B{PL_V_MID}};
                    //set all AT to V_GND
                    AT_reg <= {A{AT_V_GND}};
                    //set all FP to V_MID
                    FP_reg <= {A{FP_V_MID}};
                    //set writing_successful to WRITING_NOT_SUCCESSFUL
                    writing_successful_reg <= WRITING_NOT_SUCCESSFUL;
                    //next state
                    state <= S_WRITE_FALSE_BIT_2;
                end

                S_WRITE_FALSE_BIT_2: begin
                    //set PRG to PRG_V_D
                    PRG_reg <= PRG_V_D;
                    //next state
                    state <= S_WRITE_FALSE_BIT_3;
                end

                S_WRITE_FALSE_BIT_3: begin
                    //set PL of the current column to PL_V_HIGH
                    PL_reg[column_reg*2+:2] <= PL_V_HIGH;
                    //next state
                    state <= S_WRITE_FALSE_BIT_4;
                end

                S_WRITE_FALSE_BIT_4: begin
                    //set FP of the false bit (index write_row) to FP_V_HIGH
                    FP_reg[write_row] <= FP_V_HIGH;
                    //next state
                    state <= S_WRITE_FALSE_BIT_5;
                end

                S_WRITE_FALSE_BIT_5: begin
                    //set AT of the false bit (index write_row) to AT_V_MID
                    AT_reg[write_row] <= AT_V_MID;
                    //set BL of the current column to BL_V_MID
                    BL_reg[column_reg] <= BL_V_MID;          
                    //next state 
                    state <= S_WRITE_FALSE_BIT_6;
                end

                S_WRITE_FALSE_BIT_6: begin
                    //check if writing was successful
                    if(writing_successful) begin
                        writing_successful_reg <= writing_successful;
                    end
                    //next state
                    state <= S_WRITE_FALSE_BIT_7;
                end

                S_WRITE_FALSE_BIT_7: begin
                    //next state
                    if(writing_successful_reg || writing_successful) begin
                        //cell was written correctly
                        //reset counter_waiting_for_signal
                        counter_waiting_for_signal <= 0;
                        //next state
                        state <= S_WRITE_FALSE_BIT_8;
                    end else begin
                        //cell was not yet written
                        //deal with possible endless loops
                        if(counter_waiting_for_signal>300) begin
                            //something went wrong, back to S_STANDBY
                            done_reg <= DONE;
                            state <= S_STANDBY;
                        end else begin
                            //wait longer
                            state <= S_WRITE_FALSE_BIT_6;
                            counter_waiting_for_signal <= counter_waiting_for_signal + 1;
                        end
                    end
                end

                S_WRITE_FALSE_BIT_8: begin
                    //set AT of the false bit (index write_row) to AT_V_GND
                    AT_reg[write_row] <= AT_V_GND;
                    //next state 
                    state <= S_WRITE_FALSE_BIT_9;
                end

                S_WRITE_FALSE_BIT_9: begin
                    //set FP of the false bit (index write_row) to FP_V_MID
                    FP_reg[write_row] <= FP_V_MID;
                    //next state
                    state <= S_WRITE_FALSE_BIT_10;
                end

                S_WRITE_FALSE_BIT_10: begin
                    //set BL of the current column to BL_V_GND
                    BL_reg[column_reg] <= BL_V_GND;
                    //next state
                    state <= S_WRITE_FALSE_BIT_11;
                end

                S_WRITE_FALSE_BIT_11: begin
                    //set PL of the current column to PL_V_MID
                    PL_reg[(column_reg)*2+:2] <= PL_V_MID;
                    //check next bit in S_FIND_NEXT_FALSE_BIT
                    counter <= counter + 1;
                    //next state
                    state <= S_FIND_NEXT_FALSE_BIT;
                end

                S_WRITE_ERROR_BIT_1: begin
                    //set default conditions again
                    //set all BL to V_MID
                    BL_reg <= {B{BL_V_GND}};                
                    //set all PL to V_MID
                    PL_reg <= {B{PL_V_MID}};
                    //set all AT to V_GND
                    AT_reg <= {A{AT_V_GND}};
                    //set all FP to V_MID
                    FP_reg <= {A{FP_V_MID}};
                    //set writing_successful to WRITING_NOT_SUCCESSFUL
                    writing_successful_reg <= WRITING_NOT_SUCCESSFUL;
                    //next state
                    state <= S_WRITE_ERROR_BIT_2;
                end

                S_WRITE_ERROR_BIT_2: begin
                    //set PRG to PRG_V_D
                    PRG_reg <= PRG_V_D;
                    //next state
                    state <= S_WRITE_ERROR_BIT_3;
                end

                S_WRITE_ERROR_BIT_3: begin
                    //set PL of ERROR_BIT (current column) to PL_V_HIGH
                    PL_reg[column_reg*2+:2] <= PL_V_HIGH;
                    //next state
                    state <= S_WRITE_ERROR_BIT_4;
                end

                S_WRITE_ERROR_BIT_4: begin
                    //set FP of ERROR_BIT (index A-1) to FP_V_HIGH
                    FP_reg[A-1] <= FP_V_HIGH;
                    //next state
                    state <= S_WRITE_ERROR_BIT_5;
                end

                S_WRITE_ERROR_BIT_5: begin
                    //set AT of ERROR_BIT (index A-1) to AT_V_MID
                    AT_reg[A-1] <= AT_V_MID;
                    //set BL of ERROR_BIT (current column) to BL_V_MID
                    BL_reg[column_reg] <= BL_V_MID;          
                    //next state 
                    state <= S_WRITE_ERROR_BIT_6;
                end

                S_WRITE_ERROR_BIT_6: begin
                    //check if writing was successful
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
                        //reset counter_waiting_for_signal
                        counter_waiting_for_signal <= 0;
                        //next state
                        state <= S_WRITE_ERROR_BIT_8;
                    end else begin
                        //cell was not yet written
                        //deal with possible endless loops
                        if(counter_waiting_for_signal>300) begin
                            //something went wrong, back to S_STANDBY
                            done_reg <= DONE;
                            state <= S_STANDBY;
                        end else begin
                            //wait longer
                            state <= S_WRITE_ERROR_BIT_6;
                            counter_waiting_for_signal <= counter_waiting_for_signal + 1;
                        end
                    end
                end

                S_WRITE_ERROR_BIT_8: begin
                    //set AT of ERROR BIT (index A-1) to AT_V_GND
                    AT_reg[A-1] <= AT_V_GND;
                    //next state 
                    state <= S_WRITE_ERROR_BIT_9;
                end

                S_WRITE_ERROR_BIT_9: begin
                    //set FP of ERROR_BIT (index A-1) to FP_V_MID
                    FP_reg[A-1] <= FP_V_MID;
                    //next state
                    state <= S_WRITE_ERROR_BIT_10;
                end

                S_WRITE_ERROR_BIT_10: begin
                    //set BL of ERROR_BIT (current column) to BL_V_GND
                    BL_reg[column_reg] <= BL_V_GND;
                    //next state
                    state <= S_WRITE_ERROR_BIT_11;
                end

                S_WRITE_ERROR_BIT_11: begin
                    //set PL of ERROR_BIT (current column) to PL_V_MID
                    PL_reg[(column_reg)*2+:2] <= PL_V_MID;
                    //set done to DONE
                    done_reg <= DONE;
                    //next state
                    state <= S_STANDBY;
                end

                 S_POWER_DOWN_RESET_1: begin
                    //set selected BL to BL_V_GND
                    BL_reg[column_reg] <= BL_V_GND;
                    //next state
                    state <= S_POWER_DOWN_RESET_2;
                end

                S_POWER_DOWN_RESET_2: begin
                    //set selected PL to PL_V_MID
                    PL_reg[column_reg*2+:2] <= PL_V_MID;
                    //next state
                    state <= S_STANDBY;
                end



            endcase
        end
    end

endmodule
