FPGA 仿真
=========

.. contents:: Table of Contents


.. attention::

   使用 GUI 界面虽然简单，但是效率很低，而且 Vivado 的 GUI 做得很差。
   我们推荐你使用 TCL（Tooling Command Language）操作 Vivado。
   请自行查看 CVA6 项目中完整的 Vivado 流程，我们只会解释部分重要的 TCL 片段。

在 <cva6> 路径下运行 ``make fpga``，该脚本会搜索所有的 RTL 源文件并将其添加到 ``<cva6>/corev_apu/fpga/scripts/add_sources.tcl``。

接着会在 ``<cva6>/corev_apu/fpga`` 中运行对应的 Makefile。
这个脚本首先会遍历 ``<cva6>/corev_apu/fpga/xilinx`` 目录中所有的 IP 文件夹，生成 IP 并综合。
然后运行 ``<cva6>/corev_apu/fpga/scripts`` 目录中的 ``prologue.tcl`` 和 ``run.tcl`` 综合源文件，最后布局布线生成 bitstream。

脚本修改
^^^^^^^^^^^^^^^^^^^

为了实现 FPGA 的移植，我们需要修改部分脚本和源文件。

- ``<cva6>/Makefile``：``XILINX_PART`` ``XILINX_BOARD`` 修改。
- ``<cva6>/corev_apu/fpga/Makefile``：只保留 ips 中的所需要 ``.xci``。
- ``<cva6>/corev_apu/fpga/scripts/run.tcl``：注释掉 read_ip 中不需要的 ``.xci``。
可以选择在 ``launch_runs`` 后添加选项 ``-jobs <cpu_core_nums>``。另外，如果需要挂接 SRAM，你需要注释掉如下几行代码：

.. code-block::

   # launch_runs -jobs 24 impl_1 -to_step write_bitstream
   # wait_on_run impl_1
   # open_run impl_1

并替换成如下的代码：

.. code-block::

   open_run impl_1
   set_property SEVERITY {Warning} [get_drc_checks LUTLP-1]
   set_property IS_ENABLED 0 [get_drc_checks {CSCL-1}]
   write_bitstream -force work-fpga/${project}.bit

否则，Vivado 会报 combinational loop 的错。

- ``<cva6>/corev_apu/fpga/src/ariane_xilinx.sv``：根据需求，注释掉不需要的部分。
- ``<cva6>/corev_apu/fpga/src/ariane_peripherals_xilinx.sv``：根据需求，注释掉不需要的部分。



导入源文件
^^^^^^^^^^^

CVA6 项目中，在 ``<cva6>`` 目录下运行 ``make fpga``，即可生成获取所有源文件的 TCL 脚本。
该文件为 ``<cva6>/corev_apu/fpga/src/scripts/add_sources.tcl``。
我们需要仿照 ``<cva6>/Makefile`` 中 ``fpga`` 标签下的写法，将我们自定义的源文件也添加到 ``add_sources.tcl`` 中。


IP生成
^^^^^^^^^^^

Vivado 中提供了许多 IP（Intellectual Property），因此我们需要生成时钟和 BRAM 的 IP。

.. attention::

   我们最终不会使用 IP，需要替换为自己实现的 RTL。

我们给出 CVA6 中是如何生成这些 IP 的。

1. 设置一些环境变量。

.. code-block::

   set partNumber $::env(XILINX_PART)
   set boardName  $::env(XILINX_BOARD)
   
   set ipName xlnx_axi_clock_converter

获取 FPGA 芯片的型号、板卡的名称和 IP 核心的名称。

2. 建一个新的项目。

.. code-block::
   
   create_project $ipName . -force -part $partNumber
   set_property board_part $boardName [current_project]
   create_ip -name axi_clock_converter -vendor xilinx.com -library ip -module_name $ipName
   set_property -dict [list CONFIG.ADDR_WIDTH {64} CONFIG.DATA_WIDTH {64} CONFIG.ID_WIDTH {5}] [get_ips $ipName]

项目的名称为 IP 核心的名称，项目的位置为当前目录，如果项目已经存在则强制覆盖，项目的 FPGA 芯片型号为前面从环境变量中获取的型号。
设置当前项目的板卡名称为前面从环境变量中获取的名称。

