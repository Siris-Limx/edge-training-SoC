`include "rtl/include/define.v"

module inter_layer_block_scheduler_tb;

    reg clk, rst_n, schedule_valid;
    reg [31:0] npu_capability, in_pipeline_cim_capability;
    reg [31:0] bubble_threshold;
    reg [31:0] config_mem_read_data;
    reg config_mem_read_ready;
    reg [1:0] block_type;
    reg [31:0] block0_start, block1_start, block0_length, block1_length;
    wire [31:0] config_mem_addr;
    wire config_mem_read_valid;

    task load;
        input [1:0] test_block_type;
        input [31:0] config_mem_read_data0;
        input [31:0] config_mem_read_data1;

        begin
            #10
            block_type = test_block_type;
            rst_n = 0;
            case (block_type)
                `FORWARD_FORWARD:
                begin
                    block0_start = 4;
                    block1_start = 0;
                end

                `FORWARD_BACKWARD:
                begin
                    block0_start = 0;
                    block1_start = 4;
                end

                `BACKWARD_FORWARD:
                begin
                    block0_start = 0;
                    block1_start = 4;
                end

                `BACKWARD_BACKWARD:
                begin
                    block0_start = 4;
                    block1_start = 0;
                end
            endcase

            #10
            rst_n = 1;

            $monitoron;
            $monitor("config_mem_addr = %0h", config_mem_addr);

            #15
            if (config_mem_read_valid)
            begin
                config_mem_read_data = config_mem_read_data0;
                config_mem_read_ready = 1;
            end

            #10
            config_mem_read_ready = 0;

            #10
            if (config_mem_read_valid)
            begin
                config_mem_read_data = config_mem_read_data1;
                config_mem_read_ready = 1;
            end

            #10
            config_mem_read_ready = 0;

            #5
            $display("");
            $monitoroff;
        end
    endtask

    task compare;


        begin
            
        end
    endtask

    always #5 clk = ~clk;

    inter_layer_block_scheduler dut
    (
        .clk_i (clk),
        .rst_ni (rst_n),

        .npu_capability_i (npu_capability),
        .in_pipeline_cim_capability_i (in_pipeline_cim_capability),
        .bubble_threshold_i (bubble_threshold),

        .config_mem_addr_o (config_mem_addr),
        .config_mem_read_valid_o (config_mem_read_valid),
        .config_mem_read_data_i (config_mem_read_data),
        .config_mem_read_ready_i (config_mem_read_ready),

        .block_type_i (block_type),
        .block0_start_i (block0_start),
        .block1_start_i (block1_start),
        .block0_length_i (block0_length),
        .block1_length_i (block1_length),

        .schedule_valid_i (schedule_valid),
        .schedule_ready_o ()
    );

    initial
    begin
        clk = 1;
        rst_n = 0;
        npu_capability = 3;
        in_pipeline_cim_capability = 1;
        bubble_threshold = 2000;
        block0_start = 0;
        block1_start = 0;
        block_type = 0;
        schedule_valid = 0;

        #20
        rst_n = 1;
        schedule_valid = 1;

        /* ----------------------------- load state test ---------------------------- */
        load(`FORWARD_FORWARD, 222, 333);
        load(`FORWARD_BACKWARD, 111, 777);
        load(`BACKWARD_FORWARD, 444, 999);
        load(`BACKWARD_BACKWARD, 1111, 2222);
    end

endmodule