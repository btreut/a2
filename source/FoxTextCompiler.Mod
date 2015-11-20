MODULE TextCompiler; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Streams, Modules, Basic := FoxBasic, Compiler, TextUtilities, Diagnostics, Texts, Backend := FoxBackend, SyntaxTree := FoxSyntaxTree,
	CompilerInterface, Formats := FoxFormats, Strings, UTF8Strings, Commands;

CONST

	Name = "Fox";
	Description = "Oberon Compiler";
	FileExtension = "MOD"; (*! temporary *)

	PROCEDURE GetClipboardReader(): Streams.Reader;
	VAR size : LONGINT;
		selectionText: Texts.Text;
		pcStr: POINTER TO ARRAY OF CHAR;
		stringReader: Streams.StringReader;
	BEGIN
		selectionText := Texts.clipboard;
		selectionText.AcquireRead;
		size := UTF8Size(selectionText,0,selectionText.GetLength())+1;
		NEW(pcStr,size);
		TextUtilities.SubTextToStr(selectionText,0,size,pcStr^);
		selectionText.ReleaseRead;
		NEW(stringReader,size);
		stringReader.Set(pcStr^);
		RETURN stringReader;
	END GetClipboardReader;

	PROCEDURE GetSelectionReader(): Streams.Reader;
	VAR a, b, size : LONGINT;
		selectionText: Texts.Text;
		from, to: Texts.TextPosition;
		pcStr: POINTER TO ARRAY OF CHAR;
		stringReader: Streams.StringReader;
	BEGIN
		IF Texts.GetLastSelection(selectionText, from, to) THEN
			selectionText.AcquireRead;
			a := Strings.Min(from.GetPosition(), to.GetPosition());
			b := Strings.Max(from.GetPosition(), to.GetPosition());
			size := UTF8Size(selectionText,a,b-a+1)+1;
			NEW(pcStr,size);
			TextUtilities.SubTextToStr(selectionText, a, b - a+1, pcStr^);
			selectionText.ReleaseRead;
			NEW(stringReader,b-a+1);
			stringReader.Set(pcStr^);
		ELSE
			stringReader  := NIL;
		END;
		RETURN stringReader;
	END GetSelectionReader;

	PROCEDURE GetTextReader(text: Texts.Text; position: LONGINT): Streams.Reader;
	VAR size : LONGINT;
		pcStr: POINTER TO ARRAY OF CHAR;
		stringReader: Streams.StringReader;
	BEGIN
		text.AcquireRead;
		size := UTF8Size(text,position,text.GetLength())+1;
		NEW(pcStr,size);
		TextUtilities.SubTextToStr(text,position,size,pcStr^);
		text.ReleaseRead;
		NEW(stringReader,size);
		stringReader.Set(pcStr^);
		RETURN stringReader;
	END GetTextReader;

	PROCEDURE UTF8Size(text : Texts.Text; startPos, len : LONGINT): LONGINT;
	VAR i, length, pos,size : LONGINT; r : Texts.TextReader; ch : Texts.Char32; ok : BOOLEAN;
		string: ARRAY 16 OF CHAR;
	BEGIN
		text.AcquireRead;
		NEW(r, text);
		r.SetPosition(startPos);
		size := 0;i := 0; length := len; ok := TRUE;
		WHILE (i < length) & ok DO
			r.ReadCh(ch);
			IF (ch > 0) THEN
				pos := 0;
				ok := UTF8Strings.EncodeChar(ch, string, pos);
				INC(size,pos);
			END;
			INC(i);
		END;
		text.ReleaseRead;
		RETURN size
	END UTF8Size;


	PROCEDURE CompileText*(t: Texts.Text; CONST source: ARRAY OF CHAR; pos: LONGINT; CONST pc,opt: ARRAY OF CHAR; log: Streams.Writer;
	diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
	VAR stringReader: Streams.StringReader;
		reader: Streams.Reader;
		options: Compiler.CompilerOptions;
		importCache: SyntaxTree.ModuleScope;
	BEGIN
		IF t = NIL THEN
			log.String ("No text available"); log.Ln; log.Update;
			error := TRUE; RETURN
		END;
		NEW(stringReader,LEN(opt));
		stringReader.Set(opt);
		IF Compiler.GetOptions(stringReader,log,diagnostics,options) THEN
			reader := GetTextReader(t,pos);
			IF pc # "" THEN INCL(options.flags,Compiler.FindPC); COPY(pc, options.findPC);
			ELSIF options.findPC # "" THEN INCL(options.flags,Compiler.FindPC)
			END;
			error := ~Compiler.Modules(source,reader,0,diagnostics, log, options, importCache)
		END;
	END CompileText;

	PROCEDURE CompileSelection*(context: Commands.Context);
	BEGIN
		Compiler.CompileReader(context,GetSelectionReader())
	END CompileSelection;

	PROCEDURE CompileClipboard*(context: Commands.Context);
	BEGIN
		Compiler.CompileReader(context,GetClipboardReader())
	END CompileClipboard;

PROCEDURE Cleanup;
BEGIN
	CompilerInterface.Unregister(Name);
END Cleanup;

BEGIN
	CompilerInterface.Register(Name, Description, FileExtension, CompileText);
	Modules.InstallTermHandler(Cleanup);
END TextCompiler.
