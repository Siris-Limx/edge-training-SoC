module model_config_mem_tb;

    reg clk;

    initial
    begin
        clk = 1;
    end

    always #5 clk = ~clk;

    model_config_mem dut
    (
        .clk_i (clk)
    );

endmodule