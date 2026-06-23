# Change Log

Documents every fix made to the RTL and testbench, the reason for each, and a theoretical
walkthrough showing the processor executing correctly after the fixes.

---

## Phase 1 — Fix RTL & Make It Simulate

### 1. `mem.sv` — Hardcoded path + inconsistent address wrapping

**Problem A — Path**  
`$readmemh` used an absolute Windows path:
```sv
$readmemh("C:\\Users\\samar\\...\\bubble.txt", RAM1);
```
This breaks on any other machine and loaded the wrong program (bubble sort instead of
the baseline test).

**Fix:** Changed to a relative path:
```sv
$readmemh("riscvtest.txt", RAM1);
```
Run the simulator from the project root and it resolves correctly.

---

**Problem B — Inconsistent address wrapping**  
The read path used the full address:
```sv
assign Instr = RAM1[a[31:2]];           // no wrapping
```
But the write path masked to 8 bits:
```sv
assign a_wrapped = a & 32'hFF;
if (we) RAM1[a_wrapped[31:2]] <= wd;    // wrapped
```
For any address above 0xFF (e.g., bubble sort stack at `0xFFFFFFD0`), reads returned X
while writes went to a different word index — a silent data corruption with no error.

**Fix:** Removed `a_wrapped` entirely. Both read and write now use `a[31:2]`:
```sv
assign Instr = RAM1[a[31:2]];
if (we) RAM1[a[31:2]] <= wd;
```
For `riscvtest.txt` all accesses are small addresses (largest store is to address 100),
so no wrapping is needed. The stack address issue will be revisited in Phase 3.

---

### 2. `tb.sv` — Broken reset, wrong operator, no timeout

**Problem A — Multiple resets**  
The original reset sequence toggled reset three times:
```sv
reset <= 1; #22; reset <= 0; #100;
reset <= 1; #30; reset <= 0; #50;
reset <= 1; #22; reset <= 0;
```
Each rising edge of reset sends the FSM back to FETCH, flushing all pipeline state.
Any computation in progress is wiped out mid-run — the processor never settles.

**Fix:** Single clean reset pulse at startup:
```sv
reset <= 1; #22; reset <= 0;
```
22 ns ensures reset is seen on the first rising clock edge (clock period = 10 ns).

---

**Problem B — Bitwise `&` instead of logical `&&`**  
```sv
if(DataAdr === 100 & WriteData === 25)
```
Bitwise `&` operates bit-by-bit on the 32-bit comparison results. In most cases it
coincidentally gives the right answer, but it is semantically wrong and can produce
incorrect results for specific values where bits cancel. Short-circuit evaluation is
also lost.

**Fix:**
```sv
if (DataAdr === 32'd100 && WriteData === 32'd25)
```

---

**Problem C — No timeout**  
If the pass condition was never met (e.g., because of an RTL bug), the simulation ran
forever with no way to detect failure.

**Fix:** Added a 10 µs hard timeout:
```sv
initial begin
    #10000;
    $display("TIMEOUT: simulation did not complete in time");
    $finish;
end
```
At 10 ns/cycle this gives 1000 cycles — far more than needed for a 24-instruction test.

---

**Problem D — `$stop` instead of `$finish`**  
`$stop` drops into interactive mode in iverilog/vvp, requiring a manual response.
`$finish` terminates cleanly, which is correct for scripted/automated runs.

---

### 3. `mainfsm.sv` — `casex` and missing defaults

**Problem A — `casex`**  
```sv
always @(*) casex (state)
```
`casex` treats any `X` or `Z` bits in `state` as don't-cares. During reset or any
simulation startup where `state` is uninitialized (X), multiple case arms can match
simultaneously, causing undefined FSM behaviour that is very hard to debug.

**Fix:** Changed to `case`:
```sv
always @(*) case (state)
```

---

**Problem B — Missing defaults in DECODE and MEMADR**  
The inner `case(op)` statements had no `default`:
```sv
DECODE:
    case(op)
        7'b0000011: nextstate = MEMADR;
        ...
        // no default — if op is unknown, nextstate is undriven → latch inferred
    endcase
```
In simulation, an unknown opcode leaves `nextstate` at its previous value (a latch).
In synthesis, tools infer an unintended latch.

**Fix:** Added `default: nextstate = FETCH` to both DECODE and MEMADR:
```sv
default: nextstate = FETCH;
```
Unknown opcodes safely return to FETCH rather than hanging.

---

### 4. `alu.sv` — Missing SRA, wrong `branch_lesser`

**Problem A — No SRA**  
The original ALU had no arithmetic right shift:
```sv
3'b111: result = a >> b[4:0];  // SRL only — SRA silently wrong
```
Any `sra` or `srai` instruction produced a logical shift, corrupting sign-extended values.

**Fix:** Expanded `alucontrol` to 4 bits and added SRA as code `4'b1000`:
```sv
4'b0111: result = a >> b[4:0];               // srl
4'b1000: result = $signed(a) >>> b[4:0];     // sra
```

---

**Problem B — `branch_lesser` ignored signed overflow**  
```sv
assign branch_lesser = (1'b1 == result[31]);  // wrong for overflow cases
```
BLT works by computing `a - b` and checking the sign bit. But when subtraction
overflows, the sign bit is flipped — e.g., `(-2^31) - 1` wraps to a positive number,
incorrectly reporting `a >= b`.

**Fix:** XOR the sign bit with the overflow flag `v` (already computed in the ALU):
```sv
assign branch_lesser = result[31] ^ v;
```
This is the standard two's-complement signed comparison correction.

---

**Additional — `isAddSub` updated for 4-bit encoding**  
The old formula depended on specific bit positions of the 3-bit encoding. With 4-bit
codes ADD=`4'b0000` and SUB=`4'b0001`, the cleaner expression is:
```sv
assign isAddSub = (alucontrol[3:1] == 3'b000);
```
This selects exactly the two codes where `sum` is a valid addition/subtraction result.

---

### 5. `aludec.sv` — SRL and SRA indistinguishable

**Problem**  
Both `srl`/`srli` and `sra`/`srai` share `funct3 == 3'b101`. They are distinguished
by `funct7[5]` (bit 30 of the instruction). The original decoder ignored this:
```sv
3'b101: ALUControl = 3'b111;  // always SRL — SRA silently mapped to SRL
```

