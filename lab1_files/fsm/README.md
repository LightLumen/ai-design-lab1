# Lab 1 Task 3: double-buffer controller

Implement `src/double_buffer_ctrl.v` without changing its module name or ports.
The module controls three tiles, numbered 0, 1, and 2. Tile `n` uses buffer
`n % 2`. A request is a one-cycle pulse; its tile and buffer outputs are valid
in that cycle. The testbench sends the matching one-cycle completion pulse
later. Loading and computing may overlap only when they use different buffers.

From `run/`, execute `make rerun` in the course VCS environment. The supplied
testbench prints `ALL PASS` for a working design; the starter RTL deliberately
fails. Keep the public testbench unchanged. The course may grade additional
timing cases against the same top-level interface.
