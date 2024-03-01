/* -------------------------------------------------------------------------- */
/* ----------------------- Author: Mingxuan (Siris) Li ---------------------- */
/* -------------------------------------------------------------------------- */

`include "rtl/include/define.v"

module inter_layer_block_scheduler (
    input clk_i,
    input rst_ni,

    // mem information from model_config_mem
    input [31:0] npu_capability_i,
    input [31:0] in_pipeline_cim_capability_i,

    // read mem information from model_config_mem
    output [31:0] config_mem_addr_o,
    output config_mem_read_valid_o,
    input [31:0] config_mem_read_data_i,

    // intra-block schedule input from intra-block scheduler
    input [1:0] block_type_i,
    input [31:0] block0_start_i,
    input [31:0] block1_start_i,
    input [31:0] block0_length_i,
    input [31:0] block1_length_i,


    input schedule_valid_i,
    output schedule_ready_o


);

    reg [31:0] compute_buffer[0:3];
    reg [31:0] block0_pointer, block1_pointer;
    reg [1:0] state_d, state_q;
    reg load_finish, compare_finish, schedule_finish;

    assign schedule_ready_o = (state_q == `IDLE) && schedule_valid_i;

    always @(*)
    begin
        case (state_q)
            `IDLE:
            begin
                // clear compute buffer
                for (integer i = 0; i < 4; i = i + 1)
                    compute_buffer[i] = 0;

                // clear pointer
                block0_pointer = 0;
                block1_pointer = 0;

                // start new schedule
                if (schedule_valid_i)
                    state_d = `LOAD;
            end

            `LOAD:
            begin
                // load model information from config mem
                case (block_type_i)
                    `FORWARD_FORWARD:
                    begin
                        
                    end
                    default: 
                endcase

                if (load_finish)
                    state_d = `COMPARE;
            end

            `COMPARE:
            begin
                if (compare_finish)
                    state_d = `SCHEDULE;
            end

            `SCHEDULE:
            begin
                if (schedule_finish)
                    state_d = `IDLE;
            end
        endcase
    end

    always @(posedge clk_i or negedge rst_ni)
    begin
        if (~rst_ni)
            state_q <= `IDLE;
        else
            state_q <= state_d;
    end

endmodule