**Fix:** Check `funct7b5` for `funct3 == 3'b101`:
```sv
3'b101: if (funct7b5) ALUControl = 4'b1000; // sra, srai
        else          ALUControl = 4'b0111; // srl, srli
```
This works for both R-type (`sra`) and I-type (`srai`) because the bit is in the same
position (bit 30) in both encodings.

---

### 6. `controller.sv` — BNE not handled

**Problem**  
`PCWrite` handled BEQ, BLT, BGE but not BNE:
```sv
assign PCWrite = (Branch & (funct3 == 3'b000) &  Zero)         |  // BEQ
                 (Branch & (funct3 == 3'b100) &  branch_lesser) |  // BLT
                 (Branch & (funct3 == 3'b101) & ~branch_lesser) |  // BGE
                 PCUpdate;
```
Any `bne` instruction never updated the PC — it fell through as a NOP.

**Fix:** Added BNE condition:
```sv
assign PCWrite = (Branch & (funct3 == 3'b000) &  Zero)          |  // BEQ
                 (Branch & (funct3 == 3'b001) & ~Zero)          |  // BNE  ← added
                 (Branch & (funct3 == 3'b100) &  branch_lesser) |  // BLT
                 (Branch & (funct3 == 3'b101) & ~branch_lesser) |  // BGE
                 PCUpdate;
```

---

### 7. `datapath.sv` / `riscvmulti.sv` — ALUControl width propagation

**Problem**  
`ALUControl` was declared as `[2:0]` in `datapath.sv` (port) and `riscvmulti.sv`
(internal wire). After expanding the ALU and decoder to 4 bits, these declarations
would silently truncate the MSB, making SRA (`4'b1000`) indistinguishable from ADD
(`4'b0000`) — the MSB would be dropped and the ALU would see `3'b000`.

**Fix:** Updated both declarations to `[3:0]`.

---

### 8. `regfile.sv` — Active `$monitor` in RTL

**Problem**  
```sv
initial begin
    $monitor("RegFile: At time %t, wd3 = %0h, we3 = %0h", $time, wd3, we3);
end
```
`$monitor` fires on every signal change anywhere in simulation. With a busy processor,
this prints thousands of lines and buries any useful debug output.

**Fix:** Removed. Add back locally when debugging register writes.

---

## Theoretical Execution Trace — `riscvtest.txt`

The test program (from Harris & Harris §7.6.3) runs 24 instructions that exercise
ALU ops, a load, a store, a conditional branch, and a JAL. The final instruction
before the halt loop stores the value **25** to address **100**, which is the testbench
pass condition.

Below is the multicycle FSM trace for the first two instructions to show the fixes
working in context.

---

### Instruction 1 — `addi x2, x0, 5` (PC = 0x00)

| Cycle | State    | Key signals | What happens |
|-------|----------|-------------|--------------|
| 1 | FETCH    | IRWrite=1, AdrSrc=0, ALUSrcA=00(PC), ALUSrcB=10(4), ALUOp=00 | Instruction fetched from `RAM1[0]`=`0x00500113`. ALUResult=0+4=4 (PC+4). OldPC latched=0. |
| 2 | DECODE   | ALUSrcA=01(OldPC), ALUSrcB=01(ImmExt) | Registers read: RD1=x0=0. ImmExt sign-extends imm=5. ALUResult=0+5=5 (branch target precomputed but unused). |
| 3 | EXECUTEI | ALUSrcA=10(Addr=x0=0), ALUSrcB=01(ImmExt=5), ALUOp=10, funct3=000 → ADD | aludec: funct3=000, no RtypeSub → ALUControl=4'b0000 (ADD). ALUResult=0+5=5. |
| 4 | ALUWB    | RegWrite=1, ResultSrc=00(ALUOutput=5) | x2 ← 5. PCWrite=PCUpdate=1, Result=ALUResult=4, PC ← 4. |

**Result:** x2=5, PC advances to 4. Takes 4 cycles.

---

### Instruction 3 — `addi x7, x3, -9` (PC = 0x08) — tests negative immediate

`FF718393` → rs1=x3 (=12), imm=-9, rd=x7.
ImmExt = sign-extend(`0xFF8`) = `0xFFFFFFF7` = -9 as 32-bit signed.

| Cycle | State    | What happens |
|-------|----------|--------------|
| 1 | FETCH    | Fetches `0xFF718393`, PC+4 computed. |
| 2 | DECODE   | RD1=x3=12. ImmExt=-9. |
| 3 | EXECUTEI | ALUControl=4'b0000 (ADD). ALUResult = 12 + (-9) = 3. |
| 4 | ALUWB    | x7 ← 3. PC ← 0x0C. |

**Result:** x7=3. Sign extension and negative immediate handled correctly.

---

### Final store — `sw x2, 100(x3)` (near end of program)

At this point x2=25, x3=0 (or appropriate base). The store computes address = x3+100 = 100.

| Cycle | State   | What happens |
|-------|---------|--------------|
| 1 | FETCH   | Instruction fetched, PC+4. |
| 2 | DECODE  | RD1=x3, RD2=x2=25. ImmExt=100. |
| 3 | MEMADR  | ALUControl=4'b0000 (ADD), ALUSrcA=10(x3), ALUSrcB=01(100). ALUResult=100. |
| 4 | MEMWR   | MemWrite=1, AdrSrc=1 → adr=100. RAM1[25] ← 25. |

Testbench sees `MemWrite=1`, `DataAdr=100`, `WriteData=25` → **"Simulation succeeded"**.

---

---

## Phase 2 — Baseline Simulation Pass

### Result

```
WARNING: mem.sv:8: $readmemh(riscvtest.txt): Not enough words in the file
         for the requested range [0:255].
Simulation succeeded
tb.sv:35: $finish called at 845000 (1ps)
```

**Simulation succeeded** at 845 ns = 84.5 clock cycles (10 ns period).

The "not enough words" warning is benign — `riscvtest.txt` has 24 instructions;
the remaining 232 RAM slots initialise to X, which the program never accesses.

---

### Additional fixes made during Phase 2

**`extend.sv` / `alu.sv` — `always_comb` → `always @(*)`**

iverilog prints "sorry: constant selects in always_* processes are not currently
supported" for `always_comb` blocks that contain part-selects like `instr[31:20]`.
It falls back to including all bits in the sensitivity list (correct but noisy).
Changed both files to `always @(*)` to eliminate the warnings. This has no effect
on synthesis — `always @(*)` and `always_comb` are equivalent for combinational
logic without latches.

