(* Patrick Stuedi, 30.08.01 *)

MODULE RfsClientProxy; (** AUTHOR "pstuedi"; PURPOSE "Remote File System proxy"; *)

IMPORT  SYSTEM, RfsConnection, Files, Network, TCP, KernelLog, Streams;

CONST
	(*Server Procedures*)
	ERROR = 0;
	GETATTR = 1;
	SETATTR = 2;
	LOOKUP = 3;
	READ = 4;
	WRITE = 5;
	CREATE = 6;
	REMOVE = 8;
	RENAME = 10;
	READDIR = 11;
	CREATETMP = 12;
	CHDIR = 13;
	KILL = 14;
	AUTHENT = 15;

	(*Errorcodes*)
	REPLYOK* = 0;
	RECEIVERROR* = 1;
	PARAMERROR* = 2;
	CACHEMISS* = 3;
	GETATTRERROR* =  4;
	SETATTRERROR* = 5;
	NOFILE* = 6;
	READERROR* = 7;
	WRITEERROR* = 8;
	REMOVEERROR* = 9;
	RENAMEERROR* = 10;
	NODIR* = 11;
	AUTHENTICATIONERROR* = 12;

	HeaderLength = 100;
	Payload* = 16280;
	BufSize = Payload + HeaderLength;
	MaxNameLen = 64;
	DataOff = 8;
	Ok = TCP.Ok;
	DefaultPort = 9107;

(* Dummy Types for Files.Volume interface *)
TYPE
	Address* = LONGINT;



TYPE
	(** Type for storing Directory Information, used by RfsFS.Filesystem.Enumerate() **)
	Dir *= OBJECT
		VAR
			first*: Dirent;
			last*: Dirent;
			nbrOfEntrys*: LONGINT;

		PROCEDURE &Init*;
		BEGIN
			first := NIL;
			last := NIL;
			nbrOfEntrys := 0;
		END Init;

		(** insert tuple name, time, date and size. name is at offset off in Array **)
		PROCEDURE Insert*(VAR name: ARRAY OF CHAR; off, len, time, date, size: LONGINT);
			VAR entry: Dirent;
		BEGIN
			NEW(entry);
			CopyBuffer(name, off, entry.name, 0, len);
			entry.name[len] := 0X;
			entry.time := time;
			entry.date := date;
			entry.size := size;
			entry.next := NIL;

			IF last # NIL THEN
				last.next := entry;
				last := last.next;
			ELSE
				last := entry;
				first := last;
			END;

			INC(nbrOfEntrys);
		END Insert;

		(** Get next tuple from Object **)
		PROCEDURE Get*(VAR name: ARRAY OF CHAR; VAR time, date, size: LONGINT);
			VAR len: LONGINT;
		BEGIN
			IF first # NIL THEN
				len := Len(first.name);
				CopyBuffer(first.name, 0, name, 0, len);
				name[len] := 0X;
				time := first.time;
				date := first.date;
				size := first.size;
				DEC(nbrOfEntrys);
				first := first.next;
			END;
		END Get;

	END Dir;

TYPE
	(** Type of Dir Entry **)
	Dirent* = OBJECT
		VAR
			name: ARRAY MaxNameLen OF CHAR;
			time, date, size: LONGINT;
			next: Dirent;
	END Dirent;


