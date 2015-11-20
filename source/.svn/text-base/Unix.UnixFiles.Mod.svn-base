(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE UnixFiles;   (** AUTHOR "gf"; PURPOSE "Unix file systems" *)

(*  derived fron (SPARCOberon) Files.Mod by J. Templ 1.12. 89/14.05.93 *)

IMPORT S := SYSTEM, Unix, Machine, Heaps, Objects, Kernel, Modules, Log := KernelLog, Files;


CONST
	NBufs = 4;  Bufsize = 4096;  FileTabSize = 1024;  ResFiles = 128;  NoDesc = -1;

	Open = 0;  Create = 1;  Closed = 2;	(* file states *)
	
	NoKey = -1;
	
VAR
	fileTab: ARRAY FileTabSize OF RECORD  f {UNTRACED}: File  END;
	tempno: INTEGER;
	openfiles: INTEGER;
	
	searchPath: ARRAY 1024 OF CHAR;
	cwd: ARRAY 256 OF CHAR;
	
	unixFS: UnixFileSystem;

TYPE	
	Filename = ARRAY 256 OF CHAR;
	
	NameSet = OBJECT
			VAR
				name: ARRAY 64 OF CHAR;
				left, right: NameSet;

				PROCEDURE Add( CONST filename: ARRAY OF CHAR ): BOOLEAN;
					(* add filename if it not already exists. else return false *)
				BEGIN
					IF filename = name THEN  RETURN FALSE  END;
					IF filename < name THEN
						IF left = NIL THEN  NEW( left, filename );  RETURN TRUE
						ELSE  RETURN left.Add( filename )
						END
					ELSE
						IF right = NIL THEN  NEW( right, filename );  RETURN TRUE
						ELSE  RETURN right.Add( filename )
						END
					END
				END Add;

				PROCEDURE & Init( CONST filename: ARRAY OF CHAR );
				BEGIN
					COPY( filename, name );
					left := NIL; right := NIL
				END Init;

			END NameSet;
			
	AliasFileSystem = OBJECT (Files.FileSystem)
		VAR 
			fs: UnixFileSystem;
	
			PROCEDURE & Init*( realFS: UnixFileSystem);
			BEGIN
				SELF.fs := realFS;  
			END Init;

			PROCEDURE New0( name: ARRAY OF CHAR ): Files.File;
			VAR f: Files.File;
			BEGIN
				f := fs.New0( name ); 
				IF f # NIL THEN  f.fs := SELF  END;  
				RETURN f;
			END New0;

			PROCEDURE Old0( name: ARRAY OF CHAR ): Files.File;
			VAR f: Files.File;
			BEGIN
				f :=  fs.Old0( name ); 
				IF f # NIL THEN  f.fs := SELF  END; 
				RETURN f;
			END Old0;

			PROCEDURE Delete0( name: ARRAY OF CHAR;  VAR key, res: LONGINT );
			BEGIN
				fs.Delete0( name, key, res );
			END Delete0;

			PROCEDURE Rename0( old, new: ARRAY OF CHAR;  fold: Files.File;  VAR res: LONGINT );
			BEGIN
				fs.Rename0( old, new, fold, res );
			END Rename0;

			PROCEDURE Enumerate0( mask: ARRAY OF CHAR;  flags: SET;  enum: Files.Enumerator );
			BEGIN
				fs.Enumerate0( mask, flags, enum );
			END Enumerate0;

			PROCEDURE FileKey( name: ARRAY OF CHAR ): LONGINT;
			VAR 
			BEGIN
				RETURN fs.FileKey( name );
			END FileKey;

			PROCEDURE CreateDirectory0( name: ARRAY OF CHAR;  VAR res: LONGINT );
			BEGIN
				fs.CreateDirectory0( name, res );
			END CreateDirectory0;

			PROCEDURE RemoveDirectory0( name: ARRAY OF CHAR;  force: BOOLEAN;  VAR key, res: LONGINT );
			BEGIN
				fs.RemoveDirectory0( name, force, key, res );
			END RemoveDirectory0;

	END AliasFileSystem;
		

	UnixFileSystem* = OBJECT (Files.FileSystem)

				PROCEDURE & Init;
				BEGIN
					prefix := "";  vol := NIL;  desc := "UnixFS"
				END Init;


				PROCEDURE New0*( name: ARRAY OF CHAR ): Files.File;
				VAR f: File;
				BEGIN {EXCLUSIVE}
					AwaitFinalizingDone;
					NEW( f, SELF );
					f.workName := "";  COPY( name, f.registerName );
					f.fd := NoDesc;  f.state := Create;  f.fsize := 0;  f.fpos := 0;
					f.swapper := -1;   (*all f.buf[i] = NIL*)
					f.key := NoKey;  f.fs := SELF;
					RETURN f
				END New0;
				
				
				PROCEDURE IsDirectory( VAR stat: Unix.Status ): BOOLEAN;
				VAR mode: LONGINT;
				BEGIN
					mode := stat.mode;
					RETURN ODD( mode DIV 4000H )
				END IsDirectory;


				PROCEDURE Old0*( name: ARRAY OF CHAR ): Files.File;
				VAR f: File;  stat: Unix.Status;  fd, r, errno, pos: LONGINT;
					oflags: SET;  nextdir, path: Filename; 
				BEGIN  {EXCLUSIVE}
					IF name = "" THEN  RETURN NIL  END;
					
					IF IsFullName( name ) THEN  
						COPY( name, path );  nextdir := "";  
					ELSE
						pos := 0;  ScanPath( pos, nextdir );  MakePath( nextdir, name, path );
						ScanPath( pos, nextdir )
					END;
					
					IF (FileTabSize - openfiles) < ResFiles THEN  GC   END;
						
					LOOP
						r := Unix.access( ADDRESSOF( path ), Unix.R_OK );
						IF r >= 0 THEN
							r := Unix.access( ADDRESSOF( path ), Unix.W_OK );
							IF r < 0 THEN  oflags := Unix.rdonly  ELSE  oflags := Unix.rdwr  END;
							
							fd := Unix.open( ADDRESSOF( path ), oflags, {} );  errno := Unix.errno();
							IF ((fd < 0) & (errno IN {Unix.ENFILE, Unix.EMFILE})) OR (fd >= FileTabSize) THEN
								IF fd > 0 THEN  r := Unix.close( fd )  END;
								GC ;
								fd := Unix.open( ADDRESSOF( path ), oflags, {} );  errno := Unix.errno();
							END;

							IF fd >= 0 THEN
								r := Unix.fstat( fd, stat );
								f := FindCachedEntry( stat );
								IF f # NIL THEN
									(* use the file already cached *)  r := Unix.close( fd );  EXIT
								ELSIF fd < FileTabSize THEN
									AwaitFinalizingDone;
									NEW( f, SELF );
									f.fd := fd;  f.dev := stat.dev;  f.ino := stat.ino;  
									f.mtime := stat.mtime.sec;  f.fsize := stat.size;  f.fpos := 0;  
									f.state := Open;  f.swapper := -1;   (*all f.buf[i] = NIL*)
									COPY( path, f.workName );  f.registerName := "";  
									f.tempFile := FALSE;
									IF IsDirectory( stat ) THEN
										f.flags := {Files.Directory, Files.ReadOnly}
									ELSIF oflags = Unix.rdonly THEN
										f.flags := {Files.ReadOnly}
									END;
									f.key := NoKey;  f.fs := SELF;
									fileTab[fd].f := f;  (* cache file *)
									INC( openfiles );  RegisterFinalizer( f, Cleanup );
									EXIT
								ELSE  
									r := Unix.close( fd );  
									Halt( f, FALSE, "UnixFiles.File.Old0: too many files open" );
								END
							END
						ELSIF nextdir # "" THEN
							MakePath( nextdir, name, path );  ScanPath( pos, nextdir );
						ELSE  
							f := NIL;  EXIT
						END;
					END; (* loop *)
					RETURN f
				END Old0;

				(** Return the unique non-zero key of the named file, if it exists. *)
				PROCEDURE FileKey*( name: ARRAY OF CHAR ): LONGINT;
				(* 	Can not be used for Unix files as LONGINT is too small. 
					In the Unix filesystem a file is identified by
					- dev	(64 bit (Linux), 32 bit (Solaris, Darwin))	+
					- ino	(32 bit)
				*)
				BEGIN
					RETURN 0
				END FileKey;

				PROCEDURE Delete0*( name: ARRAY OF CHAR;  VAR key, res: LONGINT );
				VAR r: LONGINT;
				BEGIN  {EXCLUSIVE}
					r := Unix.unlink( ADDRESSOF( name ) );
					IF r = 0 THEN  res := Files.Ok
					ELSE  res := Unix.errno( )
					END;
					key := 0;
				END Delete0;


				PROCEDURE Rename0*( old, new: ARRAY OF CHAR;  f: Files.File;  VAR res: LONGINT );
				CONST Bufsize = 4096;
				VAR fdold, fdnew, n, r: LONGINT;  ostat, nstat: Unix.Status;
					buf: ARRAY Bufsize OF CHAR;
				BEGIN {EXCLUSIVE}
					r:= Unix.stat( ADDRESSOF( old ), ostat );
					IF r >= 0 THEN
						r := Unix.stat( ADDRESSOF( new ), nstat );
						IF (r >= 0) & (ostat.dev # nstat.dev) OR (ostat.ino # nstat.ino) THEN
							 r := Unix.unlink( ADDRESSOF( new ) )  (* work around stale nfs handles *)
						END;
						r := Unix.rename( ADDRESSOF( old ), ADDRESSOF( new ) );
						IF r < 0 THEN
							res := Unix.errno( );
							IF res = Unix.EXDEV THEN  (* cross device link, move the file *)
								fdold := Unix.open( ADDRESSOF( old ), Unix.rdonly, {} );
								IF fdold < 0 THEN    
									res := Unix.errno( );  RETURN
								END;
								fdnew := Unix.open( ADDRESSOF( new ), Unix.rdwr + Unix.creat + Unix.trunc, Unix.rwrwr );
								IF fdnew < 0 THEN    
									res := Unix.errno( );  RETURN
								END;
								n := Unix.read( fdold, ADDRESSOF( buf ), Bufsize );
								WHILE n > 0 DO
									r := Unix.write( fdnew, ADDRESSOF( buf ), n );
									IF r < 0 THEN
										res := Unix.errno();  
										r := Unix.close( fdold );  r := Unix.close( fdnew );
										RETURN
									END;
									n := Unix.read( fdold, ADDRESSOF( buf ), Bufsize )
								END;
								r := Unix.unlink( ADDRESSOF( old ) );  
								r := Unix.close( fdold );  r := Unix.close( fdnew );  
								res := Files.Ok
							ELSE  
								RETURN  (* res is Unix.rename return code *)
							END
						END;
						res := Files.Ok
					ELSE  
						res := Unix.errno()
					END
				END Rename0;
				

				PROCEDURE CreateDirectory0*( path: ARRAY OF CHAR;  VAR res: LONGINT );
				VAR r: LONGINT;
				BEGIN {EXCLUSIVE}
					r := Unix.mkdir( ADDRESSOF( path ), Unix.rwxrwxrwx );
					IF r = 0 THEN  res := Files.Ok   
					ELSE res := Unix.errno( )
					END	
				END CreateDirectory0;
				

				PROCEDURE RemoveDirectory0*( path: ARRAY OF CHAR;  force: BOOLEAN;  VAR key, res: LONGINT );
				VAR r: LONGINT;
				BEGIN {EXCLUSIVE}
					r := Unix.rmdir( ADDRESSOF( path ) );
					IF r = 0 THEN  res := Files.Ok
					ELSE  res := Unix.errno( )
					END
				END RemoveDirectory0;


				PROCEDURE Enumerate0*( mask: ARRAY OF CHAR;  flags: SET;  enum: Files.Enumerator );
				VAR 
					path, filemask: Filename;
					i, j: INTEGER;  dirName, fileName, fullName: Filename;
					checkSet: NameSet;  ent: Unix.Dirent; 
					
					PROCEDURE GetEntryName;
					VAR i: INTEGER;  adr: ADDRESS;
					BEGIN
						i := -1;  adr := ADDRESSOF( ent.name );
						REPEAT  INC( i );  S.GET( adr, fileName[i] );  INC( adr )  UNTIL fileName[i] = 0X
					END GetEntryName;
					
					PROCEDURE EnumDir( CONST dirName: ARRAY OF CHAR );
					VAR
						dir: ADDRESS;   
						tm: Unix.TmPtr;  date, time: LONGINT;  
						stat: Unix.Status; r: LONGINT;
					BEGIN
						dir := Unix.opendir( ADDRESSOF( dirName ) );
						IF dir # 0 THEN
							ent := Unix.readdir( dir );
							WHILE ent # NIL DO
								COPY( dirName, fullName );  
								GetEntryName;  AppendName( fullName, fileName );
								IF (fileName[0] # '.')  & Match( fileName, filemask, 0, 0 ) THEN
									IF checkSet.Add( fileName ) THEN  (* not a covered name *)
										r := Unix.stat( ADDRESSOF( fullName ), stat );
										tm := Unix.localtime( stat.mtime );
										date := tm.year*200H + (tm.mon + 1)*20H + tm.mday;
										time := tm.hour*1000H + tm.min*40H + tm.sec;
										flags := {};
										IF IsDirectory( stat ) THEN
											flags := {Files.ReadOnly, Files.Directory}
										ELSE
											r := Unix.access( ADDRESSOF( fullName ), Unix.W_OK ); 
											IF r < 0 THEN  flags := {Files.ReadOnly}  END
										END;
										enum.PutEntry( fullName, flags, time, date, stat.size );
									END
								END;
								ent := Unix.readdir( dir );
							END;
							Unix.closedir( dir )
						END;
					END EnumDir;

					
				BEGIN {EXCLUSIVE}
					Files.SplitName( mask, prefix, fullName );
					Files.SplitPath( fullName, path, filemask );
					NEW( checkSet, "M###N" );
					IF path # "" THEN
						CleanPath( path );
						EnumDir( path )
					ELSE
						i := 0;  j := 0;  
						LOOP
							IF (searchPath[i] = " ") OR (searchPath[i] = 0X) THEN
								dirName[j] := 0X;
								EnumDir( dirName );
								IF searchPath[i] = 0X THEN  EXIT   
								ELSE  INC( i );  j := 0  
								END
							ELSE
								dirName[j] := searchPath[i];  INC( j );  INC( i )
							END
						END
					END;
					checkSet := NIL;
				END Enumerate0;

			END UnixFileSystem;
	
	
	Buffer = OBJECT (Files.Hint )
			VAR
				chg: BOOLEAN;
				org, size: LONGINT;
				data: ARRAY Bufsize OF CHAR;
				
				PROCEDURE &Init;
				BEGIN 
					chg := FALSE;  org := -1; 
				END Init;
				
			END Buffer;
	
	File* = OBJECT (Files.File)
			VAR
				fd: LONGINT;
				workName, registerName: Filename;
				tempFile: BOOLEAN;
				dev: Unix.DevT;
				ino: LONGINT;
				mtime: LONGINT;
				fsize, fpos: SIZE;
				bufs: ARRAY NBufs OF Buffer;
				swapper, state: LONGINT;


				PROCEDURE & Init( fs: Files.FileSystem );
				BEGIN
					SELF.fs := fs;  flags := {};  
				END Init;

				
				PROCEDURE CreateUnixFile;
				CONST 
					CreateFlags = Unix.rdwr + Unix.creat + Unix.trunc;
				VAR 
					stat: Unix.Status;  done: BOOLEAN;  r: LONGINT;
				BEGIN
					IF state = Create THEN  
						GetTempName( registerName, workName );  tempFile := TRUE
					ELSIF state = Closed THEN  
						workName := registerName;  registerName := "";  tempFile := FALSE
					END;
					r := Unix.unlink( ADDRESSOF( workName ) );
					(*unlink first to avoid stale NFS handles and to avoid reuse of inodes*)
					
					IF (FileTabSize - openfiles) < ResFiles THEN  GC  END;
						
					fd := Unix.open( ADDRESSOF( workName ), CreateFlags, Unix.rwrwr );
					done := fd >= 0;  r := Unix.errno();
					IF (~done & (r IN {Unix.ENFILE, Unix.EMFILE})) OR (done & (fd >= FileTabSize)) THEN
						IF done THEN  r := Unix.close( fd )  END;
						GC ;
						fd := Unix.open( ADDRESSOF( workName ), CreateFlags, Unix.rwrwr );
						done := fd >= 0
					END;
					IF done THEN
						IF fd >= FileTabSize THEN  
							r := Unix.close( fd );  
							Halt( SELF, FALSE, "UnixFiles.File.Create: too many files open" )
						ELSE
							r := Unix.fstat( fd, stat );  
							dev := stat.dev;  ino := stat.ino;  mtime := stat.mtime.sec;
							state := Open;  fpos := 0;
							fileTab[fd].f := SELF;
							INC( openfiles );  RegisterFinalizer( SELF, Cleanup );
						END
					ELSE  
						Halt( SELF, TRUE, "UnixFiles.File.Create: open failed" );
					END
				END CreateUnixFile;
				
						
				PROCEDURE Flush( buf: Buffer );
				VAR res: LONGINT;  stat: Unix.Status;
				BEGIN
					IF buf.chg THEN
						IF fd = NoDesc THEN  CreateUnixFile  END;
						IF buf.org # fpos THEN  res := Unix.lseek( fd, buf.org, 0 )  END;
						res := Unix.write( fd, ADDRESSOF( buf.data ), buf.size );
						IF res < 0 THEN  Halt( SELF, TRUE, "UnixFiles.File.Flush: write failed" )  END;
						fpos := buf.org + buf.size;  buf.chg := FALSE;
						res := Unix.fstat( fd, stat );  mtime := stat.mtime.sec
					END
				END Flush;
				
	
				PROCEDURE Set*( VAR r: Files.Rider;  pos: LONGINT );
				BEGIN {EXCLUSIVE}
					SetX( r, pos )
				END Set;
						
				PROCEDURE SetX( VAR r: Files.Rider;  p: LONGINT );
				VAR  org, offset, i, n, res: LONGINT;  buf: Buffer;
				BEGIN 
					IF p > fsize THEN  p := fsize
					ELSIF p < 0 THEN  p := 0
					END;
					offset := p MOD Bufsize;  org := p - offset;  
					i := 0;
					WHILE (i < NBufs) & (bufs[i] # NIL) & (org # bufs[i].org) DO  INC( i )  END;
					IF i < NBufs THEN
						IF bufs[i] = NIL THEN  
							NEW( buf );  bufs[i] := buf;  
						ELSE  
							swapper := i;
							buf := bufs[swapper];  Flush( buf )
						END
					ELSE  
						swapper := (swapper + 1) MOD NBufs;  
						buf := bufs[swapper];  Flush( buf )
					END;
					IF buf.org # org THEN
						IF org = fsize THEN  
							buf.size := 0
						ELSE
							IF fd = NoDesc THEN  CreateUnixFile  END;
							IF fpos # org THEN  res := Unix.lseek( fd, org, 0 )  END;
							IF res < 0 THEN  Halt( SELF, TRUE, "UnixFiles.File.Set: lseek failed" )  END;
							n := Unix.read( fd, ADDRESSOF( buf.data ), Bufsize );
							IF n < 0 THEN  
								IF p < fsize THEN  Halt( SELF, TRUE, "UnixFiles.File.Set: read failed" )  
								ELSE n := 0
								END
							END;
							fpos := org + n;  buf.size := n
						END;
						buf.org := org;  buf.chg := FALSE
					ELSE
						org := buf.org 
					END;

					r.hint := buf;  r.apos := org;  r.bpos := offset;  
					r.res := 0;  r.eof := FALSE;
					r.file := SELF;  r.fs := fs  
				END SetX;
				

				PROCEDURE Pos*( VAR r: Files.Rider ): LONGINT;
				BEGIN
					RETURN r.apos + r.bpos
				END Pos;


				PROCEDURE Read*( VAR r: Files.Rider;  VAR x: CHAR );
				VAR offset: LONGINT;  buf: Buffer;
				BEGIN  {EXCLUSIVE}
					buf := r.hint(Buffer);  offset := r.bpos;
					IF r.apos # buf.org THEN  
						SetX( r, r.apos + offset );  
						buf := r.hint(Buffer);  offset := r.bpos  
					END;
					IF (offset < buf.size) THEN  
						x := buf.data[offset];  r.bpos := offset + 1
					ELSIF r.apos + offset < fsize THEN  
						SetX( r, r.apos + offset );  
						x := r.hint(Buffer).data[0];  r.bpos := 1
					ELSE  
						x := 0X;  r.eof := TRUE
					END
				END Read;

				PROCEDURE ReadBytes*( VAR r: Files.Rider;  VAR x: ARRAY OF CHAR;  ofs, len: LONGINT );
				VAR xpos, min, restInBuf, offset: LONGINT;  buf: Buffer;  
				BEGIN  {EXCLUSIVE}
					x[ofs] := 0X;  xpos := ofs;  
					buf := r.hint(Buffer);  offset := r.bpos;
					WHILE len > 0 DO
						IF (r.apos # buf.org) OR (offset >= Bufsize) THEN  
							SetX( r, r.apos + offset );  
							buf := r.hint(Buffer);  offset := r.bpos  
						END;
						restInBuf := buf.size - offset;
						IF restInBuf = 0 THEN  r.res := len;  r.eof := TRUE;  RETURN
						ELSIF len > restInBuf THEN  min := restInBuf
						ELSE  min := len
						END;
						S.MOVE( ADDRESSOF( buf.data ) + offset, ADDRESSOF( x ) + xpos, min );
						INC( offset, min );  r.bpos := offset;
						INC( xpos, min );  DEC( len, min )
					END;
					r.res := 0;  r.eof := FALSE;
				END ReadBytes;
				
				
				PROCEDURE Write*( VAR r: Files.Rider;  x: CHAR );
				VAR buf: Buffer;  offset: LONGINT;
				BEGIN  {EXCLUSIVE}
					buf := r.hint(Buffer);  offset := r.bpos;
					IF (r.apos # buf.org) OR (offset >= Bufsize) THEN  
						SetX( r, r.apos + offset );  
						buf := r.hint(Buffer);  offset := r.bpos  
					END;
					buf.data[offset] := x;  buf.chg := TRUE;
					IF offset = buf.size THEN  INC( buf.size );  INC( fsize )  END;
					r.bpos := offset + 1;  r.res := Files.Ok
				END Write;

				PROCEDURE WriteBytes*( VAR r: Files.Rider;  CONST x: ARRAY OF CHAR;  ofs, len: LONGINT );
				VAR xpos, min, restInBuf, offset: LONGINT;  buf: Buffer;
				BEGIN  {EXCLUSIVE}
					xpos := ofs;  buf := r.hint(Buffer);  offset := r.bpos;
					WHILE len > 0 DO
						IF (r.apos # buf.org) OR (offset >= Bufsize) THEN  
							SetX( r, r.apos + offset );  
							buf := r.hint(Buffer);  offset := r.bpos  
						END;
						restInBuf := Bufsize - offset;
						IF len > restInBuf THEN  min := restInBuf  ELSE  min := len  END;
						S.MOVE( ADDRESSOF( x ) + xpos, ADDRESSOF( buf.data ) + offset, min );  
						INC( offset, min );  r.bpos := offset;
						IF offset > buf.size THEN  
							INC( fsize, offset - buf.size );  buf.size := offset  
						END;
						INC( xpos, min );  DEC( len, min );  buf.chg := TRUE
					END;
					r.res := Files.Ok
				END WriteBytes;
				

				PROCEDURE Length*( ): LONGINT;
				BEGIN
					RETURN fsize
				END Length;


				PROCEDURE GetDate*( VAR t, d: LONGINT );
				VAR stat: Unix.Status;   r: LONGINT;  time: Unix.TmPtr;				
				BEGIN {EXCLUSIVE}
					IF fd = NoDesc THEN  CreateUnixFile  END;  
					r := Unix.fstat( fd, stat );
					time := Unix.localtime( stat.mtime );
					t := time.sec + ASH( time.min, 6 ) + ASH( time.hour, 12 );
					d := time.mday + ASH( time.mon + 1, 5 ) + ASH( time.year, 9 );
				END GetDate;


				PROCEDURE SetDate*( t, d: LONGINT );
				TYPE 
					Time = RECORD actime, modtime: LONGINT END;
				VAR
					tm: Unix.Tm;  buf: Time;  r: LONGINT;  path: Filename;
				BEGIN {EXCLUSIVE}
					IF registerName # "" THEN  COPY( registerName, path )  
					ELSE  COPY( workName, path )  
					END;
					(* get year and timezone *)
					(* fill in new date *)
					tm.isdst := -1;  tm.sec := t MOD 64;  tm.min := t DIV 64 MOD 64;  
					tm.hour := t DIV 4096 MOD 32;
					tm.mday := d MOD 32;  tm.mon := d DIV 32 MOD 16 - 1;  tm.year := d DIV 512;
					tm.wday := 0;  tm.yday := 0;
					buf.actime := Unix.mktime( tm );  buf.modtime := buf.actime;
					r := Unix.utime( ADDRESSOF( path ), ADDRESSOF( buf ) );
				END SetDate;


				PROCEDURE GetAttributes*( ): SET;
				BEGIN {EXCLUSIVE}
					RETURN flags
				END GetAttributes;

				PROCEDURE SetAttributes*( attr: SET );
				BEGIN {EXCLUSIVE}
					(* flags := attr	*)
				END SetAttributes;


				PROCEDURE Register0*( VAR res: LONGINT );
				BEGIN {EXCLUSIVE}
					IF (state = Create) & (registerName # "") THEN  
						state := Closed (* shortcut renaming *)   
					END;
					FlushBuffers;
					IF registerName # "" THEN
						fs.Rename0( workName, registerName, SELF, res );
						IF res # Files.Ok THEN  
							Halt( SELF, FALSE, "UnixFiles.File.Register: rename failed" )  
						END;
						workName := registerName;  registerName := "";  tempFile := FALSE
					END;
				END Register0;
				

				PROCEDURE Update*;
				BEGIN {EXCLUSIVE}
					FlushBuffers
				END Update;
				
				
				PROCEDURE FlushBuffers;
				VAR i: LONGINT; 
				BEGIN 
					IF fd = NoDesc THEN  CreateUnixFile  END;  
					FOR i := 0 TO NBufs - 1 DO
						IF bufs[i] # NIL THEN  Flush( bufs[i] )  END
					END;
				END FlushBuffers;
				
				
				PROCEDURE Close*;
				VAR r: LONGINT;
				BEGIN {EXCLUSIVE}
					IF fileTab[fd].f # NIL THEN
						IF tempFile THEN  r := Unix.unlink( ADDRESSOF( workName ) )  
						ELSE  FlushBuffers;
						END;
						fileTab[fd].f := NIL;
						r := Unix.close( fd );
						DEC( openfiles );  state := Closed
					END;
				END Close;
				
				
				PROCEDURE GetName*( VAR name: ARRAY OF CHAR );
				BEGIN {EXCLUSIVE}
					IF registerName = "" THEN  COPY( workName, name ) ;
					ELSE  COPY( registerName, name )
					END;
					CleanPath( name )
				END GetName;

			END File;

(*===================================================================*)

	(** Get the current directory. *)
	PROCEDURE GetWorkingDirectory*( VAR path: ARRAY OF CHAR );
	BEGIN
		COPY( cwd, path )
	END GetWorkingDirectory;
	
	(** Change to directory path. *)	
	PROCEDURE ChangeDirectory*( CONST path: ARRAY OF CHAR;  VAR done: BOOLEAN );
	VAR r: LONGINT;  newdir: Filename;
	BEGIN
		IF path[0] # '/' THEN  
			COPY( cwd, newdir );  AppendName( newdir, path );
			CleanPath( newdir )  
		ELSE
			COPY( path, newdir );
		END;
		r := Unix.chdir( ADDRESSOF( newdir ) );
		IF r = 0 THEN  COPY( newdir, cwd );  done := TRUE   ELSE  done := FALSE   END
	END ChangeDirectory;

(*===================================================================*)
	
	PROCEDURE StripPath*( CONST path: ARRAY OF CHAR;  VAR name: ARRAY OF CHAR );
	VAR i, p: INTEGER;  c: CHAR;
	BEGIN
		i := 0;  p := 0;
		REPEAT
			IF path[i] = '/' THEN  p := i + 1  END;
			INC( i )
		UNTIL path[i] = 0X;
		i := 0;
		REPEAT  c := path[p];  name[i] := c;  INC( i );  INC( p )  UNTIL c = 0X
	END StripPath;
	
	
	PROCEDURE CleanPath*( VAR path: ARRAY OF CHAR );
	(*  
		/aaa/../bbb/./ccc/../ddd/.  ==>   /bbb/ddd
		../aaa  ==>  CWD/../aaa  ==>  . . .
	*)
	VAR 
		i, prevNameStart, nameStart: INTEGER;
		c1, c2, c3: CHAR;

		PROCEDURE prependCWD;
		VAR tmp: ARRAY 256 OF CHAR;
		BEGIN
			COPY( cwd, tmp ); AppendName( tmp, path );  COPY( tmp, path )
		END prependCWD;
	
		PROCEDURE restart;
		BEGIN
			IF path[0] = '/' THEN  nameStart := 1  ELSE  nameStart := 0  END;
			i := -1;  prevNameStart := -1;
		END restart;

		PROCEDURE shift( p0, p1: INTEGER );
		VAR c: CHAR;
		BEGIN
			REPEAT  c := path[p1];  path[p0] := c;  INC( p0 );  INC( p1 )  UNTIL c = 0X;
			IF p0 > 1 THEN  restart  ELSE  i := 0  END
		END shift;

	BEGIN
		restart;
		REPEAT
			INC( i );
			IF i = nameStart THEN
				c1 := path[i];  c2 := path[i + 1];  c3 := path[i + 2];
				IF c1 = '/' THEN  shift( i, i + 1 ) (* // *)
				ELSIF c1 = '.' THEN
					IF c2 = 0X THEN  
						IF i > 1 THEN  DEC( i )  END;
						path[i] := 0X
					ELSIF c2 = '/' THEN  shift( i, i + 2 );   (* ./ *)
					ELSIF (c2 = '.') & ((c3 = 0X) OR (c3 = '/')) THEN  (* .. *)
						IF i = 0 THEN  prependCWD;  restart
						ELSIF c3 = 0X THEN DEC( i ); path[i] := 0X
						ELSIF c3 = '/' THEN  (* ../ *)
							IF prevNameStart >= 0 THEN  shift( prevNameStart, i + 3 )  END
						END
					END
				END
			ELSIF path[i] = '/' THEN
				IF i > 0 THEN  prevNameStart := nameStart  END;
				nameStart := i + 1
			END;
		UNTIL (i >= 0) & (path[i] = 0X);
		IF (i > 1) & (path[i - 1] = '/') THEN  path[i - 1] := 0X  END;
		IF path = "" THEN  path := "."  END;
	END CleanPath;


	PROCEDURE Match( CONST name, pat: ARRAY OF CHAR;  i, j: INTEGER ): BOOLEAN;
	BEGIN
		IF (name[i] = 0X) & (pat[j] = 0X) THEN  RETURN TRUE
		ELSIF pat[j] # "*" THEN  RETURN (name[i] = pat[j]) & Match( name, pat, i + 1, j + 1 )
		ELSE  (* pat[j] = "*", name[i] may be 0X *)
			RETURN Match( name, pat, i, j + 1 ) OR ((name[i] # 0X) & Match( name, pat, i + 1, j ))
		END
	END Match;
	
	
	PROCEDURE Append( VAR a: Filename;  CONST this: ARRAY OF CHAR );
	VAR i, j: LONGINT; 
	BEGIN
		i := 0;  j := 0;  
		WHILE a[i] # 0X DO  INC( i )  END;
		WHILE (i < LEN( a ) - 1) & (this[j] # 0X) DO  a[i] := this[j];  INC( i );  INC( j )  END;
		a[i] := 0X
	END Append;

	PROCEDURE AppendName( VAR path: Filename;  CONST filename: ARRAY OF CHAR );
	VAR i, j, max: LONGINT;
	BEGIN
		i := 0;  j := 0;  max := LEN( path ) - 1;
		WHILE path[i] # 0X DO  INC( i )  END;
		IF (i > 0) & (path[i - 1] # "/") THEN  path[i] := "/";  INC( i );  path[i] := 0X  END;
		Append( path, filename );
	END AppendName;
	
	
	PROCEDURE AppendInt( VAR str: Filename; n: LONGINT );
	VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE str[i] # 0X DO  INC(i)  END;
		WHILE n > 0 DO  str[i] := CHR( n MOD 10 + ORD('0') );  n := n DIV 10;  INC(i)  END;
		str[i] := 0X
	END AppendInt;


	PROCEDURE IsFullName( CONST name: ARRAY OF CHAR ): BOOLEAN;
	VAR i: INTEGER;  ch: CHAR;
	BEGIN
		i := 0;  ch := name[0];
		WHILE (ch # 0X) & (ch # "/") DO  INC( i );  ch := name[i]  END;
		RETURN ch = "/"
	END IsFullName;

	PROCEDURE Halt( f: File;  unixError: BOOLEAN;  CONST msg: ARRAY OF CHAR );
	VAR fd, errno: LONGINT;
		workName, registerName: Filename;
	BEGIN
		IF f = NIL THEN  
			workName := "???";  registerName := "???"
		ELSE  
			workName := f.workName;  registerName := f.registerName;  fd := f.fd
		END;
		IF unixError THEN  errno := Unix.errno( );  Unix.Perror( msg )  END;
		HALT( 99 )
	END Halt;

	PROCEDURE RegisterFinalizer( obj: ANY;  fin: Heaps.Finalizer );
	VAR n: Heaps.FinalizerNode;
	BEGIN
		NEW( n ); n.finalizer := fin;  Heaps.AddFinalizer( obj, n );
	END RegisterFinalizer;
	
	PROCEDURE GC;
	BEGIN
		Kernel.GC;
		AwaitFinalizingDone
	END GC;
	
	PROCEDURE AwaitFinalizingDone;
	BEGIN
		(* wait until finalizers have finished! (Cleanup)*)
		Machine.Acquire( Machine.GC );  Machine.Release( Machine.GC )
	END AwaitFinalizingDone;

	PROCEDURE ResetBuffers( f: File;  VAR stat: Unix.Status );
	VAR i: INTEGER;
	BEGIN
		f.fsize := stat.size;
		IF (f.mtime # stat.mtime.sec) THEN
			FOR i := 0 TO NBufs - 1 DO
				IF f.bufs[i] # NIL THEN  f.bufs[i].org := -1;  f.bufs[i] := NIL  END;
			END;
			f.swapper := -1;  f.mtime := stat.mtime.sec
		END
	END ResetBuffers;

	PROCEDURE FindCachedEntry( VAR stat: Unix.Status ): File;
	VAR f: File;  i: INTEGER;
	BEGIN
		FOR i := 0 TO FileTabSize - 1 DO
			f := fileTab[i].f;
			IF (f # NIL ) & (stat.ino = f.ino) & (stat.dev = f.dev) THEN
				(* possible different name but same file! *)
				ResetBuffers( f, stat );
				RETURN f
			END;
		END;
		RETURN NIL
	END FindCachedEntry;
	

	PROCEDURE MakePath( CONST dir, name: ARRAY OF CHAR;  VAR dest: ARRAY OF CHAR );
	VAR i, j: INTEGER;
	BEGIN
		i := 0;  j := 0;
		WHILE dir[i] # 0X DO  dest[i] := dir[i];  INC( i )  END;
		IF dest[i - 1] # "/" THEN  dest[i] := "/";  INC( i )  END;
		WHILE name[j] # 0X DO  dest[i] := name[j];  INC( i );  INC( j )  END;
		dest[i] := 0X
	END MakePath;
	
	
	PROCEDURE ScanPath( VAR pos: LONGINT;  VAR dir: ARRAY OF CHAR );
	VAR i: LONGINT;  ch: CHAR;
	BEGIN
		i := 0;  ch := searchPath[pos];
		WHILE ch = " " DO  INC( pos );  ch := searchPath[pos]  END;
		WHILE ch > " " DO  dir[i] := ch;  INC( i );  INC( pos );  ch := searchPath[pos]  END;
		dir[i] := 0X
	END ScanPath;


	PROCEDURE GetTempName( CONST finalName: ARRAY OF CHAR;  VAR tempName: Filename );
	VAR n, i, j, pe, pid: LONGINT; 
	BEGIN
		INC(tempno);  n := tempno;  i := 0;  j := 0; pe := 1;
		WHILE finalName[j] = ' ' DO  INC(j)  END;   (* skip leading spaces *)
		IF finalName[j] # "/" THEN  (* relative pathname *)
			WHILE cwd[i] # 0X DO  tempName[i] := cwd[i];  INC(i)  END;
			IF tempName[i - 1] # '/' THEN  tempName[i] := '/';  INC(i)  END;
			pe := i - 1
		END;
		WHILE finalName[j] # 0X DO  tempName[i] := finalName[j];  INC(i);  INC(j)  END;
		WHILE (i > pe) & (tempName[i-1] # '/') DO  DEC(i)  END;  (* remove filename *)
		tempName[i] := 0X;
		Append( tempName, ".tmp." );  
		AppendInt( tempName, n );  Append( tempName, "." );
		pid := Unix.getpid();
		AppendInt( tempName, pid )
	END GetTempName;

	

	
	PROCEDURE Cleanup( obj: ANY );
	VAR f: File;
	BEGIN
		f := S.VAL( File, obj );  f.Close
	END Cleanup;


	PROCEDURE CloseFiles;
	VAR i: LONGINT;  f: File;
	BEGIN
		i := 0;
		WHILE i < FileTabSize DO
			f := fileTab[i].f;
			IF f # NIL THEN  f.Close  END;
			INC( i )
		END;
	END CloseFiles;



	PROCEDURE Install;
	VAR aliasFS: AliasFileSystem;
	BEGIN
		NEW( unixFS );  (*  Files.Add( unixFS, "" );	*)
		NEW( aliasFS, unixFS );  Files.Add( aliasFS, "searcher" )
	END Install;


	
	PROCEDURE Initialize;
	VAR a: ADDRESS;  i: INTEGER;  ch: CHAR;
	BEGIN
		(* get current working directory *)
		a := Unix.getenv( ADDRESSOF( "PWD" ) );
		IF a > 0 THEN
			i := 0;
			REPEAT  S.GET( a, ch );  INC( a );  cwd[i] := ch;  INC( i )  UNTIL ch = 0X;
		ELSE
			(* $PWD not set *)  
			a := Unix.getcwd( ADDRESSOF( cwd ), LEN( cwd ) )
		END;
		i := 0;
		WHILE cwd[i] # 0X DO  INC( i )  END;
		DEC( i );
		IF (i > 0) & (cwd[i] = '/') THEN  cwd[i] := 0X  END;

		(* get search pathes *)
		a := Unix.getenv( ADDRESSOF( "AOSPATH" ) );  i := 0;
		IF a = 0 THEN
			Log.String( "UnixFiles.Initialize: environment variable AOSPATH not defined" );  Log.Ln;
			Unix.exit( 1 )
		ELSE
			REPEAT
				S.GET( a, ch );  INC( a );
				IF ch = ":" THEN  ch := " "  END;
				searchPath[i] := ch;  INC( i )
			UNTIL ch = 0X;
		END;
		i := 0;
		WHILE i < FileTabSize DO  fileTab[i].f := NIL;  INC( i )  END;
		tempno := 1;  openfiles := 0;  
		Modules.InstallTermHandler( CloseFiles )	
	END Initialize;

BEGIN
	Initialize;
	Install
END UnixFiles.
