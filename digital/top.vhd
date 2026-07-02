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
    flush_debug_o   : out std_logic
  );
end entity top;

architecture rtl of top is

  -- Internal signals to expose debug info
  signal imem_addr_s   : std_logic_vector(31 downto 0);
  signal pc_reg_s      : std_logic_vector(31 downto 0) := (others => '0');
  signal instr_reg_s   : std_logic_vector(31 downto 0) := (others => '0');
  signal alu_reg_s     : std_logic_vector(31 downto 0) := (others => '0');
  signal stall_reg_s   : std_logic := '0';
  signal flush_reg_s   : std_logic := '0';
  signal dmem_addr_s   : std_logic_vector(31 downto 0);
  signal dmem_wdata_s  : std_logic_vector(31 downto 0);
  signal dmem_we_s     : std_logic;
  signal dmem_re_s     : std_logic;

begin

  cpu: entity work.cpu_pipeline
    port map(
      clk_i        => clk_i,
      rst_i        => rst_i,
      imem_addr_o  => imem_addr_s,
      imem_data_i  => imem_data_i,
      dmem_addr_o  => dmem_addr_s,
      dmem_wdata_o => dmem_wdata_s,
      dmem_rdata_i => dmem_rdata_i,
      dmem_we_o    => dmem_we_s,
      dmem_re_o    => dmem_re_s
    );

  -- Pass through memory signals
  imem_addr_o  <= imem_addr_s;
  dmem_addr_o  <= dmem_addr_s;
  dmem_wdata_o <= dmem_wdata_s;
  dmem_we_o    <= dmem_we_s;
  dmem_re_o    <= dmem_re_s;

  -- Debug: capture PC (imem_addr = current PC)
  pc_debug_o    <= imem_addr_s;

  -- Debug: capture current instruction from memory
  instr_debug_o <= imem_data_i;

  -- Debug: capture data memory address as ALU result proxy
  alu_debug_o   <= dmem_addr_s;

  -- Debug: stall = PC not advancing (compare with registered value)
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      pc_reg_s    <= imem_addr_s;
      stall_reg_s <= '1' when imem_addr_s = pc_reg_s and rst_i = '0' else '0';
      flush_reg_s <= dmem_we_s or dmem_re_s;
    end if;
  end process;

  stall_debug_o <= stall_reg_s;
  flush_debug_o <= flush_reg_s;

end architecture rtl;
