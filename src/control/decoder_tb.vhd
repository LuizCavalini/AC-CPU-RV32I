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
begin

  uut: entity work.decoder
    port map(instr_i=>instr, reg_we_o=>reg_we, alu_src_o=>alu_src,
             alu_ctrl_o=>alu_ctrl, mem_we_o=>mem_we, mem_re_o=>mem_re,
             wb_sel_o=>wb_sel, branch_o=>branch, jump_o=>jump,
             jalr_o=>jalr, imm_o=>imm);

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

    report "Decoder: todos os testes passaram!" severity note;
    wait;
  end process;

end architecture sim;
