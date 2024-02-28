iverilog  -o build/model_config_mem_tb rtl/src/model_config_mem.v rtl/tb/model_config_mem_tb.v
vvp build/model_config_mem_tb
@REM gtkwave build/model_config_mem_tb.vcd