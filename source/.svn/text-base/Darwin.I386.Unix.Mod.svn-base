MODULE Unix;   (* Josef Templ, 5.3.90	SVR4 system calls *)  (** Linux x86 version, non portable *)

(* Linux PPC version	g.f. 18.04.98	*)
(* Linux x86 version	g.f 10.11.99 	*)
(*	2000.09.19	g.f.	'Sigaltstack' added	*)
(*	2002.06.27	g.f.	TmDesc fixed,  new: Utime, Mktime *)
(*	2006.07.31	g.f.	shared memory support added *)
(*	2007.04.13	g.f.	Thread priorities added *)

IMPORT S := SYSTEM, Glue, Trace;


CONST
	Version* = "Darwin";

	libcname* = "libc.dylib";
	libmname* = "libm.dylib";
	libX11name* = "libX11.dylib";
	libXextname* = "libXext.dylib";

	LittleEndian* = TRUE;   (** byte order of basic types *)
	LsbIs0* = TRUE;   (** bit order of SET type *)

	PageSize* = 4096;	(* least MMU page size *)

	stdin* = 0;  stdout* = 1;  stderr* = 2;

	(** Unix error codes:	*)
	EPERM* = 1;   (* Not super-user *)
	ENOENT* = 2;   (* No such file or directory *)
	ESRCH* = 3;   (* No such process *)
	EINTR* = 4;   (* interrupted system call *)
	EIO* = 5;   (* I/O error *)
	ENXIO* = 6;   (* No such device or address *)
	E2BIG* = 7;   (* Arg list too long *)
	ENOEXEC* = 8;   (* Exec format error *)
	EBADF* = 9;   (* Bad file number *)
	ECHILD* = 10;   (* No children *)
	EAGAIN* = 11;   (* No more processes *)
	ENOMEM* = 12;   (* Not enough core *)
	EACCES* = 13;   (* Permission denied *)
	EFAULT* = 14;   (* Bad address *)
	ENOTBLK* = 15;   (* Block device required *)
	EBUSY* = 16;   (* Mount device busy *)
	EEXIST* = 17;   (* File exists *)
	EXDEV* = 18;   (* Cross-device link *)
	ENODEV* = 19;   (* No such device *)
	ENOTDIR* = 20;   (* Not a directory *)
	EISDIR* = 21;   (* Is a directory *)
	EINVAL* = 22;   (* Invalid argument *)
	ENFILE* = 23;   (* File table overflow *)
	EMFILE* = 24;   (* Too many open files *)
	ENOTTY* = 25;   (* Inappropriate ioctl for device *)
	ETXTBSY* = 26;   (* Text file busy *)
	EFBIG* = 27;   (* File too large *)
	ENOSPC* = 28;   (* No space left on device *)
	ESPIPE* = 29;   (* Illegal seek *)
	EROFS* = 30;   (* Read only file system *)
	EMLINK* = 31;   (* Too many links *)
	EPIPE* = 32;   (* Broken pipe *)
	EDOM* = 33;   (* Math arg out of domain of func *)
	ERANGE* = 34;   (* Math result not representable *)
	ENOMSG* = 42;   (* No message of desired type *)
	EIDRM* = 43;   (* Identifier removed *)
	ECHRNG* = 44;   (* Channel number out of range *)
	EL2NSYNC* = 45;   (* Level 2 not synchronized *)
	EL3HLT* = 46;   (* Level 3 halted *)
	EL3RST* = 47;   (* Level 3 reset *)
	ELNRNG* = 48;   (* Link number out of range *)
	EUNATCH* = 49;   (* Protocol driver not attached *)
	ENOCSI* = 50;   (* No CSI structure available *)
	EL2HLT* = 51;   (* Level 2 halted *)
	EDEADLK* = 35;   (* Deadlock condition. *)
	ENOLCK* = 37;   (* No record locks available. *)

	(* open flags *)
	rdonly* = {};  rdwr* = {1};  creat* = {9};  trunc* = {10};

	(* access modes *)
	rwrwr* = {2, 4, 5, 7, 8};  rwxrwxrwx* = {0..8};
	
	F_OK* = {};  X_Ok* = {0};  W_OK* = {1};  R_OK* = {2};

	(*--------------------------- Threads -------------------------------*)

