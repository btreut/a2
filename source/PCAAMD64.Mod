MODULE PCAAMD64;	(** AUTHOR "negelef"; PURPOSE "AMD64 assembler"; *)

IMPORT
	SYSTEM, Modules, Commands, Streams, CompilerInterface, PCLIR, PCP, PCS, PCT, PCBT, PCM, Diagnostics,
	Texts, TextUtilities, Files, ASM := ASMAMD64, StringPool, Strings;

CONST
	maxName = 128;	(* maximum name length for labels and identifiers*)
	maxPasses = 2;		(* two pass assembler *)

	binSuffix = ".Bin";

	(* scanner codes *)
	TAB = 09X;
	LF = 0AX;
	CR = 0DX;
	SPACE = 20X;

	(* symbol values *)
	symNone = 0;
	symIdent = 1;
	symLabel = 2;
	symNumber = 3;
	symSemicolon = 4;
	symColon = 5;
	symLn = 6;
	symComma = 7;
	symString = 8;
	symPlus = 9;
	symMinus = 10;
	symTimes = 11;
	symDiv = 12;
	symLParen = 13;
	symRParen = 14;
	symLBrace = 15;
	symRBrace = 16;
	symLBraket = 17;
	symRBraket = 18;
	symPC = 19;
	symPCOffset = 20;
	symNegate = 21;
	symComposite = 22;
	symMod = 23;
	symPeriod = 24;

	(* rex prefix bit positions *)
	rexB = 0;
	rexX = 1;
	rexR = 2;
	rexW= 3;
	rex = 4;

	rAX = 0;
	rCX = 1;
	rDX = 2;
	rBX = 3;
	rSP = 4;
	rBP = 5;
	rSI = 6;
	rDI = 7;
	r8 = 8;
	r9 = 9;
	r10 = 10;
	r11 = 11;
	r12 = 12;
	r13 = 13;
	r14 = 14;
	r15 = 15;
	rIP = 16;

	(* segment registers *)
	segES = 0;
	segCS = 1;
	segSS = 2;
	segDS = 3;
	segFS = 4;
	segGS = 5;

	regIP = 109;
	regRIP = 110;

	(* sizes *)
	default* = 0;
	size8 = 8;
	size16 = 16;
	size32 = 32;
	size64 = 64;
	size128 = 128;

