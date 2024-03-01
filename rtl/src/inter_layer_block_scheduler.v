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
    input [31:0] bubble_threshold_i,

    // read mem information from model_config_mem
    output reg [31:0] config_mem_addr_o,
    output reg config_mem_read_valid_o,
    input [31:0] config_mem_read_data_i,
    input config_mem_read_ready_i,

    // intra-block schedule input from intra-block scheduler
    input [1:0] block_type_i,
    input [31:0] block0_start_i,
    input [31:0] block1_start_i,
    input [31:0] block0_length_i,
    input [31:0] block1_length_i,


    input schedule_valid_i,
    output schedule_ready_o
);

    reg config_mem_read_ready_q, schedule_valid_q;
    reg [1:0] block_type_q;
    reg [31:0] compute_buffer_d[0:3], compute_buffer_q[0:3];    // normalized computation
    reg load_counter_d, load_counter_q;
    reg [31:0] block0_pointer_d, block0_pointer_q;
    reg [31:0] block1_pointer_d, block1_pointer_q;
    reg [31:0] block0_cim_block1_npu_d, block0_cim_block1_npu_q;
    reg [31:0] block0_npu_block1_cim_d, block0_npu_block1_cim_q;
    reg schedule_type_d, schedule_type_q;
    reg [31:0] schedule_bubble_d, schedule_bubble_q;
    reg [1:0] state_d, state_q;
    reg schedule_finish;

    assign schedule_ready_o = (state_q == `IDLE) && schedule_valid_i;

    // all the denpendency logic in `case` and `if` must be latched!
    always @(*)
    begin
        // default value => don't change
        for (integer i = 0; i < 4; i = i + 1)
            compute_buffer_d[i] = compute_buffer_q[i];
        block0_pointer_d = block0_pointer_q;
        block1_pointer_d = block1_pointer_q;
        load_counter_d = load_counter_q;
        state_d = state_q;
        config_mem_read_valid_o = 1'b0;
        config_mem_addr_o = 32'b0;

        case (state_q)
            `IDLE:
            begin
                // clear compute buffer
                for (integer i = 0; i < 4; i = i + 1)
                    compute_buffer_d[i] = 0;

                // clear pointer
                block0_pointer_d = 0;
                block1_pointer_d = 0;

                // clear load counter
                load_counter_d = 1'b0;

                // start new schedule
                if (schedule_valid_q)
                    state_d = `LOAD;
            end

            `LOAD:
            begin
                // load model information from config mem
                if (load_counter_q == 1'b0)
                begin
                    case (block_type_q)
                        `FORWARD_FORWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE << 8) + block0_start_i + block0_pointer_q;
                        `FORWARD_BACKWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE << 8) + block0_start_i + block0_pointer_q;
                        `BACKWARD_FORWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block0_start_i + block0_pointer_q;
                        `BACKWARD_BACKWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block0_start_i + block0_pointer_q;
                    endcase

                    config_mem_read_valid_o = 1'b1;
                    if (config_mem_read_ready_q)
                    begin
                        compute_buffer_d[`BLOCK0_CIM] = compute_buffer_q[`BLOCK0_CIM] + config_mem_read_data_i * in_pipeline_cim_capability_i;
                        compute_buffer_d[`BLOCK0_NPU] = compute_buffer_q[`BLOCK0_NPU] + config_mem_read_data_i * npu_capability_i;
                        block0_pointer_d = block0_pointer_q + 1;
                        load_counter_d = 1'b1;
                    end
                end

                else    // load_counter_q == 1'b1
                begin
                    case (block_type_q)
                        `FORWARD_FORWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE << 8) + block1_start_i + block1_pointer_q;
                        `FORWARD_BACKWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block1_start_i + block1_pointer_q;
                        `BACKWARD_FORWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE << 8) + block1_start_i + block1_pointer_q;
                        `BACKWARD_BACKWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block1_start_i + block1_pointer_q;
                    endcase

                    config_mem_read_valid_o = 1'b1;
                    if (config_mem_read_ready_q)
                    begin
                        compute_buffer_d[`BLOCK1_CIM] = compute_buffer_q[`BLOCK1_CIM] + config_mem_read_data_i * in_pipeline_cim_capability_i;
                        compute_buffer_d[`BLOCK1_NPU] = compute_buffer_q[`BLOCK1_NPU] + config_mem_read_data_i * npu_capability_i;
                        block1_pointer_d = block1_pointer_q + 1;
                        load_counter_d = 1'b0;
                        state_d = `COMPARE;
                    end
                end
            end

            `COMPARE:
            begin
                block0_cim_block1_npu_d = (compute_buffer_q[`BLOCK0_CIM] > compute_buffer_q[`BLOCK1_NPU])
                                        ? compute_buffer_q[`BLOCK0_CIM] : compute_buffer_q[`BLOCK1_NPU];
                block0_npu_block1_cim_d = (compute_buffer_q[`BLOCK0_NPU] > compute_buffer_q[`BLOCK1_CIM])
                                        ? compute_buffer_q[`BLOCK0_NPU] : compute_buffer_q[`BLOCK1_CIM];

                if (block0_cim_block1_npu_q > block0_npu_block1_cim_q)
                begin
                    schedule_type_d = `BLOCK0_NPU_BLOCK1_CIM;
                    schedule_bubble_d = block0_cim_block1_npu_q - block0_npu_block1_cim_q;
                end
                else
                begin
                    schedule_type_d = `BLOCK0_CIM_BLOCK1_NPU;
                    schedule_bubble_d = block0_npu_block1_cim_q - block0_cim_block1_npu_q;
                end

                if (schedule_bubble_q > bubble_threshold_i)
                    state_d = `SCHEDULE;
                else
                    state_d = `LOAD;
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
        begin
            state_q <= `IDLE;
            block0_pointer_q <= 0;
            block1_pointer_q <= 0;
            load_counter_q <= 1'b0;
            block_type_q <= 2'b0;
            schedule_valid_q <= 1'b0;
            config_mem_read_ready_q <= 1'b0;
            block0_cim_block1_npu_q <= 0;
            block0_npu_block1_cim_q <= 0;
            schedule_bubble_q <= 0;
            schedule_type_q <= 2'b0;
            for (integer i = 0; i < 4; i = i + 1)
                compute_buffer_q[i] <= 0;
        end
        else
        begin
            // update registers
            for (integer i = 0; i < 4; i = i + 1)
                compute_buffer_q[i] <= compute_buffer_d[i];
            state_q <= state_d;
            block0_pointer_q <= block0_pointer_d;
            block1_pointer_q <= block1_pointer_d;
            load_counter_q <= load_counter_d;
            block0_cim_block1_npu_q <= block0_cim_block1_npu_d;
            block0_npu_block1_cim_q <= block0_npu_block1_cim_d;
            schedule_bubble_q <= schedule_bubble_d;
            schedule_type_q <= schedule_bubble_d;

            // latch input
            block_type_q <= block_type_i;
            schedule_valid_q <= schedule_valid_i;
            config_mem_read_ready_q <= config_mem_read_ready_i;

        end
    end


    /* ------------------------- print local information ------------------------ */
`ifdef SIMULATION
    initial
    begin
        $dumpfile("build/inter_layer_block_scheduler_tb.vcd");
        $dumpvars(0, inter_layer_block_scheduler);

        #10000
        $display("compute buffer:");
        for (integer i = 0; i < 4; i = i + 1)
            $display("compute_buffer[%0d] = %0d", i, compute_buffer_q[i]);
        $display("block0_pointer_q = %0d", block0_pointer_q);
        $display("block1_pointer_q = %0d", block1_pointer_q);
        $display("state_q = %0d", state_q);

        #50
        $finish;
    end
`endif

endmodule
// 我是皮球 by Yiqi Jing