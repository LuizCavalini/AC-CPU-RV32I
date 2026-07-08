library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_pipeline_vector_tb is
end entity cpu_pipeline_vector_tb;

architecture sim of cpu_pipeline_vector_tb is

  signal clk  : std_logic := '0';
  signal rst  : std_logic := '1';

  type imem_t is array(0 to 39) of std_logic_vector(31 downto 0);
  -- Programa testa as 8 instrucoes vetoriais (vadd/vaddi indiretamente via
  -- vadd; vauipc/vsub/vsll/vslli/vsrl/vsrli diretamente), varios vecsize
  -- (00/01/11), overflow sem vazamento entre lanes, shift register-register,
  -- e uma dependencia de dados costas-com-costas entre duas instrucoes
  -- vetoriais (vadd -> vsub) para exercitar forwarding EX/MEM->EX sobre um
  -- resultado vetorial.
  signal imem : imem_t := (
    -- 0x00: addi x1,x0,-1        -> x1 = 0xFFFFFFFF
    0  => x"FFF00093",
    -- 0x04: lui  x2,0x11111
    1  => x"11111137",
    -- 0x08: addi x2,x2,0x111     -> x2 = 0x11111111
    2  => x"11110113",
    -- 0x0C: vadd x3,x1,x2,vs=00  -> x3 = 0x00000000 (4b lanes, overflow em todas)
    3  => x"0020818B",
    -- 0x10: sw   x3,0(x0)
    4  => x"00302023",
    -- 0x14: lui  x4,0x05050
    5  => x"05050237",
    -- 0x18: addi x4,x4,0x505     -> x4 = 0x05050505
    6  => x"50520213",
    -- 0x1C: lui  x5,0x03030
    7  => x"030302B7",
    -- 0x20: addi x5,x5,0x303     -> x5 = 0x03030303
    8  => x"30328293",
    -- 0x24: vsub x6,x4,x5,vs=01  -> x6 = 0x02020202 (8b lanes)
    9  => x"0252330B",
    -- 0x28: sw   x6,4(x0)
    10 => x"00602223",
    -- 0x2C: vadd x7,x1,x2,vs=11  -> x7 = 0x11111110 (32b, sem lanes)
    11 => x"0620838B",
    -- 0x30: vsub x8,x7,x2,vs=11  -> x8 = 0xFFFFFFFF (depende de x7 IMEDIATAMENTE
    --       -> testa forwarding de resultado vetorial)
    12 => x"0623B40B",
    -- 0x34: sw   x8,8(x0)
    13 => x"00802423",
    -- 0x38: vslli x9,x2,sh=4,vs=00  -> x9  = 0x00000000 (4b lanes, shift contido na lane)
    14 => x"0041548B",
    -- 0x3C: sw   x9,12(x0)
    15 => x"00902623",
    -- 0x40: vslli x11,x2,sh=4,vs=11 -> x11 = 0x11111110 (32b, sem lanes, contraste)
    16 => x"0641558B",
    -- 0x44: sw   x11,16(x0)
    17 => x"00B02823",
    -- 0x48: addi x13,x0,2        -> x13 = 2 (shamt p/ vsll/vsrl reg-reg)
    18 => x"00200693",
    -- 0x4C: vsll x12,x2,x13,vs=01 -> x12 = 0x44444444 (8b lanes, register-register)
    19 => x"02D1460B",
    -- 0x50: sw   x12,20(x0)
    20 => x"00C02A23",
    -- 0x54: vsrl x14,x2,x13,vs=01 -> x14 = 0x04040404 (8b lanes, register-register)
    21 => x"02D1670B",
    -- 0x58: sw   x14,24(x0)
    22 => x"00E02C23",
    -- 0x5C: vauipc x15,imm=0x001,vs=11 -> x15 = PC(0x5C) + 0x1000 = 0x0000105C
    23 => x"C000A78B",
    -- 0x60: sw   x15,28(x0)
    24 => x"00F02E23",
    -- 0x64: vsrli x16,x2,sh=4,vs=00 -> x16 = 0x00000000 (4b lanes, shift contido)
    25 => x"0041780B",
    -- 0x68: sw   x16,32(x0)
    26 => x"03002023",
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

  imem_data <= imem(to_integer(unsigned(imem_addr(7 downto 2))))
               when to_integer(unsigned(imem_addr(7 downto 2))) < 40
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

    -- Run 60 cycles (generous margin over the 27-instruction count,
    -- no stalls expected: no lw is used, so no load-use hazard; the
    -- only data dependency, word 11->12, is covered by EX/MEM->EX
    -- forwarding, already validated structurally)
    for i in 0 to 59 loop
      wait until rising_edge(clk);
    end loop;

    assert dmem(0) = x"00000000"
      report "FALHOU: dmem[0] vadd 4b lanes (overflow, no leak)" &
             " esperado=" & to_hstring(std_logic_vector'(x"00000000")) &
             " obtido="   & to_hstring(dmem(0))
      severity error;
    if dmem(0) = x"00000000" then
      report "OK: dmem[0] vadd 4b lanes (overflow, no leak)" severity note;
    end if;

    assert dmem(1) = x"02020202"
      report "FALHOU: dmem[1] vsub 8b lanes" &
             " esperado=" & to_hstring(std_logic_vector'(x"02020202")) &
             " obtido="   & to_hstring(dmem(1))
      severity error;
    if dmem(1) = x"02020202" then
      report "OK: dmem[1] vsub 8b lanes" severity note;
    end if;

    assert dmem(2) = x"FFFFFFFF"
      report "FALHOU: dmem[2] vsub 32b, forwarding de resultado vetorial" &
             " esperado=" & to_hstring(std_logic_vector'(x"FFFFFFFF")) &
             " obtido="   & to_hstring(dmem(2))
      severity error;
    if dmem(2) = x"FFFFFFFF" then
      report "OK: dmem[2] vsub 32b, forwarding de resultado vetorial" severity note;
    end if;

    assert dmem(3) = x"00000000"
      report "FALHOU: dmem[3] vslli 4b lanes, contido" &
             " esperado=" & to_hstring(std_logic_vector'(x"00000000")) &
             " obtido="   & to_hstring(dmem(3))
      severity error;
    if dmem(3) = x"00000000" then
      report "OK: dmem[3] vslli 4b lanes, contido" severity note;
    end if;

    assert dmem(4) = x"11111110"
      report "FALHOU: dmem[4] vslli 32b, contraste sem lane" &
             " esperado=" & to_hstring(std_logic_vector'(x"11111110")) &
             " obtido="   & to_hstring(dmem(4))
      severity error;
    if dmem(4) = x"11111110" then
      report "OK: dmem[4] vslli 32b, contraste sem lane" severity note;
    end if;

    assert dmem(5) = x"44444444"
      report "FALHOU: dmem[5] vsll 8b lanes, reg-reg" &
             " esperado=" & to_hstring(std_logic_vector'(x"44444444")) &
             " obtido="   & to_hstring(dmem(5))
      severity error;
    if dmem(5) = x"44444444" then
      report "OK: dmem[5] vsll 8b lanes, reg-reg" severity note;
    end if;

    assert dmem(6) = x"04040404"
      report "FALHOU: dmem[6] vsrl 8b lanes, reg-reg" &
             " esperado=" & to_hstring(std_logic_vector'(x"04040404")) &
             " obtido="   & to_hstring(dmem(6))
      severity error;
    if dmem(6) = x"04040404" then
      report "OK: dmem[6] vsrl 8b lanes, reg-reg" severity note;
    end if;

    assert dmem(7) = x"0000105C"
      report "FALHOU: dmem[7] vauipc" &
             " esperado=" & to_hstring(std_logic_vector'(x"0000105C")) &
             " obtido="   & to_hstring(dmem(7))
      severity error;
    if dmem(7) = x"0000105C" then
      report "OK: dmem[7] vauipc" severity note;
    end if;

    assert dmem(8) = x"00000000"
      report "FALHOU: dmem[8] vsrli 4b lanes, contido" &
             " esperado=" & to_hstring(std_logic_vector'(x"00000000")) &
             " obtido="   & to_hstring(dmem(8))
      severity error;
    if dmem(8) = x"00000000" then
      report "OK: dmem[8] vsrli 4b lanes, contido" severity note;
    end if;

    report "Testes do cpu_pipeline_vector_tb concluidos" severity note;
    wait;
  end process;

end architecture sim;
