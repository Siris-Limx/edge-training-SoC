/* -------------------------------------------------------------------------- */
/* ----------------------- Author: Mingxuan (Siris) Li ---------------------- */
/* -------------------------------------------------------------------------- */

`include "rtl/include/define.v"

module top_scheduler
(
    input            clk_i,
    input            rst_ni,

    input  [31:0]    config_data_i,
    input  [31:0]    config_addr_i,
    input            config_valid_i,
    output           config_ready_o,

    input            schedule_valid_i,
    output           schedule_ready_o,
    output           block0_finish_o,
    output           block1_finish_o,
    output           schedule_type_o,
    output           block_type_o,
    output [31:0]    block0_schedule_layer_o,
    output [31:0]    block1_schedule_layer_o
);

    wire [31:0]  model_addr_interscheduler_configmem;
    wire [31:0]  model_data_configmem_interscheduler;
    wire         model_read_valid_interscheduler_configmem;
    wire         model_read_ready_configmem_interscheduler;

    wire [31:0]  npu_capability_configmem_interscheduler;
    wire [31:0]  in_pipeline_capability_configmem_interscheduler;
    wire [31:0]  bubble_threshold_configmem_interscheduler;

    wire [31:0]  forward_length_configmem_intrascheduler;
    wire [31:0]  backward_length_configmem_intrascheduler;
    wire [31:0]  forward_breakpoint_configmem_intrascheduler;
    wire [31:0]  backward_breakpoint_configmem_intrascheduler;

    wire         block_finish_valid_interscheduler_intrascheduler;

    wire [31:0]  block0_start_intrascheduler_interscheduler;
    wire [31:0]  block1_start_intrascheduler_interscheduler;
    wire [31:0]  block0_length_intrascheduler_interscheduler;
    wire [31:0]  block1_length_intrascheduler_interscheduler;
    wire [1:0]   block_type_intrascheduler_interscheduler;

    model_config_mem i_model_config_mem
    (
        .clk_i                           (clk_i),

        .config_data_i                   (config_data_i),
        .config_addr_i                   (config_addr_i),
        .config_valid_i                  (config_valid_i),
        .config_ready_o                  (config_ready_o),

        .model_addr_i                    (model_addr_interscheduler_configmem),
        .model_data_o                    (model_data_configmem_interscheduler),
        .model_read_valid_i              (model_read_valid_interscheduler_configmem),
        .model_read_ready_o              (model_read_ready_configmem_interscheduler),

        .npu_capability_o                (npu_capability_configmem_interscheduler),
        .in_pipeline_capability_o        (in_pipeline_capability_configmem_interscheduler),
        .bubble_threshold_o              (bubble_threshold_configmem_interscheduler),
        .forward_length_o                (forward_length_configmem_intrascheduler),
        .backward_length_o               (backward_length_configmem_intrascheduler),
        .forward_breakpoint_o            (forward_breakpoint_configmem_intrascheduler),
        .backward_breakpoint_o           (backward_breakpoint_configmem_intrascheduler)
    );

    intra_layer_block_scheduler i_intra_layer_block_scheduler
    (
        .clk_i                           (clk_i),
        .rst_ni                          (rst_ni),

        .forward_length_i                (forward_length_configmem_intrascheduler),
        .backward_length_i               (backward_length_configmem_intrascheduler),
        .forward_breakpoint_i            (forward_breakpoint_configmem_intrascheduler),
        .backward_breakpoint_i           (backward_breakpoint_configmem_intrascheduler),

        .block_finish_valid_i            (block_finish_valid_interscheduler_intrascheduler),

        .block0_start_o                  (block0_start_intrascheduler_interscheduler),
        .block1_start_o                  (block1_start_intrascheduler_interscheduler),
        .block0_length_o                 (block0_length_intrascheduler_interscheduler),
        .block1_length_o                 (block1_length_intrascheduler_interscheduler),
        .block_type_o                    (block_type_intrascheduler_interscheduler)
    );

    inter_layer_block_scheduler i_inter_layer_block_scheduler
    (
        .clk_i                           (clk_i),
        .rst_ni                          (rst_ni),

        .npu_capability_i                (npu_capability_configmem_interscheduler),
        .in_pipeline_cim_capability_i    (in_pipeline_capability_configmem_interscheduler),
        .bubble_threshold_i              (bubble_threshold_configmem_interscheduler),

        .config_mem_addr_o               (model_addr_interscheduler_configmem),
        .config_mem_read_valid_o         (model_read_valid_interscheduler_configmem),
        .config_mem_read_data_i          (model_data_configmem_interscheduler),
        .config_mem_read_ready_i         (model_read_ready_configmem_interscheduler),

        .block_type_i                    (block_type_intrascheduler_interscheduler),
        .block0_start_i                  (block0_start_intrascheduler_interscheduler),
        .block1_start_i                  (block1_start_intrascheduler_interscheduler),
        .block0_length_i                 (block0_length_intrascheduler_interscheduler),
        .block1_length_i                 (block1_length_intrascheduler_interscheduler),


        .schedule_valid_i                (schedule_valid_i),
        .schedule_ready_o                (schedule_ready_o),
        .block_finish_valid_o            (block_finish_valid_interscheduler_intrascheduler),
        .block0_finish_o                 (block0_finish_o),
        .block1_finish_o                 (block1_finish_o),
        .schedule_type_o                 (schedule_type_o),
        .block_type_o                    (block_type_o),
        .block0_schedule_layer_o         (block0_schedule_layer_o),
        .block1_schedule_layer_o         (block1_schedule_layer_o)
    );

endmodule