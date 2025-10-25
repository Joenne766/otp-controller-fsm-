//this testbench tests the FSM with a size of 8x5 in various writing and reading szenarios


`timescale 1ns/1ps

module testbench;


//A and B represent the number of rows (A) and the number of columns (B) of the memory cell. The ERROR_BIT is included in A, so a memory with A=2 has only 1 writable row.
localparam A = 8;
localparam B = 5;
//ADDR_WIDTH is the necessary number of bits to address all columns
localparam ADDR_WIDTH = $clog2(B);



reg clk = 0;
//reset stops all current tasks and brings the FSM back to IDLE 
reg reset = 0;
//mode tells the FSM what to do, possible are reading with MODE_READING, writing with MODE_WRITING, and idle with MODE_IDLE
reg [1:0] mode = 2;
//column = the specific address that is used when reading or writing (it is always the whole column that is read or written)
reg [ADDR_WIDTH-1:0] column = 0; 
//data_in is used for writing, each writing cycle writes one column
reg [A-2:0] data_in = 1'b1;
//writing_successful is a signal from the analog circuit part that shows if a cell was written successfully
reg writing_successful = 1; 
//output_read_circuit is the output of the read circuit and shows if the cell was written or not
reg output_read_circuit = 1;

//PL = powerlines, one powerline for each column, each powerline needs 2 bits
wire [B*2-1:0] PL;
//BL = bitlines, one bitline for each column, each bitline needs 1 bit
wire [B-1:0] BL;
wire [A-1:0] AT;
wire [A-1:0] FP;
//PRG must be PRG_READING for reading or PRG_WRITING for writing
wire PRG;
//data_out is the output of the addressed column after a reading cycle 
wire [A-1:0] data_out;
//read_active is 1 when you can use the data_out after a reading cycle, else 0
wire read_active;
//done = 1 when finished (for 1 tact), 0 when not finished
wire done;


//intern registers for the TB where the writing  of the cells is recorded
reg memory_matrix [A-1:0][B-1:0];
//the correctly written memory matrix, to compare after writing
reg  correct_memory_matrix [A-1:0][B-1:0];
//intern registers for TB where the reading of the cells is recorded
reg reading_matrix [A-1:0][B-1:0];
//the correctly written reading matrix, to compare after reading
reg  correct_reading_matrix [A-1:0][B-1:0];
//intern counter
integer a, b, c, d, error_count = 0;



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
    .FP(FP),
    .AT(AT),
    .read_active(read_active),
    .data_out(data_out),
    .PRG(PRG), 
    .done(done)
);


//this @always-block checks constantly if there are cells being written or being read.
//if yes, then it writes it into the memory_matrix or the reading_matrix
integer i, j;
always@(negedge clk) begin
    for(i = 0; i <= A-1; i = i + 1) begin
        for(j = 0; j <= B-1; j = j + 1) begin
            //test if currently writing
            if((PRG == PRG_V_D) && (FP[i] == FP_V_HIGH) && (AT[i] == AT_V_MID) && (BL[j] == BL_V_MID) && (PL[j*2+:2] == PL_V_HIGH)) begin
                memory_matrix[i][j] = 1;
            end
            //test if currently reading
            if((PRG == PRG_V_GND) && (FP[i] == FP_V_MID) && (AT[i] == AT_V_MID) && (PL[j*2+:2] == PL_V_READ)) begin   
            reading_matrix[i][j] = 1;
            end
        end
    end
end

//this task resets the FSM and sets the memory_matrix/reading_matrix to all zero
task reset_all;
    begin
        //reset the FSM
        reset = 1;
        mode = MODE_IDLE;
        #2;
        reset = 0;
        #2; 
        //reset memory_matrix and reading_matrix
        for(a = 0; a < A; a = a+1) begin
            for(b = 0; b < B; b = b+1) begin
                memory_matrix[a][b] = 0;
                reading_matrix[a][b] = 0;
            end
        end
    end
endtask

//this task is used to overwrite all the inputs of the dut
//the inputs can be changed later while testing
task set_starting_conditions;
    input reset_start;
    input [1:0] mode_start;
    input [ADDR_WIDTH-1:0] column_start;
    input [A-2:0] data_in_start;
    input writing_successful_start;
    input output_read_circuit_start;
    begin
        reset               = reset_start;
        mode                = mode_start;
        column              = column_start;
        data_in             = data_in_start;
        writing_successful  = writing_successful_start;
        output_read_circuit = output_read_circuit_start;
    end
endtask

/**this task takes the column, the data_in, and the possible error_bit as inputs to prepare the 
correct_memory_matrix for later comparison with the actual memory_matrix.
the content is divided between the manually writable cells and the ERROR_BIT
so data_in_to_write is only A-1 bits long*/
task set_correct_memory_matrix;
    input [ADDR_WIDTH-1:0] col;
    input [A-2:0] data_in_to_write;
    input error_bit;
    begin
        //set all to 0 first just to be safe
        for (a = 0; a < A; a = a + 1) begin
            for (b = 0; b < B; b = b + 1) begin
                correct_memory_matrix[a][b] = 0;        
            end
        end
        //now add from data_in
        for (a = 0; a < A-1; a = a + 1) begin
            correct_memory_matrix[a][col] = data_in_to_write[a];  
        end
        //set error bit if necessary
        correct_memory_matrix[A-1][col] = error_bit;
    end
endtask

//this task takes the column as input to prepare the correct_reading_matrix for later comparison with
//the reading_matrix. the reading_matrix is 1 when the output of the dut displays signals that represent
//reading. since it does not matter whether the output of the reading circuit is 1 or 0, all
//correct_reading_matrix cells in the correct column should be 1
task set_correct_reading_matrix;
    input [ADDR_WIDTH-1:0] col;
    begin
        //set all to 0 first just to be safe
        for (a = 0; a < A; a = a + 1) begin
            for (b = 0; b < B; b = b + 1) begin
                correct_reading_matrix[a][b] = 0;        
            end
        end
        //now make all cells in reading_matrix in column col 1
        for (a = 0; a < A; a = a + 1) begin
            correct_reading_matrix[a][col] = 1'b1;  
        end
    end
endtask

//this task shows the memory_matrix and the correct_memory_matrix in the terminal
task display_memory_matrix_and_correct_memory_matrix;
    begin
        $display("current memory_matrix: ");
        $write("column:");
        for(i=0; i <= B-1; i = i + 1) begin
            $write("%0d ", i);
        end
        $display(" ");
        for(i = 0; i <= A-1; i = i + 1) begin
            $write("row %0d: ", i);
            for(j = 0; j <= B-1; j = j + 1) begin
                $write(memory_matrix[i][j]);
                $write(" ");
            end
            $display(" ");
        end 
        $display("correct_memory_matrix: ");
        $write("column:");
        for(i=0; i <= B-1; i = i + 1) begin
            $write("%0d ", i);
        end
        $display(" ");
        for(i = 0; i <= A-1; i = i + 1) begin
            $write("row %0d: ", i);
            for(j = 0; j <= B-1; j = j + 1) begin
                $write(correct_memory_matrix[i][j]);
                $write(" ");
            end
            $display(" ");
        end
    end 
endtask

//this task shows the reading_matrix and the correct_reading_matrix in the terminal
task display_reading_matrix_and_correct_reading_matrix;
    begin
        $display("current reading_matrix: ");
        for(i = 0; i <= A-1; i = i + 1) begin
            for(j = 0; j <= B-1; j = j + 1) begin
                $write(reading_matrix[i][j]);
                $write(" ");
            end
            $display(" ");
        end 
        $display("correct_reading_matrix: ");
        for(i = 0; i <= A-1; i = i + 1) begin
            for(j = 0; j <= B-1; j = j + 1) begin
                $write(correct_reading_matrix[i][j]);
                $write(" ");
            end
            $display(" ");
        end
    end 
endtask

//this task compares the reading_matrix and the correct_reading_matrix. if they are the same, 
//it displays "Testbench found no mistakes". if there are mistakes, the number of mistakes
//are displayed and the reading_matrix and the correct_reading_matrix are shown for debugging
task compare_reading_matrix_and_correct_reading_matrix;
    begin
        //reset error_count
        error_count = 0;
        //compare memory_matrix and correct_memory_matrix
        for (i = 0; i < A; i = i + 1) begin
            for (j = 0; j < B; j = j + 1) begin
                if (reading_matrix[i][j] != correct_reading_matrix[i][j]) begin
                    error_count = error_count + 1;
                end
            end
        end
        if (error_count == 0) begin
            $display("everything ok ( ͡° ͜ʖ ͡°)");
        end else begin
            $display("Test found mistakes  O_o  , number of mistakes: ", error_count);
            display_reading_matrix_and_correct_reading_matrix(); 
        end  
    end
endtask

//this task compares the memory_matrix and the correct_memory_matrix. if they are the same, 
//it displays "Testbench found no mistakes". if there are mistakes, the number of mistakes
//are displayed and the memory_matrix and the correct_memory_matrix are shown for debugging
task compare_memory_matrix_and_correct_memory_matrix;
    begin
        //reset error_count
        error_count = 0;
        //compare memory_matrix and correct_memory_matrix
        for (i = 0; i < A; i = i + 1) begin
            for (j = 0; j < B; j = j + 1) begin
                if (memory_matrix[i][j] !== correct_memory_matrix[i][j]) begin
                    error_count = error_count + 1;
                end
            end
        end
        if (error_count == 0) begin
            $display("everything ok ( ͡° ͜ʖ ͡°)");
        end else begin
            $display("Testbench found mistakes  O_o   number of mistakes: ", error_count);
            display_memory_matrix_and_correct_memory_matrix(); 
        end  
    end
endtask

//after each reading cycle, data_out should output the correct column of the memory.
//in the state S_READING_POSSIBLE, read_active is 1 and data_out should be shown by the FSM. 
//this task waits for read_active and compares data_out with the desired correct_data_out
//the desired correct_data_out must be given as input to this task
task compare_data_out_to_correct_data_out;
    input [A-1:0] correct_data_out;
    begin
        wait(read_active);
        if(read_active && (data_out == correct_data_out)) begin
            $display("everything ok ( ͡° ͜ʖ ͡°)");
        end else if (read_active && (data_out != correct_data_out)) begin
            $display("Testbench found mistakes after reading  O_o  ");
            $display("data_out: %0b", data_out);
            $display("correct_data_out: %0b", correct_data_out);
        end
    end
endtask


initial begin
    $display("testbench2 started");
    $display("test 1 begins");
    //this test writes 7'b1101100 in the column with the index 4. since output_read_circuit is always
    //set to 1, data_out_reg is falsely set to 7'b1111111 (not fixable with S_WRITE_FALSE_BIT), so an ERROR_BIT should be written
    reset_all();
    set_starting_conditions(0, MODE_WRITING, 4, 7'b1101100, WRITING_SUCCESSFUL, 1'b1);
    set_correct_memory_matrix(4, 7'b1101100, 1'b1);           
    wait (done);
    compare_memory_matrix_and_correct_memory_matrix();

    $display("test 2 begins");
    //this test writes 7'b1111111 in the column index 0. output_read is always 1 so data_out_reg
    //is also 7'b1111111, ERROR_BIT should be 0
    reset_all();
    set_starting_conditions(0, MODE_WRITING, 0, 7'b1111111, WRITING_SUCCESSFUL, 1'b1);
    set_correct_memory_matrix(0, 7'b1111111, 1'b0);
    wait(done);
    compare_memory_matrix_and_correct_memory_matrix();

    $display("test 3 begins");
    //this test writes 7'b0000000 but output_read is always 1, so data_out_reg will be 7'b1111111 (not fixable with S_WRITE_FALSE_BIT),
    //so an ERROR_BIT should be written
    reset_all();
    set_starting_conditions(0, MODE_WRITING, 0, 7'b0000000, WRITING_SUCCESSFUL, 1'b1);
    set_correct_memory_matrix(0, 7'b0000000, 1'b1);
    wait(done);
    compare_memory_matrix_and_correct_memory_matrix();

    $display("test 4 begins");
    //this test writes 7'b0000000 and output_read is always 0, so data_out_reg will be correctly
    //7'b0000000. the ERROR_BIT should therefore be 0
    reset_all();
    set_starting_conditions(0, MODE_WRITING, 0, 7'b0000000, WRITING_SUCCESSFUL, 1'b0);
    set_correct_memory_matrix(0, 7'b0000000, 1'b0);
    wait(done);
    compare_memory_matrix_and_correct_memory_matrix();

    $display("test 5 begins");
    //this test reads the column index 0. it then checks the reading matrix, if everything was read correctly
    reset_all();
    set_starting_conditions(0, MODE_READING, 0, 7'b0000000, WRITING_NOT_SUCCESSFUL, 1'b1);
    set_correct_reading_matrix(0);
    wait(done);
    compare_reading_matrix_and_correct_reading_matrix();

    $display("test 6 begins");
    //this test has output_read_circuit always on 1, so after a reading cycle, data_out should be 
    //8'b11111111
    reset_all();
    set_starting_conditions(0, MODE_READING, 0, 7'b0000000, WRITING_NOT_SUCCESSFUL, 1'b1);
    compare_data_out_to_correct_data_out(8'b11111111);

    $display("test 7 begins");
    //this test has output_read_circuit always on 0, so after a reading cycle, data_out should be 
    //8'b00000000
    reset_all();
    set_starting_conditions(0, MODE_READING, 0, 7'b0000000, WRITING_NOT_SUCCESSFUL, 1'b0);
    compare_data_out_to_correct_data_out(8'b00000000);

    $display("test 8 begins");
    //this test tests setting WRITING_NOT_SUCCESSFUL to 0 all times, so S_WRITING_WAITING_FOR_SIGNAL 
    //should not stay in an endless loop
    //since output_read_circuit is always 1'b1, the correct memory matrix is 8'b00000001, since 
    //there is a loop after the first writing which will cause the writing to be aborted
    reset_all();
    set_starting_conditions(0, MODE_WRITING, 0, 7'b1111111, WRITING_NOT_SUCCESSFUL, 1'b1);
    set_correct_memory_matrix(0, 7'b0000001, 1'b0);
    wait(done);
    compare_memory_matrix_and_correct_memory_matrix();






    $finish;
end







always #1 clk = ~clk;

endmodule