TYPE
	Thread_t* = ADDRESS;
	Mutex_t* = ADDRESS;
	Condition_t* = ADDRESS;
	
CONST
	(* Thread priorities *)
	ThreadLow* = 15; ThreadNormal* = 20; ThreadHigh* = 47;	
	NumPriorities* = 33;	(* number of priority levels *)


	(*---------------------------- IP -----------------------------------*)

CONST
	(* domain *)
		AFINET* = 2;
		AFINET6* = 26;
		
		PFINET* = AFINET;
		PFINET6* = AFINET6;
		
	(* types of connection *)
		SockStream*	= 1;
		SockDGram*	= 2;
	(* Protocols *)
		IpProtoUDP*	= 17;
		IpProtoTCP*		= 6;

	(* setsockopt *)
		SoLSocket*		= 0FFFFH;	(* socket option level *)
		SoLinger* 		= 80H; 		(* linger (gracefully close the connection)*)
		SoKeepAlive*	= 8;			(* keep connection alive *)
		SoNoDelay*	= 1;			(* no delay *)

	(* ioctl *)
		FioNRead*		= 4004667FH;	(* something to read ? *)
		
		
	(* recv *)
		MsgPeek*		= 2;
		MsgDontWait*	= 80H;		(* non blocking read *)
		
	(* shutdown *)
		ShutRDWR*	= 2;

	SockAddrSizeV4*	= 16;
	SockAddrSizeV6*	= 28;
	
	(*-------------------seral line ---------------------------------------*)
	
	FIONREAD*	= 4004667FH;
	TIOCMGET*		= LONGINT( 4004746AH );
	TIOCMBIC*		= LONGINT( 8004746BH );
	TIOCMBIS*		= LONGINT( 8004746CH );
	TIOCMSET*		= LONGINT( 8004746DH );
	
	(* speeds *)
	B0*	= 0;
	B50*	= 50;
	B75*	= 75;
	B110*	= 110;
	B134*	= 134;
	B150*	= 150;
	B200*	= 200;
	B300*	= 300;
	B600*	= 600;
	B1200*		= 1200;
	B1800*		= 1800;
	B2400*		= 2400;
	B4800*		= 4800;
	B9600*		= 9600;
	B19200*	= 19200;
	B38400*	= 38400;

	B57600*	= 57600;
	B115200*	= 115200;
	B230400*	= 230400;


	(* tio.cflag bits *)
	CSIZE*		= {8,9};	(* character size mask *)
	   CS5*		= {};  	(* 5 bits (pseudo) *)
	   CS6*		= {8}; 	(* 6 bits *)
	   CS7*		= {9}; 	(* 7 bits *)
	   CS8*		= {8,9};	(* 8 bits *)
	CSTOPB*	= {10};	(* send 2 stop bits *)
	CREAD*	= {11};	(* enable receiver *)
	PARENB*	= {12};	(* parity enable *)
	PARODD*	= {13};	(* odd parity, else even *)
	HUPCL*		= {14};	(* hang up on last close *)
	CLOCAL*	= {15};	(* ignore modem status lines *)
	
TYPE
	Termios* = RECORD
		iflags*, oflags*, cflags*, lflags*: SET;
		cc*: ARRAY 20 OF CHAR;
		ispeed-, ospeed-: LONGINT
	END;
	
	(*------------------------------------------------------------------*)

