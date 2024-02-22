CPU 验证
================

.. contents:: Table of Contents



.. attention::

	如没有特别说明，默认运行环境为 Linux。
	Linux 下很多操作都是在终端（terminal）中进行，终端中运行的是 shell，Ubuntu 默认的 shell 为 bash。
	命令行操作有一定的学习成本，但请你一定坚持。
	我们会尽可能解释接下来的命令行操作，但绝大部分基础的内容仍需要你自行学习。


Setup
^^^^^^^^^^^^

1. 克隆仓库。

.. code-block::

	$ git clone https://github.com/openhwgroup/cva6.git
	$ cd cva6
	$ git checkout 1e78cc8e
	$ git submodule update --init --recursive

CVA6 一直在频繁地更新，这会导致一些端口定义改变或者文件结构调整。
我们需要和服务器上的 CVA6 版本对齐，因此使用 ``git checkout`` 切换到特定的 commit。

``git submodule update --init --recursive`` 是一个用于初始化和更新 Git 子模块的命令。
这个命令的各个部分的含义如下：

- ``git submodule``：这是 Git 的一个子命令，用于管理项目中的子模块。子模块允许你在一个 Git 仓库中包含另一个 Git 仓库。
- ``update``：这是 git submodule 的一个子命令，用于更新子模块。它会将子模块更新到在主项目中记录的提交。
- ``--init``：初始化子模块。如果子模块还没有被初始化（即，子模块的目录是空的），那么这个选项会先初始化子模块，然后再更新子模块。
- ``--recursive``：递归地更新子模块。如果一个子模块中还包含有其他的子模块，那么这个选项会递归地初始化和更新所有的子模块。

.. note::

	我们使用 ``<cva6>`` 代指该项目的根目录。
	例如你的 ``cva6`` 项目位于 ``/home/user/cva6``，则 ``<cva6> == /home/user/cva6``。

.. Important::

	Git 是最流行的代码版本管理工具，著名的 Github 就是依托于 Git 建立的。
	学习如何使用 Git 是基本功，任何开源项目都会用到它。
	因此，在继续下一步之前，强烈建议理解该步骤中 ``git`` 的行为。

2. 安装 GCC 工具链。

.. code-block::

	$ cd util/gcc-toolchain-builder
	$ export RISCV=<your desire RISC-V toolchain directory>
	$ sudo apt-get install autoconf automake autotools-dev curl git libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool bc zlib1g-dev
	$ sh get-toolchain.sh
	$ sh build-toolchain.sh $RISCV

你需要将 ``<your desire RISC-V toolchain directory>`` 换成一个真实的目录，它可以没有被创建，例如 ``/home/user/cva6/riscv-toolchain``。


.. attention::

	``riscv-none-elf-gcc`` 和 ``riscv64-unknown-elf-gcc`` 都是 RISC-V 架构的 GCC 编译器，但它们针对的 RISC-V 架构的位宽和目标系统可能有所不同。

	``riscv-none-elf-gcc``：这个编译器通常用于编译不依赖于特定操作系统的代码，例如嵌入式系统或裸机（bare-metal）系统的代码。
	"none" 表示没有目标操作系统。

	``riscv64-unknown-elf-gcc``：这个编译器针对的是 64 位的 RISC-V 架构，"64" 表示 64 位。
	"unknown" 表示目标系统的供应商未知。
	"elf" 表示目标文件格式是 ELF。
	这个编译器通常也用于编译不依赖于特定操作系统的代码。

.. note::

	实际上 ``<cva6>/util/gcc-toolchain-builder>`` 中有 ``README.md``，你可以自行根据其内容安装 GCC 工具链，我们也推荐你这么做，因为99%开源项目并没有本教程这样的保姆式文档。


