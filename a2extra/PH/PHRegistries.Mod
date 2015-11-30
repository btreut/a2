MODULE PHRegistries; (** AUTHOR "Patrick Hunziker"; PURPOSE "Generic registry database"; *)
(**
Registry
	- is a list of items(unique UID), and ranges (e.g. for logical rollback without deleting the data).
	- items can have links to other items.
	- allows addition of items, with duplicates allowed or forbidden
	- serialization to file (* to do: change to reader/writer paradigm *)
	*)

IMPORT Files, Streams, Strings, TFClasses, KernelLog;

CONST Ok* =0;

TYPE 
	FileName* = Files.FileName;
	CompareProc* = PROCEDURE {DELEGATE}(left, right: ANY): LONGINT;
	List* = TFClasses.SortedList;
	
TYPE Item*=POINTER TO RECORD
		uid*: LONGINT;
		name*: ARRAY 32 OF CHAR;
		links*: Link;
	END;

TYPE Range*= POINTER TO RECORD(Item)
		from*,to*: LONGINT;
	END;

TYPE Link*= POINTER TO RECORD
		from*,to*: LONGINT;
		next*:Link;
	END;
	
TYPE Registry*= OBJECT
	VAR list-: List; 
		w*: Streams.Writer; r*: Streams.Reader; 
		filename: FileName;
		UID:LONGINT;
		params0, parameters:ARRAY 64 OF CHAR;
	
	PROCEDURE &Init*(CONST filename: ARRAY OF CHAR; compare:CompareProc; CONST params: ARRAY OF CHAR);
	BEGIN
		COPY(filename, SELF.filename); 
		COPY(params,parameters);
		w:=GetWriter(filename);
		r:= GetReader(filename);
		NEW(list, compare);
		Read;
	END Init;
	
	PROCEDURE GetUID*():LONGINT;
	BEGIN
		INC(UID);	RETURN UID-1;
	END GetUID;
		
	PROCEDURE AddNew*(CONST name: ARRAY OF CHAR):Item;
	VAR new: Item; 
	BEGIN
		NEW(new); 
		IF name#"" THEN COPY(name,new.name) ELSE new.name:='""' END;
		new.uid:=GetUID(); list.Add(new); RETURN new
	END AddNew;
	
	PROCEDURE AddUnique*(uid: LONGINT; CONST name: ARRAY OF CHAR):Item;
	VAR new: Item; 
	BEGIN
		NEW(new); 
		IF name#"" THEN COPY(name,new.name) ELSE new.name:='""' END;
		new.uid:=uid;
		IF addUnique(new) THEN RETURN new
		ELSE RETURN NIL
		END;
	END AddUnique;
	
	PROCEDURE addUnique*(item:Item): BOOLEAN;
	BEGIN
		IF list.SearchByKey(item)#NIL THEN 
			KernelLog.String("addition to registry failed: ");KernelLog.String(item.name); KernelLog.Int(item.uid,0); KernelLog.Ln;
			RETURN FALSE
		ELSE list.Add(item); RETURN TRUE
		END;
	END addUnique;
	
	PROCEDURE AddRange*(uid, from, to:LONGINT):Range;
	VAR range: Range;
	BEGIN
		NEW(range); 
		COPY("Rollback", range.name); range.uid:=uid; range.from:=from; range.to:=to; 
		list.Add(range);
		RETURN range
	END AddRange;
	
	PROCEDURE WriteItem*(item:Item);
	BEGIN
		w.Int(item.uid,0); w.Char(09X); w.String(item.name); 
	END WriteItem;
	
	PROCEDURE ReadItem*():Item;
	VAR item:Item; 
	BEGIN
		NEW(item); 
		r.Int(item.uid, FALSE); r.SkipSpaces;
		r.String(item.name); 
		IF r.res=Streams.Ok THEN RETURN item ELSE r.res:=Streams.Ok; RETURN NIL END;
	END ReadItem;
	
	PROCEDURE Write*;
	VAR any: ANY; i:LONGINT; link:Link;
	BEGIN
		w.SetPos(0);
		w.Int(UID,0); w.Char(09X); w.String(parameters); 
		(*IF Strings.Length(params)>0 THEN w.Char(09X); ... END; *) (*! currently, old parameters are lost *)
		w.Ln;
		FOR i:=0 TO list.GetCount()-1 DO 
			any:=list.GetItem(i);
			IF (any#NIL) THEN
				IF any IS Range THEN
					w.Int(any(Range).uid,0); w.Char(09X); w.String(any(Range).name); 
					w.Char(09X); w.Int(any(Range).from,0); 
					w.Char(09X); w.Int(any(Range).to,0); 
					w.Ln;
				ELSIF (any IS Item) THEN 
					WriteItem(any(Item));
					link:=any(Item).links;
					WHILE link#NIL DO 
						 w.Char(09X); w.Int(link.to,0);
						 link:=link.next;
					END;
					w.Ln;
				END;
			END;
		END;
		w.Update;
		IF Trace THEN KernelLog.String("Writing registry "); KernelLog.String(filename); KernelLog.Char(" "); KernelLog.Int( list.GetCount(),0); KernelLog.String(" items"); KernelLog.Ln; END;
	END Write;
	
	PROCEDURE Read*;
	VAR item: Item; range:Range; link:Link; count:LONGINT; 
	BEGIN
		count:=0; 
		r.Int(UID,FALSE); 
		r.Ln(params0); Strings.TrimLeft(params0,09X); Strings.TrimRight(params0,09X); 
		REPEAT
			item:=ReadItem();
			IF item=NIL THEN (*  *)
			ELSIF item.name="Rollback" THEN
				NEW(range); 
				COPY(item.name, range.name); range.uid:=item.uid;
				r.SkipSpaces; r.Int(range.from, FALSE); r.SkipSpaces; r.Int(range.to, FALSE); 
				item:=range;
			ELSE
				WHILE ~r.EOLN() DO 
					NEW(link); link.from:=item.uid; r.SkipSpaces; r.Int(link.to, FALSE);
					IF r.res=Streams.Ok THEN link.next:= item.links; item.links:=link; END;
				END;
			END;
			IF r.res=Streams.Ok THEN list.Add(item); INC(count) END;
			r.SkipLn;
		UNTIL r.res#Streams.Ok;
		IF count>UID THEN KernelLog.String("Error - inconsistency of UID counter; adapting last UID to "); KernelLog.Int(count+1,0); UID:=count+1; END;
		IF Trace THEN KernelLog.String("Reading registry "); KernelLog.String(filename); KernelLog.Char(" "); KernelLog.Int(count,0); KernelLog.String(" items"); KernelLog.Ln; END;
	END Read;
	
	END Registry;

VAR Trace*:BOOLEAN;

PROCEDURE GetWriter(CONST name:ARRAY OF CHAR): Streams.Writer;
	VAR w: Files.Writer; f:Files.File;
	BEGIN
		f:=Files.Old(name); IF f=NIL THEN f:=Files.New(name); Files.Register(f); END;
		IF f#NIL THEN Files.OpenWriter(w,f,0) ELSE HALT(300) END;
		RETURN w
	END GetWriter;
	
PROCEDURE GetReader(CONST name:ARRAY OF CHAR): Streams.Reader;
	VAR r: Files.Reader; f:Files.File;
	BEGIN
		f:=Files.Old(name); IF f=NIL THEN f:=Files.New(name);  Files.Register(f);  END;
		IF f#NIL THEN Files.OpenReader(r,f,0) ELSE HALT(301) END;
		RETURN r
	END GetReader;

PROCEDURE CompareItemName(left, right: ANY): LONGINT;
	BEGIN
		IF left=NIL THEN RETURN -2
		ELSIF right =NIL THEN RETURN 2
		ELSIF left(Item).name < right(Item).name THEN RETURN -1
		ELSIF left(Item).name = right(Item).name THEN RETURN 0
		ELSE RETURN 1
		END
	END CompareItemName;

PROCEDURE CompareItemUID(left, right: ANY): LONGINT;
	BEGIN
		IF left=NIL THEN RETURN -2
		ELSIF right =NIL THEN RETURN 2
		ELSIF left(Item).uid < right(Item).uid THEN RETURN -1
		ELSIF left(Item).uid = right(Item).uid THEN RETURN 0
		ELSE RETURN 1
		END
	END CompareItemUID;
	
PROCEDURE AddLink(from, to:Item);
	VAR link:Link;
	BEGIN
		NEW(link); link.from:=from.uid; link.to:=to.uid; link.next:=from.links; from.links:=link;
	END AddLink;

PROCEDURE Test*;
	VAR r: Registry; i:Item;
	BEGIN
		NEW(r,"RegTest.txt", CompareItemName,"TEST");
		i:=r.AddNew("first");
		i:=r.AddNew("second");
		r.Write;
	END Test;

BEGIN
	Trace:=TRUE;
END PHRegistries.

PHRegistries.Test 

SystemTools.FreeDownTo PHRegistries ~