**`mem.sv` — RAM declaration direction**

Changed `reg [31:0] RAM1[255:0]` to `reg [31:0] RAM1[0:255]`.
The 1364-2005 standard changed the default load direction for `$readmemh` when the
array bounds are `[N:0]` vs `[0:N]`. Using `[0:255]` matches the expected direction
and removes the ambiguity warning.

---

---

## Phase 3 — JALR Support, Memory Fix, Bubble Sort Verification

### 1. Directory restructure

Moved all RTL files to `rtl/`, testbenches to `tb/`, simulation scripts to `sim/`,
and hex/test data to `mem/`. Updated all relative paths accordingly.
`run_xsim.bat` (in `sim/`) references files as `../rtl/` and `../tb/`.

---

### 2. `mainfsm.sv` — JALR support (two new states)

**Problem**  
JALR requires writing two different values using the same `Result` bus in the same
cycle: the return address (OldPC+4) to `rd` and the jump target (rs1+ImmExt) to PC.
A single FSM state cannot drive `Result` to both values simultaneously.

**Fix:** Two new states:

| State | # | Controls | Action |
|-------|---|----------|--------|
| JALR1 | 11 | RegWrite=1, ALUSrcA=01(OldPC), ALUSrcB=10(4), ResultSrc=10 | rd ← OldPC+4 (return address) |
| JALR2 | 12 | PCUpdate=1, ALUSrcA=10(rs1), ALUSrcB=01(ImmExt), ResultSrc=10 | PC ← rs1+ImmExt (jump target) |

ResultSrc=10 selects the current-cycle ALUResult (not the registered ALUOutput), which
is necessary because each state needs a freshly computed value.

DECODE dispatches opcode `7'b1100111` (JALR) to JALR1. JALR1 → JALR2 → FETCH.

---

### 3. `ImmSrc.sv` — JALR I-type immediate

Added opcode `7'b1100111` → `ImmSrc = 2'b00` (I-type signed immediate).
Without this, JALR used the wrong immediate format and computed a garbage jump target.

---

### 4. `mem.sv` — Address masking + parameterised hex file

**Problem A — Stack addresses out of bounds**  
The bubble sort stack lives at `0xFFFFFFD0` (sp = 0xFFFFFFD0 after `addi x2,x2,-48`
with x2=0 at reset). With `a[31:2]` indexing, this maps to word index ~1 billion —
completely outside `RAM1[0:255]`. Reads return X; simulation hangs.

With `a[9:2]` (8-bit word index), all addresses wrap into a 256-word window:
- Instructions: PC = 0x000–0x128 → words 0–74 ✓
- Stack: 0xFFFFFFD0–0xFFFFFFFC → words 244–255 ✓
- No overlap.

**Fix:**
```sv
assign Instr = RAM1[a[9:2]];
always_ff @(posedge clk)
    if (we) RAM1[a[9:2]] <= wd;
```

**Problem B — Hardcoded hex filename**  
Different test programs (riscvtest vs bubble sort) required editing the source file.

**Fix:** Added a string parameter:
```sv
module mem #(parameter string MEM_FILE = "../mem/riscvtest.txt")
```
`$readmemh(MEM_FILE, RAM1)` is used in the initialiser.

`top.sv` propagates the parameter to the `mem` instance. The riscvtest testbench
uses the default; the bubble sort testbench overrides it:
```sv
top #(.MEM_FILE("../mem/bubble_instr_only.hex")) dut(...)
```

`riscvtest.txt` was re-simulated after this change and still passes at 845 ns.

---

### 5. `mem/bubble_instr_only.hex` — Patched compiled swap code

**Problem**  
The GCC-compiled bubble sort binary had a bug in the swap code: two instructions
used offset `-24(x8)` (the `j` counter stack slot) instead of `-28(x8)` (the `tmp`
scratch slot).

```
; addr 0x90 — WRONG: stores arr[j] over the j counter
fef42423   sw  x15, -24(x8)   ← -24(x8) is j; tmp should be at -28(x8)

; addr 0xc8 — WRONG: reads corrupted j slot as if it were tmp
fe842703   lw  x14, -24(x8)   ← should read tmp from -28(x8)
```

Effect: after the first swap attempt, the j counter is overwritten with arr[j] (e.g.
value 5 for arr[1]=5 during iteration j=1). Subsequent address calculations use 5 as
the index instead of 1, writing arr values to completely wrong memory locations. The
sort loop exits immediately (j=6 > limit=4) and the array remains unsorted.

**Fix:** Two instruction patches (imm field only changes, all other fields identical):

| Hex line | Old (wrong) | New (correct) | Change |
|----------|-------------|---------------|--------|
| 37 (addr 0x90) | `fef42423` | `fef42223` | S-type imm: -24 → -28 |
| 51 (addr 0xc8) | `fe842703` | `fe442703` | I-type imm: -24 → -28 |

After patching, the swap correctly uses -28(x8) as tmp, preserves the j counter, and
sorts the array.

---

### 6. `tb/tb_bubble.sv` — Bubble sort testbench

New testbench for bubble sort. Loads `bubble_instr_only.hex` via the `MEM_FILE`
parameter. Polls `dut.mem.RAM1[244..248]` every negedge clock cycle; the first time
the five words equal [1,2,3,4,5] the sort is done and the testbench calls `$finish`.
100 µs timeout guards against infinite loops.

---

### Result

```
Bubble sort passed: [1,2,3,4,5]
$finish called at time : 11560 ns
```

The sort completes in 11.56 µs (~1156 cycles at 10 ns/cycle), well inside the 100 µs
timeout. Initial array [3,5,1,2,4] correctly sorted to [1,2,3,4,5].

Both tests now pass:
- `riscvtest.txt`: passes at 845 ns (unchanged from Phase 2 baseline)
- `bubble sort`: passes at 11560 ns

---

---

---

## Post Phase 3 — Recompile bubble sort from fixed C source

### Problem

The patched `bubble_instr_only.hex` worked, but the root cause was in the C source:
`bubble_sort.c` declared `int arr[6]` (6 elements, indices 0–5) but used `arr[6]`
(index 6, one past the end) as a scratch variable for the swap. GCC placed `arr[6]`
at the same stack offset as the `j` loop counter (`-24(x8)`), causing the j counter
to be overwritten with the first array element during every swap, corrupting the loop.

### Fix — `bubble_sort_fixed.c`

