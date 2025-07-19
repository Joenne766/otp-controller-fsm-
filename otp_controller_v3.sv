module FSM #(
    parameter A = 2,
    B = 2,
    ADDR_WIDTH = $clog2(B)
)(
    input clk, 
    input reset, 
    input [1:0] mode, 
    input [ADDR_WIDTH-1:0] column, 
    input [A-1:0] data_in, 
    input writing_successful,
    output [2*B-1:0] PL,
    output [B-1:0] BL,
    output [A-1:0] WLN,
    output [A-1:0] WLP,
    output PRG,
    output [A-1:0] data_out,
    output read_active
    );

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
    localparam WLN_V_MID = 1'b0;           //WLN_V_MID für 5 V
    localparam WLN_V_GND = 1'b1;
    localparam WLP_V_HIGH = 1'b0;        //WLP_V_HIGH für 10 V
    localparam WLP_V_MID = 1'b1;        //WLP_V_MID für 5 V
    //parameter of the read_active output
    localparam READ_NOT_ACTIVE = 1'b0;
    localparam READ_ACTIVE = 1'b1;
    //parameter of the writing_sucessful input
    localparam WRITING_NOT_SUCCESSFUL = 1'b0;
    localparam WRITING_SUCCESSFUL = 1'b1;


    localparam [5:0]
        S_IDLE = 0;

    reg [4:0] state;
    reg [2*B-1:0] PL_reg;          
    reg [B-1:0] BL_reg;       
    reg [A-1:0] WLN_reg;
    reg [A-1:0] WLP_reg;
    reg read_active_reg;
    reg [A-1:0] data_out_reg;
    reg [A-1:0] data_in_reg;
    reg PRG_reg;

    assign BL = BL_reg;
    assign PL = PL_reg;
    assign WLN = WLN_reg;
    assign WLP = WLP_reg;
    assign read_active = read_active_reg;
    assign data_out = data_out_reg;
    assign PRG = PRG_reg;



    always@(posedge clk) begin 
        if (reset) begin
            state <= S_IDLE;
        end else begin
            case (state) 
                S_IDLE: begin
                    $display ("state = S_IDLE");
                    //set default conditions
                    BL_reg <= {B{BL_V_GND}};
                    PL_reg <= {B{PL_V_GND}};
                    WLN_reg <= {A{WLN_V_GND}};
                    WLP_reg <= {A{WLP_V_MID}};
                    read_active_reg <= READ_NOT_ACTIVE;
                end
            
            endcase
        end
    end

endmodule