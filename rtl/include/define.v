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
`define BUBBLE_THRESHOLD        3
`define MODEL_TYPE              4
`define BATCH_SIZE              5
`define FORWARD_LENGTH          6
`define BACKWARD_LENGTH         7
`define TRANSFORMER_SEQ_LENGTH  8
`define TRANSFORMER_ATTEN_HEAD  9
`define TRANSDORMER_HIDDEN_DIM  10
`define CNN_
`define FORWARD_BREAKPOINT      30
`define BACKWARD_BREAKPOINT     31

// model type
`define TRANSFORMER 0
`define CNN         1


/* ----------------------- inter_layer_block_scheduler ---------------------- */

// state machine
`define IDLE        3'b000
`define LOAD        3'b001
`define COMPARE     3'b010
`define FUSE        3'b011
`define SHARE       3'b100
`define SCHEDULE    3'b101

// compute buffer index
`define BLOCK0_CIM  2'b00
`define BLOCK1_CIM  2'b01
`define BLOCK0_NPU  2'b10
`define BLOCK1_NPU  2'b11

// schedule type
`define BLOCK0_CIM_BLOCK1_NPU   1'b0
`define BLOCK0_NPU_BLOCK1_CIM   1'b1

// compute less flag
`define BLOCK0_LESS 1'b0
`define BLOCK1_LESS 1'b1

// enable simulation
`define SIMULATION

`endif