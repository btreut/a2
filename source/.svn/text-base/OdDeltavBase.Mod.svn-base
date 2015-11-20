MODULE OdDeltavBase;
(** $VCS  16, edgar@edgarschwarz.de, 24.02.02 22:23:03 $
Abstract definitions of DeltaV structures. This module will be used by DAVDeltav which will give instances depending
on e.g. filesystem and DAVDeltavHttpS, DAVDeltavHttpC, DAVDeltavLocalS, DAVDeltavLocalC (clients and servers)
Stuff taken from 18.
$Log$
$  18, edgar@edgarschwarz.de, 27.02.02 22:30:45
Now read from conf.
$  17, edgar@edgarschwarz.de, 27.02.02 22:19:17
Open conf if there are no checkFrozenVCRs().
$  16, edgar@edgarschwarz.de, 24.02.02 22:23:03
scanLeadingDigits added.
$  15, edgar@edgarschwarz.de, 24.02.02 17:46:24
Some messages improved.
$  14, edgar@edgarschwarz.de, 24.02.02 17:32:16
History manager now with digit prefix.
$  13, edgar@edgarschwarz.de, 11.02.02 10:29:10
ToDo list updated.
$  12, edgar@edgarschwarz.de, 10.02.02 17:17:59
Now also works from panel.
$   7, edgar@edgarschwarz.de, 09.02.02 22:12:21
compareBaseline fixed, Texts.Scanner -> Attributes.Scanner.
$   6, edgar@edgarschwarz.de, 05.02.02 00:22:41
compare with configuration if CV1 = leer.
$   5, edgar@edgarschwarz.de, 03.02.02 23:36:07
compareBaseline added, reportConfiguration improved.
$   4, edgar@edgarschwarz.de, 27.01.02 14:40:34
reportConfiguration added.
$   3, edgar@edgarschwarz.de, 24.01.02 22:43:11
Build VccList and VcrList structure on reportConfiguration.
$   2, edgar@edgarschwarz.de, 15.01.02 23:39:30
Recursive freeze and select for configurations.
$   1, edgar@edgarschwarz.de, 06.01.02 22:36:34
First baseline of DAVDeltav stuff.
**)
IMPORT OdVCSBase, OdUtil, OdCond, XMLObjects,
	Files, Streams, KernelLog, XML, OdXml, WebHTTP, Dates, Strings;
(* Filetypes for NO and WO
					file: 		properties         collection:            properties			   configuration data   version
															CollCh                  CollCh,PropCh  		PropCh				 	PropCh,VerCh
	F32	    <res>		<res>_			    <confname>/	  <confname>__           <confname>_	  	<confname>_.<num>
*)

CONST
	DefaultHostName = "127.0.0.1";
	VersionMarker = "/hist/";
	(*RepoMount = "FTP:";*)
	RepoMount = "";
	DefaultRepoPath = "../httproot/dav/repo/";
	(*Workspace* = "FAT:/HTTPROOT/webdav/";*)
	DefaultWorkspace="../httproot/dav/root/";
	(*WorkspaceTemp* = "FAT:/httproot/webdav/temp";*)
	DefaultWorkspaceTemp="../httproot/dav/temp/";
	VerCh* = '.'; (* delimiter before version number *)
	Indent = 9X; (* Tab *)
	CR = 0DX; (* Carriage return *)
	(* CollCh: (pseudo) collection delimiter. PropCh: VCR property files. ConfCh: Conf data files. *)
	CollCh* = '/';  PropCh* = '_'; ConfCh* = '_';
(* Filetypes for NO and WO
					file: 		properties         collection:            properties			   configuration data   version
															CollCh                  CollCh,PropCh  		PropCh				 	PropCh,VerCh
	NO		<res>		<res>.			    <confname>.	    <confname>..    	  <confname>.			<confname>..<num>
	F32	    <res>		<res>_			    <confname>/	  <confname>/__         <confname>/_	  	<confname>_.<num>
	NO		<res>		<res>.			    <confname>.	    <confname>..    	  <confname>.			<confname>..<num>
*)
CONST
	MaxVal = 512;


TYPE
(** A list of version urls *)
VcrList* = OBJECT (OdUtil.Link)
	VAR state*, (* like in properties. *)
    path*, (* name reative to VCC *)
	version*: OdUtil.Line; (* version URL *)

	PROCEDURE &vcrList*(p, v: OdUtil.Line);
	BEGIN link(); path := p; version := v; END vcrList;

	(* Find a vcr in a VCR list. compare version URL *)
	PROCEDURE find(vcr: VcrList): VcrList;
	VAR vcrs: VcrList; confA, confB, resA, resB, verA, verB: OdUtil.Line;
	BEGIN vcrs := SELF;
		WHILE vcrs # NIL DO
			(** ) OdUtil.Msg4("VcrList.find:", vcrs.version, ':', vcr.version); ( **)
			confA := ''; splitConfResVer(vcrs.version, confA, resA, verA);
			confB := ''; splitConfResVer(vcr.version, confB, resB, verB);
			IF resA = resB THEN
				(** ) OdUtil.Msg6("VcrList.found:", resA, verA, ':', resB, verB); ( **)
				RETURN vcrs;
			END;
			IF vcrs.next # NIL THEN vcrs := vcrs.next(VcrList); ELSE vcrs := NIL; END;
		END;
		RETURN NIL;
	END find;

	PROCEDURE show(indent: OdUtil.Line);
	VAR vcr: VcrList;
	BEGIN vcr := SELF;
		LOOP
			OdUtil.Msg3(indent, vcr.path, vcr.version);
			IF vcr.state = "thawed" THEN OdUtil.Msg1(" thawed"); END;
			(* NIL test  *)
			IF vcr.next = NIL THEN EXIT; ELSE vcr := vcr.next(VcrList); END;
		END;
	END show;

	PROCEDURE xml(host: ARRAY OF CHAR; crRes: OdXml.ConfigurationReportRes; ms: XML.Element);
	VAR vcr: VcrList;
	BEGIN vcr := SELF;
		LOOP
			(* HACK. How to avoid this switch ? There are different signatures but the same logical action. *)
			IF crRes IS OdXml.CompareBaselineReportRes THEN
				crRes(OdXml.CompareBaselineReportRes).addVcrType(ms, crRes(OdXml.CompareBaselineReportRes).type,
					 vcr.path, vcr.version);
			ELSIF crRes IS OdXml.BaselineReportRes THEN
				crRes(OdXml.BaselineReportRes).addVcr(host, ms, vcr.path, vcr.version);
			ELSE
				crRes.addVcrState(host, ms, vcr.path, vcr.version, vcr.state);
			END;
			IF vcr.next = NIL THEN EXIT; ELSE vcr := vcr.next(VcrList); END;
		END;
	END xml;
END VcrList;

(** A version controlled configuration. *)
VccList* = OBJECT (VcrList)
	(* A VCC also has a path and a version URL *)
	VAR vcrs*: VcrList; (* VCRs of VCC *)
	vccs*:VccList; (* subcomponents(subbaselines) of VCC *)
	PROCEDURE &vccList*(p, v: OdUtil.Line); BEGIN vcrList(p, v); vcrs := NIL; vccs:= NIL; END vccList;

	PROCEDURE show0(indent: OdUtil.Line); (* Show with depth=0 *)
	VAR vcc: VccList;
	BEGIN vcc := SELF;
		LOOP
			OdUtil.Msg3(indent, vcc.path, vcc.version);
			IF vcc.state = "thawed" THEN OdUtil.Msg1(" thawed"); END;
			(* NIL test  *)
			IF vcc.next = NIL THEN EXIT; ELSE vcc := vcc.next(VccList); END;
		END;
	END show0;

	PROCEDURE show*(indent: OdUtil.Line);
	VAR vcc: OdUtil.Link; (* for easy going to next *)
	BEGIN
		(* vcc itself *)
		OdUtil.Msg4(indent, "vcc: ", path, version);
		IF state = "thawed" THEN OdUtil.Msg1(" thawed"); END;
		Strings.AppendChar(indent, Indent);
		IF vcrs # NIL THEN vcrs.show(indent); END;
		vcc := vccs;
		WHILE vcc # NIL DO
			vcc(VccList).show(indent);
			vcc := vcc.next;
		END;
	END show;

	PROCEDURE xml*(host: ARRAY OF CHAR; crRes: OdXml.ConfigurationReportRes; ms: XML.Element);
	VAR vcc: OdUtil.Link; (* for easy going to next *)
	BEGIN
		IF vcrs # NIL THEN vcrs.xml(host, crRes, ms); END;
		vcc := vccs;
		WHILE vcc # NIL DO
			vcc(VccList).xml(host, crRes, ms);
			vcc := vcc.next;
		END;
	END xml;
END VccList;


(** "Version compare" information. Two version URLs for a changed version in baseline-compare. *)
VcrDiff* = OBJECT (OdUtil.Link)
    VAR pathA*, pathB, (* name reative to VCC *)
	versionA*, versionB: OdUtil.Line; (* version URL *)
	PROCEDURE &VcrDiffNew*(a, b: VcrList);
		BEGIN link();
			pathA := a.path; versionA := a.version; pathB := b.path; versionB := b.version;
		END VcrDiffNew;
	PROCEDURE show(indent: OdUtil.Line);
	VAR vcr: VcrDiff;
	BEGIN vcr := SELF;
		LOOP
			OdUtil.Msg6(indent, vcr.pathA, ': ', vcr.versionA, vcr.versionB, CRString);
			IF vcr.next = NIL THEN EXIT; ELSE vcr := vcr.next(VcrDiff); END;
		END;
	END show;

	PROCEDURE xml(host: ARRAY OF CHAR; crRes: OdXml.CompareBaselineReportRes; ms: XML.Element);
	VAR vcrDiff: VcrDiff;
	BEGIN vcrDiff := SELF;
		LOOP
			(* TODO: Just give the two versions at the moment instead. Paths are missing. How in RFC ? *)
			crRes.addVcrType(ms, crRes.type, vcrDiff.versionA, vcrDiff.versionB);
			IF vcrDiff.next = NIL THEN EXIT; ELSE vcrDiff := vcrDiff.next(VcrDiff); END;
		END;
	END xml;
END VcrDiff;

