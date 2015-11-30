(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMUI;	(** AUTHOR "prk"; PURPOSE "GUI plugin for Jaos" *)

IMPORT
		SYSTEM,
		AosOut,
		AosModules, AosFS,
		UTF8Strings,
		JVMConsole,
		Base := WMComponents, AosTexts,
		WM := WMWindowManager, Standard := WMStandardComponents, Editors := WMEditorComponents,
		Graphics := WMGraphics, WMBitmapFont;
		
CONST
	DefaultWidth = 590;
	DefaultHeight = 450;
	
TYPE 
	(* TextBuffer for the keyboard input; flushed at every CR *)
	BufferArray = POINTER TO ARRAY OF LONGINT;
	Buffer = OBJECT
		VAR 
			buf: BufferArray;
			pos: LONGINT;
			rider: AosFS.Rider;
		
		PROCEDURE & Init;
		BEGIN
			NEW(buf, 64);
		END Init;
		
		PROCEDURE Insert(ucs: LONGINT);
			VAR size: LONGINT; tmp: BufferArray;
		BEGIN
			size := LEN(buf^);
			IF (pos = size) THEN	(* grow array *)
				NEW(tmp, 2*size);
				SYSTEM.MOVE(SYSTEM.ADR(buf[0]), SYSTEM.ADR(tmp[0]), 4*size);
				buf := tmp
			END;
			buf[pos] := ucs;
			INC(pos)
		END Insert;
		
		PROCEDURE Delete;
		BEGIN DEC(pos)
		END Delete;
		
		PROCEDURE Flush;
			VAR utf8: ARRAY 64 OF CHAR; i, j, res: LONGINT; dummy: BOOLEAN;
		BEGIN
			i := 0; j := 0;
			WHILE i < pos DO
				WHILE (j < 60) & (i < pos) DO
					dummy := UTF8Strings.EncodeChar(buf[i], utf8, j);
					INC(i)
				END;
				AosOut.String("write to stdin"); AosOut.Ln;
				AosOut.Memory(SYSTEM.ADR(utf8[0]), j); AosOut.Ln;
				JVMConsole.input.Send(utf8, 0, j, FALSE, res);
				j := 0
			END;
			utf8[0] := 0AX; utf8[1] := 0DX; utf8[2] := 0AX; utf8[3] := 0DX; 
			JVMConsole.input.Send(utf8, 0, 4, FALSE, res);
			pos := 0;
		END Flush;
	END Buffer;

VAR
	buffer: Buffer;

TYPE	
	(* Copied fro LogWindow.Mod *)
	Window = OBJECT (Base.FormWindow)
	VAR 
		panel : Standard.Panel;
		out : Editors.Editor;
		
	
		PROCEDURE &New(w, h: LONGINT);
		BEGIN
			NEW(panel); panel.SetWidth(w); panel.SetHeight(h); panel.SetColor(Graphics.RGBAToColor(255, 255, 255, 255));
			NEW(out); out.SetAlign(Base.AlignClient); out.SetShowBorder(TRUE); panel.AddContent(out);
			Init(panel.GetWidth(), panel.GetHeight(), FALSE);
			SetContent(panel);
			out.SetReadOnly(TRUE);
			out.font := WMBitmapFont.bimbofont;
			out.SetText(text); 
			manager := WM.GetDefaultManager();
			SetTitle(WM.NewString("Jaos log"));
			manager.Add(100, 100, SELF, {WM.FlagFrame})
		END New;
		
		PROCEDURE Close;
		BEGIN
			console := NIL;
			Close^
		END Close;
		
		PROCEDURE KeyEvent(ucs: LONGINT; flags: SET; keysym: LONGINT);
			VAR str: ARRAY 3 OF LONGINT;
		BEGIN
(*
			AosOut.String("KeyEvent  ucs = ");
			AosOut.Hex(ucs, 8);
			AosOut.String("   flags = ");
			AosOut.Hex(SYSTEM.VAL(LONGINT, flags), 8);
			AosOut.String("   keysym = ");
			AosOut.Hex(keysym, 8);
			AosOut.Ln;
*)			
			IF ucs = 0DH THEN	(* ENTER *)
				text.AcquireWrite;
				str[0] := 0AH; str[1] := 0H; str[2] := 0;
				text.InsertUCS32(text.GetLength(), str);
				text.ReleaseWrite;
				buffer.Flush;
			ELSIF ucs = 7FH THEN	(* BACKSPACE *)
				buffer.Delete;
				text.AcquireWrite;
				text.Delete(text.GetLength()-1, 1);
				text.ReleaseWrite;
			ELSIF (ucs > 0H) & (ucs <= 7FH) THEN
				buffer.Insert(ucs);
				str[0] := ucs;
				str[1] := 0;
				text.AcquireWrite;
				text.InsertUCS32(text.GetLength(), str);
				text.ReleaseWrite;
			END

		END KeyEvent;
		
	END Window;
	
VAR
	console: Window;
	text: AosTexts.UnicodeText;
	
	CR: ARRAY 2 OF AosTexts.Char32;

	(** Console Admin Functions *)

	PROCEDURE Open*(w, h: LONGINT);
	BEGIN
		IF console = NIL THEN
			NEW(text);
			text.New;
			NEW(console, w, h);
		END
	END Open;
	
	PROCEDURE DefaultOpen*;
	BEGIN  Open(DefaultWidth, DefaultHeight)
	END DefaultOpen;
	
	PROCEDURE Close*;
	BEGIN
		IF console # NIL THEN
			console.Close;
			console := NIL;
			text := NIL
		END
	END Close;
	
	(** Console Output Functions *)
	
	PROCEDURE WriteChar*(ch: CHAR);
		VAR str: ARRAY 2 OF LONGINT;
	BEGIN (*{EXCLUSIVE}*)
		IF console = NIL THEN Open(DefaultWidth, DefaultHeight) END;
		str[0] := ORD(ch);
		str[1] := 0;
		text.AcquireWrite;
		text.InsertUCS32(text.GetLength(), str);
		text.ReleaseWrite
	END WriteChar;
	
	PROCEDURE WriteBytes*(VAR buf: ARRAY OF CHAR; offset, count: LONGINT);
		VAR i: LONGINT; ch: CHAR; str: ARRAY 256 OF AosTexts.Char32; dummy: BOOLEAN;
	BEGIN
		IF console = NIL THEN Open(DefaultWidth, DefaultHeight) END;
		text.AcquireWrite;
		i := 0;
		WHILE i < count DO
			dummy := UTF8Strings.DecodeChar(buf, offset, str[i]); INC(i);
			IF i = 255 THEN
				str[255] := 0;
				text.InsertUCS32(text.GetLength(), str);
				i := 0;
				DEC(count, 255)
			END
		END;
		IF i # 0 THEN
			str[i] := 0;
			text.InsertUCS32(text.GetLength(), str);
		END;
		text.ReleaseWrite;
	END WriteBytes;

	PROCEDURE WriteLn*;
	BEGIN (*{EXCLUSIVE}*)
		IF console = NIL THEN Open(DefaultWidth, DefaultHeight) END;
		text.AcquireWrite;
		text.InsertUCS32(text.GetLength(), CR);
		text.ReleaseWrite
	END WriteLn;

	PROCEDURE Install*;
	BEGIN
		JVMConsole.writeLn := WriteLn;
		JVMConsole.writeBytes := WriteBytes
	END Install;
	
	PROCEDURE CleanupHandler;
	BEGIN
		Close;
		JVMConsole.ConsoleToDefault;
	END CleanupHandler;

BEGIN
	NEW(buffer);
	AosModules.InstallTermHandler(CleanupHandler);
	JVMConsole.CR[0] := CHR(AosTexts.NewLineChar); JVMConsole.CR[1] := 0X;

	Install
END JVMUI.