.. Important::

	``export`` 指令是非常常见的 shell 指令，它为 shell 创建了环境变量（environmnet variable）。
	这个环境变量可以被当前的 shell 以及其子shell（例如运行 ``sh script.sh``，这里 ``script.sh`` 为当前 shell 的子 shell）所使用。
	如果你不确定你是否真的创建了该变量，可以在 shell 中输入 ``echo $RISCV``，输出应该和你所设置的值一致。

	如果不使用 ``export``，直接输入 ``RISCV=<your desire RISC-V toolchain directory>``，那么该变量不能被子 shell 使用。

	强烈建议你去了解常见的环境变量以及其作用，例如 ``PATH``，这对理解 shell 来说很重要。
	``PATH`` 简单来说，是 shell 搜索的默认路径。
	例如你输入 ``curl ipinfo.io``，shell 会从 ``PATH`` 的所有路径下寻找名为 ``curl`` 的可执行文件。
	你可以通过 ``which curl`` 指令来打印出该可执行文件的路径。

3. 安装必要的包。

.. code-block::

	$ sudo apt-get install help2man device-tree-compiler

4. 安装 Python 的环境依赖。

.. code-block::

	$ cd <cva6>
	$ pip3 install -r verif/sim/dv/requirements.txt

.. Important::

	我们非常建议你安装 `miniconda` 用来管理 Python 的环境。
	Python 不同版本之间并不兼容，因此最好每个项目都有一个独立的 Python 环境。

5. 安装 Spike 和 Verilator。

.. code-block::

	$ export DV_SIMULATORS=veri-testharness,spike
	$ bash verif/regress/smoke-tests.sh

在运行这条指令之前，请先查看该脚本的内容，试图理解这个脚本的行为。
实际上，该脚本首先会检查一些工具和测试样例是否下载，并安装没有下载的部分，然后批量运行测试。
如果你安装成功，你会在 ``<cva6>/tools`` 路径下发现 Spike 和 Verilator 的文件夹。

.. attention::

	实际上，你并不会有 ``<cva6>/tools/verilator*`` 这个文件夹。
	你会发现 verilator 被直接安装到了 ``<cva6>/tools/`` 文件夹下。
	这是因为，``<cva6>/verif/regress/smoke-tests.sh`` 在安装 verilator 前会先执行 ``source <cva6>/verif/sim/setup-env.sh``。
	这个脚本是设置一些环境变量，其中包括 ``VERILATOR_INSTALL_DIR`` 这个变量。
	如果你之前没有设置 ``VERILATOR_INSTALL_DIR``，那么它会自动设置为 ``<cva6>/tools/`` 路径下包含 verilator 的文件夹。
	由于你是第一次运行，``<cva6>/tools/`` 是一个空目录，因此 ``VERILATOR_INSTALL_DIR`` 会被设置为 ``<cva6>/tools/``。
	如果你有强迫症，可以在运行 ``<cva6>/verif/regress/smoke-tests.sh`` 之前设置 ``VERILATOR_INSTALL_DIR``。

6. 运行回归测试。

.. code-block::
	
	$ export DV_SIMULATORS=veri-testharness,spike
	$ bash verif/regress/dv-riscv-arch-test.sh

你应该会发现 ``<cva6>/verif/regress/smoke-tests.sh`` 不仅安装了仿真器，还安装了许多测试用例。
在 ``<cva6>/verif/regress`` 目录下，有很多回归测试的脚本，这些都可以运行。
我们建议你在运行回归测试之前，先了解脚本跑了什么指令，这对之后自定义测试用例有很大帮助。

Standalone Simulation
^^^^^^^^^^^^^^^^

如果你看过回归测试的脚本，很容易就发现 CVA6 Core 的回归测试是通过多次调用 ``<cva6>/verif/sim/cva6.py`` 来完成的。
我们自己写的 C 代码也需要通过 ``<cva6>/verif/sim/cva6.py`` 来进行 DiffTest。
CVA6 支持很多的仿真器，因此我们需要指定比较的两个仿真器。
一般而言，我们使用 Spike 和 Verilator，指定方式为添加环境变量：``export DV_SIMULATORS=veri-testharness,spike``。


