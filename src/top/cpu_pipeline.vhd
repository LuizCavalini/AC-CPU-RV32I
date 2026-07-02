library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 5-stage pipelined RV32I CPU
-- Stages: IF → ID → EX → MEM → WB
-- Hazard handling:
--   Data hazards: forwarding unit (EX/MEM→EX, MEM/WB→EX)
--   Load-use:     hazard detection unit (1-cycle stall)
--   Control:      flush IF/ID and ID/EX on branch/jump taken
entity cpu_pipeline is
  port (
    clk_i        : in  std_logic;
    rst_i        : in  std_logic;
    imem_addr_o  : out std_logic_vector(31 downto 0);
    imem_data_i  : in  std_logic_vector(31 downto 0);
    dmem_addr_o  : out std_logic_vector(31 downto 0);
    dmem_wdata_o : out std_logic_vector(31 downto 0);
    dmem_rdata_i : in  std_logic_vector(31 downto 0);
    dmem_we_o    : out std_logic;
    dmem_re_o    : out std_logic
  );
end entity cpu_pipeline;

architecture rtl of cpu_pipeline is

  -- ── IF stage signals ────────────────────────────────────────────
  signal pc_if_s         : std_logic_vector(31 downto 0) := (others => '0');
  signal pc_next_s       : std_logic_vector(31 downto 0);
  signal pc_plus4_if_s   : std_logic_vector(31 downto 0);
  signal stall_pc_s      : std_logic;

  -- ── IF/ID register outputs ──────────────────────────────────────
  signal pc_id_s         : std_logic_vector(31 downto 0);
  signal instr_id_s      : std_logic_vector(31 downto 0);

  -- ── ID stage signals ────────────────────────────────────────────
  signal rs1_id_s        : std_logic_vector(4 downto 0);
  signal rs2_id_s        : std_logic_vector(4 downto 0);
  signal rd_id_s         : std_logic_vector(4 downto 0);
  signal funct3_id_s     : std_logic_vector(2 downto 0);
  signal reg_we_id_s     : std_logic;
  signal alu_src_id_s    : std_logic;
  signal alu_ctrl_id_s   : std_logic_vector(3 downto 0);
  signal mem_we_id_s     : std_logic;
  signal mem_re_id_s     : std_logic;
  signal wb_sel_id_s     : std_logic_vector(1 downto 0);
  signal branch_id_s     : std_logic;
  signal jump_id_s       : std_logic;
  signal jalr_id_s       : std_logic;
  signal imm_id_s        : std_logic_vector(31 downto 0);
  signal rd1_id_s        : std_logic_vector(31 downto 0);
  signal rd2_id_s        : std_logic_vector(31 downto 0);
  signal auipc_id_s      : std_logic;
  signal stall_ifid_s    : std_logic;
  signal flush_ifid_s    : std_logic;

  -- ── ID/EX register outputs ──────────────────────────────────────
  signal pc_ex_s         : std_logic_vector(31 downto 0);
  signal rd1_ex_s        : std_logic_vector(31 downto 0);
  signal rd2_ex_s        : std_logic_vector(31 downto 0);
  signal imm_ex_s        : std_logic_vector(31 downto 0);
  signal rs1_ex_s        : std_logic_vector(4 downto 0);
  signal rs2_ex_s        : std_logic_vector(4 downto 0);
  signal rd_ex_s         : std_logic_vector(4 downto 0);
  signal funct3_ex_s     : std_logic_vector(2 downto 0);
  signal reg_we_ex_s     : std_logic;
  signal alu_src_ex_s    : std_logic;
  signal alu_ctrl_ex_s   : std_logic_vector(3 downto 0);
  signal mem_we_ex_s     : std_logic;
  signal mem_re_ex_s     : std_logic;
  signal wb_sel_ex_s     : std_logic_vector(1 downto 0);
  signal branch_ex_s     : std_logic;
  signal jump_ex_s       : std_logic;
  signal jalr_ex_s       : std_logic;
  signal auipc_ex_s      : std_logic;
  signal flush_idex_s    : std_logic;

  -- ── EX stage signals ────────────────────────────────────────────
  signal alu_a_ex_s      : std_logic_vector(31 downto 0);
  signal alu_b_ex_s      : std_logic_vector(31 downto 0);
  signal alu_a_muxed_s   : std_logic_vector(31 downto 0);
  signal alu_b_muxed_s   : std_logic_vector(31 downto 0);
  signal alu_result_ex_s : std_logic_vector(31 downto 0);
  signal alu_zero_ex_s   : std_logic;
  signal pc_plus4_ex_s   : std_logic_vector(31 downto 0);
  signal forward_a_s     : std_logic_vector(1 downto 0);
  signal forward_b_s     : std_logic_vector(1 downto 0);
  signal branch_target_s : std_logic_vector(31 downto 0);
  signal jump_target_s   : std_logic_vector(31 downto 0);
  signal take_branch_s   : std_logic;
  signal pc_redirect_s   : std_logic;

  -- ── EX/MEM register outputs ─────────────────────────────────────
  signal alu_result_mem_s: std_logic_vector(31 downto 0);
  signal rd2_mem_s       : std_logic_vector(31 downto 0);
  signal rd_mem_s        : std_logic_vector(4 downto 0);
  signal reg_we_mem_s    : std_logic;
  signal mem_we_mem_s    : std_logic;
  signal mem_re_mem_s    : std_logic;
  signal wb_sel_mem_s    : std_logic_vector(1 downto 0);
  signal pc_plus4_mem_s  : std_logic_vector(31 downto 0);

  -- ── MEM/WB register outputs ─────────────────────────────────────
  signal alu_result_wb_s : std_logic_vector(31 downto 0);
  signal mem_data_wb_s   : std_logic_vector(31 downto 0);
  signal rd_wb_s         : std_logic_vector(4 downto 0);
  signal reg_we_wb_s     : std_logic;
  signal wb_sel_wb_s     : std_logic_vector(1 downto 0);
  signal pc_plus4_wb_s   : std_logic_vector(31 downto 0);
  signal wb_data_s       : std_logic_vector(31 downto 0);

