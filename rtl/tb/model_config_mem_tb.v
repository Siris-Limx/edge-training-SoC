module model_config_mem_tb;

    reg clk, config_valid;
    reg [31:0] config_data, config_addr;

    initial
    begin
        clk = 1;
        config_valid = 0;

        // load data to `model_params`
        for (integer i = 0; i < 10; i = i + 1)
        begin
            #10
            config_addr = i;
            config_data = i;
            config_valid = 1;
            #10
            config_valid = 0;
        end

        // load data to `forward_sparsity_table`
        for (integer i = 0; i < 32; i = i + 1)
        begin
            #10
            config_data = 70 + i;
            config_addr = i + (1 << 8);
            config_valid = 1;

            #10
            config_valid = 0;
        end
    end

    always #5 clk = ~clk;

    model_config_mem dut
    (
        .clk_i (clk),
        .config_data_i (config_data),
        .config_addr_i (config_addr),
        .config_valid_i (config_valid)
    );

endmodule