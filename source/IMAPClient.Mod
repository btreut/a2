MODULE IMAPClient; (** AUTHOR "retmeier"; PURPOSE "An IMAP Client and its data structures"; *)

IMPORT
	Configuration, Streams, Strings, KernelLog, Classes := TFClasses, Kernel, IMAP, IMAPUtilities, XML, XMLObjects;

CONST
	DEBUG = FALSE;

	KEEPALIVE =   20 * 1000 * 1; 	(* ms *)

	Port = 143;

	(* Return value of Procecures *)
	OK* = 0;
	ERROR* = 1;

	(* status *)
	DEAD* = -1;
	ONLINE* = 0;
	OFFLINE * = 1;
	DISCONNECTED *= 2;
	CONNECTIONERROR* = 3;
	AUTHENTICATIONERROR* = 4;

	(* constans for the current work the client is doing. Can be used to output a corresponding status string *)
	CWFINISHED* = 0;
	CWCONNECTING *= 1;
	CWLOADING *= 2;
	CWCREATING *= 3;
	CWRENAMING *= 4;
	CWDELETINGFOLDER *= 5;
	CWSEARCHING *= 6;
	CWCOPYING *= 7;
	CWDELETINGMESSAGE *= 8;
	CWAPPENDING *= 9;
	CWCLOSING *= 10;
	CWSAVINGACCOUNT *= 11;
	CWLOADINGACCOUNT *= 12;
	CWPOLLING *= 13;
	CWEXPUNGING *= 14;
	CWRESTORING *= 15;

	(* Tasks *)
	TNothing *= 0;
	TLoadAllMessages *= 1;

VAR
	globalR: LONGINT;

