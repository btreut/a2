(**
	@author fof
	@date 2012.07.06

	collection of tools to do tagging of files/logs/documents that make an identification of all relevant state possible
**)
MODULE Versioning;

IMPORT Dates, Strings, Streams, Modules, Files, Basic := FoxBasic;

	PROCEDURE WriteModules*(w: Streams.Writer);
	VAR m: Modules.Module;
	BEGIN
		m := Modules.root;
		WHILE m # NIL DO w.String(m.name); w.String(":"); w.Hex(m.crc,-8); w.String(" "); m := m.next END;
	END WriteModules;

	PROCEDURE WriteDate*(w: Streams.Writer);
	VAR s: ARRAY 32 OF CHAR;
	BEGIN
		Strings.FormatDateTime("yyyy.mm.dd hh:nn:ss", Dates.Now(), s); w.String(s);
	END WriteDate;

	PROCEDURE WriteAuthor*(w: Streams.Writer);
	BEGIN
	END WriteAuthor;

	PROCEDURE TagFileName*(fileName: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
	VAR filename, extension: Files.FileName; s: ARRAY 32 OF CHAR;
	BEGIN
		Files.SplitExtension(fileName, result, extension);
		Strings.FormatDateTime("_yyyymmdd_hhnnss",Dates.Now(), s);
		Strings.Append(result,s);
		Files.JoinExtension(result, extension, result);
	END TagFileName;

	PROCEDURE NewLogWriter*(VAR logFileName: ARRAY OF CHAR; CONST purpose,name: ARRAY OF CHAR): Streams.Writer;
	VAR logFile: Files.File; log: Files.Writer;
	BEGIN
		TagFileName(logFileName, logFileName);
		logFile := Files.New(logFileName);
		IF logFile = NIL THEN RETURN NIL END;
		Files.Register(logFile);
		NEW(log,logFile,0);
		log.String(purpose); log.String(":"); log.String(name); log.Ln;
		WriteDate(log); log.Ln;
		WriteAuthor(log); log.Ln;
		WriteModules(log); log.Ln;
		RETURN log
	END NewLogWriter;

END Versioning.
