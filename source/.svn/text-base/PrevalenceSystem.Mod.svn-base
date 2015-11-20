MODULE PrevalenceSystem; (** AUTHOR "Luc Blaeser"; PURPOSE "Prevalence System - Persistent Object System"*)

IMPORT XML, XMLObjects, XMLScanner, XMLParser, TFClasses,
	Strings, Modules, Kernel, Files, Streams, KernelLog, Configuration;

CONST
	DEBUG = FALSE; (* debug output *)

	ConfigurationSupperSectionName = "PrevalenceSystem";
	ConfigurationSubSectionName = "PersistentObjectModules";
	ProcNameGetDescriptors = "GetPersistentObjectDescriptors";

	SnapShotIntervall = 15 * 60 * 100; (* 15 minutes *)

	StandardPrevSystemName = "StandardPrevalenceSystem";
	StandardSnapShotFileName = "PrevalenceSnapShot.XML";
	StandardLogFileName = "PrevalenceLog.XML";

	XMLProlog = '<?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?>';
	XMLRootElemName = "instances";
	XMLOidCounterAttrName = "oidcounter";
	XMLInstanceElemName = "instance";
	XMLAttrModuleName = "module";
	XMLAttrObjectName = "object";
	XMLAttrOidName = "oid";
	XMLAttrIsRootName = "isroot";
	XMLAttrSavingCounter ="time";
	XMLLogRootElemName = "log";
	XMLLogDelInstElemName = "deleted"; (* only for root elements *)

	TermTimeout = 1000*1000; (* Wait time to terminate *)

	(** abstract base type for all persistent objects.
	 * Since there is no introspection of object fields possible the user has to implement
	 * the externalization and internalization of an object state in XML on its own.
	 * Each command on the PersistentObject which modifies its state must be explicitly done in a
	 * BeginTransaction..EndTransaction block to ensure logging of the state changement.
	 * All persistent objects have to be registered by the prevalence system to make sure that their
	 * persistent object descriptor is known.
	 * Certain persistent objects are registered as root objects to contribute to the root set
	 * of reachable persistent objects for the persistent object garbage collector of the prevalence system.
	 * Each persistent object can belong only to one prevalence system
	 *)
	TYPE
		PersistentObject* = OBJECT
			VAR
				oid*: LONGINT; (** oid of the persistent object *)
				inModification, takingSnapShot: BOOLEAN;
				registeredAt*: PrevalenceSystem; (* prevalence system where this object is registered *)

			PROCEDURE &Init*;
			BEGIN oid := 0; inModification := FALSE; takingSnapShot := FALSE; registeredAt := NIL
			END Init;

			PROCEDURE BeginModification*;
			BEGIN {EXCLUSIVE}
				AWAIT((~takingSnapShot) & (~inModification));
				inModification := TRUE;
			END BeginModification;

			PROCEDURE EndModification*; (** after the return of this method the transaction is commited *)
			BEGIN {EXCLUSIVE}
				IF (registeredAt # NIL) THEN
					registeredAt.Log(SELF)
				ELSE
					HALT(9999); (* Object must be registered in at least one prevalence system *)
				END;
				inModification := FALSE
			END EndModification;

			PROCEDURE Externalize*() : XML.Content;
			BEGIN HALT(309);
			RETURN NIL;
			END Externalize;

			PROCEDURE Internalize*(xml: XML.Content);
			BEGIN HALT(309)
			END Internalize;

			PROCEDURE GetReferrencedObjects*() : PersistentObjectList;
			(** return all persistent objects which are referrenced by instance variables *)
			BEGIN RETURN NIL
			END GetReferrencedObjects;

		END PersistentObject;

		PersistentObjectList* = POINTER TO ARRAY OF PersistentObject;

		PersistentObjectFactory* = PROCEDURE (): PersistentObject;

		(** used to instantiate a persistent object since there is no introspection possible *)
		PersistentObjectDescriptor* = OBJECT
			VAR
				moduleName*, objectName*: Strings.String;
				factory*: PersistentObjectFactory;

			PROCEDURE &Init*(CONST modName, objName: ARRAY OF CHAR; factoryProc: PersistentObjectFactory);
			BEGIN
				NEW(moduleName, LEN(modName)); NEW(objectName, LEN(objName));
				COPY(modName, moduleName^); COPY(objName, objectName^);
				factory := factoryProc
			END Init;
		END PersistentObjectDescriptor;

		PersistentObjectDescSet* = OBJECT
			VAR
				descriptors*: POINTER TO ARRAY OF PersistentObjectDescriptor;

			PROCEDURE &Init*(CONST descs: ARRAY OF PersistentObjectDescriptor);
			VAR i: LONGINT;
			BEGIN
				NEW(descriptors, LEN(descs));
				FOR i := 0 TO LEN(descs)-1 DO
					descriptors[i] := descs[i]
				END
			END Init;

			PROCEDURE GetCount*() : LONGINT;
			BEGIN
				RETURN LEN(descriptors^)
			END GetCount;

			PROCEDURE GetItem*(i: LONGINT) : PersistentObjectDescriptor;
			BEGIN
				RETURN descriptors[i]
			END GetItem;
		END PersistentObjectDescSet;

		PersistentObjectDescSetFactory = PROCEDURE() : PersistentObjectDescSet;

		(** additionally there must be a procedure which gives all descriptors for the persistent objects in the module
			PROCEDURE GetPersistentObjectDescriptors*(par:ANY) : ANY;
				 no parameter; returns the descriptors of active elements (PersistentObjectDescSet)
				 must be thread safe
		 *)

		(** returns true iff the persistent object satisfies the predicate *)
		FilterPredicate* = PROCEDURE {DELEGATE} (obj: PersistentObject) : BOOLEAN;

		(* belongs to exactly one prevalence system *)
		PersistentObjectWrapper = OBJECT
			VAR
				prevalenceSystem: PrevalenceSystem;
				instance: PersistentObject;
				descriptor: PersistentObjectDescriptor;
				savingCounter: LONGINT; (* when was the object the last time saved in the snapshot *)
				isRoot: BOOLEAN; (* true iff the object belongs to the root set of the mark phase *)
				isMarked: BOOLEAN; (* temporary use in the mark phase, true iff not garbage *)

			PROCEDURE &Init*(prevSys: PrevalenceSystem; obj: PersistentObject; desc: PersistentObjectDescriptor);
			BEGIN
				ASSERT(prevSys # NIL); ASSERT(obj # NIL); ASSERT(desc # NIL);
				prevalenceSystem := prevSys;
				IF (obj.oid = 0) THEN obj.oid := prevalenceSystem.GetNewOid() END; (* set an oid if not done yet *)
				instance := obj; descriptor := desc;
				isMarked := TRUE (* don't remove in a now running GC sweep phase *)
			END Init;
		END PersistentObjectWrapper;

		SnapShotManager = OBJECT
			VAR timer: Kernel.Timer; alive, terminated: BOOLEAN;
				i: LONGINT; p: ANY; prevSys: PrevalenceSystem;
			BEGIN {ACTIVE}
				IF (DEBUG) THEN KernelLog.String("Prevalence System: Snapshot Manager started."); KernelLog.Ln END;
				NEW(timer); alive := TRUE; terminated := FALSE;
				timer.Sleep(SnapShotIntervall);
				WHILE (alive) DO
					prevSystemList.Lock;
					FOR i := 0 TO prevSystemList.GetCount()-1 DO
						p := prevSystemList.GetItem(i); prevSys := p(PrevalenceSystem);
						IF (DEBUG) THEN
							KernelLog.String("Prevalence System '"); KernelLog.String(prevSys.SystemName^);
							KernelLog.String("': Storing a snapshot."); KernelLog.Ln
						END;

						prevSys.PersistAllObjects;

						IF (DEBUG) THEN
							KernelLog.String("Prevalence System '"); KernelLog.String(prevSys.SystemName^);
							KernelLog.String("': Snapshot done."); KernelLog.Ln
						END
					END;
					prevSystemList.Unlock;
					timer.Sleep(SnapShotIntervall)
				END;
				IF (DEBUG) THEN KernelLog.String("Prevalence System: Snapshot Manager terminated."); KernelLog.Ln END;
				terminated := TRUE;
		END SnapShotManager;

	TYPE PrevalenceSystem* = OBJECT
		VAR
			SnapShotFileName*: Strings.String;
			LogFileName*: Strings.String;
			SystemName*: Strings.String;

			persistentObjectList: TFClasses.List; (* List of PersistentObjectWrapper *)
			oidCounter: LONGINT;

			(* file access synchronization *)
			lockSnapShotFile: BOOLEAN;
			lockLogFile: BOOLEAN;

			(* persistent object list synchronization *)
			lockPersList: BOOLEAN;

		(**  the prevalence system name, the snapshot file name and the log file name must be different to
		 * those of the other present prevalence systems. *)
		PROCEDURE &Init*(CONST name, snapShotFn, logFn: ARRAY OF CHAR);
		VAR i: LONGINT; p: ANY; prevSys: PrevalenceSystem;
		BEGIN
			LockPrevSystemList;
			prevSystemList.Lock;
			FOR i := 0 TO prevSystemList.GetCount()-1 DO
				p := prevSystemList.GetItem(i); prevSys := p(PrevalenceSystem);
				IF ((prevSys.SystemName^ = name) OR (prevSys.SnapShotFileName^ = snapShotFn)
				  OR (prevSys.LogFileName^ = logFn)) THEN
					prevSystemList.Unlock;
					UnlockPrevSystemList;
					HALT(9999) (* conflict with other prevalence system *)
				END
			END;
			prevSystemList.Unlock;
			NEW(SystemName, LEN(name)+1); COPY(name, SystemName^);
			NEW(SnapShotFileName, LEN(snapShotFn)+1); COPY(snapShotFn, SnapShotFileName^);
			NEW(LogFileName, LEN(logFn)+1); COPY(logFn, LogFileName^);
			NEW(persistentObjectList); oidCounter := 1;
			lockSnapShotFile := FALSE; lockLogFile := FALSE; lockPersList := FALSE;
			RestoreAllObjects;
			prevSystemList.Add(SELF);
			UnlockPrevSystemList;
		END Init;

		(** each persistent object has to be registered in the prevalence system to make sure that its descriptor is known.
		 * This does not affect that the object will be collected as garbage if it is not reachable through a root persistent object *)
		PROCEDURE AddPersistentObject*(obj: PersistentObject; desc: PersistentObjectDescriptor);
		VAR wrapper : PersistentObjectWrapper;
		BEGIN
			LockPersistentObjList;
			IF ((desc # NIL) & (FindRegisteredDescriptor(desc.moduleName^, desc.objectName^) # NIL)) THEN
				IF ((obj # NIL) & (GetRegisteredWrapper(obj) = NIL)) THEN (* object is not registered yet *)
					IF (obj.registeredAt = NIL) THEN
						obj.registeredAt := SELF
					ELSIF (obj.registeredAt # SELF) THEN
						UnlockPersistentObjList;
						KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
						KernelLog.String("': Cannot add objects which are alreaduy registered in another prevalence system.");
						KernelLog.Ln; HALT(9999)
					END;
					NEW(wrapper, SELF, obj, desc);
					persistentObjectList.Add(wrapper);
					UnlockPersistentObjList;
					Log(obj)
				ELSE
					UnlockPersistentObjList
				END
			ELSE
				UnlockPersistentObjList;
				KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
				KernelLog.String("': Cannot add objects with an unregistered descriptor to the prevelance system");
				KernelLog.Ln; HALT(9999)
			END
		END AddPersistentObject;

		(** add object to the root set of the prevalence system. This objects must be manually removed from the prevalence system,
		 * All objects reached by a root persistent object are also persistent *)
		PROCEDURE AddPersistentObjectToRootSet*(obj: PersistentObject; desc: PersistentObjectDescriptor);
		VAR wrapper : PersistentObjectWrapper;
		BEGIN
			LockPersistentObjList;
			IF ((desc # NIL) & (FindRegisteredDescriptor(desc.moduleName^, desc.objectName^) # NIL)) THEN
				IF (obj # NIL) THEN
					wrapper := GetRegisteredWrapper(obj);
					IF (wrapper = NIL) THEN (* object is not registered yet *)
						IF (obj.registeredAt = NIL) THEN
							obj.registeredAt := SELF
						ELSIF (obj.registeredAt # SELF) THEN
							UnlockPersistentObjList;
							KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
							KernelLog.String("': Cannot add objects which are alreaduy registered in another prevalence system.");
							KernelLog.Ln; HALT(9999)
						END;
						NEW(wrapper, SELF, obj, desc);
						wrapper.isRoot := TRUE;
						persistentObjectList.Add(wrapper)
					ELSE
						wrapper.isRoot := TRUE
					END;
					UnlockPersistentObjList;
					Log(obj)
				END
			ELSE
				UnlockPersistentObjList;
				KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
				KernelLog.String("': Cannot add objects with an unregistered descriptor to the prevelance system");
				KernelLog.Ln; HALT(9999)
			END
		END AddPersistentObjectToRootSet;

		(** the object will be marked to be no more belonging to the root set and all persistent objects only reachable by this
		 * object will be removed in the next garbage collection phase *)
		PROCEDURE RemovePersistentRootObject*(obj: PersistentObject);
		VAR wrapper: PersistentObjectWrapper;
		BEGIN
			LockPersistentObjList;
			wrapper := GetRegisteredWrapper(obj);
			IF ((wrapper # NIL) & (wrapper.isRoot)) THEN
				wrapper.isRoot := FALSE;
				UnlockPersistentObjList;
				LogRemovalFromRootSet(wrapper)
			ELSE
				UnlockPersistentObjList
			END
		END RemovePersistentRootObject;

		PROCEDURE GetPersistentObject*(oid: LONGINT): PersistentObject;
		VAR wrapper: PersistentObjectWrapper;
		BEGIN
			wrapper := GetRegisteredWrapperByOid(oid);
			IF (wrapper # NIL) THEN
				RETURN wrapper.instance
			ELSE
				RETURN NIL
			END
		END GetPersistentObject;

		PROCEDURE GetDescriptorByObject*(obj: PersistentObject) : PersistentObjectDescriptor;
		VAR wrapper: PersistentObjectWrapper;
		BEGIN
			wrapper := GetRegisteredWrapper(obj);
			IF (wrapper # NIL) THEN
				RETURN wrapper.descriptor
			END
		END GetDescriptorByObject;

		PROCEDURE FindPersistentObjects*(pred: FilterPredicate) : PersistentObjectList;
		VAR i: LONGINT; p: ANY; wrapper: PersistentObjectWrapper; obj: PersistentObject;
			list: TFClasses.List; persList: PersistentObjectList;
		BEGIN
			NEW(list);
			persistentObjectList.Lock;
			FOR i := 0 TO persistentObjectList.GetCount()-1 DO
				p := persistentObjectList.GetItem(i); wrapper := p(PersistentObjectWrapper); (* wrapper # NIL *)
				obj := wrapper.instance;
				IF (pred(obj)) THEN
					list.Add(obj)
				END
			END;
			persistentObjectList.Unlock;
			IF (list.GetCount() > 0) THEN
				NEW(persList, list.GetCount());
				FOR i := 0 TO list.GetCount()-1 DO
					p := list.GetItem(i); obj := p(PersistentObject);
					persList[i] := obj
				END;
				RETURN persList
			ELSE
				RETURN NIL
			END
		END FindPersistentObjects;

		PROCEDURE GetNewOid() : LONGINT;
		BEGIN {EXCLUSIVE}
			INC(oidCounter); RETURN oidCounter-1
		END GetNewOid;

		PROCEDURE GetXMLDocument(file: Files.File) : XML.Document;
		VAR scanner: XMLScanner.Scanner; parser: XMLParser.Parser; doc: XML.Document;
			reader: Files.Reader;
		BEGIN (* file # NIL *)
			NEW(reader, file, 0);
			NEW(scanner, reader);
			NEW(parser, scanner);
			LockParsingScanning;
			scanner.reportError := ReportXMLParserScannerError;
			parser.reportError := ReportXMLParserScannerError;
			doc := parser.Parse();
			UnlockParsingScanning;
			IF (xmlParserErrorOccurred) THEN
				KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
				KernelLog.String("': "); KernelLog.String(xmlParserErrorMsg); KernelLog.Ln;
				RETURN NIL
			ELSE
				RETURN doc
			END
		END GetXMLDocument;

		PROCEDURE LockSnapShotFile;
		BEGIN {EXCLUSIVE}
			AWAIT(~lockSnapShotFile);
			lockSnapShotFile := TRUE
		END LockSnapShotFile;

		PROCEDURE UnlockSnapShotFile;
		BEGIN {EXCLUSIVE}
			lockSnapShotFile := FALSE
		END UnlockSnapShotFile;

		PROCEDURE LockLoggingFile;
		BEGIN {EXCLUSIVE}
			AWAIT(~lockLogFile);
			lockLogFile := TRUE
		END LockLoggingFile;

		PROCEDURE UnlockLoggingFile;
		BEGIN {EXCLUSIVE}
			lockLogFile := FALSE
		END UnlockLoggingFile;

		PROCEDURE LockPersistentObjList;
		BEGIN {EXCLUSIVE}
			AWAIT(~lockPersList);
			lockPersList := TRUE
		END LockPersistentObjList;

		PROCEDURE UnlockPersistentObjList;
		BEGIN {EXCLUSIVE}
			lockPersList := FALSE
		END UnlockPersistentObjList;

		PROCEDURE CompactLogFile;
		VAR file, newfile: Files.File; doc: XML.Document; root, elem: XML.Element; enum: XMLObjects.Enumerator;
			p: ANY; oidString, savingCounterString: Strings.String; i, oid, savingCounter: LONGINT;
			wrapper: PersistentObjectWrapper; removeList: TFClasses.List; fwriter: Files.Writer; writer: Streams.Writer;
			elemName, rootName: Strings.String;
		BEGIN
			LockLoggingFile;
			file := Files.Old(LogFileName^);
			IF (file # NIL) THEN
				newfile := Files.New(LogFileName^);
				IF (newfile # NIL) THEN
					NEW(removeList);
					doc := GetXMLDocument(file);
					IF (doc # NIL) THEN
						root := doc.GetRoot();
						rootName := root.GetName();
						IF (rootName^ = XMLLogRootElemName) THEN
							enum := root.GetContents();
							WHILE (enum.HasMoreElements()) DO
								p := enum.GetNext();
								IF (p IS XML.Element) THEN
									elem := p(XML.Element);
									elemName := elem.GetName();
									IF ((elemName^ = XMLInstanceElemName) OR (elemName^ = XMLLogDelInstElemName)) THEN
										oidString := elem.GetAttributeValue(XMLAttrOidName);
										savingCounterString := elem.GetAttributeValue(XMLAttrSavingCounter);
										IF ((oidString # NIL) & (savingCounterString # NIL)) THEN
											Strings.StrToInt(oidString^, oid); Strings.StrToInt(savingCounterString^, savingCounter);
											wrapper := GetRegisteredWrapperByOid(oid);
											IF (((wrapper # NIL) & (savingCounter < wrapper.savingCounter)) OR (wrapper = NIL)) THEN
												(* either the savingCounter for the log entry is stale or the object has been removed *)
												removeList.Add(elem)
											END
										ELSE
											KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
											KernelLog.String("': In the snapshot file '"); KernelLog.String(SnapShotFileName^);
											KernelLog.String("' is an instance without oid or without saving time."); KernelLog.Ln
										END
									END
								END
							END;

							FOR i := 0 TO removeList.GetCount()-1 DO
								p := removeList.GetItem(i); elem := p(XML.Element);
								root.RemoveContent(elem)
							END;

							Files.OpenWriter(fwriter, newfile, 0); writer := fwriter;
							doc.Write(writer, NIL, 0);

							fwriter.Update;
							Files.Register(newfile);

							IF (DEBUG) THEN
								KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
								KernelLog.String("': Log file compacted."); KernelLog.Ln
							END
						ELSE
							KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
							KernelLog.String("': Cannot overwrite the log file '"); KernelLog.String(SnapShotFileName^);
							KernelLog.String("' while compacting the log file."); KernelLog.Ln
						END
					ELSE
						KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
						KernelLog.String("': In the log file '"); KernelLog.String(LogFileName^);
						KernelLog.String("' must be a root defined as '"); KernelLog.String(XMLLogRootElemName);
						KernelLog.String("'."); KernelLog.Ln
					END;
				END
			END;
			UnlockLoggingFile
		END CompactLogFile;

		PROCEDURE GarbageCollect*;
		VAR i: LONGINT; pObj: ANY; wrapper: PersistentObjectWrapper; removeList: TFClasses.List;
			(* get the registered wrapper without locking the persistentObjectList, since it is already locked by outer procedure *)
			PROCEDURE GetWrapperForObj(obj: PersistentObject) : PersistentObjectWrapper;
			VAR k: LONGINT; ptr: ANY; wpr: PersistentObjectWrapper;
			BEGIN
				FOR k := 0 TO persistentObjectList.GetCount()-1 DO
					ptr := persistentObjectList.GetItem(k); wpr := ptr(PersistentObjectWrapper); (* wpr # NIL *)
					IF (wpr.instance = obj) THEN
						RETURN wpr
					END
				END;
				RETURN NIL
			END GetWrapperForObj;

			PROCEDURE MarkReachableObjects(obj: PersistentObject);
			VAR k: LONGINT; list: PersistentObjectList; wpr: PersistentObjectWrapper;
			BEGIN (* w # NIL & w.instance # NIL *)
				list := obj.GetReferrencedObjects();
				IF (list # NIL) THEN
					FOR k := 0 TO LEN(list)-1 DO
						wpr := GetWrapperForObj(list[k]);
						IF (wpr # NIL) THEN
							IF (~wpr.isMarked) THEN
								wpr.isMarked := TRUE; (* cyclic referrencing possible *)
								MarkReachableObjects(wpr.instance) (* wpr.instance # NIL *)
							ELSE
								wpr.isMarked := TRUE
							END
						END
					END
				END
			END MarkReachableObjects;
		BEGIN
			LockPersistentObjList;
			persistentObjectList.Lock;
			FOR i := 0 TO persistentObjectList.GetCount()-1 DO(* unmark all objects *)
				pObj := persistentObjectList.GetItem(i); wrapper := pObj(PersistentObjectWrapper);
				wrapper.isMarked := FALSE
			END;
			(* mark phase *)
			FOR i := 0 TO persistentObjectList.GetCount()-1 DO
				pObj := persistentObjectList.GetItem(i); wrapper := pObj(PersistentObjectWrapper);
				IF (wrapper.isRoot) THEN (* start from a root persistent object *)
					wrapper.isMarked := TRUE;
					MarkReachableObjects(wrapper.instance)
				END
			END;
			(* detect garbage *)
			NEW(removeList);
			FOR i := 0 TO persistentObjectList.GetCount()-1 DO
				pObj := persistentObjectList.GetItem(i); wrapper := pObj(PersistentObjectWrapper);
				IF (~wrapper.isMarked) THEN
					IF (DEBUG) THEN
						KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
						KernelLog.String("': Garbage collector: Free object with oid "); KernelLog.Int(wrapper.instance.oid, 0); KernelLog.String(" ");
						KernelLog.String(wrapper.descriptor.moduleName^); KernelLog.String("."); KernelLog.String(wrapper.descriptor.objectName^); KernelLog.Ln
					END;
					removeList.Add(wrapper)
				END
			END;
			persistentObjectList.Unlock;
			(* sweep phase *)
			FOR i := 0 TO removeList.GetCount()-1 DO
				pObj := removeList.GetItem(i);
				persistentObjectList.Remove(pObj)
			END;
			UnlockPersistentObjList
		END GarbageCollect;

		PROCEDURE PersistAllObjects; (* store a snapshot of the prevalence system to an XML file *)
		VAR fw: Files.Writer; w: Streams.Writer; newFile: Files.File; newRoot, elem: XML.Element;
			i: LONGINT; pObj: ANY; wrapper: PersistentObjectWrapper; instance: PersistentObject;
			oldDocument: XML.Document; oidCounterString: ARRAY 14 OF CHAR;

			PROCEDURE GetPreviousSnapShotState(oid: LONGINT) : XML.Element;
			VAR file: Files.File; oldRoot: XML.Element; enum: XMLObjects.Enumerator; pOldElem: ANY; oldElem: XML.Element;
				oidValue: Strings.String; oldOid: LONGINT; oldRootName, oldElemName: Strings.String;
			BEGIN (* file # NIL *)
				IF (oldDocument = NIL) THEN
					file := Files.Old(SnapShotFileName^);
					IF (file # NIL) THEN
						oldDocument := GetXMLDocument(file)
					END;
				END;
				IF (oldDocument # NIL) THEN
					oldRoot := oldDocument.GetRoot();
					oldRootName := oldRoot.GetName();
					IF ((oldRoot # NIL) & (oldRootName^ = XMLRootElemName)) THEN
						enum := oldRoot.GetContents();
						WHILE (enum.HasMoreElements()) DO
							pOldElem := enum.GetNext();
							IF (pOldElem IS XML.Element) THEN
								oldElem := pOldElem(XML.Element);
								oldElemName := oldElem.GetName();
								IF (oldElemName^ = XMLInstanceElemName) THEN
									oidValue := oldElem.GetAttributeValue(XMLAttrOidName);
									IF (oidValue # NIL) THEN
										Strings.StrToInt(oidValue^, oldOid);
										IF (oldOid = oid) THEN
											RETURN oldElem
										END
									ELSE
										KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
										KernelLog.String("': In the snapshot file '"); KernelLog.String(SnapShotFileName^);
										KernelLog.String("' is an instance without attribute 'oid'."); KernelLog.Ln
									END
								END
							END
						END
					ELSE
						KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
						KernelLog.String("': In the snapshot file '"); KernelLog.String(SnapShotFileName^);
						KernelLog.String("' must be a root defined as '"); KernelLog.String(XMLRootElemName);
						KernelLog.String("'."); KernelLog.Ln
					END
				ELSE
					KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
					KernelLog.String("': Could not parse the snapshot file '"); KernelLog.String(SnapShotFileName^);
					KernelLog.String("' during taking a snapshot of the system."); KernelLog.Ln
				END;
				(* it could be that the persistent object was not present at the last snapshot time *)
				RETURN NIL
			END GetPreviousSnapShotState;

		BEGIN
			oldDocument := NIL;
			LockSnapShotFile;
			newFile := Files.New(SnapShotFileName^);
			IF (newFile # NIL) THEN
				Strings.IntToStr(oidCounter, oidCounterString);

				NEW(newRoot); newRoot.SetName(XMLRootElemName);
				newRoot.SetAttributeValue(XMLOidCounterAttrName, oidCounterString);

				GarbageCollect;

				persistentObjectList.Lock;
				FOR i := 0 TO persistentObjectList.GetCount()-1 DO
					pObj := persistentObjectList.GetItem(i); wrapper := pObj(PersistentObjectWrapper);
					(* wrapper # NIL & wrapper.instance # NIL  *)
					IF (IsModuleLoaded(wrapper.descriptor.moduleName^)) THEN
						instance := wrapper.instance;
						instance.takingSnapShot := TRUE;
						IF (~instance.inModification) THEN
							INC(wrapper.savingCounter);
							elem := GetSerializedXMLInstance(wrapper);
							instance.takingSnapShot := FALSE;
							newRoot.AddContent(elem)
						ELSE (* Is in transaction, take the previous version if present, could be recovered from log by next recovery *)
							instance.takingSnapShot := FALSE;
							elem := GetPreviousSnapShotState(instance.oid);
							IF (elem # NIL) THEN (* object was already present at the last snapshot time *)
								newRoot.AddContent(elem)
							END
						END
					ELSE (* Snapshot no more possible since module has been freed *)
						KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
						KernelLog.String("': module '"); KernelLog.String(wrapper.descriptor.moduleName^);
						KernelLog.String("' has been freed. Taking snapshot is no further possible, the system uses now only logging.");
						snapShotMgr.alive := FALSE;
						RETURN
					END
				END;
				persistentObjectList.Unlock;

				Files.OpenWriter(fw, newFile, 0); w := fw;
				w.String(XMLProlog); w.Ln;
				newRoot.Write(w, NIL, 0);
				fw.Update;
				Files.Register(newFile);

				IF (DEBUG) THEN
					KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
					KernelLog.String("': Snapshot stored to "); KernelLog.String(SnapShotFileName^); KernelLog.Ln
				END
			ELSE
				KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
				KernelLog.String("': Cannot create or overwrite file '"); KernelLog.String(SnapShotFileName^);
				KernelLog.String("' for storing the snapshot."); KernelLog.Ln
			END;
			UnlockSnapShotFile;
			(* now reduce redundant entries from the log file *)
			CompactLogFile;
		END PersistAllObjects;

		PROCEDURE GetSerializedXMLInstance(wrapper: PersistentObjectWrapper) : XML.Element;
		VAR content: XML.Content; elem: XML.Element; savingCounterString, oidString: ARRAY 14 OF CHAR;
			container: XML.Container; instance: PersistentObject; desc: PersistentObjectDescriptor;
			enum: XMLObjects.Enumerator; pChild: ANY; child: XML.Content;
		BEGIN
			instance := wrapper.instance;
			desc := wrapper.descriptor;

			(* here would be an exception handler fine*)
			content := instance.Externalize(); (* the instance externalization is locked while a transaction is done *)

			Strings.IntToStr(wrapper.savingCounter, savingCounterString);
			Strings.IntToStr(instance.oid, oidString);

			NEW(elem); elem.SetName(XMLInstanceElemName);
			elem.SetAttributeValue(XMLAttrModuleName, desc.moduleName^);
			elem.SetAttributeValue(XMLAttrObjectName, desc.objectName^);
			elem.SetAttributeValue(XMLAttrOidName, oidString);
			elem.SetAttributeValue(XMLAttrSavingCounter, savingCounterString);
			IF (wrapper.isRoot) THEN
				elem.SetAttributeValue(XMLAttrIsRootName, "true")
			END;

			IF ((content # NIL) & (content IS XML.Container) & (~(content IS XML.Element))) THEN (* it is a simple container *)
				container := content(XML.Container);
				enum := container.GetContents();
				WHILE (enum.HasMoreElements()) DO
					pChild := enum.GetNext(); child := pChild(XML.Content);
					elem.AddContent(child)
				END
			ELSIF (content # NIL) THEN
			elem.AddContent(content)
			END;
			RETURN elem
		END GetSerializedXMLInstance;

		PROCEDURE GetXMLInstanceDeletion(wrapper: PersistentObjectWrapper) : XML.Element;
		VAR instance: PersistentObject; desc: PersistentObjectDescriptor; elem: XML.Element;
			savingCounterString, oidString: ARRAY 14 OF CHAR;
		BEGIN
			instance := wrapper.instance; (* instance # NIL *)
			desc := wrapper.descriptor; (* desc # NIL *)

			Strings.IntToStr(wrapper.savingCounter, savingCounterString);
			Strings.IntToStr(instance.oid, oidString);

			NEW(elem); elem.SetName(XMLLogDelInstElemName);
			elem.SetAttributeValue(XMLAttrModuleName, desc.moduleName^);
			elem.SetAttributeValue(XMLAttrObjectName, desc.objectName^);
			elem.SetAttributeValue(XMLAttrOidName, oidString);
			elem.SetAttributeValue(XMLAttrSavingCounter, savingCounterString);
			RETURN elem
		END GetXMLInstanceDeletion;

		PROCEDURE LogXMLElement(elem: XML.Element);
		VAR file: Files.File; fwriter: Files.Writer; writer: Streams.Writer; endPos, endTagLength: LONGINT;
		BEGIN
			LockLoggingFile;
			file := Files.Old(LogFileName^);
			IF (file = NIL) THEN
				file := Files.New(LogFileName^);
				Files.Register(file)
			END;
			IF (file # NIL) THEN
				(* Don't use the XML parser, it's too inefficient.
					 Append the XML serialized state an the end of the xml file *)
				endTagLength := Strings.Length(XMLLogRootElemName)+5; (* LEN("</XMLLogRootElemName>"+CR+LF *)
				IF (file.Length()-endTagLength-Strings.Length(XMLProlog)-2 <= 0) THEN (* empty file or only <log/> in it *)
					Files.OpenWriter(fwriter, file, 0); writer := fwriter;
					writer.String(XMLProlog); writer.Ln;
					writer.String("<"); writer.String(XMLLogRootElemName);
					writer.String(">"); writer.Ln; (* opening tag "<log>" *)
				ELSE
					endPos := file.Length()-endTagLength;
					ASSERT(endPos >= 0, 9999);
					Files.OpenWriter(fwriter, file, endPos); writer := fwriter
				END;
				elem.Write(writer, NIL, 0);

				writer.Ln;
				writer.String("</");
				writer.String(XMLLogRootElemName);
				writer.String(">"); writer.Ln;

				writer.Update
			ELSE
				KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
				KernelLog.String("': Cannot open or create file '"); KernelLog.String(LogFileName^);
				KernelLog.String("'."); KernelLog.Ln;
				UnlockLoggingFile; HALT(9999); (* Cannot commit the transaction, could support "ABORT" at a later time *)
			END;
			UnlockLoggingFile
		END LogXMLElement;

		PROCEDURE Log(obj: PersistentObject);
		VAR elem: XML.Element; wrapper: PersistentObjectWrapper;
		BEGIN
			wrapper := GetRegisteredWrapper(obj);
			IF (wrapper # NIL) THEN
				elem := GetSerializedXMLInstance(wrapper);
				LogXMLElement(elem)
			ELSE
				KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
				KernelLog.String("': The object with oid '"); KernelLog.Int(obj.oid, 0);
				KernelLog.String("' is not stored in the prevalence system and will therefore not be logged."); KernelLog.Ln
			END
		END Log;

		PROCEDURE LogRemovalFromRootSet(wrapper: PersistentObjectWrapper);
		VAR elem: XML.Element;
		BEGIN
			IF (wrapper # NIL) THEN
				elem := GetXMLInstanceDeletion(wrapper);
				LogXMLElement(elem)
			ELSE
				KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
				KernelLog.String("': The object with is not stored in the prevalence system and will therefore not be logged.");
				KernelLog.Ln
			END
		END LogRemovalFromRootSet;

		(* The last oid counter can be restored by the max(oidCounter in the snapshot file, max(oid of all logged object)+1)
		    For all objects which were created before the last snapshot was taken, the oidCounter in the snapshot file is
		    greater the oid for this objects. If an object O was created after the last snapshot was taken and O has been
		    registered in the prevalence system for a time (even if it was later removed) then by looking at the maximum oid
		    occurring in the log file the oidCounter is chosen greater than the oid of O. If an object O was created before the last
		    snapshot was taken and O has never been registered in the prevalence system then O will be destroyed if the module
		    PrevalenceSystem is freed, since each module M using O imports the module PrevalenceSystem. Hence O will not affect
		    the oid uniqueness condition at the next incarnation time for the prevalence system. *)
		PROCEDURE RestoreAllObjects;
		VAR snapShotFile, logFile: Files.File; snapShotDoc, logDoc: XML.Document;
			snapShotRoot, logRoot, elem: XML.Element; enum: XMLObjects.Enumerator; p: ANY;
			moduleName, objectName, oidString, savingCounterString, isRootString: Strings.String;
			oid, savingCounter: LONGINT; isRoot: BOOLEAN;
			snapShotRootName, logRootName, elemName, oidCounterString: Strings.String;
			desc: PersistentObjectDescriptor; objWrapper: PersistentObjectWrapper;

			PROCEDURE CreatePersistentObject;
			VAR persObj: PersistentObject; wrapper: PersistentObjectWrapper;
			BEGIN
				IF (desc # NIL) THEN
					(* persistent object serializations could occur multiple times in log file *)
					IF (GetPersistentObject(oid) = NIL) THEN (* first time that the persistent object occurs *)
						(* Always overwriting savingCounter and isRoot would lead to inconsistent states since there could be
						 * stale informations in the log file *)
						persObj := desc.factory();
						IF (persObj # NIL) THEN
							persObj.oid := oid;
							NEW(wrapper, SELF, persObj, desc);
							wrapper.savingCounter := savingCounter;
							wrapper.isRoot := isRoot;
							persistentObjectList.Add(wrapper);
							persObj.registeredAt := SELF
						ELSE
							KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
							KernelLog.String("': cannot create an instance of the persistent object '");
							KernelLog.String(objectName^); KernelLog.String("' in module '"); KernelLog.String(moduleName^);
							KernelLog.String("'."); KernelLog.Ln;
							HALT(9999)
						END
					END
				ELSE
					KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
					KernelLog.String("': persistent object '"); KernelLog.String(objectName^);
					KernelLog.String("' in module '"); KernelLog.String(moduleName^);
					KernelLog.String("' must be installed because it is stored in the snapshot or log file."); KernelLog.Ln;
					HALT(9999)
				END
			END CreatePersistentObject;

			PROCEDURE RestorePersistentObject;
			VAR pContent: ANY; content: XML.Content; contentEnum: XMLObjects.Enumerator; contentList: TFClasses.List;
				persObj: PersistentObject; container: XML.Container; j: LONGINT;
			BEGIN
				persObj := GetPersistentObject(oid);
				IF (persObj # NIL) THEN
					contentEnum := elem.GetContents();
					NEW(contentList);
					WHILE (contentEnum.HasMoreElements()) DO
						pContent := contentEnum.GetNext();
						contentList.Add(pContent)
					END;
					IF (contentList.GetCount() = 0) THEN
						content := NIL
					ELSIF (contentList.GetCount() = 1) THEN
						pContent := contentList.GetItem(0);
						content := pContent(XML.Content)
					ELSE
						NEW(container);
						FOR j := 0 TO contentList.GetCount()-1 DO
							pContent := contentList.GetItem(j); content := pContent(XML.Content);
							container.AddContent(content)
						END;
						content := container
					END;
					(* here would be an exception handler fine *)
					persObj.Internalize(content);
				ELSE
					KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
					KernelLog.String("': Recovery process: there is no object with oid '"); KernelLog.Int(oid, 0);
					KernelLog.String("' present."); KernelLog.Ln
				END
			END RestorePersistentObject;

			PROCEDURE AllocatePersistentObjects(root: XML.Element);
			VAR contentEnum: XMLObjects.Enumerator;
			BEGIN
				contentEnum := root.GetContents();
				WHILE (contentEnum.HasMoreElements()) DO
					p := contentEnum.GetNext();
					IF (p IS XML.Element) THEN
						elem := p(XML.Element);
						elemName := elem.GetName();
						IF (elemName^ = XMLInstanceElemName) THEN
							 moduleName := elem.GetAttributeValue(XMLAttrModuleName);
							 objectName := elem.GetAttributeValue(XMLAttrObjectName);
							 oidString := elem.GetAttributeValue(XMLAttrOidName);
							 savingCounterString := elem.GetAttributeValue(XMLAttrSavingCounter);
							 isRootString := elem.GetAttributeValue(XMLAttrIsRootName);

							 IF ((moduleName # NIL) & (objectName # NIL) & (oidString # NIL) & (savingCounterString # NIL)) THEN
							 	Strings.StrToInt(oidString^, oid); Strings.StrToInt(savingCounterString^, savingCounter);

							 	IF ((isRootString # NIL) & (isRootString^ = "true")) THEN
							 		isRoot := TRUE
							 	ELSE
							 		isRoot := FALSE
							 	END;

							 	IF (oid >= oidCounter) THEN
							 		oidCounter := oid + 1
							 	END;

							 	desc := FindRegisteredDescriptor(moduleName^, objectName^);
							 	(* savingCounter and isRoot etc. is only set in CreatePersistentObject if the object occurs the first time.
							 	 * Always overwriting this information would lead to inconsistent states since there could be
							 	 * stale informations in the log file. *)
							 	CreatePersistentObject
							 ELSE
								KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
								KernelLog.String("': There are instances with missing attributes in the snapshot or log file.");
								KernelLog.Ln;
								UnlockLoggingFile;
								UnlockSnapShotFile;
								UnlockPersistentObjList;
								HALT(9999)
							 END
						END
					END
				END
			END AllocatePersistentObjects;

		BEGIN
			LockPersistentObjList;
			LockSnapShotFile;
			LockLoggingFile;
			(* two phases: first create all persistent object instances, then invoke the internalization methods.
				 This allows that the persistent can have references to other persistent object instances. *)

			(* first phase: create the persistent object instances. First consider all objects in the snapshot file then
			 * the new objects only reported in the log file. *)
			snapShotFile := Files.Old(SnapShotFileName^);
			IF (snapShotFile # NIL) THEN
				snapShotDoc := GetXMLDocument(snapShotFile);
				IF (snapShotDoc # NIL) THEN
					snapShotRoot := snapShotDoc.GetRoot();
					snapShotRootName := snapShotRoot.GetName();
					IF (snapShotRootName^ = XMLRootElemName) THEN
						oidCounterString := snapShotRoot.GetAttributeValue(XMLOidCounterAttrName);
						IF (oidCounterString # NIL) THEN
							Strings.StrToInt(oidCounterString^, oidCounter);
							AllocatePersistentObjects(snapShotRoot)
						ELSE
							snapShotRoot := NIL;
							KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
							KernelLog.String("': In the snapshot file '"); KernelLog.String(SnapShotFileName^);
							KernelLog.String("' the root '"); KernelLog.String(XMLRootElemName);
							KernelLog.String("' must have an attribute named'"); KernelLog.String(XMLOidCounterAttrName);
							KernelLog.String("'."); KernelLog.Ln
						END
					ELSE
						snapShotRoot := NIL;
						KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
						KernelLog.String("': In the snapshot file '"); KernelLog.String(SnapShotFileName^);
						KernelLog.String("' must be a root defined as '"); KernelLog.String(XMLRootElemName);
						KernelLog.String("'."); KernelLog.Ln
					END
				ELSE (* error message already handled by GetXMLDocument *)
					UnlockLoggingFile;
					UnlockSnapShotFile;
					UnlockPersistentObjList;
					HALT(9999)
				END
			END;
			logFile := Files.Old(LogFileName^);
			IF (logFile # NIL) THEN
				logDoc := GetXMLDocument(logFile);
				IF (logDoc # NIL) THEN
					logRoot := logDoc.GetRoot();
					logRootName := logRoot.GetName();
					IF (logRootName^ = XMLLogRootElemName) THEN
						AllocatePersistentObjects(logRoot)
					ELSE
						logRoot := NIL;
						KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
						KernelLog.String("': In the log file '"); KernelLog.String(LogFileName^);
						KernelLog.String("' must be a root defined as '"); KernelLog.String(XMLLogRootElemName);
						KernelLog.String("'."); KernelLog.Ln
					END
				ELSE (* error message already handled by GetXMLDocument *)
					UnlockLoggingFile;
					UnlockSnapShotFile;
					UnlockPersistentObjList;
					HALT(9999)
				END
			END;

			(* second phase: internalize persistent object state *)
			IF (snapShotRoot # NIL) THEN
				enum := snapShotRoot.GetContents();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext();
					IF (p IS XML.Element) THEN
						elem := p(XML.Element);
						elemName := elem.GetName();
						IF (elemName^ = XMLInstanceElemName) THEN
							oidString := elem.GetAttributeValue(XMLAttrOidName);
							IF (oidString # NIL) THEN
								Strings.StrToInt(oidString^, oid);
								(* the savingCounter and isRoot are consistent, since the object was created by the information
								 * of the snapshot file and savingCounter and isRoot were not overwritten by the log file until now *)
								RestorePersistentObject
							ELSE
								KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
								KernelLog.String("': There are object instances with missing oid in the snapshot file.");
								KernelLog.Ln
							END
						END
					END
				END;
				IF (DEBUG) THEN
					KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
					KernelLog.String("': Recovery from snapshot done."); KernelLog.Ln
				END
			END;
			IF (logRoot # NIL) THEN
				enum := logRoot.GetContents();
				WHILE (enum.HasMoreElements()) DO
					p := enum.GetNext();
					IF (p IS XML.Element) THEN
						elem := p(XML.Element);
						elemName := elem.GetName();
						IF ((elemName^ = XMLInstanceElemName) OR (elemName^ = XMLLogDelInstElemName)) THEN
							oidString := elem.GetAttributeValue(XMLAttrOidName);
							savingCounterString := elem.GetAttributeValue(XMLAttrSavingCounter);


							IF ((oidString # NIL) & (savingCounterString # NIL)) THEN
								Strings.StrToInt(oidString^, oid); Strings.StrToInt(savingCounterString^, savingCounter);
								objWrapper := GetRegisteredWrapperByOid(oid); (* objWrapper # NIL since they were previously created *)

								IF ((objWrapper # NIL) & (elemName^ = XMLInstanceElemName)) THEN
									isRootString := elem.GetAttributeValue(XMLAttrIsRootName);
									IF ((isRootString # NIL) & (isRootString^ = "true")) THEN
										isRoot := TRUE
									ELSE
										isRoot := FALSE
									END;
									IF (savingCounter >= objWrapper.savingCounter) THEN (* only update if newer information *)
										objWrapper.savingCounter := savingCounter;
										objWrapper.isRoot := isRoot;
										RestorePersistentObject
									END
								ELSIF ((objWrapper # NIL)  & (elemName^ = XMLLogDelInstElemName)) THEN
									IF (savingCounter >= objWrapper.savingCounter) THEN (* only update if newer information *)
										objWrapper.isRoot := FALSE
										 (* the object doesn't belong anymore to the root set, and could be removed later by
										  * the garbage collector of the prevalence system *)
									END
								ELSE
									KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
									KernelLog.String("': Recovery phase: Object with oid '"); KernelLog.Int(oid, 0);
									KernelLog.String("' is not present."); KernelLog.Ln
								END
							ELSE
								KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
								KernelLog.String("': There are object instances with missing oid or saving counter in the log file.");
								KernelLog.Ln
							END
						END
					END
				END;
				IF (DEBUG) THEN
					KernelLog.String("Prevalence System '"); KernelLog.String(SystemName^);
					KernelLog.String("': Recovery from log file done."); KernelLog.Ln
				END
			END;
			UnlockLoggingFile;
			UnlockSnapShotFile;
			UnlockPersistentObjList
		END RestoreAllObjects;

		PROCEDURE GetRegisteredWrapperByOid(oid: LONGINT) : PersistentObjectWrapper;
		VAR i: LONGINT; p: ANY; wrapper: PersistentObjectWrapper;
		BEGIN
			persistentObjectList.Lock;
			FOR i := 0 TO persistentObjectList.GetCount()-1 DO
				p := persistentObjectList.GetItem(i); wrapper := p(PersistentObjectWrapper);
				(* wrapper # NIL & wrapper.instance # NIL *)
				IF (wrapper.instance.oid = oid) THEN
					persistentObjectList.Unlock;
					RETURN wrapper
				END
			END;
			persistentObjectList.Unlock;
			RETURN NIL
		END GetRegisteredWrapperByOid;

		PROCEDURE GetRegisteredWrapper(obj: PersistentObject) : PersistentObjectWrapper;
		VAR i: LONGINT; p: ANY; wrapper: PersistentObjectWrapper;
		BEGIN
			IF (obj # NIL) THEN
				persistentObjectList.Lock;
				FOR i := 0 TO persistentObjectList.GetCount()-1 DO
					p := persistentObjectList.GetItem(i); wrapper := p(PersistentObjectWrapper); (* wrapper # NIL *)
					IF (wrapper.instance = obj) THEN
						persistentObjectList.Unlock;
						RETURN wrapper
					END
				END;
				persistentObjectList.Unlock
			END;
			RETURN NIL
		END GetRegisteredWrapper;
	END PrevalenceSystem;

	VAR
		prevSystemList: TFClasses.List; (* List of Prevelence System *)
		standardPrevalenceSystem*: PrevalenceSystem;
		persistentObjectDescs: TFClasses.List; (* List of PersistentObjectDescriptor *)
		snapShotMgr: SnapShotManager; (* singleton *)

		(* error handling mechanism for XML Parser and Scanner *)
		xmlParserErrorMsg: ARRAY 1024 OF CHAR;
		xmlParserErrorOccurred: BOOLEAN;

		lockParsingScanning: BOOLEAN;
		lockPrevSystemList: BOOLEAN;

	PROCEDURE GetPrevalenceSystem*(CONST name: ARRAY OF CHAR) : PrevalenceSystem;
	VAR i: LONGINT; p: ANY; prevSys: PrevalenceSystem;
	BEGIN
		prevSystemList.Lock;
		FOR i := 0 TO prevSystemList.GetCount()-1 DO
			p := prevSystemList.GetItem(i); prevSys := p(PrevalenceSystem);
			IF (prevSys.SystemName^ = name) THEN
				prevSystemList.Unlock;
				RETURN prevSys
			END
		END;
		prevSystemList.Unlock;
		RETURN NIL
	END GetPrevalenceSystem;

	(** operations on the standard prevalence system *)
	(** each persistent object has to be registered in the standard prevalence system to make sure that its descriptor is known.
	 * This does not affect that the object will be collected as garbage if it is not reachable through a root persistent object *)
	PROCEDURE AddPersistentObject*(obj: PersistentObject; desc: PersistentObjectDescriptor);
	BEGIN
		standardPrevalenceSystem.AddPersistentObject(obj, desc)
	END AddPersistentObject;

	(** add object to the root set of the standard prevalence system. This objects must be manually removed from the prevalence system,
	 * All objects reached by a root persistent object are also persistent *)
	PROCEDURE AddPersistentObjectToRootSet*(obj: PersistentObject; desc: PersistentObjectDescriptor);
	BEGIN
		standardPrevalenceSystem.AddPersistentObjectToRootSet(obj, desc)
	END AddPersistentObjectToRootSet;

	(** the object will be marked to be no more belonging to the root set of the standard prevalence system
	 * and all persistent objects only reachable by this object will be removed in the next garbage collection phase *)
	PROCEDURE RemovePersistentRootObject*(obj: PersistentObject);
	BEGIN
		standardPrevalenceSystem.RemovePersistentRootObject(obj)
	END RemovePersistentRootObject;

	PROCEDURE GetPersistentObject*(oid: LONGINT): PersistentObject;
	BEGIN
		RETURN standardPrevalenceSystem.GetPersistentObject(oid)
	END GetPersistentObject;

	PROCEDURE GetDescriptorByObject*(obj: PersistentObject) : PersistentObjectDescriptor;
	BEGIN
		RETURN standardPrevalenceSystem.GetDescriptorByObject(obj)
	END GetDescriptorByObject;

	PROCEDURE FindPersistentObjects*(pred: FilterPredicate) : PersistentObjectList;
	BEGIN
		RETURN standardPrevalenceSystem.FindPersistentObjects(pred)
	END FindPersistentObjects;

	(** end of operations on the standard prevalence system *)

	PROCEDURE LockPrevSystemList;
	BEGIN {EXCLUSIVE}
		AWAIT(~lockPrevSystemList);
		lockPrevSystemList := TRUE
	END LockPrevSystemList;

	PROCEDURE UnlockPrevSystemList;
	BEGIN {EXCLUSIVE}
		lockPrevSystemList := FALSE
	END UnlockPrevSystemList;

	PROCEDURE LockParsingScanning;
	BEGIN {EXCLUSIVE}
		AWAIT(~lockParsingScanning);
		lockParsingScanning := TRUE
	END LockParsingScanning;

	PROCEDURE UnlockParsingScanning;
	BEGIN {EXCLUSIVE}
		lockParsingScanning := FALSE
	END UnlockParsingScanning;

	PROCEDURE ReportXMLParserScannerError(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR); (* Error handler for the XML parser *)
	VAR w: Streams.StringWriter;
	BEGIN
		xmlParserErrorOccurred := TRUE;
		NEW(w, LEN(xmlParserErrorMsg));
		w.String(msg); w.String(" pos "); w.Int(pos, 0);
		w.String("line "); w.Int(line, 0);
		w.String("row "); w.Int(row, 0); w.Ln;
		w.Get(xmlParserErrorMsg)
	END ReportXMLParserScannerError;

	PROCEDURE IsModuleLoaded(CONST modName: ARRAY OF CHAR) : BOOLEAN;
	VAR module: Modules.Module;
	BEGIN
		module := Modules.ModuleByName(modName);
		RETURN (module # NIL)
	END IsModuleLoaded;

	PROCEDURE FindRegisteredDescriptor(CONST moduleName, objectName: ARRAY OF CHAR) : PersistentObjectDescriptor;
	VAR p: ANY; i: LONGINT; desc: PersistentObjectDescriptor;
	BEGIN
		persistentObjectDescs.Lock;
		FOR i := 0 TO persistentObjectDescs.GetCount()-1 DO
			p := persistentObjectDescs.GetItem(i); desc := p(PersistentObjectDescriptor);
			IF ((desc.moduleName^ = moduleName) & (desc.objectName^ = objectName)) THEN
				persistentObjectDescs.Unlock;
				RETURN desc
			END
		END;
		persistentObjectDescs.Unlock;
		RETURN NIL
	END FindRegisteredDescriptor;

	PROCEDURE RegisterDescriptor(desc: PersistentObjectDescriptor);
	VAR pos: LONGINT;
	BEGIN {EXCLUSIVE}
		IF (desc # NIL) THEN
			persistentObjectDescs.Lock;
			pos := persistentObjectDescs.IndexOf(desc);
			persistentObjectDescs.Unlock;
			IF (pos = -1) THEN (* not registered yet *)
				persistentObjectDescs.Add(desc)
			END
		END
	END RegisterDescriptor;

	PROCEDURE ReadRegisteredModules;
	VAR elem, child: XML.Element; enum: XMLObjects.Enumerator; p: ANY; childName, moduleName: Strings.String;
		attr: XML.Attribute;
	BEGIN
		IF (Configuration.config # NIL) THEN
			elem := Configuration.config.GetRoot();
			elem := Configuration.GetNamedElement(elem, "Section", ConfigurationSupperSectionName);
			IF (elem # NIL) THEN
				elem := Configuration.GetNamedElement(elem, "Section", ConfigurationSubSectionName);
				IF (elem # NIL) THEN
					enum := elem.GetContents();
					WHILE (enum.HasMoreElements()) DO
						p := enum.GetNext();
						IF (p IS XML.Element) THEN
							child := p(XML.Element); childName := child.GetName();
							IF (childName^ = "Setting") THEN
								attr := child.GetAttribute("value");
								IF (attr # NIL) THEN
									moduleName := attr.GetValue();
									RegisterModuleByName(moduleName)
								END
							END
						END
					END
				ELSE
					KernelLog.String("Prevalence System: In Configuration.XML under '");
					KernelLog.String(ConfigurationSupperSectionName); KernelLog.String("' is no section '");
					KernelLog.String(ConfigurationSubSectionName); KernelLog.String(" defined."); KernelLog.Ln
				END
			ELSE
				KernelLog.String("Prevalence System: In Configuration.XML is no section '");
				KernelLog.String(ConfigurationSupperSectionName); KernelLog.String("' defined."); KernelLog.Ln
			END
		ELSE
			KernelLog.String("Prevalence System: Cannot open Configuration.XML"); KernelLog.Ln
		END
	END ReadRegisteredModules;

	PROCEDURE RegisterModuleByName(moduleName: Strings.String);
	VAR module: Modules.Module; factory : PersistentObjectDescSetFactory; i, res: LONGINT;
		msg: ARRAY 1024 OF CHAR; desc: PersistentObjectDescriptor;
		descList: PersistentObjectDescSet;
	BEGIN
		(* load the module if not already loaded *)
		module := Modules.ThisModule(moduleName^, res, msg);
		IF ((res = 0) & (module # NIL)) THEN
			GETPROCEDURE(moduleName^, ProcNameGetDescriptors, factory);
			IF (factory # NIL) THEN
				descList := factory();
				IF (descList # NIL) THEN (* register all present descriptors *)
					FOR i := 0 TO descList.GetCount()-1 DO
						desc := descList.GetItem(i);
						RegisterDescriptor(desc)
					END
				ELSE
					KernelLog.String("System pervalence: Wrong result type from procedure '");
					KernelLog.String(ProcNameGetDescriptors); KernelLog.String("' in module '");
					KernelLog.String(moduleName^); KernelLog.String("'"); KernelLog.Ln
				END
			ELSE
				KernelLog.String("System prevalence: Procedure '"); KernelLog.String(ProcNameGetDescriptors);
				KernelLog.String("' in module '"); KernelLog.String(moduleName^); KernelLog.String("' is not present."); KernelLog.Ln
			END
		ELSE
			KernelLog.String("System prevalence: Module '"); KernelLog.String(moduleName^);
			KernelLog.String("' is not present."); KernelLog.Ln;
			KernelLog.String(msg); KernelLog.Ln
		END
	END RegisterModuleByName;

	PROCEDURE Terminator;
	VAR counter: LONGINT;
	BEGIN
		IF (snapShotMgr # NIL) THEN
			snapShotMgr.alive := FALSE;
			snapShotMgr.timer.Wakeup;
			counter := 0;
			WHILE ((~snapShotMgr.terminated) & (counter < TermTimeout)) DO INC(counter) END
				(* busy wait until snapShotMgr has stopped, avoid permanent system blocking by a timeout *)
		END
	END Terminator;

BEGIN
	NEW(persistentObjectDescs); NEW(prevSystemList);
	lockParsingScanning := FALSE;

	(* reconstruct the prevalence systems *)
	ReadRegisteredModules;

	NEW(standardPrevalenceSystem, StandardPrevSystemName, StandardSnapShotFileName, StandardLogFileName);

	NEW(snapShotMgr);
	Modules.InstallTermHandler(Terminator)
END PrevalenceSystem.