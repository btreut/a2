(* Paco, Copyright 2000, Patrik Reali, ETH Zurich *)
(* PCAARM - ARM assembler module for the Paco compiler *)

MODULE PCAARM;	(* be *)

	IMPORT SYSTEM, StringPool, PCM, PCLIR, PCT, PCS, PCBT, PCP, PCOARM, KernelLog;

(** Implements the instruction set desribed in 'ARM Architecture Reference Manual',
	Second Edition, edited by David Seal; ISBN 0-201-73719-1
*)

CONST
	Trace = FALSE;
	TraceScan = FALSE;
	TraceSymbol = FALSE;
	TraceMnemonic = FALSE;
	TraceParse = FALSE;

	INTERNALERROR = 100;

	(* assembler targets *)
	ARM = 0;
	THUMB = 1;

	(* character constants *)
	SPACE = " ";
	TAB = 09X;
	LF = 0AX;
	CR = 0DX;

	(* symbol types *)
	stAll = 0;
	stCondition = 1; stRegister = 2; stShift = 3; stStateRegister = 4; stStateRegisterFlag = 5; stStateRegisterFlagSeparator = 6;
	stLoad = 7; stLoadSpecial = 8; stStore = 9; stStoreSpecial = 10; stMultipleMode = 11; stCoprocessor = 12; stCPRegister = 13;

	(* symbols *)
	sLabel = 0; sIdent = 1; sEnd = 2; sCR = 3; sUndef = 4; sLBrak = 5; sRBrak = 6; sLBrace = 7; sRBrace = 8;
	sComma = 9; sNumber = 10; sExclamation = 11; sPlus = 12; sMinus = 13; sArrow = 14; sEquals = 15;
	sCharacter = 16; sString = 17;

	(* label types *)
	ltBranch = 0 ; ltAddress = 1;
	(* label modes *)
	lmLoad = 0; lmLoadSpecial = 1; lmShifterOperand = 2;
	NumLabelTypes = 4;

	(* miscellaneous *)
	MaxBranchOffset = 33554428;
	MinBranchOffset = -33554432;
	MinLoadOffset = -0FFFH;
	MaxLoadOffset = 0FFFH;
	MinLoadSpecialOffset = -0FFH;
	MaxLoadSpecialOffset = 0FFH;
	MaxShifterOperand = 7F000000H;
	MinShifterOperand = LONGINT(80000000H);

VAR
	MinMaxOffset: ARRAY NumLabelTypes OF RECORD min, max: LONGINT END;

TYPE
	AsmInline* = OBJECT(PCLIR.AsmInline)
	VAR
		paf-: BOOLEAN; 	(* TRUE if a procedure activation frame should be generated *)
	END AsmInline;

	Identifier = ARRAY 32 OF CHAR;

