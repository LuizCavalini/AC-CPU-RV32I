library ieee;
use ieee.std_logic_1164.all;

-- Forwarding Unit
-- Resolves data hazards by forwarding results from EX/MEM and MEM/WB stages
-- to the ALU inputs in the EX stage
--
-- forward_a/b encoding:
--   "00" = use register file output (no hazard)
--   "01" = forward from MEM/WB (wb_data)
--   "10" = forward from EX/MEM (alu_result)
entity forwarding_unit is
  port (
    -- From ID/EX (current EX stage instruction)
    rs1_ex_i    : in  std_logic_vector(4 downto 0);
    rs2_ex_i    : in  std_logic_vector(4 downto 0);
    -- From EX/MEM register
    rd_mem_i    : in  std_logic_vector(4 downto 0);
    reg_we_mem_i: in  std_logic;
    -- From MEM/WB register
    rd_wb_i     : in  std_logic_vector(4 downto 0);
    reg_we_wb_i : in  std_logic;
    -- Forwarding select signals
    forward_a_o : out std_logic_vector(1 downto 0);
    forward_b_o : out std_logic_vector(1 downto 0)
  );
end entity forwarding_unit;

architecture rtl of forwarding_unit is
begin

  -- Forwarding for ALU operand A (rs1)
  process(rs1_ex_i, rd_mem_i, reg_we_mem_i, rd_wb_i, reg_we_wb_i)
  begin
    if reg_we_mem_i = '1' and rd_mem_i /= "00000" and rd_mem_i = rs1_ex_i then
      forward_a_o <= "10";   -- EX/MEM forward (most recent, takes priority)
    elsif reg_we_wb_i = '1' and rd_wb_i /= "00000" and rd_wb_i = rs1_ex_i then
      forward_a_o <= "01";   -- MEM/WB forward
    else
      forward_a_o <= "00";   -- no forwarding
    end if;
  end process;

  -- Forwarding for ALU operand B (rs2)
  process(rs2_ex_i, rd_mem_i, reg_we_mem_i, rd_wb_i, reg_we_wb_i)
  begin
    if reg_we_mem_i = '1' and rd_mem_i /= "00000" and rd_mem_i = rs2_ex_i then
      forward_b_o <= "10";
    elsif reg_we_wb_i = '1' and rd_wb_i /= "00000" and rd_wb_i = rs2_ex_i then
      forward_b_o <= "01";
    else
      forward_b_o <= "00";
    end if;
  end process;

end architecture rtl;