TYPE
	(** Virtual Filesystem Object (Rfs File Protocoll), communicates via RfsRPC with rfsServerProxy on the serverside **)
	Proxy* = OBJECT (Files.Volume)
		VAR
			connection: RfsConnection.Connection;
			user, passwd, host, path: ARRAY MaxNameLen OF CHAR;
			port : INTEGER;
			buf, backupBuf: ARRAY BufSize OF CHAR;


		PROCEDURE &InitProxy*(VAR user, passwd, host, path: ARRAY OF CHAR; port: INTEGER);
			VAR lenHost, lenUser, lenPasswd, lenPath: LONGINT;
		BEGIN
			lenUser := Len(user);
			lenPasswd := Len(passwd);
			lenHost := Len(host);
			lenPath := Len(path);
			CopyBuffer(user, 0, SELF.user, 0, lenUser);
			CopyBuffer(passwd, 0, SELF.passwd, 0, lenPasswd);
			CopyBuffer(host, 0, SELF.host, 0, lenHost);
			CopyBuffer(path, 0, SELF.path, 0, lenPath);
			SELF.user[lenUser] := 0X;
			SELF.passwd[lenPasswd] := 0X;
			SELF.host[lenHost] := 0X;
			SELF.path[lenPath] := 0X;
			SELF.port := port;
			NEW(connection, host, port);
		END InitProxy;

		(** does nothing, just for benchmarking **)
		PROCEDURE Error*(VAR errorcode: LONGINT);
			VAR msgBytes, procID, testID, dataBytes, res, received: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := ERROR;
			dataBytes := 0;
			msgBytes := dataBytes + 8;
			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			connection.Send(buf, 0, msgBytes, res);

			(*receiving result*)
			GetResult(connection, errorcode, dataBytes, received, buf);

			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;
			connection.Close();
		END Error;

		(** retrieves fileLength, time and date of a file identified by fileID **)
		PROCEDURE GetAttr*(fileID: LONGINT; VAR fileLen, time, date, errorcode: LONGINT);
			VAR procID, testID, dataBytes, msgBytes, res, received: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := GETATTR;
			dataBytes := 8;
			msgBytes := dataBytes + 8;
			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(4, buf, DataOff);
			Int2Char(fileID, buf, DataOff + 4);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;

			IF errorcode # REPLYOK THEN
				fileLen := 0;
				time := 0;
				date := 0;
			ELSE
				Char2Int(buf, 0, fileLen);
				Char2Int(buf, 4, time);
				Char2Int(buf, 8, date);
			END;
		END GetAttr;

		(** Sets the attributes time and date of a file identified by filename **)
		PROCEDURE SetAttr*(VAR filename: ARRAY OF CHAR; time, date: LONGINT; VAR errorcode: LONGINT);
			VAR msgBytes, procID, testID, dataBytes, res, filenameLen, received: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := SETATTR;
			filenameLen := Len(filename);
			dataBytes := 12 + filenameLen;
			msgBytes := dataBytes + 8;
			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(time, buf, DataOff);
			Int2Char(date, buf, DataOff + 4);
			Int2Char(filenameLen, buf, DataOff + 8);
			CopyBuffer(filename, 0, buf, DataOff + 12, filenameLen);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;
		END SetAttr;

		(** transforms a filename into a fileID **)
		PROCEDURE Lookup*(VAR filename : ARRAY OF CHAR; VAR fileID, errorcode: LONGINT);
			VAR filenameLen, procID, testID, received, dataBytes, msgBytes, fileIDLen, res: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := LOOKUP;
			filenameLen := Len(filename);
			dataBytes := filenameLen + 4;
			msgBytes := dataBytes + 8;

			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(filenameLen, buf, DataOff);
			CopyBuffer(filename, 0, buf, DataOff + 4, filenameLen);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;

			IF errorcode # 0 THEN
				fileIDLen := 0;
				fileID := 0;
			ELSE
				Char2Int(buf, 0, fileIDLen);
				Char2Int(buf, 4, fileID);
			END;
		END Lookup;


		(** Reads len Bytes of data from a given offset off in a file identified by fileID and returns the data in buf at offset dstOff **)
		PROCEDURE Read*(fileID, off, len: LONGINT; VAR buffer: ARRAY OF CHAR; dstOff: LONGINT; VAR received, errorcode: LONGINT);
			VAR procID, testID, dataBytes, msgBytes, fileLen, res: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := READ;
			dataBytes := 16;
			msgBytes := dataBytes + 8;
			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(4, buf, DataOff);
			Int2Char(fileID, buf, DataOff + 4);
			Int2Char(off, buf, DataOff + 8);
			Int2Char(len, buf, DataOff + 12);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;

			IF errorcode # 0 THEN
				fileLen := 0;
				received := 0;
			ELSE
				Char2Int(buf, 0, fileLen);
				CopyBuffer(buf, 4, buffer, dstOff, fileLen);
				received := received -4;
			END;
		END Read;

		(** Writes len Bytes of data beginning off bytes from the beginning of file into a file identified by fileID **)
		PROCEDURE Write*(fileID, off, len: LONGINT; VAR buffer: ARRAY OF CHAR; VAR written, errorcode: LONGINT);
			VAR procID, testID, dataBytes, msgBytes, res, received: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := WRITE;
			dataBytes := 16 + len;
			msgBytes := dataBytes + 8;
			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(4, buf, DataOff);
			Int2Char(fileID, buf, DataOff + 4);
			Int2Char(off, buf, DataOff + 8);
			Int2Char(len, buf, DataOff + 12);
			CopyBuffer(buffer, 0, buf, DataOff + 16, len);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;

			IF errorcode # 0 THEN
				written := 0;
			ELSE
				Char2Int(buf, 0, written);
			END;
		END Write;

		(** Creates a file with name filename and return a fileID for it **)
		PROCEDURE Create*(VAR filename : ARRAY OF CHAR; VAR fileID, errorcode: LONGINT);
			VAR filenameLen, procID, testID, received, dataBytes, msgBytes, fileIDLen, res: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := CREATE;
			filenameLen := Len(filename);
			dataBytes := filenameLen + 4;
			msgBytes := dataBytes + 8;
			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(filenameLen, buf, DataOff);
			CopyBuffer(filename, 0, buf, DataOff + 4, filenameLen);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;

			IF errorcode # 0 THEN
				fileIDLen := 0;
				fileID := 0;
			ELSE
				Char2Int(buf, 0, fileIDLen);
				Char2Int(buf, 4, fileID);
			END;
		END Create;


		(** Deletes a File with name filename **)
		PROCEDURE Remove*(VAR filename : ARRAY OF CHAR; VAR errorcode: LONGINT);
			VAR filenameLen, procID, testID, received, dataBytes, msgBytes, res: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := REMOVE;
			filenameLen := Len(filename);
			dataBytes := filenameLen + 4;
			msgBytes := dataBytes + 8;

			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(filenameLen, buf, DataOff);
			CopyBuffer(filename, 0, buf, DataOff + 4, filenameLen);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;
		END Remove;

		(** Renames a file with name filenemFrom into a new name filenameTo **)
		PROCEDURE Rename*(VAR filenameFrom, filenameTo: ARRAY OF CHAR; VAR errorcode: LONGINT);
			VAR filenameLenFrom, filenameLenTo, procID, testID, received, dataBytes, msgBytes, res: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := RENAME;
			filenameLenFrom := Len(filenameFrom);
			filenameLenTo := Len(filenameTo);
			dataBytes := filenameLenFrom + filenameLenTo + 8;
			msgBytes := dataBytes + 8;
			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(filenameLenFrom, buf, DataOff);
			CopyBuffer(filenameFrom, 0, buf, DataOff + 4, filenameLenFrom);
			Int2Char(filenameLenTo, buf, DataOff + 4 + filenameLenFrom);
			CopyBuffer(filenameTo, 0, buf, DataOff + 4 + filenameLenFrom + 4, filenameLenTo);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;
		END Rename;


		(** Retrieves a variable number of entries with names matching the mask string from a directory identified by filename.
			  the detail is set to 1 if time, data and size information is also to be retrieved. the offset value tells how many entries
			  should be skip first **)
		PROCEDURE ReadDir*(VAR filename, mask : ARRAY OF CHAR; detail, cookie: LONGINT; dir: Dir; VAR endOfDir, errorcode: LONGINT);
			VAR filenameLen, procID, testID, received, dataBytes, msgBytes, currentIndex, maskLen, res, time, date, size: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := READDIR;
			filenameLen := Len(filename);
			maskLen := Len(mask);
			dataBytes := 4 + 4 + 4 + 4 + filenameLen + maskLen;
			msgBytes := dataBytes + 8;
			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(filenameLen, buf, DataOff);
			CopyBuffer(filename, 0, buf, DataOff + 4, filenameLen);
			Int2Char(maskLen, buf, DataOff + 4 + filenameLen);
			CopyBuffer(mask, 0, buf, DataOff + 8 + filenameLen, maskLen);
			Int2Char(detail, buf, DataOff + 8 + filenameLen + maskLen);
			Int2Char(cookie, buf, DataOff + 12 + filenameLen + maskLen);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;

			IF errorcode # 0 THEN
				endOfDir := 0;
				dir := NIL;
			ELSE
				Char2Int(buf, 0, endOfDir);
				currentIndex := 4;
				filenameLen := 0;
				IF detail > 0 THEN
					WHILE (currentIndex + 16) <= received DO
						Char2Int(buf, currentIndex, filenameLen);
						Char2Int(buf, currentIndex + 4, time);
						Char2Int(buf, currentIndex + 8, date);
						Char2Int(buf, currentIndex + 12, size);
						IF (currentIndex + 16 + filenameLen) <= received THEN
							dir.Insert(buf, currentIndex + 16, filenameLen, time, date, size);
						END;
						currentIndex := currentIndex + 16 + filenameLen;
					END;
				ELSE
					WHILE (currentIndex + 4) <= received DO
						Char2Int(buf, currentIndex, filenameLen);
						IF (currentIndex + 4 + filenameLen) <= received THEN
							dir.Insert(buf, currentIndex + 4, filenameLen, 0, 0, 0);
						END;
						currentIndex := currentIndex + 4 + filenameLen;
					END;
				END;
			END;
		END ReadDir;

		(** Creates a temporary File on the server and returns the name for it **)
		PROCEDURE CreateTmp*(VAR filename : ARRAY OF CHAR; VAR hashval, errorcode: LONGINT);
			VAR filenameLen, procID, testID, received, dataBytes, msgBytes, hashvalLen, res: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := CREATETMP;
			filenameLen := Len(filename);
			dataBytes := filenameLen + 4;
			msgBytes := dataBytes + 8;
			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(filenameLen, buf, DataOff);
			CopyBuffer(filename, 0, buf, DataOff + 4, filenameLen);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;

			IF errorcode # 0 THEN
				hashvalLen := 0;
				hashval := 0;
				filenameLen := 0;
				filename[0] := 0X;
			ELSE
				Char2Int(buf, 0, hashvalLen);

				Char2Int(buf, 4, hashval);

				Char2Int(buf, 8, filenameLen);

				CopyBuffer(buf, 12, filename, 0, filenameLen);
				filename[filenameLen] := 0X;
			END;
		END CreateTmp;

		(** Changes the Directory of the corresponding rfsServerProxy Process **)
		PROCEDURE ChDir*(VAR dir : ARRAY OF CHAR; VAR errorcode: LONGINT);
			VAR dirLen, procID, testID, received, dataBytes, msgBytes, res: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := CHDIR;
			dirLen := Len(dir);
			dataBytes := dirLen + 4;
			msgBytes := dataBytes + 8;

			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(dirLen, buf, DataOff);
			CopyBuffer(dir, 0, buf, DataOff + 4, dirLen);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;
		END ChDir;


		(** cleans the open file structure on the server an kills the process **)
		PROCEDURE Kill*(VAR errorcode: LONGINT);
			VAR msgBytes, procID, testID, dataBytes, res, received: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := KILL;
			dataBytes := 0;
			msgBytes := dataBytes + 8;
			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode = RECEIVERROR THEN
				CopyBuffer(buf, 0, backupBuf, 0, msgBytes);
				connection.Reset();
				Mount(errorcode);
				IF errorcode = REPLYOK THEN
					Char2Int(backupBuf, 0, testID);
					IF testID = procID THEN
						connection.Send(backupBuf, 0, msgBytes, res);
						GetResult(connection, errorcode, dataBytes, received, buf);
					ELSE
						errorcode := RECEIVERROR;
					END;
				END;
			END;
			connection.Close();
		END Kill;

		(** Authenticates the session. User and Passwd are sending in plainttext **)
		PROCEDURE Authent*(VAR user, passwd, path: ARRAY OF CHAR; VAR errorcode: LONGINT);
			VAR userLen, passwdLen, pathLen, procID, received, dataBytes, msgBytes, res: LONGINT;
		BEGIN
			(*prepare params and send*)
			procID := AUTHENT;
			userLen := Len(user);
			passwdLen := Len(passwd);
			pathLen := Len(path);
			dataBytes := userLen + passwdLen + pathLen + 12;
			msgBytes := dataBytes + 8;
			Int2Char(procID, buf, 0);
			Int2Char(dataBytes, buf, 4);
			Int2Char(userLen, buf, DataOff);
			CopyBuffer(user, 0, buf, DataOff + 4, userLen);
			Int2Char(passwdLen, buf, DataOff + 4 + userLen);
			CopyBuffer(passwd, 0, buf, DataOff + 4 + userLen + 4, passwdLen);
			Int2Char(pathLen, buf, DataOff + 4 + userLen + 4 + passwdLen);
			CopyBuffer(path, 0, buf, DataOff + 4 + userLen + 4 + passwdLen + 4, pathLen);
			connection.Send(buf, 0, msgBytes, res);

			(*getting result*)
			GetResult(connection, errorcode, dataBytes, received, buf);
			IF errorcode # REPLYOK THEN
				connection.Close();
			END;
		END Authent;


		(** this procedure is called from RfsClientProxy.New, it dows the Authentication and changes **)
		(** the directory on the server **)
		PROCEDURE Mount*(VAR errorcode: LONGINT);
			VAR res: LONGINT;
		BEGIN
			errorcode := RECEIVERROR;
			connection.Open(res);
			IF res = Ok THEN
				Authent(user, passwd, path, errorcode);
				IF errorcode = REPLYOK THEN
					ChDir(path, errorcode);
					IF errorcode # REPLYOK THEN
						KernelLog.String("Mount->cant change Directory");
						KernelLog.Ln;
					END;
				ELSE
					KernelLog.String("Mount->Authentification Error");
					KernelLog.Ln;
				END;
			ELSE
				KernelLog.String("Mount->can`t open the connection");
				KernelLog.Ln;
			END;
		END Mount;

		(** Kill the rfsServerProxy Process and closes the connection **)
		PROCEDURE Unmount*(VAR errorcode: LONGINT);
		BEGIN
			Kill(errorcode);
		END Unmount;

		PROCEDURE AllocBlock*(hint: Address; VAR adr: Address);
		END AllocBlock;

		PROCEDURE FreeBlock*(adr: Address);
		END FreeBlock;

		PROCEDURE MarkBlock*(adr: Address);
		END MarkBlock;

		PROCEDURE Marked*(adr: Address): BOOLEAN;
		END Marked;

		PROCEDURE Available*(): LONGINT;
		BEGIN
			RETURN 0;
		END Available;

		PROCEDURE GetBlock*(adr: LONGINT; VAR blk: ARRAY OF CHAR);
		END GetBlock;

		PROCEDURE PutBlock*(adr: LONGINT; VAR blk: ARRAY OF CHAR);
		END PutBlock;

	END Proxy;

