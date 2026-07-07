-- =============================================================
-- VEC_ADDER: Somador/Subtrator Vetorial de 32 bits
-- 8 blocos CLA4 com controle de carry via vecSize_i
--
-- vecSize_i:
--   "00" = 8 operações de  4 bits
--   "01" = 4 operações de  8 bits
--   "10" = 2 operações de 16 bits
--   "11" = 1 operação  de 32 bits
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;

entity vec_adder is
  port (
    a_i       : in  std_logic_vector(31 downto 0);
    b_i       : in  std_logic_vector(31 downto 0);
    mode_i    : in  std_logic;
    vecsize_i : in  std_logic_vector(1 downto 0);
    s_o       : out std_logic_vector(31 downto 0);
    cout_debug_o : out std_logic_vector(7 downto 0)
  );
end entity vec_adder;

architecture rtl of vec_adder is

  -- carry_out de cada bloco (8 blocos)
  signal cout : std_logic_vector(7 downto 0);

  -- carry_in de cada bloco — gate entre blocos
  -- cin(0) é sempre 0 para adição, ou controlado por mode_i
  -- cin(1..7) dependem do cout anterior e da máscara
  signal cin  : std_logic_vector(7 downto 0);

  -- máscara de 7 bits: define quais carries entre blocos são permitidos
  -- mask(i) controla se cout(i) chega em cin(i+1)
  signal mask : std_logic_vector(6 downto 0);

begin

  -- ── Máscara de carry conforme vecSize_i ──────────────────────
  -- Derivada diretamente da tabela:
  -- gate1 (cout0->cin1): passa se vecSize >= "01"  → mask(0) = vecsize(0) or vecsize(1)
  -- gate2 (cout1->cin2): passa se vecSize >= "10"  → mask(1) = vecsize(1)
  -- gate3 (cout2->cin3): passa se vecSize >= "01"  → mask(2) = vecsize(0) or vecsize(1)
  -- gate4 (cout3->cin4): passa só se vecSize = "11" → mask(3) = vecsize(0) and vecsize(1)
  -- gate5 (cout4->cin5): passa se vecSize >= "01"  → mask(4) = vecsize(0) or vecsize(1)
  -- gate6 (cout5->cin6): passa se vecSize >= "10"  → mask(5) = vecsize(1)
  -- gate7 (cout6->cin7): passa se vecSize >= "01"  → mask(6) = vecsize(0) or vecsize(1)
  mask(0) <= vecsize_i(0) or  vecsize_i(1);
  mask(1) <= vecsize_i(1);
  mask(2) <= vecsize_i(0) or  vecsize_i(1);
  mask(3) <= vecsize_i(0) and vecsize_i(1);
  mask(4) <= vecsize_i(0) or  vecsize_i(1);
  mask(5) <= vecsize_i(1);
  mask(6) <= vecsize_i(0) or  vecsize_i(1);

  cout_debug_o <= cout;

  -- ── Carries de entrada de cada bloco ─────────────────────────
  -- Bloco 0: cin vem de fora (sempre 0 pois não há cin externo)
  cin(0) <= '0';

  -- Blocos 1..7: carry do bloco anterior, bloqueado pela máscara
  cin(1) <= cout(0) and mask(0);
  cin(2) <= cout(1) and mask(1);
  cin(3) <= cout(2) and mask(2);
  cin(4) <= cout(3) and mask(3);
  cin(5) <= cout(4) and mask(4);
  cin(6) <= cout(5) and mask(5);
  cin(7) <= cout(6) and mask(6);

  -- ── 8 instâncias do CLA4 ─────────────────────────────────────
  blk0: entity work.cla4
    port map (
      a_i    => a_i( 3 downto  0),
      b_i    => b_i( 3 downto  0),
      cin_i  => cin(0),
      sub_i  => mode_i,
      s_o    => s_o( 3 downto  0),
      cout_o => cout(0),
      g_o    => open,
      p_o    => open
    );

  blk1: entity work.cla4
    port map (
      a_i    => a_i( 7 downto  4),
      b_i    => b_i( 7 downto  4),
      cin_i  => cin(1),
      sub_i  => mode_i,
      s_o    => s_o( 7 downto  4),
      cout_o => cout(1),
      g_o    => open,
      p_o    => open
    );

  blk2: entity work.cla4
    port map (
      a_i    => a_i(11 downto  8),
      b_i    => b_i(11 downto  8),
      cin_i  => cin(2),
      sub_i  => mode_i,
      s_o    => s_o(11 downto  8),
      cout_o => cout(2),
      g_o    => open,
      p_o    => open
    );

  blk3: entity work.cla4
    port map (
      a_i    => a_i(15 downto 12),
      b_i    => b_i(15 downto 12),
      cin_i  => cin(3),
      sub_i  => mode_i,
      s_o    => s_o(15 downto 12),
      cout_o => cout(3),
      g_o    => open,
      p_o    => open
    );

  blk4: entity work.cla4
    port map (
      a_i    => a_i(19 downto 16),
      b_i    => b_i(19 downto 16),
      cin_i  => cin(4),
      sub_i  => mode_i,
      s_o    => s_o(19 downto 16),
      cout_o => cout(4),
      g_o    => open,
      p_o    => open
    );

  blk5: entity work.cla4
    port map (
      a_i    => a_i(23 downto 20),
      b_i    => b_i(23 downto 20),
      cin_i  => cin(5),
      sub_i  => mode_i,
      s_o    => s_o(23 downto 20),
      cout_o => cout(5),
      g_o    => open,
      p_o    => open
    );

  blk6: entity work.cla4
    port map (
      a_i    => a_i(27 downto 24),
      b_i    => b_i(27 downto 24),
      cin_i  => cin(6),
      sub_i  => mode_i,
      s_o    => s_o(27 downto 24),
      cout_o => cout(6),
      g_o    => open,
      p_o    => open
    );

  blk7: entity work.cla4
    port map (
      a_i    => a_i(31 downto 28),
      b_i    => b_i(31 downto 28),
      cin_i  => cin(7),
      sub_i  => mode_i,
      s_o    => s_o(31 downto 28),
      cout_o => cout(7),
      g_o    => open,
      p_o    => open
    );

end architecture rtl;
