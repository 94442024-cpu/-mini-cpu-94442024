`default_nettype none

// ============================================================================
// tt_um_mini_cpu
//
// A tiny 8-bit accumulator-based CPU for Tiny Tapeout.
// Von Neumann architecture: 16 words x 8 bits, shared code + data memory.
// Instruction format: [7:4] = opcode, [3:0] = operand (address or immediate)
//
// Opcode table:
//   0x0 NOP            no operation
//   0x1 LDA addr        ACC <= MEM[addr]
//   0x2 ADD addr        ACC <= ACC + MEM[addr]           (sets carry = carry-out)
//   0x3 SUB addr         ACC <= ACC - MEM[addr]           (sets carry = borrow)
//   0x4 STA addr        MEM[addr] <= ACC
//   0x5 LDI imm4         ACC <= {4'b0, imm4}
//   0x6 JMP addr        PC <= addr
//   0x7 JZ  addr         PC <= addr   if ACC == 0
//   0x8 JC  addr         PC <= addr   if carry flag set
//   0x9 OUT              out_reg <= ACC   (drives uo_out)
//   0xA ADI imm4         ACC <= ACC + {4'b0, imm4}        (sets carry = carry-out)
//   0xB AND addr        ACC <= ACC & MEM[addr]
//   0xC OR  addr         ACC <= ACC | MEM[addr]
//   0xD XOR addr         ACC <= ACC ^ MEM[addr]
//   0xE INV               ACC <= ~ACC
//   0xF HLT               halt (CPU stops advancing)
//
// Debug bus on uio_out (all pins driven as outputs):
//   uio_out[7]   = halted
//   uio_out[6]   = carry flag
//   uio_out[5]   = zero flag  (ACC == 0)
//   uio_out[4]   = state (0 = FETCH, 1 = EXEC)
//   uio_out[3:0] = program counter
// ============================================================================

module tt_um_94442024_mini_cpu (
    input  wire [7:0] ui_in,    // unused dedicated inputs
    output wire [7:0] uo_out,   // OUT-register value
    input  wire [7:0] uio_in,   // unused
    output wire [7:0] uio_out,  // debug bus (see header)
    output wire [7:0] uio_oe,   // all uio pins driven as outputs
    input  wire        ena,
    input  wire        clk,
    input  wire        rst_n
);

  localparam FETCH = 1'b0;
  localparam EXEC  = 1'b1;

  reg [3:0] pc;
  reg [7:0] acc;
  reg [7:0] ir;
  reg [7:0] mem [0:15];
  reg       carry;
  reg       halted;
  reg [7:0] out_reg;
  reg       state;

  wire [3:0] opcode  = ir[7:4];
  wire [3:0] operand = ir[3:0];
  wire       zero    = (acc == 8'd0);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc      <= 4'd0;
      acc     <= 8'd0;
      ir      <= 8'd0;
      carry   <= 1'b0;
      halted  <= 1'b0;
      out_reg <= 8'd0;
      state   <= FETCH;

      // ---- demo program: (3 + 4), XOR with 9, then invert, printing each step ----
      mem[0]  <= 8'h1D; // LDA 13     ACC = A
      mem[1]  <= 8'h2E; // ADD 14     ACC = A + B
      mem[2]  <= 8'h4F; // STA 15     SUM = ACC
      mem[3]  <= 8'h90; // OUT        show SUM
      mem[4]  <= 8'h59; // LDI 9      ACC = 9
      mem[5]  <= 8'hDF; // XOR 15     ACC = 9 ^ SUM
      mem[6]  <= 8'h90; // OUT        show result
      mem[7]  <= 8'hE0; // INV        ACC = ~ACC
      mem[8]  <= 8'h90; // OUT        show inverted result
      mem[9]  <= 8'hF0; // HLT
      mem[10] <= 8'h00;
      mem[11] <= 8'h00;
      mem[12] <= 8'h00;
      mem[13] <= 8'h03; // A = 3
      mem[14] <= 8'h04; // B = 4
      mem[15] <= 8'h00; // SUM (written at runtime)

    end else if (ena && !halted) begin
      case (state)
        FETCH: begin
          ir    <= mem[pc];
          pc    <= pc + 4'd1;
          state <= EXEC;
        end

        EXEC: begin
          state <= FETCH;
          case (opcode)
            4'h0: ;                                             // NOP
            4'h1: acc         <= mem[operand];                  // LDA
            4'h2: {carry,acc} <= acc + mem[operand];             // ADD
            4'h3: {carry,acc} <= acc - mem[operand];             // SUB
            4'h4: mem[operand] <= acc;                           // STA
            4'h5: acc         <= {4'b0000, operand};             // LDI
            4'h6: pc          <= operand;                        // JMP
            4'h7: if (zero)  pc <= operand;                      // JZ
            4'h8: if (carry) pc <= operand;                      // JC
            4'h9: out_reg     <= acc;                            // OUT
            4'hA: {carry,acc} <= acc + {4'b0000, operand};       // ADI
            4'hB: acc         <= acc & mem[operand];             // AND
            4'hC: acc         <= acc | mem[operand];             // OR
            4'hD: acc         <= acc ^ mem[operand];             // XOR
            4'hE: acc         <= ~acc;                           // INV
            4'hF: halted      <= 1'b1;                           // HLT
            default: ;
          endcase
        end
      endcase
    end
  end

  assign uo_out  = out_reg;
  assign uio_out = {halted, carry, zero, state, pc};
  assign uio_oe  = 8'hFF;

  // keep linter happy about unused inputs
  wire _unused = &{ena, ui_in, uio_in, 1'b0};

endmodule