TYPE
	String = Strings.String;
	EventListener* = PROCEDURE  { DELEGATE };

	ErrorListener* = PROCEDURE{ DELEGATE} (CONST s:ARRAY OF CHAR);

	Message* = OBJECT
		VAR
			header*: HeaderElement;
			message*: String;
			bodystructure*: Bodystructure;
			internalDate*: String;
			size*: LONGINT;
			flags*: Flags;
			uID*: LONGINT;

		PROCEDURE ToString*():String;
		VAR
			buffer: Strings.Buffer;
			w: Streams.Writer;
			s: String;
			result: String;
		BEGIN
			NEW(buffer, 16);
			w := buffer.GetWriter();

			IF header.date # NIL THEN
				w.String("Date: "); w.String(header.date^); w.Ln();
			END;
			IF header.subject # NIL THEN
				w.String("Subject: "); w.String(header.subject^); w.Ln();
			END;
			IF header.from # NIL THEN
				IMAPUtilities.AddressesToString(header.from, s); w.String("From: "); w.String(s^); w.Ln();
			END;
			IF header.sender # NIL THEN
				IMAPUtilities.AddressesToString(header.sender, s); w.String("Sender: "); w.String(s^); w.Ln();
			END;
			IF header.replyTo # NIL THEN
				IMAPUtilities.AddressesToString(header.replyTo, s); w.String("Reply-To: "); w.String(s^); w.Ln();
			END;
			IF header.to # NIL THEN
				IMAPUtilities.AddressesToString(header.to, s); w.String("To: "); w.String(s^); w.Ln();
			END;
			IF header.cc # NIL THEN
				IMAPUtilities.AddressesToString(header.cc, s); w.String("Cc: "); w.String(s^); w.Ln();
			END;
			IF header.bcc # NIL THEN
				IMAPUtilities.AddressesToString(header.from, s); w.String("Bcc: "); w.String(s^); w.Ln();
			END;
			w.String("Content-type: text/plain; charset="); w.Char(CHR(34)); w.String("utf-8"); w.Char(CHR(34)); w.Ln();
			w.String("Content-Transfer-Encoding: quoted-printable"); w.Ln();

			w.Ln();
			s := IMAPUtilities.NewString(message^);
			IMAPUtilities.encodeQuotedPrintable(s);
			w.String(s^);

			result := buffer.GetString();
			RETURN result;
		END ToString;
	END Message;

	Client* = OBJECT
		VAR
			status-: LONGINT;
			currentWork-: LONGINT;
			abort*, userAbort*: BOOLEAN;
			c: IMAP.Connection;

			currentFolder-: Folder;
			mailboxContent-: Folder;
			getSubFoldersContext: Folder; (* shared Variable, that is used to pass the Folder from GetSubFolders() to CheckAnswer() *)

			FolderIsSynchronized: BOOLEAN; (* is set to FALSE by SelectFolder and tells the client to synchronize itself. Synchronization happens on timer wakeup *)
			FolderComplete: BOOLEAN; (* is set to FALSE by SelectFolder an means that Synchronize has not yet been executed completly *)
			Task*: LONGINT;

			searchResult-: POINTER TO ARRAY OF LONGINT;
			timer*: Kernel.Timer;

			observer: EventListener;
			errorHandler: ErrorListener;
			applySearchFilter*: BOOLEAN;

			ret: Classes.List;
			numberOfMessages: LONGINT;
			preferences*: AccountPreferences;

		PROCEDURE &Init*(obs: EventListener; error: ErrorListener);
		BEGIN
			NEW(preferences);
			preferences.LoadStandardConfig();
			abort := FALSE; userAbort := FALSE;

			observer := obs;
			errorHandler := error;
			applySearchFilter := FALSE;
			FolderIsSynchronized := TRUE;
			Task := TNothing;
			NEW(timer);

			NEW(mailboxContent,"Folders");
			mailboxContent.Noselect := TRUE;

			currentFolder := mailboxContent;

			status := DISCONNECTED;
			currentWork := CWFINISHED;
			c := NIL;
		END Init;

		PROCEDURE SetObserverMethod*(m: EventListener);
		BEGIN
			observer := m;
		END SetObserverMethod;

		PROCEDURE CallObserverMethod;
		BEGIN
			IF observer # NIL THEN
				observer();
			END;
		END CallObserverMethod;

		PROCEDURE SetErrorHandler*(m: ErrorListener);
		BEGIN
			errorHandler:= m;
		END SetErrorHandler;

		PROCEDURE CallErrorHandler(CONST string: ARRAY OF CHAR);
		BEGIN
			IF errorHandler # NIL THEN
				IF DEBUG THEN KernelLog.String(string); KernelLog.Ln(); END;
				errorHandler(string);
			END;
		END CallErrorHandler;

		PROCEDURE Connect*(CONST host, user, pass: ARRAY OF CHAR): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN ConnectUnlocked(host, user, pass);
		END Connect;

		PROCEDURE ConnectUnlocked(host, user, pass: ARRAY OF CHAR):LONGINT;
		VAR
			r: LONGINT;
			buffer: Strings.Buffer;
			w: Streams.Writer;
			errorString: String;
			inbox: Folder;
		BEGIN
			applySearchFilter := FALSE;
			userAbort := FALSE;
			abort := FALSE;
			preferences.IMAPServer := IMAPUtilities.NewString(host);
			preferences.UserName := IMAPUtilities.NewString(user);

			r := 0;
			NEW(c, host, Port, r);

			IF r # IMAP.OK THEN
				NEW(buffer, 16);
				w := buffer.GetWriter();
				w.String("Connection to host: ");
				w.String(host);
				w.String(" could not be estabilshed.");
				errorString := buffer.GetString();
				CallErrorHandler(errorString^);
				status := CONNECTIONERROR;
				c := NIL;
				RETURN ERROR;
			END;

			IF c.GetCurrentState() = IMAP.NOAUTH THEN
				r := c.Login(user, pass);
				IF r # IMAP.OK THEN
					CallErrorHandler("Username or Password wrong!");
					r := c.Logout();
					c := NIL;
					status := AUTHENTICATIONERROR;
					RETURN ERROR;
				END;
			END;

			status := ONLINE;
			currentWork := CWLOADING;

			currentFolder := mailboxContent;
			r := GetSubFolders(currentFolder);
			IF r # OK THEN
				currentWork := CWFINISHED;
				RETURN r;
			END;

			inbox := mailboxContent.FindSubFolder("INBOX");
			IF inbox # NIL THEN
				r := SelectFolderUnlocked(inbox);
			ELSE
				r := SelectFolderUnlocked(currentFolder);
			END;
			currentWork := CWFINISHED;
			IF r # OK THEN RETURN r; END;
			CallObserverMethod();
			RETURN OK;
		END ConnectUnlocked;

		PROCEDURE Disconnect*;
		VAR
			r: LONGINT;
		BEGIN {EXCLUSIVE}
			IF status = ONLINE THEN
				r := c.Logout();
				c := NIL;
			END;

			NEW(mailboxContent,"Folders");
			mailboxContent.Noselect := TRUE;
			currentFolder := mailboxContent;
			status := DISCONNECTED;
			CallObserverMethod();
		END Disconnect;

		PROCEDURE SwitchToOffline*;
		VAR
			r: LONGINT;
		BEGIN {EXCLUSIVE}
			IF status = ONLINE THEN
				r := c.Logout();
				status := OFFLINE;
				CallObserverMethod();
			END;
		END SwitchToOffline;

		PROCEDURE SwitchToOnline*(CONST password: ARRAY OF CHAR);
		VAR
			r: LONGINT;
		BEGIN {EXCLUSIVE}
			IF status = OFFLINE THEN
				(* authenticate to the server *)
				r := ConnectUnlocked(preferences.IMAPServer^, preferences.UserName^, password);
				IF r = OK THEN
					(* do local change *)
					status := ONLINE;
				ELSE
					status := OFFLINE;
				END;
				CallObserverMethod();
			END;
		END SwitchToOnline;

		PROCEDURE CheckAnswer(ret: Classes.List);
		VAR
			i: LONGINT;
			answerP: ANY;
			answer: IMAP.Entry;
		BEGIN
			i := 0;
			WHILE i < ret.GetCount() DO
				answerP := ret.GetItem(i);
				answer := answerP(IMAP.Entry);
				IF (answer.command = "EXISTS") THEN
					CheckExists(answer);
				ELSIF (answer.command = "RECENT") THEN
					CheckRecent(answer);
				ELSIF (answer.command = "EXPUNGE") THEN
					CheckExpunge(answer);
				ELSIF answer.command = "SEARCH" THEN
					CheckSearch(answer);
				ELSIF answer.command = "STATUS" THEN
					CheckStatus(answer);
				ELSIF answer.command = "LIST" THEN
					CheckList(answer);
				ELSIF answer.command = "FETCH" THEN
					CheckFetch(answer);
				ELSIF answer.command = "BYE" THEN
					CallErrorHandler("The server kicked us out by sending the BYE command. The client is disconnected.");
					c := NIL;
					NEW(mailboxContent,"Folders");
					mailboxContent.Noselect := TRUE;
					currentFolder := mailboxContent;
					status := DISCONNECTED;
					CallObserverMethod();
				END;
				INC(i);
			END;
			CallObserverMethod();
		END CheckAnswer;

		PROCEDURE CheckExists(answer: IMAP.Entry);
		BEGIN
			numberOfMessages := answer.number;
			FolderIsSynchronized := FALSE;
			timer.Wakeup();
		END CheckExists;

		PROCEDURE CheckRecent(answer: IMAP.Entry);
		BEGIN
			FolderIsSynchronized := FALSE;
			timer.Wakeup();
		END CheckRecent;

		PROCEDURE CheckExpunge(answer: IMAP.Entry);
		VAR
			messageP: ANY;
		BEGIN
			messageP := currentFolder.messages.GetItem(answer.number - 1);
			currentFolder.messages.Remove(messageP);
			DEC(numberOfMessages);
		END CheckExpunge;

		PROCEDURE CheckSearch(answer: IMAP.Entry);
		VAR
			list: Classes.List;
			j, count, number: LONGINT;
			entP: ANY;
			ent: IMAP.Entry;
		BEGIN
			list := answer.list;
			j := 0;
			count := list.GetCount();
			NEW(searchResult, count);

			WHILE j < count DO
				entP := list.GetItem(j);
				ent := entP(IMAP.Entry);
				Strings.StrToInt(ent.data^, number);
				searchResult[j] := number-1;
				INC(j);
			END;
		END CheckSearch;

		PROCEDURE CheckStatus(answer: IMAP.Entry);
		VAR
			list: Classes.List;
			j: LONGINT;
			entP: ANY;
			ent: IMAP.Entry;
		BEGIN
			list := answer.list;
			FOR j := 0 TO list.GetCount()-1 BY 2 DO
				entP := list.GetItem(j);
				ent := entP(IMAP.Entry);
				IF ent.data^ = "MESSAGES" THEN
					entP := list.GetItem(j+1);
					ent := entP(IMAP.Entry);
					Strings.StrToInt(ent.data^, numberOfMessages);
				END;
			END;
		END CheckStatus;

		PROCEDURE CheckList(answer: IMAP.Entry);
		VAR
			j: LONGINT;
			list, flags: Classes.List;
			entP, flagP: ANY;
			ent, flag: IMAP.Entry;
			path, name: String;
			folder, temp: Folder;
		BEGIN
			folder := getSubFoldersContext;
			list := answer.list;
			entP := list.GetItem(2);
			ent := entP(IMAP.Entry);

			IF getSubFoldersContext # mailboxContent THEN
				NEW(path, IMAPUtilities.StringLength(folder.path^)+IMAPUtilities.StringLength(folder.name^)+2);
				IF folder.parent = mailboxContent THEN
					IMAPUtilities.StringCopy(folder.name^, 0, IMAPUtilities.StringLength(folder.name^), path^);
				ELSE
					IMAPUtilities.StringCopy(folder.path^, 0, IMAPUtilities.StringLength(folder.path^), path^);
					path^[IMAPUtilities.StringLength(folder.path^)] := folder.hierarchyDelimiter;
					Strings.Append(path^, folder.name^);
				END;
				name := Strings.Substring2(IMAPUtilities.StringLength(path^) + 1, ent.data^);
			ELSE
				NEW(path, 1);
				path^[0] := 0X;
				name := IMAPUtilities.NewString(ent.data^);
			END;

			temp := folder.FindSubFolder(name^);
			IF temp = NIL THEN
				NEW(temp, name^);
				temp.path := path;
				temp.parent := folder;
				folder.children.Add(temp);
			END;
			temp.alive := TRUE;

			entP := list.GetItem(0);
			ent := entP(IMAP.Entry);

			flags := ent.list;
			j := 0;
			WHILE j < flags.GetCount() DO
				flagP := flags.GetItem(j);
				flag := flagP(IMAP.Entry);
				IF flag.data^ = "Noselect" THEN
					temp.Noselect := TRUE;
				ELSIF flag.data^ = "Noinferiors" THEN
					temp.Noinferiors := TRUE;
				ELSIF flag.data^ = "Marked" THEN
					temp.Marked := TRUE;
				ELSIF flag.data^ = "Unmarked" THEN
					temp.Unmarked := TRUE;
				END;
				INC(j);
			END;
			entP := list.GetItem(1);
			ent := entP(IMAP.Entry);
			temp.hierarchyDelimiter := ent.data^[0];
		END CheckList;

		PROCEDURE CheckFetch(answer: IMAP.Entry);
		VAR
			list, envList, structureList, subStructureList: Classes.List;
			entP, envEntP, structureP: ANY;
			ent, envEnt, structure: IMAP.Entry;
			j, l: LONGINT;
			message: Message;
			header: HeaderElement;
			bodystructure: Bodystructure;
			messageP: ANY;

			(* translate the internal IMAP representation [Realname] [namePart] [domainPart] to a list of Address objects *)
			PROCEDURE Imap2AdrList(entry:IMAP.Entry):Classes.List;
			VAR
				k: LONGINT;
				ent,temp: IMAP.Entry;
				entP, tempP:ANY;
				inlist, outlist: Classes.List;
				address: IMAPUtilities.Address;
			BEGIN
				NEW(outlist);
				IF entry.type # IMAP.LIST THEN RETURN outlist; END;
				inlist := entry.list;
				FOR k := 0 TO inlist.GetCount()-1 DO
					NEW(address);
					entP := inlist.GetItem(k);ent := entP(IMAP.Entry);
					ASSERT(ent.type = IMAP.LIST,1001);
					tempP := ent.list.GetItem(0); temp := tempP(IMAP.Entry);
					IF temp.data^ = "NIL" THEN
						NEW(address.realName, 1);
						COPY("",address.realName^);
					ELSE
						address.realName := temp.data;
					END;
					tempP := ent.list.GetItem(2);
					temp := tempP(IMAP.Entry);
					address.namePart := temp.data;
			 		tempP := ent.list.GetItem(3);
			 		temp := tempP(IMAP.Entry);
			 		address.domainPart := temp.data;
			 		outlist.Add(address);
			 	END;
			 	RETURN outlist;
			END Imap2AdrList;

		BEGIN
			messageP := currentFolder.messages.GetItem(answer.number - 1);
			message := messageP(Message);
			list := answer.list;

			FOR j := 0 TO list.GetCount()-1 BY 2 DO
				entP := list.GetItem(j);
				ent := entP(IMAP.Entry);
				Strings.UpperCase(ent.data^);
				IF ent.data^ = "FLAGS" THEN
					entP := list.GetItem(j+1);
					ent := entP(IMAP.Entry); (* list of flags *)
					NEW(message.flags);
					message.flags.ParseList(ent.list);
				ELSIF ent.data^ = "INTERNALDATE" THEN
					entP := list.GetItem(j+1);
					ent := entP(IMAP.Entry);
					message.internalDate := ent.data;
				ELSIF ent.data^ = "RFC822.SIZE" THEN
					entP := list.GetItem(j+1);
					ent := entP(IMAP.Entry);
					Strings.StrToInt(ent.data^,message.size);
				ELSIF ent.data^ = "UID" THEN
					entP := list.GetItem(j+1);
					ent := entP(IMAP.Entry);
					Strings.StrToInt(ent.data^,message.uID);
				ELSIF ent.data^ = "ENVELOPE" THEN
					NEW(header);
					message.header := header;
					entP := list.GetItem(j+1);
					ent := entP(IMAP.Entry);
					envList := ent.list;
					envEntP := envList.GetItem(0); envEnt := envEntP(IMAP.Entry); header.date := envEnt.data;
					envEntP := envList.GetItem(1); envEnt := envEntP(IMAP.Entry); header.subject := envEnt.data;
					envEntP := envList.GetItem(8); envEnt := envEntP(IMAP.Entry); header.inReplyTo := envEnt.data;
					envEntP := envList.GetItem(9); envEnt := envEntP(IMAP.Entry); header.messageID := envEnt.data;
					envEntP := envList.GetItem(2); envEnt := envEntP(IMAP.Entry); header.from :=  Imap2AdrList(envEnt);
					envEntP := envList.GetItem(3); envEnt := envEntP(IMAP.Entry); header.sender :=  Imap2AdrList(envEnt);
					envEntP := envList.GetItem(4); envEnt := envEntP(IMAP.Entry); header.replyTo :=  Imap2AdrList(envEnt);
					envEntP := envList.GetItem(5); envEnt := envEntP(IMAP.Entry); header.to :=  Imap2AdrList(envEnt);
					envEntP := envList.GetItem(6); envEnt := envEntP(IMAP.Entry); header.cc :=  Imap2AdrList(envEnt);
					envEntP := envList.GetItem(7); envEnt := envEntP(IMAP.Entry); header.bcc :=  Imap2AdrList(envEnt);
				ELSIF ent.data^ = "RFC822.TEXT" THEN
					entP := list.GetItem(j+1);
					ent := entP(IMAP.Entry);
					message.message := IMAPUtilities.NewString(ent.data^);
				ELSIF ent.data^ = "BODYSTRUCTURE" THEN
					entP := list.GetItem(j+1);
					ent := entP(IMAP.Entry);
					structureList := ent.list;
					structureP := structureList.GetItem(0);
					structure := structureP(IMAP.Entry);
					NEW(bodystructure);
					IF structure.type = IMAP.LIST THEN
						Strings.Copy("MULTIPART", 0, 9, bodystructure.type);
						bodystructure.subpart := NIL;
					ELSE
						structureP := structureList.GetItem(0);
						structure := structureP(IMAP.Entry);
						IMAPUtilities.StringCopy(structure.data^, 0, IMAPUtilities.StringLength(structure.data^), bodystructure.type);
						structureP := structureList.GetItem(1);
						structure := structureP(IMAP.Entry);
						IMAPUtilities.StringCopy(structure.data^, 0, IMAPUtilities.StringLength(structure.data^), bodystructure.subtype);
						structureP := structureList.GetItem(5);
						structure := structureP(IMAP.Entry);
						IMAPUtilities.StringCopy(structure.data^, 0, IMAPUtilities.StringLength(structure.data^), bodystructure.encoding);
						structureP := structureList.GetItem(2);
						structure := structureP(IMAP.Entry);
						subStructureList := structure.list;
						IF subStructureList # NIL THEN
							FOR l := 0 TO subStructureList.GetCount()-1 BY 2 DO
								structureP := subStructureList.GetItem(l);
								structure := structureP(IMAP.Entry);
								Strings.UpperCase(structure.data^);
								IF structure.data^ = "CHARSET" THEN
									structureP := subStructureList.GetItem(l+1);
									structure := structureP(IMAP.Entry);
									IMAPUtilities.StringCopy(structure.data^, 0, IMAPUtilities.StringLength(structure.data^), bodystructure.charset);
								END;
							END;
						END;
						bodystructure.subpart := NIL;

					END;
					message.bodystructure := bodystructure;

				END;
			END;
		END CheckFetch;

		PROCEDURE Synchronize(): LONGINT;
		VAR
			path, items: String;
			r, i: LONGINT;
			count, step, start, stop, single, fetchStart, fetchStop: LONGINT;
			oldMessages, newMessages: Classes.List;
			p, pOld: ANY;
			message, oldMsg: Message;
			found, found2, findable: BOOLEAN;
			sortedList: Classes.SortedList;
		BEGIN
			(* check status *)
			path := currentFolder.GetPath();
			items := Strings.NewString("(MESSAGES RECENT UIDNEXT UIDVALIDITY UNSEEN)");
			r := c.Status(path^, items^, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to get the status from the server");
				abort := TRUE;
				RETURN ERROR;
			END;
			CheckAnswer(ret);

			(* build the new list *)
			oldMessages := currentFolder.messages;
			NEW(newMessages);
			i := 0;
			WHILE i < numberOfMessages DO
				NEW(message);
				newMessages.Add(message);
				INC(i);
			END;
			currentFolder.messages := newMessages;

			(* delete NIL entries in the old list *)
			i := 0;
			WHILE i < oldMessages.GetCount() DO
				p := oldMessages.GetItem(i);
				message := p(Message);
				IF message.header = NIL THEN
					oldMessages.Remove(p);
				ELSE
					INC(i);
				END;
			END;

			(* create a sorted list with the old messages, sorted by UIDs *)
			NEW(sortedList, BiggestUIDFirst);
			FOR i := 0 TO oldMessages.GetCount()-1 DO
				p := oldMessages.GetItem(i);
				message := p(Message);
				sortedList.Add(message);
			END;

			(* load the messages in intervalls *)
			count := numberOfMessages - 1;
			step := (numberOfMessages DIV 20) + 1;
			WHILE (count >= 0) & (~abort) & (~userAbort) DO
				(* determine the intervall *)
				stop := count;
				start := count - step + 1;
				IF start < 0 THEN
					start := 0;
				END;

				(* load the UIDs and Flags if necessary *)
				IF ~FolderComplete THEN
					r := FetchSomeUIDs(start, stop-start+1);
					IF r # OK THEN
						abort := TRUE;
						RETURN r;
					END;
				END;

				(* use oldMessage in case of a UID-match for all the messages in the intervall *)
				single := stop;
				WHILE (single >= start) DO
					p := newMessages.GetItem(single);
					message := p(Message);
					i := 0;
					found := FALSE;
					findable := TRUE; (* as long as the UID is bigger then the UID of the current message in sortedList *)
					WHILE (i < sortedList.GetCount()) & (~found) & (findable) DO
						pOld := sortedList.GetItem(i);
						oldMsg := pOld(Message);
						IF oldMsg.uID = message.uID THEN
							found := TRUE;
						ELSIF oldMsg.uID < message.uID THEN
							findable := FALSE;
						ELSE
							INC(i);
						END;
					END;

					IF found THEN
						oldMsg.flags := message.flags;
						newMessages.Replace(p, pOld);
						sortedList.Remove(pOld);
					END;

					DEC(single);
				END;

				(* fetch all the messages in the intervall that have header = NIL *)
				single := stop;
				WHILE (single >= start) DO
					(* find the first message with header = NIL *)
					found := FALSE;
					WHILE ((single >= start) & (~found)) DO
						p := newMessages.GetItem(single);
						message := p(Message);
						IF message.header = NIL THEN
							found := TRUE;
							fetchStop := single;
							fetchStart := single;
						END;
						DEC(single);
					END;
					(* look for more messages with header = NIL *)
					found2 := FALSE;
					WHILE ((single >= start) & (~found2)) DO
						p := newMessages.GetItem(single);
						message := p(Message);
						IF message.header = NIL THEN
							fetchStart := single;
						ELSE
							found2 := TRUE;
						END;
						DEC(single);
					END;

					IF found THEN
						r := FetchSomeHeaders(fetchStart, fetchStop-fetchStart+1);
						IF r # OK THEN
							abort := TRUE;
							RETURN r;
						END;
					END;
				END;
				count := count - step;
			END;

			FolderComplete := TRUE;
			FolderIsSynchronized := TRUE;
			RETURN OK;
		END Synchronize;

		PROCEDURE DownloadAllMessages(): LONGINT;
		VAR
			r, count, step: LONGINT;
			start, end: LONGINT;
			message: Message;
			p: ANY;
		BEGIN
			Task := TNothing;
			count := currentFolder.messages.GetCount() - 1;
			step := (count DIV 20) + 1;

			WHILE (count >=  0) & (~abort) & (~userAbort) DO
				p := currentFolder.messages.GetItem(count);
				message := p(Message);
				WHILE (message.message # NIL) & (message.header # NIL) & (count >= 0) DO
					DEC(count);
					IF count >= 0 THEN
						p := currentFolder.messages.GetItem(count);
						message := p(Message);
					END;
				END;
				end := count;
				start := count - step + 1;
				IF start < 0 THEN
					start := 0;
				END;

				IF count < 0 THEN
					RETURN OK;
				END;

				p := currentFolder.messages.GetItem(count);
				message := p(Message);
				WHILE ((message.message = NIL) OR (message.header = NIL)) & (count >= start) DO
					DEC(count);
					IF count >= 0 THEN
						p := currentFolder.messages.GetItem(count);
						message := p(Message);
					END;
				END;
				start := count;
				IF start < 0 THEN
					start := 0;
				END;
				r := FetchSomeMessages(start, end-start+1);
			END;
			RETURN OK;
		END DownloadAllMessages;

		(* fetches starting from idx the following len Messages *)
		PROCEDURE FetchSomeHeaders(idx, len: LONGINT): LONGINT;
		VAR
			ret: Classes.List;
			r: LONGINT;
			start, end, set: ARRAY 64 OF CHAR;
		BEGIN
			Strings.IntToStr(idx+1, start);
			Strings.IntToStr(idx+len, end);
			IMAPUtilities.StringCopy(start, 0, IMAPUtilities.StringLength(start), set);
			Strings.Append(set, ":");
			Strings.Append(set, end);
			r := c.Fetch(set, "(FLAGS INTERNALDATE RFC822.SIZE ENVELOPE UID)", ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to fetch some headers.");
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			RETURN OK;
		END FetchSomeHeaders;

		(* fetches starting from idx the following len Messages *)
		PROCEDURE FetchSomeUIDs(idx, len: LONGINT): LONGINT;
		VAR
			ret: Classes.List;
			r: LONGINT;
			start, end, set: ARRAY 64 OF CHAR;
		BEGIN
			Strings.IntToStr(idx+1, start);
			Strings.IntToStr(idx+len, end);
			IMAPUtilities.StringCopy(start, 0, IMAPUtilities.StringLength(start), set);
			Strings.Append(set, ":");
			Strings.Append(set, end);
			r := c.Fetch(set, "(FLAGS UID)", ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to fetch some UIDs.");
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			RETURN OK;
		END FetchSomeUIDs;

		PROCEDURE FetchSomeMessages(idx, len: LONGINT): LONGINT;
		VAR
			ret: Classes.List;
			r: LONGINT;
			start, end, set: ARRAY 64 OF CHAR;
		BEGIN
			Strings.IntToStr(idx+1, start);
			Strings.IntToStr(idx+len, end);
			IMAPUtilities.StringCopy(start, 0, IMAPUtilities.StringLength(start), set);
			Strings.Append(set, ":");
			Strings.Append(set, end);
			r := c.Fetch(set, "(FLAGS INTERNALDATE RFC822.SIZE ENVELOPE UID RFC822.TEXT BODYSTRUCTURE)", ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to fetch some messages.");
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			RETURN OK;
		END FetchSomeMessages;

 		PROCEDURE FetchMessage*(message: Message): LONGINT;
		VAR
			i: LONGINT;
			number: ARRAY 20 OF CHAR;
			ret: Classes.List;
		BEGIN {EXCLUSIVE}
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to fetch a message. The Client is not online.");
				RETURN ERROR;
			END;
			currentWork := CWLOADING;
			Strings.IntToStr(message.uID, number);
			i := c.UIDFetch(number, "(RFC822.TEXT BODYSTRUCTURE)", ret);
			IF i # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to fetch a message.");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN OK;
		END FetchMessage;

		PROCEDURE DeleteMessage*(message: Message; expunge: BOOLEAN): LONGINT;
		VAR
			set: ARRAY 20 OF CHAR;
			ret: Classes.List;
			r: LONGINT;
		BEGIN {EXCLUSIVE}
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to delete a message. The Client is not online.");
				RETURN ERROR;
			END;
			currentWork := CWDELETINGMESSAGE;
			Strings.IntToStr(message.uID, set);
			r := c.UIDStore(set, "\Deleted", TRUE, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to delete a message.");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			IF expunge THEN
				r := ExpungeUnlocked();
				IF r # IMAP.OK THEN
					currentWork := CWFINISHED;
					RETURN ERROR;
				END;
			END;
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN OK;
		END DeleteMessage;

		PROCEDURE MoveMessageToTrashBin*(message: Message): LONGINT;
		VAR
			set: ARRAY 20 OF CHAR;
			ret: Classes.List;
			r: LONGINT;
			folder: String;
		BEGIN {EXCLUSIVE}
			IF preferences.TrashBin^ = "" THEN
				CallErrorHandler("Trash bin is not specified in Preferences.");
				RETURN ERROR;
			END;
			currentWork := CWDELETINGMESSAGE;
			Strings.IntToStr(message.uID, set);
			folder := currentFolder.GetPath();
			IF folder^ # preferences.TrashBin^ THEN (* for the case of deleting the trash bin itself, we continue after the if branche as if we were not using a trash bin *)
				r := CopyMessageUnlocked(message, preferences.TrashBin);
				IF r # OK THEN
					CallErrorHandler("An error happend while trying to move a message to the trash bin.");
					currentWork := CWFINISHED;
					RETURN ERROR;
				END;
				r := c.UIDStore(set, "\Deleted", TRUE, ret);
				IF r # IMAP.OK THEN
					CallErrorHandler("An error happend while trying to delete a message.");
					currentWork := CWFINISHED;
					RETURN ERROR;
				END;
				CheckAnswer(ret);

				r := ExpungeUnlocked();
				IF r # OK THEN
					currentWork := CWFINISHED;
					RETURN ERROR;
				END;
				CheckAnswer(ret);
				currentWork := CWFINISHED;
				CallObserverMethod();
				RETURN OK;
			END;

			(* if we get here we are deleting a message from the trash bin *)
			r := c.UIDStore(set, "\Deleted", TRUE, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to delete a message.");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			IF (preferences.ExpungeOnDelete) THEN
				r := ExpungeUnlocked();
				IF r # OK THEN
					currentWork := CWFINISHED;
					RETURN ERROR;
				END;
			END;
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN OK;
		END MoveMessageToTrashBin;

		PROCEDURE RestoreMessage*(message: Message): LONGINT;
		VAR
			set: ARRAY 20 OF CHAR;
			ret: Classes.List;
			r: LONGINT;
		BEGIN {EXCLUSIVE}
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to restore a message. The Client is not online.");
				RETURN ERROR;
			END;
			currentWork := CWRESTORING;
			Strings.IntToStr(message.uID, set);
			r := c.UIDStore(set, "\Deleted", FALSE, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to restore a message.");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN OK;
		END RestoreMessage;

		PROCEDURE CopyMessage*(message: Message; path: String): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN CopyMessageUnlocked(message, path);
		END CopyMessage;

		(* copy the Message message to the Folder target *)
		PROCEDURE CopyMessageUnlocked*(message: Message; path: String): LONGINT;
		VAR
			r: LONGINT;
			set: ARRAY 20 OF CHAR;
			ret: Classes.List;
		BEGIN
			IF path^ = "" THEN
				CallErrorHandler("The Target Folder is not specified. Select a Target Folder before trying to copy!");
				RETURN ERROR;
			END;
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to copy a message. The Client is not online.");
				RETURN ERROR;
			END;
			currentWork := CWCOPYING;
			Strings.IntToStr(message.uID, set);
			r := c.UIDCopy(set, path^, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to copy a message.");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN OK;
		END CopyMessageUnlocked;

		PROCEDURE AppendMessage*(message: Message; path: String): LONGINT;
		VAR
			string: String;
			r: LONGINT;
			ret: Classes.List;
		BEGIN {EXCLUSIVE}
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to append a message. The Client is not online.");
				RETURN ERROR;
			END;
			currentWork := CWAPPENDING;
			string := message.ToString();

			r := c.Append(path^, string^, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to append a message.");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN OK;
		END AppendMessage;

		PROCEDURE SetAnsweredFlag*(message: Message): LONGINT;
		VAR
			set: ARRAY 20 OF CHAR;
			ret: Classes.List;
			r: LONGINT;
		BEGIN {EXCLUSIVE}
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to set the answered flag of a message. The Client is not online.");
				RETURN ERROR;
			END;
			Strings.IntToStr(message.uID, set);

			r := c.UIDStore(set, "\Answered", TRUE, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to set the answered flag of a message.");
				RETURN ERROR;
			END;

			CheckAnswer(ret);
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN OK;
		END SetAnsweredFlag;

		PROCEDURE SaveSentMessage*(message: Message):LONGINT;
		VAR
			r: LONGINT;
			string: String;
			ret: Classes.List;
		BEGIN {EXCLUSIVE}
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to save the message. The Client is not online.");
				RETURN ERROR;
			END;
			IF preferences.SentFolder^ = "" THEN
				CallErrorHandler("You didn't specify in your Preferences where to store a sent Message.");
				RETURN ERROR;
			END;
			currentWork := CWAPPENDING;
			string := message.ToString();
			r := c.Append(preferences.SentFolder^, string^, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to save the message.");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			CheckAnswer(ret);

			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN OK;
		END SaveSentMessage;

		PROCEDURE Expunge*(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN ExpungeUnlocked();
		END Expunge;

		PROCEDURE ExpungeUnlocked(): LONGINT;
		VAR
			r: LONGINT;
			ret: Classes.List;
		BEGIN
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to expunge. The Client is not online.");
				RETURN ERROR;
			END;
			currentWork := CWEXPUNGING;
			r := c.Expunge(ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to expunge.");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN OK;
		END ExpungeUnlocked;

		PROCEDURE SelectFolder*(folder: Folder): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN SelectFolderUnlocked(folder);
		END SelectFolder;

		PROCEDURE  SelectFolderUnlocked(folder: Folder): LONGINT;
		VAR
			ret: Classes.List;
			i: LONGINT;
			path: String;
		BEGIN
			currentWork := CWLOADING;
			IF status = OFFLINE THEN
				currentFolder := folder;
				numberOfMessages := currentFolder.messages.GetCount();
				currentWork := CWFINISHED;
			ELSIF status = ONLINE THEN
				IF currentFolder = folder THEN
					currentWork := CWFINISHED;
				ELSE
					IF (c.GetCurrentState() = IMAP.SELECT) & preferences.ExpungeOnFolderChange THEN
						i := c.Close();
					END;

					i := GetSubFolders(folder);
					IF i # OK THEN
						CallErrorHandler("An error happend while trying to the subfolders of the Folder.");
						currentWork := CWFINISHED;
						RETURN i;
					END;

					IF folder.Noselect = FALSE THEN
						path := folder.GetPath();
						i := c.Select(path^, ret);
						IF i # IMAP.OK THEN
							CallErrorHandler("An error happend while trying to select a Folder.");
							currentWork := CWFINISHED;
							CallObserverMethod();
							RETURN ERROR;
						END;

						currentFolder := folder;
						FolderIsSynchronized := FALSE;
						FolderComplete := FALSE;
						currentWork := CWFINISHED;
						timer.Wakeup();
					ELSE
						currentFolder := folder;
						FolderIsSynchronized := TRUE;
						currentWork := CWFINISHED;
					END;
				END;
			END;
			CallObserverMethod();
			RETURN OK;
		END SelectFolderUnlocked;

		PROCEDURE GetSubFolders(VAR  folder: Folder): LONGINT;
		VAR
			i: LONGINT;
			p: ANY;
			r: LONGINT;
			temp: Folder;
			path: String;
			ret: Classes.List;
			nameLen, pathLen: LONGINT;
		BEGIN
			(* set the alive flag of all the current subfolders to FALSE to elimitate dead subfolders later *)
			i := 0;
			WHILE i < folder.children.GetCount() DO
				p := folder.children.GetItem(i);
				temp := p(Folder);
				temp.alive := FALSE;
				INC(i);
			END;

			(* check that folder is a sub folder of mailboxContent *)
			temp := folder;
			path := Strings.NewString("");

			WHILE(temp # mailboxContent) & (temp # NIL) DO
				temp := temp.parent;
			END;

			IF (temp = NIL) THEN
				CallErrorHandler("An error happend while trying to get the subfolders of a folder which does not belong to the client's folder structure.");
				RETURN ERROR;
			END;

			IF folder = mailboxContent THEN
				path := Strings.NewString("%");
			ELSE
				pathLen := IMAPUtilities.StringLength(folder.path^);
				nameLen := IMAPUtilities.StringLength(folder.name^);
				IF pathLen = 0 THEN
					NEW(path, nameLen + 3);
					IMAPUtilities.StringCopy(folder.name^, 0, nameLen, path^);
					path[nameLen] := folder.hierarchyDelimiter;
					path[nameLen + 1] := "%";
					path[nameLen + 2] := 0X;
				ELSE
					NEW(path, nameLen+pathLen+4);

					IMAPUtilities.StringCopy(folder.path^, 0, pathLen, path^);
					path[pathLen] := folder.hierarchyDelimiter;
					Strings.Append(path^, folder.name^);

					path[nameLen + pathLen + 1] := folder.hierarchyDelimiter;
					path[nameLen + pathLen + 2] := "%";
					path[nameLen + pathLen + 3] := 0X;

				END;
			END;
			IF DEBUG THEN 	KernelLog.String("Before c.List"); KernelLog.Ln(); 	END;
			r := c.List("", path^, ret);
			IF DEBUG THEN 	KernelLog.String("After c.List r= "); KernelLog.Int(r,0); KernelLog.String(" state= "); KernelLog.Int(c.GetCurrentState(),0); KernelLog.Ln(); 	END;
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to get the sub folders of a Folder.");
				RETURN ERROR;
			END;
			getSubFoldersContext := folder;
			CheckAnswer(ret);

			(* eliminate those folders with the alive flag equal to FALSE *)
			i := 0;
			WHILE i < folder.children.GetCount() DO
				p := folder.children.GetItem(i);
				temp := p(Folder);
				IF temp.alive = FALSE THEN
					folder.children.Remove(p);
				ELSE
					INC(i);
				END;
			END;
			CallObserverMethod();
			RETURN OK;
		END GetSubFolders;

		PROCEDURE Close*;
		VAR
			r: LONGINT;
		BEGIN {EXCLUSIVE}
			IF DEBUG THEN 	KernelLog.String("Client is closing..."); KernelLog.Ln(); 	END;
			currentWork := CWCLOSING;
			IF status = ONLINE THEN
				r := c.Logout();
				CheckAnswer(ret);
				c := NIL;
			END;
			status := DEAD;
			timer.Wakeup();
		END Close;

		PROCEDURE Update(): LONGINT;
		VAR
			i, count: LONGINT;
			p: ANY;
			message: Message;
			ret: Classes.List;
		BEGIN
			i := c.Noop(ret);
			IF i # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to get update information from the server.");
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			count := 0;
			WHILE count < currentFolder.messages.GetCount() DO
				p := currentFolder.messages.GetItem(count);
				message := p(Message);
				IF message.header = NIL THEN
					IF DEBUG THEN 	KernelLog.String("In Update. Message header is NIL"); KernelLog.Ln(); END;
					FolderIsSynchronized := FALSE;
				END;
				INC(count);
			END;
			CallObserverMethod();
			RETURN OK;
		END Update;

		(* tries to rename the folder *)
		PROCEDURE Rename*(folder: Folder; VAR name:  ARRAY OF CHAR): LONGINT;
		VAR
			newName: String;
			oldName: String;
			r: LONGINT;
			pathLen: LONGINT;
			ret: Classes.List;
			parent: Folder;
		BEGIN {EXCLUSIVE}
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to rename a Folder. The Client is not online.");
				RETURN ERROR;
			END;
			currentWork := CWRENAMING;
			parent := folder.parent;
			oldName := folder.GetPath();
			pathLen := IMAPUtilities.StringLength(folder.path^);
			IF pathLen = 0 THEN
				newName := IMAPUtilities.NewString(name);
			ELSE
				NEW(newName, pathLen + IMAPUtilities.StringLength(name) + 2);
				IMAPUtilities.StringCopy(folder.path^, 0, pathLen, newName^);
				newName^[pathLen] := folder.hierarchyDelimiter;
				Strings.Append(newName^, name);
			END;

			IF DEBUG THEN
				KernelLog.String("Renaming folder"); KernelLog.Ln();
				KernelLog.String("old Name: "); KernelLog.String(oldName^); KernelLog.Ln();
				KernelLog.String("new Name: "); KernelLog.String(newName^); KernelLog.Ln();
			END;

			r := c.Rename(oldName^, newName^, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to rename a Folder.");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			r := OK;
			IF parent # NIL THEN
				r := GetSubFolders(parent);
			ELSE
				r := GetSubFolders(currentFolder);
			END;
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN r;
		END Rename;

		(* tries to delete the folder *)
		PROCEDURE Delete*(folder: Folder): LONGINT;
		VAR
			r: LONGINT;
			path: String;
			ret: Classes.List;
			parent: Folder;
		BEGIN {EXCLUSIVE}
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to delete a Folder. The Client is not online.");
				RETURN ERROR;
			END;
			currentWork := CWDELETINGFOLDER;
			parent := folder.parent;
			path := folder.GetPath();
			r := c.Delete(path^, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to delete a Folder.");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			r := OK;
			IF parent # NIL THEN
				r := GetSubFolders(parent);
			ELSE
				r := GetSubFolders(currentFolder);
			END;
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN r;
		END Delete;

		PROCEDURE Create*(folder: Folder; name: ARRAY OF CHAR): LONGINT;
		VAR
			r: LONGINT;
			string: String;
			newName: String;
			len, pos: LONGINT;
			ret: Classes.List;
		BEGIN {EXCLUSIVE}
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to create a Folder. The Client is not online.");
				RETURN ERROR;
			END;
			currentWork := CWCREATING;
			string := folder.GetPath();
			pos := IMAPUtilities.StringLength(string^);
			len := pos + IMAPUtilities.StringLength(name) + 2;
			NEW(newName, len);
			IMAPUtilities.StringCopy(string^, 0, pos, newName^);

			newName^[pos] := folder.hierarchyDelimiter;
			newName^[pos+1] := 0X;
			Strings.Append(newName^, name);

			r := c.Create(newName^, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to create a Folder.");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			CheckAnswer(ret);
			r := OK;
			r := GetSubFolders(folder);
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN r;
		END Create;

		PROCEDURE Search*(string: ARRAY OF CHAR): LONGINT;
		VAR
			r: LONGINT;
			ret: Classes.List;
		BEGIN {EXCLUSIVE}
			IF status = OFFLINE THEN
				RETURN OfflineSearch(string);
			END;
			IF status # ONLINE THEN
				CallErrorHandler("An error happend while trying to search. The Client is not online.");
				RETURN ERROR;
			END;
			currentWork := CWSEARCHING;
			r := c.Search(string, ret);
			IF r # IMAP.OK THEN
				CallErrorHandler("An error happend while trying to search.");
				currentWork := CWFINISHED;
				CallObserverMethod();
				RETURN -1; (* ERROR *)
			END;
			CheckAnswer(ret);
			applySearchFilter := TRUE;
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN LEN(searchResult);
		END Search;

		PROCEDURE OfflineSearch(string: ARRAY OF CHAR): LONGINT;
		VAR
			i, count: LONGINT;
			reader: Streams.StringReader;
			command: String;
			Result: POINTER TO ARRAY OF BOOLEAN;

			PROCEDURE CheckCommand(CONST command: ARRAY OF CHAR);
			VAR
				p: ANY;
				message: Message;
				string, string2: String;
				value: LONGINT;
				date, internalDate: Date;
				temp1, temp2: POINTER TO ARRAY OF BOOLEAN;
			BEGIN
				NEW(date); NEW(internalDate);
				IF DEBUG THEN KernelLog.String("Checking Command: "); KernelLog.String(command); KernelLog.Ln(); END;
				IF command = "ANSWERED" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (~message.flags.answered) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "UNANSWERED" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (message.flags.answered) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "DELETED" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (~message.flags.deleted) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "UNDELETED" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (message.flags.deleted) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "DRAFT" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (~message.flags.draft) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "UNDRAFT" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (message.flags.draft) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "FLAGGED" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (~message.flags.flagged) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "UNFLAGGED" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (message.flags.flagged) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "SEEN" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (~message.flags.seen) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "UNSEEN" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (message.flags.seen) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "RECENT" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (~message.flags.recent) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "OLD" THEN
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (message.flags.recent) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "SUBJECT" THEN
					GetString(string);
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (~IMAPUtilities.StringContains(message.header.subject, string)) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "FROM" THEN
					GetString(string);
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IMAPUtilities.AddressesToString(message.header.from, string2);
						IF Result[i] & (~IMAPUtilities.StringContains(string2, string)) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "BODY" THEN
					GetString(string);
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (~IMAPUtilities.StringContains(message.message, string)) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "LARGER" THEN
					GetString(string);
					Strings.StrToInt(string^, value);
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (~(message.size > value)) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "SMALLER" THEN
					GetString(string);
					Strings.StrToInt(string^, value);
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						IF Result[i] & (~(message.size < value)) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "BEFORE" THEN
					GetString(string);
					date.FromInternalDate(string);
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						internalDate.FromInternalDate(message.internalDate);
						IF Result[i] & (~(internalDate.Before(date))) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "ON" THEN
					GetString(string);
					date.FromInternalDate(string);
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						internalDate.FromInternalDate(message.internalDate);
						IF Result[i] & (~(internalDate.Equal(date))) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "SINCE" THEN
					GetString(string);
					date.FromInternalDate(string);
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						p := currentFolder.messages.GetItem(i);
						message := p(Message);
						internalDate.FromInternalDate(message.internalDate);
						IF Result[i] & (~(date.Before(internalDate))) THEN
							Result[i] := FALSE;
						END;
					END;
				ELSIF command= "OR" THEN
					reader.SkipWhitespace();
					NEW(string, reader.Available() + 1);
					reader.Token(string^);
					NEW(temp1, currentFolder.messages.GetCount());
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						temp1[i] := Result[i];
						Result[i] := TRUE;
					END;
					CheckCommand(string^);
					reader.SkipWhitespace();
					reader.Token(string^);
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						temp2[i] := Result[i];
						Result[i] := TRUE;
					END;
					CheckCommand(string^);
					FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
						IF (~Result[i]) & (~temp2[i]) THEN
							Result[i] := FALSE;
						ELSE
							Result[i] := temp1[i];
						END;
					END;
				ELSE
					CallErrorHandler("Unknown Search command");
				END;
			END CheckCommand;

			PROCEDURE GetString(VAR string: String);
			VAR
				s: String;
				buffer: Strings.Buffer;
				w: Streams.Writer;
				c: CHAR;
			BEGIN
				NEW(buffer, 16);
				w := buffer.GetWriter();
				reader.SkipWhitespace();
				reader.Char(c);
				IF c = '"' THEN
					reader.Char(c);
					WHILE (ORD(c) # 34) DO
						w.Char(c);
						reader.Char(c);
					END;
				ELSE
					w.Char(c);
					NEW(s, reader.Available()+1);
					reader.Token(s^);
					w.String(s^);
				END;
				string := buffer.GetString();
			END GetString;

		BEGIN
			currentWork := CWSEARCHING;
			IF DEBUG THEN KernelLog.String("Performing offline search. Search string: "); KernelLog.String(string); KernelLog.Ln(); END;
			NEW(Result, currentFolder.messages.GetCount());
			FOR i := 0 TO currentFolder.messages.GetCount()-1 BY 1 DO
				Result[i] := TRUE;
			END;
			NEW(reader, IMAPUtilities.StringLength(string)+1);
			reader.SetRaw(string, 0, IMAPUtilities.StringLength(string));
			NEW(command, IMAPUtilities.StringLength(string)+1);
			reader.SkipWhitespace();
			WHILE reader.Available() > 0 DO
				reader.Token(command^);
				CheckCommand(command^);
				reader.SkipWhitespace();
			END;

			count := 0;
			FOR i := 0 TO LEN(Result)-1 BY 1 DO
				IF Result[i] THEN
					INC(count);
				END;
			END;
			NEW(searchResult, count);
			count := 0;
			FOR i := 0 TO LEN(Result) - 1 BY 1 DO
				IF Result[i] THEN
					searchResult[count] := i;
					INC(count);
				END;
			END;
			applySearchFilter := TRUE;
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN LEN(searchResult);
		END OfflineSearch;

		PROCEDURE Save*(VAR doc: XML.Document): LONGINT;
		VAR
			element, sub: XML.Element;

			buf: Strings.Buffer;
			w: Streams.Writer;
		BEGIN {EXCLUSIVE}
			IF DEBUG THEN KernelLog.String("Starting Save"); KernelLog.Ln(); END;
			IF (status # ONLINE) & (status # OFFLINE) THEN
				CallErrorHandler("An error happend while trying to save the account. The Client is disconnected.");
				RETURN ERROR;
			END;
			currentWork := CWSAVINGACCOUNT;
			NEW(doc);
			NEW(element);
			NEW(sub);
			NEW(buf, 16);
			w := buf.GetWriter();
			element.SetName("account");
			doc.AddContent(element);

			SavePreferences(element);

			ExtractMailboxContent(mailboxContent, element);
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN OK;
		END Save;

		PROCEDURE SavePreferences(element: XML.Element);
		VAR
			pref, sub: XML.Element;
			cdata: XML.CDataSect;
			value: String;

			PROCEDURE GetBoolean(b: BOOLEAN);
			BEGIN
				IF b THEN value := Strings.NewString("TRUE"); ELSE value := Strings.NewString("FALSE"); END;
			END GetBoolean;

		BEGIN
			NEW(pref); pref.SetName("preferences");

			NEW(sub); sub.SetName("IMAPServer");
			NEW(cdata); cdata.SetStr(preferences.IMAPServer^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("UserName");
			NEW(cdata); cdata.SetStr(preferences.UserName^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("SMTPServer");
			NEW(cdata); cdata.SetStr(preferences.SMTPServer^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("SMTPThisHost");
			NEW(cdata); cdata.SetStr(preferences.SMTPThisHost^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("SentFolder");
			NEW(cdata); cdata.SetStr(preferences.SentFolder^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("DraftFolder");
			NEW(cdata); cdata.SetStr(preferences.DraftFolder^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("TrashBin");
			NEW(cdata); cdata.SetStr(preferences.TrashBin^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("From");
			NEW(cdata); cdata.SetStr(preferences.From^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("ExpungeOnFolderChange");
			GetBoolean(preferences.ExpungeOnFolderChange);
			NEW(cdata); cdata.SetStr(value^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("ExpungeOnDelete");
			GetBoolean(preferences.ExpungeOnDelete);
			NEW(cdata); cdata.SetStr(value^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("UseDragNDropAsMove");
			GetBoolean(preferences.UseDragNDropAsMove);
			NEW(cdata); cdata.SetStr(value^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("ExpungeOnMove");
			GetBoolean(preferences.ExpungeOnMove);
			NEW(cdata); cdata.SetStr(value^);
			sub.AddContent(cdata); pref.AddContent(sub);

			NEW(sub); sub.SetName("UseATrashBin");
			GetBoolean(preferences.UseATrashBin);
			NEW(cdata); cdata.SetStr(value^);
			sub.AddContent(cdata); pref.AddContent(sub);

			element.AddContent(pref)
		END SavePreferences;

		PROCEDURE ExtractMailboxContent(folder: Folder; element: XML.Element);
		VAR
			att: XML.Attribute;
			string: ARRAY 30 OF CHAR;
			sub, subSub: XML.Element;
			subFolders: Classes.List;
			subFolderP, messageP, addressP: ANY;
			subFolder: Folder;

			address: IMAPUtilities.Address;
			messages: Classes.List;
			message: Message;
			cdata: XML.CDataSect;
			i: LONGINT;

			PROCEDURE ExtractAddresses(addresses: Classes.List; CONST tag: ARRAY OF CHAR);
			VAR
				i: LONGINT;
				part: XML.Element;
			BEGIN
				i := 0;
				IF addresses # NIL THEN
					WHILE i < addresses.GetCount() DO
						addressP := addresses.GetItem(i);
						address := addressP(IMAPUtilities.Address);
						NEW(subSub);
						subSub.SetName(tag);
						NEW(part); part.SetName("realName");
						NEW(cdata); cdata.SetStr(address.realName^); subSub.AddContent(part); part.AddContent(cdata);
						NEW(part); part.SetName("namePart");
						NEW(cdata); cdata.SetStr(address.namePart^); subSub.AddContent(part); part.AddContent(cdata);
						NEW(part); part.SetName("domainPart");
						NEW(cdata); cdata.SetStr(address.domainPart^); subSub.AddContent(part); part.AddContent(cdata);
						sub.AddContent(subSub);
						INC(i);
					END;
				END;
			END ExtractAddresses;

		BEGIN
			subFolders := folder.children;
			i := 0;
			WHILE i < subFolders.GetCount() DO
				subFolderP := subFolders.GetItem(i);
				subFolder := subFolderP(Folder);
				IF DEBUG THEN KernelLog.String("In ExtractMailboxContent: subfolder: "); KernelLog.String(subFolder.name^); KernelLog.Ln(); END;
				NEW(sub);
				sub.SetName("folder");
				NEW(subSub); subSub.SetName("name");
				NEW(cdata); cdata.SetStr(subFolder.name^); sub.AddContent(subSub); subSub.AddContent(cdata);
				NEW(subSub); subSub.SetName("hierarchyDelimiter");
				string[0] := subFolder.hierarchyDelimiter; string[1] := 0X;
				NEW(cdata); cdata.SetStr(string); sub.AddContent(subSub); subSub.AddContent(cdata);
				ExtractMailboxContent(subFolder, sub);
				element.AddContent(sub);
				INC(i);
			END;

			messages := folder.messages;
			i := 0;
			WHILE i < messages.GetCount() DO
				IF DEBUG THEN KernelLog.String("In ExtractMailboxContent: message "); KernelLog.Ln(); END;
				messageP := messages.GetItem(i);
				message := messageP(Message);
				NEW(sub);
				sub.SetName("message");

				IF message.header # NIL THEN
					NEW(subSub); subSub.SetName("date"); sub.AddContent(subSub);
					NEW(cdata); cdata.SetStr(message.header.date^); subSub.AddContent(cdata);
					NEW(subSub); subSub.SetName("subject"); sub.AddContent(subSub);
					NEW(cdata); cdata.SetStr(message.header.subject^); subSub.AddContent(cdata);
					NEW(subSub); subSub.SetName("inReplyTo"); sub.AddContent(subSub);
					NEW(cdata); cdata.SetStr(message.header.inReplyTo^); subSub.AddContent(cdata);
					NEW(subSub); subSub.SetName("messageID"); sub.AddContent(subSub);
					NEW(cdata); cdata.SetStr(message.header.messageID^); subSub.AddContent(cdata);
					NEW(subSub); subSub.SetName("internalDate"); sub.AddContent(subSub);
					NEW(cdata); cdata.SetStr(message.internalDate^); subSub.AddContent(cdata);
					NEW(att); string := "size"; att.SetName(string); Strings.IntToStr(message.size, string); att.SetValue(string); sub.AddAttribute(att);
					NEW(att); string := "uid"; att.SetName(string); Strings.IntToStr(message.uID, string); att.SetValue(string); sub.AddAttribute(att);
					NEW(att); string := "Answered"; att.SetName(string); IF message.flags.answered THEN string := "TRUE" ELSE string := "FALSE" END; att.SetValue(string); sub.AddAttribute(att);
					NEW(att); string := "Flagged"; att.SetName(string); IF message.flags.flagged THEN string := "TRUE" ELSE string := "FALSE" END; att.SetValue(string); sub.AddAttribute(att);
					NEW(att); string := "Deleted"; att.SetName(string); IF message.flags.deleted THEN string := "TRUE" ELSE string := "FALSE" END; att.SetValue(string); sub.AddAttribute(att);
					NEW(att); string := "Seen"; att.SetName(string); IF message.flags.seen THEN string := "TRUE" ELSE string := "FALSE" END; att.SetValue(string); sub.AddAttribute(att);
					NEW(att); string := "Recent"; att.SetName(string); IF message.flags.recent THEN string := "TRUE" ELSE string := "FALSE" END; att.SetValue(string); sub.AddAttribute(att);
					NEW(att); string := "Draft"; att.SetName(string); IF message.flags.draft THEN string := "TRUE" ELSE string := "FALSE" END; att.SetValue(string); sub.AddAttribute(att);
					ExtractAddresses(message.header.from, "from");
					ExtractAddresses(message.header.sender, "sender");
					ExtractAddresses(message.header.replyTo, "replyTo");
					ExtractAddresses(message.header.to, "to");
					ExtractAddresses(message.header.cc, "cc");
					ExtractAddresses(message.header.bcc, "bcc");

					IF message.message # NIL THEN
						NEW(subSub); subSub.SetName("text"); sub.AddContent(subSub);
						NEW(cdata); cdata.SetStr(message.message^); subSub.AddContent(cdata);
					END;

					IF message.bodystructure # NIL THEN
						NEW(subSub); subSub.SetName("bodystructureType"); sub.AddContent(subSub);
						NEW(cdata); cdata.SetStr(message.bodystructure.type); subSub.AddContent(cdata);
						NEW(subSub); subSub.SetName("bodystructureSubType"); sub.AddContent(subSub);
						NEW(cdata); cdata.SetStr(message.bodystructure.subtype); subSub.AddContent(cdata);
						NEW(subSub); subSub.SetName("bodystructureEncoding"); sub.AddContent(subSub);
						NEW(cdata); cdata.SetStr(message.bodystructure.encoding); subSub.AddContent(cdata);
						NEW(subSub); subSub.SetName("bodystructureCharset"); sub.AddContent(subSub);
						NEW(cdata); cdata.SetStr(message.bodystructure.charset); subSub.AddContent(cdata);
					END;
					element.AddContent(sub);
				END;
				INC(i);
			END;
		END ExtractMailboxContent;

		PROCEDURE Load*(document:XML.Document): LONGINT;
		VAR
			buffer: Strings.Buffer;
			writer: Streams.Writer;
			string: String;
			i, r: LONGINT;
			element, subElement: XML.Element;
			subElements, subSubElements, data: XMLObjects.Enumerator;
			cdata: XML.CDataSect;
			elementP: ANY;
			folder: Folder;
		BEGIN {EXCLUSIVE}
			currentWork := CWLOADINGACCOUNT;
			status := OFFLINE;
			NEW(buffer,16);
			writer := buffer.GetWriter();
			IF document # NIL THEN
				element := document.GetRoot();
				string := element.GetName();
				IF ~Strings.Equal(string, Strings.NewString("account")) THEN
					CallErrorHandler("An error happend while trying to load an Account. The file is not compatible");
					currentWork := CWFINISHED;
					CallObserverMethod();
					RETURN ERROR;
				END;

				subElements := element.GetContents();
				WHILE subElements.HasMoreElements() DO
					elementP := subElements.GetNext();
					subElement := elementP(XML.Element);
					string := subElement.GetName();
					IF string^ = "preferences" THEN
						r := LoadPreferences(subElement);
						IF r # OK THEN
							CallErrorHandler("An error happend while trying to load the Preferences");
							currentWork := CWFINISHED;
							RETURN r;
						END;

					ELSIF string^ = "folder" THEN
						subSubElements := subElement.GetContents();
						(* get name *)
						elementP := subSubElements.GetNext();
						element := elementP(XML.Element);
						data := element.GetContents();
						elementP := data.GetNext();
						cdata := elementP(XML.CDataSect);
						string := cdata.GetStr();

						NEW(folder, string^);

						(* get hierarchyDelimiter *)
						elementP := subSubElements.GetNext();
						element := elementP(XML.Element);
						data := element.GetContents();
						elementP := data.GetNext();
						cdata := elementP(XML.CDataSect);
						string := cdata.GetStr();

						folder.hierarchyDelimiter := string^[0];
						folder.parent := mailboxContent;
						mailboxContent.children.Add(folder);

						r := InsertMailboxContent(folder, subElement);
						IF r # OK THEN
							currentWork := CWFINISHED;
							RETURN r;
						END;
						currentFolder := mailboxContent;

					END;
				END;

				i := mailboxContent.children.GetCount();
				IF DEBUG THEN KernelLog.String("Reading File successful"); KernelLog.Ln(); END;
			ELSE
				CallErrorHandler("Reading failed");
				currentWork := CWFINISHED;
				RETURN ERROR;
			END;
			currentWork := CWFINISHED;
			CallObserverMethod();
			RETURN OK;
		END Load;

		PROCEDURE LoadPreferences(element: XML.Element): LONGINT;
		VAR
			subElements, data: XMLObjects.Enumerator;
			subElement: XML.Element;
			cdata: XML.CDataSect;
			p: ANY;
			string, value: String;

			PROCEDURE GetBoolean(): BOOLEAN;
			BEGIN
				value := cdata.GetStr();
				IF value^ = "TRUE" THEN RETURN TRUE; ELSE RETURN FALSE; END;
			END GetBoolean;

		BEGIN
			IF DEBUG THEN KernelLog.String("In LoadPreferences"); KernelLog.Ln(); END;
			subElements := element.GetContents();
			WHILE subElements.HasMoreElements() DO
				p := subElements.GetNext();
				subElement := p(XML.Element);
				string := subElement.GetName();
				data := subElement.GetContents();
				p := data.GetNext();
				cdata := p(XML.CDataSect);

				IF string^ = "IMAPServer" THEN
					preferences.IMAPServer := cdata.GetStr();
				ELSIF string^ = "UserName" THEN
					preferences.UserName := cdata.GetStr();
				ELSIF string^ = "SMTPServer" THEN
					preferences.SMTPServer := cdata.GetStr();
				ELSIF string^ = "SMTPThisHost" THEN
					preferences.SMTPThisHost := cdata.GetStr();
				ELSIF string^ = "ExpungeOnFolderChange" THEN
					preferences.ExpungeOnFolderChange := GetBoolean();
				ELSIF string^ = "ExpungeOnDelete" THEN
					preferences.ExpungeOnDelete := GetBoolean();
				ELSIF string^ = "UseDragNDropAsMove" THEN
					preferences.UseDragNDropAsMove := GetBoolean();
				ELSIF string^ = "ExpungeOnMove" THEN
					preferences.ExpungeOnMove := GetBoolean();
				ELSIF string^ = "UseATrashBin" THEN
					preferences.UseATrashBin := GetBoolean();
				ELSIF string^ = "SentFolder" THEN
					preferences.SentFolder := cdata.GetStr();
				ELSIF string^ = "DraftFolder" THEN
					preferences.DraftFolder := cdata.GetStr();
				ELSIF string^ = "TrashBin" THEN
					preferences.TrashBin := cdata.GetStr();
				ELSIF string^ = "From" THEN
					preferences.From := cdata.GetStr();
				ELSE
					CallErrorHandler("Invalid name for an XML Element detected");
					CallErrorHandler(string^);
					RETURN ERROR;
				END;
			END;
			RETURN OK;
		END LoadPreferences;

		PROCEDURE InsertMailboxContent(folder: Folder; element: XML.Element): LONGINT;
		VAR
			subElements, messageElements, data: XMLObjects.Enumerator;
			elementP: ANY;
			subElem, messageElement: XML.Element;
			cdata: XML.CDataSect;
			address: IMAPUtilities.Address;
			elementName, string: String;
			subFolder: Folder;
			message: Message;
			header: HeaderElement;
			flag : Flags;
			i, r: LONGINT;

			PROCEDURE GetAddress(element: XML.Element): IMAPUtilities.Address;
			VAR
				addressParts: XMLObjects.Enumerator;
				part: XML.Element;
				address: IMAPUtilities.Address;
				i: LONGINT;
			BEGIN
				NEW(address);
				addressParts := element.GetContents();
				FOR i := 0 TO 2 DO
					elementP := addressParts.GetNext();
					part := elementP(XML.Element);
					data := part.GetContents();
					elementP := data.GetNext();
					cdata := elementP(XML.CDataSect);
					IF i = 0 THEN address.realName := cdata.GetStr();
					ELSIF i = 1 THEN address.namePart := cdata.GetStr();
					ELSIF i = 2 THEN address.domainPart := cdata.GetStr();
					END;
				END;
				RETURN address;
			END GetAddress;

		BEGIN
			subElements := element.GetContents();
			WHILE subElements.HasMoreElements() DO
				elementP := subElements.GetNext();
				subElem := elementP(XML.Element);
				elementName := subElem.GetName();
				IF elementName^ = "name" THEN
					data := subElem.GetContents();
					elementP := data.GetNext();
					cdata := elementP(XML.CDataSect);
					folder.name := cdata.GetStr();
				ELSIF elementName^ = "hierarchyDelimiter" THEN
					data := subElem.GetContents();
					elementP := data.GetNext();
					cdata := elementP(XML.CDataSect);
					string := cdata.GetStr();
					folder.hierarchyDelimiter := string^[0];
				ELSIF elementName^ = "folder" THEN
					(* create the subFolder *)
					NEW(subFolder, "temp"); (* will be overwritten when calling InsertMailboxContent recursivly *)
					subFolder.parent := folder;
					folder.children.Add(subFolder);

					r := InsertMailboxContent(subFolder, subElem);
					IF r # OK THEN
						currentWork := CWFINISHED;
						RETURN ERROR;
					END;
				ELSIF elementName^ =  "message" THEN
					NEW(message);
					NEW(header);
					message.header := header;
					NEW(message.header.from);
					NEW(message.header.sender);
					NEW(message.header.replyTo);
					NEW(message.header.to);
					NEW(message.header.cc);
					NEW(message.header.bcc);
					messageElements := subElem.GetContents();
					WHILE messageElements.HasMoreElements() DO
						elementP := messageElements.GetNext();
						messageElement := elementP(XML.Element);
						elementName := messageElement.GetName();
						IF (elementName^ = "date") OR (elementName^ = "subject") OR (elementName^ = "inReplyTo") OR (elementName^ = "messageID") OR (elementName^ = "internalDate") OR (elementName^ = "text") OR (elementName^ = "bodystructureType") OR (elementName^ = "bodystructureSubType") OR (elementName^ = "bodystructureEncoding") OR (elementName^ = "bodystructureCharset")  THEN
							data := messageElement.GetContents();
							elementP := data.GetNext();
							cdata := elementP(XML.CDataSect);
							IF elementName^ = "date" THEN
								message.header.date := cdata.GetStr();
							ELSIF elementName^ = "subject" THEN
								message.header.subject := cdata.GetStr();
							ELSIF elementName^ = "inReplyTo" THEN
								message.header.inReplyTo := cdata.GetStr();
							ELSIF elementName^ = "messageID" THEN
								message.header.messageID := cdata.GetStr();
							ELSIF elementName^ = "internalDate" THEN
								message.internalDate := cdata.GetStr();
							ELSIF elementName^ = "size" THEN
								string := cdata.GetStr();
								Strings.StrToInt(string^, message.size);
							ELSIF elementName^ = "uid" THEN
								string := cdata.GetStr();
								Strings.StrToInt(string^, message.uID);
							ELSIF elementName^ = "text" THEN
								message.message := cdata.GetStr();
							ELSIF elementName^ = "bodystructureType" THEN
								IF message.bodystructure = NIL THEN
									NEW(message.bodystructure);
								END;
								string := cdata.GetStr();
								IMAPUtilities.StringCopy(string^, 0, IMAPUtilities.StringLength(string^), message.bodystructure.type);
							ELSIF elementName^ = "bodystructureSubType" THEN
								IF message.bodystructure = NIL THEN
									NEW(message.bodystructure);
								END;
								string := cdata.GetStr();
								IMAPUtilities.StringCopy(string^, 0, IMAPUtilities.StringLength(string^), message.bodystructure.subtype);
							ELSIF elementName^ = "bodystructureEncoding" THEN
								IF message.bodystructure = NIL THEN
									NEW(message.bodystructure);
								END;
								string := cdata.GetStr();
								IMAPUtilities.StringCopy(string^, 0, IMAPUtilities.StringLength(string^), message.bodystructure.encoding);
							ELSIF elementName^ = "bodystructureCharset" THEN
								IF message.bodystructure = NIL THEN
									NEW(message.bodystructure);
								END;
								string := cdata.GetStr();
								IMAPUtilities.StringCopy(string^, 0, IMAPUtilities.StringLength(string^), message.bodystructure.charset);

							END;
						ELSIF (elementName^ = "from") OR (elementName^ = "sender") OR (elementName^ = "replyTo") OR (elementName^ = "to") OR (elementName^ = "cc") OR (elementName^ = "bcc") THEN
							address := GetAddress(messageElement);
							IF elementName^ = "from" THEN
								message.header.from.Add(address);
							ELSIF elementName^ = "sender" THEN
								message.header.sender.Add(address);
							ELSIF elementName^ = "replyTo" THEN
								message.header.replyTo.Add(address);
							ELSIF elementName^ = "to" THEN
								message.header.to.Add(address);
							ELSIF elementName^ = "cc" THEN
								message.header.cc.Add(address);
							ELSIF elementName^ = "bcc" THEN
								message.header.bcc.Add(address);
							END;
						ELSE
							CallErrorHandler("Invalid XML element name");
							RETURN ERROR;
						END;
					END;

					string := subElem.GetAttributeValue("size"); Strings.StrToInt(string^, i); message.size := i;
					string := subElem.GetAttributeValue("uid"); Strings.StrToInt(string^, i); message.uID := i;

					NEW(flag);
					string := subElem.GetAttributeValue("Answered"); IF string^ = "TRUE" THEN flag.answered := TRUE; ELSE flag.answered := FALSE; END;
					string := subElem.GetAttributeValue("Flagged"); IF string^ = "TRUE" THEN flag.flagged := TRUE; ELSE flag.flagged := FALSE; END;
					string := subElem.GetAttributeValue("Deleted"); IF string^ = "TRUE" THEN flag.deleted := TRUE; ELSE flag.deleted := FALSE; END;
					string := subElem.GetAttributeValue("Seen"); IF string^ = "TRUE" THEN flag.seen := TRUE; ELSE flag.seen := FALSE; END;
					string := subElem.GetAttributeValue("Recent"); IF string^ = "TRUE" THEN flag.recent := TRUE; ELSE flag.recent := FALSE; END;
					string := subElem.GetAttributeValue("Draft"); IF string^ = "TRUE" THEN flag.draft := TRUE; ELSE flag.draft := FALSE; END;
					message.flags := flag;

					folder.messages.Add(message);
				END;
			END;
			RETURN OK;
		END InsertMailboxContent;


	BEGIN {ACTIVE} (* keepalive *)
		NEW(timer);
		WHILE status # DEAD DO
			timer.Sleep(KEEPALIVE);
			BEGIN {EXCLUSIVE}
				IF status = ONLINE THEN
					IF Task = TLoadAllMessages THEN
						currentWork := CWLOADING;
						globalR := DownloadAllMessages();
					ELSE
						IF FolderIsSynchronized OR abort OR userAbort THEN
							currentWork := CWPOLLING;
							globalR := Update();
						END;
						WHILE (~FolderIsSynchronized) & (~abort) & (~userAbort) DO
							currentWork := CWLOADING;
							globalR := Synchronize();
						END;
					END;
					currentWork := CWFINISHED;

				END; (* IF *)
				CallObserverMethod();
			END (* EXCLUSIVE *);
		END (* WHILE *);
		IF DEBUG THEN KernelLog.String("Client Activitiy finished"); KernelLog.Ln(); END;

	END Client;

	Folder* = OBJECT
	VAR
		name*: String;
		path*: String;
		hierarchyDelimiter*: CHAR;
		parent*: Folder;
		children*: Classes.List;
		Noinferiors*: BOOLEAN;
		Noselect*: BOOLEAN;
		Marked*: BOOLEAN;
		Unmarked*: BOOLEAN;
		messages*: Classes.List;
		alive: BOOLEAN;


		PROCEDURE &Init*(n: ARRAY OF CHAR);
		BEGIN
			NEW(name,IMAPUtilities.StringLength(n)+1 );
			IMAPUtilities.StringCopy(n,0, IMAPUtilities.StringLength(n), name^);
			NEW(path,1);
			path^[0] := 0X;
			hierarchyDelimiter := 0X;
			parent := NIL;
			NEW(children);
			Noinferiors := FALSE;
			Noselect := FALSE;
			Marked := FALSE;
			Unmarked := FALSE;
			NEW(messages);
			alive := TRUE;
		END Init;

		PROCEDURE FindSubFolder(CONST n: ARRAY OF CHAR): Folder;
		VAR
			i: LONGINT;
			sub: Folder;
			p: ANY;
		BEGIN
			i := 0;
			WHILE i < children.GetCount() DO
				p := children.GetItem(i);
				sub := p (Folder);
				IF sub.name^ = n THEN
					RETURN sub;
				END;
				INC(i);
			END;
			RETURN NIL;
		END FindSubFolder;


		(* Returns the Path including the folder name as a String *)
		PROCEDURE GetPath*(): String;
		VAR
			path: String;
			pathLen, nameLen: LONGINT;
		BEGIN
			pathLen := IMAPUtilities.StringLength(SELF.path^);
			nameLen := IMAPUtilities.StringLength(SELF.name^);
			IF pathLen = 0 THEN
				path := IMAPUtilities.NewString(SELF.name^);
			ELSE
				NEW(path, pathLen + nameLen + 2);
				IMAPUtilities.StringCopy(SELF.path^, 0, pathLen, path^);
				path^[pathLen] := SELF.hierarchyDelimiter;
				path^[pathLen+1] := 0X;
				Strings.Append(path^, SELF.name^);
			END;
			RETURN path;
		END GetPath;

	END Folder;


	HeaderElement* = POINTER TO RECORD (** according to RFC 2060 *)
		date*: String;
		subject*: String;
		from*: Classes.List; (** of Address *)
		sender*: Classes.List; (** of Address *)
		replyTo*: Classes.List; (** of Address *)
		to*: Classes.List; (** of Address *)
		cc*: Classes.List; (** of Address *)
		bcc*: Classes.List; (** of Address *)
		inReplyTo*: String;
		messageID*: String;
	END;

	Flags* = OBJECT
	VAR
		answered*: BOOLEAN;
		flagged*: BOOLEAN;
		deleted*: BOOLEAN;
		seen*: BOOLEAN;
		recent*: BOOLEAN;
		draft*: BOOLEAN;


		PROCEDURE Clear*;
		BEGIN
			answered := FALSE;
			flagged := FALSE;
			deleted := FALSE;
			seen := FALSE;
			recent := FALSE;
			draft := FALSE;
		END Clear;


		(* import list of flags *)
		PROCEDURE ParseList*(list: Classes.List);
		VAR
			i: LONGINT;
			ent: IMAP.Entry;
			entP: ANY;
		BEGIN
			Clear; (* reset structure *)
			FOR i :=  0 TO list.GetCount() - 1 DO
				entP := list.GetItem(i); ent := entP(IMAP.Entry);
				IMAPUtilities.UpperCase(ent.data^);
				IF ent.data^ = "\ANSWERED" THEN answered := TRUE END;
				IF ent.data^ = "\FLAGGED" THEN flagged := TRUE END;
				IF ent.data^ = "\DELETED" THEN deleted := TRUE END;
				IF ent.data^ = "\SEEN" THEN seen := TRUE END;
				IF ent.data^ = "\RECENT" THEN recent := TRUE END;
				IF ent.data^ = "\DRAFT" THEN draft := TRUE END
			END
		END ParseList;

		PROCEDURE ToString*(VAR string: ARRAY OF CHAR);
		BEGIN
			string[0] := 0X;
			IF answered THEN Strings.Append(string, "A"); ELSE  Strings.Append(string, "-") END;
			IF flagged THEN Strings.Append(string, "F"); ELSE  Strings.Append(string, "-") END;
			IF deleted THEN Strings.Append(string, "D"); ELSE  Strings.Append(string, "-") END;
			IF seen THEN Strings.Append(string, "-"); ELSE  Strings.Append(string, "N") END;
			IF recent THEN Strings.Append(string, "R"); ELSE  Strings.Append(string, "-") END;
			IF draft THEN Strings.Append(string, "S"); ELSE  Strings.Append(string, "-") END
		END ToString;
	END Flags;


	Bodystructure* = POINTER TO RECORD
		type* : ARRAY 32 OF CHAR;
		subtype* : ARRAY 32 OF CHAR;
		encoding* : ARRAY 32 OF CHAR;
		charset*: ARRAY 32 OF CHAR;
		subpart* : Classes.List (* of type Bodystructure *)
	END;

	AccountPreferences* = OBJECT
	VAR
		IMAPServer*: String;
		UserName*: String;
		SMTPServer*: String;
		SMTPThisHost*: String;
		ExpungeOnFolderChange*: BOOLEAN; (* specifies if an expunge or close command is called before another folder is selected *)
		ExpungeOnDelete*: BOOLEAN; (* specifies if a message gets expunged directly when deleting it *)
		UseDragNDropAsMove*: BOOLEAN; (* on drag'n'drop the source is deleted. i.e the Messages are moved. Otherwise they are copied*)
		ExpungeOnMove*: BOOLEAN; (* specifies if an expunge command is called after the Move Operation. *)
		UseATrashBin*: BOOLEAN; (* specifies if deleted Messages are move to a trash bin *)
		SentFolder*: String; (* specifies in which folder to store the sent Messages *)
		DraftFolder*: String; (* specifies in which folder to store the draft Messages *)
		TrashBin*: String; (* specifies in which folder to move the deleted Messages. *)
		From *: String; (* specifies the From Field that is used when sending Messages *)

		PROCEDURE &New*;
		BEGIN
			IMAPServer := Strings.NewString("");
			UserName := Strings.NewString("");
			SMTPServer := Strings.NewString("");
			SMTPThisHost := Strings.NewString("");
			SentFolder := Strings.NewString("");
			DraftFolder := Strings.NewString("");
			TrashBin := Strings.NewString("");
			From := Strings.NewString("");
		END New;

		PROCEDURE LoadStandardConfig;
		VAR
			config : XML.Element;
			enum: XMLObjects.Enumerator;
			p: ANY;
			e: XML.Element;
			name, value: XML.String;

			PROCEDURE GetBoolean(): BOOLEAN;
			BEGIN
				IF value^ = "TRUE" THEN RETURN TRUE; ELSE RETURN FALSE; END;
			END GetBoolean;

		BEGIN
			IF DEBUG THEN KernelLog.String("In LoadStandardConfig"); KernelLog.Ln(); END;
			config := Configuration.GetSection("Applications.MailClient");
			IF config # NIL THEN
				enum := config.GetContents();
				WHILE enum.HasMoreElements() DO
					p := enum.GetNext();
					IF p IS XML.Element THEN
						e := p(XML.Element);
						name := e.GetAttributeValue("name");
						value := e.GetAttributeValue("value");

						IF name^ = "IMAPServer" THEN
							IMAPServer := value;
						ELSIF name^ = "UserName" THEN
							UserName := value;
						ELSIF name^ = "SMTPServer" THEN
							SMTPServer := value;
						ELSIF name^ = "SMTPThisHost" THEN
							SMTPThisHost := value;
						ELSIF name^ = "ExpungeOnFolderChange" THEN
							ExpungeOnFolderChange := GetBoolean();
						ELSIF name^ = "ExpungeOnDelete" THEN
							ExpungeOnDelete := GetBoolean();
						ELSIF name^ = "UseDragNDropAsMove" THEN
							UseDragNDropAsMove := GetBoolean();
						ELSIF name^ = "ExpungeOnMove" THEN
							ExpungeOnMove := GetBoolean();
						ELSIF name^ = "UseATrashBin" THEN
							UseATrashBin := GetBoolean();
						ELSIF name^ = "SentFolder" THEN
							SentFolder := value;
						ELSIF name^ = "DraftFolder" THEN
							DraftFolder := value;
						ELSIF name^ = "TrashBin" THEN
							TrashBin := value;
						ELSIF name^ = "From" THEN
							From := value;
						ELSE
							IF DEBUG THEN KernelLog.String("Unknown Setting in Configuration.XML Section: IMAP Setting: "); KernelLog.String(name^); KernelLog.Ln(); END;
						END;
					END;
				END;
			END;
		END LoadStandardConfig;

	END AccountPreferences;

	Date* = OBJECT
	VAR
		day, month, year: LONGINT;

		(* Returns TRUE if this date is equal to otherDate *)
		PROCEDURE Equal*(otherDate: Date): BOOLEAN;
		BEGIN
			RETURN (otherDate.day = day) & (otherDate.month = month) & (otherDate.year = year);
		END Equal;

		(* Returns TRUE if this date is before otherDate *)
		PROCEDURE Before*(otherDate: Date): BOOLEAN;
		BEGIN
			IF year < otherDate.year THEN
				RETURN TRUE;
			ELSIF otherDate.year < year THEN
				RETURN FALSE;
			END;
			IF month < otherDate.month THEN
				RETURN TRUE;
			ELSIF otherDate.month < month THEN
				RETURN FALSE;
			END;
			IF day < otherDate.day THEN
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END Before;

		PROCEDURE FromInternalDate(string: String);
		VAR
			d: ARRAY 3 OF CHAR;
			m: ARRAY 4 OF CHAR;
			y: ARRAY 5 OF CHAR;
		BEGIN
			IF string^[1] = "-" THEN
				Strings.Copy(string^, 0,1, d);
				Strings.Copy(string^, 2, 3, m);
				Strings.Copy(string^, 6, 4, y);
			ELSIF string^[2] = "-" THEN
				IF string^[0] = " " THEN
					Strings.Copy(string^, 1, 1, d);
				ELSE
					Strings.Copy(string^, 0, 2, d);
				END;
				Strings.Copy(string^, 3, 3, m);
				Strings.Copy(string^, 7, 4, y);
			ELSE

			END;
			Strings.StrToInt(d, day);
			IF m = "Jan" THEN
				month := 1;
			ELSIF m = "Feb" THEN
				month := 2;
			ELSIF m = "Mar" THEN
				month := 3;
			ELSIF m = "Apr" THEN
				month := 4;
			ELSIF m = "May" THEN
				month := 5;
			ELSIF m = "Jun" THEN
				month := 6;
			ELSIF m = "Jul" THEN
				month := 7;
			ELSIF m = "Aug" THEN
				month := 8;
			ELSIF m = "Sep" THEN
				month := 9;
			ELSIF m = "Oct" THEN
				month := 10;
			ELSIF m = "Nov" THEN
				month := 11;
			ELSIF m = "Dec" THEN
				month := 12;
			END;
			Strings.StrToInt(y, year);
		END FromInternalDate;

	END Date;

	Time *= OBJECT
	VAR
		hour, minute, second: LONGINT;

		(* Returns TRUE if this time is equal to otherTime *)
		PROCEDURE Equal*(otherTime: Time): BOOLEAN;
		BEGIN
			RETURN (otherTime.hour = hour) & (otherTime.minute = minute) & (otherTime.second = second);
		END Equal;

		(* Returns TRUE if this time is before otherTime *)
		PROCEDURE Before*(otherTime: Time): BOOLEAN;
		BEGIN
			IF hour < otherTime.hour THEN
				RETURN TRUE;
			ELSIF otherTime.hour < hour THEN
				RETURN FALSE;
			END;
			IF minute < otherTime.minute THEN
				RETURN TRUE;
			ELSIF otherTime.minute < minute THEN
				RETURN FALSE;
			END;
			IF second < otherTime.second THEN
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END Before;

		PROCEDURE FromInternalDate(string: String);
		VAR
			h, m, s: ARRAY 3 OF CHAR;
			str: String;
		BEGIN
			str := string;
			Strings.Copy(string^, 12, 2, h);
			Strings.Copy(string^, 15, 2, m);
			Strings.Copy(string^, 18, 2, s);
			Strings.StrToInt(h, hour);
			Strings.StrToInt(m, minute);
			Strings.StrToInt(s, second);
		END FromInternalDate;

	END Time;

	DateTime *= OBJECT
	VAR
		time: Time;
		date: Date;

		PROCEDURE &New*;
		BEGIN
			NEW(time);
			NEW(date);
		END New;

		(* Returns TRUE if this DateTime is equal to otherDateTime *)
		PROCEDURE Equal*(otherDateTime: DateTime): BOOLEAN;
		BEGIN
			RETURN date.Equal(otherDateTime.date) & time.Equal(otherDateTime.time);
		END Equal;

		(* Returns TRUE if this DateTime is before otherDateTime *)
		PROCEDURE Before*(otherDateTime:DateTime): BOOLEAN;
		BEGIN
			IF date.Before(otherDateTime.date) THEN
				RETURN TRUE;
			ELSIF otherDateTime.date.Before(date) THEN
				RETURN FALSE;
			ELSE
				IF time.Before(otherDateTime.time) THEN
					RETURN TRUE;
				ELSE
					RETURN FALSE;
				END;
			END;
		END Before;

		PROCEDURE FromInternalDate*(string: String);
		BEGIN
			time.FromInternalDate(string);
			date.FromInternalDate(string);
		END FromInternalDate;

	END DateTime;


	(* defines the ordering of the Messages of a Mailbox as oldest first *)
	PROCEDURE OldestFirst*(x,y: ANY): LONGINT;
	VAR
		m1, m2: Message;
		h1, h2: HeaderElement;
		dt1, dt2: DateTime;
	BEGIN
		m1 := x(Message);
		m2 := y(Message);
		h1 := m1.header;
		h2 := m2.header;
		IF h1 = NIL THEN
			RETURN 1;
		END;
		IF h2 = NIL THEN
			RETURN -1;
		END;
		IF (m1.internalDate = NIL) OR (m1.internalDate^ = "") THEN
			RETURN 1;
		END;
		IF (m2.internalDate = NIL) OR (m2.internalDate^ = "") THEN
			RETURN -1;
		END;
		NEW(dt1); NEW(dt2);
		dt1.FromInternalDate(m1.internalDate);
		dt2.FromInternalDate(m2.internalDate);

		IF dt1.Equal(dt2) THEN RETURN 0; END;

		IF dt1.Before(dt2) THEN
			RETURN 1;
		ELSE
			RETURN -1;
		END;
	END OldestFirst;

	PROCEDURE BiggestUIDFirst*(x,y: ANY): LONGINT;
	VAR
		m1, m2: Message;
		h1, h2: HeaderElement;

	BEGIN
		m1 := x(Message);
		m2 := y(Message);
		h1 := m1.header;
		h2 := m2.header;
		IF h1 = NIL THEN
			RETURN 1;
		END;
		IF h2 = NIL THEN
			RETURN -1;
		END;
		IF m1.uID < m2.uID THEN
			RETURN 1;
		ELSE
			RETURN -1;
		END;

	END BiggestUIDFirst;

END IMAPClient.