(** a new global Proxy for a specific host, port pair is created. in addition a dummy Volume is set to par.vol.
	  this is needed so that the mounting works correctly **)
PROCEDURE New*(context : Files.Parameters);
VAR
	server, user, passwd, path: ARRAY MaxNameLen OF CHAR;
	i, errorcode: LONGINT; ch: CHAR; port: LONGINT; newVol: Proxy;

BEGIN
	context.arg.SkipWhitespace;

	ch := context.arg.Peek();
	i := 0;
	WHILE (i < LEN(user)-1) & (ch > " ") & (ch # ":") & (context.arg.res = Streams.Ok) DO
		context.arg.Char(ch); (* consume ch *)
		user[i] := ch; INC(i);
		ch := context.arg.Peek();
	END;
	user[i] := 0X;

	ch := context.arg.Peek();
	i := 0;
	WHILE (i < LEN(passwd)-1) & (ch > " ") & (ch # "@") & (context.arg.res = Streams.Ok) DO
		context.arg.Char(ch); (* consume ch *)
		passwd[i] := ch; INC(i);
		ch := context.arg.Peek();
	END;
	passwd[i] := 0X;

	ch := context.arg.Peek();
	i := 0;
	WHILE (i < LEN(server)-1) & (ch > " ") & (ch # ":") & (context.arg.res = Streams.Ok) DO
		context.arg.Char(ch); (* consume ch *)
		server[i] := ch; INC(i);
		ch := context.arg.Peek();
	END;
	server[i] := 0X;

	port := 0;
	IF (ch = ":") THEN
		context.arg.Char(ch); (* consume ":" *)
		context.arg.Int(port, FALSE);
	ELSE
		port := DefaultPort;
	END;

	ch := context.arg.Peek();
	i := 0;
	IF ch = "/" THEN
		context.arg.Char(ch); (* consume "/" *)
		ch := context.arg.Peek();
		WHILE (i < LEN(path)-1) & (ch > " ") & (ch # ":") & (context.arg.res = Streams.Ok) DO
			context.arg.Char(ch); (* consume ch *)
			path[i] := ch; INC(i);
			ch := context.arg.Peek();
		END;
		path[i] := 0X;
	ELSE
		CopyBuffer(user, 0, path, 0, Len(user));
	END;

	context.out.String("Proxy->user: "); context.out.String(user);
	context.out.String(", server: "); context.out.String(server);
	context.out.String(", port "); context.out.Int(port, 4);
	context.out.String(", path: "); context.out.String(path);
	context.out.String(", password: "); context.out.String(passwd);
	context.out.Ln;

	NEW(newVol, user, passwd, server, path, SHORT(port));
	newVol.Mount(errorcode);
	IF errorcode = REPLYOK THEN
		context.vol := newVol;
		context.out.String("Proxy->done");
		context.out.Ln;
	ELSE
		context.error.String("Proxy->Failure");
		context.error.Ln;
	END;
END New;

PROCEDURE GetResult(connection: RfsConnection.Connection; VAR errorcode, dataBytes, received: LONGINT; VAR buf: ARRAY OF CHAR);
	VAR res: LONGINT;
BEGIN
	errorcode := ReadInteger(connection, res);
	IF res = Ok THEN
		dataBytes := ReadInteger(connection, res);
		IF res = Ok THEN
			connection.Receive(buf, 0, dataBytes, received, res);
			IF res = Ok THEN
				RETURN;
			END;
		END;
	END;
	errorcode := RECEIVERROR;
END GetResult;

(** An integer is filled into an array of character **)
PROCEDURE Int2Char*(int: LONGINT; VAR buf: ARRAY OF CHAR; off: LONGINT);
BEGIN
	(*
	buf[off + 0] := CHR(int MOD Block);
	int := int DIV Block;
	buf[off + 1] := CHR(int MOD Block);
	int := int DIV Block;
	buf[off + 2] := CHR(int MOD Block);
	int := int DIV Block;
	buf[off + 3] := CHR(int MOD Block);
	*)

	Network.PutNet4(buf, off, int);
END Int2Char;

(** four bytes of an array of characters are casted into an integer **)
PROCEDURE Char2Int*(buf: ARRAY OF CHAR; off: LONGINT; VAR int: LONGINT);
BEGIN
	int := Network.GetNet4(buf, off);
END Char2Int;


PROCEDURE ReadInteger*(connection: RfsConnection.Connection; VAR res: LONGINT): LONGINT;
	VAR val, received: LONGINT; buf: ARRAY 4 OF CHAR;
BEGIN
	connection.Receive(buf, 0, 4, received, res);
	IF received # 4 THEN
		val := -1;
		res := PARAMERROR;
	ELSE
		Char2Int(buf, 0, val);
	END;
	RETURN val;
END ReadInteger;


PROCEDURE Len(x: ARRAY OF CHAR): LONGINT;
	VAR j: LONGINT;
BEGIN
	j := 0;
	WHILE x[j] # 0X DO
		INC(j);
	END;
	RETURN j;
END Len;

(** Fast Buffer Copying. copy from offset offFrom len Bytes of Buffer bufFrom into bufTo at offset offTo **)
PROCEDURE CopyBuffer*(VAR bufFrom: ARRAY OF CHAR; offFrom: LONGINT; VAR bufTo: ARRAY OF CHAR; offTo, len: LONGINT);
BEGIN
	ASSERT(offTo + len <= LEN(bufTo));
	SYSTEM.MOVE(ADDRESSOF(bufFrom[offFrom]), ADDRESSOF(bufTo[offTo]), len);
END CopyBuffer;

END RfsClientProxy.