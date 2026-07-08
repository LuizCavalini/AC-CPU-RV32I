library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vec_alu_tb is
end entity vec_alu_tb;

architecture sim of vec_alu_tb is

  signal a, b, s   : std_logic_vector(31 downto 0);
  signal alu_ctrl  : std_logic_vector(3 downto 0);
  signal vecsize   : std_logic_vector(1 downto 0);
  signal cout_dbg  : std_logic_vector(7 downto 0);

  procedure check32(expected : std_logic_vector(31 downto 0);
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

  procedure check8(expected : std_logic_vector(7 downto 0);
                    actual   : std_logic_vector(7 downto 0);
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

  uut: entity work.vec_alu
    port map (
      a_i => a, b_i => b, alu_ctrl_i => alu_ctrl,
      vecsize_i => vecsize, s_o => s, cout_debug_o => cout_dbg
    );

  stim: process
  begin
    -- Caso 1: vADD, lanes de 4 bits, overflow em cada nibble (0xF+0x1)
    -- resultado deve ser 0 em cada nibble (carry bloqueado), mas
    -- cout_debug_o deve mostrar carry=1 em todos os 8 blocos
    a <= x"FFFFFFFF"; b <= x"11111111";
    alu_ctrl <= "0000"; vecsize <= "00";
    wait for 10 ns;
    check32(x"00000000", s, "vADD 4b overflow por lane");
    check8("11111111", cout_dbg, "cout_debug_o todos os blocos com carry");

    -- Caso 2: vSUB, 32 bits (sem lanes)
    a <= x"00000005"; b <= x"00000003";
    alu_ctrl <= "0001"; vecsize <= "11";
    wait for 10 ns;
    check32(x"00000002", s, "vSUB 32b simples");

    -- Caso 3: vSLL, lanes de 4 bits, shamt=2 (cross-check com vec_shifter_tb)
    a <= x"01234567"; b <= std_logic_vector(to_unsigned(2, 32));
    alu_ctrl <= "0101"; vecsize <= "00";
    wait for 10 ns;
    check32(x"048C048C", s, "vSLL 4b shamt=2");

    -- Caso 4: vSRL, 32 bits, shamt=4
    a <= x"00000010"; b <= std_logic_vector(to_unsigned(4, 32));
    alu_ctrl <= "0110"; vecsize <= "11";
    wait for 10 ns;
    check32(x"00000001", s, "vSRL 32b shamt=4");

    report "Testes do vec_alu concluidos";
    wait;
  end process;

end architecture sim;
