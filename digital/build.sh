#!/usr/bin/env bash
# Recompila toda a biblioteca de trabalho do GHDL usada pelo Digital
# (componente "Arquivo externo" do cpu_pipeline.dig, workdir=digital).
# Rode isto sempre que qualquer arquivo VHDL do projeto mudar, antes de
# abrir o circuito no Digital.
set -euo pipefail
cd "$(dirname "$0")/.."
WORKDIR=digital

ghdl -a --std=08 --workdir=$WORKDIR src/alu/alu.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/vector/cla4.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/vector/vec_adder.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/vector/vec_shifter.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/vector/vec_alu.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/regfile/regfile.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/control/decoder.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/pipeline/if_id_reg.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/pipeline/id_ex_reg.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/pipeline/ex_mem_reg.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/pipeline/mem_wb_reg.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/pipeline/hazard_unit.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/pipeline/forwarding_unit.vhd
ghdl -a --std=08 --workdir=$WORKDIR src/top/cpu_pipeline.vhd
ghdl -a --std=08 --workdir=$WORKDIR digital/top.vhd

echo "Biblioteca $WORKDIR/work-obj08.cf reconstruida com sucesso."