.. Hint::

	如果你想知道 ``<cva6>/verif/sim/cva6.py`` 到底运行了什么，你可以在运行该文件时试着添加 ``--debug <your debug log output directory>``，或者使用 ``pdb`` 添加断点，利用 debugger 来了解其运行顺序。

你可以在任意路径下创建你自定义的 C 代码，例如 ``<custom path>/test.c``。
接下来，你只需要进入 ``cva6.py`` 所在的路径并运行该文件即可。

.. code-block::

	$ cd <cva6>/verif/sim
	$ python cva6.py --target cv32a60x --iss=$DV_SIMULATORS --iss_yaml=cva6.yaml --c_tests <custom path>/test.c --linker=../tests/custom/common/test.ld --gcc_opts="-static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g ../tests/custom/common/syscalls.c ../tests/custom/common/crt.S -lgcc -I../tests/custom/env -I../tests/custom/common"

这个 python 文件会进行如下5件事情：

1. 你之前安装的 riscv-none-elf-gcc 会将 ``test.c`` 编译成一个对象文件（``test.o``），它包含了源代码编译后的机器代码，但还没有被链接成可以执行的程序。如果你想查看你所写的 C 程序对应的汇编代码，你可以通过 ``riscv-none-elf-objdump -d test.o`` 生成该对象文件的反汇编文件（disassembly）。

2. riscv-none-elf-objcopy 会把 ``test.o`` 转换为一个二进制文件 ``test.bin``，这个二进制文件可以被直接加载到内存中执行。

3. 调用 Verilator 和仿真环境，加载二进制文件，记录仿真过程，输出到 ``<verilator output path>/test.csv``。

4. 调用 Spike 和仿真环境，加载二进制文件，记录仿真过程，输出到 ``<spike output path>/test.csv``。

5. 将 Verilator 和 Spike 生成的 CSV 文件进行比较，输出测试结果。

.. Important::

	本小节中各种文件的路径请根据 shell 中的输出来寻找。
	同时，我们强烈推荐你了解仿真过程中 Python 文件是怎么调用 Makefile，Makefile 是怎么调用 gcc，verilator 和 spike，最终完成仿真的。

GCC
################

gcc 执行的指令有两条，第一条为：

.. code-block::

	<cva6>/gcc-toolchain/bin/riscv-none-elf-gcc ../tests/custom/hello_world/hello_world.c          -I<cva6>/verif/sim/dv/user_extension           -T../tests/custom/common/test.ld -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g ../tests/custom/common/syscalls.c ../tests/custom/common/crt.S -lgcc -I../tests/custom/env -I../tests/custom/common -o <cva6>/verif/sim/<out_date>/directed_c_tests/hello_world.o  -march=rv32imac_zba_zbb_zbs_zbc_zicsr_zifencei -mabi=ilp32

- ``-I<cva6>/verif/sim/dv/user_extension``：指定包含文件的搜索路径。
- ``-T../tests/custom/common/test.ld``：指定链接器脚本。
- ``-static``：生成静态链接的可执行文件。
- ``-mcmodel=medany``：指定代码模型。
- ``-fvisibility=hidden -nostdlib -nostartfiles``：用于控制链接过程，包括不链接标准库、不链接启动文件。
- ``-g``：生成调试信息。
- ``-lgcc``：链接 GCC 的运行时库。
- ``-I../tests/custom/env -I../tests/custom/common``：指定其他的包含文件搜索路径。
- ``-o``：指定输出文件的路径和名称。
- ``-march=rv32imac_zba_zbb_zbs_zbc_zicsr_zifencei -mabi=ilp32``：指定目标架构和 ABI。

第二条为：

.. code-block::

	<cva6>/gcc-toolchain/bin/riscv-none-elf-objcopy -O binary <cva6>/verif/sim/<out_date>/directed_c_tests/hello_world.o <cva6>/verif/sim/<out_date>/directed_c_tests/hello_world.bin

