/* -------------------------------------------------------------------------- */
/* ----------------------- Author: Mingxuan (Siris) Li ---------------------- */
/* -------------------------------------------------------------------------- */

`timescale 1ns/1ns

module model_config_mem
(
    input clk_i,

    input [31:0] config_data_i,
    input [31:0] config_addr_i,
    input config_valid_i,
    output reg config_ready_o,

    input [31:0] model_addr_i,
    output [31:0] model_data_o,
    input model_read_valid_i
);

    reg [31:0] model_params[0:31];              // addr offset = 0x000
    reg [31:0] forward_sparsity_table[0:31];    // addr offset = 0x100
    reg [31:0] backward_sparsity_table[0:31];   // addr offset = 0x200
    reg [31:0] intermediate_table[0:31];        // addr offset = 0x300
    reg [31:0] forward_compute_table[0:31];     // addr offset = 0x400
    reg [31:0] backward_compute_table[0:31];    // addr offset = 0x500

    // address offset definitions
    localparam  MODEL_PARAM = 3'b000,
                FORWARD_SPARSITY = 3'b001,
                BACKWARD_SPARSITY = 3'b010,
                INTERMEDIATE_MEM = 3'b011,
                FORWARD_COMPUTE = 3'b100,
                BACKWARD_COMPUTE = 3'b101,
                UNDEFINED = 3'b111;

    localparam  TRANSFORMER = 0, CNN = 1;

    wire [2:0] mem_select;
    assign mem_select = config_valid_i
                      ? config_addr_i[10:8]
                      : model_read_valid_i
                      ? model_addr_i[10:8]
                      : UNDEFINED;

    wire [4:0] addr_select;
    assign addr_select = config_valid_i
                       ? config_addr_i[4:0]
                       : model_read_valid_i
                       ? model_addr_i[4:0]
                       : 5'b0;

    // only forward_mem, backward_mem, forward_compute, backward_compute can be read
    assign model_data_o = mem_select == INTERMEDIATE_MEM
                        ? intermediate_table[addr_select]
                        : mem_select == FORWARD_COMPUTE
                        ? forward_compute_table[addr_select]
                        : mem_select == BACKWARD_COMPUTE
                        ? backward_compute_table[addr_select]
                        : 32'b0;

    // only model_params, forward_sparsity_table, backward_sparsity_table can be written
    // sparsity range: 0 ~ 100
    always @(posedge clk_i)
    begin
        if (config_valid_i)
        begin
            config_ready_o <= 1'b1;

            case (mem_select)
                MODEL_PARAM:       model_params[addr_select]             <= config_data_i;
                FORWARD_SPARSITY:  forward_sparsity_table[addr_select]   <= config_data_i;
                BACKWARD_SPARSITY: backward_sparsity_table[addr_select]  <= config_data_i;
            endcase
        end
        else
            config_ready_o <= 1'b0;
    end

    // infer intermediate_table, forward_compute_table, backward_compute_table
    // from model_params, forward_sparsity_table, backward_sparsity_table

    // model_params definition:
    wire [31:0] in_pipeline_cim_capability,     // in-pipeline CIM computation capability
                npu_capability,                 // NPU computation capability
                memory_boundary,                // memory boundary
                model_type,                     // model type (transformer, CNN)
                batch_size,                     // batch size
                forward_length,                 // forward layer length
                backward_length,                // backward layer length
                transformer_seq_length,         // transformer sequence length
                transformer_attention_head,     // transformer attention head
                hidden_layer_size,              // transformer hidden layer size
                forward_breakpoint,             // forward breakpoint
                backward_breakpoint;            // backward breakpoint

    assign in_pipeline_cim_capability    = model_params[0];
    assign npu_capability                = model_params[1];
    assign memory_boundary               = model_params[2];
    assign model_type                    = model_params[3];
    assign batch_size                    = model_params[4];
    assign forward_length                = model_params[5];
    assign backward_length               = model_params[6];
    assign transformer_seq_length        = model_params[7];
    assign transformer_attention_head    = model_params[8];
    assign hidden_layer_size             = model_params[9];
    assign forward_breakpoint            = model_params[30];
    assign backward_breakpoint           = model_params[31];


    always @(*)
    begin
        // forward breakpoint = backward length
        // result in two layer blocks: [0, breakpoint-1] & [breakpoint, forward_length-1]
        model_params[30] = backward_length;

        // backward breakpoint = the first time overall memory usage exceeds memory boundary
        // TODO: implement backward breakpoint algorithm
    end

    always @(*)
    begin
        for (integer i = 0; i < 32; i = i + 1)
        begin
            intermediate_table[i] = 32'b0;

            if (i > backward_breakpoint && i < forward_length)
            begin
                if (model_type == TRANSFORMER)
                    // transformer intermediate algorithm:
                    // 14 * batch_size * seq_length * hidden_layer_size
                    // + 2 * batch_size * attention head * seq_length * seq_length
                    intermediate_table[i] = 14 * batch_size
                                          * transformer_seq_length * hidden_layer_size
                                          + 2 * batch_size * transformer_attention_head
                                          * transformer_seq_length * transformer_seq_length;
                else if (model_type == CNN)
                    // TODO: CNN intermediate algorithm
                    ;
            end
        end
    end

    // integer i;
    // always @(*)
    // begin
    //     for (i = 0; i < 32; i = i + 1)
    //     begin
    //         forward_compute_table[i] = 32'b0;

    //         if (i < forward_length)
    //         begin
    //             if (model_type == TRANSFORMER)
    //                 // transformer forward compute algorithm:
    //                 // 24 * forward_sparsity * batch_size * seq_length
    //                 // * hidden_layer_size * hidden_layer_size
    //                 forward_compute_table[i] = 24 * batch_size
    //                                         * transformer_seq_length * hidden_layer_size
    //                                         * hidden_layer_size * forward_sparsity_table[i];
    //             else if (model_type == CNN)
    //                 // TODO: CNN forward compute algorithm
    //         end
    //     end
    // end

    // always @(*)
    // begin
    //     for (int i = 0; i < 32; i = i + 1)
    //     begin
    //         backward_compute_table[i] = 32'b0;

    //         if (i > forward_length - backward_length && i < forward_length)
    //         begin
    //             if (model_type == TRANSFORMER)
    //                 // transformer backward compute algorithm:
    //                 // forward_compute * (100 + forward_sparsity * backward_sparsity / 100)
    //                 backward_compute_table[i] = forward_compute_table[i]
    //                 * (100 + ((backward_sparsity_table[i] * forward_sparsity_table[i]) >> 7));
    //             else if (model_type == CNN)
    //                 // TODO: CNN backward compute algorithm
    //         end

    //         else if (i == forward_length - backward_length)
    //         begin
    //             if (model_type == TRANSFORMER)
    //                 // transformer backward compute algorithm:
    //                 // forward_compute * forward_sparsity * backward_sparsity / 100
    //                 backward_compute_table[i] = forward_compute_table[i]
    //                 * ((backward_sparsity_table[i] * forward_sparsity_table[i]) >> 7);
    //             else if (model_type == CNN)
    //                 // TODO: CNN backward compute algorithm
    //         end
    //     end
    // end

`define SIM

