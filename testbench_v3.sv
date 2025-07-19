`timescale 1ns/1ps

module testbench;


logic clk;
logic reset;
logic [1:0] mode;
logic [ADDR_WIDTH-1:0] column; 
logic [A-1:0] data_in;
logic writing_successful; 
logc [2*B-1:0] PL;
logic [B-1:0] BL;
logic [A-1:0] WLN;
logic [A-1:0] WLP;
logic PRG;
logic [A-1] data_out;
logic read active;



