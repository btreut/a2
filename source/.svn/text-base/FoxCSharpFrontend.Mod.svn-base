MODULE FoxCSharpFrontend; (**  AUTHOR "fof"; PURPOSE "Oberon Compiler: CSharp frontend module";  **)

IMPORT
	Streams, Diagnostics,  SyntaxTree := FoxSyntaxTree, Parser := FoxCSharpParser, Scanner := FoxCSharpScanner, FoxFrontend;

TYPE

	Frontend* = OBJECT (FoxFrontend.Frontend)
	VAR
		scanner: Scanner.Scanner;
		parser: Parser.Parser;
		
		PROCEDURE Initialize*(diagnostics: Diagnostics.Diagnostics; reader: Streams.Reader; CONST fileName: ARRAY OF CHAR; pos: LONGINT; activeCells: BOOLEAN);
		BEGIN
			Initialize^(diagnostics, reader, fileName, pos, activeCells);
			scanner := Scanner.NewScanner(fileName, reader, pos, diagnostics);
			parser := Parser.NewParser( scanner, diagnostics );
		END Initialize;
		
		PROCEDURE Parse*(): SyntaxTree.Module;
		BEGIN 
			RETURN parser.Module();
		END Parse;
		
		PROCEDURE Error(): BOOLEAN;
		BEGIN
			RETURN parser.error;
		END Error;
		
	END Frontend;

	PROCEDURE Get*():FoxFrontend.Frontend;
	VAR frontend: Frontend;
	BEGIN
		NEW(frontend);
		RETURN frontend;
	END Get;

END FoxCSharpFrontend.