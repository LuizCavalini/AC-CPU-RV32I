-- =============================================================
-- Testbench do somador vetorial de 32 bits
-- Testa os 4 modos: 4, 8, 16 e 32 bits
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vec_adder_tb is
end entity vec_adder_tb;

architecture sim of vec_adder_tb is

  signal a, b : std_logic_vector(31 downto 0);
  signal mode : std_logic;
  signal vsize: std_logic_vector(1 downto 0);
  signal s    : std_logic_vector(31 downto 0);

  -- converte inteiro para std_logic_vector de 32 bits
  function slv(x : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(x, 32));
  end function;

begin

  uut: entity work.vec_adder
    port map (a_i=>a, b_i=>b, mode_i=>mode, vecsize_i=>vsize, s_o=>s);

  process
  begin
    -- ── vecSize = "00": 8 somas de 4 bits ───────────────────────
    -- Cada nibble some independentemente
    -- A = 0x12345678, B = 0x11111111
    -- Nibble por nibble: 8+1=9, 7+1=8, 6+1=7, 5+1=6, 4+1=5, 3+1=4, 2+1=3, 1+1=2
    -- Resultado esperado: 0x23456789
    mode  <= '0'; vsize <= "00";
    a <= x"12345678"; b <= x"11111111"; wait for 10 ns;
    assert s = x"23456789"
      report "FALHOU [4b ADD]: 0x12345678 + 0x11111111" severity error;

    -- Overflow dentro de nibble não vaza: F+1 = 0 (carry contido)
    -- A = 0xFFFFFFFF, B = 0x11111111
    -- Cada nibble: F+1=10 → resultado=0, carry bloqueado
    -- Resultado esperado: 0x00000000
    a <= x"FFFFFFFF"; b <= x"11111111"; wait for 10 ns;
    assert s = x"00000000"
      report "FALHOU [4b CARRY BLOCK]: 0xFFFFFFFF + 0x11111111" severity error;

    -- ── vecSize = "01": 4 somas de 8 bits ───────────────────────
    mode  <= '0'; vsize <= "01";
    -- A = 0x0A0B0C0D, B = 0x01020304
    -- Byte por byte: 0D+04=11, 0C+03=0F, 0B+02=0D, 0A+01=0B
    -- Resultado esperado: 0x0B0D0F11
    a <= x"0A0B0C0D"; b <= x"01020304"; wait for 10 ns;
    assert s = x"0B0D0F11"
      report "FALHOU [8b ADD]: 0x0A0B0C0D + 0x01020304" severity error;

    -- Overflow de byte não vaza: FF+01 = 00, carry bloqueado
    a <= x"FF0000FF"; b <= x"01000001"; wait for 10 ns;
    assert s = x"00000000"
      report "FALHOU [8b CARRY BLOCK]: 0xFF0000FF + 0x01000001" severity error;

    -- ── vecSize = "10": 2 somas de 16 bits ──────────────────────
    mode  <= '0'; vsize <= "10";
    -- A = 0x00010002, B = 0x00030004
    -- Half por half: 0002+0004=0006, 0001+0003=0004
    -- Resultado esperado: 0x00040006
    a <= x"00010002"; b <= x"00030004"; wait for 10 ns;
    assert s = x"00040006"
      report "FALHOU [16b ADD]: 0x00010002 + 0x00030004" severity error;

    -- Overflow de 16 bits não vaza: FFFF+0001 = 0000, carry bloqueado
    a <= x"FFFF0000"; b <= x"00010000"; wait for 10 ns;
    assert s = x"00000000"
      report "FALHOU [16b CARRY BLOCK]: 0xFFFF0000 + 0x00010000" severity error;

    -- ── vecSize = "11": 1 soma de 32 bits ───────────────────────
    mode  <= '0'; vsize <= "11";
    -- Carry deve se propagar normalmente entre todos os blocos
    a <= x"FFFF0001"; b <= x"0000FFFF"; wait for 10 ns;
    assert s = x"00000000"
      report "FALHOU [32b ADD overflow]: 0xFFFF0001 + 0x0000FFFF" severity error;

    a <= x"00000001"; b <= x"00000001"; wait for 10 ns;
    assert s = x"00000002"
      report "FALHOU [32b ADD simple]: 1 + 1 = 2" severity error;

    -- ── Subtração em modo 32 bits ───────────────────────────────
    mode  <= '1'; vsize <= "11";
    a <= x"00000005"; b <= x"00000003"; wait for 10 ns;
    assert s = x"00000002"
      report "FALHOU [32b SUB]: 5 - 3 = 2" severity error;

    a <= x"00000010"; b <= x"00000010"; wait for 10 ns;
    assert s = x"00000000"
      report "FALHOU [32b SUB zero]: 16 - 16 = 0" severity error;

    -- ── Subtração em modo 8 bits ────────────────────────────────
    mode  <= '1'; vsize <= "01";
    -- Subtrai byte a byte: 0A-05=05, 0F-0F=00, 20-10=10, FF-01=FE
    a <= x"FF200F0A"; b <= x"01100F05"; wait for 10 ns;
    assert s = x"FE100005"
      report "FALHOU [8b SUB]: byte-wise subtraction" severity error;

    report "Todos os testes passaram!" severity note;
    wait;
  end process;

end architecture sim;
