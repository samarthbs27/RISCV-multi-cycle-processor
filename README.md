# RISCV‑multi‑cycle‑processor

A 32‑bit multi‑cycle RISC‑V processor implementing a subset of the RV32I
ISA.

## Table of Contents

-   [Overview](#overview)
-   [Features](#features)
-   [Repository Structure](#repository-structure)
-   [Getting Started](#getting-started)
    -   [Prerequisites](#prerequisites)
    -   [Simulation / Testbench](#simulation--testbench)
-   [Usage](#usage)
-   [Supported Instructions](#supported-instructions)
-   [Design Approach](#design-approach)
-   [Future Work](#future-work)
-   [Contributing](#contributing)
-   [License](#license)
-   [About the Author & Project
    Context](#about-the-author--project-context)

## Overview

This repository contains a SystemVerilog implementation of a 32‑bit
multi‑cycle RISC‑V processor core, compatible with a subset of the RV32I
instruction set. The design emphasises a clear separation of the
datapath and control FSM, enabling instruction execution over multiple
cycles for improved resource reuse and simpler control logic.

## Features

-   Multi‑cycle datapath implementation (fetch → decode → execute →
    memory → write‑back)
-   Implemented in SystemVerilog
-   Subset of RV32I instructions supported
-   Modular design: ALU, register file, memory, control FSM,
    multiplexers, extension logic
-   Testbench and sample programs included for validation

## Repository Structure

    ├── ImmSrc.sv
    ├── alu.sv
    ├── aludec.sv
    ├── branch_test.txt
    ├── bubble.txt
    ├── controller.sv
    ├── datapath.sv
    ├── extend.sv
    ├── flopenr.sv
    ├── flopr.sv
    ├── flopr2.sv
    ├── mainfsm.sv
    ├── mem.sv
    ├── mux2.sv
    ├── mux3.sv
    ├── regfile.sv
    ├── riscvmulti.sv
    ├── riscvtest.txt
    ├── tb.sv
    ├── top.sv
    ├── LICENSE
    └── README.md

## Getting Started

### Prerequisites

-   A SystemVerilog‑capable simulator
-   Optional: GTKWave

### Simulation / Testbench

    git clone https://github.com/<username>/RISCV-multi-cycle-processor.git
    vsim -sv -f tb.sv

## Usage

Modify `.txt` program files and simulate to verify functionality.

## Supported Instructions

Supports a subset of RV32I such as: - lui, auipc - addi, slti, andi,
ori, xori - add, sub, sll, slt, sra, srli, slli - lw, sw - beq, bne,
blt, bge - jal, jalr

## Design Approach

-   Multi‑cycle FSM based processor
-   Modular datapath
-   Test‑driven verification
-   Educational and extensible design

## Future Work

-   Full RV32I support
-   Hazard detection
-   Pipelining
-   Cache/MEM hierarchy
-   RV32M extension
-   FPGA implementation

## Contributing

PRs welcome!

## License

MIT License.

## About the Author & Project Context

Developed as part of self‑learning in architecture and VLSI, including
multi‑cycle RISC‑V, UVM testing, and CVA6 exploration.
