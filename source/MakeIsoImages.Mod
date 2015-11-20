MODULE MakeIsoImages;

(*
References:
	ECMA-119 Volume and File Structure of CDROM for Information Interchange
	IEEE P1282 Rock Ridge Interchange Protocol
	Joliet Specification
*)

IMPORT SYSTEM, Files, Streams, Commands, Dates, Strings, UTF8Strings, Utils := CDRecordUtils, ATADisks, Disks;

CONST
	MaxLen = 256;
	TransferSize = 10; (* Save Image *)

	MaxISODepth = 8;
	MaxISOPathLength  = 255;
	IsoLevel1* = 0; IsoLevel2* = 1; Joliet* = 2;
	RelaxMaxDepth* = 0; RelaxMaxPathLength* = 1; NoVersion* = 2;
	SectorSize* = 2048;
	ISO9660Id* = "CD001";

	NumSystemSectors* =  16; (* number of unused sectors at the beginning *)

	(* volume descriptor *)
	Primary* = 0; Supplementary* = 1;

	(* pathtables *)
	LType = 1; RType = 2;

	(* File Flags *)
	FFHidden = 1X; FFDirectory = 2X;

	(* errors *)
	ResErr = 1;
	ResOk = 0;
	ErrNotEnoughSpace* = 2; (* not enough space on destination volume *)
	ErrDestinationInvalid* = 3;
	ErrDestinationReadOnly* = 4;
	ErrDirNotFound* = 5;
	ErrFileNotFound* = 6;
	ErrNoIsoImage*= 7;

	(* Bootable CD-ROM *)

	NumPartitions = 4;
	OfsPartitionTable = 446;

	ElToritoSysId = "EL TORITO SPECIFICATION";
	Platform80x86* = 0X;
	PlatformPowerPC* = 1X;
	PlatformMac* = 2X;

	Bootable = 88X;
	NotBootable = 00X;

	EmulationNone* = 0X;
	Emulation12Floppy* = 1X;
	Emulation144Floppy* = 2X;
	Emulation288Floppy* = 3X;
	EmulationHDD* = 4X;