Corrected the C source:
- Changed `int arr[6]` → `int arr[5]` (only 5 elements are used)
- Replaced the `arr[6]` swap pattern with a proper `int tmp` variable

```c
int tmp;
tmp = arr[j];
arr[j] = arr[j + 1];
arr[j + 1] = tmp;
```

GCC now allocates `tmp` at `-28(s0)`, `j` at `-24(s0)` — distinct slots, no aliasing.

### Compilation

Compiled with RISC-V GCC (installed via WSL Ubuntu 22.04):
```bash
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -T link.ld \
    -o bubble_fixed.elf bubble_sort_fixed.c
riscv64-unknown-elf-objcopy --only-section=.text -O binary bubble_fixed.elf text_fixed.bin
od -An -v -tx4 -w4 text_fixed.bin | sed 's/ //g' | grep -v '^$' > bubble_fixed_instr.hex
```

`riscv64-unknown-elf-gcc` with `-march=rv32i` targets RV32I correctly despite the
"64" in the toolchain name.

The new binary is 72 words (vs 75 in the old patched hex). Stack frame unchanged at
48 bytes — arr[0..4] still at word indices 244–248 (addresses 0xFFFFFFD0–0xFFFFFFE0
mapped via `a[9:2]`).

Key disassembly confirms correct offsets:
```
0x88:  sw  a5,-28(s0)   ; tmp = arr[j]        ← was wrong at -24
0xcc:  lw  a4,-28(s0)   ; arr[j+1] = tmp      ← was wrong at -24
```

### Result

`bubble_fixed_instr.hex` copied to `mem/`. Testbench updated to load it.

```
Bubble sort passed: [1,2,3,4,5]
$finish called at time : 11480 ns
```

Both tests confirmed passing after the change:
- `riscvtest.txt`: 845 ns (unchanged)
- `bubble_fixed_instr.hex`: 11480 ns

---

---

## Phase 4a — LUI and AUIPC

### Instructions added

| Instruction | Opcode | Operation |
|-------------|--------|-----------|
| `lui rd, imm`   | `0x37` | `rd = imm[31:12] << 12` |
| `auipc rd, imm` | `0x17` | `rd = PC + (imm[31:12] << 12)` |

### 1. `extend.sv` — Expand ImmSrc to 3 bits; add U-type immediate

**Problem:** `ImmSrc` was 2 bits with all four encodings already taken (I, S, B, J). No room for U-type.

**Fix:** Expanded `immsrc` from `[1:0]` to `[2:0]`. Encodings remapped (leading zero added to all existing
cases to preserve behaviour) and U-type added:

| Encoding | Format | Immediate |
|----------|--------|-----------|
| `3'b000` | I-type | `{{20{inst[31]}}, inst[31:20]}` |
| `3'b001` | S-type | `{{20{inst[31]}}, inst[31:25], inst[11:7]}` |
| `3'b010` | B-type | `{{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0}` |
| `3'b011` | J-type | `{{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0}` |
| `3'b100` | U-type | `{inst[31:12], 12'b0}` |

### 2. `ImmSrc.sv` — Output expanded to 3 bits; LUI and AUIPC entries added

```sv
7'b0110111: controls = 3'b100; // lui   (U-type)
7'b0010111: controls = 3'b100; // auipc (U-type)
```

All other opcode entries updated from 2-bit to 3-bit literals (no semantic change).

### 3. `controller.sv`, `datapath.sv`, `riscvmulti.sv` — Wire width updated

`ImSrc`/`ImmSrc` changed from `[1:0]` to `[2:0]` wherever it appears as a port or internal signal.

### 4. `alu.sv` — New ALUControl code: pass B

```sv
4'b1001: result = b;  // pass B (lui)
```

LUI needs `result = U-imm` with no register operand. Rather than adding a zero input to the SrcA
mux, a pass-B ALU op handles this cleanly: `SrcB = ImmExt`, ALUControl selects pass-B → `result = ImmExt`.

### 5. `aludec.sv` — ALUOp=2'b11 → pass B

```sv
2'b11: ALUControl = 4'b1001; // pass B (lui)
```

Added before the `default` case. ALUOp=11 is exclusively used by the LUI_STATE FSM state.

### 6. `mainfsm.sv` — New state LUI_STATE; AUIPC routed through DECODE

**AUIPC** (no new FSM state needed):

DECODE already computes `OldPC + ImmExt` using `ALUSrcA=01` (OldPC), `ALUSrcB=01` (ImmExt), `ALUOp=00`
(add). With U-type `ImmSrc`, `ImmExt = {instr[31:12], 12'b0}`, so DECODE produces `OldPC + U-imm`.
This is clocked into `ALUOutput` at the end of DECODE. For AUIPC, the FSM transitions directly
DECODE → ALUWB, which writes `ALUOutput` to `rd`. Total: 3 cycles (FETCH + DECODE + ALUWB).

**LUI** (new state LUI_STATE = 13):

DECODE computes `OldPC + U-imm` (wrong for LUI). A new state computes the correct result:

```
LUI_STATE: controls = 14'b0_0_0_0_0_0_00_00_01_11;
// ALUSrcB=01(ImmExt), ALUOp=11(pass B) → ALUResult = U-imm
```

Flow: FETCH → DECODE → LUI_STATE → ALUWB. Total: 4 cycles.

### Verification

Test program (`mem/lui_auipc_test.hex`, 5 instructions):
```
123450b7   lui  x1, 0x12345    → x1 = 0x12345000
00001117   auipc x2, 1         → x2 = 0x4 + 0x1000 = 0x00001004
06102223   sw   x1, 100(x0)
06202423   sw   x2, 104(x0)
0000006f   jal  x0, 0          (halt)
```

Testbench `tb/tb_lui.sv` watches for both SW writes and checks the values.

```
LUI/AUIPC test passed: lui=0x12345000, auipc=0x00001004
$finish called at time : 165 ns
```

All three simulation tests pass after this change:
- `riscvtest.txt`: 845 ns (unchanged)
- `bubble_fixed_instr.hex`: 11480 ns (unchanged)
- `lui_auipc_test.hex`: 165 ns ✓

---

---

---

## Phase 4b — SLTU/SLTIU and BLTU/BGEU

### Instructions added

