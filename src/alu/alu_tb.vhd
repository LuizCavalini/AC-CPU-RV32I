library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_tb is
end entity alu_tb;

architecture sim of alu_tb is
  signal a, b, result : std_logic_vector(31 downto 0);
  signal ctrl         : std_logic_vector(3 downto 0);
  signal zero         : std_logic;
begin

  uut: entity work.alu
    port map(a_i=>a, b_i=>b, alu_ctrl_i=>ctrl, result_o=>result, zero_o=>zero);

  process
  begin
    -- ADD: 10 + 5 = 15
    a <= x"0000000A"; b <= x"00000005"; ctrl <= "0000"; wait for 10 ns;
    assert result = x"0000000F" report "FALHOU: ADD 10+5" severity error;
    assert zero = '0'           report "FALHOU: ADD zero flag" severity error;

    -- SUB: 10 - 10 = 0 (zero flag)
    a <= x"0000000A"; b <= x"0000000A"; ctrl <= "0001"; wait for 10 ns;
    assert result = x"00000000" report "FALHOU: SUB 10-10" severity error;
    assert zero = '1'           report "FALHOU: SUB zero flag" severity error;

    -- AND: 0xF0 AND 0xFF = 0xF0
    a <= x"000000F0"; b <= x"000000FF"; ctrl <= "0010"; wait for 10 ns;
    assert result = x"000000F0" report "FALHOU: AND" severity error;

    -- OR: 0xF0 OR 0x0F = 0xFF
    a <= x"000000F0"; b <= x"0000000F"; ctrl <= "0011"; wait for 10 ns;
    assert result = x"000000FF" report "FALHOU: OR" severity error;

    -- XOR: 0xFF XOR 0xFF = 0x00
    a <= x"000000FF"; b <= x"000000FF"; ctrl <= "0100"; wait for 10 ns;
    assert result = x"00000000" report "FALHOU: XOR" severity error;
    assert zero = '1'           report "FALHOU: XOR zero flag" severity error;

    -- SLL: 1 << 4 = 16
    a <= x"00000001"; b <= x"00000004"; ctrl <= "0101"; wait for 10 ns;
    assert result = x"00000010" report "FALHOU: SLL 1<<4" severity error;

    -- SRL: 16 >> 2 = 4
    a <= x"00000010"; b <= x"00000002"; ctrl <= "0110"; wait for 10 ns;
    assert result = x"00000004" report "FALHOU: SRL 16>>2" severity error;

    -- LUI: passa B direto
    a <= x"00000000"; b <= x"DEADBEEF"; ctrl <= "0111"; wait for 10 ns;
    assert result = x"DEADBEEF" report "FALHOU: LUI" severity error;

    -- SLT: 3 < 5 = 1
    a <= x"00000003"; b <= x"00000005"; ctrl <= "1000"; wait for 10 ns;
    assert result = x"00000001" report "FALHOU: SLT 3<5" severity error;

    -- SLT: 5 < 3 = 0
    a <= x"00000005"; b <= x"00000003"; ctrl <= "1000"; wait for 10 ns;
    assert result = x"00000000" report "FALHOU: SLT 5<3" severity error;

    -- ADD overflow negativo: -1 + 1 = 0
    a <= x"FFFFFFFF"; b <= x"00000001"; ctrl <= "0000"; wait for 10 ns;
    assert result = x"00000000" report "FALHOU: ADD overflow" severity error;
    assert zero = '1'           report "FALHOU: ADD overflow zero" severity error;

    report "ALU: todos os testes passaram!" severity note;
    wait;
  end process;

end architecture sim;
