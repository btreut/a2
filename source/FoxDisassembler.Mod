MODULE FoxDisassembler; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Streams, ObjectFile, Scanner := FoxScanner, Basic := FoxBasic, BitSets, D := Debugging, Files, Commands;


CONST Trace = TRUE;
TYPE
	Block*= POINTER TO RECORD (ObjectFile.Section)
		to-: LONGINT;
		next-: Block;
	END;

	Disassembler* = OBJECT
	VAR
		first, block: Block; w: Streams.Writer; stringWriter: Streams.StringWriter; code,data: BitSets.BitSet; codeUnit, dataUnit: LONGINT;
		codeDisplacement-, dataDisplacement: LONGINT;

		PROCEDURE & Init*(w: Streams.Writer);
		BEGIN SELF.w := w; NEW(stringWriter, 256);
			codeDisplacement := 0; dataDisplacement := 0;

		END Init;

		PROCEDURE GetLogFile*(CONST binaryFileName: ARRAY OF CHAR): Files.File;
		VAR fileName,extension: Files.FileName;
		BEGIN
			Files.SplitExtension(binaryFileName, fileName, extension);
			Files.JoinExtension(fileName, "log", fileName);
			RETURN Files.Old(fileName)
		END GetLogFile;

		PROCEDURE BlockHeader(block: Block);
		VAR name: ObjectFile.SectionName; offset: LONGINT;
		BEGIN
			Basic.SegmentedNameToString(block.identifier.name, name);
			w.String("-------- "); w.Char(Scanner.TAB);
			IF  ObjectFile.IsCode(block.type) THEN w.String("code");
			ELSE w.String("data");
			END;
			w.Char(Scanner.TAB);
			w.String(name);
			w.String(" @");
			w.Hex(block.alignment,-8); (*w.String("-"); w.Hex(block.to+offset,-8);*)
			w.String(" ---");
			w.Ln;
		END BlockHeader;

		PROCEDURE WriteReference*(adr: LONGINT; isCode: BOOLEAN; w: Streams.Writer);
		VAR b: Block; name: ObjectFile.SectionName; offset: LONGINT;
		BEGIN
			w.String(" --> "); w.Hex(adr+codeDisplacement,-8);
			b := first; IF b = NIL THEN RETURN END;
			IF isCode THEN offset := codeDisplacement ELSE offset := dataDisplacement END;
			WHILE (b # NIL) & ((adr < b.alignment-offset) OR (adr > b.to - offset) OR (ObjectFile.IsCode(b.type)#isCode)) DO
				b := b.next;
			END;
			IF (b # NIL) & (b # block) THEN
				Basic.SegmentedNameToString(b.identifier.name, name);
				w.String(" [");
				w.String(name);
				IF adr # b.alignment THEN
					w.String("+"); w.Int(adr-b.alignment,1)
				END;
				w.String("]");
			END;
		END WriteReference;

		PROCEDURE DisassembleInstruction*(bitset: BitSets.BitSet; VAR adrInUnits: LONGINT; maxInstructionSize: LONGINT; w: Streams.Writer);
		BEGIN
		END DisassembleInstruction;

		PROCEDURE DisassembleBlock(from, to: LONGINT);
		VAR adr, prevadr, max, digit,value: LONGINT; string: ARRAY 256 OF CHAR;
		BEGIN
			IF code = NIL THEN RETURN END;
			adr := from;
			max := MIN(to+1, code.GetSize() DIV codeUnit);
			WHILE adr < max DO
				(* adr *)
				w.Hex(adr+codeDisplacement,-8); w.String(": ");
				prevadr := adr;
				DisassembleInstruction(code, adr, max-adr, stringWriter);
				IF prevadr = adr THEN w.String("decoder error: address must increase"); w.Ln; RETURN END;
				stringWriter.Update;
				stringWriter.Get(string);
				(* value *)
				WHILE prevadr < adr DO
					value := code.GetBits(prevadr*codeUnit, codeUnit);
					w.Hex(value,-((codeUnit-1) DIV 4 +1)); w.String(" ");
					INC(prevadr);
				END;
				(* instruction string *)
				w.Char(Scanner.TAB); w.String(string); w.Ln;
			END;
		END DisassembleBlock;

		PROCEDURE DataBlock(from, to: LONGINT);
		VAR adr,width,max,value: LONGINT;
		BEGIN
			IF data = NIL THEN RETURN END;
			adr := from;
			max := MIN(to+1, data.GetSize() DIV dataUnit);
			WHILE adr < max DO
				w.Hex(adr+dataDisplacement,-8); w.String(": ");
				width := 8;
				WHILE (adr < max) & (width > 0) DO
					value := data.GetBits(adr*dataUnit, dataUnit);
					w.Hex(value,-((dataUnit-1) DIV 4 +1)); w.String(" ");
					INC(adr); DEC(width);
				END;
				w.Ln;
			END;
		END DataBlock;

		PROCEDURE ParseLogFile*(file: Files.File): Block;
		VAR reader: Files.Reader; newline: BOOLEAN; sectionName: ObjectFile.SectionName; scanner: Scanner.AssemblerScanner;
			symbol: Scanner.Symbol; b: BOOLEAN; block: Block; first: Block; last: Block;

			PROCEDURE GetNextSymbol;
			VAR b: BOOLEAN;
			BEGIN b := scanner.GetNextSymbol(symbol)
			END GetNextSymbol;

			PROCEDURE ExpectToken(token: LONGINT): BOOLEAN;
			BEGIN IF symbol.token = token THEN GetNextSymbol; RETURN TRUE ELSE RETURN FALSE END;
			END ExpectToken;

			PROCEDURE ExpectIdentifier(VAR name: ARRAY OF CHAR): BOOLEAN;
			BEGIN
				IF (symbol.token = Scanner.Identifier) THEN COPY(symbol.identifierString,name); GetNextSymbol; RETURN TRUE
				ELSE RETURN FALSE
				END;
			END ExpectIdentifier;

			PROCEDURE ExpectThisIdentifier(CONST name: ARRAY OF CHAR): BOOLEAN;
			BEGIN
				IF (symbol.token = Scanner.Identifier) & (symbol.identifierString = name) THEN GetNextSymbol; RETURN TRUE
				ELSE RETURN FALSE
				END;
			END ExpectThisIdentifier;

			PROCEDURE ExpectNumber(VAR int: LONGINT):BOOLEAN;
			BEGIN
				IF (symbol.token = Scanner.Number) THEN
					int := SHORT(symbol.hugeint); GetNextSymbol; RETURN TRUE
				ELSE RETURN FALSE
				END;
			END ExpectNumber;

			PROCEDURE ParseLine(): Block;
			VAR from,to: LONGINT; block: Block; displacement: LONGINT;
			BEGIN
				block := NIL;
				IF ExpectNumber(from) & ExpectToken(Scanner.Colon) THEN
					IF ExpectThisIdentifier("code") & ExpectIdentifier(sectionName) &  ExpectThisIdentifier("to") & ExpectNumber(to) THEN
						NEW(block); block.type := ObjectFile.Code; Basic.ToSegmentedName(sectionName, block.identifier.name); block.alignment := from; block.fixed := TRUE; block.to := to;
					ELSIF ExpectThisIdentifier("data") & ExpectIdentifier(sectionName) &  ExpectThisIdentifier("to") & ExpectNumber(to) THEN
						NEW(block); block.type := ObjectFile.Data; Basic.ToSegmentedName(sectionName, block.identifier.name); block.alignment := from; block.fixed := TRUE; block.to := to;
					END;
				ELSIF ExpectThisIdentifier("code") & ExpectThisIdentifier("displacement") & ExpectNumber(displacement) THEN
					codeDisplacement := displacement; dataDisplacement := displacement
				ELSIF ExpectThisIdentifier("data") & ExpectThisIdentifier("displacement") & ExpectNumber(displacement) THEN
					dataDisplacement := displacement;
				ELSE scanner.SkipToEndOfLine; GetNextSymbol;	scanner.ResetError;
				END;
				IF (block # NIL) & Trace THEN
					D.String("found section ");
					D.String(sectionName);
					IF  ObjectFile.IsCode(block.type) THEN D.String(" (code) ") ELSE D.String(" (data) ") END;
					D.Int(block.alignment,1); D.String(" "); D.Int(block.to,1);
					D.Ln;
				END;
				RETURN block
			END ParseLine;

		BEGIN
			first := NIL; last := NIL;
			IF file = NIL THEN RETURN NIL END;
			NEW(reader, file, 0);
			NEW(scanner, "", reader,0,  NIL);
			b := scanner.GetNextSymbol(symbol);
			REPEAT
				block := ParseLine();
				IF block # NIL THEN
					IF first = NIL THEN first := block; last := block ELSE last.next := block; last := block END;
				END;
				GetNextSymbol
			UNTIL symbol.token = Scanner.EndOfText;
			RETURN first;
		END ParseLogFile;

		PROCEDURE Disassemble*(code, data: BitSets.BitSet; codeUnit, dataUnit: LONGINT; logFile: Files.File; address: ADDRESS);
		BEGIN
			SELF.code := code;SELF.data := data; SELF.codeUnit := codeUnit; SELF.dataUnit := dataUnit;
			first := ParseLogFile(logFile); block := first;
			IF block = NIL THEN
				w.String("------ code ------"); w.Ln;
				DisassembleBlock(0, MAX(LONGINT)-1);
				IF code # data THEN
					w.String("------ data ------"); w.Ln;
					DataBlock(0, MAX(LONGINT)-1);
				END;
			ELSE
				WHILE block # NIL DO
					IF (address = 0) OR (block.alignment <= address) & (block.to > address) THEN
						BlockHeader(block);
						IF ObjectFile.IsCode(block.type) & (code # NIL) THEN
							DisassembleBlock(block.alignment-codeDisplacement, block.to-codeDisplacement);
						ELSE
							DataBlock(block.alignment-dataDisplacement, block.to-dataDisplacement);
						END;
					END;
					block := block.next
				END;
			END;
		END Disassemble;

		PROCEDURE SetDisplacements*(code, data: LONGINT);
		BEGIN
			codeDisplacement := code;
			dataDisplacement := data;
		END SetDisplacements;
		

	END Disassembler;

	PROCEDURE FindPC*(context: Commands.Context);
	VAR file: Files.File; logFile: Files.FileName; adr,maxadr: LONGINT; disassembler: Disassembler; block, found: Block; name: ObjectFile.SectionName;
	BEGIN
		IF context.arg.GetString(logFile) & context.arg.GetInteger(adr, TRUE) THEN
			file := Files.Old(logFile);
			IF file = NIL THEN Files.JoinExtension(logFile,".log",logFile); file := Files.Old(logFile) END;
			IF file = NIL THEN
				context.error.String("file not found "); context.error.String(logFile); context.error.Ln
			ELSE
				NEW(disassembler, context.out);
				maxadr := 0;
				block := disassembler.ParseLogFile(file);
				WHILE (block # NIL ) DO
					IF (block.alignment < adr) & (block.alignment > maxadr) & ObjectFile.IsCode(block.type) THEN
						found := block;
						maxadr := block.alignment
					END;
					block := block.next
				END;
				Basic.SegmentedNameToString(found.identifier.name, name);
				context.out.String(name); context.out.String(":"); context.out.Int(adr-found.alignment,1); context.out.Ln;
			END;
		END;
	END FindPC;





	(*
	PROCEDURE Test*(context: Commands.Context);
	VAR filename: Files.FileName; name: ObjectFile.SectionName; block: Block;
	BEGIN
		IF context.arg.GetString(filename) THEN
		file := Files.Old(filename);
		IF file = NIL THEN (* error *) HALT(100) END;
		 block := ParseLogFile(filename);
			WHILE block # NIL DO
				Basic.SegmentedNameToString(block.identifier.name, name);
				context.out.String(name); context.out.String(" at "); context.out.Int(block.alignment,1); context.out.Ln;
				block := block.next;
			END;
		END;
	END Test;
	*)

END FoxDisassembler.

SystemTools.FreeDownTo FoxDisassembler ~
FoxDisassembler.Test ins.log ~

