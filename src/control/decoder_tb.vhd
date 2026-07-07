library ieee;
use ieee.std_logic_1164.all;

entity decoder_tb is
end entity decoder_tb;

architecture sim of decoder_tb is
  signal instr    : std_logic_vector(31 downto 0);
  signal reg_we   : std_logic;
  signal alu_src  : std_logic;
  signal alu_ctrl : std_logic_vector(3 downto 0);
  signal mem_we   : std_logic;
  signal mem_re   : std_logic;
  signal wb_sel   : std_logic_vector(1 downto 0);
  signal branch   : std_logic;
  signal jump     : std_logic;
  signal jalr     : std_logic;
  signal imm      : std_logic_vector(31 downto 0);
  signal is_vector: std_logic;
  signal vecsize  : std_logic_vector(1 downto 0);
begin

  uut: entity work.decoder
    port map(instr_i=>instr, reg_we_o=>reg_we, alu_src_o=>alu_src,
             alu_ctrl_o=>alu_ctrl, mem_we_o=>mem_we, mem_re_o=>mem_re,
             wb_sel_o=>wb_sel, branch_o=>branch, jump_o=>jump,
             jalr_o=>jalr, imm_o=>imm,
             is_vector_o=>is_vector, vecsize_o=>vecsize);

  process
  begin
    -- ADD x1, x2, x3  (R-type: funct7=0, funct3=000, opcode=0110011)
    -- 0000000 00011 00010 000 00001 0110011
    instr <= "00000000001100010000000010110011"; wait for 10 ns;
    assert reg_we   = '1'    report "FALHOU: ADD reg_we"   severity error;
    assert alu_src  = '0'    report "FALHOU: ADD alu_src"  severity error;
    assert alu_ctrl = "0000" report "FALHOU: ADD alu_ctrl" severity error;
    assert branch   = '0'    report "FALHOU: ADD branch"   severity error;
    assert jump     = '0'    report "FALHOU: ADD jump"     severity error;
    -- Regressão: instrução escalar não deve acionar sinais vetoriais
    assert is_vector = '0'   report "FALHOU: ADD is_vector" severity error;
    assert vecsize   = "00"  report "FALHOU: ADD vecsize"   severity error;

    -- SUB x1, x2, x3  (R-type: funct7=0100000, funct3=000)
    -- 0100000 00011 00010 000 00001 0110011
    instr <= "01000000001100010000000010110011"; wait for 10 ns;
    assert alu_ctrl = "0001" report "FALHOU: SUB alu_ctrl" severity error;

    -- ADDI x1, x2, 5  (I-type: imm=5, funct3=000, opcode=0010011)
    -- 000000000101 00010 000 00001 0010011
    instr <= "00000000010100010000000010010011"; wait for 10 ns;
    assert reg_we   = '1'    report "FALHOU: ADDI reg_we"   severity error;
    assert alu_src  = '1'    report "FALHOU: ADDI alu_src"  severity error;
    assert alu_ctrl = "0000" report "FALHOU: ADDI alu_ctrl" severity error;
    assert imm      = x"00000005" report "FALHOU: ADDI imm" severity error;

    -- LW x1, 8(x2)  (I-type: imm=8, funct3=010, opcode=0000011)
    -- 000000001000 00010 010 00001 0000011
    instr <= "00000000100000010010000010000011"; wait for 10 ns;
    assert reg_we   = '1'    report "FALHOU: LW reg_we"  severity error;
    assert mem_re   = '1'    report "FALHOU: LW mem_re"  severity error;
    assert wb_sel   = "01"   report "FALHOU: LW wb_sel"  severity error;
    assert imm      = x"00000008" report "FALHOU: LW imm" severity error;

    -- SW x3, 8(x2)  (S-type: imm=8, funct3=010, opcode=0100011)
    -- 0000000 00011 00010 010 01000 0100011
    instr <= "00000000001100010010010000100011"; wait for 10 ns;
    assert reg_we   = '0'    report "FALHOU: SW reg_we"  severity error;
    assert mem_we   = '1'    report "FALHOU: SW mem_we"  severity error;
    assert imm      = x"00000008" report "FALHOU: SW imm" severity error;

    -- BEQ x1, x2, 4  (B-type: imm=4, funct3=000, opcode=1100011)
    -- 0000000 00010 00001 000 00100 1100011
    instr <= "00000000001000001000001001100011"; wait for 10 ns;
    assert branch   = '1'    report "FALHOU: BEQ branch"   severity error;
    assert alu_ctrl = "0001" report "FALHOU: BEQ alu_ctrl" severity error;

    -- LUI x1, 0x12345  (U-type: imm=0x12345, opcode=0110111)
    -- 00010010001101000101 00001 0110111
    instr <= "00010010001101000101000010110111"; wait for 10 ns;
    assert reg_we   = '1'    report "FALHOU: LUI reg_we"   severity error;
    assert alu_ctrl = "0111" report "FALHOU: LUI alu_ctrl" severity error;
    assert imm      = x"12345000" report "FALHOU: LUI imm" severity error;

    -- JAL x1, 0  (J-type: imm=0, opcode=1101111)
    -- 00000000000000000000 00001 1101111
    instr <= "00000000000000000000000011101111"; wait for 10 ns;
    assert jump     = '1'    report "FALHOU: JAL jump"   severity error;
    assert wb_sel   = "10"   report "FALHOU: JAL wb_sel" severity error;

    -- ── Custom-0: instruções vetoriais (Parte 2) ──────────────────
    -- VADD, vecsize="01" (opcode=0001011, funct3=000)
    instr <= x"0231008B"; wait for 10 ns;
    assert is_vector = '1'    report "FALHOU: VADD is_vector" severity error;
    assert alu_ctrl  = "0000" report "FALHOU: VADD alu_ctrl"  severity error;
    assert alu_src   = '0'    report "FALHOU: VADD alu_src"   severity error;
    assert vecsize   = "01"   report "FALHOU: VADD vecsize"   severity error;
    assert reg_we    = '1'    report "FALHOU: VADD reg_we"    severity error;

    -- VADDI, vecsize="10" (opcode=0001011, funct3=001)
    instr <= x"8052920B"; wait for 10 ns;
    assert is_vector = '1'    report "FALHOU: VADDI is_vector" severity error;
    assert alu_ctrl  = "0000" report "FALHOU: VADDI alu_ctrl"  severity error;
    assert alu_src   = '1'    report "FALHOU: VADDI alu_src"   severity error;
    assert vecsize   = "10"   report "FALHOU: VADDI vecsize"   severity error;
    assert reg_we    = '1'    report "FALHOU: VADDI reg_we"    severity error;
    assert imm       = x"00000005" report "FALHOU: VADDI imm" severity error;

    -- VAUIPC, vecsize="11" (opcode=0001011, funct3=010)
    instr <= x"C015230B"; wait for 10 ns;
    assert is_vector = '1'    report "FALHOU: VAUIPC is_vector" severity error;
    assert alu_ctrl  = "0000" report "FALHOU: VAUIPC alu_ctrl"  severity error;
    assert alu_src   = '1'    report "FALHOU: VAUIPC alu_src"   severity error;
    assert vecsize   = "11"   report "FALHOU: VAUIPC vecsize"   severity error;
    assert reg_we    = '1'    report "FALHOU: VAUIPC reg_we"    severity error;
    assert imm       = x"0002A000" report "FALHOU: VAUIPC imm" severity error;

    -- VSUB, vecsize="00" (opcode=0001011, funct3=011)
    instr <= x"0094338B"; wait for 10 ns;
    assert is_vector = '1'    report "FALHOU: VSUB is_vector" severity error;
    assert alu_ctrl  = "0001" report "FALHOU: VSUB alu_ctrl"  severity error;
    assert alu_src   = '0'    report "FALHOU: VSUB alu_src"   severity error;
    assert vecsize   = "00"   report "FALHOU: VSUB vecsize"   severity error;
    assert reg_we    = '1'    report "FALHOU: VSUB reg_we"    severity error;

    -- VSLL, vecsize="01" (opcode=0001011, funct3=100)
    instr <= x"02C5C50B"; wait for 10 ns;
    assert is_vector = '1'    report "FALHOU: VSLL is_vector" severity error;
    assert alu_ctrl  = "0101" report "FALHOU: VSLL alu_ctrl"  severity error;
    assert alu_src   = '0'    report "FALHOU: VSLL alu_src"   severity error;
    assert vecsize   = "01"   report "FALHOU: VSLL vecsize"   severity error;
    assert reg_we    = '1'    report "FALHOU: VSLL reg_we"    severity error;

    -- VSLLI, vecsize="10" (opcode=0001011, funct3=101)
    instr <= x"0437568B"; wait for 10 ns;
    assert is_vector = '1'    report "FALHOU: VSLLI is_vector" severity error;
    assert alu_ctrl  = "0101" report "FALHOU: VSLLI alu_ctrl"  severity error;
    assert alu_src   = '1'    report "FALHOU: VSLLI alu_src"   severity error;
    assert vecsize   = "10"   report "FALHOU: VSLLI vecsize"   severity error;
    assert reg_we    = '1'    report "FALHOU: VSLLI reg_we"    severity error;
    assert imm       = x"00000003" report "FALHOU: VSLLI imm" severity error;

    -- VSRL, vecsize="11" (opcode=0001011, funct3=110)
    instr <= x"0718678B"; wait for 10 ns;
    assert is_vector = '1'    report "FALHOU: VSRL is_vector" severity error;
    assert alu_ctrl  = "0110" report "FALHOU: VSRL alu_ctrl"  severity error;
    assert alu_src   = '0'    report "FALHOU: VSRL alu_src"   severity error;
    assert vecsize   = "11"   report "FALHOU: VSRL vecsize"   severity error;
    assert reg_we    = '1'    report "FALHOU: VSRL reg_we"    severity error;

    -- VSRLI, vecsize="00" (opcode=0001011, funct3=111)
    instr <= x"0079F90B"; wait for 10 ns;
    assert is_vector = '1'    report "FALHOU: VSRLI is_vector" severity error;
    assert alu_ctrl  = "0110" report "FALHOU: VSRLI alu_ctrl"  severity error;
    assert alu_src   = '1'    report "FALHOU: VSRLI alu_src"   severity error;
    assert vecsize   = "00"   report "FALHOU: VSRLI vecsize"   severity error;
    assert reg_we    = '1'    report "FALHOU: VSRLI reg_we"    severity error;
    assert imm       = x"00000007" report "FALHOU: VSRLI imm" severity error;

    report "Decoder: todos os testes passaram!" severity note;
    wait;
  end process;

end architecture sim;
