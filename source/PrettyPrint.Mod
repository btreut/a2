MODULE PrettyPrint; (** AUTOR "GF"; PURPOSE "pretty printing of Oberon programs"; *)

(* ---------------------------------------------------------- 
	Usage:
		PrettyPrint.Convert 
			<filename>  <filename>  ...  ~
	

	The real printing on a postscript printer can be done in the Oberon subsystem:
		
		Desktops.PrintDoc  <printer name>	PPr/<filename> ~
	
  ----------------------------------------------------------- *)

IMPORT Commands, Files, Strings, Streams, Texts, TextUtilities, SyntaxHighlighter;

CONST 
	PPDir = "PPr";

VAR
	highlighter: SyntaxHighlighter.Highlighter;
	out, err: Streams.Writer;
	
	PROCEDURE CheckSubDirectory( CONST dname: ARRAY OF CHAR ): BOOLEAN;
	VAR 
		enum: Files.Enumerator;
		fname, cname: ARRAY 64 OF CHAR; time, date, size: LONGINT; flags: SET;
	BEGIN
		cname := "./";  Strings.Append( cname, dname );
		NEW( enum );
		enum.Open( "./*", {} );
		WHILE enum.GetEntry( fname, flags, time, date, size ) DO
			IF fname = cname THEN  RETURN TRUE  END
		END;
		RETURN FALSE
	END CheckSubDirectory;
	

	(* convert program sources into syntax highlighted Oberon Texts in subdir 'PPr' *)
	
	PROCEDURE Convert*( context: Commands.Context );	(*  {filename} ~ *)
	VAR 
		filename, dest: ARRAY 64 OF CHAR;  format, res: LONGINT;
		f: Files.File;  text: Texts.Text;
	BEGIN
		out := context.out;  err := context.error;
		
		out.String( "PrettyPrint.Convert" ); out.Ln;
		IF ~CheckSubDirectory( PPDir ) THEN  Files.CreateDirectory( PPDir, res )  END;
		IF highlighter = NIL THEN  LoadHighlighter  END;
		IF highlighter # NIL THEN
			WHILE context.arg.GetString( filename ) DO
				out.String( "    " );  out.String( filename );  
				f := Files.Old( filename );
				IF f = NIL THEN
					err.String( " : file not found" ); err.Ln;  
				ELSE
					NEW( text );
					TextUtilities.LoadAuto( text, filename, format, res );
					SyntaxHighlighter.HighlightText( text, highlighter );
					dest := PPDir; Strings.Append( dest, "/" ); Strings.Append( dest, filename );
					TextUtilities.StoreOberonText( text, dest, res );
					out.String( " => " ); out.String( dest );  out.Ln;  
				END
			END
		ELSE
			err.String( "Highlighter 'PrintOberon' not found" );  err.Ln
		END;
		out.Update;  err.Update
	END Convert;
	
	
	PROCEDURE LoadHighlighter;
	VAR res: LONGINT; msg: ARRAY 128 OF CHAR;
	BEGIN 
		Commands.Call( "SyntaxHighlighter.Open PrettyPrintHighlighter.XML", {}, res, msg );
		highlighter := SyntaxHighlighter.GetHighlighter( "PrintOberon" );
		Commands.Call( "SyntaxHighlighter.Open SyntaxHighlighter.XML", {}, res, msg );
	END LoadHighlighter;

BEGIN
	highlighter := NIL
END PrettyPrint.


	SystemTools.Free PrettyPrint ~
	
	PrettyPrint.Convert  PrettyPrint.Mod  Xyz.Mod ~