它将目标文件 ``hello_world.o`` 转换为二进制文件 ``hello_world.bin``。
这个二进制文件可以直接加载到内存中执行，或者烧写到硬件设备中。


Verilator
###################

``<cva6>/verif/sim/cva6.py`` 会生成调用 shell 的指令。
其中一条指令为 ``make veri-testharness ...``。
这会调用 ``<cva6>/verif/sim/Makefile`` 中 ``veri-testharness`` 标签对应的指令。
这个标签中的指令会跳转到 ``<cva6>/Makefile`` 运行 ``verilate`` 标签对应的指令。

调用 Verilator 的指令为

.. code-block::

	verilator --no-timing verilator_config.vlt -f core/Flist.cva6 <cva6>/corev_apu/tb/ariane_axi_pkg.sv <cva6>/corev_apu/tb/axi_intf.sv <cva6>/corev_apu/register_interface/src/reg_intf.sv <cva6>/corev_apu/tb/ariane_soc_pkg.sv <cva6>/corev_apu/riscv-dbg/src/dm_pkg.sv <cva6>/corev_apu/tb/ariane_axi_soc_pkg.sv <cva6>/corev_apu/src/ariane.sv <cva6>/corev_apu/bootrom/bootrom.sv <cva6>/corev_apu/clint/axi_lite_interface.sv <cva6>/corev_apu/clint/clint.sv <cva6>/corev_apu/fpga/src/axi2apb/src/axi2apb_wrap.sv <cva6>/corev_apu/fpga/src/axi2apb/src/axi2apb.sv <cva6>/corev_apu/fpga/src/axi2apb/src/axi2apb_64_32.sv <cva6>/corev_apu/fpga/src/apb_timer/apb_timer.sv <cva6>/corev_apu/fpga/src/apb_timer/timer.sv <cva6>/corev_apu/fpga/src/axi_slice/src/axi_w_buffer.sv <cva6>/corev_apu/fpga/src/axi_slice/src/axi_b_buffer.sv <cva6>/corev_apu/fpga/src/axi_slice/src/axi_slice_wrap.sv <cva6>/corev_apu/fpga/src/axi_slice/src/axi_slice.sv <cva6>/corev_apu/fpga/src/axi_slice/src/axi_single_slice.sv <cva6>/corev_apu/fpga/src/axi_slice/src/axi_ar_buffer.sv <cva6>/corev_apu/fpga/src/axi_slice/src/axi_r_buffer.sv <cva6>/corev_apu/fpga/src/axi_slice/src/axi_aw_buffer.sv <cva6>/corev_apu/src/axi_riscv_atomics/src/axi_riscv_amos.sv <cva6>/corev_apu/src/axi_riscv_atomics/src/axi_riscv_atomics.sv <cva6>/corev_apu/src/axi_riscv_atomics/src/axi_res_tbl.sv <cva6>/corev_apu/src/axi_riscv_atomics/src/axi_riscv_lrsc_wrap.sv <cva6>/corev_apu/src/axi_riscv_atomics/src/axi_riscv_amos_alu.sv <cva6>/corev_apu/src/axi_riscv_atomics/src/axi_riscv_lrsc.sv <cva6>/corev_apu/src/axi_riscv_atomics/src/axi_riscv_atomics_wrap.sv <cva6>/corev_apu/axi_mem_if/src/axi2mem.sv <cva6>/corev_apu/rv_plic/rtl/rv_plic_target.sv <cva6>/corev_apu/rv_plic/rtl/rv_plic_gateway.sv <cva6>/corev_apu/rv_plic/rtl/plic_regmap.sv <cva6>/corev_apu/rv_plic/rtl/plic_top.sv <cva6>/corev_apu/riscv-dbg/src/dmi_cdc.sv <cva6>/corev_apu/riscv-dbg/src/dmi_jtag.sv <cva6>/corev_apu/riscv-dbg/src/dmi_jtag_tap.sv <cva6>/corev_apu/riscv-dbg/src/dm_csrs.sv <cva6>/corev_apu/riscv-dbg/src/dm_mem.sv <cva6>/corev_apu/riscv-dbg/src/dm_sba.sv <cva6>/corev_apu/riscv-dbg/src/dm_top.sv <cva6>/corev_apu/riscv-dbg/debug_rom/debug_rom.sv <cva6>/corev_apu/register_interface/src/apb_to_reg.sv <cva6>/vendor/pulp-platform/axi/src/axi_multicut.sv <cva6>/vendor/pulp-platform/common_cells/src/rstgen_bypass.sv <cva6>/vendor/pulp-platform/common_cells/src/rstgen.sv <cva6>/vendor/pulp-platform/common_cells/src/addr_decode.sv <cva6>/vendor/pulp-platform/common_cells/src/stream_register.sv <cva6>/vendor/pulp-platform/axi/src/axi_cut.sv <cva6>/vendor/pulp-platform/axi/src/axi_join.sv <cva6>/vendor/pulp-platform/axi/src/axi_delayer.sv <cva6>/vendor/pulp-platform/axi/src/axi_to_axi_lite.sv <cva6>/vendor/pulp-platform/axi/src/axi_id_prepend.sv <cva6>/vendor/pulp-platform/axi/src/axi_atop_filter.sv <cva6>/vendor/pulp-platform/axi/src/axi_err_slv.sv <cva6>/vendor/pulp-platform/axi/src/axi_mux.sv <cva6>/vendor/pulp-platform/axi/src/axi_demux.sv <cva6>/vendor/pulp-platform/axi/src/axi_xbar.sv <cva6>/vendor/pulp-platform/common_cells/src/cdc_2phase.sv <cva6>/vendor/pulp-platform/common_cells/src/spill_register_flushable.sv <cva6>/vendor/pulp-platform/common_cells/src/spill_register.sv <cva6>/vendor/pulp-platform/common_cells/src/deprecated/fifo_v1.sv <cva6>/vendor/pulp-platform/common_cells/src/deprecated/fifo_v2.sv <cva6>/vendor/pulp-platform/common_cells/src/stream_delay.sv <cva6>/vendor/pulp-platform/common_cells/src/lfsr_16bit.sv <cva6>/vendor/pulp-platform/tech_cells_generic/src/deprecated/cluster_clk_cells.sv <cva6>/vendor/pulp-platform/tech_cells_generic/src/deprecated/pulp_clk_cells.sv <cva6>/vendor/pulp-platform/tech_cells_generic/src/rtl/tc_clk.sv <cva6>/corev_apu/tb/ariane_testharness.sv <cva6>/corev_apu/tb/ariane_peripherals.sv <cva6>/corev_apu/tb/rvfi_tracer.sv <cva6>/corev_apu/tb/common/uart.sv <cva6>/corev_apu/tb/common/SimDTM.sv <cva6>/corev_apu/tb/common/SimJTAG.sv +define+ corev_apu/tb/common/mock_uart.sv +incdir+corev_apu/axi_node  --unroll-count 256 -Wall -Werror-PINMISSING -Werror-IMPLICIT -Wno-fatal -Wno-PINCONNECTEMPTY -Wno-ASSIGNDLY -Wno-DECLFILENAME -Wno-UNUSED -Wno-UNOPTFLAT -Wno-BLKANDNBLK -Wno-style  -DPRELOAD=1     -LDFLAGS "-L<cva6>/gcc-toolchain/lib -L<cva6>/tools/spike/lib -Wl,-rpath,<cva6>/gcc-toolchain/lib -Wl,-rpath,<cva6>/tools/spike/lib -lfesvr -lriscv  -lpthread " -CFLAGS "-I/include -I/include -I<cva6>/tools/verilator-v5.008/share/verilator/include/vltstd -I<cva6>/gcc-toolchain/include -I<cva6>/tools/spike/include -std=c++17 -I../corev_apu/tb/dpi -O3 -DVL_DEBUG -I<cva6>/tools/spike"   --cc --vpi  +incdir+<cva6>/vendor/pulp-platform/common_cells/include/  +incdir+<cva6>/vendor/pulp-platform/axi/include/  +incdir+<cva6>/corev_apu/register_interface/include/  +incdir+<cva6>/corev_apu/tb/common/  +incdir+<cva6>/vendor/pulp-platform/axi/include/  +incdir+<cva6>/verif/core-v-verif/lib/uvm_agents/uvma_rvfi/ --top-module ariane_testharness --threads-dpi none --Mdir work-ver -O3 --exe corev_apu/tb/ariane_tb.cpp corev_apu/tb/dpi/SimDTM.cc corev_apu/tb/dpi/SimJTAG.cc corev_apu/tb/dpi/remote_bitbang.cc corev_apu/tb/dpi/msim_helper.cc