(* Paco bug workaround *)
(*
	(* IdentHandler - 'ident' contains the string in question.
			If the IdentHandler scans part of the string, it has to delete this (sub)string from ident *)
	IdentHandler = PROCEDURE {DELEGATE} (assembler: Assembler; VAR ident: Identifier): SET;

	(* Parser Handler - on entry, the the scanner points to the first symbol.
			Each handler is responsible that on exit the scanner points to the first foreign symbol *)
	Handler = PROCEDURE {DELEGATE} (assembler: Assembler): SET;
*)

	(* Symbol - a symbol *)
	Symbol = OBJECT
		VAR
			name: Identifier;
			type: LONGINT;
			value: SET;
			next: Symbol;
			local: BOOLEAN;

		PROCEDURE &Init*(name: Identifier; type: LONGINT; value: SET; local: BOOLEAN);
		BEGIN SELF.name := name; SELF.type := type; SELF.value := value; SELF.local := local;
		END Init;
	END Symbol;

	(* SymbolTable - singleton object. Contains all symbols  & offers functions to add/find symbols *)
	SymbolTable = OBJECT (* singleton *)
		VAR
			symbols: ARRAY 27 OF Symbol;
			parent: SymbolTable;

		(* Init - constructor *)
		PROCEDURE &Init*(parent: SymbolTable);
		BEGIN SELF.parent := parent
		END Init;

		(* Enter - registers a symbol
				the assembler language is neither prefix- nor postfix-free....(what moron designed it ?!?)
				If the symbols are sorted by their length, the longer symbols are checked first & it works.
		*)
		PROCEDURE Enter(symbol: Identifier; type: LONGINT; value: SET; local: BOOLEAN);
		VAR s, p, c: Symbol; idx, len: LONGINT;
		BEGIN { EXCLUSIVE }
			ASSERT(symbol # "");
			NEW(s, symbol, type, value, local);
			idx := ORD(Cap(symbol[0])) - ORD("A");
			IF (idx < 0) OR (idx >= 26) THEN idx := 26 END; (* symbols that do not start with a letter go here *)

			p := NIL; c := symbols[idx]; len := Length(symbol);
			WHILE (c # NIL) & (Length(c.name) > len) DO p := c; c := c.next END;
			IF (p = NIL) THEN symbols[idx] := s; s.next := c
			ELSE s.next := p.next; p.next := s
			END
		END Enter;

		(* Find - finds a symbol by its exact name and type *)
		PROCEDURE Find(symbol: Identifier; type: LONGINT; VAR value: SET): BOOLEAN;
		VAR idx: LONGINT; s: Symbol;
		BEGIN
			IF TraceSymbol THEN Write("  FindSymbol '"); Write(symbol) END;
			IF (symbol # "") THEN
				idx := ORD(Cap(symbol[0])) - ORD("A");
				IF (idx < 0) OR (idx >= 26) THEN idx := 26 END;
				s := symbols[idx];
				WHILE (s # NIL) & (((type # stAll) & (s.type # type)) OR (s.name # symbol)) DO s := s.next END;
				IF (s # NIL) THEN value := s.value; IF TraceSymbol THEN WriteLn("': found") END
				ELSE value := {}; IF TraceSymbol THEN WriteLn("': not found") END
				END
			END;
			IF (s = NIL) & (parent # NIL) THEN	(* lookup in parent symbol table *)
				RETURN parent.Find(symbol, type, value)
			ELSE
				RETURN (s # NIL)
			END
		END Find;

		(* GetSymbol - finds a symbol by its exact name and type *)
		PROCEDURE GetSymbol(symbol: Identifier; type: LONGINT): Symbol;
		VAR idx: LONGINT; s: Symbol;
		BEGIN
			IF (symbol # "") THEN
				idx := ORD(Cap(symbol[0])) - ORD("A");
				IF (idx < 0) OR (idx >= 26) THEN idx := 26 END;
				s := symbols[idx];
				WHILE (s # NIL) & (((type # stAll) & (s.type # type)) OR (s.name # symbol)) DO s := s.next END;
			END;
			IF (s = NIL) & (parent # NIL) THEN RETURN parent.GetSymbol(symbol, type)
			ELSE RETURN s
			END
		END GetSymbol;

		(* Prefix - finds a symbol with a matching prefix and type. If a symbol is found,
				matching part of the string is deleted from 'symbol'.
		*)
		PROCEDURE Prefix(VAR symbol: Identifier; type: LONGINT; VAR value: SET): BOOLEAN;
		VAR idx: LONGINT; s: Symbol;

			PROCEDURE Match(s: Symbol; VAR str: Identifier): BOOLEAN;
			VAR p, q: LONGINT;
			BEGIN p := 1;
				WHILE (s.name[p] # 0X) & (s.name[p] = str[p]) DO INC(p) END;
				IF (s.name[p] = 0X) THEN
					(* copy remaining part of str to the beginning *)
					q := 0; WHILE (str[p] # 0X) DO str[q] := str[p]; INC(p); INC(q) END;
					str[q] := 0X;
					RETURN TRUE
				ELSE RETURN FALSE
				END
			END Match;

		BEGIN
			IF TraceSymbol THEN Write("  PrefixSymbol '"); Write(symbol) END;
			idx := ORD(Cap(symbol[0])) - ORD("A");
			IF (idx < 0) OR (idx >= 26) THEN idx := 26 END;
			s := symbols[idx];
			WHILE (s # NIL) & (((type # stAll) & (s.type # type)) OR ~Match(s, symbol))DO s := s.next END;
			IF (s # NIL) THEN value := s.value;
				IF TraceSymbol THEN Write("' found; remaining '"); Write(symbol); Char("'"); Ln END
			ELSE value := {};
				IF TraceSymbol THEN WriteLn("' not found") END
			END;
			IF (s = NIL) & (parent # NIL) THEN RETURN parent.Prefix(symbol, type, value)
			ELSE RETURN (s # NIL)
			END
		END Prefix;

		(* ClearLocalSymbols - removes all symbols from the symbol table *)
		PROCEDURE ClearLocalSymbols;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO 26 DO symbols[i] := NIL END
		END ClearLocalSymbols;
	END SymbolTable;

	(* Mnemonic - a mnemonic *)
	Mnemonic = OBJECT
		VAR
			name: ARRAY 7 OF CHAR;
			opcode: SET;
			cond, suffix: IdentHandler;
			handlers: ARRAY 6 OF Handler;
			next: Mnemonic;

		PROCEDURE &Init*(name: ARRAY OF CHAR; opcode: SET; cond, suffix: IdentHandler; h0, h1, h2, h3, h4, h5: Handler);
		BEGIN COPY(name, SELF.name); SELF.opcode := opcode; SELF.cond := cond; SELF.suffix := suffix;
			handlers[0] := h0; handlers[1] := h1; handlers[2] := h2; handlers[3] := h3; handlers[4] := h4; handlers[5] := h5
		END Init;

		(* Print - debug *)
		PROCEDURE Print;
		VAR i: LONGINT;
		BEGIN
			Write("Mnemonic: "); WriteLn(SELF.name);
			FOR i := 0 TO 5 DO
				Write(" handler["); Int(i); Write("]: ");
				IF (handlers[i] = NIL) THEN WriteLn("clear")
				ELSE Write("set; "); IF (handlers[i] = NILHandler) THEN Write("nil") END; Ln
				END
			END
		END Print;
	END Mnemonic;

	(* Mnemonics - singleton object. Contains all supported mnemonics & offers functions to add/find mnemonics *)
	Mnemonics = OBJECT (* singleton *)
		VAR
			mnemonics: ARRAY 26 OF Mnemonic;

		(* Enter - registers a mnemonic with its specific handlers
				the assembler language is neither prefix- nor postfix-free....(what moron designed it ?!?)
				If the mnemonics are sorted by their length, the longer mnemonics are checked first & it works.
		*)
		PROCEDURE Enter(mnemonic: ARRAY OF CHAR; opcode: SET; cond, suffix: IdentHandler;
														h0, h1, h2, h3, h4, h5: Handler);
		VAR m, p, c: Mnemonic; idx, len: LONGINT;
		BEGIN
			NEW(m, mnemonic, opcode, cond, suffix, h0, h1, h2, h3, h4, h5);
			idx := ORD(Cap(mnemonic[0])) - ORD("A");
			ASSERT((0<= idx) & (idx < 26));

			p := NIL; c := mnemonics[idx]; len := Length(mnemonic);
			WHILE (c # NIL) & (Length(c.name) > len) DO p := c; c := c.next END;
			IF (p = NIL) THEN mnemonics[idx] := m; m.next := c
			ELSE m.next := p.next; p.next := m
			END
		END Enter;

		(* Find - searches the mnemonics for one that begins with the same string. If a mnemonic is found, the
			matching part of the string is deleted from 'mnemonic'
		*)
		PROCEDURE Find(VAR mnemonic: Identifier): Mnemonic;
		VAR idx: LONGINT; m: Mnemonic;

			PROCEDURE Match(m: Mnemonic; VAR str: Identifier): BOOLEAN;
			VAR p, q: LONGINT;
			BEGIN p := 1;
				WHILE (m.name[p] # 0X) & (m.name[p] = str[p]) DO INC(p) END;
				IF (m.name[p] = 0X) THEN
					(* copy condition codes and S flag to the beginning of str *)
					q := 0; WHILE (str[p] # 0X) DO str[q] := str[p]; INC(p); INC(q) END;
					str[q] := 0X;
					RETURN TRUE
				ELSE RETURN FALSE
				END
			END Match;

		BEGIN
			IF TraceMnemonic THEN Write("  FindMnemonic '"); Write(mnemonic) END;
			idx := ORD(Cap(mnemonic[0])) - ORD("A");
			m := mnemonics[idx];
			WHILE (m # NIL) & ~Match(m, mnemonic) DO m := m.next END;
			IF TraceMnemonic THEN
				IF (m # NIL) THEN Write("' found: '"); Write(mnemonic); Char("'")
				ELSE Write("' not found")
				END;
				Ln
			END;
			RETURN m
		END Find;

		PROCEDURE Branch(assembler: Assembler; VAR ident: Identifier): SET;
		BEGIN RETURN assembler.Branch(ident)
		END Branch;

		PROCEDURE Condition(assembler: Assembler; VAR ident: Identifier): SET;
		BEGIN RETURN assembler.Condition(ident)
		END Condition;

		PROCEDURE SFlag(assembler: Assembler; VAR ident: Identifier): SET;
		BEGIN RETURN assembler.SFlag(ident)
		END SFlag;

		PROCEDURE BFlag(assembler: Assembler; VAR ident: Identifier): SET;
		BEGIN RETURN assembler.BFlag(ident)
		END BFlag;

		PROCEDURE LFlag(assembler: Assembler; VAR ident: Identifier): SET;
		BEGIN RETURN assembler.LFlag(ident)
		END LFlag;

		PROCEDURE Load(assembler: Assembler; VAR ident: Identifier): SET;
		BEGIN RETURN assembler.LoadStore(ident, stLoad, stLoadSpecial)
		END Load;

		PROCEDURE Store(assembler: Assembler; VAR ident: Identifier): SET;
		BEGIN RETURN assembler.LoadStore(ident, stStore, stStoreSpecial)
		END Store;

		PROCEDURE Multiple(assembler: Assembler; VAR ident: Identifier): SET;
		BEGIN RETURN assembler.LoadStoreMultiple(ident)
		END Multiple;

		PROCEDURE R16(assembler: Assembler): SET;
		BEGIN RETURN assembler.Register(stRegister, 16);
		END R16;

		PROCEDURE R12(assembler: Assembler): SET;
		BEGIN RETURN assembler.Register(stRegister,12)
		END R12;

		PROCEDURE R8(assembler: Assembler): SET;
		BEGIN RETURN assembler.Register(stRegister, 8)
		END R8;

		PROCEDURE R0(assembler: Assembler): SET;
		BEGIN RETURN assembler.Register(stRegister, 0)
		END R0;

		PROCEDURE Coprocessor(assembler: Assembler): SET;
		BEGIN RETURN assembler.Register(stCoprocessor, 8)
		END Coprocessor;

		PROCEDURE CR16(assembler: Assembler): SET;
		BEGIN RETURN assembler.Register(stCPRegister, 16);
		END CR16;

		PROCEDURE CR12(assembler: Assembler): SET;
		BEGIN RETURN assembler.Register(stCPRegister, 12)
		END CR12;

		PROCEDURE CR0(assembler: Assembler): SET;
		BEGIN RETURN assembler.Register(stCPRegister, 0)
		END CR0;

		PROCEDURE CPOpcode1cdp(assembler: Assembler): SET;
		BEGIN RETURN assembler.CPOpcode(20, 10H)
		END CPOpcode1cdp;

		PROCEDURE CPOpcode1m(assembler: Assembler): SET;
		BEGIN RETURN assembler.CPOpcode(21, 8H)
		END CPOpcode1m;

		PROCEDURE CPOpcode2(assembler: Assembler): SET;
		BEGIN RETURN assembler.CPOpcode(5, 8H)
		END CPOpcode2;

		PROCEDURE LoadStoreCoprocessor(assembler: Assembler): SET;
		BEGIN RETURN assembler.LoadStoreCoprocessor()
		END LoadStoreCoprocessor;

		PROCEDURE MoveCoprocessor(assembler: Assembler): SET;
		BEGIN RETURN assembler.MoveCoprocessor()
		END MoveCoprocessor;

		PROCEDURE PSR(assembler: Assembler): SET;
		BEGIN RETURN assembler.PSR(FALSE)
		END PSR;

		PROCEDURE Target(assembler: Assembler): SET;
		BEGIN RETURN assembler.Target()
		END Target;

		PROCEDURE ShifterOperand(assembler: Assembler): SET;
		BEGIN RETURN assembler.AddressingMode1()
		END ShifterOperand;

		PROCEDURE MSR(assembler: Assembler): SET;
		BEGIN RETURN assembler.MSR()
		END MSR;

		PROCEDURE Swap(assembler: Assembler): SET;
		BEGIN RETURN assembler.Swap()
		END Swap;

		PROCEDURE Immediate24(assembler: Assembler): SET;
		BEGIN RETURN assembler.Immediate24()
		END Immediate24;

		PROCEDURE BkptImmediate(assembler: Assembler): SET;
		BEGIN RETURN assembler.BkptImmediate()
		END BkptImmediate;

		PROCEDURE DCB(assembler: Assembler): SET;
		BEGIN RETURN assembler.DCB()
		END DCB;

		PROCEDURE DCW(assembler: Assembler): SET;
		BEGIN RETURN assembler.DCW()
		END DCW;

		PROCEDURE DCD(assembler: Assembler): SET;
		BEGIN RETURN assembler.DCD()
		END DCD;

		PROCEDURE DCFS(assembler: Assembler): SET;
		BEGIN RETURN assembler.DCFS()
		END DCFS;

		PROCEDURE DCFD(assembler: Assembler): SET;
		BEGIN RETURN assembler.DCFD()
		END DCFD;

		PROCEDURE ADR(assembler: Assembler): SET;
		BEGIN RETURN assembler.ADR()
		END ADR;

		PROCEDURE DEFINE(assembler: Assembler): SET;
		BEGIN RETURN assembler.DEFINE()
		END DEFINE;

		(* another try: workaround for IF (delegate=NIL) trap *)
(*		PROCEDURE IdentNil(assembler: Assembler; VAR ident: Identifier): SET;
		BEGIN RETURN {}
		END IdentNil;

		PROCEDURE Nil(assembler: Assembler): SET;
		BEGIN RETURN {}
		END Nil;
*)
	END Mnemonics;

	UseList = OBJECT
		VAR
			sourcepos,			(* position in source code *)
			pc,						(* pc of branch *)
			mode: LONGINT; (* mode of use *)
			next: UseList;

		PROCEDURE &Init*(sourcepos, pc, mode: LONGINT; next: UseList);
		BEGIN SELF.sourcepos := sourcepos; SELF.pc := pc; SELF.mode := mode; SELF.next := next
		END Init;
	END UseList;

	Label = OBJECT
		VAR
			pc: LONGINT; (* pc of location where the label is defined *)
			name: Identifier;
			type: LONGINT;
			uses: UseList;
			next: Label;

		PROCEDURE &Init*(pc: LONGINT; name: Identifier; type: LONGINT; next: Label);
		BEGIN SELF.pc := pc; SELF.name := name; SELF.type := type; SELF.next := next
		END Init;
	END Label;

	LabelManager = OBJECT
		VAR
			labels: Label;
			assembler: Assembler;

		PROCEDURE &Init*(assembler: Assembler);
		BEGIN SELF.assembler := assembler
		END Init;

		(* AddDefinition - adds a label. Duplicates are not allowed
			If a label has been 'defined' already, all forward references are fixed and then deleted.
			If a use is too far away, the error is reported to PCM.
		*)
		PROCEDURE AddDefinition(sourcepos, pc: LONGINT; label: Identifier; type: LONGINT);
		VAR l: Label; use: UseList; offset: LONGINT;
		BEGIN
			IF TraceParse THEN Write("  label manager: adding definition for "); Write(label); Write("; type "); Int(type); Ln END;
			l := Find(label, type);
			IF (l # NIL) THEN
				IF (l.pc = -1) THEN	(* label must not be defined yet *)
					IF TraceParse THEN WriteLn("  existing label, fixing forward references...") END;
					l.pc := pc;
					use := l.uses;
					WHILE (use # NIL) DO
						offset := pc - (use.pc + 8);
						IF (offset < MinMaxOffset[type+use.mode].min) OR (offset > MinMaxOffset[type+use.mode].max) THEN
							PCM.Error(500, use.sourcepos, "Offset too big.");
						ELSE
							IF (type = ltBranch) THEN
								assembler.FixBranch(use.pc, SYSTEM.VAL(SET, offset DIV 4)*PCOARM.Mask24)
							ELSIF (type = ltAddress) THEN
								assembler.FixLoad(use.pc, use.mode, offset)
							ELSE
								HALT(INTERNALERROR)
							END
						END;
						use := use.next
					END;
					l.uses := NIL
				ELSE
					Write(" label already defined at pc="); Int(l.pc); Write("; this pc="); Int(pc); Ln;
					PCM.Error(500, sourcepos, "Label already defined")
				END
			ELSE
				IF TraceParse THEN WriteLn("  new label") END;
				NEW(l, pc, label, type, labels); labels := l
			END
		END AddDefinition;

		(* Find - searches for a given label. Returns NIL if not found *)
		PROCEDURE Find(label: Identifier; type: LONGINT): Label;
		VAR l: Label;
		BEGIN
			l := labels;
			WHILE (l # NIL) & ((l.name # label) OR (l.type # type)) DO l := l.next END;
			RETURN l
		END Find;

		(* AddUse - adds a use to a given label. If the labes does not yet exist, it will be created automatically.
			If the location of the label is already known, the correct branch offset is returned, {} otherwise.
			If the branch offset is too big, the error is reported to PCM
		*)
		PROCEDURE AddUse(sourcepos, pc: LONGINT; label: Identifier; type, mode: LONGINT): SET;
		VAR l: Label; use: UseList; offset: LONGINT; res: SET;
		BEGIN (* HEUREKA ! *)
			IF TraceParse THEN Write("  label manager: adding use for "); Write(label); Write("; type "); Int(type); Ln END;
			l := Find(label, type);
			IF (l = NIL) THEN
				IF TraceParse THEN WriteLn("   first use, not yet defined") END;
				IF TraceParse THEN Write("   adding "); Write(label); Write("; type "); Int(type); Ln END;
				 NEW(l, -1, label, type, labels); labels := l
			END;
			IF (l.pc = -1) THEN NEW(use, sourcepos, pc, mode, l.uses); l.uses := use; RETURN {}
			ELSE
				offset := l.pc - (pc + 8);
				IF (offset < MinMaxOffset[type+mode].min) OR (offset > MinMaxOffset[type+mode].max) THEN
					PCM.Error(500, sourcepos, "Offset too big."); RETURN {}
				ELSE
					IF (type = ltBranch) THEN
						RETURN SYSTEM.VAL(SET, offset DIV 4)*PCOARM.Mask24
					ELSIF (type = ltAddress) THEN
						IF (mode = lmLoad) THEN res := SYSTEM.VAL(SET, ABS(offset))
						ELSIF (mode = lmLoadSpecial) THEN res := SYSTEM.VAL(SET, ABS(offset) DIV 10H * 100H + ABS(offset) MOD 10H)
						ELSIF (mode = lmShifterOperand) THEN (* the offset will be put into a shifter operand - don't set any flags *)
							RETURN SYSTEM.VAL(SET, offset)
						END;
						IF (offset < 0) THEN res := res + PCOARM.IdxSub
						ELSE res := res + PCOARM.IdxAdd
						END;
						RETURN res + PCOARM.Offset
					ELSE
						HALT(INTERNALERROR)
					END
				END
			END
		END AddUse;

		(* Check - checks if all uses are resolved. Errors are reported to PCM *)
		PROCEDURE Check;
		VAR l: Label; u: UseList;
		BEGIN
			l := labels;
			WHILE (l # NIL) DO
				u := l.uses;
				WHILE (u # NIL) DO
					IF TraceParse THEN
						Write(" unresolved label "); Write(l.name); Write(" at position "); Int(u.sourcepos); Ln
					END;
					PCM.LogWLn;
					PCM.LogWStr("unresolved label '"); PCM.LogWStr(l.name); PCM.LogWStr("' at position ");
					PCM.LogWNum(u.sourcepos); PCM.LogWLn;
					PCM.Error(500, u.sourcepos, "Unresolved label."); (* unresolved label *)
					u := u.next
				END;
				l := l.next
			END
		END Check;
	END LabelManager;



	(* ------------------------------   Scanner   ---------------------------------*)
	Scanner = OBJECT
		VAR
			scanner: PCS.Scanner;
			position, symbol: LONGINT; (* current position, current symbol *)
			eot: BOOLEAN; (* TRUE if the end has been reached (symbol = sEnd) *)
			ident: Identifier; (* valid if symbol equals sIdent *)
			number: LONGINT; (* valid if symbol equals sNumber *)
			ch: CHAR; (* valid if symbol equals sCharacter *)
			string: ARRAY 256 OF CHAR; (* valid if symbol equals sString *)

		(* Init - constructor *)
		PROCEDURE &Init*(scanner: PCS.Scanner);
		BEGIN SELF.scanner := scanner; Scan
		END Init;

		(* SkipWhiteSpace - skips over white space (spaces & tabs) and assembler-style commentary ("; ...<CR>") *)
		PROCEDURE SkipWhiteSpace;
		BEGIN
			WHILE (scanner.ch = SPACE) OR (scanner.ch = TAB) DO scanner.NextChar END;
			IF (scanner.ch = ";") THEN
				WHILE (scanner.ch # CR) & (scanner.ch # LF) DO scanner.NextChar END	(* skip comments *)
			END
		END SkipWhiteSpace;

		(* Character - returns TRUE if 'ch' is a character *)
		PROCEDURE Character(ch: CHAR): BOOLEAN;
		BEGIN RETURN ((Cap(ch) >= "A") & (Cap(ch) <= "Z"))
		END Character;

		(* Digit - returns the value of a (hexadecimal) digit. If 'ch' is not a digit, -1 is returned *)
		PROCEDURE Digit(ch: CHAR): LONGINT;
		BEGIN
			IF (ch >= "0") & (ch <= "9") THEN RETURN ORD(ch) - ORD("0")
			ELSIF (Cap(ch) >= "A") & (Cap(ch) <= "F") THEN RETURN ORD(Cap(ch)) - ORD("A") + 10
			ELSE RETURN -1
			END
		END Digit;

		(* Delimiter - returns TRUE if 'ch' is a word delimiter (i.e., neither a character, a digit nor an underscore) *)
		PROCEDURE Delimiter(ch: CHAR): BOOLEAN;
		BEGIN RETURN ~Character(ch) & (Digit(ch) = -1) & (ch # "_")
		END Delimiter;

		(* GetIdent - returns an identifier *)
		PROCEDURE GetIdent(VAR ident: Identifier);
		VAR pos: LONGINT;
		BEGIN
			WHILE (pos < LEN(ident)-1) & ~Delimiter(scanner.ch) DO
				ident[pos] := scanner.ch; INC(pos); scanner.NextChar
			END;
			IF ~Delimiter(scanner.ch) THEN PCM.Error(240, scanner.curpos-1, "Identifier too long.") END; (* ident too long *)
			ident[pos] := 0X
		END GetIdent;

		(* GetNumber - returns a number. Hexadecimal numbers are terminated with an "H", a leading "0" is not necessary.
			Binary numbers are terminated by "B", decimal numbers as usual.
		*)
		PROCEDURE GetNumber(allowChars: BOOLEAN);
		VAR str: ARRAY 33 OF CHAR; i, base, sign, value: LONGINT;
		BEGIN
			symbol := sNumber;
			IF (scanner.ch = "-") THEN sign := -1; scanner.NextChar
			ELSE sign := 1;
				IF (scanner.ch = "+") THEN scanner.NextChar END
			END;
			WHILE (i < LEN(str)-1) & (Digit(scanner.ch) # -1) DO
				str[i] := scanner.ch; INC(i); scanner.NextChar
			END;
			DEC(i);
			IF (scanner.ch = "H") THEN scanner.NextChar; base := 10H (* it's a hex number *)
			ELSIF (scanner.ch = "B") THEN scanner.NextChar; base := 2 (* it's a binary number *)
			ELSIF (scanner.ch = "X") & allowChars THEN (* it's a character *)
				scanner.NextChar; base := 10H; symbol := sCharacter
			ELSIF Delimiter(scanner.ch) THEN base := 10 (* it's a decimal number *)
			ELSE PCM.Error(2, position, "Illegal character in number."); RETURN (* illegal character in number *)
			END;
			value := 1; number := 0;
			WHILE (i >= 0) DO number := number + Digit(str[i])*value; value := value*base; DEC(i) END;
			IF (symbol = sNumber) THEN
				 number := sign*number
			ELSE (* symbol = sCharacter *)
				IF (sign = -1) OR (number >= 100H) THEN PCM.Error(203, position, "Number too large.") END; (* number too large *)
				ch := CHR(number)
			END;
		END GetNumber;

		(* WriteSymbol - debug *)
		PROCEDURE WriteSymbol;
		VAR s: ARRAY 32 OF CHAR;
		BEGIN
			CASE symbol OF
			| sLabel: s := "sLabel"
			| sIdent: s := "sIdent"
			| sEnd: s := "sEnd"
			| sCR: s := "sCR"
			| sUndef: s := "sUndef"
			| sLBrak: s := "sLBrak"
			| sRBrak: s := "sRBrak"
			| sLBrace: s := "s:LBrace"
			| sRBrace: s := "sRBrace"
			| sComma: s := "sComma"
			| sNumber: s := "sNumber"
			| sExclamation: s := "sExclamation"
			| sPlus: s := "sPlus"
			| sMinus: s := "sMinus"
			| sArrow: s := "sArrow"
			| sEquals: s := "sEquals"
			| sCharacter: s := "sCharacter"
			| sString: s := "sString"
			ELSE s := "UNKNOWN"
			END;
			Write("  Scan: symbol = "); WriteLn(s)
		END WriteSymbol;

		(* Scan - scans the next symbol. Stops at "END" *)
		PROCEDURE Scan;
		VAR pos: LONGINT;
		BEGIN
			IF ~eot THEN
				SkipWhiteSpace;
				position := scanner.curpos;
				IF Character(scanner.ch) THEN
					GetIdent(ident);
					IF (ident = "END") THEN symbol := sEnd; eot := TRUE
					ELSE symbol := sIdent
					END
				ELSIF (scanner.ch = ".") THEN
					scanner.NextChar;
					GetIdent(ident);
					symbol := sLabel
				ELSIF (scanner.ch = "#") THEN
					scanner.NextChar;
					GetNumber(FALSE)
				ELSIF (scanner.ch >= "0") & (scanner.ch <= "9") THEN
					GetNumber(TRUE)
				ELSIF (scanner.ch = "-") THEN
					scanner.NextChar;
					IF (scanner.ch >= "0") & (scanner.ch <= "9") THEN
						GetNumber(FALSE);
						number := -number
					ELSE
						symbol := sMinus
					END
				ELSIF (scanner.ch = "'") THEN
					scanner.NextChar;
					ch := scanner.ch;
					symbol := sCharacter;
					scanner.NextChar;
					IF (scanner.ch # "'") THEN PCM.Error(500, scanner.curpos, "' expected.")  (* ' expected *)
					ELSE scanner.NextChar
					END
				ELSIF (scanner.ch = '"') THEN
					scanner.NextChar;
					pos := 0;
					WHILE (scanner.ch # '"') & (scanner.ch # CR) & (scanner.ch # LF) & (pos < LEN(string)-1) DO
						string[pos] := scanner.ch; INC(pos);
						scanner.NextChar
					END;
					IF (scanner.ch = '"') THEN
						scanner.NextChar;
						string[pos] := 0X;
						symbol := sString
					ELSIF (pos = LEN(string)-1) THEN
						PCM.Error(500, scanner.curpos, "String too long."); (* string too long *)
						WHILE (scanner.ch # CR) & (scanner.ch # LF) DO scanner.NextChar END
					ELSE
						PCM.Error(500, scanner.curpos, '" expected.') (* " expected *)
					END
				ELSE
					CASE scanner.ch OF
					| "," : symbol := sComma
					| "[" : symbol := sLBrak
					| "]" : symbol := sRBrak
					| "{" : symbol := sLBrace
					| "}" : symbol := sRBrace
					| "!" : symbol := sExclamation
					| "+": symbol := sPlus
					| "^": symbol := sArrow
					| "=": symbol := sEquals
					| ":" : symbol := sCR
					| CR, LF: symbol := sCR
					ELSE symbol := sUndef
					END;
					scanner.NextChar
				END;
				IF (scanner.ch = PCS.Eot) THEN eot := TRUE END
			END;
			IF TraceScan THEN WriteSymbol END;
		END Scan;

		(* Match - returns TRUE and scans the next symbol if the current symbol equals 'symbol'*)
		PROCEDURE Match(symbol: LONGINT): BOOLEAN;
		BEGIN
			IF (SELF.symbol = symbol) THEN
				Scan; RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END Match;
	END Scanner;


	(* Assembler - the assembler (huga, what a surprise !) *)
	Assembler = OBJECT
		VAR
			scanner: Scanner;
			scope: PCT.Scope;
			symbols: SymbolTable;
			exported, inlined: BOOLEAN;
			labels: LabelManager;
			target: SET;
			asm: AsmInline;
			code: PCLIR.AsmBlock;
			ignore: BOOLEAN;
			pc: LONGINT;
			opcode: SET;	(* opcode we have assembled so far *)

		(*-------------------------------------- parser functions ----------------------------------------*)

		(* Branch - parses the "L" & optional condition codes of a branch instruction.
				The language design of ARM assembler is really brain dead. We can't look for "B"/"BL" mnemonics at the beginning of an
				identifier and decide whether it is a branch or a branch and link instruction, because a branch if less than/if less than or
				equal/if unsinged lower or same is BLT, BLE and BLS repectively...
		*)
		PROCEDURE Branch(VAR ident: Identifier): SET;
		VAR link: SET; pos: LONGINT;
		BEGIN
			(* the "B" is already gone. Now we have to check if it's a BL[cond] or a B[cond] *)
			IF (ident[0] = "L") & (ident[1] # "S") & (ident[1] # "T") & ((ident[1] # "E") OR (ident[2] = "Q")) THEN
				(* it's a branch-and-link: not BLS, not BLT, not BLE (but maybe BLEQ) *)
				link := PCOARM.LinkBit;
				pos := 1;
				WHILE (ident[pos] # 0X) DO ident[pos-1] := ident[pos]; INC(pos) END;
				ident[pos-1] := 0X
			END;
			RETURN link + Condition(ident)
		END Branch;

		(* Condition - checks if 'ident' contains a conditional execution code. If true the opcode for this condition is
				returned and the condition code removed from 'ident'. Otherwise the unconditional execution opcode is returned.
		*)
		PROCEDURE Condition(VAR ident: Identifier): SET;
		VAR cond: Identifier; value: SET; p: LONGINT;
		BEGIN
			IF TraceParse THEN Write("  condition: ident = '"); Write(ident); Write("': ") END;
			cond[0] := ident[0]; cond[1] := ident[1]; cond[2] := 0X;
			IF symbols.Find(cond, stCondition, value) THEN
				p := 2; WHILE (ident[p] # 0X) DO ident[p-2] := ident[p]; INC(p) END;
				ident[p-2] := 0X;
				IF TraceParse THEN Write("found, ident = '"); Write(ident); WriteLn("'") END
			ELSE
				IF TraceParse THEN WriteLn("not found, using default") END;
				value := PCOARM.AL (* default *)
			END;
			RETURN value
		END Condition;

		(* SFlag - checks if 'ident' contains the 'S' flag (update condition codes). If true the 'S' flag opcode is returned and
				the flag deleted from 'ident'.
		*)
		PROCEDURE SFlag(VAR ident: Identifier):SET;
		VAR p: LONGINT;
		BEGIN
			IF (Cap(ident[0]) = "S") THEN
				p := 1; WHILE (ident[p] # 0X) DO ident[p-1] := ident[p]; INC(p) END; ident[p-1] := 0X;
				RETURN PCOARM.Sflag
			ELSE RETURN {}
			END
		END SFlag;

		(* BFlag - checks if 'ident' contains the 'B' flag (swap byte, used in SWP instructions). If true the 'B' flag opcode is returned and
				the flag deleted from 'ident'.
		*)
		PROCEDURE BFlag(VAR ident: Identifier):SET;
		VAR p: LONGINT;
		BEGIN
			IF (Cap(ident[0]) = "B") THEN
				p := 1; WHILE (ident[p] # 0X) DO ident[p-1] := ident[p]; INC(p) END; ident[p-1] := 0X;
				RETURN PCOARM.Bflag
			ELSE RETURN {}
			END
		END BFlag;

		(* LFlag - checks if 'ident' contains the 'L' flag (long load, used in LDC instructions). If true the 'L' flag opcode is returned and
				the flag deleted from 'ident'.
		*)
		PROCEDURE LFlag(VAR ident: Identifier):SET;
		VAR p: LONGINT;
		BEGIN
			IF (Cap(ident[0]) = "L") THEN
				p := 1; WHILE (ident[p] # 0X) DO ident[p-1] := ident[p]; INC(p) END; ident[p-1] := 0X;
				RETURN PCOARM.Lflag
			ELSE RETURN {}
			END
		END LFlag;

		(* Register - parses a register and returns its opcode shifted left by 'shift' *)
		PROCEDURE Register(type, shift: LONGINT): SET;
		VAR value: SET;
		BEGIN
			IF (scanner.symbol = sIdent) & symbols.Find(scanner.ident, type, value) THEN
				scanner.Scan;
				RETURN LSH(value, shift)
			ELSE Error(499);
				RETURN {} (* error: register expected *)
			END
		END Register;

		PROCEDURE Target(): SET;
		VAR offset: SET; obj: PCT.Symbol; adr: PCBT.Procedure; fixup: PCLIR.AsmFixup; idx: PCT.StringIndex;
		BEGIN
			IF (scanner.symbol = sIdent) THEN
				(* first check if it is a procedure *)
				StringPool.GetIndex(scanner.ident, idx);
				IF (scope # NIL) THEN obj := PCT.Find(scope, scope, idx, PCT.procdeclared, TRUE)
				ELSE obj := NIL
				END;
				IF (obj # NIL) THEN
					IF (obj IS PCT.Proc) THEN
						adr := obj.adr(PCBT.Procedure);
						IF (adr.owner = PCBT.context) THEN
							IF (adr.codeoffset = 0) THEN (* address unknown, will be patched later *)
								NEW(fixup); fixup.offset := pc; fixup.adr := adr; fixup.next := asm.fixup;
								asm.fixup := fixup;
								offset := {}
							ELSE (* address already known (this is probabely never the case) *)
								offset := SYSTEM.VAL(SET, (adr.codeoffset - pc - 8) DIV 4)
							END
						ELSE
							Error(499) (* imported procedures cannot be called *)
						END
					ELSE
						Error(499) (* procedure name expected *)
					END
				ELSE (* it's a label *)
					offset := labels.AddUse(scanner.position, pc, scanner.ident, ltBranch, 0);
				END;
				scanner.Scan
			ELSE Error(499) (* CHECK: allow numbers ? *)
			END;
			RETURN offset
		END Target;

		(* Variable - parses a use of a variable. Variables can be used in ldr/str instructions only.
			The user is responsible for choosing the correct load/store mode (word,halfword,byte & signed/unsigned access).
			'Variable' only prepares the value (for value parameters) or the address (for reference parameters)
			by loading the base register (SP or FP) and the offset into the return value (but not the addressing mode !)
		*)
		PROCEDURE Variable(mode: LONGINT): SET;
		VAR var: SET; obj: PCT.Symbol; offset: LONGINT; idx: PCT.StringIndex;
		BEGIN
			StringPool.GetIndex(scanner.ident, idx);
			IF (scope # NIL) THEN obj := PCT.Find(scope, scope, idx, PCT.procdeclared, TRUE)
			ELSE obj := NIL
			END;

			IF (obj # NIL) THEN
				IF (obj IS PCT.Variable) THEN
					IF (obj IS PCT.GlobalVar) THEN
						(* This loads the address of a global variable that must be defined by an 'ADDR' directive.
							The load is pc-relative.
						*)
						IF ~(symbols.Find("PC", stRegister, var)) THEN HALT(INTERNALERROR) END;
						var := LSH(var, 16) + labels.AddUse(scanner.position, pc, scanner.ident, ltAddress, mode)
					ELSE
						IF (obj IS PCT.Parameter) & ~inlined THEN
							IF ~(symbols.Find("FP", stRegister, var)) THEN HALT(INTERNALERROR) END
						ELSE
							IF ~(symbols.Find("SP", stRegister, var)) THEN HALT(INTERNALERROR) END
						END;
						offset := obj.adr(PCBT.Variable).offset;
						IF (obj IS PCT.Parameter) & inlined THEN (* no PAF -> adjust offset relative to SP *)
							(* if we have no stack frame, the SP points to the first parameter. Normally, there's a
								gap of 8 bytes between the first parameter and the FP, so we have to adjust this
							*)
							offset := offset - 8;
						END;
						IF (ABS(offset) < 1000H) THEN
							var := LSH(var, 16) + SYSTEM.VAL(SET, ABS(offset)) + PCOARM.Offset;
							IF (offset < 0) THEN var := var + PCOARM.IdxSub
							ELSE var := var + PCOARM.IdxAdd
							END
						ELSE Error(499) (* offset too big *)
						END
					END;
					scanner.Scan
				ELSE Error(499) (* not a variable *)
				END
			ELSE
				(* This loads the "value" of a label, i.e. the first byte/halfword/word following the definition of the label *)
				IF ~(symbols.Find("PC", stRegister, var)) THEN HALT(INTERNALERROR) END;
				var := LSH(var, 16) + labels.AddUse(scanner.position, pc, scanner.ident, ltAddress, mode);
				scanner.Scan
			END;
			RETURN var
		END Variable;

		(*------------------------------- Addressing Mode 1 -------------------------------*)
		(* Shift - parses a shifter
				["," ((LSL|LSR|ASR|ROR) (#<shift imm>|<Rs>) | RRX)]
		*)
		PROCEDURE Shift(): SET;
		VAR shift: SET; shifter: Identifier;
		BEGIN
			IF scanner.Match(sComma) THEN
				IF (scanner.symbol = sIdent) & symbols.Find(scanner.ident, stShift, shift) THEN
					shifter := scanner.ident;
					scanner.Scan;
					IF (scanner.symbol = sCR) THEN (* must be RRX *)
						IF (shifter # "RRX") THEN Error(499) (* malformed addressing mode (RRX has no parameters) *)
						END
					ELSIF (shifter # "RRX") THEN (* must not be RRX *)
						IF (scanner.symbol = sNumber) THEN
							shift := shift + PCOARM.A1ShiftImm;
							IF (-32 < scanner.number) & (scanner.number < 32) THEN
								shift := shift + LSH(SYSTEM.VAL(SET, scanner.number)*{0..4}, 7)
							ELSE Error(499) (* malformed addressing mode (immediate shift invalid) *)
							END;
							scanner.Scan
						ELSIF (scanner.symbol = sIdent) THEN
							shift := shift + PCOARM.A1ShiftReg + Register(stRegister, 8)
						ELSE Error(499) (* malformed addressing mode (shifter invalid) *)
						END;
					ELSE Error(499) (* malformed addressing mode (RRX has no parameters) *)
					END;
				ELSE Error(499) (* malformed addressing mode (invalid shift mode) *)
				END
			END;
			RETURN shift
		END Shift;

		(* RotateImmediate - try to split an immediate into 4 bit rotate and 8 bit immediate *)
		PROCEDURE RotateImmediate(): SET;
		VAR s: SET; rot: LONGINT;
		BEGIN
			ASSERT(scanner.symbol = sNumber);
			rot := 0; s := SYSTEM.VAL(SET, scanner.number);
			WHILE (rot < 32) & (ODD(rot) OR (s * { 8..31} # {})) DO
				s := ROT(s, 1); INC(rot)
			END;
			IF (rot < 32) THEN
				s := s + SYSTEM.VAL(SET, LSH(rot DIV 2, 8))
			ELSE Error(499); (* malformed addressing mode (immediate can't be generated) *)
				s := {}
			END;
			scanner.Scan;
			RETURN s
		END RotateImmediate;

		(* AddressingMode1 - parses addressing mode 1
			(#<immediate> | <Rm> ["," Shift])
		*)
		PROCEDURE AddressingMode1(): SET;
		VAR mode: SET;
		BEGIN
			IF (scanner.symbol = sNumber) THEN
				mode := mode + PCOARM.A1Imm + RotateImmediate()
			ELSIF (scanner.symbol = sIdent) THEN
				mode := mode + PCOARM.A1Reg + Register(stRegister, 0) + Shift()
			ELSE Error(499) (* number or register expected *)
			END;
			RETURN mode
		END AddressingMode1;

		(*------------------------------- Addressing Mode 2 -------------------------------*)

		(* Offset12 - reads a signed 12bit offset
			#["+"|"-"]<offset12>
		*)
		PROCEDURE Offset12(): SET;
		VAR offset: SET;
		BEGIN (* wp: scanner.symbol = sNumber *)
			ASSERT(scanner.symbol = sNumber);
			IF (ABS(scanner.number) < 1000H) THEN
				IF (scanner.number < 0) THEN offset := PCOARM.IdxSub
				ELSE offset := PCOARM.IdxAdd
				END;
				offset := offset + PCOARM.A2Imm + SYSTEM.VAL(SET, ABS(scanner.number))
			ELSE Error(499) (* offset too big *)
			END;
			scanner.Scan;
			RETURN offset + PCOARM.A2Imm
		END Offset12;

		(* ScaledRegister - returns a register offset, optionally scaled
			["+"|"-"]<Rm> Shift
		*)
		PROCEDURE ScaledRegister(): SET;
		VAR regoffset: SET;
		BEGIN (* wp: scanner.symbol IN (sIdent, sPlus, sMinus) *)
			ASSERT((scanner.symbol = sIdent) OR (scanner.symbol = sPlus) OR (scanner.symbol = sMinus));
			CASE scanner.symbol OF
			| sIdent: regoffset := PCOARM.IdxAdd
			| sPlus: regoffset := PCOARM.IdxAdd; scanner.Scan
			| sMinus: regoffset := PCOARM.IdxSub; scanner.Scan
			END;
			RETURN  regoffset + PCOARM.A2Reg + Register(stRegister, 0) + Shift()
		END ScaledRegister;

		(* OffsetRegister2 - parses a offset or an optionally scaled register
			( Offset12 | ScaledRegister )
		*)
		PROCEDURE OffsetRegister2(): SET;
		VAR offreg: SET;
		BEGIN
			IF (scanner.symbol = sNumber) THEN
				offreg := offreg + Offset12()	(* immediate offset *)
			ELSIF (scanner.symbol = sIdent) OR (scanner.symbol = sPlus) OR (scanner.symbol = sMinus) THEN
				offreg := offreg + ScaledRegister()
			ELSE Error(499) (* malformed addressing mode *)
			END;
			RETURN offreg
		END OffsetRegister2;

		(* PreIndexed - returns the addressing mode 'preindexed' or 'offset'
			"]" ["!"]
		*)
		PROCEDURE PreIndexed(): SET;
		VAR preidxd: SET;
		BEGIN (* wp: scanner.symbol = sRBrak *)
			IF scanner.Match(sRBrak) THEN
				IF scanner.Match(sExclamation) THEN preidxd := PCOARM.PreIdxd
				ELSE preidxd := PCOARM.Offset
				END
			ELSE Error(499) (* malformed addressing mode ("]" expected) *)
			END;
			RETURN preidxd
		END PreIndexed;

		(* AddressingMode2 - parses addressing mode 2
			"["<Rn> ("," OffsetRegister [PreIndexed] | "]," OffsetRegister )
		*)
		PROCEDURE AddressingMode2(): SET;
		VAR mode, s: SET;
		BEGIN
			IF scanner.Match(sLBrak) THEN
				IF (scanner.symbol = sIdent) THEN
					IF symbols.Find(scanner.ident, stRegister, s) THEN
						mode := Register(stRegister, 16);	(* Rn *)
						IF (scanner.symbol = sComma) THEN (* immediate/register pre-indexed/offset mode *)
							scanner.Scan;
							mode := mode + OffsetRegister2() + PreIndexed()
						ELSIF (scanner.symbol = sRBrak) THEN (* post-indexed mode *)
							scanner.Scan;
							IF scanner.Match(sComma) THEN
								mode := mode + PCOARM.PostIdxd + OffsetRegister2()
							ELSE Error(499) (* malformed addressing mode ("," expected) *)
							END
						END
					ELSE (* form: [address] *)
						(*IF ~(symbols.Find("PC", stRegister, mode)) THEN HALT(INTERNALERROR) END;
						mode := LSH(mode, 16) + labels.AddUse(scanner.position, pc, scanner.ident, ltAddress, lmLoad);
						scanner.Scan;
						IF ~scanner.Match(sRBrak) THEN
							Error(499) (* ']' expected *)
						END*)
						Error(499)
					END
				ELSE Error(499) (* register/identifier expected *)
				END
			ELSIF (scanner.symbol = sIdent) THEN mode := Variable(lmLoad) + PCOARM.A2Imm
			ELSE Error(499)
			END;
			RETURN mode
		END AddressingMode2;

		(*------------------------------- Addressing Mode 3 -------------------------------*)

		(* A3Offset8 - reads a signed 8bit offset
			#["+"|"-"]<offset8>
		*)
		PROCEDURE A3Offset8(): SET;
		VAR offset: SET; v: LONGINT;
		BEGIN
			ASSERT(scanner.symbol = sNumber);
			IF (ABS(scanner.number) < 100H) THEN
				v := ABS(scanner.number);
				offset := PCOARM.A3Imm + SYSTEM.VAL(SET, (v DIV 10H) * 100H + v MOD 10H);
				IF (scanner.number < 0) THEN offset := offset + PCOARM.IdxSub
				ELSE offset := offset + PCOARM.IdxAdd
				END
			ELSE Error(499) (* offset too big *)
			END;
			scanner.Scan;
			RETURN offset
		END A3Offset8;

		(* OffsetRegister3 - parses an offset or register
			( Offset0 | Register )
		*)
		PROCEDURE OffsetRegister3(): SET;
		VAR offreg: SET;
		BEGIN
			IF (scanner.symbol = sNumber) THEN
				offreg := offreg + A3Offset8()	(* immediate offset *)
			ELSIF (scanner.symbol = sIdent) OR (scanner.symbol = sPlus) OR (scanner.symbol = sMinus) THEN
				CASE scanner.symbol OF
				| sIdent: offreg := PCOARM.IdxAdd
				| sPlus: offreg := PCOARM.IdxAdd; scanner.Scan
				| sMinus: offreg := PCOARM.IdxSub; scanner.Scan
				END;
				offreg := offreg + PCOARM.A3Reg + Register(stRegister, 0)
			ELSE Error(499) (* malformed addressing mode *)
			END;
			RETURN offreg
		END OffsetRegister3;

		(* AddressingMode3 - parses addresing mode 3
		*)
		PROCEDURE AddressingMode3(): SET;
		VAR mode, s: SET;
		BEGIN
			IF scanner.Match(sLBrak) THEN
				IF (scanner.symbol = sIdent) THEN
					IF symbols.Find(scanner.ident, stRegister, s) THEN
						mode := Register(stRegister, 16);	(* Rn *)
						IF (scanner.symbol = sComma) THEN (* immediate/register pre-indexed/offset mode *)
							scanner.Scan;
							mode := mode + OffsetRegister3() + PreIndexed()
						ELSIF (scanner.symbol = sRBrak) THEN (* post-indexed mode *)
							scanner.Scan;
							IF scanner.Match(sComma) THEN
								mode := mode + PCOARM.PostIdxd + OffsetRegister3()
							ELSIF (scanner.symbol = sCR) THEN
								mode := mode + PCOARM.PostIdxd + PCOARM.A3Imm
								ELSE Error(499) (* malformed addressing mode ("," expected) *)
							END
						END
					ELSE (* form: [address] *)
						(*IF ~(symbols.Find("PC", stRegister, mode)) THEN HALT(INTERNALERROR) END;
						mode := LSH(mode, 16) + labels.AddUse(scanner.position, pc, scanner.ident, ltAddress, lmLoadSpecial);
						scanner.Scan;
						IF ~scanner.Match(sRBrak) THEN
							Error(499) (* "]" expected *)
						END*)
						Error(499)
					END
				ELSE Error(499) (* register/identifier expected *)
				END
			ELSIF (scanner.symbol = sIdent) THEN mode := Variable(lmLoadSpecial) + PCOARM.A3Imm
			ELSE Error(499)
			END;
			RETURN mode
		END AddressingMode3;

		(* Special - returns either 'normalMode' or 'specialMode', depending on which symbol type 'ident' matches, or -1 on error *)
		PROCEDURE Special(normalMode, specialMode: LONGINT; VAR ident: Identifier; VAR opcode: SET; opcode2: SET): LONGINT;
		BEGIN
			IF TraceParse THEN Write("  special: ident is '"); Write(ident); Write("': ") END;
			IF (ident = "") OR symbols.Find(ident, normalMode, opcode) THEN
				IF TraceParse THEN WriteLn("normal mode") END;
				ident := "";
				opcode := opcode + opcode2 + PCOARM.A2Mode;
				RETURN normalMode
			ELSIF symbols.Find(ident, specialMode, opcode) THEN
				IF TraceParse THEN WriteLn("special mode") END;
				ident := "";
				opcode := opcode + opcode2 + PCOARM.A3Mode;
				RETURN specialMode
			ELSE Error(499); (* invalid load/store *)
				IF TraceParse THEN WriteLn(" ERROR") END;
				RETURN -1
			END
		END Special;

		(* LoadStore - parses load/store instructions
			suffix <Rd> "," (AddressingMode2|AddressingMode3)
		*)
		PROCEDURE LoadStore(VAR ident: Identifier; normalMode, specialMode: LONGINT): SET;
		VAR ls: SET; mode: LONGINT;
		BEGIN
			ls := Register(stRegister, 12);
			IF scanner.Match(sComma) THEN
				mode := Special(normalMode, specialMode, ident, ls, ls);
				IF (mode = normalMode) THEN ls := ls + AddressingMode2()
				ELSIF (mode = specialMode) THEN ls := ls + AddressingMode3()
				ELSE Error(499)
				END
			ELSE Error(19) (* malformed load/store: "," expected *)
			END;
			RETURN ls
		END LoadStore;

		(*--------------------------- Load/Store Multiple --------------------------------*)

		PROCEDURE RegisterList(mode: SET): SET;
		VAR regList: SET; regOne, regTwo, i: LONGINT; continue: BOOLEAN;
		BEGIN
			IF scanner.Match(sLBrace) THEN
				continue := TRUE;
				WHILE continue DO
					continue := FALSE;
					regOne := SYSTEM.VAL(LONGINT, Register(stRegister, 0));
					IF scanner.Match(sMinus) THEN
						regTwo := SYSTEM.VAL(LONGINT, Register(stRegister, 0));
						IF (regOne < regTwo) THEN
							FOR i := regOne TO regTwo DO INCL(regList, i) END
						ELSE Error(499) (* error, lower register must be the first one *)
						END
					ELSE
						INCL(regList, regOne)
					END;
					continue := scanner.Match(sComma);
				END;
				IF scanner.Match(sRBrace) THEN
					IF scanner.Match(sArrow) THEN
						regList := regList + PCOARM.A4User;

						IF (PCOARM.A4W * mode = PCOARM.A4W) & ((opcode * PCOARM.A4LDMMask = {}) OR ~(PCOARM.PC IN regList)) THEN
							(* it'sn't a LDM, but regList includes the PC and write-back is selected ;-) *)
							Error(499)	(* STM(2): write-back not supported *)
						END
					END
				ELSE Error(499) (* "}" expected *)
				END
			ELSE Error(499) (* "{" expected *)
			END;
			RETURN regList
		END RegisterList;

		PROCEDURE LoadStoreMultiple(VAR ident: Identifier): SET;
		VAR mode: SET; load: BOOLEAN;
		BEGIN
			(* ugly.... *)
			load := opcode * PCOARM.A4LDMMask # {};
			IF (ident = "FD") THEN
				IF load THEN ident := "IA"
				ELSE ident := "DB"
				END
			ELSIF (ident = "ED") THEN
				IF load THEN ident := "IB"
				ELSE ident := "DA"
				END
			ELSIF (ident = "FA") THEN
				IF load THEN ident := "DA"
				ELSE ident := "IB"
				END
			ELSIF (ident = "EA") THEN
				IF load THEN ident := "DB"
				ELSE ident := "IA"
				END
			END;

			IF symbols.Find(ident, stMultipleMode, mode) THEN
				ident := "";
				mode := mode + Register(stRegister, 16);
				IF scanner.Match(sExclamation) THEN mode := mode + PCOARM.A4W END;
				IF scanner.Match(sComma) THEN mode := mode + RegisterList(mode)
				ELSE Error(499) (* "," expected *)
				END
			ELSE Error(499) (* malformed addressing mode *)
			END;
			RETURN mode
		END LoadStoreMultiple;


		(*------------------------------- MRS/MSR ------------------------------------*)

		(* PSR - parses the program status register. If 'extended'=TRUE, the PSR may be followed by PSR flags. *)
		PROCEDURE PSR(extended: BOOLEAN): SET;
		VAR psr, flag: SET; dummy: BOOLEAN;
		BEGIN
			IF (scanner.symbol = sIdent) THEN
				IF extended & symbols.Prefix(scanner.ident, stStateRegister, psr) THEN
					dummy := symbols.Prefix(scanner.ident, stStateRegisterFlagSeparator, flag);
					WHILE (scanner.ident[0] # 0X) DO
						IF symbols.Prefix(scanner.ident, stStateRegisterFlag, flag) THEN
							psr := psr + flag
						ELSE (* malformed PSR *)
							scanner.ident[0] := 0X; Error(499)
						END
					END
				ELSIF extended OR ~symbols.Find(scanner.ident, stStateRegister, psr) THEN
					Error(499) (* malformed instruction: PSR expected *)
				END;
				scanner.Scan
			ELSE Error(499) (* malformed instruction: PSR expected *)
			END;
			RETURN psr
		END PSR;

		(* MSR - parses the operand part of the MSR instruction*)
		PROCEDURE MSR(): SET;
		VAR msr: SET;
		BEGIN
			msr := PSR(TRUE);
			IF scanner.Match(sComma) THEN
				IF (scanner.symbol = sNumber) THEN
					msr := msr + PCOARM.A1Imm + RotateImmediate()
				ELSIF (scanner.symbol = sIdent) THEN
					msr := msr + Register(stRegister, 0)
				ELSE Error(499) (* malformed MSR command: register or immediate expected *)
				END
			ELSE Error(499) (* malformed MSR command: "," expected *)
			END;
			RETURN msr
		END MSR;

		(*----------------------------- miscellaneous -----------------------------*)

		(* Swap - parses the memory location of a SWP[B] instruction
			"[" <Rn> "]"
		*)
		PROCEDURE Swap(): SET;
		VAR r: SET;
		BEGIN
			IF scanner.Match(sLBrak) THEN
				r := Register(stRegister, 16);
				IF ~scanner.Match(sRBrak) THEN r := {}; Error(499) (* malformed SWP[B] instruction: "]" expected *)
				END
			ELSE Error(499) (* malformed SWP[B] instruction: "[" expected *)
			END;
			RETURN r
		END Swap;

		(* Immediate24 - parses a 24bit immediate value *)
		PROCEDURE Immediate24(): SET;
		VAR imm: SET;
		BEGIN
			Write("Immediate24 - ");
			IF (scanner.symbol = sNumber) THEN
				IF (scanner.number >= 0) & (scanner.number < 1000000H) THEN
					imm := SYSTEM.VAL(SET, scanner.number);
					scanner.Scan
				ELSE Error(499) (* immediate too small/big *)
				END
			ELSE Error(499) (* immediate expected *)
			END;
			RETURN imm
		END Immediate24;

		(* BkptImmediate - parses a 16bit immediate value and places it into bits 19-8, 3-0 (used by BKPT) *)
		PROCEDURE BkptImmediate(): SET;
		VAR imm: SET;
		BEGIN
			IF (scanner.symbol = sNumber) THEN
				IF (scanner.number >= 0) & (scanner.number < 10000) THEN
					imm := SYSTEM.VAL(SET, ((scanner.number DIV 10H) * 100H + scanner.number MOD 10H));
					scanner.Scan
				ELSE Error(499) (* immediate too small/big *)
				END
			ELSE Error(499) (* immediate expected *)
			END;
			RETURN imm
		END BkptImmediate;

		(* CPOpcode - parses a coprocessor opcode *)
		PROCEDURE CPOpcode(shift, max: LONGINT): SET;
		VAR opcode: SET;
		BEGIN
			IF (scanner.symbol = sNumber) THEN
				IF (scanner.number >= 0) & (scanner.number < max) THEN
					opcode := LSH(SYSTEM.VAL(SET, scanner.number), shift);
					scanner.Scan
				ELSE Error(499); (* opcode too small/big *)
					ErrorStr("CPOpcode: opcode too small/big")
				END
			ELSE Error(499); (* opcode expected *)
				ErrorStr("CPOpcode: opcode expected")
			END;
			RETURN opcode
		END CPOpcode;

		(* MoveCoprocessor -
			<CRm> ["," <opcode2]
		*)
		PROCEDURE MoveCoprocessor(): SET;
		VAR opcode: SET;
		BEGIN
			opcode := Register(stCPRegister, 0);
			IF (scanner.symbol = sComma) THEN
				scanner.Scan;
				opcode := opcode + CPOpcode(5, 8H)
			END;
			RETURN opcode
		END MoveCoprocessor;

		(* A5Offset8 - parses an 8bit offset *)
		PROCEDURE A5Offset8(): SET;
		VAR offset: SET;
		BEGIN
			ASSERT(scanner.symbol = sNumber);
			IF (ABS(scanner.number) < 100H) THEN
				IF (scanner.number < 0) THEN offset := PCOARM.IdxAdd
				ELSE offset := PCOARM.IdxSub
				END;
				offset := offset + SYSTEM.VAL(SET, ABS(scanner.number));
				scanner.Scan
			ELSE (* offset too small/big *) Error(499)
			END;
			RETURN offset
		END A5Offset8;

		(* LoadStoreCoprocessor -
			"[" <Rn> ("," "#"["+"/"-"] <offset8> "]" ["!"] | "]" "," ("#"["+"/"-"]<offset8> | <option>))
		*)
		PROCEDURE LoadStoreCoprocessor(): SET;
		VAR opcode: SET;
		BEGIN
			IF scanner.Match(sLBrak) THEN
				opcode := Register(stRegister, 16);
				IF (scanner.symbol = sComma) THEN
					scanner.Scan;
					IF (scanner.symbol = sNumber) THEN
						opcode := opcode + A5Offset8();
						IF scanner.Match(sRBrak) THEN
							IF scanner.Match(sExclamation) THEN opcode := opcode + PCOARM.A5PreIdxd
							ELSE opcode := opcode + PCOARM.A5Offset
							END
						ELSE (* "]" expected *) Error(499)
						END
					ELSE (* offset expected *) Error(499)
					END
				ELSIF (scanner.symbol = sRBrak) THEN
					scanner.Scan;
					IF scanner.Match(sComma) THEN
						IF (scanner.symbol = sNumber) THEN
							opcode := opcode + PCOARM.A5PostIdxd + A5Offset8()
						ELSIF scanner.Match(sLBrace) THEN
							IF (scanner.symbol = sNumber) THEN
								IF (scanner.number >= 0) & (scanner.number < 100H) THEN
									opcode := opcode + PCOARM.A5UnIdxd + SYSTEM.VAL(SET, scanner.number);
									scanner.Scan;
									IF ~scanner.Match(sRBrace) THEN (* "}" expected *) Error(499)
									END
								ELSE (* bare number too small/big *) Error(499)
								END
							ELSE (* bare number expected *) Error(499)
							END
						ELSE (* number or "{" expected *) Error(499)
						END
					ELSE (* "," expected *) Error(499)
					END
				ELSE (* "," or "]" expected *) Error(499)
				END
			ELSE (* "[" expected *) Error(499)
			END;
			RETURN opcode
		END LoadStoreCoprocessor;

		(* DCB - parses a DCB directive *)
		PROCEDURE DCB(): SET;
		VAR pos: LONGINT;
		BEGIN
			IF (scanner.symbol = sNumber) OR (scanner.symbol = sCharacter) OR (scanner.symbol = sString) THEN
				REPEAT
					IF (scanner.symbol = sNumber) THEN
						WriteLn("   number");
						IF (MIN(SHORTINT) > scanner.number) OR (scanner.number > 2*MAX(SHORTINT)+1) THEN
							Error(499) (* number too small/big *)
						ELSE
							PutData(scanner.number, 1)
						END
					ELSIF (scanner.symbol = sCharacter) THEN
						PutData(SYSTEM.VAL(LONGINT, scanner.ch), 1)
					ELSE
						WHILE (scanner.string[pos] # 0X) DO
							PutData(SYSTEM.VAL(LONGINT, scanner.string[pos]), 1);
							INC(pos)
						END;
						PutData(0, 1); (* 0X terminated *)
					END;
					scanner.Scan;
					IF scanner.Match(sComma) THEN END;
				UNTIL (scanner.symbol # sNumber) & (scanner.symbol # sCharacter) & (scanner.symbol # sString);
			ELSE WriteLn("data expected");
				Error(499) (* data expected *)
			END;
			ignore := TRUE;
			RETURN {}
		END DCB;

		(* DCW - parses a DCW directive *)
		PROCEDURE DCW(): SET;
		BEGIN
			IF (scanner.symbol = sNumber) THEN
				REPEAT
					IF (MIN(INTEGER) > scanner.number) OR (scanner.number > 2*MAX(INTEGER)+1) THEN
						Error(499) (* number too small/big *)
					ELSE
						PutData(scanner.number, 2)
					END;
					scanner.Scan;
					IF scanner.Match(sComma) THEN END;
				UNTIL (scanner.symbol # sNumber)
			ELSE Error(499) (* data expected *)
			END;
			ignore := TRUE;
			RETURN {}
		END DCW;

		(* DCD - parses a DCD directive *)
		PROCEDURE DCD(): SET;
		VAR adr: SET; obj: PCT.Symbol; fixup: PCLIR.AsmFixup; idx: PCT.StringIndex;
		BEGIN
			IF (scanner.symbol = sNumber) THEN
				REPEAT
					PutData(scanner.number, 4);
					scanner.Scan;
					IF scanner.Match(sComma) THEN END;
				UNTIL (scanner.symbol # sNumber)
			ELSIF (scanner.symbol = sIdent) THEN
				StringPool.GetIndex(scanner.ident, idx);
				obj := PCT.Find(scope, scope, idx, PCT.procdeclared, TRUE);
				IF (obj # NIL) & (obj IS PCT.GlobalVar) THEN
					labels.AddDefinition(scanner.position, pc, scanner.ident, ltAddress);
					NEW(fixup); fixup.offset := pc; fixup.adr := obj.adr;
					fixup.next := asm.fixup; asm.fixup := fixup;
					adr := SYSTEM.VAL(SET, obj(PCT.GlobalVar).adr(PCBT.GlobalVariable).offset);
					PutData(SYSTEM.VAL(LONGINT, adr), 4)
				ELSE Error(499) (* global var expected *)
				END;
				scanner.Scan
			END;
			ignore := TRUE;
			RETURN {}
		END DCD;

		(* DCFS - parses a DCFS directive *)
		PROCEDURE DCFS(): SET;
		BEGIN
			Error(499); (* not supported *)
			RETURN {}
		END DCFS;

		(* DCFD - parses a DCFD directive *)
		PROCEDURE DCFD(): SET;
		BEGIN
			Error(499); (* not supported *)
			RETURN {}
		END DCFD;

		(* ADR - parses the address part of an ADR instruction *)
		PROCEDURE ADR(): SET;
		VAR adr, imm, regPC: SET; offset: LONGINT;
		BEGIN
			IF (scanner.symbol = sIdent) THEN
				offset := SYSTEM.VAL(LONGINT, labels.AddUse(scanner.position, pc, scanner.ident, ltAddress, lmShifterOperand));
				IF (offset < 0) THEN adr := adr + PCOARM.opSUB; offset := -offset	(* offset known and negative *)
				ELSE adr := adr + PCOARM.opADD													(* offset positive or unknown (0) *)
				END;
				IF ~(PCOARM.MakeA1Immediate(offset, imm)) THEN Error(499) (* invalid offset *) END;
				IF ~(symbols.Find("PC", stRegister, regPC)) THEN HALT(INTERNALERROR) END;
				adr := adr + LSH(regPC, 16) + imm + PCOARM.A1Imm;
				scanner.Scan
			ELSE Error(499) (* identifier expected *)
			END;
			RETURN adr
		END ADR;

		(* DEFINE - parses a DEFINE directive *)
		PROCEDURE DEFINE(): SET;
		VAR ident: Identifier; s: Symbol;
		BEGIN
			IF TraceParse THEN WriteLn("  DEFINE:") END;
			IF (scanner.symbol = sIdent) THEN
				ident := scanner.ident;
				IF (symbols.GetSymbol(ident, stAll) = NIL) THEN
					scanner.Scan;
					IF scanner.Match(sEquals) THEN
						IF (scanner.symbol = sIdent) THEN
							s := symbols.GetSymbol(scanner.ident, stAll);
							IF (s # NIL) THEN
								symbols.Enter(ident, s.type, s.value, TRUE);
								scanner.Scan
							ELSE Error(499) (* definition not found *)
							END;
						ELSIF (scanner.symbol = sNumber) THEN
							Error(499);
							ErrorStr("DEFINED: number: NOT IMPLEMENTED")
						ELSE
							Error(499) (* identifier or number expected *)
						END
					END
				ELSE Error(499) (* already defined *)
				END
			ELSE Error(499) (* identifier expected *)
			END;
			ignore := TRUE;
			RETURN {};
		END DEFINE;


		(*-------------------------- main parser functions -------------------------------*)

		PROCEDURE ParseLabel;
		BEGIN (* wp: scanner.symbol = sLabel;  scanner.ident = label *)
			IF TraceParse THEN Write("  ParseLabel: ident = "); WriteLn(scanner.ident) END;
			labels.AddDefinition(scanner.position, pc, scanner.ident, ltBranch);
			labels.AddDefinition(scanner.position, pc, scanner.ident, ltAddress); (* could also be used as an address in a load/store *)
			scanner.Scan
		END ParseLabel;

		(* ParseInstruction - parses an instruction *)
		PROCEDURE ParseInstruction;
		VAR i: LONGINT; m: Mnemonic; comma: BOOLEAN; mnemonic: Identifier;
		BEGIN (* wp: scanner.symbol = sIdent; scanner.ident = mnemonic *)
			IF TraceParse THEN Write("  ParseInstruction: ident = "); WriteLn(scanner.ident) END;
			UpperCase(scanner.ident);
			m := mnemonics.Find(scanner.ident);
			IF (m # NIL) THEN
				ignore := FALSE;
				mnemonic := scanner.ident;
				scanner.Scan;
				opcode := m.opcode;
				IF (m.cond # NILIdentHandler) THEN opcode := opcode + m.cond(SELF, mnemonic) END;
				IF (m.suffix # NILIdentHandler) THEN opcode := opcode + m.suffix(SELF, mnemonic) END;
				IF (mnemonic # "") THEN Error(499) END; (* something is left *)
				FOR i := 0 TO 5 DO
					IF (m.handlers[i] # NIL(*Handler (was Delegate-NIL check workaround)*)) THEN
						IF TraceParse THEN Write("   handler "); Int(i); Write(": ") END;
						IF comma THEN
							IF TraceParse THEN WriteLn("(comma)") END;
							IF ~scanner.Match(sComma) THEN  Error(499) (* malformed instruction *)
							ELSE comma := FALSE
							END
						ELSIF TraceParse THEN Ln
						END;
						opcode := opcode + m.handlers[i](SELF);
						comma := TRUE
					END
				END;
				IF ~ignore THEN PutCode(opcode) END;
				IF TraceParse THEN Write("  End of ParseInstruction; symbol = "); Int(scanner.symbol); Ln END;
			ELSE  Error(499) (* undeclared identifier *)
			END
		END ParseInstruction;

		(* Error - reports an error to PCM *)
		PROCEDURE Error(code: LONGINT);
		BEGIN
			IF (code = 499) THEN HALT(MAX(INTEGER)) END;
			IF (scope # NIL) THEN PCM.Error(code, scanner.position, "")
			ELSE
				KernelLog.String("Error "); KernelLog.Int(code, 0); KernelLog.String(" at position "); KernelLog.Int(scanner.position, 0);
				KernelLog.Ln
			END
		END Error;

		(* ErrorStr - prints an error string *)
		PROCEDURE ErrorStr(msg: ARRAY OF CHAR);
		BEGIN
			IF (scope # NIL) THEN PCM.LogWStr(msg); PCM.LogWLn
			ELSE
				KernelLog.String(msg); KernelLog.Ln
			END
		END ErrorStr;

		(* PutCode - puts an opcode into the code array *)
		PROCEDURE PutCode(opcode: SET);
		TYPE Opcode = ARRAY 4 OF CHAR;
		VAR i: LONGINT; oc: Opcode;
		BEGIN
			IF (pc MOD 4 # 0) THEN PCM.Error(500, scanner.position, "Alignment fault.") END; (* alignment fault *)
			IF (code.len = 256) THEN NEW(code.next); code:= code.next; code.len := 0 END;
			oc := SYSTEM.VAL(Opcode, opcode);
			FOR i := 0 TO 3 DO
				IF PCM.bigEndian THEN
					code.code[code.len] := oc[3-i];
				ELSE
					code.code[code.len] := oc[i];
				END;
				INC(code.len)
			END;
			INC(pc, 4)
		END PutCode;

		(* PutData - puts data into the code array. 'size' = 1, 2 or 4 (bytes) *)
		PROCEDURE PutData(value, size: LONGINT);
		TYPE Data = ARRAY 4 OF CHAR;
		VAR data: Data; i: LONGINT;
		BEGIN
			IF (pc MOD size # 0) THEN PCM.Error(500, scanner.position, "Alignment fault.") END; (* alignment fault *)
			data := SYSTEM.VAL(Data, value);
			FOR i := 0 TO size-1 DO
				IF (code.len = 256) THEN NEW(code.next); code := code.next; code.len := 0 END;
				IF PCM.bigEndian THEN
					code.code[code.len] := data[size-1-i];
				ELSE
					code.code[code.len] := data[i];
				END;
				INC(code.len)
			END;
			INC(pc, size)
		END PutData;

		(* FixBranch - fixes the branch offset of a forward branch. Called by the label manager *)
		PROCEDURE FixBranch(pc: LONGINT; offset: SET);
		VAR i, v: LONGINT; code: PCLIR.AsmBlock;
		BEGIN
			IF TraceParse THEN Write("Fixing forward branch reference at pc "); Hex(pc, 8); Ln END;
			code := asm.code;
			WHILE (pc >= 256) & (code # NIL) DO code := code.next; DEC(pc, 256) END;
			ASSERT(code # NIL);
			v := SYSTEM.VAL(LONGINT, offset);

			IF PCM.bigEndian THEN
				INC(pc);
				PCM.SwapBytes(v, 0, 4);
				v := v DIV 100H;
			END;

			FOR i := 0 TO 2 DO
				code.code[pc] := CHR(v MOD 100H); INC(pc);
				v := v DIV 100H
			END
		END FixBranch;

		(* FixLoad - fixes the load offset of a forward load. Called by the label manager *)
		PROCEDURE FixLoad(pc: LONGINT; mode, offset: LONGINT);
		TYPE Opcode = ARRAY 4 OF CHAR;
		VAR i: LONGINT; code: PCLIR.AsmBlock; opcode, imm: SET; oc: Opcode;
		BEGIN
			IF TraceParse THEN Write("Fixing forward load reference at pc "); Hex(pc, 8); Ln END;
			code := asm.code;
			WHILE (pc > 256) & (code # NIL) DO code := code.next; DEC(pc, 256) END;
			ASSERT(code # NIL);

			FOR i := 0 TO 3 DO
				opcode := opcode + LSH(SYSTEM.VAL(SET, code.code[pc+i]), 8*i)
			END;

			IF PCM.bigEndian THEN
				PCM.SwapBytes(opcode, 0, 4);
			END;

			IF (offset >= MinMaxOffset[ltAddress + mode].min) & (offset <= MinMaxOffset[ltAddress + mode].max) THEN
				IF (mode = lmLoad) THEN
					ASSERT(opcode * PCOARM.opLDR = PCOARM.opLDR, 499); (* must be LDR *)
					opcode := opcode + PCOARM.A2Imm + PCOARM.Offset + SYSTEM.VAL(SET, ABS(offset));
					IF (offset < 0) THEN opcode := opcode + PCOARM.IdxSub
					ELSE opcode := opcode + PCOARM.IdxAdd
					END
				ELSIF (mode = lmLoadSpecial) THEN
					ASSERT(opcode * PCOARM.opLDRH = PCOARM.opLDRH, 499); (* must be LDRH *)
					opcode := opcode + PCOARM.A3Imm + PCOARM.Offset + SYSTEM.VAL(SET, ABS(offset) DIV 10H * 100H + ABS(offset) MOD 10H);
					IF (offset < 0) THEN opcode := opcode + PCOARM.IdxSub
					ELSE opcode := opcode + PCOARM.IdxAdd
					END
				ELSIF (mode = lmShifterOperand) THEN
					ASSERT(opcode * PCOARM.opADD = PCOARM.opADD, 499); (* must be ADD *)
					IF (offset < 0) THEN opcode := opcode - PCOARM.opADD + PCOARM.opSUB; offset := -offset END;
					IF ~PCOARM.MakeA1Immediate(offset, imm) THEN Error(499) END; (* cannot be generated *)
					opcode := opcode + imm
				ELSE
					HALT(INTERNALERROR)
				END;

				oc := SYSTEM.VAL(Opcode, opcode);
				IF PCM.bigEndian THEN
					PCM.SwapBytes(oc, 0, 4);
				END;
				FOR i := 0 TO 3 DO code.code[pc+i] := oc[i] END
			ELSE Error(499) (* offset too big *)
			END
		END FixLoad;

		(* Assemble - parses the input until an "END" symbol is found *)
		PROCEDURE Assemble(s: PCS.Scanner; scope: PCT.Scope; exported, inlined: BOOLEAN): PCLIR.AsmInline;
		VAR i, n: LONGINT; skip: BOOLEAN;
		BEGIN
			IF TraceParse THEN WriteLn("Assembling...") END;
			IF (scope # NIL) & ~scope.module.sysImported THEN
				PCM.Error(135, s.curpos, "SYSTEM not imported.");
				RETURN NIL
			END;
			NEW(SELF.scanner, s); SELF.scope := scope; SELF.exported := exported; SELF.inlined := inlined;
			NEW(SELF.symbols, symbolTable);
			NEW(asm); asm.paf := TRUE; NEW(asm.code); code := asm.code;
			NEW(labels, SELF);
			pc := 0; skip := FALSE;

			IF (scanner.symbol = sLBrace) THEN
				REPEAT
					scanner.Scan;
					IF (scanner.symbol = sIdent) THEN
						IF (scanner.ident = "SYSTEM") THEN
							scanner.Scan;
							IF (scanner.symbol = sLabel) THEN
								IF (scanner.ident = "ARM") THEN
									target := { ARM }
(* TODO
								ELSIF (scanner.ident = "THUMB") THEN
									target := { THUMB }
*)
								ELSE skip := TRUE; Error(499)	(* unknown target *)
								END
							ELSE skip := TRUE; Error(499)	(* ".Target" expected *)
							END
						ELSIF (scanner.ident = "NOPAF") THEN asm.paf := FALSE
						ELSE skip := TRUE; Error(499) (* unknown switch *)
						END;
						scanner.Scan;
						IF (scanner.symbol # sRBrace) & (scanner.symbol # sComma) THEN
							skip := TRUE; Error(499) (* "}" or "," expected *)
						END
					ELSE skip := TRUE; Error(499) (* identifier expected *)
					END;
				UNTIL (scanner.symbol = sRBrace) OR scanner.eot;
				IF scanner.Match(sRBrace) THEN END
			ELSIF (scope # NIL) THEN
				skip := TRUE; Error(499)	(* "{" expected *)
			END;

			IF (scope # NIL) & (target = {}) THEN
				skip := TRUE; Error(499)	(* no target specified *)
			END;

			IF ~skip THEN
				IF inlined THEN (* push locals on stack *)
					n := (scope(PCT.ProcScope).ownerO.adr(PCBT.Procedure).locsize + 3) DIV 4;
					IF (n >= 100H) THEN Error(499); RETURN NIL END;
					IF (n > 0) THEN
						PutCode(SYSTEM.VAL(SET, 0E3A00000H)); (* MOV R0, #0 *)
						FOR i := 1 TO n DO
							PutCode(SYSTEM.VAL(SET, 0E52D0004H)); (* STR R0, [SP, -4H]! *)
						END
					END
				END;

				WHILE ~scanner.eot & (scanner.symbol # sUndef) DO
					IF (scanner.symbol = sLabel) THEN ParseLabel END;
					IF (scanner.symbol = sIdent) THEN  ParseInstruction END;
					WHILE (scanner.symbol # sCR) & ~scanner.eot DO
						scanner.Scan; PCM.Error(510, scanner.position, "")
					END;
					(* wp: (scanner.symbol = sCr) OR scanner.eot *)
					scanner.Scan
				END;
				IF ~PCM.error THEN labels.Check END;

				IF inlined & (n > 0) THEN (* clean up stack *)
					PutCode(SYSTEM.VAL(SET, 0E3A0A000H + n)); (* MOV R10, n *)
					PutCode(SYSTEM.VAL(SET, 0E08DD10AH));		(* ADD SP, SP, R10, LSL 2 *)
				END;

				WHILE (pc MOD 4 # 0) DO PutData(0, 1) END; (* align *)

				symbols.ClearLocalSymbols
			ELSE
				WHILE ~scanner.eot DO scanner.Scan END	(* skip over assembly code *)
			END;

			IF TraceParse THEN Write("Done assembling.") END;
			RETURN asm
		END Assemble;
	END Assembler;

	(* Paco bug workaround - see above *)
	(* IdentHandler - 'ident' contains the string in question.
			If the IdentHandler scans part of the string, it has to delete this (sub)string from ident *)
	IdentHandler = PROCEDURE {DELEGATE} (assembler: Assembler; VAR ident: Identifier): SET;

	(* Parser Handler - on entry, the the scanner points to the first symbol.
			Each handler is responsible that on exit the scanner points to the first foreign symbol *)
	Handler = PROCEDURE {DELEGATE} (assembler: Assembler): SET;

VAR mnemonics: Mnemonics;
	symbolTable: SymbolTable;	(* "master" symbol table *)
	(* workaround for delegate=NIL tests *)
	NILIdentHandler: IdentHandler;
	NILHandler: Handler;

(* Install - called by Paco. Installs the assembler *)
PROCEDURE Install*;
BEGIN PCP.Assemble := Assemble
END Install;

(* Assemble - inline ARM assembler. Forks an object to support concurrency *)
PROCEDURE Assemble*(scanner:PCS.Scanner; scope: PCT.Scope; exported, inlined: BOOLEAN): PCM.Attribute;
VAR assembler: Assembler;
BEGIN
	NEW(assembler);
	RETURN assembler.Assemble(scanner, scope, exported, inlined)
END Assemble;

(* Initialize - initializes the symbols & mnemonics  *)
PROCEDURE Initialize;
VAR s: SymbolTable; m: Mnemonics;

	PROCEDURE Set(v: LONGINT): SET;
	BEGIN RETURN SYSTEM.VAL(SET,v)
	END Set;

BEGIN
	NEW(s, NIL); symbolTable := s;
	s.Enter("EQ", stCondition, PCOARM.EQ, FALSE);
	s.Enter("NE", stCondition, PCOARM.NE, FALSE);
	s.Enter("CS", stCondition, PCOARM.CS, FALSE);
	s.Enter("HS", stCondition, PCOARM.CS, FALSE);
	s.Enter("CC", stCondition, PCOARM.CC, FALSE);
	s.Enter("LO", stCondition, PCOARM.CC, FALSE);
	s.Enter("MI", stCondition, PCOARM.MI, FALSE);
	s.Enter("PL", stCondition, PCOARM.PL, FALSE);
	s.Enter("VS", stCondition, PCOARM.VS, FALSE);
	s.Enter("VC", stCondition, PCOARM.VC, FALSE);
	s.Enter("HI", stCondition, PCOARM.HI, FALSE);
	s.Enter("LS", stCondition, PCOARM.LS, FALSE);
	s.Enter("GE", stCondition, PCOARM.GE, FALSE);
	s.Enter("LT", stCondition, PCOARM.LT, FALSE);
	s.Enter("GT", stCondition, PCOARM.GT, FALSE);
	s.Enter("LE", stCondition, PCOARM.LE, FALSE);
	s.Enter("AL", stCondition, PCOARM.AL, FALSE);
	s.Enter("R0", stRegister, Set(PCOARM.R0), FALSE);
	s.Enter("R1", stRegister, Set(PCOARM.R1), FALSE);
	s.Enter("R2", stRegister, Set(PCOARM.R2), FALSE);
	s.Enter("R3", stRegister, Set(PCOARM.R3), FALSE);
	s.Enter("R4", stRegister, Set(PCOARM.R4), FALSE);
	s.Enter("R5", stRegister, Set(PCOARM.R5), FALSE);
	s.Enter("R6", stRegister, Set(PCOARM.R6), FALSE);
	s.Enter("R7", stRegister, Set(PCOARM.R7), FALSE);
	s.Enter("R8", stRegister, Set(PCOARM.R8), FALSE);
	s.Enter("R9", stRegister, Set(PCOARM.R9), FALSE);
	s.Enter("R10", stRegister, Set(PCOARM.R10), FALSE);
	s.Enter("R11", stRegister, Set(PCOARM.R11), FALSE);
	s.Enter("R12", stRegister, Set(PCOARM.FP), FALSE);
	s.Enter("FP", stRegister, Set(PCOARM.FP), FALSE);
	s.Enter("R13", stRegister, Set(PCOARM.SP), FALSE);
	s.Enter("SP", stRegister, Set(PCOARM.SP), FALSE);
	s.Enter("R14", stRegister, Set(PCOARM.LR), FALSE);
	s.Enter("LR", stRegister, Set(PCOARM.LR), FALSE);
	s.Enter("R15", stRegister, Set(PCOARM.PC), FALSE);
	s.Enter("PC", stRegister, Set(PCOARM.PC), FALSE);
	s.Enter("CPSR", stStateRegister, PCOARM.CPSR, FALSE);
	s.Enter("SPSR", stStateRegister, PCOARM.SPSR, FALSE);
	s.Enter("c", stStateRegisterFlag, PCOARM.PSRc, FALSE);
	s.Enter("x", stStateRegisterFlag, PCOARM.PSRx, FALSE);
	s.Enter("s", stStateRegisterFlag, PCOARM.PSRs, FALSE);
	s.Enter("f", stStateRegisterFlag, PCOARM.PSRf, FALSE);
	s.Enter("_", stStateRegisterFlagSeparator, {}, FALSE);
	s.Enter("LSL", stShift, PCOARM.Lsl, FALSE);
	s.Enter("LSR", stShift, PCOARM.LSR, FALSE);
	s.Enter("ASR", stShift, PCOARM.Asr, FALSE);
	s.Enter("ROR", stShift, PCOARM.Ror, FALSE);
	s.Enter("RRX", stShift, PCOARM.RRX, FALSE);
	s.Enter("B", stLoad, PCOARM.opLDR + PCOARM.A2Byte, FALSE);
	s.Enter("BT", stLoad, PCOARM.opLDR + PCOARM.A2Byte + PCOARM.PostIdxd, FALSE);
	s.Enter("H", stLoadSpecial,  PCOARM.opLDRH + PCOARM.A3Halfword + PCOARM.A3Unsigned, FALSE);
	s.Enter("SB", stLoadSpecial, PCOARM.opLDRH + PCOARM.A3Byte + PCOARM.A3Signed, FALSE);
	s.Enter("SH", stLoadSpecial, PCOARM.opLDRH + PCOARM.A3Halfword + PCOARM.A3Signed, FALSE);
	s.Enter("T", stLoad, PCOARM.opLDR + PCOARM.PostIdxd, FALSE);
	s.Enter("B", stStore, PCOARM.opSTR + PCOARM.A2Byte, FALSE);
	s.Enter("BT", stStore, PCOARM.opSTR + PCOARM.A2Byte + PCOARM.PostIdxd, FALSE);
	s.Enter("H", stStoreSpecial, PCOARM.opSTRH, FALSE);
	s.Enter("T", stStore, PCOARM.opSTR + PCOARM.PostIdxd, FALSE);
	s.Enter("IA", stMultipleMode, PCOARM.A4IA, FALSE);
	s.Enter("IB", stMultipleMode, PCOARM.A4IB, FALSE);
	s.Enter("DA", stMultipleMode, PCOARM.A4DA, FALSE);
	s.Enter("DB", stMultipleMode, PCOARM.A4DB, FALSE);
	(* cf. LoadStoreMultiple
	s.Enter("FD", stMultipleMode, PCOARM.A4IA, FALSE);
	s.Enter("FA", stMultipleMode, PCOARM.A4DA, FALSE);
	s.Enter("ED", stMultipleMode, PCOARM.A4IB, FALSE);
	s.Enter("EA", stMultipleMode, PCOARM.A4DB, FALSE);
	*)
	s.Enter("p0", stCoprocessor, Set(0), FALSE);
	s.Enter("p1", stCoprocessor, Set(1), FALSE);
	s.Enter("p2", stCoprocessor, Set(2), FALSE);
	s.Enter("p3", stCoprocessor, Set(3), FALSE);
	s.Enter("p4", stCoprocessor, Set(4), FALSE);
	s.Enter("p5", stCoprocessor, Set(5), FALSE);
	s.Enter("p6", stCoprocessor, Set(6), FALSE);
	s.Enter("p7", stCoprocessor, Set(7), FALSE);
	s.Enter("p8", stCoprocessor, Set(8), FALSE);
	s.Enter("p9", stCoprocessor, Set(9), FALSE);
	s.Enter("p10", stCoprocessor, Set(10), FALSE);
	s.Enter("p10", stCoprocessor, Set(11), FALSE);
	s.Enter("p12", stCoprocessor, Set(12), FALSE);
	s.Enter("p13", stCoprocessor, Set(13), FALSE);
	s.Enter("p14", stCoprocessor, Set(14), FALSE);
	s.Enter("p15", stCoprocessor, Set(15), FALSE);
	s.Enter("CR0", stCPRegister, Set(PCOARM.CR0), FALSE);
	s.Enter("CR1", stCPRegister, Set(PCOARM.CR1), FALSE);
	s.Enter("CR2", stCPRegister, Set(PCOARM.CR2), FALSE);
	s.Enter("CR3", stCPRegister, Set(PCOARM.CR3), FALSE);
	s.Enter("CR4", stCPRegister, Set(PCOARM.CR4), FALSE);
	s.Enter("CR5", stCPRegister, Set(PCOARM.CR5), FALSE);
	s.Enter("CR6", stCPRegister, Set(PCOARM.CR6), FALSE);
	s.Enter("CR7", stCPRegister, Set(PCOARM.CR7), FALSE);
	s.Enter("CR8", stCPRegister, Set(PCOARM.CR8), FALSE);
	s.Enter("CR9", stCPRegister, Set(PCOARM.CR9), FALSE);
	s.Enter("CR10", stCPRegister, Set(PCOARM.CR10), FALSE);
	s.Enter("CR11", stCPRegister, Set(PCOARM.CR11), FALSE);
	s.Enter("CR12", stCPRegister, Set(PCOARM.CR12), FALSE);
	s.Enter("CR13", stCPRegister, Set(PCOARM.CR13), FALSE);
	s.Enter("CR14", stCPRegister, Set(PCOARM.CR14), FALSE);
	s.Enter("CR15", stCPRegister, Set(PCOARM.CR15), FALSE);
	s.Enter("c0", stCPRegister, Set(PCOARM.CR0), FALSE);
	s.Enter("c1", stCPRegister, Set(PCOARM.CR1), FALSE);
	s.Enter("c2", stCPRegister, Set(PCOARM.CR2), FALSE);
	s.Enter("c3", stCPRegister, Set(PCOARM.CR3), FALSE);
	s.Enter("c4", stCPRegister, Set(PCOARM.CR4), FALSE);
	s.Enter("c5", stCPRegister, Set(PCOARM.CR5), FALSE);
	s.Enter("c6", stCPRegister, Set(PCOARM.CR6), FALSE);
	s.Enter("c7", stCPRegister, Set(PCOARM.CR7), FALSE);
	s.Enter("c8", stCPRegister, Set(PCOARM.CR8), FALSE);
	s.Enter("c9", stCPRegister, Set(PCOARM.CR9), FALSE);
	s.Enter("c10", stCPRegister, Set(PCOARM.CR10), FALSE);
	s.Enter("c11", stCPRegister, Set(PCOARM.CR11), FALSE);
	s.Enter("c12", stCPRegister, Set(PCOARM.CR12), FALSE);
	s.Enter("c13", stCPRegister, Set(PCOARM.CR13), FALSE);
	s.Enter("c14", stCPRegister, Set(PCOARM.CR14), FALSE);
	s.Enter("c15", stCPRegister, Set(PCOARM.CR15), FALSE);

	NEW(m); mnemonics := m;

	(* workaround for delegate=NIL checks *)
	(*NILIdentHandler := NIL;
	NILHandler := m.Nil;*)
	(* Branch Instructions *)
	m.Enter("B", PCOARM.opB, m.Branch, NIL, m.Target, NIL, NIL, NIL, NIL, NIL);
	(*m.Enter("BL", PCOARM.opBL, m.Condition, NIL, m.Target, NIL, NIL, NIL, NIL, NIL);*)
	(* Data-processing Instructions using Addressing Mode 1 *)
	m.Enter("AND", PCOARM.opAND, m.Condition, m.SFlag, m.R12, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("EOR", PCOARM.opEOR, m.Condition, m.SFlag, m.R12, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("SUB", PCOARM.opSUB, m.Condition, m.SFlag, m.R12, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("RSB", PCOARM.opRSB, m.Condition, m.SFlag, m.R12, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("ADD", PCOARM.opADD, m.Condition, m.SFlag, m.R12, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("ADC", PCOARM.opADC, m.Condition, m.SFlag, m.R12, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("SBC", PCOARM.opSBC, m.Condition, m.SFlag, m.R12, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("RSC", PCOARM.opRSC, m.Condition, m.SFlag, m.R12, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("TST", PCOARM.opTST, m.Condition, m.SFlag, NIL, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("TEQ", PCOARM.opTEQ, m.Condition, m.SFlag, NIL, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("CMP", PCOARM.opCMP, m.Condition, m.SFlag, NIL, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("CMN", PCOARM.opCMN, m.Condition, m.SFlag, NIL, m.R16, m.ShifterOperand, NIL, NIL, NIL); (* ejz, fof *)
	m.Enter("ORR", PCOARM.opORR, m.Condition, m.SFlag, m.R12, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("MOV", PCOARM.opMOV, m.Condition, m.SFlag, m.R12, NIL, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("BIC", PCOARM.opBIC, m.Condition, m.SFlag, m.R12, m.R16, m.ShifterOperand, NIL, NIL, NIL);
	m.Enter("MVN", PCOARM.opMVN, m.Condition, m.SFlag, m.R12, NIL, m.ShifterOperand, NIL, NIL, NIL);
	(* Multiply Instructions *)
	m.Enter("MLA", PCOARM.opMLA, m.Condition, m.SFlag, m.R16, m.R0, m.R8, m.R12, NIL, NIL);
	m.Enter("MUL", PCOARM.opMUL, m.Condition, m.SFlag, m.R16, m.R0, m.R8, NIL, NIL, NIL);
	m.Enter("SMLAL", PCOARM.opSMLAL, m.Condition, m.SFlag, m.R12, m.R16, m.R0, m.R8, NIL, NIL);
	m.Enter("SMULL", PCOARM.opSMULL, m.Condition, m.SFlag, m.R12, m.R16, m.R0, m.R8, NIL, NIL);
	m.Enter("UMLAL", PCOARM.opUMLAL, m.Condition, m.SFlag, m.R12, m.R16, m.R0, m.R8, NIL, NIL);
	m.Enter("UMULL", PCOARM.opUMULL, m.Condition, m.SFlag, m.R12, m.R16, m.R0, m.R8, NIL, NIL);
	(* Status Register Access Instructions *)
	m.Enter("MRS", PCOARM.opMRS, m.Condition, NIL, m.R12, m.PSR, NIL, NIL, NIL, NIL);
	m.Enter("MSR", PCOARM.opMSR, m.Condition, NIL, m.MSR, NIL, NIL, NIL, NIL, NIL);
	(* Load and Store Instructions *)
	m.Enter("LDR", PCOARM.Load, m.Condition, m.Load, NIL, NIL, NIL, NIL, NIL, NIL);
	m.Enter("STR", PCOARM.Store, m.Condition, m.Store, NIL, NIL, NIL, NIL, NIL, NIL);
	(* Load and Store Multiple Instructions *)
	m.Enter("LDM", PCOARM.opLDM, m.Condition, m.Multiple, NIL, NIL, NIL, NIL, NIL, NIL);
	m.Enter("STM", PCOARM.opSTM, m.Condition, m.Multiple, NIL, NIL, NIL, NIL, NIL, NIL);
	(* Semaphore Instructions *)
	m.Enter("SWP", PCOARM.opSWP, m.Condition, m.BFlag, m.R12, m.R0, m.Swap, NIL, NIL, NIL);
	(* Exception Generating Instructions *)
	m.Enter("SWI", PCOARM.opSWI, m.Condition, NIL, m.Immediate24, NIL, NIL, NIL, NIL, NIL);
	m.Enter("BKPT", PCOARM.opBKPT, NIL, NIL, m.BkptImmediate, NIL, NIL, NIL, NIL, NIL);
	(* Coprocessor Instructions *)
	m.Enter("CDP", PCOARM.opCDP, m.Condition, NIL, m.Coprocessor, m.CPOpcode1cdp, m.CR12, m.CR16, m.CR0, m.CPOpcode2);
	m.Enter("LDC", PCOARM.opLDC, m.Condition, m.LFlag, m.Coprocessor, m.CR12, m.LoadStoreCoprocessor, NIL, NIL, NIL);
	m.Enter("MCR", PCOARM.opMCR, m.Condition, NIL, m.Coprocessor, m.CPOpcode1m, m.R12, m.CR16, m.MoveCoprocessor, NIL);
	m.Enter("MRC", PCOARM.opMRC, m.Condition, NIL, m.Coprocessor, m.CPOpcode1m, m.R12, m.CR16, m.MoveCoprocessor, NIL);
	m.Enter("STC", PCOARM.opSTC, m.Condition, m.LFlag, m.Coprocessor, m.CR12, m.LoadStoreCoprocessor, NIL, NIL, NIL);
	(* Special Instructions *)
	m.Enter("ADR", {}, m.Condition, NIL, m.R12, m.ADR, NIL, NIL, NIL, NIL);
	(* Directives *)
	m.Enter("DCB", {}, NIL, NIL, m.DCB, NIL, NIL, NIL, NIL, NIL);
	m.Enter("DCW", {}, NIL, NIL, m.DCW, NIL, NIL, NIL, NIL, NIL);
	m.Enter("DCD", {}, NIL, NIL, m.DCD, NIL, NIL, NIL, NIL, NIL);
	m.Enter("DCFS", {}, NIL, NIL, m.DCFS, NIL, NIL, NIL, NIL, NIL);
	m.Enter("DCFD", {}, NIL, NIL, m.DCFD, NIL, NIL, NIL, NIL, NIL);
	m.Enter("DEFINE", {}, NIL, NIL, m.DEFINE, NIL, NIL, NIL, NIL, NIL);

	(* Template
	m.Enter("", PCOARM., m.Condition, m.SFlag, m., m., m., NIL, NIL, NIL);
	*)

	MinMaxOffset[ltBranch].min := MinBranchOffset;
	MinMaxOffset[ltBranch].max := MaxBranchOffset;
	MinMaxOffset[ltAddress + lmLoad].min := MinLoadOffset;
	MinMaxOffset[ltAddress + lmLoad].max := MaxLoadOffset;
	MinMaxOffset[ltAddress + lmLoadSpecial].min := MinLoadSpecialOffset;
	MinMaxOffset[ltAddress + lmLoadSpecial].max := MaxLoadSpecialOffset;
	MinMaxOffset[ltAddress + lmShifterOperand].min := MinShifterOperand;
	MinMaxOffset[ltAddress + lmShifterOperand].max := MaxShifterOperand
END Initialize;

PROCEDURE UpperCase(VAR s: ARRAY OF CHAR);
VAR p: LONGINT;
BEGIN WHILE (s[p] # 0X) DO s[p] := Cap(s[p]); INC(p) END
END UpperCase;

(* Cap - a CAP function that really works. ;-) *)
PROCEDURE Cap(ch: CHAR): CHAR;
BEGIN IF ("a" <= ch) & (ch <= "z") THEN RETURN CAP(ch) ELSE RETURN ch END
END Cap;

(* Length - returns the length of a string *)
PROCEDURE Length(s: ARRAY OF CHAR): LONGINT;
VAR p: LONGINT;
BEGIN WHILE(s[p] # 0X) DO INC(p) END; RETURN p
END Length;


PROCEDURE Char(c: CHAR);
BEGIN IF Trace THEN KernelLog.Char(c) END
END Char;

PROCEDURE Write(s: ARRAY OF CHAR);
BEGIN IF Trace THEN KernelLog.String(s) END
END Write;

PROCEDURE WriteLn(s: ARRAY OF CHAR);
BEGIN IF Trace THEN Write(s); KernelLog.Ln END
END WriteLn;

PROCEDURE Int(i: LONGINT);
BEGIN IF Trace THEN KernelLog.Int(i, 0) END
END Int;

PROCEDURE Hex(i, n: LONGINT);
BEGIN IF Trace THEN KernelLog.Hex(i, n) END
END Hex;

PROCEDURE Ln;
BEGIN IF Trace THEN KernelLog.Ln END
END Ln;


BEGIN Initialize
END PCAARM.ok

System.Free ASM PCAARM~