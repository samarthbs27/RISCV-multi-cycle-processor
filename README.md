# RISCV-multi-cycle-processor

A 32-bit multicycle RISC-V processor implementing a subset of RV32I, written in SystemVerilog.
Based on Harris & Harris *"Digital Design and Computer Architecture: RISC-V Edition"* (Chapters 6 & 7.4).

## Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Supported Instructions](#supported-instructions)
- [Known Limitations](#known-limitations)
- [Design Approach](#design-approach)
- [Future Work](#future-work)
- [License](#license)
- [About the Author](#about-the-author)

---

## Overview

A SystemVerilog implementation of a 32-bit multicycle RISC-V processor core. The design follows the
Harris & Harris textbook multicycle FSM model: each instruction takes 3–6 clock cycles, reusing the
ALU and memory across stages. Control is a Mealy FSM; the datapath uses a unified instruction + data
memory with parameterised hex file loading.

Verified programs:
- `riscvtest.txt` — 24-instruction ALU/branch/memory baseline (passes at 845 ns)
- `bubble_fixed_instr.hex` — bubble sort of 5 integers compiled from C with RV32I GCC (passes at 11480 ns)

---

## Repository Structure

```
rtl/          SystemVerilog source files (processor + memory)
tb/           Testbenches
sim/          Simulation scripts (Xsim/Vivado)
mem/          Hex program files loaded at simulation time
docs/         C source, linker script, disassembly listings
CHANGES.md    Per-phase change log with root-cause analysis
```

### Module hierarchy

```
tb/tb.sv  /  tb/tb_bubble.sv
└── rtl/top.sv
    ├── rtl/riscvmulti.sv
    │   ├── rtl/controller.sv
    │   │   ├── rtl/ImmSrc.sv
    │   │   ├── rtl/aludec.sv
    │   │   └── rtl/mainfsm.sv
    │   └── rtl/datapath.sv
    │       ├── rtl/flopenr.sv, flopr.sv, flopr2.sv
    │       ├── rtl/mux2.sv, mux3.sv
    │       ├── rtl/regfile.sv
    │       ├── rtl/extend.sv
    │       └── rtl/alu.sv
    └── rtl/mem.sv
```

---

## Getting Started

### Prerequisites

- **Simulator:** Xilinx Vivado 2025.x (Xsim) — full SystemVerilog support required
- **Compilation (optional):** `riscv64-unknown-elf-gcc` with `-march=rv32i` (via WSL/Linux)

### Simulation

Run from the `sim/` directory with Vivado's `bin/` on PATH, or execute `sim\run_xsim.bat`.

**Step 1 — Compile (run once):**
```bat
xvlog --sv ..\tb\tb.sv ..\rtl\top.sv ..\rtl\riscvmulti.sv ..\rtl\mem.sv ^
  ..\rtl\controller.sv ..\rtl\datapath.sv ..\rtl\ImmSrc.sv ..\rtl\aludec.sv ^
  ..\rtl\mainfsm.sv ..\rtl\flopenr.sv ..\rtl\mux2.sv ..\rtl\flopr.sv ^
  ..\rtl\regfile.sv ..\rtl\extend.sv ..\rtl\flopr2.sv ..\rtl\mux3.sv ..\rtl\alu.sv
```

**Step 2a — Baseline test:**
```bat
xelab -debug typical testbench -s riscv_snap
xsim riscv_snap --runall
```
Expected: `Simulation succeeded` at 845 ns.

**Step 2b — Bubble sort:**
```bat
xelab -debug typical testbench_bubble -s bubble_snap
xsim bubble_snap --runall
```
Expected: `Bubble sort passed: [1,2,3,4,5]` at 11480 ns.

---

## Supported Instructions

The following instructions are implemented and simulation-verified:

| Category | Instructions |
|----------|-------------|
| I-type ALU | `addi`, `slti`, `andi`, `ori`, `xori`, `slli`, `srli`, `srai` |
| R-type ALU | `add`, `sub`, `sll`, `slt`, `srl`, `sra`, `and`, `or`, `xor` |
| Load / Store | `lw`, `sw` (word-aligned only) |
| Branches | `beq`, `bne`, `blt`, `bge` |
| Jumps | `jal`, `jalr` |

---

## Known Limitations

### Unimplemented instructions

| Instruction(s) | Missing piece |
|----------------|---------------|
| `lui`, `auipc` | U-type immediate not in `extend.sv` / `ImmSrc.sv`; no FSM states |
| `sltu`, `sltiu` | Unsigned set-less-than not in ALU or decoder |
| `bltu`, `bgeu` | Unsigned branch comparison needs carry flag, not sign bit |
| `lb`, `lbu`, `lh`, `lhu` | Byte/halfword loads not in `mem.sv` |
| `sb`, `sh` | Byte/halfword stores not in `mem.sv` |
| `fence`, `ecall`, `ebreak` | Not implemented |

### Memory model

- 256-word (1 KB) unified RAM shared between instructions and data
- Address bits `[9:2]` index the RAM — all 32-bit addresses wrap into the 256-word window.
  This maps the typical stack region (`0xFFFFFFD0`–`0xFFFFFFFC`) to words 244–255,
  safely above the instruction region (words 0–74 for bubble sort)
- Only word-aligned (`lw`/`sw`) accesses are supported; byte/halfword access is Phase 4 work

### Branch signed comparison edge case

`blt`/`bge` use `result[31] ^ overflow` for correct signed comparison. Unsigned variants
(`bltu`/`bgeu`) require the carry flag instead and are not yet implemented.

---

## Design Approach

- 13-state multicycle FSM: FETCH → DECODE → per-instruction execute/memory/writeback paths
- Shared ALU and memory across all stages — no separate instruction/data buses
- `MEM_FILE` string parameter on `top` and `mem` allows loading different hex programs
  without RTL changes
- `ALUControl` is 4 bits: MSB=1 selects SRA (`1000`), distinguishing it from SRL (`0111`)
- JALR uses two FSM states (JALR1 writes return address, JALR2 updates PC) because both
  values need the ALU in the same instruction

---

## Future Work

- **Phase 4:** `lui`, `auipc`, `sltu`/`sltiu`, `bltu`/`bgeu`, byte/halfword loads and stores
- **Phase 5:** `fence` (NOP), `ecall`/`ebreak` (trap)
- **Phase 6:** UVM testbench — sequence item, driver, monitor, scoreboard, functional coverage
- Pipelining with hazard detection
- FPGA implementation

---

## License

MIT License.

---

## About the Author

Developed as part of self-learning in computer architecture and VLSI design, covering
multicycle RISC-V, UVM verification methodology, and CVA6 exploration.