接下来，我们会逐一介绍其中的每个参数。

- ``--no-timing``：忽略时序信息。
- ``verilator_config.vlt``：通过配置文件控制警告和其他功能。
- ``-f core/Flist.cva6``：将文件内容视作命令行参数。
- ``+define+``：定义给定的预处理器符号（preprocessor symbol）。
- ``+incdir+``：将目录添加到查找包含文件（include files）或库（libiraries）的目录列表中。
- ``--unroll-count``：指定循环中要展开的循环的最大数目。
- ``-W*``：控制如何处理源代码中的各种情况。
- ``-DPRELOAD=1``：这是一个预处理器定义，它将在源代码中定义一个名为 PRELOAD 的宏，其值为1。
- ``-LDFLAGS``：链接器选项。
- ``-CFLAGS``：编译器选项。
- ``--cc --vpi``：告诉 Verilator 生成 C++ 模型和 VPI 接口。
- ``--top-module``：指定了顶层模块的名称。
- ``--threads-dpi``：指定 DPI 线程模式。
- ``-Mdir``：输出目录的名称。
- ``--exe``：链接用于生成可执行文件。

.. hint::

	更详细完整的参数列表，请查询 `官方文档 <https://verilator.org/guide/latest/index.html>`__。

运行输出目录中的 ``Variane_testharness.mk`` 会生成一个可执行文件 ``Variane_testharness``。
运行该文件：

