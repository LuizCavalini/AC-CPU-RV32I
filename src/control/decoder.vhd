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
    imm_o       : out std_logic_vector(31 downto 0);
    -- Vector control (Parte 2)
    is_vector_o : out std_logic;
    vecsize_o   : out std_logic_vector(1 downto 0)
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
    is_vector_o <= '0';
    vecsize_o   <= "00";

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

      -- ── Custom-0: instruções vetoriais (Parte 2 — extensão vetorial) ──
      -- Reaproveita os códigos alu_ctrl já existentes (0000=ADD, 0001=SUB,
      -- 0101=SLL, 0110=SRL). funct3 (instr[14:12]) seleciona a operação
      -- vetorial uniformemente, mesmo para vauipc (que no U-type padrão
      -- não tem esse campo — aqui é reaproveitado por uniformidade,
      -- custando parte do imediato do vauipc).
      when "0001011" =>
        reg_we_o    <= '1';
        is_vector_o <= '1';
        wb_sel_o    <= "00";
        case funct3 is
          when "000" =>  -- vadd (R-type-like)
            alu_ctrl_o <= "0000";
            alu_src_o  <= '0';
            vecsize_o  <= instr_i(26 downto 25);
          when "001" =>  -- vaddi (I-type-like, imm reduzido a 10 bits)
            alu_ctrl_o <= "0000";
            alu_src_o  <= '1';
            vecsize_o  <= instr_i(31 downto 30);
            imm_o      <= (31 downto 10 => instr_i(29)) & instr_i(29 downto 20);
          when "010" =>  -- vauipc (U-type-like, imm reduzido a 15 bits)
            alu_ctrl_o <= "0000";
            alu_src_o  <= '1';
            vecsize_o  <= instr_i(31 downto 30);
            imm_o      <= (31 downto 27 => '0') & instr_i(29 downto 15) & (11 downto 0 => '0');
          when "011" =>  -- vsub (R-type-like)
            alu_ctrl_o <= "0001";
            alu_src_o  <= '0';
            vecsize_o  <= instr_i(26 downto 25);
          when "100" =>  -- vsll (R-type-like, shamt = rs2[4:0])
            alu_ctrl_o <= "0101";
            alu_src_o  <= '0';
            vecsize_o  <= instr_i(26 downto 25);
          when "101" =>  -- vslli (I-type-like, shamt = imm[4:0])
            alu_ctrl_o <= "0101";
            alu_src_o  <= '1';
            vecsize_o  <= instr_i(26 downto 25);
            imm_o      <= (31 downto 5 => '0') & instr_i(24 downto 20);
          when "110" =>  -- vsrl (R-type-like, shamt = rs2[4:0])
            alu_ctrl_o <= "0110";
            alu_src_o  <= '0';
            vecsize_o  <= instr_i(26 downto 25);
          when "111" =>  -- vsrli (I-type-like, shamt = imm[4:0])
            alu_ctrl_o <= "0110";
            alu_src_o  <= '1';
            vecsize_o  <= instr_i(26 downto 25);
            imm_o      <= (31 downto 5 => '0') & instr_i(24 downto 20);
          when others => null;
        end case;

      when others => null;
    end case;
  end process;

end architecture rtl;