创建一个新的 IP 核心，核心的名称为 axi_clock_converter，供应商为 xilinx.com，库为 ip，模块的名称为前面设置的 IP 核心的名称。

设置 IP 核心的地址宽度为 64 位，数据宽度为 64 位，ID 宽度为 5 位。

3. IP 综合。

.. code-block::

   generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
   generate_target all [get_files  ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
   create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
   launch_run -jobs <num of CPUs> ${ipName}_synth_1
   wait_on_run ${ipName}_synth_1

首先生成 IP 核心的实例化模板。
实例化模板是一个包含了如何实例化 IP 核心的代码的文件。
然后，生成所有目标。
在这里，所有目标可能包括了实例化模板、综合结果、实现结果等。

创建一个 IP 核心的运行。
在这里，运行是一个包含了如何综合和实现 IP 核心的流程的对象。
启动 IP 核心的综合。在这里，``-jobs <num of CPUs>`` 参数表示使用几个 CPU 来执行综合。
最后等待综合完成，确保在继续执行后续的脚本之前，综合已经成功完成。

4. 重复步骤 1 ~ 3，直到所有的 IP 都已经生成。

.. attention::

   如果不清楚生成 IP 的 TCL 脚本怎么写，可以在 Vivado 的 GUI 界面中生成 IP，然后观察底部的 TCL Console 中对应的指令。

一般而言，在 FPGA 验证中需要的 IP 为时钟生成器（将固定的晶振频率分频到所需的频率）、BRAM（Block RAM，用于替换需要用到 SRAM 的地方，如 Cache、Global Buffer 等）。

.. Warning::

   TODO：BRAM 参数的详细解析。



管脚约束
^^^^^^^^^^^^^^

1. FPGA 设计项目的创建和一些参数的设置。

.. code-block::

   set project ariane
   create_project $project . -force -part $::env(XILINX_PART)
   set_property board_part $::env(XILINX_BOARD) [current_project]
   # set number of threads to 8 (maximum, unfortunately)
   set_param general.maxThreads 8
   set_msg_config -id {[Synth 8-5858]} -new_severity "info"
   set_msg_config -id {[Synth 8-4480]} -limit 1000

设置变量 project，其值为 ariane。
这个变量将被用作项目的名称。

创建一个新的项目，项目的名称为 project 变量的值，即 ariane。
项目的位置是当前目录（.）。
-force 选项表示如果项目已经存在，则覆盖它。
-part $::env(XILINX_PART) 选项表示项目的 FPGA 芯片型号为环境变量 XILINX_PART 的值。

设置了当前项目的板卡型号为环境变量 XILINX_BOARD 的值、Vivado 的最大线程数为 8。
改变消息 Synth 8-5858 的严重性级别为 "info"，Synth 8-4480 的最大显示次数为 1000。

2. IP 的读取、包含目录的设置以及顶层设计的设置。

``read_ip {...}``：读取了一系列 IP。
这些 IP 核的文件路径被包含在大括号 {} 中，每个路径都被双引号 "" 包围。
这些 IP 包括 DDR3 内存接口、AXI 时钟转换器、AXI 数据宽度转换器、AXI GPIO、AXI Quad SPI 和时钟生成器等。

``set_property include_dirs {...} [current_fileset]``：这个命令设置了当前文件集的包含目录。
这些目录包含了设计所需的头文件。
这些目录的路径被包含在大括号 {} 中，每个路径都被双引号 "" 包围。

``source scripts/add_sources.tcl``：这个命令执行了一个 Tcl 脚本 add_sources.tcl。
这个脚本可能包含了一些添加源文件的命令。

``set_property top ${project}_xilinx [current_fileset]``：这个命令设置了当前文件集的顶层设计。
顶层设计的名称为 ${project}_xilinx，其中 ${project} 是一个变量，其值应该在之前的代码中被设置。

3. 向设计项目中添加约束文件。

``add_files -fileset constrs_1 -norecurse constraints/$project.xdc``：这个命令向名为 constrs_1 的文件集中添加了一个约束文件。
约束文件的路径为 constraints/$project.xdc，其中 $project 是一个变量，其值应该在之前的代码中被设置。
-norecurse 选项表示不递归地添加目录中的文件，也就是说，只添加指定的文件，不添加该文件所在目录下的其他文件。

.. attention::

   在约束文件中加入 ``set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets tck_IBUF]``，否则 Vivado 会报错。


