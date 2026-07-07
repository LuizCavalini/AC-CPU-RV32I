library ieee;
use ieee.std_logic_1164.all;

entity vec_alu is
  port (
    a_i          : in  std_logic_vector(31 downto 0);
    b_i          : in  std_logic_vector(31 downto 0);
    alu_ctrl_i   : in  std_logic_vector(3 downto 0);
    vecsize_i    : in  std_logic_vector(1 downto 0);
    s_o          : out std_logic_vector(31 downto 0);
    cout_debug_o : out std_logic_vector(7 downto 0)
  );
end entity vec_alu;

architecture rtl of vec_alu is
  signal add_result   : std_logic_vector(31 downto 0);
  signal shift_result  : std_logic_vector(31 downto 0);
  signal adder_mode   : std_logic;
  signal shifter_dir  : std_logic;
  signal use_shift    : std_logic;
begin

  -- Decodifica alu_ctrl_i (mesma convencao da ALU escalar, Tabela 2 do
  -- relatorio da Parte 1), restrito as 4 operacoes vetorizadas:
  -- 0000=vADD  0001=vSUB  0101=vSLL  0110=vSRL
  process(alu_ctrl_i)
  begin
    case alu_ctrl_i is
      when "0000" => adder_mode <= '0'; shifter_dir <= '0'; use_shift <= '0';
      when "0001" => adder_mode <= '1'; shifter_dir <= '0'; use_shift <= '0';
      when "0101" => adder_mode <= '0'; shifter_dir <= '0'; use_shift <= '1';
      when "0110" => adder_mode <= '0'; shifter_dir <= '1'; use_shift <= '1';
      when others => adder_mode <= '0'; shifter_dir <= '0'; use_shift <= '0';
    end case;
  end process;

  adder: entity work.vec_adder
    port map (
      a_i => a_i, b_i => b_i, mode_i => adder_mode,
      vecsize_i => vecsize_i, s_o => add_result,
      cout_debug_o => cout_debug_o
    );

  shifter: entity work.vec_shifter
    port map (
      a_i => a_i, shamt_i => b_i(4 downto 0), dir_i => shifter_dir,
      vecsize_i => vecsize_i, s_o => shift_result
    );

  s_o <= shift_result when use_shift = '1' else add_result;

end architecture rtl;
