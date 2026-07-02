library ieee;
use ieee.std_logic_1164.all;

entity top is
  port (
    clk_i        : in  std_logic;
    rst_i        : in  std_logic;
    imem_data_i  : in  std_logic_vector(31 downto 0);
    dmem_rdata_i : in  std_logic_vector(31 downto 0);
    imem_addr_o  : out std_logic_vector(31 downto 0);
    dmem_addr_o  : out std_logic_vector(31 downto 0);
    dmem_wdata_o : out std_logic_vector(31 downto 0);
    dmem_we_o    : out std_logic;
    dmem_re_o    : out std_logic
  );
end entity top;

architecture rtl of top is
begin
  cpu: entity work.cpu_pipeline
    port map(
      clk_i        => clk_i,
      rst_i        => rst_i,
      imem_addr_o  => imem_addr_o,
      imem_data_i  => imem_data_i,
      dmem_addr_o  => dmem_addr_o,
      dmem_wdata_o => dmem_wdata_o,
      dmem_rdata_i => dmem_rdata_i,
      dmem_we_o    => dmem_we_o,
      dmem_re_o    => dmem_re_o
    );
end architecture rtl;