.. code-block::

	<cva6>/work-ver/Variane_testharness   <cva6>/verif/sim/out_2024-01-13/directed_c_tests/test.o +debug_disable=1 +ntb_random_seed=1 +elf_file=<cva6>/verif/sim/out_<date>/directed_c_tests/test.o +tohost_addr=80001000

其中的参数解释如下。

- ``+debug_disable=1``：禁用调试功能。
- ``+ntb_random_seed=1``：设置随机数生成器的种子。
- ``+elf_file``：加载的 ELF 文件的路径。这个文件包含了要在仿真器中运行的程序的机器代码。
- ``+tohost_addr``：指定 tohost 寄存器的地址映射。

上述参数都是传递给在仿真 RISC-V CPU 上执行的程序的选项。

.. note Important::

	``tohost`` 地址需要从 ELF 文件中获取，具体的工具为 RISC-V GCC 中的 ``nm`` 命令。

.. note::
	
	在仿真环境中，尤其是在使用像 Spike 或 Verilator 这样的 RISC-V 仿真器时，向可执行文件传递参数常常会使用一个加号（+）作为前缀。
	这种格式通常用于区分仿真器本身的参数和传递给仿真程序的参数。

Spike
###################

调用 Spike 的指令为

.. code-block::

	LD_LIBRARY_PATH="$(realpath ../../tools/spike/lib):$LD_LIBRARY_PATH" <cva6>/tools/spike/bin/spike --steps=2000000  --log-commits --isa=rv32imac_zba_zbb_zbs_zbc_zicsr_zifencei -l <cva6>/verif/sim/out_<date>/directed_c_tests/hello_world.o

- ``--log commits -l``：启动指令跟踪，并且每次指令提交时都会写入日志。

