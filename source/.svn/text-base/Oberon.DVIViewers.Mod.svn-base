MODULE DVIViewers IN Oberon;
(** Implements a frame gadget to display the contents of a dvi-file
    as produced by the typesetting-sytem TeX.  The gadget is a viewer
    gadget of the dvi-model gadget defined in module DVIFiles.Mod.

    A Frame gadget comes with the following attributes: PageNo
    gives the number of the page to display.  HOffset and VOffset
    specify (in dvi-units) which point of the dvi-file is to be
    displayed at the top-left corner of the view. And zoom gives the
    zoom-level (1.0 means 100%). Furthermore an attribute File is
    available which maps to the File attribute of the underlying
    model. **)
IMPORT Display, Display3, Effects, Files, Gadgets, Oberon, Strings, Input,
   Objects, Printer, In, Out, Documents, Desktops, DVIFiles, Gfx,
   GfxImages, GfxDisplay, GfxRegions, GfxMatrix, GfxFonts, GfxPS, Math IN A2,
   Links, Attributes, Images, BIT IN A2;
CONST
   Version* = 100; (** version 1.00 **)
   MaxZoom = 20.0; (* maximum zoom factor *)
TYPE
   Frame* = POINTER TO FrameDesc;
   DrawCharHook = PROCEDURE (c: CHAR; x,y,dviWidth: LONGREAL; F: Frame);
   FrameDesc* = RECORD(Gadgets.FrameDesc)
      pageNo: LONGINT;
      zoom: REAL; conv: LONGREAL;
      hOffset,vOffset: LONGREAL;
      b,l,h,w: INTEGER;
      M: Display3.Mask; clipReg: GfxRegions.Region;
      context: Gfx.Context;

      drawChar: DrawCharHook;
   END;

   StackElement = POINTER TO StackElementDesc;
   StackElementDesc = RECORD
      next: StackElement;
      h,v,w,x,y,z: LONGREAL
   END;

   PSFileSpecial = POINTER TO PSFileSpecialDesc;
   PSFileSpecialDesc = RECORD(DVIFiles.SpecialDesc)
      name: POINTER TO ARRAY OF CHAR; (* file's name *)
      llx,lly,urx,ury: LONGREAL; (* bounding box in dvi-coords
         relative to the current dvi-point *)
      angle: REAL; (* angle in degrees counterclockwise *)
      image: Images.Image;
   END;

VAR
   tmpRgn: GfxRegions.Region;

   PROCEDURE Assert(expr: BOOLEAN; msg: ARRAY OF CHAR);
   BEGIN
      IF expr = FALSE THEN
         Out.String("Error: "); Out.String(msg); Out.Ln;
         HALT(25)
      END
   END Assert;

   PROCEDURE DVIToScreenX(F: Frame; x: LONGREAL): LONGREAL;
   BEGIN
      RETURN F.l+(x-F.hOffset)*F.zoom*F.conv;
   END DVIToScreenX;

   PROCEDURE DVIToScreenY(F: Frame; y: LONGREAL): LONGREAL;
   BEGIN
      RETURN F.b+F.h-(y-F.vOffset)*F.zoom*F.conv;
   END DVIToScreenY;

   PROCEDURE ScreenToDVIX(F: Frame; x: INTEGER): LONGREAL;
   BEGIN
      RETURN F.hOffset + (x-F.l)/F.zoom/F.conv;
   END ScreenToDVIX;

   PROCEDURE ScreenToDVIY(F: Frame; y: INTEGER): LONGREAL;
   BEGIN
      RETURN F.vOffset + (F.b+F.h-y)/F.zoom/F.conv;
   END ScreenToDVIY;

   PROCEDURE Push(VAR s: StackElement; h,v,w,x,y,z: LONGREAL);
   VAR e: StackElement;
   BEGIN
      NEW(e); e.h:= h; e.v:= v; e.w:= w; e.x:= x; e.y:= y; e.z:= z;
      e.next:= s; s:= e
   END Push;

   PROCEDURE Pop(VAR s: StackElement; VAR h,v,w,x,y,z: LONGREAL);
   BEGIN
      Assert(s#NIL,"More Pops than Push's in this page of the dvi-file.");
      h:= s.h; v:= s.v; w:= s.w; x:= s.x; y:= s.y; z:= s.z;
      s:= s.next;
   END Pop;

   PROCEDURE GetResolution() : LONGREAL;
   BEGIN
      RETURN 91.44;
   END GetResolution;

   PROCEDURE DrawCharImage(c: CHAR; x,y,dviWidth: LONGREAL; F: Frame);
   VAR cx, cy, dx, dy, llx, lly, urx, ury: REAL; img: GfxImages.Image;
   BEGIN
      GfxFonts.GetMap(F.context.font,c,cx,cy,dx,dy,img);
      cx:= SHORT(DVIToScreenX(F,x)+cx); cy:= SHORT(DVIToScreenY(F,y)+cy);
      Gfx.GetClipRect(F.context,llx,lly,urx,ury);
      IF (cx<=urx) & (llx<=cx+img.width) &
         (cy<=ury) & (lly<cy+img.height) THEN
         Gfx.DrawImageAt(F.context,cx,cy,img,GfxImages.NoFilter)
      END
   END DrawCharImage;

   PROCEDURE DrawChar(c: CHAR; x,y,dviWidth: LONGREAL; F: Frame);
   VAR str: ARRAY 2 OF CHAR;
   BEGIN
      str[0]:= c; str[1]:= CHR(0);
      Gfx.DrawStringAt(F.context,SHORT(DVIToScreenX(F,x)),
        SHORT(DVIToScreenY(F,y)),str)
   END DrawChar;

   PROCEDURE DrawRule(x,y,h,w: LONGREAL; F: Frame);
   VAR llx, lly, urx, ury, lw, tmp: REAL;
   BEGIN
      llx := SHORT(DVIToScreenX(F,x)); lly := SHORT(DVIToScreenY(F,y-h));
      urx := SHORT(DVIToScreenX(F,x+w)); ury := SHORT(DVIToScreenY(F,y));
      IF llx > urx THEN tmp:= llx; llx:= urx; urx:= tmp END;
      IF lly > ury THEN tmp:= lly; lly:= ury; ury:= tmp END;
      lw := F.context.lineWidth;
      IF ABS(urx-llx) > ABS(ury-lly) THEN
        Gfx.SetLineWidth(F.context,ury-lly);
        Gfx.DrawLine(F.context,llx,0.5*(lly+ury),urx,0.5*(lly+ury),
          {Gfx.Stroke})
      ELSE
        Gfx.SetLineWidth(F.context,urx-llx);
        Gfx.DrawLine(F.context,0.5*(llx+urx),lly,0.5*(llx+urx),ury,
          {Gfx.Stroke})
      END;
      Gfx.SetLineWidth(F.context,lw)
   END DrawRule;
   PROCEDURE SetCurrentFont(F: Frame; font: DVIFiles.FontInfo);
   VAR
      f: GfxFonts.Font;
      m: GfxMatrix.Matrix;
      PROCEDURE DesignSize(VAR n: ARRAY OF CHAR): INTEGER;
      VAR ds,i: INTEGER;
      BEGIN
         i:= 0;
         WHILE (n[i]#CHR(0)) & ((n[i]<"0") OR (n[i]>"9")) DO
            INC(i)
         END;
         Assert(n[i]#CHR(0),"Font-name is strange: design-size unknown.");
         ds:= 0;
         WHILE n[i]#CHR(0) DO
            ds:= 10*ds + ORD(n[i])-ORD("0");
            INC(i)
         END;
         RETURN ds
      END DesignSize;

   BEGIN
      GfxMatrix.Init(m,F.zoom,0.0,0.0,F.zoom,0.0,0.0);
      f:= GfxFonts.Open(font.name^,DesignSize(font.name^),m);
      IF f = NIL THEN
         Out.String("Font '"); Out.String(font.name^);
         Out.String("' not found."); Out.Ln
      ELSE
         Gfx.SetFont(F.context,f)
      END
   END SetCurrentFont;

   PROCEDURE ReadPSPreview(s: PSFileSpecial);
   CONST Tag = "01%%BeginPreview:"; End = 16;
      (* (state "0" means we're waiting for a new-line, state "1"
         means we're warting for a '%', and for the rest, position
         i (i>1) means we're waiting for Tag[i+1]) *)
   VAR f: Files.File; r: Files.Rider;
      ch: CHAR; (* char to process *)
      state: INTEGER;
      w,h,depth,lines: INTEGER;
      str: ARRAY End+2 OF CHAR;
      hex: INTEGER; (* hex=-1 means that we're waiting for the first digit *)
      val: INTEGER; base,bytesPerColumn,i: LONGINT;

      PROCEDURE EatWhiteSpace(): BOOLEAN;
      (* returns true iff eof is not readched *)
      BEGIN
         WHILE ORD(ch) <= ORD(' ') DO
           Files.Read(r,ch);
           IF r.eof THEN RETURN FALSE END
         END;
         RETURN TRUE
      END EatWhiteSpace;

      PROCEDURE ParseInt(VAR n: INTEGER): BOOLEAN;
      (* returns true iff eof is not readched *)
      BEGIN
         IF ~EatWhiteSpace() THEN RETURN FALSE END;
         n:= 0;
         WHILE Strings.IsDigit(ch) DO
            n:= 10*n + ORD(ch) - ORD('0');
            Files.Read(r,ch);
            IF r.eof THEN RETURN FALSE END
         END;
         RETURN TRUE
      END ParseInt;

      PROCEDURE Abort;
      BEGIN
         Out.String("Cannot find preview in PS-file."); Out.Ln;
         s.image:= NIL
      END Abort;
   BEGIN
      NEW(s.image); f:= Files.Old(s.name^);
      IF f = NIL THEN
         Out.String("Cannot find PS-file '"); Out.String(s.name^);
         Out.String("'."); Out.Ln; s.image:= NIL; RETURN
      END;
      Files.Set(r,f,0);
      (* try to find '%%BeginPreview': *)
      state:= 0; COPY(Tag,str);
      REPEAT
         Files.Read(r,ch);
         IF (state = 0) THEN
            IF (ORD(ch)=10) OR (ORD(ch)=12) OR
               (ORD(ch)=13) THEN (* "new-line?" *)
               state:= 1
            END
         ELSIF (state = 1) & (ch # '%') THEN Abort; RETURN
         ELSIF ch = str[state+1] THEN INC(state)
         ELSE state:= 0
         END
      UNTIL state = End;
      Files.Read(r,ch);
      IF ~ParseInt(w) OR ~ParseInt(h) OR
         ~ParseInt(depth) OR ~ParseInt(lines) THEN
         Abort; RETURN
      END;
      (* parse image-data: *)
      IF depth # 1 THEN
         Out.String("Only b/w previews supported currently - skipping.");
         Out.Ln; s.image:= NIL; RETURN
      END;
      Images.Create(s.image,w,h,Images.A1);
      bytesPerColumn:= w DIV 8;
      IF BIT.IAND(w,7) # 0 THEN INC(bytesPerColumn) END;
      base:= (h-1)*bytesPerColumn; i:= 0;
      (* (from here on, state=0 means that the last char was not a '%'
         and state=1 means that it was indeed a '%') *)
      state:= 0; hex:= -1;
      WHILE (state # 1) OR (ch # '%') DO
         IF ch = '%' THEN state:= 1
         ELSIF Strings.IsHexDigit(ch) THEN
            ch:= Strings.LowerCh(ch);
            IF Strings.IsDigit(ch) THEN val:= ORD(ch) - ORD('0')
            ELSE val:= ORD(ch) - ORD('a') + 10 END;
            IF hex = -1 THEN hex:= val
            ELSE
               hex:= hex*16 + val;
               IF i >= LEN(s.image.mem^) THEN Abort; RETURN END;
               s.image.mem^[base+i]:= CHR(hex);
               INC(i);
               IF i = bytesPerColumn THEN
                  i:= 0; DEC(base,bytesPerColumn)
               END;
               hex:= -1
            END;
            state:= 0;
         END;
         Files.Read(r,ch)
      END;
   END ReadPSPreview;

   PROCEDURE ParseSpecial(M: DVIFiles.File; VAR r: Files.Rider;
      pageNo,len: LONGINT): DVIFiles.Special;
   CONST
      PSMsg = "Error parsing 'PSfile' special.";
      (* tokens we expect in a general special: *)
      EOS = 0; String = 1; Number = 2; Identifier = 3; Unknown = 4;
      (* identifiers we expect in a 'PSfile' special: *)
      hsize = 0; vsize = 1; hoffset = 2; voffset = 3;
      hscale = 4; vscale = 5; angle = 6; llx = 7;
      lly = 8; urx = 9; ury = 10; rwi = 11; rhi = 12; clip = 13; none = 14;
   VAR
      tok: INTEGER; (* current token *)
      str: POINTER TO ARRAY OF CHAR; (* string used in GetToken below *)
      n: LONGINT; (* integer used in GetToken below *)
      seen: SET; (* whether we have seen any of the 'PSfile' identifiers *)
      vals: ARRAY rhi+1 OF REAL; (* values of 'PSfile' identifiers *)
      s: PSFileSpecial;
      i: INTEGER;
      c: LONGREAL; (* one 1/72 inch represents c dvi-units *)

      PROCEDURE GetToken(): INTEGER;
      (* Uses the variables r, len, n, str^.
         Preconditon: len >= 0 & LEN(str) > len. *)
      VAR i: INTEGER;
      BEGIN
         REPEAT (* skip white-space *)
            IF len = 0 THEN RETURN EOS END;
            Files.Read(r,str^[0]); DEC(len);
         UNTIL ORD(str^[0]) > ORD(' ');
         (* len >= 0 here *)
         IF str^[0] = '"' THEN (* string? *)
            i:= -1;
            REPEAT
               IF len = 0 THEN RETURN Unknown END;
               INC(i); Files.Read(r,str^[i]); DEC(len)
            UNTIL str^[i] = '"';
            str^[i]:= CHR(0);
            RETURN String;
         ELSIF Strings.IsDigit(str^[0]) THEN (* integer? *)
            n:= 0;
            WHILE (len > 0) & Strings.IsDigit(str^[0]) DO
               n:= 10*n + ORD(str^[0])-ORD('0');
               Files.Read(r,str^[0]); DEC(len)
            END;
            IF (len = 0) & Strings.IsDigit(str^[0]) THEN
               n:= 10*n + ORD(str^[0])-ORD('0')
            ELSE (* len > 0 => ~Strings.IsDigit(str^[0]) *)
               Files.Set(r,Files.Base(r),Files.Pos(r)-1); INC(len)
            END;
            RETURN Number;
         ELSE (* identifier? *)
            i:= 0;
            IF len > 0 THEN
               REPEAT
                  INC(i); Files.Read(r,str^[i]); DEC(len)
               UNTIL (len = 0) OR ~Strings.IsAlpha(str^[i]);
               IF ~Strings.IsAlpha(str^[i]) THEN
                  Files.Set(r,Files.Base(r),Files.Pos(r)-1); INC(len); DEC(i)
               END;
            END;
            str^[i+1]:= CHR(0);
            RETURN Identifier;
         END;
      END GetToken;


   BEGIN
      NEW(s); s.pos:= Files.Pos(r); NEW(str,len+1); NEW(s.name,len+1);
      IF (GetToken() = Identifier) & (str^ = "PSfile") THEN
         IF (GetToken() # Identifier) OR (str^ # "=") OR
            (GetToken() # String) THEN
            Out.String(PSMsg); Out.Ln
         END;
         COPY(str^,s.name^);
         seen:= {};
         vals[hsize]:= 0.0; vals[vsize]:= 0.0; vals[hoffset]:= 0.0;
         vals[voffset]:= 0.0; vals[hscale]:= 1.0; vals[vscale]:= 1.0;
         vals[angle]:= 0.0;
         REPEAT
            tok:= GetToken(); i:= none;
            IF tok # Identifier THEN
               IF tok # EOS THEN Out.String(PSMsg); Out.Ln END
            ELSE
               IF str^ = "hsize" THEN i:= hsize
               ELSIF str^ = "vsize" THEN i:= vsize
               ELSIF str^ = "hoffset" THEN i:= hoffset
               ELSIF str^ = "voffset" THEN i:= voffset
               ELSIF str^ = "hscale" THEN i:= hscale
               ELSIF str^ = "vscale" THEN i:= vscale
               ELSIF str^ = "angel" THEN i:= angle
               ELSIF str^ = "llx" THEN i:= llx
               ELSIF str^ = "lly" THEN i:= lly
               ELSIF str^ = "urx" THEN i:= urx
               ELSIF str^ = "ury" THEN i:= ury
               ELSIF str^ = "rwi" THEN i:= rwi
               ELSIF str^ = "rhi" THEN i:= rhi
               ELSIF str^ = "clip" THEN i:= clip; seen:= seen + {clip}
               END;
               IF (i # none) & (i # clip) & (GetToken() = Identifier) &
                  (str^ = "=") & (GetToken() = Number) THEN
                  vals[i]:= n; seen:= seen + {i};
               ELSE
                  Out.String(PSMsg); Out.Ln
               END;
            END
         UNTIL tok = EOS;
         (* now evaluate the tokens we've seen: *)
         IF hscale IN seen THEN vals[hscale]:= vals[hscale]/100.0 END;
         IF vscale IN seen THEN vals[vscale]:= vals[vscale]/100.0 END;
         IF (llx IN seen) & (urx IN seen) THEN
            vals[hsize]:= vals[urx]-vals[llx]
         END;
         IF (lly IN seen) & (ury IN seen) THEN
            vals[vsize]:= vals[ury]-vals[lly]
         END;
         IF (rwi IN seen) OR (rhi IN seen) THEN
            IF (rwi IN seen) & ~(rhi IN seen) THEN
               vals[hscale]:= vals[rwi]/(10.0*vals[hsize]);
               vals[vscale]:= vals[hscale]
            ELSIF ~(rwi IN seen) & (rhi IN seen) THEN
               vals[hscale]:= vals[rhi]/(10.0*vals[vsize]);
               vals[vscale]:= vals[hscale]
            ELSE
               vals[hscale]:= vals[rwi]/(10.0*vals[hsize]);
               vals[vscale]:= vals[rhi]/(10.0*vals[vsize])
            END;
         END;
         (* here, the bounding box in PostScript units (1/72 inch) relative
            to the current dvi point is
               (x1,y1,x2,y2) = (vals[hoffset],vals[voffset],
               vals[hoffset]+vals[hsize]*vals[hscale],
               vals[voffset]-vals[vsize]*vals[vscale]) *)
         c:= 2.54D5/72.0 * M.den/M.num;
         s.llx:= c*vals[hoffset]; s.lly:= c*vals[voffset];
         s.urx:= c*(vals[hoffset]+vals[hsize]*vals[hscale]);
         s.ury:= c*(vals[voffset]-vals[vsize]*vals[vscale]);
         s.angle:= vals[angle];
         ReadPSPreview(s);
         DVIFiles.CacheSpecial(M,pageNo,s);
         RETURN s
      ELSE DVIFiles.SkipBytes(r,len); RETURN NIL END;
   END ParseSpecial;

   PROCEDURE DoSpecial(F: Frame; M: DVIFiles.File; h,v: LONGREAL;
      VAR r: Files.Rider; len: LONGINT);
   VAR
      tmp: DVIFiles.Special; s: PSFileSpecial; pos: LONGINT;
      ctm: GfxMatrix.Matrix; sc,phi: REAL;
   BEGIN
      pos:= Files.Pos(r);
      IF ~DVIFiles.IsSpecialCacheComplete(M,F.pageNo) THEN
         tmp:= ParseSpecial(M,r,F.pageNo,len);
      ELSE
         tmp:= DVIFiles.GetCachedSpecial(M,F.pageNo,pos);
         DVIFiles.SkipBytes(r,len)
      END;
      IF tmp # NIL THEN
         s:= tmp(PSFileSpecial);
         IF s.image # NIL THEN (* draw the preview: *)
            ctm := F.context.ctm;
            Gfx.Translate(F.context,SHORT(DVIToScreenX(F,h+s.llx)),
               SHORT(DVIToScreenY(F,v+s.lly)));
            sc := SHORT(F.zoom * GetResolution()/2.54D5/M.den*M.num);
            Gfx.Scale(F.context,SHORT(sc*(s.urx-s.llx)/s.image.width),
               SHORT(sc*(s.lly-s.ury)/s.image.height));
            phi:= 2.0*Math.pi/360.0*s.angle;
            Gfx.Rotate(F.context,Math.sin(phi),Math.cos(phi));
            Gfx.DrawImageAt(F.context,0,0,s.image,GfxImages.NoFilter);
            Gfx.SetCTM(F.context,ctm);
         ELSE (* no image available, draw bounds: *)
            Gfx.DrawRect(F.context,
               SHORT(DVIToScreenX(F,h+s.llx)),SHORT(DVIToScreenY(F,v+s.lly)),
               SHORT(DVIToScreenX(F,h+s.urx)),SHORT(DVIToScreenY(F,v+s.ury)),
               {Gfx.Stroke})
         END
      END;
   END DoSpecial;
   PROCEDURE DrawPage(F: Frame; M: DVIFiles.File);
   CONST
         SetChar0Cmd = 0; SetChar127Cmd = 127;
         Set1Cmd = 128; Set4Cmd = 131;
         SetRuleCmd = 132;
         Put1Cmd = 133; Put4Cmd = 136;
         PutRuleCmd = 137;
         NopCmd = 138;
         BopCmd = 139;
         EopCmd = 140;
         PushCmd = 141;
         PopCmd = 142;
         Right1Cmd = 143; Right4Cmd = 146;
         W0Cmd = 147;
         W1Cmd = 148; W4Cmd = 151;
         X0Cmd = 152;
         X1Cmd = 153; X4Cmd = 156;
         Down1Cmd = 157; Down4Cmd = 160;
         Y0Cmd = 161;
         Y1Cmd = 162; Y4Cmd = 165;
         Z0Cmd = 166;
         Z1Cmd = 167; Z4Cmd = 170;
         FntNum0Cmd = 171; FntNum63 = 234;
         Fnt1Cmd = 235; Fnt4Cmd = 238;
         Xxx1Cmd = 239; Xxx4Cmd = 242;
         FntDef1Cmd = 243; FntDef4Cmd = 246;

   VAR
      r: Files.Rider;
      cmd: LONGINT;
      h,v,w,x,y,z: LONGREAL;
      fontNo: LONGINT; font: DVIFiles.FontInfo;
      stack: StackElement;
      a,b,c: LONGINT;
   BEGIN
      IF ~DVIFiles.GetPage(M,F.pageNo,r) THEN RETURN END;
      F.conv:= GetResolution()/2.54D8*M.mag*M.num/M.den;
      cmd:= DVIFiles.ReadByte(r);
      Assert(cmd = BopCmd,"A page in the dvi-file doesn't start with BOP.");
      h:= 0; v:= 0; w:= 0; x:= 0; y:= 0; z:= 0; stack:= NIL;
      DVIFiles.SkipBytes(r,10*4+4); cmd:= DVIFiles.ReadByte(r);
      REPEAT
         CASE cmd OF
            SetChar0Cmd..SetChar127Cmd,Set1Cmd..Set4Cmd,Put1Cmd..Put4Cmd:
               IF cmd <= SetChar127Cmd THEN c:= cmd
               ELSIF cmd <= Set4Cmd THEN
                  c:= DVIFiles.Read(r,cmd-Set1Cmd+1)
               ELSE c:= DVIFiles.Read(r,cmd-Put1Cmd+1) END;
               F.drawChar(CHR(c),h,v,font.width[c],F);
               IF cmd <= Set4Cmd THEN h:= h+font.width[c] END
          | SetRuleCmd,PutRuleCmd:
               a:= DVIFiles.ReadSignedQuad(r);
               b:= DVIFiles.ReadSignedQuad(r);
               DrawRule(h,v,a,b,F);
               IF cmd = SetRuleCmd THEN h:= h+b END
          | NopCmd: (* do nothing here *)
          | PushCmd:
               Push(stack,h,v,w,x,y,z)
          | PopCmd:
               Pop(stack,h,v,w,x,y,z)
          | Right1Cmd..Right4Cmd:
               h:= h+DVIFiles.ReadSigned(r,cmd-Right1Cmd+1)
          | W0Cmd:
               h:= h+w
          | W1Cmd..W4Cmd:
               w:= DVIFiles.ReadSigned(r,cmd-W1Cmd+1);
               h:= h+w
          | X0Cmd:
               h:= h+x
          | X1Cmd..X4Cmd:
               x:= DVIFiles.ReadSigned(r,cmd-X1Cmd+1);
               h:= h+x
          | Down1Cmd..Down4Cmd:
               v:= v+DVIFiles.ReadSigned(r,cmd-Down1Cmd+1)
          | Y0Cmd:
               v:= v+y
          | Y1Cmd..Y4Cmd:
               y:= DVIFiles.ReadSigned(r,cmd-Y1Cmd+1);
               v:= v+y
          | Z0Cmd:
               v:= v+z
          | Z1Cmd..Z4Cmd:
               z:= DVIFiles.ReadSigned(r,cmd-Z1Cmd+1);
               v:= v+z
          | FntNum0Cmd..FntNum63,Fnt1Cmd..Fnt4Cmd:
               IF cmd <= FntNum63 THEN fontNo:= cmd-FntNum0Cmd
               ELSE fontNo:= DVIFiles.Read(r,cmd-Fnt1Cmd+1) END;
               font:= DVIFiles.GetFont(M,fontNo);
               Assert(font#NIL,"Font-number not defined in dvi-file.");
               SetCurrentFont(F,font);
          | Xxx1Cmd..Xxx4Cmd:
               a:= DVIFiles.Read(r,cmd-Xxx1Cmd+1);
               DoSpecial(F,M,h,v,r,a);
          | FntDef1Cmd..FntDef4Cmd:
               a:= DVIFiles.Read(r,cmd-FntDef1Cmd+1); (* font number *)
               c:= DVIFiles.ReadSignedQuad(r); (* tfm-checksum *)
               DVIFiles.SkipBytes(r,4+4);
               (* to do ???: check *)
               b:= DVIFiles.ReadByte(r); b:= b+DVIFiles.ReadByte(r);
               DVIFiles.SkipBytes(r,b);
          | BopCmd,EopCmd:
              Assert(FALSE,"BOP (or EOP) found within a dvi-page.");
         ELSE
            Assert(FALSE,"Unknown command found within a dvi-page.");
         END;
         cmd:= DVIFiles.ReadByte(r)
      UNTIL cmd = EopCmd;
      DVIFiles.CacheComplete(M,F.pageNo)
   END DrawPage;

   (* Routines to Manage the Gadget's Attributes: *)
   PROCEDURE UpdateModels(F: Frame);
   (* Notify the zoom- and page-number models that we
      changed their attributes. *)
   VAR m: Objects.Object;
   BEGIN
      Links.GetLink(F,"PageNumber",m);
      Attributes.SetInt(m,"Value",F.pageNo);
      Gadgets.Update(m);
      Links.GetLink(F,"ZoomNumber",m);
      Attributes.SetReal(m,"Value",F.zoom);
      Gadgets.Update(m);
   END UpdateModels;

   PROCEDURE DoAttributeMsg(F: Frame; VAR M: Objects.AttrMsg);
   BEGIN
      IF M.id = Objects.get THEN
         IF M.name = "Gen" THEN
            M.class := Objects.String; COPY("DVIViewers.New", M.s); M.res:= 0
         ELSIF M.name = "PageNo" THEN
            M.class:= Objects.Int; M.i:= F.pageNo; M.res:= 0
         ELSIF M.name = "HOffset" THEN
            M.class:= Objects.LongReal; M.y:= F.hOffset; M.res:= 0
         ELSIF M.name = "VOffset" THEN
           M.class:= Objects.LongReal; M.y:= F.vOffset; M.res:= 0
         ELSIF M.name = "Zoom" THEN
            M.class:= Objects.LongReal; M.y:= F.zoom; M.res:= 0
         ELSIF M.name = "File" THEN
            F.obj.handle(F.obj,M)
         ELSE Gadgets.framehandle(F,M)
         END
      ELSIF M.id = Objects.set THEN
         IF (M.name = "HOffset") & (M.class = Objects.Int) THEN
            F.hOffset:= M.i; M.res:= 0
         ELSIF (M.name = "VOffset") & (M.class = Objects.Int) THEN
            F.vOffset:= M.i; M.res:= 0
         ELSIF (M.name = "File") THEN
            F.obj.handle(F.obj,M)
         ELSE Gadgets.framehandle(F, M)
      END
      ELSIF M.id = Objects.enum THEN
         M.Enum("HOffset"); M.Enum("VOffset");
         M.Enum("File"); Gadgets.framehandle(F, M)
      END
   END DoAttributeMsg;

   (* Routines to Copy, Load & Store the Gadget: *)
   PROCEDURE Copy*(VAR M: Objects.CopyMsg; from, to: Frame);
   VAR dc: GfxDisplay.Context;
   BEGIN
      to.pageNo:= from.pageNo; to.hOffset:= from.hOffset;
      to.vOffset:= from.vOffset; to.zoom:= from.zoom;
      NEW(to.clipReg); GfxRegions.Init(to.clipReg,GfxRegions.Winding);
      NEW(dc); to.context:= dc; GfxDisplay.Init(dc,Display.ColLeft,0,
         Display.Width,Display.Height); to.drawChar:= DrawCharImage;
      Gadgets.CopyFrame(M,from,to);
   END Copy;

   PROCEDURE DoCopyMsg(F: Frame; VAR M: Objects.CopyMsg);
   VAR tmp: Frame;
   BEGIN
      IF M.stamp = F.stamp THEN M.obj:= F.dlink
      ELSE
      NEW(tmp); F.stamp:= M.stamp; F.dlink:= tmp;
      Copy(M, F, tmp); M.obj:= tmp
      END
   END DoCopyMsg;

   PROCEDURE DoStore(F: Frame; M: Objects.FileMsg);
   BEGIN
      Files.WriteLInt(M.R,F.pageNo);
      Files.WriteLReal(M.R,F.hOffset);
      Files.WriteLReal(M.R,F.vOffset);
      Files.WriteReal(M.R,F.zoom)
   END DoStore;

   PROCEDURE DoLoad(F: Frame; M: Objects.FileMsg);
   BEGIN
      Files.ReadLInt(M.R,F.pageNo);
      Files.ReadLReal(M.R,F.hOffset);
      Files.ReadLReal(M.R,F.vOffset);
      Files.ReadReal(M.R,F.zoom)
   END DoLoad;

   (* Routines to Draw & Print the Gadget: *)
   PROCEDURE AddMaskRect(x,y,w,h: INTEGER);
   BEGIN
      GfxRegions.AddRect(tmpRgn,x,y,x+w,y+h)
   END AddMaskRect;

   PROCEDURE DoRestore(F: Frame);
   VAR f: DVIFiles.File; inch: LONGREAL;
      PROCEDURE PrinterToDVIUnits(x:LONGREAL): LONGREAL;
      BEGIN
         RETURN 1.0D7/f.num/f.mag*f.den*x*Printer.Unit/36000.0;
      END PrinterToDVIUnits;
   BEGIN
      Oberon.RemoveMarks(F.l,F.b,F.w,F.h);
      Display3.ReplConst(F.M, Display3.white,F.l,F.b,F.w,F.h,Display.replace);
      Display3.Rect(F.M,Display3.black,Display.solid,F.l,F.b,
         F.w,F.h,1,Display.paint);
      (* calculate and set the clip region: *)
      GfxRegions.Clear(F.clipReg);
      tmpRgn:= F.clipReg;
      Display3.EnumRect(F.M,F.M.X,F.M.Y,F.M.W,F.H,AddMaskRect);
      GfxRegions.IntersectRect(F.clipReg,F.l,F.b,F.l+F.w,F.b+F.h);
      GfxDisplay.SetClipRegion(F.context(GfxDisplay.Context),F.clipReg);
      (* establish default coordinate system: *)
      GfxDisplay.SetCoordinates(F.context(GfxDisplay.Context),0.0,0.0,1.0);
      Gfx.Reset(F.context);
      f:= F.obj(DVIFiles.File);
      (* draw the page boundaries: *)
      inch:= 2.54D8/f.num/f.mag*f.den;
      Gfx.SetStrokeColor(F.context,Gfx.LGrey);
      Gfx.DrawRect(F.context,SHORT(DVIToScreenX(F,-inch)),
         SHORT(DVIToScreenY(F,-inch)),
         SHORT(DVIToScreenX(F,PrinterToDVIUnits(Printer.Width)-inch)),
         SHORT(DVIToScreenY(F,PrinterToDVIUnits(Printer.Height)-inch)),
         {Gfx.Stroke});
      (* draw the page: *)
      Gfx.SetStrokeColor(F.context,Gfx.Black);
      DrawPage(F,f);
      (* hilite, if selected: *)
      IF Gadgets.selected IN F.state THEN
         Display3.FillPattern(F.M,Display3.white,Display3.selectpat,
            F.l,F.b,F.l,F.b,F.w,F.h,Display.paint)
      END
   END DoRestore;

   PROCEDURE DoPrint(F: Frame; VAR M: Display.DisplayMsg);
   (* following is old:
   VAR Q: Display3.Mask;
      PROCEDURE P(x: INTEGER): INTEGER;
      BEGIN RETURN SHORT(x * Display.Unit DIV Printer.Unit)
      END P;
   BEGIN
      Gadgets.MakePrinterMask(F, M.x, M.y, M.dlink, Q);
      Printer3.ReplConst(Q,Display3.black, M.x, M.y, P(F.W),
         P(F.H), Display.replace)
   * till here. *)
   END DoPrint;

   (* Routines for Mouse-Handling: *)
   PROCEDURE MoveViewToMouse(F: Frame;
      dviX,dviY: LONGREAL; mX,mY: INTEGER);
   (* Moves the view so that the DVI-point (dviX,dviY) lies under
      the point (mX,mY) (normally the mouse-coordinates) in Oberon
      coordinates. *)
   BEGIN
      F.hOffset:= F.hOffset + (dviX - ScreenToDVIX(F,mX));
      F.vOffset:= F.vOffset + (dviY - ScreenToDVIY(F,mY));
   END MoveViewToMouse;

   PROCEDURE DoMouseEvent(F: Frame; VAR M: Oberon.InputMsg);
   CONST right = 0; middle = 1; left = 2;
   VAR
      keysum: SET; (* accumulates key-buttons during interclicks *)
      X,Y,W,H: INTEGER; (* dummy variables *)
      dviX,dviY: LONGREAL;  (* mouse-loc in dvi-coords *)

      PROCEDURE DoZoomIn;
      BEGIN
        Effects.SizeRect(F.M,keysum,M.X,M.Y,X,Y,W,H,NIL);
        IF keysum = {left} THEN
          IF (W = 0) & (H = 0) THEN (* zoom in by a factor of two *)
             F.zoom:= F.zoom*2.0;
             IF F.zoom > MaxZoom THEN F.zoom:= MaxZoom END;
             MoveViewToMouse(F,dviX,dviY,M.X,M.Y);
             DoRestore(F);
             UpdateModels(F); (* because we changed our attributes *)
          ELSE (* zoom to the rect specified by the user *)
             dviX:= ScreenToDVIX(F,X); dviY:= ScreenToDVIY(F,Y+H);
             IF F.h/H <= F.w/W THEN F.zoom:= F.zoom*(F.h/H);
             ELSE F.zoom:= F.zoom*(F.w/W); END;
             IF F.zoom > MaxZoom THEN F.zoom:= MaxZoom END;
             F.hOffset:= dviX; F.vOffset:= dviY;
             DoRestore(F);
             UpdateModels(F); (* because we changed our attributes *)
          END;
        END;
      END DoZoomIn;

      PROCEDURE DoPanning;
      VAR mX,mY,dX,dY: INTEGER; n,copy: Display3.Mask;
      BEGIN
         Input.Mouse(M.keys,mX,mY); (* mask out clicks to bring window
                                       to the front *)
         IF M.keys = {} THEN RETURN END;
         REPEAT
           mX:= M.X; mY:= M.Y;
           Effects.TrackMouse(M.keys,M.X,M.Y,Effects.PointHand);
           Oberon.FadeCursor(Oberon.Mouse);
           MoveViewToMouse(F,dviX,dviY,M.X,M.Y);
           dX:= M.X - mX; dY:= M.Y - mY;
           Display3.Subtract(F.M,F.l,F.b,1,F.h); (* subtract left border *)
           Display3.Subtract(F.M,F.l,F.b,F.w,1); (* subtract bottom border *)
           Display3.Subtract(F.M,F.l+F.w-1,F.b,1,F.h); (* and right border *)
           Display3.Subtract(F.M,F.l,F.b+F.h-1,F.w,1); (* and top border *)
           Display3.Copy(F.M,n);
           INC(n.x,dX); INC(n.y,dY);
           Display3.IntersectMasks(F.M,n,copy);
           DEC(copy.x,dX); DEC(copy.y,dY);
           Display3.CopyMask(copy,copy.x+dX,copy.y+dY,Display3.replace);
           Display3.Copy(F.M,copy);
           Display3.SubtractMasks(copy,n,F.M);
           DoRestore(F); F.M:= NIL; Gadgets.MakeMask(F,F.l,F.b,M.dlink,F.M);
         UNTIL M.keys = {};
      END DoPanning;

      PROCEDURE DoZoomOut;
      BEGIN
         keysum:= M.keys;
         WHILE M.keys # {} DO
            Input.Mouse(M.keys,M.X,M.Y);
            keysum:= keysum + M.keys;
         END;
         IF keysum = {right} THEN
            F.zoom:= F.zoom/2.0;
            MoveViewToMouse(F,dviX,dviY,X,Y);
            DoRestore(F);
            UpdateModels(F); (* because we changed our attributes *)
         END;
      END DoZoomOut;

   BEGIN
      Gadgets.MakeMask(F,F.l,F.b,M.dlink,F.M);
      dviX:= ScreenToDVIX(F,M.X); dviY:= ScreenToDVIY(F,M.Y);
      X:= M.X; Y:= M.Y; W:= 0; H:= 0;
      Oberon.FadeCursor(Oberon.Mouse);
      IF M.keys  = {left} THEN DoZoomIn
      ELSIF M.keys = {middle} THEN DoPanning
      ELSIF M.keys = {right} THEN DoZoomOut
      ELSE Gadgets.framehandle(F,M)
      END;
      Input.Mouse(M.keys,M.X,M.Y);
      Oberon.DrawCursor(Oberon.Mouse,Effects.PointHand,M.X,M.Y);
      M.res:= 0
   END DoMouseEvent;

   (* Message- Handler: *)
   PROCEDURE CheckModels(M: Gadgets.UpdateMsg; F: Frame);
   (* Check whether the zoom- and page-number models changed. *)
   VAR z,p: Objects.Object; r: REAL; n: LONGINT;
   BEGIN
      Links.GetLink(F,"PageNumber",p);
      IF M.obj = p THEN
         Attributes.GetInt(p,"Value",n);
         IF n # F.pageNo THEN F.pageNo:= n; Gadgets.Update(F) END;
      ELSE
         Links.GetLink(F,"ZoomNumber",z);
         IF M.obj = z THEN
            Attributes.GetReal(z,"Value",r);
            IF r # F.zoom THEN F.zoom:= r; Gadgets.Update(F) END;
         END;
      END;
      M.res:= 0
   END CheckModels;

   PROCEDURE Handle*(F: Objects.Object; VAR M: Objects.ObjMsg);
   BEGIN
      WITH F: Frame DO
         IF M IS Display.FrameMsg THEN
            WITH M: Display.FrameMsg DO
               IF M IS Gadgets.UpdateMsg THEN
                  CheckModels(M(Gadgets.UpdateMsg),F)
               ELSIF (M.F = NIL) OR (M.F = F) THEN
                  F.l:= M.x + F.X; F.b:= M.y + F.Y; F.w:= F.W; F.h:= F.H;
                  IF M IS Display.DisplayMsg THEN
                     WITH M: Display.DisplayMsg DO
                        IF M.device = Display.screen THEN
                           IF (M.id = Display.full) OR (M.F = NIL) THEN
                              Gadgets.MakeMask(F,F.l,F.b,M.dlink,F.M);
                              DoRestore(F)
                           ELSIF M.id = Display.area THEN
                              Gadgets.MakeMask(F,F.l,F.b,M.dlink,F.M);
                              Display3.AdjustMask(F.M,F.l+M.u,F.b+
                                 F.h-1+M.v,M.w,M.h);
                              DoRestore(F)
                           END
                        ELSIF M.device = Display.printer THEN DoPrint(F, M)
                        END
                     END
                  ELSIF M IS Oberon.InputMsg THEN
                     WITH M: Oberon.InputMsg DO
                        IF (M.id = Oberon.track) &
                           Gadgets.InActiveArea(F, M) THEN
                           DoMouseEvent(F,M);
                        ELSE Gadgets.framehandle(F, M)
                     END
                  END
               ELSE Gadgets.framehandle(F, M)
               END
            END
         END
      ELSIF M IS Objects.AttrMsg THEN DoAttributeMsg(F, M(Objects.AttrMsg))
      ELSIF M IS Objects.CopyMsg THEN DoCopyMsg(F,M(Objects.CopyMsg))
      ELSIF M IS Objects.FileMsg THEN
         WITH M: Objects.FileMsg DO
            IF M.id = Objects.store THEN DoStore(F,M);
            ELSIF M.id = Objects.load THEN DoLoad(F,M);
            END;
            Gadgets.framehandle(F, M)
         END;
      ELSE Gadgets.framehandle(F, M)
      END
      END
   END Handle;

   (* Routines to Initialize & Instantiate the Gadget: *)
   PROCEDURE Init*(F: Frame);
   VAR dc: GfxDisplay.Context;
   BEGIN
      F.W:= 50; F.H:= 50; F.pageNo:= 1; F.hOffset:= 0; F.vOffset:= 0;
      F.zoom:= 1.0; F.handle:= Handle;
      NEW(F.clipReg); GfxRegions.Init(F.clipReg,GfxRegions.Winding);
      NEW(dc); F.context:= dc; GfxDisplay.Init(dc,Display.ColLeft,0,
         Display.Width, Display.Height); F.drawChar:= DrawCharImage;
   END Init;

   PROCEDURE New*;
   VAR F: Frame;
   BEGIN
      NEW(F); Init(F); Objects.NewObj:= F
   END New;

   PROCEDURE CurrentDVIViewer(): Frame;
   (* First we check, whether the current document contains an item
   called "DVIViewer" and, if so, returns it.  Otherwise we try to find a
   DVIViewers under the current mark. *)
   VAR
      currDoc: Documents.Document;
      M: Display.LocateMsg;
      obj: Objects.Object;
   BEGIN
      currDoc:= Desktops.CurDoc(Gadgets.context);
      IF currDoc # NIL THEN
         obj:= Gadgets.FindObj(currDoc,"DVIViewer");
         IF (obj # NIL) & (obj IS Frame) THEN
            RETURN obj(Frame)
         END
      END;
      M.loc:= NIL; M.X:= Oberon.Pointer.X; M.Y:= Oberon.Pointer.Y;
      M.F:= NIL; M.res:= -1;
      Display.Broadcast(M);
      IF (M.loc # NIL) & (M.loc IS Frame) THEN
      RETURN M.loc(Frame) END;
      RETURN NIL
   END CurrentDVIViewer;

   (** go to the next page **)
   PROCEDURE Next*;
   VAR
      v: Frame; m: DVIFiles.File;
   BEGIN
      v:= CurrentDVIViewer();
      IF v # NIL THEN
         m:= v.obj(DVIFiles.File);
         IF v.pageNo < m.pageNr THEN
            INC(v.pageNo);
            UpdateModels(v);
            Gadgets.Update(v);
         END
      END
   END Next;

   (** go to the previous page **)
   PROCEDURE Prev*;
   VAR
      v: Frame;
   BEGIN
      v:= CurrentDVIViewer();
      IF (v # NIL) & (v.pageNo > 1) THEN
         DEC(v.pageNo);
         UpdateModels(v);
         Gadgets.Update(v);
      END
   END Prev;

   (** reset zoom to 100% and move origin to top-left corner **)
   PROCEDURE Home*;
   VAR
      v: Frame;
   BEGIN
      v:= CurrentDVIViewer();
      v.zoom:= 1.0; v.hOffset:= 0; v.vOffset:= 0;
      UpdateModels(v);
      Gadgets.Update(v);
   END Home;

   PROCEDURE ToPSFile*;
   (** Create a PS-file from the current dvi-document.
       Usage: ToPSFile [A4|Letter] outfile
   **)
   CONST
     Border = 25.4; (* margin is one inch (in mm) *)
     DPI = 600; (* default resolution *)
   VAR
     v: Frame; f: DVIFiles.File;
     c: GfxPS.Context; oldc: Gfx.Context;
     w,h,oldZoom: REAL; oldHOff,oldVOff: LONGREAL;
     name: ARRAY 64 OF CHAR;
     oldDrawChar: DrawCharHook;
     oldPageNo,i: LONGINT;
   BEGIN
     v:= CurrentDVIViewer();
     IF v = NIL THEN RETURN END; f:= v.obj(DVIFiles.File);
     In.Open; In.Name(name);
     IF name = "A4" THEN w:= GfxPS.A4W; h:= GfxPS.A4H
     ELSIF name = "Letter" THEN w:= GfxPS.LetterW; h:= GfxPS.LetterH
     ELSE Assert(FALSE,"Unknown paper size, use A4 or Letter."); END;
     NEW(c); GfxPS.Init(c,FALSE,FALSE,w,h,Border,Border,Border,Border,DPI);
     In.Name(name);
     GfxPS.Open(c,Files.New(name));
     oldc:= v.context; v.context:= c; oldZoom:= v.zoom; v.zoom:= 1.0;
     oldHOff:= v.hOffset; v.hOffset:= 0.0; oldVOff:= v.vOffset; v.vOffset:= 0.0;
     oldDrawChar:= v.drawChar; v.drawChar:= DrawChar; v.b:= 0; v.l:= 0;
     v.h:= SHORT(ENTIER(h/25.4*GetResolution()/v.conv));
     v.w:= SHORT(ENTIER(w/25.4*GetResolution()/v.conv));
     oldPageNo:= v.pageNo;
     FOR i:= 1 TO f.pageNr DO
        Out.Char('[');
        v.pageNo:= i; DrawPage(v,f);
        Out.Int(i,0); GfxPS.ShowPage(c);
        Out.Char(']');
     END;
     Out.Ln;
     GfxPS.Close(c);
     v.context:= oldc; v.zoom:= oldZoom; v.hOffset:= oldHOff;
     v.vOffset:= oldVOff; v.drawChar:= oldDrawChar; v.pageNo:= oldPageNo;
     Out.String("done."); Out.Ln;
   END ToPSFile;

END DVIViewers.
