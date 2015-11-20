MODULE DVIFiles IN Oberon;
(** Implements a model-gagdet for dvi-files as produced by the
    typesetting-system TeX.  The module exports a model gadget
    of type File which loads a dvi-file and provides viewer-gadgets
    with pages. **)
IMPORT Files, Objects, Gadgets, Out, Strings;
CONST
   Version* = 100; (** version 1.00 **)
TYPE
   Special* = POINTER TO SpecialDesc;
   SpecialDesc* = RECORD (* contains cached data about a special *)
      next*: Special; (* leads to the other specials with same pos *)
      pos*: LONGINT; (* position of first data-byte in the dvi-file *)
   END;
   PageDesc = RECORD
      offset: LONGINT;
      specialCacheComplete: BOOLEAN;
      spec: Special
   END;

   FontInfo* = POINTER TO FontInfoDesc;
   FontInfoDesc* = RECORD
      next: FontInfo;
      name*: POINTER TO ARRAY OF CHAR; (** font's name **)
      no: LONGINT;
      checksum*: LONGINT; (** font's tfm-checksum **)
      s,d,a,l: LONGINT; (* cf. DVIViewers *)
      width*: ARRAY 256 OF LONGREAL; (** widths in dvi-units **)
   END;

   File* = POINTER TO FileDesc;
   FileDesc* = RECORD(Gadgets.ObjDesc)
      fileName: ARRAY 128 OF CHAR;
      file: Files.File;
      num*,den*,mag*: LONGREAL;
      pageNr*: LONGINT; (* number of pages in the dvi-file *)
      page: POINTER TO ARRAY OF PageDesc;
      fonts: FontInfo;

   END;


   (** Read an unsigned byte from rider r. **)
   PROCEDURE ReadByte*(VAR r: Files.Rider): LONGINT;
   VAR c: CHAR;
   BEGIN
      Files.Read(r,c);
      RETURN ORD(c)
   END ReadByte;

   (** Read a signed byte from rider r. **)
   PROCEDURE ReadSignedByte*(VAR r: Files.Rider): LONGINT;
   VAR s: SHORTINT;
   BEGIN
      Files.Read(r,s);
      RETURN s
   END ReadSignedByte;

   (** Read an unsigned word (two bytes) from rider r. **)
   PROCEDURE ReadWord*(VAR r: Files.Rider): LONGINT;
   VAR l,u: LONGINT;
   BEGIN
      u:= ReadByte(r); l:= ReadByte(r);
      RETURN u*100H+l;
   END ReadWord;

   (** Read a signed word (two bytes) from rider r. **)
   PROCEDURE ReadSignedWord*(VAR r: Files.Rider): LONGINT;
   CONST Sign = 8000H; Moduli = 10000H;
   VAR s: LONGINT;
   BEGIN
      s:= ReadWord(r);
      IF s >= Sign THEN RETURN s - Moduli
      ELSE RETURN s END
   END ReadSignedWord;

   (** Read an unsigned trio (three bytes) from rider r. **)
   PROCEDURE ReadTrio*(VAR r: Files.Rider): LONGINT;
   VAR l,u: LONGINT;
   BEGIN
      u:= ReadByte(r); l:= ReadWord(r);
      RETURN u*10000H+l;
   END ReadTrio;

   (** Read a signed trio (three bytes) from rider r. **)
   PROCEDURE ReadSignedTrio*(VAR r: Files.Rider): LONGINT;
   CONST Sign = 800000H; Moduli = 1000000H;
   VAR s: LONGINT;
   BEGIN
      s:= ReadTrio(r);
      IF s >= Sign THEN RETURN s - Moduli
      ELSE RETURN s END
   END ReadSignedTrio;

   (** Read a signed quad (four bytes) from rider r. **)
   PROCEDURE ReadSignedQuad*(VAR r: Files.Rider): LONGINT;
   VAR l,u: LONGINT;
   BEGIN
      u:= ReadWord(r); l:= ReadWord(r);
      RETURN ASH(u,16)+l;
   END ReadSignedQuad;

   (** Read size bytes as an unsigned value from rider r. **)
   PROCEDURE Read*(VAR r: Files.Rider; size: LONGINT): LONGINT;
   BEGIN
      CASE size OF
         4: RETURN ReadSignedQuad(r);
       | 3: RETURN ReadTrio(r);
       | 2: RETURN ReadWord(r);
       | 1: RETURN ReadByte(r);
      END
   END Read;

   (** Read size bytes as a signed value from rider r. **)
   PROCEDURE ReadSigned*(VAR r: Files.Rider; size: LONGINT): LONGINT;
   BEGIN
      CASE size OF
         4: RETURN ReadSignedQuad(r);
       | 3: RETURN ReadSignedTrio(r);
       | 2: RETURN ReadSignedWord(r);
       | 1: RETURN ReadSignedByte(r);
      END
   END ReadSigned;

   (** Read four bytes from rider r and interpret them as
       fixed-point number. **)
   PROCEDURE ReadFixedWord*(VAR r: Files.Rider): LONGREAL;
   CONST Multiplier = 9.5367431640625D-7;
   BEGIN
      RETURN ReadSignedQuad(r) * Multiplier
   END ReadFixedWord;

   (** Advance rider r by numberOfBytes bytes. **)
   PROCEDURE SkipBytes*(VAR r: Files.Rider; numberOfBytes: LONGINT);
   BEGIN
      Files.Set(r,Files.Base(r),Files.Pos(r)+numberOfBytes);
   END SkipBytes;

   PROCEDURE Assert(expr: BOOLEAN; msg: ARRAY OF CHAR);
   BEGIN
      IF expr = FALSE THEN
         Out.String("Error: "); Out.String(msg); Out.Ln;
         HALT(25)
      END
   END Assert;


   PROCEDURE ReadCharacterWidths(font: FontInfo);
   VAR
      tfmFile: Files.File; tfm: Files.Rider;
      checksum: LONGINT; (* tfm-checksum of the font *)
      w: POINTER TO ARRAY OF LONGREAL;
      wIndex: ARRAY 256 OF INTEGER;
      headerLength,begin,end,widthNr,i: LONGINT;

      PROCEDURE OpenTFMFile(VAR fontName: ARRAY OF CHAR): Files.File;
      CONST
         DefaultPath = "";
         Suffix = ".tfm";
         ErrMsg1 = "TMF File for font '";
         ErrMsg2 = "' not found.";
      VAR
         str: ARRAY 128 OF CHAR;
         tfm: Files.File;
      BEGIN
         str:= DefaultPath; Strings.Append(str,fontName);
         Strings.Append(str,Suffix);
         tfm:= Files.Old(str);
         IF tfm = NIL THEN
            str:= ErrMsg1; Strings.Append(str,fontName);
            Strings.Append(str,ErrMsg2);
            Assert(tfm#NIL,str);
         END;
         RETURN tfm;
      END OpenTFMFile;


   BEGIN
      tfmFile:= OpenTFMFile(font.name^);
      Files.Set(tfm,tfmFile,0);
      SkipBytes(tfm,2);
      headerLength:= ReadWord(tfm); (* length of the header in quads *)
      begin:= ReadWord(tfm); end:= ReadWord(tfm);
      IF end < begin THEN begin:= end+1 END;
      widthNr:= ReadWord(tfm);
      NEW(w,widthNr);
      SkipBytes(tfm,4+4+4+2);
      checksum:= ReadSignedQuad(tfm);
      Assert(checksum=font.checksum,
         "Checksum in dvi-file doesn't match font-checksum.");
      SkipBytes(tfm,headerLength*4-4);
      FOR i:= begin TO end DO
         wIndex[i]:= SHORT(ReadByte(tfm)); SkipBytes(tfm,3);
      END;

      FOR i:= 0 TO widthNr-1 DO
         w[i]:= ReadFixedWord(tfm)
      END;

      FOR i:= begin TO end DO
         font.width[i]:= w[wIndex[i]] * font.s
      END;

   END ReadCharacterWidths;


   PROCEDURE ParsePostamble(m: File; postamble: LONGINT): LONGINT;
   CONST
      FontDfn1Cmd = 243;
      FontDfn4Cmd = 246;
      NopCmd = 138;
      PostPostCmd = 249;
   VAR
      r: Files.Rider; lastPage,currCmd: LONGINT; f: FontInfo;
   BEGIN
      Files.Set(r,m.file,postamble); SkipBytes(r,1); (* skip command-number *)
      lastPage:= ReadSignedQuad(r); m.num:= ReadSignedQuad(r);
      m.den:= ReadSignedQuad(r); m.mag:= ReadSignedQuad(r);
      SkipBytes(r,4+4+2); m.pageNr:= ReadWord(r);
      (* what now comes are any number of font-definition commands,
         possibly interspersed with no-operation commands---the following
         parses these commands: *)
      m.fonts:= NIL;
      currCmd:= ReadByte(r);
      WHILE currCmd # PostPostCmd DO
         CASE currCmd OF
            NopCmd,PostPostCmd:
               (* do nothing here *)
          | FontDfn1Cmd..FontDfn4Cmd:
               NEW(f); f.next:= m.fonts; m.fonts:= f;
               f.no:= Read(r,currCmd - FontDfn1Cmd+1);
               f.checksum:= ReadSignedQuad(r); f.s:= ReadSignedQuad(r);
               f.d:= ReadSignedQuad(r); f.a:= ReadByte(r);
               f.l:= ReadByte(r); NEW(f.name,f.a+f.l+1);
               Files.ReadBytes(r,f.name^,f.a+f.l);
               f.name[f.a+f.l] := CHR(0);
               ReadCharacterWidths(f);
         ELSE
            Assert(FALSE,"Unknown command in the postamble of the dvi-file.")
         END;
         currCmd:= ReadByte(r);
      END;
      RETURN lastPage
   END ParsePostamble;

   PROCEDURE ScanPages(m: File; lastPageOffset,postambleOffset: LONGINT);
   VAR currPage,currPageOffset, prevOffset: LONGINT;
      r: Files.Rider; s: Special;
   BEGIN
      NEW(m.page,m.pageNr);
      currPage:= m.pageNr; currPageOffset:= lastPageOffset;
      prevOffset:= postambleOffset;
      WHILE currPage > 0 DO
         Assert((0<currPageOffset) & (currPageOffset<Files.Length(m.file)),
            "Problem scanning the pages of the dvi-file.");
         Files.Set(r,m.file,currPageOffset);
         m.page[currPage-1].offset:= currPageOffset;
         (* set up special-cache as a circluar list with two sentinels *)
         m.page[currPage-1].specialCacheComplete:= FALSE;
         NEW(m.page[currPage-1].spec); NEW(s);
         m.page[currPage-1].spec.pos:= 0; s.pos:= MAX(LONGINT);
         m.page[currPage-1].spec.next:= s;
         s.next:= m.page[currPage-1].spec;
         SkipBytes(r,1+10*4);
         prevOffset:= currPageOffset; currPageOffset:= ReadSignedQuad(r);
         DEC(currPage)
      END;
      Assert(currPageOffset = -1,
         "There seem to be more pages in the dvi-file than stated.");
   END ScanPages;

   PROCEDURE LoadDVIFile(m: File);
   CONST DVITag = 0F702H; EndTag = 223; DVIVersion = 02H;
   VAR
      r: Files.Rider;
      l,postambleOffset: LONGINT;
   BEGIN
      m.file:= Files.Old(m.fileName);
      IF m.file = NIL THEN COPY("",m.fileName); RETURN END;
      Files.Set(r,m.file,0); l:= ReadWord(r);
      IF (Files.Length(m.file)<1) OR (l#DVITag) THEN
         Out.String("File doen't look like a dvi-file (strange header).");
         COPY("",m.fileName); RETURN
      END;

      Files.Set(r,m.file,Files.Length(m.file)-1);
      l:= ReadByte(r);
      REPEAT
         IF l#EndTag THEN
            Out.String("File doesn't look like a dvi-file (strange tail).");
            COPY("",m.fileName); RETURN
         END;
         Files.Set(r,m.file,Files.Pos(r)-2);
         l:= ReadByte(r)
      UNTIL l = DVIVersion;
      Files.Set(r,m.file,Files.Pos(r)-5);
      postambleOffset:= ReadSignedQuad(r);
      IF (0>postambleOffset) OR (postambleOffset>=Files.Length(m.file)) THEN
         Out.String("This dvi-file seems corrupt (postamble not found).");
         COPY("",m.fileName); RETURN
      END;

      l:= ParsePostamble(m,postambleOffset); (* read global
         parameters (mag, etc.), create the font-info descriptions
         and return a pointer to the beginning of the last page *)
      ScanPages(m,l,postambleOffset); (* create the page-descriptors *)
   END LoadDVIFile;

   PROCEDURE GetPage*(m: File; pageNo: LONGINT;
      VAR r: Files.Rider): BOOLEAN;
   BEGIN
      IF (m.fileName = "") OR (pageNo < 1) OR (pageNo > m.pageNr) THEN
         RETURN FALSE
      END;
      Files.Set(r,m.file,m.page[pageNo-1].offset);
      RETURN TRUE;
   END GetPage;

   PROCEDURE GetFont*(m: File; fontNo: LONGINT): FontInfo;
   VAR f: FontInfo;
   BEGIN
      IF m.fileName = "" THEN RETURN NIL END;
      f:= m.fonts;
      WHILE (f#NIL) & (f.no#fontNo) DO
         f:= f.next
      END;
      RETURN f
   END GetFont;

   PROCEDURE IsSpecialCacheComplete*(m: File; pageNo: LONGINT): BOOLEAN;
   BEGIN
      RETURN (m.fileName # "") & (pageNo >= 1) & (pageNo <= m.pageNr) &
         m.page[pageNo-1].specialCacheComplete;
   END IsSpecialCacheComplete;

   PROCEDURE CacheComplete*(m: File; pageNo: LONGINT);
   BEGIN
      IF (m.fileName # "") & (pageNo >= 1) & (pageNo <= m.pageNr) THEN
         m.page[pageNo-1].specialCacheComplete:= TRUE
      END
   END CacheComplete;

   PROCEDURE FindSpecial(m: File; pageNo,pos: LONGINT): Special;
   (* Precondition: 0 < pos < MAX(LONGINT).
      Postcondition for the result s: s.pos < pos <= s.next.pos. *)
   BEGIN
      WHILE (pos > m.page[pageNo-1].spec.next.pos) OR
         (pos <= m.page[pageNo-1].spec.pos) DO
         m.page[pageNo-1].spec:= m.page[pageNo-1].spec.next
      END;
      (* => m.page[...].spec.pos < pos <= m.page[...].spec.next.pos *)
      RETURN m.page[pageNo-1].spec
   END FindSpecial;

   PROCEDURE GetCachedSpecial*(m: File; pageNo,pos: LONGINT): Special;
   (* Precondition: 0 < pos < MAX(LONGINT). *)
   VAR s: Special;
   BEGIN
      IF (m.fileName = "") OR (pageNo < 1) OR (pageNo > m.pageNr) THEN
         RETURN NIL
      END;
      s:= FindSpecial(m,pageNo,pos);
      IF pos = s.next.pos THEN RETURN s.next
      ELSE RETURN NIL END
   END GetCachedSpecial;

   PROCEDURE CacheSpecial*(m: File; pageNo: LONGINT; new: Special);
   VAR s: Special;
   BEGIN
      s:= FindSpecial(m,pageNo,new.pos);
      new.next:= s.next; s.next:= new;
   END CacheSpecial;

   PROCEDURE DoAttributeMsg(obj: File; VAR M: Objects.AttrMsg);
   BEGIN
      IF M.id = Objects.get THEN
         IF M.name = "Gen" THEN
            M.class:= Objects.String; COPY("DVIFiles.New", M.s); M.res:= 0
         ELSIF M.name = "File" THEN
            M.class:= Objects.String; COPY(obj.fileName,M.s); M.res:= 0
         ELSE Gadgets.objecthandle(obj, M)
         END
      ELSIF M.id = Objects.set THEN
         IF (M.name = "File") & (M.class = Objects.String) THEN
            COPY(M.s,obj.fileName); LoadDVIFile(obj); M.res:= 0;
            Gadgets.Update(obj)
         END;
      ELSIF M.id = Objects.enum THEN
         M.Enum("File"); Gadgets.objecthandle(obj,M);
      END
   END DoAttributeMsg;

   PROCEDURE Copy*(VAR M: Objects.CopyMsg; from, to: File);
   BEGIN
      to.fileName:= from.fileName; to.file:= from.file;
      to.fonts:= from.fonts; to.pageNr:= from.pageNr;
      to.num:= from.num; to.den:= from.den; to.mag:= from.mag;
      to.page:= from.page;
      Gadgets.CopyObject(M, from, to)
   END Copy;

   PROCEDURE DoCopyMsg(obj: File; VAR M: Objects.CopyMsg);
   VAR tmp: File;
   BEGIN
      IF M.stamp = obj.stamp THEN M.obj := obj.dlink
      ELSE
         NEW(tmp); obj.stamp := M.stamp; obj.dlink := tmp;
         Copy(M,obj,tmp);
         M.obj := tmp
      END
   END DoCopyMsg;

   PROCEDURE DoStoreMsg(obj: File; VAR M: Objects.FileMsg);
   BEGIN
      Files.WriteString(M.R,obj.fileName);
   END DoStoreMsg;

   PROCEDURE DoLoadMsg(obj: File; VAR M: Objects.FileMsg);
   BEGIN
      Files.ReadString(M.R, obj.fileName);
      LoadDVIFile(obj)
   END DoLoadMsg;

   PROCEDURE Handler*(obj: Objects.Object; VAR M: Objects.ObjMsg);
   BEGIN
      WITH obj: File DO
         IF M IS Objects.AttrMsg THEN
            DoAttributeMsg(obj(File),M(Objects.AttrMsg));
         ELSIF M IS Objects.CopyMsg THEN
            DoCopyMsg(obj,M(Objects.CopyMsg));
         ELSIF M IS Objects.FileMsg THEN
            WITH M: Objects.FileMsg DO
               IF M.id = Objects.store THEN
                  DoStoreMsg(obj,M(Objects.FileMsg));
               ELSIF M.id = Objects.load THEN
                  DoLoadMsg(obj,M(Objects.FileMsg));
               END;
               Gadgets.objecthandle(obj, M)
            END
         ELSE Gadgets.objecthandle(obj, M)
         END
      END
   END Handler;

   PROCEDURE Init*(obj: File; fileName: ARRAY OF CHAR);
   BEGIN
      obj.handle:= Handler; COPY(fileName,obj.fileName);
      LoadDVIFile(obj); Gadgets.Update(obj)
   END Init;

   PROCEDURE New*;
   VAR obj: File;
   BEGIN
      NEW(obj); Init(obj,""); Objects.NewObj:= obj
   END New;

END DVIFiles.
