MODULE WMEthiopicIME; (** AUTHOR "Patrick Hunziker"; PURPOSE "Ethiopian alphabet: Ge'ez abugida "; *)

(* for a detailed explanation of the ethiopic script(s), see http://en.wikipedia.org/wiki/Ge%27ez_script  
for a discussion about ethiopic keyboard layouts, see http://keyboards.ethiopic.org/specification/#AppendixA 
for a repository of ethiopic fonts, see http://www.wazu.jp/gallery/Fonts_Ethiopic.html 
for unicode numbers, see unicode documentation range 1200-137F 
*)

(* the ethiopic script has a letter per syllabe, usually a consonant followed by a vowel 
 the principles of keyboard layout follow the papers above.
 Some consonants or vowels are constructed by doubling a keystroke.
 E.g., there are several consonants for variants "s", which can be encoded by typing "s", "ss", "S", "SS" followed by one (or 2,3) vowels.
 *)

(*! Note that the Ethiopic Fonts are not part of the default font package Single.ccg . 
To edit a text in ethiopic script, an ethiopic font, e.g. "Jiret.ttf" needs to be loaded. 
This can be done using the TextStyle Tool or by program. 
 *)
 
 

IMPORT
	Strings, WMInputMethods, WMGraphics, Texts, KernelLog, Commands, TextUtilities;

CONST
	imeName* = "Ethiopic";