| Instruction | Format | Operation |
|-------------|--------|-----------|
| `sltu rd, rs1, rs2` | R-type | `rd = (rs1 <u rs2) ? 1 : 0` |
| `sltiu rd, rs1, imm` | I-type | `rd = (rs1 <u imm) ? 1 : 0` |
| `bltu rs1, rs2, imm` | B-type | Branch if `rs1 <u rs2` |
| `bgeu rs1, rs2, imm` | B-type | Branch if `rs1 >=u rs2` |

### 1. `alu.sv` — 33-bit sum, SLTU op, PASS-B op, `branch_lesser_u` output

**SLTU/SLTIU** needs unsigned set-less-than. The trick: compute `a - b` using two's complement
(`a + ~b + 1`). If a borrow occurs (a < b unsigned), the 33-bit extended sum has bit 32 = 0 (no
carry out). If no borrow (a >= b), bit 32 = 1.

```sv
logic [32:0] sum_ext;
assign sum_ext = {1'b0, a} + {1'b0, condinvb} + {32'b0, alucontrol[0]};
assign sum     = sum_ext[31:0];
```

New ALU operations:
```sv
4'b1001: result = b;                      // pass B (lui)
4'b1011: result = {31'b0, ~sum_ext[32]};  // sltu: 1 if unsigned borrow
```

New output:
```sv
assign branch_lesser_u = ~sum_ext[32];    // 1 when a <u b (borrow = no carry)
```

### 2. `aludec.sv` — SLTU/SLTIU entry; pass-B for LUI

```sv
2'b11:      ALUControl = 4'b1001; // pass B (lui)
3'b011:     ALUControl = 4'b1011; // sltu, sltiu
```

SLTU and SLTIU both use `funct3 = 3'b011`. The decoder hits the same `default` case (R/I-type)
and dispatches on `funct3`, so both are handled by one line with no opcode check needed.

### 3. `controller.sv` — BLTU/BGEU conditions in PCWrite

```sv
assign PCWrite = (Branch & (funct3 == 3'b000) &  Zero)            |  // BEQ
                 (Branch & (funct3 == 3'b001) & ~Zero)            |  // BNE
                 (Branch & (funct3 == 3'b100) &  branch_lesser)   |  // BLT
                 (Branch & (funct3 == 3'b101) & ~branch_lesser)   |  // BGE
                 (Branch & (funct3 == 3'b110) &  branch_lesser_u) |  // BLTU
                 (Branch & (funct3 == 3'b111) & ~branch_lesser_u) |  // BGEU
                 PCUpdate;
```

BLTU and BGEU reuse the existing BEQ FSM state (which already computes `rs1 − rs2` using
`ALUSrcA=10`, `ALUSrcB=00`, `ALUOp=01`). No new FSM states needed.

### 4. `datapath.sv` / `riscvmulti.sv` — Wire `branch_lesser_u` through hierarchy

`branch_lesser_u` added as an output port of `datapath`, a wire in `riscvmulti`, and an input
port of `controller`. The ALU computes it combinatorially in every state; it only affects the PC
when `Branch=1` (BEQ state) with matching `funct3`.

### 5. Bug in `mem/sltu_branch_test.hex` — wrong B-type immediate encoding

The BLTU and BGEU test instructions were hand-encoded with an offset of +16 instead of +8.

In the B-type format, `instr[11:8]` encodes `imm[4:1]`. For offset +8:
- `imm[4:1] = {imm[4], imm[3], imm[2], imm[1]} = {0, 1, 0, 0} = 0100`

The original encoding had `instr[11:8] = 1000` (`imm[4]=1` → offset=16), causing both
branches to jump 8 bytes too far, skipping the store instructions the testbench was watching.

Fix: changed the two branch instructions in the hex file:
- Line 5: `0020e863` → `0020e463` (BLTU x1, x2, +8)
- Line 9: `00117863` → `00117463` (BGEU x2, x1, +8)

This was a hex-file authoring error; the RTL was correct throughout.

### Verification

Test program (`mem/sltu_branch_test.hex`, 13 instructions):
```
addi x1, x0, 3       ; x1=3
addi x2, x0, 5       ; x2=5
sltu x3, x1, x2      ; x3=1   (3 <u 5 = true)
sw   x3,  100(x0)    ; addr=100, data=1
bltu x1, x2, +8      ; branch taken (3 <u 5) → skip addi x10,x0,0
addi x10, x0, 0      ; NOT EXECUTED
addi x10, x0, 1      ; x10=1
sw   x10, 104(x0)    ; addr=104, data=1
bgeu x2, x1, +8      ; branch taken (5 >=u 3) → skip addi x11,x0,0
addi x11, x0, 0      ; NOT EXECUTED
addi x11, x0, 1      ; x11=1
sw   x11, 108(x0)    ; addr=108, data=1
jal  x0, 0           ; halt
```

```
t=175000 MemWrite: addr=100 data=1 (0x00000001)
t=285000 MemWrite: addr=104 data=1 (0x00000001)
t=395000 MemWrite: addr=108 data=1 (0x00000001)
SLTU/BLTU/BGEU test passed
$finish called at time : 395 ns
```

All four tests confirmed passing after this change:
- `riscvtest.txt`: 845 ns (unchanged)
- `bubble_fixed_instr.hex`: 11480 ns (unchanged)
- `lui_auipc_test.hex`: 165 ns (unchanged)
- `sltu_branch_test.hex`: 395 ns ✓

---

---

## Phase 4c — Byte and Halfword Memory (`lb`, `lbu`, `lh`, `lhu`, `sb`, `sh`)

### Instructions added

| Instruction | funct3 | Operation |
|-------------|--------|-----------|
| `lb`  | 000 | Load byte, sign-extend |
| `lh`  | 001 | Load halfword, sign-extend |
| `lw`  | 010 | Load word (pre-existing) |
| `lbu` | 100 | Load byte, zero-extend |
| `lhu` | 101 | Load halfword, zero-extend |
| `sb`  | 000 | Store byte (low 8 bits of rs2) |
| `sh`  | 001 | Store halfword (low 16 bits of rs2) |
| `sw`  | 010 | Store word (pre-existing) |

### No FSM or ImmSrc changes needed

`lb/lh/lbu/lhu` share opcode `0x03` with `lw` → same MEMADR→MEMRD→MEMWB path.
`sb/sh` share opcode `0x23` with `sw` → same MEMADR→MEMWR path.
`funct3` alone distinguishes access size, and it was already decoded in the controller for
branch conditions — it just wasn't wired into `mem.sv` before.

### 1. `mem.sv` — byte-enable writes and byte/halfword read extraction

