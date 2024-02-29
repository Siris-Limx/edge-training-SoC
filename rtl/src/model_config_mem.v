/* -------------------------------------------------------------------------- */
/* ----------------------- Author: Mingxuan (Siris) Li ---------------------- */
/* -------------------------------------------------------------------------- */

`timescale 1ns/1ns

`include "rtl/include/define.v"

module model_config_mem
(
    input           clk_i,

    input [31:0]    config_data_i,
    input [31:0]    config_addr_i,
    input           config_valid_i,
    output reg      config_ready_o,

    input  [31:0]   model_addr_i,
    output [31:0]   model_data_o,
    input           model_read_valid_i,

    output [31:0]   forward_length_o,
    output [31:0]   backward_length_o,
    output [31:0]   forward_breakpoint_o,
    output [31:0]   backward_breakpoint_o
);

    reg [31:0] model_params[0:31];              // addr offset = 0x000
    reg [31:0] forward_sparsity_table[0:31];    // addr offset = 0x100
    reg [31:0] backward_sparsity_table[0:31];   // addr offset = 0x200
    reg [31:0] intermediate_table[0:31];        // addr offset = 0x300
    reg [31:0] forward_compute_table[0:31];     // addr offset = 0x400
    reg [31:0] backward_compute_table[0:31];    // addr offset = 0x500

    wire [2:0] mem_select;
    assign mem_select = config_valid_i
                      ? config_addr_i[10:8]
                      : model_read_valid_i
                      ? model_addr_i[10:8]
                      : `UNDEFINED;

    wire [4:0] addr_select;
    assign addr_select = config_valid_i
                       ? config_addr_i[4:0]
                       : model_read_valid_i
                       ? model_addr_i[4:0]
                       : 5'b0;


    /* -------------------------------- read mem -------------------------------- */
    // only forward_mem, backward_mem, forward_compute, backward_compute can be read
    assign model_data_o = mem_select == `INTERMEDIATE_MEM
                        ? intermediate_table[addr_select]
                        : mem_select == `FORWARD_COMPUTE
                        ? forward_compute_table[addr_select]
                        : mem_select == `BACKWARD_COMPUTE
                        ? backward_compute_table[addr_select]
                        : 32'b0;


    /* -------------------------------- write mem ------------------------------- */
    // only model_params, forward_sparsity_table, backward_sparsity_table can be written
    // sparsity range: 0 ~ 100
    always @(posedge clk_i)
    begin
        if (config_valid_i)
        begin
            config_ready_o <= 1'b1;

            case (mem_select)
                `MODEL_PARAM:
                    model_params[addr_select] <= config_data_i;
                `FORWARD_SPARSITY:
                begin
                    // forward layer range: [0 ~ forward_length-1]
                    if (addr_select < forward_length)
                        forward_sparsity_table[addr_select] <= config_data_i;
                    else
                        forward_sparsity_table[addr_select] <= 32'b0;
                end
                `BACKWARD_SPARSITY:
                begin
                    // backward layer range: [forward_length-backward_length ~ forward_length-1]
                    if (addr_select < forward_length && addr_select >= forward_length - backward_length)
                        backward_sparsity_table[addr_select] <= config_data_i;
                    else
                        backward_sparsity_table[addr_select] <= 32'b0;
                end
            endcase
        end
        else
            config_ready_o <= 1'b0;
    end


    /* ------------------------- model_params definition ------------------------ */
    wire [31:0] in_pipeline_cim_capability,     // in-pipeline CIM computation capability
                npu_capability,                 // NPU computation capability
                memory_boundary,                // memory boundary
                model_type,                     // model type (transformer, CNN)
                batch_size,                     // batch size
                forward_length,                 // forward layer length
                backward_length,                // backward layer length
                transformer_seq_length,         // transformer sequence length
                transformer_attention_head,     // transformer attention head
                transformer_hidden_layer_size,  // transformer hidden layer size
                forward_breakpoint,             // forward breakpoint
                backward_breakpoint;            // backward breakpoint

    assign in_pipeline_cim_capability    = model_params[`IN_PIPELINE_CAPABILITY];
    assign npu_capability                = model_params[`NPU_CAPABILITY];
    assign memory_boundary               = model_params[`MEMORY_BOUNDARY];
    assign model_type                    = model_params[`MODEL_TYPE];
    assign batch_size                    = model_params[`BATCH_SIZE];
    assign forward_length                = model_params[`FORWARD_LENGTH];
    assign backward_length               = model_params[`BACKWARD_LENGTH];
    assign transformer_seq_length        = model_params[`TRANSFORMER_SEQ_LENGTH];
    assign transformer_attention_head    = model_params[`TRANSFORMER_ATTEN_HEAD];
    assign transformer_hidden_layer_size = model_params[`TRANSDORMER_HIDDEN_DIM];
    assign forward_breakpoint            = model_params[`FORWARD_BREAKPOINT];
    assign backward_breakpoint           = model_params[`BACKWARD_BREAKPOINT];

    assign forward_length_o              = forward_length;
    assign backward_length_o             = backward_length;
    assign forward_breakpoint_o          = forward_breakpoint;
    assign backward_breakpoint_o         = backward_breakpoint;


    /* ------------- infer forward_breakpoint & backward_breakpoint ------------- */
    always @(*)
    begin
        // forward breakpoint = backward length
        // result in two layer blocks: [0, breakpoint-1] & [breakpoint, forward_length-1]
        model_params[30] = backward_length;

        // backward breakpoint = the first time overall memory usage exceeds memory boundary
        // TODO: implement backward breakpoint algorithm
    end

    /* ---------------------- infer intermediate activation --------------------- */
    always @(*)
    begin
        for (integer i = 0; i < 32; i = i + 1)
        begin
            intermediate_table[i] = 32'b0;

            if (i >= forward_length - backward_length && i < forward_length)
            begin
                if (model_type == `TRANSFORMER)
                    // transformer intermediate algorithm:
                    // 14 * batch_size * seq_length * hidden_layer_size
                    // + 2 * batch_size * attention head * seq_length * seq_length
                    intermediate_table[i] = 14 * batch_size
                                          * transformer_seq_length * transformer_hidden_layer_size
                                          + 2 * batch_size * transformer_attention_head
                                          * transformer_seq_length * transformer_seq_length;
                else if (model_type == `CNN)
                    // TODO: CNN intermediate algorithm
                    ;
            end
        end
    end


    /* ----------------------- infer forward_compute_table ---------------------- */
    wire [31:0] transformer_compute_coefficient;
    assign transformer_compute_coefficient = 24 * batch_size
                                           * transformer_seq_length * transformer_hidden_layer_size
                                           * transformer_hidden_layer_size;

    always @(*)
    begin
        for (integer i = 0; i < 32; i = i + 1)
        begin
            forward_compute_table[i] = 32'b0;

            if (i < forward_length)
            begin
                if (model_type == `TRANSFORMER)
                    // transformer forward compute algorithm:
                    // 24 * (100 - forward_sparsity) * batch_size * seq_length
                    // * hidden_layer_size * hidden_layer_size
                    forward_compute_table[i] = transformer_compute_coefficient * (100 - forward_sparsity_table[i]);
                else if (model_type == `CNN)
                    // TODO: CNN forward compute algorithm
                    ;
            end
        end
    end


    /* ---------------------- infer backward_compute_table ---------------------- */
    always @(*)
    begin
        for (integer i = 0; i < 32; i = i + 1)
        begin
            backward_compute_table[i] = 32'b0;

            if (i > forward_length - backward_length && i < forward_length)
            begin
                if (model_type == `TRANSFORMER)
                    // transformer backward compute algorithm:
                    // forward_compute * (100 + (100 - forward_sparsity) * (100 - backward_sparsity) / 100)
                    backward_compute_table[i] = transformer_compute_coefficient
                    * (100 + (((100 - backward_sparsity_table[i]) * (100 - forward_sparsity_table[i])) / 100));
                else if (model_type == `CNN)
                    // TODO: CNN backward compute algorithm
                    ;
            end

            else if (i == forward_length - backward_length)
            begin
                if (model_type == `TRANSFORMER)
                    // transformer backward compute algorithm:
                    // forward_compute * (100 - forward_sparsity) * (100 - backward_sparsity) / 100
                    backward_compute_table[i] = transformer_compute_coefficient
                    * (((100 - backward_sparsity_table[i]) * (100 - forward_sparsity_table[i])) / 100);
                else if (model_type == `CNN)
                    // TODO: CNN backward compute algorithm
                    ;
            end
        end
    end


    /* -------------------------- print mem information ------------------------- */
`ifdef SIMULATION
    initial
    begin
        $dumpfile("build/model_config_mem_tb.vcd");
        $dumpvars(0, model_config_mem);

        #10000
        // $display("\nGolden intermediate memory:");
        // $display("\nGolden forward_compute memory:");
        $display("\nGolden backward_compute memory:");
        for (integer i = 0; i < 16; i = i + 1)
        begin
            ;
            // $display("model_params           [%2d] = %0d", i, model_params[i]);
            // $display("forward_sparsity_table [%2d] = %0d", i, forward_sparsity_table[i]);
            // $display("backward_sparsity_table[%2d] = %0d", i, backward_sparsity_table[i]);
            // $display("forward_compute_table[%2d] = %0d", i, forward_compute_table[i]);
            $display("backward_compute_table[%2d] = %0d", i, backward_compute_table[i]);
            // $display("intermediate_table[%2d] = %0d", i, intermediate_table[i]);
        end

        // $display("batch_size        = %2d", batch_size);
        // $display("seq_length        = %2d", transformer_seq_length);
        // $display("hidden_layer_size = %2d", transformer_hidden_layer_size);
        // $display("attention_head    = %2d", transformer_attention_head);
        // $display("forward_length    = %2d", forward_length);
        // $display("backward_length   = %2d", backward_length);

        #50 $finish;
    end

    initial
    begin
        ;
        // $monitor("config_data_i = %0h @ time %0d\nconfig_addr_i = %0h @ time %0d\nmem_select = %0h @ time %0d\naddr_select = %0h @ time %0d", config_data_i, $time, config_addr_i, $time, mem_select, $time, addr_select, $time);
    end
`endif

endmodule