library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
  port (
    a_i       : in  std_logic_vector(31 downto 0);
    b_i       : in  std_logic_vector(31 downto 0);
    alu_ctrl_i: in  std_logic_vector(3  downto 0);
    result_o  : out std_logic_vector(31 downto 0);
    zero_o    : out std_logic
  );
end entity alu;

architecture rtl of alu is
  signal result_s : std_logic_vector(31 downto 0);
begin

  process(a_i, b_i, alu_ctrl_i)
    variable a_s   : signed(31 downto 0);
    variable b_s   : signed(31 downto 0);
    variable a_u   : unsigned(31 downto 0);
    variable b_u   : unsigned(31 downto 0);
    variable shamt : integer range 0 to 31;
  begin
    a_s   := signed(a_i);
    b_s   := signed(b_i);
    a_u   := unsigned(a_i);
    b_u   := unsigned(b_i);
    shamt := to_integer(unsigned(b_i(4 downto 0)));

    case alu_ctrl_i is
      when "0000" => result_s <= std_logic_vector(a_s + b_s);          -- ADD
      when "0001" => result_s <= std_logic_vector(a_s - b_s);          -- SUB
      when "0010" => result_s <= a_i and b_i;                          -- AND
      when "0011" => result_s <= a_i or  b_i;                          -- OR
      when "0100" => result_s <= a_i xor b_i;                          -- XOR
      when "0101" => result_s <= std_logic_vector(shift_left (a_u, shamt)); -- SLL
      when "0110" => result_s <= std_logic_vector(shift_right(a_u, shamt)); -- SRL
      when "0111" => result_s <= b_i;                                   -- LUI (passa B)
      when "1000" =>                                                     -- SLT
        if a_s < b_s then
          result_s <= (0 => '1', others => '0');
        else
          result_s <= (others => '0');
        end if;
      when others => result_s <= (others => '0');
    end case;
  end process;

  result_o <= result_s;
  zero_o   <= '1' when result_s = x"00000000" else '0';

end architecture rtl;
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
library ieee;
use ieee.std_logic_1164.all;

-- Instruction decoder for RV32I
-- Decodes the 7-bit opcode + funct3 + funct7 into control signals
--
-- Instruction formats:
--   R-type: funct7 | rs2 | rs1 | funct3 | rd  | opcode
--   I-type: imm[11:0]      | rs1 | funct3 | rd  | opcode
--   S-type: imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode
--   B-type: imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode
--   U-type: imm[31:12] | rd | opcode
--   J-type: imm[20|10:1|11|19:12] | rd | opcode
entity decoder is
  port (
    instr_i     : in  std_logic_vector(31 downto 0);
    -- Register file control
    reg_we_o    : out std_logic;
    -- ALU control
    alu_src_o   : out std_logic;       -- 0=rs2, 1=immediate
    alu_ctrl_o  : out std_logic_vector(3 downto 0);
    -- Memory control
    mem_we_o    : out std_logic;
    mem_re_o    : out std_logic;
    -- Writeback mux
    wb_sel_o    : out std_logic_vector(1 downto 0); -- 00=alu, 01=mem, 10=pc+4
    -- Branch/Jump control
    branch_o    : out std_logic;       -- beq/bne
    jump_o      : out std_logic;       -- jal/jalr
    jalr_o      : out std_logic;       -- jalr uses rs1+imm (not PC+imm)
    -- Immediate value (sign extended)
    imm_o       : out std_logic_vector(31 downto 0)
  );
end entity decoder;

architecture rtl of decoder is
  alias opcode : std_logic_vector(6 downto 0) is instr_i(6  downto 0);
  alias funct3 : std_logic_vector(2 downto 0) is instr_i(14 downto 12);
  alias funct7 : std_logic_vector(6 downto 0) is instr_i(31 downto 25);

  -- Immediate generation
  signal imm_i_s : std_logic_vector(31 downto 0); -- I-type
  signal imm_s_s : std_logic_vector(31 downto 0); -- S-type
  signal imm_b_s : std_logic_vector(31 downto 0); -- B-type
  signal imm_u_s : std_logic_vector(31 downto 0); -- U-type
  signal imm_j_s : std_logic_vector(31 downto 0); -- J-type
