MODULE FoxTRMTools; (** AUTHOR ""; PURPOSE ""; *)
(*! deprecated -- not used any more in Active Cells3 *)
IMPORT Files,Commands,Options,Strings,Basic := FoxBasic, Diagnostics, Random, Machine, ActiveCells := FoxActiveCells, Streams, WinApplications, Hardware := FoxHardware,
		BitSets,ObjectFile;

VAR
	random: Random.Generator;

	PROCEDURE PatchSpartan6(this: ARRAY OF CHAR; VAR result: ARRAY OF CHAR; line: LONGINT);

		(*
			decode 36 bits 2 instruction big endian format
				35 ... 18				17 .. 0
				ins2_bit17 ... ins2_bit0 ins1_bit17 .. ins1_bit0

			to 2 x 18 bits instructions in the following form
				35			34			33..16					15..0
				ins2_bit17, ins2_bit16 ins1_bit17 ... inst1_bit0 ins2_bit15.. ins2_bit_0

		*)

	VAR inpos, outpos, i, bits, i1, i2, val: LONGINT;

		PROCEDURE ReadInt(): LONGINT;
		VAR c: CHAR;
		BEGIN
			c := this[inpos]; INC(inpos);
			CASE c OF
				'0' .. '9': RETURN ORD(c)- ORD('0')
				|'A'..'F': RETURN ORD(c) - ORD('A') + 10
				|'a'..'f': RETURN ORD(c) - ORD('a') + 10
			ELSE HALT(100) (* to be on the safe side *)
			END;
		END ReadInt;

		PROCEDURE WriteInt(i: LONGINT);
		VAR c: CHAR;
		BEGIN
			IF i < 0AH THEN c := CHR(i + ORD('0'))
			ELSIF i < 10H THEN c := CHR(i-10 + ORD('A'))
			ELSE HALT(100)
			END;
			result[outpos] := c; INC(outpos);
		END WriteInt;

	BEGIN
		(* decode *)
		inpos := 0; outpos := 0;
		WHILE (this[inpos] # 0X) & (this[inpos] <=" ") DO INC(inpos) END; (* skip spaces, if any *)
		i1 := 0; i2 := 0;

		IF this[inpos] # 0X THEN
			i2 := 0;
			(* upper most 16 bits of i2 *)
			FOR i := 0 TO 3 DO
				i2 := i2 * 10H + ReadInt();
			END;
			(* lower most 2 bits of i2 *)
			val := ReadInt();
			i2 := i2 * 4 + val DIV 4;
			(* upper most 2 bits of i1 *)
			i1 := val MOD 4;
			(* lower most 16 bits of i2 *)
			FOR i := 0 TO 3 DO
				i1 := i1 * 10H + ReadInt();
			END;

			(* make sure that no meaningful code is written to the "forbidden" islands *)
			ASSERT((line MOD 512 < 480) OR (line MOD 512 > 487) OR (i1 = 0) & (i2=0) OR (this = "fffffffff"));

			i := 0;
			(* upper most 2 bits of i1 and i2 *)
			WriteInt( (i2 DIV  10000H) * 4 + (i1 DIV 10000H) );
			i2 := i2 MOD 10000H; i1 := i1 MOD 10000H;
			(* remaining 16 bits of i1 *)
			bits := 10000H;
			FOR i := 0 TO 3 DO
				i1 := i1 MOD bits; bits := bits DIV 10H;
				WriteInt(i1 DIV bits);
			END;
			(* remaining 16 bits of i2 *)
			bits := 10000H;
			FOR i := 0 TO 3 DO
				i2 := i2 MOD bits; bits := bits DIV 10H;
				WriteInt(i2 DIV bits);
			END;
		END;
		result[outpos] := 0X;

	END PatchSpartan6;

	(*trm code file is split into columns. baseDiv words per line, line distributed onto numBase words.*)
	PROCEDURE SplitColumns* (CONST source,target: ARRAY OF CHAR; instructionWidth, numBase, baseDiv: LONGINT;diagnostics: Diagnostics.Diagnostics): BOOLEAN;
	VAR
		i,j,k,numReadNibbles,nibble,payloadInLeadingNibble,unCutWordLength:LONGINT;
		files: ARRAY 5 OF Files.File;
		writers: ARRAY 5 OF Files.Writer;
		currFileName: Files.FileName;
		base:  BitSets.BitSet;
		word: BitSets.BitSet;
		reader: Files.Reader;
		inputFileName: ARRAY 50 OF CHAR;
		inputFile: Files.File;
		line: ARRAY 128 OF CHAR;

	BEGIN
		(*generate multiple outupt files. horizontal split into blocks later using splitfiles*)
		FOR i:=0 TO numBase-1 DO(*create filenames*)
			(*copy name. add '.base i' to distinguish*)
			COPY(target,currFileName);
			Strings.Append(currFileName,"base");
			Basic.AppendNumber(currFileName, i);
			files[i]:= Files.New(currFileName);
			Files.OpenWriter(writers[i],files[i],0);
		END;

		unCutWordLength:= (numBase*36) DIV (baseDiv); (*a division of the base row may be longer than the actual word length*)
		payloadInLeadingNibble:=instructionWidth MOD 4;
		IF payloadInLeadingNibble=0 THEN payloadInLeadingNibble:=payloadInLeadingNibble+4; END;
		numReadNibbles:=instructionWidth DIV 4;
		IF payloadInLeadingNibble<4 THEN
			INC(numReadNibbles);
		END;
		COPY(source, inputFileName);
		inputFile := Files.Old(inputFileName);
		IF inputFile= NIL THEN
			diagnostics.Error(inputFileName,Diagnostics.Invalid,Diagnostics.Invalid,"could not open file");
			RETURN FALSE
		END;
		Files.OpenReader( reader,inputFile,0);
		NEW(base,numBase*36);
		NEW(word,instructionWidth);
		WHILE reader.Available()>0 DO (*assumes number of words is a multiple of baseDiv. make sure in static linker*)
			
			base.Zero;
			(*read a BASE line*)
			FOR k:=0 TO baseDiv-1 DO 
				(*read a word into the base*)
				word.Zero;
				j:=0;
				(*read 1 word from row into BASE bitset*)
				reader.LnEOT(line);
				(*TRACE(line);
				TRACE(payloadInLeadingNibble);
				TRACE(line[0]);*)
				(*read first nibble, removes padding*)
				nibble:=ObjectFile.CharacterToNibble(line[0]);
				j:=j+payloadInLeadingNibble;
				word.SetBits(instructionWidth-j,payloadInLeadingNibble, nibble);
				
				(*read rest*)
				FOR i:=1 TO numReadNibbles-1 DO
					(*TRACE(line[i]);*)
					nibble:=ObjectFile.CharacterToNibble(line[i]);
					j:=j+4;
					word.SetBits(instructionWidth-j,4,nibble);
				END;
				(*note there may be gaps because unCut is larger than insW*)
				BitSets.CopyBits(word,0,base,k*unCutWordLength,instructionWidth);
			END;
			FOR j:= 0 TO numBase-1 DO (*divide base into the columns*)
				(*write 36 bits to appropriate file*)	(*writing msb first*)	
				FOR k:=8 TO 0 BY -1 DO
					writers[j].Char(ObjectFile.NibbleToCharacter(base.GetBits((j)*36+k*4,4) ) );
				END;
				writers[j].Ln;
			END;
		END;
		FOR i:=0 TO numBase-1 DO
			writers[i].Update;
			Files.Register(files[i]);
		END;
		RETURN TRUE
	END SplitColumns;





	PROCEDURE DoSplitFiles*(CONST source, dest, extension: ARRAY OF CHAR; blocks, blockSize: LONGINT; verbose,strided,patchSpartan6: BOOLEAN; diagnostics: Diagnostics.Diagnostics): BOOLEAN;
	VAR line: LONGINT; fileName: Files.FileName; oldFile: Files.File;
		newFiles: POINTER TO ARRAY OF Files.File;
		reader: Files.Reader;
		writers: POINTER TO ARRAY OF Files.Writer;
		x: ARRAY 128 OF CHAR;
		i,fileNumber: LONGINT;
		linewidth: LONGINT;

		PROCEDURE GetFileName(index: LONGINT; VAR fileName: ARRAY OF CHAR);
		BEGIN
			COPY(dest,fileName);
			Basic.AppendNumber(fileName, index);
			Files.JoinExtension(fileName,extension,fileName);
		END GetFileName;



	BEGIN
	
		TRACE(source);
	
		COPY(source, fileName);
		oldFile := Files.Old(fileName);
		IF oldFile = NIL THEN
			diagnostics.Error(fileName,Diagnostics.Invalid,Diagnostics.Invalid,"could not open file");
			RETURN FALSE
		END;
		Files.OpenReader( reader,oldFile,0);

		NEW(newFiles, blocks);
		NEW(writers, blocks);

		FOR i := 0 TO blocks-1 DO
			GetFileName(i,fileName);
			newFiles[i] := Files.New(fileName);
			IF newFiles[i]= NIL THEN
				diagnostics.Error(fileName,Diagnostics.Invalid,Diagnostics.Invalid,"could not open file");
				RETURN FALSE
			ELSE
				Files.OpenWriter(writers[i],newFiles[i],0);
			END;
			IF verbose THEN
				diagnostics.Information(fileName,Diagnostics.Invalid,Diagnostics.Invalid,"file generated");
			END;
		END;
		(*If strided: read line by line, fill round robin into the output files*)
		line := 0;
		WHILE (line < blocks*blockSize) & (reader.Available()>0) DO
			IF strided THEN fileNumber := line MOD blocks ELSE fileNumber := line DIV blockSize END;
			reader.LnEOT(x);
			IF linewidth = 0 THEN linewidth := Strings.Length(x) END;
			IF patchSpartan6 THEN PatchSpartan6(x,x, line) END;
			writers[fileNumber].String(x); writers[fileNumber].Ln;
			INC(line);
		END;
		ASSERT((linewidth = 8) OR (linewidth =9) OR (linewidth = 0));
		WHILE line < blocks*blockSize DO
			IF strided THEN fileNumber := line MOD blocks ELSE fileNumber := line DIV blockSize END;
			FOR i := 0 TO linewidth-1 DO
				writers[fileNumber].Char("0");
			END;
			writers[fileNumber].Ln;
			INC(line);
		END;
		IF reader.Available()>0 THEN
			diagnostics.Warning(source,Diagnostics.Invalid,Diagnostics.Invalid,"source file truncated");
		END;
		FOR i := 0 TO blocks-1 DO
			writers[i].Update; Files.Register(newFiles[i])
		END;
		RETURN TRUE
	END DoSplitFiles;


	PROCEDURE SplitFiles* (context: Commands.Context);
	VAR options: Options.Options;
		sourceName, name, extension: Files.FileName;
		blocks: LONGINT;
		blockSize: LONGINT;
		strided: BOOLEAN;
		diagnostics: Diagnostics.StreamDiagnostics;
		done: BOOLEAN;
	BEGIN
		NEW (options);
		options.Add('b',"blocks",Options.Integer);
		options.Add('s',"blockSize",Options.Integer);
		options.Add('S',"strided",Options.Flag);
		options.Add(0X,"patchSpartan6", Options.Flag);

		IF ~options.Parse (context.arg, context.error) THEN context.result := Commands.CommandParseError; RETURN; END;
		IF ~options.GetInteger("blocks",blocks) THEN blocks := 1 END;
		IF ~options.GetInteger("blockSize",blockSize) THEN blockSize := 1024 END;
		strided := options.GetFlag("strided");
		NEW(diagnostics,context.out);

		done := TRUE;
		WHILE done & context.arg.GetString (name) DO
			Files.SplitExtension(name,sourceName,extension);
			done := DoSplitFiles(name, sourceName, extension, blocks, blockSize, TRUE, strided, options.GetFlag("patchSpartan6"), diagnostics);
		END;
	END SplitFiles;

	PROCEDURE GenerateTestFile*(context: Commands.Context);
	VAR fileName, sourceFileName: Files.FileName; size, value: LONGINT; options: Options.Options; file: Files.File; writer: Files.Writer; i: LONGINT; i1, i2: LONGINT;
		 source: Files.File; reader: Files.Reader;

		PROCEDURE WriteInt(i: LONGINT);
		VAR c: CHAR;
		BEGIN
			IF i < 0AH THEN c := CHR(i + ORD('0'))
			ELSIF i < 10H THEN c := CHR(i-10 + ORD('A'))
			ELSE HALT(100)
			END;
			writer.Char(c);
		END WriteInt;

		PROCEDURE WriteHex36(i1, i2: LONGINT);
		VAR i,j: LONGINT; c: ARRAY 9 OF LONGINT;
		BEGIN
			FOR i := 0 TO 3 DO
				c[j] := i1 MOD 10H; i1 := i1 DIV 10H; INC(j);
			END;
			c[j] := i1 + (i2 MOD 4H) * 4H; i2 := i2 DIV 4H;
			INC(j);
			FOR i := 0 TO 3 DO
				c[j] := i2 MOD 10H; i2 := i2 DIV 10H; INC(j);
			END;

			FOR j := 8 TO 0 BY -1 DO WriteInt(c[j]) END; writer.Ln;
		END WriteHex36;

	BEGIN
		NEW(options);
		options.Add("s","size",Options.Integer);
		options.Add("v","value",Options.Integer);
		options.Add("r","random",Options.Flag);
		options.Add("f","sourceFile",Options.String);

		IF ~options.Parse (context.arg, context.error) THEN context.result := Commands.CommandParseError; RETURN; END;
		IF ~options.GetInteger("size",size) THEN size := 4096 END;
		IF ~options.GetInteger("value",value) THEN value := 0 END;
		IF options.GetString("sourceFile", sourceFileName) THEN
			source := Files.Old(sourceFileName);
			NEW(reader, source, 0);
			ASSERT(source # NIL);
		END;

		IF context.arg.GetString(fileName) THEN
			file := Files.New(fileName);
			ASSERT(file # NIL);
			NEW(writer, file, 0);
			IF source = NIL THEN
				FOR i := 0 TO size -1 DO
					IF options.GetFlag("random") THEN
						i1 := random.Dice(40000H);
						i2 := random.Dice(40000H);
					ELSE
					i1 := value; i2 := value;
					END;
					WriteHex36(i1, i2);
				END;
			ELSE
				WHILE reader.Available()>0 DO
					reader.RawLInt(i1); reader.RawLInt(i2);
					WriteHex36(i1,i2);
				END;
			END;
			writer.Update;
			Files.Register(file);
			context.out.String("written file "); context.out.String(fileName); context.out.Ln;
		END;

	END GenerateTestFile;

	PROCEDURE CompareFiles*(context: Commands.Context);
	VAR f1,f2,f3: Files.File; name1, name2, matrixname: Files.FileName; r1, r2: Files.Reader;  x,y: ARRAY 32 OF CHAR; i: LONGINT; line1, line2: LONGINT;
		matrix: ARRAY 16 OF ARRAY 16 OF LONGINT; j: LONGINT; p1, p2: LONGINT; writer: Files.Writer;

		PROCEDURE WriteBit(x: LONGINT);
		BEGIN
			IF ODD(x) THEN context.out.Char("1") ELSE context.out.Char("0") END;
		END WriteBit;

		PROCEDURE WriteBits(c: CHAR);
		VAR v: LONGINT;
		BEGIN
			CASE c OF
				'0' .. '9': v :=  ORD(c)- ORD('0')
				|'A'..'F': v :=  ORD(c) - ORD('A') + 10
				|'a'..'f': v :=  ORD(c) - ORD('a') + 10
			ELSE HALT(100) (* to be on the safe side *)
			END;
			WriteBit(ORD(c) DIV 8);
			WriteBit(ORD(c) DIV 4);
			WriteBit(ORD(c) DIV 2);
			WriteBit(ORD(c));

		END WriteBits;

		PROCEDURE Value(c: CHAR): LONGINT;
		BEGIN
			CASE c OF
				'0' .. '9': RETURN  ORD(c)- ORD('0')
				|'A'..'F': RETURN  ORD(c) - ORD('A') + 10
				|'a'..'f': RETURN  ORD(c) - ORD('a') + 10
			ELSE HALT(100) (* to be on the safe side *)
			END;

		END Value;


		PROCEDURE WriteLn;
		BEGIN
			context.out.Ln;
		END WriteLn;

	BEGIN
		IF context.arg.GetString(name1) & context.arg.GetString(name2) &  context.arg.GetString(matrixname) THEN
			f1 := Files.Old(name1); f2 := Files.Old(name2); f3 := Files.New(matrixname);
			NEW(r1,f1,0); NEW(r2,f2,0); NEW(writer, f3,0);
			WHILE (r1.Available() > 0) & (r2.Available() > 0) DO
				r1.LnEOT(x);r2.LnEOT(y);

				IF (line1 MOD 512 >= 480) & (line1 MOD 512 <= 487) THEN
					p1 := (Value(x[0]) DIV 4H)*4H+Value(x[4]) MOD 4H;
					p2 := (Value(y[0]) DIV 4H)*4H+Value(y[4]) MOD 4H;
					context.out.Int(line1,1); context.out.Ln; context.out.Update;
					ASSERT(Value(x[0]) MOD 4 = Value(y[0]) MOD 4);
					ASSERT(Value(x[4]) DIV 4 = Value(y[4]) DIV 4);
					INC(matrix[p1, p2]);
				ELSE
					ASSERT(x = y);
				END;
				INC(line1);


				(*
				IF (line1 MOD 512 = 480)  THEN
					context.out.Int(line1,1); context.out.String(":");
					WHILE line1 MOD 512 < 487 DO
					r1.LnEOT(x);
					i := 0;
					WHILE (x[i] # 0X) DO
						IF i IN {0,4} THEN
						WriteBits(x[i]);
						ELSE
						context.out.Char(x[i]);
						END;
						context.out.String("|");
						INC(i);
					END;
					context.out.String(" ");
					INC(line1);
					END;

					WriteLn;
					context.out.Int(line2,1); context.out.String(":");
					WHILE line2 MOD 512 < 487 DO
					r2.LnEOT(y);
					i := 0;
					WHILE (y[i] # 0X) DO
						IF i IN {0,4} THEN
						WriteBits(y[i]);
						ELSE context.out.Char(y[i]);
						END;
						context.out.String("|");
						INC(i)
					END;
					context.out.String(" ");
					INC(line2);
					END;

					WriteLn;
					WriteLn;
				ELSE INC(line1); INC(line2);r1.LnEOT(x);r2.LnEOT(y);

				END;
				*)
			END;


			FOR i := 0 TO 15 DO
			FOR j := 0 TO 15 DO
				writer.Int(matrix[i,j],1); writer.String(" ");
				context.out.Int(matrix[i,j],1); context.out.String(" ");
			END;
				context.out.Ln;
				writer.Ln;
			END;
			writer.Update;
			Files.Register(f3);
		END;
	END CompareFiles;

	PROCEDURE SameFiles(CONST filename1, filename2: ARRAY OF CHAR): BOOLEAN;
	VAR
		file1, file2 : Files.File; reader1, reader2 : Files.Reader; ch1, ch2 : CHAR;
	BEGIN
		file1 := Files.Old(filename1);
		IF (file1# NIL) THEN
			file2 := Files.Old(filename2);
			IF (file2 # NIL) THEN
				IF (file1.Length() = file2.Length()) THEN
					NEW(reader1, file1, 0);
					NEW(reader2, file2, 0);
					REPEAT
						reader1.Char(ch1);
						reader2.Char(ch2);
					UNTIL (ch1 # ch2) OR (reader1.res # Files.Ok) OR (reader2.res # Files.Ok);

					IF (ch1 = ch2) & (reader1.res = reader2.res) & (reader1.res = Streams.EOF) THEN
						RETURN TRUE;
					ELSE
						RETURN FALSE;
					END;
				ELSE
					RETURN FALSE;
				END;
			ELSE
				RETURN FALSE;
			END;
		ELSE
			RETURN FALSE;
		END;
	END SameFiles;

	PROCEDURE IsEngine(instance: ActiveCells.Instance): BOOLEAN;
	VAR type: ActiveCells.Type;
	BEGIN
		type := instance.instanceType;
		IF type.scope.name = "Engines" THEN
			IF type.name = "Adder" THEN RETURN TRUE
			ELSE RETURN FALSE (* unknown engine in Engines module *)
			END;
		ELSE (* not in Engines module *)
			RETURN FALSE
		END;
	END IsEngine;

	PROCEDURE DeleteFiles(CONST fileSelectionMask: ARRAY OF CHAR; context: Commands.Context; VAR res: LONGINT);
	VAR
		enum: Files.Enumerator;
		flags: SET;
		time, date, size: LONGINT;
		name: Files.FileName;
	BEGIN
		NEW(enum);
		enum.Open(fileSelectionMask,{});

		res := 0;
		WHILE (res = 0) & enum.GetEntry(name,flags,time,date,size) DO
			IF ~(Files.Directory IN flags) THEN
				context.out.String("deleting file "); context.out.String(name); context.out.String(" ...");
				Files.Delete(name,res);
				IF res = 0 THEN context.out.String(" Ok"); context.out.Ln; context.out.Update;
				ELSE
					context.error.String("failed to delete file "); context.error.String(name); context.error.String(", res="); context.error.Int(res,0); context.error.Ln; context.error.Update;
				END;
			END;
		END;
	END DeleteFiles;

	(* Execute a command line command given a path *)
	PROCEDURE ExecuteInPath(CONST cmd: ARRAY OF CHAR; CONST path: ARRAY OF CHAR; VAR res: LONGINT);
	VAR
		file: Files.File;
		w: Files.Writer;
	BEGIN
		file := Files.New("temp.bat"); ASSERT(file # NIL);
		Files.Register(file);
		NEW(w,file,0);
		w.String("cd \"); w.Ln;
		w.String("cd ");
		w.String(path); w.Ln;
		w.String(cmd); w.Ln;
		w.Update;
		file.Close;

		res := WinApplications.Call("temp.bat","");
	END ExecuteInPath;

	PROCEDURE SizeInBlocks(sizeInUnits, blockSize: LONGINT): LONGINT;
	BEGIN
		RETURN (sizeInUnits-1) DIV blockSize +1
	END SizeInBlocks;

	(* Get the execution status of an impact batch command

		cmdPath - the path where impact command was issued
		success - TRUE for success
		res - result code (0 in case if status was determined successfully)
	*)
	PROCEDURE GetImpactCmdStatus(CONST cmdPath: ARRAY OF CHAR; VAR success: BOOLEAN; VAR res: LONGINT);
	VAR
		file: Files.File;
		fileName: Files.FileName;
		r: Files.Reader;
		str: ARRAY 128 OF CHAR;
		overwrite: BOOLEAN;
		k: LONGINT;
	BEGIN
		res := 0;

		Files.JoinPath(cmdPath,"_impactbatch.log",fileName);


		file := Files.Old(fileName);
		IF file = NIL THEN res := -1; RETURN; END;
		NEW(r,file,0);

		REPEAT
			r.Ln(str);
			(*success := str = "'1': Programmed successfully.";*)
			k := Strings.Find(str,0,':');
			IF k > 0 THEN
				Strings.Delete(str,0,k+1);
				Strings.TrimWS(str);
				success := str = "Programmed successfully.";
			END;
		UNTIL success OR (r.res = Streams.EOF);

	FINALLY
		file.Close();
	END GetImpactCmdStatus;

	(**
		Command for building ActiveCells hardware

		syntax:

		BuildHardware -p=platformId -f=specificationName ~

		where

		platformId - a string with an ActiveCells platform ID
		specificationName - a string with the name of hardware specification (file name without ".spec" extension)
	*)
	PROCEDURE BuildHardware*(context: Commands.Context);
	CONST BuiltPrefix = "built-";
	VAR
		options: Options.Options;
		specName, builtSpecName, specPath, hwPath, str: Files.FileName;
		platformId: Files.FileName;
		spec, builtSpec: ActiveCells.Specification;
		instance: ActiveCells.Instance;
		description: Hardware.Description;
		changes: BOOLEAN;

		res: LONGINT;
		diagnostics: Diagnostics.StreamDiagnostics;

		PROCEDURE Exists(CONST path, name, ext: ARRAY OF CHAR): BOOLEAN;
		VAR fileName: Files.FileName;
		BEGIN
			Files.JoinPath(path,name,fileName);
			Files.JoinExtension(fileName,ext,fileName);
			RETURN Files.Old(fileName) # NIL;
		END Exists;

		PROCEDURE CopyAsBuilt(CONST path, name, ext: ARRAY OF CHAR; CONST dstPath: ARRAY OF CHAR; VAR res: LONGINT);
		VAR
			overwrite: BOOLEAN;
			fileName, builtFileName: Files.FileName;
		BEGIN
			Files.JoinExtension(name,ext,fileName);
			Files.JoinPath(path,fileName,fileName);

			Strings.Concat(BuiltPrefix,name,builtFileName);
			Files.JoinExtension(builtFileName,ext,builtFileName);
			Files.JoinPath(dstPath,builtFileName,builtFileName);

			overwrite := TRUE;
			Files.CopyFile(fileName,builtFileName,overwrite,res);
			IF res # 0 THEN context.error.String("failed to copy file "); context.error.String(fileName); context.error.String(" to "); context.error.String(builtFileName); context.error.Ln; context.error.Update; RETURN; END;
		END CopyAsBuilt;

		PROCEDURE SameAsBuilt(CONST path, name, ext: ARRAY OF CHAR): BOOLEAN;
		VAR fileName, builtFileName: Files.FileName;
		BEGIN
			Files.JoinExtension(name,ext,fileName);
			Files.JoinPath(path,fileName,fileName);

			Strings.Concat(BuiltPrefix,name,builtFileName);
			Files.JoinExtension(builtFileName,ext,builtFileName);
			Files.JoinPath(path,builtFileName,builtFileName);

			RETURN SameFiles(fileName,builtFileName);
		END SameAsBuilt;

		PROCEDURE PatchAndConfigure(VAR res: LONGINT);
		VAR
			insBlockSize, dataBlockSize: LONGINT;
			file: Files.File;
			w: Files.Writer;
			iBlock, numBlocks: LONGINT;
			k: LONGINT;
			blockName, instanceName: Files.FileName;
			tempOut, success: BOOLEAN;
			numPatched: LONGINT;
		BEGIN
			(* instruction and data memory block sizes *)
			(*! query these parameters from FoxActiveCells!!! *)
			IF platformId = "ML505" THEN insBlockSize := 2048; dataBlockSize := 1024;
			ELSIF platformId = "AVSP6LX75T" THEN insBlockSize := 1024; dataBlockSize := 512;
			ELSIF platformId = "TL400" THEN insBlockSize := 1024; dataBlockSize := 512;
			ELSIF platformId = "Spartan_XC3S200" THEN insBlockSize := 1024; dataBlockSize := 512;
			ELSIF platformId = "Spartan_XC3S500e" THEN insBlockSize := 1024; dataBlockSize := 512;
			ELSE HALT(100);
			END;

			file := Files.New("temp.bat"); ASSERT(file # NIL);
			NEW(w,file,0);
			w.String("cd \"); w.Ln;
			w.String("cd "); w.String(hwPath); w.Ln;

			tempOut := TRUE;
			numPatched := 0;

			FOR k := 0 TO spec.instances.Length()-1 DO

				instance := spec.instances.GetInstance(k);
				IF ~IsEngine(instance) THEN

					(** process instruction memory files *)
					instance.GetFullName(instanceName,NIL);
					Files.JoinExtension(instanceName,ActiveCells.CodeFileExtension,instanceName);
					iBlock := 0; numBlocks := SizeInBlocks(instance.instructionMemorySize,insBlockSize);
					WHILE iBlock < numBlocks DO

						ActiveCells.NormalizeName(instanceName,blockName);
						Basic.AppendNumber(blockName,iBlock);
						Files.JoinExtension(blockName,"mem",blockName);

						IF ~SameAsBuilt(hwPath,blockName,"") THEN

							IF ~Exists(hwPath,blockName,"") THEN res := -1; diagnostics.Error(blockName,Diagnostics.Invalid,Diagnostics.Invalid," file does not exist"); RETURN; END;

							w.String("data2mem -bm "); ActiveCells.WriteName(w,spec,"","bd"); w.String(".bmm  -bt  .\");
							IF tempOut THEN w.String(builtSpecName); ELSE w.String("temp"); END;
							w.String(".bit  -bd "); w.String(blockName);
							w.String(" tag "); ActiveCells.WriteName(w,instance.scope,instance.name,"ins"); w.Int(iBlock,1);
							w.String(" -o b .\");
							IF tempOut THEN w.String("temp"); ELSE w.String(builtSpecName); END; tempOut := ~tempOut;
							w.String(".bit");
							w.Ln;

							CopyAsBuilt(hwPath,blockName,"",hwPath,res);
							IF res # 0 THEN RETURN; END;

							INC(numPatched);
						END;

						INC(iBlock);
					END;

					(** process data memory files *)
					instance.GetFullName(instanceName,NIL);
					Files.JoinExtension(instanceName,ActiveCells.DataFileExtension,instanceName);
					iBlock := 0; numBlocks := SizeInBlocks(instance.dataMemorySize,dataBlockSize);
					WHILE iBlock < numBlocks DO
						ActiveCells.NormalizeName(instanceName,blockName);
						Basic.AppendNumber(blockName,iBlock);
						Files.JoinExtension(blockName,"mem",blockName);

						IF ~SameAsBuilt(hwPath,blockName,"") THEN

							IF ~Exists(hwPath,blockName,"") THEN res := -1; diagnostics.Error(blockName,Diagnostics.Invalid,Diagnostics.Invalid," file does not exist"); END;

							w.String("data2mem -bm "); ActiveCells.WriteName(w,spec,"","bd"); w.String(".bmm  -bt  .\");
							IF tempOut THEN w.String(builtSpecName); ELSE w.String("temp"); END;
							w.String(".bit  -bd "); w.String(blockName);
							w.String(" tag "); ActiveCells.WriteName(w,instance.scope,instance.name,"dat"); w.Int(iBlock,1);
							w.String(" -o b .\");
							IF tempOut THEN w.String("temp"); ELSE w.String(builtSpecName); END; tempOut := ~tempOut;
							w.String(".bit");
							w.Ln;

							CopyAsBuilt(hwPath,blockName,"",hwPath,res);
							IF res # 0 THEN RETURN; END;

							INC(numPatched);
						END;

						INC(iBlock);
					END;

				END;
			END;

			IF numPatched > 0 THEN
				IF ~tempOut THEN (* copy final bitstream stored in temp.bit to builtSpecName.bit *)
					w.String("copy /B /Y /V temp.bit "); w.String(builtSpecName); w.String(".bit"); w.Ln;
				END;
				w.String("del temp.bit"); w.Ln;
			END;

			w.String("copy /B /Y /V "); w.String(builtSpecName); w.String(".bit"); w.String(" df.bit"); w.Ln;
			w.String("copy /B /Y /V ..\download.cmd  download.cmd"); w.Ln;
			w.String("impact -batch download.cmd"); w.Ln;
			w.String("del df.bit"); w.Ln;

			w.Update;
			Files.Register(file);
			file.Close;

			(* execute the script *)
			context.out.String("configuring the FPGA ... "); context.out.Update;
			res := WinApplications.Call("temp.bat","");
			IF res # 0 THEN context.error.String("failed to configure the FPGA, cmd batch res="); context.error.Int(res,0); context.error.Ln; context.error.Update; RETURN; END;

			GetImpactCmdStatus(hwPath,success,res);
			IF res # 0 THEN context.error.String("failed to determine status of Xilinx Impact command execution!"); RETURN; END;

			IF success THEN
				context.out.String("Ok"); context.out.Ln; context.out.Update;
			ELSE
				res := -1;
				Files.JoinPath(hwPath,"_impactbatch.log",str);
				context.error.String("failed to configure the FPGA: see "); context.error.String(str); context.error.String(" for details about the error!"); context.error.Ln; context.error.Update;
			END;
		END PatchAndConfigure;

	BEGIN
		NEW(options);
		options.Add("p","platform",Options.String);
		options.Add("f","specName",Options.String);
		options.Add("n","forceNew",Options.Flag);
		IF ~options.Parse(context.arg,context.error) THEN RETURN; END;

		IF ~options.GetString("platform",platformId) THEN
			context.error.String("platform string ID is expected!"); context.error.Ln; RETURN;
		END;

		IF ~options.GetString("specName",specName) THEN
			context.error.String("specification file name is expected!"); context.error.Ln; RETURN;
		END;

		NEW(diagnostics,context.error);

		spec := ActiveCells.LoadSpecification(specName,diagnostics,context.out);
		IF spec = NIL THEN
			context.error.String("failed to load specification from file "); context.error.String(specName); context.error.String(".spec"); context.error.Ln; RETURN;
		END;

		description := Hardware.GetDescription(platformId);
		IF description = NIL THEN
			context.error.String("failed to instantiate hardware description "); context.error.String(platformId); context.error.Ln; RETURN;
		END;


		(* get the hardware path *)
		description.GetHardwarePath(hwPath);

		(* remove the path from the specification name *)
		Files.SplitPath(specName,specPath,specName); IF specPath = "" THEN specPath := "WORK:"; END;

		Strings.Concat(BuiltPrefix,specName,builtSpecName);
		Files.JoinPath(hwPath,builtSpecName,str);
		builtSpec := ActiveCells.LoadSpecification(str,diagnostics,context.out);

		changes := (builtSpec = NIL) OR ~spec.Same(builtSpec,{});

		IF changes OR options.GetFlag("forceNew") THEN (* have to compile the hardware *)

			IF changes THEN
				context.out.String("detected changes in hardware specification, ");
			END;
			context.out.String("compiling FPGA hardware design ... "); context.out.Update;

			(* remove old bit file *)
			Files.JoinExtension(specName,"bit",str);
			Files.JoinPath(hwPath,str,str);
			DeleteFiles(str,context,res);

			(* execute TCL script *)
			Strings.Concat("xtclsh ",specName,str);
			Strings.Concat(str,".tcl",str);
			ExecuteInPath(str,hwPath,res);

			(* get the result of compilation *)
			IF res # 0 THEN context.error.String("failed to compile FPGA hardware design, cmd batch res="); context.error.Int(res,0); context.error.Ln; RETURN; END;

			context.out.String("Ok"); context.out.Ln; context.out.Update;

			(* remove old built bitstream *)
			Files.JoinExtension(builtSpecName,"bit",str);
			Files.JoinPath(hwPath,str,str);
			DeleteFiles(str,context,res);
			IF res # 0 THEN RETURN; END;

			(* remove old built mem-files *)
			Strings.Concat(builtSpecName,"*.mem",str);
			Files.JoinPath(hwPath,str,str);
			DeleteFiles(str,context,res);
			IF res # 0 THEN RETURN; END;

			(*
				make a copy of the bitstream and use it as a built version
			*)
			CopyAsBuilt(hwPath,specName,"bit",hwPath,res);
			IF res # 0 THEN RETURN; END;

			(*
				remember the current specification as already built
			*)
			CopyAsBuilt(specPath,specName,"spec",hwPath,res);
			IF res # 0 THEN RETURN; END;
		END;

		PatchAndConfigure(res);

		IF res = 0 THEN
			context.out.String("successfully built ActiveCells hardware!"); context.out.Ln;
		ELSE context.result := Commands.CommandError
		END;
	END BuildHardware;

BEGIN
	NEW(random);
	random.InitSeed(SHORT(Machine.GetTimer()));
END FoxTRMTools.

FoxTRMTools.Test ~

Compiler.Compile -b=TRM --objectFile=Intermediate --activeCells --noRuntimeChecks --activeCellsSpecification=FoxAVSP6LX75T --patchSpartan6
oc/TRM.RS232.Mod
oc/TRM.Testing.Mod
oc/TRM.TRMRuntime.Mod
oc/TRM.TestNet.Mdf
~

Compiler.Compile -b=TRM --objectFile=Intermediate --activeCells --noRuntimeChecks --activeCellsSpecification=ML505
oc/TRM.RS232.Mod
oc/TRM.Testing.Mod
oc/TRM.TRMRuntime.Mod
oc/TRM.TestNet.Mdf
~


FoxAVSP6LX75T.ReadSpecification TestNet ~

FoxTRMTools.BuildHardware -p="AVSP6LX75T" -f="TestNet" ~

FoxTRMTools.BuildHardware -p="ML505" -f="TestNet" ~

SystemTools.Free FoxTRMTools ~

FoxTRMTools.SplitFiles  code.mem data.mem ~
FoxTRMTools.SplitFiles  --blocks=8 --strided data.mem ~
PET.Open data.mem ~
PET.Open data0.mem ~
PET.Open data1.mem ~


FoxTRMTools.GenerateTestFile test.code ~
FoxTRMTools.GenerateTestFile --value=010H test.code ~
FoxTRMTools.GenerateTestFile --random test.code ~
FoxTRMTools.GenerateTestFile --sourceFile=binary.code test2.code ~

FoxTRMTools.SplitFiles  --blockSize=1024 --blocks=5 test.code ~

PET.Open -e test.code test2.code ~

FoxTRMTools.CompareFiles test.code test2.code matrix.txt ~



UARTPC.Open 6 ~

SystemTools.DoCommands

FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


FoxTRMTools.GenerateTestFile --random --size=4096 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=8 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 8192 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~


SystemTools.Show "DONE!" ~
~




SystemTools.DoCommands

FoxTRMTools.GenerateTestFile --random --size=512 TestBRAM0con0code.mem ~
FoxTRMTools.SplitFiles  --blockSize=512 --blocks=1 --patchSpartan6 TestBRAM0con0code.mem ~
WinApplications.Run "testbram.bat" ~
UARTPC.DumpBRAM 6 0 1024 "bram.dat" ~
FoxTRMTools.GenerateTestFile --sourceFile=bram.dat test.code ~
PET.Open -e TestBRAM0con0code.mem test.code ~
FoxTRMTools.CompareFiles TestBRAM0con0code.mem test.code bram.mtx~

~


M = {};

file =fopen('bram.mtx')
A = fscanf(file,'%d');
fclose(file)
A = reshape(A,16,16);

M{numel(M)+1}=A;