(** Baseline-compare information *)
VccDiff* = OBJECT (VcrDiff)
	VAR addedVcrs, deletedVcrs: VcrList;
	changedVcrs: VcrDiff;
	addedVccs, deletedVccs: VccList;
	changedVccs: VccDiff;
	PROCEDURE &VccDiffNew*(old, new: VccList);
	CONST PLog = FALSE;
	VAR vcrOld, vcrNew, vcrTemp: VcrList; vcrDiff: VcrDiff;
		   vccOld, vccNew: VccList;                vccDiff: VccDiff;
	BEGIN
		VcrDiffNew(old, new); addedVcrs := NIL; deletedVcrs := NIL; changedVcrs := NIL;
		addedVccs := NIL; deletedVccs := NIL; changedVccs := NIL;
		(* look for deleted and changed VCRs by iterating over  old VCRs *)
		(*Msg1("vccDiff: VCR deleted and changed");*)
		vcrOld := old.vcrs;
		WHILE vcrOld # NIL DO
			IF new.vcrs # NIL THEN
				vcrNew := new.vcrs.find(vcrOld);
			ELSE
				vcrNew := NIL;
			END;
			IF vcrNew = NIL THEN (* deleted *)
				IF PLog THEN OdUtil.Msg2("VCR deleted:", vcrOld.path); END;
				IF deletedVcrs = NIL THEN NEW(deletedVcrs, vcrOld.path, vcrOld.version);
				ELSE NEW(vcrNew, vcrOld.path, vcrOld.version);  deletedVcrs.add(vcrNew); END;
			ELSE (* possibly changed *)
				IF vcrOld.version # vcrNew.version THEN
					IF PLog THEN OdUtil.Msg4("VCR changed", vcrOld.path, vcrOld.version, vcrNew.version); END;
					IF changedVcrs = NIL THEN NEW(changedVcrs, vcrOld, vcrNew);
					ELSE NEW(vcrDiff, vcrOld, vcrNew);  changedVcrs.add(vcrDiff); END;
				ELSE
					IF PLog THEN OdUtil.Msg2("VCR unchanged:", vcrOld.path); END;
				END;
			END;
			(*Msg1("vccDiff deleted and changed: next");*)
			IF vcrOld.next # NIL THEN vcrOld := vcrOld.next(VcrList); ELSE vcrOld := NIL; END;
		END;
		(* look for added VCRs by iterating over  new VCRs *)
		(*Msg1("vccDiff: VCR added");*)
		vcrNew := new.vcrs;
		WHILE vcrNew # NIL DO
			IF old.vcrs # NIL THEN
				vcrOld := old.vcrs.find(vcrNew);
			ELSE
				vcrOld := NIL;
			END;
			IF vcrOld = NIL THEN (* added *)
				IF PLog THEN OdUtil.Msg2("VCR added;", vcrNew.path); END;
				IF addedVcrs = NIL THEN NEW(addedVcrs, vcrNew.path, vcrNew.version);
				ELSE NEW(vcrOld, vcrNew.path, vcrNew.version);  addedVcrs.add(vcrOld); END;
			END;
			(*Msg1("vccDiff added: next");*)
			IF vcrNew.next # NIL THEN vcrNew := vcrNew.next(VcrList); ELSE vcrNew := NIL; END;
		END;
		(* look for deleted and changed VCCs by iterating over  old VCCs *)
		(*Msg1("vccDiff: VCC deleted and changed");*)
		vccOld := old.vccs;
		WHILE vccOld # NIL DO
			IF new.vccs # NIL THEN
				vcrTemp := new.vccs.find(vccOld); vccNew := vcrTemp(VccList);
			ELSE (* No subconfigurations in new VCC. *)
				vccNew := NIL;
			END;
			IF vccNew = NIL THEN (* deleted *)
				IF PLog THEN OdUtil.Msg2("VCC deleted:", vccOld.path); END;
				(* dont care about the VCRs they aren't of interest in this case. *)
				IF deletedVccs = NIL THEN NEW(deletedVccs, vccOld.path, vccOld.version);
				ELSE NEW(vccNew, vccOld.path, vccOld.version);  deletedVccs.add(vccNew); END;
			ELSE (* possibly changed *)
				IF vccOld.version # vccNew.version THEN
					IF PLog THEN OdUtil.Msg4("VCC changed:", vccOld.path, vccOld.version, vccNew.version); END;
					IF changedVccs = NIL THEN NEW(changedVccs, vccOld, vccNew);
					ELSE NEW(vccDiff, vccOld, vccNew);  changedVccs.add(vccDiff); END;
				ELSE
					IF PLog THEN OdUtil.Msg2("VCC unchanged:", vccOld.path); END;
				END;
			END;
			(*Msg1("vccDiff deleted and changed: next");*)
			IF vccOld.next # NIL THEN vccOld := vccOld.next(VccList); ELSE vccOld := NIL; END;
		END;
		(* look for added VCCs by iterating over  new VCCs *)
		(*Msg1("vccDiff added");*)
		vccNew := new.vccs;
		WHILE vccNew # NIL DO
			IF old.vccs # NIL THEN
				vcrTemp := old.vccs.find(vccNew); vccOld := vcrTemp(VccList);
			ELSE (* No subconfigurations in old VCC. *)
				vccOld := NIL;
			END;
			IF vccOld = NIL THEN (* added *)
				IF PLog THEN OdUtil.Msg2("VCC added:", vccNew.path); END;
				(* dont care about the VCRs they aren't of interest in this case. *)
				IF addedVccs = NIL THEN NEW(addedVccs, vccNew.path, vccNew.version);
				ELSE NEW(vccOld, vccNew.path, vccNew.version);  addedVccs.add(vccOld); END;
			END;
			(* OdUtil.Msg1("vccDiff added: next"); *)
			IF vccNew.next # NIL THEN vccNew := vccNew.next(VccList); ELSE vccNew := NIL; END;
		END;
	END VccDiffNew;
	PROCEDURE show*(indent: OdUtil.Line);
	VAR indent1: OdUtil.Line;
	BEGIN
		OdUtil.Msg6(indent, "", "vccdiff:", pathA, versionA, versionB);
		Strings.AppendChar(indent, Indent); indent1 := indent; Strings.AppendChar(indent1, Indent);
		IF addedVcrs # NIL THEN OdUtil.Msg3(indent, "", "added VCRs"); addedVcrs.show(indent1); END;
		IF deletedVcrs # NIL THEN OdUtil.Msg3(indent, "", "deleted VCRs"); deletedVcrs.show(indent1); END;
		IF changedVcrs # NIL THEN OdUtil.Msg3(indent, "", "changed VCRs"); changedVcrs.show(indent1); END;
		IF addedVccs # NIL THEN OdUtil.Msg3(indent, "", "added VCCs"); addedVccs.show0(indent1); END;
		IF deletedVccs # NIL THEN OdUtil.Msg3(indent, "", "deleted VCCs"); deletedVccs.show0(indent1); END;
		IF changedVccs # NIL THEN OdUtil.Msg3(indent, "", "changed VCCs"); changedVccs.show(indent1); END;
	END show;

	PROCEDURE xml*(host: ARRAY OF CHAR; cbrRes: OdXml.CompareBaselineReportRes; ms: XML.Element);
	VAR vcc: OdUtil.Link; (* for easy going to next *)
	BEGIN
		IF addedVcrs     # NIL THEN cbrRes.type := "added";    addedVcrs.xml(host, cbrRes, ms); END;
		IF deletedVcrs  # NIL THEN cbrRes.type := "deleted";  deletedVcrs.xml(host, cbrRes, ms); END;
		IF changedVcrs # NIL THEN cbrRes.type := "changed"; changedVcrs.xml(host, cbrRes, ms); END;
		(* TODO: vcc stuff
		vcc := vccs;
		WHILE vcc # NIL DO
			vcc(VccList).xml(crRes, ms);
			vcc := vcc.next;
		END;
		*)
	END xml;

END VccDiff;
TYPE
(*  *)
Version = OBJECT
	VAR next: Version;
	PROCEDURE &init*;
		BEGIN next := NIL;
		END init;
	PROCEDURE add * (version: Version);
	    VAR old: Version;
		BEGIN old := SELF;
			WHILE old.next # NIL DO old := old.next;  END;
			old.next := version;
		END add;
END Version;

(*  *)
TYPE
VersionProperties * = OBJECT
	VAR
		fileName, propName: OdUtil.Line; f: Files.File;
		propVal: ARRAY MaxVal OF CHAR;
		state*, versionHistory*, versionName*, creatorDisplayname*, comment*: OdUtil.Line;
		creationDate*, keywords*, versionURL*: OdUtil.Line;
		fields: WebHTTP.AdditionalField; (*   *)
	PROCEDURE &init*(conf, res: ARRAY OF CHAR);
		CONST PLog = FALSE;
		VAR r: Files.Reader;
		BEGIN
			(* Property information for a VCR is stored in a file with extension PropCh *)
			state := ""; (* "", "frozen", "thawed" *)
			(* Version: predecessorSet, successorSet, checkoutSet, versionName, versionHistory *)
			(* Resource: creatorDisplayname, comment *)
			versionHistory := ""; versionName := ""; creatorDisplayname := ""; comment := "";
			(* Own stuff *)
			creationDate := ""; keywords := "f"; state := ""; (* "", "frozen", "thawed" *)
			versionURL := "";
			IF (conf = "") & (res = "") THEN RETURN END; (* Look for parent of a configuration. *)
			IF isConfiguration(res) THEN
				fileName := ConfDataFileName(res); Strings.Append(fileName, PropCh);
			ELSIF isConfDataFileName(res) THEN
				IF res[0] = '/' THEN
					COPY(workMan.prefix, fileName);
					unpadConfiguration(fileName);
					Strings.Append(fileName, res);
				ELSE COPY(res, fileName);
				END;
				Strings.Append(fileName, PropCh);
			ELSE
				fileName := ResPropFileName(conf, res);
			END;
			fields := NIL;
			IF PLog THEN OdUtil.Msg6("VP.init:", conf, ":", res, ":", fileName); END;
			f := Files.Old(fileName);
			IF f # NIL THEN
				Files.OpenReader(r, f, 0);
				LOOP
					r.RawString(propName);
					IF  r.res # 0 THEN
						EXIT;
					ELSE
						r.RawString(propVal);
						(** ) OdUtil.Msg3("VP.init.prop:", propName, propVal); ( **)
						IF       propName = "state" THEN COPY(propVal, state);
						ELSIF propName = "versionHistory" THEN COPY(propVal, versionHistory);
						ELSIF propName = "versionName" THEN COPY(propVal, versionName);
						ELSIF propName = "creatorDisplayname" THEN COPY(propVal, creatorDisplayname);
						ELSIF propName = "comment" THEN COPY(propVal, comment);
						ELSIF propName = "creationDate" THEN COPY(propVal, creationDate);
						ELSIF propName = "keywords" THEN COPY(propVal, keywords);
						ELSE
							WebHTTP.SetAdditionalFieldValue(fields, propName, propVal);
						END;
						versionURL := versionHistory; Strings.Append(versionURL, VerCh); Strings.Append(versionURL, versionName);
					END;
				END;
			END;
		END init;

		PROCEDURE set*(prop: OdUtil.Line; val: ARRAY OF CHAR);
		BEGIN
			IF       prop = "state" THEN COPY(val, state);
			ELSIF prop = "versionHistory" THEN COPY(val, versionHistory);
			ELSIF prop = "versionName" THEN  COPY(val, versionName);
			ELSIF prop = "creatorDisplayname" THEN  COPY(val, creatorDisplayname);
			ELSIF prop = "comment" THEN  COPY(val, comment);
			ELSIF prop = "creationDate" THEN  COPY(val, creationDate);
			ELSIF prop = "keywords" THEN  COPY(val, keywords );
			ELSE (* other property *)
				WebHTTP.SetAdditionalFieldValue(fields, prop, val);
			END;
			(** ) OdUtil.Msg4("VP.store.prop:", fileName, prop, val); ( **)
			store(); (* At the moment update file with every set. *)
		END set;

		PROCEDURE get*(prop: OdUtil.Line; VAR val: ARRAY OF CHAR);
		VAR ok: BOOLEAN;
		BEGIN
			IF       prop = "state" THEN COPY(state, val);
			ELSIF prop = "versionHistory" THEN COPY(versionHistory, val);
			ELSIF prop = "versionName" THEN COPY(versionName, val);
			ELSIF prop = "creatorDisplayname" THEN COPY(creatorDisplayname, val);
			ELSIF prop = "comment" THEN COPY(comment, val);
			ELSIF prop = "creationDate" THEN COPY(creationDate, val);
			ELSIF prop = "keywords" THEN COPY(keywords, val);
			ELSE
				ok := WebHTTP.GetAdditionalFieldValue(fields, prop, val);
				(** ) OdUtil.Msg3("VP.get:", prop, val); ( **)
			END;
		END get;

		PROCEDURE store;
			VAR erg: LONGINT; w: Files.Writer; field: WebHTTP.AdditionalField;
			PROCEDURE nameVal(name, value: ARRAY OF CHAR (*OdUtil.Line*));
			BEGIN
				IF value # '' THEN
					(* Strings are written with terminating 0X *)
					w.RawString(name); w.RawString(value);
				END;
			END nameVal;
		BEGIN
			(** ) OdUtil.Msg2("VersionProperties.store", fileName); ( **)
			f := Files.New(fileName);
			IF f # NIL THEN (* write data *)
				Files.OpenWriter(w, f, 0);
				nameVal("state", state);
				nameVal("versionHistory", versionHistory);
				nameVal("versionName", versionName);
				nameVal("creatorDisplayname", creatorDisplayname);
				nameVal("comment", comment);
				nameVal("creationDate", creationDate);
				nameVal("keywords", keywords );
				field := fields;
				WHILE field # NIL DO
					nameVal(field.key, field.value);
					field := field.next;
				END;
				w.Update;
				Files.Register(f);
			ELSE
				OdUtil.Msg2("VersionProperties.store: error f = NIL, filename =", fileName);
			END;
		END store;
END VersionProperties;

(*  *)
TYPE
(** Repository root: OFSTools.Mount R FatFS IDE0#04 |WebDAV/Repository ~
There will be an &init() later. *)
RepositoryManager = OBJECT
VAR
	prefix: OdUtil.Line;

	PROCEDURE &Init*;
	BEGIN
		SELF.prefix := OdVCSBase.BaseDir;
	END Init;

	PROCEDURE newHistory*(res: OdUtil.Line): OdUtil.Line;
	CONST PLog = FALSE;
	VAR enum: Files.Enumerator;
		flags, entryFlags: SET; time, date, size: LONGINT; pattern, last, hist, name, dir, base: OdUtil.Line;
		numPos: LONGINT; prefix: OdUtil.Line;
	BEGIN
		numPos := Strings.Length(prefix);
		flags := {}; last := prefix;
		IF PLog THEN OdUtil.Msg2("RepMan: resAlt = ", res); END;
		IF isConfiguration(res) THEN  res := ConfShortDataFileName(res); END; (* A configuration is / terminated. *)
		splitDirBase(res, dir, base);
		pattern := prefix; Strings.Append(pattern, '*'); Strings.Append(pattern, base); Strings.Append(pattern, '.VCS');
		IF PLog THEN OdUtil.Msg3("RepMan: resNeu,pattern = ", res, pattern); END;
		NEW(enum); enum.Open(pattern, flags);
		WHILE enum.GetEntry(name, entryFlags, time, date, size) DO
			IF (name[numPos] >= '0') & (name[numPos] <= '9') THEN last := name; END;
		END;
		IF last = prefix THEN (* no resource with this name yet exists. *)
			hist := '0'; Strings.Append(hist, base);
		ELSE (* Inc number *)
			hist := ' '; hist[0] := CHR(ORD(last[numPos])+1); Strings.Append(hist, base);
		END;
		IF PLog THEN OdUtil.Msg2("RepMan: hist = ", hist); END;
		RETURN hist;
	END newHistory;

	(* Get repository filename. History name beginning with '/' is optional. *)
	PROCEDURE repName*(hist: OdUtil.Line): OdUtil.Line;
	VAR rep: OdUtil.Line;
	BEGIN
		rep := prefix;
		IF hist[0] = '/' THEN (* drop trailing '/' of repository prefix. *)
			unpadConfiguration(rep);
		END;
		Strings.Append(rep, hist);
		RETURN rep;
	END repName;
END RepositoryManager;

TYPE
(** Workspace root: OFSTools.Mount W FatFS IDE0#09 |WebDAV/Workspaces ~
 Will get more functionality in the future. *)
WorkspaceManager * = OBJECT
	VAR prefix - : ARRAY 128 OF CHAR; TempDir-: ARRAY 8 OF CHAR;
	PROCEDURE &Init*(prefix: ARRAY OF CHAR);
	BEGIN
		SELF.TempDir := "/temp";
		COPY(prefix, SELF.prefix);
	END Init;

	PROCEDURE SetPrefix * (prefix: ARRAY OF CHAR);
	BEGIN
		COPY(prefix, SELF.prefix);
	END SetPrefix;

	PROCEDURE prefixLen(): LONGINT;
	BEGIN
		RETURN Strings.Length(prefix);
	END prefixLen;
END WorkspaceManager;


(*  DavTexts  *)
TYPE
(*  *)
(*  *)
Server * = OBJECT
	VAR
		root: OdUtil.Line;
	PROCEDURE &initServer*(root: OdUtil.Line);
		BEGIN SELF.root := root; END initServer;
	(**                                                      freeze                                                      **)
	PROCEDURE freezeResource(conf, res, hist: OdUtil.Line; log: OdVCSBase.TLog; flags: SET);
		CONST Log = FALSE;
		VAR historyName, fileName: OdVCSBase.TFileName; nv: LONGINT; ver, verStr: OdUtil.Line;
		BEGIN
			ver := ResFileName(conf, res); COPY(ver, fileName); (* Compiler problem. *)
			COPY(root, historyName); Strings.Append(historyName, hist); (* Prefix added to history. *)
			IF Log THEN OdUtil.Msg3("DAVDeltavBase.fR:", historyName, fileName); END;
			nv := OdVCSBase.Create(historyName, fileName, log, flags);
			IF nv > 0 THEN
				(* Select the new version for the VCR *)
				COPY(fileName, ver); Strings.Append(ver, VerCh);
				Strings.IntToStr(nv, verStr);
				Strings.Append(ver, verStr);
				selectResource(conf, res, hist, ver);
			ELSE
				preCond := OdCond.ErrorMsg;
				OdC.SetError(WebHTTP.InternalServerError, OdVCSBase.errMsg, -1);
			END;
		END freezeResource;
	PROCEDURE freezeInitialResource*(conf, res: OdUtil.Line; log: OdVCSBase.TLog; flags: SET); (*  VERSION-CONTROL  *)
		CONST PLog = FALSE;
		VAR confProps, props: VersionProperties; hist: OdUtil.Line;
		BEGIN
			preCond := OdCond.Ok;
			IF conf # "" THEN
				NEW(confProps, "", conf);
				IF confProps.state = "frozen" THEN
					preCond := OdCond.MustNotUpdateBaselineCollection;
					RETURN;
				END;
			END;
			NEW(props, conf, res);
			IF props.state # "" THEN
				(* 3.5. Just warn for the moment. This can happen if a server used auto-checkin. *)
				OdUtil.Msg3(conf, res, "resource already under version control");
			ELSE
				IF PLog THEN OdUtil.Msg2(res, " before newHistory"); END;
				hist := repMan.newHistory(res);
				freezeResource(conf, res, hist, log, flags);
			END;
		END freezeInitialResource;

	PROCEDURE equalVersion(conf, res, hist, ver: OdUtil.Line): BOOLEAN;
		CONST TempBase = "equal";
		VAR erg: LONGINT; f1, f2: Files.File; equal: BOOLEAN; resName, resPropName, tempDir: OdUtil.Line;
		BEGIN
			resName := ResFileName(workMan.TempDir, TempBase);
			resPropName := ResPropFileName(workMan.TempDir, TempBase);
			COPY(workMan.TempDir, tempDir);
			selectResource(tempDir, TempBase, hist, ver); (* get version to temporary file *)
			IF preCond = OdCond.Ok THEN
				f1 := Files.Old(ResFileName(conf, res)); f2 := Files.Old(resName);
				equal := FileEqual(f1, f2);
				Files.Register(f1); Files.Register(f2);
				RETURN equal;
			ELSE
				preCond := OdCond.ErrorMsg;
				OdC.SetError(WebHTTP.InternalServerError, OdVCSBase.errMsg, -1);
				RETURN FALSE;
			END;
		END equalVersion;

	PROCEDURE freezeOtherResource*(conf, res: OdUtil.Line; log: OdVCSBase.TLog; flags: SET); (* CHECKIN  *)
		CONST PLog = FALSE;
		VAR confProps, props: VersionProperties;
		BEGIN
			NEW(confProps, "", conf);
			IF confProps.state = "frozen" THEN
				preCond := OdCond.VccMustBeCheckedOut;
				RETURN;
			END;
			NEW(props, conf, res);
			IF props.versionHistory = "" THEN
				preCond := OdCond.VersionHistoryIsTree;
			ELSIF props.state = "frozen" THEN
				preCond := OdCond.MustBeCheckedOutVcr;
			ELSE
				IF PLog THEN OdUtil.Msg5("before equalVersion:", conf, res, props.versionHistory, props.versionURL); END;
				IF equalVersion(conf, res, props.versionHistory, props.versionURL) THEN
					props.set("state", "frozen");
					preCond := OdCond.CheckedOutVersionUnchanged;
				ELSE
					freezeResource(conf, res, props.versionHistory, log, flags);
				END;
			END;
		END freezeOtherResource;

	(* Delete VCRs and VCCs (subbaseline). Simple way of cleaning up. It would be more efficient to keep the
		list of the frozen VCRs from checking and only delete unnecessary VCRs or with the wrong version. *)
	PROCEDURE deleteFrozenVCRs(conf: OdUtil.Line);
	CONST PLog = FALSE;
	VAR lines: OdUtil.Lines; erg: LONGINT; resName, resPropName, fileName: OdUtil.Line;
	BEGIN
		(* Delete existing resources *)
		IF PLog THEN OdUtil.Msg2("deleteFrozenVCRs:", conf); END;
		lines := findVCRs(conf);
		WHILE lines # NIL DO
			resName := lines.line;
			resPropName := lines.line; Strings.Append(resPropName, PropCh);
			IF PLog THEN OdUtil.Msg3("deleteFrozenVCRs:", resName, resPropName); END;
			Files.Delete(resName, erg); (* remove resource *)
			Files.Delete(resPropName, erg);  (* remove property file *)
			lines := lines.next;
		END;
		(* Delete existing subconfigurations. *)
		lines := findVCCs(conf);
		WHILE lines # NIL DO
			IF PLog THEN OdUtil.Msg2("deleting subbaseline", lines.line); END;
			deleteFrozenVCRs(lines.line);
			fileName := ConfDataFileName(lines.line);
			Files.Delete(fileName, erg); (* remove configuration file *)
			fileName := ConfPropFileName(lines.line);
			Files.Delete(fileName, erg);  (* remove property file *)
			lines := lines.next;
		END;
	END deleteFrozenVCRs;

	(* Check whether all VCRs of a configuration are frozen. Return a text which can be written to '<conf>.'
		in case of success. Check also VCRs of subconfigurations but don't add them to writer (root= FALSE) *)
	PROCEDURE checkFrozenVCRs(conf: OdUtil.Line; root: BOOLEAN; VAR w: Files.Writer): BOOLEAN;
	CONST PLog = FALSE;
	VAR allFrozen: BOOLEAN; subconfs, lines: OdUtil.Lines; confLen: LONGINT; res:OdUtil.Line; props: VersionProperties;
	BEGIN
		IF PLog THEN OdUtil.Msg2("checkFrozenVCRs:", conf); END;
		lines := findVCRs(conf); (* from filesystem *)
		confLen := Strings.Length(conf);
		allFrozen := TRUE;
		WHILE lines # NIL DO
			splitConfRes(lines.line, conf, res); (* <ws>/test/Test.html, /test => Test.html *)
			IF PLog THEN OdUtil.Msg4("checkFrozenVCRs:", lines.line, conf, res); END;
			NEW(props, conf, res);
			IF props.state = "frozen" THEN
				IF root THEN
					IF PLog THEN OdUtil.Msg2(lines.line, "frozen."); END;
					w.String(res); w.Char(' ');
					w.String(props.versionHistory); w.Char(VerCh);
					w.String(props.versionName); w.Ln();
				END;
			ELSIF props.state = "" THEN
				(* Subconfiguration erronously appear as VCRs. But don't have sensible state normally. *)
				IF PLog THEN OdUtil.Msg2(lines.line, "configuration"); END;
			ELSE
				IF PLog THEN OdUtil.Msg2(lines.line, "not frozen."); END;
				allFrozen := FALSE;
			END;
			lines := lines.next;
		END;
		IF allFrozen THEN (* check subconfigurations *)
			subconfs := findVCCs(conf); (* From file <conf> *)
			WHILE subconfs # NIL DO
				IF PLog THEN  OdUtil.Msg2("checkFrozenVCRs: subconf", subconfs.line); END;
				IF ~checkFrozenVCRs(subconfs.line, FALSE, w) THEN allFrozen := FALSE; END;
				subconfs := subconfs.next;
			END;
		END;
		RETURN allFrozen;
	END checkFrozenVCRs;

	(** Freeze a configuration and recursively it's subconfigurations. Only freeze if all VCRs are frozen. *)
	PROCEDURE freezeConfiguration(mode, conf, hist: OdUtil.Line; log: OdVCSBase.TLog; flags: SET);(* BASELINE-CONTROL  *)
		CONST PLog = FALSE;
		VAR subconf: OdUtil.Line; subconfs: OdUtil.Lines; textLen: LONGINT; allFrozen: BOOLEAN; props: VersionProperties;
			f: Files.File; r: Files.Rider; erg: INTEGER; fileName: OdUtil.Line; w: Files.Writer;
		BEGIN
			fileName := ConfDataFileName(conf);
			IF PLog THEN OdUtil.Msg3("freezeConfiguration.ConfDataFileName:", conf, fileName); END;
			f := Files.New(fileName); Files.OpenWriter(w, f, 0);
			IF PLog THEN OdUtil.Msg4("freezeConfiguration: ", mode, conf, hist); END;
			unpadConfiguration(conf);
			allFrozen := checkFrozenVCRs(conf, TRUE, w); (* w contains <path>,<url> pairs of VCRs for later writing to file <conf> *)
			IF allFrozen THEN (* freeze subconfigurations if necessary *)
				subconfs := findVCCs(conf); (* From file <conf> *)
				WHILE subconfs # NIL DO (* Freeze subconfigurations if necessary with some log data. *)
					IF PLog THEN OdUtil.Msg3("freeze subconf", conf, subconfs.line);  END;
					(* subconf := FullSubconfName(conf, subconfs.line); *)
					subconf := subconfs.line;
					padConfiguration(subconf);
					NEW(props, "", subconf);
					IF props.state = "" THEN (* unversioned *)
						freezeConfiguration("initial", subconf, hist, log, flags);
						IF PLog THEN OdUtil.Msg3("freezeConfigurations: subconf ", subconf, "created"); END;
					ELSIF props.state = "thawed" THEN (* thawed, so freeze it *)
						freezeConfiguration("other", subconf, hist, log, flags);
						IF PLog THEN OdUtil.Msg3("freezeConfigurations: subconf ", subconf, "frozen"); END;
					ELSE
						IF PLog THEN OdUtil.Msg3("freezeConfigurations: subconf ", subconf, "was already frozen"); END;
					END;
					NEW(props, "", subconf); (* Data was perhaps changed on checkin. So reload. *)
					(* If a sub configuration is 'below' the root configuration this is shown by leading dots.
					    .<name> means starting with the local directory. ..<name> could mean going up. This
					    would make sense in navigating relative to a ws/root configuration. This could mean
					    that an additional root configuration parameter must be there.*)
					IF Strings.Pos(conf, subconf) = 0 THEN (* a relative name *)
						Slice(subconf, Strings.Length(conf)+1, Strings.Length(subconf) - Strings.Length(conf) -1 , subconf);
					END;
					w.String(ConfShortDataFileName(subconf)); w.Char(' ');
					w.String(props.versionURL);  w.Ln();
					subconfs := subconfs.next;
				END;
			END;
			IF allFrozen THEN
				w.Update(); Files.Register(f);
				fileName := ConfShortDataFileName(conf);
				IF PLog THEN OdUtil.Msg3("freezeConfiguration.ConfShortDataFileName", conf, fileName); END;
				IF       mode = "initial" THEN freezeInitialResource("", fileName, log, flags);
				ELSIF mode = "other"  THEN freezeOtherResource("", fileName, log, flags);
				END;
			ELSE
				preCond := OdCond.ErrorMsg;
				OdC.SetError(WebHTTP.InternalServerError, "Not all VCRs were frozen", -1);
			END;
		END freezeConfiguration;

	PROCEDURE freezeInitialConfiguration*(conf: OdUtil.Line; log: OdVCSBase.TLog; flags: SET);(* BASELINE-CONTROL  *)
		VAR props: VersionProperties; hist: OdUtil.Line;
		BEGIN
			preCond := OdCond.Ok;
			NEW(props, "", conf);
			IF props.state # "" THEN
				preCond := OdCond.VccMustNotExist;
			ELSE
				hist := repMan.newHistory(conf);
				freezeConfiguration("initial", conf, hist, log, flags);
			END;
		END freezeInitialConfiguration;

	PROCEDURE freezeOtherConfiguration*(conf: OdUtil.Line; log: OdVCSBase.TLog; flags: SET);(* CHECKIN  *)
		VAR props: VersionProperties;
		BEGIN
			preCond := OdCond.Ok;
			NEW(props, "", conf);
			IF props.versionHistory = "" THEN
				OdUtil.Msg2(conf, "no version history property found for configuration");
			ELSIF props.state = "frozen" THEN
				OdUtil.Msg2(conf, "VCR exists and is frozen. Please thaw it.");
			ELSE
				freezeConfiguration("other", conf, props.versionHistory, log, flags);
			END;
		END freezeOtherConfiguration;

	(**                                      select                              **)
	(** conf: configuration path, res: relative resource path,
		histUrl: history file name without leading '/'
		ver: history path + '.' + version number.
		Version URL has history and version number combined. *)
	PROCEDURE selectResource(conf, res, hist, ver: OdUtil.Line);(*  VERSION-CONTROL  *)
		CONST PLog = FALSE;
		VAR historyName, fileName: OdVCSBase.TFileName; version, pos, erg, verPos: LONGINT;
			log: OdVCSBase.TLog;
			props: VersionProperties;  line: OdUtil.Line;
			errMsg: ARRAY 256 OF CHAR; f: Files.File;
		BEGIN
			IF PLog THEN OdUtil.Msg5("DAVDeltavBase.sR:",conf, res, hist, ver); END;
(*$IF old THEN
			(* Why the distinction ?  Still necessary ? *)
			IF isConfDataFileName(res) THEN
				COPY(res, fileName);
			ELSE
				line := ResFileName(conf, res); COPY(line, fileName);
			END;
$ELSE
			line := ResFileName(conf, res); COPY(line, fileName);
$END*)
			line := ResFileName(conf, res); COPY(line, fileName);
			(* find version number: [<name>.]<version number> *)
			verPos := -1;
			FOR pos := 0 TO Strings.Length(ver)-1 DO
				IF ver[pos] = VerCh THEN verPos := SHORT(pos); END;
			END;
			INC(verPos);
			Strings.StrToIntPos(ver, version, verPos); (* get version number *)
			IF version <= 0 THEN
				OdUtil.Msg2("DAVDeltavBase.sR: ver = ", ver);
				preCond := OdCond.MustBeVersion;
				RETURN;
			END;
			(* Build internal history name with prefix *)
			line := repMan.repName(hist); COPY(line, historyName);
			(*IF PLog THEN OdUtil.Msg6("DAVDeltavBase.sR:",conf, res, fileName, historyName, OdUtil.I(version)); END;*)
			erg := OdVCSBase.View(historyName, version, fileName);
			IF erg < 0 THEN
				preCond := OdCond.ErrorMsg;
				Strings.Concat("DAVDeltavBasse.selectResource: ", OdVCSBase.errMsg, errMsg);
				OdC.SetError(WebHTTP.InternalServerError, errMsg, erg);
			ELSE
				(* Show some version info *)
				OdVCSBase.GetLog(historyName, version, log);
				(* save it *)
				IF PLog THEN OdUtil.Msg3("DAVDeltavBase.sR: NEW(props)", conf, res); END;
				NEW(props, conf, res);
				GetSuffix(ver, props.versionName);
				IF props.versionName = "" THEN (* Only <number> *)
					props.versionName := ver;
				END;
				props.set("versionName", props.versionName);
				props.set("state", "frozen");
				props.set("versionHistory", hist);
				props.set("DAV:creator-displayname", log.author);
				props.set("DAV:comment", log.logText);
				props.set("creationDate", log.date);
				IF ~ (OdVCSBase.MakroBit IN log.flags)  THEN
					props.set("keywords", "f");
				ELSE (* recheckout with makro expansion *)
					props.set("keywords", "t");
				END;
			END;
			(* Show existing VCRs if a resource was restored 	*)
		END selectResource;

	PROCEDURE selectInitialResource*(conf, res, versionUrl: OdUtil.Line); (*  VERSION-CONTROL  *)
		CONST PLog = FALSE;
		VAR histPos, verPos, pos: LONGINT; histName: OdUtil.Line;
			confProps, props: VersionProperties;
		BEGIN
			preCond := OdCond.Ok;
			IF PLog THEN OdUtil.Msg6("DAVDeltavBase.siR:",conf, ",", res, ",", versionUrl); END;
			(* check whether configuration exists and is thawed *)
			IF conf # "" THEN (* For toplevel configuration data conf is "" *)
				NEW(confProps, "", conf);
				IF confProps.state = "frozen" THEN
					preCond := OdCond.MustNotUpdateBaselineCollection;
					RETURN;
				END;
			END;
			(* check whether resource already exists *)
			NEW(props, conf, res);
			IF props.state # "" THEN
				preCond := OdCond.CannotAddToExistingHistory; (* VCR already exists. Use UPDATE. *)
				RETURN;
			END;
			(* create history path from version URL: Drop leading [[http://]<servername>]/hist/ *)
			histPos := Strings.Pos(VersionMarker, versionUrl);
			IF histPos > -1 THEN (* Drop the virtual prefix *)
				Slice(versionUrl, histPos+6, Strings.Length(versionUrl)-histPos-6, histName);
			ELSE
				histName := versionUrl;
			END;
			(* find version number *)
			FOR pos := 0 TO Strings.Length(histName)-1 DO
				IF histName[pos] = VerCh THEN verPos := pos; END;
			END;
			(* remove tail beginning with last verPos *)
			histName[verPos] := 0X;
			selectResource(conf, res, histName, versionUrl);
		END selectInitialResource;

		(* <conf>, <res>, [<history file>.]<version number> *)
		(* TODO: Not yet clear whether to use <history file> or the pure number. *)
		PROCEDURE selectOtherResource*(conf, res, ver: OdUtil.Line); (* UPDATE  *)
		CONST PLog = FALSE;
		VAR confProps, props: VersionProperties; verPos, pos: LONGINT;
		BEGIN
			preCond := OdCond.Ok;
			IF PLog THEN OdUtil.Msg6("soR: conf, res, ver =",conf, ":", res, ":", ver); END;
			(* check whether configuration exists and is thawed *)
			IF conf # "" THEN (* For toplevel configuration data conf is "" *)
				NEW(confProps, "", conf);
				IF confProps.state = "frozen" THEN
					OdUtil.Msg2(conf, "VCC exists and is frozen. Please thaw it.");
					RETURN;
				END;
			END;
			(* check whether resource already exists *)
			NEW(props, conf, res);
			IF PLog THEN OdUtil.Msg2("soR: props.versionHistory =", props.versionHistory); END;
			IF props.versionHistory = "" THEN
				OdUtil.Msg3("soR: couldn't find props.versionHistory. conf, res = ", conf, res);
				RETURN;
			END;
			IF props.state # "frozen" THEN
				OdUtil.Msg3(conf, res, "must be checked-in for UPDATE");
			ELSE
				(* find version number *)
				verPos := -1;
				FOR pos := 0 TO Strings.Length(ver)-1 DO
					IF ver[pos] = VerCh THEN verPos := pos; END;
				END;
				IF verPos > 0 THEN (* no pure number *)
					pos := Strings.Pos(props.versionHistory, ver);
					IF pos # 0 THEN
						OdUtil.Msg3(props.versionHistory, ver, "must belong to same version history");
						RETURN;
					END;
				END;
				IF PLog THEN OdUtil.Msg4("soR: props.versionHistory, ver", props.versionHistory, ":", ver); END;
				selectResource(conf, res, props.versionHistory, ver);
			END;
		END selectOtherResource;

	PROCEDURE selectConfiguration(mode, conf, ver: OdUtil.Line);(* BASELINE-CONTROL  *)
		CONST Log0 = FALSE; Log1 = FALSE; Log2 = FALSE;
		VAR f: Files.File; w: Files.Writer; r: Files.Reader; line, res, resVer, subConf: OdUtil.Line;
			confProps: VersionProperties; absConf, confData: OdUtil.Line;
			dir: Files.File; splitter: OdXml.StringSplitter; ok: BOOLEAN;
			status: LONGINT; errMsg: ARRAY 128 OF CHAR;
		BEGIN
			IF Log0 THEN OdUtil.Msg4("sC:", mode, conf, ver); END;
			(* check whether collection exists *)
			absConf := AbsWorkPath(conf); unpadConfiguration(absConf);
			dir := Files.Old(absConf);
			IF dir # NIL THEN
				IF Log1 THEN OdUtil.Msg2("sC: Directory exists:", absConf); END;
			ELSE
				IF Log0 THEN OdUtil.Msg2("sC: Directory will be created:", absConf); END;
				mkcol(absConf, status); (* Now instead of CreDir. Perhaps better. *)
				dir := Files.Old(absConf);
				IF dir = NIL THEN
					preCond := OdCond.ErrorMsg;
					Strings.Concat("SelectConfiguration: couldn't create directory ", absConf, errMsg);
					OdC.SetError(WebHTTP.InternalServerError, errMsg, status);
					RETURN;
				END;
			END;
			f := Files.New(""); Files.OpenWriter(w, f, 0); (* Only for checkFrozenVCRs *)
			IF checkFrozenVCRs(conf, TRUE, w) THEN (* checks subbaselines recursively *)
				Files.Register(f); (* Try to close it. *)
				deleteFrozenVCRs(conf); (* Delete existing resources and subconfigurations. *)
				(* Select configuration itself. *)
				confData := ConfDataFileName(conf);
				IF Log1 THEN OdUtil.Msg2("sC: confData:", confData); END;
				IF mode = "initial" THEN
					selectInitialResource("", confData, ver);
					IF preCond # OdCond.Ok THEN
						RETURN;
					END;
				ELSIF mode = "other" THEN
					selectOtherResource("", confData, ver);
					IF preCond # OdCond.Ok THEN
						RETURN;
					END;
				ELSE
					preCond := OdCond.ErrorMsg;
					OdC.SetError(WebHTTP.InternalServerError, "SelectConfiguration: Unknown mode", 0);
					RETURN;
				END;
				NEW(confProps, "", ResFileName("", conf)); confProps.set("state", "thawed"); (* allow creation of resources *)
				(* create resources *)
				f := Files.Old(confData);
				IF f = NIL THEN
					preCond := OdCond.ErrorMsg;
					OdC.SetError(WebHTTP.InternalServerError, "SelectConfiguration: couldn't open conf datafile", 0);
					RETURN;
				END;
				Files.OpenReader(r, f, 0);
				LOOP
					r.Ln(line);
					IF r.res # Streams.Ok THEN EXIT; END;
					NEW(splitter, line); ok := splitter.Next(' ', res); ok := splitter.Next(' ', resVer);
					IF Log2 THEN OdUtil.Msg3("sC: res,resVer = ",res, resVer); END;
					IF isConfDataFileName(res) THEN
						IF res[0] = CollCh THEN (* absolute subconfiguration. *)
							subConf := Data2Conf(res);
						ELSE (* relative below configuration *)
							absConf (* not used anymore so use as dummy *) := Data2Conf(res);
							subConf := FullSubconfName(conf, absConf);
							IF Log2 THEN OdUtil.Msg3("sC: conf,fullConf = ",absConf, subConf); END;
						END;
						selectConfiguration("initial", subConf, resVer);
						IF preCond # OdCond.Ok THEN
							Files.Register(f); RETURN;
						ELSE (* register subbaseline *)
							confProps.set("DAV:subbaseline-set", subConf);
						END;
					ELSE
						selectInitialResource(conf, res, resVer); (* Old resources were deleted if some existed. *)
						IF preCond # OdCond.Ok THEN
							Files.Register(f); RETURN;
						END;
					END;
				END;
				confProps.set("state", "frozen"); (* disallow creation of resources *)
			ELSE
				Files.Register(f); (* Try to close it. *)
			END;
		END selectConfiguration;

	PROCEDURE selectInitialConfiguration*(conf, ver: OdUtil.Line);(* BASELINE-CONTROL  *)
		CONST PLog = FALSE;
		VAR props: VersionProperties;
		BEGIN
			IF PLog THEN OdUtil.Msg2("siC: conf = ", conf); END;
			NEW(props, "", conf);
			IF PLog THEN OdUtil.Msg2("siC: props.state = ", props.state); END;
			IF props.state # "" THEN
				preCond := OdCond.VccMustNotExist;
				RETURN;
			END;
			selectConfiguration("initial", conf, ver);
		END selectInitialConfiguration;

	PROCEDURE selectOtherConfiguration*(conf, ver: OdUtil.Line);(* UPDATE  *)
		VAR props: VersionProperties; errMsg: ARRAY 64 OF CHAR;
		BEGIN
			NEW(props, "", conf);
			IF props.state = "" THEN
				preCond := OdCond.ErrorMsg;
				COPY(conf, errMsg); Strings.Append(errMsg, " not found");
				OdC.SetError(WebHTTP.InternalServerError, errMsg, -1);
			ELSIF props.state = "thawed" THEN
				preCond := OdCond.ErrorMsg;
				COPY(conf, errMsg); Strings.Append(errMsg, "must be checked-in for UPDATE");
				OdC.SetError(WebHTTP.InternalServerError, errMsg, -1);
			ELSE (* "frozen" *)
				selectConfiguration("other", conf, ver);
			END;
		END selectOtherConfiguration;

	(**                          thaw                           **)
	PROCEDURE thawResource*(conf, res: OdUtil.Line);(* CHECKOUT  *)
		VAR confProps, props: VersionProperties;
		BEGIN
			preCond := OdCond.Ok;
			NEW(confProps, "", conf);
			IF confProps.state = "frozen" THEN
				preCond := OdCond.MustNotUpdateBaselineCollection;
			ELSE
				NEW(props, conf, res);
				IF props.state = "" THEN
					preCond := OdCond.MustBeVcr;
				ELSIF props.state = "thawed" THEN
					preCond := OdCond.MustBeCheckedIn;
				ELSE
					props.set("state", "thawed");
					(* OdUtil.Msg2(res, "thawed"); *)
				END;
			END;
		END thawResource;

	PROCEDURE unThawResource*(conf, res: OdUtil.Line);(* UNCHECKOUT  *)
		VAR props: VersionProperties;
		BEGIN
			preCond := OdCond.Ok;
			NEW(props, conf, res);
			IF props.state = "" THEN
				preCond := OdCond.MustBeVcr;
			ELSIF props.state = "frozen" THEN
				preCond := OdCond.MustBeCheckedOutVcr;
			ELSE
				props.set("state", "frozen");
				selectOtherResource(conf, res, props.versionURL);
				(* OdUtil.Msg2(res, "unthawed"); *)
			END;
		END unThawResource;

	PROCEDURE thawConfiguration*(conf: OdUtil.Line);(* CHECKOUT  *)
		BEGIN
			thawResource("", conf);
		END thawConfiguration;

	PROCEDURE unThawConfiguration*(conf: OdUtil.Line);(* UNCHECKOUT  *)
		CONST PLog = TRUE;
		VAR thawed: OdUtil.Lines; props: VersionProperties;
		BEGIN
			thawed := thawedVCRs(conf);
			IF thawed # NIL THEN (* warn that some resources are thwawed (possibly changed) *)
				(* TODO: What to do in this case ? Error ? *)
				IF PLog THEN OdUtil.Msg3("DAVDeltavBase.unThawConfiguration:", conf, "unthaw thawed VCRs"); END;
				WHILE thawed # NIL DO OdUtil.Msg2(thawed.line, "thawed"); thawed := thawed.next; END;
				preCond := OdCond.ErrorMsg;
				OdC.SetError(WebHTTP.Conflict, "vcc-has-checked-out-vcrs", 0);
			ELSE (* Restore old state from version URL *)
				unThawResource("", conf);
				(* Don't select other stuff. What's the UNCHECKOUT semantic for a baseline ?
				NEW(props, "", conf);
				IF PLog THEN OdUtil.Msg3("DAVDeltavBase.unThawConfiguration: selectOther =", conf, props.versionURL); END;
				selectOtherConfiguration(conf, props.versionURL);
				*)
			END;
		END unThawConfiguration;

	(**                        modify                      **)
	PROCEDURE modifyResource*;(* PUT  *)
		BEGIN HALT(21); END modifyResource;
	PROCEDURE modifyConfiguration*;(* MKCOL  *)
		BEGIN HALT(21); END modifyConfiguration;

	(**                          reports                              **)
	PROCEDURE reportResource*(conf, res: OdUtil.Line);(* REPORT  *)
		VAR props: VersionProperties;
		BEGIN
			NEW(props, conf, res);
			OdUtil.Msg4(conf, res, props.versionName, props.state);
		END reportResource;

	(* Find the current state of the configuration in the workspace. Displaying it is done later by
		the caller with vcc.show() *)
	PROCEDURE reportConfiguration*(conf: OdUtil.Line; vccList: VccList);(* REPORT  *)
		VAR vccs, lines: OdUtil.Lines; res, ver: OdUtil.Line; props: VersionProperties; vcrList: VcrList; subList: VccList;
		BEGIN lines := findVCRs(conf);
			NEW(props, "", conf);
			vccList.state := props.state; vccList.version := props.versionURL;
			WHILE lines # NIL DO
				splitConfRes(lines.line, conf, res);
				 (** )Msg4("reportConfiguration.lines:", lines.line, conf, res); ( **)
				NEW(props, conf, res);
				ver := props.versionHistory; Strings.Append(ver, VerCh); Strings.Append(ver, props.versionName);
				(* A subconfiguration shows up with ver = '.'. Don't show it. Doesn't mean that it's
					a subbaseline. *)
				IF ver # '.' THEN (* Unclear whether to modify for WO *)
					(* Collect data in structure. *)
					IF vccList.vcrs = NIL THEN NEW(vccList.vcrs, res, ver); vccList.vcrs.state := props.state;
					ELSE NEW(vcrList, res, ver);  vcrList.state := props.state; vccList.vcrs.add(vcrList); END;
				END;
				lines := lines.next;
			END;
			(* report on subbaselines *)
			vccs := findVCCs(conf);
			WHILE vccs # NIL DO
				NEW(subList, vccs.line, props.versionURL);
				IF vccList.vccs = NIL THEN vccList.vccs := subList; ELSE vccList.vccs.add(subList); END;
				reportConfiguration(vccs.line, subList);
				vccs := vccs.next;
			END;
		END reportConfiguration;

	(* Find the current state of the configuration in the workspace. *)
	PROCEDURE webReportConfiguration*(host: ARRAY OF CHAR; conf: OdUtil.Line; VAR xmlDoc: XML.Document);(* REPORT  *)
		VAR vcc: VccList; crRes: OdXml.ConfigurationReportRes;
		BEGIN NEW(vcc, conf, "top");
			reportConfiguration(conf, vcc);
			NEW(crRes, hostName, conf);
			vcc.xml(host, crRes, crRes.GetRoot());
			xmlDoc := crRes;
		END webReportConfiguration;

	(* Create the vcc.baseline-collection information. Just as data in memory at the moment. Checkout just the configuration
		data to ConfBase = "temp/<confName>(0..9)_". Create the datastructure which also can can contain subbaselines. In this case
		it's necessary to have baseline data files of different levels. *)
	PROCEDURE reportBaseline*(confName, baselineUrl: OdUtil.Line; vccList: VccList; level: INTEGER; VAR statusCode: LONGINT);
		(* PROPFIND vcc.baseline-collection  *)
		CONST PLog = FALSE;
		VAR confPropFileName, confDataFileName, line, res, ver: OdUtil.Line;
			vcrList: VcrList; subList: VccList;
			rc: LONGINT; f: Files.File; r: Files.Reader; splitter: OdXml.StringSplitter; ok: BOOLEAN;
		BEGIN
			IF level > 9 THEN
				statusCode := WebHTTP.InternalServerError; preCond := OdCond.ErrorMsg;
				OdC.SetError(WebHTTP.InternalServerError, "DAVDeltavBase.reportBaseline: too many nested baselines", 0);
				RETURN;
			END;
			(*IF PLog THEN OdUtil.Msg4("DAVDeltavBase.rB:", confName, baselineUrl, OdUtil.I(level)); END;*)
			(* Select configuration datafile to <repMan.prefix>/temp/<confName><level>_  *)
			confDataFileName := ResFileName(workMan.TempDir, confName);
			Strings.Append(confDataFileName, " _");
			confDataFileName[Strings.Length(confDataFileName)-2] := CHR(ORD('0')+level);
			(* Select baseline if it exists. *)
			Files.Delete(confDataFileName, rc);  (* Delete configuration file. *)
			confPropFileName := ConfData2PropFileName(confDataFileName);
			Files.Delete(confPropFileName, rc); (* Delete property file *)
			IF PLog THEN OdUtil.Msg3("DAVDeltavBase.rB: confDataFileName, baseline = ", confDataFileName, baselineUrl);  END;
			selectInitialResource("", confDataFileName, baselineUrl);
			f := Files.Old(confDataFileName);
			IF f = NIL THEN
				statusCode := WebHTTP.InternalServerError; preCond := OdCond.ErrorMsg;
				OdC.SetError(WebHTTP.InternalServerError, "DAVDeltavBase.reportBaseline: couldn't open confDataFileName", 0);
				RETURN;
			END;
			Files.OpenReader(r, f, 0);
			LOOP
				r.Ln(line);
				IF r.res # Streams.Ok THEN EXIT; END;
				NEW(splitter, line); ok := splitter.Next(' ', res); ok := splitter.Next(' ', ver);
				IF PLog THEN OdUtil.Msg3("DAVDeltavBase.rB: res, ver = ", res, ver); END;
				IF ~ isConfDataFileName(res) THEN
					(* Collect resource data in structure. *)
					IF vccList.vcrs = NIL THEN NEW(vccList.vcrs, res, ver);
					ELSE NEW(vcrList, res, ver);  vccList.vcrs.add(vcrList); END;
				ELSE (* a subbaseline *)
					NEW(subList, Data2Conf(res), ver);
					IF vccList.vccs = NIL THEN vccList.vccs := subList; ELSE vccList.vccs.add(subList); END;
					reportBaseline(Data2Conf(res), ver (* baseline *), subList, level+1, statusCode);
					IF statusCode # WebHTTP.OK THEN RETURN; END;
				END;
			END;
		END reportBaseline;

	(* Find information on a baseline.
		baseline-controlled-collection.version-controlled-configuration.checked-(in|out).baseline.baseline-collection
		REPORT  *)
	PROCEDURE webReportBaseline*(host: ARRAY OF CHAR; baseline: OdUtil.Line; VAR xmlDoc: XML.Document;
		VAR statusCode: LONGINT);
		CONST conf = "bl"; (* Just a dummy *)
		VAR vcc: VccList; brRes: OdXml.BaselineReportRes;
		BEGIN NEW(vcc, conf, "top");
			reportBaseline(conf, baseline, vcc, 0, statusCode);
			NEW(brRes, hostName, baseline);
			vcc.xml(host, brRes, brRes.GetRoot());
			xmlDoc := brRes;
		END webReportBaseline;

	(* Create the vcc.baseline-collection information. Just as data in memory at the moment. *)
	PROCEDURE compareBaseline*(a, b: OdUtil.Line; VAR vccDiff: VccDiff; VAR statusCode: LONGINT); (* REPORT baseline-compare  *)
		CONST PLog = FALSE;
		VAR blA, blB: VccList;
		BEGIN
			NEW(blA, "baselineA", a);  reportBaseline("blA", a, blA, 0, statusCode);
			IF statusCode # WebHTTP.OK THEN RETURN; END;
			IF PLog THEN blA.show(""); END;
			NEW(blB, "baselineB", b); reportBaseline("blB", b, blB, 0, statusCode);
			IF statusCode # WebHTTP.OK THEN RETURN; END;
			IF PLog THEN blB.show(""); END;
			NEW(vccDiff, blA, blB);
		END compareBaseline;

	(* REPORT compare-baseline 12.7.1  *)
		PROCEDURE reportCompareBaseline*(host: ARRAY OF CHAR; baseline0, baseline1: OdUtil.Line;
			VAR xmlOut: XML.Document; VAR statusCode: LONGINT);
		CONST PLog = FALSE;
		VAR vccDiff: VccDiff; cbrRes: OdXml.CompareBaselineReportRes;
			BEGIN
			IF PLog THEN OdUtil.Msg3("reportCompareBaseline: baseline0, baseline1 =", baseline0, baseline1); END;
			localServer.compareBaseline(baseline0, baseline1, vccDiff, statusCode);
			IF statusCode = WebHTTP.OK THEN
				IF PLog THEN vccDiff.show(""); END;
				NEW(cbrRes, hostName, baseline0); (* Creates a multistatus root element. *)
				vccDiff.xml(host, cbrRes, cbrRes.GetRoot());
				xmlOut := cbrRes;
			END;
		END reportCompareBaseline;

	PROCEDURE reportHistory*(hist: OdUtil.Line);(* REPORT  *)
		VAR historyName: OdVCSBase.TFileName; version, newestVersion: LONGINT;
			log: OdVCSBase.TLog;
		BEGIN
			COPY(root, historyName); Strings.Append(historyName, hist);
			newestVersion := OdVCSBase.Init(historyName);
			(** ) OdUtil.Msg2("DAVDeltavBase.historyName:", historyName); ( **)
			IF newestVersion < 0 THEN OdUtil.Msg2(hist, "no versions"); RETURN; END;
			(* show data for existing versions *)
			FOR version := 1 TO newestVersion DO
				OdVCSBase.GetLog(historyName, version, log);
				KernelLog.String(hist); KernelLog.Char(VerCh); KernelLog.Int(log.versionID, 0); KernelLog.Char(' ');
				KernelLog.String(log.date); KernelLog.Char(' '); KernelLog.String(log.author); KernelLog.Ln;
				KernelLog.String(log.logText); KernelLog.Ln;
			END;
		END reportHistory;

	(* REPORT version-tree 3.7  *)
	PROCEDURE reportVersionTree*(host: ARRAY OF CHAR; conf, res: OdUtil.Line; VAR xmlDoc: XML.Document);
		CONST PLog = FALSE;
		VAR historyName: OdVCSBase.TFileName; version, newestVersion: LONGINT; temp: ARRAY 8 OF CHAR;
			log: OdVCSBase.TLog; props: VersionProperties; vtRes: OdXml.VersionTreeRes; w: Streams.Writer;
		BEGIN
			NEW(props, conf, res);
			COPY(root, historyName); Strings.Append(historyName, props.versionHistory);
			NEW(vtRes, props.versionHistory);
			newestVersion := OdVCSBase.Init(historyName);
			(*IF PLog THEN OdUtil.Msg6("reportVersionTree", conf, CollCh, res, historyName, OdUtil.I(newestVersion)); END;*)
			IF newestVersion < 0 THEN OdUtil.Msg1("no versions"); RETURN; END;
			(* show data for existing versions *)
			FOR version := 1 TO newestVersion DO
				OdVCSBase.GetLog(historyName, version, log);
				(* OdUtil.Msg3(I(log.versionID), log.date, log.author);  OdUtil.Msg1(log.logText); *)
				temp:=OdUtil.I(log.versionID); vtRes.addVersion(host, temp, log.author, log.date, log.logText);
			END;
			xmlDoc := vtRes;
		END reportVersionTree;

	(* Available properties of a resource. *)
	PROCEDURE PropNames(VAR href: ARRAY OF CHAR; propfindRes: OdXml.PropfindCollectionRes);
	VAR
		props: VersionProperties;
		host: ARRAY 64 OF CHAR; path: ARRAY 256 OF CHAR; port: LONGINT;
	BEGIN
		(* TODO: really check for href. E.g. whether it's a VCR or a normal resource or a collection. *)
		(* Standard properties *)
		propfindRes.addOK("D:getcontentlength", "");
		propfindRes.addOK("D:getlastmodified", "");
		propfindRes.addOK("D:resourcetype", "");
		propfindRes.addOK("D:displayname", "");
		(* propfindRes.addOK("D:creationdate", ""); *)
		IF WebHTTP.SplitHTTPAdr (href, host, path, port) THEN
			NEW(props, "", path);
			IF props.state # "" THEN
				(* Version properties *)
				propfindRes.addOK("D:comment", "");
				propfindRes.addOK("D:creator-displayname", "");
				(* propfindRes.addOK("D:supported-method-set", ""); protected *)
				(* propfindRes.addOK("D:supported-live-property-set", ""); protected *)
				(* propfindRes.addOK("D:supported-report-set", "");  protected *)
				propfindRes.addOK("D:checked-in", ""); (* protected *)
				(* propfindRes.addOK("D:auto-version", ""); *)
				propfindRes.addOK("D:checked-out", ""); (* protected *)
				(* propfindRes.addOK("D:predecessor-set", ""); protected *)
				(* propfindRes.addOK("D:successor-set", ""); computed *)
				(* propfindRes.addOK("D:checkout-set", ""); computed *)
				(* propfindRes.addOK("D:version-name", ""); protected *)
			END;
		END;
	END PropNames;

	(* Iterate over a list of requested properties and add its values to the result body. *)
	PROCEDURE doPropfindList(propfindRes: OdXml.PropfindCollectionRes; propList: XML.Document;
		href, type, dateTime: ARRAY OF CHAR; length: LONGINT);
	VAR propfindEl, propEl, prop: XML.Element; elName: ARRAY 128 OF CHAR; p: ANY;
		resourceProps: VersionProperties;
		host, path: ARRAY 128 OF CHAR; value: ARRAY 512 OF CHAR; port: LONGINT;
		propName, absName: OdUtil.Line; props: XMLObjects.Enumerator;
	BEGIN
		propfindRes.addResponse(href);
		propEl := OdX.GetFirstChild(propList.GetRoot());
		absName := OdX.AbsXmlName(propEl.GetName());
		(** )  OdUtil.Msg2("DAVDeltavBase.doPropfindList: childName = ", absName);  ( **)
		IF  absName = "DAV:propname" THEN
			PropNames(href, propfindRes);
		ELSIF absName = "DAV:prop" THEN
			props := propEl.GetContents();
			WHILE props.HasMoreElements() DO
				p := props.GetNext();
				IF p IS XML.Element THEN
					prop :=  p(XML.Element);
					propName  := OdX.AbsXmlName(prop.GetName());
					(** )  OdUtil.Msg2("DAVDeltavBase.doPropfindList: propName = ", propName);  ( **)
					(* First care for some special properties *)
					IF propName = "DAV:getcontentlength" THEN
						Strings.IntToStr(length, host); propfindRes.addOK("D:getcontentlength", host);
					ELSIF propName = "DAV:getlastmodified" THEN
						propfindRes.addOK("D:getlastmodified", dateTime);
					ELSIF propName = "DAV:resourcetype"THEN
						propfindRes.addResourceType(type);
					ELSIF propName = "DAV:displayname"THEN
						IF WebHTTP.SplitHTTPAdr(href, host, path, port) THEN
							Files.SplitPath(path, host, elName);
						ELSE
							elName := "";
						END;
						propfindRes.addOK("D:displayname", elName);
					ELSE (* Properties from properties file. *)
						IF resourceProps = NIL THEN
							IF WebHTTP.SplitHTTPAdr(href, host, path, port) THEN
								absName := ResFileName("", path);
								(** ) OdUtil.Msg4("DAVDeltavBase.doPropfindList: href, path, absname = ", href, path, absName); ( **)
								NEW(resourceProps, "", absName);
							END;
						END;
						IF resourceProps # NIL THEN
							(** ) OdUtil.Msg2("DAVDeltavBase.doPropfindList: resourceProps.state = ", resourceProps.state); ( **)
							(* Get special properties *)
							value := "";
							IF propName = "DAV:version-time" THEN
								COPY(resourceProps.creationDate, value);
							ELSIF (propName = "DAV:checked-in") & (resourceProps.state = "frozen") THEN
								Strings.Concat("/hist/", resourceProps.versionHistory, value);
								Strings.Append(value, "."); Strings.Append(value, resourceProps.versionName);
							ELSIF (propName = "DAV:checked-out") & (resourceProps.state = "thawed") THEN
								Strings.Concat("/hist/", resourceProps.versionHistory, value);
								Strings.Append(value, "."); Strings.Append(value, resourceProps.versionName);
							ELSE
								resourceProps.get(propName, value);
							END;
							IF value # "" THEN
								propfindRes.addOK(propName, value);
							ELSE
								propfindRes.addNotFound(propName);
							END;
						ELSE
							propfindRes.addNotFound(propName);
						END;
						(** ) OdUtil.Msg1("DAVDeltavBase.doPropfindList: to next = "); ( **)
					END;
				ELSE (* Something wrong with XML doc. Unexpected XML element. *)
					(* Try to send back some information. *)
					propfindRes.addNotFound("ES:DAVDeltavBase.doPropfindList.Unexpected XML element");
				END;
			(*while*)END;
		ELSE
			(* TODO: Error handling. *)
			(* *)  OdUtil.Msg1("DAVDeltavBase.doPropfindList: no prop element found");  (* *)
		END;
	END doPropfindList;

	(** Get properties of a resource. Either some standard properties or properties given by a list. *)
	PROCEDURE propfind*(host : ARRAY OF CHAR; conf, res: OdUtil.Line; depth: ARRAY OF CHAR;
		propList: XML.Document; VAR propResults: XML.Document);
		(* REPORT version-tree 3.7  *)
		CONST PLog = FALSE;
		VAR historyName: OdVCSBase.TFileName; version, pos: LONGINT; prefixLen: LONGINT;
			log: OdVCSBase.TLog; w: Streams.Writer;
			propfindRes: OdXml.PropfindCollectionRes;
			enum: Files.Enumerator; pattern, fullPattern, name, href: OdUtil.Line; time, date, size: LONGINT;
			entryFlags, flags: SET;
			dateTimeStr, timeStr, depthString: ARRAY 32 OF CHAR;
			hostPrefix, parentColl, coll, absColl: ARRAY 64 OF CHAR;
	BEGIN
		IF host[0] = '*' THEN Strings.Delete(host, 0, 1); END;
		IF host#"" THEN Strings.Concat("http://", host, hostPrefix); ELSE COPY(host,hostPrefix) END; (* PH XXX *)
		padConfiguration(workMan.prefix); (* Just to be sure *)
		name := ResFileName(conf, res); (* complete name with FAT:... *)
		IF PLog THEN OdUtil.Msg6("host name depth = ", host, ",", name, ",", depth); END;
		IF isConfiguration(name) THEN (* Directory *)
			NEW(propfindRes, res);
			IF depth = "0" THEN
				(* DIrEntry stuff. Funny code because enumerator gives member info for directory instead of directory data. *)
				pos := Strings.Pos(RepoPath, res);
				IF pos = 0 THEN (* Wants to get info at FTP:/WebDAV/... Should be checked for permission somehow. *)
					fullPattern := RepoMount;
				ELSE
					COPY(workMan.prefix, fullPattern);
				END;
				unpadConfiguration(fullPattern);
				prefixLen := Strings.Length(fullPattern);
				Strings.Append(fullPattern, res); unpadConfiguration(fullPattern);
				Files.SplitPath(fullPattern, parentColl, coll);
				IF PLog THEN OdUtil.Msg4("propfind pattern, depth = ", parentColl, ",", depth); END;
				NEW(enum); enum.Open(parentColl, flags);
				WHILE enum.GetEntry(name, entryFlags, time, date, size) DO
					IF PLog THEN  OdUtil.Msg2("propfind.name = ", name); END;
					IF name = fullPattern THEN
						Strings.FormatDateTime(WebHTTP.DateTimeFormat, Dates.OberonToDateTime(date, time), dateTimeStr);
						IF PLog THEN OdUtil.Msg3("propfind.addMember: ", name, dateTimeStr); END;
						COPY(hostPrefix, href);
						IF Strings.Length(name) = prefixLen THEN
							Strings.Append(href, "/");
						ELSE
							Slice(name, prefixLen, Strings.Length(name) - prefixLen + 1, name);
							Strings.Append(href, name);
						END;
						IF propList # NIL THEN (* Add properties given by list in XML body. *)
							doPropfindList(propfindRes, propList, href, "collection", dateTimeStr, size);
						ELSE (* Just add standard properties. *)
							propfindRes.addMember(href, "collection", dateTimeStr, size);
						END;
					END;
				END;
				enum.Close;
			ELSIF depth # "0" THEN
				(* TODO: discriminate between 1 and infinity *)
				pos := Strings.Pos(RepoPath, res);
				IF pos = 0 THEN (* Wants to get info at FTP:/WebDAV/... Should be checked for permission somehow. *)
					pattern := RepoMount;
				ELSE
					COPY(workMan.prefix, pattern);
				END;
				prefixLen := Strings.Length(pattern);
				unpadConfiguration(pattern);
				prefixLen := Strings.Length(pattern);
				Strings.Append(pattern, res); padConfiguration(pattern); Strings.Append(pattern, '*');
				IF PLog THEN OdUtil.Msg5("propfindCollection: ", conf, CollCh, res, pattern); END;
				NEW(enum); enum.Open(pattern, flags);
				WHILE enum.GetEntry(name, entryFlags, time, date, size) DO
					(* OdUtil.Msg2("propfindCollectionName = ", name); *)
					IF name[Strings.Length(name)-1] # PropCh THEN
						Strings.FormatDateTime(WebHTTP.DateTimeFormat, Dates.OberonToDateTime(date, time), dateTimeStr);
						Slice(name, prefixLen, Strings.Length(name) - prefixLen + 1, name);
						Strings.Concat(hostPrefix, name, href);
						IF PLog THEN OdUtil.Msg3("propfind.addMember: ", href, dateTimeStr); END;
						IF propList # NIL THEN (* Add properties given by list in XML body. *)
							IF (Files.Directory IN entryFlags) THEN
								doPropfindList(propfindRes, propList, href, "collection", dateTimeStr, size);
							ELSE (* File *)
								doPropfindList(propfindRes, propList, href, "resource", dateTimeStr, size);
							END;
						ELSE (* Just add standard properties. *)
							IF (Files.Directory IN entryFlags) THEN
								propfindRes.addMember(href, "collection", dateTimeStr, size);
							ELSE (* File *)
								propfindRes.addMember(href, "resource", dateTimeStr, size);
							END;
						END;
					END;
				END;
				enum.Close;
			END (* depth # "0" *) ;
			propResults := propfindRes;
		ELSE (* File *)
			name := ResFileName(conf, res); (* complete name with FAT:... *)
			(* Get directory info *)
			NEW(enum); enum.Open(name, flags);
			IF enum.GetEntry(name, entryFlags, time, date, size) THEN
				Strings.FormatDateTime(WebHTTP.DateTimeFormat, Dates.OberonToDateTime(date, time), dateTimeStr);
			END;
			(* Get version info *)
			(** ) OdUtil.Msg2("propfind", name); ( **)
			href := ResHrefName(host, conf, res);
			(** ) OdUtil.Msg2("propfind href = ", href); ( **)
			NEW(propfindRes, href);
			IF propList # NIL THEN (* Add properties given by list in XML body. *)
				doPropfindList(propfindRes, propList, href, "resource", dateTimeStr, size);
			ELSE
				propfindRes.addMember(href, "resource", dateTimeStr, size);
			END;
			propResults := propfindRes;
		END;
	END propfind;

	(** props = 1{key value}. For multiple values of a key the key is repeated. So as long as a single value
		goes it a OdUtil.Line it's ok. The complete value-set can be larger. patchMode = "set" | "add" | "rem". *)
	PROCEDURE proppatch * (conf, res: OdUtil.Line; patchMode: ARRAY OF CHAR; props: OdUtil.Lines; VAR xmlDoc: XML.Document);
	CONST PLog = FALSE;
		SplitChar = 0DX; (* gives nice display for raw edit of property file. Could be escaped later in case of problems. *)
	VAR versionProps: VersionProperties; key: OdUtil.Line; value, oldValue: ARRAY 1024 OF CHAR;
		pos: LONGINT;
	BEGIN
		NEW(versionProps, conf, res);
		IF PLog THEN OdUtil.Msg4("conf = ", conf, "res = ", res); END;
		IF patchMode = "DAV:set" THEN
			(* Overwrite old value. *)
			key := "";
			WHILE props # NIL DO
				IF PLog THEN OdUtil.Msg2("line = ", props.line); END;
				IF props.line # key THEN
					(* new key found *)
					IF key # "" THEN versionProps.set(OdX.AbsName(key), value); END;
					COPY(props.line, key);
					props := props.next;
					COPY(props.line, value);
				ELSE (* Additional value for existing key. *)
					props := props.next;
					Strings.AppendChar(value, SplitChar);
					Strings.Append(value, props.line);
				END;
				props := props.next;
			END;
			IF key # "" THEN versionProps.set(OdX.AbsName(key), value); END;
		ELSIF patchMode = "DAV:add" THEN
			(* Add a new value to a multivalue property. No test for duplicate entries yet. *)
			key := "";
			WHILE props # NIL DO
				IF PLog THEN OdUtil.Msg2("line = ", props.line); END;
				IF props.line # key THEN
					(* new key found *)
					IF key # "" THEN
						versionProps.get(key, oldValue);
						IF oldValue # "" THEN Strings.AppendChar(oldValue, SplitChar); END;
						Strings.Append(oldValue, value);
						versionProps.set(OdX.AbsName(key), oldValue);
					END;
					COPY(props.line, key);
					props := props.next;
					COPY(props.line, value);
				ELSE (* Additional value for existing key. *)
					props := props.next;
					Strings.AppendChar(value, SplitChar);
					Strings.Append(value, props.line);
				END;
				props := props.next;
			END;
			IF key # "" THEN
				versionProps.get(key, oldValue);
				IF oldValue # "" THEN Strings.AppendChar(oldValue, SplitChar); END;
				Strings.Append(oldValue, value);
				versionProps.set(key, oldValue);
			END;
		ELSIF patchMode = "DAV:remove" THEN
			(* Remove one or sequence of values from a multivalue property. No test for multiple entries yet. *)
			key := "";
			WHILE props # NIL DO
				IF PLog THEN OdUtil.Msg2("line = ", props.line); END;
				IF props.line # key THEN
					(* new key found *)
					IF key # "" THEN
						versionProps.get(key, oldValue);
						pos := Strings.Pos(value, oldValue);
						(* OdUtil.Msg4("proppatch ", I(pos), value, oldValue); *)
						IF pos = 0 THEN (* Remove entry and following SplitChar. *)
							Strings.Delete(oldValue, pos, Strings.Length(value)+1);
						ELSIF pos > 0 THEN (* Remove entry and preceding SplitChar. *)
							Strings.Delete(oldValue, pos-1, Strings.Length(value)+1);
						END;
						versionProps.set(key, oldValue);
					END;
					COPY(props.line, key);
					props := props.next;
					COPY(props.line, value);
				ELSE (* Additional value for existing key. *)
					props := props.next;
					Strings.AppendChar(value, SplitChar);
					Strings.Append(value, props.line);
				END;
				props := props.next;
			END;
			IF key # "" THEN
				versionProps.get(key, oldValue);
				(* OdUtil.Msg4("proppatch ", I(pos), value, oldValue); *)
				pos := Strings.Pos(value, oldValue);
				IF pos = 0 THEN (* Remove entry and following SplitChar. *)
					Strings.Delete(oldValue, pos, Strings.Length(value)+1);
				ELSIF pos > 0 THEN (* Remove entry and preceding SplitChar. *)
					Strings.Delete(oldValue, pos-1, Strings.Length(value)+1);
				END;
				versionProps.set(key, oldValue);
			END;
		END;
	END proppatch;

	PROCEDURE addConfiguration * (conf, subconf: OdUtil.Line);
	VAR confProps: VersionProperties; members: OdUtil.Lines;
	BEGIN
		NEW(confProps, "", conf);
		IF confProps.state # "thawed" THEN
			OdUtil.Msg2(conf, "must be thawed to add subconfiguration");
		ELSE
			members := VCCloadMembers(conf);
			members.add(ConfShortDataFileName(subconf)); members.add("dummyURL");
			VCCstoreMembers(conf, members);
		END;
	END addConfiguration;

	PROCEDURE remConfiguration * (conf, subconf: OdUtil.Line);
	VAR confProps: VersionProperties; members, member: OdUtil.Lines; subconfData: OdUtil.Line;
	BEGIN
		NEW(confProps, "", conf);
		IF confProps.state # "thawed" THEN
			OdUtil.Msg2(conf, "must be thawed to remove subconfiguration");
		ELSE
			subconfData := ConfShortDataFileName(subconf);
			members := VCCloadMembers(conf); member := members;
			IF members.line = subconfData THEN (* first entry *)
				members  := members.next.next; (* assume that there is at least one other *)
			ELSE (* not first entry *)
				member := members.next; (* set it to <url> *)
				WHILE member.next # NIL DO
					IF member.next.line = subconfData THEN member.next := member.next.next.next; (* drop <subconf> and <url> *)
					ELSE member := member.next.next;
					END;
				END;
			END;
			VCCstoreMembers(conf, members);
		END;
	END remConfiguration;

	PROCEDURE delete * (uri: ARRAY OF CHAR);
	CONST PLog = FALSE;
	VAR absName, name: OdUtil.Line; rc, pos: LONGINT;
	BEGIN
		preCond := OdCond.Ok;
		COPY(uri, name);
		IF isConfiguration(name) THEN
			absName := ResFileName("", uri);
			unpadConfiguration(absName);
			Files.RemoveDirectory(absName, TRUE (*force*), rc);
			IF rc # 0 THEN
				preCond := OdCond.ErrorMsg;
				OdC.SetError(WebHTTP.InternalServerError, "DAVDeltavBase.delete: collection", rc);
			ELSE
				(* HACK: Delete again. Without that a following create sometimes seems doesn't work. *)
				Files.RemoveDirectory(absName, TRUE (*force*), rc);
			END;
			(* Try to delete data and prop file in case it's baseline-controlled. *)
			name := ConfDataFileName(absName);
			Files.Delete(name, rc);
			IF rc # 0 THEN
				(* OdUtil.Msg3("DAVDeltavBase.delete: ", name, I(rc)); *)
			ELSE (* HACK: Delete again. *)
				Files.Delete(name, rc);
			END;
			name :=ConfPropFileName(absName);
			Files.Delete(name, rc);
			IF rc # 0 THEN
				(* OdUtil.Msg3("DAVDeltavBase.delete: ", name, I(rc));  *)
			ELSE (* HACK: Delete again. *)
				Files.Delete(name, rc);
			END;
		ELSE
			pos := Strings.Pos(RepoPath, uri);
			IF pos = 0 THEN (* Wants to delete absolute file at FTP:/WebDAV/. Should be checked for permission somehow. *)
				absName := RepoMount; Strings.Append(absName, uri);
			ELSE
				absName := ResFileName("", uri);
			END;
			Files.Delete(absName, rc);
			IF rc # 0 THEN
				preCond := OdCond.ErrorMsg;
				OdC.SetError(WebHTTP.InternalServerError, "DAVDeltavBase.delete: resource", rc);
			END;
			(* Try to delete prop file in case it's version-controlled. *)
			name := ResPropFileName("", absName);
			IF PLog THEN OdUtil.Msg3("delete: res, reprop = ", absName, name); END;
			Files.Delete(name, rc);
			IF rc # 0 THEN
				(* OdUtil.Msg3("DAVDeltavBase.delete: ", name, I(rc));  *)
			ELSE (* HACK: Delete again. *)
				Files.Delete(name, rc);
			END;
		END;
	END delete;

	PROCEDURE mkcol * (uri: ARRAY OF CHAR; VAR statusCode: LONGINT);
	VAR absName, name: OdUtil.Line; rc: LONGINT; errMsg: ARRAY 256 OF CHAR;
	BEGIN
		preCond := OdCond.Ok;
		absName := ResFileName("", uri);
		unpadConfiguration(absName);
		(** )Msg2("mkcol.absName = ", absName);( **)
		Files.CreateDirectory(absName, rc);
		(** )Msg2("mkcol.rc = ", I(rc));( **)
		IF rc # 0 THEN
			statusCode := WebHTTP.InternalServerError;
			preCond := OdCond.ErrorMsg;
			Strings.Concat("DAVDeltavBase.mkcol: ", absName, errMsg);
			OdC.SetError(WebHTTP.InternalServerError, errMsg, rc);
		END;
	END mkcol;

END Server;


VAR
	Workspace*: ARRAY 256 OF CHAR;
	WorkspaceTemp*: ARRAY 256 OF CHAR;
	RepoPath: ARRAY 256 OF CHAR;

	frozenDeleted: BOOLEAN;
	preCond*, postCond*: INTEGER; (* pre and post condition codes of repository functions (DAVDeltavBase.Server) *)
	repMan: RepositoryManager;
	workMan * : WorkspaceManager;
	hostName * : ARRAY 64 OF CHAR;
	localServer*: Server;
	OdC:OdCond.OdCond;
	OdX:OdXml.OdXml;
	CRString:ARRAY 2 OF CHAR;


(** Get the suffix of str. The suffix is started by the last dot in str. Copied from Strings.Mod*)
	PROCEDURE GetSuffix*(VAR str(** in *), suf(** out *): ARRAY OF CHAR);
		VAR i, j, l, dot: LONGINT;
	BEGIN
		dot := -1; i := 0;
		WHILE str[i] # 0X DO
			IF str[i] = "." THEN
				dot := i
			ELSIF str[i] = "/" THEN
				dot := -1
			END;
			INC(i)
		END;
		j := 0;
		IF dot > 0 THEN
			l := LEN(suf)-1; i := dot+1;
			WHILE (j < l) & (str[i] # 0X) DO
				suf[j] := str[i]; INC(j); INC(i)
			END
		END;
		suf[j] := 0X
	END GetSuffix;



(* A little string utility *)
PROCEDURE Slice*(src: ARRAY OF CHAR; pos, len: LONGINT; VAR dest: ARRAY OF CHAR);
BEGIN dest[len] := 0X; WHILE len > 0 DO dest[len-1] := src[pos+len-1]; DEC(len); END; END Slice;
(* Split an absolute path in conf and res. At the moment conf is an input parameter. But in principle this could
	be changed later if there are uses where conf isn't already known. *)
PROCEDURE splitConfRes*(confRes: OdUtil.Line; VAR conf, res: OdUtil.Line);
VAR confPos: LONGINT;
BEGIN
	IF conf # "" THEN
		padConfiguration(conf);
		confPos := Strings.Pos(conf, confRes);
		Slice(confRes, confPos+Strings.Length(conf), Strings.Length(confRes)-confPos-Strings.Length(conf), res);
	ELSE
		res := confRes;
	END;
END splitConfRes;
(* confResVer = '<conf><res>.<ver>' conf has a trailing CollCh *)
PROCEDURE splitConfResVer*(confResVer: OdUtil.Line; VAR conf, res, ver: OdUtil.Line);
VAR resVer: OdUtil.Line; verPos: INTEGER; pos: LONGINT;
BEGIN
	splitConfRes(confResVer, conf, resVer);
	(* find version number *)
	verPos:= 0;
	FOR pos := 0 TO Strings.Length(resVer)-1 DO
			IF resVer[pos] = VerCh THEN verPos := SHORT(pos); END;
	END;
	Slice(resVer, 0, verPos, res);
	Slice(resVer, verPos+1, Strings.Length(resVer)-verPos-1, ver);
END splitConfResVer;
PROCEDURE splitDirBase(dirBase: OdUtil.Line; VAR dir, base: OdUtil.Line);
VAR resVer: OdUtil.Line; basePos: INTEGER; pos: LONGINT;
BEGIN
	(* find version number *)
	basePos:= -1;
	FOR pos := 0 TO Strings.Length(dirBase)-1 DO
			IF dirBase[pos] = CollCh THEN basePos := SHORT(pos); END;
	END;
	IF basePos = -1 THEN (* no path *)
		dir := ""; base := dirBase;
	ELSE (* split in directory and path *)
		Slice(dirBase, 0, basePos, dir);
		Slice(dirBase, basePos+1, Strings.Length(dirBase)-basePos-1, base);
	END;
END splitDirBase;

PROCEDURE isConfiguration*(res: ARRAY OF CHAR): BOOLEAN;
VAR f: Files.File; absName: OdUtil.Line;
BEGIN
	IF res[Strings.Length(res)-1] = CollCh THEN
		RETURN TRUE;
	ELSE
		absName := ResFileName("", res);
		f := Files.Old(absName);
		IF f # NIL THEN
			RETURN Files.Directory IN f.flags;
		ELSE
			RETURN FALSE;
		END;
	END;
END isConfiguration;

PROCEDURE isConfDataFileName*(res: ARRAY OF CHAR): BOOLEAN;
VAR len: LONGINT;
BEGIN
	IF res # "" THEN
		RETURN res[Strings.Length(res)-1] = PropCh;
	ELSE (* In some cases a conf as an empty string can be sent. *)
		RETURN FALSE;
	END;
END isConfDataFileName;
PROCEDURE isConfPropFileName(res: OdUtil.Line): BOOLEAN;
VAR len: LONGINT;
BEGIN len := Strings.Length(res);
	IF len > 1 THEN
		RETURN (res[len-1] = PropCh);
	ELSE
		RETURN FALSE;
	END;
END isConfPropFileName;

(* Add a trailing '/' *)
PROCEDURE padConfiguration*(VAR conf: ARRAY OF CHAR);
BEGIN
	IF conf = "" THEN
		COPY("/", conf);
	ELSIF conf[Strings.Length(conf)-1] # CollCh THEN
		Strings.Append(conf, CollCh);
	END;
END padConfiguration;

(* Remove a trailing '/' *)
PROCEDURE unpadConfiguration*(VAR conf: ARRAY OF CHAR);
BEGIN
	IF conf # "" THEN
		IF (conf[Strings.Length(conf)-1] = CollCh) THEN
			conf[Strings.Length(conf)-1] := 0X;
		END;
	END;
END unpadConfiguration;

(* Some of the following functions will be consolidated in an object later *)
(** resFileName = workMan.prefix conf "/" res. Also <mountpoint>:.. is possible. *)
PROCEDURE ResFileName*(conf, res: ARRAY OF CHAR): OdUtil.Line;
CONST PLog = FALSE;
VAR name: OdUtil.Line; pos: LONGINT;
BEGIN
	IF conf # "" THEN
		COPY(workMan.prefix, name); unpadConfiguration(name);
		Strings.Append(name, conf); padConfiguration(name);
	ELSE (* perhaps res already complete *)
		pos := Strings.Pos(workMan.prefix, res);
		IF pos # 0 THEN COPY(workMan.prefix, name); ELSE name := ""; END;
	END;
	IF res[0] = CollCh THEN
		unpadConfiguration(name);
	ELSE
		IF pos # 0 THEN
			(* '/' padding needed if res isn't  absolute path *)
			 padConfiguration(name);
		END;
	END;
	Strings.Append(name, res);
	IF PLog THEN OdUtil.Msg6("ResFileName:", conf, ":", res, ":", name); END;
	RETURN name;
END ResFileName;

(** resHrefName = http:// host "/" conf "/" res. *)
PROCEDURE ResHrefName * (host, conf, res: ARRAY OF CHAR): OdUtil.Line;
CONST PLog = FALSE;
VAR name: OdUtil.Line; pos: LONGINT;
BEGIN
	IF host#"" THEN Strings.Concat("http://", host, name); ELSE Strings.Concat("http://", DefaultHostName, name);  END; (*PH XXX*)
	padConfiguration(name);
	IF conf # "" THEN
		unpadConfiguration(name);
		Strings.Append(name, conf); padConfiguration(name);
	END;
	IF res[0] = CollCh THEN
		unpadConfiguration(name);
	END;
	Strings.Append(name, res);
	IF PLog THEN OdUtil.Msg6("ResHrefName:", conf, ":", res, ":", name); END;
	RETURN name;
END ResHrefName;

(** resFileName = conf "/" res "_" *)
PROCEDURE ResPropFileName*(conf, res: ARRAY OF CHAR): OdUtil.Line;
VAR name: OdUtil.Line;
BEGIN
	name := ResFileName(conf, res); Strings.Append(name, PropCh);
	RETURN name;
END ResPropFileName;

PROCEDURE FullSubconfName*(conf, subconf: ARRAY OF CHAR): OdUtil.Line;
VAR full: OdUtil.Line;
BEGIN
	IF subconf[0] = CollCh THEN
		COPY(subconf, full); (* absolute name already. *)
	ELSE (* reative, prefix it with configuration *)
		COPY(conf, full);
		padConfiguration(full);
		Strings.Append(full, subconf);
	END;
	RETURN full;
END FullSubconfName;

PROCEDURE AbsWorkPath*(conf: ARRAY OF CHAR): OdUtil.Line;
VAR abs: OdUtil.Line;
BEGIN
	COPY(workMan.prefix, abs);
	IF conf[Strings.Length(abs)-1] = ':' THEN
		COPY(conf, abs); (* ok *)
	ELSE (* add prefix *)
		IF conf[0] = CollCh THEN
			unpadConfiguration(abs);
		ELSE
			padConfiguration(abs);
		END;
		Strings.Append(abs, conf);
	END;
	RETURN abs;
END AbsWorkPath;

(* <confname>/ -> <confname>_ *)
PROCEDURE ConfDataFileName*(conf: ARRAY OF CHAR): OdUtil.Line;
VAR name: OdUtil.Line; pos: LONGINT;
BEGIN (* <ws>:<conf>/_ *)
	pos := Strings.Pos(workMan.prefix, conf);
	IF pos # 0 THEN
		COPY(workMan.prefix, name);
		IF conf[0] = CollCh THEN
			unpadConfiguration(name);
		ELSE
			padConfiguration(name);
		END;
		Strings.Append(name, conf);
	ELSE
		COPY(conf, name);
	END;
	padConfiguration(name);
	name[Strings.Length(name)-1] := PropCh;
	RETURN name;
END ConfDataFileName;

(* <confData> -> <confData_> *)
PROCEDURE ConfData2PropFileName*(confDat: ARRAY OF CHAR): OdUtil.Line;
VAR name: OdUtil.Line;
BEGIN (* <ws>:<conf>/_ *)
	COPY(confDat, name);
	Strings.Append(name, PropCh);
	RETURN name;
END ConfData2PropFileName;

(* <confname>/ -> <confname>_ *)
PROCEDURE ConfShortDataFileName*(conf: ARRAY OF CHAR): OdUtil.Line;
CONST PLog = FALSE;
VAR name: OdUtil.Line;
BEGIN (* prefix is added later in the resource stage *)
	COPY(conf, name);
	padConfiguration(name);
	name[Strings.Length(name)-1] := PropCh;
	IF PLog THEN  OdUtil.Msg3("ConfShortDataFileName:", conf, name); END;
	RETURN name;
END ConfShortDataFileName;

PROCEDURE ConfHistFileName*(conf: ARRAY OF CHAR): OdUtil.Line;
VAR name: OdUtil.Line; pos, slash: LONGINT;
BEGIN (* <last path segment of configuration> *)
	slash := 0; FOR pos := 0 TO Strings.Length(conf) -1 DO IF conf[pos] = CollCh THEN slash := pos END; END;
	INC(slash); pos := 0;
	REPEAT name[pos] := conf[slash]; INC(slash); INC(pos); UNTIL conf[slash] = 0X;
	Strings.Append(name, PropCh);
	RETURN name;
END ConfHistFileName;

PROCEDURE ConfPropFileName * (conf: ARRAY OF CHAR): OdUtil.Line;
VAR name: OdUtil.Line;
BEGIN
	name := ConfDataFileName(conf); Strings.Append(name, PropCh);
	RETURN name;
END ConfPropFileName;

PROCEDURE ConfFullFileName * (conf: ARRAY OF CHAR): OdUtil.Line;
VAR name: OdUtil.Line;
BEGIN
	COPY(workMan.prefix, name);
	IF conf[0] = CollCh THEN
		unpadConfiguration(name);
	ELSE
		padConfiguration(name);
	END;
	Strings.Append(name, conf);
	padConfiguration(name);
	(** ) OdUtil.Msg2("ConfFullFileName = ", name); ( **)
	RETURN name;
END ConfFullFileName;

PROCEDURE Data2HistFileName*(VAR conf: OdUtil.Line);
VAR segment: OdUtil.Line; pos, slash: LONGINT;
BEGIN (* [<segment>/]<last segment>/_ => <last segment>_ *)
	pos := Strings.Length(conf); conf[pos-2] := PropCh; conf[pos-1] := 0X; (* .../_ => ..._ *)
	slash := -1; FOR pos := 0 TO Strings.Length(conf) -1 DO IF conf[pos] = CollCh THEN slash := pos END; END;
	INC(slash); pos := 0;
	REPEAT segment[pos] := conf[slash]; INC(slash); INC(pos); UNTIL conf[slash] = 0X;
	conf := segment;
END Data2HistFileName;

(** Get configuration name from configuration data file name: <conf> ConfCh => <conf> CollCh*)
PROCEDURE Data2Conf*(dataFileName: OdUtil.Line): OdUtil.Line;
BEGIN
	dataFileName[Strings.Length(dataFileName)-1] := CollCh;
	RETURN dataFileName;
END Data2Conf;

PROCEDURE FileEqual(f1, f2: Files.File): BOOLEAN;
VAR f1r, f2r: Files.Rider; f1ch, f2ch: CHAR;
BEGIN
	IF f1.Length() # f2.Length() THEN RETURN FALSE; END;
	f1.Set(f1r, 0); f2.Set(f2r, 0);
	LOOP
		f1r.file.Read(f1r,f1ch); f2r.file.Read(f2r,f2ch);
		IF f1r.eof OR f2r.eof THEN RETURN f1r.eof & f2r.eof; END;
		IF f1ch # f2ch THEN RETURN FALSE END;
	END;
END FileEqual;

(** Load all members of a VCC from it's file <conf>. Return a list of lines alternating <path>,<url>.
Members can be resources and configurations.*)
PROCEDURE VCCloadMembers(conf: OdUtil.Line): OdUtil.Lines;
VAR  lines: OdUtil.Lines; line: OdUtil.Line; (*  *)
	reader:  Files.Reader; file: Files.File;
BEGIN
	NEW(lines); line := ConfDataFileName(conf);
	file := Files.Old(line);
	IF file # NIL THEN
		NEW(reader, file, 0);
		LOOP
			reader.SkipWhitespace; IF reader.res # Streams.Ok THEN EXIT; END;
			reader.Token(line); IF reader.res # Streams.Ok THEN EXIT; END;
			(**) OdUtil.Msg2("VCCloadMembers res", line); (**)
			lines.add(line);
			reader.SkipWhitespace; IF reader.res # Streams.Ok THEN EXIT; END;
			reader.Token(line); IF reader.res # Streams.Ok THEN EXIT; END;
			(**) OdUtil.Msg2("VCCloadMembers ver", line); (**)
			lines.add(line);
		END;
	END;
	(* DAVTexts  *)
	IF lines = lines.next THEN lines := NIL; END; (* lines added *)
	RETURN lines;
END VCCloadMembers;

(** Store all members of a VCC from it's alternating <path>,<url> line to it's file.
Members can be resources and configurations.*)
PROCEDURE VCCstoreMembers(conf: OdUtil.Line; lines: OdUtil.Lines);
VAR  fileName: OdUtil.Line; file: Files.File; writer: Files.Writer;
	(*  *)
BEGIN
	fileName := ConfDataFileName(conf);
	file := Files.New(fileName);
	NEW(writer, file, 0);
	WHILE lines # NIL DO
		(**) OdUtil.Msg2("VCCstoreMembers res", lines.line); (**)
		writer.String(lines.line); writer.Char(' '); lines := lines.next;
		(**) OdUtil.Msg2("VCCstoreMembers ver", lines.line); (**)
		writer.String(lines.line); writer.Char(0DX); lines := lines.next;
	END;
	writer.Update;
	(* DAVTexts  *)
	Files.Register(file);
END VCCstoreMembers;

(** Find subconfigurations from version properties. Marked by trailing CollChar.  *)
PROCEDURE findVCCs*(conf: OdUtil.Line): OdUtil.Lines;
CONST PLog0 = FALSE; PLog1 = FALSE;
VAR subconfs: OdUtil.Lines; subconf: OdUtil.Line;
	splitter: OdXml.StringSplitter;
	props: VersionProperties; subbaselineLine: ARRAY 1024 OF CHAR;
BEGIN
	padConfiguration(conf);
	IF PLog0 THEN OdUtil.Msg2("DAVDeltavBase.findVCCs: ", conf); END;
	NEW(subconfs);
	NEW(props, "", conf);
	props.get("DAV:subbaseline-set", subbaselineLine);
	IF PLog0 THEN OdUtil.Msg2("DAVDeltavBase.findVCCs: subbaselineLine = ", subbaselineLine); END;
	NEW(splitter, subbaselineLine);
	WHILE splitter.Next(0DX, subconf) DO
		IF PLog1 THEN OdUtil.Msg2("DAVDeltavBase.findVCC: subbaseline = ", subconf);  END;
		subconfs.add(FullSubconfName(conf, subconf));
	END;
	IF subconfs = subconfs.next THEN subconfs := NIL; END; (* lines added *)
	RETURN subconfs;
END findVCCs;

(** Find version controlled resources of a configuration with pattern: <conf>*<PropChar>
	Use pattern '*' and then check for trailing '.' because System.Directory doesn't match like expected.
	Return the paths without trailing '.'.  *)
PROCEDURE findVCRs * (conf: OdUtil.Line): OdUtil.Lines;
 VAR lines: OdUtil.Lines;

PROCEDURE findVCRs0(conf, resDir: OdUtil.Line);
CONST
	PLog = FALSE;
VAR enum: Files.Enumerator;
	(* <conf><resDir><resBase>: pattern =  <conf><resDir>* *)
	pattern, name, confResDir: OdUtil.Line; time, date, size: LONGINT;
	entryFlags, flags: SET;
	f: Files.File;
BEGIN
	flags := {}; entryFlags := {};
	padConfiguration(conf);
	Strings.Concat(conf, resDir, confResDir);
	pattern := ConfFullFileName(confResDir); Strings.Append(pattern, '*');
	IF PLog THEN OdUtil.Msg3("findVCRs:", confResDir, pattern); END;
	(* Iterating over all entries and filtering without file open test would also be possible.
		Probably more efficient. Working with a couple of Lines would be necessary. *)
	NEW(enum); enum.Open(pattern, flags);
	WHILE enum.GetEntry(name, entryFlags, time, date, size) DO
		IF PLog THEN  OdUtil.Msg2("findVCRs.file:", name); END;
		IF name[Strings.Length(name)-1]  = PropCh THEN
			(* Resource propfile or configuration datafile *)
			name[Strings.Length(name)-1] := 0X; (* drop trailing PropCh to get real name *)
			IF name[Strings.Length(name)-1]  # PropCh THEN
				(* Configuration prop files are ignored. *)
				f := Files.Old(name);
				IF f #  NIL THEN
					IF ~ (Files.Directory IN f.flags) THEN
						(* Not datafile of a directory. *)
						IF PLog THEN  OdUtil.Msg3("findVCRs.found:", conf, name);  END;
						lines.add(name);
					END;
					Files.Register(f); (* Close it again. *)
				END;
			END;
		ELSIF Files.Directory IN entryFlags THEN
			f := Files.Old(ConfDataFileName(name));
			IF f = NIL THEN
				(* No subconfiguration. *)
				Strings.Copy(name, Strings.Length(pattern)-1, Strings.Length(name)-Strings.Length(pattern)+1, resDir);
				padConfiguration(resDir);
				findVCRs0(conf, resDir);
			ELSE
				Files.Register(f); (* Close it again. *)
			END;
		END;
	END;
	enum.Close;
END findVCRs0;

BEGIN
	NEW(lines);
	findVCRs0(conf, "");
	IF lines = lines.next THEN lines := NIL; END; (* lines added *)
	RETURN lines;
END findVCRs;

PROCEDURE thawedVCRs(conf: OdUtil.Line): OdUtil.Lines;
VAR thawed, vcrs: OdUtil.Lines; props: VersionProperties; res: OdUtil.Line;
BEGIN
	vcrs := findVCRs(conf); NEW(thawed);
	WHILE vcrs # NIL DO
		splitConfRes(vcrs.line, conf, res);
		NEW(props, conf, res);
		IF props.state = "thawed" THEN thawed.add(res); END;
		vcrs := vcrs.next;
	END;
	IF thawed = thawed.next THEN thawed := NIL; END; (* lines added *)
	RETURN thawed;
END thawedVCRs;






(*  VERSION-CONTROL *)
(* CHECKIN  *)
(* BASELINE-CONTROL  *)
(* CHECKIN *)
(*  VERSION-CONTROL  *)
(* UPDATE  *)
(* BASELINE-CONTROL *)
(* UPDATE  *)
(* CHECKOUT  *)
(* CHECKOUT  *)
(* UNCHECKOUT  *)
(* UNCHECKOUT  *)
(* PUT  *)
(* MKCOL  *)
(* REPORT  *)
(* REPORT  *)
(* REPORT  *)

PROCEDURE GetErrorMsg(res: LONGINT; VAR s: ARRAY OF CHAR);
VAR temp: ARRAY 8 OF CHAR;
BEGIN
(***********
	CASE res OF
	| FATFiles.ErrReadOnly: COPY("read-only file system", s)
	| FATFiles.ErrInvalidParams: COPY("invalid parameters", s)
	| FATFiles.ErrIOError: COPY("I/O error", s)
	| FATFiles.ErrFileReadOnly: COPY("file is read-only", s)
	| FATFiles.ErrParentNotFound: COPY("parent directory not found", s)
	| FATFiles.ErrInvalidFilename: COPY("invalid filename", s)
	| FATFiles.ErrTooManySimilarFiles: COPY("too many similar filenames", s)
	| FATFiles.ErrRootDirFull: COPY("root directory overflow", s)
	| FATFiles.ErrFileNotFound: COPY("file not found", s)
	| FATFiles.ErrFileExists: COPY("file exists", s)
	| FATFiles.ErrHasOpenFiles: COPY("has open files. Try System.Collect first", s)
	| FATFiles.ErrNoRelativePaths: COPY("relative path names not supported", s)
	| FATFiles.ErrDirectoryProtection: COPY("directory is write-protected", s)
	| FATFiles.ErrDirectoryNotEmpty: COPY("directory not empty", s)
	| FATFiles.ErrNotADirectory: COPY("not a directory", s)
	| FATFiles.ErrDirectoryOpen: COPY("directory is still open", s)
	ELSE OdUtil.Msg2("unknown error: ", OdUtil.I(res))
	END
*********)
	temp:=OdUtil.I(res); OdUtil.Msg2("GetErrorMsg: error=", temp);
END GetErrorMsg;

(** Create a FAT Directory: path. Includes prefix, e.g. "FTP:/New Folder/A/B/C" *)
PROCEDURE CreDir*(path: ARRAY OF CHAR);
VAR p: ARRAY 1024 OF CHAR;
	res: LONGINT; msg: ARRAY 256 OF CHAR;
BEGIN
	COPY(path, p);
	OdUtil.Msg3("Creating directory: ", p, ": ");
	Files.CreateDirectory(p, res);
	IF (res = 0) THEN
		OdUtil.Msg1("created");
		Files.CreateDirectory(p, res); (* HACK: Try to create again. *)
	ELSE
		IF (res = -1) THEN COPY("directories not supported by file system", msg)
		ELSE GetErrorMsg(res, msg);
		END;
		OdUtil.Msg1(msg)
	END;
END CreDir;

(** Remove a FAT Directory: path ["\F"]. Includes prefix, e.g. "FTP:/A/B/C". Use 'force' for  deletion of non-empty dirs. *)
PROCEDURE RemDir*(path: ARRAY OF CHAR; force: BOOLEAN);
VAR p: ARRAY 1024 OF CHAR;
	res: LONGINT; msg: ARRAY 256 OF CHAR;
BEGIN
	COPY(path, p);
	OdUtil.Msg3("Deleting directory: ", p, ": ");
	Files.RemoveDirectory(p, force, res);
	IF (res = 0) THEN OdUtil.Msg1("deleted")
	ELSE
		IF (res = -1) THEN COPY("directories not supported by file system", msg)
		ELSE GetErrorMsg(res, msg);
		END;
		OdUtil.Msg1(msg)
	END;
END RemDir;

BEGIN
	(* Default values should be changed in WebDAVServerTools.AddHost() *)
	COPY(DefaultHostName, hostName);
	COPY(DefaultWorkspace,Workspace);
	COPY(DefaultWorkspaceTemp,WorkspaceTemp);
	COPY(DefaultRepoPath, RepoPath);
	NEW(repMan); NEW(workMan, Workspace);
	NEW(localServer, repMan.prefix);
	frozenDeleted := FALSE;
	NEW(OdC); NEW(OdX);
	Strings.AppendChar(CRString,CR);
END OdDeltavBase.

Builder.Compile * System.Free DAVDeltavBase VCS OdVCSBase ~

OFSTools.Mount DV AosFS IDE0#05 ~ OFSTools.Unmount DV ~
(* Collection DV:deltav.test. exists. DAVDeltavBase.localServer,localClient are created with loading. *)
Environment
Repository: v.<resource name>
Release configuration: deltav.rel.
Development configuration: deltav.dev

System.DeleteFiles ~ System.Directory ^ v.*\d deltav.test*\d  deltav.rel.*\d deltav.test.data1.Text deltav.rel.data1.Text
deltav.rel.data1.Text. deltav.rest*
CHECKIN    DAVDeltavBase.fiR deltav.test. data1.Text "edgar@edgarschwarz.de" "Eine erste Testversion" expand ~
	DAVDeltavBase.fiR deltav.test. data2.Text "edgar@edgarschwarz.de" "Eine erste Testversion der 2. Datei" expand ~
	DAVDeltavBase.foR deltav.test. data1.Text "edgar@edgarschwarz.de" "Eine 4. Testversion der 1. Datei" expand ~
	DAVDeltavBase.foC deltav.test. "edgar@edgarschwarz.de" "Nun mit relativem Pfad und Versionhistory in ResourceURLs" ~
UPDATE	DAVDeltavBase.siR deltav.test. data1.Text data1.Text.3 ~ History name from version URL
	DAVDeltavBase.soR deltav.test. data1.Text 3 ~ History name from property file.
	DAVDeltavBase.siC deltav.rest. deltav.test..5 ~ Take resource name as history name at the moment.
CHECKOUT DAVDeltavBase.tR deltav.test. data1.Text ~
UNCHECKOUT DAVDeltavBase.utR deltav.test. data1.Text ~
REPORT DAVDeltavBase.rC deltav.test. DAVDeltavBase.rR deltav.test. data1.Text
	DAVDeltavBase.rH data1.Text DAVDeltavBase.rH deltav.test.

DAVDeltavBase.cB deltav.test..7 deltav.test..8
DAVDeltavBase.cB deltav.test..8 deltav.test..9
DAVDeltavBase.cB deltav.test..7 deltav.test..9

Old Interface:
VCS.HandleView v.data1.Text 1 VCS.init v.deltav.test. VCS.init v.data1.Text VCS.rlog v.deltav.test. 3
Report VCS.init  <file name> 	; number of versions, -1 if none exist
			shows number of versions in <version number>
CheckIn VCS.New <file name> "<author>" "log text"
			; create new version, first is 1, else increment last
PropFind VCS.rlog <file> <version> VCS.rlog v.data3.Text 1
			; show log text of version in System.log and also in panel
			; tags only will be expanded it log text starts with $
CheckOut  VCS.HandleView <file name> <version number>
			; get version from file and create file <file>.V<version>
			; if it doesn't exist

Was passiert eigentlich nach dem ersten VERSION-CONTROL ? Ist da die Arbeitsdatei da ? Dann müsste ich gleich
ein selectInitialResource hinterherschicken.

Subconfigurations:
- Version is registered in '<conf>.'. The '.' is a sign for a subbaseline. Will be the collection char. CollCh = '.' | '/'.
- Freeze:
	- check own frozen VCRs
	- check sub VCRs. If VCC is frozen just return version URL. Else show thawed stuff.
	- if all VCRs are frozen but some thawed VCCs freeze them recursively and add their version URLs to  '<conf>.'.
	  use the same logtext for all thawed VCCs.
	- then freeze configuration itself.
- Select:
	- check recursively for thawed VCRs
	- selcect VCRs
	- select VCCs
- Thaw:
	Check whether Masterconfiguration is thawed => Configuration needs 'parentConf'.

Done
- Vergleich mit falscher Version beim Diff: ExpandTags hat gefehlt.
ToDo
- Relative Pfade unter einer Rootkonfiguration.
- Beschreibung in DAV.Panel ergänzen
- Erste Baseline von DAVDeltav: Workspace 'dav.' ?
	es.DAVDeltav.Tool
- Historyfiles v.<nnn><name> Einfach dreistellig durchzählen oder mit '0' anfangen und nur im Falle eines
	Konflikts (sollte selten vorkommen) hochzählen ?
- Bei Select einer Konfiguration Dateien die stimmen nicht löschen und wieder herausholen, sondern
	lassen.

