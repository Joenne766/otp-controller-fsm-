module FSM (
    input clk, 
    input [1:0] mode, 
    input reset, 
    input [1:0] addr,       //2 Bit Addresse bei 2x2
                            //addr[0] = Spalte, addr[1] = Zeile
    output [1:0] BL,        //1 Bit pro BL, (10) heißt BL[0]=1 und BL[1]=0
    output [3:0] PL,        //hier 2 Bit pro PL, (1000) heißt PL[0]=2, PL[1]=0
                            //2'b00 = V_HV, 2'b01 = V_MID, 2'b10 = V_READ
    output [1:0] WLN,
    output [1:0] WLP,
    output reading          //0 for not reading, 1 for reading
    );
    
    parameter IDLE  = 5'b00000;       //Verschiedene Zustände
    parameter READ_STEP_1  = 5'b00001;
    parameter READ_STEP_2  = 5'b00010;
    parameter READ_STEP_3  = 5'b00011;
    parameter READ_STEP_4  = 5'b00100;
    parameter READ_STEP_5  = 5'b00101;
    parameter READING_POSSIBLE = 5'b00110;
    parameter WRITE_STEP_1 = 5'b00111;
    parameter WRITE_STEP_2 = 5'b01000;
    parameter WRITE_STEP_3 = 5'b01001;
    parameter WRITE_STEP_4 = 5'b01010;
    parameter WRITE_STEP_5 = 5'b01011;
    parameter WRITE_STEP_6 = 5'b01100;
    parameter POWER_DOWN_STEP_1 = 5'b01101;
    parameter POWER_DOWN_STEP_2 = 5'b01110;
    parameter POWER_DOWN_STEP_3 = 5'b01111;
    parameter POWER_DOWN_STEP_4 = 5'b10000;
    parameter PL_V_HV   = 2'b00;    //Verschiedene Spannungslevel an PL/BL/WL
    parameter PL_V_MID  = 2'b01;
    parameter PL_V_READ = 2'b10;
    parameter PL_V_GND = 2'b11;
    parameter BL_V_MID = 1'b0;
    parameter BL_V_GND = 1'b1;
    parameter WLN_V_MID = 1'b0;     //WLN_V_MID für 5 V
    parameter WLN_V_GND = 1'b1;
    parameter WLP_V_HV = 1'b0;      //WLP_V_HV für 10 V
    parameter WLP_V_MID = 1'b1;     //WLP_V_MID für 5 V
    parameter NOT_READING = 1'b0;
    parameter READING = 1'b1;
    parameter MODE_READING = 2'b01;
    parameter MODE_WRITING = 2'b00;
    parameter MODE_IDLE = 2'b10;

    reg [4:0] state;
    reg [3:0] PL_reg;          
    reg [1:0] BL_reg;       
    reg [1:0] WLN_reg;
    reg [1:0] WLP_reg;
    reg reading_reg;
    assign BL = BL_reg;
    assign PL = PL_reg;
    assign WLN = WLN_reg;
    assign WLP = WLP_reg;
    assign reading = reading_reg;
    
    initial begin
        $display ("Starting FSM"); 
    end
    
    
    

    always@(posedge clk) begin
        if(reset) begin
            state <= IDLE;
            $display ("reset");
        end else begin
            case (state)
            
                IDLE: begin 
                    $display ("state = IDLE");
                    //set default conditions
                    BL_reg <= {BL_V_GND, BL_V_GND};
                    PL_reg <= {PL_V_GND, PL_V_GND};
                    WLN_reg <= {WLN_V_GND, WLN_V_GND};
                    WLP_reg <= {WLP_V_MID, WLP_V_MID};
                    reading_reg <= NOT_READING;
                    //next state
                    if(mode == MODE_READING) begin
                        state <= READ_STEP_2;
                        $display ("next state = READ_STEP_2");
                    end else if(mode == MODE_WRITING) begin
                        state <= WRITE_STEP_1;
                    end else if(mode == MODE_IDLE) begin
                        //nothing
                    end else begin
                        $display("WARNUNG: Ungültiger mode = %b", mode);
                    end
                end
                
                READ_STEP_2: begin 
                    $display ("state = READ_STEP_2");
                    //set Powerline from selected Array to 1.8 V
                    if(addr[0]) begin
                        PL_reg <= {PL_V_READ, PL_V_GND};
                    end
                    else begin
                        PL_reg <= {PL_V_GND, PL_V_READ};
                    end
                    state <= READ_STEP_3;
                end
                
                READ_STEP_3: begin
                    $display ("state = READ_STEP_3");
                    //set WLN of the selected cells to 5 V
                    if(addr[0]) begin
                        WLN_reg <= {WLN_V_MID, WLN_V_GND};
                    end else begin
                        WLN_reg <= {WLN_V_GND, WLN_V_MID};
                    end
                    state <= READING_POSSIBLE;
                end
                
                READING_POSSIBLE: begin
                    $display ("state = READING_POSSIBLE");
                    //set reading to high
                    reading_reg <= READING;     //für 1 Takt kann gelesen werden
                    state <= IDLE;
                end
                
                
                WRITE_STEP_1: begin
                    $display ("state = WRITE_STEP_1");
                    //1. set all WLN to 5 V
                    WLN_reg <= {WLN_V_MID, WLN_V_MID};
                    state <= WRITE_STEP_2;
                end
                
                WRITE_STEP_2: begin
                    $display ("state = WRITE_STEP_2");
                    //2. set BL and PL of unselected cells to 5 V
                    if(addr[0]) begin
                        BL_reg <= {BL_V_GND, BL_V_MID};
                        PL_reg <= {PL_V_GND, PL_V_MID};
                    end else begin
                        BL_reg <= {BL_V_MID, BL_V_GND};
                        PL_reg <= {PL_V_MID, PL_V_GND};
                    end
                    state <= WRITE_STEP_3;
                end
                
                WRITE_STEP_3: begin
                     $display ("state = WRITE_STEP_3");
                    //3. resetting all WLN to 0 V
                    WLN_reg <= {WLN_V_GND, WLN_V_GND};
                    state <= WRITE_STEP_4;
                end
                
                WRITE_STEP_4: begin
                    $display ("state = WRITE_STEP_4");
                    //4. set PL of selected cells to 10 V
                    if(addr[0]) begin
                        PL_reg <= {PL_V_HV, PL_V_MID};
                    end else begin
                        PL_reg <= {PL_V_MID, PL_V_HV};
                    end
                    state <= WRITE_STEP_5;
                end
                
                WRITE_STEP_5: begin
                    $display ("state = WRITE_STEP_5");
                    //5. set WLP of selected cells to 10 V
                    if(addr[1]) begin
                        WLP_reg <= {WLP_V_HV, WLP_V_MID};
                    end else begin
                        WLP_reg <= {WLP_V_MID, WLP_V_HV};
                    end
                    state <= WRITE_STEP_6;
                end
                
                WRITE_STEP_6: begin
                    $display ("state = WRITE_STEP_6");
                    //6. set WLN of selected cells to 5 V
                    if(addr[1]) begin
                        WLN_reg <= {WLN_V_MID, WLN_V_GND};
                    end else begin
                        WLN_reg <= {WLN_V_GND, WLN_V_MID};
                    end
                    state <= POWER_DOWN_STEP_1;
                end
                
                POWER_DOWN_STEP_1: begin
                    $display ("state = POWER_DOWN_STEP_1");
                    //1. set WLN of selected cell to 0 V
                    WLN_reg <= {WLN_V_GND, WLN_V_GND};
                    state <= POWER_DOWN_STEP_2;
                end
                
                POWER_DOWN_STEP_2: begin
                     $display ("state = POWER_DOWN_STEP_2");
                     //2. set WLP of selected cell to 5 V
                    WLP_reg <= {WLP_V_MID, WLP_V_MID};
                    state <= POWER_DOWN_STEP_3;
                end
                
                POWER_DOWN_STEP_3: begin
                    $display ("state = POWER_DOWN_STEP_3");
                    //3. set PL and BL of the selected cell to 0 V.
                    if(addr[0]) begin
                        PL_reg[3:2] <= PL_V_GND;
                    end else begin
                        PL_reg[1:0] <= PL_V_GND;
                    end
                    if(addr[1]) begin
                        BL_reg[3:2] <= BL_V_GND;
                    end else begin
                        BL_reg[1:0] <= BL_V_GND;
                    end
                    state <= POWER_DOWN_STEP_4;
                end
                    
                POWER_DOWN_STEP_4: begin
                $display ("state = POWER_DOWN_STEP_4");
                    //4. set PL and BL of the unselected cells to 0 V
                    if(addr[0]) begin
                        PL_reg[1:0] <= PL_V_GND;
                    end else begin
                        PL_reg[3:2] <= PL_V_GND;
                    end
                    if(addr[1]) begin
                        BL_reg[1:0] <= BL_V_GND;
                    end else begin
                        BL_reg[3:2] <= BL_V_GND;
                    end
                    state <= IDLE;
                end
            
                default: begin      //default state, unknown state
                    $display ("unknown state: %b", state);
                end
        
            endcase
        end
    end

    
endmodule




module tb;

    reg clk = 0;
    reg [1:0] mode = 0;
    reg reset = 0;
    reg [1:0] addr = 1;
    
    wire [3:0] PL;
    wire [1:0] BL;
    wire [1:0] WLN;
    wire [1:0] WLP;
    wire reading;

    FSM dut(clk, mode, reset, addr, BL, PL, WLN, WLP, reading);
    
    always #1 clk = ~clk;
    
    initial begin
        #5 reset = 1;
        #6 reset = 0;
        #15 mode = 2'b10;   //mode idle
        #20 mode = 2'b00;   //mode write
        #30 $finish;
    end
    
   endmodule