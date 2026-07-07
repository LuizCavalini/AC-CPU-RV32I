library ieee;
use ieee.std_logic_1164.all;

entity vec_shifter_tb is
end entity vec_shifter_tb;

architecture sim of vec_shifter_tb is

  signal a       : std_logic_vector(31 downto 0);
  signal shamt   : std_logic_vector(4 downto 0);
  signal dir     : std_logic;
  signal vecsize : std_logic_vector(1 downto 0);
  signal s       : std_logic_vector(31 downto 0);

  procedure check(expected : std_logic_vector(31 downto 0);
                   actual   : std_logic_vector(31 downto 0);
                   msg      : string) is
  begin
    assert actual = expected
      report "FALHOU: " & msg &
             " esperado=" & to_hstring(expected) &
             " obtido="   & to_hstring(actual)
      severity error;
    if actual = expected then
      report "OK: " & msg;
    end if;
  end procedure;

begin

  uut: entity work.vec_shifter
    port map (
      a_i => a, shamt_i => shamt, dir_i => dir,
      vecsize_i => vecsize, s_o => s
    );

  stim: process
  begin
    -- Caso 1: lanes de 4 bits, shift esquerda por 1, cada nibble = 1000b
    -- bit de topo de cada nibble deve ser descartado, sem vazar pro vizinho
    a <= x"88888888"; shamt <= "00001"; dir <= '0'; vecsize <= "00";
    wait for 10 ns;
    check(x"00000000", s, "4b esquerda sem vazamento");

    -- Caso 2: lanes de 4 bits, shift direita por 1, cada nibble = 0001b
    a <= x"11111111"; shamt <= "00001"; dir <= '1'; vecsize <= "00";
    wait for 10 ns;
    check(x"00000000", s, "4b direita sem vazamento");

    -- Caso 3: lanes de 8 bits, shift esquerda por 1, cada byte = 10000000b
    a <= x"80808080"; shamt <= "00001"; dir <= '0'; vecsize <= "01";
    wait for 10 ns;
    check(x"00000000", s, "8b esquerda sem vazamento");

    -- Caso 4: lanes de 16 bits, shift esquerda por 1, cada halfword = 8000h
    a <= x"80008000"; shamt <= "00001"; dir <= '0'; vecsize <= "10";
    wait for 10 ns;
    check(x"00000000", s, "16b esquerda sem vazamento");

    -- Caso 5: 32 bits (sem lanes), shift esquerda por 4 — cruzar fronteira
    -- de nibble deve ser permitido aqui
    a <= x"00000001"; shamt <= "00100"; dir <= '0'; vecsize <= "11";
    wait for 10 ns;
    check(x"00000010", s, "32b esquerda cruza nibble normalmente");

    -- Caso 6: 32 bits, shift direita por 4
    a <= x"00000010"; shamt <= "00100"; dir <= '1'; vecsize <= "11";
    wait for 10 ns;
    check(x"00000001", s, "32b direita cruza nibble normalmente");

    -- Caso 7: lanes de 4 bits, shift esquerda por 2, valores nao-triviais
    -- cada nibble d vira (d*4) mod 16 dentro da propria lane
    a <= x"01234567"; shamt <= "00010"; dir <= '0'; vecsize <= "00";
    wait for 10 ns;
    check(x"048C048C", s, "4b esquerda por 2, valores reais");

    report "Testes do vec_shifter concluidos";
    wait;
  end process;

end architecture sim;
