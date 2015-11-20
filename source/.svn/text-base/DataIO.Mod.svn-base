(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE DataIO;   (** AUTHOR "adf, fof"; PURPOSE "File IO for making scientific data types persistent"; *)

(**  A template exists for creating persistent OBJECT's  that use the reader and writer defined in this module.
	This template is found in: DataTemplate.Mod. *)

IMPORT Modules, Streams, Files, Dates, NbrInt, NbrRat, NbrRe, NbrCplx, NbrStrings, DataErrors;

TYPE
	Item = POINTER TO RECORD
		type: Modules.TypeDesc;
		load: LoadProc;
		store: StoreProc;
		next: Item
	END;

	Registry = POINTER TO RECORD
		root: Item
	END;

	Card = OBJECT
	VAR number: NbrInt.Integer;
		type: Modules.TypeDesc;
		next: Card;

		PROCEDURE Read( R: Reader );
		VAR res: LONGINT;
			msg: ARRAY 64 OF CHAR;
			string: NbrStrings.String;  module: Modules.Module;  moduleName, typeName: Modules.Name;
		BEGIN
			NbrInt.Load( R, number );  R.RawString( moduleName );  R.RawString( typeName );
			module := Modules.ThisModule( moduleName, res, msg );  NEW( string, 64 );
			IF module # NIL THEN
				type := Modules.ThisType( module, typeName );
				IF type = NIL THEN
					string := "Type "; string := string + moduleName;  string := string + ".";  string := string + typeName;  string := string + " does not exist on your computer.";
					DataErrors.Error( string^ )
				END
			ELSE
				string := "Module "; string := string + moduleName;  string := string + " does not exist on your computer.";
				DataErrors.Error( string^ );  HALT( 1000 );   (* Must halt here, further reading is catastrophic. *)
			END
		END Read;

		PROCEDURE Write( W: Writer );
		BEGIN
			NbrInt.Store( W, number );  W.RawString( type.mod.name );  W.RawString( type.name )
		END Write;

	END Card;

	Library = OBJECT
	VAR entries: NbrInt.Integer;
		root, card: Card;

		PROCEDURE & Initialize*;
		BEGIN
			entries := 0;  NEW( root );  root.number := 0;  card := root
		END Initialize;

		PROCEDURE Read( R: Reader );
		VAR i: NbrInt.Integer;  new: Card;
		BEGIN
			card := root;  NbrInt.Load( R, entries );
			FOR i := 1 TO entries DO NEW( new );  new.Read( R );  card.next := new;  card := card.next END;
			card := root
		END Read;

		PROCEDURE Write( W: Writer );
		VAR i: NbrInt.Integer;
		BEGIN
			card := root;  NbrInt.Store( W, entries );
			FOR i := 1 TO entries DO card := card.next;  card.Write( W ) END;
			card := root
		END Write;

		PROCEDURE Push( type: Modules.TypeDesc );
		VAR new: Card;
		BEGIN
			card := root;
			IF type # NIL THEN
				LOOP
					IF card.next = NIL THEN
						NEW( new );  new.number := card.number + 1;  new.type := type;  card.next := new;  card := new;
						NbrInt.Inc( entries );  EXIT
					END;
					IF type = card.type THEN  (* This library card already exists. *) EXIT END;
					card := card.next
				END
			END
		END Push;

	END Library;


	(** Reader for reading data from a  .Data  file. *)
	Reader* = OBJECT (Files.Reader)
	VAR lib: Library;
		file: File;

		PROCEDURE ReaderAvailable( ): BOOLEAN;
		BEGIN
			IF res = Streams.Ok THEN RETURN TRUE
			ELSIF res = Streams.EOF THEN DataErrors.Error( "Attempted to read past the end of file." );  RETURN FALSE
			ELSIF res = Streams.FormatError THEN DataErrors.Error( "A format error encounter by the reader." );  RETURN FALSE
			ELSE DataErrors.IntError( res, "The 'res' error number originating from an Streams reader error." );  RETURN FALSE
			END
		END ReaderAvailable;

	(** Reads a date and time. *)
		PROCEDURE DateTime*( VAR x: Dates.DateTime );
		VAR d, t: LONGINT;
		BEGIN
			IF ReaderAvailable() THEN RawNum( d );  RawNum( t );  x := Dates.OberonToDateTime( d, t ) ELSE HALT( 1000 ) END
		END DateTime;

	(** Reads an integer number. *)
		PROCEDURE Integer*( VAR x: NbrInt.Integer );
		BEGIN
			IF ReaderAvailable() THEN NbrInt.Load( SELF, x ) ELSE HALT( 1000 ) END
		END Integer;

	(** Reads a rational number. *)
		PROCEDURE Rational*( VAR x: NbrRat.Rational );
		BEGIN
			IF ReaderAvailable() THEN NbrRat.Load( SELF, x ) ELSE HALT( 1000 ) END
		END Rational;

	(** Reads a real number. *)
		PROCEDURE Real*( VAR x: NbrRe.Real );
		BEGIN
			IF ReaderAvailable() THEN NbrRe.Load( SELF, x ) ELSE HALT( 1000 ) END
		END Real;

	(** Reads a complex number. *)
		PROCEDURE Complex*( VAR x: NbrCplx.Complex );
		BEGIN
			IF ReaderAvailable() THEN NbrCplx.Load( SELF, x ) ELSE HALT( 1000 ) END
		END Complex;

	(** Reads a dynamic 0X-terminated string. *)
		PROCEDURE PtrString*( VAR x: NbrStrings.String );
		BEGIN
			IF ReaderAvailable() THEN NbrStrings.Load( SELF, x ) ELSE HALT( 1000 ) END
		END PtrString;
		(*
	(* Reads a dynamic POINTER TO ARRAY of some type that has been registered via the PlugIn procedure. *)
		PROCEDURE PtrArray*( VAR x: ANY );
		BEGIN
			IF ReaderAvailable() THEN
			ELSE HALT(1000)
			END
		END PtrArray;
*)
	(** Reads a dynamic object whose type has been registered via the PlugIn procedure. *)
		PROCEDURE Object*( VAR x: OBJECT );
		VAR n: NbrInt.Integer;  item: Item;
		BEGIN
			IF ReaderAvailable() THEN
				Integer( n );
				IF n > 0 THEN
					lib.card := lib.root;
					LOOP
						lib.card := lib.card.next;
						IF lib.card = NIL THEN DataErrors.Error( "Corrupt file - sought library card does not exist." );  HALT( 1001 );  EXIT END;
						IF n = lib.card.number THEN
							item := registry.root;
							LOOP
								item := item.next;
								IF item = NIL THEN DataErrors.Warning( "Encountered an alien object to be read from file." );  HALT( 1002 );  EXIT END;
								IF lib.card.type = item.type THEN item.load( SELF, x );  EXIT END
							END;
							EXIT
						END
					END
				ELSE  (* The object stored was the NIL pointer. *) x := NIL
				END;
				lib.card := lib.root
			ELSE HALT( 1000 )
			END
		END Object;

	END Reader;


	(** Writer for writing data to a  .Data  file. *)
	Writer* = OBJECT (Files.Writer);
	VAR lib: Library;
		file: File;

		(** Writes a date and time. *)
		PROCEDURE DateTime*( x: Dates.DateTime );
		VAR d, t: LONGINT;
		BEGIN
			Dates.DateTimeToOberon( x, d, t );  RawNum( d );  RawNum( t );  Update
		END DateTime;

	(** Writes an integer number. *)
		PROCEDURE Integer*( x: NbrInt.Integer );
		BEGIN
			NbrInt.Store( SELF, x );  Update
		END Integer;

	(** Writes a rational number. *)
		PROCEDURE Rational*( x: NbrRat.Rational );
		BEGIN
			NbrRat.Store( SELF, x );  Update
		END Rational;

	(** Writes a real number. *)
		PROCEDURE Real*( x: NbrRe.Real );
		BEGIN
			NbrRe.Store( SELF, x );  Update
		END Real;

	(** Writes a complex number. *)
		PROCEDURE Complex*( x: NbrCplx.Complex );
		BEGIN
			NbrCplx.Store( SELF, x );  Update
		END Complex;

	(** Writes a dynamic 0X-terminated string. *)
		PROCEDURE PtrString*( x: NbrStrings.String );
		BEGIN
			NbrStrings.Store( SELF, x );  Update
		END PtrString;
		(*
	(* Writes a dynamic POINTER TO ARRAY of some type that has been registered via the PlugIn procedure. *)
		PROCEDURE PtrArray*( x: ANY );
		VAR
		BEGIN
		END PtrArray;
*)
	(** Writes a dynamic object whose type has been registered via the PlugIn procedure. *)
		PROCEDURE Object*( x: OBJECT );
		VAR item: Item;
		BEGIN
			IF x # NIL THEN
				lib.Push( Modules.TypeOf( x ) );  item := registry.root;
				LOOP
					item := item.next;
					IF item = NIL THEN DataErrors.Error( "Attempted to write an object whose type has not been registered." );  HALT( 1003 );  EXIT END;
					IF lib.card.type = item.type THEN Integer( lib.card.number );  item.store( SELF, x );  EXIT END
				END
			ELSE  (* Object is NIL. *) Integer( 0 )
			END;
			Update
		END Object;

	END Writer;


	(** File type for files with a .Data extension. *)
	File* = OBJECT  (** Not shareable between multiple processes. *)
	VAR F: Files.File;
		lib: Library;
		initialwpos: LONGINT;
		R-: Reader;
		W-: Writer;

		PROCEDURE & Initialize*;
		BEGIN
			NEW( lib );  initialwpos := 0
		END Initialize;

		PROCEDURE Length*( ): LONGINT;
		BEGIN
			RETURN F.Length()
		END Length;

	END File;


	(** Loading procedure type for registering an object for data IO. *)
	LoadProc* = PROCEDURE ( R: Reader;  VAR obj: OBJECT );


	(** Storing procedure type for registering an object for data IO. *)
	StoreProc* = PROCEDURE ( W: Writer;  obj: OBJECT );

VAR
	registry: Registry;


	(** Register the load and store procedures that belong to the dynamic object to be made persistent. *)
	PROCEDURE PlugIn*( obj: ANY;  load: LoadProc;  store: StoreProc );
	VAR item, new: Item;  type: Modules.TypeDesc;  string: NbrStrings.String;
	BEGIN
		IF obj # NIL THEN
			IF load # NIL THEN
				IF store # NIL THEN
					type := Modules.TypeOf( obj );  item := registry.root;
					LOOP
						IF type = item.type THEN  (* already registered *) EXIT END;
						IF item.next = NIL THEN
							NEW( new );  new.type := type;  new.load := load;  new.store := store;  item.next := new;  EXIT
						END;
						item := item.next
					END
				ELSE NEW( string, 64 );  string := "A NIL 'store' procedure was sent for registation from module ";  string := string + type.mod.name;  string := string + ".";  DataErrors.Error( string^ )
				END
			ELSE NEW( string, 64 );  string := "A NIL 'load' procedure was sent for registation from module ";  string := string + type.mod.name;  string := string + ".";  DataErrors.Error( string^ )
			END
		ELSE NEW( string, 64 );  string := "A NIL 'obj' was sent for registation from module ";  string := string + type.mod.name;  string := string + ".";  DataErrors.Error( string^ )
		END
	END PlugIn;


(** Open a .Data  file.
	The reader is placed at the beginning of the file.
	The writer is placed at the end of the file, which is at the beginning if the file is new,
	thereby preventing existing data from being overwritten. *)
	PROCEDURE Open*( fileName: Files.FileName ): File;
	VAR existingFile: BOOLEAN;  dummy, libPos: LONGINT;  file: File;  libR: Reader;
		name, fName: ARRAY Files.NameLength OF CHAR;
		suffix: ARRAY Files.PrefixLength OF CHAR;
	BEGIN
		(* Create the file. *)
		NEW( file );  Files.SplitExtension( fileName, name, suffix );  Files.JoinExtension( name, "Data", fName );
		file.F := Files.Old( fName );
		IF file.F # NIL THEN existingFile := TRUE ELSE existingFile := FALSE;  file.F := Files.New( fName ) END;
		(* Attach the reader. *)
		NEW( file.R, file.F, 0 );  file.R.file := file;
		IF existingFile THEN
			(* Read in the library. *)
			file.R.RawLInt( libPos );  NEW( libR, file.F, libPos );  file.lib.Read( libR )
		END;
		file.R.lib := file.lib;
		(* Attach the writer. *)
		IF existingFile THEN
			(* Append any new data. *)
			NEW( file.W, file.F, libPos );  file.W.InitFileWriter( file.F, libPos );
			file.initialwpos := libPos;   (* Position of a Writer is relative to initial point *)
		ELSE
			NEW( file.W, file.F, 0 );
			(* Handle the place holder locating the library. *)
			file.W.RawLInt( dummy );  file.R.RawLInt( dummy )
		END;
		file.W.lib := file.lib;  file.W.file := file;  RETURN file
	END Open;

(** Opening an existing file places the writer at the end of that file, by default, therefore all future
	writings append the file.  Calling Rewind moves the reader and writer to the beginning of the file,
	and will therefore overwrite all contents previously held by the file. All prior data will be lost. *)
	PROCEDURE Rewind*( f: File );
	VAR dummy: LONGINT;
	BEGIN
		IF f # NIL THEN
			NEW( f.lib );  NEW( f.R, f.F, 0 );  NEW( f.W, f.F, 0 );  f.initialwpos := 0;  f.R.lib := f.lib;  f.R.file := f;  f.W.lib := f.lib;  f.W.file := f;
			(* Handle the place holder locating the library. *)
			f.W.RawLInt( dummy );  f.R.RawLInt( dummy )
		END
	END Rewind;

(** Close a .Data  file.
	Executing this command attaches a hidden library needed to allocate memory to restore stored PTR variables.
	It is therefore imperative that every file opened with Open gets physically closed with this command. *)
	PROCEDURE Close*( f: File );
	VAR libPosW: Writer;
	BEGIN
		f.W.Update;  NEW( libPosW, f.F, 0 );   (* writing library position to very first position *)

		libPosW.RawLInt( f.W.Pos() + f.initialwpos );  libPosW.Update;  f.lib.Write( f.W );

		f.W.Update;  Files.Register( f.F );  f.F := NIL;  f.lib := NIL;  f.R := NIL;  f.W := NIL
	END Close;

BEGIN
	NEW( registry );  NEW( registry.root )
END DataIO.