TYPE
	DevT* = LONGINT;

	Status* = RECORD
				dev-		: DevT;
				ino-		: LONGINT;
				mode-	: INTEGER;
				nlink-		: INTEGER;
				uid-		: LONGINT;
				gid-		: LONGINT;
				rdev-		: DevT;
				atime-	: Timeval;
				mtime-	: Timeval;
				ctime-	: Timeval;
				size-		: LONGINT;
				size2-	: LONGINT;
				blocks-	: HUGEINT;
				blksize-	: LONGINT;
				flags-		: LONGINT;
				gen-		: LONGINT;
				lspare-	: LONGINT;
				qspare-	: ARRAY 4 OF LONGINT
			END;

	Timeval* = RECORD
				sec*		: LONGINT;
				usec*		: LONGINT
			END;

	TmPtr* = POINTER TO Tm;
	Tm* = RECORD
				sec*, min*, hour*, mday*, mon*, year*, wday*, yday*, isdst*: LONGINT;
				gmtoff*, tmzone*: LONGINT;
			END;

	Tms* = POINTER TO RECORD
				utime*, stime*, cutime*, cstime*: LONGINT
			END;

	Timezone* = RECORD
				minuteswest*, dsttime*: LONGINT
			END;

	Itimerval* = RECORD
				interval*, value*: Timeval
			END;



	FdSet* = ARRAY 32 OF SET;
	FdSetPtr* = POINTER TO FdSet;

	Dirent* = POINTER TO RECORD
				ino-		: LONGINT;
				reclen-	: INTEGER;
				typ-		: SHORTINT;
				namlen-	: SHORTINT;
				name-	:  (*array of*) CHAR;
			END;

	Stack* = RECORD
				sp*		: ADDRESS;
				size*		: SIZE;
				flags*		: SET;
			END;

	Ucontext* = POINTER TO UcontextDesc;
	UcontextDesc* = RECORD
				onstack-	: LONGINT;
				sigmask-	: LONGINT;
				stack-	: Stack;
				link-		: ADDRESS;
				mclen-	: SIZE;
				mc-{UNTRACED}	: Mcontext
			END;

	Mcontext* = POINTER TO McontextDesc;
	McontextDesc* = RECORD
				r_trapno-		: LONGINT;
				r_err-			: LONGINT;
				r_faultvaddr-	: LONGINT;
				r_ax-			: LONGINT;
				r_bx-			: LONGINT;
				r_cx-			: LONGINT;
				r_dx-			: LONGINT;
				t_di-			: LONGINT;
				r_si-			: LONGINT;
				r_bp-			: LONGINT;
				r_sp-			: LONGINT;
				r_ss-			: LONGINT;
				r_flags-		: LONGINT;
				r_pc-			: LONGINT;
				r_cs-			: LONGINT;
				r_ds-			: LONGINT;
				r_es-			: LONGINT;
				r_fs-			: LONGINT;
				r_gs-			: LONGINT;
				
				flavor-			: LONGINT;
				count-		: LONGINT;
				fpc-			: FPcontextDesc;
			END;

	FPcontext* = POINTER TO FPcontextDesc;
	FPcontextDesc* = RECORD
				fpsate*: ARRAY 100 OF LONGINT;
			END;



