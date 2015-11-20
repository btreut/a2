MODULE TFWebForum; (** AUTHOR "TF"; PURPOSE "CGI based forum system"; *)

IMPORT
	Dates, Strings,
	XML, XMLObjects, XMLScanner, XMLParser,
	Commands, Files, Streams, IP, Kernel, KernelLog,
	WebHTTP, WebCGI, HTTPSupport;

CONST
(*	MaxAuthor = 16;	*)
	ForumConfigFile = "WebForums.dat";

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

(*		PROCEDURE URIString(VAR s : ARRAY OF CHAR);
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
*)

	END HTMLWriter;

	EntryInfo = RECORD
		subject, id, datetime, author : String;
		entry : XML.Element;
		level : LONGINT;
	END;

	EntryList = POINTER TO ARRAY OF EntryInfo;

	Forum= OBJECT
	VAR doc : XML.Document;
		forum : XML.Element;
		errors : BOOLEAN;
		entryList : EntryList;
		nofEntries : LONGINT;
		title, editor, password : Strings.String;
		filename : ARRAY 128 OF CHAR;

		PROCEDURE &Create*;
		BEGIN
			NEW(doc);
			NEW(forum);
			title:= empty; editor := empty; password := empty;
			forum.SetName("Forum");
			doc.AddContent(forum);
		END Create;

		PROCEDURE SetTitle(CONST title : ARRAY OF CHAR);
		BEGIN
			SELF.title := Strings.NewString(title);
			forum.SetAttributeValue("title", title);
		END SetTitle;

		PROCEDURE SetEditor(CONST editor, password : ARRAY OF CHAR);
		BEGIN
			SELF.editor := Strings.NewString(editor);
			forum.SetAttributeValue("editor", editor);
			SELF.password := Strings.NewString(password);
			forum.SetAttributeValue("password", password);
		END SetEditor;

		PROCEDURE Fail(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
		BEGIN
			errors := TRUE;
			KernelLog.String("Version load failed : "); KernelLog.String("pos= "); KernelLog.Int(pos, 0); KernelLog.String("msg= "); KernelLog.String(msg); KernelLog.Ln;
		END Fail;

		PROCEDURE Load(CONST filename : ARRAY OF CHAR) : BOOLEAN;
		VAR s : XMLScanner.Scanner;
			p : XMLParser.Parser;
			d : XML.Document;
			f : Files.File;
			r : Files.Reader;
		BEGIN {EXCLUSIVE}
			f := Files.Old(filename); COPY(filename, SELF.filename);
			KernelLog.String("loading filename= "); KernelLog.String(filename); KernelLog.Ln;
			IF f = NIL THEN RETURN FALSE END;
			Files.OpenReader(r, f, 0);
			NEW(s, r); NEW(p, s); p.reportError := Fail;
			errors := FALSE;
			d := p.Parse();
			IF errors THEN RETURN FALSE END;
			doc := d;
			forum := doc.GetRoot();
			title := forum.GetAttributeValue("title");
			IF title = NIL THEN title := empty END;

			editor := forum.GetAttributeValue("editor");
			IF editor = NIL THEN editor := empty END;

			password := forum.GetAttributeValue("password");
			IF password = NIL THEN password := empty END;
			RETURN TRUE
		END Load;

		PROCEDURE StoreInternal(CONST filename : ARRAY OF CHAR);
		VAR f : Files.File;
			w : Files.Writer;
		BEGIN
			f := Files.New(filename);
			Files.OpenWriter(w, f, 0);
			doc.Write(w, NIL, 0);
			w.Update;
			Files.Register(f);
			f.Update
		END StoreInternal;

		PROCEDURE Store(CONST filename : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			StoreInternal(filename)
		END Store;

		PROCEDURE AddEntryToParent*(parent, entry : XML.Element);
		VAR id, t : LONGINT;
			s : String;
			ids : ARRAY 10 OF CHAR;
			contents : XMLObjects.Enumerator;
			content : ANY;
		BEGIN {EXCLUSIVE}
			ASSERT((parent # NIL) & (entry # NIL));
			entryList := NIL; nofEntries := 0;
			id := -1;
			contents := parent.GetContents();
			WHILE contents.HasMoreElements() DO
				content := contents.GetNext();
				IF content IS XML.Element THEN
					s := content(XML.Element).GetName();
					IF (s # NIL) & (s^ = "Entry") THEN
						s := content(XML.Element).GetAttributeValue("id");
						IF s # NIL THEN
							Strings.StrToInt(s^, t);
							IF t > id THEN id := t END;
						END
					END
				END;
			END;
			Strings.IntToStr(id + 1, ids);
			entry.SetAttributeValue("id", ids);
			parent.AddContent(entry);
		END AddEntryToParent;

		PROCEDURE FindElement*(CONST path : ARRAY OF CHAR) : XML.Element;
		VAR i, j, l : LONGINT;
			id : ARRAY 32 OF CHAR;
			s : String;
			e, next : XML.Element;
			contents : XMLObjects.Enumerator;
			content : ANY;
		BEGIN {EXCLUSIVE}
			i := 0; j := 0; l := Strings.Length(path);
			e := forum;
			IF forum = NIL THEN RETURN NIL END;
			WHILE j < l DO
				j := Strings.IndexOfByte("/", i, path);
				IF j < 0 THEN j := l END;
				Strings.Copy(path, i, j - i, id);
				i := j + 1;

				contents := e.GetContents();
				next := NIL;
				WHILE contents.HasMoreElements() & (next = NIL) DO
					content := contents.GetNext();
					IF content IS XML.Element THEN
						s := content(XML.Element).GetName();
						IF (s # NIL) & (s^ = "Entry") THEN
							s := content(XML.Element).GetAttributeValue("id");
							IF s # NIL THEN
								IF s^ = id THEN next := content(XML.Element) END;
							END;
						END
					END
				END;
				IF next = NIL THEN RETURN NIL END;
				e := next;
			END;
			RETURN e
		END FindElement;

		PROCEDURE GetEntryPath(e : XML.Element; VAR path : ARRAY OF CHAR);
		VAR s : String; p : XML.Element;
		BEGIN
			p := e.GetParent();
			IF (p # NIL) & (p # forum) THEN GetEntryPath(p, path) END;
			IF (e.GetParent() # forum) THEN Strings.Append(path, "/") END;
			s := e.GetAttributeValue("id");
			IF s # NIL THEN
				Strings.Append(path, s^);
			END;
		END GetEntryPath;

		PROCEDURE AddEntryToList(e : XML.Element);
		VAR subject, author, email, datetime, ip, text : String;
			path : ARRAY 512 OF CHAR;
			new : EntryList; i : LONGINT;
			t : XML.Element;
		BEGIN
			IF entryList = NIL THEN NEW(entryList, 1024) END;
			IF nofEntries >= LEN(entryList) THEN
				NEW(new, LEN(entryList) * 2);
				FOR i := 0 TO nofEntries - 1 DO new[i] := entryList[i] END;
				entryList := new
			END;
			ReadEntry(e, subject, author, email, datetime, ip, text);
			GetEntryPath(e, path);
			entryList[nofEntries].subject := subject;
			entryList[nofEntries].author := author;
			entryList[nofEntries].datetime := datetime;
			entryList[nofEntries].id := Strings.NewString(path);
			entryList[nofEntries].level := 0;
			entryList[nofEntries].entry := e;
			t := e;
			WHILE (t.GetParent() # NIL) & (t.GetParent() # forum) DO INC(entryList[nofEntries].level); t := t.GetParent() END;
			INC(nofEntries)
		END AddEntryToList;

		PROCEDURE  Traverse (c : XML. Content; data: ANY);
		VAR name : String;
		BEGIN
			IF (c # NIL) & (c IS XML.Element) THEN
				name := c(XML.Element).GetName();
				IF (name # NIL) & (name^ = "Entry") THEN
					AddEntryToList(c(XML.Element));
				END
			END;
		END Traverse;

		PROCEDURE GetSubjectList*(VAR e : EntryList; VAR nof : LONGINT);
		BEGIN {EXCLUSIVE}
			IF entryList = NIL THEN forum.Traverse(Traverse, NIL) END;
			e := entryList;
			nof := nofEntries
		END GetSubjectList;

		PROCEDURE AddEntry*(CONST path : ARRAY OF CHAR; entry : XML.Element);
		VAR parent : XML.Element;
			f : Files.File;
			w : Files.Writer;
			s : ARRAY 100 OF CHAR;
		BEGIN
			ASSERT(entry # NIL);
			parent := FindElement(path);
			IF parent # NIL THEN
				AddEntryToParent(parent, entry);
				IF filename # "" THEN Store(filename) END;
			ELSE
				KernelLog.String("Lost entry stored in LostForumEntries.txt"); KernelLog.Ln;
				BEGIN {EXCLUSIVE}
					f := Files.Old("LostForumEntries.txt");
					IF f = NIL THEN
						f := Files.New("LostForumEntries.txt");
					END;
					Files.OpenWriter(w, f, f.Length());
					w.Ln;
					Strings.FormatDateTime("@ yyyy.mm.dd hh.nn.ss", Dates.Now(), s);
					w.String("Was not stored in "); w.String(filename); w.String(s); w.Ln;
					entry.Write(w, NIL, 0);
					w.Update;
					Files.Register(f);
					f.Update;
				END;
			END
		END AddEntry;

		PROCEDURE DeleteEntry*(CONST path : ARRAY OF CHAR);
		VAR entry, parent : XML.Element;
			f : Files.File;
			w : Files.Writer;
			s : ARRAY 100 OF CHAR;
		BEGIN
			entry := FindElement(path);
			ASSERT(entry # NIL);
			parent := entry.GetParent();
			IF parent # NIL THEN
				parent.RemoveContent(entry);
				IF filename # "" THEN Store(filename) END;
				KernelLog.String("deleted entry stored in DeletedEntries.txt"); KernelLog.Ln;
				BEGIN {EXCLUSIVE}
					entryList := NIL; nofEntries := 0; (* kill the cached list *)

					f := Files.Old("DeletedEntries.txt");
					IF f = NIL THEN
						f := Files.New("DeletedEntries.txt");
					END;
					Files.OpenWriter(w, f, f.Length());
					w.Ln;
					Strings.FormatDateTime("@ yyyy.mm.dd hh.nn.ss", Dates.Now(), s);
					w.String("Deleted from "); w.String(filename); w.String(s); w.Ln;
					entry.Write(w, NIL, 0);
					w.Update;
					Files.Register(f);
					f.Update;
				END;
			END
		END DeleteEntry;

		PROCEDURE EditEntry(parent: XML.Element; subject, author, email, datetime, ip, text : String);

			PROCEDURE Set(CONST name : ARRAY OF CHAR; value : String);
			VAR e : XML.Element;
				c : XML.CDataSect;
			BEGIN
				e := GetSubElementByType(parent, name); IF e # NIL THEN parent.RemoveContent(e) END;
				NEW(e);
				e.SetName(name); parent.AddContent(e);
				NEW(c); c.SetStr(value^); e.AddContent(c);
			END Set;

		BEGIN
			entryList := NIL; nofEntries := 0;
			BEGIN {EXCLUSIVE}
				Set("Subject", subject);
				Set("Author", author);
				Set("Email", email);
				Set("DateTime", datetime);
				Set("IP", ip);
				Set("Text", text);
			END;
			IF filename # "" THEN Store(filename) END;
		END EditEntry;

	END Forum;

	ForumInfo = RECORD
		id : ARRAY 256 OF CHAR;
		fileName : ARRAY 256 OF CHAR;
		content : Forum;
	END;

	ForumList = POINTER TO ARRAY OF ForumInfo;

VAR
	uriLiteral : ARRAY 256 OF BOOLEAN;
	empty : String;
	forumList : ForumList;
	nofForum : LONGINT;

PROCEDURE GetSubElementByType*(parent: XML.Element; CONST type : ARRAY OF CHAR): XML.Element;
VAR enum: XMLObjects.Enumerator; p: ANY; e: XML.Element; s: XML.String;
BEGIN
	enum := parent.GetContents();
	WHILE enum.HasMoreElements() DO
		p := enum.GetNext();
		IF p IS XML.Element THEN
			e := p(XML.Element); s := e.GetName();
			IF (s # NIL) & (s^ = type) THEN	(* correct element name *)
				RETURN e
			END
		END
	END;
	RETURN NIL
END GetSubElementByType;

PROCEDURE MakeEntry*(subject, author, email, datetime, ip, text : String): XML.Element;
VAR r, e : XML.Element;
	c : XML.CDataSect;
BEGIN
	NEW(r);
	r.SetName("Entry");

	NEW(e); e.SetName("Subject"); r.AddContent(e);
	NEW(c); c.SetStr(subject^); e.AddContent(c);

	NEW(e); e.SetName("Author"); r.AddContent(e);
	NEW(c); c.SetStr(author^); e.AddContent(c);

	NEW(e); e.SetName("Email"); r.AddContent(e);
	NEW(c); c.SetStr(email^); e.AddContent(c);

	NEW(e); e.SetName("DateTime"); r.AddContent(e);
	NEW(c); c.SetStr(datetime^); e.AddContent(c);

	NEW(e); e.SetName("IP"); r.AddContent(e);
	NEW(c); c.SetStr(ip^); e.AddContent(c);

	NEW(e); e.SetName("Text"); r.AddContent(e);
	NEW(c); c.SetStr(text^); e.AddContent(c);

	RETURN r
END MakeEntry;


PROCEDURE PostingToHTML*(w : Streams.Writer; h : HTMLWriter; subject, author, email, datetime, ip, text : String);
BEGIN
	w.String('<table border="0" bgcolor="#F0F0F0">'); w.Ln;
	w.String('<tr><td>');
	w.String("Subject : "); w.String("<b>"); h.HTMLString(subject^);w.String("</b>");
	w.String('</td></tr>'); w.Ln;

	w.String('<tr><td>');
	w.String("Author : "); h.HTMLString(author^); h.Br;
	w.String('</td></tr>'); w.Ln;

	w.String('<tr><td>');
	w.String("Email : ");h.HTMLString(email^); h.Br;
	w.String('</td></tr>'); w.Ln;

	w.String('<tr><td>');
	w.String("Date : ");h.HTMLString(datetime^); h.Br;
	w.String('</td></tr>'); w.Ln;
	w.String("</table>");

	w.String('<table border="1" width="100%" cellpadding="0" cellspacing="0" bordercolor="#111111" bgcolor="#CCFFFF"><tr><td>');
	h.HTMLString(text^); h.Br;
	w.String("</td></tr></table>");
END PostingToHTML;

PROCEDURE ReadEntry*(entry : XML.Element; VAR subject, author, email, datetime, ip, text : String);
VAR
	enum: XMLObjects.Enumerator; obj : ANY;
	e: XML.Element; str : String;

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
	subject := empty; author := empty; email := empty; datetime := empty; ip := empty; text := empty;
	enum := entry.GetContents();
	WHILE enum.HasMoreElements() DO
		obj := enum.GetNext();
		IF obj IS XML.Element THEN
			e := obj(XML.Element); str := e.GetName();
			IF str^ = "Subject" THEN subject := GetCDataContent(e) END;
			IF str^ = "Author" THEN author := GetCDataContent(e) END;
			IF str^ = "Email" THEN email := GetCDataContent(e) END;
			IF str^ = "DateTime" THEN datetime := GetCDataContent(e) END;
			IF str^ = "IP" THEN ip := GetCDataContent(e) END;
			IF str^ = "Text" THEN text := GetCDataContent(e) END;
		END
	END;
END ReadEntry;

PROCEDURE ListLink(VAR forumID, link : ARRAY OF CHAR);
BEGIN
	COPY("Forum?forum=", link);
	Strings.Append(link, forumID);
	Strings.Append(link, "&action=List")
END ListLink;

PROCEDURE ShowLink(VAR forumID, entryID, link : ARRAY OF CHAR);
BEGIN
	COPY("Forum?forum=", link);
	Strings.Append(link, forumID);
	Strings.Append(link, "&action=Show&entry=");
	Strings.Append(link, entryID);
END ShowLink;

PROCEDURE ReplyLink(VAR forumID, entryID, link : ARRAY OF CHAR);
BEGIN
	COPY("Forum?forum=", link);
	Strings.Append(link, forumID);
	Strings.Append(link, "&action=Reply");
	IF entryID # "" THEN
		Strings.Append(link, "&entry=");
		Strings.Append(link, entryID)
	END
END ReplyLink;

PROCEDURE PublishPostLink(VAR forumID, entryID, link : ARRAY OF CHAR);
BEGIN
	COPY("Forum?forum=", link);
	Strings.Append(link, forumID);
	Strings.Append(link, "&action=Publish");
	IF entryID # "" THEN
		Strings.Append(link, "&entry=");
		Strings.Append(link, entryID)
	END
END PublishPostLink;


PROCEDURE DeletePostLink(VAR forumID, entryID, link : ARRAY OF CHAR);
BEGIN
	COPY("Forum?forum=", link);
	Strings.Append(link, forumID);
	Strings.Append(link, "&action=PublishDelete");
	IF entryID # "" THEN
		Strings.Append(link, "&entry=");
		Strings.Append(link, entryID)
	END
END DeletePostLink;

PROCEDURE GetParentLink(VAR forumID, entryID, link : ARRAY OF CHAR) : BOOLEAN;
VAR p : LONGINT;
	parentID : ARRAY 512 OF CHAR;
BEGIN
	p := Strings.LastIndexOfByte2("/", entryID);
	IF p > 0 THEN
		Strings.Copy(entryID, 0, p, parentID);
		ShowLink(forumID, parentID, link);
		RETURN TRUE
	ELSE RETURN FALSE
	END;
END GetParentLink;

PROCEDURE List*(forum : Forum; forumID : ARRAY OF CHAR; context: WebCGI.CGIContext);
VAR
	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;
	h : HTMLWriter;
	entryList : EntryList;
	nof, i, j : LONGINT;
	link : ARRAY 256 OF CHAR;
	e : ARRAY 2 OF CHAR;
BEGIN
	forum.GetSubjectList(entryList, nof);
	(* reply *)
	NEW(chunker, w, context.w, context.request.header, context.reply);
	context.reply.statuscode := WebHTTP.OK;
	context.reply.contenttype := "text/html; charset=UTF-8";
	WebHTTP.SendResponseHeader(context.reply, context.w);

	NEW(h, w);
	h.Head(forum.title^);
	w.String("<H1>");
	h.HTMLString(forum.title^);
	w.String("</H1>"); w.Ln;

	FOR i := 0 TO nof - 1 DO
		FOR j := 0 TO entryList[i].level - 1 DO h.Nbsp; h.Nbsp END;
		ShowLink(forumID, entryList[i].id^, link);
		h.TextLink(entryList[i].subject^, link);
		w.String("<i> (");
		w.String(entryList[i].author^);
		w.String( " @ ");
		w.String(entryList[i].datetime^);
		w.String(")</i>");
		h.Br;
	END;
	e := "";
	h.Br;
	ReplyLink(forumID, e, link);
	h.TextLink("Write new message", link);

	h.Tail;
	w.Ln; w.Update;
	chunker.Close;
END List;

PROCEDURE Show*(forum : Forum; forumID, entryID : ARRAY OF CHAR; context: WebCGI.CGIContext);
VAR
	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;
	h : HTMLWriter;
	nof, i, j, thisIndent : LONGINT;
	entry : XML.Element;
	firstReply : BOOLEAN;
	link, title : ARRAY 256 OF CHAR;
	subject, author, email, datetime, ip, text : String;
	entries : EntryList;
BEGIN
	(* reply *)
	NEW(chunker, w, context.w, context.request.header, context.reply);
	context.reply.statuscode := WebHTTP.OK;
	context.reply.contenttype := "text/html; charset=UTF-8";
	WebHTTP.SendResponseHeader(context.reply, context.w);

	NEW(h, w);

	entry := forum.FindElement(entryID);
	IF entry # NIL THEN
		forum.GetSubjectList(entries, nof);

		ReadEntry(entry, subject, author, email, datetime, ip, text);
		COPY(forum.title^, title);
		Strings.Append(title, " - "); Strings.Append(title, subject^);
		h.Head(title);

		ListLink(forumID, link);
		h.TextLink("List", link); h.Nbsp;

		IF GetParentLink(forumID, entryID, link) THEN h.TextLink("Parent", link) END;
		h.Br;
		i := 0; WHILE (entryID # entries[i].id^) & (i < nof) DO INC(i) END;

		IF i > 0 THEN
			ShowLink(forumID, entries[i -1].id^, link);
			h.TextLink("Previous", link)
		END;

		IF i < nof - 1 THEN
			h.Nbsp;
			ShowLink(forumID, entries[i + 1].id^, link);
			h.TextLink("Next", link)
		END;

		h.Br;

		PostingToHTML(w, h, subject, author, email, datetime, ip, text);

		h.Br;

		firstReply := TRUE;
		FOR i := 0 TO nof - 1 DO
			IF Strings.StartsWith2(entryID, entries[i].id^) THEN
				IF (entryID = entries[i].id^) THEN
					thisIndent := entries[i].level;
				ELSE
					IF firstReply THEN w.String("<b>Replies</b>"); h.Br; firstReply := FALSE END;
					FOR j := 0 TO entries[i].level - thisIndent - 1 DO h.Nbsp; h.Nbsp END;
					ShowLink(forumID, entries[i].id^, link);
					h.TextLink(entries[i].subject^, link);
					w.String("<i> (");
					w.String(entries[i].author^);
					w.String( " @ ");
					w.String(entries[i].datetime^);
					w.String(")</i>");
					h.Br;
				END
			END
		END;
		h.Br;
		ReplyLink(forumID, entryID, link);
		h.TextLink("Write a new reply", link); h.Br;

	ELSE
		ListLink(forumID, link);
		h.TextLink("list", link); h.Nbsp;
		link := "entry not found";
		h.HTMLString(link);
	END;

	h.Tail;
	w.Ln; w.Update;
	chunker.Close;
END Show;

PROCEDURE QueryPost(forum : Forum; forumID, entryID : ARRAY OF CHAR; context: WebCGI.CGIContext);
VAR
	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;
	h : HTMLWriter;
	entry : XML.Element;
	link, s : ARRAY 256 OF CHAR;
	subject, author, email, datetime, ip, text : String;
BEGIN
	(* reply *)
	NEW(chunker, w, context.w, context.request.header, context.reply);
	context.reply.statuscode := WebHTTP.OK;
	context.reply.contenttype := "text/html; charset=UTF-8";
	WebHTTP.SendResponseHeader(context.reply, context.w);

	NEW(h, w);

	entry := forum.FindElement(entryID);
	IF (entry # NIL) & (entry # forum.forum) THEN
		ReadEntry(entry, subject, author, email, datetime, ip, text);
		s := "Reply to ";
		Strings.Append(s, subject^);
		h.Head(s);

		ListLink(forumID, link);
		h.TextLink("list", link); h.Nbsp;

		IF GetParentLink(forumID, entryID, link) THEN h.TextLink("parent", link); h.Br END;
		h.Br;

		PostingToHTML(w, h, subject, author, email, datetime, ip, text);

	ELSE
		h.Head("Create a new thread");
		w.String("Create a new thread"); h.Br;
	END;
	PublishPostLink(forumID, entryID, link);
	w.String('<form action="');w.String(link); w.String('"method="POST" accept-charset="UTF-8" >'); w.Ln;
	h.Br; w.String("<hr/>");  w.Ln;

	w.String('Subject : '); h.InputText("subject", subject); h.Br; w.Ln;
	w.String("Author : "); h.InputText("author", empty);  h.Br; w.Ln;
	w.String("Email : "); h.InputText("email", empty); w.String("<i>optional</i>"); h.Br; w.Ln;
	w.String("Text : "); h.InputArea("text", empty); h.Br; w.Ln;
	h.Submit("Post");

	w.String('</form>');

	h.Tail;
	w.Ln; w.Update;
	chunker.Close;
END QueryPost;

PROCEDURE QueryEditPost(forum : Forum; forumID, entryID : ARRAY OF CHAR; context: WebCGI.CGIContext);
VAR
	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;
	h : HTMLWriter;
	entry : XML.Element;
	link, s : ARRAY 256 OF CHAR;
	subject, author, email, datetime, ip, text : String;
BEGIN
	(* reply *)
	NEW(chunker, w, context.w, context.request.header, context.reply);
	context.reply.statuscode := WebHTTP.OK;
	context.reply.contenttype := "text/html; charset=UTF-8";
	WebHTTP.SendResponseHeader(context.reply, context.w);

	NEW(h, w);

	entry := forum.FindElement(entryID);
	IF (entry # NIL) & (entry # forum.forum) THEN
		ReadEntry(entry, subject, author, email, datetime, ip, text);
		s := "Edit ";
		Strings.Append(s, subject^);
		h.Head(s);

		ListLink(forumID, link);
		h.TextLink("list", link); h.Nbsp;

		IF GetParentLink(forumID, entryID, link) THEN h.TextLink("parent", link); h.Br END;
		h.Br;

		PostingToHTML(w, h, subject, author, email, datetime, ip, text);


		PublishPostLink(forumID, entryID, link);
		w.String('<form action="');w.String(link); w.String('"method="POST" accept-charset="UTF-8" >'); w.Ln;
		h.Br; w.String("<hr/>");  w.Ln;

		w.String("<b>Accreditiation:</b><br/>");
		w.String('Editor : '); h.InputText("editor", NIL); w.String('Authorization : '); h.InputText("password", NIL);
		h.Br;

		w.String('Subject : '); h.InputText("subject", subject); h.Br; w.Ln;
		w.String("Author : "); h.InputText("author", author);  h.Br; w.Ln;
		w.String("Email : "); h.InputText("email", email); w.String("<i>optional</i>"); h.Br; w.Ln;
		w.String("Text : "); h.InputArea("text", text); h.Br; w.Ln;
		h.Hide("ip", ip^);
		h.Hide("datetime", datetime^);
		h.Hide("replace", "true");
		h.Submit("Edit");

		w.String('</form>');

		h.Tail;
	END;
	w.Ln; w.Update;
	chunker.Close;
END QueryEditPost;

PROCEDURE QueryDeletePost(forum : Forum; forumID, entryID : ARRAY OF CHAR; context: WebCGI.CGIContext);
VAR
	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;
	h : HTMLWriter;
	entry : XML.Element;
	link, s : ARRAY 256 OF CHAR;
	subject, author, email, datetime, ip, text : String;
BEGIN
	(* reply *)
	NEW(chunker, w, context.w, context.request.header, context.reply);
	context.reply.statuscode := WebHTTP.OK;
	context.reply.contenttype := "text/html; charset=UTF-8";
	WebHTTP.SendResponseHeader(context.reply, context.w);

	NEW(h, w);

	entry := forum.FindElement(entryID);
	IF (entry # NIL) & (entry # forum.forum) THEN
		ReadEntry(entry, subject, author, email, datetime, ip, text);
		s := "Delete ";
		Strings.Append(s, subject^);
		h.Head(s);

		ListLink(forumID, link);
		h.TextLink("list", link); h.Nbsp;

		IF GetParentLink(forumID, entryID, link) THEN h.TextLink("parent", link); h.Br END;
		h.Br;

		PostingToHTML(w, h, subject, author, email, datetime, ip, text);

	ELSE
	END;
	DeletePostLink(forumID, entryID, link);
	w.String('<form action="');w.String(link); w.String('"method="POST" accept-charset="UTF-8" >'); w.Ln;
	h.Br; w.String("<hr/>");  w.Ln;

	w.String("<b>Accreditiation:</b><br/>");
	w.String('Editor : '); h.InputText("editor", NIL); w.String('Authorization : '); h.InputText("password", NIL);
	h.Submit("Delete");

	w.String('</form>');

	h.Tail;
	w.Ln; w.Update;
	chunker.Close;
END QueryDeletePost;

PROCEDURE PublishPost(forum : Forum; forumID, entryID : ARRAY OF CHAR; context: WebCGI.CGIContext);
VAR
	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;
	h : HTMLWriter;
	entry, parent : XML.Element;
	link, s, editor, password : ARRAY 256 OF CHAR;
	subject, author, email, datetime, ip, text : String;
	var: HTTPSupport.HTTPVariable;
	replace : BOOLEAN;
BEGIN
	(* reply *)
	NEW(chunker, w, context.w, context.request.header, context.reply);
	context.reply.statuscode := WebHTTP.OK;
	context.reply.contenttype := "text/html; charset=UTF-8";
	WebHTTP.SendResponseHeader(context.reply, context.w);

	NEW(h, w);

	var := context.request.GetVariableByName("replace");
	IF (var # NIL) & (var.value # "") THEN replace := var.value = "true"
	ELSE replace := FALSE
	END;

	IF replace THEN KernelLog.String("Replace entry") ELSE KernelLog.String("New Entry"); KernelLog.Ln;  END;

	var := context.request.GetVariableByName("subject");
	IF (var # NIL) & (var.value # "") THEN subject := Strings.NewString(var.value)
	ELSE subject := Strings.NewString("anonymous");
	END;

	var := context.request.GetVariableByName("author");
	IF (var # NIL) & (var.value # "") THEN author := Strings.NewString(var.value)
	ELSE author := Strings.NewString("anonymous");
	END;

	var := context.request.GetVariableByName("email");
	IF (var # NIL) & (var.value # "") THEN email := Strings.NewString(var.value)
	ELSE email:= Strings.NewString("");
	END;

	var := context.request.GetVariableByName("text");
	IF (var # NIL) & (var.value # "") THEN text := Strings.NewString(var.value)
	ELSE text := Strings.NewString("");
	END;

	IP.AdrToStr(context.request.header.fadr, s);
	ip := Strings.NewString(s);


	Strings.FormatDateTime("yyyy.mm.dd hh.nn.ss", Dates.Now(), s);
	datetime := Strings.NewString(s);

	IF ~replace THEN
		entry := MakeEntry(subject, author, email, datetime, ip, text);
		forum.AddEntry(entryID, entry);

		parent := forum.FindElement(entryID);
		IF parent # NIL THEN
			h.Head(subject^);
			ListLink(forumID, link); h.TextLink("list", link); h.Nbsp;
			ShowLink(forumID, entryID, link); h.TextLink("parent", link); h.Br;
		ELSE h.Head("New thread created");
			ListLink(forumID, link); h.TextLink("list", link); h.Nbsp;
		END;

	ELSE
		h.Head(subject^);
		var := context.request.GetVariableByName("editor");
		IF (var # NIL) THEN COPY(var.value, editor) END;

		var := context.request.GetVariableByName("password");
		IF (var # NIL) THEN COPY(var.value, password) END;

		IF (editor = forum.editor^) & (password = forum.password^) THEN
			ListLink(forumID, link); h.TextLink("list", link); h.Nbsp;
			entry := forum.FindElement(entryID);
			IF entry # NIL THEN
				forum.EditEntry(entry, subject, author, email, datetime, ip, text)
			END;
		ELSE
			w.String("<h1>Your accredition was not accepted.</h1>"); w.Ln;
		END
	END;

	PostingToHTML(w, h, subject, author, email, datetime, ip, text);
	h.Br;
	h.Tail;
	w.Ln; w.Update;
	chunker.Close;
END PublishPost;

PROCEDURE DeletePost(forum : Forum; forumID, entryID : ARRAY OF CHAR; context: WebCGI.CGIContext);
VAR
	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;
	h : HTMLWriter;
	link, editor, password : ARRAY 256 OF CHAR;
	var: HTTPSupport.HTTPVariable;
BEGIN
	(* reply *)
	NEW(chunker, w, context.w, context.request.header, context.reply);
	context.reply.statuscode := WebHTTP.OK;
	context.reply.contenttype := "text/html; charset=UTF-8";
	WebHTTP.SendResponseHeader(context.reply, context.w);

	NEW(h, w);

	h.Head("Deleting Post");
	var := context.request.GetVariableByName("editor");
	IF (var # NIL) THEN COPY(var.value, editor) END;

	var := context.request.GetVariableByName("password");
	IF (var # NIL) THEN COPY(var.value, password) END;

	IF (editor = forum.editor^) & (password = forum.password^) THEN
		ListLink(forumID, link); h.TextLink("list", link); h.Nbsp;
		forum.DeleteEntry(entryID);
		w.String("Entry deleted.");
	ELSE
		w.String("<h1>Your accredition was not accepted.</h1>"); w.Ln;
	END;
	h.Tail;
	w.Ln; w.Update;
	chunker.Close;
END DeletePost;

PROCEDURE Access*(context : WebCGI.CGIContext);
VAR
	r : HTTPSupport.HTTPRequest;
	var: HTTPSupport.HTTPVariable;

	action, forumID, entry : ARRAY 32 OF CHAR;
	forum : Forum;

	w : Streams.Writer;
	chunker : WebHTTP.ChunkedOutStream;
	defaultAction : BOOLEAN;
	milliTimer : Kernel.MilliTimer;
BEGIN
	Kernel.SetTimer(milliTimer, 0);
	r := context.request;
	defaultAction := TRUE;
	var := r.GetVariableByName("action");
	IF var # NIL THEN COPY(var.value, action); defaultAction := FALSE END;

	var := r.GetVariableByName("forum");
	IF var # NIL THEN COPY(var.value, forumID) END;

	var := r.GetVariableByName("entry");
	IF var # NIL THEN COPY(var.value, entry) END;

	forum := GetForum(forumID);

	IF forum = NIL THEN
		NEW(chunker, w, context.w, context.request.header, context.reply);
		context.reply.statuscode := WebHTTP.NotFound;
		WebHTTP.SendResponseHeader(context.reply, context.w);
		w.String("<html><head><title>Forum</title></head>");
		w.String("<body>");
		w.String("Forum not found"); w.Ln;
		w.String("</body></html>");
		w.Ln; w.Update;
		chunker.Close
	ELSE
		IF action = "Show" THEN Show(forum, forumID, entry, context);
		ELSIF defaultAction OR (action = "List") THEN List(forum, forumID, context);
		ELSIF action = "Reply" THEN QueryPost(forum, forumID, entry, context)
		ELSIF action = "Publish" THEN PublishPost(forum, forumID, entry, context)
		ELSIF action = "Edit" THEN QueryEditPost(forum, forumID, entry, context)
		ELSIF action = "Delete" THEN QueryDeletePost(forum, forumID, entry, context)
		ELSIF action = "PublishDelete" THEN DeletePost(forum, forumID, entry, context)
		ELSE
			NEW(chunker, w, context.w, context.request.header, context.reply);
			context.reply.statuscode := WebHTTP.NotFound;
			WebHTTP.SendResponseHeader(context.reply, context.w);
			w.String("<html><head><title>Forum</title></head>");
			w.String("<body>");
			w.String("Illegal forum request"); w.Ln;
			w.String("</body></html>");
			w.Ln; w.Update;
			chunker.Close
		END
	END;
	KernelLog.String("Forum request handled in "); KernelLog.Int(Kernel.Elapsed(milliTimer), 0); KernelLog.String("ms"); KernelLog.Ln;
END Access;

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

PROCEDURE AddForum(CONST id,fileName : ARRAY OF CHAR);
VAR new : ForumList;
	i : LONGINT;
BEGIN
	IF nofForum >= LEN(forumList) THEN
		NEW(new, LEN(forumList) * 2);
		FOR i := 0 TO nofForum - 1 DO new[i] := forumList[i] END;
		forumList := new
	END;
	COPY(id, forumList[nofForum].id);
	COPY(fileName, forumList[nofForum].fileName);
	INC(nofForum)
END AddForum;

PROCEDURE GetForumInternal(CONST id : ARRAY OF CHAR) : Forum;
VAR i : LONGINT; result : Forum;
BEGIN
	i := 0;
	WHILE (i < nofForum) & (result = NIL)  DO
		IF forumList[i].id = id THEN
			IF forumList[i].content = NIL THEN
				NEW(forumList[i].content);
				IF forumList[i].content.Load(forumList[i].fileName) THEN
					KernelLog.String(forumList[i].id); KernelLog.String(" loaded from "); KernelLog.String(forumList[i].fileName); KernelLog.Ln;
				ELSE
					KernelLog.String(forumList[i].id); KernelLog.String("FAILED loading  from "); KernelLog.String(forumList[i].fileName); KernelLog.Ln;
				END;
			END;
			result := forumList[i].content
		END;
		INC(i)
	END;
	RETURN result
END GetForumInternal;

PROCEDURE GetForum(CONST id : ARRAY OF CHAR) : Forum;
BEGIN {EXCLUSIVE}
	RETURN GetForumInternal(id)
END GetForum;

PROCEDURE LoadForumList;
VAR f : Files.File;
	r : Files.Reader;
	id, fileName : ARRAY 128 OF CHAR;
BEGIN {EXCLUSIVE}
	f := Files.Old(ForumConfigFile);
	IF f # NIL THEN
		Files.OpenReader(r, f, 0);
		WHILE r.res = 0 DO
			r.Token(id); r.SkipWhitespace;
			r.String(fileName);
			IF r.res = 0 THEN AddForum(id, fileName) END;
			r.SkipLn;
		END
	END;
END LoadForumList;

PROCEDURE StoreForumList;
VAR f : Files.File;
	w : Files.Writer;
	i : LONGINT;
BEGIN {EXCLUSIVE}
	f := Files.New(ForumConfigFile);
	Files.OpenWriter(w, f, 0);
	FOR i := 0 TO nofForum - 1 DO
		w.String(forumList[i].id); w.String(' "'); w.String(forumList[i].fileName); w.String('"'); w.Ln
	END;
	w.Update;
	Files.Register(f)
END StoreForumList;

PROCEDURE CreateForum*(context : Commands.Context);
VAR
	id, fileName, title, user, password : ARRAY 128 OF CHAR;
	forum : Forum;
BEGIN
	context.arg.Token(id); context.arg.SkipWhitespace(); context.arg.String(fileName); context.arg.SkipWhitespace(); context.arg.String(title);
	context.arg.SkipWhitespace(); context.arg.String(user); context.arg.SkipWhitespace(); context.arg.String(password);
	BEGIN{EXCLUSIVE}
		forum := GetForumInternal(id);
		IF forum # NIL THEN
			context.error.String("Forum already exists"); context.error.Ln; RETURN;
		ELSE
			AddForum(id, fileName);
			forum := GetForumInternal(id);
			forum.SetTitle(title);
			forum.SetEditor(user, password);
			forum.Store(fileName);
		END
	END;
	StoreForumList;
END CreateForum;

BEGIN
	empty := Strings.NewString("");
	NEW(forumList, 128); nofForum := 0;
	LoadForumList;
	InitURILiterals;
END TFWebForum.

SystemTools.Free TFWebForum ~
TFWebForum.CreateForum RFWde ForumRFWde.XML "Raily for Windows (Deutsch)" rfwuser rfwpassword ~
TFWebForum.CreateForum RFWfr ForumRFWfr.XML "Raily for Windows (Francais)" rfwuser rfwpassword ~
TFWebForum.CreateForum RFWen ForumRFWen.XML "Raily for Windows (English)" rfwuser rfwpassword ~
TFWebForum.CreateForum PCFrey ForumPCFrey.XML "PC - Forum" rfwuser rfwpassword ~

TFWebForum.CreateForum BluebottleFeatures ForumBluebottle.XML "Forum Bluebottlerum" user password ~


WebHTTPServerTools.Start ~
WebCGI.Install ~
WebCGI.RegisterCGI Forum TFWebForum.Access~
WebCGI.ListCGI ~


