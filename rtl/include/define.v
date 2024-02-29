/* -------------------------------------------------------------------------- */
/* ----------------------- Author: Mingxuan (Siris) Li ---------------------- */
/* -------------------------------------------------------------------------- */


`ifndef DEFINE_VH_
`define DEFINE_VH_

/* ----------------------- intra_layer_block_scheduler ---------------------- */

// simultaneous forward & backward pattern
`define FORWARD_FORWARD   2'b00
`define FORWARD_BACKWARD  2'b01
`define BACKWARD_FORWARD  2'b10
`define BACKWARD_BACKWARD 2'b11



/* ---------------------------- model_config_mem ---------------------------- */

// address offset
`define MODEL_PARAM       3'b000
`define FORWARD_SPARSITY  3'b001
`define BACKWARD_SPARSITY 3'b010
`define INTERMEDIATE_MEM  3'b011
`define FORWARD_COMPUTE   3'b100
`define BACKWARD_COMPUTE  3'b101
`define UNDEFINED         3'b111

// model parameter
`define IN_PIPELINE_CAPABILITY  0
`define NPU_CAPABILITY          1
`define MEMORY_BOUNDARY         2
`define MODEL_TYPE              3
`define BATCH_SIZE              4
`define FORWARD_LENGTH          5
`define BACKWARD_LENGTH         6
`define TRANSFORMER_SEQ_LENGTH  7
`define TRANSFORMER_ATTEN_HEAD  8
`define TRANSDORMER_HIDDEN_DIM  9
`define FORWARD_BREAKPOINT      30
`define BACKWARD_BREAKPOINT     31

// model type
`define TRANSFORMER 0
`define CNN         1

// enable simulation
`define SIMULATION

`endif