# Simulation

## Prerequisites

Xilinx Vivado 2025.x must be installed. The `xvlog`, `xelab`, and `xsim` tools from
Vivado's `bin/` directory are required.

## Before running

Open `run_xsim.bat` and update the `VIVADO_BIN` path on line 4 to match your Vivado
installation:

```bat
set VIVADO_BIN=E:\AMDDesignTools\2025.2\Vivado\bin
```

Common locations:
- `C:\Xilinx\Vivado\2025.2\bin`
- `D:\Xilinx\Vivado\2025.2\bin`
- `E:\AMDDesignTools\2025.2\Vivado\bin`

## Running

Double-click `run_xsim.bat` or run it from a terminal in this directory.
It compiles all RTL and runs the `riscvtest.txt` baseline test by default.

To run the bubble sort test, elaborate `testbench_bubble` instead:

```bat
xelab -debug typical testbench_bubble -s bubble_snap
xsim bubble_snap --runall
```

## Expected output

- Baseline: `Simulation succeeded` at 845 ns
- Bubble sort: `Bubble sort passed: [1,2,3,4,5]` at 11480 ns
