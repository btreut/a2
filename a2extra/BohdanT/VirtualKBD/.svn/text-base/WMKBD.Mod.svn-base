MODULE WMKBD;(** AUTHOR "BohdanT"; PURPOSE "screen keyboard"; *)
IMPORT
	Modules, WMComponents, WM := WMWindowManager, WSC:=WMStandardComponents,WMWindowManager,
	Strings, VirtualKBD, Inputs,WMGraphics,KernelLog,WMMenus,WMTrees,UTF8Strings,WMInputMethods,
	Texts;
VAR
	caps,shift,ctrl,alt,meta:BOOLEAN; 
	scalef:REAL;
	SaveSwitchCallback:WMInputMethods.IMToolSwitchCallback;
	curchar:VirtualKBD.KeyCap ;

CONST
	pheight=16;(*Height of top panel*)
TYPE
	KBDBut = WSC.Button;
	
	Window* = OBJECT (WMComponents.FormWindow)
		VAR
			ime:WMInputMethods.IME;
			lx,ly:LONGINT;
			panel,spanel : WSC.Panel;
			menu : WMTrees.Tree;
			menuPanel : WMMenus.MenuPanel;
			tmp:ANY;

		PROCEDURE &New;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			vc := CreateForm ();
			(*scaling:=TRUE;*)
			Init (vc.bounds.GetWidth (), vc.bounds.GetHeight (), TRUE);
			SetContent (vc);
			WMWindowManager.ExtAddWindow(SELF, 100, 100, {WM.FlagStayOnTop,WM.FlagNoFocus(*, WM.FlagFrame*)});
			
			SetTitle (Strings.NewString ("Virtual KBD"));
			(**hook toolSwitch procedure*)
			SaveSwitchCallback:=WMInputMethods.toolSwitch;
			GETPROCEDURE("WMKBD","ChangeAppearance",WMInputMethods.toolSwitch);	
		END New;

		PROCEDURE Close ;
		BEGIN
			Close^;
			winstance := NIL
		END Close;

		PROCEDURE CreateKBD(CONST name:ARRAY OF CHAR;f:BOOLEAN);
		VAR
			 i:LONGINT;
			k:VirtualKBD.VKey;
			but : KBDBut;
		BEGIN
			VirtualKBD.LoadVKeyTable(name);
				FOR i:=0 TO VirtualKBD.keys.GetCount()-1 DO
					tmp:=VirtualKBD.keys.GetItem(i); 
					k:=tmp(VirtualKBD.VKey);
					NEW(but);
						but.alignment.Set(WMComponents.AlignNone);
						but.bounds.SetLeft(Round(k.l*scalef));but.bounds.SetTop(Round(k.t*scalef)+pheight); but.bounds.SetExtents(Round(k.width*scalef), Round(k.height*scalef));
						but.caption.SetAOC(k.c1);

						but.onClick.Add (Down );
						but.userData:=k;
						but.fillColor.Set(WMGraphics.Red);
						k.data:=but;
					IF (k.c1="CAPS") OR(k.c1="CTRL")OR(k.c1="ALT")OR(k.c1="SHIFT")OR(k.c1="META") THEN 
						but.isToggle.Set(TRUE);  
					END;
					panel.AddContent(but);
					IF f THEN		
							but.Reset(NIL,NIL);
					END;		
				END;
		
		END CreateKBD;

		PROCEDURE CreateForm () : WMComponents.VisualComponent;	(* A *)
		VAR 
			but : WSC.Button;
			PROCEDURE CreateMenu;
			VAR
				root : WMTrees.TreeNode;
			BEGIN
				NEW(menu); NEW(root);NEW(menuPanel);
				menuPanel.fillColor.Set(SHORT(08080FFFFH));menuPanel.bounds.SetHeight(pheight); menuPanel.bounds.SetWidth(100);
				menuPanel.alignment.Set(WMComponents.AlignLeft); menuPanel.horizontal.Set(TRUE);
				menuPanel.openDirection.Set(WMMenus.OpenDownRight);
				menuPanel.SetMenu(menu, root);

				menuPanel.onSelect.Add(SelectKBD);
				spanel.AddContent(menuPanel);
				SetDocument;
			END CreateMenu;

			PROCEDURE SetDocument;
			VAR 
				node : WMTrees.TreeNode;
				newNode : WMTrees.TreeNode;
				 i:LONGINT;
				 k:VirtualKBD.Keyboard;

				PROCEDURE AddMenuItem(node : WMTrees.TreeNode; k:VirtualKBD.Keyboard );
				VAR newNode : WMTrees.TreeNode;
				BEGIN
					NEW(newNode);
					menu.AddChildNode(node, newNode);
					menu.SetNodeData(newNode, k);
					menu.SetNodeCaption(newNode, WMComponents.NewString(k.name));
				END AddMenuItem;
				
			BEGIN
				NEW(node);
				menu.Acquire;
				menu.SetRoot(node);
				menu.SetNodeState(node, {WMTrees.NodeAlwaysExpanded});
				NEW(newNode);
				menu.AddChildNode(node, newNode);
				menu.SetNodeCaption(newNode,WMComponents.NewString("KBDS"));
				FOR i:=0 TO VirtualKBD.keyBoards.GetCount()-1 DO
					tmp:=VirtualKBD.keyBoards.GetItem(i); 
					 k:=tmp(VirtualKBD.Keyboard);
					AddMenuItem(newNode,k);
				END;
				menu.Release;
				menuPanel.SetMenu(menu, node)
			END SetDocument;
			
		BEGIN
			
			NEW (panel); 
			CreateKBD("wmkbd.en.xml",FALSE);
			
			panel.bounds.SetExtents (Round(VirtualKBD.keys.l*scalef),Round(VirtualKBD.keys.t*scalef)+pheight); panel.fillColor.Set (0);
			panel.SetExtPointerDownHandler(HandlePointerDown);
			panel.SetExtPointerMoveHandler(HandlePointerMove) ;
			NEW (spanel); spanel.bounds.SetExtents (Round(VirtualKBD.keys.l*scalef),pheight); spanel.fillColor.Set (WMGraphics.Blue);
			spanel.alignment.Set(WMComponents.AlignTop);
