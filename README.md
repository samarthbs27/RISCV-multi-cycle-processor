# RISCV-multi-cycle-processor

A 32-bit multicycle RISC-V processor implementing the full RV32I base ISA plus the RV32M
integer multiply extension, written in SystemVerilog.
Based on Harris & Harris *"Digital Design and Computer Architecture: RISC-V Edition"* (Chapters 6 & 7.4).

## Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Supported Instructions](#supported-instructions)
- [Memory Model](#memory-model)
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

**Verified programs (all pass with Xsim):**

| Program | Description | Pass condition |
|---------|-------------|----------------|
| `mem/riscvtest.txt` | 24-instruction ALU/branch/memory baseline | `845 ns` |
| `mem/bubble_fixed_instr.hex` | Bubble sort of [3,5,1,2,4] compiled from C (RV32I) | `11480 ns` |
| `mem/lui_auipc_test.hex` | LUI and AUIPC correctness | `165 ns` |
| `mem/sltu_branch_test.hex` | SLTU, BLTU, BGEU correctness | `395 ns` |
| `mem/byte_halfword_test.hex` | lb, lbu, lh, lhu, sb, sh correctness | `545 ns` |
| `mem/ecall_test.hex` | ECALL terminates simulation | `110 ns` |
| `mem/mul_test.hex` | MUL lower 32 bits (6×7=42, −3×5=−15) | `345 ns` |
| `mem/mulh_test.hex` | MULH / MULHU / MULHSU upper 32 bits | `305 ns` |
| `mem/matmul.hex` | 3×3 integer matmul compiled from C (`-march=rv32im`) | `10755 ns` |

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
tb/tb.sv  /  tb/tb_bubble.sv  /  tb/tb_mul.sv  /  tb/tb_mulh.sv  /  tb/tb_matmul.sv  / ...
└── rtl/top.sv                        ← system top: processor + unified memory
    ├── rtl/riscvmulti.sv             ← processor: controller + datapath
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
- **Compilation (optional):** `riscv64-unknown-elf-gcc` via WSL/Linux

### Simulation

Run from the `sim/` directory with Vivado's `bin/` on PATH, or execute `sim\run_xsim.bat`.

**Step 1 — Compile all sources (run once per RTL change):**
```bat
xvlog --sv ..\tb\tb.sv ..\tb\tb_bubble.sv ..\tb\tb_mul.sv ..\tb\tb_mulh.sv ^
  ..\tb\tb_matmul.sv ..\rtl\top.sv ..\rtl\riscvmulti.sv ..\rtl\mem.sv ^
  ..\rtl\controller.sv ..\rtl\datapath.sv ..\rtl\ImmSrc.sv ..\rtl\aludec.sv ^
  ..\rtl\mainfsm.sv ..\rtl\flopenr.sv ..\rtl\mux2.sv ..\rtl\flopr.sv ^
  ..\rtl\regfile.sv ..\rtl\extend.sv ..\rtl\flopr2.sv ..\rtl\mux3.sv ..\rtl\alu.sv
```

**Step 2 — Elaborate and run each test:**
```bat
xelab -debug typical testbench         -s riscv_snap  && xsim riscv_snap  --runall
xelab -debug typical testbench_bubble  -s bubble_snap && xsim bubble_snap --runall
xelab -debug typical testbench_mul     -s mul_snap    && xsim mul_snap    --runall
xelab -debug typical testbench_mulh    -s mulh_snap   && xsim mulh_snap   --runall
xelab -debug typical testbench_matmul  -s matmul_snap && xsim matmul_snap --runall
```

### Recompiling C programs (WSL, Ubuntu 22.04)

```bash
# RV32I only
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -T link.ld -o out.elf program.c

# RV32I + M extension (mul/mulh)
riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -O2 -nostdlib -T link.ld -o out.elf program.c

# Extract all loadable sections (includes .rodata constant pool)
riscv64-unknown-elf-objcopy -O binary out.elf full.bin
od -An -v -tx4 -w4 full.bin | sed 's/ //g' | grep -v '^$' > ../mem/program.hex
```

---

## Supported Instructions

All RV32I base instructions are implemented and simulation-verified.
The RV32M multiply instructions are also implemented.

| Category | Instructions |
|----------|-------------|
| I-type ALU | `addi`, `slti`, `sltiu`, `andi`, `ori`, `xori`, `slli`, `srli`, `srai` |
| R-type ALU | `add`, `sub`, `sll`, `slt`, `sltu`, `srl`, `sra`, `and`, `or`, `xor` |
| Loads | `lw`, `lh`, `lb`, `lhu`, `lbu` |
| Stores | `sw`, `sh`, `sb` |
| Branches | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| Jumps | `jal`, `jalr` |
| Upper-immediate | `lui`, `auipc` |
| System | `fence` (NOP), `ecall` / `ebreak` (`$finish`) |
| RV32M multiply | `mul`, `mulh`, `mulhu`, `mulhsu` |

**Not implemented:** `div`, `divu`, `rem`, `remu` (RV32M division).

---

## Memory Model

- 256-word (1 KB) unified RAM shared between instructions and data
- Address bits `[9:2]` index the RAM — all 32-bit addresses wrap into the 256-word window.
  This maps the typical stack region (`0xFFFFFFD0`–`0xFFFFFFFC`) to words 244–255,
  safely above the instruction region
- Byte and halfword accesses (`lb`/`lh`/`lbu`/`lhu`/`sb`/`sh`) use `funct3` to extract
  or write the correct byte/halfword within the 32-bit word; sign/zero extension applied on load

---

## Design Approach

- **14-state multicycle FSM:** FETCH → DECODE → per-instruction execute/memory/writeback paths.
  States: FETCH(0), DECODE(1), MEMADR(2), MEMRD(3), MEMWB(4), MEMWR(5), EXECUTER(6),
  EXECUTEI(7), ALUWB(8), BEQ(9), JAL(10), JALR1(11), JALR2(12), LUI_STATE(13)
- Shared ALU and memory across all stages — no separate instruction/data buses
- `MEM_FILE` string parameter on `top` and `mem` allows loading different hex programs
  without RTL changes
- `ALUControl` is 4 bits; codes 0–11 cover RV32I, codes 12–15 cover RV32M multiply
- **JALR** uses two FSM states: JALR1 writes return address to `rd`, JALR2 updates PC
- **LUI** uses a dedicated LUI_STATE that selects pass-B (ALUControl=1001) to forward
  the U-type immediate directly as the result; AUIPC reuses DECODE's OldPC+ImmExt path
- **RV32M multiply** reuses the EXECUTER→ALUWB path — no new FSM states needed.
  `funct7b0` (instruction bit 25) is threaded from `riscvmulti` through `controller`
  to `aludec` to distinguish M-extension opcodes from base R/I-type

---

## Future Work

- **Phase 6:** Custom packed SIMD extension using RISC-V custom opcode space (`0x0B`/`0x2B`);
  2×16-bit lane operations; optimised matmul inner loop in inline assembly; cycle-count benchmark
- **Phase 7:** UVM testbench — sequence item, driver, monitor, scoreboard, functional coverage
- Pipelining with hazard detection and forwarding
- FPGA implementation

---

## License

MIT License.

---

## About the Author

Developed as part of self-learning in computer architecture and VLSI design, covering
multicycle RISC-V, UVM verification methodology, and CVA6 exploration.
