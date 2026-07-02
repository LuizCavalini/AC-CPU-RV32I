library ieee;
use ieee.std_logic_1164.all;

-- Pipeline register: MEM/WB
entity mem_wb_reg is
  port (
    clk_i        : in  std_logic;
    rst_i        : in  std_logic;
    -- Control
    reg_we_i     : in  std_logic;
    wb_sel_i     : in  std_logic_vector(1 downto 0);
    -- Data
    alu_result_i : in  std_logic_vector(31 downto 0);
    mem_data_i   : in  std_logic_vector(31 downto 0);
    rd_i         : in  std_logic_vector(4 downto 0);
    pc_plus4_i   : in  std_logic_vector(31 downto 0);
    -- Outputs
    reg_we_o     : out std_logic;
    wb_sel_o     : out std_logic_vector(1 downto 0);
    alu_result_o : out std_logic_vector(31 downto 0);
    mem_data_o   : out std_logic_vector(31 downto 0);
    rd_o         : out std_logic_vector(4 downto 0);
    pc_plus4_o   : out std_logic_vector(31 downto 0)
  );
end entity mem_wb_reg;

architecture rtl of mem_wb_reg is
begin
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        reg_we_o <= '0'; wb_sel_o <= "00";
        alu_result_o <= (others => '0'); mem_data_o <= (others => '0');
        rd_o <= (others => '0'); pc_plus4_o <= (others => '0');
      else
        reg_we_o     <= reg_we_i;
        wb_sel_o     <= wb_sel_i;
        alu_result_o <= alu_result_i;
        mem_data_o   <= mem_data_i;
        rd_o         <= rd_i;
        pc_plus4_o   <= pc_plus4_i;
      end if;
    end if;
  end process;
end architecture rtl;