.. Hint::

   建议将时钟信号引出，约束到 led 上，以便观察时钟信号是否存在。


生成 Bitstream
^^^^^^^^^^^^

.. code-block::

   add_files -fileset constrs_1 -norecurse constraints/$project.xdc
   synth_design -rtl -name rtl_1
   set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
   launch_runs synth_1
   wait_on_run synth_1
   open_run synth_1


启动名为 rtl_1 的 RTL 级别的综合。
设置 synth_1 综合步骤的参数，使得综合过程中进行重时序操作。重时序可以优化设计的时序性能。
最终启动名为 synth_1 的综合流程，并打开 synth_1 的综合流程的结果。
这个结果包括了综合报告、网表文件等。

.. code-block::

   # set for RuntimeOptimized implementation
   set_property "steps.place_design.args.directive" "RuntimeOptimized" [get_runs impl_1]
   set_property "steps.route_design.args.directive" "RuntimeOptimized" [get_runs impl_1]

设置名为 impl_1 的实现流程中布局布线设计步骤的指令为 "RuntimeOptimized"。
"RuntimeOptimized" 指令会优化设计的运行时间。

.. code-block::

   launch_runs impl_1
   wait_on_run impl_1
   launch_runs impl_1 -to_step write_bitstream
   wait_on_run impl_1
   open_run impl_1

启动名为 `impl_1` 的实现流程，但只执行到 "write_bitstream" 步骤。
"write_bitstream" 步骤是实现流程的最后一个步骤，它生成了一个比特流文件，这个文件可以被下载到 FPGA 芯片上。
打开名为 `impl_1` 的实现流程的结果。
这个命令可以让用户查看实现流程的结果，包括布局布线的结果和比特流文件（.bit）。

.. Tip::

   .bit 文件是一个二进制文件，用于直接配置FPGA的硬件。
   当你设计并综合一个FPGA项目时，最终会生成一个.bit文件。
   这个文件包含了用于配置FPGA的所有必要信息，如查找表（LUTs）、寄存器等的配置数据。
   通常，这个文件是通过JTAG或其他直接编程接口传输到FPGA的。
   一旦FPGA断电，这个配置就会丢失。

.. hint::

   如果你想要 FPGA 每次启动时都能自动加载所需的配置，那你需要将 .bit 文件转换成 .mcs 文件（Memory Configuration Stream）。
   这是一个用于非易失性存储器编程的文件，比如用于配置PROM（Programmable Read-Only Memory）或者闪存。

报告
^^^^^^^^^^^^^^^^

.. code-block::

   check_timing -verbose                                                   -file reports/$project.check_timing.rpt
   report_timing -max_paths 100 -nworst 100 -delay_type max -sort_by slack -file reports/$project.timing_WORST_100.rpt
   report_timing -nworst 1 -delay_type max -sort_by group                  -file reports/$project.timing.rpt
   report_utilization -hierarchical                                        -file reports/$project.utilization.rpt
   report_cdc                                                              -file reports/$project.cdc.rpt
   report_clock_interaction                                                -file reports/$project.clock_interaction.rpt

生成 FPGA 设计的各种报告，包括时序报告、资源利用率报告、CDC 报告和时钟交互报告。

.. code-block::

   # output Verilog netlist + SDC for timing simulation
   write_verilog -force -mode funcsim work-fpga/${project}_funcsim.v
   write_verilog -force -mode timesim work-fpga/${project}_timesim.v
   write_sdf     -force work-fpga/${project}_timesim.sdf

生成 Verilog 网表和 SDF 文件，用于功能仿真和时序仿真。
这是 FPGA 设计流程的一部分，通过这个步骤，可以对设计进行仿真，验证设计的功能和时序。





综合后仿真
^^^^^^^^^^^^^^^^

打开 GUI 界面，添加 Testbench 到源文件中并设置为顶层，然后即可仿真。