(*			CreateMenu();*)
			
				NEW(but);
				but.alignment.Set(WMComponents.AlignLeft);but.caption.SetAOC("+");but.onClick.Add (ScaleP );
				spanel.AddContent(but);
				
				NEW(but);
				but.alignment.Set(WMComponents.AlignLeft);but.caption.SetAOC("-");but.onClick.Add (ScaleM);
				spanel.AddContent(but);

				NEW(but);
				but.alignment.Set(WMComponents.AlignRight);but.caption.SetAOC("H/S");but.onClick.Add (HideShow );
				spanel.AddContent(but);
			
			panel.AddContent(spanel);
			spanel.SetExtPointerDownHandler(HandlePointerDown);
			spanel.SetExtPointerMoveHandler(HandlePointerMove) ;
	
			RETURN panel;
		END CreateForm;
		
		PROCEDURE SelectKBD(sender, data : ANY);
		VAR
			kbd:VirtualKBD.Keyboard;
			i:LONGINT;
			but : WSC.Button;
		BEGIN
			IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
				menu.Acquire;
				panel.visible.Set(FALSE);
				FOR i:=0 TO VirtualKBD.keys.GetCount()-1 DO
					tmp:=VirtualKBD.keys.GetItem(i);
					WITH tmp:VirtualKBD.VKey DO
						but:=tmp.data(WSC.Button);
						panel.RemoveContent(but);
					END;
				END;
				tmp:=menu.GetNodeData(data(WMTrees.TreeNode));
				kbd:=tmp(VirtualKBD.Keyboard);
				
				KernelLog.String(kbd.file);KernelLog.Ln;
				CreateKBD(kbd.file, TRUE);
				ReScale;
				panel.visible.Set(TRUE);
				menu.Release;
			END;
		END SelectKBD;
		
		PROCEDURE HideShow(sender, data: ANY);
		VAR
			w,h:LONGINT;
		BEGIN
			manager.SetWindowSize(SELF,w,h);
			IF h<=pheight THEN 
				h:=Round(VirtualKBD.keys.t*scalef)+pheight;
			ELSE 
				h:=pheight;
			END;
			manager.SetWindowSize(SELF,w,h);
			Resized(w, h);
			panel.bounds.SetExtents (Round(VirtualKBD.keys.l*scalef),Round(VirtualKBD.keys.t*scalef)+pheight);
		END HideShow;
		
		PROCEDURE ScaleP(sender, data: ANY);
		BEGIN
			scalef:=scalef*1.414214;
			ReScale();	
		END ScaleP;
		
		PROCEDURE ScaleM(sender, data: ANY);
		BEGIN
			scalef:=scalef/1.414214;
			ReScale();
		END ScaleM;
		
		PROCEDURE ReScale;
		VAR 
			i:LONGINT;
			k:VirtualKBD.VKey;
			but : WSC.Button;
			w,h:LONGINT;
		BEGIN
			w:=Round(VirtualKBD.keys.l*scalef);
			h:=Round(VirtualKBD.keys.t*scalef)+pheight;
			manager.SetWindowSize(SELF,w,h);
			Resized(w, h);
			
			panel.bounds.SetExtents (Round(VirtualKBD.keys.l*scalef),Round(VirtualKBD.keys.t*scalef)+pheight);
			panel.visible.Set(FALSE);
			FOR i:=0 TO VirtualKBD.keys.GetCount()-1 DO
				tmp:=VirtualKBD.keys.GetItem(i);
				k:=tmp(VirtualKBD.VKey);
				but:=k.data(WSC.Button);
