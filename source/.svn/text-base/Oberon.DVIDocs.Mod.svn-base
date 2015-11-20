MODULE DVIDocs IN Oberon;
(** Implements a document-type to display dvi-files as produced
    by the typesetting-system TeX.
    Usage: Desktops.OpenDoc test.dvi(DVIDocs.NewDoc)~
    to open file "test.dvi". **)
IMPORT Attributes, Desktops, Documents,
   Gadgets, Links, Objects, Out, DVIFiles, DVIViewers, Oberon;
CONST
   Version* = 100; (** version 1.00 **)

   PROCEDURE Load(D: Documents.Document);
   VAR
      view: Objects.Object;
   BEGIN
      view:= Gadgets.CreateViewModel("DVIViewers.New","DVIFiles.New");
      Attributes.SetString(view,"Name","DVIViewer");
      WITH view: Gadgets.Frame DO
         Attributes.SetString(view.obj,"File",D.name);
         D.X := 0; D.Y := 0; D.W := 550; D.H := 600;
         Documents.Init(D,view)
      END
   END Load;

   PROCEDURE Store(D: Documents.Document);
   BEGIN
      Out.String("DVI documents cannot be stored."); Out.Ln
   END Store;

   PROCEDURE Handler(D: Objects.Object; VAR M: Objects.ObjMsg);
   BEGIN
      WITH D: Documents.Document DO
         IF M IS Objects.AttrMsg THEN
            WITH M: Objects.AttrMsg DO
               IF M.id = Objects.get THEN
                  IF M.name = "Gen" THEN
                     M.class := Objects.String;
                     M.s := "DVIDocs.NewDoc"; M.res := 0
                  ELSIF M.name = "Adaptive" THEN
                     M.class := Objects.Bool; M.b := TRUE; M.res := 0
                  ELSIF M.name = "Icon" THEN
                     M.class := Objects.String;
                     M.s := "Icons.Tool"; M.res := 0
                  ELSE Documents.Handler(D, M)
                  END
               ELSE Documents.Handler(D, M)
               END
            END
         ELSIF M IS Objects.LinkMsg THEN
            WITH M: Objects.LinkMsg DO
               IF (M.id = Objects.get) &
                  ((M.name = "DeskMenu") OR (M.name = "SystemMenu") OR
                  (M.name = "UserMenu")) THEN
                  M.obj := Gadgets.CopyPublicObject("DVI.DeskMenu",TRUE);
                  IF M.obj = NIL THEN
                     Out.String("Library DVI not found."); Out.Ln; HALT(25)
                  END;
                  Links.SetLink(D.dsc,"PageNumber",
                     Gadgets.FindObj(M.obj,"PageNumber"));
                  Links.SetLink(D.dsc,"ZoomNumber",
                     Gadgets.FindObj(M.obj,"ZoomNumber"));
                  M.res := 0
               ELSE Documents.Handler(D, M)
               END
            END
         ELSE Documents.Handler(D, M)
         END
      END
   END Handler;

   PROCEDURE NewDoc*;
   VAR D: Documents.Document;
   BEGIN
      NEW(D); D.Load := Load; D.Store := Store; D.handle := Handler;
      Objects.NewObj:= D
   END NewDoc;

   PROCEDURE Copy*;
   VAR
      curr: Documents.Document; (* the doc to copy *)
      v: DVIViewers.Frame; (* the above doc's dvi-viewer *)
      m: DVIFiles.File; (* the above doc's model *)
      new: Documents.Document; (* the new doc *)
      M: Objects.CopyMsg; (* message to create new viewer *)
      nv: DVIViewers.Frame; (* the new doc's dvi-viewer *)
      num: Objects.Object;
      i: LONGINT; r: REAL;
   BEGIN
      curr:= Desktops.CurDoc(Gadgets.context);
      v:= curr.dsc(DVIViewers.Frame);
      m:= v.obj(DVIFiles.File);
      NewDoc; (* create a new document *)
      new:= Objects.NewObj(Documents.Document);
      M.id:= Objects.shallow; Objects.Stamp(M);
      v.handle(v,M); (* create a new viewer *)
      nv:= M.obj(DVIViewers.Frame);
      Attributes.SetString(nv,"Name","DVIViewer");
      Links.SetLink(nv,"Model",m);
      new.X := 0; new.Y := 0; new.W := curr.W; new.H := curr.H;
      Documents.Init(new,nv);
      Attributes.SetString(new,"DocumentName",curr.name);
      Desktops.ShowDoc(new);
      (* now copy zoom- and page-number: *)
      Links.GetLink(v,"ZoomNumber",num);
      Attributes.GetReal(num,"Value",r);
      Links.GetLink(nv,"ZoomNumber",num);
      Attributes.SetReal(num,"Value",r);
      Gadgets.Update(num);
      Links.GetLink(v,"PageNumber",num);
      Attributes.GetInt(num,"Value",i);
      Links.GetLink(nv,"PageNumber",num);
      Attributes.SetInt(num,"Value",i);
      Gadgets.Update(num);
      Gadgets.Update(nv);
   END Copy;

   PROCEDURE Grow*;
   VAR obj: Objects.Object; DW: INTEGER;
   BEGIN
      obj := Gadgets.context;
      WHILE (obj # NIL) & ~((obj IS Desktops.DocGadget) OR
         (obj IS Desktops.DocViewer)) DO
         obj := obj.dlink
      END;
      IF (obj # NIL) & (obj IS Desktops.DocViewer) THEN  (* Viewer *)
         DW := Oberon.DisplayWidth(100);
         Oberon.OpenTrack(Oberon.UserTrack(100),DW);
         Copy;
      END
   END Grow;

END DVIDocs.