如果需要修改 BRAM 的初始值，可以单独重新综合生成一个名称相同的 BRAM，避免整个项目重新综合。

.. Warning::

   TODO：详细解释单独综合 BRAM 的步骤，配图。




Bitstream 验证
^^^^^^^^^^^^^^^^^


RISC-V 官方推荐的调试平台即为 OpenOCD，因此我们也采用 OpenOCD 作为我们 SoC 的调试工具。
安装方法如下：

.. code-block::

   $ git clone https://github.com/riscv/riscv-openocd
   $ sudo apt-get install libftdi-dev libusb-1.0-0 libusb-1.0-0-dev autoconf automake texinfo pkg-config
   $ cd riscv-openocd
   $ ./bootstrap
   $ ./configure --enable-ftdi
   $ make -j<number of your cpus>
   $ sudo make install

如果你安装成功，执行如下指令，你会看到类似的输出：

.. code-block::

   $ which openocd
   /usr/local/bin/openocd
   $ openocd -v
   Open On-Chip Debugger 0.12.0+dev-03598-g78a719fad (2024-01-20-05:43)
   Licensed under GNU GPL v2
   For bug reports, read
           http://openocd.org/doc/doxygen/bugs.html

.. Tip::

   如果你想查阅有关 OpenOCD 的使用方法，请参考 `官方文档 <https://openocd.org/doc/pdf/openocd.pdf>`__ 。


OpenOCD 可以看作调试主机（Debug Host）所运行的一个软件，它一般通过主机的 USB 接口发送信号。
我们所实现的 SoC 对外的调试接口是 JTAG（joint Test Action Group，是一种用于测试集成电路的标准接口和协议）。
二者之间需要 JTAG Adapter 用于信号的格式转换。

我们所使用的 JTAG Adapter 中最关键的芯片称为 `FTDI <https://ftdichip.com/wp-content/uploads/2020/07/DS_FT232H.pdf>`__ （Future Technology Devices International），它负责输出 JTAG 信号。
连接到 PC 后，``lsusb`` 的输出中会有如下一条：

.. code-block::

   Bus <bus id> Device <device id>: ID 0403:6014 Future Technology Devices International, Ltd FT232H Single HS USB-UART/FIFO IC

下面是使用 OpenOCD 调试 FPGA 的步骤：

1. 烧录 bitstream 到 FPGA 上。

在 Vivado GUI 中，打开 hardware manager，将生成的 bitstream 通过 jtag 接口烧录至 FPGA 中。

2. 连接 PC 和 FPGA。

JTAG Adapter 的 USB 端接入 PC，另一端接到实例化 SoC 中 JTAG 对应的约束管脚。

3. 在 PC 中启动 OpenOCD。

.. code-block::

   $ cd <cva6>/corev_apu/fpga
   $ sudo openocd -f ariane.cfg

``ariane.cfg`` 中定义了如何通过 JTAG 接口对一个 RISC-V 设备进行调试。

.. code-block::

   adapter speed  100
   adapter driver ftdi

设置适配器的速度为 100 kHz，并指定其驱动为 FTDI。

.. code-block::

   ftdi vid_pid 0x0403 0x6014

   # Channel 1 is taken by Xilinx JTAG
   ftdi channel 0

指定 FTDI 芯片的 VID 和 PID，这两个参数用于在 USB 设备中唯一标识一个设备。
并指定使用 FTDI 芯片的哪个通道进行 JTAG 调试。

.. code-block::

   ftdi layout_init 0x0018 0x001b
   ftdi layout_signal nTRST -ndata 0x0010

设置 JTAG 的引脚布局。
``ftdi layout_init`` 设置初始的引脚状态，``ftdi layout_signal`` 设置 nTRST 信号的引脚。

.. code-block::

   set _CHIPNAME riscv
   jtag newtap $_CHIPNAME cpu -irlen 5
   
   set _TARGETNAME $_CHIPNAME.cpu
   target create $_TARGETNAME riscv -chain-position $_TARGETNAME -coreid 0

创建一个新的 JTAG TAP，并创建一个目标设备。
这里的目标设备是一个 RISC-V 架构的 CPU。