VAR
	argc-: LONGINT;  argv-: ADDRESS;
	aargc: ADDRESS;

	sysinfo-: RECORD
				sysname-, nodename-, release-, version-, machine-: ARRAY 65 OF CHAR;
			END;



	read-			: PROCEDURE {C} ( fd: LONGINT; buf: ADDRESS; n: SIZE ): LONGINT;
	write-			: PROCEDURE {C} ( fd: LONGINT; buf: ADDRESS; n: SIZE ): LONGINT;
	open-			: PROCEDURE {C} ( name: ADDRESS;  flags, mode: SET ): LONGINT;
	close-		: PROCEDURE {C} ( fd: LONGINT ): LONGINT;
	lseek-		: PROCEDURE {C} ( fd: LONGINT; offset, origin: SIZE ): LONGINT;
	fsync-		: PROCEDURE {C} ( fd: LONGINT ): LONGINT;
	ioctl-			: PROCEDURE {C} ( fd: LONGINT; request: LONGINT; arg: ADDRESS ): LONGINT;
	unlink-		: PROCEDURE {C} ( name: ADDRESS ): LONGINT;
	rename-		: PROCEDURE {C} ( oldname, newname: ADDRESS ): LONGINT;
	ftruncate-		: PROCEDURE {C} ( fd: LONGINT;  length: SIZE ): LONGINT;
	chmod-		: PROCEDURE {C} ( name: ADDRESS;  mode: SET ): LONGINT;
	utime-		: PROCEDURE {C} ( fd: LONGINT;  tb: ADDRESS ): LONGINT;
	access-		: PROCEDURE {C} ( name: ADDRESS;  mode: SET ): LONGINT;
	select-		: PROCEDURE {C} ( width: LONGINT; rd, wr, ex: FdSetPtr;  VAR timeout: Timeval ): LONGINT;

	chdir-			: PROCEDURE {C} ( name: ADDRESS ): LONGINT;
	mkdir-		: PROCEDURE {C} ( name: ADDRESS;  mode: SET ): LONGINT;
	rmdir-			: PROCEDURE {C} ( path: ADDRESS ): LONGINT;

	stat-			: PROCEDURE {C} ( name: ADDRESS;  VAR buf: Status ): LONGINT;
	lstat-			: PROCEDURE {C} ( name: ADDRESS;  VAR buf: Status ): LONGINT;
	fstat-			: PROCEDURE {C} ( fd: LONGINT;  VAR buf: Status ): LONGINT;

	getpid-		: PROCEDURE {C} ( ): LONGINT;
	getuid-		: PROCEDURE {C} ( ): LONGINT;

	malloc-		: PROCEDURE {C} ( size: SIZE ): ADDRESS;
	posix_memalign-	: PROCEDURE {C} ( VAR p: ADDRESS;  alignment, size: SIZE ): LONGINT;
	free-			: PROCEDURE {C} ( p: ADDRESS );
	mprotect-	: PROCEDURE {C} ( p: ADDRESS; len: SIZE; prot: LONGINT ): LONGINT;

	alarm-		: PROCEDURE {C} ( ms: LONGINT ): LONGINT;
	setitimer-		: PROCEDURE {C} ( which: LONGINT;  VAR value, ovalue: Itimerval ): LONGINT;
	getitimer-		: PROCEDURE {C} ( which: LONGINT;  VAR value: Itimerval ): LONGINT;

	gettimeofday-	: PROCEDURE {C} ( VAR tv: Timeval;  VAR tz: Timezone ): LONGINT;
	mktime-			: PROCEDURE {C} ( VAR tm: Tm ): LONGINT;
	localtime-		: PROCEDURE {C} ( CONST tv: Timeval ): TmPtr;
	time-				: PROCEDURE {C} ( VAR tv: Timeval ): LONGINT;
	times-			: PROCEDURE {C} ( VAR tms: Tms ): LONGINT;

	system-		: PROCEDURE {C} ( cmd: ADDRESS );
	uname-		: PROCEDURE {C} ( utsname: ADDRESS ): LONGINT;

	getcwd-		: PROCEDURE {C} ( buf: ADDRESS;  len: SIZE ): LONGINT;
	getenv-		: PROCEDURE {C} ( name: ADDRESS ): LONGINT;

	opendir-		: PROCEDURE {C} ( name: ADDRESS ): ADDRESS;
	readdir-		: PROCEDURE {C} ( dir: ADDRESS ): Dirent;
	closedir-		: PROCEDURE {C} ( dir: ADDRESS );

	sigsetjmp-	: PROCEDURE {C} ( env: ADDRESS;  savemask: LONGINT ): LONGINT;
	siglongjmp-	: PROCEDURE {C} ( env: ADDRESS;  val: LONGINT );

	kill-			: PROCEDURE {C} ( pid, sig: LONGINT ): LONGINT;
	exit-			: PROCEDURE {C} ( status: LONGINT );
	perror-		: PROCEDURE {C} ( msg: ADDRESS );
	errno-			: PROCEDURE {C} ( ): LONGINT;


	libc-: LONGINT;

	libraryPaths: ARRAY 7 OF ARRAY 32 OF CHAR;
	noPaths: LONGINT;


	PROCEDURE ModifyContext*( cont: Ucontext;  pc, bp, sp: LONGINT );
	BEGIN
		cont.mc.r_pc := pc;
		cont.mc.r_bp := bp;
		cont.mc.r_sp := sp
	END ModifyContext;

	PROCEDURE Perror*( CONST msg: ARRAY OF CHAR );
	BEGIN
		perror( ADDRESSOF( msg ) )
	END Perror;

	PROCEDURE Dlsym*( lib: ADDRESS;  CONST sym: ARRAY OF CHAR;  objAddr: ADDRESS );
	VAR val: LONGINT;
	BEGIN
		Glue.dlsym( lib, ADDRESSOF( sym ), objAddr );
		S.GET( objAddr, val );
		IF val = 0 THEN
			Trace.String( "Unix.Dlsym:  entry '" );  Trace.String( sym );  Trace.String( "' not found" );
			Trace.Ln
		END
	END Dlsym;

	PROCEDURE Dlopen*( CONST libname: ARRAY OF CHAR;  mode: LONGINT ): ADDRESS;
	VAR h: ADDRESS;  i, j, k: INTEGER;
		p: ARRAY 256 OF CHAR;
	BEGIN
		IF libname[0] = '/' THEN  h := Glue.dlopen( ADDRESSOF( libname ), mode );
		ELSE
			i := 0;  h := 0;
			WHILE (h = 0) & (i < noPaths) DO
				COPY( libraryPaths[i], p );  j := 0;
				WHILE p[j] # 0X DO  INC( j )  END;
				p[j] := '/';  k := 0;
				REPEAT  INC( j );  p[j] := libname[k];  INC( k )  UNTIL p[j] = 0X;
				h := Glue.dlopen( ADDRESSOF( p ), mode );  INC( i )
			END
		END;
		IF h = 0 THEN
			Trace.String( "Unix.Dlopen: loading library " );
			Trace.String( libname );  Trace.String( " failed" );  Trace.Ln
		END;
		RETURN h
	END Dlopen;

	PROCEDURE Dlclose*( lib: ADDRESS );
	BEGIN
		Glue.dlclose( lib )
	END Dlclose;

	PROCEDURE GetArg*( no: LONGINT;  VAR val: ARRAY OF CHAR );
	VAR ch: CHAR;  adr: ADDRESS;  i: LONGINT;
	BEGIN
		IF no >= argc THEN  val[0] := 0X
		ELSE
			S.GET( argv + SIZEOF(ADDRESS)*no, adr );  i := 0;
			REPEAT  S.GET( adr, ch );  val[i] := ch;  INC( adr );  INC( i );   UNTIL (ch = 0X) OR (i >= LEN( val ));
		END
	END GetArg;

	PROCEDURE GetArgval*(  CONST argName: ARRAY OF CHAR;  VAR val: ARRAY OF CHAR );
	VAR i: INTEGER;
		buf: ARRAY 40 OF CHAR;
	BEGIN
		i := 1;
		WHILE i < argc - 1 DO
			GetArg( i, buf );
			IF buf = argName THEN  GetArg( i + 1, val );  RETURN   END;
			INC( i )
		END;
		val[0] := 0X
	END GetArgval;


	PROCEDURE getSysinfo;
	VAR res: LONGINT;  p: INTEGER;
		buf: ARRAY 4096 OF CHAR;

		PROCEDURE copy( VAR p: INTEGER;  VAR dest: ARRAY OF CHAR );
		VAR i: INTEGER;
		BEGIN
			WHILE buf[p] <= ' ' DO  INC( p )  END;
			i := 0;
			REPEAT  dest[i] := buf[p];  INC( i );  INC( p )  UNTIL (buf[p - 1] = 0X) OR (i >= LEN( dest ));
			dest[i - 1] := 0X
		END copy;

	BEGIN
		FOR p := 0 TO 4096 - 1 DO  buf[p] := 0X  END;
		res := uname( ADDRESSOF( buf ) );
		p := 0;
		copy( p, sysinfo.sysname );
		copy( p, sysinfo.nodename );
		copy( p, sysinfo.release );
		copy( p, sysinfo.version );
		copy( p, sysinfo.machine );
	END getSysinfo;

