module intra_layer_block_scheduler_tb;

    reg block_finish_valid, clk, rst_n;

    reg [31:0] forward_length, backward_length,
                forward_breakpoint, backward_breakpoint;

    wire [31:0] block0_start, block0_length,
                block1_start, block1_length;

    wire [1:0] block_type;

    initial
    begin
        $dumpfile("build/intra_layer_block_scheduler_tb.vcd");
        $dumpvars(0, scheduler_tb);
    end

    initial
    begin
        clk = 1;
        rst_n = 0;
        block_finish_valid = 0;
        forward_length = 10;
        backward_length = 4;
        forward_breakpoint = 7;
        backward_breakpoint = 3;

        #10 rst_n = 1;
        #20 block_finish_valid = 1;
        #10 block_finish_valid = 0;
        #30 block_finish_valid = 1;
        #20 block_finish_valid = 0;
        #40 block_finish_valid = 1;
        #30 block_finish_valid = 0;

        #30 $finish;
    end

    always #5 clk = ~clk;

    intra_layer_block_scheduler dut
    (
        .clk_i (clk),
        .rst_ni (rst_n),

        .block_finish_valid_i (block_finish_valid),

        .forward_length_i (forward_length),
        .backward_length_i (backward_length),
        .forward_breakpoint_i (forward_breakpoint),
        .backward_breakpoint_i (backward_breakpoint),

        .block0_start_o (block0_start),
        .block1_start_o (block1_start),
        .block0_length_o (block0_length),
        .block1_length_o (block1_length),
        .block_type_o (block_type)
    );

endmodule