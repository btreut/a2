MODULE FoxTRMAssembler; (** AUTHOR ""; PURPOSE ""; *)

IMPORT InstructionSet := FoxTRMInstructionSet, FoxAssembler, D := Debugging, Scanner := FoxScanner, Diagnostics;

CONST Trace=FoxAssembler.Trace;

TYPE
	Register* = LONGINT; (* index for InstructionSet.registers *)
	Operand* = InstructionSet.Operand;

TYPE
	Assembler*= OBJECT (FoxAssembler.Assembler)
	VAR capabilities-: SET;
		  instructionSet: InstructionSet.InstructionSet;

		PROCEDURE &Init2*(diagnostics: Diagnostics.Diagnostics; capabilities: SET; instructionSet: InstructionSet.InstructionSet);
		BEGIN
			SELF.capabilities := capabilities;
			SELF.instructionSet:=instructionSet;
			Init(diagnostics);
		END Init2;

		PROCEDURE Instruction*(CONST mnemonic: ARRAY OF CHAR);
		VAR i,numberOperands,mnem,pos: LONGINT; VAR operands: ARRAY 3 OF Operand; instruction: InstructionSet.Instruction;

			PROCEDURE ParseOperand;
			(* stub, must be overwritten by implementation *)
			VAR operand: InstructionSet.Operand;
				result: FoxAssembler.Result;
				register1,register2: SHORTINT;
				stop,memory: BOOLEAN;
			BEGIN
				stop := FALSE;
				register1 := InstructionSet.None;
				register2 := InstructionSet.None;
				result.type := -1;
				result.value := 0;

				IF numberOperands >= 2 THEN Error(errorPosition,"too many operands")
				ELSE
					memory := ThisToken(Scanner.LeftBracket);
					IF (symbol.token = Scanner.Identifier) & GetRegister(symbol.identifierString,register1) THEN
						NextSymbol;
						stop := ~ThisToken(Scanner.Plus);
					END;
					IF ~stop THEN
						IF (symbol.token = Scanner.Identifier) THEN
							IF GetRegister(symbol.identifierString,register2) THEN
								NextSymbol;
							ELSIF GetNonConstant(errorPosition,symbol.identifierString, result) THEN
								NextSymbol;
							ELSIF Expression(result,FALSE) THEN
							END;
						ELSIF Expression(result,FALSE) THEN
						END;
					END;
					IF memory & ExpectToken(Scanner.RightBracket) THEN
						instructionSet.InitMemory(operand,register1,result.value);
					ELSIF register1 # -1 THEN
						instructionSet.InitRegister(operand,register1);
					ELSE
						instructionSet.InitImmediate(operand,result.sizeInBits,result.value);
					END;
					IF result.fixup # NIL THEN
						instructionSet.AddFixup(operand,result.fixup);
					END;
					operands[numberOperands] := operand;
				END;
			END ParseOperand;

		BEGIN
			IF Trace THEN
				D.String("Instruction: "); D.String(mnemonic);  D.String(" "); D.Ln;
			END;
			pos := errorPosition;
			mnem := instructionSet.FindMnemonic(mnemonic);
			IF mnem >= 0 THEN
				FOR i := 0 TO 2 DO instructionSet.InitOperand(operands[i]) END;
				numberOperands := 0;
				IF symbol.token # Scanner.Ln THEN
					REPEAT
						ParseOperand;
						INC(numberOperands);
					UNTIL error OR ~ThisToken(Scanner.Comma);
				END;
				IF ~error THEN
					instructionSet.MakeInstruction(instruction,mnem,operands[0],operands[1]);
					IF instruction.format = InstructionSet.None THEN
						ErrorSS(pos,"operand instruction format mismatch",mnemonic);
					ELSIF instructionSet.instructionFormats[instruction.format].capabilities > capabilities THEN
						Error(pos,"instruction not supported");
					ELSE
						IF pass < FoxAssembler.MaxPasses THEN
							(* not last pass: only increment the current PC by a unit *)
							section.resolved.SetPC(section.resolved.pc + 1)
						ELSE
							instructionSet.EmitInstruction(instruction, mnem, section.resolved);
						END;
					END;
				END
			ELSE
				ErrorSS(pos,"unknown instruction ",mnemonic)
			END
		END Instruction;
		
		PROCEDURE GetRegister(CONST ident: ARRAY OF CHAR; VAR register: SHORTINT): BOOLEAN;
		BEGIN
			register := instructionSet.FindRegister(ident);
			RETURN register # InstructionSet.None
		END GetRegister;
	END Assembler;

	


END FoxTRMAssembler.

SystemTools.Free FoxTRMAssembler FoxTRMInstructionSet ~





