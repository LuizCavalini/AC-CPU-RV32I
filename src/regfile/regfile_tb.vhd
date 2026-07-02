library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity regfile_tb is
end entity regfile_tb;

architecture sim of regfile_tb is
  signal clk  : std_logic := '0';
  signal we   : std_logic := '0';
  signal rs1  : std_logic_vector(4 downto 0) := (others => '0');
  signal rs2  : std_logic_vector(4 downto 0) := (others => '0');
  signal rd   : std_logic_vector(4 downto 0) := (others => '0');
  signal wd   : std_logic_vector(31 downto 0) := (others => '0');
  signal rd1  : std_logic_vector(31 downto 0);
  signal rd2  : std_logic_vector(31 downto 0);

  constant CLK_PERIOD : time := 10 ns;
begin

  uut: entity work.regfile
    port map(clk_i=>clk, we_i=>we, rs1_i=>rs1, rs2_i=>rs2,
             rd_i=>rd, wd_i=>wd, rd1_o=>rd1, rd2_o=>rd2);

  clk <= not clk after CLK_PERIOD/2;

  process
  begin
    -- Test 1: x0 is always zero, even after write attempt
    we <= '1'; rd <= "00000"; wd <= x"DEADBEEF";
    wait until rising_edge(clk); wait for 1 ns;
    rs1 <= "00000";
    wait for 1 ns;
    assert rd1 = x"00000000" report "FALHOU: x0 nao e zero" severity error;

    -- Test 2: write x1 = 0xABCD1234, read back
    we <= '1'; rd <= "00001"; wd <= x"ABCD1234";
    wait until rising_edge(clk); wait for 1 ns;
    rs1 <= "00001";
    wait for 1 ns;
    assert rd1 = x"ABCD1234" report "FALHOU: escrita/leitura x1" severity error;

    -- Test 3: write x2 = 0x00000005, read both x1 and x2 simultaneously
    we <= '1'; rd <= "00010"; wd <= x"00000005";
    wait until rising_edge(clk); wait for 1 ns;
    rs1 <= "00001"; rs2 <= "00010";
    wait for 1 ns;
    assert rd1 = x"ABCD1234" report "FALHOU: leitura x1 simultanea" severity error;
    assert rd2 = x"00000005" report "FALHOU: leitura x2 simultanea" severity error;

    -- Test 4: write disabled (we=0), value must not change
    we <= '0'; rd <= "00001"; wd <= x"FFFFFFFF";
    wait until rising_edge(clk); wait for 1 ns;
    rs1 <= "00001";
    wait for 1 ns;
    assert rd1 = x"ABCD1234" report "FALHOU: write disabled alterou valor" severity error;

    -- Test 5: write x31 (last register)
    we <= '1'; rd <= "11111"; wd <= x"CAFEBABE";
    wait until rising_edge(clk); wait for 1 ns;
    rs1 <= "11111";
    wait for 1 ns;
    assert rd1 = x"CAFEBABE" report "FALHOU: escrita/leitura x31" severity error;

    report "Regfile: todos os testes passaram!" severity note;
    wait;
  end process;

end architecture sim;
