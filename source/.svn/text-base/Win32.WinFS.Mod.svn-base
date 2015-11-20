MODULE WinFS;   (*AUTHOR "fof,ejz"; PURPOSE "Windows file system  for WinAos"; *)

IMPORT SYSTEM, Machine, Kernel32, KernelLog, Modules, Kernel, Files, Commands;
(* orange marked lines denote overloaded methods *)

CONST
	PathDelimiter = "\";  BufferSize = 4096;
	(** File flags *)
	ReadOnly* = Files.ReadOnly;
	Directory* = Files.Directory;
	Hidden* = Files.Hidden;
	System* = Files.System;
	Archive* = Files.Archive;
	Temporary* = Files.Temporary;

	TraceFile = 0;  TraceFileSystem = 1;  TraceCollection = 2;  TraceSearch = 3;  Trace = {};
	TraceMounting=FALSE;
	deviceArrival* = 08000H;   (* DBT_DEVICEARRIVAL = 08000H *)
	deviceRemove* = 08004H;   (* DBT_DEVICEREMOVECOMPLETE = 08004H *)


TYPE
	FileName = ARRAY Kernel32.MaxPath OF CHAR;
	PFileName = POINTER TO FileName;
	NotificationProc* = PROCEDURE ( type: LONGINT;  drives: SET );
	Notification = POINTER TO RECORD
		p: NotificationProc;
		next: Notification
	END;

VAR
	searchPath: ARRAY 4 * Kernel32.MaxPath OF CHAR;
	workPath, tempPath: FileName;  notifications: Notification;
