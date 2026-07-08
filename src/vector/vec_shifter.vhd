library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vec_shifter is
  port (
    a_i       : in  std_logic_vector(31 downto 0);
    shamt_i   : in  std_logic_vector(4 downto 0);
    dir_i     : in  std_logic;
    vecsize_i : in  std_logic_vector(1 downto 0);
    s_o       : out std_logic_vector(31 downto 0)
  );
end entity vec_shifter;

architecture rtl of vec_shifter is
begin

  process(a_i, shamt_i, dir_i, vecsize_i)
    variable lane_width : integer;
    variable lane_start : integer;
    variable lane_end   : integer;
    variable shamt      : integer;
    variable src        : integer;
  begin
    -- largura da lane, mesma convenção do vec_adder:
    -- 00=4 bits, 01=8 bits, 10=16 bits, 11=32 bits
    case vecsize_i is
      when "00"   => lane_width := 4;
      when "01"   => lane_width := 8;
      when "10"   => lane_width := 16;
      when others => lane_width := 32;
    end case;

    shamt := to_integer(unsigned(shamt_i));

    for i in 0 to 31 loop
      lane_start := (i / lane_width) * lane_width;
      lane_end   := lane_start + lane_width - 1;

      if dir_i = '0' then
        -- deslocamento a esquerda (sll): bit sai da lane por cima,
        -- entra 0 por baixo dentro da mesma lane
        src := i - shamt;
        if src >= lane_start then
          s_o(i) <= a_i(src);
        else
          s_o(i) <= '0';
        end if;
      else
        -- deslocamento a direita (srl): bit sai da lane por baixo,
        -- entra 0 por cima dentro da mesma lane
        src := i + shamt;
        if src <= lane_end then
          s_o(i) <= a_i(src);
        else
          s_o(i) <= '0';
        end if;
      end if;
    end loop;
  end process;

end architecture rtl;
