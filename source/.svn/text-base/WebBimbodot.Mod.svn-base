MODULE WebBimbodot;

IMPORT
	Dates, Strings, Modules, Kernel,
	XML, XMLObjects, XMLScanner, XMLParser,

	Streams, KernelLog, Archives, Files,
	WebHTTP, WebCGI, HTTPSupport, Commands;

CONST
	MaxAuthor = 16;
	ArticleListFile = "BimboArticles.txt";
	CategoryFile = "BimbodotCategories.txt";
	AuthorDataFile = "BimbodotAuthors.txt";
	BimbodotConfigFile = "BimbodotConfig.dat";


TYPE
	String = Strings.String;

	HTMLWriter= OBJECT
	VAR w* : Streams.Writer;

		PROCEDURE &New*(w : Streams.Writer);
		BEGIN SELF.w := w;
		END New;

		PROCEDURE Head*(CONST title : ARRAY OF CHAR);
		BEGIN
			w.String('<html><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"><title>');
			w.String(title);
			w.String("</title></head>");
			w.String("<body>");
		END Head;

		PROCEDURE Br*;
		BEGIN
			w.String("<br/>");
		END Br;

		PROCEDURE Nbsp*;
		BEGIN
			w.String("&nbsp;");
		END Nbsp;

		PROCEDURE InputText*(CONST name : ARRAY OF CHAR; value : String);
		BEGIN
			w.String('<input type="text" name="'); w.String(name);	w.String('" ');
			IF value # NIL THEN w.String('value="'); HTMLString(value^); w.String('" ') END;
			w.String('/>');
		END InputText;

		PROCEDURE Hide*(CONST name, value : ARRAY OF CHAR);
		BEGIN
			w.String('<input type="hidden" name="'); w.String(name);	w.String('" ');
			w.String('value="'); HTMLString(value); w.String('" ');
			w.String('/>');
		END Hide;

		PROCEDURE BeginOptionField*(CONST name, value: ARRAY OF CHAR);
		BEGIN
			w.String('<select  name="'); w.String(name); w.String('" ');
			IF value # "" THEN w.String(' value="'); w.String(value); w.String('"')	END;
			w.String('>');
		END BeginOptionField;

		PROCEDURE Option*(CONST text : ARRAY OF CHAR);
		BEGIN
			w.String('<option>'); HTMLString(text); w.String('</option>');
		END Option;

		PROCEDURE EndOptionField*;
		BEGIN
			w.String('</select>');
		END EndOptionField;


		PROCEDURE Submit(CONST text : ARRAY OF CHAR);
		BEGIN
			w.String('<input type="submit" value="');
			w.String(text);
			w.String('" />');
		END Submit;

		PROCEDURE InputArea*(CONST name : ARRAY OF CHAR; value : String);
		BEGIN
			w.String('<textarea cols="80" rows="10" name="'); w.String(name);	w.String('"> ');
			IF value # NIL THEN TAHTMLString(value^); END;
			w.String('</textarea>');
		END InputArea;

		PROCEDURE TextLink*(CONST text, target : ARRAY OF CHAR);
		BEGIN
			w.String('<a href="'); w.String(target); w.String('">'); w.String(text); w.String("</a>")
		END TextLink;

		PROCEDURE Tail*;
		BEGIN
			w.String("</body></html>");
		END Tail;

		PROCEDURE TAHTMLString(CONST s : ARRAY OF CHAR);
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE s[i] # 0X DO
				CASE s[i] OF
					|"<" : w.String("&lt;");
					|">" : w.String("&gt;");
					|"&" : w.String("&amp;");
					|'"' : w.String("&quot;");
				ELSE w.Char(s[i])
				END;
				INC(i)
			END
		END TAHTMLString;

		PROCEDURE HTMLString(CONST s : ARRAY OF CHAR);
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE s[i] # 0X DO
				CASE s[i] OF
					|"<" : w.String("&lt;");
					|">" : w.String("&gt;");
					|"&" : w.String("&amp;");
					|'"' : w.String("&quot;");
					|0DX : w.String("<br/>");
				ELSE w.Char(s[i])
				END;
				INC(i)
			END
		END HTMLString;

		PROCEDURE URIString(CONST s : ARRAY OF CHAR);
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE s[i] # 0X DO
				IF uriLiteral[ORD(s[i])] THEN w.Char(s[i])
				ELSE w.Char("%"); w.Hex(ORD(s[i]), -2)
				END;
				INC(i)
			END
		END URIString;


	END HTMLWriter;

	Version = OBJECT
	VAR title, department, category, author, email, posterUID, date, text, cache  : String;
		articleID : String;
		authorUID : LONGINT;
		errors : BOOLEAN;

		PROCEDURE &New*;
		BEGIN
			title := empty; department := empty; category := empty; author := empty; email := empty; posterUID := empty; date := empty; text := empty; cache := NIL;
		END New;

		PROCEDURE Store(w : Streams.Writer);
		VAR d : XML.Document;
			r, e : XML.Element;
			c : XML.CDataSect;
		BEGIN
			NEW(d);
			NEW(r); r.SetName("Version"); d.AddContent(r);

			NEW(e); e.SetName("Title"); r.AddContent(e);
			NEW(c); c.SetStr(title^); e.AddContent(c);

			NEW(e); e.SetName("Department"); r.AddContent(e);
			NEW(c); c.SetStr(department^); e.AddContent(c);

			NEW(e); e.SetName("PosterUID"); r.AddContent(e);
			NEW(c); c.SetStr(posterUID^); e.AddContent(c);

			NEW(e); e.SetName("Email"); r.AddContent(e);
			NEW(c); c.SetStr(email^); e.AddContent(c);

			NEW(e); e.SetName("Author"); r.AddContent(e);
			NEW(c); c.SetStr(author^); e.AddContent(c);

			NEW(e); e.SetName("Category"); r.AddContent(e);
			NEW(c); c.SetStr(category^); e.AddContent(c);

			NEW(e); e.SetName("Date"); r.AddContent(e);
			NEW(c); c.SetStr(date^); e.AddContent(c);

			NEW(e); e.SetName("Text"); r.AddContent(e);
			NEW(c); c.SetStr(text^); e.AddContent(c);

			d.Write(w, NIL, 0);
			w.Update;
		END Store;

		PROCEDURE Fail(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
		BEGIN
			errors := TRUE;
			KernelLog.String("Version load failed : "); KernelLog.String("pos= "); KernelLog.Int(pos, 0); KernelLog.String("msg= "); KernelLog.String(msg); KernelLog.Ln;
		END Fail;

		PROCEDURE Load(r : Streams.Reader) : BOOLEAN;
		VAR s : XMLScanner.Scanner;
			p : XMLParser.Parser;
			d : XML.Document;
			enum: XMLObjects.Enumerator; obj : ANY;
			root, e: XML.Element; str : String;

			PROCEDURE GetCDataContent(e : XML.Element) : String;
			VAR en : XMLObjects.Enumerator;
				p : ANY;
			BEGIN
				en := e.GetContents();
				p := en.GetNext();
				IF p # NIL THEN
					IF p IS XML.CDataSect THEN
						RETURN p(XML.CDataSect).GetStr()
					END
				END;
				RETURN NIL
			END GetCDataContent;

		BEGIN
			NEW(s, r); NEW(p, s); p.reportError := Fail;
			errors := FALSE;
			d := p.Parse();
			IF errors THEN RETURN FALSE END;

			root := d.GetRoot();

			enum := root.GetContents();
			WHILE enum.HasMoreElements() DO
				obj := enum.GetNext();
				IF obj IS XML.Element THEN
					e := obj(XML.Element); str := e.GetName();
					IF str^ = "Title" THEN title := GetCDataContent(e) END;
					IF str^ = "Department" THEN department := GetCDataContent(e) END;
					IF str^ = "Author" THEN author := GetCDataContent(e) END;
					IF str^ = "Email" THEN email := GetCDataContent(e) END;
					IF str^ = "PosterUID" THEN posterUID := GetCDataContent(e) END;
					IF str^ = "Category" THEN category := GetCDataContent(e) END;
					IF str^ = "Date" THEN date:= GetCDataContent(e) END;
					IF str^ = "Text" THEN text := GetCDataContent(e) END;
				END
			END;
			RETURN TRUE
		END Load;

	END Version;

	Article* = OBJECT
	VAR uid, path, filename, stateFileName : String;
		nofVersions : LONGINT;
		current : Version;
		archive : Archives.Archive;
		site : Archive;


		PROCEDURE Load(CONST path, uid : ARRAY OF CHAR) : BOOLEAN;
		VAR fn : ARRAY 1024 OF CHAR;
		BEGIN
			SELF.uid := Strings.NewString(uid);
			SELF.path := Strings.NewString(path);
			COPY(path, fn); Strings.Append(fn, uid); Strings.Append(fn, ".tar");
			SELF.filename := Strings.NewString(fn);
			archive := Archives.Old(filename^, "tar");
			IF archive = NIL THEN RETURN FALSE END;

			COPY(path, fn); Strings.Append(fn, uid); Strings.Append(fn, ".art");
			stateFileName := Strings.NewString(fn);
			LoadState;

			current := GetVersion(nofVersions - 1);
			RETURN TRUE
		END Load;

		PROCEDURE Create(CONST path, uid : ARRAY OF CHAR; version : Version);
		VAR fn : ARRAY 1024 OF CHAR;
		BEGIN
			nofVersions := 0;
			SELF.uid := Strings.NewString(uid);
			SELF.path := Strings.NewString(path);
			COPY(path, fn); Strings.Append(fn, uid); Strings.Append(fn, ".tar");
			SELF.filename := Strings.NewString(fn);
			archive := Archives.New(filename^, "tar");

			COPY(path, fn); Strings.Append(fn, uid); Strings.Append(fn, ".art");
			stateFileName := Strings.NewString(fn);
			InternalAdd(version)
		END Create;


		(* count the number of article versions in the archive file *)
		PROCEDURE CountVersions;
		VAR index : Archives.Index;
			i, count : LONGINT;
			n : String;
		BEGIN
			archive.Acquire;
			index := archive.GetIndex();
			count := 0;
			FOR i := 0 TO LEN(index) - 1 DO
				n := index[i].GetName();
				IF n[0] = "V" THEN INC(count) END
			END;
			archive.Release;
			nofVersions := count
		END CountVersions;

		(* load the info about the number of article version from a cache file *)
		PROCEDURE LoadState;
		VAR f : Files.File;
			r : Files.Reader;
		BEGIN
			f := Files.Old(stateFileName^);
			IF f = NIL THEN
				CountVersions;
				StoreState
			ELSE
				Files.OpenReader(r, f, 0);
				r.Int(nofVersions, FALSE);
			END;
			IF nofVersions = 0 THEN CountVersions; StoreState END;
		END LoadState;

		(* store the number of article versions in the archive file *)
		PROCEDURE StoreState;
		VAR f : Files.File;
			w : Files.Writer;
		BEGIN
			f := Files.New(stateFileName^);
			Files.OpenWriter(w, f, 0);
			w.Int(nofVersions, 0);
			w.Update;
			Files.Register(f)
		END StoreState;

		PROCEDURE GetVersion*(nr : LONGINT) : Version;
		VAR v : Version;
			receiver : Streams.Receiver;
			r : Streams.Reader;
			t, vName : ARRAY 8 OF CHAR;
		BEGIN {EXCLUSIVE}
			IF (nr < 0) OR (nr >= nofVersions) THEN nr := nofVersions - 1 END;
			Strings.IntToStr(nr, t);
			vName := "V";
			Strings.Append(vName, t);
			NEW(v);
			archive.Acquire;
			receiver := archive.OpenReceiver(vName);
			IF receiver # NIL THEN
				NEW(r, receiver, 128);
				IF ~v.Load(r) THEN v := NIL END;
			ELSE v := NIL
			END;
			archive.Release;
			IF v # NIL THEN v.articleID := uid END;
			RETURN v
		END GetVersion;

		PROCEDURE InternalAdd(v : Version);
		VAR t, vName : ARRAY 8 OF CHAR;
			w : Streams.Writer;
			s : Streams.Sender;
		BEGIN
			v.articleID := uid;
			Strings.IntToStr(nofVersions, t);
			vName := "V";
			Strings.Append(vName, t);
			archive.Acquire;
			s := archive.OpenSender(vName);
			NEW(w, s, 128);
			v.Store(w);
			archive.Release;
			current := v;
			INC(nofVersions);
			StoreState;
		END InternalAdd;

		PROCEDURE AddVersion*(v : Version);
		BEGIN {EXCLUSIVE}
			InternalAdd(v);
			IF site # NIL THEN site.ArticleUpdated END;
		END AddVersion;

	END Article;

	Articles = POINTER TO ARRAY OF Article;

	ArticleList = POINTER TO RECORD
		uid : String;
		prev, next: ArticleList;
	END;

	Author = RECORD
		uid : ARRAY 16 OF CHAR;
		pwd : ARRAY 16 OF CHAR;
		name : ARRAY 64 OF CHAR;
		email : ARRAY 64 OF CHAR;
		dept : ARRAY 64 OF CHAR;
	END;

	CategoryStrings = POINTER TO ARRAY OF Strings.String;

	Archive= OBJECT
	VAR articles : Articles;
		nofLoadedArticles : LONGINT;
		aList, path, title : ARRAY 256 OF CHAR;
		id : ARRAY 32 OF CHAR;
		frontPage : Strings.Buffer;

		first, last : ArticleList;
		needUpdate : BOOLEAN;
		alive : BOOLEAN;

		authorList : ARRAY MaxAuthor OF Author;
		nofAuthor : LONGINT;

		nofCategories : LONGINT;
		categoryStrings : CategoryStrings;

		PROCEDURE LoadCategories;
		VAR
			f : Files.File;
			r : Files.Reader;
			s : ARRAY 64 OF CHAR;
			fn : ARRAY 256 OF CHAR;
		BEGIN
			COPY(path, fn);
			Strings.Append(fn, CategoryFile);
			f := Files.Old(fn);

			IF f = NIL THEN
				nofCategories := 3; NEW(categoryStrings, 3);
				categoryStrings[0] := Strings.NewString("Shit Happens");
				categoryStrings[1] := Strings.NewString("Department");
				categoryStrings[2] := Strings.NewString("People");
			ELSE
				NEW(categoryStrings, 64); nofCategories := 0;
				Files.OpenReader(r, f, 0);
				WHILE (r.res = 0) & (nofCategories < 64) DO
					r.Ln(s);
					categoryStrings[nofCategories] := Strings.NewString(s);
					INC(nofCategories)
				END
			END;
		END LoadCategories;


		PROCEDURE &Init*(CONST path, id, title : ARRAY OF CHAR);
		VAR
			f : Files.File;
			r : Files.Reader;
			s : ARRAY 32 OF CHAR;
			al : ArticleList;
			fn : ARRAY 256 OF CHAR;
		BEGIN
			COPY(path, SELF.path);
			COPY(id, SELF.id);
			COPY(title, SELF.title);

			nofAuthor := 0;
			COPY(path, fn);
			Strings.Append(fn, AuthorDataFile);

			f := Files.Old(fn);
			IF f = NIL THEN
				nofAuthor := 1;
				authorList[0].uid := "T";
				authorList[0].pwd := "F";
				authorList[0].name := "Hobbes the Rat";
				authorList[0].email := "hobbestherat@bimbodot.org";
				authorList[0].dept := "bimbo";
			ELSE
				Files.OpenReader(r, f, 0);
				WHILE (r.res = 0) & (nofAuthor < MaxAuthor) DO
					r.String(authorList[nofAuthor].uid); r.SkipWhitespace;
					r.String(authorList[nofAuthor].pwd); r.SkipWhitespace;
					r.String(authorList[nofAuthor].name); r.SkipWhitespace;
					r.String(authorList[nofAuthor].email); r.SkipWhitespace;
					r.String(authorList[nofAuthor].dept); r.SkipLn;
					IF r.res = 0 THEN INC(nofAuthor) END;
				END;
			END;

			LoadCategories;

			NEW(first); NEW(last); first.next := last; last.prev := first;


			NEW(articles, 4);
			COPY(path, aList);
			Strings.Append(aList, ArticleListFile);

			f := Files.Old(aList);
			IF f # NIL THEN
				Files.OpenReader(r, f, 0);

				WHILE r.res = 0 DO
					r.String(s); r.SkipLn;
					IF r.res = 0 THEN
						NEW(al);

						al.uid := Strings.NewString(s);
						al.prev := last.prev; last.prev := al;
						al.next := last; al.prev.next := al;
					END
				END
			END;
			CreateFrontPage
		END Init;

		PROCEDURE CreateFrontPage;
		VAR w : Streams.Writer;
			h : HTMLWriter;
			al : ArticleList;
			a : Article; count : LONGINT;
			b : Strings.Buffer;
			l : ARRAY 128 OF CHAR;
		BEGIN
			NEW(b, 1024); w := b.GetWriter();
			NEW(h, w);
			h.Head(title);
			MakeListLink(SELF, l);
			Strings.Append(l, "&action=Edit");
			h.TextLink("Author New Article", l);
			h.Br;

			al := last.prev;
			count := 0;

			WHILE (count < 20) & (al # first) DO
				a := InternalGetArticle(al.uid^);
				IF a # NIL THEN	RenderArticleHeadline(h, SELF, a) END;
				INC(count); al := al.prev;
			END;
			h.Tail;
			w.Update;
			frontPage := b
		END CreateFrontPage;

		PROCEDURE ArticleUpdated;
		BEGIN  {EXCLUSIVE}
			needUpdate := TRUE;
		END ArticleUpdated;

		PROCEDURE LoadArticle(CONST uid : ARRAY OF CHAR) : Article;
		VAR a : Article;
		BEGIN
			NEW(a); a.site := SELF;
			IF a.Load(path, uid) THEN RETURN a
			ELSE RETURN NIL
			END
		END LoadArticle;

		PROCEDURE AddLoadedArticle(a : Article);
		VAR grow : Articles; i : LONGINT;
		BEGIN
			IF nofLoadedArticles >= LEN(articles) THEN
				NEW(grow, LEN(articles) * 2);
				FOR i := 0 TO nofLoadedArticles - 1 DO	grow[i] := articles[i]	END;
				articles := grow
			END;
			articles[nofLoadedArticles] := a; INC(nofLoadedArticles)
		END AddLoadedArticle;

		PROCEDURE InternalGetArticle(CONST uid : ARRAY OF CHAR) : Article;
		VAR i : LONGINT;
			a : Article;
		BEGIN
			FOR i := 0 TO nofLoadedArticles - 1 DO
				IF articles[i].uid^ = uid THEN
					RETURN articles[i]
				END;
			END;
			a := LoadArticle(uid);
			IF a # NIL THEN AddLoadedArticle(a) END;
			RETURN a
		END InternalGetArticle;

		PROCEDURE GetArticle*(CONST uid : ARRAY OF CHAR): Article;
		BEGIN
			RETURN InternalGetArticle(uid)
		END GetArticle;


		PROCEDURE GetVersion*(CONST uid : ARRAY OF CHAR; vNr : LONGINT) : Version;
		VAR a : Article;
		BEGIN {EXCLUSIVE}
			a := InternalGetArticle(uid);
			RETURN a.GetVersion(vNr)
		END GetVersion;

		PROCEDURE GetUID(VAR uid : ARRAY OF CHAR);
		VAR t, ts : ARRAY 32 OF CHAR;
			i : LONGINT;
		BEGIN
			uid := "D";
			Strings.FormatDateTime("yyyymmdd", Dates.Now(), t);
			Strings.Append(uid, t);
			Strings.Append(uid, "A");
			COPY(uid, t); i := 0;
			REPEAT
				Strings.IntToStr(i, ts);
				COPY(t, uid); Strings.Append(uid, ts);
				INC(i)
			UNTIL InternalGetArticle(uid) = NIL;
		END GetUID;


		PROCEDURE CreateArticle(v : Version) : Article;
		VAR
			a : Article;
			uid : ARRAY 32 OF CHAR;
			al : ArticleList;

			f: Files.File; w : Files.Writer;
		BEGIN {EXCLUSIVE}
			GetUID(uid);

			NEW(a);a.site := SELF;
			a.Create(path, uid, v);
			AddLoadedArticle(a);
			NEW(al);
			al.uid := Strings.NewString(uid);
			al.prev := last.prev; last.prev := al;
			al.next := last; al.prev.next := al;

			f := Files.Old(aList);
			IF f = NIL THEN f := Files.New(aList) END;

			Files.OpenWriter(w, f, f.Length());
			w.String(uid); w.Ln;
			w.Update;
			Files.Register(f);

			CreateFrontPage;
			needUpdate := TRUE;
			RETURN a
		END CreateArticle;

		PROCEDURE Finish;
		BEGIN {EXCLUSIVE}
			alive := FALSE
		END Finish;


	BEGIN {ACTIVE}
		alive := TRUE;
		WHILE alive DO
			BEGIN{EXCLUSIVE}
				AWAIT(needUpdate OR ~alive);
				CreateFrontPage;
				needUpdate := FALSE
			END
		END;
	END Archive;

	ArchiveInfo = RECORD
		id : ARRAY 256 OF CHAR;
		path, title : ARRAY 256 OF CHAR;
		content : Archive;
	END;
	ArchiveList = POINTER TO ARRAY OF ArchiveInfo;

VAR
	uriLiteral : ARRAY 256 OF BOOLEAN;
	empty : String;
	archiveList : ArchiveList;
	nofArchive : LONGINT;

PROCEDURE MakeListLink(archive : Archive; VAR l : ARRAY OF CHAR);
BEGIN
	l := "Bimbodot?archive=";
	Strings.Append(l, archive.id)
END MakeListLink;


PROCEDURE RenderArticleHeadline(h :HTMLWriter; archive : Archive; a : Article);
VAR version : Version;
	w : Streams.Writer; l : ARRAY 256 OF CHAR;
BEGIN
	version := a.GetVersion(-1);
	IF version = NIL THEN KernelLog.String("Version is NIL"); KernelLog.Ln; END;
	IF version = NIL THEN RETURN END;
	w := h.w;
	w.String('<h2>');
	l := "Bimbodot?action=Show&archive=";Strings.Append(l, archive.id);
	Strings.Append(l, "&article="); Strings.Append(l, version.articleID^);
	h.TextLink(version.title^, l);
	w.String("</h2>");

	w.String("<b>");
	IF version.category # NIL THEN w.String("["); w.String(version.category^); w.String("] ") END;
	w.String('Posted by <a href="mailto:');w.String(version.email^); w.String('">');
	w.String(version.author^); w.String("</a> on "); w.String(version.date^);	w.String("</b>"); h.Br;
	w.String("<i> from the "); w.String(version.department^); w.String(" dept. </i>"); h.Br;
	w.String(version.text^);
	h.Br
END RenderArticleHeadline;

PROCEDURE FindVersion(archive : Archive; r : HTTPSupport.HTTPRequest) : Version;
VAR
	article : Article;
	var: HTTPSupport.HTTPVariable;
	vNr : LONGINT;
BEGIN
	var := r.GetVariableByName("article");
	IF var # NIL THEN
		article := archive.GetArticle(var.value);
		var := r.GetVariableByName("version");
		IF var = NIL THEN RETURN article.current
		ELSE
			Strings.StrToInt(var.value, vNr);
			RETURN article.GetVersion(vNr)
		END
	ELSE
		RETURN NIL
	END
END FindVersion;

PROCEDURE Frontpage*(archive : Archive; data : ANY) : ANY;
VAR context : WebCGI.CGIContext;
	b : Strings.Buffer;
	s : String;
BEGIN
	IF (data # NIL) & (data IS WebCGI.CGIContext) THEN
		context := data(WebCGI.CGIContext);
		b := archive.frontPage;
		context.reply.statuscode := WebHTTP.OK;
		context.reply.contentlength:= b.GetLength();
		context.reply.contenttype := "text/html; charset=UTF-8";
		WebHTTP.SendResponseHeader(context.reply, context.w);
		s := b.GetString();
		context.w.Bytes(s^, 0, b.GetLength());
		context.w.Update;
	END;
	RETURN NIL
END Frontpage;

PROCEDURE QueryEdit*(archive : Archive; data : ANY) : ANY;
VAR context : WebCGI.CGIContext;
	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;
	v : Version;
	 tv : String;
	now : ARRAY 64 OF CHAR;
	h : HTMLWriter;
	i : LONGINT;
BEGIN
	IF (data # NIL) & (data IS WebCGI.CGIContext) THEN
		context := data(WebCGI.CGIContext);
		v := FindVersion(archive, context.request);

		NEW(chunker, w, context.w, context.request.header, context.reply);
		context.reply.statuscode := WebHTTP.OK;
		context.reply.contenttype := "text/html; charset=UTF-8";
		WebHTTP.SendResponseHeader(context.reply, context.w);

		NEW(h, w);
		h.Head("Bimbodot Edit Article");

		w.String('<form action="Bimbodot?action=Publish" method="POST" accept-charset="UTF-8" >'); w.Ln;

		w.String("<b>Accreditiation:</b><br/>");
		w.String('Editor : '); h.InputText("editor", NIL);
		w.String('Authorization : '); h.InputText("password", NIL);
		h.Br; w.String("<hr/>");  w.Ln;

		h.Hide("archive", archive.id);
		IF (v # NIL) & (v.articleID # NIL) THEN h.Hide("article", v.articleID^) END;

		IF (v # NIL) THEN tv := v.title END;
		w.String('Title : '); h.InputText("title", tv); h.Br; w.Ln;

		IF (v # NIL) THEN tv := v.author END;
		w.String("Author : "); h.InputText("author", tv); w.String("<i>leave empty for poster default</i>"); h.Br; w.Ln;

		IF (v # NIL) THEN tv := v.email END;
		w.String("Email : "); h.InputText("email", tv); w.String("<i>leave empty for poster default</i>"); h.Br; w.Ln;

		IF (v # NIL) THEN tv := v.department END;
		w.String("Department : "); h.InputText("department", tv); w.String("<i>leave empty for poster default</i>"); h.Br; w.Ln;

		IF (v # NIL) THEN tv := v.category ELSE tv := empty END;
		w.String("Category : ");
		h.BeginOptionField("category", tv^); h.Br; w.Ln;
		FOR i := 0 TO archive.nofCategories - 1 DO
			h.Option(archive.categoryStrings[i]^)
		END;
		h.EndOptionField;


		Strings.FormatDateTime("yyyy.mm.dd @ hh.nn.ss", Dates.Now(), now);
		w.String("Date : "); h.InputText("date", Strings.NewString(now)); h.Br; w.Ln;

		IF (v # NIL) THEN tv := v.text END;
		w.String("Text : "); h.InputArea("text", tv); h.Br; w.Ln;
		h.Submit("Publish");

		w.String('</form>');

		h.Tail;
		w.Ln; w.Update;
		chunker.Close;
	END;
	RETURN NIL
END QueryEdit;

PROCEDURE Publish*(archive: Archive;  data : ANY) : ANY;
VAR context : WebCGI.CGIContext;
	w : Streams.Writer;
	h : HTMLWriter;
	chunker : WebHTTP.ChunkedOutStream;
	version : Version;
	article : Article;
	var: HTTPSupport.HTTPVariable;
	editor, pw : ARRAY 64 OF CHAR;
	l : ARRAY 256 OF CHAR;
	id : LONGINT;
BEGIN
	IF (data # NIL) & (data IS WebCGI.CGIContext) THEN
		context := data(WebCGI.CGIContext);

		var := context.request.GetVariableByName("editor");
		IF var # NIL THEN COPY(var.value, editor) END;
		var := context.request.GetVariableByName("password");
		IF var # NIL THEN COPY(var.value, pw) END;

		id := 0; WHILE (id < archive.nofAuthor) & (archive.authorList[id].uid # editor) DO
		INC(id) END;

		IF (id < archive.nofAuthor) & (archive.authorList[id].pwd = pw) THEN
			NEW(chunker, w, context.w, context.request.header, context.reply);
			context.reply.statuscode := WebHTTP.OK;
			WebHTTP.SendResponseHeader(context.reply, context.w);
			NEW(h, w);

			h.Head("Bimbodot Edit Result");

			var := context.request.GetVariableByName("article");
			IF (var # NIL) THEN article := archive.GetArticle(var.value) END;

			NEW(version);

			var := context.request.GetVariableByName("title");
			IF (var # NIL) & (var.value # "")  THEN version.title := Strings.NewString(var.value)
			ELSE version.title := Strings.NewString("I forgot the Title");
			END;

			var := context.request.GetVariableByName("author");
			IF (var # NIL) & (var.value # "") THEN version.author := Strings.NewString(var.value)
			ELSE version.author := Strings.NewString(archive.authorList[id].name);
			END;

			var := context.request.GetVariableByName("email");
			IF (var # NIL) & (var.value # "") THEN version.email:= Strings.NewString(var.value)
			ELSE version.email := Strings.NewString(archive.authorList[id].email);
			END;


			var := context.request.GetVariableByName("department");
			IF (var # NIL) & (var.value # "") THEN version.department := Strings.NewString(var.value)
			ELSE version.department := Strings.NewString(archive.authorList[id].dept);
			END;

			var := context.request.GetVariableByName("category");
			IF (var # NIL) & (var.value # "") THEN version.category := Strings.NewString(var.value)
			ELSE version.category := Strings.NewString("Bimbo");
			END;


			var := context.request.GetVariableByName("date");
			IF (var # NIL) & (var.value # "") THEN version.date := Strings.NewString(var.value)
			ELSE version.date := Strings.NewString("Whenever");
			END;

			var := context.request.GetVariableByName("text");
			IF (var # NIL) & (var.value # "") THEN version.text := Strings.NewString(var.value)
			ELSE version.text := Strings.NewString("Whatever");
			END;

			IF article = NIL THEN
				article := archive.CreateArticle(version);
				w.String("Article : "); w.String(article.uid^); w.String(" has been created"); w.Ln
			ELSE
				w.String("Article : "); w.String(article.uid^); w.String(" has been updated"); w.Ln;
				article.AddVersion(version);
			END;
			MakeListLink(archive, l);
			h.Br; h.TextLink("Home", l);

			h.Tail;
			w.Ln; w.Update;
			chunker.Close;
		ELSE
			NEW(chunker, w, context.w, context.request.header, context.reply);
			context.reply.statuscode := WebHTTP.Unauthorized;
			WebHTTP.SendResponseHeader(context.reply, context.w);

			NEW(h, w);
			h.Head("Error : Editing Article");
			w.String("You need a-huga-accredition to publish an article! If you have one... go back and fill it in otherwise just forget about it.");
			h.Tail;
			w.Ln; w.Update;
			chunker.Close;
		END;
	END;
	RETURN NIL
END Publish;


PROCEDURE ShowArticle*(archive : Archive; data : ANY) : ANY;
VAR r : HTTPSupport.HTTPRequest;
	context : WebCGI.CGIContext;
	i : LONGINT;
	var: HTTPSupport.HTTPVariable;
	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;

	article : Article;
	version : Version;
	vNr : LONGINT;
	h : HTMLWriter;
	l : ARRAY 128 OF CHAR;
BEGIN
	IF (data # NIL) & (data IS WebCGI.CGIContext) THEN
		context := data(WebCGI.CGIContext);
		r := context.request;
		var := r.GetVariableByName("article");
		IF var # NIL THEN
			article := archive.GetArticle(var.value);
		END;
		IF article # NIL THEN

			(* reply *)
			NEW(chunker, w, context.w, context.request.header, context.reply);
			context.reply.statuscode := WebHTTP.OK;
			WebHTTP.SendResponseHeader(context.reply, context.w);

			NEW(h, w);
			h.Head(archive.title);

			MakeListLink(archive, l);
			h.TextLink(archive.title, l);

			var := r.GetVariableByName("version");
			IF var = NIL THEN version := article.current
			ELSE
				Strings.StrToInt(var.value, vNr);
				version := article.GetVersion(vNr)
			END;

			IF version # NIL THEN
				w.String('<h2>');
				l := "Bimbodot?action=Show&archive="; Strings.Append(l, archive.id); Strings.Append(l, "&article=");Strings.Append(l, version.articleID^); h.TextLink(version.title^, l);
				w.String("</h2>");

				w.String("<b>");
				IF version.category # NIL THEN w.String("["); w.String(version.category^); w.String("] ") END;
				w.String('Posted by <a href="mailto:');w.String(version.email^); w.String('">');
				w.String(version.author^); w.String("</a> on "); w.String(version.date^);	w.String("</b>"); h.Br;
				w.String("<i> from the "); w.String(version.department^); w.String(" dept. </i>"); h.Br;
				w.String(version.text^);
				h.Br;

				w.String('<a href="Bimbodot?action=Edit&archive='); w.String(archive.id);
				w.String("&article="); w.String(version.articleID^); w.String('">Change this article</a>');	w.String("<br/>");
				w.String("<br/>");
				IF article.nofVersions > 1 THEN
					w.String("Other versions of the article :");
					FOR i := 0 TO article.nofVersions - 1 DO
						w.String('<a href="Bimbodot?action=Show&archive=');w.String(archive.id);
						w.String("&article="); w.String(article.uid^);
						w.String("&version="); w.Int(i, 0); w.String('">'); w.Int(i, 0); w.String("</a>&nbsp;");
					END
				END;
			END;
			h.Tail;
			w.Ln; w.Update;
			chunker.Close;

		ELSE
			NEW(chunker, w, context.w, context.request.header, context.reply);
			context.reply.statuscode := WebHTTP.NotFound;
			WebHTTP.SendResponseHeader(context.reply, context.w);
			w.String("<html><head><title>Bimbodot</title></head>");
			w.String("<body>");
			w.String("Article not found : "); w.String(var.value); w.Ln;
			w.String("</body></html>");
			w.Ln; w.Update;
			chunker.Close;
		END;
	END;
	RETURN NIL
END ShowArticle;

PROCEDURE Access*(context : WebCGI.CGIContext);
VAR
	r : HTTPSupport.HTTPRequest;
	var: HTTPSupport.HTTPVariable;

	action, archiveID, entry : ARRAY 32 OF CHAR;

	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;

	ignore : ANY;

	defaultAction : BOOLEAN;
	milliTimer : Kernel.MilliTimer;
	archive : Archive;
BEGIN
	Kernel.SetTimer(milliTimer, 0);
	r := context.request;
	defaultAction := TRUE;
	var := r.GetVariableByName("action");
	IF var # NIL THEN COPY(var.value, action); defaultAction := FALSE END;

	var := r.GetVariableByName("archive");
	IF var # NIL THEN COPY(var.value, archiveID) END;

	var := r.GetVariableByName("entry");
	IF var # NIL THEN COPY(var.value, entry) END;

	archive := GetArchive(archiveID);

	IF archive = NIL THEN
		NEW(chunker, w, context.w, context.request.header, context.reply);
		context.reply.statuscode := WebHTTP.NotFound;
		WebHTTP.SendResponseHeader(context.reply, context.w);
		w.String("<html><head><title>Forum</title></head>");
		w.String("<body>");
		w.String("Archive not found"); w.Ln;
		w.String("</body></html>");
		w.Ln; w.Update;
		chunker.Close
	ELSE
		IF action = "Show" THEN ignore := ShowArticle(archive, context); RETURN;
		ELSIF defaultAction OR (action = "List") THEN ignore := Frontpage(archive, context); RETURN;
		ELSIF action = "Publish" THEN ignore := Publish(archive, context); RETURN;
		ELSIF action = "Edit" THEN ignore := QueryEdit(archive, context); RETURN;
		ELSE
			NEW(chunker, w, context.w, context.request.header, context.reply);
			context.reply.statuscode := WebHTTP.NotFound;
			WebHTTP.SendResponseHeader(context.reply, context.w);
			w.String("<html><head><title>Forum</title></head>");
			w.String("<body>");
			w.String("Illegal Bimbo request"); w.Ln;
			w.String("</body></html>");
			w.Ln; w.Update;
			chunker.Close
		END
	END;
	KernelLog.String("Bimbodot request handled in "); KernelLog.Int(Kernel.Elapsed(milliTimer), 0); KernelLog.String("ms"); KernelLog.Ln;
END Access;

PROCEDURE AddArchive(CONST id, path, title: ARRAY OF CHAR);
VAR new : ArchiveList;
	i : LONGINT;
BEGIN
	IF nofArchive >= LEN(archiveList) THEN
		NEW(new, LEN(archiveList) * 2);
		FOR i := 0 TO nofArchive - 1 DO new[i] := archiveList[i] END;
		archiveList := new
	END;
	COPY(id, archiveList[nofArchive].id);
	COPY(path, archiveList[nofArchive].path);
	COPY(title, archiveList[nofArchive].title);
	INC(nofArchive)
END AddArchive;

PROCEDURE GetArchiveInternal(CONST id : ARRAY OF CHAR) : Archive;
VAR i : LONGINT; result : Archive;
BEGIN
	i := 0;
	WHILE (i < nofArchive) & (result = NIL)  DO
		IF archiveList[i].id = id THEN
			IF archiveList[i].content = NIL THEN
				NEW(archiveList[i].content, archiveList[i].path, id, archiveList[i].title);
			(*	IF archiveList[i].content.Load() THEN
					KernelLog.String(archiveList[i].id); KernelLog.String(" loaded from "); KernelLog.String(archiveList[i].path); KernelLog.Ln;
				ELSE
					KernelLog.String(archiveList[i].id); KernelLog.String("FAILED loading  from "); KernelLog.String(archiveList[i].path); KernelLog.Ln;
				END;*)
			END;
			result := archiveList[i].content
		END;
		INC(i)
	END;
	RETURN result
END GetArchiveInternal;

PROCEDURE GetArchive(CONST id : ARRAY OF CHAR) : Archive;
BEGIN {EXCLUSIVE}
	RETURN GetArchiveInternal(id)
END GetArchive;

PROCEDURE LoadArchiveList;
VAR f : Files.File;
	r : Files.Reader;
	id, path, title: ARRAY 256 OF CHAR;
BEGIN {EXCLUSIVE}
	f := Files.Old(BimbodotConfigFile);
	IF f # NIL THEN
		Files.OpenReader(r, f, 0);
		WHILE r.res = 0 DO
			r.Token(id); r.SkipWhitespace;
			r.String(path); r.SkipWhitespace;
			r.String(title);
			IF r.res = 0 THEN AddArchive(id, path, title) END;
			r.SkipLn;
		END
	END;
END LoadArchiveList;

PROCEDURE StoreArchiveList;
VAR f : Files.File;
	w : Files.Writer;
	i : LONGINT;
BEGIN {EXCLUSIVE}
	f := Files.New(BimbodotConfigFile);
	Files.OpenWriter(w, f, 0);
	FOR i := 0 TO nofArchive- 1 DO
		w.String(archiveList[i].id); w.String(' "'); w.String(archiveList[i].path); w.String('" '); w.String(' "'); w.String(archiveList[i].title); w.String('" '); w.Ln
	END;
	w.Update;
	Files.Register(f)
END StoreArchiveList;

PROCEDURE Create*(context : Commands.Context);
VAR
	id, path, title: ARRAY 128 OF CHAR;
	archive : Archive;
BEGIN
	context.arg.Token(id); context.arg.SkipWhitespace; context.arg.String(path);
	context.arg.SkipWhitespace; context.arg.String(title);
	BEGIN{EXCLUSIVE}
		archive := GetArchiveInternal(id);
		IF archive # NIL THEN
			context.error.String("Archive already exists"); context.error.Ln;
			RETURN;
		ELSE
			AddArchive(id, path, title);
		END
	END;
	StoreArchiveList;
END Create;

PROCEDURE Finalizer;
VAR i : LONGINT;
	t : Kernel.Timer;
BEGIN
	FOR i := 0 TO nofArchive - 1 DO
		IF archiveList[i].content # NIL THEN archiveList[i].content.Finish END
	END;
	NEW(t);
	t.Sleep(100);
END Finalizer;

PROCEDURE InitURILiterals;
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO 255 DO uriLiteral[i] := FALSE END;
	FOR i :=  61H TO  7AH DO uriLiteral[i] := TRUE END;(* RFC2396 lowalpha *)
	FOR i :=  41H TO 5AH DO uriLiteral[i] := TRUE END;(* RFC2396 upalpha *)
	FOR i := 30H TO 39H DO uriLiteral[i] := TRUE END; (* RFC2396 digit *)
	uriLiteral[2DH] := TRUE; (* - *)
	uriLiteral[5FH] := TRUE; (* underscore *)
	uriLiteral[2EH] := TRUE; (* . *)
	uriLiteral[21H] := TRUE; (* ! *)
	uriLiteral[7EH] := TRUE; (* ~ *)
	uriLiteral[2AH] := TRUE; (* * *)
	uriLiteral[27H] := TRUE; (* ' *)
	uriLiteral[28H] := TRUE; (* ( *)
	uriLiteral[29H] := TRUE;  (* ) *)
END InitURILiterals;

BEGIN
	empty := Strings.NewString("");
	InitURILiterals;
	NEW(archiveList, 128); nofArchive := 0;

	LoadArchiveList;
	Modules.InstallTermHandler(Finalizer)
END WebBimbodot.


WebBimbodot.Test ~
SystemTools.Free WebBimbodot ~

WebHTTPServerTools.Start ~
WebCGI.Install ~

WebCGI.RegisterCGI Bimbodot WebBimbodot.Access~
WebCGI.ListCGI ~
WebBimbodot.Create Bimbodot "FAT:/BDATA/BIMBO/" "The Original Bimbodot" ~
WebBimbodot.Create CSucks "FAT:/BDATA/CSUCKS/" "The Reasons Why C Sucks" ~

Example for BimbodotAuthors.txt :
"hobbes" "password" "Hobbes the Rat" "hobbestherat@bimbodot.org" "RZ-H23"
"barnoid" "password" "Barnoid the Master" "barnoidthemaster@bimbodot.org" "South-Korea"