begin

  -- ══════════════════════════════════════════════════════════════
  -- IF STAGE
  -- ══════════════════════════════════════════════════════════════
  pc_plus4_if_s   <= std_logic_vector(unsigned(pc_if_s) + 4);
  branch_target_s <= std_logic_vector(unsigned(pc_ex_s) + unsigned(imm_ex_s));
  jump_target_s   <= std_logic_vector(unsigned(alu_a_muxed_s) + unsigned(imm_ex_s))
                     when jalr_ex_s = '1'
                     else std_logic_vector(unsigned(pc_ex_s) + unsigned(imm_ex_s));

  take_branch_s <= branch_ex_s and (
    (alu_zero_ex_s     and not funct3_ex_s(0)) or
    (not alu_zero_ex_s and     funct3_ex_s(0))
  );
  pc_redirect_s <= jump_ex_s or take_branch_s;

  pc_next_s <= jump_target_s   when jump_ex_s = '1'       else
               branch_target_s when take_branch_s = '1'   else
               pc_plus4_if_s;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        pc_if_s <= (others => '0');
      elsif stall_pc_s = '0' then
        pc_if_s <= pc_next_s;
      end if;
    end if;
  end process;

  imem_addr_o  <= pc_if_s;
  flush_ifid_s <= pc_redirect_s;

  -- ══════════════════════════════════════════════════════════════
  -- IF/ID PIPELINE REGISTER
  -- ══════════════════════════════════════════════════════════════
  if_id: entity work.if_id_reg
    port map(
      clk_i   => clk_i, rst_i   => rst_i,
      flush_i => flush_ifid_s, stall_i => stall_ifid_s,
      pc_i    => pc_if_s,  instr_i => imem_data_i,
      pc_o    => pc_id_s,  instr_o => instr_id_s
    );

  -- ══════════════════════════════════════════════════════════════
  -- ID STAGE
  -- ══════════════════════════════════════════════════════════════
  rs1_id_s    <= instr_id_s(19 downto 15);
  rs2_id_s    <= instr_id_s(24 downto 20);
  rd_id_s     <= instr_id_s(11 downto  7);
  funct3_id_s <= instr_id_s(14 downto 12);
  auipc_id_s  <= '1' when instr_id_s(6 downto 0) = "0010111" else '0';

  dec: entity work.decoder
    port map(
      instr_i    => instr_id_s,
      reg_we_o   => reg_we_id_s,  alu_src_o  => alu_src_id_s,
      alu_ctrl_o => alu_ctrl_id_s, mem_we_o   => mem_we_id_s,
      mem_re_o   => mem_re_id_s,  wb_sel_o   => wb_sel_id_s,
      branch_o   => branch_id_s,  jump_o     => jump_id_s,
      jalr_o     => jalr_id_s,    imm_o      => imm_id_s
    );

  rf: entity work.regfile
    port map(
      clk_i => clk_i, we_i  => reg_we_wb_s,
      rs1_i => rs1_id_s, rs2_i => rs2_id_s,
      rd_i  => rd_wb_s,  wd_i  => wb_data_s,
      rd1_o => rd1_id_s, rd2_o => rd2_id_s
    );

  haz: entity work.hazard_unit
    port map(
      mem_re_ex_i  => mem_re_ex_s, rd_ex_i      => rd_ex_s,
      rs1_id_i     => rs1_id_s,    rs2_id_i     => rs2_id_s,
      stall_pc_o   => stall_pc_s,  stall_ifid_o => stall_ifid_s,
      flush_idex_o => flush_idex_s
    );

  -- ══════════════════════════════════════════════════════════════
  -- ID/EX PIPELINE REGISTER
  -- ══════════════════════════════════════════════════════════════
  id_ex: entity work.id_ex_reg
    port map(
      clk_i => clk_i, rst_i => rst_i, flush_i => flush_idex_s,
      reg_we_i => reg_we_id_s, alu_src_i => alu_src_id_s,
      alu_ctrl_i => alu_ctrl_id_s, mem_we_i => mem_we_id_s,
      mem_re_i => mem_re_id_s, wb_sel_i => wb_sel_id_s,
      branch_i => branch_id_s, jump_i => jump_id_s,
      jalr_i => jalr_id_s, pc_i => pc_id_s,
      rd1_i => rd1_id_s, rd2_i => rd2_id_s, imm_i => imm_id_s,
      rs1_i => rs1_id_s, rs2_i => rs2_id_s, rd_i => rd_id_s,
      funct3_i => funct3_id_s, auipc_i => auipc_id_s,
      reg_we_o => reg_we_ex_s, alu_src_o => alu_src_ex_s,
      alu_ctrl_o => alu_ctrl_ex_s, mem_we_o => mem_we_ex_s,
      mem_re_o => mem_re_ex_s, wb_sel_o => wb_sel_ex_s,
      branch_o => branch_ex_s, jump_o => jump_ex_s,
      jalr_o => jalr_ex_s, pc_o => pc_ex_s,
      rd1_o => rd1_ex_s, rd2_o => rd2_ex_s, imm_o => imm_ex_s,
      rs1_o => rs1_ex_s, rs2_o => rs2_ex_s, rd_o => rd_ex_s,
      funct3_o => funct3_ex_s, auipc_o => auipc_ex_s
    );

  -- ══════════════════════════════════════════════════════════════
  -- EX STAGE
  -- ══════════════════════════════════════════════════════════════
  fwd: entity work.forwarding_unit
    port map(
      rs1_ex_i => rs1_ex_s, rs2_ex_i => rs2_ex_s,
      rd_mem_i => rd_mem_s, reg_we_mem_i => reg_we_mem_s,
      rd_wb_i  => rd_wb_s,  reg_we_wb_i  => reg_we_wb_s,
      forward_a_o => forward_a_s, forward_b_o => forward_b_s
    );

  -- Forwarding mux for ALU operand A
  with forward_a_s select alu_a_ex_s <=
    rd1_ex_s       when "00",
    wb_data_s      when "01",
    alu_result_mem_s when "10",
    rd1_ex_s       when others;

  -- AUIPC: use PC as ALU A input
  alu_a_muxed_s <= pc_ex_s when auipc_ex_s = '1' else alu_a_ex_s;

  -- Forwarding mux for ALU operand B
  with forward_b_s select alu_b_ex_s <=
    rd2_ex_s       when "00",
    wb_data_s      when "01",
    alu_result_mem_s when "10",
    rd2_ex_s       when others;

  -- Immediate or register select for B
  alu_b_muxed_s <= imm_ex_s when alu_src_ex_s = '1' else alu_b_ex_s;

  pc_plus4_ex_s <= std_logic_vector(unsigned(pc_ex_s) + 4);

  alu_inst: entity work.alu
    port map(
      a_i        => alu_a_muxed_s,
      b_i        => alu_b_muxed_s,
      alu_ctrl_i => alu_ctrl_ex_s,
      result_o   => alu_result_ex_s,
      zero_o     => alu_zero_ex_s
    );

  -- ══════════════════════════════════════════════════════════════
  -- EX/MEM PIPELINE REGISTER
  -- ══════════════════════════════════════════════════════════════
  ex_mem: entity work.ex_mem_reg
    port map(
      clk_i => clk_i, rst_i => rst_i,
      reg_we_i => reg_we_ex_s, mem_we_i => mem_we_ex_s,
      mem_re_i => mem_re_ex_s, wb_sel_i => wb_sel_ex_s,
      alu_result_i => alu_result_ex_s, rd2_i => alu_b_ex_s,
      rd_i => rd_ex_s, pc_plus4_i => pc_plus4_ex_s,
      reg_we_o => reg_we_mem_s, mem_we_o => mem_we_mem_s,
      mem_re_o => mem_re_mem_s, wb_sel_o => wb_sel_mem_s,
      alu_result_o => alu_result_mem_s, rd2_o => rd2_mem_s,
      rd_o => rd_mem_s, pc_plus4_o => pc_plus4_mem_s
    );

  -- ══════════════════════════════════════════════════════════════
  -- MEM STAGE
  -- ══════════════════════════════════════════════════════════════
  dmem_addr_o  <= alu_result_mem_s;
  dmem_wdata_o <= rd2_mem_s;
  dmem_we_o    <= mem_we_mem_s;
  dmem_re_o    <= mem_re_mem_s;

  -- ══════════════════════════════════════════════════════════════
  -- MEM/WB PIPELINE REGISTER
  -- ══════════════════════════════════════════════════════════════
  mem_wb: entity work.mem_wb_reg
    port map(
      clk_i => clk_i, rst_i => rst_i,
      reg_we_i => reg_we_mem_s, wb_sel_i => wb_sel_mem_s,
      alu_result_i => alu_result_mem_s, mem_data_i => dmem_rdata_i,
      rd_i => rd_mem_s, pc_plus4_i => pc_plus4_mem_s,
      reg_we_o => reg_we_wb_s, wb_sel_o => wb_sel_wb_s,
      alu_result_o => alu_result_wb_s, mem_data_o => mem_data_wb_s,
      rd_o => rd_wb_s, pc_plus4_o => pc_plus4_wb_s
    );

  -- ══════════════════════════════════════════════════════════════
  -- WB STAGE
  -- ══════════════════════════════════════════════════════════════
  with wb_sel_wb_s select wb_data_s <=
    alu_result_wb_s when "00",
    mem_data_wb_s   when "01",
    pc_plus4_wb_s   when "10",
    (others => '0') when others;

end architecture rtl;
