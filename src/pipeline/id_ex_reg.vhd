library ieee;
use ieee.std_logic_1164.all;

-- Pipeline register: ID/EX
-- Holds decoded values between Decode and Execute stages
entity id_ex_reg is
  port (
    clk_i      : in  std_logic;
    rst_i      : in  std_logic;
    flush_i    : in  std_logic;
    -- Control signals
    reg_we_i   : in  std_logic;
    alu_src_i  : in  std_logic;
    alu_ctrl_i : in  std_logic_vector(3 downto 0);
    mem_we_i   : in  std_logic;
    mem_re_i   : in  std_logic;
    wb_sel_i   : in  std_logic_vector(1 downto 0);
    branch_i   : in  std_logic;
    jump_i     : in  std_logic;
    jalr_i     : in  std_logic;
    -- Data
    pc_i       : in  std_logic_vector(31 downto 0);
    rd1_i      : in  std_logic_vector(31 downto 0);
    rd2_i      : in  std_logic_vector(31 downto 0);
    imm_i      : in  std_logic_vector(31 downto 0);
    rs1_i      : in  std_logic_vector(4 downto 0);
    rs2_i      : in  std_logic_vector(4 downto 0);
    rd_i       : in  std_logic_vector(4 downto 0);
    funct3_i   : in  std_logic_vector(2 downto 0);
    auipc_i    : in  std_logic;
    is_vector_i : in  std_logic;
    vecsize_i   : in  std_logic_vector(1 downto 0);
    -- Outputs
    reg_we_o   : out std_logic;
    alu_src_o  : out std_logic;
    alu_ctrl_o : out std_logic_vector(3 downto 0);
    mem_we_o   : out std_logic;
    mem_re_o   : out std_logic;
    wb_sel_o   : out std_logic_vector(1 downto 0);
    branch_o   : out std_logic;
    jump_o     : out std_logic;
    jalr_o     : out std_logic;
    pc_o       : out std_logic_vector(31 downto 0);
    rd1_o      : out std_logic_vector(31 downto 0);
    rd2_o      : out std_logic_vector(31 downto 0);
    imm_o      : out std_logic_vector(31 downto 0);
    rs1_o      : out std_logic_vector(4 downto 0);
    rs2_o      : out std_logic_vector(4 downto 0);
    rd_o       : out std_logic_vector(4 downto 0);
    funct3_o   : out std_logic_vector(2 downto 0);
    auipc_o    : out std_logic;
    is_vector_o : out std_logic;
    vecsize_o   : out std_logic_vector(1 downto 0)
  );
end entity id_ex_reg;

architecture rtl of id_ex_reg is
begin
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' or flush_i = '1' then
        reg_we_o   <= '0'; alu_src_o  <= '0'; alu_ctrl_o <= "0000";
        mem_we_o   <= '0'; mem_re_o   <= '0'; wb_sel_o   <= "00";
        branch_o   <= '0'; jump_o     <= '0'; jalr_o     <= '0';
        pc_o       <= (others => '0'); rd1_o <= (others => '0');
        rd2_o      <= (others => '0'); imm_o <= (others => '0');
        rs1_o      <= (others => '0'); rs2_o <= (others => '0');
        rd_o       <= (others => '0'); funct3_o <= (others => '0');
        auipc_o    <= '0';
        is_vector_o <= '0'; vecsize_o <= "00";
      else
        reg_we_o   <= reg_we_i;  alu_src_o  <= alu_src_i;
        alu_ctrl_o <= alu_ctrl_i; mem_we_o   <= mem_we_i;
        mem_re_o   <= mem_re_i;  wb_sel_o   <= wb_sel_i;
        branch_o   <= branch_i;  jump_o     <= jump_i;
        jalr_o     <= jalr_i;    pc_o       <= pc_i;
        rd1_o      <= rd1_i;     rd2_o      <= rd2_i;
        imm_o      <= imm_i;     rs1_o      <= rs1_i;
        rs2_o      <= rs2_i;     rd_o       <= rd_i;
        funct3_o   <= funct3_i;  auipc_o    <= auipc_i;
        is_vector_o <= is_vector_i; vecsize_o <= vecsize_i;
      end if;
    end if;
  end process;
end architecture rtl;
