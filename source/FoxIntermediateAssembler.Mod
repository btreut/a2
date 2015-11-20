MODULE FoxIntermediateAssembler; (** AUTHOR ""; PURPOSE ""; *)

IMPORT IntermediateCode := FoxIntermediateCode, FoxAssembler, D := Debugging, Scanner := FoxScanner;

CONST Trace=FoxAssembler.Trace;
TYPE
	Register* = LONGINT; (* index for InstructionSet.registers *)
	Operand* = IntermediateCode.Operand;

	TYPE
	Assembler*= OBJECT (FoxAssembler.Assembler)

		PROCEDURE Instruction*(CONST mnemonic: ARRAY OF CHAR);
		VAR i,numberOperands,mnem,pos: LONGINT; VAR operands: ARRAY 3 OF Operand; instruction: IntermediateCode.Instruction;

			PROCEDURE ParseOperand;
			(* stub, must be overwritten by implementation *)
			VAR operand: IntermediateCode.Operand;
				result: FoxAssembler.Result;
				register1,register2:LONGINT;
				class1, class2: IntermediateCode.RegisterClass;
				stop,memory: BOOLEAN;
			BEGIN
				stop := FALSE;
				register1 := IntermediateCode.None;
				register2 := IntermediateCode.None;
				result.type := -1;
				result.value := 0;

				IF numberOperands >= 3 THEN Error(errorPosition,"too many operands")
				ELSE
					memory := ThisToken(Scanner.LeftBracket);
					IF (symbol.token = Scanner.Identifier) & IntermediateCode.DenotesRegister(symbol.identifierString,class1,register1) THEN
						NextSymbol;
						stop := ~ThisToken(Scanner.Plus);
					END;
					IF ~stop THEN
						IF (symbol.token = Scanner.Identifier) THEN
							IF IntermediateCode.DenotesRegister(symbol.identifierString,class2,register2) THEN
								NextSymbol;
							ELSIF GetNonConstant(errorPosition,symbol.identifierString,result) THEN
								NextSymbol;
							ELSIF Expression(result,FALSE) THEN
							END;
						ELSIF Expression(result,FALSE) THEN
						END;
					END;
					IF memory & ExpectToken(Scanner.RightBracket) THEN
						(*
						IntermediateCode.InitMemory(operand,register1,register2,result.value);
						*)
					ELSIF register1 # -1 THEN
						(*
						IntermediateCode.InitRegister(operand,0,register1);
						*)
					ELSE
						(*
						IntermediateCode.InitImmediate(operand,result.sizeInBits,result.value);
						*)
					END;
					(*
					IF result.fixup # NIL THEN
						IntermediateCode.AddFixup(operand,result.fixup);
					END;
					*)
					operands[numberOperands] := operand;
				END;
			END ParseOperand;

		BEGIN
			IF Trace THEN
				D.String("Instruction: "); D.String(mnemonic);  D.String(" "); D.Ln;
			END;
			pos := errorPosition;
			mnem := IntermediateCode.FindMnemonic(mnemonic);
			IF mnem >= 0 THEN
				FOR i := 0 TO 2 DO IntermediateCode.InitOperand(operands[i]) END;
				numberOperands := 0;
				IF symbol.token # Scanner.Ln THEN
					REPEAT
						ParseOperand;
						INC(numberOperands);
					UNTIL error OR ~ThisToken(Scanner.Comma);
				END;

				IF ~error THEN
					IntermediateCode.InitInstruction(instruction, 0, SHORTINT(mnem), operands[0], operands[1], operands[2]);
					section.Emit(instruction);
					(*

					mnem,operands[0],operands[1],operands[2],section.resolved);
					*)
				END

			ELSE
				ErrorSS(pos,"unknown instruction ",mnemonic)
			END
		END Instruction;

	END Assembler;



END FoxIntermediateAssembler.

SystemTools.Free FoxInlineAssembler FoxInlineInstructionSet ~