(*!!!!				but.fontHeight.Set(24);*)
				but.bounds.SetLeft(Round(k.l*scalef));but.bounds.SetTop(Round(k.t*scalef)+pheight); but.bounds.SetExtents(Round(k.width*scalef), Round(k.height*scalef));
			END;
			panel.visible.Set(TRUE);

		END ReScale;
		
		PROCEDURE HandlePointerMove(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR dx, dy : LONGINT;
		BEGIN
		
			IF 0 IN keys THEN 
				dy := y - ly;	dx := x - lx;
				manager.SetWindowPos (SELF, bounds.l + dx, bounds.t+dy);
			END;
			handled := TRUE
		END HandlePointerMove;		
		PROCEDURE HandlePointerDown(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		BEGIN
			lx := x; ly := y;
		END HandlePointerDown;
		
		
		(**next procedures need for IMEInterface*)
		PROCEDURE InsertUCS32(atPosition : LONGINT; CONST string : Texts.UCS32String);
		BEGIN
			UTF8Strings.UnicodetoUTF8(string, curchar); (**save caption of key to curchar*)
		END InsertUCS32;
		(**stub procedures*)
		PROCEDURE SetCursorInfo(position : LONGINT); BEGIN END SetCursorInfo;
		PROCEDURE Dummy; BEGIN END Dummy;
		PROCEDURE GetCursorPosition():LONGINT;BEGIN RETURN 0; END GetCursorPosition;
		PROCEDURE GetCursorScreenPosition(VAR x, y : LONGINT); BEGIN END GetCursorScreenPosition;

		PROCEDURE SetIMEInterface(ime : WMInputMethods.IME);
		VAR i : WMInputMethods.IMEInterface;
		BEGIN
			ASSERT((ime # NIL));
			i.AcquireText := Dummy; i.ReleaseText := Dummy;
			i.InsertUCS32 := InsertUCS32;
			i.GetCursorPosition := GetCursorPosition; i.GetCursorScreenPosition := GetCursorScreenPosition;
			i.SetCursorInfo := SetCursorInfo;
			ime.SetInterface(i);
		END SetIMEInterface;

		(** ChangeAppearance called when IME changed*)
		PROCEDURE ChangeAppearance;
		BEGIN
			IF SaveSwitchCallback#NIL THEN SaveSwitchCallback END;
			RefreshKBDCaption;
			
		END  ChangeAppearance;
		PROCEDURE  RefreshKBDCaption;
		VAR
			i:LONGINT;
 			k:VirtualKBD.VKey;
 			b:KBDBut;
			ime : WMInputMethods.IME;
		BEGIN
				ime := WMInputMethods.activeIME;
				IF ime#NIL THEN SetIMEInterface(ime); END;
				FOR i:=0 TO VirtualKBD.keys.GetCount()-1 DO
					tmp:=VirtualKBD.keys.GetItem(i);
					k:=tmp(VirtualKBD.VKey);

					b:=k.data(KBDBut);
					IF (ime # NIL) & (k.scan=0)&(Strings.Length(k.c1)=1) THEN
						ime.KeyEvent(ORD(k.c1[0]), {Inputs.Release},0);
						k.cap1:=curchar;
					ELSE
						k.cap1:=k.c1;
					END;
					
					IF (ime # NIL) & (k.scan=0)&(Strings.Length(k.c2)=1) THEN
						ime.KeyEvent(ORD(k.c2[0]), {Inputs.Release},0);
						k.cap2:=curchar;
					ELSE
						k.cap2:=k.c2;
					END;
				END;
				RefreshKBD;
		END RefreshKBDCaption;


		PROCEDURE  RefreshKBD;
		VAR
			i:LONGINT;
 			k:VirtualKBD.VKey;
 			b:KBDBut;
			ime : WMInputMethods.IME;
		BEGIN
				FOR i:=0 TO VirtualKBD.keys.GetCount()-1 DO
					tmp:=VirtualKBD.keys.GetItem(i);
					k:=tmp(VirtualKBD.VKey);

					b:=k.data(KBDBut);
					b.SetPressed(FALSE);
					IF (k.c1="CAPS")&(caps) THEN b.SetPressed(TRUE);
					ELSIF (k.c1="CTRL")&(ctrl) THEN b.SetPressed(TRUE);
					ELSIF (k.c1="ALT")&(alt) THEN b.SetPressed(TRUE);
					ELSIF (k.c1="SHIFT")&(shift) THEN b.SetPressed(TRUE);
					ELSIF (k.c1="META")&(meta) THEN b.SetPressed(TRUE);
					ELSE
						IF ~((caps&~shift)OR(~caps&shift))OR(k.c2="") THEN
								b.caption.SetAOC(k.cap1);
						ELSIF (k.scan=0)&(Strings.Length(k.c2)=1) THEN
								b.caption.SetAOC(k.cap2);
						END;
					END;
				END;
		END RefreshKBD;

		PROCEDURE Down(sender, data: ANY);
		VAR
			key:VirtualKBD.VKey;
			km:Inputs.KeyboardMsg;
 			b:KBDBut;

		BEGIN
			key:=data(VirtualKBD.VKey);
			b:=sender(KBDBut);

			IF key.c1="CAPS" THEN caps:=~caps; RefreshKBD();  RETURN;END;
			IF key.c1="CTRL" THEN ctrl:=~ctrl;  RefreshKBD(); RETURN; END;
			IF key.c1="ALT" THEN alt:=~alt; RefreshKBD();  RETURN;END;
			IF key.c1="SHIFT" THEN shift:=~shift; RefreshKBD(); RETURN; END;
			IF key.c1="META" THEN meta:=~meta;RefreshKBD();  RETURN; END;
			
			IF alt THEN km.flags := km.flags + Inputs.Alt;END;
			IF shift THEN km.flags := km.flags + Inputs.Shift;END;
			IF ctrl THEN km.flags := km.flags + Inputs.Ctrl;END;
			IF meta THEN km.flags := km.flags + Inputs.Meta;END;
			
			IF key.scan#0 THEN
				km.keysym:=key.scan;
			ELSE
				IF ctrl THEN
					IF (ORD(key.c1[0])>=ORD("a"))&(ORD(key.c1[0])<=ORD("z")) THEN
						km.keysym:=ORD(key.c1[0])+1-ORD("a");
					ELSE
						km.keysym:=ORD(key.c1[0]);
					END
				ELSIF ((caps&~shift)OR(~caps&shift))&(key.c2#"") THEN
					km.ch:=key.c2[0];
				ELSE
					km.ch:=key.c1[0];
				END;	
			END;
			KernelLog.String("km.keysym= "); KernelLog.Int(km.keysym, 0); KernelLog.Ln;
			Inputs.keyboard.Handle(km);
			km.keysym:=0FFFFFFH;
			km.flags:={Inputs.Release};
			Inputs.keyboard.Handle(km);
			shift:=FALSE;ctrl:=FALSE;alt:=FALSE;meta:=FALSE;
			RefreshKBD();
		END Down;
	END Window;

VAR
	winstance : Window;
(** Round - helper procedure, work correctly only for positive value*)
PROCEDURE Round(r:REAL):LONGINT;
BEGIN
	RETURN ENTIER(r+0.5);
END Round;

(** Standard single window, non-restorable. *)
PROCEDURE Open*;
BEGIN
	IF winstance = NIL THEN NEW (winstance) END;
END Open;

(** Hack IME subsystem*)
PROCEDURE ChangeAppearance*;
BEGIN
	winstance.ChangeAppearance;
END ChangeAppearance;	

PROCEDURE Cleanup;
BEGIN
	WMInputMethods.toolSwitch:=SaveSwitchCallback;

	IF winstance # NIL THEN winstance.Close END
	
END Cleanup;

BEGIN
	scalef:=0.5;(*Set Default scale factor*)
	Modules.InstallTermHandler (Cleanup);
	(* Additional BEGIN processing. *)
END WMKBD.Open ~

SystemTools.Free WMKBD~