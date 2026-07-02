# AC-CPU-RV32I — RISC-V RV32I Pipelined CPU

**UFRJ — Escola Politécnica — Computer Architecture**

5-stage pipelined RISC-V RV32I CPU implemented in VHDL, simulated with GHDL and validated in Digital.

## Supported Instructions
- Arithmetic: add, addi, auipc, sub
- Logical: and, andi, or, ori, xor, xori
- Shift: sll, slli, srl, srli
- Memory: lw, lui, sw
- Jump/Branch: jal, jalr, beq, bne

## Pipeline Stages
IF → ID → EX → MEM → WB

## Source Structure
src/alu/        — ALU and supporting arithmetic units
src/regfile/    — 32×32-bit register file
src/control/    — instruction decoder and control unit
src/pipeline/   — pipeline registers (IF/ID, ID/EX, EX/MEM, MEM/WB)
src/memory/     — instruction and data memory interfaces
src/top/        — top-level CPU integration
digital/        — Digital simulator circuit files
sim/            — simulation scripts and test programs

## How to simulate
ghdl -a src/alu/alu.vhd
ghdl -a src/alu/alu_tb.vhd
ghdl -e alu_tb
ghdl -r alu_tb

## Authors
Luiz Cavalini, Eduardo Viana, Henrique Kezen, Rafael Maurício