begin

  -- ── Immediate generation ────────────────────────────────────────
  -- I-type: sign-extend instr[31:20]
  imm_i_s <= (31 downto 12 => instr_i(31)) & instr_i(31 downto 20);

  -- S-type: sign-extend {instr[31:25], instr[11:7]}
  imm_s_s <= (31 downto 12 => instr_i(31)) & instr_i(31 downto 25) & instr_i(11 downto 7);

  -- B-type: sign-extend {instr[31],instr[7],instr[30:25],instr[11:8],1'b0}
  imm_b_s <= (31 downto 13 => instr_i(31)) &
             instr_i(31) & instr_i(7) &
             instr_i(30 downto 25) & instr_i(11 downto 8) & '0';

  -- U-type: {instr[31:12], 12'b0}
  imm_u_s <= instr_i(31 downto 12) & (11 downto 0 => '0');

  -- J-type: sign-extend {instr[31],instr[19:12],instr[20],instr[30:21],1'b0}
  imm_j_s <= (31 downto 21 => instr_i(31)) &
             instr_i(31) & instr_i(19 downto 12) &
             instr_i(20) & instr_i(30 downto 21) & '0';

  -- ── Control signal generation ───────────────────────────────────
  process(opcode, funct3, funct7,
          imm_i_s, imm_s_s, imm_b_s, imm_u_s, imm_j_s)
  begin
    -- Safe defaults
    reg_we_o   <= '0';
    alu_src_o  <= '0';
    alu_ctrl_o <= "0000";
    mem_we_o   <= '0';
    mem_re_o   <= '0';
    wb_sel_o   <= "00";
    branch_o   <= '0';
    jump_o     <= '0';
    jalr_o     <= '0';
    imm_o      <= (others => '0');

    case opcode is

      -- ── R-type: add, sub, and, or, xor, sll, srl ──────────────
      when "0110011" =>
        reg_we_o  <= '1';
        alu_src_o <= '0';    -- use rs2
        wb_sel_o  <= "00";   -- ALU result
        case funct3 is
          when "000" =>
            if funct7 = "0100000" then
              alu_ctrl_o <= "0001"; -- SUB
            else
              alu_ctrl_o <= "0000"; -- ADD
            end if;
          when "111" => alu_ctrl_o <= "0010"; -- AND
          when "110" => alu_ctrl_o <= "0011"; -- OR
          when "100" => alu_ctrl_o <= "0100"; -- XOR
          when "001" => alu_ctrl_o <= "0101"; -- SLL
          when "101" => alu_ctrl_o <= "0110"; -- SRL
          when others => null;
        end case;

      -- ── I-type arithmetic: addi, andi, ori, xori, slli, srli ──
      when "0010011" =>
        reg_we_o  <= '1';
        alu_src_o <= '1';    -- use immediate
        wb_sel_o  <= "00";
        imm_o     <= imm_i_s;
        case funct3 is
          when "000" => alu_ctrl_o <= "0000"; -- ADDI
          when "111" => alu_ctrl_o <= "0010"; -- ANDI
          when "110" => alu_ctrl_o <= "0011"; -- ORI
          when "100" => alu_ctrl_o <= "0100"; -- XORI
          when "001" => alu_ctrl_o <= "0101"; -- SLLI
          when "101" => alu_ctrl_o <= "0110"; -- SRLI
          when others => null;
        end case;

      -- ── Load: lw ───────────────────────────────────────────────
      when "0000011" =>
        reg_we_o  <= '1';
        alu_src_o <= '1';    -- rs1 + imm = address
        alu_ctrl_o <= "0000"; -- ADD for address calc
        mem_re_o  <= '1';
        wb_sel_o  <= "01";   -- write back memory data
        imm_o     <= imm_i_s;

      -- ── Store: sw ──────────────────────────────────────────────
      when "0100011" =>
        reg_we_o  <= '0';
        alu_src_o <= '1';    -- rs1 + imm = address
        alu_ctrl_o <= "0000"; -- ADD
        mem_we_o  <= '1';
        imm_o     <= imm_s_s;

      -- ── Branch: beq, bne ───────────────────────────────────────
      when "1100011" =>
        branch_o  <= '1';
        alu_src_o <= '0';    -- compare rs1 and rs2
        alu_ctrl_o <= "0001"; -- SUB (check zero flag)
        imm_o     <= imm_b_s;

      -- ── U-type: lui ────────────────────────────────────────────
      when "0110111" =>
        reg_we_o  <= '1';
        alu_src_o <= '1';
        alu_ctrl_o <= "0111"; -- LUI: pass B (immediate)
        wb_sel_o  <= "00";
        imm_o     <= imm_u_s;

      -- ── U-type: auipc ──────────────────────────────────────────
      when "0010111" =>
        reg_we_o  <= '1';
        alu_src_o <= '1';
        alu_ctrl_o <= "0000"; -- ADD: PC + imm
        wb_sel_o  <= "00";
        imm_o     <= imm_u_s;

      -- ── J-type: jal ────────────────────────────────────────────
      when "1101111" =>
        reg_we_o  <= '1';
        jump_o    <= '1';
        alu_ctrl_o <= "0000"; -- ADD: PC + imm (jump target)
        alu_src_o <= '1';
        wb_sel_o  <= "10";   -- write back PC+4
        imm_o     <= imm_j_s;

      -- ── I-type: jalr ───────────────────────────────────────────
      when "1100111" =>
        reg_we_o  <= '1';
        jump_o    <= '1';
        jalr_o    <= '1';
        alu_ctrl_o <= "0000"; -- ADD: rs1 + imm (jump target)
        alu_src_o <= '1';
        wb_sel_o  <= "10";   -- write back PC+4
        imm_o     <= imm_i_s;

      when others => null;
    end case;
  end process;

end architecture rtl;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Pipeline register: IF/ID
-- Holds instruction and PC between Fetch and Decode stages
entity if_id_reg is
  port (
    clk_i    : in  std_logic;
    rst_i    : in  std_logic;
    flush_i  : in  std_logic;   -- control hazard: discard instruction
    stall_i  : in  std_logic;   -- data hazard: hold current values
    pc_i     : in  std_logic_vector(31 downto 0);
    instr_i  : in  std_logic_vector(31 downto 0);
    pc_o     : out std_logic_vector(31 downto 0);
    instr_o  : out std_logic_vector(31 downto 0)
  );
end entity if_id_reg;

architecture rtl of if_id_reg is
begin
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' or flush_i = '1' then
        pc_o    <= (others => '0');
        instr_o <= (others => '0');  -- NOP
      elsif stall_i = '0' then
        pc_o    <= pc_i;
        instr_o <= instr_i;
      end if;
      -- stall: hold values (do nothing)
    end if;
  end process;
end architecture rtl;
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
    auipc_o    : out std_logic
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
      end if;
    end if;
  end process;
end architecture rtl;
library ieee;
use ieee.std_logic_1164.all;

-- Pipeline register: EX/MEM
entity ex_mem_reg is
  port (
    clk_i        : in  std_logic;
    rst_i        : in  std_logic;
    -- Control
    reg_we_i     : in  std_logic;
    mem_we_i     : in  std_logic;
    mem_re_i     : in  std_logic;
    wb_sel_i     : in  std_logic_vector(1 downto 0);
    -- Data
    alu_result_i : in  std_logic_vector(31 downto 0);
    rd2_i        : in  std_logic_vector(31 downto 0);
    rd_i         : in  std_logic_vector(4 downto 0);
    pc_plus4_i   : in  std_logic_vector(31 downto 0);
    -- Outputs
    reg_we_o     : out std_logic;
    mem_we_o     : out std_logic;
    mem_re_o     : out std_logic;
    wb_sel_o     : out std_logic_vector(1 downto 0);
    alu_result_o : out std_logic_vector(31 downto 0);
    rd2_o        : out std_logic_vector(31 downto 0);
    rd_o         : out std_logic_vector(4 downto 0);
    pc_plus4_o   : out std_logic_vector(31 downto 0)
  );
end entity ex_mem_reg;

architecture rtl of ex_mem_reg is
begin
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        reg_we_o <= '0'; mem_we_o <= '0'; mem_re_o <= '0';
        wb_sel_o <= "00"; alu_result_o <= (others => '0');
        rd2_o <= (others => '0'); rd_o <= (others => '0');
        pc_plus4_o <= (others => '0');
      else
        reg_we_o     <= reg_we_i;
        mem_we_o     <= mem_we_i;
        mem_re_o     <= mem_re_i;
        wb_sel_o     <= wb_sel_i;
        alu_result_o <= alu_result_i;
        rd2_o        <= rd2_i;
        rd_o         <= rd_i;
        pc_plus4_o   <= pc_plus4_i;
      end if;
    end if;
  end process;
end architecture rtl;
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
