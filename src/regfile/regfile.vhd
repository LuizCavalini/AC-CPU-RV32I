library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Register file: 32 x 32-bit registers
-- x0 is hardwired to zero (reads always return 0, writes are ignored)
-- Write on rising edge of clk when we_i = '1'
-- Read is asynchronous (combinational)
entity regfile is
  port (
    clk_i   : in  std_logic;
    we_i    : in  std_logic;
    rs1_i   : in  std_logic_vector(4 downto 0);
    rs2_i   : in  std_logic_vector(4 downto 0);
    rd_i    : in  std_logic_vector(4 downto 0);
    wd_i    : in  std_logic_vector(31 downto 0);
    rd1_o   : out std_logic_vector(31 downto 0);
    rd2_o   : out std_logic_vector(31 downto 0)
  );
end entity regfile;

architecture rtl of regfile is
  type reg_array_t is array(0 to 31) of std_logic_vector(31 downto 0);
  signal regs : reg_array_t := (others => (others => '0'));
begin

  -- Synchronous write (x0 is hardwired to zero)
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if we_i = '1' and rd_i /= "00000" then
        regs(to_integer(unsigned(rd_i))) <= wd_i;
      end if;
    end if;
  end process;

  -- Asynchronous read (x0 always returns zero)
  rd1_o <= (others => '0') when rs1_i = "00000" else
           regs(to_integer(unsigned(rs1_i)));
  rd2_o <= (others => '0') when rs2_i = "00000" else
           regs(to_integer(unsigned(rs2_i)));

end architecture rtl;
