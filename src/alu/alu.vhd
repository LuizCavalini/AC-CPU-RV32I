library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
  port (
    a_i       : in  std_logic_vector(31 downto 0);
    b_i       : in  std_logic_vector(31 downto 0);
    alu_ctrl_i: in  std_logic_vector(3  downto 0);
    result_o  : out std_logic_vector(31 downto 0);
    zero_o    : out std_logic
  );
end entity alu;

architecture rtl of alu is
  signal result_s : std_logic_vector(31 downto 0);
begin

  process(a_i, b_i, alu_ctrl_i)
    variable a_s   : signed(31 downto 0);
    variable b_s   : signed(31 downto 0);
    variable a_u   : unsigned(31 downto 0);
    variable b_u   : unsigned(31 downto 0);
    variable shamt : integer range 0 to 31;
  begin
    a_s   := signed(a_i);
    b_s   := signed(b_i);
    a_u   := unsigned(a_i);
    b_u   := unsigned(b_i);
    shamt := to_integer(unsigned(b_i(4 downto 0)));

    case alu_ctrl_i is
      when "0000" => result_s <= std_logic_vector(a_s + b_s);          -- ADD
      when "0001" => result_s <= std_logic_vector(a_s - b_s);          -- SUB
      when "0010" => result_s <= a_i and b_i;                          -- AND
      when "0011" => result_s <= a_i or  b_i;                          -- OR
      when "0100" => result_s <= a_i xor b_i;                          -- XOR
      when "0101" => result_s <= std_logic_vector(shift_left (a_u, shamt)); -- SLL
      when "0110" => result_s <= std_logic_vector(shift_right(a_u, shamt)); -- SRL
      when "0111" => result_s <= b_i;                                   -- LUI (passa B)
      when "1000" =>                                                     -- SLT
        if a_s < b_s then
          result_s <= (0 => '1', others => '0');
        else
          result_s <= (others => '0');
        end if;
      when others => result_s <= (others => '0');
    end case;
  end process;

  result_o <= result_s;
  zero_o   <= '1' when result_s = x"00000000" else '0';

end architecture rtl;
