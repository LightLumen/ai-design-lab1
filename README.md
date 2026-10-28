# AI Design Lab1

数字电路设计课程 Lab1：Winograd 一维卷积、CORDIC 旋转和双缓冲控制器的 RTL 实现与功能验证。使用 SystemVerilog-2012，支持 Icarus Verilog 本地仿真。

## 项目内容

| 任务 | 实现 | 说明 |
| --- | --- | --- |
| Winograd F(2,3) | 四次乘法、三级流水线，32 位有符号输入，输出取低 32 位 | [实现与时序](lab1_files/winograd/IMPLEMENTATION.md) |
| CORDIC | 16 次迭代流水线，支持全圆周角度 | [实现与时序](lab1_files/cordic/IMPLEMENTATION.md) |
| 双缓冲 FSM | 三个 tile 交替使用两个缓冲区，重叠加载与计算 | [实现与时序](lab1_files/fsm/IMPLEMENTATION.md) |

每项任务的 `src/` 包含 RTL 与课程测试平台，`verification/` 包含独立自检和 VCD 导出模块，`run/` 保留课程文件列表与 Makefile。`prompts/` 保存实现提示词。

## Windows 本地验证

先按 [本地环境说明](LOCAL_SETUP.md) 配置 Icarus Verilog。工具链二进制和运行库不随仓库上传；现有 PowerShell 脚本使用项目内 `.tools/iverilog/mingw64/bin/` 和本机 `C:\msys64\mingw64\bin`。

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-winograd-checks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-cordic-checks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-fsm-checks.ps1
```

各脚本依次执行课程测试与独立自检；编译失败、仿真失败或缺少通过标志都会报错。日志和波形生成在 `build/<任务>/`，这些产物不提交到仓库。

## 使用系统 Icarus 运行课程用例

已安装 `iverilog` 和 `vvp` 的 Linux 环境可在仓库根目录直接执行：

```sh
mkdir -p build
iverilog -g2012 -DNO_FSDB -s winograd_1d_tb -o build/winograd.vvp \
  lab1_files/winograd/src/input_transform.v \
  lab1_files/winograd/src/weight_transform.v \
  lab1_files/winograd/src/output_transform.v \
  lab1_files/winograd/src/winograd_1d.v \
  lab1_files/winograd/src/winograd_1d_tb.v
vvp build/winograd.vvp

iverilog -g2012 -DNO_FSDB -s cordic_tb -o build/cordic.vvp \
  lab1_files/cordic/src/cordic.v lab1_files/cordic/src/cordic_tb.sv
vvp build/cordic.vvp

iverilog -g2012 -s double_buffer_ctrl_tb -o build/fsm.vvp \
  lab1_files/fsm/src/double_buffer_ctrl.v lab1_files/fsm/src/double_buffer_ctrl_tb.sv
vvp build/fsm.vvp
```

这里显式列出源文件，避开课程部分 `.f` 文件缺少末尾换行时的 Icarus 兼容问题。上述命令只运行课程用例；独立自检和波形导出方法见各任务的实现说明。

## 已有验证记录

本地 Icarus 功能仿真记录（2026-10-16）：

| 任务 | 课程用例 | 独立自检关键结果 |
| --- | --- | --- |
| Winograd | `ALL PASS: Winograd, 10 cases` | `accepted=3193 checked=3191 reset_flushed=2` |
| CORDIC | `ALL PASS: CORDIC, 10 cases` | `checked=1774 numeric=862 wrapped=912` |
| FSM | `ALL PASS` | `accepted=53 completed=50 aborted=3` |

独立自检覆盖边界数据、连续事务、有效位或握手时序，以及有复位接口模块的在途复位。详细覆盖范围与日志摘录见各任务说明。这些结果来自功能仿真；尚未完成目标工艺综合和静态时序分析，10ns 仿真时钟不代表物理时序已经收敛。
