/* -------------------------------------------------------------------------- */
/* ----------------------- Author: Mingxuan (Siris) Li ---------------------- */
/* -------------------------------------------------------------------------- */

module intra_layer_block_scheduler
(
    input clk_i,
    input rst_ni,

    input [31:0] forward_length_i,
    input [31:0] backward_length_i,
    input [31:0] forward_breakpoint_i,
    input [31:0] backward_breakpoint_i,

    input block_finish_valid_i,

    output reg [31:0] block0_start_o,
    output reg [31:0] block1_start_o,
    output reg [31:0] block0_length_o,
    output reg [31:0] block1_length_o,
    output reg [1:0] block_type_o
);

    localparam [1:0] FORWARD_FORWARD = 2'b00,
                    FORWARD_BACKWARD = 2'b01,
                    BACKWARD_FORWARD = 2'b10,
                    BACKWARD_BACKWARD = 2'b11;

    reg [1:0] state_d, state_q;

    always @(*)
    begin
        case (state_q)
            FORWARD_FORWARD:
            begin
                block_type_o = FORWARD_FORWARD;
                block0_start_o = forward_breakpoint_i;
                block0_length_o = forward_length_i - forward_breakpoint_i;
                block1_start_o = 0;
                block1_length_o = forward_length_i - forward_breakpoint_i;
            end

            FORWARD_BACKWARD:
            begin
                block_type_o = FORWARD_BACKWARD;
                block0_start_o = 0;
                block0_length_o = forward_breakpoint_i;
                block1_start_o = backward_length_i - backward_breakpoint_i;
                block1_length_o = backward_breakpoint_i;
            end

            BACKWARD_FORWARD:
            begin
                block_type_o = BACKWARD_FORWARD;
                block0_start_o = 0;
                block0_length_o = backward_breakpoint_i;
                block1_start_o = forward_length_i - forward_breakpoint_i;
                block1_length_o = forward_breakpoint_i;
            end

            BACKWARD_BACKWARD:
            begin
                block_type_o = BACKWARD_BACKWARD;
                block0_start_o = backward_breakpoint_i;
                block0_length_o = backward_length_i - backward_breakpoint_i;
                block1_start_o = 0;
                block1_length_o = backward_length_i - backward_breakpoint_i;
            end
        endcase
    end

    always @(*)
    begin
        state_d = state_q;

        case (state_q)
            FORWARD_FORWARD: state_d = block_finish_valid_i ? BACKWARD_FORWARD : state_q;
            BACKWARD_FORWARD: state_d = block_finish_valid_i ? BACKWARD_BACKWARD : state_q;
            BACKWARD_BACKWARD: state_d = block_finish_valid_i ? FORWARD_BACKWARD : state_q;
            FORWARD_BACKWARD: state_d = block_finish_valid_i ? FORWARD_FORWARD : state_q;
        endcase
    end

    always @(posedge clk_i or negedge rst_ni)
    begin
        if (!rst_ni)
            state_q <= FORWARD_FORWARD;
        else
            state_q <= state_d;
    end

endmodule