TYPE
	PathTableRecord = RECORD
		IdentLen: CHAR;
		AttrLen: CHAR;
		Lba: ARRAY 4 OF CHAR;
		ParentNo: ARRAY 2 OF CHAR;
		Ident: ARRAY MaxLen OF CHAR;
	END;
	PathTableRecordPtr = POINTER TO PathTableRecord;

	DirectoryRecord = RECORD
		Len: CHAR;
		AttrLen: CHAR;
		Lba: ARRAY 8 OF CHAR;
		Size: ARRAY 8 OF CHAR;
		Time: ARRAY 7 OF CHAR;
		Flags: CHAR;
		UnitSize: CHAR;
		GapSize: CHAR;
		VolSeqNo: ARRAY 4 OF CHAR;
		IdentLen: CHAR;
		Ident: ARRAY MaxLen OF CHAR;
	END;
	DirectoryRecordPtr = POINTER TO DirectoryRecord;

	(* Volume Descriptors *)

	VolumeDescriptor = ARRAY 2048 OF CHAR;

	SetTerminator = RECORD
		Type: CHAR;
		StdIdent: ARRAY 5 OF CHAR;
		Version: CHAR;
		Reserved: ARRAY 2041 OF CHAR;
	END;

	BootRecord = RECORD
		Type: CHAR;
		StdIdent: ARRAY 5 OF CHAR;
		Version: CHAR;
		BootSysIdent: ARRAY 32 OF CHAR;
		Unused1: ARRAY 32 OF CHAR;
		Lba: ARRAY 4 OF CHAR;
		Unuesed: ARRAY 1973 OF CHAR;
	END;

	Partition = RECORD
		BootIndicator: CHAR;
		Begin: ARRAY 3 OF CHAR;
		SysIndicator: CHAR;
		End: ARRAY 3 OF CHAR;
		StartSec: LONGINT;
		NofSecs: LONGINT;
	END;

	PartitionTable = ARRAY NumPartitions OF Partition;

	(* Primary / Supplementary Volume Descriptor *)

	PSVolumeDescriptor* = RECORD
		Type*: CHAR;
		StdIdent*: ARRAY 5 OF CHAR;
		Version*: CHAR;
		Flags*: CHAR;		(* valid only for supplementary volume descriptor *)
		SysIdent*: ARRAY 32 OF CHAR;
		VolIdent*: ARRAY 32 OF CHAR;
		Unused1*: ARRAY 8 OF CHAR;
		VolSpaceSize*: ARRAY 8 OF CHAR;
		EscSeq*: ARRAY 32 OF CHAR; (* valid only for supplementary volume descriptor *)
		VolSetSize*: ARRAY 4 OF CHAR;
		VolSeqNo*: ARRAY 4 OF CHAR;
		BlockSize*: ARRAY 4 OF CHAR;
		PathTableSize*: ARRAY 8 OF CHAR;
		LocLPathTable*: ARRAY 4 OF CHAR;
		LocOptRPathTable*: ARRAY 4 OF CHAR;
		LocMPathTable*: ARRAY 4 OF CHAR;
		LocOptMPathTable*: ARRAY 4 OF CHAR;
		RootDirRecord*: ARRAY 34 OF CHAR;
		VolSetIdent*: ARRAY 128 OF CHAR;
		PubIdent*: ARRAY 128 OF CHAR;
		DataPrepIdent*: ARRAY 128 OF CHAR;
		ApplIdent*: ARRAY 128 OF CHAR;
		CopyRightIdent*: ARRAY 37 OF CHAR;
		AbstrFileIdent*: ARRAY 37 OF CHAR;
		BibFileIdent*:  ARRAY 37 OF CHAR;
		CreationTime*: ARRAY 17 OF CHAR;
		ModificationTime*: ARRAY 17 OF CHAR;
		ExpirationTime*: ARRAY 17 OF CHAR;
		EffectiveTime*: ARRAY 17 OF CHAR;
		FileStructVer*: CHAR;
		Unused2*: CHAR;
		AppUse*: ARRAY 512 OF CHAR;
		Unused3*: ARRAY 653 OF CHAR;
	END;
	PSVolumeDescriptorPtr = POINTER TO PSVolumeDescriptor;

	BootCatalogEntry = ARRAY 32 OF CHAR;
	BCValidationEntry = RECORD
		HeaderId: CHAR;
		PlatformId: CHAR;
		Reserved: INTEGER;
		IdString: ARRAY 24 OF CHAR;
		Checksum: INTEGER;
		KeyBytes: ARRAY 2 OF CHAR;
	END;

	BCInitialDefaultEntry = RECORD
		BootIndicator: CHAR;
		BootMediaType: CHAR;
		LoadSegment: INTEGER;
		SystemType: CHAR;
		Unused1: CHAR;
		SectorCount: INTEGER;
		LoadRBA: LONGINT;
		Unused2: ARRAY 20 OF CHAR;
	END;

	String = Strings.String;

	Node* = OBJECT
		VAR
			next*: Node;
			name*, fullpath*: String;
			shortname: String;
			lba: LONGINT;
			size*: LONGINT; (* size in bytes *)
	END Node;

	Directory* = OBJECT(Node)
		VAR
			parent*, nextdir*: Directory;
			subdir*: Directory; (* first subdirectory in this directory *)
			content*: Node; (*Pointer to first entry in directory *)
			depth*: LONGINT;
			fullpath*: String; (* set only if tree is physical *)
			no: LONGINT; (* no in pathtable *)

		PROCEDURE &New*(parent: Directory; name, fullpath: String; depth: LONGINT);
		BEGIN
			SELF.parent := parent;
			SELF.name := name;
			SELF.fullpath := fullpath;
			SELF.depth := depth;
		END New;
	END Directory;

	File* = OBJECT(Node)
	VAR
		fullpath*: String; (* set only if tree is not physical*)
		jolietFile: File; (* points to the file in the joliet tree if there is one *)
		prevSession*: BOOLEAN; (* file is from a previous session *)

		PROCEDURE &New*(name, fullpath: String; size: LONGINT);
		BEGIN
			SELF.name := name;
			SELF.fullpath := fullpath;
			SELF.size := size;
		END New;
	END File;

	DirectoryTree* = OBJECT
		VAR
			root*: Directory;
			dircnt*: LONGINT; (* number of directories *)
			size*: LONGINT; (* total size of direcotry tree in bytes *)
			sizeFiles*: LONGINT; (* total size of associated files in bytes *)
			type: LONGINT; (* ISO Level1 / ISO Level 2 / Joliet *)
			flags*: SET;

		PROCEDURE &New*(root: Directory; type: LONGINT; flags: SET);
		BEGIN
			(* the parent of the root dir shall be the root dir itself *)
			root.parent := root;
			SELF.root := root;
			SELF.type := type;
			SELF.flags := flags;
		END New;

		(* build up joliet tree from an iso tree *)
		PROCEDURE CloneTree(type: LONGINT): DirectoryTree;
		VAR
			newRoot: Directory;
			tree: DirectoryTree;
		BEGIN
			NEW(newRoot, NIL, root.name, root.fullpath, 0);
			NEW(tree, newRoot, type, flags);
			tree.dircnt := dircnt;
			tree.root := CloneDir(root);
			tree.root.parent := tree.root;
			tree.BuildRootName();
			tree.BuildShortNames(tree.root);
			tree.SortTree(tree.root);
			RETURN tree;
		END CloneTree;

		PROCEDURE CloneDir(dir: Directory): Directory;
		VAR
			cur, tmp, curNew: Node;
			newDir, folder: Directory;
			newFile: File;
		BEGIN
			NEW(folder, NIL, dir.name, dir.fullpath, dir.depth);
			cur := dir.content;
			WHILE cur # NIL DO
				IF cur IS Directory THEN
					newDir := CloneDir(cur(Directory));
					newDir.parent := folder;
					tmp:= newDir;
				ELSE
					NEW(newFile, cur.name, NIL, cur.size);
					newFile.lba := cur.lba; (* in case file is from a previous session *)
					cur(File).jolietFile := newFile;
					tmp := newFile;
				END;
				IF folder.content = NIL THEN
					folder.content := tmp;
				ELSE
					curNew.next := tmp;
				END;
				curNew := tmp;
				cur := cur.next;
			END;
			UpdateDirPointers(folder);
			RETURN folder;
		END CloneDir;

		PROCEDURE Build;
		BEGIN
			dircnt := 1;
			BuildTree(root);
			BuildRootName();
			BuildShortNames(root);
			SortTree(root);
		END Build;

		PROCEDURE BuildFromTree;
		BEGIN
			dircnt := 0;
			CountDirs(root);
			BuildRootName();
			BuildShortNames(root);
			SortTree(root);
		END BuildFromTree;

		PROCEDURE CountDirs(dir: Directory);
		VAR
			cur: Directory;
		BEGIN
			cur := dir;
			WHILE cur # NIL DO
				INC(dircnt);
				IF cur.subdir # NIL THEN
					CountDirs(cur.subdir);
				END;
				cur := cur.nextdir;
			END;
		END CountDirs;

		PROCEDURE AssignFirstDirLba(startLba: LONGINT);
		BEGIN
			size := AssignDirLba(root, startLba);
			size := size * SectorSize;
		END AssignFirstDirLba;

		PROCEDURE AssignFirstFileLba(startLba: LONGINT);
		BEGIN
			sizeFiles := AssignFileLba(root, startLba);
			sizeFiles := sizeFiles * SectorSize;
		END AssignFirstFileLba;

		PROCEDURE BuildTree(dir: Directory);
		VAR
			enumerator: Files.Enumerator;
			name, filename, path, mask: ARRAY MaxLen OF CHAR;
			time, date, size: LONGINT;
			flags: SET;
			newDir: Directory;
			newFile : File;
			cur, tmp : Node;
		BEGIN
			NEW(enumerator);
			COPY(dir.fullpath^, mask);
			Strings.Append(mask, "/*");
			enumerator.Open(mask, {Files.EnumSize});
			WHILE enumerator.HasMoreEntries() DO
				IF enumerator.GetEntry(name, flags, time, date, size) THEN
					Files.SplitPath(name, path, filename);
					IF Files.Directory IN flags THEN
						INC(dircnt);
						NEW(newDir, dir, Strings.NewString(filename), Strings.NewString(name), dir.depth+1);
						BuildTree(newDir);
						tmp := newDir;
					ELSE
						NEW(newFile, Strings.NewString(filename), NIL, size);
						tmp := newFile;
					END;
					IF dir.content = NIL THEN
						dir.content := tmp;
					ELSE
						cur.next := tmp;
					END;
					cur := tmp;
				END;
			END;
			UpdateDirPointers(dir);
		END BuildTree;

		PROCEDURE UpdateDirPointers(dir: Directory);
		VAR
			node: Node;
			curDir: Directory;
		BEGIN
			curDir := NIL;
			node := dir.content;
			WHILE node # NIL DO
				IF node IS Directory THEN
					IF curDir = NIL THEN
						curDir := node(Directory);
						dir.subdir := curDir;
					ELSE
						curDir.nextdir := node(Directory);
						curDir := curDir.nextdir;
					END;
					curDir.nextdir := NIL;
				END;
				node := node.next;
			END;
		END UpdateDirPointers;

		PROCEDURE SortTree(dir: Directory);
		VAR
			cur: Directory;
		BEGIN
			dir.content := Mergesort(dir.content);
			UpdateDirPointers(dir);
			cur := dir.subdir;
			WHILE cur # NIL DO
				SortTree(cur);
			cur := cur.nextdir;
			END;
		END SortTree;

		(* Merge Sort *)

		PROCEDURE Mergesort(head : Node): Node;
		VAR
			secondhalf: Node;
		BEGIN
			IF (head = NIL) OR (head.next = NIL) THEN
				RETURN head;
			END;
			secondhalf := Split(head);
			head := Mergesort(head);
			secondhalf := Mergesort(secondhalf);
			RETURN Merge(head, secondhalf);
		END Mergesort;

		PROCEDURE Split(head: Node): Node;
		VAR
			len, i: LONGINT;
			node, secondhalf: Node;
		BEGIN
			node := head;
			WHILE node # NIL DO
				INC(len, 1);
				node := node.next;
			END;
			node := head;
			FOR i:=0 TO (len DIV 2) -2 DO
				node := node.next;
			END;
			secondhalf := node.next;
			node.next := NIL;
		RETURN secondhalf;
		END Split;

		PROCEDURE Merge(head1, head2: Node): Node;
		BEGIN
			IF head1 = NIL THEN RETURN head2 END;
			IF head2 = NIL THEN RETURN head1 END;

			IF head1.shortname^ < head2.shortname^ THEN
				head1.next := Merge(head1.next, head2);
				RETURN head1;
			ELSE
				head2.next := Merge(head1, head2.next);
				RETURN head2;
			END;
		END Merge;

		PROCEDURE BuildRootName;
		VAR
			name, shortname: ARRAY MaxLen OF CHAR;
			len, count: LONGINT;
		BEGIN
			IF type = Joliet THEN
				COPY(root.name^, name);
				ReplaceNonJolietChars(name);
				len := Strings.Min(UTF8Strings.Length(name), 32 DIV 2);
				UTF8Strings.Extract(name, 0, len, shortname);
			ELSE
				count := UTF8Strings.UTF8toASCII(root.name^, CHR(95), name);
				Strings.UpperCase(name);
				ReplaceNonDChars(name);
				len := Strings.Min(Strings.Length(name), 32);
				Strings.Copy(name, 0, len, shortname);
			END;
			root.shortname := Strings.NewString(shortname);
		END BuildRootName;

		PROCEDURE BuildShortNames(dir: Directory);
		VAR
			node: Node;
			map: NameMap;
			shortname, val: ARRAY MaxLen OF CHAR;
			count, len: LONGINT;
		BEGIN
			NEW(map);
			node := dir.content;
			WHILE node # NIL DO
				IF type = Joliet THEN
					len := BuildJolietName(node, shortname);
				ELSIF type = IsoLevel2 THEN
					len := BuildIsoLevel2Name(node, shortname);
				ELSE
					len := BuildIsoLevel1Name(node, shortname);
				END;
				count := map.GetCount(shortname);
				IF count > 1 THEN
					Strings.IntToStr(count, val);
					Replace(shortname, len-Strings.Length(val), val);
				END;
				node.shortname := Strings.NewString(shortname);

				IF node IS Directory THEN
					BuildShortNames(node(Directory));
				END;
				node := node.next;
			END;
		END BuildShortNames;

		(* builds the iso level1 name and returns the length without extension *)
		PROCEDURE BuildIsoLevel1Name(node: Node; VAR shortname: ARRAY OF CHAR): LONGINT;
		VAR
			name, file, ext: ARRAY MaxLen OF CHAR;
			len, count: LONGINT;
		BEGIN
			count := UTF8Strings.UTF8toASCII(node.name^, CHR(95), name);
			Strings.UpperCase(name);
			IF (node IS File) & GetExtension(name, file, ext) THEN
				ReplaceNonDChars(file);
				ReplaceNonDChars(ext);
				len := Strings.Min(Strings.Length(file), 8);
				Strings.Copy(file, 0, len, shortname);
				Strings.Append(shortname, ".");
				ext[3] := 0X;
				Strings.Append(shortname, ext);
			ELSE
				len := Strings.Min(Strings.Length(name), 8);
				Strings.Copy(name, 0, len, shortname);
				ReplaceNonDChars(shortname);
			END;
			RETURN len;
		END BuildIsoLevel1Name;

		(* builds the iso level2 name and returns the length without extension *)
		PROCEDURE BuildIsoLevel2Name(node: Node; VAR shortname: ARRAY OF CHAR): LONGINT;
		VAR
			name, file, ext: ARRAY MaxLen OF CHAR;
			len, count: LONGINT;
		BEGIN
			count := UTF8Strings.UTF8toASCII(node.name^, CHR(95), name);
			Strings.UpperCase(name);
			IF (node IS File) THEN
				IF GetExtension(name, file, ext) THEN
					ReplaceNonDChars(file);
					ReplaceNonDChars(ext);
					len := Strings.Min(Strings.Length(file), 30-Strings.Length(ext)-1);
					Strings.Copy(file, 0, len, shortname);
					Strings.Append(shortname, ".");
					ext[30] := 0X;
					Strings.Append(shortname, ext);
				ELSE
					len := Strings.Min(Strings.Length(name), 30);
					Strings.Copy(name, 0, len, shortname);
					ReplaceNonDChars(shortname);
				END;
			ELSE
				len := Strings.Min(Strings.Length(name), 31);
				Strings.Copy(name, 0, len, shortname);
				ReplaceNonDChars(shortname);
			END;
			RETURN len;
		END BuildIsoLevel2Name;


		(* builds the joliet name and returns the length without extension *)
		(* we do not convert to UCS-2 here but only check name length and replace some chars *)

		PROCEDURE BuildJolietName(node: Node; VAR shortname: ARRAY OF CHAR): LONGINT;
		VAR
			name, file, ext: ARRAY MaxLen OF CHAR;
			len: LONGINT;
		BEGIN
			COPY(node.name^, name);
			ReplaceNonJolietChars(name);
			IF (node IS File) & GetExtension(name, file, ext) THEN
				len := Strings.Min(UTF8Strings.Length(file), 64 - UTF8Strings.Length(ext) -1);
				UTF8Strings.Extract(name, 0, len, shortname);
				Strings.Append(shortname, ".");
				Strings.Append(shortname, ext);
			ELSE
				len := Strings.Min(UTF8Strings.Length(name), 64);
				UTF8Strings.Extract(name, 0, len, shortname);
			END;
			RETURN len;
		END BuildJolietName;

		PROCEDURE ReplaceNonJolietChars(VAR str: ARRAY OF CHAR);
		VAR
			len, i: LONGINT;
		BEGIN
			len := UTF8Strings.Length(str);
			FOR i := 0 TO len -1 DO
				CASE str[i] OF
					'*', '/', ':', ';', '?': str[i] := '_';
					ELSE
				END;
			END;
		END ReplaceNonJolietChars;

		(* splits name in file and extension *)
		(* returns FALSE in case there is no extension *)
		PROCEDURE Replace(VAR src: ARRAY OF CHAR; pos: LONGINT; CONST new: ARRAY OF CHAR);
		VAR
			len: LONGINT;
		BEGIN
			len := UTF8Strings.Length(new);
			UTF8Strings.Delete(src, pos, len);
			UTF8Strings.Insert(new, pos, src);
		END Replace;

		PROCEDURE ReplaceNonDChars(VAR str: ARRAY OF CHAR);
		VAR
			i, num: LONGINT;
		BEGIN
			WHILE str[i] # 0X DO
				num := ORD(str[i]);
				IF (num < 48) OR ((num > 57) & (num < 65)) OR ((num > 90) & (num <97)) OR (num > 122) THEN
					str[i] := CHR(95);
				END;
				INC(i, 1);
			END;
		END ReplaceNonDChars;

		PROCEDURE GetMaxPathLength(): LONGINT;
		BEGIN
			RETURN GetMaxPathLengthDir(root);
		END GetMaxPathLength;

		PROCEDURE GetMaxPathLengthDir(dir : Directory): LONGINT;
		VAR
			node: Node;
			cur: Directory;
			max, len: LONGINT;
		BEGIN
			max := 0;
			node := dir.content;
			WHILE node # NIL DO
				len := UTF8Strings.Length(node.shortname^);
				max := Strings.Max(max, len);
				node := node.next;
			END;
			cur := dir.subdir;
			WHILE cur # NIL DO
				len :=GetMaxPathLengthDir(cur);
				max := Strings.Max(max, len);
				cur := cur.nextdir;
			END;
			IF dir.parent # dir THEN (* root directory *)
				INC(max); (* relevant directory *)
				INC(max, UTF8Strings.Length(dir.shortname^)); (* length of relevant directory identifier *)
			END;
			RETURN max;
		END GetMaxPathLengthDir;

		PROCEDURE AssignDirLba(dir: Directory; startsec: LONGINT): LONGINT;
		VAR
			cur: Directory;
			secs, nextsec: LONGINT;
		BEGIN
			secs := 0;
			dir.lba := startsec;
			secs := CalcDirLength(dir);
			nextsec := startsec + secs;
			cur := dir.subdir;
			WHILE cur # NIL DO
				secs := AssignDirLba(cur, nextsec);
				INC(nextsec, secs);
				cur := cur.nextdir;
			END;
			RETURN nextsec - startsec;
		END AssignDirLba;

		PROCEDURE CalcDirLength(dir: Directory): LONGINT;
		VAR
			node: Node;
			secs, ofs, len: LONGINT;
		BEGIN
			secs := 0;
			node := dir.content;
			ofs := 2*22H; (* self and parent reference *)
			WHILE node # NIL DO
				len := UTF8Strings.Length(node.shortname^);
				IF (node IS File) & ~(NoVersion IN flags) THEN INC(len, 2); END;
				IF type =Joliet THEN len := 2*len; END;
				INC(len, 33);
				INC(len, len MOD 2); (* pad to even size *)
				IF ofs + len > SectorSize THEN
					INC(secs); ofs := 0;
				END;
				INC(ofs, len);
				node := node.next;
			END;
			INC(secs);
			dir.size := secs*SectorSize;
			RETURN secs;
		END CalcDirLength;

		PROCEDURE AssignFileLba(dir: Directory; startsec: LONGINT): LONGINT;
		VAR
			node: Node;
			cur: Directory;
			secs, nextsec: LONGINT;
		BEGIN
			nextsec := startsec;
			node := dir.content;
			WHILE node # NIL DO
				IF (node IS File) & ~node(File).prevSession THEN (* skip files from previous sessions *)
					node.lba := nextsec;
					IF node(File).jolietFile # NIL THEN node(File).jolietFile.lba := nextsec END;
					INC(nextsec, (node.size + SectorSize - 1) DIV SectorSize);
				END;
				node := node.next;
			END;
			cur := dir.subdir;
			WHILE cur # NIL DO
				secs := AssignFileLba(cur, nextsec);
				INC(nextsec, secs);
				cur := cur.nextdir;
			END;
			RETURN nextsec - startsec;
		END AssignFileLba;

		PROCEDURE Write(w: Streams.Writer);
		BEGIN
			WriteTree(w, root);
		END Write;

		PROCEDURE WriteTree(w: Streams.Writer; dir: Directory);
		VAR
			cur: Directory;
		BEGIN
			WriteDirectory(w, dir);
			cur := dir.subdir;
			WHILE (cur # NIL) DO
				WriteTree(w, cur);
				cur := cur.nextdir;
			END;
		END WriteTree;

		PROCEDURE WriteDirectory(w: Streams.Writer; dir: Directory);
		VAR
			rec: DirectoryRecordPtr;
			cur: Node;
			ofs: LONGINT;
			bufAdr, recAdr: ADDRESS;
			buf: POINTER TO ARRAY OF CHAR;
			time: Dates.DateTime;
			len: LONGINT;
			name: ARRAY MaxLen OF CHAR;
		BEGIN
			time := Dates.Now();
			NEW(buf, dir.size);
			bufAdr := ADDRESSOF(buf^); recAdr := bufAdr;

			(* add record for self reference *)
			rec := SYSTEM.VAL(DirectoryRecordPtr, recAdr);
			ASSERT(ADDRESSOF(rec^) = SYSTEM.VAL(LONGINT, rec));
			rec.Len := 22X;
			SetBothByteOrder32(dir.lba, rec.Lba);
			SetBothByteOrder32(dir.size, rec.Size);
			SetTime(time, 0, rec.Time);
			rec.Flags := FFDirectory;
			SetBothByteOrder16(1, rec.VolSeqNo);
			rec.IdentLen := 1X; rec.Ident[0] := 0X;
			INC(recAdr, 22H);

			(* add record for parent reference *)
			rec := SYSTEM.VAL(DirectoryRecordPtr, recAdr);
			rec.Len := 22X;
			SetBothByteOrder32(dir.parent.lba, rec.Lba);
			SetBothByteOrder32(dir.parent.size, rec.Size);
			SetTime(time, 0, rec.Time);
			rec.Flags := FFDirectory;
			SetBothByteOrder16(1, rec.VolSeqNo);
			rec.IdentLen := 1X; rec.Ident[0] := 1X;
			INC(recAdr, 22H);

			ofs := 2*22H;

			(* add an entry for each node in this directory *)
			cur := dir.content;
			WHILE cur # NIL DO
				COPY(cur.shortname^, name);
				IF (cur IS File) & ~(NoVersion IN flags) THEN
					Strings.Append(name, ";1");
				END;
				len := GetIdentLen(name);
				INC(len, 33);
				INC(len, len MOD 2); (* pad to even size *)
				IF ofs + len > SectorSize THEN
					INC(recAdr, SectorSize-ofs); ofs := 0;
				END;
				rec := SYSTEM.VAL(DirectoryRecordPtr, recAdr);
				ASSERT(recAdr+len <= bufAdr + LEN(buf^));
				rec.Len := CHR(len);
				SetBothByteOrder32(cur.lba, rec.Lba);
				SetBothByteOrder32(cur.size, rec.Size);
				SetTime(time, 0, rec.Time);
				IF cur IS Directory THEN
					rec.Flags := FFDirectory;
				ELSE
					rec.Flags := 0X;
				END;
				SetBothByteOrder16(1, rec.VolSeqNo);
				rec.IdentLen := CHR(GetIdentLen(name));
				IF type = Joliet THEN
					ConvertUTF8ToUCS2(name, rec.Ident);
				ELSE
					COPY(name, rec.Ident);
				END;
				INC(ofs, len); INC(recAdr, ORD(rec.Len));
				cur := cur.next;
			END;
			w.Bytes(buf^, 0, dir.size);
		END WriteDirectory;

		PROCEDURE GetIdentLen(CONST name: ARRAY OF CHAR): LONGINT;
		VAR
			len: LONGINT;
		BEGIN
			len := UTF8Strings.Length(name);
			IF type = Joliet THEN len := 2*len; END;
			RETURN len;
		END GetIdentLen;
	END DirectoryTree;

	(* Builds the Directory Tree from an ISO File *)
	(* necessary for Multisession ISO *)
	ISOReader* = OBJECT
		VAR
			dev: ATADisks.DeviceATAPI;
			tree*: DirectoryTree;

		PROCEDURE &New*(dev: ATADisks.DeviceATAPI);
		BEGIN
			SELF.dev := dev;
		END New;

		PROCEDURE Read*(startsec: LONGINT): LONGINT;
		VAR
			voldescr: PSVolumeDescriptor;
			res, treeType: LONGINT;
			rootRec: DirectoryRecord;
			root: Directory;
			tmp, name: ARRAY MaxLen OF CHAR;
		BEGIN
			IF GetVolumeDescriptor(dev, startsec, voldescr, Supplementary) = ResOk THEN
				treeType := Joliet;
			ELSIF GetVolumeDescriptor(dev, startsec, voldescr, Primary) # ResOk THEN
				RETURN ResErr; (* iso image not found *)
			END;
			ConvertIdentToUTF8(voldescr.StdIdent, LEN(voldescr.StdIdent), FALSE, tmp);
			ASSERT(tmp = ISO9660Id);
			SYSTEM.MOVE(ADDRESSOF(voldescr.RootDirRecord), ADDRESSOF(rootRec), 22H);
			ConvertIdentToUTF8(voldescr.VolIdent, LEN(voldescr.VolIdent), treeType = Joliet, name);
			NEW(root, NIL, Strings.NewString(name), NIL, 0);
			root.size := Utils.ConvertLE32Int(rootRec.Size);
			root.lba := Utils.ConvertLE32Int(rootRec.Lba);
			NEW(tree, root, treeType, {});
			tree.dircnt := 1;
			res := ReadDir(tree.root);
			RETURN ResOk;
		END Read;

		PROCEDURE ReadDir(parent: Directory): LONGINT;
		VAR
			index, size, lba, len, res: LONGINT;
			name : ARRAY MaxLen OF CHAR;
			dirRec: DirectoryRecord;
			file: File;
			dir, curDir: Directory;
			cur, tmp: Node;
			buf: POINTER TO ARRAY OF CHAR;
		BEGIN
			NEW(buf, parent.size); INC(tree.size, parent.size);
			dev.Transfer(Disks.Read, parent.lba, parent.size DIV SectorSize, buf^, 0, res);
			IF res # ResOk THEN
				RETURN res;
			END;
			index := 2*22H; (* skip parent and self reference*)
			WHILE buf[index] > 0X DO
				len := ORD(buf[index]);
				SYSTEM.MOVE(ADDRESSOF(buf[index]), ADDRESSOF(dirRec), len);
				size := Utils.ConvertLE32Int(dirRec.Size);
				lba := Utils.ConvertLE32Int(dirRec.Lba);
				ConvertIdentToUTF8(dirRec.Ident, ORD(dirRec.IdentLen), tree.type = Joliet, name);
				RemoveVersion(name);
				IF dirRec.Flags # FFHidden THEN
					IF dirRec.Flags = FFDirectory THEN
						INC(tree.dircnt);
						NEW(dir, parent, Strings.NewString(name), NIL, parent.depth+1);
						dir.size := size; dir.lba := lba;
						res := ReadDir(dir);
						IF res # ResOk THEN RETURN res END;
						IF parent.subdir = NIL THEN
							parent.subdir := dir;
						ELSE
							curDir.nextdir := dir;
						END;
						tmp := dir;
						curDir := dir;
					ELSE
						NEW(file, Strings.NewString(name), NIL, size);
						INC(tree.sizeFiles, size);
						file.prevSession := TRUE;
						file.lba := lba;
						tmp := file;
					END;
					tmp.shortname := tmp.name;
					IF parent.content = NIL THEN
						parent.content := tmp;
					ELSE
						cur.next := tmp;
					END;
					cur := tmp;
				END;
				INC(index, len);
			END;
			RETURN ResOk;
		END ReadDir;

		PROCEDURE RemoveVersion(VAR str: ARRAY OF CHAR);
		VAR
			len: LONGINT;
		BEGIN
			len := Strings.Length(str);
			IF str[len-2] = ';' THEN
				str[len-2] := 0X;
			ELSIF str[len-1] = ';' THEN
				str[len-1] := 0X;
			END;
		END RemoveVersion;
	END ISOReader;

	ISOInfo* = OBJECT
		VAR
			pvd: PSVolumeDescriptorPtr;

		PROCEDURE Open*(filename: Strings.String): LONGINT;
		VAR
			ofs, bytesRead, total: LONGINT;
			file: Files.File;
			r: Files.Reader;
			buf: ARRAY SectorSize OF CHAR;
			tmp: ARRAY 256 OF CHAR;
		BEGIN
			file := Files.Old(filename^);
			IF file = NIL THEN RETURN ErrFileNotFound END;
			IF file.Length() MOD SectorSize # 0 THEN RETURN ErrNoIsoImage END;

			(* search pvd in first 10 sectors after system area *)
			ofs := NumSystemSectors*SectorSize;
			Files.OpenReader(r, file, ofs);
			total := 0;
			REPEAT
				r.Bytes(buf, 0, SectorSize, bytesRead);
				IF bytesRead < SectorSize THEN RETURN ErrNoIsoImage END;
				INC(total, SectorSize);
			UNTIL  (buf[0] = 1X) OR (total > ofs + 10*SectorSize);
			IF buf[0] # 1X THEN RETURN ErrNoIsoImage END;

			pvd := SYSTEM.VAL(PSVolumeDescriptorPtr, ADDRESSOF(buf[0]));

			ConvertIdentToUTF8(pvd.StdIdent, LEN(pvd.StdIdent), FALSE, tmp);

			IF tmp # ISO9660Id THEN RETURN ErrNoIsoImage END;

			RETURN ResOk;
		END Open;
	END ISOInfo;

	(* queue for level order traversal of tree *)
	Queue = OBJECT
	VAR
		queue: POINTER TO ARRAY OF ANY;
		head, tail, size: LONGINT;

		PROCEDURE &New*(size: LONGINT);
		BEGIN
			head := 0; tail := 0;
			SELF.size := size;
			NEW(queue, size+1);
		END New;

		PROCEDURE Put(ptr: ANY);
		BEGIN
			queue[tail] := ptr; INC(tail);
			IF tail > size THEN tail := 0; END;
		END Put;

		PROCEDURE Get(): ANY;
		VAR
			ptr: ANY;
		BEGIN
			ptr := queue[head]; INC(head);
			IF head > size THEN head := 0; END;
			RETURN ptr;
		END Get;

		PROCEDURE IsEmpty(): BOOLEAN;
		BEGIN
			RETURN head = tail;
		END IsEmpty;
	END Queue;

	PathTable = OBJECT
		VAR
			tree: DirectoryTree;
			table: POINTER TO ARRAY OF Directory;
			size: LONGINT; (* length of pathtable in bytes *)
			lbaLType, lbaRType: LONGINT;

		PROCEDURE &New*(tree: DirectoryTree);
		BEGIN
			SELF.tree := tree;
		END New;

		(* traverse the tree in level order and fill the table *)
		PROCEDURE Build;
		VAR
			queue: Queue;
			ptr : ANY;
			cur: Directory;
			no: LONGINT;
		BEGIN
			NEW(table, tree.dircnt);
			NEW(queue, tree.dircnt);
			size := 0;
			cur := tree.root;
			queue.Put(cur);
			WHILE ~queue.IsEmpty() DO
				ptr := queue.Get();
				cur := ptr(Directory);
				table[no] := cur;
				INC(no); cur.no := no;
				INC(size, CalcRecordLength(cur));
				cur := cur.subdir;
				WHILE cur # NIL DO
					queue.Put(cur);
					cur := cur.nextdir;
				END;
			END;
		END Build;

		PROCEDURE CalcRecordLength(dir: Directory): LONGINT;
		VAR
			len: LONGINT;
		BEGIN
			IF dir.parent = dir THEN (* root directory *)
				len := 10;
			ELSE
				len := UTF8Strings.Length(dir.shortname^);
				IF tree.type = Joliet THEN len := 2*len; END;
				INC(len, 8);
				INC(len, len MOD 2); (* pad to even size *)
			END;
			RETURN len;
		END CalcRecordLength;

		PROCEDURE Write	(w: Streams.Writer; tableType: LONGINT);
		VAR
			dir: Directory;
			buf: POINTER TO ARRAY OF CHAR;
			rec: PathTableRecordPtr;
			i, len, bytesWritten : LONGINT;
		BEGIN
			NEW(buf, MaxLen); (* max record length *)
			rec := SYSTEM.VAL(PathTableRecordPtr, ADDRESSOF(buf^));
			ASSERT(ADDRESSOF(rec^) = SYSTEM.VAL(LONGINT, rec));

			(* first write entry for root record *)
			rec.IdentLen := 1X;
			IF tableType = LType THEN
				Utils.SetLE32(tree.root.lba, rec.Lba);
				Utils.SetLE16(1, rec.ParentNo);
			ELSE
				Utils.SetBE32(tree.root.lba, rec.Lba);
				Utils.SetBE16(1, rec.ParentNo);
			END;
			rec.Ident[0] := 0X;
			w.Bytes(buf^, 0, 10); bytesWritten := 10;

			(* now write the records for all other entries in the pathtable *)
			FOR i:=1 TO  tree.dircnt-1 DO
				dir := table[i](Directory);
				len := UTF8Strings.Length(dir.shortname^);
				IF tree.type = Joliet THEN len := 2*len; END;
				rec.IdentLen := CHR(len);
				INC(len, 8);
				INC(len, len MOD 2); (* pad to even size *)
				IF tableType = LType THEN
					Utils.SetLE32(dir.lba, rec.Lba);
					Utils.SetLE16(SHORT(dir.parent.no), rec.ParentNo);
				ELSE
					Utils.SetBE32(dir.lba, rec.Lba);
					Utils.SetBE16(SHORT(dir.parent.no), rec.ParentNo);
				END;
				IF tree.type = Joliet THEN
					ConvertUTF8ToUCS2(dir.shortname^, rec.Ident);
				ELSE
					COPY(dir.shortname^, rec.Ident);
				END;
				ASSERT(len <= MaxLen);
				w.Bytes(buf^, 0, len);
				INC(bytesWritten, len);
			END;
			IF (size MOD SectorSize) # 0 THEN
				Pad(w, SectorSize - bytesWritten MOD SectorSize);
			END;
		END Write;

	END PathTable;

	(* Boot Catalog *)
	BCEntry = POINTER TO RECORD
		next: BCEntry;
		image: String;
		loadRBA, size: LONGINT;
		bootable: BOOLEAN;
		emulation: CHAR;
		id: String;
		platform: CHAR;
	END;

	(* at the moment only the default entry is implemented *)
	BootCatalog* = OBJECT
		VAR
			size: LONGINT; (* size in bytes *)
			sizeImages: LONGINT; (* size of associated images *)
			root: BCEntry;

			PROCEDURE &New*;
			BEGIN
				INC(size, 32); (* validation entry *)
			END New;

			PROCEDURE AddDefaultEntry*(image, id: String; bootable: BOOLEAN; platform, emulation: CHAR);
			VAR
				file: Files.File;
			BEGIN
				file := Files.Old(image^);
				IF file # NIL THEN
					INC(size, 32);
					NEW(root);
					root.size := file.Length();
					root.image := image;
					root.id := id;
					root.bootable := bootable;
					root.platform := platform;
					root.emulation := emulation;
					INC(sizeImages, root.size);
					IF (root.size MOD SectorSize) # 0 THEN
						INC(sizeImages, SectorSize - (root.size MOD SectorSize)); (* Padding *)
					END;
				END;
			END AddDefaultEntry;

			PROCEDURE AssignFirstImageLba(startlba: LONGINT);
			VAR
				cur: BCEntry;
			BEGIN
				cur := root;
				WHILE cur # NIL DO
					cur.loadRBA := startlba;
					INC(startlba, (cur.size + SectorSize - 1) DIV SectorSize);
					cur := cur.next;
				END;
			END AssignFirstImageLba;

			PROCEDURE Write(w: Streams.Writer);
			VAR
				entry: BCValidationEntry; entry2: BCInitialDefaultEntry;
			BEGIN
				ASSERT(size >= 64);

				(* validation entry *)
				entry.HeaderId := 1X; (* header id *)
				entry.PlatformId := root.platform; (* platform id *)
				entry.Reserved := 0; (* reserved *)
				SetStringWithPadding(root.id^, entry.IdString, 0X, FALSE);
				entry.Checksum := 0;(* init checksum to zero *)
				entry.KeyBytes[0] := 55X; entry.KeyBytes[1] := 0AAX; (* key bytes *)
				entry.Checksum := CalcChecksum16(SYSTEM.VAL(BootCatalogEntry, entry)); (* update the checksum *)
				w.Bytes(SYSTEM.VAL(BootCatalogEntry, entry), 0, SIZEOF(BCValidationEntry));

				(* initial / default entry *)
				IF root.bootable THEN
					entry2.BootIndicator := Bootable;
				ELSE
					entry2.BootIndicator := NotBootable;
				END;
				entry2.BootMediaType := root.emulation;
				entry2.LoadSegment := 0; (* use default load segment which is 7C0H *)
				GetSysType(root, entry2.SystemType);
				entry2.Unused1 := 0X;
				entry2.SectorCount := 1;
				entry2.LoadRBA := root.loadRBA;
				w.Bytes(SYSTEM.VAL(BootCatalogEntry, entry2), 0, SIZEOF(BCInitialDefaultEntry));

				IF (size MOD SectorSize) # 0 THEN
					Pad(w, SectorSize - (size MOD SectorSize));
				END;
			END Write;

			PROCEDURE GetSysType(entry: BCEntry; VAR type: CHAR);
			VAR
				file: Files.File;
				r: Files.Reader;
				bytesRead, i: LONGINT;
				buf: POINTER TO ARRAY OF CHAR;
				table: PartitionTable;
			BEGIN
				IF entry.emulation # EmulationHDD THEN type := 0X; RETURN END;
				file := Files.Old(root.image^);
				IF file # NIL THEN
					Files.OpenReader(r, file, 0);
					NEW(buf, SIZEOF(PartitionTable));
					r.Bytes(buf^, 0, SIZEOF(PartitionTable), bytesRead);
					ASSERT(bytesRead = SIZEOF(PartitionTable));
					SYSTEM.MOVE(ADDRESSOF(buf^), ADDRESSOF(table), SIZEOF(PartitionTable));

					FOR i := 0 TO NumPartitions-1 DO
						IF  table[i].BootIndicator = Bootable THEN
							type := table[i].SysIndicator;
						END;
					END;
				END;
			END GetSysType;

			PROCEDURE WriteImages(w: Streams.Writer): LONGINT;
			VAR
				res : LONGINT;
				cur: BCEntry;
			BEGIN
				cur := root;
				WHILE cur # NIL DO
					res := WriteFile(w, cur.image^);
					IF res # ResOk THEN RETURN res END;
					IF (cur.size MOD SectorSize) # 0 THEN
						Pad(w, SectorSize - (cur.size MOD SectorSize));
					END;
					cur := cur.next;
				END;
				RETURN ResOk;
			END WriteImages;

			PROCEDURE CalcChecksum16(CONST buf: ARRAY OF CHAR): INTEGER;
			VAR
				checksum, i, numWords: LONGINT;
			BEGIN
				checksum := 0;
				numWords := LEN(buf) DIV 2;
				FOR i := 0 TO numWords - 1 DO
					checksum := (checksum + SYSTEM.VAL(INTEGER, buf[i * 2])) MOD 10000H;
				END;
				RETURN SHORT(10000H - checksum);
			END CalcChecksum16;
	END BootCatalog;


	(* NameMap  implements a binary search tree for looking up filenames *)
	(* used to build unique short names *)

	Entry = OBJECT
		VAR
			left, right: Entry;
			name: ARRAY MaxLen OF CHAR;
			count: LONGINT;

		PROCEDURE &New*(CONST name: ARRAY OF CHAR);
		BEGIN
			COPY(name, SELF.name);
			SELF.count := 1;
		END New;
	END Entry;

	NameMap = OBJECT
		VAR
			root: Entry;

		PROCEDURE GetCount(CONST str: ARRAY OF CHAR): LONGINT;
		VAR
			entry, tmp: Entry;
		BEGIN
			IF root = NIL THEN
				NEW(root, str);
				RETURN 1;
			END;
			entry := root;
			WHILE (entry # NIL) DO
				IF str = entry.name THEN
					INC(entry.count, 1);
					RETURN entry.count;
				ELSIF entry.name > str THEN
					IF entry.left = NIL THEN
						NEW(tmp, str);
						entry.left := tmp;
						RETURN 1;
					ELSE
						entry := entry.left;
					END;
				ELSE
					IF entry.right = NIL THEN
						NEW(tmp, str);
						entry.right := tmp;
						RETURN 1;
					ELSE
						entry := entry.right;
					END;
				END;
			END;
		END GetCount;
	END NameMap;

	IsoSettings* = RECORD
		isoLevel*: LONGINT;
		padToSize*: LONGINT; (* small images are padded to padToSize sectors *)
		joliet*: BOOLEAN;
		flags*: SET;
		bootCatalog*: BootCatalog;
		startLba*: LONGINT;
		volumeIdent: String;
	END;

	WritingStatus* = OBJECT(Utils.Status);
	VAR
		fileName*: String;
		bytesWritten*: LONGINT;
	END WritingStatus;

VAR
	onWriteStatusChanged: Utils.StatusProc;
	status: WritingStatus;

PROCEDURE GetExtension*(CONST name: ARRAY OF CHAR; VAR file, ext: ARRAY OF CHAR) : BOOLEAN;
BEGIN
	Strings.GetExtension (name, file, ext);
	RETURN ext[0] # 0X
END GetExtension;

PROCEDURE Pad(w: Streams.Writer; len: LONGINT);
VAR
	buf: POINTER TO ARRAY SectorSize OF CHAR;
	i: LONGINT;
BEGIN
	IF len >= SectorSize THEN
		NEW(buf);
		(* Utils.ClearBuffer(buf^, 0, SectorSize); *) (* memory is cleared on allocation *)
	END;
	WHILE len >= SectorSize DO
		w.Bytes(buf^, 0, SectorSize);
		DEC(len, SectorSize);
	END;
	FOR i:=0 TO len - 1 DO
		w.Char(0X);
	END;
END Pad;

PROCEDURE WriteFiles(w: Streams.Writer; dir: Directory): LONGINT;
VAR
	node: Node;
	cur: Directory;
	pathname: ARRAY MaxLen OF CHAR;
	res: LONGINT;
BEGIN
	node := dir.content;
	WHILE node # NIL DO
		IF (node IS File) & ~node(File).prevSession  THEN
			IF node(File).fullpath = NIL THEN
				Files.JoinPath(dir.fullpath^, node.name^, pathname);
			ELSE
				COPY(node(File).fullpath^, pathname);
			END;
			IF node.size > 0 THEN
				res := WriteFile(w, pathname);
				IF res # ResOk THEN RETURN res END;
				IF (node.size MOD SectorSize) # 0 THEN
					Pad(w, SectorSize - (node.size MOD SectorSize));
				END;
			END;
		END;
		node := node.next;
	END;
	cur := dir.subdir;
	WHILE cur # NIL DO
		res := WriteFiles(w, cur);
		IF res # ResOk THEN RETURN res END;
		cur := cur.nextdir;
	END;
	RETURN ResOk;
END WriteFiles;

PROCEDURE WriteFile(w: Streams.Writer; CONST pathname: ARRAY OF CHAR): LONGINT;
VAR
	file: Files.File;
	r: Files.Reader;
	buf: ARRAY 1024 OF CHAR;
	bytesRead, res: LONGINT;
BEGIN
	res := ErrFileNotFound;
	status.fileName := Strings.NewString(pathname);
	file := Files.Old(pathname);
	IF file # NIL THEN
		Files.OpenReader(r, file, 0);
		REPEAT
			r.Bytes(buf, 0, 1024, bytesRead);
			w.Bytes(buf, 0, bytesRead);
			IF onWriteStatusChanged # NIL THEN
				INC(status.bytesWritten, bytesRead);
				onWriteStatusChanged(status);
			END;
		UNTIL bytesRead <1024;
		res := ResOk;
	END;
	RETURN res;
END WriteFile;

PROCEDURE WriteVolumeDescriptor(w: Streams.Writer; descr: VolumeDescriptor);
BEGIN
	w.Bytes(descr, 0, LEN(descr));
END WriteVolumeDescriptor;

(* initialize Set Terminator *)
PROCEDURE InitSetTerminator(VAR descr: SetTerminator);
BEGIN
	descr.Type := 0FFX;
	SetStringWithPadding(ISO9660Id, descr.StdIdent, ' ', FALSE);
	descr.Version := 1X;
END InitSetTerminator;

(* Initialize Boot Record *)
PROCEDURE InitBootRecord(VAR descr: BootRecord; lba: LONGINT);
BEGIN
	descr.Type := 0X;
	SetStringWithPadding(ISO9660Id, descr.StdIdent, 0X, FALSE);
	descr.Version := 1X;
	SetStringWithPadding(ElToritoSysId, descr. BootSysIdent, 0X, FALSE);
	Utils.SetLE32(lba, descr.Lba);
END InitBootRecord;

(* initialize Primary  / Supplementary volume descriptor *)
PROCEDURE InitPSVolumeDescriptor(VAR descr: PSVolumeDescriptor; tree: DirectoryTree; table: PathTable; volSize, descrType: LONGINT);
VAR
	rec: DirectoryRecord;
	time: Dates.DateTime;
	dtBuf: ARRAY 20 OF CHAR;
	srcAdr, dstAdr: ADDRESS;
	ucs2: BOOLEAN;
BEGIN
	time := Dates.Now();
	ucs2 := FALSE;
	Strings.FormatDateTime("yyyymmddhhnnss00", time, dtBuf);

	SetStringWithPadding(ISO9660Id, descr.StdIdent, ' ', FALSE);
	descr.Version := 1X;

	IF descrType = Primary THEN
		descr.Type := 1X;
	ELSIF descrType = Supplementary THEN
		descr.Type := 2X;
		ucs2 := TRUE;
	END;

	SetStringWithPadding("", descr.SysIdent, ' ', ucs2);
	SetStringWithPadding(tree.root.shortname^, descr.VolIdent, ' ', ucs2);
	SetBothByteOrder32(volSize, descr.VolSpaceSize);

	(* escape sequences *)
	IF descrType = Supplementary THEN
		(* UCS-2 level 1 *)
		descr.EscSeq[0] := 25X; descr.EscSeq[1] := 2FX; descr.EscSeq[2] := 40X;
	END;

	SetBothByteOrder16(1, descr.VolSetSize);
	SetBothByteOrder16(1, descr.VolSeqNo);
	SetBothByteOrder16(SectorSize, descr.BlockSize);

	(* pathtable *)
	SetBothByteOrder32(table.size, descr.PathTableSize);
	Utils.SetLE32(table.lbaLType, descr.LocLPathTable);
	Utils.SetBE32(table.lbaRType, descr.LocMPathTable);

	(* root record *)
	rec.Len := 22X;
	SetBothByteOrder32(tree.root.lba, rec.Lba);
	SetBothByteOrder32(tree.root.size, rec.Size);
	SetTime(time, 0, rec.Time);
	rec.Flags := FFDirectory; (* directory *)
	SetBothByteOrder16(1, rec.VolSeqNo);
	rec.IdentLen := 1X; rec.Ident[0] := 0X;
	srcAdr := ADDRESSOF(rec); dstAdr := ADDRESSOF(descr.RootDirRecord);
	SYSTEM.MOVE(srcAdr, dstAdr, ORD(rec.Len)); INC(dstAdr, 22H);

	SetStringWithPadding("", descr.VolSetIdent, ' ', ucs2);
	SetStringWithPadding("", descr.PubIdent, ' ', ucs2);
	SetStringWithPadding("", descr.DataPrepIdent, ' ',  ucs2);
	SetStringWithPadding("", descr.ApplIdent, ' ', ucs2);
	SetStringWithPadding("", descr.CopyRightIdent, ' ', ucs2);
	SetStringWithPadding("", descr.AbstrFileIdent, ' ', ucs2);
	SetStringWithPadding("", descr.BibFileIdent, ' ', ucs2);
	SetStringWithPadding(dtBuf, descr.CreationTime, ' ', FALSE);
	dtBuf := "000000000000000";
	SetStringWithPadding(dtBuf, descr.ModificationTime, ' ', FALSE);
	SetStringWithPadding(dtBuf, descr.ExpirationTime, ' ', FALSE);
	SetStringWithPadding(dtBuf, descr.EffectiveTime, ' ', FALSE);
	descr.FileStructVer := 1X;
END InitPSVolumeDescriptor;

PROCEDURE SetBothByteOrder16(x: INTEGER; VAR dst: ARRAY OF CHAR);
BEGIN
	dst[0] := CHR(x MOD 100H);
	dst[1] := CHR(x DIV 100H MOD 100H);
	dst[2] := dst[1];
	dst[3] := dst[0];
END SetBothByteOrder16;

PROCEDURE SetBothByteOrder32(x: LONGINT; VAR dst: ARRAY OF CHAR);
BEGIN
	dst[0] := CHR(x MOD 100H);
	dst[1] := CHR(x DIV 100H MOD 100H);
	dst[2] := CHR(x DIV 10000H MOD 100H);
	dst[3] := CHR(x DIV 1000000H MOD 100H);
	dst[4] := dst[3];
	dst[5] := dst[2];
	dst[6] := dst[1];
	dst[7] := dst[0];
END SetBothByteOrder32;

(* we set the time so that it is displayed correct in bluebottle *)
PROCEDURE SetTime(time: Dates.DateTime; ofs: LONGINT; VAR dst: ARRAY OF CHAR);
BEGIN
	dst[0] := CHR(time.year - 1900);
	dst[1] := CHR(time.month + 1);
	dst[2] := CHR(time.day);
	dst[3] := CHR(time.hour);
	dst[4] := CHR(time.minute);
	dst[5] := CHR(time.second);
	dst[6] := CHR(ofs);
END SetTime;

PROCEDURE SetStringWithPadding(CONST id: ARRAY OF CHAR; VAR dst : ARRAY OF CHAR; chr : CHAR; ucs2: BOOLEAN);
VAR
	i, len: LONGINT;
BEGIN
	i := 0;	len := LEN(dst);
	WHILE (id[i] # 0X) & (i < len) DO
		dst[i] := id[i];
		INC(i);
	END;
	(* pad remainder with chr *)
	WHILE i < len DO
		dst[i] := chr;
		INC(i);
	END;
	IF ucs2 THEN
		ConvertUTF8ToUCS2(dst, dst);
	END;
END SetStringWithPadding;

PROCEDURE ConvertUTF8ToUCS2(VAR src, dst: ARRAY OF CHAR);
VAR
	ucs4: ARRAY MaxLen OF LONGINT;
	i, len: LONGINT;
BEGIN
	UTF8Strings.UTF8toUnicode(src, ucs4, len);
	DEC(len);
	i := 0; len := Strings.Min(len, LEN(dst) DIV 2);
	FOR i := 0 TO len-1 DO
		dst[2*i] := CHR(ucs4[i] DIV 100H MOD 100H);
		dst[2*i+1] :=  CHR(ucs4[i] MOD 100H);
	END;
END ConvertUTF8ToUCS2;

(* converts an identifier to a zero terminated utf8 string *)
PROCEDURE ConvertIdentToUTF8*(CONST id: ARRAY OF CHAR; len: LONGINT; ucs2: BOOLEAN; VAR str: ARRAY OF CHAR);
VAR
	i, p, val: LONGINT;
	b: BOOLEAN;
BEGIN
	ASSERT(len <= LEN(id));
	IF ucs2 THEN
		b := TRUE; i := 0; p := 0;
		WHILE (i < len-1) & b DO
			val := ASH(ORD(id[i]), 8) + ORD(id[i+1]);
			b := UTF8Strings.EncodeChar(val, str, p);
			INC(i, 2)
		END;
		str[p] := 0X;
	ELSE
		WHILE (i < len) & (id[i] # 0X) DO
			str[i] := id[i]; INC(i);
		END;
		str[i] := 0X;
	END;
	Strings.TrimRight(str, ' ');
END ConvertIdentToUTF8;

PROCEDURE MakeImageFromDir*(rootDir, isoDest: String; settings: IsoSettings; writeStatusChanged: Utils.StatusProc): LONGINT;
VAR
	root: Directory;
	isotree: DirectoryTree;
BEGIN
	IF ~DirExists(rootDir) THEN
		RETURN ErrDirNotFound;
	END;
	onWriteStatusChanged := writeStatusChanged;
	NEW(root, NIL, settings.volumeIdent, rootDir, 0);
	NEW(isotree, root, settings.isoLevel, settings.flags);
	isotree.Build();
	RETURN MakeImage(isotree, isoDest, settings);
END MakeImageFromDir;

PROCEDURE MakeImageFromTree*(root: Directory; isoDest: String; settings: IsoSettings; writeStatusChanged: Utils.StatusProc): LONGINT;
VAR
	isotree: DirectoryTree;
BEGIN
	onWriteStatusChanged := writeStatusChanged;
	NEW(isotree, root, settings.isoLevel, settings.flags);
	isotree.BuildFromTree();
	RETURN MakeImage(isotree, isoDest, settings);
END MakeImageFromTree;

PROCEDURE MakeImage*(isotree: DirectoryTree; isoDest: String; settings: IsoSettings): LONGINT;
VAR
	fOut: Files.File;
	out: Files.Writer;
	jtree : DirectoryTree;
	isotable, jtable: PathTable;
	lba, freeSpace, padding, res: LONGINT;
	pdescr, sdescr: PSVolumeDescriptor;
	bdescr: BootRecord;
	tdescr: SetTerminator;
	readOnly: BOOLEAN;
BEGIN
	lba := settings.startLba + NumSystemSectors;
	INC(lba, 1); (* Primary Volume descriptor *)

	IF settings.joliet THEN
		INC(lba, 1); (* Supplementary Volume Descriptor *)
	END;
	INC(lba, 1); (* Set Terminator Volume Descriptor *)

	IF settings.bootCatalog # NIL THEN
		INC(lba, 1); (* Boot Record *)
		InitBootRecord(bdescr, lba);
		INC(lba, (settings.bootCatalog.size + SectorSize - 1) DIV SectorSize);
	END;

	isotree.AssignFirstDirLba(lba);
	INC(lba, isotree.size DIV SectorSize);
	NEW(isotable, isotree);
	isotable.Build();
	isotable.lbaLType := lba;
	INC(lba, (isotable.size + SectorSize - 1) DIV SectorSize);
	isotable.lbaRType := lba;
	INC(lba, (isotable.size + SectorSize - 1) DIV SectorSize);

	IF settings.joliet THEN
		jtree := isotree.CloneTree(Joliet);
		jtree.AssignFirstDirLba(lba);
		INC(lba, jtree.size DIV SectorSize);
		NEW(jtable, jtree);
		jtable.Build();
		jtable.lbaLType := lba;
		INC(lba, (jtable.size + SectorSize - 1) DIV SectorSize);
		jtable.lbaRType := lba;
		INC(lba, (jtable.size + SectorSize - 1) DIV SectorSize);
	END;

	IF settings.bootCatalog # NIL THEN
		settings.bootCatalog.AssignFirstImageLba(lba);
		INC(lba, settings.bootCatalog.sizeImages DIV SectorSize);
	END;

	isotree.AssignFirstFileLba(lba);
	INC(lba, isotree.sizeFiles DIV SectorSize);

	IF (lba - settings. startLba) < settings.padToSize THEN
		padding := settings.padToSize - lba;
		INC(lba, padding);
	END;

	InitPSVolumeDescriptor(pdescr, isotree, isotable, lba - settings.startLba, Primary);

	IF settings.joliet THEN
		InitPSVolumeDescriptor(sdescr, jtree, jtable, lba - settings.startLba, Supplementary);
	END;

	(* initialize volume descriptor set terminator *)
	InitSetTerminator(tdescr);

	(* check if there is enough space on destination volume *)
	IF (Utils.IsReadOnly(isoDest^, readOnly) # ResOk) OR (Utils.GetFreeSpace(isoDest^, freeSpace) # ResOk) THEN
		RETURN ErrDestinationInvalid;
	END;
	IF readOnly THEN
		RETURN ErrDestinationReadOnly;
	ELSIF  ((lba - settings.startLba) * SectorSize) DIV 1024 >= freeSpace THEN
		RETURN ErrNotEnoughSpace;
	END;

	NEW(status);

	(* now write the image *)
	fOut := Files.New(isoDest^);
	IF fOut # NIL THEN
		Files.Register(fOut);
		Files.OpenWriter(out, fOut, 0);
		Pad(out, NumSystemSectors*SectorSize);
		WriteVolumeDescriptor(out, SYSTEM.VAL(VolumeDescriptor, pdescr));
		IF settings.bootCatalog # NIL THEN
			(* Boot Record must reside at sector 17 *)
			WriteVolumeDescriptor(out, SYSTEM.VAL(VolumeDescriptor, bdescr));
		END;
		IF settings.joliet THEN
			WriteVolumeDescriptor(out, SYSTEM.VAL(VolumeDescriptor, sdescr));
		END;
		WriteVolumeDescriptor(out, SYSTEM.VAL(VolumeDescriptor, tdescr));
		IF settings.bootCatalog # NIL THEN
			settings.bootCatalog.Write(out);
		END;
		isotree.Write(out);
		isotable.Write(out, LType);
		isotable.Write(out, RType);
		IF settings.joliet THEN
			jtree.Write(out);
			jtable.Write(out, LType);
			jtable.Write(out, RType);
		END;
		IF settings.bootCatalog # NIL THEN
			res := settings.bootCatalog.WriteImages(out);
			IF res # ResOk THEN RETURN res END;
		END;
		res := WriteFiles(out, isotree.root);
		IF res # ResOk THEN RETURN res END;
		Pad(out, padding*SectorSize);
	END;

	out.Update;
	fOut.Update;
	RETURN ResOk;
END MakeImage;

PROCEDURE DirExists(dir: String): BOOLEAN;
VAR
	file: Files.File;
BEGIN
	file := Files.Old(dir^);
	IF file # NIL THEN
		RETURN Files.Directory IN file.flags;
	END;
	RETURN FALSE;
END DirExists;

(* SaveImage is used to copy data cds *)
PROCEDURE SaveImage*(dev: ATADisks.DeviceATAPI; startsec: LONGINT; CONST dest: ARRAY OF CHAR; onWriteStatusChanged: Utils.StatusProc): LONGINT;
VAR
	sec, size, res: LONGINT;
	buf: ARRAY TransferSize*SectorSize OF CHAR;
	pvd: PSVolumeDescriptor;
	f: Files.File;
	w: Files.Writer;
	status: WritingStatus;
BEGIN
	NEW(status);
	sec := startsec + NumSystemSectors;
	IF GetVolumeDescriptor(dev, startsec, pvd, Primary) # ResOk THEN
		RETURN ResErr;
	END;
	size := Utils.ConvertLE32Int(pvd.VolSpaceSize);
	sec := startsec;
	f := Files.New(dest);
	IF f # NIL THEN
		Files.Register(f);
		Files.OpenWriter(w, f, 0);
		WHILE size > TransferSize DO
			dev.Transfer(Disks.Read, sec, TransferSize, buf, 0, res);
			IF res # ResOk THEN RETURN res END;
			w.Bytes(buf, 0, TransferSize*SectorSize);
			IF onWriteStatusChanged # NIL THEN
				INC(status.bytesWritten, TransferSize*SectorSize);
				onWriteStatusChanged(status);
			END;
			DEC(size, TransferSize); INC(sec, TransferSize);
		END;
		IF size > 0 THEN
			dev.Transfer(Disks.Read, sec, size, buf, 0, res);
			IF res # ResOk THEN RETURN res END;
			w.Bytes(buf, 0, size*SectorSize);
			IF onWriteStatusChanged # NIL THEN
				INC(status.bytesWritten, size*SectorSize);
				onWriteStatusChanged(status);
			END;
		END;
	ELSE
		RETURN ResErr;
	END;
	w.Update;
	f.Update;
	RETURN ResOk;
END SaveImage;

PROCEDURE GetVolumeDescriptor*(dev: ATADisks.DeviceATAPI; startsec: LONGINT; VAR descr: PSVolumeDescriptor; descrType: LONGINT): LONGINT;
VAR
	type: CHAR;
	sec, res: LONGINT;
	tmp: ARRAY MaxLen OF CHAR;
	buf: ARRAY SectorSize OF CHAR;
BEGIN
	IF descrType = Primary THEN
		type := 1X;
	ELSE
		type := 2X;
	END;
	sec := startsec + NumSystemSectors;

	(* find descriptor in first 10 sectors following system area *)
	REPEAT
		dev.Transfer(Disks.Read, sec, 1, buf, 0, res);
		IF res # ResOk THEN RETURN res END;
		INC(sec);
	UNTIL  (buf[0] = type) OR (sec > startsec + NumSystemSectors + 10);

	IF buf[0] = type THEN
		SYSTEM.MOVE(ADDRESSOF(buf[0]), ADDRESSOF(descr), SIZEOF(PSVolumeDescriptor));
		ConvertIdentToUTF8(descr.StdIdent, LEN(descr.StdIdent), FALSE, tmp);
		IF tmp = ISO9660Id THEN RETURN ResOk END;
	END;
	RETURN ResErr;
END GetVolumeDescriptor;

PROCEDURE Make*(context : Commands.Context);
VAR
	rootDir, isoDest: String;
	res : LONGINT;
	settings: IsoSettings;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(isoDest^);
	context.arg.SkipWhitespace; context.arg.String(rootDir^);
	settings.isoLevel := IsoLevel1;
	settings.joliet := TRUE;
	settings.volumeIdent := Strings.NewString("NEW");
	IF DirExists(rootDir) THEN
		res := MakeImageFromDir(rootDir, isoDest, settings, NIL);
	END;
END Make;

END MakeIsoImages.

MakeIsoImages.Make TestIso.ISO Auto0:/Daten/Test/
