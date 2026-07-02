library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Single-cycle RV32I CPU (no pipeline yet)
-- Used to validate the datapath before adding pipeline registers
entity cpu_single_cycle is
  port (
    clk_i      : in  std_logic;
    rst_i      : in  std_logic;
    -- Instruction memory interface
    imem_addr_o  : out std_logic_vector(31 downto 0);
    imem_data_i  : in  std_logic_vector(31 downto 0);
    -- Data memory interface
    dmem_addr_o  : out std_logic_vector(31 downto 0);
    dmem_wdata_o : out std_logic_vector(31 downto 0);
    dmem_rdata_i : in  std_logic_vector(31 downto 0);
    dmem_we_o    : out std_logic;
    dmem_re_o    : out std_logic
  );
end entity cpu_single_cycle;

architecture rtl of cpu_single_cycle is

  -- PC
  signal pc_s        : std_logic_vector(31 downto 0) := (others => '0');
  signal pc_next_s   : std_logic_vector(31 downto 0);
  signal pc_plus4_s  : std_logic_vector(31 downto 0);

  -- Instruction fields
  signal instr_s     : std_logic_vector(31 downto 0);
  signal rs1_s       : std_logic_vector(4 downto 0);
  signal rs2_s       : std_logic_vector(4 downto 0);
  signal rd_s        : std_logic_vector(4 downto 0);

  -- Decoder outputs
  signal reg_we_s    : std_logic;
  signal alu_src_s   : std_logic;
  signal alu_ctrl_s  : std_logic_vector(3 downto 0);
  signal mem_we_s    : std_logic;
  signal mem_re_s    : std_logic;
  signal wb_sel_s    : std_logic_vector(1 downto 0);
  signal branch_s    : std_logic;
  signal jump_s      : std_logic;
  signal jalr_s      : std_logic;
  signal imm_s       : std_logic_vector(31 downto 0);

  -- Register file outputs
  signal rd1_s       : std_logic_vector(31 downto 0);
  signal rd2_s       : std_logic_vector(31 downto 0);

  -- ALU
  signal alu_a_s     : std_logic_vector(31 downto 0);
  signal alu_b_s     : std_logic_vector(31 downto 0);
  signal alu_result_s: std_logic_vector(31 downto 0);
  signal alu_zero_s  : std_logic;

  -- Writeback
  signal wb_data_s   : std_logic_vector(31 downto 0);

  -- Branch/Jump target
  signal branch_target_s : std_logic_vector(31 downto 0);
  signal jump_target_s   : std_logic_vector(31 downto 0);
  signal take_branch_s   : std_logic;

begin

  -- ── Program Counter ────────────────────────────────────────────
  pc_plus4_s <= std_logic_vector(unsigned(pc_s) + 4);

  -- Branch target: PC + imm (B-type)
  branch_target_s <= std_logic_vector(unsigned(pc_s) + unsigned(imm_s));

  -- Jump target: PC + imm (JAL) or rs1 + imm (JALR)
  jump_target_s <= std_logic_vector(unsigned(rd1_s) + unsigned(imm_s))
                   when jalr_s = '1'
                   else std_logic_vector(unsigned(pc_s) + unsigned(imm_s));

  -- Branch decision: beq (funct3=000) checks zero, bne (funct3=001) checks not-zero
  take_branch_s <= branch_s and (
    (alu_zero_s     and not instr_s(12)) or  -- beq: zero=1
    (not alu_zero_s and     instr_s(12))      -- bne: zero=0
  );

  -- PC mux
  pc_next_s <= jump_target_s   when jump_s = '1'       else
               branch_target_s when take_branch_s = '1' else
               pc_plus4_s;

  -- PC register
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        pc_s <= (others => '0');
      else
        pc_s <= pc_next_s;
      end if;
    end if;
  end process;

  -- ── Instruction Memory ─────────────────────────────────────────
  imem_addr_o <= pc_s;
  instr_s     <= imem_data_i;

  -- Instruction field extraction
  rs1_s <= instr_s(19 downto 15);
  rs2_s <= instr_s(24 downto 20);
  rd_s  <= instr_s(11 downto  7);

  -- ── Decoder ────────────────────────────────────────────────────
  dec: entity work.decoder
    port map (
      instr_i    => instr_s,
      reg_we_o   => reg_we_s,
      alu_src_o  => alu_src_s,
      alu_ctrl_o => alu_ctrl_s,
      mem_we_o   => mem_we_s,
      mem_re_o   => mem_re_s,
      wb_sel_o   => wb_sel_s,
      branch_o   => branch_s,
      jump_o     => jump_s,
      jalr_o     => jalr_s,
      imm_o      => imm_s
    );

  -- ── Register File ──────────────────────────────────────────────
  rf: entity work.regfile
    port map (
      clk_i  => clk_i,
      we_i   => reg_we_s,
      rs1_i  => rs1_s,
      rs2_i  => rs2_s,
      rd_i   => rd_s,
      wd_i   => wb_data_s,
      rd1_o  => rd1_s,
      rd2_o  => rd2_s
    );

  -- ── ALU ────────────────────────────────────────────────────────
  -- AUIPC: ALU input A = PC (not rs1)
  alu_a_s <= pc_s when instr_s(6 downto 0) = "0010111" else rd1_s;
  alu_b_s <= imm_s when alu_src_s = '1' else rd2_s;

  alu_inst: entity work.alu
    port map (
      a_i        => alu_a_s,
      b_i        => alu_b_s,
      alu_ctrl_i => alu_ctrl_s,
      result_o   => alu_result_s,
      zero_o     => alu_zero_s
    );

  -- ── Data Memory ────────────────────────────────────────────────
  dmem_addr_o  <= alu_result_s;
  dmem_wdata_o <= rd2_s;
  dmem_we_o    <= mem_we_s;
  dmem_re_o    <= mem_re_s;

  -- ── Writeback Mux ──────────────────────────────────────────────
  with wb_sel_s select wb_data_s <=
    alu_result_s   when "00",   -- ALU result (R-type, I-type, LUI, AUIPC)
    dmem_rdata_i   when "01",   -- Memory data (LW)
    pc_plus4_s     when "10",   -- PC+4 (JAL, JALR)
    (others => '0') when others;

end architecture rtl;
