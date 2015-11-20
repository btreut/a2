(** AUTHOR "rg"; PURPOSE "Decoder for binary executable code"; *)

MODULE Decoder;

IMPORT SYSTEM, Modules, Streams, MemoryReader, Strings, Files, KernelLog, TextUtilities, Commands, WMGraphics,
	WMEditors, WMTextView, WMComponents, WMStandardComponents, WMDialogs, WMRestorable, WMTrees, WMMessages,
	WM := WMWindowManager, D:= Debugging;

CONST
	maxDecoders = 5;

	MaxOpcodeSize = 20; (* enough for IA32 *)

	RepresentationModePlain = 0;
	RepresentationModeMeta = 1;

	OFFHdrRef = 8CX;
	OFFHdrBodyRef = 0F8X;
	OFFHdrProcRef = 0F9X;

	VarModeDirect = 1;
	VarModeIndirect = 3;
	VarRecord = 0;
	VarArray = 1;
	VarType = 2;

	AddressSize = SIZEOF(ADDRESS);

TYPE
	Opcode* = OBJECT
		VAR
			instr* : LONGINT; (* instruction code *)
			offset* : LONGINT;
			code* : Modules.Bytes;
			length- : LONGINT;
			decoder* : Decoder;
			next*: Opcode;
			stream : Streams.Writer;
			proc- : ProcedureInfo;

		PROCEDURE &New* (proc : ProcedureInfo; stream : Streams.Writer);
		BEGIN
			length := 0;
			SELF.proc := proc;
			SELF.stream := stream
		END New;

		PROCEDURE PrintOpcodeBytes* (w : Streams.Writer);
		END PrintOpcodeBytes;

		PROCEDURE PrintInstruction* (w : Streams.Writer);
		END PrintInstruction;

		PROCEDURE PrintArguments* (w : Streams.Writer);
		END PrintArguments;

		PROCEDURE PrintVariables* (w : Streams.Writer);
		END PrintVariables;

		PROCEDURE ToString* () : Strings.String;
		VAR
			str : ARRAY 255 OF CHAR;
			temp : ARRAY 10 OF CHAR;
		BEGIN
			Strings.IntToStr(instr, temp);
			Strings.Append(str, "Opcode: instr = "); Strings.Append(str, temp);
			Strings.IntToHexStr(offset, 0, temp);
			Strings.Append(str, ", offset = "); Strings.Append(str, temp);
			RETURN Strings.NewString(str)
		END ToString;

		PROCEDURE WriteHex8* (x : LONGINT; w : Streams.Writer);
		VAR result : ARRAY 3 OF CHAR;
		BEGIN
			IntToHex(x, 2, result); w.String(result)
		END WriteHex8;

		PROCEDURE WriteHex16* (x : LONGINT; w : Streams.Writer);
		VAR result : ARRAY 5 OF CHAR;
		BEGIN
			IntToHex(x, 4, result); w.String(result)
		END WriteHex16;

		PROCEDURE WriteHex32* (x : LONGINT; w : Streams.Writer);
		VAR result : ARRAY 10 OF CHAR;
		BEGIN
			IntToHex(x, 8, result); w.String(result)
		END WriteHex32;
	END Opcode;

	Decoder* = OBJECT
		VAR
			codeBuffer : Modules.Bytes;
			reader: Streams.Reader;
			outputStreamWriter* : Streams.Writer;
			firstOpcode, lastOpcode, currentOpcode: Opcode;
			completed : BOOLEAN;
			currentBufferPos, currentCodePos, opcodes, mode : LONGINT;
			currentProc* : ProcedureInfo;

		PROCEDURE &New* (reader : Streams.Reader);
		BEGIN
			SELF.reader := reader;
			SELF.mode := mode;
			NEW(codeBuffer, MaxOpcodeSize);  (* limit: maximum # bytes per opcode *)
			currentCodePos := 0;
			opcodes := 0;
			completed := FALSE
		END New;

		PROCEDURE Bug* (op, no: LONGINT);
		BEGIN
			KernelLog.Ln;  KernelLog.String("*** decode error ***; "); KernelLog.String("op = "); KernelLog.Hex(op, -1); KernelLog.String(", no = "); KernelLog.Int(no, 0); KernelLog.Ln;
			completed := TRUE
		END Bug;

		PROCEDURE NewOpcode* () : Opcode;
		VAR
			opcode : Opcode;
		BEGIN
			NEW(opcode, currentProc, outputStreamWriter);
			RETURN opcode
		END NewOpcode;

		PROCEDURE DecodeThis* (opcode : Opcode);
		END DecodeThis;

		PROCEDURE Decode* (proc : ProcedureInfo) : Opcode;
		(*
		VAR
			str : Strings.String;
		*)
		BEGIN
			currentProc := proc;
			WHILE ~completed DO
				currentBufferPos := 0;
				IF reader.Available() > 0 THEN
					currentOpcode := NewOpcode();
					BEGIN {EXCLUSIVE}
						DecodeThis(currentOpcode);
						IF reader.res = Streams.Ok THEN
							IF lastOpcode = NIL THEN
								lastOpcode := currentOpcode;
								firstOpcode := currentOpcode;
							ELSE
								lastOpcode.next := currentOpcode;
								lastOpcode := currentOpcode
							END;
							currentOpcode.offset := currentCodePos+proc.codeOffset;
							(*
							str := currentOpcode.ToString();
							KernelLog.String(str^); KernelLog.Ln;
							*)
							INC(currentOpcode.length);
							(* copy all buffered bytes to the opcode *)
							CopyBufferToOpcode(currentOpcode);
							INC(opcodes)
						END
					END
				ELSE
					completed := TRUE
				END;
				IF reader.res # Streams.Ok THEN completed := TRUE END;
			END;
			RETURN firstOpcode
		END Decode;

		PROCEDURE CopyBufferToOpcode(opcode : Opcode);
		VAR i : LONGINT;
		BEGIN
			NEW(opcode.code, currentBufferPos);
			FOR i := 0 TO currentBufferPos-1 DO
				opcode.code[i] := codeBuffer[i]
			END;
			opcode.length := currentBufferPos;
			INC(currentCodePos, currentBufferPos)
		END CopyBufferToOpcode;

		PROCEDURE InsertBytesAtBufferHead* (bytes : Modules.Bytes);
		VAR i, n : LONGINT;
		BEGIN
			n := LEN(bytes);
			FOR i := currentBufferPos-1 TO 0 BY -1 DO
				codeBuffer[i+n] := codeBuffer[i]
			END;
			FOR i := 0 TO n-1 DO
				codeBuffer[i] := bytes[i]
			END;
			INC(currentBufferPos, n)
		END InsertBytesAtBufferHead;

		PROCEDURE ReadChar* () : CHAR;
		VAR
			ch : CHAR;
		BEGIN
			reader.Char(ch);
			IF reader.res = Streams.Ok THEN
				codeBuffer[currentBufferPos] := ch;
				INC(currentBufferPos);
			END;
			RETURN ch
		END ReadChar;

		PROCEDURE ReadInt* () : INTEGER;
		VAR
			i : INTEGER;
		BEGIN
			reader.RawInt(i);
			IF reader.res = Streams.Ok THEN
				SYSTEM.MOVE(ADDRESSOF(i), ADDRESSOF(codeBuffer[currentBufferPos]), 2);
				INC(currentBufferPos, 2)
			END;
			RETURN i
		END ReadInt;

		PROCEDURE ReadLInt* () : LONGINT;
		VAR
			l, highByte, base : LONGINT;
			ch : CHAR;
		BEGIN
			ch := ReadChar();
			l := LONG(ORD(ch));
			ch := ReadChar();
			l := l + LONG(ORD(ch)) * 100H;
			ch := ReadChar();
			l := l + LONG(ORD(ch)) * 10000H;
			ch := ReadChar();
			highByte := ORD(ch);
			IF highByte >= 128 THEN base := MIN(LONGINT); DEC(highByte, 128) ELSE base := 0 END;
			l := base + highByte * 1000000H + l;
			RETURN l
		END ReadLInt;
	END Decoder;

	DecoderFactory = PROCEDURE {DELEGATE} (reader : Streams.Reader) : Decoder;

	Info = OBJECT
		VAR
			name-: ARRAY 256 OF CHAR;
	END Info;

	FieldInfo* = OBJECT (Info)
		VAR
			offset, mode, kind, type, dim, tdadr : LONGINT;
			markerPositions, temp : POINTER TO ARRAY OF RECORD
								pos : LONGINT;
								marker : WMTextView.PositionMarker
								END;
			nextMarker, markerSize : LONGINT;
			markersCreated : BOOLEAN;
			procedure : ProcedureInfo;

		PROCEDURE WriteType(w : Streams.Writer);
		BEGIN
			IF mode = VarModeIndirect THEN w.String("VAR ") END;
			IF kind = VarArray THEN w.String("ARRAY "); w.Int(dim, 0); w.String(" OF ") END;
			CASE type OF
				1H : w.String("BYTE")
				| 2H : w.String("BOOLEAN")
				| 3H : w.String("CHAR")
				| 4H : w.String("SHORTINT")
				| 5H : w.String("INTEGER")
				| 6H : w.String("LONGINT")
				| 7H : w.String("REAL")
				| 8H : w.String("LONGREAL")
				| 9H : w.String("SET")
				| 0AH : w.String("?")
				| 0BH : w.String("?")
				| 0CH : w.String("?")
				| 0DH : w.String("PTR")
				| 0EH : w.String("PROC")
				| 0FH : w.String("STRING")
				| 10H : w.String("HUGEINT")
				| 16H : w.String("RECORD")
				| 1DH : w.String("OBJECT")
			ELSE
			END;
		END WriteType;

		PROCEDURE ToString(w : Streams.Writer);
		BEGIN
			w.String(name);
			w.String(" (");
			WriteType(w);
			w.String(") [");
			w.Int(offset, 0);
			w.String("]")
		END ToString;

		PROCEDURE AddMarkerPosition* (pos : LONGINT);
		VAR i : LONGINT;
		BEGIN
			markersCreated := FALSE;
			IF markerPositions = NIL THEN markerSize := 5; NEW(markerPositions, markerSize); nextMarker := 0 END;
			IF nextMarker >= LEN(markerPositions) THEN
				temp := markerPositions;
				markerSize := 2*markerSize;
				NEW(markerPositions, markerSize);
				FOR i := 0 TO nextMarker-1 DO
					markerPositions[i] := temp[i]
				END
			END;
			markerPositions[nextMarker].pos := pos;
			INC(nextMarker)
		END AddMarkerPosition;

		PROCEDURE CreateMarkers (tv : WMTextView.TextView);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO nextMarker-1 DO
				markerPositions[i].marker := tv.CreatePositionMarker();
				markerPositions[i].marker.SetPosition(markerPositions[i].pos);
				markerPositions[i].marker.SetVisible(FALSE);
				markerPositions[i].marker.Load("DecoderRes.zip://VariablePositionIcon.png")
			END;
			markersCreated := TRUE
		END CreateMarkers;

		PROCEDURE ToggleMarkers(enabled : BOOLEAN);
		VAR i : LONGINT;
		BEGIN
			IF markersCreated THEN
				FOR i := 0 TO nextMarker-1 DO
					markerPositions[i].marker.SetVisible(enabled)
				END
			END
		END ToggleMarkers
	END FieldInfo;

	FieldArray = POINTER TO ARRAY OF FieldInfo;

	ProcedureInfo* = OBJECT (Info)
		VAR
			codeOffset, codeSize, retType, index : LONGINT;
			fields : FieldArray;
			fieldCount : LONGINT;
			method : BOOLEAN;

			gcInfo: GCInfo;

		PROCEDURE &New (CONST n : ARRAY OF CHAR; ofs, idx : LONGINT);
		BEGIN
			COPY (n, name);
			codeOffset := ofs;
			index := idx;
			method := FALSE;
			NEW(fields, 5);
			gcInfo := NIL;
		END New;

		PROCEDURE AddField (fldInfo : FieldInfo);
		VAR
			oldFlds : FieldArray;
			i, len : LONGINT;
		BEGIN
			IF fieldCount = LEN(fields) THEN
				oldFlds := fields;
				len := LEN(fields);
				NEW(fields, 2 * len);
				FOR i := 0 TO len-1 DO fields[i] := oldFlds[i] END;
			END;
			fields[fieldCount] := fldInfo;
			INC(fieldCount)
		END AddField;

		PROCEDURE GetFieldAtOffset*(offset : LONGINT) : FieldInfo;
		VAR
			i : LONGINT;
		BEGIN
			i := 0;
			WHILE i < fieldCount DO
				IF fields[i].offset = offset THEN RETURN fields[i] END;
				INC(i)
			END;
			RETURN NIL
		END GetFieldAtOffset;
	END ProcedureInfo;

	ProcedureArray = POINTER TO ARRAY OF ProcedureInfo;

	TypeInfo* = OBJECT (Info)
		VAR
			procedures : ProcedureArray;
			fields : FieldArray;
			procedureCount, fieldCount : LONGINT;

		PROCEDURE &New (CONST n : ARRAY OF CHAR);
		BEGIN
			COPY (n, name);
			procedureCount := 0;
			fieldCount := 0;
			NEW(procedures, 5);
			NEW(fields, 5)
		END New;

		PROCEDURE AddProcedure (procInfo : ProcedureInfo);
		VAR
			oldProcs : ProcedureArray;
			i, len : LONGINT;
		BEGIN
			IF procedureCount = LEN(procedures) THEN
				oldProcs := procedures;
				len := LEN(procedures);
				NEW(procedures, 2 * len);
				FOR i := 0 TO len-1 DO procedures[i] := oldProcs[i] END;
			END;
			procedures[procedureCount] := procInfo;
			INC(procedureCount)
		END AddProcedure;

	END TypeInfo;

	TypeArray = POINTER TO ARRAY OF TypeInfo;

	Export*=POINTER TO RECORD
		next: Export;
		fp: LONGINT;
		type: LONGINT;
		val: LONGINT;
		name: ARRAY 256 OF CHAR;
	END;

	Use= POINTER TO RECORD
		next: Use;
		fp: LONGINT;
		type: LONGINT;
		val: LONGINT;
		name: ARRAY 256 OF CHAR;
	END;

	Import=OBJECT
	VAR
		next: Import;
		name: ARRAY 256 OF CHAR;
		uses: Use;

		PROCEDURE AddUse(u: Use);
		VAR x: Use;
		BEGIN
			IF uses = NIL THEN uses := u
			ELSE x := uses; WHILE x.next # NIL DO x := x.next; END;
			x.next := u;
			END;
		END AddUse;

	END Import;

	VarConstLink=RECORD
		num: LONGINT;
		ch: CHAR;
		links: POINTER TO ARRAY OF LONGINT;
	END;

	Link=RECORD
		num: LONGINT;
	END;

	Entry=RECORD
		num: LONGINT;
	END;

	GCInfo= POINTER TO RECORD
		codeOffset, beginOffset, endOffset: LONGINT;
		pointers: POINTER TO ARRAY OF LONGINT
	END;

	ObjHeader = RECORD (* data from object file header *)
		entries, commands, pointers, types, modules, links, dataLinks: LONGINT;
		codeSize, dataSize, refSize, constSize, exTableLen, procs, maxPtrs, crc: LONGINT;
		staticTdSize: LONGINT; (* ug *)
		name: Modules.Name
	END;

	ModuleInfo* = OBJECT (Info)
		VAR
			module : Modules.Module;
			header: ObjHeader;
			representationMode : LONGINT;
			procedures : ProcedureArray; (* references to all procedures, including methods *)
			procedureCount : LONGINT;
			types : TypeArray;
			typeCount : LONGINT;
			treeView : WMTrees.TreeView;
			tree : WMTrees.Tree;
			treePanel, lastDAssPanel : WMStandardComponents.Panel;
			resizerH : WMStandardComponents.Resizer;
			editor : WMEditors.Editor;
			textWriter : TextUtilities.TextWriter;
			currentProcInfo : ProcedureInfo;
			markPC : LONGINT;
			ext : Extension;
			codeScaleCallback: CodeScaleCallback;

			exports: Export;
			imports: Import;
			varConstLinks: POINTER TO ARRAY OF VarConstLink;
			links: POINTER TO ARRAY OF Link;
			entries: POINTER TO ARRAY OF Entry;
			gcInfo: POINTER TO ARRAY OF GCInfo;

		PROCEDURE AddExport(e: Export);
		VAR x: Export;
		BEGIN
			IF exports = NIL THEN exports := e
			ELSE
				x := exports;
				WHILE x.next # NIL DO x := x.next END;
				x.next := e;
			END;
		END AddExport;

		PROCEDURE AddImport(i: Import);
		VAR x: Import;
		BEGIN
			IF imports = NIL THEN imports := i
			ELSE
				x := imports;
				WHILE x.next # NIL DO x := x.next END;
				x.next := i;
			END;
		END AddImport;


		PROCEDURE IsExceptionHandled(pc: LONGINT): BOOLEAN;
		VAR
			i: LONGINT;
			entry: Modules.ExceptionTableEntry;
		BEGIN
			IF (module # NIL) & (module.exTable # NIL) THEN
				FOR i := 0 TO LEN(module.exTable) - 1 DO
					entry := module.exTable[i];
					IF (entry.pcFrom <= pc) & (entry.pcTo > pc) THEN
						RETURN TRUE;
					END
				END
			END;
			RETURN FALSE;
		END IsExceptionHandled;

		PROCEDURE GetOpcodes (proc : ProcedureInfo) : Opcode;
		VAR
			reader : MemoryReader.Reader;
			ofs : LONGINT;
			decoder : Decoder;
		BEGIN
			ofs := ADDRESSOF(module.code[proc.codeOffset]);
			NEW(reader, ofs, proc.codeSize);
			decoder := GetDecoder(ext, reader);
			RETURN decoder.Decode(proc)
		END GetOpcodes;

		PROCEDURE AddProcedure (procInfo : ProcedureInfo);
		VAR
			oldProcs : ProcedureArray;
			i, len : LONGINT;
		BEGIN
			IF procedureCount = LEN(procedures) THEN
				oldProcs := procedures;
				len := LEN(procedures);
				NEW(procedures, 2 * len);
				FOR i := 0 TO len-1 DO procedures[i] := oldProcs[i] END
			END;
			procedures[procedureCount] := procInfo;
			INC(procedureCount)
		END AddProcedure;

		PROCEDURE FindEntryByOffset (ofs : LONGINT) : LONGINT;
		VAR
			i : LONGINT;
		BEGIN
			i := 0;
			WHILE i < header.entries DO
				IF ofs = module.entry[i] THEN RETURN i END;
				INC(i)
			END;
			RETURN -1
		END FindEntryByOffset;

		PROCEDURE GetProcedureByIndex (idx : LONGINT) : ProcedureInfo;
		VAR
			i : LONGINT;
		BEGIN
			i := 0;
			WHILE i < procedureCount DO
				IF idx = procedures[i].index THEN
					RETURN procedures[i]
				END;
				INC(i)
			END;
			RETURN NIL
		END GetProcedureByIndex;

		PROCEDURE DecodeRefs(reader : Streams.Reader);
		VAR idx, thisIdx : LONGINT;
			procInfo : ProcedureInfo;
			fldInfo : FieldInfo;
			ch : CHAR;
			ofs, prevOfs, retType, entry : LONGINT;
			name :ARRAY 256 OF CHAR;
			i: LONGINT;

		BEGIN
			ASSERT(header.codeSize > 0);
			(* body ref *)
			IF reader.Available() > 0 THEN
				ch := reader.Get();
				ASSERT(ch = OFFHdrBodyRef);
				reader.RawNum(ofs);
				reader.RawString(name);
				ASSERT(name = "$$");
				name := "@Body";
				NEW(procInfo, name, 0, header.entries); (* indexes below this are reserved by procedures/methods part of entries *)
				AddProcedure(procInfo);
				fldInfo := DecodeField(reader);
				WHILE fldInfo # NIL DO
					procInfo.AddField(fldInfo);
					fldInfo := DecodeField(reader);
				END
			END;
			idx := header.entries+1; (* start after entries and BODY *)
			ofs := 0;
			WHILE (reader.Available() > 0) & (reader.Peek() = OFFHdrProcRef) DO
				ch := reader.Get();
				prevOfs := ofs;
				reader.RawNum(ofs);
				IF (codeScaleCallback # NIL) THEN codeScaleCallback(ofs) END;
				ASSERT(procInfo # NIL);
				procInfo.codeSize := ofs - prevOfs; (* set size of previous procedure *)
				FOR i := 0 TO LEN(gcInfo)-1 DO
					IF (gcInfo[i]# NIL) & (prevOfs <=gcInfo[i].codeOffset) & (gcInfo[i].endOffset <= ofs) THEN
						procInfo.gcInfo := gcInfo[i]
					END;
				END;
				ch := reader.Get();
				retType := SYSTEM.VAL(LONGINT, reader.Get());
				ch := reader.Get(); ch := reader.Get();
				reader.RawString(name);
				entry := FindEntryByOffset(ofs);
				procInfo := NIL;
				IF entry >= 0 THEN
					procInfo := GetProcedureByIndex(entry);
					thisIdx := entry
				ELSE
					thisIdx := idx;
					INC(idx)
				END;
				IF procInfo = NIL THEN
					NEW(procInfo, name, ofs, thisIdx);
					AddProcedure(procInfo);
				ELSE
					COPY(name,procInfo.name);
				END;


				procInfo.retType := retType;
				fldInfo := DecodeField(reader);
				WHILE fldInfo # NIL DO
					procInfo.AddField(fldInfo);
					fldInfo := DecodeField(reader);
				END
			END;
			ASSERT(procInfo # NIL);
			procInfo.codeSize := header.codeSize - ofs; (* set size of last procedure *)
				FOR i := 0 TO LEN(gcInfo)-1 DO
					IF (gcInfo[i]# NIL) & (ofs <=gcInfo[i].codeOffset) & (gcInfo[i].endOffset <= header.codeSize) THEN
						procInfo.gcInfo := gcInfo[i]
					END;
				END;
		END DecodeRefs;

		PROCEDURE DecodeTypes;
		END DecodeTypes;

		PROCEDURE DecodeField(reader : Streams.Reader) : FieldInfo;
		VAR
			fieldInfo : FieldInfo;
			ch : CHAR;
		BEGIN
			NEW(fieldInfo);
			IF reader.Peek() = 1X THEN
				fieldInfo.mode := VarModeDirect
			ELSIF reader.Peek() = 3X THEN
				fieldInfo.mode := VarModeIndirect
			ELSE
				RETURN NIL (* not a field *)
			END;
			ch := reader.Get();
			fieldInfo.type := SYSTEM.VAL(LONGINT, reader.Get());
			IF fieldInfo.type <= 15H THEN
				fieldInfo.kind := VarType;
			ELSIF (fieldInfo.type >= 81H) & (fieldInfo.type <= 90H) THEN
				fieldInfo.kind := VarArray;
				DEC(fieldInfo.type, 80H);
				reader.RawNum(fieldInfo.dim)
			ELSE
				(*ASSERT((fieldInfo.type = 16H) OR (fieldInfo.type = 1DH));*)
				fieldInfo.kind := VarRecord;
				reader.RawNum(fieldInfo.tdadr)
			END;
			reader.RawNum(fieldInfo.offset);
			reader.RawString(fieldInfo.name);
			RETURN fieldInfo
		END DecodeField;

		PROCEDURE FindProcedureFromPC(pc : LONGINT) : ProcedureInfo;
		VAR
			i : LONGINT;
		BEGIN
			ASSERT(procedures # NIL);
			WHILE i < procedureCount DO
				IF (pc >= procedures[i].codeOffset) & (pc < procedures[i].codeOffset + procedures[i].codeSize) THEN
					RETURN procedures[i]
				END;
				INC(i)
			END;
			RETURN NIL
		END FindProcedureFromPC;

		PROCEDURE Init;
		BEGIN
			NEW(module);
			procedureCount := 0;
			markPC := -1;
			NEW(procedures, 5);
			codeScaleCallback := NIL;
			ext := ""
		END Init;

		PROCEDURE ClickNode(sender, data : ANY);
		VAR
			d: ANY;
			i : LONGINT;

			PROCEDURE ChangeProcedure(proc : ProcedureInfo);
			BEGIN
				IF editor # NIL THEN lastDAssPanel.RemoveContent(editor) END;
				OutlineProcedure(proc, lastDAssPanel)
			END ChangeProcedure;

		BEGIN
			lastDAssPanel.DisableUpdate;
			IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
				tree.Acquire;
				d := tree.GetNodeData(data(WMTrees.TreeNode));
				tree.Release;
				IF d # NIL THEN
					IF d IS ProcedureInfo THEN ChangeProcedure(d(ProcedureInfo))
					ELSIF d IS FieldInfo THEN
						IF (currentProcInfo = NIL) OR (d(FieldInfo).procedure # currentProcInfo) THEN ChangeProcedure(d(FieldInfo).procedure)
						ELSE
							FOR i := 0 TO currentProcInfo.fieldCount-1 DO
								currentProcInfo.fields[i].ToggleMarkers(FALSE)
							END;
						END;
						d(FieldInfo).ToggleMarkers(TRUE);
					ELSIF d IS TypeInfo THEN
						IF editor # NIL THEN lastDAssPanel.RemoveContent(editor) END;
						OutlineType(d(TypeInfo), lastDAssPanel)
					ELSIF d IS ModuleInfo THEN
						IF editor # NIL THEN lastDAssPanel.RemoveContent(editor) END;
						OutlineModule(d(ModuleInfo), lastDAssPanel)
					ELSE
						HALT(99)
					END
				END
			END;
			lastDAssPanel.EnableUpdate;
			lastDAssPanel.Invalidate
		END ClickNode;

		PROCEDURE OutlineNamedProcedure(CONST name : ARRAY OF CHAR);
		VAR found : BOOLEAN;
			i : LONGINT;
		BEGIN
			i := 0; found := FALSE;
			WHILE ~found & (i < procedureCount) DO
				IF procedures[i].name = name THEN
					found := TRUE;
					OutlineProcedure(procedures[i], lastDAssPanel)
				END;
				INC(i)
			END;
			IF ~found THEN
				KernelLog.String("Decoder: ERROR: OutlineNamedProcedure: Procedure not found: "); KernelLog.String(name); KernelLog.Ln
			END
		END OutlineNamedProcedure;

		PROCEDURE OutlinePC (pc : LONGINT);
		VAR proc : ProcedureInfo;
		BEGIN
			proc := FindProcedureFromPC(pc);
			IF proc # NIL THEN
					markPC := pc;
					OutlineProcedure(proc, lastDAssPanel);
					markPC := -1;
			ELSE
				KernelLog.String("Decoder: ERROR: OutlinePC: Procedure not found at PC: "); KernelLog.Hex(pc, 0); KernelLog.Ln
			END
		END OutlinePC;

		PROCEDURE InitializeOutline (panel : WMStandardComponents.Panel) : Streams.Writer;
		VAR
			avgTabSize : LONGINT;
			tabStops : WMTextView.CustomTabStops;
			tabPositions : WMTextView.TabPositions;
		BEGIN
			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(editor);

			panel.Reset(SELF, NIL);
			panel.AlignSubComponents;

			NEW(tabPositions, 4);
			avgTabSize := editor.bounds.GetWidth() DIV 14; (* 5 columns, 2 have double width *)
			tabPositions[0] := 2*avgTabSize; tabPositions[1] := 6*avgTabSize; tabPositions[2] := 8*avgTabSize; tabPositions[3] := 11*avgTabSize;
			NEW(tabStops, tabPositions);
			editor.tv.SetTabStops(tabStops);
			editor.tv.wrapMode.Set(WMTextView.NoWrap);

			NEW(textWriter, editor.text);
			RETURN textWriter
		END InitializeOutline;

		PROCEDURE OutlineProcedure (proc : ProcedureInfo; panel : WMStandardComponents.Panel);
			VAR
				s : Strings.String;
				opcodes : Opcode;
				w : Streams.Writer;
				i, opStart, opEnd, pcPos : LONGINT;
				pcMarker : WMTextView.PositionMarker;
(* ug *)			s2: Strings.String;
		BEGIN
			currentProcInfo := proc;
			w := InitializeOutline(panel);

			textWriter.SetFontStyle({WMGraphics.FontBold});
			w.String(currentProcInfo.name);
			w.String(":");
(* ug *)		w.Ln; w.String("codeOffset = "); NEW(s2, 20); IntToHex(currentProcInfo.codeOffset, 8, s2^); Strings.Append(s2^, "H"); w.String(s2^);
			w.Ln; w.Ln;
			textWriter.SetFontStyle({});

			(* output data *)
			opcodes := GetOpcodes(currentProcInfo);
			WHILE opcodes # NIL DO

				IF IsExceptionHandled(opcodes.offset) THEN
					textWriter.SetBgColor(LONGINT(0C0D5FFFFH));
				ELSE
					textWriter.SetBgColor(WMGraphics.White);
				END;

				textWriter.SetFontColor(WMGraphics.Black);
				NEW(s, 20);
				IntToHex(opcodes.offset, 8, s^);
				Strings.Append(s^, "H");
				w.String(s^); w.Char(9X);
				(* insert marker for pc if selected *)
				IF markPC >= 0 THEN
					opStart := opcodes.offset;
					opEnd := opStart + opcodes.length - 1;
					IF (markPC >= opStart) &	(markPC <= opEnd) THEN
						pcPos := w.Pos() + (markPC-opStart)*3; (* text position within opcode bytes *)
					END
				END;
				opcodes.PrintOpcodeBytes(w); 	w.Char(9X);
				textWriter.SetFontColor(0000099FFH);
				opcodes.PrintInstruction(w);	w.Char(9X);
				opcodes.PrintArguments(w); w.Char(9X);
				textWriter.SetFontColor(LONGINT(0999999FFH));
				opcodes.PrintVariables(w);
				w.Ln;
				opcodes := opcodes.next
			END;

			w.Update;

			IF proc.gcInfo # NIL THEN
				w.Ln;
				w.String("pcFrom="); w.Hex(proc.gcInfo.codeOffset,1);w.Ln;
				w.String("gcEnd="); w.Hex(proc.gcInfo.endOffset,1);w.Ln;
				w.String("gcBegin="); w.Hex(proc.gcInfo.beginOffset,1);w.Ln;
				FOR i := 0 TO LEN(proc.gcInfo.pointers)-1 DO
					w.String("ptr @ "); w.Int(proc.gcInfo.pointers[i],1); w.Ln;
				END;
			END;
			w.Update;

			IF markPC >= 0 THEN
				(* insert marker *)
				pcMarker := editor.tv.CreatePositionMarker();
				pcMarker.SetPosition(pcPos);
				pcMarker.SetVisible(TRUE);
				pcMarker.Load ("DecoderRes.zip://PCPositionIcon.png");
				editor.tv.cursor.SetPosition(pcPos);
				markPC := -1 (* forget this pc now *)
			ELSE
				editor.tv.cursor.SetPosition(0)
			END;

			(* set markers to highlight variables *)
			FOR i := 0 TO currentProcInfo.fieldCount-1 DO
				currentProcInfo.fields[i].CreateMarkers(editor.tv);
			END;

		END OutlineProcedure;

		PROCEDURE OutlineType  (typeInfo : TypeInfo; panel : WMStandardComponents.Panel);
		VAR
			w : Streams.Writer;
		BEGIN
			w := InitializeOutline(panel);

			textWriter.SetFontStyle({WMGraphics.FontBold});
			w.String(typeInfo.name);
			w.String(":"); w.Ln; w.Ln;
			textWriter.SetFontStyle({});

			(*
			w.String("Fields: "); w.Int(typeInfo.fieldCount, 0); w.Ln;

			FOR i := 0 TO typeInfo.fieldCount-1 DO
				w.String(typeInfo.fields[i].name); w.Char(9X);
				typeInfo.fields[i].WriteType(w); w.Char(9X);
				w.String(") ["); w.Int(typeInfo.fields[i].offset, 0); w.String("]")
			END;
			*)
			w.Update
		END OutlineType;

		PROCEDURE OutlineModule  (moduleInfo: ModuleInfo; panel : WMStandardComponents.Panel);
		VAR
			w : Streams.Writer;
			i,j : LONGINT;
			ch: CHAR;
			proc : ProcedureInfo;
			e: Export;
			import: Import;
			u: Use;

			PROCEDURE DataBlock(from,to: LONGINT);
			VAR i: LONGINT; ch: CHAR;
			BEGIN
				IF to >= LEN(module.data) THEN to := LEN(module.data)-1 END;
				FOR i := from TO to DO
					ch := module.data[i];
					w.Hex(ORD(ch),-2); w.String(" ");
				END;
				FOR i := from TO to DO
					ch := module.data[i];
					IF (ORD(ch)>20) & (ORD(ch)<127) THEN
						w.Char(ch)
					ELSE
						w.Char(".")
					END;
				 END;
				w.Ln;
			END DataBlock;



		BEGIN
			w := InitializeOutline(panel);

			w.String(moduleInfo.name);
			w.String(":"); w.Ln; w.Ln;

			ASSERT(module # NIL);
			w.String("refSize:"); w.Char(9X); w.Int(header.refSize, 0); w.String(" ("); w.Hex(header.refSize, 0); w.String("H)"); w.Ln;
			w.String("# entries:"); w.Char(9X); w.Int(header.entries, 0); w.Ln;
			w.String("# commands:"); w.Char(9X); w.Int(header.commands, 0); w.Ln;
			w.String("# pointers:"); w.Char(9X); w.Int(header.pointers, 0); w.Ln;
			w.String("# types"); w.Char(9X); w.Int(header.types, 0); w.Ln;
			w.String("dataSize:"); w.Char(9X); w.Int(header.dataSize, 0); w.String(" ("); w.Hex(header.dataSize, 0); w.String("H)"); w.Ln;
			w.String("constSize:"); w.Char(9X); w.Int(header.constSize, 0); w.String(" ("); w.Hex(header.constSize, 0); w.String("H)"); w.Ln;
			w.String("codeSize:"); w.Char(9X); w.Int(header.codeSize, 0); w.String(" ("); w.Hex(header.codeSize, 0); w.String("H)"); w.Ln;
			w.String("crc:"); w.Char(9X); w.Hex(header.crc,-8); w.Ln;
			w.Ln;
			w.String("Constants:"); w.Ln;
			FOR i := 0 TO header.constSize-1 BY 16 DO
				DataBlock(i,i+15);
			END;

			IF (header.constSize-1) MOD 32 # 31 THEN w.Ln END;

			w.Ln;
			w.String("Entries:"); w.Ln;
			FOR i := 0 TO header.entries-1 DO
				proc := GetProcedureByIndex(FindEntryByOffset(module.entry[i]));
				w.Hex(module.entry[i], 0); w.Char(9X);
				IF proc # NIL THEN w.String(proc.name) END;
				w.Ln;
			END;

			w.Ln;
			w.String("Exception Handler Table"); w.Ln;
			FOR i := 0 TO header.exTableLen - 1 DO
				w.String("pcFrom= "); w.Hex(module.exTable[i].pcFrom, 0);
				w.String("H  pcTo= "); w.Hex(module.exTable[i].pcTo, 0);
				w.String("H pcHandler= "); w.Hex(module.exTable[i].pcHandler, 0);
				w.String("H");
				w.Ln;
			END;

			w.Ln;
			w.String("Exports"); w.Ln;
			e := exports;
			WHILE e # NIL DO
				w.String("fp = "); w.Int(e.fp,1);
				w.String(", val = "); w.Int(e.val,1);
				w.String(", name= "); w.String(e.name);
				w.Ln;
				e := e.next;
			END;

			w.Ln;
			w.String("Imports"); w.Ln;
			import := imports;
			WHILE import # NIL DO
				w.String("module ="); w.String(import.name); w.Ln;
				u := import.uses;
				WHILE u # NIL DO
					w.String("    fp ="); w.Int(u.fp,1);
					w.String(", val = "); w.Int(u.val,1);
					w.String(", name ="); w.String(u.name);
					w.Ln;
					u := u.next;
				END;
				import := import.next;
			END;

			w.Ln;
			w.String("VarConstLinks"); w.Ln;
			FOR i := 0 TO LEN(varConstLinks)-1 DO
				w.String("num="); w.Int(varConstLinks[i].num,1);
				w.String(", no="); w.Int(ORD(varConstLinks[i].ch),1);
				w.Ln;

				FOR j := 0 TO LEN(varConstLinks[i].links)-1 DO
					w.String("    link="); w.Int(varConstLinks[i].links[j],1);
					w.String("(");
					w.Hex(varConstLinks[i].links[j],1);
					w.String("H)");
					w.Ln;
				END;
			END;

			w.Ln;
			w.String("Links"); w.Ln;
			FOR i := 0 TO LEN(links)-1 DO
				w.String("num="); w.Int(links[i].num,1);w.Ln;
			END;

			w.Ln;
			w.String("Link Entries"); w.Ln;
			FOR i := 0 TO LEN(entries)-1 DO
				w.String("num="); w.Int(entries[i].num,1);w.Ln;
			END;

			w.Ln;
			w.String("Pointers in Procs"); w.Ln;
			FOR i := 0 TO LEN(gcInfo)-1 DO
				w.String("code offset "); w.Hex(gcInfo[i].codeOffset,-8); w.Ln;
				w.String("begin offset "); w.Hex(gcInfo[i].beginOffset,-8); w.Ln;;
				w.String("end offset "); w.Hex(gcInfo[i].endOffset,-8); w.Ln;
				w.String("pointers: "); w.Ln;
				FOR j := 0 TO LEN(gcInfo[i].pointers) - 1 DO
					w.Int(gcInfo[i].pointers[j],1); w.String(", ");
				END;
				w.Ln;
			END;

			w.Update
		END OutlineModule;

		PROCEDURE Outline (panel : WMStandardComponents.Panel);
			VAR
				moduleNode, fieldNode, typeNode : WMTrees.TreeNode;
				stringWriter : Strings.Buffer;
				w : Streams.Writer;
				i, j : LONGINT;

			PROCEDURE AddProcedureNode (parent : WMTrees.TreeNode; proc : ProcedureInfo; CONST typeName : ARRAY OF CHAR);
			VAR
				procedureNode : WMTrees.TreeNode;
				fieldCaption, procCaption : Strings.String;
				k : LONGINT;
			BEGIN
				NEW(procedureNode);
				tree.AddChildNode(parent, procedureNode);
				procCaption := Strings.NewString(proc.name);
				RemoveTypeName(procCaption^, typeName);
				tree.SetNodeCaption(procedureNode, procCaption);
				tree.SetNodeData(procedureNode, proc);
				tree.SetNodeImage(procedureNode, WMGraphics.LoadImage("DecoderRes.zip://ProcedureIcon.png", TRUE));
				k := 0;
				WHILE k < proc.fieldCount DO
					proc.fields[k].procedure := proc;
					NEW(fieldCaption, 40);
					NEW(fieldNode);
					tree.AddChildNode(procedureNode, fieldNode);
					proc.fields[k].ToString(w);
					fieldCaption := stringWriter.GetString();
					tree.SetNodeCaption(fieldNode, Strings.NewString(fieldCaption^));
					tree.SetNodeImage(fieldNode, WMGraphics.LoadImage("DecoderRes.zip://VariableIcon.png", TRUE));
					stringWriter.Clear;
					tree.SetNodeData(fieldNode, proc.fields[k]);
					INC(k)
				END
			END AddProcedureNode;

		BEGIN
			lastDAssPanel := panel;
			NEW(stringWriter, 0);
			w := stringWriter.GetWriter();

			NEW(treePanel);
			treePanel.alignment.Set(WMComponents.AlignLeft);
			treePanel.bounds.SetWidth(300);
			panel.AddContent(treePanel);

			NEW(resizerH);
			resizerH.bounds.SetWidth(5); resizerH.alignment.Set(WMComponents.AlignRight);
			resizerH.fillColor.Set(0808080FFH);
			treePanel.AddContent(resizerH);

			(* add a tree component *)
			NEW(treeView); treeView.alignment.Set(WMComponents.AlignClient);
			treePanel.AddContent(treeView);
			tree := treeView.GetTree();

			treeView.Initialize;
			treeView.onClickNode.Add(ClickNode);
			panel.Reset(SELF, NIL);
			panel.AlignSubComponents;

			tree.Acquire;
			NEW(moduleNode);
			tree.SetRoot(moduleNode);
			tree.InclNodeState(moduleNode, WMTrees.NodeAlwaysExpanded);
			tree.SetNodeCaption(moduleNode, Strings.NewString(name));
			tree.SetNodeData(moduleNode, SELF);

			i := 0;
			WHILE i < typeCount DO
				NEW(typeNode);
				tree.AddChildNode(moduleNode, typeNode);
				tree.SetNodeCaption(typeNode, Strings.NewString(types[i].name));
				tree.SetNodeData(typeNode, types[i]);
				tree.SetNodeImage(typeNode, WMGraphics.LoadImage("DecoderRes.zip://TypeIcon.png", TRUE));
				j := 0;
				WHILE j < types[i].procedureCount DO
					AddProcedureNode(typeNode, types[i].procedures[j], types[i].name);
					INC(j)
				END;
				INC(i)
			END;
			i := 0;
			WHILE i < procedureCount DO
				IF ~procedures[i].method THEN
					AddProcedureNode(moduleNode, procedures[i], "")
				END;
				INC(i)
			END;
			tree.Release;
		END Outline;

		PROCEDURE Discard(panel : WMStandardComponents.Panel);
		BEGIN
			IF treePanel # NIL THEN
				panel.RemoveContent(treePanel)
			END;
			IF editor # NIL THEN
				panel.RemoveContent(editor)
			END;
			lastDAssPanel := NIL
		END Discard;

	END ModuleInfo;

	ModuleInfoBytes = OBJECT (ModuleInfo)

		PROCEDURE &New(bytes : Modules.Bytes);
		BEGIN
			Init;
			name := "[UNKNOWN]";
			representationMode := RepresentationModePlain;
			NEW(procedures[0], "[UNKNOWN]", 0, 0);
			procedureCount := 1;
			procedures[0].codeSize := LEN(bytes);
			module.code := bytes
		END New;

		PROCEDURE Outline (panel : WMStandardComponents.Panel);
		BEGIN
			ext := lastExt; (* allows to decode with the decoder the last file was decoded *)
			OutlineProcedure(procedures[0], panel)
		END Outline;

	END ModuleInfoBytes;

	CodeScaleCallback* = PROCEDURE(VAR size : LONGINT);

	ModuleInfoObjectFile = OBJECT (ModuleInfo)
	VAR
		f: Files.File;
		r : Files.Reader;
		version : LONGINT;
		nofLinks, nofVarConstLinks : LONGINT;
		symSize : LONGINT;
		noProcs : LONGINT; (* ug: temporary *)

		PROCEDURE DecodeEntries;
		VAR
			ch : CHAR; i, e : LONGINT;
		BEGIN
			ch := r.Get();
			ASSERT(ch = 82X);
			NEW(module.entry, header.entries);
			FOR i := 0 TO header.entries-1 DO
				r.RawNum(e);
				module.entry[i] := e
			END
		END DecodeEntries;

		PROCEDURE SkipCommands;
		VAR
			ch : CHAR;
			i, num : LONGINT;
			n : Modules.Name;
		BEGIN
			ch := r.Get();
			ASSERT(ch = 83X);
			FOR i := 0 TO header.commands-1 DO
				r.RawNum(num); r.RawNum(num); r.RawString(n); r.RawNum(num)
			END
		END SkipCommands;

		PROCEDURE SkipPointers;
		VAR
			ch : CHAR;
			i, num : LONGINT;
		BEGIN
			ch := r.Get();
			ASSERT(ch = 84X);
			FOR i := 0 TO header.pointers-1 DO
				r.RawNum(num)
			END
		END SkipPointers;

		PROCEDURE SkipImports;
		VAR
			ch : CHAR;
			i : LONGINT;
			n : Modules.Name;
		BEGIN
			ch := r.Get();
			ASSERT(ch = 85X);
			FOR i := 0 TO header.modules-1 DO
				r.RawString(n)
			END
		END SkipImports;

		PROCEDURE SkipVarConstLinks;
		VAR
			ch : CHAR;
			i, j, num, count : LONGINT;
		BEGIN
			ch := r.Get();
			ASSERT(ch = 8DX);
			NEW(varConstLinks,nofVarConstLinks);
			FOR i := 0 TO nofVarConstLinks-1 DO
				ch := r.Get();
				r.RawNum(num);
				r.RawLInt(count);
				varConstLinks[i].num := i;
				varConstLinks[i].ch := ch;
				NEW(varConstLinks[i].links,count);
				FOR j := 0 TO count-1 DO
					r.RawNum(num);
					varConstLinks[i].links[j] := num;
				END
			END
		END SkipVarConstLinks;

		PROCEDURE SkipLinks;
		VAR
			ch : CHAR;
			i, num : LONGINT;
		BEGIN
			ch := r.Get();
			ASSERT(ch = 86X);
			NEW(links,nofLinks);
			FOR i := 0 TO nofLinks-1 DO
				r.SkipBytes(2);  (* skip 2 characters *)
				r.RawNum(num);
				links[i].num := num;
			END;
			NEW(entries,header.entries);
			FOR i := 0 TO header.entries-1 DO
				r.RawNum(num);
				entries[i].num := num;
			END;
			r.RawNum(num)
		END SkipLinks;

		PROCEDURE SkipConsts;
		VAR
			ch : CHAR; i: LONGINT;
		BEGIN
			ch := r.Get();
			ASSERT(ch = 87X);
			NEW(module.data,header.constSize);
			FOR i := 0 TO header.constSize-1 DO
				r.Char(module.data[i]);
			END;
		END SkipConsts;

		PROCEDURE SkipExports;
		VAR count: LONGINT; name: Modules.Name; ch : CHAR;

			PROCEDURE LoadScope (level: LONGINT);
			VAR adr, fp, off, i, len, exp: LONGINT; check: POINTER TO ARRAY OF LONGINT;export: Export;
			BEGIN
				r.RawLInt(exp);
				r.RawNum(fp);
				len := 0;
				IF fp # 0 THEN NEW(check, exp) END;
				WHILE fp # 0 DO
				D.Hex(fp,-8); D.Ln;
					NEW(export);
					export.fp := fp;
					AddExport(export);
					IF (fp = 1) THEN
						r.RawNum(off);
						export.val := off;
						IF off >= 0 THEN
							INC(count);
							LoadScope (level+1(*1*))
						END
					ELSE
						IF level = 0 THEN
							r.RawNum(adr);
							export.val := adr;
							(*
							i := 0;
							WHILE i # len DO
								IF check[i] = fp THEN
									r.RawString(name);
									COPY(name,export.name);
									i := len
								ELSE
									INC(i)
								END
							END;
							*)
							check[len] := fp; INC(len)
						END;
					END;
					r.RawNum(fp)
				END
			END LoadScope;

		BEGIN
			ch := r.Get();
			ASSERT(ch = 88X);
			LoadScope (0)
		END SkipExports;

		PROCEDURE SkipUse;
		VAR ch : CHAR;

			PROCEDURE ReadUsedModules;
			VAR name : Modules.Name;					import: Import;

				PROCEDURE ReadEntry;
				VAR
					fp, arg : LONGINT;
					name : ARRAY 256 OF CHAR;
					use: Use;
				BEGIN
					r.RawNum(fp);
					r.RawString(name);
					r.RawNum(arg);
					NEW(use);
					use.fp := fp;
					COPY(name,use.name);
					use.val := arg;
					import.AddUse(use);
					IF arg > 0 THEN
						IF r.Peek() = 1X THEN
							ch := r.Get();
							r.RawNum(arg)
						END
					ELSIF arg < 0 THEN
					ELSE
						IF r.Peek() = 1X THEN
							(* read used record *)
							ch := r.Get();
							r.RawNum(arg); (* tdentry *)
							IF r.Peek() # 0X THEN
								r.RawNum(arg); (* FP *)
								r.RawString(name);
								ASSERT(name = "@");
							END;
							ch := r.Get();
							ASSERT(ch = 0X)
						END;
					END
				END ReadEntry;

			BEGIN
				WHILE r.Peek() # 0X DO
					r.RawString(name);
					NEW(import);
					COPY(name,import.name);
					AddImport(import);
					WHILE r.Peek() # 0X DO
						ReadEntry
					END;
					ch := r.Get();
					ASSERT(ch = 0X)
				END
			END ReadUsedModules;

		BEGIN
			ch := r.Get();
			ASSERT(ch = 08AX);
			ReadUsedModules;
			ch := r.Get();
			ASSERT(ch = 0X)
		END SkipUse;

		PROCEDURE DecodeTypes;
		VAR
			i, j, size, entry, ptrOfs, tdaddr, moduleBase, nofMethods, nofInhMethods, nofNewMethods, nofPointers, tdSize (* ug *), methNr, entryNr : LONGINT;
			name : ARRAY 256 OF CHAR; ch : CHAR;
			type : TypeInfo;
			procInfo : ProcedureInfo;
		BEGIN
			ch := r.Get();
			ASSERT(ch = 08BX);
			typeCount := header.types;
			NEW(types, typeCount);
			FOR i := 0 TO header.types-1 DO
				r.RawNum(size);
				r.RawNum(tdaddr);
				(* read Base *)
				r.RawNum(moduleBase); r.RawNum(entry);
				(* read Count *)
				r.RawNum(nofMethods); nofMethods := ABS (nofMethods);
				r.RawNum(nofInhMethods); r.RawNum(nofNewMethods); r.RawLInt(nofPointers);
				r.RawString(name);
				r.RawLInt(tdSize); (* ug *)
				NEW(type, name);
				IF type.name = "" THEN type.name := "[anonymous]" END;
				types[i] := type;

				KernelLog.Ln;
				KernelLog.String(" - name = "); KernelLog.String(type.name); KernelLog.Ln;
				KernelLog.String(" - size = "); KernelLog.Int(size, 0); KernelLog.Ln;
				KernelLog.String(" - tdaddr = "); KernelLog.Int(tdaddr, 0); KernelLog.Ln;
				KernelLog.String(" - moduleBase = "); KernelLog.Int(moduleBase, 0); KernelLog.Ln;
				KernelLog.String(" - entry = "); KernelLog.Int(entry, 0); KernelLog.Ln;
				KernelLog.String(" - nofMethods = "); KernelLog.Int(nofMethods, 0); KernelLog.Ln;
				KernelLog.String(" - nofInhMethods = "); KernelLog.Int(nofInhMethods, 0); KernelLog.Ln;
				KernelLog.String(" - nofNewMethods = "); KernelLog.Int(nofNewMethods, 0); KernelLog.Ln;
				KernelLog.String(" - nofPointers = "); KernelLog.Int(nofPointers, 0); KernelLog.Ln;
				KernelLog.String(" - tdSize = "); KernelLog.Int(tdSize, 0); KernelLog.Ln; (* ug *)
				KernelLog.String(" - Methods:"); KernelLog.Ln;

				(* read Methods *)
				type.procedureCount := nofNewMethods;
				NEW(type.procedures, type.procedureCount);
				FOR j := 0 TO type.procedureCount-1 DO
					r.RawNum(methNr); r.RawNum(entryNr);
					NEW(procInfo, "", module.entry[entryNr], entryNr);
					procInfo.method := TRUE;
					AddProcedure(procInfo);
					type.procedures[j] := procInfo;
				END;

				KernelLog.String(" - PtrOfs: ");
				(* read Pointers *)
				FOR j := 0 TO nofPointers-1 DO
					r.RawNum(ptrOfs);
					KernelLog.Int(ptrOfs,1); KernelLog.String(" ");
				END;
				KernelLog.Ln;
			END;
		END DecodeTypes;

		PROCEDURE DecodeExTable(r: Streams.Reader);
		VAR
			i: LONGINT;
			tag: CHAR;
			a: LONGINT;
		BEGIN
			NEW(module.exTable, header.exTableLen);
			FOR i := 0 TO header.exTableLen -1 DO
				r.Char(tag);
				ASSERT(tag = 0FEX);
				r.RawNum(a); module.exTable[i].pcFrom := a;
				r.RawNum(a); module.exTable[i].pcTo := a;
				r.RawNum(a); module.exTable[i].pcHandler := a;
			END;
		END DecodeExTable;

		PROCEDURE SkipPointerInProc;
		VAR ch : CHAR;
			i, j, codeoffset, beginOffset, endOffset, p, nofptrs : LONGINT;
		BEGIN
			ch := r.Get();
			ASSERT(ch = 8FX);
			KernelLog.String(" - PointersInProc: "); KernelLog.Ln;
			NEW(gcInfo,noProcs);
			FOR i := 0 TO noProcs - 1 DO
				NEW(gcInfo[i]);
				r.RawNum(codeoffset);
				r.RawNum(beginOffset);
				r.RawNum(endOffset);
				gcInfo[i].codeOffset := codeoffset;
				gcInfo[i].beginOffset := beginOffset;
				gcInfo[i].endOffset := endOffset;
				r.RawLInt(nofptrs);
				NEW(gcInfo[i].pointers,nofptrs);
				FOR j := 0 TO nofptrs - 1 DO
					r.RawNum(p);
					gcInfo[i].pointers[j] := p;
				END
			END
		END SkipPointerInProc;

		PROCEDURE &New (CONST fileName : ARRAY OF CHAR);
		VAR ch : CHAR; tmp : LONGINT; j, res : LONGINT; msg : ARRAY 255 OF CHAR; pos: LONGINT;
		BEGIN
			Init;
			Strings.GetExtension (fileName, msg, ext);
			lastExt := ext;
			codeScaleCallback := GetCodeScaleCallback(ext);
			f := Files.Old(fileName);
			IF f # NIL THEN
				Files.OpenReader(r, f, 0);
				IF r.Get() = 0BBX THEN
					version := ORD(r.Get());
					IF version = 0ADH THEN version := ORD(r.Get()) END;
					IF version = 0B1H THEN (* PACO object file *)
						r.RawNum(symSize);
					ELSIF (version >= 0B2H) THEN (*fof: OC object file *)
						r.RawLInt(symSize);
					END;
					r.SkipBytes(symSize); (* skip symbol file *)
				ELSE
					KernelLog.String("Decoder: ERROR: Tag not supported or wrong file type!"); KernelLog.Ln;
					RETURN
				END;
				r.RawLInt(header.refSize);
				r.RawLInt(header.entries);
				r.RawLInt(header.commands);
				r.RawLInt(header.pointers);
				r.RawLInt(header.types);
				r.RawLInt(header.modules);
				r.RawLInt(nofVarConstLinks);
				r.RawLInt(nofLinks);
				r.RawLInt(header.dataSize);
				r.RawLInt(header.constSize);
				r.RawLInt(header.codeSize);

				IF (codeScaleCallback # NIL) THEN codeScaleCallback(header.codeSize) END;

				(* Sz: Exception handling *)
				r.RawLInt(header.exTableLen);

				(* ug: Pointers in procedures, maxPtrs, staticTdSize: *)
				r.RawLInt(noProcs);
				r.RawLInt(tmp); (* ug: skip maxPtrs *)
				r.RawLInt(tmp); (* ug: skip staticTdSize *)
				IF version > 0B3H THEN r.RawLInt(header.crc) END;
				r.RawString(name);
				(* skip to code block *)
				DecodeEntries;
				SkipCommands;
				SkipPointers;
				SkipImports;
				SkipVarConstLinks;
				SkipLinks;
				SkipConsts;
				SkipExports;
				ch := r.Get();
				pos := r.Pos();
				ASSERT(ch = 89X);

				(* code section *)
				NEW(module.code, header.codeSize);
				FOR j := 0 TO header.codeSize-1 DO
					module.code[j] := r.Get()
				END;
				SkipUse;
				DecodeTypes;

				(* Sz: read exception handling table *)
				ch := r.Get();
				ASSERT(ch = 8EX);
				DecodeExTable(r);

				SkipPointerInProc; (* ug *)

				(* read ref header *)
				ch := r.Get();
				ASSERT(ch = OFFHdrRef);
				DecodeRefs(r);
			ELSE
				msg := "Object file '"; Strings.Append(msg, fileName); Strings.Append(msg, "' could not be found.");
				 WMDialogs.Error("Decoder", msg)
			END;
		END New;

	END ModuleInfoObjectFile;

	ModuleInfoMemory = OBJECT (ModuleInfo)
		VAR
			reader : MemoryReader.Reader;

		PROCEDURE &New (module : Modules.Module; header: ObjHeader);
		BEGIN
			Init;
			COPY(module.name,name);
			representationMode := RepresentationModeMeta;

			NEW(reader, ADDRESSOF(module.refs[0]), header.refSize);
			SELF.module := module;
			SELF.header := header;

			DecodeRefs(reader);
			DecodeTypes
		END New;

		PROCEDURE DecodeTypes;
		VAR
			i, j : LONGINT;
			type : TypeInfo;
			typeDesc : Modules.TypeDesc;
			adr : ADDRESS;
		BEGIN
			typeCount := header.types;
			NEW(types, typeCount);
			FOR i := 0 TO typeCount-1 DO

(* ug: for old heap DS *)
(*
				adr := SYSTEM.VAL(ADDRESS, module.type[i]);
				SYSTEM.GET(adr - AddressSize, typeDesc);
				NEW(type, typeDesc.name);
*)
(* ug: for new heap DS *)
				NEW(type, module.typeInfo[i].name);
				types[i] := type;
				(* check for methods of this type *)
				IF type.name # "" THEN
					(* silly way: name matching -> improve by reading typeDesc method block *)
					FOR j := 0 TO procedureCount-1 DO
						IF Strings.StartsWith(type.name, 0, procedures[j].name) THEN
							type.AddProcedure(procedures[j]);
							procedures[j].method := TRUE
						END
					END
				ELSE
					type.name := "[anonymous]"
				END
			END
		END DecodeTypes;

	END ModuleInfoMemory;

	KillerMsg = OBJECT
	END KillerMsg;

	DecoderWindow = OBJECT (WMComponents.FormWindow)
	VAR
		panel : WMStandardComponents.Panel;
		toolbar : WMStandardComponents.Panel;
		decodeFile, decodeModule, decodeBytes: WMStandardComponents.Button;
		stopped : BOOLEAN;
		moduleInfo : ModuleInfo;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		BEGIN

			NEW(panel); panel.bounds.SetExtents(1024, 768); panel.fillColor.Set(WMGraphics.White); panel.takesFocus.Set(TRUE);
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);

			NEW(decodeFile); decodeFile.caption.SetAOC("Decode File"); decodeFile.alignment.Set(WMComponents.AlignLeft);
			decodeFile.bounds.SetWidth(2 * decodeFile.bounds.GetWidth());
			decodeFile.onClick.Add(DecodeFileHandler);
			toolbar.AddContent(decodeFile);

			NEW(decodeModule); decodeModule.caption.SetAOC("Decode Module"); decodeModule.alignment.Set(WMComponents.AlignLeft);
			decodeModule.bounds.SetWidth(2 * decodeModule.bounds.GetWidth());
			decodeModule.onClick.Add(DecodeModuleHandler);
			toolbar.AddContent(decodeModule);

			NEW(decodeBytes); decodeBytes.caption.SetAOC("Decode Bytes"); decodeBytes.alignment.Set(WMComponents.AlignLeft);
			decodeBytes.bounds.SetWidth(2 * decodeBytes.bounds.GetWidth());
			decodeBytes.onClick.Add(DecodeBytesHandler);
			toolbar.AddContent(decodeBytes);

			RETURN panel
		END CreateForm;

		PROCEDURE &New(CONST fileName : ARRAY OF CHAR; c : WMRestorable.Context);
		VAR
			vc : WMComponents.VisualComponent;
			moduleInfoObjectFile : ModuleInfoObjectFile;
			moduleInfoMemory : ModuleInfoMemory;
			msg : ARRAY 256 OF CHAR;
			module : Modules.Module;
			header: ObjHeader;
			res, extPos : LONGINT;
		BEGIN
			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			WM.DefaultAddWindow(SELF);

			stopped := FALSE;
			IF fileName # "" THEN
				extPos := Strings.Pos(".", fileName) + 1;
				IF extPos # 0 THEN (* must be a file name *)
					(* load the file and outline it *)
					NEW(moduleInfoObjectFile, fileName);
					moduleInfoObjectFile.Outline(panel);
					moduleInfo := moduleInfoObjectFile;
				ELSE
					module := Modules.ThisModule(fileName, res, msg);
					MakeHeader(module, header);
					NEW(moduleInfoMemory, module, header);

					moduleInfoMemory.Outline(panel);
					moduleInfo := moduleInfoMemory;
				END;
				AdjustTitle(fileName);
			ELSE
				AdjustTitle("")
			END;
			IncCount;
		END New;

		PROCEDURE AdjustTitle (CONST str : ARRAY OF CHAR);
		VAR
			titleString : ARRAY Files.NameLength+10 OF CHAR;
		BEGIN
			titleString := "Decoder";
			IF str # "" THEN
				Strings.Append(titleString, " - ");
				Strings.Append(titleString, str)
			END;
			SetTitle(Strings.NewString(titleString))
		END AdjustTitle;

		PROCEDURE DecodeFileHandler(sender, data : ANY);
		VAR
			fileNameStr : ARRAY Files.NameLength OF CHAR;
			moduleInfoObjectFile : ModuleInfoObjectFile;
		BEGIN
			IF WMDialogs.QueryString("Enter file name", fileNameStr) = WMDialogs.ResOk THEN
				IF moduleInfo # NIL THEN
					moduleInfo.Discard(panel)
				END;
				NEW(moduleInfoObjectFile, fileNameStr);
				moduleInfoObjectFile.Outline(panel);
				moduleInfo := moduleInfoObjectFile;
				AdjustTitle(fileNameStr)
			END;
		END DecodeFileHandler;

		PROCEDURE DecodeModuleHandler(sender, data : ANY);
		VAR moduleNameStr, msg : ARRAY 256 OF CHAR;
			module : Modules.Module;
			res : LONGINT;
			moduleInfoMemory : ModuleInfoMemory;
			header: ObjHeader;
		BEGIN
			IF WMDialogs.QueryString("Enter module name", moduleNameStr) = WMDialogs.ResOk THEN
				module := Modules.ThisModule(moduleNameStr, res, msg);
				IF res # 0 THEN
					msg := "Module "; Strings.Append(msg, moduleNameStr); Strings.Append(msg, " not found in memory.");
					WMDialogs.Error("Decoder", msg);
				ELSE
					IF moduleInfo # NIL THEN
						moduleInfo.Discard(panel)
					END;
					MakeHeader(module,header);
					NEW(moduleInfoMemory, module, header);
					moduleInfoMemory.Outline(panel);
					moduleInfo := moduleInfoMemory;
					AdjustTitle(moduleNameStr)
				END
			END
		END DecodeModuleHandler;

		PROCEDURE DecodeBytesHandler(sender, data : ANY);
		VAR hexByteStr : ARRAY 1024 OF CHAR;
			moduleInfoBytes : ModuleInfoBytes;
		BEGIN
			IF WMDialogs.QueryString("Enter bytes in hex format (separated by spaces)", hexByteStr) = WMDialogs.ResOk THEN
				IF moduleInfo # NIL THEN
					moduleInfo.Discard(panel)
				END;
				NEW(moduleInfoBytes, HexBytes2Code(hexByteStr));
				moduleInfoBytes.Outline(panel);
				moduleInfo := moduleInfoBytes;
				AdjustTitle("[byte array]")
			END
		END DecodeBytesHandler;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE OutlineProcedure (CONST name : ARRAY OF CHAR);
		BEGIN
			IF (moduleInfo # NIL) & ~(moduleInfo IS ModuleInfoBytes) THEN
				moduleInfo.OutlineNamedProcedure(name)
			END
		END OutlineProcedure;

		PROCEDURE OutlinePC (pc : LONGINT);
		BEGIN
			IF (moduleInfo # NIL) & ~(moduleInfo IS ModuleInfoBytes) THEN
				moduleInfo.OutlinePC(pc)
			END
		END OutlinePC;

		PROCEDURE Close;
		BEGIN
			Close^;
			BEGIN {EXCLUSIVE}
				stopped := TRUE
			END;
			DecCount
		END Close;
	END DecoderWindow;

	Extension = ARRAY 4 OF CHAR;

	DecoderType = OBJECT
		VAR
			ext : Extension;
			decoderFactory : DecoderFactory;
			codeScaleCallback : CodeScaleCallback;

		PROCEDURE &New (CONST ext : Extension; decoderFactory : DecoderFactory; codeScaleCallback : CodeScaleCallback);
		BEGIN
			SELF.ext := ext; SELF.decoderFactory := decoderFactory; SELF.codeScaleCallback := codeScaleCallback
		END New;
	END DecoderType;

VAR
	nofWindows : LONGINT;
	win : DecoderWindow;
	decoderTypes : ARRAY maxDecoders OF DecoderType;
	nofDecoders : LONGINT;
	lastExt : Extension;

	PROCEDURE OpenEmpty*;
	BEGIN
		NEW(win, "", NIL);
	END OpenEmpty;

	PROCEDURE MakeHeader(module: Modules.Module; VAR header: ObjHeader);
	BEGIN
		header.entries := LEN(module.entry);
		header.commands := LEN(module.command);
		header.pointers := LEN(module.ptrAdr);
		header.types := LEN(module.typeInfo);
		header.modules := LEN(module.module);
		header.codeSize := LEN(module.code);
		header.dataSize := LEN(module.data);
		header.refSize := LEN(module.refs);
		header.constSize := 0;
		header.exTableLen := LEN(module.exTable);
		header.procs := module.noProcs;
		header.maxPtrs := module.maxPtrs;
		header.staticTdSize := LEN(module.typeInfo);
		header.crc := module.crc;
		header.name := module.name;
	END MakeHeader;


	PROCEDURE RemoveTypeName (VAR procName : ARRAY OF CHAR; CONST typeName : ARRAY OF CHAR);
	VAR
		i, j : LONGINT;
	BEGIN
		i := 0;
		IF Strings.Length(typeName) > 0 THEN
			WHILE procName[i] = typeName[i] DO INC(i) END;
			IF (typeName[i] = 0X) & (procName[i] = '.') THEN
				j := 0;
				INC(i);
				WHILE procName[i] # 0X DO
					procName[j] := procName[i];
					INC(i); INC(j)
				END;
				procName[j] := 0X
			END
		END
	END RemoveTypeName;

	PROCEDURE HexBytes2Code(CONST bytes : ARRAY OF CHAR) : Modules.Bytes;
	VAR
		buffer, result : Modules.Bytes;
		byte : CHAR;
		j, size : LONGINT;

		PROCEDURE DecodeHexChar(ch : CHAR) : LONGINT;
		BEGIN
			IF (ORD(ch) >= 48) & (ORD(ch) <= 57) THEN RETURN ORD(ch) - 48 END;
			IF (ORD(ch) >= 65) & (ORD(ch) <= 70) THEN RETURN ORD(ch) - 55 END;
			IF (ORD(ch) >= 97) & (ORD(ch) <= 102) THEN RETURN ORD(ch) - 87 END;
			RETURN 0
		END DecodeHexChar;

	BEGIN
		NEW(buffer, LEN(bytes));
		j := 0; size := 0;
		WHILE j < Strings.Length(bytes)-1 DO
			byte := CHR(DecodeHexChar(bytes[j])*16 + DecodeHexChar(bytes[j+1]));
			INC(j, 2);
			IF (j < LEN(bytes)) & (bytes[j] = 20X) THEN INC(j) END;
			buffer[size] := byte;
			INC(size)
		END;
		NEW(result, size);
		j := 0;
		WHILE j < size DO
			result[j] := buffer[j]; INC(j)
		END;
		RETURN result
	END HexBytes2Code;

	PROCEDURE IntToHex(h, width: LONGINT; VAR s: ARRAY OF CHAR);
	VAR c: CHAR;
	BEGIN
		IF (width <= 0) THEN width := 8 END;
		ASSERT(LEN(s) > width);
		s[width] := 0X;
		DEC(width);
		WHILE (width >= 0) DO
			c := CHR(h MOD 10H + ORD("0"));
			IF (c > "9") THEN c := CHR((h MOD 10H - 10) + ORD("A")) END;
			s[width] := c; h := h DIV 10H; DEC(width)
		END
	END IntToHex;

	PROCEDURE IncCount;
	BEGIN {EXCLUSIVE}
		INC(nofWindows)
	END IncCount;

	PROCEDURE DecCount;
	BEGIN {EXCLUSIVE}
		DEC(nofWindows)
	END DecCount;

	PROCEDURE Cleanup;
	VAR
		die : KillerMsg;
		msg : WMMessages.Message;
		m : WM.WindowManager;
	BEGIN {EXCLUSIVE}
		NEW(die);
		msg.ext := die;
		msg.msgType := WMMessages.MsgExt;
		m := WM.GetDefaultManager();
		m.Broadcast(msg);
		AWAIT(nofWindows = 0);
	END Cleanup;

	PROCEDURE Open* (context : Commands.Context);
	VAR
		name : ARRAY Files.NameLength OF CHAR;
		pc : LONGINT;
	BEGIN
		context.arg.SkipWhitespace; context.arg.String(name);
		NEW(win, name, NIL);
		context.arg.SkipWhitespace();
		IF (context.arg.Peek() < "0") OR (context.arg.Peek() > "9") THEN
			context.arg.Token(name);
			IF name # "" THEN win.OutlineProcedure (name) END
		ELSIF (context.arg.Peek() >= "0") & (context.arg.Peek() <= "9") THEN
			context.arg.Int(pc, FALSE);
			IF pc > 0 THEN win.OutlinePC(pc) END
		END;
	END Open;

	PROCEDURE OpenProcedure* (CONST moduleName, procedureName : ARRAY OF CHAR);
	BEGIN
		NEW(win, moduleName, NIL);
		win.OutlineProcedure(procedureName)
	END OpenProcedure;

	PROCEDURE OpenPC* (CONST moduleName : ARRAY OF CHAR; pc : LONGINT);
	BEGIN
		NEW(win, moduleName, NIL);
		win.OutlinePC(pc)
	END OpenPC;

	PROCEDURE GetDecoderType (CONST ext : Extension) : DecoderType;
	VAR i : LONGINT;
	BEGIN
		IF nofDecoders < 1 THEN RETURN NIL END;
		IF ext = "" THEN RETURN decoderTypes[0] END;
		FOR i := 0 TO nofDecoders-1 DO
			IF decoderTypes[i].ext = ext THEN
				RETURN decoderTypes[i]
			END
		END;
		RETURN NIL
	END GetDecoderType;

	PROCEDURE GetDecoder (CONST ext : Extension; reader : Streams.Reader) : Decoder;
	VAR dec : DecoderType;
	BEGIN
		dec := GetDecoderType(ext);
		IF dec # NIL THEN RETURN dec.decoderFactory(reader)
		ELSE RETURN NIL
		END
	END GetDecoder;

	PROCEDURE RegisterDecoder* (CONST ext : Extension; decFactory : DecoderFactory; csclCallback : CodeScaleCallback);
	VAR dec : DecoderType;
	BEGIN
		ASSERT(nofDecoders < maxDecoders);
		dec := GetDecoderType(ext);
		IF dec = NIL THEN
			NEW(decoderTypes[nofDecoders], ext, decFactory, csclCallback);
			INC(nofDecoders)
		END
	END RegisterDecoder;

	PROCEDURE GetCodeScaleCallback (CONST ext : Extension) : CodeScaleCallback;
	VAR dec : DecoderType;
	BEGIN
		dec := GetDecoderType(ext);
		IF dec # NIL THEN RETURN dec.codeScaleCallback
		ELSE RETURN NIL
		END
	END GetCodeScaleCallback;

	PROCEDURE Initialize (CONST decoder: ARRAY OF CHAR);
	VAR initializer: PROCEDURE;
	BEGIN
		GETPROCEDURE (decoder, "Init", initializer);
		IF initializer # NIL THEN initializer END;
	END Initialize;

BEGIN
	nofDecoders := 0;
	Modules.InstallTermHandler(Cleanup);
	Initialize ("I386Decoder");
	Initialize ("ARMDecoder");
	Initialize ("AMD64Decoder");
END Decoder.

SystemTools.FreeDownTo Decoder ~
WMProperties.Obw
