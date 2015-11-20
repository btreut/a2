MODULE FoxBinaryCode; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Basic := FoxBasic, Sections := FoxSections, SYSTEM, Streams, ObjectFile, BitSets, D := Debugging;

CONST
	Absolute*=ObjectFile.Absolute;
	Relative*=ObjectFile.Relative;
	Byte=8;
TYPE
	Code* = BitSets.BitSet;
	Unit*= ObjectFile.Unit;
	Bits*=ObjectFile.Bits;

	FixupPatterns*=ObjectFile.FixupPatterns;

	Alias*=OBJECT
	VAR
		nextAlias-: Alias;
		identifier-: ObjectFile.Identifier;
		offset-: LONGINT;

		PROCEDURE & InitAlias*(identifier: ObjectFile.Identifier; offset: LONGINT);
		BEGIN
			nextAlias := NIL;
			SELF.identifier := identifier;
			SELF.offset := offset;
		END InitAlias;

		PROCEDURE Dump*(w: Streams.Writer);
		VAR i: LONGINT;
		BEGIN
			Basic.WriteSegmentedName(w, identifier.name);
			IF identifier.fingerprint # 0 THEN w.String("["); w.Hex(identifier.fingerprint,-8); w.String("]") END;
			w.String(" "); w.Int(offset,1);
		END Dump;

	END Alias;

	AliasList*=OBJECT
	VAR
		firstAlias-, lastAlias-: Alias; aliases-: LONGINT;

		PROCEDURE &InitAliasList*;
		BEGIN
			firstAlias := NIL; lastAlias := NIL;
			aliases := 0;
		END InitAliasList;

		PROCEDURE AddAlias*(alias: Alias);
		BEGIN
			IF firstAlias = NIL THEN
				firstAlias := alias;
			ELSE
				lastAlias.nextAlias := alias;
			END;
			lastAlias := alias; alias.nextAlias := NIL;
			INC(aliases);
		END AddAlias;

		PROCEDURE Dump*(w: Streams.Writer);
		VAR alias: Alias;
		BEGIN
			alias := firstAlias;
			WHILE alias # NIL DO
				w.String("alias "); w.Int(alias.offset,1); w.String(" <-- ");
				alias.Dump(w);
				w.Ln;
				alias := alias.nextAlias;
			END;
		END Dump;

	END AliasList;

	Fixup*=OBJECT
	VAR
		nextFixup-: Fixup;
		mode-: INTEGER; (* fixup mode: relative or absolute *)
		displacement-: ObjectFile.Unit; (* displacement of the fixup ('source') *)
		scale-: ObjectFile.Bits; (* exponent of scale factor (factor=2^scale) *)
		patterns-: LONGINT;
		pattern-: FixupPatterns; (* patterns describing the fixup format, cf. above *)
		offset-: ObjectFile.Unit;

		symbol-: ObjectFile.Identifier; (* reference to the fixup's destination section *)
		symbolOffset-: LONGINT; (* offset in intermediate section, must be patched (resolved and added to displacement) to destination section displacement *)
		resolved*: Sections.Section; (* cache ! *)

		PROCEDURE & InitFixup*(mode: INTEGER; fixupOffset: Unit; symbol: ObjectFile.Identifier; symbolOffset: LONGINT; displacement: Unit; scale: LONGINT; fixupPattern: ObjectFile.FixupPatterns);
		BEGIN
			ASSERT((mode = Relative) OR (mode = Absolute));
			ASSERT(symbol.name # "");
			ASSERT(symbol.name[0] # 0);
			nextFixup := NIL;
			SELF.mode := mode;
			SELF.displacement := displacement;
			SELF.scale := scale;
			SELF.offset := fixupOffset;
			SELF.pattern := fixupPattern;
			IF fixupPattern # NIL THEN
				SELF.patterns := LEN(fixupPattern);
			ELSE
				SELF.patterns := 0
			END;

			SELF.symbol := symbol;
			SELF.symbolOffset := symbolOffset;
		END InitFixup;

		PROCEDURE SetFixupOffset*(offset: Unit);
		BEGIN
			SELF.offset := offset;
		END SetFixupOffset;

		PROCEDURE SetSymbol*(symbol: Sections.SectionName; fp: LONGINT; symbolOffset: LONGINT; displacement: Unit);
		BEGIN
			SELF.symbol.name := symbol;
			SELF.symbol.fingerprint := fp;
			SELF.symbolOffset := symbolOffset;
			SELF.displacement := displacement;
		END SetSymbol;

		PROCEDURE Dump*(w: Streams.Writer);
		VAR i: LONGINT;
		BEGIN
			Basic.WriteSegmentedName(w, symbol.name);
			IF symbol.fingerprint # 0 THEN w.String("["); w.Hex(symbol.fingerprint,-8); w.String("]") END;
			IF symbolOffset # 0 THEN w.String(":"); w.Int(symbolOffset, 0) END;

			w.String(" (displ="); w.Int(displacement, 0); w.String(")");

			IF scale # 0 THEN w.String(" *"); w.Int(scale,1); END;
			w.String(" [");

			IF pattern # NIL THEN
				FOR i := 0 TO LEN(pattern)-1 DO
					w.Int(pattern[i].offset,1);
					IF pattern[i].bits >=0 THEN w.String("+"); w.Int(pattern[i].bits,1);
					ELSE w.String("-"); w.Int(-pattern[i].bits,1);
					END;
					IF i < LEN(pattern)-1 THEN w.String(", ") ELSE w.String(" ") END;
				END;
			END;
			IF mode = Absolute THEN w.String("abs") ELSIF mode = Relative THEN w.String("rel") ELSE w.String("?"); END;
			w.String("]");

		END Dump;

	END Fixup;

	FixupList*=OBJECT
	VAR
		firstFixup-, lastFixup-: Fixup; fixups-: LONGINT;

		PROCEDURE &InitFixupList*;
		BEGIN
			firstFixup := NIL; lastFixup := NIL;
			fixups := 0;
		END InitFixupList;

		PROCEDURE AddFixup*(fixup: Fixup);
		BEGIN
			IF firstFixup = NIL THEN
				firstFixup := fixup;
			ELSE
				lastFixup.nextFixup := fixup;
			END;
			lastFixup := fixup; fixup.nextFixup := NIL;
			INC(fixups);
		END AddFixup;

		PROCEDURE Dump*(w: Streams.Writer);
		VAR fixup: Fixup;
		BEGIN
			fixup := firstFixup;
			WHILE fixup # NIL DO
				w.String("fixup "); w.Int(fixup.offset,1); w.String(" <-- ");
				fixup.Dump(w);
				w.Ln;
				fixup := fixup.nextFixup;
			END;
		END Dump;

	END FixupList;

	LabelList*= POINTER TO RECORD
		offset-: LONGINT; position-: LONGINT;
		prev-: LabelList;
	END;


	Section* = OBJECT
	VAR
		os*: ObjectFile.Section;
		labels-: LabelList; (* labels for tracking the PC / debugging *)
		fixupList-: FixupList;
		aliasList-: AliasList;
		finally-: Unit; (* position of finally section in bitstream -1 if none *)
		comments-: Sections.CommentWriter; (* writer to write comment text between instructions *)
		bigEndian-: BOOLEAN; (* endianess of bits (not bytes) *)
		validPAFEnter-,validPAFExit-: Unit; (* begin and end of code section where current PAF (procedure activation frame) is considered valid *)
		pc-: Unit; (* current position, in units *)

		PROCEDURE GetPC(): LONGINT;
		BEGIN
			RETURN pc
		END GetPC;


		PROCEDURE & InitBinarySection*(type: SHORTINT; priority: LONGINT; unit: LONGINT; CONST name:Basic.SegmentedName; dump: BOOLEAN; bigEndian: BOOLEAN);
		BEGIN
			ASSERT(unit > 0);
			ASSERT(unit <= 32); (* implementation restriction *)
			SELF.os.type := type;
			os.identifier.name := name;
			(*
			ObjectFile.ToSegmentedName(name, SELF.identifier.name);
			*)
			(*COPY(name,SELF.identifier.name);*)
			NEW(os.bits,0);
			SELF.os.unit := unit;
			IF dump THEN
				comments := Sections.NewCommentWriter(GetPC);
			ELSE
				comments := NIL
			END;
			os.alignment := 0;
			finally := -1;
			labels := NIL;
			SELF.bigEndian := bigEndian;
			NEW(fixupList);
			NEW(aliasList);
			validPAFEnter := 0; validPAFExit := 0;
			pc := 0;
			os.fixed := FALSE;
			SELF.os.priority := priority;
		END InitBinarySection;

		PROCEDURE Reset*;
		BEGIN
			NEW(os.bits,0);
			NEW(fixupList);
			IF comments # NIL THEN comments.Reset END;
			validPAFEnter := 0; validPAFExit := 0;
			pc := 0;
		END Reset;

		PROCEDURE EnterValidPAF*;
		BEGIN
			validPAFEnter := pc;
		END EnterValidPAF;

		PROCEDURE ExitValidPAF*;
		BEGIN
			validPAFExit := pc;
		END ExitValidPAF;

		PROCEDURE AddLabel*(position: Unit);
		VAR new: LabelList;
		BEGIN
			NEW(new);
			IF labels = NIL THEN
				labels := new
			ELSE
				new.prev := labels; labels := new;
			END;
			new.position := position;
			new.offset := pc;
		END AddLabel;

		PROCEDURE SetPC*(pc: Unit);
		BEGIN
			SELF.pc := pc;
			CheckSize(0); (* adjust size *)
		END SetPC;

		PROCEDURE Align*(alignment: Unit);
		BEGIN
			SetPC(pc + (-pc) MOD alignment)
		END Align;


		PROCEDURE SetFinally*(atPC: Unit);
		BEGIN finally := atPC
		END SetFinally;

		PROCEDURE SetAlignment*(fixed: BOOLEAN; alignat: LONGINT);
		BEGIN os.alignment := alignat; SELF.os.fixed := fixed;
		END SetAlignment;

		PROCEDURE CheckSize(size: LONGINT);
		BEGIN
			IF os.bits.GetSize()  < size + pc*os.unit THEN os.bits.Resize(size + pc*os.unit) END;
			ASSERT(os.bits.GetSize() MOD os.unit = 0);
		END CheckSize;

		PROCEDURE CopyBits*(src: BitSets.BitSet; srcPos, len: Bits);
		BEGIN
			ASSERT(len MOD os.unit = 0);
			CheckSize(src.GetSize());
			BitSets.CopyBits(src,srcPos,os.bits,pc*os.unit,len);
			INC(pc,len DIV os.unit);
		END CopyBits;

		PROCEDURE PutBits*(d: LONGINT; size: Bits);
		BEGIN
			(*ASSERT(size MOD unit = 0);*)
			CheckSize(size);
			os.bits.SetBits(pc*os.unit,size,d);
			INC(pc,size DIV os.unit);
		END PutBits;

		PROCEDURE PutBitsAt*(at: Unit; d: LONGINT; size: Bits);
		VAR oldpc: LONGINT;
		BEGIN
			oldpc := pc;
			pc := at;
			PutBits(d,size);
			pc := oldpc;
		END PutBitsAt;

		PROCEDURE PutByte* (b: LONGINT);
		BEGIN
			PutBits(b,Byte);
		END PutByte;

		PROCEDURE PutWord*(w: LONGINT);
		VAR c1,c2: LONGINT;
		BEGIN
			ASSERT((2*Byte) MOD os.unit = 0);
			CheckSize(2*Byte);
			c1 := w;
			c2 := w DIV 100H;
			IF bigEndian THEN
				os.bits.SetBits(pc*os.unit,Byte,c2);
				os.bits.SetBits(pc*os.unit+Byte,Byte,c1);
			ELSE
				os.bits.SetBits(pc*os.unit,Byte,c1);
				os.bits.SetBits(pc*os.unit+Byte,Byte,c2);
			END;
			INC(pc,(2*Byte) DIV os.unit);
		END PutWord;

		PROCEDURE PutDWord*(d: LONGINT);
		VAR c1,c2,c3,c4: LONGINT;
		BEGIN
			ASSERT((4*Byte) MOD os.unit = 0);
			CheckSize(4*Byte);
			c1 := d;
			c2 := d DIV 100H;
			c3 := d DIV 10000H;
			c4 := d DIV 1000000H;
			IF bigEndian THEN
				os.bits.SetBits(pc*os.unit+0*Byte,Byte,c4);
				os.bits.SetBits(pc*os.unit+1*Byte,Byte,c3);
				os.bits.SetBits(pc*os.unit+2*Byte,Byte,c2);
				os.bits.SetBits(pc*os.unit+3*Byte,Byte,c1);
			ELSE
				os.bits.SetBits(pc*os.unit+0*Byte,Byte,c1);
				os.bits.SetBits(pc*os.unit+1*Byte,Byte,c2);
				os.bits.SetBits(pc*os.unit+2*Byte,Byte,c3);
				os.bits.SetBits(pc*os.unit+3*Byte,Byte,c4);
			END;
			INC(pc,(4*Byte) DIV os.unit);
		END PutDWord;

		PROCEDURE PutQWord* (q: HUGEINT);
		VAR c: ARRAY 8 OF LONGINT; i: LONGINT;
		BEGIN
			ASSERT((8*Byte) MOD os.unit = 0);
			CheckSize(8*Byte);
			FOR i := 0 TO 7 DO
				c[i] := SHORT(q MOD 100H);
				q := q DIV 100H;
			END;
			IF bigEndian THEN
				FOR i := 0 TO 7 DO
					os.bits.SetBits(pc*os.unit+i*Byte,Byte,c[7-i]);
				END;
			ELSE
				FOR i := 0 TO 7 DO
					os.bits.SetBits(pc*os.unit+i*Byte,Byte,c[i]);
				END;
			END;
			INC(pc,(8*Byte) DIV os.unit);
		END PutQWord;


		PROCEDURE PutReal*(f: REAL);
		VAR x: LONGINT;
		BEGIN
			x := ConvertReal(f);
			PutDWord(x)
		END PutReal;

		PROCEDURE PutLongreal*(f: LONGREAL);
		VAR x: HUGEINT;
		BEGIN
			x := ConvertLongreal(f);
			PutQWord(x)
		END PutLongreal;

		PROCEDURE PutByteAt*(at: Unit; d: LONGINT);
		VAR oldpc: LONGINT;
		BEGIN
			oldpc := pc;
			pc := at;
			PutByte(d);
			pc := oldpc;
		END PutByteAt;

		PROCEDURE PutWordAt*(at: Unit; d: LONGINT);
		VAR oldpc: LONGINT;
		BEGIN
			oldpc := pc;
			pc := at;
			PutWord(d);
			pc := oldpc;
		END PutWordAt;

		PROCEDURE PutDWordAt*(at: Unit; d: LONGINT);
		VAR oldpc: LONGINT;
		BEGIN
			oldpc := pc;
			pc := at;
			PutDWord(d);
			pc := oldpc;
		END PutDWordAt;

		PROCEDURE PutQWordAt*(at: Unit; d: HUGEINT);
		VAR oldpc: LONGINT;
		BEGIN
			oldpc := pc;
			pc := at;
			PutQWord(d);
			pc := oldpc;
		END PutQWordAt;

		PROCEDURE PutBytes* (data: HUGEINT; bytes: SHORTINT);
		BEGIN
			CASE bytes OF
			1: PutByte (SHORT(data));
			| 2: PutWord (SHORT(data));
			| 4: PutDWord (SHORT(data));
			| 8: PutQWord(data);
			END
		END PutBytes;

		PROCEDURE GetByte* (pc: Unit): CHAR;
		BEGIN
			RETURN CHR(os.bits.GetBits(pc*os.unit,8));
		END GetByte;

		PROCEDURE GetWord*(pc: Unit): LONGINT;
		VAR c1,c2: LONGINT;
		BEGIN
			c1 := os.bits.GetBits(pc*os.unit,8);
			c2 := os.bits.GetBits(pc*os.unit+8,8);
			IF bigEndian THEN
				RETURN c1*100H + c2;
			ELSE
				RETURN c1 + c2*100H;
			END
		END GetWord;

		PROCEDURE GetDWord*(pc: Unit): LONGINT;
		VAR c1,c2,c3,c4: LONGINT;
		BEGIN
			c1 := os.bits.GetBits(pc*os.unit+0*Byte,Byte);
			c2 := os.bits.GetBits(pc*os.unit+1*Byte,Byte);
			c3 := os.bits.GetBits(pc*os.unit+2*Byte,Byte);
			c4 := os.bits.GetBits(pc*os.unit+3*Byte,Byte);
			IF bigEndian THEN
				RETURN c4 + 100H * (c3 + 100H * (c2 + c1*100H));
			ELSE
				RETURN c1 + 100H * (c2 + 100H * (c3 + c4*100H));
			END
		END GetDWord;

		PROCEDURE GetQWord*(pc: Unit): HUGEINT;
		VAR i: LONGINT; h: HUGEINT;
		BEGIN
			h := 0;
			IF bigEndian THEN
				FOR i := 0 TO 7 DO
					h := 100H*h;
					h := h + os.bits.GetBits(pc*os.unit+i*Byte,Byte);
				END;
			ELSE
				FOR i := 7 TO 0 BY -1 DO
					h := 100H*h;
					h := h + os.bits.GetBits(pc*os.unit+i*Byte,Byte);
				END;
			END;
			RETURN h
		END GetQWord;

		PROCEDURE GetReal*(pc: Unit): REAL;
		VAR x: LONGINT;
		BEGIN
			x := GetDWord(pc);
			RETURN ConvertToReal(x)
		END GetReal;

		PROCEDURE GetLongreal*(pc: Unit): LONGREAL;
		VAR x: HUGEINT;
		BEGIN
			x := GetDWord(pc);
			RETURN ConvertToLongreal(x)
		END GetLongreal;

		PROCEDURE GetBits*(pc: Unit; size: Bits): LONGINT;
		BEGIN
			RETURN os.bits.GetBits(pc*os.unit,size)
		END GetBits;

		PROCEDURE ApplyFixup*(fixup: Fixup): BOOLEAN;
		VAR address,i: LONGINT;

			PROCEDURE PatchPattern (CONST pattern: ObjectFile.FixupPattern);
			BEGIN
				IF pattern.offset # MIN(SHORTINT) THEN
					os.bits.SetBits(fixup.offset*os.unit+pattern.offset,pattern.bits,address);
				END;
				address := ASH (address, -pattern.bits);
			END PatchPattern;

			PROCEDURE CheckBits(): BOOLEAN;
			VAR nobits,remainder,i: LONGINT;
			BEGIN
				nobits := 0;
				FOR i := 0 TO fixup.patterns-1 DO
					INC(nobits,fixup.pattern[i].bits);
				END;
				IF fixup.mode = Relative THEN DEC(nobits) END;
				remainder := ASH(address,-nobits);
				RETURN (nobits >31) OR (remainder = 0) OR (remainder = -1)
			END CheckBits;

		BEGIN
			address := fixup.displacement;
			IF fixup.mode = Relative THEN
				address := address - fixup.offset
			ELSE
				ASSERT(fixup.mode = Absolute)
			END;
			address := ASH(address,fixup.scale);

			IF CheckBits() THEN
				FOR i := 0 TO fixup.patterns-1 DO
					PatchPattern(fixup.pattern[i]);
				END;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END;
		END ApplyFixup;

		PROCEDURE DumpCode*(w: Streams.Writer; from,to: Unit);
		VAR i: LONGINT; c: Sections.Comment; nextpos: LONGINT;

			PROCEDURE Hex(i: LONGINT): CHAR;
			BEGIN
				ASSERT(i>=0);
				ASSERT(i<16);
				IF i<10 THEN
					RETURN CHR(ORD("0")+i)
				ELSE
					RETURN CHR(ORD("A")+i-10);
				END;
			END Hex;


			PROCEDURE DumpUnit(at: LONGINT);
			VAR val: LONGINT; a: ARRAY 9 OF CHAR; bits: LONGINT;
			BEGIN
				val := GetBits(at,os.unit);
				bits := os.unit;
				a[(bits-1) DIV 4 +1] := 0X;
				WHILE (bits > 0) DO
					a[(bits-1) DIV 4] := Hex(val MOD 16);
					val := LSH(val,-4);
					DEC(bits,4);
				END;
				w.String(a);
			END DumpUnit;

			PROCEDURE DumpBlock(from,to: LONGINT);
			VAR i: LONGINT; nr: LONGINT;
			BEGIN
				i := from; nr := 0;
				IF to >= pc THEN to := pc-1 END;
				WHILE i <= to DO
					w.String("["); w.Hex(i,3); w.String("] ");
					nr := 0;
					WHILE (i<=to) & (nr<16) DO
						IF i = 8 THEN w.String(" ") END;
						DumpUnit(i);
						w.String(" ");
						INC(i); INC(nr);
					END;
					IF i <= to THEN
						w.Ln;
					END;
				END;
			END DumpBlock;

		BEGIN
			IF comments # NIL THEN
				c := comments.firstComment;
				WHILE(c # NIL) & (c.pos <from) DO
					c := c.nextComment;
				END;
				i := from;
				WHILE(i<=to) DO
					WHILE (c # NIL) & (c.pos = i) DO
						c.Dump(w); w.Ln;
						c := c.nextComment;
					END;
					IF (c # NIL) & (c.pos <= to) THEN nextpos := c.pos-1 ELSE nextpos := to END;
					DumpBlock(i,nextpos);w.Ln;
					i := nextpos+1;
				END;
				WHILE (c#NIL) & (c.pos = to+1) DO
					c.Dump(w); w.Ln; c := c.nextComment;
				END;
			ELSE
				DumpBlock(0,SELF.pc-1)
			END
		END DumpCode;

		PROCEDURE Dump*(w: Streams.Writer);
		VAR ww: Basic.Writer;
		BEGIN
			IF comments # NIL THEN comments.Update END;
			ww := Basic.GetWriter(w);
			ww.String(" unit="); ww.Int(os.unit,1);
			IF os.fixed THEN w.String(" fixed") ELSE w.String(" relocatable") END;
			w.String(" align="); w.Int(os.alignment,1);
			ww.String(" size="); ww.Int(SELF.pc,1);
			ww.String(" fixups="); ww.Int(SELF.os.fixups,1);
			ww.Ln;
			ww.IncIndent;
			fixupList.Dump(ww);
			DumpCode(ww,0,SELF.pc-1);
			ww.DecIndent;
		END Dump;

	END Section;

	PROCEDURE ConvertReal* (value: REAL): LONGINT;
	CONST Exponent = 8; Significant = 23;
	VAR result: LONGINT; VAR exponent, i: INTEGER;
	BEGIN
		(*! NaN code missing, we need an extra - machine specific - functionality for that  / cf. Streams.NaNCode *)
	    IF value = 0 THEN RETURN 0 END;
	    result := 0; exponent := 0;
	    IF value < 0 THEN value := -value; result := ASH (1, Exponent) END;
	    WHILE value < 1 DO value := value * 2; DEC (exponent) END;
	    WHILE value >= 2 DO value := value / 2; INC (exponent) END;
	    value := value - 1; INC (result, ASH (1, Exponent - 1) - 1 + exponent);
	    FOR i := 0 TO Significant - 1 DO
	        value := value * 2; INC (result, result);
	        IF value >= 1 THEN value := value - 1; INC (result) END;
	    END;
	    RETURN result;
	END ConvertReal;

	PROCEDURE ConvertLongreal*(value: LONGREAL): HUGEINT;
	CONST Exponent = 11; Significant = 52;
	VAR result: HUGEINT; VAR exponent, i: INTEGER;
	BEGIN
		(*! NaN code missing, we need an extra - machine specific - functionality for that  / cf. Streams.NaNCode *)
	    IF value = 0 THEN RETURN 0 END;
	    result := 0; exponent := 0;
	    IF value < 0 THEN value := -value; result := ASH (1, Exponent) END;
	    WHILE value < 1 DO value := value * 2; DEC (exponent) END;
	    WHILE value >= 2 DO value := value / 2; INC (exponent) END;
	    value := value - 1; INC (result, ASH (1, Exponent - 1) - 1 + exponent);
	    FOR i := 0 TO Significant - 1 DO
	        value := value * 2; INC (result, result);
	        IF value >= 1 THEN value := value - 1; INC (result) END;
	    END;
	    RETURN result;
	END ConvertLongreal;

	PROCEDURE ConvertToReal*(x: LONGINT): REAL;
	VAR result: REAL; e,i: LONGINT;

		PROCEDURE Bit(bit: LONGINT): BOOLEAN;
		BEGIN
			RETURN ODD(ASH(x,-bit))
		END Bit;
	BEGIN
		result := 0; e := 0;
		FOR i := 0 TO 22 DO
			IF Bit(i) THEN result := result + 1 END; result := result / 2;
		END;
		FOR i :=  30 TO 23 BY -1 DO
			e := e*2; IF Bit(i) THEN e := e+1 END;
		END;
		IF e = 0FFH THEN (* NaN or Inf *)
			HALT(200);
			(*! NaN code missing, we need an extra - machine specific - functionality for that  / cf. Streams.NaNCode *)
		ELSIF (result # 0) OR (e#0) THEN
			result := result + 1;
			DEC(e,127);
			WHILE e > 0 DO result := result *2; DEC(e) END;
			WHILE e < 0 DO result := result / 2; INC(e) END;
			IF Bit(31) THEN result := -result END;
		END;
		RETURN result
	END ConvertToReal;

	PROCEDURE ConvertToLongreal*(x: HUGEINT): LONGREAL;
	VAR result: LONGREAL; e,i: LONGINT;

		PROCEDURE Bit(bit: LONGINT): BOOLEAN;
		BEGIN
			RETURN ODD(ASH(x,-bit))
		END Bit;
	BEGIN
		result := 0; e:= 0;
		FOR i := 0 TO 51 DO
			IF Bit(i) THEN result := result + 1 END; result := result / 2;
		END;
		result := result + 1;
		FOR i :=  62 TO 52 BY -1 DO
			e := e*2; IF Bit(i) THEN e := e+1 END;
		END;
		IF e = 7FFH THEN (* NaN or Inf *)
			HALT(200)
			(*! NaN code missing, we need an extra - machine specific - functionality for that  / cf. Streams.NaNCode *)
		ELSIF (result # 0) OR (e#0) THEN
			DEC(e,1023);
			WHILE e > 0 DO result := result *2; DEC(e) END;
			WHILE e < 0 DO result := result / 2; INC(e) END;
			IF Bit(63) THEN result := -result END;
		END;
		RETURN result
	END ConvertToLongreal;

	PROCEDURE NewFixup*(mode: INTEGER; fixupOffset: LONGINT; symbol: ObjectFile.Identifier; symbolOffset,displacement: LONGINT; scale: LONGINT; fixupPattern: ObjectFile.FixupPatterns): Fixup;
	VAR fixup: Fixup;
	BEGIN
		NEW(fixup,mode,fixupOffset,symbol,symbolOffset,displacement,scale,fixupPattern); RETURN fixup
	END NewFixup;

	PROCEDURE NewBinarySection*(type: SHORTINT; priority: LONGINT; unit: LONGINT; CONST name: Basic.SegmentedName; dump: BOOLEAN; bigEndian: BOOLEAN): Section;
	VAR binarySection: Section;
	BEGIN
		NEW(binarySection,type,priority, unit,name,dump,bigEndian); RETURN binarySection
	END NewBinarySection;


END FoxBinaryCode.

FoxBinaryCode.TestFixup
	(*
	PROCEDURE TestFixup*;
	VAR data1,data2: Section; i: LONGINT; fixup: Fixup; fixupFormat: FixupFormat;
		PROCEDURE DumpBits(ch: CHAR);
		VAR v: LONGINT; s: ARRAY 9 OF CHAR; i: LONGINT;
		BEGIN
			v := ORD(ch);
			FOR i := 7 TO 0 BY -1 DO
				IF ODD(v) THEN s[i]:='1' ELSE s[i] := '0' END;
				v := ASH(v,-1);
			END;
			s[8] := 0X;
			D.String(s);
		END DumpBits;

	BEGIN
		NEW(data1,Sections.CodeSection,8,"test",NIL,FALSE,TRUE);
		NEW(data2,Sections.CodeSection,8,"test",NIL,FALSE,TRUE);
		FOR i := 0 TO 100 DO
			data1.PutByte(170);
			data2.PutByte(85);
		END;
		FOR i := 15 TO 20 DO DumpBits(data1.data[i]); END; D.Ln;
		FOR i := 15 TO 20 DO DumpBits(data2.data[i]); END;D.Ln;

		NEW(fixupFormat,3);
		fixupFormat[0].offset := 0;
		fixupFormat[0].bits := 12;
		fixupFormat[1].offset := MIN(SHORTINT);
		fixupFormat[1].bits := 8;
		fixupFormat[2].offset := 20;
		fixupFormat[2].bits := 12;

		NEW(fixup,Absolute,16,NIL,0,0,0,fixupFormat);
		data1.ApplyFixup(fixup,3F7DEEDH);
		data2.ApplyFixup(fixup,3F7DEEDH);
		FOR i := 15 TO 20 DO DumpBits(data1.data[i]); END; D.Ln;
		FOR i := 15 TO 20 DO DumpBits(data2.data[i]); END;D.Ln;		D.Ln;
		D.Update;

		data1.Dump(D.Log); D.Ln;
		data2.Dump(D.Log); D.Ln;
	END TestFixup;
	*)

