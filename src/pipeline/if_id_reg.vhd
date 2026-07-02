library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Pipeline register: IF/ID
-- Holds instruction and PC between Fetch and Decode stages
entity if_id_reg is
  port (
    clk_i    : in  std_logic;
    rst_i    : in  std_logic;
    flush_i  : in  std_logic;   -- control hazard: discard instruction
    stall_i  : in  std_logic;   -- data hazard: hold current values
    pc_i     : in  std_logic_vector(31 downto 0);
    instr_i  : in  std_logic_vector(31 downto 0);
    pc_o     : out std_logic_vector(31 downto 0);
    instr_o  : out std_logic_vector(31 downto 0)
  );
end entity if_id_reg;

architecture rtl of if_id_reg is
begin
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' or flush_i = '1' then
        pc_o    <= (others => '0');
        instr_o <= (others => '0');  -- NOP
      elsif stall_i = '0' then
        pc_o    <= pc_i;
        instr_o <= instr_i;
      end if;
      -- stall: hold values (do nothing)
    end if;
  end process;
end architecture rtl;