`ifdef SIM
    initial
    begin
        $dumpfile("build/model_config_mem_tb.vcd");
        $dumpvars(0, model_config_mem);

        // model_params[0] = 3;
        // model_params[1] = 9;
        // model_params[2] = 100;
        // model_params[3] = TRANSFORMER;
        // model_params[4] = 32;
        // model_params[5] = 10;
        // model_params[6] = 4;
        // model_params[7] = 32;
        // model_params[8] = 12;
        // model_params[9] = 768;

        // for (integer i = 0; i < 32; i = i + 1)
        // begin
        //     model_params[i] = i;
        //     forward_sparsity_table[i] = 70;
        //     backward_sparsity_table[i] = 80;
        // end

        #10000
        for (integer i = 0; i < 32; i = i + 1)
        begin
            ;
            $display("model_params[%2d] = %2d", i, model_params[i]);
            $display("forward_sparsity_table[%2d] = %2d", i, forward_sparsity_table[i]);
        end

        // $display("model_params[30] = %2d", model_params[30]);

        #50 $finish;
    end

    initial
    begin
        ;
        $monitor("config_data_i = %0h @ time %0d\nconfig_addr_i = %0h @ time %0d\nmem_select = %0h @ time %0d\naddr_select = %0h @ time %0d", config_data_i, $time, config_addr_i, $time, mem_select, $time, addr_select, $time);
    end
`endif

endmodule