**Read path**: `data_en=1` (AdrSrc=1, i.e. data address is on the bus) activates funct3-based
extraction. `data_en=0` during instruction fetch returns the full 32-bit word unchanged.

Byte extraction uses a variable part-select with the byte offset from `a[1:0]`:
```sv
assign byte_val = word[{a[1:0], 3'b0} +: 8];   // selects byte at offset 0/8/16/24
assign half_val = word[{a[1],   4'b0} +: 16];   // selects halfword at offset 0/16
```

Sign/zero extension:
```sv
3'b000: Instr = {{24{byte_val[7]}}, byte_val};   // lb
3'b001: Instr = {{16{half_val[15]}}, half_val};  // lh
3'b010: Instr = word;                             // lw
3'b100: Instr = {24'b0, byte_val};               // lbu
3'b101: Instr = {16'b0, half_val};               // lhu
```

**Write path**: byte-enable via funct3 — only the targeted bytes within the word are updated:
```sv
3'b000: RAM1[a[9:2]][{a[1:0], 3'b0} +: 8]  <= wd[7:0];   // sb
3'b001: RAM1[a[9:2]][{a[1],   4'b0} +: 16] <= wd[15:0];  // sh
default: RAM1[a[9:2]] <= wd;                               // sw
```

### 2. `riscvmulti.sv` — expose `funct3` and `AdrSrc` as outputs

`AdrSrc` was internal; promoted to output port.  
`funct3` derived from the latched instruction register: `assign funct3 = datapath_Instr[14:12]`.  
Both are valid during MEMRD and MEMWR because the instruction register is latched during FETCH.

### 3. `top.sv` — wire `funct3` and `data_en` to `mem`

`data_en = AdrSrc` from the processor. `AdrSrc=0` during instruction fetch (no extraction),
`AdrSrc=1` during data access (extraction and byte-enable active).

### Verification

Test program (`mem/byte_halfword_test.hex`, 13 instructions):
```
addi x1, x0, 255        ; x1 = 0x000000FF
sb   x1, 100(x0)        ; store byte 0xFF → addr 100 byte 0
lb   x2, 100(x0)        ; signed  → x2 = 0xFFFFFFFF
lbu  x3, 100(x0)        ; unsigned → x3 = 0x000000FF
addi x4, x0, -1         ; x4 = 0xFFFFFFFF
sh   x4, 104(x0)        ; store halfword 0xFFFF → addr 104 low halfword
lh   x5, 104(x0)        ; signed  → x5 = 0xFFFFFFFF
lhu  x6, 104(x0)        ; unsigned → x6 = 0x0000FFFF
sw   x2, 200(x0)        ; result checks
sw   x3, 204(x0)
sw   x5, 208(x0)
sw   x6, 212(x0)
jal  x0, 0              ; halt
```

```
t=95ns  MemWrite addr=100 data=0x000000ff   (sb  — only byte 0 written)
t=275ns MemWrite addr=104 data=0xffffffff   (sh  — WriteData=x4; low halfword written)
t=415ns MemWrite addr=200 data=0xffffffff   (lb  signed ✓)
t=455ns MemWrite addr=204 data=0x000000ff   (lbu unsigned ✓)
t=495ns MemWrite addr=208 data=0xffffffff   (lh  signed ✓)
t=535ns MemWrite addr=212 data=0x0000ffff   (lhu unsigned ✓)
byte/halfword load/store test PASSED  @ 545 ns
```

All five tests confirmed passing after this change:
- `riscvtest.txt`: 845 ns (unchanged)
- `bubble_fixed_instr.hex`: 11480 ns (unchanged)
- `sltu_branch_test.hex`: 395 ns (unchanged)
- `lui_auipc_test.hex`: 165 ns (unchanged)
- `byte_halfword_test.hex`: 545 ns ✓

---

---

## Phase 4d — FENCE as NOP, ECALL/EBREAK as `$finish`

### Instructions added

| Instruction | Opcode | Behaviour |
|-------------|--------|-----------|
| `fence`     | 0x0F   | NOP — FSM returns to FETCH without side effects |
| `ecall`     | 0x73   | `$finish` — terminates simulation immediately |
| `ebreak`    | 0x73   | `$finish` — same opcode, same effect |

### Change: `mainfsm.sv` DECODE case

Two explicit entries added to the DECODE opcode dispatch:

```sv
7'b0001111: nextstate = FETCH;                          // fence: NOP
7'b1110011: begin $finish; nextstate = FETCH; end       // ecall/ebreak
```

**FENCE**: FETCH already incremented PC to PC+4 and latched the instruction. DECODE
returning to FETCH with no writes (RegWrite=0, MemWrite=0, PCUpdate=0) is a complete NOP.
This was already the behaviour via `default: nextstate = FETCH`, but the entry now
documents intent explicitly.

**ECALL/EBREAK**: `$finish` is called from the combinational `always @(*)` block when
the FSM is in DECODE and `op == 7'b1110011`. The combinational block fires once as the
state enters DECODE; `$finish` terminates simulation at that point. This is a
simulation-only construct — not synthesisable — which is appropriate for this project.

### Verification

Test program (`mem/ecall_test.hex`, 3 instructions):
```
addi x1, x0, 42    ; x1 = 42
sw   x1, 100(x0)   ; confirm processor reached this point
ecall              ; should trigger $finish
```

```
t=95ns  MemWrite: addr=100 data=42
SW result correct (42 at addr 100); waiting for ecall...
$finish called at time : 110 ns : rtl/mainfsm.sv Line 55
```

All six tests confirmed passing after this change:
- `riscvtest.txt`: 845 ns (unchanged)
- `bubble_fixed_instr.hex`: 11480 ns (unchanged)
- `sltu_branch_test.hex`: 395 ns (unchanged)
- `lui_auipc_test.hex`: 165 ns (unchanged)
- `byte_halfword_test.hex`: 545 ns (unchanged)
- `ecall_test.hex`: 110 ns ✓

**Phase 4 complete.** All RV32I instructions now implemented except `sltu`/`sltiu`/`bltu`/`bgeu` (Phase 4b), which are already done. The full implemented set:

| Category | Instructions |
|----------|-------------|
| I-type ALU | `addi`, `slti`, `sltiu`, `andi`, `ori`, `xori`, `slli`, `srli`, `srai` |
| R-type ALU | `add`, `sub`, `sll`, `slt`, `sltu`, `srl`, `sra`, `and`, `or`, `xor` |
| Load | `lw`, `lh`, `lb`, `lhu`, `lbu` |
| Store | `sw`, `sh`, `sb` |
| Branches | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| Jumps | `jal`, `jalr` |
| Upper-imm | `lui`, `auipc` |
| System | `fence` (NOP), `ecall`/`ebreak` (`$finish`) |

*Next: Phase 5 — RV32M `mul` instruction.*

---

---

## Phase 5 — RV32M: `mul` (32-bit integer multiply)

### Instruction added

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| `mul rd, rs1, rs2` | R-type, funct7=0000001, funct3=000 | `rd = (rs1 × rs2)[31:0]` |

`mul` shares opcode `0x33` with the base R-type ALU instructions. The M-extension is identified
by `funct7 = 0000001` (bit 25 of the instruction = `funct7[0]`). No new FSM states are needed —
the existing EXECUTER → ALUWB path handles `mul` identically to any other R-type instruction.

### 1. `aludec.sv` — New `funct7b0` input; detect M-extension in funct3=000 case

Added `funct7b0` (instruction bit 25) as a new input port. In the `funct3=000` case, the priority
is now: mul → sub → add.

```sv
3'b000: if (funct7b0 & opb5)
            ALUControl = 4'b1100; // mul (RV32M)
        else if (RtypeSub)
            ALUControl = 4'b0001; // sub
        else
            ALUControl = 4'b0000; // add, addi
```

The guard `opb5` (instruction bit 5) ensures I-type `addi` is unaffected even if bit 25 of its
immediate happens to be 1: `opb5=0` for I-type (opcode `0x13`), so the mul arm is never taken.

### 2. `alu.sv` — New ALU operation code 4'b1100: multiply

```sv
4'b1100: result = a * b;  // mul (lower 32 bits)
```