.. code-block::

   gdb_report_data_abort enable
   gdb_report_register_access_error enable
   
   riscv set_reset_timeout_sec 120
   riscv set_command_timeout_sec 120

设置一些 GDB 的参数，以及 RISC-V 的超时时间。

.. code-block::
   # prefer to use sba for system bus access
   riscv set_mem_access progbuf sysbus abstract
   
   # Try enabling address translation (only works for newer versions)
   if { [catch {riscv set_enable_virtual on} ] } {
       echo "Warning: This version of OpenOCD does not support address translation. To debug on virtual addresses, please update to the latest version." }

设置 RISC-V 的内存访问方式，优先使用 system bus access，尝试启用地址转换功能。

.. code-block::

   init
   halt
   echo "Ready for Remote Connections"

执行 ``init`` 和 ``halt`` 指令，初始化 JTAG 调试器并暂停目标设备的运行。

如果你能成功启动 OpenOCD，终端中会输出如下信息：

.. code-block::

   Open On-Chip Debugger 0.12.0+dev-03598-g78a719fad (2024-01-20-05:43)
   Licensed under GNU GPL v2
   For bug reports, read
           http://openocd.org/doc/doxygen/bugs.html
   Info : auto-selecting first available session transport "jtag". To override use 'transport select <transport>'.
   Info : clock speed 100 kHz
   Info : JTAG tap: riscv.cpu tap/device found: 0x00000001 (mfg: 0x000 (<invalid>), part: 0x0000, ver: 0x0)
   Info : [riscv.cpu] datacount=2 progbufsize=8
   Info : [riscv.cpu] Examined RISC-V core
   Info : [riscv.cpu]  XLEN=64, misa=0x800000000014112d
   [riscv.cpu] Target successfully examined.
   Info : [riscv.cpu] Examination succeed
   Info : starting gdb server for riscv.cpu on 3333
   Info : Listening on port 3333 for gdb connections
   Ready for Remote Connections
   Info : Listening on port 6666 for tcl connections
   Info : Listening on port 4444 for telnet connections

4. 使用 gdb 连接 OpenOCD。

.. code-block::

   $ <riscv-gcc-toolchain>/bin/riscv-none-elf-gdb /path/to/elf
   GNU gdb (GDB) 14.0.50.20230114-git
   Copyright (C) 2022 Free Software Foundation, Inc.
   License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
   This is free software: you are free to change and redistribute it.
   There is NO WARRANTY, to the extent permitted by law.
   Type "show copying" and "show warranty" for details.
   This GDB was configured as "--host=x86_64-pc-linux-gnu --target=riscv-none-elf".
   Type "show configuration" for configuration details.
   For bug reporting instructions, please see:
   <https://www.gnu.org/software/gdb/bugs/>.
   Find the GDB manual and other documentation resources online at:
       <http://www.gnu.org/software/gdb/documentation/>.
   
   For help, type "help".
   Type "apropos word" to search for commands related to "word".
   (gdb) target remote: 3333
   (gdb)

接着，你就可以通过 GDB 调试程序和访问内存了。
一些常用的 GDB 指令如下：

- ``x/10w 0x12345``：以字（4 字节）为单位，查看地址 0x12345 开始的 10 个字的内容。
- ``x/i``：一种特殊的格式，用于将内存中的内容解释为机器指令。i 代表 "instruction"，即指令。例如，`x/i $pc` 这条命令会显示程序计数器（PC）当前指向的机器指令。
- ``info registers``：列出所有寄存器的值。
- ``set {int}0x54321 = 0xabcdf``：将地址 0x54321 处的 4 个字节的内容设置为 16 进制的 abcdf。
- ``stepi``：执行 pc 地址对应的指令。

.. Hint::

   ROM（只读存储器）是一种只能读取不能写入的存储器。
   如果你试图在 GDB 中使用 ``set`` 命令写入 ROM 地址的数据，GDB 可能不会显示错误，但实际上数据并没有被写入 ROM。
   当你使用 ``x`` 命令读取该地址时，GDB 可能会显示你之前尝试写入的数据，但这只是 GDB 内部状态的一部分，不代表实际的硬件状态。
   在真实的硬件中，ROM 的内容在写入后就不能更改。


.. note::

   This section is under development.
