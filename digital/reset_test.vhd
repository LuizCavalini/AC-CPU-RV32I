library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity reset_tb is
end entity reset_tb;
architecture sim of reset_tb is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal ia  : std_logic_vector(31 downto 0);
  signal id  : std_logic_vector(31 downto 0) := x"00000013";
  signal da, dw, dr : std_logic_vector(31 downto 0) := (others=>'0');
  signal we, re : std_logic;
begin
  clk <= not clk after 5 ns;
  dut: entity work.cpu_pipeline
    port map(clk_i=>clk,rst_i=>rst,imem_addr_o=>ia,imem_data_i=>id,
             dmem_addr_o=>da,dmem_wdata_o=>dw,dmem_rdata_i=>dr,
             dmem_we_o=>we,dmem_re_o=>re);
  process
  begin
    wait for 30 ns; rst <= '0';
    wait for 50 ns;
    report "PC=0x" & to_hstring(ia) severity note;
    rst <= '1'; wait for 20 ns; rst <= '0';
    wait for 10 ns;
    report "PC apos reset=0x" & to_hstring(ia) severity note;
    wait;
  end process;
end architecture sim;