TYPE
	IME* = OBJECT(WMInputMethods.IME)
		VAR cons,vow: LONGINT; (* count the consonants and vowels to detect specific keycodes*)
			ucs0, geez:LONGINT;
			
		PROCEDURE GetName*() : Strings.String;
		BEGIN
			RETURN Strings.NewString(imeName);
		END GetName;
		
		PROCEDURE Reset;
		BEGIN
			cons:=0; vow:=0; geez:=0; ucs0:=0H;
		END Reset;

		PROCEDURE Remap(ucs1:LONGINT):LONGINT;
		VAR ucs2:LONGINT;
		BEGIN
			CASE ucs1 OF
				| 01201H: ucs2:=1288H; (*hu*)	(*remap unicode to other character block*)
				| 01241H: ucs2:=1248H; (*qu*)
				| 01281H: ucs2:=1288H; (*hhu*)
				| 012A9H: ucs2:=12B0H; (*ku*)
				| 01309H: ucs2:=1310H; (*gu*)
			ELSE ucs2:=ucs1-1; (* remap unicode within character block*)
			END;
			RETURN ucs2
		END Remap;

		(* Map characters from US-Keyboard to ethiopic keyboard *)
		PROCEDURE KeyEvent*(ucs : LONGINT; flags : SET; keysym : LONGINT);
		BEGIN
			IF ((ucs>=65) & (ucs<=90)) OR  ((ucs>=97)&(ucs<=122)) THEN		
				CASE ucs OF
					(* vowels key *) 
					| 65H, 45H : (*e,E*)
						IF cons>0 THEN 
							IF (ucs0=49H) OR (ucs0=69H) THEN INC(geez,2); InsertChar(geez); Reset;(*ie*)
							ELSIF (ucs0=55H) OR (ucs0=75H) THEN geez:=Remap(geez); INC(vow); (*ue*)
							ELSE INC(geez,0);  INC(vow);	(*e*)
							END;
						ELSE 
						END;
					| 41H, 61H : (*a,A*)
						IF cons=0 THEN 
							IF ucs=41H THEN geez:=012A0H; INC(cons) (*A*)(* glottal a..o*)
							ELSE geez:=012D0H; INC(cons) (*a*) (* pharyngeal a..o*)
							END;
						ELSIF (ucs0=55H) OR (ucs0=75H) THEN geez:=Remap(geez)+3;INC(vow); (*ua*) 
						ELSE INC(geez,3); INC(vow);
						END;
					| 55H, 75H : (* u,U *)
						IF cons=0 THEN 
						ELSIF (ucs0=55H) OR (ucs0=75H) THEN geez:=Remap(geez)+1; INC(vow);  (* uu *)
						ELSE INC(geez, 1);INC(vow);
						END;
					| 49H, 69H : (* i,I *)
						IF cons=0 THEN 
						ELSIF (ucs0=55H) OR (ucs0=75H) THEN geez:=Remap(geez)+2; INC(vow);(*ui*)
						ELSE INC(geez, 2); INC(vow); (*i*)
						END;
					| 4FH, 6FH : (* o,O *)
						IF cons=0 THEN 
						ELSIF (ucs0=55H) OR (ucs0=75H) THEN geez:=Remap(geez)+6; (*does not occur*)(*uo*)
						ELSE INC(geez, 6); INC(vow); (*o*)
						END;
				ELSE 
					IF (cons>0) & ((vow>0) OR (ucs#ucs0)) THEN InsertChar(geez); Reset; END;
				END;
				ucs0:=ucs;
				CASE ucs OF
					(* syllabes *)
					| 68H : 
						IF cons=0 THEN geez:=01200H; INC(cons); (*h*);
						ELSIF (cons=1)&(geez=1200H) THEN geez:=1280H; INC(cons); vow:=0; (*hh*)
						ELSE geez:=01200H; INC(cons);
						END;
					| 6CH, 4CH : geez:=01208H; INC(cons); (*l,L*)
					| 48H : geez:=01210H; INC(cons); (*H*)
					| 6DH, 4DH : geez:=01218H; INC(cons); (*m,M*)
					| 72H, 52H : geez:=01228H; INC(cons); (*r,R*)
					| 73H : 
							IF cons=0 THEN geez:=01230H;  INC(cons);(*s*);
							ELSIF (cons=1)&(geez=1230H) THEN geez:=1220H; INC(cons); vow:=0; (*ss*)
							END;
					| 78H, 58H : geez:=01238H; INC(cons); (*x, X*)
					| 71H, 51H : geez:=01240H; INC(cons); (*q, Q*)
					(* QA, QWA, QHA, QWHA*)					
					| 62H, 42H : geez:=01260H; INC(cons); (*b, B*)
					| 76H, 56H : geez:=01268H; INC(cons); (*v, V*)
					| 74H : geez:=01270H; INC(cons); (*t*)
					| 63H : geez:=01278H; INC(cons); (*c*)
					(* XWA ?*)	
					| 6EH : geez:=01290H; INC(cons); (*n*)
					| 4EH : geez:=01298H; INC(cons); (*N*) (*'NYA'*)
					| 6BH : geez:=012A8H; INC(cons); (*k*)
					| 4BH : geez:=012B0H; INC(cons); (*K*) (*=KWA?*)
					(* 12B8 - KXA, 12C0 - KXWA ?*)				
					| 77H, 57H : geez:=012C8H; INC(cons); (*w, W*) 
					| 7AH : geez:=012D8H; INC(cons); (*z*)
					| 5AH : geez:=012E0H; INC(cons); (*Z*)
					| 79H, 59H : geez:=012EAH; INC(cons); (*y, Y*)
					| 64H, 44H : geez:=012F0H; INC(cons); (*d, D*)
						(* 12F8 - DDA ?*)
					| 6AH, 4AH : geez:=01300H; INC(cons); (*j, J*)
					| 67H, 47H : geez:=01308H; INC(cons); (*g, G*)
						(* 1310 GWA, 1318 GGA*)
					| 54H : geez:=01320H; INC(cons); (*T*)
					| 43H : geez:=01328H; INC(cons); (*C*) 
					| 50H : geez:=01330H; INC(cons); (*P*)
					| 53H : 
							IF cons=0 THEN geez:=01338H;  INC(cons); (*S =TSA*);
							ELSIF  (cons=1)&(geez=1338H) THEN geez:=1340H; INC(cons); vow:=0; (*SS = TZA*)
							END;
					| 66H, 46H : geez:=01348H; INC(cons); (*f, F*)
					| 70H : geez:=01350H; INC(cons); (*p*)
				ELSE
				END;
			ELSE
				IF cons>0 THEN 
					IF vow=0 THEN INC(geez,5); END;
					InsertChar(geez); Reset; 
				END;
				CASE ucs OF
					| 2CH : geez:=01363H; InsertChar(geez); Reset; (* , *)
					| 2EH : geez:=01362H; InsertChar(geez); Reset; (* . *)
					(* to do:
				Punctuation
					1360 ETHIOPIC SECTION MARK
					1361 ETHIOPIC WORDSPACE
					1362 ETHIOPIC FULL STOP
					1363 ETHIOPIC COMMA
					1364 ETHIOPIC SEMICOLON
					1365 ETHIOPIC COLON
					1366 ETHIOPIC PREFACE COLON
					1367 ETHIOPIC QUESTION MARK
					1368 ETHIOPIC PARAGRAPH SEPARATOR
					(* digits*)
					136A ETHIOPIC DIGIT TWO
					136B ETHIOPIC DIGIT THREE
					etc
					*)
				(* shifted *)
					| 22H: geez:=0121FH; InsertChar(geez); Reset; (* " *)
				ELSE 
					InsertChar(ucs); Reset; 
				END;
			END;
			(* to do: show current char in popup *)
		END KeyEvent;

	END IME;

(* installs the Ethiopic IME *)
PROCEDURE Install*;
VAR ime : IME;
BEGIN
	NEW(ime);
	WMInputMethods.InstallIME(ime);
END Install;

(* helper procedure for development : return the UCS code of a selected character in a text *)
PROCEDURE SelectedCharToUCS*;
VAR r : Texts.TextReader;
	selectionText: Texts.Text;
	ucs : LONGINT;
	from, to : Texts.TextPosition;
BEGIN
	IF Texts.GetLastSelection(selectionText, from, to) THEN
		selectionText.AcquireRead;
		NEW(r, selectionText);
		r.SetPosition(Strings.Min(from.GetPosition(), to.GetPosition()));
		r.ReadCh(ucs);
		selectionText.ReleaseRead;
		KernelLog.String("SetChar("); KernelLog.Hex(ucs, 0); KernelLog.String("H; (**)"); KernelLog.Ln;
	END;
END SelectedCharToUCS;

(* helper procedure for development : write an UTF8 character *)
PROCEDURE UCSToChar*(context:Commands.Context);
VAR 
	ucs : LONGINT;
	res:BOOLEAN;
BEGIN
	res:=context.arg.GetInteger(ucs,TRUE);
	TextUtilities.WriteUTF8Char(context.out, ucs); context.out.Update;	
	KernelLog.String("SetChar("); KernelLog.Hex(ucs, 0); KernelLog.String("H; (**)"); KernelLog.Ln;
END UCSToChar;

VAR i:LONGINT; done:BOOLEAN;

BEGIN
	i:=0; 
	WHILE (i<LEN(WMGraphics.fallbackFonts)) & (WMGraphics.fallbackFonts[i]#NIL) DO
		done:= done OR (WMGraphics.fallbackFonts[i].name="jiret");
		IF WMGraphics.fallbackFonts[i].name="jiret" THEN 
			KernelLog.String("found Jiret ethiopic font at "); KernelLog.Int(i,0); KernelLog.Ln;
		END;
		INC(i);
	END;
	(*hack*)
	IF ~done & (i<LEN(WMGraphics.fallbackFonts)) THEN
		KernelLog.String("adding Jiret ethiopic font");KernelLog.Ln;
		WMGraphics.fallbackFonts[i]:=WMGraphics.GetFont("jiret",20,{});
	END;

END WMEthiopicIME.Install~
SystemTools.FreeDownTo WMEthiopicIME~
WMEthiopicIME.SelectedCharToUCS ~
WMEthiopicIME.UCSToChar 121CH ~
WMEthiopicIME.UCSToChar  4636~
WMEthiopicIME.UCSToChar 963FH ~
WMEthiopicIME.UCSToChar 120BH~


WMKeyCode.Open ~
