module FSM #(
    parameter A = 2,
    parameter B = 2
)(
    input clk, 
    input reset, 
    input [1:0] mode, 
    input [ADDR_WIDTH-1:0] column, 
    input [A-1:0] data_in, 
    input writing:successful,
    output [2*B-1:0] PL,
    output [B-1:0] BL,
    output [A-1:0] WLN,
    output [A-1:0] WLP,
    output PRG,
    output [A-1] data_out,
    output read_active
    )

    localparam ADDR_WIDTH = ceil{log2(B)};

    localparam [5:0]
        parameter S_IDLE = 0




always@(posedge clk) begin 
    if (reset) begin
        state <= S_IDLE;
    end else begin
        case (state) begin
            //...
        end
    
        endcase
    end

endmodule