MODULE OpenType;	(** AUTHOR "eos, PL"; PURPOSE "Bluebottle port of OpenType"; *)

	(**
		OpenType library (partial implementation; supports only TrueType so far)
	**)

	(*
		24.05.2000 - introduced cvtLen to deal with fonts that have no CVT
	*)

	IMPORT
		OpenTypeInt, OpenTypeScan,
		KernelLog, Strings, Files;


	CONST 
		SharpenContours = TRUE; (* switching off sharpening can result in visually hard to see lines in small chinese fonts *)

	CONST
		(** name ids **)
		Copyright* = 0; Family* = 1; Subfamily* = 2; UniqueID* = 3; FullName* = 4; Version* = 5;
		PSName* = 6; Trademark* = 7; Manufacturer* = 8; Designer* = 9; Description* = 10;
		VendorURL* = 11; DesignerURL* = 12;

		(** LoadGlyph modes **)
		Hinted* = 0; Width* = 1; Outline* = 2; Raster* = 3; Grey* = 4;

		DefaultCacheSize* = 8;									(** maximal number of objects per cache **)

		NumTables = 32;										(* maximal number of tables in font file *)
		CharMapSize = 254;										(* number of unicode characters with equivalent Mac character *)

		CallStackSize = 32;

		X = OpenTypeInt.X; Y = OpenTypeInt.Y;

		Debug = FALSE;


	TYPE
		Fixed* = OpenTypeInt.Fixed;
		F26D6* = OpenTypeInt.F26D6;
		F2D14* = OpenTypeInt.F2D14;
		FUnit* = OpenTypeInt.FUnit;

		CacheObj = POINTER TO CacheObjDesc;
		CacheObjDesc = RECORD
			prev, next: CacheObj;
			stamp: LONGINT;
		END;

		(** object cache **)
		Cache* = RECORD
			entries, max: INTEGER;								(* current and maximal number of entries *)
			sent: CacheObj;										(* sentinel of cached object list *)
		END;

		(* OpenType table directory entry *)
		TableEntry = RECORD
			tag: LONGINT;										(* table identifier *)
			checkSum: LONGINT;								(* checksum over table *)
			offset, length: LONGINT;								(* position and length of table within file *)
		END;

		(** header table **)
		FontHeader* = RECORD
			flags: INTEGER;										(* only using bits 0..4 *)
			unitsPerEm*: INTEGER;								(** in range 16..16384 **)
			xMin*, yMin*, xMax*, yMax*: FUnit;					(** bounding box of all glyphs **)
			lowestRecPPEM*: INTEGER;							(** smallest readable size in pixels **)
			indexToLocFormat: INTEGER;							(* 'loca' index format *)
		END;

		(** horizontal header table **)
		HorHeader* = RECORD
			ascender*, descender*, lineGap*: FUnit;				(** typographic ascent, descent and line gap **)
			advanceWidthMax*, minLeftSideBearing*, minRightSideBearing*, xMaxExtent*: FUnit;	(** calculated over all glyphs **)
			numberOfHMetrics: LONGINT;						(* number of horizontal metrics entries *)
		END;

		(* character map table *)
		CharMapSegment* = RECORD
			start*, end*, delta*, offset*: INTEGER;
		END;
		CharMapSegments* = POINTER TO ARRAY OF CharMapSegment;

		CharMapGlyphs* = POINTER TO ARRAY OF INTEGER;

		CharMap* = RECORD
			segCount*: INTEGER;									(* number of segments *)
			seg*: CharMapSegments;
			glyph*: CharMapGlyphs;
		END;

		(** maximum profile table **)
		MaxProfile* = RECORD
			numGlyphs*: LONGINT;								(** number of glyphs in font **)
			maxPoints, maxContours: INTEGER;
			maxCompositePoints, maxCompositeContours: INTEGER;
			maxZones, maxTwilightPoints: INTEGER;
			maxStorage: INTEGER;
			maxFunctionDefs, maxInstructionDefs: INTEGER;
			maxStackElements, maxSizeOfInstructions: INTEGER;
		END;

		(* horizontal metrics *)
		HorMetric = RECORD
			aw: INTEGER;
			lsb: INTEGER;
		END;
		HorMetrics = POINTER TO ARRAY OF HorMetric;

		(* linear threshold table *)
		LinearThresholds = POINTER TO ARRAY OF CHAR;

		(** OpenType font object **)
		Font* = POINTER TO FontDesc;
		FontDesc* = RECORD (CacheObjDesc)
			name*: ARRAY 64 OF CHAR;							(** font name **)
			file*: Files.File;										(** font file **)
			inst*: Cache;										(** cached instances **)

			table: ARRAY NumTables OF TableEntry;
			numTables: INTEGER;
			head*: FontHeader;
			hhea*: HorHeader;
			cmap*: CharMap;
			maxp*: MaxProfile;
			hmtx: HorMetrics;
			LTSH: LinearThresholds;

			fontProg, cvtProg, glyphProg: OpenTypeInt.Code;

			stack: OpenTypeInt.Stack;
			callStack: OpenTypeInt.CallStack;
			func: OpenTypeInt.Functions;
			instr: OpenTypeInt.Instructions;
			store: OpenTypeInt.Store;
			cvt: OpenTypeInt.CVT;
			cvtLen: LONGINT;
			twilight: OpenTypeInt.Zone;
		END;

		(** transformation matrix **)
		Matrix* = ARRAY 4 OF Fixed;

		(** resolution specific font instance **)
		Instance* = POINTER TO InstanceDesc;
		InstanceDesc* = RECORD (CacheObjDesc)
			font*: Font;											(** font that instance is derived from **)
			ptsize*: F26D6;										(** point size **)
			xdpi*, ydpi*: INTEGER;								(** device resolution in dots per inch **)
			xppm*, yppm*: F26D6;								(** number of pixels per Em square **)
			mat*: Matrix;										(** current transform matrix **)
			xmin*, ymin*, xmax*, ymax*: F26D6;				(** union of all character bounding boxes **)
			useHints*, useGrey*: BOOLEAN;						(** suggestions for glyphs loaded from this instance **)
			rotated, stretched: BOOLEAN;						(* is matrix rotated or scaled? *)
			aw: POINTER TO ARRAY OF CHAR;					(* advance width for each glyph *)
			func: OpenTypeInt.Functions;
			instr: OpenTypeInt.Instructions;
			store: OpenTypeInt.Store;
			cvt: OpenTypeInt.CVT;
			twilight: OpenTypeInt.Zone;
			state: OpenTypeInt.State;
		END;

		(** glyph structure **)
		Glyph* = POINTER TO GlyphDesc;
		GlyphDesc* = RECORD
			font*: Font;											(** font that glyph is compatible with **)
			awx*, awy*: INTEGER;								(** advance vector **)
			hbx*, hby*: INTEGER;								(** horizontal bearing (vector from origin to lower left corner of bounding box) **)
			rw*, rh*: INTEGER;									(** raster width and height **)
			xmin*, ymin*, xmax*, ymax*: F26D6;				(** outline bounding box **)
			lppx, rppx: F26D6;									(* phantom point coordinates *)
			outline, simple, comp: OpenTypeInt.Zone;				(* glyph outline *)
			fixDropouts: BOOLEAN;
			scanType: INTEGER;
			store: OpenTypeInt.Store;
			cvt: OpenTypeInt.CVT;
		END;

		(** glyph outline enumeration **)
		OutlineData0* = RECORD END;
		OutlineData* = RECORD (OutlineData0)
			moveto*: PROCEDURE (x, y: F26D6; VAR data: OutlineData0);
			lineto*: PROCEDURE (x, y: F26D6; VAR data: OutlineData0);
			bezierto*: PROCEDURE (x, y: ARRAY OF F26D6; n: INTEGER; VAR data: OutlineData0);
		END;

		(** glyph raster enumeration **)
		RasterData0* = RECORD (OpenTypeScan.EnumData) END;
		RasterData* = RECORD (RasterData0)
			rect*: PROCEDURE (llx, lly, urx, ury, opacity: INTEGER; VAR data: RasterData0);
		END;

	(**--- Debug ---**)

	DebugLogArray = POINTER TO ARRAY OF Strings.String;
	DebugLog = OBJECT
	VAR log : DebugLogArray;
		logEntries : LONGINT;

		PROCEDURE &New*;
		BEGIN
			NEW(log, 16);
			logEntries := 0;
		END New;

		PROCEDURE Add(logEntry : ARRAY OF CHAR);
		VAR newLog : DebugLogArray; i : LONGINT;
		BEGIN
			INC(logEntries);
			IF logEntries >= LEN(log) THEN
				NEW(newLog, LEN(log)*2); i := 0;
				WHILE i < LEN(log) DO
					newLog[i] := log[i]; INC(i)
				END;
				log := newLog
			END;
			log[logEntries-1] := Strings.NewString(logEntry)
		END Add;

		PROCEDURE AddB(logEntry : ARRAY OF CHAR; logVal :BOOLEAN);
		VAR tString : ARRAY 32 OF CHAR; entry : ARRAY 256 OF CHAR;
		BEGIN
			COPY(logEntry, entry);
			Strings.BoolToStr(logVal, tString);
			Strings.Append(entry, tString);
			Add(entry)
		END AddB;

		PROCEDURE AddI(logEntry : ARRAY OF CHAR; logVal : LONGINT);
		VAR tString : ARRAY 32 OF CHAR; entry : ARRAY 256 OF CHAR;
		BEGIN
			COPY(logEntry, entry);
			Strings.IntToStr(logVal, tString);
			Strings.Append(entry, tString);
			Add(entry)
		END AddI;

		PROCEDURE Flush;
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE i < logEntries DO
				KernelLog.String(log[i]^); KernelLog.Ln; INC(i)
			END;
			logEntries := 0
		END Flush;

	END DebugLog;

	(* ------------------------------------- *)
	VAR
		FontCache*: Cache;										(** cache for font objects **)
		CharToUnicode*: ARRAY 256 OF INTEGER;				(** mapping from Oberon character codes to Unicodes **)
		Identity*: Matrix;										(** matrix normally used for generating instances **)
		CacheStamp: LONGINT;									(* next object stamp *)
		MacChar, UniChar: ARRAY 256 OF INTEGER;				(* corresponding Mac and Unicode characters in ascending Unicode order *)
		Log : DebugLog;

	(**--- Object Caches ---**)

	(** initialize object cache **)
	PROCEDURE InitCache* (VAR cache: Cache);
	BEGIN
		NEW(cache.sent); cache.sent.next := cache.sent; cache.sent.prev := cache.sent;
		cache.sent.stamp := MAX(LONGINT);
		cache.entries := 0; cache.max := DefaultCacheSize
	END InitCache;

	(** set new maximal number of objects that are kept in a cache **)
	PROCEDURE SetCacheSize* (VAR cache: Cache; max: INTEGER);
	BEGIN
		cache.max := max;
		WHILE cache.entries > max DO
			cache.sent.next := cache.sent.next.next;
			DEC(cache.entries)
		END;
		cache.sent.next.prev := cache.sent
	END SetCacheSize;

