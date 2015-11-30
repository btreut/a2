MODULE PHWebSyndication; (** AUTHOR "Patrick Hunziker"; PURPOSE "Web Syndication Client for RSS and Atom formats"; *)
(* 
RSS and Atom are XML Formats.

RSS specification: 
	http://www.rssboard.org/rss-specification

Atom specification: 
	http://tools.ietf.org/html/rfc4287
	http://www.atomenabled.org/developers/syndication/  
	
Comparison of RSS and Atom:
http://www.intertwingly.net/wiki/pie/Rss20AndAtom10Compared

a few million feeds referenced here:
*)

IMPORT XML, XMLParser, XMLScanner, Commands, Strings, Streams, Kernel, Modules, TFClasses, SearchTools, Files, KernelLog, NewHTTPClient;

TYPE Feed*= OBJECT
	VAR
		url*: Strings.String;
		status*: SET;		
	END Feed;


TYPE Aggregator*= OBJECT
	VAR 
		alive, wait: BOOLEAN;
		feeds: TFClasses.List;
		contents: TFClasses.List; 
		timer:Kernel.Timer;
		handleContent: ContentHandler;
		next*: Aggregator;
	
	PROCEDURE &Init*(handleContent: ContentHandler);
	BEGIN
		SELF.handleContent:=handleContent;
		KernelLog.String("Feed Aggregator started"); KernelLog.Ln;
		NEW(feeds);
		NEW(contents);
		NEW(timer);
		alive:=TRUE; wait:=FALSE;
		next:=aggregators; aggregators:=SELF;
	END Init;
	
	PROCEDURE Stop*;
	BEGIN {EXCLUSIVE}
		alive:=FALSE
	END Stop;
	
	PROCEDURE Sleep(ms:LONGINT); (*! this is a still a hack  *)
	BEGIN
		wait:=TRUE;
		timer.Sleep(4000);
		BEGIN{EXCLUSIVE}
			wait:=FALSE
		END;
	END Sleep;
	
	PROCEDURE AddFeed*(CONST url: ARRAY OF CHAR); (* add a feed address to the list *)
	VAR feed: Feed;
	BEGIN
		NEW(feed); feed.url:=Strings.NewString(url);
		feeds.Add(feed);
	END AddFeed;
	
	PROCEDURE AddContent(CONST url: ARRAY OF CHAR); (* add a feed's content to the content list *)
	VAR content: XML.Document;
	BEGIN
		content:=GetFeed(url);
		IF content#NIL THEN contents.Add(content) END;
	END AddContent;
	
	PROCEDURE HandleContents;
	VAR feed, content: ANY; i, n:LONGINT;
	BEGIN
		NEW(contents); (*! inefficient; preserve some content *)
		
		IF feeds#NIL THEN
			n:=feeds.GetCount();
			FOR i:=0 TO n-1 DO
				feed:=feeds.GetItem(i);
				IF feed#NIL THEN AddContent(feed(Feed).url^) END;
			END;
		ELSE KernelLog.String("Feeds=NIL"); KernelLog.Ln;
		END;
		
		IF contents#NIL THEN
			n:=contents.GetCount();
			FOR i:=0 TO n-1 DO
				content:=contents.GetItem(i);
				IF (content#NIL)&(content IS XML.Document) & (handleContent#NIL)THEN 
					handleContent(content(XML.Document));
				END;
			END;
		ELSE KernelLog.String("Contents=NIL"); KernelLog.Ln;
		END;
	END HandleContents;
		
	BEGIN {ACTIVE}
		LOOP
			BEGIN{EXCLUSIVE} AWAIT((~wait)&(alive)) END;
			IF ~alive THEN EXIT END;
			HandleContents; 
			Sleep(4000);
		END;
	END Aggregator;

TYPE LinkHandler=PROCEDURE{DELEGATE}(CONST url: ARRAY OF CHAR);
TYPE ContentHandler=PROCEDURE{DELEGATE}(content: XML.Document);

VAR aggregators: Aggregator;

PROCEDURE GetFeed*(CONST url: ARRAY OF CHAR): XML.Document; (** accepts http://... or file://... *) 
	CONST verbose=FALSE;
	VAR parser: XMLParser.Parser;
		scanner: XMLScanner.Scanner;
		protocol, filename : Strings.String;
		file : Files.File;
		fileReader : Files.Reader;
		r: Streams.Reader;
		h : NewHTTPClient.HTTPConnection;
		res,pos:LONGINT;
		feed: XML.Document;
	BEGIN
		pos := Strings.Pos("://", url);
		IF pos = -1 THEN
			IF verbose THEN KernelLog.String("Unknown Protocol: "); KernelLog.String(url); KernelLog.Ln(); END;
			RETURN NIL;
		END;
		protocol := Strings.Substring(0, pos, url);
		IF (pos + 3) >= Strings.Length(url) THEN
			IF verbose THEN KernelLog.String("Bad URL: "); KernelLog.String(url); KernelLog.Ln(); END;
			RETURN NIL;
		END;
		filename := Strings.Substring2(pos+3, url);
		IF protocol^ = "http" THEN	
			NEW(h);
			h.Get(url, TRUE, r, res);
		ELSIF protocol^ = "file" THEN
			file := Files.Old(filename^);
			IF file = NIL THEN
				IF verbose THEN KernelLog.String("file not found: "); KernelLog.String(url); KernelLog.Ln(); END;
				RETURN NIL
			END;
			Files.OpenReader(fileReader, file, 0);
			r:=fileReader
		ELSE
			IF verbose THEN KernelLog.String("Unknown Protocol: "); KernelLog.String(protocol^); KernelLog.Ln(); END;
			RETURN NIL;
		END;
		NEW(scanner, r);
		NEW(parser, scanner);
		feed:= parser.Parse();
		(*IF parser.res=XMLParser.Ok THEN RETURN feed ELSE RETURN NIL END;*)
		RETURN feed
	END GetFeed;
	
	PROCEDURE LogFeed(CONST url: ARRAY OF CHAR);
	VAR xml: XML.Document; w:Streams.Writer;
	BEGIN
		xml:=GetFeed(url);
		Streams.OpenWriter(w, KernelLog.Send);
		xml.Write(w,NIL,0); w.Update;
	END LogFeed;
	
	PROCEDURE LogContent(content: XML.Document);
	VAR  w:Streams.Writer;
	BEGIN
		Streams.OpenWriter(w, KernelLog.Send);
		content.Write(w,NIL,0); 
		w.Update;
	END LogContent;
	
	PROCEDURE GetLinks*(url: ARRAY OF CHAR; handle:LinkHandler); (** accepts http://... or file://... *) 
	CONST verbose=TRUE;
	VAR 
		protocol, filename : Strings.String;
		file : Files.File;
		fileReader : Files.Reader;
		r: Streams.Reader;
		h : NewHTTPClient.HTTPConnection;
		res,pos:LONGINT;
	BEGIN
		pos := Strings.Pos("://", url);
		IF pos = -1 THEN
			IF verbose THEN KernelLog.String("Unknown Protocol: "); KernelLog.String(url); KernelLog.Ln(); END;
			RETURN;
		END;
		protocol := Strings.Substring(0, pos, url);
		IF (pos + 3) >= Strings.Length(url) THEN
			IF verbose THEN KernelLog.String("Bad URL: "); KernelLog.String(url); KernelLog.Ln(); END;
			RETURN;
		END;
		filename := Strings.Substring2(pos+3, url);
		IF protocol^ = "http" THEN	
			NEW(h);
			h.Get(url, TRUE, r, res);
		ELSIF protocol^ = "file" THEN
			file := Files.Old(filename^);
			IF file = NIL THEN
				IF verbose THEN KernelLog.String("file not found: "); KernelLog.String(url); KernelLog.Ln(); END;
				RETURN
			END;
			Files.OpenReader(fileReader, file, 0);
			r:=fileReader
		ELSE
			IF verbose THEN KernelLog.String("Unknown Protocol: "); KernelLog.String(protocol^); KernelLog.Ln(); END;
			RETURN
		END;
		FindLinks(r, url, handle);
	END GetLinks;
	
	(*<link rel="alternate" type="application/atom+xml" href="index.atom"> ; Implementation limitation: only small caps keywords (also capitals are allowed in specification) *)
	PROCEDURE FindLinks(r:Streams.Reader; CONST base:ARRAY OF CHAR; handle:LinkHandler);
	VAR sw: Streams.StringWriter; sr: Streams.StringReader; 
		s,href: ARRAY 1024 OF CHAR; 
		i,pos,len:LONGINT;
	BEGIN
		SearchTools.SearchPatternRaw(r, NIL, "<link");
		WHILE r.res=Streams.Ok DO
			NEW(sw, 1024); 
			SearchTools.SearchPatternRaw(r, sw, ">");
			IF r.res=Streams.Ok THEN
				NEW(sr, 1024);
				sw.GetRaw(s,len);
				pos:=Strings.Pos("application/atom+xml",s);
				IF pos>=0 THEN 
					pos:=Strings.Pos("href=",s);
					IF pos>=0 THEN 
						WHILE s[pos]#'"' DO INC(pos); END; INC(pos);
						i:=0;
						WHILE s[pos]#'"' DO href[i]:=s[pos]; INC(i); INC(pos); END; href[i+1]:=0X;
						KernelLog.String("Atom Link href="); KernelLog.String(href); KernelLog.Ln;
						IF Strings.Pos("http://", href)<0 THEN 
							COPY(base,s); Strings.AppendChar(s,"/"); Strings.Append(s,href); COPY(s, href);
						END;
						IF handle#NIL THEN handle(href) END;
					ELSE KernelLog.String("href not found"); KernelLog.Ln;
					END;
				END;
					
				pos:=Strings.Pos("application/rss+xml",s);
				IF pos>=0 THEN 
					pos:=Strings.Pos("href=",s);
					IF pos>=0 THEN 
						WHILE s[pos]#'"' DO INC(pos); END; INC(pos);
						i:=0;
						WHILE s[pos]#'"' DO href[i]:=s[pos]; INC(i); INC(pos); END; href[i+1]:=0X;
						KernelLog.String("RSS Link href="); KernelLog.String(href); KernelLog.Ln;
						IF Strings.Pos("http://", href)<0 THEN 
							COPY(base,s); Strings.AppendChar(s,"/"); Strings.Append(s,href); COPY(s, href);
						END;
						IF handle#NIL THEN handle(href) END;
					ELSE KernelLog.String("href not found"); KernelLog.Ln;
					END;
				END;
			END;
			SearchTools.SearchPatternRaw(r, NIL, "<link");
		END;	
	END FindLinks;

PROCEDURE TestURL*(context:Commands.Context);
VAR 
	rss: XML.Document;
	url: ARRAY 1024 OF CHAR;
	h : NewHTTPClient.HTTPConnection;
	ok: BOOLEAN;
	w:Streams.Writer;
BEGIN
	ok:=context.arg.GetString(url);
	rss:=GetFeed(url);
	Streams.OpenWriter(w, KernelLog.Send);
	rss.Write(w, NIL, 0); w.Update;
	IF h#NIL THEN h.Close END;
END TestURL;

PROCEDURE TestLinks*(context:Commands.Context);
VAR 
	url: ARRAY 1024 OF CHAR;
	ok: BOOLEAN;
BEGIN
	ok:=context.arg.GetString(url);
	GetLinks(url,LogFeed);
END TestLinks;

PROCEDURE LoadPage*(context:Commands.Context);
VAR h : NewHTTPClient.HTTPConnection;
	r : Streams.Reader;
	res : LONGINT;
	url: ARRAY 1024 OF CHAR;
	ok:BOOLEAN;
BEGIN
	ok:=context.arg.GetString(url);
	NEW(h);
	h.Get(url, TRUE, r, res);
	KernelLog.String("res= "); KernelLog.Int(res, 0); KernelLog.Ln;
	WHILE r.res = 0 DO KernelLog.Char(r.Get()) END;
	KernelLog.String("---------------------------------"); KernelLog.Ln;
	h.Close;
END LoadPage;

PROCEDURE TestAggregator*;
VAR A: Aggregator;
BEGIN
	NEW(A, LogContent);
	A.AddFeed("http://rss.feedsportal.com/c/32209/f/424473/index.rss");
END TestAggregator;

PROCEDURE FreeModule; (* this does not work because of timeout issues *)
VAR a: Aggregator;
BEGIN
	a:=aggregators;
	WHILE a#NIL DO 
		a.Stop; aggregators:=a.next; a.next:=NIL; 
		a:=aggregators;
	END;
END FreeModule;

BEGIN
	Modules.InstallTermHandler(FreeModule)
END PHWebSyndication.

SystemTools.FreeDownTo PHWebSyndication ~

PHWebSyndication.TestAggregator ~

PHWebSyndication.TestURL file://example.rss ~
PHWebSyndication.TestURL http://haaretz.feedsportal.com/c/34191/f/620528/index.rss

PHWebSyndication.TestURL http://rss.feedsportal.com/c/32209/f/424473/index.rss ~
PHWebSyndication.TestLinks http://www.nzz.ch~
PHWebSyndication.TestLinks http://www.haaretz.com~

PHWebSyndication.TestLinks http://www.ietf.org/rfc/rfc4287 ~

PHWebSyndication.LoadPage http://www.haaretz.com/cmlink/haaretz-com-headlines-rss-1.263335?localLinksEnabled=false ~
PHWebSyndication.LoadPage http://haaretz.feedsportal.com/c/34191/f/620528/index.rss ~
=========================RSS syndication format==============================
RSS syntax: 
At the top level, a RSS document is a <rss> element, with a mandatory attribute called version, that specifies the version of RSS that the document conforms to. If it conforms to this specification, the version attribute must be 2.0.
Subordinate to the <rss> element is a single <channel> element, which contains information about the channel (metadata) and its contents.

<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<?xml-stylesheet  type='text/xsl' href='http://rss.feedsportal.com/xsl/de/rss.xsl'?>
<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:taxo="http://purl.org/rss/1.0/modules/taxonomy/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" version="2.0">
	<channel>
		<title>Some title</title>
		<link>http://www.pctipp.ch/</link>
		<description>Sicherheitsmeldungen</description>
		...
		
		<item>
			<title>Kein Virenschutz für iOS: Kaspersky warnt</title>
			<link>http://rss.feedsportal.com/c/32209/f/424473/s/1fa0bed6/l/0L0Spctipp0Bch0C0Imisc0Crss0Cgo0Bcfm0Dpk0F622910Gfk0F9/story01.htm</link>
			<description>Apple gestattet es den Virenjägern von Kaspersky nicht, eine Security-App für iOS herauszubringen. Laut Kaspersky schaufelt sich Apple damit sein eigenes Grab.&lt;img width='1' height='1' src='http://rss.feedsportal.com/c/32209/f/424473/s/1fa0bed6/mf.gif' border='0'/&gt;&lt;div class='mf-viral'&gt;&lt;table border='0'&gt;&lt;tr&gt;&lt;td valign='middle'&gt;&lt;a href="http://share.feedsportal.com/viral/sendEmail.cfm?lang=de&amp;title=Kein+Virenschutz+f%C3%BCr+iOS%3A+Kaspersky+warnt&amp;link=http%3A%2F%2Fwww.pctipp.ch%2F_misc%2Frss%2Fgo.cfm%3Fpk%3D62291%26fk%3D9" target="_blank"&gt;&lt;img src="http://rss.feedsportal.com/images/emailthis2.gif" border="0" /&gt;&lt;/a&gt;&lt;/td&gt;&lt;td valign='middle'&gt;&lt;a href="http://res.feedsportal.com/viral/bookmark_de.cfm?title=Kein+Virenschutz+f%C3%BCr+iOS%3A+Kaspersky+warnt&amp;link=http%3A%2F%2Fwww.pctipp.ch%2F_misc%2Frss%2Fgo.cfm%3Fpk%3D62291%26fk%3D9" target="_blank"&gt;&lt;img src="http://rss.feedsportal.com/images/bookmark.gif" border="0" /&gt;&lt;/a&gt;&lt;/td&gt;&lt;/tr&gt;&lt;/table&gt;&lt;/div&gt;&lt;br/&gt;&lt;br/&gt;&lt;a href="http://da.feedsportal.com/r/134204562740/u/359/f/424473/c/32209/s/1fa0bed6/a2.htm"&gt;&lt;img src="http://da.feedsportal.com/r/134204562740/u/359/f/424473/c/32209/s/1fa0bed6/a2.img" border="0"/&gt;&lt;/a&gt;&lt;img width="1" height="1" src="http://pi.feedsportal.com/r/134204562740/u/359/f/424473/c/32209/s/1fa0bed6/a2t.img" border="0"/&gt;</description>
			...
		</item>
		
		<item>
			...
		</item>
		
	</channel>
</rss>


- required channel elements:
	title			The name of the channel. It's how people refer to your service. If you have an HTML website that contains the same information as your RSS file, the title of your channel should be the same as the title of your website.	GoUpstate.com News Headlines
	link				The URL to the HTML website corresponding to the channel.	http://www.goupstate.com/
	description		Phrase or sentence describing the channel.	The latest news from GoUpstate.com, a Spartanburg Herald-Journal Web site.
- optional channel elements: 
	language		The language the channel is written in. This allows aggregators to group all Italian language sites, for example, on a single page. A list of allowable values for this element, as provided by Netscape, is here. You may also use values defined by the W3C.	en-us
	copyright		Copyright notice for content in the channel.	Copyright 2002, Spartanburg Herald-Journal
	managingEditor	Email address for person responsible for editorial content.	geo@herald.com (George Matesky)
	webMaster		Email address for person responsible for technical issues relating to channel.	betty@herald.com (Betty Guernsey)
	pubDate		The publication date for the content in the channel. For example, the New York Times publishes on a daily basis, the publication date flips once every 24 hours. That's when the pubDate of the channel changes. All date-times in RSS conform to the Date and Time Specification of RFC 822, with the exception that the year may be expressed with two characters or four characters (four preferred).	Sat, 07 Sep 2002 00:00:01 GMT
	lastBuildDate	The last time the content of the channel changed.	Sat, 07 Sep 2002 09:42:31 GMT
	category		Specify one or more categories that the channel belongs to. Follows the same rules as the <item>-level category element. More info.	<category>Newspapers</category>
	generator		A string indicating the program used to generate the channel.	MightyInHouse Content System v2.3
	docs			A URL that points to the documentation for the format used in the RSS file. It's probably a pointer to this page. It's for people who might stumble across an RSS file on a Web server 25 years from now and wonder what it is.	http://www.rssboard.org/rss-specification
	cloud			Allows processes to register with a cloud to be notified of updates to the channel, implementing a lightweight publish-subscribe protocol for RSS feeds. More info here.	<cloud domain="rpc.sys.com" port="80" path="/RPC2" registerProcedure="pingMe" protocol="soap"/>
	ttl				ttl stands for time to live. It's a number of minutes that indicates how long a channel can be cached before refreshing from the source. More info here.	<ttl>60</ttl>
	image			Specifies a GIF, JPEG or PNG image that can be displayed with the channel. More info here.	
	rating			The PICS rating for the channel.	
	textInput		Specifies a text input box that can be displayed with the channel. More info here.	
	skipHours		A hint for aggregators telling them which hours they can skip. This element contains up to 24 <hour> sub-elements whose value is a number between 0 and 23, representing a time in GMT, when aggregators, if they support the feature, may not read the channel on hours listed in the <skipHours> element. The hour beginning at midnight is hour zero.	
	skipDays		A hint for aggregators telling them which days they can skip. This element contains up to seven <day> sub-elements whose value is Monday, Tuesday, Wednesday, Thursday, Friday, Saturday or Sunday. Aggregators may not read the channel during days listed in the <skipDays> element.	

required elements in an item:
	All elements of an item are optional, however at least one of title or description must be present.

optional item elements:
	[Element]	[Description]					[Example]
	title		The title of the item.			Venice Film Festival Tries to Quit Sinking
	link			The URL of the item.			http://nytimes.com/2004/12/07FEST.html
	description	The item synopsis.				<description>Some of the most heated chatter at the Venice Film Festival this week was about the way that the arrival of the stars at the Palazzo del Cinema was being staged.</description>
	author		Email address of the author of the item. 
	category	Includes the item in one or more categories. 
	comments	URL of a page for comments relating to the item.	
	enclosure	Describes a media object that is attached to the item.	
	guid		A string that uniquely identifies the item. 
	pubDate	Indicates when the item was published. 
	source		The RSS channel that the item came from. 



HTML link example of of RSS feeds: 
<link rel="alternate" type="application/rss+xml"  title="RSS" href="http://www.example.net/feed.rss" />

RSS document example: 

<?xml version="1.0" encoding="UTF-8" standalone="no"?>
	<?xml-stylesheet  type='text/xsl' href='http://rss.feedsportal.com/xsl/de/rss.xsl'?>
	<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:taxo="http://purl.org/rss/1.0/modules/taxonomy/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" version="2.0">
		<channel>
			<title>PCtipp-Sicherheitsmeldungen (5)</title>
			<link>http://www.pctipp.ch/</link>
			<description>Sicherheitsmeldungen</description>
			<language>de-de</language>
			<copyright>Â© 1996 - 2007 by IDG Communications AG - Alle Rechte vorbehalten</copyright>
			<pubDate>Wed, 23 May 2012 12:05:53 GMT</pubDate>
			<lastBuildDate>Wed, 23 May 2012 12:05:53 GMT</lastBuildDate>
			<ttl>30</ttl>
			<image>
				<title>PCtipp-Sicherheitsmeldungen (5)</title>
				<url>http://www.pctipp.ch/img/pctipp_logo.gif</url>
				<link>http://www.pctipp.ch/</link>
			</image>
			<item>
				<title>Kein Virenschutz fÃ¼r iOS: Kaspersky warnt</title>
				<link>http://rss.feedsportal.com/c/32209/f/424473/s/1fa0bed6/l/0L0Spctipp0Bch0C0Imisc0Crss0Cgo0Bcfm0Dpk0F622910Gfk0F9/story01.htm</link>
				<description>Apple gestattet es den VirenjÃ¤gern von Kaspersky nicht, eine Security-App fÃ¼r iOS herauszubringen. Laut Kaspersky schaufelt sich Apple damit sein eigenes Grab.&lt;img width='1' height='1' src='http://rss.feedsportal.com/c/32209/f/424473/s/1fa0bed6/mf.gif' border='0'/&gt;&lt;div class='mf-viral'&gt;&lt;table border='0'&gt;&lt;tr&gt;&lt;td valign='middle'&gt;&lt;a href="http://share.feedsportal.com/viral/sendEmail.cfm?lang=de&amp;title=Kein+Virenschutz+f%C3%BCr+iOS%3A+Kaspersky+warnt&amp;link=http%3A%2F%2Fwww.pctipp.ch%2F_misc%2Frss%2Fgo.cfm%3Fpk%3D62291%26fk%3D9" target="_blank"&gt;&lt;img src="http://rss.feedsportal.com/images/emailthis2.gif" border="0" /&gt;&lt;/a&gt;&lt;/td&gt;&lt;td valign='middle'&gt;&lt;a href="http://res.feedsportal.com/viral/bookmark_de.cfm?title=Kein+Virenschutz+f%C3%BCr+iOS%3A+Kaspersky+warnt&amp;link=http%3A%2F%2Fwww.pctipp.ch%2F_misc%2Frss%2Fgo.cfm%3Fpk%3D62291%26fk%3D9" target="_blank"&gt;&lt;img src="http://rss.feedsportal.com/images/bookmark.gif" border="0" /&gt;&lt;/a&gt;&lt;/td&gt;&lt;/tr&gt;&lt;/table&gt;&lt;/div&gt;&lt;br/&gt;&lt;br/&gt;&lt;a href="http://da.feedsportal.com/r/134204562740/u/359/f/424473/c/32209/s/1fa0bed6/a2.htm"&gt;&lt;img src="http://da.feedsportal.com/r/134204562740/u/359/f/424473/c/32209/s/1fa0bed6/a2.img" border="0"/&gt;&lt;/a&gt;&lt;img width="1" height="1" src="http://pi.feedsportal.com/r/134204562740/u/359/f/424473/c/32209/s/1fa0bed6/a2t.img" border="0"/&gt;</description>
				<pubDate>Wed, 23 May 2012 11:41:00 GMT</pubDate>
				<guid isPermaLink="false">62291</guid>
			</item>
			<item>
				<title>Avira-Update lÃ¶st Fehlalarme aus</title>
				<link>http://rss.feedsportal.com/c/32209/f/424473/s/1f61320b/l/0L0Spctipp0Bch0C0Imisc0Crss0Cgo0Bcfm0Dpk0F621720Gfk0F9/story01.htm</link>
				<description>Das letzte automatische Update fÃ¼r drei Avira-Programme blockierte einzelne Anwendungen oder gar Windows selbst. Mittlerweile hat Avira das Problem behoben.&lt;img width='1' height='1' src='http://rss.feedsportal.com/c/32209/f/424473/s/1f61320b/mf.gif' border='0'/&gt;&lt;div class='mf-viral'&gt;&lt;table border='0'&gt;&lt;tr&gt;&lt;td valign='middle'&gt;&lt;a href="http://share.feedsportal.com/viral/sendEmail.cfm?lang=de&amp;title=Avira-Update+l%C3%B6st+Fehlalarme+aus&amp;link=http%3A%2F%2Fwww.pctipp.ch%2F_misc%2Frss%2Fgo.cfm%3Fpk%3D62172%26fk%3D9" target="_blank"&gt;&lt;img src="http://rss.feedsportal.com/images/emailthis2.gif" border="0" /&gt;&lt;/a&gt;&lt;/td&gt;&lt;td valign='middle'&gt;&lt;a href="http://res.feedsportal.com/viral/bookmark_de.cfm?title=Avira-Update+l%C3%B6st+Fehlalarme+aus&amp;link=http%3A%2F%2Fwww.pctipp.ch%2F_misc%2Frss%2Fgo.cfm%3Fpk%3D62172%26fk%3D9" target="_blank"&gt;&lt;img src="http://rss.feedsportal.com/images/bookmark.gif" border="0" /&gt;&lt;/a&gt;&lt;/td&gt;&lt;/tr&gt;&lt;/table&gt;&lt;/div&gt;&lt;br/&gt;&lt;br/&gt;&lt;a href="http://da.feedsportal.com/r/134204254991/u/359/f/424473/c/32209/s/1f61320b/a2.htm"&gt;&lt;img src="http://da.feedsportal.com/r/134204254991/u/359/f/424473/c/32209/s/1f61320b/a2.img" border="0"/&gt;&lt;/a&gt;&lt;img width="1" height="1" src="http://pi.feedsportal.com/r/134204254991/u/359/f/424473/c/32209/s/1f61320b/a2t.img" border="0"/&gt;</description>
				<pubDate>Wed, 16 May 2012 07:30:00 GMT</pubDate>
				<guid isPermaLink="false">62172</guid>
			</item>
		</channel>
	</rss>
	=======================Atom syndication format ============================
	
Atom Syndication format specification:
	
A Feed consists of some metadata, followed by any number of entries.

-Required feed elements
-Element 	Description Example
id 	Identifies the feed using a universally unique and permanent URI. If you have a long-term, renewable lease on your Internet domain name, then you can feel free to use your website's address.
		<id>http://example.com/</id>

title 	Contains a human readable title for the feed. Often the same as the title of the associated website. This value should not be blank.
		<title>Example, Inc.</title>

updated 	Indicates the last time the feed was modified in a significant way.
		<updated>2003-12-13T18:30:02Z</updated>

Recommended feed elements
- Atom makes a number of additional requirements and recommendations for feed elements that you should to be aware of. They are as follows:
- Element 	Description
author 	Names one author of the feed. A feed may have multiple author elements. A feed must contain at least one author element unless all of the entry elements contain at least one author element. More info here.
		<author>
		  <name>John Doe</name>
		  <email>JohnDoe@example.com</email>
		  <uri>http://example.com/~johndoe</uri>
		</author>

link 	Identifies a related Web page. The type of relation is defined by the rel attribute. A feed is limited to one alternate per type and hreflang. A feed should contain a link back to the feed itself. More info here.
	<link rel="self" href="/feed" />

Optional feed elements

Element 	Description
category 	Specifies a category that the feed belongs to. A feed may have multiple category elements. More info here.
		<category term="sports"/>

contributor 	Names one contributor to the feed. An feed may have multiple contributor elements. More info here.
		<contributor>
		  <name>Jane Doe</name>
		</contributor>

generator 	Identifies the software used to generate the feed, for debugging and other purposes. Both the uri and version attributes are optional.
		<generator uri="/myblog.php" version="1.0">
		  Example Toolkit
		</generator>

icon 	Identifies a small image which provides iconic visual identification for the feed. Icons should be square.
		<icon>/icon.jpg</icon>

logo 	Identifies a larger image which provides visual identification for the feed. Images should be twice as wide as they are tall.
		<logo>/logo.jpg</logo>

rights 	Conveys information about rights, e.g. copyrights, held in and over the feed. More info here.
		<rights> © 2005 John Doe </rights>

subtitle 	Contains a human-readable description or subtitle for the feed. More info here.
		<subtitle>all your examples are belong to us</subtitle>


	
	Example: 
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <author>
    <name>Autor des Weblogs</name>
  </author>
  <title>Titel des Weblogs</title>
  <id>urn:uuid:60a76c80-d399-11d9-b93C-0003939e0af6</id>
  <updated>2003-12-14T10:20:09Z</updated>
 
  <entry>
    <title>Titel des Weblog-Eintrags</title>
    <link href="http://example.org/2003/12/13/atom-beispiel"/>
    <id>urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a</id>
    <updated>2003-12-13T18:30:02Z</updated>
    <summary>Zusammenfassung des Weblog-Eintrags</summary>
    <content>Volltext des Weblog-Eintrags</content>
  </entry>
</feed>

Unterschiedliche Inhaltstypen

Die hauptsächliche Besonderheit von Atom gegenüber RSS ist die Möglichkeit, dass bei inhaltstragenden Elementen ausdrücklich angegeben werden kann, in welchem Format die Inhalte kodiert sind. In RSS 2.0 beispielsweise kann im description-Element reiner Text oder maskiertes HTML stehen, ohne dass ein verarbeitendes Programm weiß, worum es sich gerade handelt. Atom fordert eine Eindeutigkeit, indem inhaltstragende Elemente ein type-Attribut bekommen. Neben reinem Text und maskiertem HTML ist es zudem möglich, direkt XHTML-Markup mit Namensraum-Angabe einzubetten. Sinnvoll ist XHTML aber vor allem im content-Element.

Beispiel für reinen Text im title-Element:

<title type="text">Beispieleintrag</title>

Das type-Attribut kann in diesem Fall auch weggelassen werden, da text der Standardwert des Attributs ist.

Beispiel für HTML im summary-Element:

<summary type="html">Beispielzusammenfassung mit
 &lt;strong&gt;wichtigem Text&lt;/strong&gt;</summary>

Die HTML-eigenen Zeichen <, > und & werden mit den Entity-Referenzen &lt;, &gt; und &amp; umschrieben. Alternativ kann der Inhalt in einem CDATA-Abschnitt untergebracht werden:

<summary type="html"><![CDATA[ Beispielzusammenfassung mit
 <strong>wichtigem Text</strong> ]]></summary>

Beispiel für XHTML im content-Element:

<content type="xhtml" xml:base="http://example.org/">
  <div xmlns="http://www.w3.org/1999/xhtml">
    <p>Beispielabsatz mit <strong>wichtigem Text</strong> und einem
    <a href="beispiel">relativen Hyperlink</a>.</p>
  </div>
</content>

Das content-Element bekommt ein div-Element aus dem XHTML-Namensraum als Kind. Darin können weitere XHTML-Elemente direkt notiert werden.

===========================Atom autodiscovery========================
An Atom autodiscovery element is a link element, as defined in
   section 12.3 of HTML 4 [W3C.REC-html401-19991224].  As with other
   types of link elements, an autodiscovery element MAY appear within
   the <head> element of an HTML or XHTML document, but it MUST NOT
   appear within the <body>.
   (in HTML4.0, lower-,upper-, or mixed case is allowed, in XHTML~XML, only lowercase keywords are allowed)

example:
<link rel="alternate" type="application/atom+xml" href="index.atom">

Required attributes

4.1 rel attribute
   The rel attribute MUST be present in an Atom autodiscovery element.
   As defined in section 6.12 of HTML 4 [W3C.REC-html401-19991224], the
   value of the rel attribute is a space-separated list of keywords.
   The list of keywords MUST include the keyword "alternate" in
   uppercase, lowercase, or mixed case.

4.2 type attribute
   The type attribute MUST be present in an Atom autodiscovery element.
   As defined in section 12.3 of HTML 4 [W3C.REC-html401-19991224], the
   value of the type attribute of any link element MUST be a registered
   Internet media type [RFC2045].  The media type for Atom is
   "application/atom+xml" [I-D.ietf-atompub-format], so in an Atom
   autodiscovery element the value of the type attribute MUST contain
   the string "application/atom+xml" in uppercase, lowercase, or mixed
   case.

4.3 href attribute
   The href attribute MUST be present in an Atom autodiscovery element,
   and its value MUST be the URI [RFC3986] of an Atom feed.  The value
   MAY be a relative URI, and if so, clients MUST resolve it to a full
   URI (section 5 of [RFC3986]) using the document's base URI (section
   12.4 of HTML 4 [W3C.REC-html401-19991224]).

5. Optional attributes
   An Atom autodiscovery element MAY contain any other attributes of the
   link element defined in section 12.4 of HTML 4 [W3C.REC-html401- 19991224].  
   Clients MAY ignore any attributes other than rel, type, and href.

================================AtomPub: Atom publication format API ======================================

Die Atom-Programmierschnittstelle kann beispielsweise genutzt werden, um mit einer Client-Applikation auf die in einer Weblog-Software hinterlegten Inhalte Einfluss zu nehmen.
Funktionsweise

Die Kommunikation mit dem System funktioniert nach dem REST-Prinzip:

GET   um Informationen über bereits vorhandene Elemente einzuholen und andere Nur-Lese-Zugriffe auszuführen.
PUT   um ein bekanntes Element zu bearbeiten.
POST   kreiert ein neues, dynamisch benanntes Element.
DELETE    führt zur Löschung eines Elementes.

Diese Aktionen werden in Verbindung mit den drei hauptsächlichen URIs verwendet, wobei das Datenaustauschformat ein so genannter Atom Entry ist, ein Fragment/Eintrag eines vollen Atom-Feeds.

PostURI    erwartet POST. Wird verwendet um neue Elemente anzulegen. Schickt man einen Atom Entry an diese URI, so wird ein neues Element erzeugt.
EditURI    erwartet PUT, GET oder DELETE. Wird zum Bearbeiten von Elementen benötigt. Auch hier erfolgt der Datenaustausch über den Atom Entry.
FeedURI    erwartet GET. Repräsentiert ein komplettes Atom-Feed.

Die Atom-Programmierschnittstelle und das Atom Syndication Format ergänzen sich somit.
