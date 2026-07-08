library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
  port (
    clk_i        : in  std_logic;
    rst_i        : in  std_logic;
    imem_data_i  : in  std_logic_vector(31 downto 0);
    dmem_rdata_i : in  std_logic_vector(31 downto 0);
    -- Memory interface
    imem_addr_o  : out std_logic_vector(31 downto 0);
    dmem_addr_o  : out std_logic_vector(31 downto 0);
    dmem_wdata_o : out std_logic_vector(31 downto 0);
    dmem_we_o    : out std_logic;
    dmem_re_o    : out std_logic;
    -- Debug outputs (for Digital inspection)
    pc_debug_o      : out std_logic_vector(31 downto 0);
    instr_debug_o   : out std_logic_vector(31 downto 0);
    alu_debug_o     : out std_logic_vector(31 downto 0);
    stall_debug_o   : out std_logic;
    flush_debug_o   : out std_logic;
    vec_cout_debug_o : out std_logic_vector(7 downto 0)
  );
end entity top;

architecture rtl of top is

  -- Internal signals to expose debug info
  signal imem_addr_s   : std_logic_vector(31 downto 0);
  signal instr_reg_s   : std_logic_vector(31 downto 0) := (others => '0');
  signal alu_reg_s     : std_logic_vector(31 downto 0) := (others => '0');
  signal dmem_addr_s   : std_logic_vector(31 downto 0);
  signal dmem_wdata_s  : std_logic_vector(31 downto 0);
  signal dmem_we_s     : std_logic;
  signal dmem_re_s     : std_logic;

begin

  cpu: entity work.cpu_pipeline
    port map(
      clk_i         => clk_i,
      rst_i         => rst_i,
      imem_addr_o   => imem_addr_s,
      imem_data_i   => imem_data_i,
      dmem_addr_o   => dmem_addr_s,
      dmem_wdata_o  => dmem_wdata_s,
      dmem_rdata_i  => dmem_rdata_i,
      dmem_we_o     => dmem_we_s,
      dmem_re_o     => dmem_re_s,
      pc_debug_o    => pc_debug_o,
      instr_debug_o => instr_debug_o,
      alu_debug_o   => alu_debug_o,
      stall_debug_o => stall_debug_o,
      flush_debug_o => flush_debug_o,
      vec_cout_debug_o => vec_cout_debug_o
    );

  -- Pass through memory signals
  imem_addr_o  <= imem_addr_s;
  dmem_addr_o  <= dmem_addr_s;
  dmem_wdata_o <= dmem_wdata_s;
  dmem_we_o    <= dmem_we_s;
  dmem_re_o    <= dmem_re_s;

end architecture rtl;
