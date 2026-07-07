library ieee;
use ieee.std_logic_1164.all;

entity cla4 is
  port (
    a_i    : in  std_logic_vector(3 downto 0);
    b_i    : in  std_logic_vector(3 downto 0);
    cin_i  : in  std_logic;
    sub_i  : in  std_logic;
    s_o    : out std_logic_vector(3 downto 0);
    cout_o : out std_logic;
    g_o    : out std_logic;
    p_o    : out std_logic
  );
end entity cla4;

architecture rtl of cla4 is
  signal b_eff : std_logic_vector(3 downto 0);
  signal g : std_logic_vector(3 downto 0);
  signal p : std_logic_vector(3 downto 0);
  signal c : std_logic_vector(4 downto 0);
begin
  b_eff <= b_i xor (sub_i & sub_i & sub_i & sub_i);
  c(0) <= cin_i or sub_i;
  g(0) <= a_i(0) and b_eff(0);
  g(1) <= a_i(1) and b_eff(1);
  g(2) <= a_i(2) and b_eff(2);
  g(3) <= a_i(3) and b_eff(3);
  p(0) <= a_i(0) xor b_eff(0);
  p(1) <= a_i(1) xor b_eff(1);
  p(2) <= a_i(2) xor b_eff(2);
  p(3) <= a_i(3) xor b_eff(3);
  c(1) <= g(0) or (p(0) and c(0));
  c(2) <= g(1) or (p(1) and g(0)) or (p(1) and p(0) and c(0));
  c(3) <= g(2) or (p(2) and g(1)) or (p(2) and p(1) and g(0)) or (p(2) and p(1) and p(0) and c(0));
  c(4) <= g(3) or (p(3) and g(2)) or (p(3) and p(2) and g(1)) or (p(3) and p(2) and p(1) and g(0)) or (p(3) and p(2) and p(1) and p(0) and c(0));
  s_o(0) <= p(0) xor c(0);
  s_o(1) <= p(1) xor c(1);
  s_o(2) <= p(2) xor c(2);
  s_o(3) <= p(3) xor c(3);
  cout_o <= c(4);
  g_o <= g(3) or (p(3) and g(2)) or (p(3) and p(2) and g(1)) or (p(3) and p(2) and p(1) and g(0));
  p_o <= p(3) and p(2) and p(1) and p(0);
end architecture rtl;