TYPE

	SearchByName = OBJECT
	VAR sname: FileName;
		found: File;

		PROCEDURE Init( name: ARRAY OF CHAR );
		BEGIN
			found := NIL;  UpperCase( name, sname )
		END Init;

		PROCEDURE EnumFile( f: ANY;  VAR cont: BOOLEAN );
		VAR F: File;  fname: FileName;
		BEGIN
			F := f( File );  UpperCase( F.fname, fname );

			IF TraceSearch IN Trace THEN KernelLog.String( "Enumerate: " );  KernelLog.String( fname );
			END;
			IF sname = fname THEN found := F;  cont := FALSE ELSE cont := TRUE END;
			IF TraceSearch IN Trace THEN
				IF cont THEN KernelLog.String( " # " );  ELSE KernelLog.String( " = " );  END;
				KernelLog.String( sname );  KernelLog.Ln;
			END;
		END EnumFile;

	END SearchByName;

	FinalizeFiles = OBJECT

		PROCEDURE EnumFile( f: ANY;  VAR cont: BOOLEAN );
		VAR F: File;
		BEGIN
			F := f( File );  F.Finalize();  cont := TRUE
		END EnumFile;

	END FinalizeFiles;

	Collection = OBJECT  (* methods in Collection shared by objects Filesystem and File *)
	VAR oldFiles, newFiles: Kernel.FinalizedCollection;
		search: SearchByName;
		fileKey: LONGINT;

		PROCEDURE & Init*;
		BEGIN
			NEW( oldFiles );  NEW( newFiles );  NEW( search );  fileKey := -1;
		END Init;

		PROCEDURE GetNextFileKey( ): LONGINT;
		BEGIN {EXCLUSIVE}
			DEC( fileKey );  RETURN fileKey
		END GetNextFileKey;

		PROCEDURE Register( F: File );
		BEGIN {EXCLUSIVE}
			IF TraceCollection IN Trace THEN KernelLog.String( "Collections.Register " );  KernelLog.String( F.fname );  KernelLog.Ln;  END;
			oldFiles.Add( F, FinalizeFile );  newFiles.Remove( F );  DEC( fileKey );  F.Init( F.fname, F.hfile, fileKey,F.fileSystem );
		END Register;

		PROCEDURE Unregister( F: File );
		BEGIN {EXCLUSIVE}
			IF TraceCollection IN Trace THEN KernelLog.String( "Unregister " );  KernelLog.String( F.fname );  KernelLog.Ln;  END;
			oldFiles.Remove( F );  newFiles.Add( F, FinalizeFile (* FinalizeFile*) );  F.Init( F.fname, Kernel32.InvalidHandleValue, 0, F.fileSystem );
		END Unregister;

		PROCEDURE AddNew( F: File );
		BEGIN {EXCLUSIVE}
			IF TraceCollection IN Trace THEN KernelLog.String( "Collections.AddNew: " );  KernelLog.String( F.fname );  KernelLog.Ln;  END;
			newFiles.Add( F, FinalizeFile );
		END AddNew;

		PROCEDURE AddOld( F: File );
		BEGIN {EXCLUSIVE}
			IF TraceCollection IN Trace THEN KernelLog.String( "Collections.AddOld: " );  KernelLog.String( F.fname );  KernelLog.Ln;  END;
			oldFiles.Add( F, FinalizeFile );
		END AddOld;

		PROCEDURE ByName( VAR fname: ARRAY OF CHAR ): File;
		BEGIN {EXCLUSIVE}
			IF TraceCollection IN Trace THEN KernelLog.String( "Collections.ByName: " );  KernelLog.String( fname );  KernelLog.Ln;  END;
			search.Init( fname );  oldFiles.Enumerate( search.EnumFile );  RETURN search.found
		END ByName;

		PROCEDURE ByNameNotGC( VAR fname: ARRAY OF CHAR ): File;
		BEGIN {EXCLUSIVE}
			IF TraceCollection IN Trace THEN KernelLog.String( "Collections.ByName: " );  KernelLog.String( fname );  KernelLog.Ln;  END;
			search.Init( fname );  oldFiles.EnumerateN( search.EnumFile );  RETURN search.found;
		END ByNameNotGC;

		PROCEDURE Finalize;
		VAR fin: FinalizeFiles;
		BEGIN {EXCLUSIVE}
			IF TraceCollection IN Trace THEN KernelLog.String( "Collections.Finalize " );  KernelLog.Ln;  END;
			NEW( fin );  newFiles.Enumerate( fin.EnumFile );  newFiles.Clear();  oldFiles.Enumerate( fin.EnumFile );  oldFiles.Clear();
		END Finalize;

		PROCEDURE FinalizeFile( obj: ANY );
		VAR F: File;
		BEGIN
			F := obj( File );
			IF TraceCollection IN Trace THEN KernelLog.String( "Collections.FinalizeFile " );  KernelLog.String( F.fname );  KernelLog.Ln;  END;
			F.Finalize()
		END FinalizeFile;

	END Collection;

	AliasFileSystem* = OBJECT (Files.FileSystem)
	VAR fs: WinFileSystem;
		useprefix*: BOOLEAN;

		PROCEDURE Prefix( VAR name, res: ARRAY OF CHAR );
		BEGIN
			IF useprefix & (name # "") THEN Join( prefix, ":", name, res );  ELSE COPY( name, res );  END;
		END Prefix;

		PROCEDURE & Init*;
		BEGIN
			SELF.fs := winFS;  useprefix := TRUE;  INCL( flags, Files.NeedsPrefix );
		END Init;

		PROCEDURE New0( name: ARRAY OF CHAR ): Files.File;
		VAR fname: FileName;  f: Files.File;
		BEGIN
			Prefix( name, fname ); f := fs.New0( fname ); IF f # NIL THEN  f.fs := SELF; END;  RETURN f;
		END New0;

		PROCEDURE Old0( name: ARRAY OF CHAR ): Files.File;
		VAR fname: FileName;   f: Files.File;
		BEGIN
			Prefix( name, fname );  f :=  fs.Old0( fname ); IF f # NIL THEN  f.fs := SELF; END; RETURN f;
		END Old0;

		PROCEDURE Delete0( name: ARRAY OF CHAR;  VAR key, res: LONGINT );
		VAR fname: FileName;
		BEGIN
			Prefix( name, fname );  fs.Delete0( fname, key, res );
		END Delete0;

		PROCEDURE Rename0( old, new: ARRAY OF CHAR;  fold: Files.File;  VAR res: LONGINT );
		VAR old0, new0: FileName;
		BEGIN
			Prefix( old, old0 );  Prefix( new, new0 );  fs.Rename0( old0, new0, fold, res );
		END Rename0;

		PROCEDURE Enumerate0( mask: ARRAY OF CHAR;  flags: SET;  enum: Files.Enumerator );
		VAR fmask: FileName;
		BEGIN
			Prefix( mask, fmask );  fs.Enumerate1( fmask, flags, enum, useprefix );
		END Enumerate0;

		PROCEDURE FileKey( name: ARRAY OF CHAR ): LONGINT;
		VAR fname: FileName;
		BEGIN
			Prefix( name, fname );  RETURN fs.FileKey( fname );
		END FileKey;

		PROCEDURE CreateDirectory0( name: ARRAY OF CHAR;  VAR res: LONGINT );
		VAR fname: FileName;
		BEGIN
			Prefix( name, fname );  fs.CreateDirectory0( fname, res );
		END CreateDirectory0;

		PROCEDURE RemoveDirectory0( name: ARRAY OF CHAR;  force: BOOLEAN;  VAR key, res: LONGINT );
		VAR fname: FileName;
		BEGIN
			Prefix( name, fname );  fs.RemoveDirectory0( fname, force, key, res );
		END RemoveDirectory0;

	END AliasFileSystem;

	WinFileSystem = OBJECT (* own object for synchronisation of all actions on the (unique) windows file system *)
	VAR collection: Collection;

		PROCEDURE & Init*;
		BEGIN
			NEW( collection );
		END Init;

		PROCEDURE New0( name: ARRAY OF CHAR ): Files.File;
		VAR F: File;  fname: FileName;
		BEGIN {EXCLUSIVE}
			ConvertChar( name, Files.PathDelimiter, PathDelimiter );
			IF TraceFileSystem IN Trace THEN KernelLog.String( "New0 " );  KernelLog.String( name );  KernelLog.Ln;  END;
			F := NIL;
			IF name = "" THEN  (* temporary file *)
				NEW( F, name, Kernel32.InvalidHandleValue, 0, SELF ); collection.AddNew( F );
			ELSIF FullPathName( name, fname ) & CheckPath(fname) THEN
				NEW( F, fname, Kernel32.InvalidHandleValue, 0, SELF ); collection.AddNew( F );
			END;
			IF TraceFileSystem IN Trace THEN KernelLog.String( "failed" );  KernelLog.Ln;  END;
			RETURN F;
		END New0;

		PROCEDURE Old0( name: ARRAY OF CHAR ): Files.File;
		VAR F: File;  hfile: Kernel32.HANDLE;  fname: FileName;
		BEGIN {EXCLUSIVE}
			ConvertChar( name, Files.PathDelimiter, PathDelimiter );
			IF TraceFileSystem IN Trace THEN KernelLog.String( "Old0 " );  KernelLog.String( name );  KernelLog.Ln;  END;

			IF (name # "") & FindFile( name, fname ) THEN
				hfile := Kernel32.CreateFile( fname, {Kernel32.GenericRead}, {Kernel32.FileShareRead, Kernel32.FileShareWrite}, NIL , Kernel32.OpenExisting, {Kernel32.FileAttributeNormal}, 0 );
				IF hfile # Kernel32.InvalidHandleValue THEN NEW( F, fname, hfile, collection.GetNextFileKey() , SELF);    collection.AddOld( F );  RETURN F END
			END;
			IF TraceFileSystem IN Trace THEN KernelLog.String( "failed" );  KernelLog.Ln;  END;
			RETURN NIL
		END Old0;

		PROCEDURE Delete0( name: ARRAY OF CHAR;  VAR key, res: LONGINT );
		VAR fname: FileName;  F: File;  ret: Kernel32.BOOL;
		BEGIN {EXCLUSIVE}
			ConvertChar( name, Files.PathDelimiter, PathDelimiter );  key := 0;  res := 1;
			IF FullPathName( name, fname ) THEN
				F := collection.ByName( fname );
				IF F # NIL THEN
					key := F.key;
					IF F.ToTemp() THEN res := 0 END;
				ELSE
					ret := Kernel32.DeleteFile( fname );
					IF ret # 0 THEN res := 0 END
				END
			END
		END Delete0;

		PROCEDURE Rename0( old, new: ARRAY OF CHAR;  fold: Files.File;  VAR res: LONGINT );
		VAR fnold, fnnew: FileName;  Fo, Fn: File;  ret: Kernel32.BOOL;
		BEGIN {EXCLUSIVE}
			IF TraceFileSystem IN Trace THEN KernelLog.String( "Rename " );  KernelLog.String( old );  KernelLog.String( " -> " );  KernelLog.String( new );  KernelLog.Ln;  END;
			ConvertChar( old, Files.PathDelimiter, PathDelimiter );  ConvertChar( new, Files.PathDelimiter, PathDelimiter );  res := 1;
			IF FullPathName( old, fnold ) & FullPathName( new, fnnew ) THEN
				Fn := collection.ByName( fnnew );
				IF Fn # NIL THEN
					IF ~Fn.ToTemp() THEN RETURN END
				END;
				IF fold # NIL THEN
					Fo := fold( File );
					IF ~Fo.ToTemp() THEN RETURN END;
					ret := Kernel32.CopyFile( Fo.tfname^, fnnew, 0 )
				ELSE ret := Kernel32.MoveFileEx( fnold, fnnew, {Kernel32.MoveFileReplaceExisting, Kernel32.MoveFileCopyAllowed} )
				END;
				IF ret # 0 THEN res := 0 END
			ELSIF TraceFileSystem IN Trace THEN KernelLog.String( "Rename failed :" );  KernelLog.String( fnold );  KernelLog.String( " => " );  KernelLog.String( fnnew );  KernelLog.Ln;
			END
		END Rename0;

		PROCEDURE Enumerate1( mask: ARRAY OF CHAR;  flags: SET;  enum: Files.Enumerator;  useprefix: BOOLEAN );
		VAR i, j: LONGINT;
			path, pattern: ARRAY 256 OF CHAR;
			attr: SET;  curPath, longname: FileName;

			PROCEDURE EnumeratePath;
			VAR h: Kernel32.HANDLE;  FD: Kernel32.FindData;  ft: Kernel32.FileTime;  st: Kernel32.SystemTime;  i, j, t, d: LONGINT;
			BEGIN
				i := 0;
				WHILE curPath[i] # 0X DO INC( i ) END;
				IF curPath[i - 1] # PathDelimiter THEN curPath[i] := PathDelimiter;  INC( i );  curPath[i] := 0X END;
				j := i - 1;  h := 0;
				WHILE pattern[h] # 0X DO curPath[i] := pattern[h];  INC( i );  INC( h ) END;
				IF h = 0 THEN curPath[i] := "*";  INC( i );  curPath[i] := ".";  INC( i );  curPath[i] := "*";  INC( i ) END;
				curPath[i] := 0X;

				h := Kernel32.FindFirstFile( curPath, FD );  curPath[j] := 0X;  ConvertChar( curPath, PathDelimiter, Files.PathDelimiter ); FixDriveLetter (curPath);
				IF h # Kernel32.InvalidHandleValue THEN
					t := 0;  d := 0;
					REPEAT
						IF Files.EnumTime IN flags THEN
							Kernel32.FileTimeToLocalFileTime( FD.ftLastWriteTime, ft );  Kernel32.FileTimeToSystemTime( ft, st );
							d := LONG( st.wYear - 1900 ) * 200H + LONG( st.wMonth ) * 20H + LONG( st.wDay );  t := LONG( st.wHour ) * 1000H + LONG( st.wMinute ) * 40H + LONG( st.wSecond );
						END;
						Join( curPath, "/", FD.cFileName, longname );
						IF ~(Kernel32.FileAttributeDirectory IN FD.dwFileAttributes) THEN
							enum.PutEntry( longname, {}, t, d, FD.nFileSizeLow )
						ELSIF (FD.cFileName # ".") & ((FD.cFileName # "..")) THEN
							enum.PutEntry( longname, {Files.Directory}, t, d, FD.nFileSizeLow )
						END;
					UNTIL Kernel32.FindNextFile( h, FD ) = Kernel32.False;
					Kernel32.FindClose( h )
				END;
			END EnumeratePath;

		BEGIN {EXCLUSIVE}
			COPY( mask, path );  ConvertChar( path, Files.PathDelimiter, PathDelimiter );  attr := Kernel32.GetFileAttributes( path );  path := "";
			IF (Kernel32.FileAttributeDirectory IN attr) & (~(Kernel32.FileAttributeTemporary IN attr)) THEN COPY( mask, path );  COPY( "*", pattern );  ELSE Files.SplitPath( mask, path, pattern );  END;
			IF TraceFileSystem IN Trace THEN
				KernelLog.String( "Enumerate0: " );   KernelLog.String( mask );  KernelLog.String( " :: " );  KernelLog.String( path );  KernelLog.String( " :: " );  KernelLog.String( pattern );  KernelLog.Ln;
			END;

			IF enum = NIL THEN RETURN
			END;
			IF path = "." THEN COPY( workPath, curPath );  EnumeratePath()
			ELSIF IsLocalPath(path) THEN
				COPY( workPath, curPath );
				IF path # "" THEN
					ConvertChar(curPath, PathDelimiter, Files.PathDelimiter);
					Files.JoinPath(curPath, path, curPath);
					ConvertChar( curPath, Files.PathDelimiter, PathDelimiter );
				END;
				EnumeratePath();
				IF ~useprefix THEN
					i := 0;  j := 0;
					WHILE searchPath[i] # 0X DO
						IF searchPath[i] # ";" THEN curPath[j] := searchPath[i];  INC( j )
						ELSIF j > 0 THEN
							curPath[j] := 0X;
							IF curPath # workPath THEN
								IF path # "" THEN
									ConvertChar(curPath, PathDelimiter, Files.PathDelimiter);
									Files.JoinPath(curPath, path, curPath);
									ConvertChar( curPath, Files.PathDelimiter, PathDelimiter );
								END;
								EnumeratePath()
							END;
							j := 0
						END;
						INC( i )
					END;
					IF j > 0 THEN
						curPath[j] := 0X;
						IF path # "" THEN
							ConvertChar(curPath, PathDelimiter, Files.PathDelimiter);
							Files.JoinPath(curPath, path, curPath);
							ConvertChar( curPath, Files.PathDelimiter, PathDelimiter );
						END;
						IF curPath # workPath THEN EnumeratePath() END
					END;
				END;
			ELSE (* path is an absolute path *)
				COPY( path, curPath );  ConvertChar( curPath, Files.PathDelimiter, PathDelimiter );  EnumeratePath()
			END;
		END Enumerate1;

		PROCEDURE FileKey( name: ARRAY OF CHAR ): LONGINT;
		VAR fname: FileName;  F: File;
		BEGIN {EXCLUSIVE}
			(*RETURN 0;  (* Finalizers may steal file *) *)

			IF name = "" THEN RETURN 0 END;

			IF TraceFileSystem IN Trace THEN KernelLog.String( "FileKey " );  KernelLog.String( name );  KernelLog.Ln;
			END;
			ConvertChar( name, Files.PathDelimiter, PathDelimiter );
			IF FindFile( name, fname ) (* OR FullPathName(name,fname) *) THEN
				F := collection.ByNameNotGC( fname );
				IF F # NIL THEN RETURN F.key END
			ELSIF TraceFileSystem IN Trace THEN KernelLog.String( "not found: " );  KernelLog.String( name );  KernelLog.String( "(" );  KernelLog.String( fname );  KernelLog.String( ")" );  KernelLog.Ln;
			END;
			IF TraceFileSystem IN Trace THEN KernelLog.String( "no key: " );  KernelLog.String( name );  KernelLog.String( "(" );  KernelLog.String( fname );  KernelLog.String( ")" );  KernelLog.Ln;  END;
			RETURN 0

		END FileKey;

		PROCEDURE CreateDirectory0( name: ARRAY OF CHAR;  VAR res: LONGINT );
		VAR ret: Kernel32.BOOL;
		BEGIN {EXCLUSIVE}
			ConvertChar( name, Files.PathDelimiter, PathDelimiter );  ret := Kernel32.CreateDirectory( name, NIL );
			IF ret # 0 THEN 
				res := 0 
			ELSIF Kernel32.GetLastError() = 183 (*ERROR_ALREADY_EXISTS*) THEN res := Files.FileAlreadyExists;
			ELSE res := 1 END
		END CreateDirectory0;

		PROCEDURE RemoveDirectory0( name: ARRAY OF CHAR;  force: BOOLEAN;  VAR key, res: LONGINT );
		VAR ret: Kernel32.BOOL;
		BEGIN {EXCLUSIVE}
			ConvertChar( name, Files.PathDelimiter, PathDelimiter );  key := 0;  res := 1;
			IF ~force THEN
				ret := Kernel32.RemoveDirectory( name );
				IF ret # 0 THEN res := 0 END
			ELSE res := -1
			END
		END RemoveDirectory0;

		PROCEDURE Finalize;
		BEGIN
			collection.Finalize();
		END Finalize;

	END WinFileSystem;

	Buffer = POINTER TO RECORD
		data: ARRAY BufferSize OF CHAR;
		apos, len: LONGINT;
		dirty: BOOLEAN
	END;

	File* = OBJECT (Files.File)
	VAR fname: FileName;
		tfname: PFileName;
		hfile: Kernel32.HANDLE;
		buffer: Buffer;
		fsize, fpos: LONGINT;
		fileSystem: WinFileSystem;

		PROCEDURE & Init*( VAR name: ARRAY OF CHAR;  hfile: Kernel32.HANDLE;  key: LONGINT ; fs: WinFileSystem);
		VAR s: SET;  res: Kernel32.BOOL;
		BEGIN
			IF TraceFile IN Trace THEN KernelLog.String( "Init: " );  KernelLog.String( name );  KernelLog.String( " (" );  KernelLog.Int( key, 1 );  KernelLog.String( ")" );  KernelLog.Ln;  END;
			SELF.key := key;  fpos := 0;  SELF.hfile := hfile;  COPY( name, SELF.fname );  tfname := NIL;
			IF hfile # Kernel32.InvalidHandleValue THEN
				fsize := Kernel32.GetFileSize( hfile, NIL );  ASSERT( fsize >= 0 );  s := Kernel32.GetFileAttributes( name );
				IF Kernel32.FileAttributeTemporary IN s THEN EXCL( s, Kernel32.FileAttributeTemporary );  res := Kernel32.SetFileAttributes( name, s );  ASSERT( res # 0 );  s := Kernel32.GetFileAttributes( name ) END;
				flags := FileFlags( s )
			ELSE flags := {Temporary};  fsize := 0
			END;
			IF buffer = NIL THEN NEW( buffer );  END;
			buffer.apos := -1;  buffer.len := 0;  buffer.dirty := FALSE;
			fileSystem := fs
		END Init;

		PROCEDURE Set( VAR r: Files.Rider;  pos: LONGINT );
		VAR size: LONGINT;
		BEGIN {EXCLUSIVE}
			IF hfile # Kernel32.InvalidHandleValue THEN
				size := Kernel32.GetFileSize( hfile, NIL );   (* maybe Windows has modified the file since last access, but we ignore file changes once the file rider is set *)
				IF size > fsize THEN fsize := size END;
			END;
			r.eof := FALSE;  r.res := 0;  r.file := SELF;  r.fs := fs;
			IF pos < 0 THEN pos := 0
			ELSIF pos > fsize THEN pos := fsize
			END;
			r.apos := pos DIV BufferSize;  r.bpos := pos MOD BufferSize
		END Set;

		PROCEDURE Pos( VAR r: Files.Rider ): LONGINT;
		BEGIN
			RETURN r.apos * BufferSize + r.bpos
		END Pos;

		PROCEDURE WriteBuffer;
		VAR pos, n: LONGINT;  res: Kernel32.BOOL;
		BEGIN
			ASSERT( buffer.dirty );  ASSERT( buffer.len > 0 );  pos := buffer.apos * BufferSize;
			IF hfile = Kernel32.InvalidHandleValue THEN
				ASSERT( Temporary IN flags );  NEW( tfname );  TempName( tfname^ );
				hfile := Kernel32.CreateFile( tfname^, {Kernel32.GenericRead, Kernel32.GenericWrite}, {Kernel32.FileShareRead}, NIL , Kernel32.CreateAlways, {Kernel32.FileAttributeTemporary}, 0 );
				ASSERT( hfile # Kernel32.InvalidHandleValue );  fpos := 0
			END;
			IF fpos # pos THEN fpos := Kernel32.SetFilePointer( hfile, pos, NIL , Kernel32.FileBegin );  ASSERT( fpos = pos ) END;
			res := Kernel32.WriteFile( hfile, buffer.data, buffer.len, n, NIL );
			IF (res = 0) & ~(ReadOnly IN flags) THEN
				res := Kernel32.CloseHandle( hfile );
				IF TraceFile IN Trace THEN KernelLog.String( "closed handle of " );  KernelLog.String( fname );  KernelLog.Ln;  END;
				hfile :=
					Kernel32.CreateFile( fname, {Kernel32.GenericRead, Kernel32.GenericWrite}, {Kernel32.FileShareRead, Kernel32.FileShareWrite}, NIL , Kernel32.OpenExisting, {Kernel32.FileAttributeNormal}, 0 );
				ASSERT( hfile # Kernel32.InvalidHandleValue );  fpos := Kernel32.SetFilePointer( hfile, pos, NIL , Kernel32.FileBegin );  ASSERT( fpos = pos );
				res := Kernel32.WriteFile( hfile, buffer.data, buffer.len, n, NIL )
			END;
			ASSERT( (res # 0) & (n = buffer.len) );  INC( fpos, n );  buffer.dirty := FALSE
		END WriteBuffer;

		PROCEDURE ReadBuffer( apos: LONGINT );
		VAR pos, n: LONGINT;  res: Kernel32.BOOL;
		BEGIN
			IF buffer.dirty THEN WriteBuffer() END;
			pos := apos * BufferSize;
			IF pos >= fsize THEN buffer.apos := apos;  buffer.len := 0;  RETURN END;
			IF fpos # pos THEN
				fpos := Kernel32.SetFilePointer( hfile, pos, NIL , Kernel32.FileBegin );
				IF (fpos # pos) THEN KernelLog.String( "failed to set buffer: " );  KernelLog.String( fname );  KernelLog.Ln END;
				ASSERT( fpos = pos )
			END;
			res := Kernel32.ReadFile( hfile, buffer.data, BufferSize, n, NIL );
			IF res = 0 THEN KernelLog.String( "read file did not work for: " );  KernelLog.String( fname );  KernelLog.Ln;  END;
			ASSERT( res # 0 );  INC( fpos, n );  buffer.apos := apos;  buffer.len := n
		END ReadBuffer;

		PROCEDURE Read( VAR r: Files.Rider;  VAR x: CHAR );
		VAR pos: LONGINT;
		BEGIN {EXCLUSIVE}
			pos := r.apos * BufferSize + r.bpos;
			IF pos < fsize THEN
				IF buffer.apos # r.apos THEN ReadBuffer( r.apos ) END;
				x := buffer.data[r.bpos];  INC( pos );  r.apos := pos DIV BufferSize;  r.bpos := pos MOD BufferSize
			ELSE
				x := 0X; r.eof := TRUE
			END
		END Read;

		PROCEDURE ReadBytes( VAR r: Files.Rider;  VAR x: ARRAY OF CHAR;  ofs, len: LONGINT );
		VAR pos, n: LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT( (ofs + len) <= LEN( x ) );
			pos := r.apos * BufferSize + r.bpos;
			WHILE (len > 0) & (pos < fsize) DO
				IF buffer.apos # r.apos THEN ReadBuffer( r.apos ) END;
				n := buffer.len - r.bpos;
				IF (n > 0) THEN
					IF n > len THEN n := len END;
					SYSTEM.MOVE( ADDRESSOF( buffer.data[r.bpos] ), ADDRESSOF( x[ofs] ), n );
					INC( pos, n );  INC( ofs, n );  DEC( len, n );
					r.apos := pos DIV BufferSize;  r.bpos := pos MOD BufferSize;
				ELSE
					pos := fsize;
				END;
			END;
			r.res := len; r.eof := (pos > fsize) OR ((pos = fsize) & (len > 0));
		END ReadBytes;

		PROCEDURE Write( VAR r: Files.Rider;  x: CHAR );
		VAR pos: LONGINT;
		BEGIN {EXCLUSIVE}
			pos := r.apos * BufferSize + r.bpos;
			IF buffer.apos # r.apos THEN ReadBuffer( r.apos ) END;
			buffer.data[r.bpos] := x;  INC( pos );
			IF (r.bpos + 1) > buffer.len THEN buffer.len := r.bpos + 1 END;
			r.apos := pos DIV BufferSize;  r.bpos := pos MOD BufferSize;
			IF pos > fsize THEN fsize := pos END;
			buffer.dirty := TRUE;
		END Write;

		PROCEDURE WriteBytes( VAR r: Files.Rider;  CONST x: ARRAY OF CHAR;  ofs, len: LONGINT );
		VAR pos, n: LONGINT;
		BEGIN {EXCLUSIVE}
			IF len = 0 THEN RETURN END;
			ASSERT( (len > 0) & ((ofs + len) <= LEN( x )) );  pos := r.apos * BufferSize + r.bpos;
			WHILE len > 0 DO
				IF buffer.apos # r.apos THEN ReadBuffer( r.apos ) END;
				n := BufferSize - r.bpos;
				IF n > len THEN n := len END;
				SYSTEM.MOVE( ADDRESSOF( x[ofs] ), ADDRESSOF( buffer.data[r.bpos] ), n );
				IF (r.bpos + n) > buffer.len THEN buffer.len := r.bpos + n END;
				INC( pos, n );  INC( ofs, n );  DEC( len, n );  r.apos := pos DIV BufferSize;  r.bpos := pos MOD BufferSize;
				IF pos > fsize THEN fsize := pos END;
				buffer.dirty := TRUE
			END
		END WriteBytes;

		PROCEDURE Length( ): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN fsize
		END Length;

		PROCEDURE GetDate( VAR t, d: LONGINT );
		VAR ft, lft: Kernel32.FileTime;  st: Kernel32.SystemTime;  res: Kernel32.BOOL;
		BEGIN {EXCLUSIVE}
			res := Kernel32.GetFileTime( hfile, NIL , NIL , ft );
			(*
			ASSERT ( res # 0 );   (* <- only if file is not temporary ! *)
			*)
			res := Kernel32.FileTimeToLocalFileTime( ft, lft );  res := Kernel32.FileTimeToSystemTime( lft, st );  d := LONG( st.wYear - 1900 ) * 200H + LONG( st.wMonth ) * 20H + LONG( st.wDay );
			t := LONG( st.wHour ) * 1000H + LONG( st.wMinute ) * 40H + LONG( st.wSecond )
		END GetDate;

		PROCEDURE SetDate( t, d: LONGINT );
		VAR ft, lft: Kernel32.FileTime;  st: Kernel32.SystemTime;  res: Kernel32.BOOL; err: LONGINT;
		BEGIN {EXCLUSIVE}
			st.wDay := SHORT( d MOD 20H );  d := ASH( d, -5 );  st.wMonth := SHORT( d MOD 10H );  d := ASH( d, -4 );  st.wYear := SHORT( d MOD 80H ) + 1900;  st.wMilliseconds := 0;
			st.wSecond := SHORT( t MOD 40H );  t := ASH( t, -6 );  st.wMinute := SHORT( t MOD 40H );  t := ASH( t, -6 );  st.wHour := SHORT( t MOD 20H );  res := Kernel32.SystemTimeToFileTime( st, lft );
			res := Kernel32.LocalFileTimeToFileTime( lft, ft );  res := Kernel32.SetFileTime( hfile, NIL , NIL , ft );
			IF res = 0 THEN err := Kernel32.GetLastError(); DebugFile(SELF) END;
			ASSERT( res # 0 )
		END SetDate;

		PROCEDURE GetAttributes(): SET;
		VAR s: SET;
		BEGIN
			s := Kernel32.GetFileAttributes( fname );
			RETURN FileFlags(s);
		END GetAttributes;

		PROCEDURE SetAttributes(a: SET);
		VAR s: SET;
		BEGIN
			s:= WindowsFlags(a);
			SetFileAttributes(fname,s);
		END SetAttributes;

		PROCEDURE GetName( VAR name: ARRAY OF CHAR );
		VAR i: LONGINT;  ch: CHAR;
		BEGIN {EXCLUSIVE}
			COPY( fname, name );  i := 0;  ch := name[0];
			WHILE ch # 0X DO
				IF ch = PathDelimiter THEN name[i] := Files.PathDelimiter END;
				INC( i );  ch := name[i]
			END
		END GetName;

		PROCEDURE ToTemp( ): BOOLEAN;
		VAR tfname: PFileName;  res: Kernel32.BOOL;
			from, to: ARRAY 256 OF CHAR;
		BEGIN {EXCLUSIVE}
			ASSERT( ~(Temporary IN flags) );
			(*ALEX 2005.12.08*)
			IF hfile = Kernel32.InvalidHandleValue THEN
				hfile := Kernel32.CreateFile( fname, {Kernel32.GenericRead}, {Kernel32.FileShareRead, Kernel32.FileShareWrite}, NIL , Kernel32.CreateAlways, {Kernel32.FileAttributeNormal}, 0 );
			END;
			IF hfile = Kernel32.InvalidHandleValue THEN
				hfile := Kernel32.CreateFile( fname, {Kernel32.GenericRead}, {Kernel32.FileShareRead, Kernel32.FileShareWrite}, NIL , Kernel32.OpenExisting, {Kernel32.FileAttributeNormal}, 0 );
			END;
			IF buffer.dirty THEN WriteBuffer() END;
			(*
			IF hfile # Kernel32.InvalidHandleValue THEN
			*)
			ASSERT( hfile # Kernel32.InvalidHandleValue );  fsize := Kernel32.GetFileSize( hfile, NIL );  res := Kernel32.CloseHandle( hfile );  hfile := Kernel32.InvalidHandleValue;
			(*
			END;
			*)
			NEW( tfname );  TempName( tfname^ );  COPY( fname, from );  COPY( tfname^, to );
			IF TraceFile IN Trace THEN KernelLog.String( "toTemp: " );  KernelLog.String( fname );  KernelLog.String( " => " );  KernelLog.String( tfname^ );  KernelLog.Ln;  END;
			IF ~MoveFile( fname, tfname^ ) THEN HALT( 1241 ) (* RETURN FALSE *) END;
			winFS.collection.Unregister( SELF );
			hfile := Kernel32.CreateFile( tfname^, {Kernel32.GenericRead, Kernel32.GenericWrite}, {Kernel32.FileShareRead}, NIL , Kernel32.OpenExisting, {Kernel32.FileAttributeTemporary}, 0 );
			(* IF hfile = Kernel32.InvalidHandleValue THEN RETURN FALSE END; *)
			ASSERT( hfile # Kernel32.InvalidHandleValue );  fsize := Kernel32.GetFileSize( hfile, NIL );  ASSERT( fsize >= 0 );  SELF.tfname := tfname;  COPY( tfname^, fname );  RETURN TRUE;
		END ToTemp;

		PROCEDURE Register0( VAR res: LONGINT );
		VAR F: File;  ret: Kernel32.BOOL;
			from, to: ARRAY 256 OF CHAR;
		BEGIN {EXCLUSIVE}
			IF ~(Temporary IN flags) OR (fname = "") THEN res := 1;  RETURN END;
			IF buffer.dirty THEN WriteBuffer() END;
			IF hfile # Kernel32.InvalidHandleValue THEN ret := Kernel32.CloseHandle( hfile );  hfile := Kernel32.InvalidHandleValue END;
			IF TraceFile IN Trace THEN KernelLog.String( "Register:  existing?: " );  KernelLog.String( fname );  KernelLog.Ln;  END;
			F := winFS.collection.ByName( fname );
			IF (TraceFile IN Trace) & (F = NIL ) THEN KernelLog.String( "Register: not existing: " );  KernelLog.String( fname );  KernelLog.Ln;  END;
			IF (F # NIL ) THEN
				IF ~F.ToTemp() THEN res := 1;  RETURN END
			END;   (* registered file stays alive for its users *)

			IF tfname # NIL THEN
				COPY( tfname^, from );  COPY( fname, to );
				IF ~MoveFile( tfname^, fname ) THEN
					(* first try closing file -> for windows versions < 2000 *)
					res := 1;  RETURN;
					(* HALT( 1242 )*)
				END;
				hfile := Kernel32.CreateFile( fname, {Kernel32.GenericRead, Kernel32.GenericWrite}, {Kernel32.FileShareRead, Kernel32.FileShareWrite}, NIL , Kernel32.OpenExisting, {Kernel32.FileAttributeNormal}, 0 )
			ELSE hfile := Kernel32.CreateFile( fname, {Kernel32.GenericRead, Kernel32.GenericWrite}, {Kernel32.FileShareRead, Kernel32.FileShareWrite}, NIL , Kernel32.CreateAlways, {Kernel32.FileAttributeNormal}, 0 )
			END;
			IF hfile = Kernel32.InvalidHandleValue THEN res := 1;  RETURN END;
			ASSERT( hfile # Kernel32.InvalidHandleValue );  winFS.collection.Register( SELF );  res := 0
		END Register0;

		PROCEDURE Update;
		BEGIN {EXCLUSIVE}
			IF buffer.dirty THEN WriteBuffer() END
		END Update;

		PROCEDURE Finalize*;
		VAR res: Kernel32.BOOL;
		BEGIN {EXCLUSIVE}
			IF TraceFile IN Trace THEN KernelLog.String( "File.Finalize " );  KernelLog.String( fname );  KernelLog.Ln;  END;
			IF hfile # Kernel32.InvalidHandleValue THEN
				IF ~(Temporary IN flags) & buffer.dirty THEN WriteBuffer() END;

				res := Kernel32.CloseHandle( hfile );  hfile := Kernel32.InvalidHandleValue;
				IF (Temporary IN flags) & (tfname # NIL ) THEN
					res := Kernel32.DeleteFile( tfname^ );
					(*
					KernelLog.String("Deleted: "); KernelLog.String(tfname^); KernelLog.Ln;
					IF res = 0 THEN KernelLog.String("failed!"); KernelLog.Ln; END;
					*)
					(* ASSERT ( res # 0 ) *)
				END;
				(* ASSERT ( res # 0 ) *)

			END
		END Finalize;

		PROCEDURE Close;
		BEGIN
			Finalize;
			fileSystem.collection.oldFiles.Remove(SELF);
		END Close;


	END File;
VAR
	winFS: WinFileSystem;   (* must be unique *)


	PROCEDURE DebugFile(f: File);
	BEGIN
		KernelLog.String("fname = "); KernelLog.String(f.fname); KernelLog.Ln;
		KernelLog.String("tname = "); IF f.tfname # NIL THEN KernelLog.String(f.tfname^) ELSE KernelLog.String("(NIL)") END; KernelLog.Ln;
		KernelLog.String("hfile = "); KernelLog.Address(f.hfile); KernelLog.Ln;
		KernelLog.String("fsize = "); KernelLog.Int(f.fsize, 1); KernelLog.Ln;
		KernelLog.String("fpos = "); KernelLog.Int(f.fpos, 1); KernelLog.Ln;
	END DebugFile;


	PROCEDURE IsLocalPath(path: ARRAY OF CHAR): BOOLEAN;
	VAR prefix, name: Files.FileName;
	BEGIN
		ConvertChar(path, PathDelimiter, Files.PathDelimiter);
		Files.SplitName(path, prefix, name);
		RETURN (prefix = "") & (name[0] # "/")
	END IsLocalPath;


	(* WinAPI functions like e.g. GetCurrentDirectory sometimes yield paths with drive letters in lowercase
	   which have to be capitalized as they are mapped as filesystems which themselves are case sensitive *)
	PROCEDURE FixDriveLetter (VAR path: ARRAY OF CHAR);
	BEGIN
		IF (LEN (path) >= 2) & (path[0] # 0X) & (path[1] = ':') THEN path[0] := CAP (path[0]) END;
	END FixDriveLetter;

	PROCEDURE MoveFile( VAR from, to: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		IF Kernel32.MoveFileEx( from, to, {Kernel32.MoveFileReplaceExisting, Kernel32.MoveFileCopyAllowed} ) = Kernel32.False THEN
			IF Kernel32.CopyFile( from, to, Kernel32.False ) = Kernel32.False THEN
				IF TraceFile IN Trace THEN KernelLog.String( "could not copy" );  KernelLog.Ln;  END;
				RETURN FALSE
			ELSE
				IF Kernel32.DeleteFile( from ) = Kernel32.False THEN
				END;
				RETURN TRUE;   (* warning: Could not delete file ! *)
			END
		ELSE RETURN TRUE
		END
	END MoveFile;

	PROCEDURE UpperCase( VAR src, dst: ARRAY OF CHAR );
	VAR i: LONGINT;  ch: CHAR;
	BEGIN
		i := 0;  ch := src[0];
		WHILE ch # 0X DO
			IF (ch >= "a") & (ch <= "z") THEN ch := CAP( ch ) END;
			dst[i] := ch;  INC( i );  ch := src[i]
		END;
		dst[i] := 0X
	END UpperCase;

	PROCEDURE TempName( VAR name: ARRAY OF CHAR );
	VAR temp: FileName;
		pref: ARRAY 4 OF CHAR;
		ret: LONGINT;
	BEGIN
		ret := Kernel32.GetTempPath( LEN( temp ), temp );  ASSERT( ret > 0 );  pref := "Aos";  ret := Kernel32.GetTempFileName( temp, pref, 0, name ); FixDriveLetter (name); ASSERT( ret # 0 )
	END TempName;

	PROCEDURE FullPathName( name: ARRAY OF CHAR;  VAR fname: ARRAY OF CHAR ): BOOLEAN;
	VAR i, fp: LONGINT;
	BEGIN
		i := Kernel32.GetFullPathName( name, Kernel32.MaxPath, fname, fp );
		FixDriveLetter (fname); RETURN i > 0
	END FullPathName;

	(* convert flags from windows file flags to A2 file flags *)
	PROCEDURE FileFlags( flags: SET ): SET;
	VAR s: SET;
	BEGIN
		s := {};
		IF Kernel32.FileAttributeDirectory IN flags THEN INCL( s, Directory ) END;
		IF Kernel32.FileAttributeReadonly IN flags THEN INCL( s, ReadOnly ) END;
		IF Kernel32.FileAttributeHidden IN flags THEN INCL( s, Hidden ) END;
		IF Kernel32.FileAttributeSystem IN flags THEN INCL( s, System ) END;
		IF Kernel32.FileAttributeArchive IN flags THEN INCL( s, Archive ) END;
		IF Kernel32.FileAttributeTemporary IN flags THEN INCL( s, Temporary ) END;
		RETURN s
	END FileFlags;

	(* convert flags from A2 file flags to windows file flags *)
	PROCEDURE WindowsFlags(flags: SET): SET;
	VAR s: SET;
	BEGIN
		s := {};
		IF  Directory IN flags THEN INCL( s,  Kernel32.FileAttributeDirectory) END;
		IF ReadOnly IN flags THEN INCL( s,  Kernel32.FileAttributeReadonly ) END;
		IF Hidden IN flags THEN INCL( s,  Kernel32.FileAttributeHidden) END;
		IF System IN flags THEN INCL( s,  Kernel32.FileAttributeSystem) END;
		IF Archive IN flags THEN INCL( s,  Kernel32.FileAttributeArchive) END;
		IF Temporary IN flags THEN INCL( s,  Kernel32.FileAttributeTemporary) END;
		RETURN s
	END WindowsFlags;


(** Generate a new file system object.  Files.NewVol has volume parameter, Files.Par has mount prefix. *)
	PROCEDURE NewFS*(context : Files.Parameters);
	VAR fs: AliasFileSystem;
	BEGIN
		IF (Files.This(context.prefix ) = NIL) THEN
			NEW( fs );  fs.vol := context.vol;  Files.Add( fs, context.prefix );
		ELSE
			context.error.String( "Win32FS: " );  context.error.String( context.prefix );  context.error.String( " already in use" );
			context.error.Ln;
		 END;
	END NewFS;

	PROCEDURE Join( a1, a2, a3: ARRAY OF CHAR;  VAR res: ARRAY OF CHAR );
	VAR i, j: LONGINT;
	BEGIN
		i := 0;
		WHILE (a1[i] # 0X) DO res[j] := a1[i];  INC( i );  INC( j ) END;
		i := 0;
		WHILE (a2[i] # 0X) DO res[j] := a2[i];  INC( i );  INC( j ) END;
		i := 0;
		WHILE (a3[i] # 0X) DO res[j] := a3[i];  INC( i );  INC( j ) END;
		res[j] := 0X
	END Join;

(*ALEX 2005.02.10, fof 071008*)
	PROCEDURE MountDrive(CONST drive: ARRAY OF CHAR; context : Commands.Context);
	VAR
		p: Files.Parameters; namebuf1, namebuf2: FileName;  size, snum, mlen, sysfl: LONGINT;
		res: LONGINT; prefix: ARRAY 256 OF CHAR;
	BEGIN
		COPY(drive,prefix);
		size := LEN( namebuf1 );  res := Kernel32.GetVolumeInformation( prefix, namebuf1, size, snum, mlen, sysfl, namebuf2, size );
		IF res = 0 THEN
			IF context# NIL THEN
				context.error.String("Not mounted (no volume information): "); context.error.String(prefix); context.error.Ln;
				context.error.Update;
			END;
		ELSE
			IF (context = NIL) THEN
				NEW(context, NIL, NIL, NIL, NIL, NIL);
			END;
			NEW(p, context.in, context.arg, context.out, context.error, context.caller);
			IF TraceMounting THEN
				context.out.String( "Mounting: " );  context.out.String( drive );
				context.out.String( " (" );  context.out.String( namebuf1 );  context.out.String( "), fs = " );
				context.out.String( namebuf2 );  context.out.Ln;
				context.out.Update;
			END;
			prefix[1] := 0X;
			COPY( prefix, p.prefix );
			NewFS( p );
		END;
	END MountDrive;

	PROCEDURE AutoMountWindowsLogicalDrives( drives: SET );
	(* fof 090221
		implemented asynchronously as it blocked execution on A2 startup for a while;
		now some of the drives may get mounted later in the system,
		should not be a problem since the search path is handled through windows anyway
	*)
	VAR
		AutoMountObject: OBJECT
		VAR prefix: ARRAY 4 OF CHAR;  i: LONGINT; drives: SET;
		PROCEDURE & Init(drives:SET);
		BEGIN
			SELF.drives := drives
		END Init;

		BEGIN {ACTIVE}
			FOR i := 0 TO MAX( SET ) - 1 DO
				IF i IN drives THEN
					prefix := "X:\";  prefix[0] := CHR( ORD( "A" ) + i );
					MountDrive(prefix, NIL);
				END;
			END;
		END;
	BEGIN
		NEW(AutoMountObject,drives);
	END AutoMountWindowsLogicalDrives;

	PROCEDURE UnmountDrive(CONST drive: ARRAY OF CHAR; context : Commands.Context);
	VAR this: Files.FileSystem;
	BEGIN
		this := Files.This( drive );
		IF (this # NIL ) & (this IS AliasFileSystem) THEN
			IF (context # NIL) THEN
				context.out.String( "Auto Unmount: " );  context.out.String( drive );
				context.out.String( ":" );  context.out.Ln;
			ELSE
				KernelLog.String("Auto Unmount: "); KernelLog.String(drive); KernelLog.String(":"); KernelLog.Ln;
			END;
			Files.Remove( this );
		END;
	END UnmountDrive;

	PROCEDURE AutoUnmountLogicalDrives( drives: SET );
	VAR i: LONGINT;
		prefix: ARRAY 4 OF CHAR;
	BEGIN
		FOR i := 0 TO MAX( SET ) - 1 DO
			IF i IN drives THEN
				prefix[0] := CHR( ORD( "A" ) + i );  prefix[1] := 0X;
				UnmountDrive(prefix, NIL);
			END;
		END;
	END AutoUnmountLogicalDrives;

	PROCEDURE Finalization;
	VAR ft: Files.FileSystemTable;  i: LONGINT;
	BEGIN
		Files.GetList( ft );
		IF ft # NIL THEN
			FOR i := 0 TO LEN( ft^ ) - 1 DO
				IF ft[i] IS AliasFileSystem THEN Files.Remove( ft[i] ) END
			END
		END;
		winFS.Finalize;
	END Finalization;

	PROCEDURE FindFile*( name: ARRAY OF CHAR;  VAR fullname: ARRAY OF CHAR ): BOOLEAN;
	VAR ret: LONGINT;  fileName: Kernel32.LPSTR;
	BEGIN
		ret := Kernel32.SearchPath( workPath, name, NIL , LEN( fullname ), fullname, fileName );
		IF (ret <= 0) THEN ret := Kernel32.SearchPath( searchPath, name, NIL , LEN( fullname ), fullname, fileName ) END;
		FixDriveLetter (fullname);
		RETURN ret > 0;
	END FindFile;

	PROCEDURE ConvertChar*( VAR name: ARRAY OF CHAR;  from, to: CHAR );
	VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE name[i] # 0X DO
			IF name[i] = from THEN name[i] := to END;
			INC( i )
		END
	END ConvertChar;

	PROCEDURE SetPaths;
	VAR ret, i, j, k: LONGINT;
		work, files, temp: ARRAY Kernel32.MaxPath OF CHAR;
		directories, dirs: ARRAY 4 * Kernel32.MaxPath OF CHAR;
		dir, sysPath: FileName;

		PROCEDURE SetSysPath(VAR dir: ARRAY OF CHAR);
		VAR ch: CHAR; i: LONGINT;
		BEGIN
			IF (dir[0] = "~") & (dir[1] = PathDelimiter) THEN
				Kernel32.SetCurrentDirectory( sysPath );
				i := 2;
				REPEAT ch := dir[i]; dir[i-2] := ch; INC(i) UNTIL ch = 0X;
			ELSE
				Kernel32.SetCurrentDirectory(workPath) 
			END;
		END SetSysPath;
		

		PROCEDURE AddDir;
		BEGIN
			IF k > 0 THEN
				dir[k] := 0X;
				IF dir[k - 1] = '"' THEN dir[k - 1] := 0X END;
				ConvertChar( dir, Files.PathDelimiter, PathDelimiter );
				SetSysPath(dir);
				IF Kernel32.SetCurrentDirectory( dir ) # Kernel32.False THEN
					Kernel32.GetCurrentDirectory( LEN( dir ), dir );  searchPath[i] := ";";  INC( i );  k := 0;
					WHILE dir[k] # 0X DO searchPath[i] := dir[k];  INC( i );  INC( k ) END
				END;
				k := 0
			END
		END AddDir;

	BEGIN {EXCLUSIVE}
		Machine.GetConfig( "Paths.Files", files ); Machine.GetConfig( "Paths.Search", directories );
		Machine.GetConfig( "Paths.Temp", temp ); Machine.GetConfig( "Paths.Work", work );

		Kernel32.GetCurrentDirectory( LEN( workPath ), workPath );  i := 0;  ret := 0;

		IF files # "" THEN
			COPY( files, sysPath );
			IF Kernel32.SetCurrentDirectory( sysPath ) # Kernel32.False THEN ret := Kernel32.GetCurrentDirectory( LEN( sysPath ), sysPath ) END
		END;
		IF ret = 0 THEN
			Kernel32.GetModuleFileName( Kernel32.hInstance, sysPath, LEN( sysPath ) );  j := -1;
			WHILE sysPath[i] # 0X DO
				IF sysPath[i] = PathDelimiter THEN j := i END;
				INC( i )
			END;
			i := j + 1;  sysPath[i] := 0X;  COPY( sysPath, searchPath )
		ELSE
			WHILE sysPath[i] # 0X DO searchPath[i] := sysPath[i];  INC( i ) END;
			searchPath[i] := 0X
		END;

		COPY( directories, dirs );
		IF dirs[0] = '"' THEN j := 1 ELSE j := 0 END;

		k := 0;
		WHILE dirs[j] # 0X DO
			IF (dirs[j] = ";") OR (dirs[j] < " ") THEN AddDir() ELSE dir[k] := dirs[j];  INC( k ) END;
			INC( j )
		END;
		AddDir();  searchPath[i] := 0X;  ret := 0;

		COPY( temp, tempPath );
		IF tempPath # "" THEN
			ConvertChar( tempPath, Files.PathDelimiter, PathDelimiter );  
			SetSysPath(tempPath);
			IF Kernel32.SetCurrentDirectory( tempPath ) # Kernel32.False THEN ret := Kernel32.GetCurrentDirectory( LEN( tempPath ), tempPath ) END
		END;
		IF ret = 0 THEN Kernel32.GetTempPath( LEN( tempPath ), tempPath ) END;

		COPY( work, dir );
		IF dir # "" THEN
			ConvertChar( dir, Files.PathDelimiter, PathDelimiter );  
			SetSysPath(dir);
			IF Kernel32.SetCurrentDirectory( dir ) # Kernel32.False THEN Kernel32.GetCurrentDirectory( LEN( workPath ), workPath ) END
		END;
		Kernel32.SetCurrentDirectory( workPath );
	END SetPaths;

	PROCEDURE SameName*( VAR a, b: ARRAY OF CHAR ): BOOLEAN;   (** non-portable *)
	VAR i, j: LONGINT;
	BEGIN
		i := 0;  j := 0;
		WHILE (a[i] # 0X) & (b[j] # 0X) & (CAP( a[i] ) = CAP( b[j] )) DO INC( i );  INC( j ) END;
		RETURN (a[i] = 0X) & (b[j] = 0X)
	END SameName;

	PROCEDURE CheckPath(fullName: ARRAY OF CHAR ): BOOLEAN;
	VAR i, j: LONGINT;  done: BOOLEAN;
	BEGIN
		i := 0;  j := -1;
		WHILE fullName[i] # 0X DO
			IF fullName[i] = PathDelimiter THEN j := i END;
			INC( i )
		END;
		IF j > 0 THEN fullName[j] := 0X END;
		BEGIN {EXCLUSIVE}
			done := Kernel32.SetCurrentDirectory( fullName ) # Kernel32.False;
			Kernel32.SetCurrentDirectory( workPath );  RETURN done
		END;
	END CheckPath;

	PROCEDURE CheckName*( name: ARRAY OF CHAR ): BOOLEAN;
	VAR fullName: FileName;  fileNamePart: Kernel32.LPSTR;  ret, i: LONGINT;  ch: CHAR;  stream, ok: BOOLEAN;
	BEGIN
		ConvertChar( name, Files.PathDelimiter, PathDelimiter );  ret := Kernel32.GetFullPathName( name, Kernel32.MaxPath, fullName, fileNamePart );
		IF (ret > 0) & CheckPath( fullName ) & (fileNamePart # Kernel32.NULL) THEN
			ok := TRUE;  stream := FALSE;  i := fileNamePart - ADDRESSOF( fullName );  fullName[i - 1] := 0X;  ch := fullName[i];
			WHILE (ch # 0X) & ok DO
				IF ch = ":" THEN
					IF stream THEN ok := FALSE ELSE stream := TRUE END
				ELSIF (ch = ":") OR (ch = "\") OR (ch = "?") OR (ch = "|") OR (ch = ">") OR (ch = "<") OR (ch = "/") OR (ch = "*") OR (ch = '"') THEN ok := FALSE;
				END;
				(* \ / : * ? " < > | *)

				INC( i );  ch := fullName[i]
			END
		ELSE ok := FALSE
		END;
		RETURN ok
	END CheckName;

	PROCEDURE GetAttributes*( file: ARRAY OF CHAR ): SET;   (** non-portable *)
	VAR attrs: SET;
	BEGIN
		ConvertChar( file, Files.PathDelimiter, PathDelimiter );  attrs := Kernel32.GetFileAttributes( file );
		IF attrs = {0..31} THEN RETURN {} ELSE RETURN attrs END
	END GetAttributes;

	PROCEDURE SetAttributes*( file: ARRAY OF CHAR;  attrs: SET );   (** non-portable *)
	BEGIN
		ConvertChar( file, Files.PathDelimiter, PathDelimiter );  Kernel32.SetFileAttributes( file, attrs )
	END SetAttributes;

	PROCEDURE SetFileAttributes*( file: ARRAY OF CHAR;  attrs: SET );   (** non-portable *)
	BEGIN
		ConvertChar( file, Files.PathDelimiter, PathDelimiter );  Kernel32.SetFileAttributes( file, attrs )
	END SetFileAttributes;


(** Get the current directory. *)
	PROCEDURE GetWorkingDirectory*( VAR path: ARRAY OF CHAR );
	BEGIN {EXCLUSIVE}
		Kernel32.GetCurrentDirectory( Kernel32.MaxPath, workPath );  COPY( workPath, path );  ConvertChar( path, PathDelimiter, Files.PathDelimiter ); FixDriveLetter (path);
	END GetWorkingDirectory;

(** Change to directory path. *)
	PROCEDURE ChangeDirectory*( path: ARRAY OF CHAR;  VAR done: BOOLEAN );
	BEGIN {EXCLUSIVE}
		ConvertChar( path, Files.PathDelimiter, PathDelimiter );  done := Kernel32.SetCurrentDirectory( path ) # Kernel32.False;  Kernel32.GetCurrentDirectory( Kernel32.MaxPath, workPath );
	END ChangeDirectory;

(** Get the directory for temporary files. *)
	PROCEDURE GetTempDirectory*( VAR path: ARRAY OF CHAR );
	BEGIN
		COPY( tempPath, path );  ConvertChar( path, PathDelimiter, Files.PathDelimiter )
	END GetTempDirectory;

(** Compute the relative filename (relative to the working directory). *)
	PROCEDURE RelFileName*( fileName: ARRAY OF CHAR;  VAR relFileName: ARRAY OF CHAR );
	VAR i, j, k, p: LONGINT;  fullName: FileName;  fileNamePart: Kernel32.LPSTR;
	BEGIN
		IF ~FindFile( fileName, fullName ) THEN  (* file does not exist -> would be created in the current dir *)
			ConvertChar( fileName, Files.PathDelimiter, PathDelimiter );  Kernel32.GetFullPathName( fileName, Kernel32.MaxPath, fullName, fileNamePart ); FixDriveLetter (fullName);
		ELSE ConvertChar( fullName, Files.PathDelimiter, PathDelimiter )
		END;   (* from here on all with PathDelimiter and drive letter *)
 		IF CAP( workPath[0] ) # CAP( fullName[0] ) THEN  (* different drive letters -> nothing to be done *)
			COPY( fullName, relFileName )
		ELSE
			i := 0;  j := -1;  p := 0;
			WHILE CAP( fullName[i] ) = CAP( workPath[i] ) DO
				IF workPath[i] = PathDelimiter THEN j := i END;
				INC( i )
			END;
			IF workPath[i] = 0X THEN
				IF fullName[i] # PathDelimiter THEN  (* first part of directories do match *)
					relFileName[p] := ".";  relFileName[p + 1] := ".";  relFileName[p + 2] := PathDelimiter;  INC( p, 3 );  INC( j );
					WHILE fullName[j] # 0X DO relFileName[p] := fullName[j];  INC( j );  INC( p ) END
				ELSE  (* file is in a subdirectory of the current dir *)
					INC( i );
					WHILE fullName[i] # 0X DO relFileName[p] := fullName[i];  INC( i );  INC( p ) END
				END
			ELSIF j > 2 THEN  (* first part of directories do match *)
				k := j;  i := j + 1;
				WHILE workPath[k] # 0X DO
					IF workPath[k] = PathDelimiter THEN relFileName[p] := ".";  relFileName[p + 1] := ".";  relFileName[p + 2] := PathDelimiter;  INC( p, 3 ) END;
					INC( k )
				END;
				WHILE fullName[i] # 0X DO relFileName[p] := fullName[i];  INC( i );  INC( p ) END
			ELSE  (* only drive letters match *)
				i := j;
				WHILE fullName[i] # 0X DO relFileName[p] := fullName[i];  INC( i );  INC( p ) END
			END;
			relFileName[p] := 0X
		END;
		ConvertChar( relFileName, PathDelimiter, Files.PathDelimiter )
	END RelFileName;

	PROCEDURE DeviceNotification*( type: LONGINT;  drives: SET );
	VAR n: Notification;
	BEGIN
		IF type = deviceArrival THEN AutoMountWindowsLogicalDrives( drives );
		ELSIF type = deviceRemove THEN AutoUnmountLogicalDrives( drives );
		ELSE
			(* scan for changes *)
		END;
		n := notifications;
		WHILE(n#NIL) DO
			n.p(type,drives);
			n := n.next;
		END;
	END DeviceNotification;

	PROCEDURE RegisterNotification*( p: NotificationProc );
	VAR n: Notification;
	BEGIN
		NEW( n );  n.p := p;  n.next := notifications;  notifications := n;
	END RegisterNotification;

	PROCEDURE Init;
	VAR
		i, j: LONGINT;  sysPath: FileName;  p: Files.Parameters;  drives: SET;  fs : Files.FileSystem;
	BEGIN
		NEW( winFS );

		NEW( p, NIL, NIL, NIL, NIL, NIL);  p.prefix := "searcher";
		NewFS( p );

		fs := Files.This(p.prefix);
		IF (fs # NIL) & (fs IS AliasFileSystem) THEN
			fs( AliasFileSystem ).useprefix := FALSE;
			EXCL( fs( AliasFileSystem ).flags, Files.NeedsPrefix );
		END;

		(* now the file system is installed *)

		drives := Kernel32.GetLogicalDrives();
		drives := drives - {0,1}; (* do not scan for diskettes *)
		AutoMountWindowsLogicalDrives( drives );

		Kernel32.GetCurrentDirectory( LEN( workPath ), workPath );  i := 0;  Kernel32.GetModuleFileName( Kernel32.hInstance, sysPath, LEN( sysPath ) );  j := -1;
		FixDriveLetter (workPath); FixDriveLetter (sysPath);
		WHILE sysPath[i] # 0X DO
			IF sysPath[i] = PathDelimiter THEN j := i END;
			INC( i )
		END;

		i := j + 1;  sysPath[i] := 0X;  COPY( sysPath, searchPath );  Kernel32.GetTempPath( LEN( tempPath ), tempPath );  Kernel32.SetCurrentDirectory( workPath );

		notifications := NIL;
	END Init;

	PROCEDURE Mount*(context : Commands.Context);
	VAR diskname: ARRAY 256 OF CHAR;
	BEGIN
		context.arg.SkipWhitespace;
		context.arg.String(diskname);
		MountDrive(diskname, context);
	END Mount;

	PROCEDURE Unmount*(context : Commands.Context);
	VAR diskname: ARRAY 256 OF CHAR;
	BEGIN
		context.arg.SkipWhitespace;
		context.arg.String(diskname);
		UnmountDrive(diskname, context);
	END Unmount;

BEGIN
	Init();  Modules.InstallTermHandler( Finalization ); SetPaths;
END WinFS.
