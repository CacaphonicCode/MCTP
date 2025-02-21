// Universal constants
`define RUNTIME 1024      // How long simulator can run
`define MEMDEL  4         // MEMory read delay
`define CLKDEL  2         // CLocK delay
`define	WORD	[31:0]    // size of a data word
`define	REG	[4:0]     // size of a register number
`define	STATENO	[7:0]     // size of a state number
`define	MEMDIM	[1023:0]  // number of memory location to implement

// Control signals
`define ALUadd		ALUMUX = (Y + BUS);
`define ALUand		ALUMUX = (Y & BUS);
`define ALUxor		ALUMUX = (Y ^ BUS);
`define ALUor		ALUMUX = (Y | BUS);
`define ALUsll		ALUMUX = (BUS << Y);
`define ALUslt		ALUMUX = (Y < BUS);
`define ALUsrl		ALUMUX = (Y >> BUS);
`define ALUsub		ALUMUX = (Y - BUS);
`define CONST(value)	BUS = value;
`define HALT		halt = 1;
`define IRaddrout	BUS = {PC[31:26], IR[25:0]};
`define IRimmedout	BUS = {{16{IR[15]}}, IR[15:0]};
`define IRin		IR <= BUS;
`define IRoffsetout	BUS = {{14{IR[15]}}, IR[15:0], 2'b00};
`define JUMP(label)	NEWSTATE = label;
`define JUMPonop	NEWSTATE = (ONOP ? ONOP : (STATE + 1));
`define NEXT            NEWSTATE = STATE + 1;
`define MARin		MAR = BUS;
`define MARout		BUS = MAR;
`define MDRin		MDR = BUS; // had been MDR <= BUS;
`define MDRout		BUS = MDR;
`define MEMread         begin rnotw = 1; strobe = 1; #1 strobe = 0; end
`define MEMwrite	begin rnotw = 0; strobe = 1; #1 strobe = 0; end
`define PCin		PC <= BUS;
`define PCinif0		if (ALUZ == 0) PC <= BUS;
`define PCout		BUS = PC;
`define REGin		r[WHICH] <= BUS;
`define REGout		BUS = r[WHICH];
`define SELrs		WHICH = IR[25:21];
`define SELrt		WHICH = IR[20:16];
`define SELrd		WHICH = IR[15:11];
`define UNTILmfc	if (mfc) NEWSTATE = STATE + 1;
`define Yin		Y <= BUS;
`define Yout		BUS = Y;
`define ALUZin		ALUZ <= ALUMUX;
`define ALUZout		BUS = ALUZ;

// Macros for encoding field values
`define	OP(EXPR)	(((EXPR) & 32'h0000003f) << 26)
`define	RS(EXPR)	(((EXPR) & 32'h0000001f) << 21)
`define	RT(EXPR)	(((EXPR) & 32'h0000001f) << 16)
`define	RD(EXPR)	(((EXPR) & 32'h0000001f) << 11)
`define	SHAMT(EXPR)	(((EXPR) & 32'h0000001f) << 6)
`define	FUNCT(EXPR)	((EXPR) & 32'h0000003f)
`define	ADDR(EXPR)	((EXPR) & 32'h03ffffff)
`define	IMMED(EXPR)	((EXPR) & 32'h0000ffff)

`define DECODE(mask,match,go) \
  ((-((IR & (mask)) == (match))) & (go)) |

// Simple 32-bit memory, byte addressed
module memory(mfc, dread, dwrite, addr, rnotw, strobe);
output reg mfc;
output reg `WORD dread;
input `WORD dwrite,  addr;
input rnotw, strobe;
reg `WORD m `MEMDIM;

// initialize memory here...
initial begin
  // m[0] = MIPS instruction: add $1,$2,$3
  m[0] = `OP(0) + `RD(1) + `RS(2) + `RT(3) + `FUNCT('h20);

  // illegal instruction to stop simulator
  m[1] = 32'h00000000;
end

always @(posedge strobe) begin
  mfc = 0;
  if (rnotw) begin
    dread = m[addr >> 2];
    mfc = #`MEMDEL 1;
  end else begin
    m[addr >> 2] <= dwrite;
  end
end
endmodule

// Generic multi-cycle processor
module processor(halt, reset, clk);
output reg halt;
input reset, clk;

reg `WORD IR, PC, MAR, MDR, Y, ALUMUX, ALUZ;
reg `WORD r[31:0];
reg `WORD BUS;
reg `STATENO STATE, NEWSTATE;
wire `STATENO ONOP;
reg `REG WHICH;
reg rnotw, strobe;
wire mfc;
wire `WORD dread;
reg `WORD addr;

memory mainmem(mfc, dread, MDR, MAR, rnotw, strobe);

assign ONOP =
  // MIPS add instruction goes to state 5
  `DECODE(`OP(-1)+`FUNCT(-1), `FUNCT('h20), 5)

  // additional JUMPonop decode options go here...

  // PAUL G 
  // SET LESS THAN IMMEDIATE 
  `DECODE(`OP(-1), `OP(10), 500) // IF I understand how this works it's basically saying "checking over the entire OP field" (bc -1 is all 1s) "then make sure the value is 10" "and if it is, we goto case 500"
  
  // PAUL G
  // ATOMIC INCREMENT 
  `DECODE(`OP(-1), `OP(34), 600) // if there is a 34 in the OP field then goto case 600


  // end of JUMPonop decode options
  

  0;

// initialize registers here...
initial begin
  r[0] = 0;
  r[1] = 1;
  r[2] = 2;
  r[3] = 3;
end

// the state machine...
always @(posedge clk) begin
  // show register contents
  $display("TIME  %8d", $time);
  $display("IR  = %x  PC  = %x", IR, PC);
  $display("MAR = %x  MDR = %x", MAR, MDR);
  $display("Y   = %x  Z   = %x", Y, ALUZ);
  $display("$0  = %x  $1  = %x  $2  = %x  $3  = %x", r[ 0], r[ 1], r[ 2], r[ 3]);
  $display("$4  = %x  $5  = %x  $6  = %x  $7  = %x", r[ 4], r[ 5], r[ 6], r[ 7]);
  $display("$8  = %x  $9  = %x  $10 = %x  $11 = %x", r[ 8], r[ 9], r[10], r[11]);
  $display("$12 = %x  $13 = %x  $14 = %x  $15 = %x", r[12], r[13], r[14], r[15]);
  $display("$16 = %x  $17 = %x  $18 = %x  $19 = %x", r[16], r[17], r[18], r[19]);
  $display("$20 = %x  $21 = %x  $22 = %x  $23 = %x", r[20], r[21], r[22], r[23]);
  $display("$24 = %x  $25 = %x  $26 = %x  $27 = %x", r[24], r[25], r[26], r[27]);
  $display("$28 = %x  $29 = %x  $30 = %x  $31 = %x", r[28], r[29], r[30], r[31]);

  if (reset) begin
    $display("RESET");
    halt <= 0;
    PC <= 0;
    STATE <= 0;
    strobe <= 0;
  end else begin
    if (mfc) MDR = dread;
    $display("STATE %8d", STATE);
    case (STATE)
	 // fetch and decode an instruction
      0: begin `PCout `Yin `MARin `MEMread `NEXT end
      1: begin `CONST(4) `ALUadd `ALUZin `UNTILmfc end
      2: begin `MDRout `IRin `NEXT end
      3: begin `ALUZout `PCin `JUMPonop end

	 // MIPS add instruction
      5: begin `SELrs `REGout `Yin `NEXT end
      6: begin `SELrt `REGout `ALUadd `ALUZin `NEXT end
      7: begin `ALUZout `SELrd `REGin `JUMP(0) end

	 // Additional instructions go here...
    


   // PAUL G
   // Set Less Than Immediate Instruction
      600: begin end
      601: begin end
      602: begin end
      603: begin end
      604: begin end
      605: begin end
      606: begin end
      607: begin end
      608: begin end
      609: begin end
      610: begin end
   // PAUL G
   // Atomic Increment Instruction
      500: begin end 
      501: begin end 
      502: begin end 
      503: begin end 
      504: begin end 
   // DEFAULT CASE
      default: begin `HALT end
    endcase
    STATE <= NEWSTATE;
  end

  $display();
end
endmodule

// Testbench
module bench;
reg reset = 1;
reg clk = 0;
wire halt;

processor PE(halt, reset, clk);

initial begin
  #`CLKDEL clk = 1;
  #`CLKDEL clk = 0;
  reset = 0;
  while (($time < `RUNTIME) && !halt) begin
    #`CLKDEL clk = 1;
    #`CLKDEL clk = 0;
  end
end
endmodule


