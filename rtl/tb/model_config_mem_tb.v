`include "rtl/include/define.v"

module model_config_mem_tb;

    reg clk, config_valid, model_read_valid;
    reg [31:0] config_data, config_addr, model_addr;
    wire [31:0] model_data;

    task config_mem;
        input [31:0] addr_val;
        input [31:0] data_val;

        begin
            #10
            config_addr = addr_val;
            config_data = data_val;
            config_valid = 1;
            #10
            config_valid = 0;
        end
    endtask

    task read_mem;
        input [31:0] addr_val;

        begin
            #10
            model_addr = addr_val;
            model_read_valid = 1;
            #10
            model_read_valid = 0;
            if (model_addr[10:8] == `INTERMEDIATE_MEM)
                $display("intermediate_table[%2d] = %0d", addr_val[4:0], model_data);
            else if (model_addr[10:8] == `FORWARD_COMPUTE)
                $display("forward_compute_table[%2d] = %0d", addr_val[4:0], model_data);
            else if (model_addr[10:8] == `BACKWARD_COMPUTE)
                $display("backward_compute_table[%2d] = %0d", addr_val[4:0], model_data);
        end
    endtask

    always #5 clk = ~clk;

    model_config_mem dut
    (
        .clk_i (clk),
        .config_data_i (config_data),
        .config_addr_i (config_addr),
        .config_valid_i (config_valid),

        .model_addr_i (model_addr),
        .model_read_valid_i (model_read_valid),
        .model_data_o (model_data)
    );

    initial
    begin
        clk = 1;
        config_valid = 0;

        /* ----------------------- load data to `model_params` ---------------------- */

        // initialize `model_params` to 0
        for (integer i = 0; i < 32; i = i + 1)
            config_mem(i, 0);

        // model type
        config_mem(`MODEL_TYPE, `TRANSFORMER);

        // batch size
        config_mem(`BATCH_SIZE, 4);

        // forward length
        config_mem(`FORWARD_LENGTH, 12);

        // backward length
        config_mem(`BACKWARD_LENGTH, 6);

        // sequence length
        config_mem(`TRANSFORMER_SEQ_LENGTH, 2);

        // attention head
        config_mem(`TRANSFORMER_ATTEN_HEAD, 12);

        // hidden dim
        config_mem(`TRANSDORMER_HIDDEN_DIM, 64);


        /* ------------------ load data to `forward_sparsity_table` ----------------- */

        // initialize `forward_sparsity_table` to 0
        for (integer i = 0; i < 32; i = i + 1)
            config_mem(i + (`FORWARD_SPARSITY << 8), 0);

        // layer 3-5 sparsity ratio = 15
        for (integer i = 3; i < 6; i = i + 1)
            config_mem(i + (`FORWARD_SPARSITY << 8), 15);

        // layer 6-8 sparsity ratio = 25
        for (integer i = 6; i < 9; i = i + 1)
            config_mem(i + (`FORWARD_SPARSITY << 8), 25);

        // layer 9-11 sparsity ratio = 80
        for (integer i = 9; i < 12; i = i + 1)
            config_mem(i + (`FORWARD_SPARSITY << 8), 80);


        /* ----------------- load data to `backward_sparsity_table` ----------------- */

        // initialize `backward_sparsity_table` to 0
        for (integer i = 0; i < 32; i = i + 1)
            config_mem(i + (`BACKWARD_SPARSITY << 8), 0);

        // layer 6-8 sparsity ratio = 66
        for (integer i = 6; i < 9; i = i + 1)
            config_mem(i + (`BACKWARD_SPARSITY << 8), 66);


        /* ------------------------ read intermediate memory ------------------------ */

        $display("\nread intermediate memory:");
        for (integer i = 0; i < 16; i = i + 1)
            read_mem(i + (`INTERMEDIATE_MEM << 8));


        /* ----------------------- read forward_compute memory ---------------------- */

        $display("\nread forward compute memory:");
        for (integer i = 0; i < 16; i = i + 1)
            read_mem(i + (`FORWARD_COMPUTE << 8));


        /* ---------------------- read backward_compute memory ---------------------- */

        $display("\nread backward compute memory:");
        for (integer i = 0; i < 16; i = i + 1)
            read_mem(i + (`BACKWARD_COMPUTE << 8));
    end

endmodule