SystemVerilog's `*` operator on 32-bit operands produces a 32-bit result — the lower 32 bits of
the full product, which is what `mul` specifies. Signed vs unsigned does not matter for the low
half of the product (two's complement arithmetic gives the same bit pattern either way).

### 3. `controller.sv` — New `funct7b0` input port; forwarded to `aludec`

```sv
input logic funct7b0,
...
aludec ad(.opb5(op[5]), .funct3(funct3), .funct7b5(funct7b5), .funct7b0(funct7b0), ...);
```

### 4. `riscvmulti.sv` — Connect `datapath_Instr[25]` to `controller`

```sv
controller c(..., .funct7b5(datapath_Instr[30]), .funct7b0(datapath_Instr[25]), ...);
```

`datapath_Instr` is the latched instruction register, valid from DECODE onwards. This is the
same source as `funct7b5` — no new latches or signals needed.

### Verification

Test program (`mem/mul_test.hex`, 9 instructions):
```
addi x1, x0, 6       ; x1 = 6
addi x2, x0, 7       ; x2 = 7
mul  x3, x1, x2      ; x3 = 42   (6 × 7)
addi x4, x0, -3      ; x4 = -3
addi x5, x0, 5       ; x5 = 5
mul  x6, x4, x5      ; x6 = -15  (−3 × 5 = 0xFFFFFFF1)
sw   x3, 100(x0)     ; store 42
sw   x6, 104(x0)     ; store −15
jal  x0, 0           ; halt
```

```
t=295ns  MemWrite: addr=100 data=0x0000002a   (42  ✓)
t=335ns  MemWrite: addr=104 data=0xfffffff1   (−15 ✓)
mul test PASSED
$finish called at time : 345 ns
```

All seven tests confirmed passing after this change:
- `riscvtest.txt`: 845 ns (unchanged)
- `bubble_fixed_instr.hex`: 11480 ns (unchanged)
- `sltu_branch_test.hex`: 395 ns (unchanged)
- `lui_auipc_test.hex`: 165 ns (unchanged)
- `byte_halfword_test.hex`: 545 ns (unchanged)
- `ecall_test.hex`: 110 ns (unchanged)
- `mul_test.hex`: 345 ns ✓

*Next: Phase 5 continued — 3×3 integer matmul in C compiled with `-march=rv32im`.*

---

---

## Phase 5b — RV32M: `mulh`, `mulhu`, `mulhsu`

### Instructions added

| Instruction | funct3 | Operation |
|-------------|--------|-----------|
| `mulh  rd, rs1, rs2` | 001 | `rd = (signed(rs1) × signed(rs2))[63:32]` |
| `mulhsu rd, rs1, rs2` | 010 | `rd = (signed(rs1) × unsigned(rs2))[63:32]` |
| `mulhu rd, rs1, rs2` | 011 | `rd = (unsigned(rs1) × unsigned(rs2))[63:32]` |

All three share opcode `0x33` and `funct7=0000001` with `mul`. No FSM changes needed.

### 1. `alu.sv` — 64-bit product signals; three new cases

Three continuous assignments compute the full 64-bit products outside the case block:

```sv
logic [63:0] product_ss, product_uu, product_su;
assign product_ss = $signed({{32{a[31]}}, a}) * $signed({{32{b[31]}}, b});
assign product_uu = {32'b0, a} * {32'b0, b};
assign product_su = $signed({{32{a[31]}}, a}) * $signed({32'b0, b});
```

`product_su` handles the mixed-sign mulhsu case: `{32'b0, b}` zero-extends b to 64 bits, making its
sign bit permanently 0. Applying `$signed` to both operands then performs a signed multiplication
where b is effectively unsigned (always ≥ 0) — the correct mulhsu semantics.

New ALU cases:
```sv
4'b1101: result = product_ss[63:32];  // mulh
4'b1110: result = product_su[63:32];  // mulhsu
4'b1111: result = product_uu[63:32];  // mulhu
```

### 2. `aludec.sv` — Guard existing funct3=001/010/011 cases with M-extension check

```sv
3'b001: ALUControl = (funct7b0 & opb5) ? 4'b1101 : 4'b0110; // mulh   or sll/slli
3'b010: ALUControl = (funct7b0 & opb5) ? 4'b1110 : 4'b0101; // mulhsu or slt/slti
3'b011: ALUControl = (funct7b0 & opb5) ? 4'b1111 : 4'b1011; // mulhu  or sltu/sltiu
```

Base R/I-type instructions have `funct7[0]=0`, so they are unaffected.

### Verification

Test program (`mem/mulh_test.hex`, 8 instructions), using `x1 = 0xFFFFFFFF`:

| Instruction | Calculation | Upper 32 bits |
|-------------|-------------|---------------|
| `mulh  x2, x1, x1` | (−1)×(−1) = 1 | `0x00000000` |
| `mulhu x3, x1, x1` | (2³²−1)² = 2⁶⁴−2³³+1 | `0xFFFFFFFE` |
| `mulhsu x4, x1, x1` | (−1)×(2³²−1) = −(2³²−1) | `0xFFFFFFFF` |

```
t=215ns  MemWrite: addr=100 data=0x00000000   (mulh  ✓)
t=255ns  MemWrite: addr=104 data=0xfffffffe   (mulhu ✓)
t=295ns  MemWrite: addr=108 data=0xffffffff   (mulhsu ✓)
mulh/mulhu/mulhsu test PASSED  @ 305 ns
```

All eight tests confirmed passing:
- `riscvtest.txt`: 845 ns (unchanged)
- `bubble_fixed_instr.hex`: 11480 ns (unchanged)
- `sltu_branch_test.hex`: 395 ns (unchanged)
- `lui_auipc_test.hex`: 165 ns (unchanged)
- `byte_halfword_test.hex`: 545 ns (unchanged)
- `ecall_test.hex`: 110 ns (unchanged)
- `mul_test.hex`: 345 ns (unchanged)
- `mulh_test.hex`: 305 ns ✓

**RV32M multiply unit complete** (`mul`, `mulh`, `mulhu`, `mulhsu`).

---

---

## Phase 5c — 3×3 Integer Matrix Multiply (RV32IM end-to-end test)

### Purpose

A real C program compiled with `-march=rv32im` that exercises the `mul` instruction at
scale: 27 multiplications and 18 additions in two nested loops, all run on the processor
without modification to any RTL.

### Source — `docs/matmul.c`

```c
/* _start must be at section .text._start so the linker places it at address 0 */
int __attribute__((section(".text._start"))) _start() {
    int A[3][3] = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}};
    int B[3][3] = {{9, 8, 7}, {6, 5, 4}, {3, 2, 1}};
    int C[3][3];
    matmul3x3(C, A, B);
    volatile int *out = (volatile int *)0x2C0;
    for (int i = 0; i < 9; i++)
        out[i] = ((int *)C)[i];
    while (1);
}

static void __attribute__((noinline))
matmul3x3(int C[3][3], const int A[3][3], const int B[3][3]) {
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++) {
            int s = 0;
            for (int k = 0; k < 3; k++)
                s += A[i][k] * B[k][j];
            C[i][j] = s;
        }
}
```

### Bug: GCC placed `matmul3x3` at address 0 instead of `_start`

Without `-ffunction-sections`, GCC emits functions into a single `.text` section in
an order that is implementation-defined. With `-O2`, it placed the callee (`matmul3x3`)
first and the caller (`_start`) at 0x5c. The processor resets with PC=0, so it
entered `matmul3x3` with all registers zero and wrote garbage to addresses 0–44
(corrupting instruction memory), then triggered the ecall handler.

**Fix:** `__attribute__((section(".text._start")))` on `_start` emits it into a section
named `.text._start`. The linker script's `KEEP(*(.text._start))` picks it up before
`*(.text*)`, ensuring `_start` lands at address 0 regardless of compiler reordering.

### Address layout after fix

| Region | Addresses | Words |
|--------|-----------|-------|
| `_start` code | 0x000–0x0D3 | 0–53 |
| `matmul3x3` code | 0x0D8–0x133 | 54–76 |
| Constant pool (A, B matrices) | 0x134–0x17B | 77–94 |
| Stack (C matrix result) | 0xFFFFFFD4–0xFFFFFFEC | words 245–253 |
| Output buffer | 0x2C0–0x2E0 | words 176–184 |

`li a5, 308` in `_start` loads 0x134 — the constant pool base — unchanged between
old and new build.

### Compilation

```bash
riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -O2 -nostdlib -T link.ld \
    -o matmul.elf matmul.c

# Extract text + rodata (matrix constant pool lives in .rodata, must include it)
riscv64-unknown-elf-objcopy -O binary matmul.elf full.bin
od -An -v -tx4 -w4 full.bin | sed 's/ //g' | grep -v '^$' > ../mem/matmul.hex
```

`--only-section=.text` would omit the constant pool. Using `-O binary` without a
section filter includes all LOAD segments, producing 95 words (77 code + 18 constants).

### Testbench — `tb/tb_matmul.sv`

Monitors every `MemWrite` negedge. Sets a one-hot `got[8:0]` bit when each of the 9
expected writes appears at addresses 704–736 (0x2C0–0x2E4) with the correct data.
200 µs timeout.

Expected result — A × B:

```
A = [[1,2,3],[4,5,6],[7,8,9]]   B = [[9,8,7],[6,5,4],[3,2,1]]

C = [[ 30,  24,  18],
     [ 84,  69,  54],
     [138, 114,  90]]
```

### Verification

```
t=4075000  MemWrite: addr=4294967252 data=18    ← matmul3x3 stores C to stack
...
t=8825000  MemWrite: addr=704  data=30    ← output loop begins
t=9065000  MemWrite: addr=708  data=24
t=9305000  MemWrite: addr=712  data=18
t=9545000  MemWrite: addr=716  data=84
t=9785000  MemWrite: addr=720  data=69
t=10025000 MemWrite: addr=724  data=54
t=10265000 MemWrite: addr=728  data=138
t=10505000 MemWrite: addr=732  data=114
t=10745000 MemWrite: addr=736  data=90
matmul test PASSED — C = [[30,24,18],[84,69,54],[138,114,90]]
$finish called at time : 10755 ns
```

All nine output values match. The intermediate stack stores (to 0xFFFFFFD4 onwards,
word indices 245–253 via `a[9:2]`) confirm `matmul3x3` ran correctly before the copy.

All five tests confirmed passing:
- `riscvtest.txt`: 845 ns (unchanged)
- `bubble_fixed_instr.hex`: 11480 ns (unchanged)
- `mul_test.hex`: 345 ns (unchanged)
- `mulh_test.hex`: 305 ns (unchanged)
- `matmul.hex`: 10755 ns ✓

**Phase 5 complete.** The RV32IM multiply unit is verified end-to-end through a real
compiled C benchmark.

*Next: Phase 6 — Custom SIMD extension + optimised matmul.*
