library ieee;
use ieee.std_logic_1164.all;

-- Hazard Detection Unit
-- Detects load-use hazard: LW followed immediately by instruction that uses the loaded value
-- Solution: stall pipeline for 1 cycle (hold PC and IF/ID, insert NOP into ID/EX)
entity hazard_unit is
  port (
    -- From ID/EX register
    mem_re_ex_i  : in  std_logic;
    rd_ex_i      : in  std_logic_vector(4 downto 0);
    -- From IF/ID register (current instruction being decoded)
    rs1_id_i     : in  std_logic_vector(4 downto 0);
    rs2_id_i     : in  std_logic_vector(4 downto 0);
    -- Stall outputs
    stall_pc_o   : out std_logic;   -- hold PC
    stall_ifid_o : out std_logic;   -- hold IF/ID register
    flush_idex_o : out std_logic    -- insert NOP into ID/EX (bubble)
  );
end entity hazard_unit;

architecture rtl of hazard_unit is
  signal load_use_s : std_logic;
begin
  -- Load-use hazard: EX stage has a load AND it writes to a register read in ID
  load_use_s <= mem_re_ex_i when
    (rd_ex_i /= "00000") and
    (rd_ex_i = rs1_id_i or rd_ex_i = rs2_id_i)
    else '0';

  stall_pc_o   <= load_use_s;
  stall_ifid_o <= load_use_s;
  flush_idex_o <= load_use_s;
end architecture rtl;
