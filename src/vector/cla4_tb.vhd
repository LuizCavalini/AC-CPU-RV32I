library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cla4_tb is
end entity cla4_tb;

architecture sim of cla4_tb is
  signal a, b : std_logic_vector(3 downto 0);
  signal cin  : std_logic;
  signal sub  : std_logic;
  signal s    : std_logic_vector(3 downto 0);
  signal cout : std_logic;
  signal g, p : std_logic;
begin
  uut: entity work.cla4
    port map (a_i=>a, b_i=>b, cin_i=>cin, sub_i=>sub,
              s_o=>s, cout_o=>cout, g_o=>g, p_o=>p);
  process
  begin
    sub <= '0'; cin <= '0';
    a <= "0011"; b <= "0100"; wait for 10 ns;
    assert s = "0111" and cout = '0' report "FALHOU: 3+4" severity error;
    a <= "0111"; b <= "0001"; wait for 10 ns;
    assert s = "1000" and cout = '0' report "FALHOU: 7+1" severity error;
    a <= "1111"; b <= "0001"; wait for 10 ns;
    assert s = "0000" and cout = '1' report "FALHOU: 15+1" severity error;
    sub <= '1'; cin <= '0';
    a <= "0111"; b <= "0011"; wait for 10 ns;
    assert s = "0100" report "FALHOU: 7-3" severity error;
    a <= "0101"; b <= "0101"; wait for 10 ns;
    assert s = "0000" report "FALHOU: 5-5" severity error;
    report "Todos os testes passaram!" severity note;
    wait;
  end process;
end architecture sim;