BEGIN
	Dlsym( 0, "argc", ADDRESSOF( aargc ) );  S.GET( aargc, argc );
	Dlsym( 0, "argv", ADDRESSOF( argv ) );

	libraryPaths[0] := "/usr/lib";
	libraryPaths[1] := "/opt/X11/lib";
	libraryPaths[2] := "/usr/X11/lib";
	libraryPaths[3] := "/opt/local/lib";
	noPaths := 4;



	libc := Dlopen( libcname, 2 );

	Dlsym( libc, "read",		ADDRESSOF( read ) );
	Dlsym( libc, "write",	ADDRESSOF( write ) );
	Dlsym( libc, "open",		ADDRESSOF( open ) );
	Dlsym( libc, "close",	ADDRESSOF( close ) );
	Dlsym( libc, "lseek",	ADDRESSOF( lseek ) );
	Dlsym( libc, "fsync",	ADDRESSOF( fsync ) );
	Dlsym( libc, "ioctl",	ADDRESSOF( ioctl ) );
	Dlsym( libc, "unlink",	ADDRESSOF( unlink ) );
	Dlsym( libc, "rename",	ADDRESSOF( rename ) );
	Dlsym( libc, "ftruncate",	ADDRESSOF( ftruncate ) );
	Dlsym( libc, "chmod",	ADDRESSOF( chmod ) );
	Dlsym( libc, "utime",	ADDRESSOF( utime ) );
	Dlsym( libc, "access",	ADDRESSOF( access ) );
	Dlsym( libc, "select",	ADDRESSOF( select ) );

	Dlsym( libc, "chdir",	ADDRESSOF( chdir ) );
	Dlsym( libc, "mkdir",	ADDRESSOF( mkdir ) );
	Dlsym( libc, "rmdir",	ADDRESSOF( rmdir ) );

	Dlsym( libc, "stat",		ADDRESSOF( stat ) );
	Dlsym( libc, "lstat",	ADDRESSOF( lstat ) );
	Dlsym( libc, "fstat",	ADDRESSOF( fstat ) );

	Dlsym( libc, "getpid",	ADDRESSOF( getpid ) );
	Dlsym( libc, "getuid",	ADDRESSOF( getuid ) );

	Dlsym( libc, "alarm",	ADDRESSOF( alarm ) );
	Dlsym( libc, "setitimer",	ADDRESSOF( setitimer ) );
	Dlsym( libc, "getitimer",	ADDRESSOF( getitimer ) );

	Dlsym( libc, "gettimeofday", ADDRESSOF( gettimeofday ) );
	Dlsym( libc, "mktime",		ADDRESSOF( mktime ) );
	Dlsym( libc, "localtime",	ADDRESSOF( localtime ) );
	Dlsym( libc, "time",			ADDRESSOF( time ) );
	Dlsym( libc, "times",		ADDRESSOF( times ) );

	Dlsym( libc, "getcwd",		ADDRESSOF( getcwd ) );
	Dlsym( libc, "getenv",		ADDRESSOF( getenv ) );

	Dlsym( libc, "opendir",		ADDRESSOF( opendir ) );
	Dlsym( libc, "readdir",		ADDRESSOF( readdir ) );
	Dlsym( libc, "closedir",	ADDRESSOF( closedir ) );

	Dlsym( libc, "sigsetjmp",	ADDRESSOF( sigsetjmp ) );
	Dlsym( libc, "siglongjmp",	ADDRESSOF( siglongjmp ) );

	Dlsym( libc, "malloc",		ADDRESSOF( malloc ) );
	Dlsym( libc, "posix_memalign",	ADDRESSOF( posix_memalign ) );
	Dlsym( libc, "free",			ADDRESSOF( free ) );
	Dlsym( libc, "mprotect",	ADDRESSOF( mprotect ) );

	Dlsym( libc, "system",		ADDRESSOF( system ) );
	Dlsym( libc, "uname",		ADDRESSOF( uname ) );

	Dlsym( libc, "kill",			ADDRESSOF( kill ) );
	Dlsym( libc, "exit",			ADDRESSOF( exit ) );
	Dlsym( libc, "perror",		ADDRESSOF( perror ) );
	Dlsym( libc, "errno",		ADDRESSOF( errno ) );

	getSysinfo;
END Unix.
