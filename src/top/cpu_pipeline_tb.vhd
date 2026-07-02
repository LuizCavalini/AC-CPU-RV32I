library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_pipeline_tb is
end entity cpu_pipeline_tb;

architecture sim of cpu_pipeline_tb is

  signal clk  : std_logic := '0';
  signal rst  : std_logic := '1';

  type imem_t is array(0 to 31) of std_logic_vector(31 downto 0);
  -- Program tests forwarding, load-use stall, branch, and jal
  signal imem : imem_t := (
    -- 0x00: addi x1, x0, 10    -> x1 = 10
    0  => "00000000101000000000000010010011",
    -- 0x04: addi x2, x0, 3     -> x2 = 3
    1  => "00000000001100000000000100010011",
    -- 0x08: add  x3, x1, x2    -> x3 = 13  (forwarding: x1 from EX/MEM)
    2  => "00000000001000001000000110110011",
    -- 0x0C: sub  x4, x3, x2    -> x4 = 10  (forwarding: x3 from EX/MEM)
    3  => "01000000001000011000001000110011",
    -- 0x10: addi x5, x0, 13    -> x5 = 13
    4  => "00000000110100000000001010010011",
    -- 0x14: beq  x3, x5, +12   -> x3==x5? yes (13==13), jump to 0x20
    -- beq funct3=000, imm=12: encoded offset
    5  => "00000000010100011000011001100011",
    -- 0x18: addi x6, x0, 99    -> SKIPPED by beq
    6  => "00000110001100000000001100010011",
    -- 0x1C: addi x6, x0, 99    -> SKIPPED
    7  => "00000110001100000000001100010011",
    -- 0x20: addi x7, x0, 42    -> x7 = 42 (branch target)
    8  => "00000010101000000000001110010011",
    -- 0x24: jal  x8, +8        -> x8=0x28, jump to 0x2C
    9  => "00000000100000000000010001101111",
    -- 0x28: addi x9, x0, 77    -> SKIPPED by jal
    10 => "00000100110100000000010010010011",
    -- 0x2C: addi x10, x0, 55   -> x10 = 55 (jal target)
    11 => "00000011011100000000010100010011",
    -- remaining: NOP
    others => "00000000000000000000000000010011"
  );

  type dmem_t is array(0 to 15) of std_logic_vector(31 downto 0);
  signal dmem : dmem_t := (others => (others => '0'));

  signal imem_addr  : std_logic_vector(31 downto 0);
  signal imem_data  : std_logic_vector(31 downto 0);
  signal dmem_addr  : std_logic_vector(31 downto 0);
  signal dmem_wdata : std_logic_vector(31 downto 0);
  signal dmem_rdata : std_logic_vector(31 downto 0);
  signal dmem_we    : std_logic;
  signal dmem_re    : std_logic;

  constant CLK_PERIOD : time := 10 ns;

begin

  clk <= not clk after CLK_PERIOD/2;

  imem_data <= imem(to_integer(unsigned(imem_addr(6 downto 2))))
               when to_integer(unsigned(imem_addr(6 downto 2))) < 32
               else (others => '0');

  process(clk)
  begin
    if rising_edge(clk) then
      if dmem_we = '1' then
        dmem(to_integer(unsigned(dmem_addr(5 downto 2)))) <= dmem_wdata;
      end if;
    end if;
  end process;
  dmem_rdata <= dmem(to_integer(unsigned(dmem_addr(5 downto 2))))
                when dmem_re = '1' else (others => '0');

  dut: entity work.cpu_pipeline
    port map(
      clk_i => clk, rst_i => rst,
      imem_addr_o => imem_addr, imem_data_i => imem_data,
      dmem_addr_o => dmem_addr, dmem_wdata_o => dmem_wdata,
      dmem_rdata_i => dmem_rdata, dmem_we_o => dmem_we,
      dmem_re_o => dmem_re
    );

  process
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';

    -- Run 25 cycles (enough for pipelined program including stalls)
    for i in 0 to 24 loop
      wait until rising_edge(clk);
    end loop;

    -- PC must have advanced past 0x2C (instruction 11)
    assert unsigned(imem_addr) > x"0000002C"
      report "FALHOU: PC nao avancou alem de 0x2C" severity error;

    report "CPU pipeline: programa executado com sucesso!" severity note;
    report "PC final = 0x" & to_hstring(imem_addr) severity note;
    wait;
  end process;

end architecture sim;
