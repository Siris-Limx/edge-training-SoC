iverilog  -o build/scheduler_tb rtl/src/scheduler.v rtl/tb/scheduler_tb.v
vvp build/scheduler_tb
gtkwave build/scheduler_tb.vcd