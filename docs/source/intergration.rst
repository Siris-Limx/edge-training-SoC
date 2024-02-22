SoC 集成
=======

.. contents:: Table of Contents

CVA6 使用的总线是 AXI 协议。

总线拓扑
--------

集成新设备时需要修改的内容：

- ``<cva6>/corev_apu/fpga/src/ariane_xilinx.sv: // cached region``：可缓存区域的定义。
- ``<cva6>/corev_apu/fpga/src/ariane_xilinx.sv: assign addr_map =``：AXI 地址映射定义。
- ``<cva6>/corev_apu/tb/ariane_soc_pkg.sv``：新设备的地址映射定义。


接入总线
--------

``<cva6>/vendor/pulp-platform/axi`` 中定义了许多 AXI 相关的模块，例如位宽转换等，可以很方便的使用。
再加上 ``<cva6>/corev_apu/axi_mem_if/src/axi2mem.sv`` 的接口转换，基本可以满足模块接入总线的需求。

我们使用的 NPU 模块，就是通过 ``axi_dw_converter`` 再加上 ``axi2mem`` 接入总线的。


.. note::

   This section is under development.
