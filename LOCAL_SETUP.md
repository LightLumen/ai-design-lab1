# Lab 1 本地仿真环境

在 Windows PowerShell 中进入本项目目录，再运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-local.ps1 -Task env
```

看到 `ENV_CHECK_PASS` 和 `PASS: env` 表示本地工具链检查通过。
三个任务已实现。使用以下专用脚本运行课程测试平台与独立自检：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-winograd-checks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-cordic-checks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-fsm-checks.ps1
```

保留的 `run-local.ps1` 支持 `-Task all`，但 Winograd 和 CORDIC 的课程 `.f` 文件缺少末尾换行，在当前 Icarus 下会引发文件列表解析问题。上面的专用脚本使用显式源文件参数，课程文件列表和测试平台保持原样。

- 工具：项目内 `.tools/iverilog/mingw64/` 的 Icarus Verilog 13.0。
- 运行库：复用本机现有的 `C:\msys64\mingw64\bin`；脚本仅临时调整当前进程的 PATH。
- 课程源码及实现：`lab1_files/`；课程测试平台、文件列表与 Makefile 保持原样。
- 结果：`build/<任务>/public.compile.log`、`public.simulation.log`、`selfcheck.compile.log`、`selfcheck.simulation.log` 和波形文件。
- 使用 `-g2012` 和 `-DNO_FSDB`；波形通过独立生成的模块导出 VCD，无需改动课程 TB。
- 目前未安装波形查看器；需要图形查看波形时，可另外配置 GTKWave。
- 课程默认工具为 VCS/Verdi。本地结果用于开发和功能验证，最终工具要求以助教确认为准。

工具链二进制、下载包和运行库不随 GitHub 仓库上传。重新克隆后，需要将下列 MSYS2 工具包解压到 `.tools/iverilog/`，并提供 `C:\msys64\mingw64\bin` 中的运行库；若使用其他安装位置，需相应调整脚本内的路径。Linux 下使用系统 Icarus 的命令见根目录 README。

工具包来源：MSYS2 官方仓库。

<https://repo.msys2.org/mingw/mingw64/mingw-w64-x86_64-iverilog-1~13.0-2-any.pkg.tar.zst>

下载包 SHA256 已核对：

`e22c86dad1a0658d5f769362bfbec6533028c0d0bb63059b4fda0cc1084d1406`