TYPE
	Name = ARRAY maxName OF CHAR;

	Size = LONGINT;

	Label = POINTER TO RECORD;
		name: Name;
		pc, pass: LONGINT;
		equ: BOOLEAN;
		next: Label;
	END;

	Operand* = OBJECT (PCLIR.InstructionAttribute)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		END Matches;

	END Operand;

	Reg* = OBJECT (Operand)
	VAR
		index-: LONGINT;

		PROCEDURE &New *(i: LONGINT);
		BEGIN index := i END New;

	END Reg;

	Reg8* = OBJECT (Reg)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			CASE type OF
			ASM.reg8, ASM.regmem8:
				RETURN TRUE;
			| ASM.AL, ASM.rAX:
				RETURN index = rAX;
			| ASM.CL:
				RETURN index = rCX;
			ELSE
				RETURN FALSE;
			END;
		END Matches;

	END Reg8;

	MemReg = OBJECT (Reg)
	END MemReg;

	Reg16* = OBJECT (MemReg)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			CASE type OF
			ASM.reg16, ASM.regmem16:
				RETURN TRUE;
			| ASM.AX, ASM.rAX:
				RETURN index = rAX;
			| ASM.DX:
				RETURN index = rDX;
			ELSE
				RETURN FALSE;
			END;
		END Matches;

	END Reg16;

	Reg32* = OBJECT (MemReg)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			CASE type OF
			ASM.reg32, ASM.regmem32:
				RETURN TRUE;
			| ASM.EAX, ASM.rAX:
				RETURN index = rAX;
			ELSE
				RETURN FALSE;
			END;
		END Matches;

	END Reg32;

	Reg64* = OBJECT (MemReg)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			CASE type OF
			ASM.reg64, ASM.regmem64:
				RETURN TRUE;
			| ASM.RAX, ASM.rAX:
				RETURN index = rAX;
			ELSE
				RETURN FALSE;
			END;
		END Matches;

	END Reg64;

	RegCR* = OBJECT (Reg)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			CASE type OF
			ASM.CRn:
				RETURN TRUE;
			| ASM.CR8:
				RETURN index = 8;
			ELSE
				RETURN FALSE;
			END;
		END Matches;

	END RegCR;

	RegDR* = OBJECT (Reg)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			RETURN type = ASM.DRn;
		END Matches;

	END RegDR;

	SegReg* = OBJECT (Reg)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			CASE type OF
			ASM.segReg:
				RETURN TRUE;
			| ASM.ES:
				RETURN index = segES;
			| ASM.CS:
				RETURN index = segCS;
			| ASM.SS:
				RETURN index = segSS;
			| ASM.DS:
				RETURN index = segDS;
			| ASM.FS:
				RETURN index = segFS;
			| ASM.GS:
				RETURN index = segGS;
			ELSE
				RETURN FALSE;
			END
		END Matches;

	END SegReg;

	FPReg* = OBJECT (Reg)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			CASE type OF
			ASM.sti:
				RETURN TRUE;
			| ASM.st0:
				RETURN index = 0;
			ELSE
				RETURN FALSE;
			END
		END Matches;

	END FPReg;

	MMXReg* = OBJECT (Reg)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			CASE type OF
			ASM.mmx, ASM.mmxmem32, ASM.mmxmem64:
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END
		END Matches;

	END MMXReg;

	XMMReg* = OBJECT (Reg)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			CASE type OF
			ASM.xmm, ASM.xmmmem32, ASM.xmmmem64, ASM.xmmmem128:
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END
		END Matches;

	END XMMReg;

	Mem* = OBJECT (Operand)
	VAR
		size-: Size;
		seg, reg, index: Reg;
		scale, displacement: LONGINT;
		fixup: PCM.Attribute;

		PROCEDURE &New *(s: Size);
		BEGIN size := s; displacement := 0; scale := 1
		END New;

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			CASE type OF
			| ASM.mem:
				RETURN TRUE;
			| ASM.mem8:
				RETURN (size = default) OR (size = size8);
			| ASM.regmem8:
				RETURN ((size = default) OR (size = size8)) & ((reg = NIL) OR (reg IS MemReg));
			| ASM.mem16:
				RETURN (size = default) OR (size = size16);
			| ASM.regmem16:
				RETURN ((size = default) OR (size = size16)) & ((reg = NIL) OR (reg IS MemReg));
			| ASM.mem32:
				RETURN (size = default) OR (size = size32);
			| ASM.regmem32, ASM.mmxmem32, ASM.xmmmem32:
				RETURN ((size = default) OR (size = size32)) & ((reg = NIL) OR (reg IS MemReg));
			| ASM.mem64:
				RETURN (size = default) OR (size = size64);
			| ASM.regmem64, ASM.mmxmem64, ASM.xmmmem64:
				RETURN ((size = default) OR (size = size64)) & ((reg = NIL) OR (reg IS MemReg));
			| ASM.mem128:
				RETURN (size = default) OR (size = size128);
			| ASM.xmmmem128:
				RETURN ((size = default) OR (size = size128)) & ((reg = NIL) OR (reg IS MemReg));
			| ASM.moffset8:
				RETURN ((size = default) OR (size = size8)) & (reg = NIL);
			| ASM.moffset16:
				RETURN ((size = default) OR (size = size16)) & (reg = NIL);
			| ASM.moffset32:
				RETURN ((size = default) OR (size = size32)) & (reg = NIL);
			| ASM.moffset64:
				RETURN ((size = default) OR (size = size64)) & (reg = NIL);
			ELSE
				RETURN FALSE;
			END;
		END Matches;

	END Mem;

	Imm* = OBJECT (Operand)
	VAR
		size: Size;
		val-: HUGEINT;
		pc-: LONGINT;
		fixup: PCM.Attribute;

		PROCEDURE &New *(s: Size; v: HUGEINT);
		BEGIN size:= s; val := v; pc := -1
		END New;

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			CASE type OF
			ASM.one:
				RETURN val = 1
			| ASM.three:
				RETURN val = 3
			| ASM.rel8off:
				RETURN (size = default) OR (size = size8)
			| ASM.imm8:
				RETURN ((size = default) OR (size = size8)) & (val >= -80H) & (val < 100H)
			| ASM.simm8:
				RETURN ((size = default) OR (size = size8)) & (val >= -80H) & (val < 80H)
			| ASM.uimm8:
				RETURN ((size = default) OR (size = size8)) & (val >= 0H) & (val < 100H)
			| ASM.rel16off:
				RETURN (size = default) OR (size = size16)
			| ASM.imm16:
				RETURN ((size = default) OR (size = size16)) & (val >= -8000H) & (val < 10000H)
			| ASM.simm16:
				RETURN ((size = default) OR (size = size16)) & (val >= -8000H) & (val < 8000H)
			| ASM.uimm16:
				RETURN ((size = default) OR (size = size16)) & (val >= 0H) & (val < 10000H)
			| ASM.rel32off:
				RETURN (size = default) OR (size = size32)
			| ASM.imm32:
				RETURN ((size = default) OR (size = size32)) (* & & (val >= -80000000H) & (val < 100000000H)  PACO confused? *)
			| ASM.simm32:
				RETURN ((size = default) OR (size = size32)) (* & & (val >= -80000000H) & (val < 80000000H)  PACO confused? *)
			| ASM.uimm32:
				RETURN ((size = default) OR (size = size32)) & (val >= 0H) (*  & (val < 100000000H)  PACO confused? *)
			| ASM.imm64:
				RETURN (size = default) OR (size = size64)
			ELSE
				RETURN FALSE
			END
		END Matches;

	END Imm;

	Offset* = OBJECT (Imm)
	END Offset;

	Pntr1616 = OBJECT (Operand)
	VAR
		selector, offset: LONGINT;

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN RETURN type = ASM.pntr1616;
		END Matches;

		PROCEDURE &New *(s, o: LONGINT);
		BEGIN selector := s; offset := o
		END New;

	END Pntr1616;

	Pntr1632 = OBJECT (Pntr1616)

		PROCEDURE Matches (type: ASM.OperandType): BOOLEAN;
		BEGIN
			RETURN type = ASM.pntr1632;
		END Matches;

	END Pntr1632;

	Assembly* = OBJECT (PCLIR.AsmInline)

		VAR
			pc-, pcOffset, errPos*: LONGINT;
			current: PCLIR.AsmBlock;
			bits: Size;
			cpuoptions: ASM.CPUOptions;
			firstLabel: Label;
			diagnostics: Diagnostics.Diagnostics;
			listing: Streams.Writer;

		PROCEDURE &Init *(d: Diagnostics.Diagnostics; list: Streams.Writer);
		BEGIN
			NEW (code);
			Reset;
			current.len := 0;
			diagnostics := d;
			listing := list;
		END Init;

		PROCEDURE Reset*;
		BEGIN
			current := code;
			pc := 0;
			pcOffset := 0;
			bits := 64;
			cpuoptions := {ASM.cpu8086 .. ASM.cpuAMD64} + ASM.cpuOptions;
		END Reset;

		PROCEDURE SetPC* (newPC: LONGINT);
		BEGIN
			current := code;
			pc := newPC;
			pcOffset := 0;
			WHILE newPC - pcOffset > current.len DO
				INC (pcOffset, current.len);
				current := current.next;
			END;
		END SetPC;

		PROCEDURE AddFixup (adr: PCM.Attribute; offset: LONGINT);
		VAR asmFixup: PCLIR.AsmFixup;
		BEGIN
			NEW (asmFixup);
			asmFixup.offset := offset;
			asmFixup.adr := adr;
			asmFixup.next := fixup;
			fixup := asmFixup;
		END AddFixup;

		PROCEDURE PutByte* (b: LONGINT);
		BEGIN
			IF pc - pcOffset = LEN (current.code) THEN
				IF current.next = NIL THEN
					NEW (current.next);
					current.next.len := 0;
				END;
				INC (pcOffset, current.len);
				current := current.next;
			END;
			current.code[pc - pcOffset] := SYSTEM.VAL (CHAR, b);
			IF (current.len = pc - pcOffset) THEN INC (current.len) END;
			INC (pc);
		END PutByte;

		PROCEDURE GetByte* (): CHAR;
		BEGIN
			IF pc - pcOffset = current.len THEN
				INC (pcOffset, current.len);
				current := current.next;
			END;
			INC (pc);
			RETURN current.code[pc - pcOffset - 1];
		END GetByte;

		PROCEDURE GetWord* (): INTEGER;
		VAR word: INTEGER;
		BEGIN
			word := ORD (GetByte ());
			INC (word, ORD (GetByte ()) * 100H);
			RETURN word;
		END GetWord;

		PROCEDURE GetDWord* (): LONGINT;
		VAR dword, byte: LONGINT;
		BEGIN
			dword := ORD (GetByte ());
			INC (dword, LONG (ORD (GetByte ())) * 100H);
			INC (dword, LONG (ORD (GetByte ())) * 10000H);
			byte := LONG (ORD (GetByte ()));
			IF byte >= 128 THEN DEC (byte, 256) END;
			RETURN dword + byte * 1000000H;
		END GetDWord;

		PROCEDURE PutWord* (w: LONGINT);
		BEGIN
			PutByte (w MOD 100H);
			PutByte ((w DIV 100H) MOD 100H);
		END PutWord;

		PROCEDURE PutDWord* (d: LONGINT);
		BEGIN
			PutByte (d MOD 100H);
			PutByte ((d DIV 100H) MOD 100H);
			PutByte ((d DIV 10000H) MOD 100H);
			PutByte ((d DIV 1000000H) MOD 100H);
		END PutDWord;

		PROCEDURE PutQWord* (q: HUGEINT);
		VAR d: LONGINT;
		BEGIN
			SYSTEM.GET (ADDRESSOF (q), d);
			PutDWord (d);
			SYSTEM.GET (ADDRESSOF (q) + 4, d);
			PutDWord (d);
		END PutQWord;

		PROCEDURE Put (data: LONGINT; size: Size);
		BEGIN
			CASE size OF
			size8: PutByte (data);
			| size16: PutWord (data);
			| size32: PutDWord (data);
			END
		END Put;

		PROCEDURE InsertLabel (CONST name: ARRAY OF CHAR): Label;
		VAR label: Label;
		BEGIN
			label := GetLabel (name);
			IF label = NIL THEN
				NEW (label);
				COPY (name, label.name);
				label.next := firstLabel;
				label.pass := -1;
				label.equ := FALSE;
				firstLabel := label;
			END;
			RETURN label;
		END InsertLabel;

		PROCEDURE GetLabel (CONST name: ARRAY OF CHAR): Label;
		VAR label: Label;
		BEGIN
			label := firstLabel;
			WHILE (label # NIL) & (label.name # name) DO label := label.next END;
			RETURN label;
		END GetLabel;

		PROCEDURE Assemble (scan: PCS.Scanner;  scope: PCT.Scope;  exported, inlined, inlineAssembly: BOOLEAN);
		VAR
			scanner: PCS.Scanner;
			symbol, reg: LONGINT;
			ident, idents: Name;
			val, times, val2, val3: LONGINT;
			currentLabel: Label;
			prevPC: LONGINT;
			pass: LONGINT;
			absoluteMode: BOOLEAN;
			absoluteOffset: LONGINT;
			orgOffset: LONGINT;

			PROCEDURE NextChar;
			BEGIN IF (listing # NIL) & (pass = maxPasses) THEN listing.Char (scanner.ch) END; scanner.NextChar
			END NextChar;

			PROCEDURE SkipBlanks;
			BEGIN
				(* tf returns 01X when an embedded object is encountered *)
				WHILE (scanner.ch = SPACE) OR (scanner.ch = TAB) OR (scanner.ch = 01X) DO NextChar END;
				IF scanner.ch = ";" THEN
					WHILE (scanner.ch # CR) & (scanner.ch # LF) DO NextChar END	(* Skip comments *)
				END;
			END SkipBlanks;

			PROCEDURE GetNumber (VAR intval: LONGINT);
			VAR i, m, n: INTEGER; dig: ARRAY 24 OF CHAR;
			BEGIN
				i := 0; m := 0; n := 0;
				WHILE ('0' <= scanner.ch) & (scanner.ch <= '9') OR ('A' <= CAP (scanner.ch)) & (CAP (scanner.ch) <= 'F') DO
					IF  (m > 0) OR (scanner.ch # "0") THEN (* ignore leading zeros *)
						IF n < LEN(dig) THEN dig[n] := scanner.ch; INC(n) END;
						INC(m)
					END;
					NextChar; INC(i)
				END;

				IF n = m THEN intval := 0; i := 0;
					IF CAP (scanner.ch) = "H" THEN NextChar;
						IF (n = PCM.MaxHDig) & (dig[0] > "7") THEN (* prevent overflow *) intval := -1 END;
						WHILE i < n DO intval := intval * 10H + HexOrd (dig[i]); INC(i) END;
					ELSE
						IF (n = PCM.MaxHDig) & (dig[0] > "7") THEN (* prevent overflow *) intval := -1 END;
						WHILE i < n DO intval := intval * 10 + Ord (dig[i]); INC(i) END
					END
				END;
			END GetNumber;

			PROCEDURE GetIdentifier;
			VAR i: LONGINT;
			BEGIN
				i := 0;
				REPEAT
					IF i < maxName - 1 THEN
						IF ('0' <= scanner.ch) & (scanner.ch <= '9') THEN
							ident[i] := scanner.ch; idents[i] := scanner.ch;
						ELSE
							ident[i] := CAP (scanner.ch); idents[i] := scanner.ch; END;
						INC (i);
					END;
					NextChar
				UNTIL ~((('A' <= CAP(scanner.ch)) & (CAP(scanner.ch) <= 'Z')) OR (('0' <= scanner.ch) & (scanner.ch <= '9')));
				ident[i] := 0X; idents[i] := 0X;
			END GetIdentifier;

			PROCEDURE GetString;
			VAR i: LONGINT;
			BEGIN
				i := 0;
				NextChar;
				WHILE (scanner.ch # "'") & (i < maxName - 1) DO
					ident[i] := scanner.ch; INC (i);
					NextChar;
				END;
				ident[i] := 0X;
				NextChar;
			END GetString;

			PROCEDURE NextSymbol;
			BEGIN
				SkipBlanks;
				errPos := scanner.curpos - 1;

				CASE scanner.ch OF
				'A' .. 'Z', 'a' .. 'z' :
					GetIdentifier;
					SkipBlanks;
					IF scanner.ch = ':' THEN
						NextChar; symbol := symLabel;
					ELSE
						symbol := symIdent;
					END;
				| '0' .. '9':
					GetNumber (val);
					symbol := symNumber;
				| "'": GetString;
					symbol := symString;
				| '.': symbol := symPeriod;
					NextChar;
				| ';': symbol := symSemicolon;
					NextChar;
				| ':': symbol := symColon;
					NextChar;
				| CR, LF: symbol := symLn;
					NextChar;
				| ',': symbol := symComma;
					NextChar;
				| '+': symbol := symPlus;
					NextChar;
				| '-': symbol := symMinus;
					NextChar;
				| '*': symbol := symTimes;
					NextChar;
				| '/': symbol := symDiv;
					NextChar;
				| '%': symbol := symMod;
					NextChar;
				| '~': symbol := symNegate;
					NextChar;
				| '(': symbol := symLParen;
					NextChar;
				| ')': symbol := symRParen;
					NextChar;
				| '[': symbol := symLBraket;
					NextChar;
				| ']': symbol := symRBraket;
					NextChar;
				| '{': symbol := symLBrace;
					NextChar;
				| '}': symbol := symRBrace;
					NextChar;
				| '$': NextChar;
					IF scanner.ch = '$' THEN
						symbol := symPCOffset; NextChar;
					ELSE
						symbol := symPC;
					END
				ELSE
					symbol := symNone;
					NextChar;
				END;
			END NextSymbol;

			PROCEDURE SkipLine;
			BEGIN
				WHILE (symbol # symLn) & (symbol # symNone) DO
					NextSymbol;
				END;
			END SkipLine;

			PROCEDURE Ensure (desiredSymbol, errNumber : LONGINT) : BOOLEAN;
			BEGIN
				IF symbol = desiredSymbol THEN
					NextSymbol;
					RETURN TRUE;
				ELSE
					PCM.Error (errNumber, errPos, "");
					RETURN FALSE;
				END;
			END Ensure;

			PROCEDURE SetBits (newBits: LONGINT): BOOLEAN;
			BEGIN
				CASE newBits OF
				16: bits := size16;
				| 32: bits := size32;
				| 64: bits := size64;
				ELSE
					PCM.Error (553, errPos, ""); RETURN FALSE;
				END;
				RETURN TRUE;
			END SetBits;

			PROCEDURE GetCPU (cumulateOptions: BOOLEAN): BOOLEAN;
			VAR i: LONGINT;
			BEGIN
				SkipBlanks;
				GetIdentifier;
				i := ASM.FindCPU (ident);
				IF i # ASM.none THEN
					IF cumulateOptions THEN
						cpuoptions := cpuoptions + ASM.cpus[i].cpuoptions;
					ELSE
						cpuoptions := ASM.cpus[i].cpuoptions + ASM.cpuOptions;
					END;
					NextSymbol;
					RETURN TRUE;
				ELSE
					PCM.Error (552, errPos, ident);
					RETURN FALSE;
				END;
			END GetCPU;

			PROCEDURE GetScopeSymbol (ident: ARRAY OF CHAR): PCT.Symbol;
			VAR idx: LONGINT;
			BEGIN
				StringPool.GetIndex(ident, idx);
				RETURN PCT.Find (scope, scope, idx, PCT.procdeclared, TRUE);
			END GetScopeSymbol;

			PROCEDURE Factor (VAR x: LONGINT; critical: BOOLEAN): BOOLEAN;
			VAR label: Label; scopeSymbol: PCT.Symbol; l: LONGINT;
			BEGIN
				IF symbol = symNumber THEN
					x := val; NextSymbol; RETURN TRUE;
				ELSIF symbol = symPC THEN
					x := orgOffset + pc; NextSymbol; RETURN TRUE;
				ELSIF symbol = symPCOffset THEN
					x := orgOffset; NextSymbol; RETURN TRUE;
				ELSIF symbol = symString THEN
					x := 0; l := Strings.Length (ident);
					IF l > 0 THEN INC (x, ORD (ident [0])) END;
					IF l > 1 THEN INC (x, ORD (ident [1])*100H) END;
					IF l > 2 THEN INC (x, ORD (ident [2])*10000H) END;
					IF l > 3 THEN INC (x, ORD (ident [3])*1000000H) END;
					NextSymbol; RETURN TRUE;
				ELSIF symbol = symIdent THEN
					label := GetLabel (ident); NextSymbol;
					IF label # NIL THEN
						IF label.equ THEN
							x := label.pc;
						ELSE
							x := orgOffset + label.pc;
						END;
						RETURN TRUE;
					ELSIF inlineAssembly THEN
						scopeSymbol := GetScopeSymbol (idents);
						IF scopeSymbol # NIL THEN
							IF scopeSymbol IS PCT.Value THEN
								IF scopeSymbol.type = PCT.Char8 THEN
									x := scopeSymbol(PCT.Value).const.int
								ELSIF PCT.IsCardinalType(scopeSymbol.type) THEN
									x := scopeSymbol(PCT.Value).const.int
								ELSE
									PCM.Error(51, errPos, "");
									RETURN FALSE;
								END;
								RETURN TRUE;
							ELSIF pass = maxPasses THEN
								PCM.Error (560, errPos, idents);
								RETURN FALSE;
							END;
						END
					END;

					IF (~critical) & (pass # maxPasses) THEN
						x := 0;
						RETURN TRUE
					END;

					PCM.Error (554, errPos, idents);
					RETURN FALSE;

				ELSIF symbol = symLParen  THEN
					NextSymbol;
					RETURN Expression (x, critical) & Ensure (symRParen, 555);
				END;

				PCM.Error (555, errPos, "");
				RETURN FALSE
			END Factor;

			PROCEDURE Term (VAR x: LONGINT; critical: BOOLEAN): BOOLEAN;
			VAR y, op : LONGINT;
			BEGIN
				IF Factor (x, critical) THEN
					WHILE (symbol = symTimes) OR (symbol = symDiv) OR (symbol = symMod) DO
						op := symbol; NextSymbol;
						IF Factor (y, critical) THEN
							IF op = symTimes THEN x := x * y
							ELSIF op = symDiv THEN x := x DIV y
							ELSE x := x MOD y
							END;
						ELSE
							RETURN FALSE;
						END;
					END;
					RETURN TRUE;
				ELSE
					RETURN FALSE;
				END;
			END Term;

			PROCEDURE Expression (VAR x: LONGINT; critical: BOOLEAN): BOOLEAN;
			VAR y, op : LONGINT;
			BEGIN
				IF symbol = symMinus THEN
					op := symbol; NextSymbol;
					IF Term (x, critical) THEN
						x := -x
					ELSE
						RETURN FALSE;
					END;
				ELSIF symbol = symPlus THEN
					op := symbol; NextSymbol;
					IF ~Term (x, critical) THEN
						RETURN FALSE;
					END;
				ELSIF symbol = symNegate THEN
					op := symbol; NextSymbol;
					IF Term (x, critical) THEN
						x := -x - 1
					ELSE
						RETURN FALSE;
					END;
				ELSIF ~Term (x, critical) THEN
					RETURN FALSE;
				END;
				WHILE (symbol = symPlus) OR (symbol = symMinus) DO
					op := symbol; NextSymbol;
					IF Term (y, critical) THEN
						IF op = symPlus THEN x := x + y ELSE x := x - y END;
					ELSE
						RETURN FALSE;
					END;
				END;
				RETURN TRUE;
			END Expression;

			PROCEDURE PutData (size: Size): BOOLEAN;
			VAR i: LONGINT;
			BEGIN
				NextSymbol;

				WHILE symbol # symLn DO

					IF symbol = symString THEN
						i := 0;
						WHILE ident[i] # 0X DO
							PutByte (ORD (ident[i]));
							INC (i);
						END;
						IF size # size8 THEN
							i := (size DIV 8) - i MOD (size DIV 8);
							WHILE i # 0 DO PutByte (0); DEC (i) END;
						END;
						NextSymbol;
					ELSIF Expression (i, FALSE) THEN
						Put (i, size);
					ELSE
						RETURN FALSE;
					END;
					IF symbol = symComma THEN
						NextSymbol;
					ELSIF symbol # symLn THEN
						PCM.Error(511, errPos, "");
					END
				END;
				Duplicate (pc - prevPC, NIL);
				RETURN TRUE;
			END PutData;

			PROCEDURE Duplicate (size: LONGINT; fixup: PCLIR.AsmFixup);
			VAR i: LONGINT; buffer: ARRAY 100 OF CHAR;
			BEGIN
				IF times = 1 THEN RETURN END;

				SetPC (prevPC);

				IF times > 0 THEN
					IF (listing # NIL) & (pass = maxPasses) THEN listing.Hex (pc, 0); listing.Char (' ') END;
						FOR i := 0 TO size - 1 DO
						buffer[i] := GetByte ();
						IF (listing # NIL) & (pass = maxPasses) THEN listing.Hex (ORD (buffer[i]), -2); END;
					END;

					WHILE times # 1 DO
						IF fixup # NIL THEN
							AddFixup (fixup.adr, pc + fixup.offset - prevPC);
						END;
						FOR i := 0 TO size - 1 DO
							PutByte (ORD (buffer[i]));
							IF (listing # NIL) & (pass = maxPasses) THEN listing.Hex (ORD (buffer[i]), -2); END;
						END;
						DEC (times);
					END;
				ELSE
					times := 1;
				END;

				IF (listing # NIL) & (pass = maxPasses) THEN listing.Ln END;
			END Duplicate;

			PROCEDURE Reserve (size: Size) : BOOLEAN;
			BEGIN
				IF Expression (val2, TRUE) THEN
					absoluteOffset := absoluteOffset + val * size;
					RETURN TRUE;
				ELSE
					RETURN FALSE;
				END;
			END Reserve;

			PROCEDURE GetMemFixup (CONST ident: ARRAY OF CHAR; VAR mem: Mem);
			VAR scopeSymbol: PCT.Symbol;
			BEGIN
				scopeSymbol := GetScopeSymbol (ident);
				IF scopeSymbol = NIL THEN RETURN END;

				IF (scopeSymbol IS PCT.GlobalVar) THEN
					RETURN;
					IF ~inlined OR ~exported  THEN
						mem.displacement := scopeSymbol.adr(PCBT.GlobalVariable).offset;
					END;
				ELSIF scopeSymbol IS PCT.Parameter THEN
					mem.displacement := scopeSymbol.adr(PCBT.Variable).offset;
				ELSIF scopeSymbol IS PCT.Variable THEN
					mem.displacement := scopeSymbol.adr(PCBT.Variable).offset;
				ELSE
					RETURN;
				END;
				mem.fixup := scopeSymbol.adr;
				NextSymbol;
			END GetMemFixup;

			PROCEDURE GetOffsetFixup (CONST ident: ARRAY OF CHAR; VAR offset: Offset);
			VAR scopeSymbol: PCT.Symbol;
			BEGIN
				scopeSymbol := GetScopeSymbol (ident);
				IF scopeSymbol = NIL THEN RETURN END;

				IF (scopeSymbol IS PCT.GlobalVar) THEN
					IF ~inlined OR ~exported  THEN
						offset.val := scopeSymbol.adr(PCBT.GlobalVariable).offset;
					ELSE
						RETURN;
					END;
				ELSIF (scopeSymbol IS PCT.Proc) THEN
					IF ~inlined OR ~exported  THEN
						offset.val := scopeSymbol.adr(PCBT.Procedure).codeoffset;
					ELSE
						RETURN;
					END;
				ELSE
					RETURN;
				END;
				offset.size := size64;
				offset.fixup := scopeSymbol.adr;
			END GetOffsetFixup;

			PROCEDURE GetInstruction (): BOOLEAN;
			VAR
				mnem, opCount: LONGINT;
				size: Size;
				operands: ARRAY ASM.maxOperands OF Operand;
				prevFixup: PCLIR.AsmFixup;
				mem: Mem;
				offset: Offset;

			BEGIN
				mnem := ASM.FindMnem (ident);
				IF mnem = ASM.none THEN
					PCM.Error (554, errPos, idents);
					RETURN FALSE;
				END;

				opCount := 0;
				NextSymbol;

				WHILE (symbol # symLn) & (symbol # symNone) DO

					IF symbol = symIdent THEN
						IF (ident = "BYTE") OR (ident = "SHORT") THEN
							size := size8; NextSymbol;
						ELSIF (ident = "WORD") OR (ident = "NEAR") THEN
							size := size16; NextSymbol;
						ELSIF ident = "DWORD" THEN
							size := size32; NextSymbol;
						ELSIF ident = "QWORD" THEN
							size := size64; NextSymbol;
						ELSIF ident = "TWORD" THEN
							size := size128; NextSymbol;
						ELSE
							size := default;
						END;
					ELSE
						size := default;
					END;

					IF symbol = symIdent THEN
						reg := ASM.FindReg (ident);
						IF reg # ASM.none THEN
							IF size # default THEN
								PCM.Error (562, errPos, ""); RETURN FALSE;
							END;
							operands[opCount] := NewReg (ASM.registers[reg].type, ASM.registers[reg].index);
							INC (opCount);
							NextSymbol;
						END;
					ELSE
						reg := ASM.none;
					END;

					IF reg = ASM.none THEN
						IF symbol = symLBraket THEN
							NextSymbol;

							NEW (mem, size);

							operands[opCount] := mem;
							INC (opCount);

							IF symbol = symLabel THEN
								reg := ASM.FindReg (ident);
								IF reg = ASM.none THEN
									PCM.Error (554, errPos, idents); RETURN FALSE;
								END;
								mem.seg := NewReg (ASM.registers[reg].type, ASM.registers[reg].index);
								NextSymbol;
							END;

							IF symbol = symIdent THEN
								reg := ASM.FindReg (ident);
								IF reg # ASM.none THEN
									mem.reg := NewReg (ASM.registers[reg].type, ASM.registers[reg].index);
									NextSymbol;

									IF symbol = symTimes THEN
										NextSymbol;
										IF ~Factor (mem.scale, FALSE) THEN
											RETURN FALSE;
										END;
										mem.index := mem.reg;
										mem.reg := NIL;
									END;
									IF symbol = symPlus THEN
										NextSymbol;
										IF symbol = symIdent THEN
											reg := ASM.FindReg (ident);
											IF reg # ASM.none THEN
												NextSymbol;
												IF mem.index = NIL THEN
													mem.index := NewReg (ASM.registers[reg].type, ASM.registers[reg].index);
													IF symbol = symTimes THEN
														NextSymbol;
														IF ~Factor (mem.scale, FALSE) THEN
															RETURN FALSE;
														END;
													END;
												ELSE
													mem.reg := NewReg (ASM.registers[reg].type, ASM.registers[reg].index);
												END;
											END;
										END;
									END;
								END;
							END;

							IF symbol = symPlus THEN
								NextSymbol;
							END;

							IF inlineAssembly & (symbol = symIdent) THEN
								GetMemFixup (idents, mem);
							END;

							IF (symbol # symRBraket) & (symbol # symNegate) THEN
								val2 := 0;
								IF ~Expression (val2, FALSE) THEN
									RETURN FALSE;
								END;
								INC (mem.displacement, val2);
							ELSIF (mem.reg = NIL) & (mem.index = NIL) THEN
								PCM.Error (511, errPos, ""); RETURN FALSE;
							END;

							IF ~Ensure (symRBraket, 556) THEN
								RETURN FALSE;
							END;
						ELSE
							offset := NewOffset (size, val2);

							IF inlineAssembly & (symbol = symIdent) THEN
								GetOffsetFixup (idents, offset);
							END;

							IF offset.fixup = NIL THEN
								IF ~Expression (val2, FALSE) THEN
									RETURN FALSE;
								END;
								offset.val := val2;
								IF symbol = symColon THEN
									NextSymbol;
									IF ~Expression (val3, FALSE) THEN
										RETURN FALSE;
									END;
									operands[opCount] := NewOffset (default, val3);
									INC (opCount);
								END;
							ELSE
								NextSymbol;
							END;
							operands[opCount] := offset;
							INC (opCount);
						END;
					END;

					IF symbol = symComma THEN
						NextSymbol;
					ELSIF symbol # symLn THEN
						PCM.Error(511, errPos, "");
					END
				END;

				prevFixup := fixup;

				IF ~EmitInstr (mnem, operands, pass = maxPasses) THEN
					RETURN FALSE;
				END;

				IF fixup = prevFixup THEN
					Duplicate (pc - prevPC, NIL);
				ELSE
					Duplicate (pc - prevPC, fixup);
				END;

				RETURN TRUE;
			END GetInstruction;

		BEGIN

			FOR pass := 1 TO maxPasses DO
				scanner := PCS.ForkScanner (scan);
				Reset;
				times := 1;
				prevPC := pc;
				currentLabel := NIL;
				absoluteMode := FALSE;
				orgOffset := 0;

				NextSymbol;

				IF inlineAssembly THEN
					cpuoptions := {};
					IF ~Ensure (symLBrace, 550) THEN
						RETURN
					END;

					LOOP
						IF ~Ensure (symIdent, 551) THEN
							RETURN
						END;
						IF ident # "SYSTEM" THEN
							PCM.Error (552, errPos, ident); RETURN
						END;
						IF symbol # symPeriod THEN
							PCM.Error (551, errPos, ""); RETURN;
						END;
						IF ~GetCPU (TRUE) THEN
							RETURN;
						END;
						IF symbol = symRBrace THEN
							EXIT
						ELSIF symbol = symComma THEN
							NextSymbol
						ELSE
							PCM.Error (550, errPos, ident); RETURN;
						END;
					END;
					NextSymbol;
				END;

				LOOP
					IF (listing # NIL) & (pass = maxPasses) THEN listing.Char (9X); listing.Char (9X) END;
					IF symbol = symLn THEN
						NextSymbol;
					ELSIF symbol = symLabel THEN
						currentLabel := InsertLabel (ident);
						IF absoluteMode THEN
							currentLabel.pc := absoluteOffset;
						ELSE
							currentLabel.pc := pc;
						END;
						IF currentLabel.pass < pass THEN
							currentLabel.pass := pass;
						ELSE
							PCM.Error (1, errPos, ident);
						END;
						NextSymbol;
					ELSIF symbol = symIdent THEN
						IF ident = "END" THEN
							symbol := symNone;
						ELSIF ~inlineAssembly & (ident = "BITS") THEN
							NextSymbol;
							IF ~Ensure (symNumber, 553) OR ~SetBits (val) THEN
								SkipLine;
							ELSE
								NextSymbol;
							END;
						ELSIF ~inlineAssembly & (ident = "CPU") THEN
							IF ~GetCPU (FALSE) THEN
								SkipLine;
							END;
						ELSIF ~inlineAssembly & (ident = "ABSOLUTE") THEN
							absoluteMode := TRUE;
							NextSymbol;
							IF ~Expression (absoluteOffset, TRUE) THEN
								SkipLine;
							END;
						ELSIF ~inlineAssembly & (ident = "ORG") THEN
							NextSymbol;
							IF (orgOffset # 0) OR ~Expression (orgOffset, TRUE) THEN
								SkipLine;
							END;
						ELSIF ~inlineAssembly & (ident = "RESB") THEN
							NextSymbol;
							IF ~Reserve (1) THEN SkipLine END;
						ELSIF ~inlineAssembly & (ident = "RESW") THEN
							NextSymbol;
							IF ~Reserve (2) THEN SkipLine END;
						ELSIF ~inlineAssembly & (ident = "RESD") THEN
							NextSymbol;
							IF ~Reserve (4) THEN SkipLine END;
						ELSIF ident = "EQU" THEN
							IF currentLabel # NIL THEN
								NextSymbol;
								IF Expression (val2, FALSE) THEN
									currentLabel.pc := val2;
									currentLabel.equ := TRUE;
								ELSE
									SkipLine;
								END;
							ELSE
								PCM.Error (520, errPos, ""); RETURN;
							END;
						ELSIF ident = "TIMES" THEN
							NextSymbol;
							IF ~Expression (times, TRUE) THEN
								SkipLine;
							ELSIF times < 0 THEN
								PCM.Error (561, errPos, ""); RETURN;
							ELSE
								prevPC := pc;
							END;
						ELSIF ident = "DB" THEN
							IF ~PutData (size8) THEN SkipLine END;
						ELSIF ident = "DW" THEN
							IF ~PutData (size16) THEN SkipLine END;
						ELSIF ident = "DD" THEN
							IF ~PutData (size32) THEN SkipLine END;
						ELSIF ident = "REP" THEN
							NextSymbol;
							PutByte (ASM.prfREP);
						ELSIF ident = "LOCK" THEN
							NextSymbol;
							PutByte (ASM.prfLOCK);
						ELSIF ident = "REPE" THEN
							NextSymbol;
							PutByte (ASM.prfREPE);
						ELSIF ident = "REPZ" THEN
							NextSymbol;
							PutByte (ASM.prfREPZ);
						ELSIF ident = "REPNE" THEN
							NextSymbol;
							PutByte (ASM.prfREPNE);
						ELSIF ident = "REPNZ" THEN
							NextSymbol;
							PutByte (ASM.prfREPNZ);
						ELSIF ~GetInstruction () THEN
							SkipLine
						END;
						currentLabel := NIL;
					ELSIF symbol = symNone THEN
						EXIT
					ELSE
						PCM.Error (551, errPos, "");
						RETURN;
					END;
				END;
			END;
		END Assemble;

		PROCEDURE EmitPrefix* (prefix: LONGINT);
		BEGIN PutByte (prefix);
		END EmitPrefix;

		PROCEDURE Emit* (mnem: LONGINT; op1, op2, op3: Operand);
		VAR operands: ARRAY ASM.maxOperands OF Operand; res: BOOLEAN;
		BEGIN
			operands[0] := op1;
			operands[1] := op2;
			operands[2] := op3;

			res := EmitInstr (mnem, operands, TRUE);
		END Emit;

		PROCEDURE EmitInstr (mnem: LONGINT; operands: ARRAY OF Operand; lastPass: BOOLEAN): BOOLEAN;
		VAR instr, i, oppos, op: LONGINT;
			val: LONGINT;
			regOperand: LONGINT;
			addressOperand: LONGINT;
			regField, modField, rmField: LONGINT;
			scaleField, indexField, baseField: LONGINT;
			free: ARRAY ASM.maxOperands OF BOOLEAN;
			byte: LONGINT;
			offset: LONGINT;
			mem: Mem;
			lastPC: LONGINT;
			opPrefix, adrPrefix: BOOLEAN;
			segPrefix: LONGINT; rexPrefix: SET;

			PROCEDURE MatchesInstruction (): BOOLEAN;
			BEGIN
				FOR i := 0 TO ASM.maxOperands - 1 DO
					IF operands[i] = NIL THEN
						IF ASM.instructions[instr].operands[i] # ASM.none THEN RETURN FALSE END;
					ELSIF ~operands[i].Matches (ASM.instructions[instr].operands[i]) THEN
						RETURN FALSE
					ELSIF (bits = size64) & (ASM.optI64 IN ASM.instructions[instr].options) THEN
						RETURN FALSE;
					END;
				END;
				RETURN TRUE;
			END MatchesInstruction;

			PROCEDURE GetRegOperand (): LONGINT;
			VAR i: LONGINT;
			BEGIN
				FOR i := 0 TO ASM.maxOperands -1 DO
					CASE ASM.instructions[instr].operands[i] OF
					ASM.reg8, ASM.reg16, ASM.reg32, ASM.reg64, ASM.xmm, ASM.mmx:
						RETURN i;
					ELSE
					END;
				END;
				RETURN ASM.none;
			END GetRegOperand;

			PROCEDURE GetAddressOperand (): LONGINT;
			VAR i: LONGINT;
			BEGIN
				FOR i := 0 TO ASM.maxOperands -1 DO
					CASE ASM.instructions[instr].operands[i] OF
					ASM.mem,
					ASM.mem8, ASM.mem16, ASM.mem32, ASM.mem64, ASM.mem128,
					ASM.regmem8, ASM.regmem16, ASM.regmem32, ASM.regmem64,
					ASM.mmxmem32, ASM.mmxmem64,
					ASM.xmmmem32, ASM.xmmmem64, ASM.xmmmem128:
						RETURN i;
					ELSE
					END;
				END;
				RETURN ASM.none;
			END GetAddressOperand;

			PROCEDURE GetSpecialOperand (): LONGINT;
			VAR i: LONGINT;
			BEGIN
				FOR i := 0 TO ASM.maxOperands -1 DO
					CASE ASM.instructions[instr].operands[i] OF
					ASM.segReg, ASM.mmx, ASM.xmm, ASM.CRn, ASM.DRn:
						RETURN i;
					ELSE
					END;
				END;
				RETURN ASM.none;
			END GetSpecialOperand;

			PROCEDURE ModRM (mod, reg, rm: LONGINT);
			BEGIN PutByte (mod MOD 4 * 40H + reg MOD 8 * 8H + rm MOD 8);
			END ModRM;

			PROCEDURE SIB (scale, index, base: LONGINT);
			BEGIN PutByte (scale MOD 4 * 40H + index MOD 8 * 8H + base MOD 8);
			END SIB;

		BEGIN
			instr := ASM.mnemonics[mnem].firstInstr;

			WHILE (~MatchesInstruction ()) & (instr # ASM.mnemonics[mnem].lastInstr) DO INC (instr); END;

			IF instr = ASM.mnemonics[mnem].lastInstr THEN
				PCM.Error (557, errPos, ASM.mnemonics[mnem].name); RETURN FALSE;
			ELSIF ASM.instructions[instr].cpuoptions * cpuoptions # ASM.instructions[instr].cpuoptions THEN
				PCM.Error (558, errPos, ASM.mnemonics[mnem].name); RETURN FALSE;
			END;

			oppos := 0;
			val := -1;
			lastPC := pc;

			opPrefix := FALSE;
			adrPrefix := FALSE;
			segPrefix := ASM.none;
			rexPrefix := {};

			IF (ASM.optO16 IN ASM.instructions[instr].options) & (bits # size16) THEN
				opPrefix := TRUE;
			END;
			IF (ASM.optO32 IN ASM.instructions[instr].options) & (bits = size16) THEN
				opPrefix := TRUE;
			END;
			IF (ASM.optO64 IN ASM.instructions[instr].options) & (bits = size64) THEN
				INCL (rexPrefix, rexW)
			END;

			IF ASM.optPOP IN ASM.instructions[instr].options THEN
				opPrefix := TRUE;
			END;

			regOperand := GetSpecialOperand ();
			addressOperand := GetAddressOperand ();
			IF regOperand = ASM.none THEN
				regOperand := GetRegOperand ();
			END;
			IF addressOperand = ASM.none THEN
				addressOperand := GetRegOperand();
			END;

(*			KernelLog.String (ASM.mnemonics[mnem].name); KernelLog.Int (regOperand, 10); KernelLog.Int (addressOperand, 10); KernelLog.Ln; *)

			FOR i := 0 TO ASM.maxOperands - 1 DO
				IF operands[i] # NIL THEN
					IF operands[i] IS Mem THEN
						mem := operands[i](Mem);
						IF mem.seg # NIL THEN
							segPrefix := mem.seg.index;
						END;
						IF mem.reg # NIL THEN
							IF (mem.reg.index >= 8) THEN
								INCL (rexPrefix, rexB)
							END;
							IF (mem.reg IS Reg32) & (bits # size32) THEN
								adrPrefix := TRUE;
							END;
							IF mem.reg IS Reg16 THEN
								IF bits = size64 THEN
									PCM.Error (556, errPos, ""); RETURN FALSE;
								ELSIF bits = size32 THEN
									adrPrefix := TRUE;
								END;
							END;
						END;
						IF mem.index # NIL THEN
							IF (mem.index IS Reg64) & (mem.index.index >= 8) THEN
								INCL (rexPrefix, rexX)
							END
						END;
						IF (mem.size = size64) & ~(ASM.optD64 IN ASM.instructions[instr].options) THEN
							INCL (rexPrefix, rexW)
						END;
						IF ASM.instructions[instr].operands[i] = ASM.moffset64 THEN
							adrPrefix := TRUE;
						END;
					ELSIF operands[i] IS Reg THEN
						IF (operands[i] IS Reg64) & ~(ASM.optD64 IN ASM.instructions[instr].options) THEN
							INCL (rexPrefix, rexW)
						END;
						IF operands[i](Reg).index >= 8 THEN
							IF i = addressOperand THEN
								INCL (rexPrefix, rexB)
							ELSIF i = regOperand THEN
								INCL (rexPrefix, rexR)
							END;
						ELSIF (bits = size64) & (operands[i] IS Reg8) & (operands[i](Reg).index >= 4) THEN
							INCL (rexPrefix, rex);
						END;
					END;
				END;
				free[i] := operands[i] # NIL;
			END;

			CASE segPrefix OF
			ASM.none:
			| segES: PutByte (ASM.prfES);
			| segCS: PutByte (ASM.prfCS);
			| segSS: PutByte (ASM.prfSS);
			| segDS: PutByte (ASM.prfDS);
			| segFS: PutByte (ASM.prfFS);
			| segGS: PutByte (ASM.prfGS);
			END;

			IF opPrefix THEN PutByte (ASM.prfOP) END;
			IF adrPrefix THEN PutByte (ASM.prfADR) END;

			IF ASM.optPLOCK IN ASM.instructions[instr].options THEN PutByte (ASM.prfLOCK) END;
			IF ASM.optPREP IN ASM.instructions[instr].options THEN PutByte (ASM.prfREP) END;
			IF ASM.optPREPN IN ASM.instructions[instr].options THEN PutByte (ASM.prfREPNE) END;

			IF rexPrefix # {} THEN
				byte := 40H;
				IF rexB IN rexPrefix THEN byte := byte + 1H END;
				IF rexX IN rexPrefix THEN byte := byte + 2H END;
				IF rexR IN rexPrefix THEN byte := byte + 4H END;
				IF rexW IN rexPrefix THEN byte := byte + 8H END;
				PutByte (byte);
			END;

			op := 0;

			WHILE ASM.instructions[instr].opcode[oppos] # 0X DO
				IF ASM.instructions[instr].opcode[oppos] = 'i' THEN
					IF val # -1 THEN PutByte (val); val := -1 END;
					CASE ASM.instructions[instr].opcode[oppos + 1] OF
					'b': FOR i := 0 TO ASM.maxOperands - 1 DO
							IF (free[i]) & (operands[i] IS Imm) THEN
								offset := SHORT (operands[i](Imm).val);
								IF FALSE & lastPass & ~ValueInByteRange (offset) THEN
									PCM.Error (559, errPos, ""); RETURN FALSE;
								END;
								operands[i](Imm).pc := pc;
								PutByte (SHORT (operands[i](Imm).val));
								free[i] := FALSE; i:= ASM.maxOperands;
							END
						END;
					| 'w': FOR i := 0 TO ASM.maxOperands - 1 DO
							IF (free[i]) & (operands[i] IS Imm) THEN
								operands[i](Imm).pc := pc;
								PutWord (SHORT (operands[i](Imm).val));
								free[i] := FALSE; i:= ASM.maxOperands;
							END
						END;
					| 'd': FOR i := 0 TO ASM.maxOperands - 1 DO
							IF (free[i]) & (operands[i] IS Imm) THEN
								operands[i](Imm).pc := pc;
								PutDWord (SHORT (operands[i](Imm).val));
								free[i] := FALSE; i:= ASM.maxOperands;
							END
						END;
					| 'q': FOR i := 0 TO ASM.maxOperands - 1 DO
							IF (free[i]) & (operands[i] IS Imm) THEN
								operands[i](Imm).pc := pc;
								IF lastPass & (operands[i](Imm).fixup # NIL) THEN
									AddFixup (operands[i](Imm).fixup, pc);
								END;
								PutQWord (operands[i](Imm).val);
								free[i] := FALSE; i:= ASM.maxOperands;
							END
						END;
					END;
				ELSIF ASM.instructions[instr].opcode[oppos] = 'c' THEN
					IF val # -1 THEN PutByte (val); val := -1 END;
					CASE ASM.instructions[instr].opcode[oppos + 1] OF
					'b': FOR i := 0 TO ASM.maxOperands - 1 DO
							IF (free[i]) & (operands[i] IS Offset) THEN
								offset := SHORT (operands[i](Offset).val - pc - 1);
								IF lastPass & ~ValueInByteRange (offset) THEN
									PCM.Error (559, errPos, ""); RETURN FALSE;
								END;
								operands[i](Offset).pc := pc;
								PutByte (offset);
								free[i] := FALSE; i:= ASM.maxOperands;
							ELSIF (free[i]) & (operands[i] IS Imm) THEN
								offset := SHORT (operands[i](Imm).val);
								IF lastPass & ~ValueInByteRange (offset) THEN
									PCM.Error (559, errPos, ""); RETURN FALSE;
								END;
								operands[i](Imm).pc := pc;
								PutByte (offset);
								free[i] := FALSE; i:= ASM.maxOperands;
							END
						END;
					|'w': FOR i := 0 TO ASM.maxOperands - 1 DO
							IF (free[i]) & (operands[i] IS Offset) THEN
								offset := SHORT (operands[i](Offset).val - pc - 2);
								IF lastPass & ~ValueInWordRange (offset) THEN
									PCM.Error (559, errPos, ""); RETURN FALSE;
								END;
								operands[i](Offset).pc := pc;
								PutWord (offset);
								free[i] := FALSE; i:= ASM.maxOperands;
							ELSIF (free[i]) & (operands[i] IS Imm) THEN
								offset := SHORT (operands[i](Imm).val);
								IF lastPass & ~ValueInWordRange (offset) THEN
									PCM.Error (559, errPos, ""); RETURN FALSE;
								END;
								operands[i](Imm).pc := pc;
								PutWord (offset);
								free[i] := FALSE; i:= ASM.maxOperands;
							END
						END;
					|'d': FOR i := 0 TO ASM.maxOperands - 1 DO
							IF (free[i]) & (operands[i] IS Offset) THEN
								operands[i](Offset).pc := pc;
								PutDWord (SHORT (operands[i](Offset).val - pc - 4));
								free[i] := FALSE; i:= ASM.maxOperands;
							ELSIF (free[i]) & (operands[i] IS Imm) THEN
								operands[i](Imm).pc := pc;
								PutDWord (SHORT (operands[i](Imm).val));
								free[i] := FALSE; i:= ASM.maxOperands;
							END
						END;
					END;
				ELSIF ASM.instructions[instr].opcode[oppos] = '/' THEN
					IF val # -1 THEN PutByte (val); val := -1 END;
					CASE ASM.instructions[instr].opcode[oppos + 1] OF
					'r':
						regField := operands[regOperand](Reg).index MOD 8;
					| '0'..'9':
						regField := ORD (ASM.instructions[instr].opcode[oppos + 1]) - ORD ('0');
					END;

					IF operands[addressOperand] IS Reg THEN
						ModRM (3, regField, operands[addressOperand](Reg).index MOD 8);
					ELSIF (bits = size16) & ((operands[addressOperand](Mem).reg = NIL) OR ~(operands[addressOperand](Mem).reg IS Reg32)) THEN
						mem := operands[addressOperand](Mem);
						IF (mem.scale # 1) OR (mem.fixup # NIL) THEN
							PCM.Error (556, errPos, ""); RETURN FALSE;
						ELSIF mem.reg = NIL THEN
							IF mem.index # NIL THEN
								PCM.Error (556, errPos, ""); RETURN FALSE;
							END;
							ModRM (0, regField, 6);
							PutWord (mem.displacement);
						ELSIF mem.reg IS Reg16 THEN
							IF mem.displacement = 0 THEN
								modField := 0;
							ELSIF (mem.displacement >= -80H) & (mem.displacement < 80H) THEN
								modField := 1;
							ELSIF (mem.displacement >= -8000H) & (mem.displacement < 8000H) THEN
								modField := 2;
							ELSE
								PCM.Error (559, errPos, ""); RETURN FALSE;
							END;

							CASE mem.reg.index OF
							| rBX:
								IF mem.index = NIL THEN
									rmField := 7;
								ELSIF mem.index.index = rSI THEN
									rmField := 0;
								ELSIF mem.index.index = rDI THEN
									rmField := 1;
								ELSE
									PCM.Error (556, errPos, ""); RETURN FALSE;
								END
							| rBP:
								IF mem.index = NIL THEN
									rmField := 6;
									IF modField = 0 THEN modField := 1 END;
								ELSIF mem.index.index = rSI THEN
									rmField := 2;
								ELSIF mem.index.index = rDI THEN
									rmField := 3;
								ELSE
									PCM.Error (556, errPos, ""); RETURN FALSE;
								END
							| rSI:
								IF mem.index = NIL THEN
									rmField := 4;
								ELSIF mem.index.index = rBX THEN
									rmField := 0;
								ELSIF mem.index.index = rBP THEN
									rmField := 2;
								ELSE
									PCM.Error (556, errPos, ""); RETURN FALSE;
								END;
							| rDI:
								IF mem.index = NIL THEN
									rmField := 5;
								ELSIF mem.index.index = rBX THEN
									rmField := 1;
								ELSIF mem.index.index = rBP THEN
									rmField := 3;
								ELSE
									PCM.Error (556, errPos, ""); RETURN FALSE;
								END;
							ELSE
								PCM.Error (556, errPos, ""); RETURN FALSE;
							END;

							ModRM (modField, regField, rmField);

							IF modField = 1 THEN
								PutByte (mem.displacement);
							ELSIF modField = 2 THEN
								PutWord (mem.displacement);
							END;
						END;
					ELSE
						mem := operands[addressOperand](Mem);

						IF (mem.reg = NIL) & (mem.index = NIL) THEN
							IF mem.scale # 1 THEN
								PCM.Error (556, errPos, ""); RETURN FALSE;
							END;
							IF bits = size64 THEN
								ModRM (0, regField, 4);
								SIB (0, 4, 5);
							ELSE
								ModRM (0, regField, 5);
							END;
							(* fixup must be 8bit wide for linker!
								IF lastPass & (mem.fixup # NIL) THEN
									AddFixup (mem.fixup, pc);
								END;
							*)
							PutDWord (mem.displacement);
						ELSE
							IF (mem.index # NIL) THEN
								IF (mem.index.index = rSP) OR (mem.index.index = rIP) THEN
									PCM.Error (556, errPos, ""); RETURN FALSE;
								END;
								IF (mem.reg # NIL) & (mem.reg.index = rIP) THEN
									PCM.Error (556, errPos, ""); RETURN FALSE;
								END;

								CASE mem.scale OF
								1: scaleField := 0;
								| 2: scaleField := 1;
								| 4: scaleField := 2;
								| 8: scaleField := 3;
								ELSE
									PCM.Error (556, errPos, ""); RETURN FALSE;
								END;
								rmField := 4;
							ELSE
								IF (mem.scale # 1) THEN
									PCM.Error (556, errPos, ""); RETURN FALSE;
								END;
								IF mem.reg.index = rIP THEN
									rmField := 5;
								ELSIF mem.reg.index MOD 8 = rSP THEN
									rmField := 4;
								ELSE
									rmField := mem.reg.index MOD 8;
								END;
							END;

							(* IF mem.fixup # NIL THEN
								modField := 2;
								mem fixups only for local variables and parameters
							*)
							IF mem.displacement = 0 THEN
								IF (mem.reg # NIL) & (mem.reg.index = rBP) THEN
									modField := 1;
								ELSE
									modField := 0;
								END;
							ELSIF (mem.reg # NIL) & (mem.reg.index = rIP) THEN
								modField := 0;
							ELSIF (mem.displacement >= -80H) & (mem.displacement < 80H) THEN
								modField := 1;
							ELSE
								modField := 2;
							END;

							ModRM (modField, regField, rmField);

							IF (mem.index # NIL) OR (mem.reg.index MOD 8 = rSP) THEN
								IF mem.index # NIL THEN
									indexField := mem.index.index MOD 8;
								ELSE
									indexField := 4;
								END;

								IF mem.reg # NIL THEN
									baseField := mem.reg.index MOD 8;
								ELSE
									baseField := 5;
								END;

								SIB (scaleField, indexField, baseField);
							END;

							IF (modField = 0) & (mem.reg # NIL) & (mem.reg.index = rIP) THEN
								PutDWord (mem.displacement);
							ELSIF modField = 1 THEN
								PutByte (mem.displacement);
							ELSIF modField = 2 THEN
								(* fixup must be 8bit wide for linker!
									IF lastPass & (mem.fixup # NIL) THEN
										AddFixup (mem.fixup, pc);
									END;
								*)
								PutDWord (mem.displacement);
							END;
						END;
					END;
				ELSIF ASM.instructions[instr].opcode[oppos] = '+' THEN
					CASE ASM.instructions[instr].opcode[oppos + 1] OF
					'o':
						IF val # -1 THEN PutByte (val); val := -1 END;
						FOR i := 0 TO ASM.maxOperands - 1 DO
							IF (free[i]) & (operands[i] IS Mem) THEN
								mem := operands[i](Mem);
								IF bits = size16 THEN
									PutWord (mem.displacement);
								ELSE
									IF lastPass & (mem.fixup # NIL) THEN
										AddFixup (mem.fixup, pc);
									END;
									PutDWord (mem.displacement);
								END;
								free[i] := FALSE; i:= ASM.maxOperands;
							END;
						END;
					| 'i': FOR i := 0 TO ASM.maxOperands - 1 DO
							IF (free[i]) & (operands[i] IS FPReg) & (ASM.instructions[instr].operands[i] # ASM.st0) THEN
								val := val + operands[i](FPReg).index;
								PutByte (val); val := -1;
								free[i] := FALSE; i:= ASM.maxOperands;
							END;
						END;
					END;
				ELSIF ASM.instructions[instr].opcode[oppos] = 'r' THEN
					regOperand := GetRegOperand ();
					val := val + operands[regOperand](Reg).index MOD 8;
					PutByte (val); val := -1;
					free[regOperand] := FALSE;
				ELSE
					IF val # -1 THEN PutByte (val) END;
					val := HexOrd (ASM.instructions[instr].opcode[oppos]) * 10H + HexOrd (ASM.instructions[instr].opcode[oppos + 1]);
				END;
				INC (oppos, 2);
			END;
			IF val # -1 THEN PutByte (val) END;

			RETURN TRUE;
		END EmitInstr;

	END Assembly;

(** Text processing handler registered at CompilerInterface *)
PROCEDURE AssembleText(
	text : Texts.Text;
	CONST source: ARRAY OF CHAR;
	pos: LONGINT; (* ignore *)
	CONST pc,opt: ARRAY OF CHAR; (* filename *)
	log: Streams.Writer; diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
VAR
	assembly: Assembly;
	destFile : Files.FileName;
BEGIN
	ASSERT(text # NIL);
	ASSERT(log # NIL);
	ASSERT(diagnostics # NIL);
	IF (opt = "") THEN
		log.String("Error: Expected target filename as parameter"); log.Ln;
		log.Update;
		RETURN;
	END;

	PCM.Init(source, NIL, diagnostics);

	NEW (assembly, diagnostics, NIL);
	assembly.Assemble (PCS.InitWithText (text, 0), NIL, FALSE, FALSE, FALSE);

	error := PCM.error;

	IF error THEN
		(* error reported to diagnostics interface *)
	ELSE
		COPY(opt, destFile);
		ReplaceSuffix(destFile, binSuffix);
		log.String("Assembling "); log.String(destFile); log.String("... "); log.Update;
		WriteBinary(destFile, assembly, diagnostics, error);
		IF error THEN
			log.String("error: could not write binary.");
		ELSE
			log.String("done.");
		END;
		log.Update;
	END;
END AssembleText;

PROCEDURE AssembleFile* (CONST fileName: ARRAY OF CHAR; diagnostics: Diagnostics.Diagnostics; labels, listing: Streams.Writer);
VAR
	format, res: LONGINT;
	text: Texts.Text;
	assembly: Assembly;
	destFile: ARRAY Files.NameLength OF CHAR;
	label: Label;
	ignore : BOOLEAN;
BEGIN
	PCM.Init (fileName, NIL, diagnostics);

	NEW (text);
	TextUtilities.LoadAuto (text, fileName, format, res);

	IF res # 0 THEN
		diagnostics.Error (fileName, Diagnostics.Invalid, Diagnostics.Invalid, "failed to open file"); RETURN;
	END;

	NEW (assembly, diagnostics, NIL);
	assembly.Assemble (PCS.InitWithText (text, 0), NIL, FALSE, FALSE, FALSE);

	IF PCM.error THEN
		(* error reported to diagnostics interface *)
	ELSE
		COPY (fileName, destFile);
		ReplaceSuffix(destFile, binSuffix);
		WriteBinary(destFile, assembly, diagnostics, ignore);

		IF labels # NIL THEN
			label := assembly.firstLabel;
			WHILE label # NIL DO
				labels.String (label.name); labels.String (" := ");
				labels.Int (label.pc, 0); labels.String ("  (");
				labels.Hex (label.pc, 0); labels.String (")");
				labels.Ln;
				label := label.next;
			END;
		END;
	END;
END AssembleFile;

(* Assemble file: usage: PCAAMD64.Assemble file [l] *)
PROCEDURE Assemble* (context: Commands.Context);
VAR fileName: Files.FileName; labels: Streams.Writer; diagnostics: Diagnostics.StreamDiagnostics;
BEGIN
	context.arg.SkipWhitespace; context.arg.String (fileName); context.arg.SkipWhitespace;
	IF context.arg.Peek () = 'l' THEN labels := context.out ELSE labels := NIL END;
	NEW (diagnostics, context.error);
	AssembleFile (fileName, diagnostics, labels, context.out);
END Assemble;

PROCEDURE InlineAssemble (scanner: PCS.Scanner;  scope: PCT.Scope;  exported, inlined: BOOLEAN): PCM.Attribute;
VAR assembly: Assembly;
BEGIN
	NEW (assembly, PCM.diagnostics, NIL);
	assembly.Assemble (scanner, scope, exported, inlined, TRUE);
	RETURN assembly;
END InlineAssemble;

PROCEDURE WriteBinary(CONST filename : ARRAY OF CHAR; assembly :  Assembly; diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
VAR file : Files.File; writer : Files.Writer; asmblock: PCLIR.AsmBlock;
BEGIN
	ASSERT(assembly # NIL);
	ASSERT(diagnostics # NIL);
	file := Files.New (filename);
	IF (file # NIL) THEN
		error := FALSE;
		Files.OpenWriter (writer, file, 0);
		asmblock := assembly.code;
		WHILE asmblock # NIL DO
			writer.Bytes (asmblock.code, 0, asmblock.len);
			asmblock := asmblock.next;
		END;
		writer.Update;
		Files.Register(file);
	ELSE
		diagnostics.Error(filename, Diagnostics.Invalid, Diagnostics.Invalid, "Could not create output file");
		error := TRUE;
	END;
END WriteBinary;

PROCEDURE ReplaceSuffix (VAR destFile : ARRAY OF CHAR; CONST suffix: ARRAY OF CHAR);
VAR i, j: LONGINT; fileName : Files.FileName;
BEGIN
	COPY(destFile, fileName);
	i := 0; WHILE (fileName[i] # 0X) & (fileName[i] # '.') DO destFile[i] := fileName[i];  INC(i) END;
	j := 0; WHILE suffix[j] # 0X DO destFile[i+j] := suffix[j]; INC(j) END;
	destFile[i+j] := 0X;
END ReplaceSuffix;

PROCEDURE Ord (ch: CHAR): INTEGER;
BEGIN RETURN ORD (ch) - ORD ("0")
END Ord;

PROCEDURE HexOrd (ch: CHAR): INTEGER;
BEGIN
	IF ch <= "9" THEN RETURN ORD (ch) - ORD ("0")
	ELSE RETURN ORD (CAP (ch)) - ORD ("A") + 10
	END
END HexOrd;

PROCEDURE ValueInByteRange (value: HUGEINT): BOOLEAN;
BEGIN RETURN SYSTEM.VAL (SHORTINT, value) = value
END ValueInByteRange;

PROCEDURE ValueInWordRange (value: HUGEINT): BOOLEAN;
BEGIN RETURN SYSTEM.VAL (INTEGER, value) = value
END ValueInWordRange;

PROCEDURE NewReg (type, index: LONGINT): Reg;
BEGIN
	CASE type OF
	ASM.reg8: RETURN NewReg8 (index);
	| ASM.reg16: RETURN NewReg16 (index);
	| ASM.reg32: RETURN NewReg32 (index);
	| ASM.reg64: RETURN NewReg64 (index);
	| ASM.segReg: RETURN NewSegReg (index);
	| ASM.CRn: RETURN NewRegCR (index);
	| ASM.DRn: RETURN NewRegDR (index);
	| ASM.st0: RETURN NewFPReg (0);
	| ASM.sti: RETURN NewFPReg (index);
	| ASM.xmm: RETURN NewXMMReg (index);
	| ASM.mmx: RETURN NewMMXReg (index);
	END;
END NewReg;

PROCEDURE NewReg8* (index: LONGINT): Reg8;
VAR reg8: Reg8;
BEGIN
	NEW (reg8, index);
	RETURN reg8;
END NewReg8;

PROCEDURE NewReg16* (index: LONGINT): Reg16;
VAR reg16: Reg16;
BEGIN
	NEW (reg16, index);
	RETURN reg16;
END NewReg16;

PROCEDURE NewReg32* (index: LONGINT): Reg32;
VAR reg32: Reg32;
BEGIN
	NEW (reg32, index);
	RETURN reg32;
END NewReg32;

PROCEDURE NewReg64* (index: LONGINT): Reg64;
VAR reg64: Reg64;
BEGIN
	NEW (reg64, index);
	RETURN reg64;
END NewReg64;

PROCEDURE NewRegCR* (index: LONGINT): RegCR;
VAR regCR: RegCR;
BEGIN
	NEW (regCR, index);
	RETURN regCR;
END NewRegCR;

PROCEDURE NewRegDR* (index: LONGINT): RegDR;
VAR regDR: RegDR;
BEGIN
	NEW (regDR, index);
	RETURN regDR;
END NewRegDR;

PROCEDURE NewSegReg* (index: LONGINT): SegReg;
VAR segReg: SegReg;
BEGIN
	NEW (segReg, index);
	RETURN segReg;
END NewSegReg;

PROCEDURE NewFPReg* (index: LONGINT): FPReg;
VAR fpReg: FPReg;
BEGIN
	NEW (fpReg, index);
	RETURN fpReg;
END NewFPReg;

PROCEDURE NewMMXReg* (index: LONGINT): MMXReg;
VAR mmxReg: MMXReg;
BEGIN
	NEW (mmxReg, index);
	RETURN mmxReg;
END NewMMXReg;

PROCEDURE NewXMMReg* (index: LONGINT): XMMReg;
VAR xmmReg: XMMReg;
BEGIN
	NEW (xmmReg, index);
	RETURN xmmReg;
END NewXMMReg;

PROCEDURE NewMem (size: Size; reg: Reg; displacement: LONGINT): Mem;
VAR mem: Mem;
BEGIN
	NEW (mem, size);
	mem.reg := reg;
	mem.displacement := displacement;
	RETURN mem;
END NewMem;

PROCEDURE NewMem8* (reg: Reg; displacement: LONGINT): Mem;
BEGIN RETURN NewMem (size8, reg, displacement);
END NewMem8;

PROCEDURE NewMem16* (reg: Reg; displacement: LONGINT): Mem;
BEGIN RETURN NewMem (size16, reg, displacement);
END NewMem16;

PROCEDURE NewMem32* (reg: Reg; displacement: LONGINT): Mem;
BEGIN RETURN NewMem (size32, reg, displacement);
END NewMem32;

PROCEDURE NewMem64* (reg: Reg; displacement: LONGINT): Mem;
BEGIN RETURN NewMem (size64, reg, displacement);
END NewMem64;

PROCEDURE NewMem128* (reg: Reg; displacement: LONGINT): Mem;
BEGIN RETURN NewMem (size128, reg, displacement);
END NewMem128;

PROCEDURE NewImm* (size: LONGINT; val: HUGEINT): Imm;
VAR imm: Imm;
BEGIN
	NEW (imm, size, val);
	RETURN imm;
END NewImm;

PROCEDURE NewImm8* (val: HUGEINT): Imm;
BEGIN RETURN NewImm (size8, val);
END NewImm8;

PROCEDURE NewImm16* (val: HUGEINT): Imm;
BEGIN RETURN NewImm (size16, val);
END NewImm16;

PROCEDURE NewImm32* (val: HUGEINT): Imm;
BEGIN RETURN NewImm (size32, val);
END NewImm32;

PROCEDURE NewImm64* (val: HUGEINT): Imm;
BEGIN RETURN NewImm (size64, val);
END NewImm64;

PROCEDURE NewOffset* (size: LONGINT; val: HUGEINT): Offset;
VAR offset: Offset;
BEGIN
	NEW (offset, size, val);
	RETURN offset;
END NewOffset;

PROCEDURE NewOffset8* (val: HUGEINT): Offset;
BEGIN RETURN NewOffset (size8, val);
END NewOffset8;

PROCEDURE NewOffset16* (val: HUGEINT): Offset;
BEGIN RETURN NewOffset (size16, val);
END NewOffset16;

PROCEDURE NewOffset32* (val: HUGEINT): Offset;
BEGIN RETURN NewOffset (size32, val);
END NewOffset32;

PROCEDURE NewOffset64* (val: HUGEINT): Offset;
BEGIN RETURN NewOffset (size64, val);
END NewOffset64;

PROCEDURE NewPntr1616* (s, o: LONGINT): Pntr1616;
VAR pntr1616: Pntr1616;
BEGIN
	NEW (pntr1616, s, o);
	RETURN pntr1616;
END NewPntr1616;

PROCEDURE NewPntr1632* (s, o: LONGINT): Pntr1632;
VAR pntr1632: Pntr1632;
BEGIN
	NEW (pntr1632, s, o);
	RETURN pntr1632;
END NewPntr1632;

PROCEDURE Install*;
BEGIN PCP.Assemble := InlineAssemble;
END Install;

PROCEDURE Cleanup;
BEGIN
	CompilerInterface.Unregister("AAMD64");
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	CompilerInterface.Register("AAMD64", "AMD64 Assembler", "ASM", AssembleText);
END PCAAMD64.