(*
	PROCEDURE Stamp (obj: CacheObj);
	BEGIN
		obj.next.prev := obj.prev; obj.prev.next := obj.next;
		obj.stamp := CacheStamp; INC(CacheStamp);
		WHILE obj.stamp > obj.next.stamp DO obj.next := obj.next.next END;
		obj.prev := obj.next.prev; obj.prev.next := obj; obj.next.prev := obj
	END Stamp;
*)

	PROCEDURE Append (VAR cache: Cache; obj: CacheObj);
	BEGIN
		obj.stamp := CacheStamp; INC(CacheStamp);
		obj.prev := cache.sent.prev; obj.prev.next := obj;
		obj.next := cache.sent; obj.next.prev := obj;
		IF cache.entries = cache.max THEN
			cache.sent.next := cache.sent.next.next; cache.sent.next.prev := cache.sent
		ELSE
			INC(cache.entries)
		END
	END Append;


	(**--- Fonts ---**)

	(** return location of table within font file (returns whether table was found) **)
	PROCEDURE FindTable* (font: Font; name: ARRAY OF CHAR; VAR offset, length: LONGINT): BOOLEAN;
		VAR tag, lo, hi, m: LONGINT;
	BEGIN
		tag := ASH(ASH(ASH(ORD(name[0]), 8) + ORD(name[1]), 8) + ORD(name[2]), 8) + ORD(name[3]);
		lo := 0; hi := font.numTables;
		WHILE lo+1 < hi DO
			m := (lo + hi) DIV 2;
			IF font.table[m].tag <= tag THEN lo := m
			ELSE hi := m
			END
		END;
		offset := font.table[lo].offset; length := font.table[lo].length;
		RETURN font.table[lo].tag = tag
	END FindTable;

	(** read big endian 2 byte integer **)
	PROCEDURE ReadInt* (VAR r: Files.Rider; VAR i: INTEGER);
		VAR c: ARRAY 2 OF CHAR;
	BEGIN
		r.file.ReadBytes(r, c, 0, 2);
		i := 100H*ORD(c[0]) + ORD(c[1])
	END ReadInt;

	(** read big endian 4 byte integer **)
	PROCEDURE ReadLInt* (VAR r: Files.Rider; VAR l: LONGINT);
		VAR c: ARRAY 4 OF CHAR;
	BEGIN
		r.file.ReadBytes(r, c, 0, 4);
		l := ASH(ORD(c[0]), 24) + ASH(ORD(c[1]), 16) + ASH(ORD(c[2]), 8) + ORD(c[3])
	END ReadLInt;

	(** read big endian 2 byte integer **)
	PROCEDURE Read16U* (VAR r: Files.Rider; VAR i: LONGINT);
		VAR c: ARRAY 2 OF CHAR;
	BEGIN
		r.file.ReadBytes(r, c, 0, 2);
		i := 100H* LONG(ORD(c[0])) + LONG(ORD(c[1]))
	END Read16U;

	PROCEDURE LoadHeader (font: Font): BOOLEAN;
		VAR pos, len, version, magic: LONGINT; r: Files.Rider; gformat: INTEGER;
	BEGIN
		IF ~FindTable(font, "head", pos, len) THEN RETURN FALSE END;
		font.file.Set(r, pos); ReadLInt(r, version);
		IF version # 10000H THEN RETURN FALSE END;
		r.file.Set(r,pos+12); ReadLInt(r, magic);
		IF magic # 5F0F3CF5H THEN RETURN FALSE END;
		ReadInt(r, font.head.flags); ReadInt(r, font.head.unitsPerEm);
		font.file.Set(r, pos+36);
		ReadInt(r, font.head.xMin); ReadInt(r, font.head.yMin);
		ReadInt(r, font.head.xMax); ReadInt(r, font.head.yMax);
		font.file.Set(r, pos+46);
		ReadInt(r, font.head.lowestRecPPEM);
		font.file.Set(r, pos+50);
		ReadInt(r, font.head.indexToLocFormat);
		ReadInt(r, gformat);
		RETURN gformat = 0
	END LoadHeader;

	PROCEDURE LoadHorHeader (font: Font): BOOLEAN;
		VAR pos, len, version: LONGINT; r: Files.Rider; mformat: INTEGER;
	BEGIN
		IF ~FindTable(font, "hhea", pos, len) THEN RETURN FALSE END;
		font.file.Set(r, pos); ReadLInt(r, version);
		IF version # 10000H THEN RETURN FALSE END;
		ReadInt(r, font.hhea.ascender); ReadInt(r, font.hhea.descender); ReadInt(r, font.hhea.lineGap);
		IF Debug THEN KernelLog.String("Ascender: "); KernelLog.Int(font.hhea.ascender, 0); KernelLog.Ln END;
		IF Debug THEN KernelLog.String("Descender: "); KernelLog.Int(font.hhea.descender, 0); KernelLog.Ln END;
		IF Debug THEN KernelLog.String("LineGap: "); KernelLog.Int(font.hhea.lineGap, 0); KernelLog.Ln END;
		ReadInt(r, font.hhea.advanceWidthMax); ReadInt(r, font.hhea.minLeftSideBearing);
		IF Debug THEN KernelLog.String("AdvanceWidthMax: "); KernelLog.Int(font.hhea.advanceWidthMax, 0); KernelLog.Ln END;
		IF Debug THEN KernelLog.String("LeftSideBearing: "); KernelLog.Int(font.hhea.minLeftSideBearing, 0); KernelLog.Ln END;
		ReadInt(r, font.hhea.minRightSideBearing); ReadInt(r, font.hhea.xMaxExtent);
		IF Debug THEN KernelLog.String("RightSideBearing: "); KernelLog.Int(font.hhea.minRightSideBearing, 0); KernelLog.Ln END;
		IF Debug THEN KernelLog.String("xMaxExtent: "); KernelLog.Int(font.hhea.xMaxExtent, 0); KernelLog.Ln END;
		font.file.Set(r, pos+32); ReadInt(r, mformat);
		Read16U(r, font.hhea.numberOfHMetrics);
		IF Debug THEN KernelLog.String("Num of HMetrics: "); KernelLog.Int(font.hhea.numberOfHMetrics, 0); KernelLog.Ln END;
		RETURN mformat = 0
	END LoadHorHeader;

	PROCEDURE LoadCharMap (font: Font): BOOLEAN;
		VAR
			r: Files.Rider; pos, length, offset, s, p: LONGINT;
			version, tables, t, platform, encoding, format, n, len, segCountX2, pad, off: INTEGER;
			found: BOOLEAN; glyph: ARRAY 256 OF CHAR; uni: ARRAY CharMapSize OF INTEGER;
	BEGIN
		IF ~FindTable(font, "cmap", pos, length) THEN
			IF Debug THEN Log.Add("CMAP Table not found"); Log.Flush END;
			RETURN FALSE
		END;
		font.file.Set(r, pos); ReadInt(r, version);
		IF version # 0 THEN
			IF Debug THEN Log.AddI("Version is not 0: ", version); Log.Flush END;
			RETURN FALSE
		END;
		ReadInt(r, tables);
			IF Debug THEN Log.AddI("Number of CMAP tables: ", tables); END;
		found := FALSE;
		t := 0;
		WHILE t < tables DO
			r.file.Set(r, pos + 4 + 8*t);
			ReadInt(r, platform); ReadInt(r, encoding); ReadLInt(r, offset); INC(offset, pos);
			IF (platform = 3) & (encoding = 1) THEN				(* found Microsoft Unicode encoding *)
				IF Debug THEN Log.Add("found platform ID 3 encoding 1") END;
				font.file.Set(r, offset); ReadInt(r, format);
				IF format # 4 THEN
					IF Debug THEN Log.AddI("format for platform 3:1 not supported: ", format) END;
				ELSE
					ReadInt(r, len); ReadInt(r, version); ReadInt(r, segCountX2);
					font.cmap.segCount := segCountX2 DIV 2;
					IF Debug THEN Log.AddI("SegCount: ", font.cmap.segCount) END;
					NEW(font.cmap.seg, font.cmap.segCount);
					font.file.Set(r, offset+14);
					n := 0; WHILE n < font.cmap.segCount DO ReadInt(r, font.cmap.seg[n].end); INC(n) END;
					ReadInt(r, pad);
					n := 0; WHILE n < font.cmap.segCount DO ReadInt(r, font.cmap.seg[n].start); INC(n) END;
					n := 0; WHILE n < font.cmap.segCount DO ReadInt(r, font.cmap.seg[n].delta); INC(n) END;
					n := 0;
					WHILE n < font.cmap.segCount DO
						ReadInt(r, off);
						IF off = 0 THEN font.cmap.seg[n].offset := -1
						ELSE font.cmap.seg[n].offset := off DIV 2 - (font.cmap.segCount - n)
						END;
						INC(n)
					END;
					len := SHORT(offset + len - r.file.Pos(r)) DIV 2;
					IF len > 0 THEN
						NEW(font.cmap.glyph, len);
						n := 0; WHILE n < len DO ReadInt(r, font.cmap.glyph[n]); INC(n) END;
						IF Debug THEN Log.AddI("Glyphs added: ", len) END
					ELSE
						font.cmap.glyph := NIL
					END;
					RETURN TRUE;
				END;

			ELSIF (platform = 1) & (encoding = 0) THEN
				IF Debug THEN Log.Add("found platform ID 1 encoding 0") END;
				font.file.Set(r, offset); ReadInt(r, format);
				IF format # 0 THEN
					IF Debug THEN Log.AddI("format for platform 1:0 not supported: ", format) END;
				ELSE
					ReadInt(r, len); ReadInt(r, version);
					r.file.ReadBytes(r, glyph, 0,256);
					FOR n := 0 TO CharMapSize-1 DO
						uni[n] := ORD(glyph[MacChar[n]])			(* character UniChar[n] now has glyph uni[n] *)
					END;

					p := 0; s := 0;
					FOR n := 0 TO CharMapSize-1 DO
						IF uni[n] # 0 THEN							(* UniChar[n] is defined *)
							IF (n = 0) OR (uni[n-1] = 0) OR (UniChar[n-1] + 1 # UniChar[n]) THEN
								INC(s)
							END;
							INC(p)
						END
					END;
					font.cmap.segCount := SHORT(s);
					NEW(font.cmap.seg, s+1);						(* add one for the sentinel segment *)
					NEW(font.cmap.glyph, p);

					s := 0; p := 0;
					FOR n := 0 TO CharMapSize-1 DO
						IF uni[n] # 0 THEN
							IF (n = 0) OR (uni[n-1] = 0) OR (UniChar[n-1] + 1 # UniChar[n]) THEN
								font.cmap.seg[s].start := UniChar[n];
								font.cmap.seg[s].delta := 0;
								font.cmap.seg[s].offset := SHORT(p)
							END;
							IF (n = CharMapSize-1) OR (UniChar[n+1] = 0) OR (UniChar[n+1] - 1 # UniChar[n]) THEN
								font.cmap.seg[s].end := UniChar[n];
								INC(s)
							END;
							font.cmap.glyph[p] := uni[n];
							INC(p)
						END
					END;

					font.cmap.seg[s].start := -1;	(* = FFFF *)
					font.cmap.seg[s].end := -1;	(* = FFFF *)
					font.cmap.seg[s].delta := 1;
					font.cmap.seg[s].offset := -1;

					found := TRUE
				END
			ELSE
				IF Debug THEN
					Log.AddI("Platform not supported: ", platform);
					Log.AddI("Encoding: ",encoding)
				END;
			END;
			INC(t)
		END;
		RETURN found
	END LoadCharMap;

	PROCEDURE LoadMaxProfile (font: Font): BOOLEAN;
		VAR pos, len, version: LONGINT; r: Files.Rider;
	BEGIN
		IF ~FindTable(font, "maxp", pos, len) THEN RETURN FALSE END;
		font.file.Set(r, pos); ReadLInt(r, version);
		IF version # 10000H THEN RETURN FALSE END;									(* only TrueType supported so far *)
		Read16U(r, font.maxp.numGlyphs);
		IF Debug THEN KernelLog.String("Num of Glyphs: "); KernelLog.Int(font.maxp.numGlyphs, 0); KernelLog.Ln END;
		ReadInt(r, font.maxp.maxPoints); ReadInt(r, font.maxp.maxContours);
		IF Debug THEN KernelLog.String("Num of Points: "); KernelLog.Int(font.maxp.maxPoints, 0); KernelLog.Ln END;
		IF Debug THEN KernelLog.String("Num of Contours: "); KernelLog.Int(font.maxp.maxContours, 0); KernelLog.Ln END;
		ReadInt(r, font.maxp.maxCompositePoints); ReadInt(r, font.maxp.maxCompositeContours);
		IF Debug THEN KernelLog.String("Num of Comp Points: "); KernelLog.Int(font.maxp.maxCompositePoints, 0); KernelLog.Ln END;
		IF Debug THEN KernelLog.String("Num of Comp Countours: "); KernelLog.Int(font.maxp.maxCompositeContours, 0); KernelLog.Ln END;
		ReadInt(r, font.maxp.maxZones); ReadInt(r, font.maxp.maxTwilightPoints);
		IF Debug THEN KernelLog.String("Num of maxZones: "); KernelLog.Int(font.maxp.maxZones, 0); KernelLog.Ln END;
		IF Debug THEN KernelLog.String("Num of maxTwilight: "); KernelLog.Int(font.maxp.maxTwilightPoints, 0); KernelLog.Ln END;
		ReadInt(r, font.maxp.maxStorage); ReadInt(r, font.maxp.maxFunctionDefs);
		IF Debug THEN KernelLog.String("Num of maxStorage: "); KernelLog.Int(font.maxp.maxStorage, 0); KernelLog.Ln END;
		IF Debug THEN KernelLog.String("Num of maxFuncDefs: "); KernelLog.Int(font.maxp.maxFunctionDefs, 0); KernelLog.Ln END;
		IF font.maxp.maxFunctionDefs = 0 THEN font.maxp.maxFunctionDefs := 64 END;	(* seems to be necessary *)
		ReadInt(r, font.maxp.maxInstructionDefs); ReadInt(r, font.maxp.maxStackElements);
		IF Debug THEN KernelLog.String("Num of InstructionDefs: "); KernelLog.Int(font.maxp.maxInstructionDefs, 0); KernelLog.Ln END;
		IF Debug THEN KernelLog.String("Num of maxStackElems: "); KernelLog.Int(font.maxp.maxStackElements, 0); KernelLog.Ln END;
		ReadInt(r, font.maxp.maxSizeOfInstructions);
		IF Debug THEN KernelLog.String("MaxSize of Instruction: "); KernelLog.Int(font.maxp.maxSizeOfInstructions, 0); KernelLog.Ln END;
		RETURN TRUE
	END LoadMaxProfile;

	PROCEDURE LoadHorMetrics (font: Font): BOOLEAN;
		VAR pos, len: LONGINT; r: Files.Rider; aw: INTEGER; n: LONGINT;
	BEGIN
		IF ~FindTable(font, "hmtx", pos, len) THEN RETURN FALSE END;
		NEW(font.hmtx, font.maxp.numGlyphs);
		font.file.Set(r, pos);
		n := 0;
		WHILE n < font.hhea.numberOfHMetrics DO
			ReadInt(r, font.hmtx[n].aw); ReadInt(r, font.hmtx[n].lsb);
			INC(n)
		END;
		aw := font.hmtx[n-1].aw;
		WHILE n < font.maxp.numGlyphs DO
			font.hmtx[n].aw := aw; ReadInt(r, font.hmtx[n].lsb);
			INC(n)
		END;
		RETURN TRUE
	END LoadHorMetrics;

	PROCEDURE LoadCVT (font: Font);
		VAR pos, len, n: LONGINT; r: Files.Rider; val: FUnit;
	BEGIN
		font.cvt := NIL; font.cvtLen := 0;
		IF FindTable(font, "cvt ", pos, len) THEN
			font.cvtLen := len DIV 2;
			OpenTypeInt.NewCVT(font.cvt, font.cvtLen);
			font.file.Set(r, pos);
			FOR n := 0 TO font.cvtLen-1 DO
				ReadInt(r, val); font.cvt[n] := val
			END
		END
	END LoadCVT;

	PROCEDURE LoadLinearThresholds (font: Font);
		VAR pos, len: LONGINT; r: Files.Rider; numGlyphs: LONGINT;
	BEGIN
		font.LTSH := NIL;
		IF FindTable(font, "LTSH", pos, len) THEN
			NEW(font.LTSH, font.maxp.numGlyphs);
			font.file.Set(r, pos+2);
			Read16U(r, numGlyphs);
			IF numGlyphs >= font.maxp.numGlyphs THEN
				r.file.ReadBytes(r, font.LTSH^, 0, font.maxp.numGlyphs)
			ELSE
				r.file.ReadBytes(r, font.LTSH^, 0, numGlyphs);
				WHILE numGlyphs < font.maxp.numGlyphs DO
					font.LTSH[numGlyphs] := 0FFX;
					INC(numGlyphs)
				END
			END
		END
	END LoadLinearThresholds;

	PROCEDURE LoadFont (font: Font): BOOLEAN;
		VAR r: Files.Rider; n: LONGINT; ok: BOOLEAN;
		lh, lhh, lcm, lmp, lhm : BOOLEAN;
	BEGIN
		(* load table directory *)
		font.file.Set(r, 4); ReadInt(r, font.numTables);
		IF font.numTables > NumTables THEN
			font.numTables := NumTables						(* this is somewhat crude, but unlikely to ever happen *)
		END;
		font.file.Set(r, 12); n := 0;
		WHILE n < font.numTables DO
			ReadLInt(r, font.table[n].tag);
			ReadLInt(r, font.table[n].checkSum);
			ReadLInt(r, font.table[n].offset);
			ReadLInt(r, font.table[n].length);
			INC(n)
		END;

		(* load required tables *)
		IF Debug THEN
			Log.Add("-- LoadHeader: "); lh := LoadHeader(font); Log.AddB("status: ", lh);
			Log.Add("-- LoadHorHeader: "); lhh := LoadHorHeader(font); Log.AddB("status: ", lhh);
			Log.Add("-- LoadCharMap: "); lcm := LoadCharMap(font); Log.AddB("status: ", lcm);
			Log.Add("-- LoadMaxProfile: "); lmp := LoadMaxProfile(font); Log.AddB("status: ", lmp);
			Log.Add("-- LoadHorMetrics: "); lhm := LoadHorMetrics(font); Log.AddB("status: ", lhm);
			Log.Flush;
			ok := lh & lhh & lcm & lmp & lhm
		ELSE
		ok :=
			LoadHeader(font) &
			LoadHorHeader(font) &
			LoadCharMap(font) &
			LoadMaxProfile(font) &
			LoadHorMetrics(font);
		END;

		IF ok THEN
			(* load optional structures *)
			IF Debug THEN KernelLog.String("LoadCVT"); KernelLog.Ln END;
			LoadCVT(font);
			IF Debug THEN KernelLog.String("LoadLinearThresholds"); KernelLog.Ln END;
			LoadLinearThresholds(font);

			(* allocate structures *)
			IF Debug THEN KernelLog.String("NewCode: "); KernelLog.Int(font.maxp.maxSizeOfInstructions, 0); KernelLog.Ln END;
			OpenTypeInt.NewCode(font.glyphProg, font.maxp.maxSizeOfInstructions);
			IF Debug THEN KernelLog.String("NewStack: "); KernelLog.Int(font.maxp.maxStackElements, 0); KernelLog.Ln END;
			OpenTypeInt.NewStack(font.stack, font.maxp.maxStackElements);
			IF Debug THEN KernelLog.String("NewCallStack: "); KernelLog.Int(CallStackSize, 0); KernelLog.Ln END;
			OpenTypeInt.NewCallStack(font.callStack, CallStackSize);
			IF Debug THEN KernelLog.String("NewFunctions: "); KernelLog.Int(font.maxp.maxFunctionDefs, 0); KernelLog.Ln END;
			OpenTypeInt.NewFunctions(font.func, font.maxp.maxFunctionDefs);
			IF Debug THEN KernelLog.String("NewInstructions: "); KernelLog.Int(font.maxp.maxInstructionDefs, 0); KernelLog.Ln END;
			OpenTypeInt.NewInstructions(font.instr, font.maxp.maxInstructionDefs);
			IF Debug THEN KernelLog.String("NewStore: "); KernelLog.Int(font.maxp.maxStorage, 0); KernelLog.Ln END;
			OpenTypeInt.NewStore(font.store, font.maxp.maxStorage);
			IF Debug THEN KernelLog.String("NewZone: "); KernelLog.Int(font.maxp.maxTwilightPoints, 0); KernelLog.Ln END;
			OpenTypeInt.NewZone(font.twilight, 1, font.maxp.maxTwilightPoints);
			IF Debug THEN KernelLog.String("-- done"); KernelLog.Ln END;
		END;

		RETURN ok
	END LoadFont;

	PROCEDURE ExecFontProg (font: Font);
		VAR pos, len: LONGINT; r: Files.Rider; context: OpenTypeInt.Context;
	BEGIN
		IF FindTable(font, "fpgm", pos, len) THEN
			IF Debug THEN KernelLog.String("fpgm execution started"); KernelLog.Ln END;
			OpenTypeInt.NewCode(font.fontProg, len);
			font.file.Set(r, pos);
			r.file.ReadBytes(r, font.fontProg^, 0,len);
			OpenTypeInt.SetStacks(context, font.stack, font.callStack);
			OpenTypeInt.SetStructures(context, font.func, font.instr, font.store, font.cvt);
			OpenTypeInt.SetResolution(context, 10*40H, (10*40H+36) DIV 72, (10*40H+36) DIV 72, font.head.unitsPerEm, FALSE, FALSE);
			OpenTypeInt.InitState(context);
			OpenTypeInt.Execute(context, font.fontProg, len, OpenTypeInt.EmptyZone, OpenTypeInt.EmptyZone);
			IF Debug THEN KernelLog.String("fpgm execution ended"); KernelLog.Ln END;
		END
	END ExecFontProg;

	(** open a OpenType font file; file name extension and path may be omitted; returns NIL if not found **)
	PROCEDURE Open* (name: ARRAY OF CHAR): Font;
		VAR fname, temp, ext: Files.FileName; obj: CacheObj; file: Files.File; r: Files.Rider; version: LONGINT; font: Font;
	BEGIN
		NEW(Log);
		COPY(name, fname);
		Strings.GetExtension(name, temp, ext);
		IF ext[0] = 0X THEN
			Strings.Append(fname, ".TTF")
		ELSE
			name[Strings.Length(name) - Strings.Length(ext) - 1] := 0X
		END;

		(* find font in cache *)
		obj := FontCache.sent.next;
		WHILE obj # FontCache.sent DO
			IF obj(Font).name = name THEN
				RETURN obj(Font)
			END;
			obj := obj.next
		END;

		(* try to open font file *)
		file := Files.Old(fname);
		IF (file = NIL) & (ext[0] = 0X) THEN							(* try extension '.OTF' if none was specified *)
			COPY(name, fname); Strings.Append(fname, ".OTF");
			file := Files.Old(fname)
		END;
		IF file # NIL THEN
			file.Set(r, 0); ReadLInt(r, version);
			IF version = 10000H THEN								(* 'OTTO' (including CFF outlines) not supported *)
				NEW(font); COPY(name, font.name); font.file := file;
				IF LoadFont(font) THEN
					Append(FontCache, font);
					InitCache(font.inst);
					ExecFontProg(font);
					RETURN font
				ELSE
					IF Debug THEN Log.Add("## loading error") END
				END
			ELSE
				IF Debug THEN Log.Add("## wrong version") END
			END
		END;
		IF Debug THEN Log.Flush END;
		RETURN NIL													(* failed to load font *)
	END Open;

	(** get entry from name table; whenever possible, a string in English is returned **)
	PROCEDURE GetName* (font: Font; id: INTEGER; VAR name: ARRAY OF CHAR);
		VAR
			pos, len, off: LONGINT;
			r: Files.Rider;
			unicode: BOOLEAN;
			n, offset, platform, encoding, language, nameID, l, o: INTEGER;
			dummy: CHAR;
	BEGIN
		name[0] := 0X;
		IF FindTable(font, "name", pos, len) THEN
			off := -1; len := 0; unicode := FALSE;
			font.file.Set(r, pos+2); ReadInt(r, n); ReadInt(r, offset);
			WHILE n > 0 DO
				ReadInt(r, platform); ReadInt(r, encoding); ReadInt(r, language); ReadInt(r, nameID);
				ReadInt(r, l); ReadInt(r, o);
				IF nameID = id THEN
					off := o; len := l;
					IF (platform = 3) & (encoding = 1) & (language MOD 100H = 9) THEN
						n := 1; unicode := TRUE
					ELSIF (platform = 1) & (encoding = 0) & (language = 0) THEN
						n := 1
					END
				END;
				DEC(n)
			END;
			IF off >= 0 THEN
				font.file.Set(r, pos + offset + off);
				l := 0;
				WHILE len > 0 DO
					IF unicode THEN
						r.file.Read(r, dummy); DEC(len)				(* skip high byte *)
					END;
					r.file.Read(r, name[l]); INC(l); DEC(len)
				END;
				name[l] := 0X
			END
		END
	END GetName;

	(** map Unicode character code to glyph number **)
	PROCEDURE UnicodeToGlyph* (font: Font; code: LONGINT): LONGINT;
		VAR lo, hi, m, start, end, delta, offset, idx: LONGINT;
	BEGIN
		lo := 0; hi := font.cmap.segCount;
		WHILE lo+1 < hi DO
			m := (lo + hi) DIV 2;
			IF LONG(font.cmap.seg[m].start) MOD 10000H <= code THEN lo := m
			ELSE hi := m
			END
		END;
		start := LONG(font.cmap.seg[lo].start) MOD 10000H;
		end := LONG(font.cmap.seg[lo].end) MOD 10000H;
		IF (start <= code) & (code <= end) THEN
			delta := font.cmap.seg[lo].delta; offset := font.cmap.seg[lo].offset;
			IF offset < 0 THEN
				RETURN (code + delta) MOD 10000H
			ELSE
				idx := font.cmap.glyph[code - start + offset];
				IF idx = 0 THEN
					RETURN 0
				ELSE
					RETURN (idx + delta) MOD 10000H
				END
			END
		ELSE
			RETURN 0
		END
	END UnicodeToGlyph;


	(**--- Instances ---**)

	PROCEDURE CalcPPEm (font: Font; ptsize: F26D6; xdpi, ydpi: INTEGER; VAR xppm, yppm: F26D6);
	BEGIN
		xppm := OpenTypeInt.MulDiv(ptsize, xdpi, 72);
		yppm := OpenTypeInt.MulDiv(ptsize, ydpi, 72);
		IF ODD(font.head.flags DIV 8) THEN						(* round ppem to integer *)
			xppm := (xppm + 20H) DIV 40H * 40H;
			yppm := (yppm + 20H) DIV 40H * 40H
		END
	END CalcPPEm;

	(** get an instance for an opened font (an instance has fixed point size and resolution) **)
	PROCEDURE GetInstance* (font: Font; ptsize: F26D6; xdpi, ydpi: INTEGER; mat: Matrix; VAR inst: Instance);
		VAR
			xppm, yppm, ppm, lo, hi, xmin, xmax, ymin, ymax: F26D6; obj: CacheObj; i, pos, len, size: LONGINT;
			context: OpenTypeInt.Context; r: Files.Rider; version, n, maxPPM, flags: INTEGER; ch: CHAR;
	BEGIN
		CalcPPEm(font, ptsize, xdpi, ydpi, xppm, yppm);
		obj := font.inst.sent;
		WHILE obj # font.inst.sent DO
			inst := obj(Instance);
			IF (inst.xppm = xppm) & (inst.yppm = yppm) &
				(~ODD(font.head.flags DIV 4) OR (inst.ptsize = ptsize)) &
				(inst.mat[0] = mat[0]) & (inst.mat[1] = mat[1]) & (inst.mat[2] = mat[2]) & (inst.mat[3] = mat[3])
			THEN
				RETURN
			END;
			obj := obj.next
		END;

		NEW(inst); inst.font := font;
		inst.ptsize := ptsize;
		inst.xdpi := xdpi; inst.ydpi := ydpi;
		inst.xppm := xppm; inst.yppm := yppm;
		IF xppm >= yppm THEN ppm := xppm ELSE ppm := yppm END;
		inst.mat[0] := mat[0]; inst.mat[1] := mat[1];
		inst.mat[2] := mat[2]; inst.mat[3] := mat[3];
		inst.rotated := (mat[1] # 0) OR (mat[2] # 0);
		inst.stretched := (mat[0] # 10000H) OR (mat[3] # 10000H);
		Append(font.inst, inst);

		OpenTypeInt.NewFunctions(inst.func, font.maxp.maxFunctionDefs);
		OpenTypeInt.NewInstructions(inst.instr, font.maxp.maxInstructionDefs);
		OpenTypeInt.NewStore(inst.store, font.maxp.maxStorage);
		OpenTypeInt.NewCVT(inst.cvt, font.cvtLen);
		OpenTypeInt.NewZone(inst.twilight, 1, font.maxp.maxTwilightPoints);

		FOR i := 0 TO font.maxp.maxFunctionDefs-1 DO inst.func[i] := font.func[i] END;
		FOR i := 0 TO font.maxp.maxInstructionDefs-1 DO inst.instr[i] := font.instr[i] END;
		FOR i := 0 TO font.maxp.maxStorage-1 DO inst.store[i] := font.store[i] END;
		FOR i := 0 TO font.cvtLen-1 DO
			inst.cvt[i] := OpenTypeInt.MulDiv(font.cvt[i], ppm, font.head.unitsPerEm)
		END;

		OpenTypeInt.InitState(context);
		IF FindTable(font, "prep", pos, len) THEN					(* load and execute cvt program *)
			IF Debug THEN KernelLog.String("Processing prep table"); KernelLog.Ln END;
			IF font.cvtProg = NIL THEN
				OpenTypeInt.NewCode(font.cvtProg, len);
				font.file.Set(r, pos);
				r.file.ReadBytes(r, font.cvtProg^, 0,len)
			END;
			OpenTypeInt.SetStacks(context, font.stack, font.callStack);
			OpenTypeInt.SetStructures(context, inst.func, inst.instr, inst.store, inst.cvt);
			OpenTypeInt.SetResolution(context, ptsize, xppm, yppm, font.head.unitsPerEm, inst.rotated, inst.stretched);
			OpenTypeInt.Execute(context, font.cvtProg, len, inst.twilight, OpenTypeInt.EmptyZone)
		END;
		OpenTypeInt.SaveState(context, inst.state);

		inst.xmin := OpenTypeInt.MulDiv(font.head.xMin, ppm, font.head.unitsPerEm);
		inst.ymin := OpenTypeInt.MulDiv(font.head.yMin, ppm, font.head.unitsPerEm);
		inst.xmax := OpenTypeInt.MulDiv(font.head.xMax, ppm, font.head.unitsPerEm);
		inst.ymax := OpenTypeInt.MulDiv(font.head.yMax, ppm, font.head.unitsPerEm);
		IF inst.rotated OR inst.stretched THEN
			lo := OpenTypeInt.MulShift(inst.xmin, mat[0], -16); hi := OpenTypeInt.MulShift(inst.xmax, mat[0], -16);
			IF lo <= hi THEN xmin := lo; xmax := hi ELSE xmin := hi; xmax := lo END;
			lo := OpenTypeInt.MulShift(inst.ymin, mat[2], -16); hi := OpenTypeInt.MulShift(inst.ymax, mat[2], -16);
			IF lo <= hi THEN xmin := xmin + lo; xmax := xmax + hi ELSE xmin := xmin + hi; xmax := xmax + lo END;
			lo := OpenTypeInt.MulShift(inst.xmin, mat[1], -16); hi := OpenTypeInt.MulShift(inst.xmax, mat[1], -16);
			IF lo <= hi THEN ymin := lo; ymax := hi ELSE ymin := hi; ymax := lo END;
			lo := OpenTypeInt.MulShift(inst.ymin, mat[3], -16); hi := OpenTypeInt.MulShift(inst.ymax, mat[3], -16);
			IF lo <= hi THEN ymin := ymin + lo; ymax := ymax + hi ELSE ymin := ymin + hi; ymax := ymax + lo END;
			inst.xmin := xmin; inst.ymin := ymin; inst.xmax := xmax; inst.ymax := ymax
		END;

		inst.useHints := TRUE; inst.useGrey := FALSE;
		IF FindTable(font, "gasp", pos, len) THEN					(* get suggestion for hinting and grayscale usage *)
			IF Debug THEN KernelLog.String("Processing gasp table"); KernelLog.Ln END;
			font.file.Set(r, pos);
			ReadInt(r, version);
			IF version = 0 THEN
				ReadInt(r, n);
				REPEAT
					ReadInt(r, maxPPM); ReadInt(r, flags)
				UNTIL (yppm <= 40H*maxPPM) OR r.eof;
				inst.useHints := ODD(flags);
				inst.useGrey := ODD(flags DIV 2)
			END
		END;

		inst.aw := NIL;
		IF FindTable(font, "hdmx", pos, len) THEN					(* get horizontal device metrics *)
			IF Debug THEN KernelLog.String("Processing hdmx table"); KernelLog.Ln END;
			font.file.Set(r, pos+2);
			ReadInt(r, n); ReadLInt(r, size);
			REPEAT
				r.file.Read(r, ch);
				IF ORD(ch) = yppm DIV 40H THEN
					r.file.Read(r, ch);
					NEW(inst.aw, font.maxp.numGlyphs);
					r.file.ReadBytes(r, inst.aw^, 0, font.maxp.numGlyphs);
					n := 0
				ELSE
					font.file.Set(r, font.file.Pos(r) - 1 + size);
					DEC(n)
				END
			UNTIL n = 0
		END;
		IF Debug THEN KernelLog.String("## finished"); KernelLog.Ln END
	END GetInstance;


	(**--- Glyphs ---**)

	(** initialize glyph structure to be compatible with given font **)
	PROCEDURE InitGlyph* (glyph: Glyph; font: Font);
	BEGIN
		glyph.font := font;
		IF Debug THEN KernelLog.String("max Contours: "); KernelLog.Int(font.maxp.maxContours, 0); KernelLog.String(" NewZone Simple: "); KernelLog.Int(font.maxp.maxPoints+2, 0); KernelLog.Ln END;
		OpenTypeInt.NewZone(glyph.simple, font.maxp.maxContours, font.maxp.maxPoints+2);
		IF Debug THEN KernelLog.String("max CompContours: ");KernelLog.Int(font.maxp.maxCompositeContours, 0); KernelLog.String(" NewZone Comp: "); KernelLog.Int(font.maxp.maxCompositePoints+2, 0); KernelLog.Ln END;
		OpenTypeInt.NewZone(glyph.comp, font.maxp.maxCompositeContours, font.maxp.maxCompositePoints+2);
		IF Debug THEN KernelLog.String("NewStore: "); KernelLog.Int(font.maxp.maxStorage, 0); KernelLog.Ln END;
		OpenTypeInt.NewStore(glyph.store, font.maxp.maxStorage);
		IF Debug THEN KernelLog.String("NewCVT: "); KernelLog.Int(font.cvtLen, 0); KernelLog.Ln END;
		OpenTypeInt.NewCVT(glyph.cvt, font.cvtLen)
	END InitGlyph;

	PROCEDURE LoadSimpleOutline (VAR r: Files.Rider; glyph: Glyph; inst: Instance; num: LONGINT; contours: INTEGER; hinted, rotated, stretched: BOOLEAN);
		VAR
			font: Font; zone: OpenTypeInt.Zone; pt: OpenTypeInt.Points; points, instrLen, xmin, ymin, xmax, ymax, i, j, val: INTEGER;
			flag: SHORTINT; byte: CHAR; x, y, aw, lsb: FUnit; dx: F26D6; context: OpenTypeInt.Context;
	BEGIN
		font := glyph.font; zone := glyph.simple; pt := zone.pt;
		zone.contours := 0; points := 0; instrLen := 0;
		IF contours > 0 THEN
			ReadInt(r, xmin); ReadInt(r, ymin);
			ReadInt(r, xmax); ReadInt(r, ymax);

			(* load contour end points *)
			zone.contours := contours; zone.first[0] := 0;
			FOR i := 1 TO contours DO
				ReadInt(r, j); zone.first[i] := j+1
			END;
			points := zone.first[contours];

			(* load glyph instructions *)
			ReadInt(r, instrLen);
			IF instrLen > 0 THEN
				IF hinted THEN
					IF instrLen > LEN(font.glyphProg^) THEN
						IF Debug THEN KernelLog.String("Wrong Instruction Prog Size: "); KernelLog.Int(instrLen, 0); KernelLog.String(" Array size: "); KernelLog.Int(LEN(font.glyphProg^), 0); KernelLog.Ln END;
						hinted := FALSE;
						font.file.Set(r,  r.file.Pos(r) + instrLen)
					ELSE
						r.file.ReadBytes(r, font.glyphProg^, 0, instrLen)
					END
				ELSE font.file.Set(r,  r.file.Pos(r) + instrLen)
				END
			END;

			(* load flags (small hack: store flags in pt[i].cur[0]) *)
			i := 0;
			WHILE i < points DO
				Files.ReadSInt(r, flag); pt[i].cur[0] := flag;
				IF ODD(flag DIV 8) THEN	(* repeat flag set *)
					r.file.Read(r, byte); j := ORD(byte);
					WHILE j > 0 DO
						INC(i); pt[i].cur[0] := flag; DEC(j)
					END
				END;
				INC(i)
			END;

			(* load x-coordinates *)
			x := 0;
			FOR i := 0 TO points-1 DO
				flag := SHORT(SHORT(pt[i].cur[0]));
				IF ODD(flag DIV 2) THEN							(* x is short *)
					r.file.Read(r, byte);
					IF ODD(flag DIV 10H) THEN INC(x, ORD(byte))	(* short x-value is positive *)
					ELSE DEC(x, ORD(byte))							(* short x-value is negative *)
					END
				ELSIF ~ODD(flag DIV 10H) THEN						(* x has previous value *)
					ReadInt(r, val); INC(x, val)
				END;
				pt[i].org[X] := OpenTypeInt.MulDiv(x, inst.xppm, font.head.unitsPerEm)
			END;

			(* load y-coordinates *)
			y := 0;
			FOR i := 0 TO points-1 DO
				flag := SHORT(SHORT(pt[i].cur[0]));
				IF ODD(flag DIV 4) THEN							(* y is short *)
					r.file.Read(r, byte);
					IF ODD(flag DIV 20H) THEN INC(y, ORD(byte))	(* short y-value is positive *)
					ELSE DEC(y, ORD(byte))							(* short y-value is negative *)
					END
				ELSIF ~ODD(flag DIV 20H) THEN						(* y has previous value *)
					ReadInt(r, val); INC(y, val)
				END;
				pt[i].org[Y] := OpenTypeInt.MulDiv(y, inst.yppm, font.head.unitsPerEm)
			END;

			FOR i := 0 TO points-1 DO
				pt[i].onCurve := ODD(pt[i].cur[0])
			END
		END;

		(* add phantom points *)
		aw := font.hmtx[num].aw; lsb := font.hmtx[num].lsb;
		IF ODD(font.head.flags DIV 2) THEN
			pt[points].org[X] := 0;
			pt[points+1].org[X] := OpenTypeInt.MulDiv(aw, inst.xppm, font.head.unitsPerEm)
		ELSE
			pt[points].org[X] := OpenTypeInt.MulDiv(xmin - lsb, inst.xppm, font.head.unitsPerEm);
			pt[points+1].org[X] := pt[points].org[X] + OpenTypeInt.MulDiv(aw, inst.xppm, font.head.unitsPerEm)
		END;
		pt[points].org[Y] := 0; pt[points].onCurve := FALSE;
		pt[points+1].org[Y] := 0; pt[points+1].onCurve := FALSE;

		IF hinted THEN												(* round phantom points to grid and shift whole outline *)
			dx := 20H - (pt[points].org[X] + 20H) MOD 40H;
			IF dx # 0 THEN
				FOR i := 0 TO points+1 DO
					INC(pt[i].org[X], dx)
				END
			END;
			pt[points+1].org[X] := (pt[points+1].org[X] + 20H) DIV 40H * 40H
		END;

		FOR i := 0 TO points+1 DO
			pt[i].cur := pt[i].org;
			pt[i].touched[0] := FALSE; pt[i].touched[1] := FALSE
		END;

		IF hinted & (instrLen > 0) THEN								(* execute instructions *)
			OpenTypeInt.RestoreState(context, inst.state);
			IF context.ignorePrep THEN								(* use default state and cvt *)
				OpenTypeInt.InitState(context)
			END;
			FOR i := 0 TO font.maxp.maxStorage-1 DO glyph.store[i] := inst.store[i] END;
			FOR i := 0 TO SHORT(font.cvtLen-1) DO glyph.cvt[i] := inst.cvt[i] END;
			FOR i := 0 TO font.maxp.maxTwilightPoints-1 DO font.twilight.pt[i] := inst.twilight.pt[i] END;
			OpenTypeInt.SetStacks(context, font.stack, font.callStack);
			OpenTypeInt.SetStructures(context, inst.func, inst.instr, glyph.store, glyph.cvt);
			OpenTypeInt.SetResolution(context, inst.ptsize, inst.xppm, inst.yppm, font.head.unitsPerEm, rotated, stretched);
			OpenTypeInt.Execute(context, font.glyphProg, instrLen, font.twilight, zone);
			glyph.fixDropouts := context.fixDropouts;
			glyph.scanType := context.scanType
		END;

		glyph.lppx := pt[points].cur[X]; glyph.rppx := pt[points+1].cur[X]
	END LoadSimpleOutline;

	PROCEDURE LoadOutline (glyph: Glyph; inst: Instance; num: LONGINT; hinted, rotated, stretched: BOOLEAN);
		VAR
			font: Font; pos, len, beg, end, idx: LONGINT; r: Files.Rider;
			int, contours, flags, arg1, arg2, firstc, firstp, i, lastc, lastp, instrLen, points: INTEGER; comp: OpenTypeInt.Zone;
			aw, lsb, xmin, ymin, xmax, ymax: FUnit; lppx, rppx, dx, dy: F26D6; m00, m01, m10, m11: F2D14;
			scaled, rot: BOOLEAN; context: OpenTypeInt.Context;
	BEGIN
		font := glyph.font;
		IF FindTable(font, "loca", pos, len) THEN
			IF font.head.indexToLocFormat = 0 THEN					(* short offsets *)
				font.file.Set(r, pos + 2*num);
				ReadInt(r, int); beg := 2*(LONG(int) MOD 10000H);
				ReadInt(r, int); end := 2*(LONG(int) MOD 10000H)
			ELSE													(* long offsets *)
				font.file.Set(r, pos + 4*num);
				ReadLInt(r, beg);
				ReadLInt(r, end);
			END;
			glyph.lppx := 0;
			IF beg >= end THEN										(* character without contour *)
				LoadSimpleOutline(r, glyph, inst, num, 0, hinted, rotated, stretched)
			ELSIF FindTable(font, "glyf", pos, len) THEN
				font.file.Set(r, pos + beg);
				ReadInt(r, contours);
				IF Debug THEN KernelLog.String(" Contours read: "); KernelLog.Int(contours, 0); KernelLog.Ln END;
				IF contours > 0 THEN									(* simple glyph *)
					LoadSimpleOutline(r, glyph, inst, num, contours, hinted, rotated, stretched)

				ELSE												(* composite glyph *)
					IF Debug THEN KernelLog.String("--------------- Composite Glyph ----------------"); KernelLog.Ln END;
					comp := glyph.comp; glyph.outline := comp;
					aw := font.hmtx[num].aw; lsb := font.hmtx[num].lsb;
					ReadInt(r, xmin); ReadInt(r, ymin);
					ReadInt(r, xmax); ReadInt(r, ymax);
					lppx := OpenTypeInt.MulDiv(xmin - lsb, inst.xppm, font.head.unitsPerEm);
					rppx := lppx + OpenTypeInt.MulDiv(aw, inst.xppm, font.head.unitsPerEm);

					REPEAT
						ReadInt(r, flags); Read16U(r, idx);
						IF ODD(flags) THEN							(* args are words *)
							ReadInt(r, arg1); ReadInt(r, arg2)
						ELSE
							ReadInt(r, arg1); arg2 := arg1 MOD 100H; arg1 := arg1 DIV 100H MOD 100H
						END;

						(* load transformation (if any) *)
						IF ODD(flags DIV 8) THEN					(* we_have_a_scale *)
							ReadInt(r, m00); m01 := 0;
							m10 := 0; m11 := m00;
							scaled := TRUE; rot := FALSE
						ELSIF ODD(flags DIV 40H) THEN				(* we_have_an_x_and_y_scale *)
							ReadInt(r, m00); m01 := 0;
							m10 := 0; ReadInt(r, m11);
							scaled := TRUE; rot := FALSE
						ELSIF ODD(flags DIV 80H) THEN				(* we_have_a_two_by_two *)
							ReadInt(r, m00); ReadInt(r, m01);
							ReadInt(r, m10); ReadInt(r, m11);
							scaled := TRUE; rot := TRUE
						ELSE
							m00 := 4000H; m01 := 0; m10 := 0; m11 := 4000H;
							scaled := FALSE; rot := FALSE
						END;

						(* recursively load component *)
						firstc := comp.contours; firstp := comp.first[firstc];
						LoadOutline(glyph, inst, idx, hinted, rotated OR rot, stretched OR scaled);
						IF comp.contours = firstc THEN				(* loaded simple outline => copy to composite zone *)
							FOR i := 0 TO glyph.simple.first[glyph.simple.contours] DO
								comp.pt[firstp + i] := glyph.simple.pt[i]
							END;
							FOR i := 1 TO glyph.simple.contours DO
								comp.first[firstc + i] := firstp + glyph.simple.first[i]
							END;
							INC(comp.contours, glyph.simple.contours)
						END;
						lastc := comp.contours-1; lastp := comp.first[comp.contours]-1;

						IF scaled THEN								(* apply transformation *)
							FOR i := firstp TO lastp DO
								dx := comp.pt[i].cur[X]; dy := comp.pt[i].cur[Y];
								comp.pt[i].cur[X] := OpenTypeInt.MulShift(dx, m00, -14) + OpenTypeInt.MulShift(dy, m10, -14);
								comp.pt[i].cur[Y] := OpenTypeInt.MulShift(dx, m01, -14) + OpenTypeInt.MulShift(dy, m11, -14)
							END;
							glyph.lppx := OpenTypeInt.MulShift(glyph.lppx, m00, -14);
							glyph.rppx := OpenTypeInt.MulShift(glyph.rppx, m00, -14)
						END;

						IF ODD(flags DIV 200H) THEN	(* use_my_metrics *)
							lppx := glyph.lppx; rppx := glyph.rppx	(* won't work very well with rotated subglyphs *)
						END;

						(* compute translation vector and shift new glyph *)
						IF ODD(flags DIV 2) THEN					(* args_arg_xy_values *)
							dx := OpenTypeInt.MulDiv(arg1, inst.xppm, font.head.unitsPerEm);
							dy := OpenTypeInt.MulDiv(arg2, inst.yppm, font.head.unitsPerEm);
							IF ODD(flags DIV 4) THEN				(* round_xy_to_grid *)
								dx := (dx + 20H) DIV 40H * 40H;
								dy := (dy + 20H) DIV 40H * 40H
							END
						ELSE
							dx := comp.pt[arg2].cur[X] - comp.pt[arg1].cur[X];
							dy := comp.pt[arg2].cur[Y] - comp.pt[arg2].cur[Y]
						END;
						IF (dx # 0) OR (dy # 0) THEN
							FOR i := firstp TO lastp DO
								INC(comp.pt[i].cur[X], dx);
								INC(comp.pt[i].cur[Y], dy)
							END
						END
					UNTIL ~ODD(flags DIV 20H);

					(* load instructions *)
					IF ODD(flags DIV 100H) THEN					(* we_have_instr *)
						ReadInt(r, instrLen);
						IF hinted THEN r.file.ReadBytes(r, font.glyphProg^, 0, instrLen)
						ELSE font.file.Set(r, r.file.Pos(r) + instrLen)
						END
					ELSE
						instrLen := 0
					END;

					(* add phantom points *)
					points := comp.first[comp.contours];
					IF hinted THEN comp.pt[points].cur[X] := (lppx + 20H) DIV 40H * 40H
					ELSE comp.pt[points].cur[X] := lppx
					END;
					comp.pt[points].cur[Y] := 0; comp.pt[points].onCurve := FALSE;
					INC(points);
					IF hinted THEN comp.pt[points].cur[X] := (rppx + 20H) DIV 40H * 40H
					ELSE comp.pt[points].cur[X] := rppx
					END;
					comp.pt[points].cur[Y] := 0; comp.pt[points].onCurve := FALSE;
					INC(points);

					FOR i := 0 TO points-1 DO
						comp.pt[i].org := comp.pt[i].cur; comp.pt[i].touched[X] := FALSE; comp.pt[i].touched[Y] := FALSE
					END;

					IF hinted & (instrLen > 0) THEN					(* execute instructions *)
						OpenTypeInt.RestoreState(context, inst.state);
						IF context.ignorePrep THEN					(* use default state and cvt *)
							OpenTypeInt.InitState(context)
						END;
						FOR i := 0 TO font.maxp.maxStorage-1 DO glyph.store[i] := inst.store[i] END;
						FOR i := 0 TO SHORT(font.cvtLen-1) DO glyph.cvt[i] := inst.cvt[i] END;
						FOR i := 0 TO font.maxp.maxTwilightPoints-1 DO font.twilight.pt[i] := inst.twilight.pt[i] END;
						OpenTypeInt.SetStacks(context, font.stack, font.callStack);
						OpenTypeInt.SetStructures(context, inst.func, inst.instr, glyph.store, glyph.cvt);
						OpenTypeInt.SetResolution(context, inst.ptsize, inst.xppm, inst.yppm, font.head.unitsPerEm, rotated, stretched);
						OpenTypeInt.Execute(context, font.glyphProg, instrLen, font.twilight, comp);
						glyph.fixDropouts := TRUE OR context.fixDropouts;
						glyph.scanType := context.scanType
					END;

					glyph.lppx := comp.pt[points-2].cur[X];
					glyph.rppx := comp.pt[points-1].cur[X]
				END
			END;

			(* translate glyph so that left phantom point is at origin *)
			IF glyph.lppx # 0 THEN
				FOR i := 0 TO glyph.outline.first[glyph.outline.contours]+1 DO
					DEC(glyph.outline.pt[i].cur[X], glyph.lppx)
				END;
				DEC(glyph.rppx, glyph.lppx); glyph.lppx := 0
			END
		END
	END LoadOutline;

	(** load glyph structure with appropriately scaled outline **)
	PROCEDURE LoadGlyph* (inst: Instance; glyph: Glyph; VAR ras: OpenTypeScan.Rasterizer; num: LONGINT; mode: SET);
		VAR
			font: Font; aw, xmin, ymin, xmax, ymax: F26D6; n: INTEGER;
			cur: OpenTypeInt.Coord; rules: SET;
	BEGIN
		ASSERT(inst.font = glyph.font, 100);
		ASSERT((0 <= num) & (num < glyph.font.maxp.numGlyphs), 101);
		font := glyph.font;

		(* try to get metrics if neither outline nor raster is requested *)
		IF mode * {Hinted, Width} = mode THEN
			IF (Hinted IN mode) & (inst.aw # NIL) THEN
				aw := 40H*ORD(inst.aw[num])
			ELSE
				aw := OpenTypeInt.MulDiv(font.hmtx[num].aw, inst.xppm, LONG(font.head.unitsPerEm))
			END;
			IF inst.rotated OR inst.stretched THEN
				glyph.awx := SHORT(OpenTypeInt.MulShift(aw, inst.mat[0], -22));
				glyph.awy := SHORT(OpenTypeInt.MulShift(aw, inst.mat[1], -22))
			ELSE
				glyph.awx := SHORT((aw + 20H) DIV 40H); glyph.awy := 0
			END;
			IF (mode = {Width}) OR								(* unhinted width requested *)
				~ODD(font.head.flags DIV 10H) OR				(* width scales linearly *)
				(font.LTSH # NIL) & (40H*ORD(font.LTSH[num]) <= inst.yppm) OR	(* in linear range *)
				(inst.aw # NIL)									(* hinted width available *)
			THEN
				RETURN
			END
		END;

		(* load glyph outline *)
		glyph.comp.contours := 0; glyph.comp.first[0] := 0; glyph.outline := glyph.simple;
		LoadOutline(glyph, inst, num, Hinted IN mode, inst.rotated, inst.stretched);

		(* transform outline if necessary *)
		IF (mode * {Outline, Raster} # {}) & (inst.rotated OR inst.stretched) THEN
			FOR n := 0 TO glyph.outline.first[glyph.outline.contours]-1 DO
				cur := glyph.outline.pt[n].cur;
				glyph.outline.pt[n].cur[X] := OpenTypeInt.MulShift(cur[X], inst.mat[0], -16) + OpenTypeInt.MulShift(cur[Y], inst.mat[2], -16);
				glyph.outline.pt[n].cur[Y] := OpenTypeInt.MulShift(cur[X], inst.mat[1], -16) + OpenTypeInt.MulShift(cur[Y], inst.mat[3], -16)
			END
		END;

		(* compute bounding box *)
		IF mode * {Width, Raster} # {} THEN
			xmin := MAX(F26D6); ymin := MAX(F26D6); xmax := MIN(F26D6); ymax := MIN(F26D6);
			FOR n := 0 TO glyph.outline.first[glyph.outline.contours]-1 DO
				cur := glyph.outline.pt[n].cur;
				IF cur[X] < xmin THEN xmin := cur[X] END;
				IF cur[X] > xmax THEN xmax := cur[X] END;
				IF cur[Y] < ymin THEN ymin := cur[Y] END;
				IF cur[Y] > ymax THEN ymax := cur[Y] END
			END;
			IF Hinted IN mode THEN								(* round to grid *)
				DEC(xmin, xmin MOD 40H); DEC(ymin, ymin MOD 40H);
				INC(xmax, (-xmax) MOD 40H); INC(ymax, (-ymax) MOD 40H)
			END;
			glyph.xmin := xmin; glyph.ymin := ymin;
			glyph.xmax := xmax; glyph.ymax := ymax
		END;

		IF Width IN mode THEN
			IF (Hinted IN mode) & (inst.aw # NIL) THEN
				aw := 40H*ORD(inst.aw[num])
			ELSE
				aw := glyph.rppx								(* glyph.lppx = 0 *)
			END;
			IF inst.rotated OR inst.stretched THEN
				glyph.awx := SHORT(OpenTypeInt.MulShift(aw, inst.mat[0], -22));
				glyph.awy := SHORT(OpenTypeInt.MulShift(aw, inst.mat[1], -22))
			ELSE
				glyph.awx := SHORT((aw + 20H) DIV 40H); glyph.awy := 0
			END
		END;

		IF Raster IN mode THEN
			rules := {};
			IF ~(Grey IN mode) THEN
				INCL(rules, OpenTypeScan.Round)
			END;
			IF glyph.fixDropouts THEN
				IF glyph.scanType IN {0, 1, 4, 5} THEN INCL(rules, OpenTypeScan.Dropouts) END;
				IF glyph.scanType IN {1, 5} THEN INCL(rules, OpenTypeScan.Stubs) END;
				IF glyph.scanType IN {4, 5} THEN INCL(rules, OpenTypeScan.Smart) END
			END;
			INCL(rules, OpenTypeScan.Dropouts);
			OpenTypeScan.Convert(glyph.outline, rules, ras);
			glyph.hbx := SHORT(ras.xmin DIV 40H);
			glyph.hby := SHORT(ras.ymin DIV 40H);
			glyph.rw := ras.width; glyph.rh := ras.height
		END
	END LoadGlyph;

	(** enumerate glyph outline **)
	PROCEDURE EnumOutline* (glyph: Glyph; VAR data: OutlineData);
		VAR pt: OpenTypeInt.Points; cont, beg, points, i, j, k, l: INTEGER; x, y: F26D6; xx, yy: ARRAY 2 OF F26D6;
	BEGIN
		pt := glyph.outline.pt;
		cont := 0;
		WHILE cont < glyph.outline.contours DO
			beg := glyph.outline.first[cont]; points := glyph.outline.first[cont+1] - beg;
			i := 0; WHILE (i < points) & ~pt[beg + i].onCurve DO INC(i) END;
			IF i < points THEN
				j := i; k := beg + j;
				x := pt[k].cur[X]; y := pt[k].cur[Y];
				data.moveto(x, y, data);
				REPEAT
					j := (j+1) MOD points; k := beg + j;
					IF pt[k].onCurve THEN
						x := pt[k].cur[X]; y := pt[k].cur[Y];
						data.lineto(x, y, data)
					ELSE
						xx[0] := pt[k].cur[X]; yy[0] := pt[k].cur[Y];
						l := beg + (j+1) MOD points;
						IF pt[l].onCurve THEN
							k := l; j := k - beg;
							xx[1] := pt[k].cur[X]; yy[1] := pt[k].cur[Y]
						ELSE
							xx[1] := (xx[0] + pt[l].cur[X]) DIV 2; yy[1] := (yy[0] + pt[l].cur[Y]) DIV 2
						END;
						data.bezierto(xx, yy, 2, data);
						x := xx[1]; y := yy[1]
					END
				UNTIL j = i
			END;
			INC(cont)
		END
	END EnumOutline;


	PROCEDURE SharpenC(VAR x0,x1,a0,a1: INTEGER);
	BEGIN
		IF x0=x1 THEN 
			a0 := 0; a1 := 0; INC(x1)
		ELSIF ((x1-x0) = 1) & (a0 # 0) THEN
			
			IF 40H-a0 > a1 THEN 
				a0 := 0; 
				(*a1 := 0;*)
				(*DEC(a0,a1); a1 := 0;*)
			ELSE 
				(*a0 := 0; *) a1 := 0; (* INC(x0); *) INC(x1);
				(*INC(a1, 40H-a0); a0 := 3FH;*)
			END;
		END;
	END SharpenC;
	
	PROCEDURE EnumRow (row: INTEGER; beg, end: F26D6; VAR data: OpenTypeScan.EnumData);
	VAR x0, a0, x1, a1: INTEGER;
	BEGIN
		WITH data: RasterData DO
			x0 := SHORT(beg DIV 40H); a0 := SHORT(beg MOD 40H);
			x1 := SHORT(end DIV 40H); a1 := SHORT(end MOD 40H);
			
			IF SharpenContours THEN SharpenC(x0,x1,a0,a1) END;
			
			IF x0 < x1 THEN
				IF a0 # 0 THEN
					data.rect(x0, row, x0+1, row+1, 4*(40H-a0), data);
					INC(x0)
				END;
				IF x0 < x1 THEN
					data.rect(x0, row, x1, row+1, 255, data)
				END;
				IF a1 # 0 THEN
					data.rect(x1, row, x1+1, row+1, 4*a1, data)
				END
			ELSIF a0 < a1 THEN
				data.rect(x0, row, x0+1, row+1, 4*(a1 - a0), data)
			END
		END
	END EnumRow;

	PROCEDURE EnumCol (col: INTEGER; beg, end: F26D6; VAR data: OpenTypeScan.EnumData);
		VAR y0, a0, y1, a1: INTEGER;
	BEGIN
		WITH data: RasterData DO
			y0 := SHORT(beg DIV 40H); a0 := SHORT(beg MOD 40H);
			y1 := SHORT(end DIV 40H); a1 := SHORT(end MOD 40H);

			IF SharpenContours THEN SharpenC(y0,y1,a0,a1) END;

			IF y0 < y1 THEN
				IF a0 # 0 THEN
					data.rect(col, y0, col+1, y0+1, 4*(40H-a0), data);
					INC(y0)
				END;
				IF y0 < y1 THEN
					data.rect(col, y0, col+1, y1, 255, data)
				END;
				IF a1 # 0 THEN
					data.rect(col, y1, col+1, y1+1, 4*a1, data)
				END
			ELSIF a0 < a1 THEN
				data.rect(col, y0, col+1, y0+1, 4*(a1 - a0) , data)
			END
		END
	END EnumCol;

	(** enumerate non-transparent pixels of glyph raster image **)
	PROCEDURE EnumRaster* (VAR ras: OpenTypeScan.Rasterizer; VAR data: RasterData);
	BEGIN
		OpenTypeScan.EnumerateRows(ras, EnumRow, data);
		OpenTypeScan.EnumerateColumns(ras, EnumCol, data)
	END EnumRaster;


	(*--- Initialization ---*)

	PROCEDURE InitCharMaps;
		VAR i: INTEGER; l: LONGINT;
	BEGIN
		FOR i := 0 TO 126 DO
			UniChar[i] := i; MacChar[i] := i
		END;
		UniChar[127] := 0A0H; MacChar[127] := 0CAH;
		UniChar[128] := 0A1H; MacChar[128] := 0C1H;
		UniChar[129] := 0A2H; MacChar[129] := 0A2H;
		UniChar[130] := 0A3H; MacChar[130] := 0A3H;
		UniChar[131] := 0A4H; MacChar[131] := 0DBH;
		UniChar[132] := 0A5H; MacChar[132] := 0B4H;
		UniChar[133] := 0A7H; MacChar[133] := 0A4H;
		UniChar[134] := 0A8H; MacChar[134] := 0ACH;
		UniChar[135] := 0A9H; MacChar[135] := 0A9H;
		UniChar[136] := 0AAH; MacChar[136] := 0BBH;
		UniChar[137] := 0ABH; MacChar[137] := 0C7H;
		UniChar[138] := 0ACH; MacChar[138] := 0C2H;
		UniChar[139] := 0AEH; MacChar[139] := 0A8H;
		UniChar[140] := 0AFH; MacChar[140] := 0F8H;
		UniChar[141] := 0B0H; MacChar[141] := 0A1H;
		UniChar[142] := 0B1H; MacChar[142] := 0B1H;
		UniChar[143] := 0B4H; MacChar[143] := 0ABH;
		UniChar[144] := 0B5H; MacChar[144] := 0B5H;
		UniChar[145] := 0B6H; MacChar[145] := 0A6H;
		UniChar[146] := 0B8H; MacChar[146] := 0FCH;
		UniChar[147] := 0BAH; MacChar[147] := 0BCH;
		UniChar[148] := 0BBH; MacChar[148] := 0C8H;
		UniChar[149] := 0BFH; MacChar[149] := 0C0H;
		UniChar[150] := 0C0H; MacChar[150] := 0CBH;
		UniChar[151] := 0C1H; MacChar[151] := 0E7H;
		UniChar[152] := 0C2H; MacChar[152] := 0E5H;
		UniChar[153] := 0C3H; MacChar[153] := 0CCH;
		UniChar[154] := 0C4H; MacChar[154] := 80H;
		UniChar[155] := 0C5H; MacChar[155] := 81H;
		UniChar[156] := 0C6H; MacChar[156] := 0AEH;
		UniChar[157] := 0C7H; MacChar[157] := 82H;
		UniChar[158] := 0C8H; MacChar[158] := 0E9H;
		UniChar[159] := 0C9H; MacChar[159] := 83H;
		UniChar[160] := 0CAH; MacChar[160] := 0E6H;
		UniChar[161] := 0CBH; MacChar[161] := 0E8H;
		UniChar[162] := 0CCH; MacChar[162] := 0EDH;
		UniChar[163] := 0CDH; MacChar[163] := 0EAH;
		UniChar[164] := 0CEH; MacChar[164] := 0EBH;
		UniChar[165] := 0CFH; MacChar[165] := 0ECH;
		UniChar[166] := 0D1H; MacChar[166] := 84H;
		UniChar[167] := 0D2H; MacChar[167] := 0F1H;
		UniChar[168] := 0D3H; MacChar[168] := 0EEH;
		UniChar[169] := 0D4H; MacChar[169] := 0EFH;
		UniChar[170] := 0D5H; MacChar[170] := 0CDH;
		UniChar[171] := 0D6H; MacChar[171] := 85H;
		UniChar[172] := 0D8H; MacChar[172] := 0AFH;
		UniChar[173] := 0D9H; MacChar[173] := 0F4H;
		UniChar[174] := 0DAH; MacChar[174] := 0F2H;
		UniChar[175] := 0DBH; MacChar[175] := 0F3H;
		UniChar[176] := 0DCH; MacChar[176] := 86H;
		UniChar[177] := 0DFH; MacChar[177] := 0A7H;
		UniChar[178] := 0E0H; MacChar[178] := 88H;
		UniChar[179] := 0E1H; MacChar[179] := 87H;
		UniChar[180] := 0E2H; MacChar[180] := 89H;
		UniChar[181] := 0E3H; MacChar[181] := 8BH;
		UniChar[182] := 0E4H; MacChar[182] := 8AH;
		UniChar[183] := 0E5H; MacChar[183] := 8CH;
		UniChar[184] := 0E6H; MacChar[184] := 0BEH;
		UniChar[185] := 0E7H; MacChar[185] := 8DH;
		UniChar[186] := 0E8H; MacChar[186] := 8FH;
		UniChar[187] := 0E9H; MacChar[187] := 8EH;
		UniChar[188] := 0EAH; MacChar[188] := 90H;
		UniChar[189] := 0EBH; MacChar[189] := 91H;
		UniChar[190] := 0ECH; MacChar[190] := 93H;
		UniChar[191] := 0EDH; MacChar[191] := 92H;
		UniChar[192] := 0EEH; MacChar[192] := 94H;
		UniChar[193] := 0EFH; MacChar[193] := 95H;
		UniChar[194] := 0F1H; MacChar[194] := 96H;
		UniChar[195] := 0F2H; MacChar[195] := 98H;
		UniChar[196] := 0F3H; MacChar[196] := 97H;
		UniChar[197] := 0F4H; MacChar[197] := 99H;
		UniChar[198] := 0F5H; MacChar[198] := 9BH;
		UniChar[199] := 0F6H; MacChar[199] := 9AH;
		UniChar[200] := 0F7H; MacChar[200] := 0D6H;
		UniChar[201] := 0F8H; MacChar[201] := 0BFH;
		UniChar[202] := 0F9H; MacChar[202] := 9DH;
		UniChar[203] := 0FAH; MacChar[203] := 9CH;
		UniChar[204] := 0FBH; MacChar[204] := 9EH;
		UniChar[205] := 0FCH; MacChar[205] := 9FH;
		UniChar[206] := 0FFH; MacChar[206] := 0D8H;
		UniChar[207] := 131H; MacChar[207] := 0F5H;
		UniChar[208] := 152H; MacChar[208] := 0CEH;
		UniChar[209] := 153H; MacChar[209] := 0CFH;
		UniChar[210] := 178H; MacChar[210] := 0D9H;
		UniChar[211] := 192H; MacChar[211] := 0C4H;
		UniChar[212] := 2C6H; MacChar[212] := 0F6H;
		UniChar[213] := 2C7H; MacChar[213] := 0FFH;
		UniChar[214] := 2D6H; MacChar[214] := 0F7H;
		UniChar[215] := 2D8H; MacChar[215] := 0F9H;
		UniChar[216] := 2D9H; MacChar[216] := 0FAH;
		UniChar[217] := 2DAH; MacChar[217] := 0FBH;
		UniChar[218] := 2DBH; MacChar[218] := 0FEH;
		UniChar[219] := 2DDH; MacChar[219] := 0FDH;
		UniChar[220] := 3C0H; MacChar[220] := 0B9H;
		UniChar[221] := 2013H; MacChar[221] := 0D0H;
		UniChar[222] := 2014H; MacChar[222] := 0D1H;
		UniChar[223] := 2018H; MacChar[223] := 0D4H;
		UniChar[224] := 2019H; MacChar[224] := 0D5H;
		UniChar[225] := 201AH; MacChar[225] := 0E2H;
		UniChar[226] := 201CH; MacChar[226] := 0D2H;
		UniChar[227] := 201DH; MacChar[227] := 0D3H;
		UniChar[228] := 201EH; MacChar[228] := 0E3H;
		UniChar[229] := 2020H; MacChar[229] := 0A0H;
		UniChar[230] := 2021H; MacChar[230] := 0E0H;
		UniChar[231] := 2022H; MacChar[231] := 0A5H;
		UniChar[232] := 2026H; MacChar[232] := 0C9H;
		UniChar[233] := 2030H; MacChar[233] := 0E4H;
		UniChar[234] := 2039H; MacChar[234] := 0DCH;
		UniChar[235] := 203AH; MacChar[235] := 0DDH;
		UniChar[236] := 2122H; MacChar[236] := 0AAH;
		UniChar[237] := 2126H; MacChar[237] := 0BDH;
		UniChar[238] := 2202H; MacChar[238] := 0B6H;
		UniChar[239] := 2206H; MacChar[239] := 0C6H;
		UniChar[240] := 220FH; MacChar[240] := 0B8H;
		UniChar[241] := 2211H; MacChar[241] := 0B7H;
		UniChar[242] := 2215H; MacChar[242] := 0DAH;
		UniChar[243] := 2219H; MacChar[243] := 0E1H;
		UniChar[244] := 221AH; MacChar[244] := 0C3H;
		UniChar[245] := 221EH; MacChar[245] := 0B0H;
		UniChar[246] := 222BH; MacChar[246] := 0BAH;
		UniChar[247] := 2248H; MacChar[247] := 0C5H;
		UniChar[248] := 2260H; MacChar[248] := 0ADH;
		UniChar[249] := 2264H; MacChar[249] := 0B2H;
		UniChar[250] := 2265H; MacChar[250] := 0B3H;
		UniChar[251] := 25CAH; MacChar[251] := 0D7H;
		l := 0F001H; UniChar[252] := SHORT(l); MacChar[252] := 0DEH;
		l := 0F002H; UniChar[253] := SHORT(l); MacChar[253] := 0DFH;

		FOR i := 0 TO 126 DO CharToUnicode[i] := i END;
		CharToUnicode[127] := 0;
		CharToUnicode[128] := 0C4H;
		CharToUnicode[129] := 0D6H;
		CharToUnicode[130] := 0DCH;
		CharToUnicode[131] := 0E4H;
		CharToUnicode[132] := 0F6H;
		CharToUnicode[133] := 0FCH;
		CharToUnicode[134] := 0E2H;
		CharToUnicode[135] := 0EAH;
		CharToUnicode[136] := 0EEH;
		CharToUnicode[137] := 0F4H;
		CharToUnicode[138] := 0FBH;
		CharToUnicode[139] := 0E0H;
		CharToUnicode[140] := 0E8H;
		CharToUnicode[141] := 0ECH;
		CharToUnicode[142] := 0F2H;
		CharToUnicode[143] := 0F9H;
		CharToUnicode[144] := 0E9H;
		CharToUnicode[145] := 0EBH;
		CharToUnicode[146] := 0EFH;
		CharToUnicode[147] := 0E7H;
		CharToUnicode[148] := 0E1H;
		CharToUnicode[149] := 0F1H;
		CharToUnicode[150] := 0DFH;
		CharToUnicode[151] := 0A3H;
		CharToUnicode[152] := 0B6H;
		CharToUnicode[153] := 0C7H;
		CharToUnicode[154] := 2030H;
		CharToUnicode[155] := 2013H;
		FOR i := 156 TO 170 DO CharToUnicode[i] := 0 END;
		CharToUnicode[171] := 0DFH;
		FOR i := 172 TO 255 DO CharToUnicode[i] := 0 END;
	END InitCharMaps;

BEGIN
	KernelLog.String("OpenType 0.45 BBPort /3.12.2004  eos, pl"); KernelLog.Ln;
	InitCharMaps;
	InitCache(FontCache);
	Identity[0] := 10000H; Identity[1] := 0;
	Identity[2] := 0; Identity[3] := 10000H
END OpenType.
