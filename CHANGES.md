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

*Next: Phase 4 — Complete RV32I ISA (LUI, AUIPC, SLTU, SLTIU, BLTU, BGEU, byte/halfword loads and stores).*
