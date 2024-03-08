/* -------------------------------------------------------------------------- */
/* ----------------------- Author: Mingxuan (Siris) Li ---------------------- */
/* -------------------------------------------------------------------------- */

`include "rtl/include/define.v"

module inter_layer_block_scheduler (
    input                clk_i,
    input                rst_ni,

    // mem information from model_config_mem
    input      [31:0]    npu_capability_i,
    input      [31:0]    in_pipeline_cim_capability_i,
    input      [31:0]    bubble_threshold_i,

    // read mem information from model_config_mem
    output reg [31:0]    config_mem_addr_o,
    output reg           config_mem_read_valid_o,
    input      [31:0]    config_mem_read_data_i,
    input                config_mem_read_ready_i,

    // intra-block schedule input from intra-block scheduler
    input      [1:0]     block_type_i,
    input      [31:0]    block0_start_i,
    input      [31:0]    block1_start_i,
    input      [31:0]    block0_length_i,
    input      [31:0]    block1_length_i,

    input                schedule_valid_i,
    output               schedule_ready_o,
    output               block_finish_valid_o,
    output               block0_finish_o,
    output               block1_finish_o,
    output reg           schedule_type_o,
    output reg [1:0]     block_type_o,
    output reg [31:0]    block0_schedule_layer_o,
    output reg [31:0]    block1_schedule_layer_o
);

    reg         config_mem_read_ready_q, schedule_valid_q;
    reg         load_counter_d,          load_counter_q;
    reg         schedule_type_d,         schedule_type_q;
    reg         less_compute_d,          less_compute_q;
    reg [1:0]   block_type_q;
    reg [1:0]   compare_counter_d,       compare_counter_q;
    reg [2:0]   state_d, state_q;
    reg [31:0]  compute_buffer_d[0:3],   compute_buffer_q[0:3];    // normalized computation
    reg [31:0]  block0_pointer_d,        block0_pointer_q;
    reg [31:0]  block1_pointer_d,        block1_pointer_q;
    reg [31:0]  block0_cim_block1_npu_d, block0_cim_block1_npu_q;
    reg [31:0]  block0_npu_block1_cim_d, block0_npu_block1_cim_q;
    reg [31:0]  schedule_bubble_d,       schedule_bubble_q;


    assign schedule_ready_o      = (state_q == `SCHEDULE);
    assign block_finish_valid_o  =  block0_finish_o && block1_finish_o;
	assign block0_finish_o       = (block0_pointer_q == block0_length_i);
	assign block1_finish_o       = (block1_pointer_q == block1_length_i);

    // all the denpendency logic in `case` and `if` must be latched!
    always @(*)
    begin
        // default value => don't change
        for (integer i = 0; i < 4; i = i + 1)
            compute_buffer_d[i]  = compute_buffer_q[i];
        block0_pointer_d         = block0_pointer_q;
        block1_pointer_d         = block1_pointer_q;
        load_counter_d           = load_counter_q;
        compare_counter_d        = compare_counter_q;
        block0_cim_block1_npu_d  = block0_cim_block1_npu_q;
        block0_npu_block1_cim_d  = block0_npu_block1_cim_q;
        less_compute_d           = less_compute_q;
        schedule_type_d          = schedule_type_q;
        schedule_bubble_d        = schedule_bubble_q;
        state_d                  = state_q;
        config_mem_read_valid_o  = 1'b0;
        config_mem_addr_o        = 32'b0;
        schedule_type_o          = 1'b0;
        block_type_o             = 2'b0;

        case (state_q)
            `IDLE:
            begin
                // clear compute buffer
                for (integer i = 0; i < 4; i = i + 1)
                    compute_buffer_d[i] = 0;

                // clear counter
                load_counter_d       = 1'b0;
                compare_counter_d    = 2'b00;

                // start new schedule
                if (block0_pointer_q == block0_length_i && block1_pointer_q == block1_length_i)
                begin
                    state_d          = `IDLE;
                    block0_pointer_d = 0;
                    block1_pointer_d = 0;
                end
                else if (schedule_valid_q)
                begin
                    if (block0_pointer_q == block0_length_i || block1_pointer_q == block1_length_i)
                        state_d      = `SHARE;
                    else
                        state_d      = `LOAD;
                end
            end

            `LOAD:
            begin
                // load model information from config mem
                if (load_counter_q == 1'b0)
                begin
                    case (block_type_q)
                        `FORWARD_FORWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE  << 8) + block0_start_i + block0_pointer_q;
                        `FORWARD_BACKWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE  << 8) + block0_start_i + block0_pointer_q;
                        `BACKWARD_FORWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block0_start_i + block0_length_i - block0_pointer_q - 1;
                        `BACKWARD_BACKWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block0_start_i + block0_length_i - block0_pointer_q - 1;
                    endcase

                    config_mem_read_valid_o = 1'b1;
                    if (config_mem_read_ready_q)
                    begin
                        compute_buffer_d[`BLOCK0_CIM] = compute_buffer_q[`BLOCK0_CIM] + config_mem_read_data_i * in_pipeline_cim_capability_i;
                        compute_buffer_d[`BLOCK0_NPU] = compute_buffer_q[`BLOCK0_NPU] + config_mem_read_data_i * npu_capability_i;
                        block0_pointer_d              = block0_pointer_q + 1;
                        load_counter_d                = 1'b1;
                    end
                end

                else    // load_counter_q == 1'b1
                begin
                    case (block_type_q)
                        `FORWARD_FORWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE  << 8) + block1_start_i + block1_pointer_q;
                        `FORWARD_BACKWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block1_start_i + block1_length_i + block1_pointer_q - 1;
                        `BACKWARD_FORWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE  << 8) + block1_start_i + block1_pointer_q;
                        `BACKWARD_BACKWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block1_start_i + block1_length_i + block1_pointer_q - 1;
                    endcase

                    config_mem_read_valid_o = 1'b1;
                    if (config_mem_read_ready_q)
                    begin
                        compute_buffer_d[`BLOCK1_CIM] = compute_buffer_q[`BLOCK1_CIM] + config_mem_read_data_i * in_pipeline_cim_capability_i;
                        compute_buffer_d[`BLOCK1_NPU] = compute_buffer_q[`BLOCK1_NPU] + config_mem_read_data_i * npu_capability_i;
                        block1_pointer_d              = block1_pointer_q + 1;
                        load_counter_d                = 1'b0;
                        state_d                       = `COMPARE;
                    end
                end
            end

            `COMPARE:
            begin
                case (compare_counter_q)
                    2'b00:
                    begin
                        block0_cim_block1_npu_d = (compute_buffer_q[`BLOCK0_CIM] > compute_buffer_q[`BLOCK1_NPU])
                                                ?  compute_buffer_q[`BLOCK0_CIM] : compute_buffer_q[`BLOCK1_NPU];
                        block0_npu_block1_cim_d = (compute_buffer_q[`BLOCK0_NPU] > compute_buffer_q[`BLOCK1_CIM])
                                                ?  compute_buffer_q[`BLOCK0_NPU] : compute_buffer_q[`BLOCK1_CIM];
                        compare_counter_d       = 2'b01;
                    end

                    2'b01:
                    begin
                        if (block0_cim_block1_npu_q > block0_npu_block1_cim_q)
                        begin
                            schedule_type_d = `BLOCK0_NPU_BLOCK1_CIM;
                            if (compute_buffer_q[`BLOCK0_NPU] > compute_buffer_q[`BLOCK1_CIM])
                            begin
                                less_compute_d    = `BLOCK1_LESS;
                                schedule_bubble_d = compute_buffer_q[`BLOCK0_NPU] - compute_buffer_q[`BLOCK1_CIM];
                            end
                            else
                            begin
                                less_compute_d    = `BLOCK0_LESS;
                                schedule_bubble_d = compute_buffer_q[`BLOCK1_CIM] - compute_buffer_q[`BLOCK0_NPU];
                            end
                        end
                        else
                        begin
                            schedule_type_d = `BLOCK0_CIM_BLOCK1_NPU;
                            if (compute_buffer_q[`BLOCK0_CIM] > compute_buffer_q[`BLOCK1_NPU])
                            begin
                                less_compute_d    = `BLOCK1_LESS;
                                schedule_bubble_d = compute_buffer_q[`BLOCK0_CIM] - compute_buffer_q[`BLOCK1_NPU];
                            end
                            else
                            begin
                                less_compute_d    = `BLOCK0_LESS;
                                schedule_bubble_d = compute_buffer_q[`BLOCK1_NPU] - compute_buffer_q[`BLOCK0_CIM];
                            end
                        end
                        compare_counter_d = 2'b10;
                    end

                    2'b10:
                    begin
                        if (schedule_bubble_q > bubble_threshold_i)
                        begin
                            if (less_compute_q == `BLOCK0_LESS)
                                state_d = (block0_pointer_q == block0_length_i) ? `SCHEDULE : `FUSE;
                            else
                                state_d = (block1_pointer_q == block1_length_i) ? `SCHEDULE : `FUSE;
                        end
                        else
                            state_d = `SCHEDULE;
                        compare_counter_d = 2'b00;
                    end

                    default:
                        compare_counter_d = 2'b00;
                endcase
            end

            `FUSE:
            begin
                if (less_compute_q == `BLOCK0_LESS)
                begin
                    case (block_type_q)
                        `FORWARD_FORWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE  << 8) + block0_start_i + block0_pointer_q;
                        `FORWARD_BACKWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE  << 8) + block0_start_i + block0_pointer_q;
                        `BACKWARD_FORWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block0_start_i + block0_length_i - block0_pointer_q - 1;
                        `BACKWARD_BACKWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block0_start_i + block0_length_i - block0_pointer_q - 1;
                    endcase

                    config_mem_read_valid_o = 1'b1;
                    if (config_mem_read_ready_q)
                    begin
                        compute_buffer_d[`BLOCK0_CIM] = compute_buffer_q[`BLOCK0_CIM] + config_mem_read_data_i * in_pipeline_cim_capability_i;
                        compute_buffer_d[`BLOCK0_NPU] = compute_buffer_q[`BLOCK0_NPU] + config_mem_read_data_i * npu_capability_i;
                        block0_pointer_d              = block0_pointer_q + 1;
                        state_d                       = `COMPARE;
                    end
                end
                else
                begin
                    case (block_type_q)
                        `FORWARD_FORWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE  << 8) + block1_start_i + block1_pointer_q;
                        `FORWARD_BACKWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block1_start_i + block1_length_i - block1_pointer_q - 1;
                        `BACKWARD_FORWARD:
                            config_mem_addr_o = (`FORWARD_COMPUTE  << 8) + block1_start_i + block1_pointer_q;
                        `BACKWARD_BACKWARD:
                            config_mem_addr_o = (`BACKWARD_COMPUTE << 8) + block1_start_i + block1_length_i - block1_pointer_q - 1;
                    endcase

                    config_mem_read_valid_o = 1'b1;
                    if (config_mem_read_ready_q)
                    begin
                        compute_buffer_d[`BLOCK1_CIM] = compute_buffer_q[`BLOCK1_CIM] + config_mem_read_data_i * in_pipeline_cim_capability_i;
                        compute_buffer_d[`BLOCK1_NPU] = compute_buffer_q[`BLOCK1_NPU] + config_mem_read_data_i * npu_capability_i;
                        block1_pointer_d              = block1_pointer_q + 1;
                        state_d                       = `COMPARE;
                    end
                end
            end

            `SHARE:
            begin
                if (block0_pointer_q == block0_length_i)
                    block1_pointer_d =  block1_pointer_q + 1;
                if (block1_pointer_q == block1_length_i)
                    block0_pointer_d =  block0_pointer_q + 1;
                state_d = `SCHEDULE;
            end

            `SCHEDULE:
            begin
                state_d         = schedule_valid_i ? `SCHEDULE : `IDLE;
                block_type_o    = block_type_q;
                schedule_type_o = schedule_type_q;
                case (block_type_q)
                    `FORWARD_FORWARD:
                    begin
                        block0_schedule_layer_o = block0_start_i + block0_pointer_q - 1;
                        block1_schedule_layer_o = block1_start_i + block1_pointer_q - 1;
                    end

                    `FORWARD_BACKWARD:
                    begin
                        block0_schedule_layer_o = block0_start_i + block0_pointer_q - 1;
                        block1_schedule_layer_o = block1_start_i + block1_length_i - block1_pointer_q;
                    end

                    `BACKWARD_FORWARD:
                    begin
                        block0_schedule_layer_o = block0_start_i + block0_length_i - block0_pointer_q;
                        block1_schedule_layer_o = block1_start_i + block1_pointer_q - 1;
                    end

                    `BACKWARD_BACKWARD:
                    begin
                        block0_schedule_layer_o = block0_start_i + block0_length_i - block0_pointer_q;
                        block1_schedule_layer_o = block1_start_i + block1_length_i - block1_pointer_q;
                    end
                endcase
            end

            default:
                state_d = `IDLE;
        endcase
    end

    always @(posedge clk_i or negedge rst_ni)
    begin
        if (~rst_ni)
        begin
            state_q                  <= `IDLE;
            block0_pointer_q         <= 0;
            block1_pointer_q         <= 0;
            load_counter_q           <= 1'b0;
            compare_counter_q        <= 2'b0;
            block_type_q             <= 2'b0;
            schedule_valid_q         <= 1'b0;
            config_mem_read_ready_q  <= 1'b0;
            block0_cim_block1_npu_q  <= 0;
            block0_npu_block1_cim_q  <= 0;
            less_compute_q           <= 1'b0;
            schedule_bubble_q        <= 0;
            schedule_type_q          <= 2'b0;
            for (integer i = 0; i < 4; i = i + 1)
                compute_buffer_q[i]  <= 0;
        end
        else
        begin
            // update registers
            state_q                  <= state_d;
            block0_pointer_q         <= block0_pointer_d;
            block1_pointer_q         <= block1_pointer_d;
            load_counter_q           <= load_counter_d;
            compare_counter_q        <= compare_counter_d;
            block0_cim_block1_npu_q  <= block0_cim_block1_npu_d;
            block0_npu_block1_cim_q  <= block0_npu_block1_cim_d;
            less_compute_q           <= less_compute_d;
            schedule_bubble_q        <= schedule_bubble_d;
            schedule_type_q          <= schedule_type_d;
            for (integer i = 0; i < 4; i = i + 1)
                compute_buffer_q[i]  <= compute_buffer_d[i];

            // latch input
            block_type_q             <= block_type_i;
            schedule_valid_q         <= schedule_valid_i;
            config_mem_read_ready_q  <= config_mem_read_ready_i;
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
        $display("block_type_q = %0d", block_type_q);
        $display("block0_pointer_q = %0d", block0_pointer_q);
        $display("block1_pointer_q = %0d", block1_pointer_q);
        $display("state_q = %0d", state_q);
        $display("block0_cim_block1_npu_q = %0d", block0_cim_block1_npu_q);
        $display("block0_npu_block1_cim_q = %0d", block0_npu_block1_cim_q);
        $display("schedule_type_q = %0d", schedule_type_q);
        $display("schedule_bubble_q = %0d", schedule_bubble_q);
        $display("bubble_threshold = %0d", bubble_threshold_i);
        $display("schedule_type_o = %0d", schedule_type_o);
        $display("block0_schedule_layer_o = %0d", block0_schedule_layer_o);
        $display("block1_schedule_layer_o = %0d", block1_schedule_layer_o);
        $display("less_compute_q = %0d", less_compute_q);

        #50
        $finish;
    end
`endif

endmodule
// 我是皮球 by Yiqi Jing