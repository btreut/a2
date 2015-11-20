MODULE WMFontManager;	(** AUTHOR "TF"; PURPOSE "Default implementation of a simple font manager"; *)

IMPORT
	KernelLog, Kernel, Modules, Commands, WMGraphics, WMDefaultFont, Strings, Configuration, XML, XMLObjects;

TYPE
	String = XML.String;

	FontInfo* = OBJECT
	VAR
		name* : String;
		size* : LONGINT;
		style* : SET;
	END FontInfo;

	FontFactory = PROCEDURE(info : FontInfo) : WMGraphics.Font;

	LoaderInfo = POINTER TO RECORD
		loader : String;
		next : LoaderInfo;
	END;

	FontManager = OBJECT (WMGraphics.FontManager)
	VAR
		fontCache : Kernel.FinalizedCollection;

		(* lru: last recently used font - circular buffer. This buffer is for fast access and provides a protection for a limited number of loaded fonts from being garbage collected.  *)
		lru: ARRAY 64 OF WMGraphics.Font;
		lruPosition: LONGINT;

		defaultFont : WMGraphics.Font;
		font : WMGraphics.Font; (* set by the enumerator *)
		searchName : ARRAY 256 OF CHAR;
		searchSize : LONGINT;
		searchStyle : SET;
		found : BOOLEAN;
		exactLoaders, approximateLoaders : LoaderInfo;

		(* default font settings specified in Configuration.XML, read by procedure GetConfig *)
		defaultFontName : ARRAY 256 OF CHAR;
		defaultFontSize : LONGINT;
		defaultFontStyle : SET;

		PROCEDURE &Init*;
		VAR t : WMGraphics.Font;
		BEGIN
			NEW(fontCache);
			defaultFontName := "Oberon"; defaultFontSize := 14; defaultFontStyle := {};
			GetConfig;
			defaultFont := WMDefaultFont.LoadDefaultFont(); (* fallback case *)
			t := GetFont(defaultFontName, defaultFontSize, defaultFontStyle);
			IF t = defaultFont THEN KernelLog.String("Using embedded font"); KernelLog.Ln ELSE defaultFont := t END;
			WMGraphics.InstallDefaultFont(defaultFont);
			lruPosition := 0;
		END Init;

		PROCEDURE MatchExact(obj : ANY; VAR cont : BOOLEAN);
		VAR f : WMGraphics.Font;
		BEGIN
			cont := TRUE;
			IF obj IS WMGraphics.Font THEN
				f := obj(WMGraphics.Font);
				IF (f.name = searchName) & (f.size = searchSize) & (f.style = searchStyle) THEN
					font := f; cont := FALSE; found := TRUE;
				END
			END;
		END MatchExact;

		PROCEDURE MatchSimiliar(obj : ANY; VAR cont : BOOLEAN);
		VAR f : WMGraphics.Font;
		BEGIN
			cont := TRUE;
			IF obj IS WMGraphics.Font THEN
				f := obj(WMGraphics.Font);
				IF (f.name = searchName) & (f.size = searchSize) THEN
					font := f; cont := FALSE; found := TRUE;
				END
			END;
		END MatchSimiliar;

		PROCEDURE AddExact(str : String);
		VAR n : LoaderInfo;
		BEGIN
			IF str = NIL THEN RETURN END;
			NEW(n); n.loader := str;
			n.next := exactLoaders; exactLoaders := n
		END AddExact;

		PROCEDURE AddApproximate(str : String);
		VAR n : LoaderInfo;
		BEGIN
			IF str = NIL THEN RETURN END;
			NEW(n); n.loader := str;
			n.next := approximateLoaders; approximateLoaders := n
		END AddApproximate;

		PROCEDURE GetConfig;
		VAR
			section, e : XML.Element;
			p : ANY; enum: XMLObjects.Enumerator;
			string : ARRAY 16 OF CHAR; res : LONGINT;

			PROCEDURE Error;
			BEGIN KernelLog.String("WindowManager.FontManager subsection missing in Configuration. Running on defaults"); KernelLog.Ln
			END Error;

		BEGIN { EXCLUSIVE }
			section := Configuration.GetSection("WindowManager.FontManager.FontLoaders");
			IF section # NIL THEN
				enum := section.GetContents();
				WHILE enum.HasMoreElements() DO
					p := enum.GetNext();
					IF p IS XML.Element THEN
						e := Configuration.GetNamedElement(p(XML.Element), "Setting", "Exact");
						IF e # NIL THEN AddExact(e.GetAttributeValue("value")) END;
						e := Configuration.GetNamedElement(p(XML.Element), "Setting", "Approximate");
						IF e # NIL THEN AddApproximate(e.GetAttributeValue("value")) END;
					END;
				END;
				Configuration.Get("WindowManager.FontManager.DefaultFont.Name", defaultFontName, res);
				Configuration.Get("WindowManager.FontManager.DefaultFont.Size", string, res);
				IF (res = Configuration.Ok) THEN Strings.StrToInt(string, defaultFontSize); END;
			ELSE Error;
			END
		END GetConfig;

		PROCEDURE Load(ln : String; fi : FontInfo) : WMGraphics.Font;
		VAR
			factory : FontFactory; font : WMGraphics.Font;
			moduleName, procedureName : Modules.Name;
			msg : ARRAY 32 OF CHAR; res : LONGINT;
		BEGIN
			IF (ln = NIL) THEN RETURN NIL END;
			font := NIL;
			Commands.Split(ln^, moduleName, procedureName, res, msg);
			IF (res = Commands.Ok) THEN
				GETPROCEDURE(moduleName, procedureName, factory);
				IF (factory # NIL) THEN
					font := factory(fi);
				END;
			END;
			RETURN font;
		END Load;

		PROCEDURE GetFont*(CONST name : ARRAY OF CHAR; size : LONGINT; style : SET) : WMGraphics.Font;
		VAR tf,f : WMGraphics.Font; l : LoaderInfo; fi : FontInfo; i: LONGINT;
		BEGIN {EXCLUSIVE}
			font := defaultFont;
			found := FALSE;

			i := (lruPosition-1) MOD LEN(lru);
			REPEAT
				i := (i - 1) MOD LEN(lru);
				f := lru[i];
				IF f = NIL THEN i := lruPosition
				ELSIF (f.size = size) & (f.style = style) & (f.name= name)THEN
					font := f; found := TRUE;
				END;
			UNTIL (i = lruPosition) OR found;

			IF ~found THEN
				COPY(name, searchName); searchSize := size; searchStyle := style;
				fontCache.Enumerate(MatchExact);
				IF ~found THEN
					NEW(fi);
					fi.name := Strings.NewString(name);
					fi.size := size; fi.style := style;
					(* search for exact matches *)
					l := exactLoaders;
					WHILE ~found & (l # NIL) DO
						tf := Load(l.loader, fi);
						IF tf # NIL THEN font := tf; fontCache.Add(font, NIL); found := TRUE END;
						l := l.next;
					END;
					(* search for approximate matches (not exact style) *)
					IF ~found THEN fontCache.Enumerate(MatchSimiliar) END;
					l := approximateLoaders;
					WHILE ~found & (l # NIL) DO
						tf := Load(l.loader, fi);
						IF tf # NIL THEN font := tf; fontCache.Add(font, NIL); found := TRUE END;
						l := l.next;
					END
				END;
				lru[lruPosition] := font; lruPosition := (lruPosition+1) MOD LEN(lru);

			END;
			RETURN font
		END GetFont;

	END FontManager;

VAR fm : FontManager;

PROCEDURE Install*;
BEGIN
	fm.GetConfig();
END Install;

PROCEDURE Load;
BEGIN
	NEW(fm);
	WMGraphics.InstallFontManager(fm)
END Load;

PROCEDURE Cleanup;
BEGIN
	WMGraphics.InstallFontManager(NIL)
END Cleanup;

BEGIN
	Load;
	Modules.InstallTermHandler(Cleanup)
END WMFontManager.
