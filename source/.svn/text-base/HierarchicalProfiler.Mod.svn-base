MODULE HierarchicalProfiler; (** AUTHOR "staubesv"; PURPOSE "Simple statistical hierarchical profiler"; *)

IMPORT
	SYSTEM, Machine, Streams, Modules, Objects, Kernel, Reflection, Commands, Options, Strings, Errors, HierarchicalProfiler0;

CONST
	Ok* = 0;
	AlreadyRunning* = 5101;
	NotRunning* = 5102;
	NoProfileDataAvailable* = 5103;
	SampleBufferFull* = 5104;
	SampleBufferNotInitialized* = 5105;

	(* 	profile creation parameters
		Note: The profiler always gathers all data necessary for any profile *)
	(* type *)
	Hierarchical* = 0;
	Flat* = 1;
	(* thread / processor information *)
	None* = 0;
	Threads* = 1;
	Processors* = 2;
	ThreadsProcessors* = 3;
	ProcessorsThreads* = 4;

	(* Profiler states *)
	NotRunningNoDataAvailable* = 0;
	NotRunningDataAvailable* = 1;
	Running* = 2;

	DefaultMaxTime = 30;

	MaxUnwindingDepth = 64;

	Invalid = 0;

TYPE

	Name = ARRAY 256 OF CHAR;

	Sample =  ARRAY MaxUnwindingDepth OF ADDRESS;
	Samples = POINTER TO ARRAY OF Sample; (* HUGE!! *)

	SampleInfo = RECORD
		processorID : LONGINT;
		process : Objects.Process;
	END;

	SampleInfos = POINTER TO ARRAY OF SampleInfo;

TYPE

	(** 'Node's are use to represent the hierarchical profile *)
	Node* = OBJECT
	VAR
		parent- : Node;
		child- : Node;
		sibling- : Node;
		count- : LONGINT;
		percent- : REAL;
		nofChildren- : LONGINT; (* number of direct descendants *)
		name- : Name;

		(* for external profile processing *)
		extern* : BOOLEAN;
		marked* : BOOLEAN;

		next : Node; (* for internal purposes, e.g. sorting *)

		PROCEDURE GetCaption*() : Strings.String;
		VAR string : ARRAY 256 OF CHAR; number : ARRAY 16 OF CHAR;
		BEGIN
			string := "[";
			Strings.IntToStr(ENTIER(percent), number); Strings.AppendX(string, number); Strings.AppendX(string, ".");
			Strings.IntToStr(ENTIER(10 * (percent - ENTIER(percent))), number); Strings.AppendX(string, number);
			Strings.AppendX(string, "%, ");
			Strings.IntToStr(count, number); Strings.AppendX(string, number); Strings.AppendX(string, "]: ");
			Strings.AppendX(string, name);
			RETURN Strings.NewString(string);
		END GetCaption;

		PROCEDURE Show(out : Streams.Writer; indent : LONGINT);
		VAR i : LONGINT;
		BEGIN
			ASSERT(out # NIL);
			FOR i := 0 TO indent-1 DO out.Char(" "); END;
			out.String("["); out.Int(ENTIER(percent), 0); out.Char("."); out.Int(ENTIER(10*(percent - ENTIER(percent))), 0); out.String("%, "); out.Int(count, 0); out.String("]: ");
			out.String(name); out.Ln;
			out.Update;
		END Show;

		PROCEDURE &Init*; (* private *)
		BEGIN
			parent := NIL; child := NIL; sibling := NIL;
			count := 0; percent := 0; nofChildren := 0;
			name := "";
			extern := FALSE; marked := TRUE;
			next := NIL;
		END Init;
	END Node;

TYPE

	VisitorProcedure* = PROCEDURE {DELEGATE} (node : Node);

	Profile* = OBJECT
	VAR
		nodes- : Node;

		nofSamples- : LONGINT;
		nofProcessors- : LONGINT;
		nofRunsTooDeep- : LONGINT;
		nofUnwindingFaults- : LONGINT;
		nofSamplesNotStored- : LONGINT;

		pattern : ARRAY 64 OF CHAR;
		minPercent : LONGINT;

		PROCEDURE FindNode(CONST name : Name; list : Node) : Node;
		BEGIN
			WHILE (list # NIL) & (list.name # name) DO list := list.next; END;
			RETURN list;
		END FindNode;

		(** Insert node 'newNode' into 'parent.next' list. If a node with the same name is already present, merge it with the newNode *)
		PROCEDURE MergeNode(newNode, parent: Node);
		VAR node : Node;
		BEGIN
			ASSERT((newNode # NIL) & (parent # NIL));
			node := FindNode(newNode.name, parent.next);
			IF (node = NIL) THEN
				newNode.next := parent.next;
				parent.next := newNode;
			ELSE
				node.count := node.count + newNode.count;
				newNode.next := NIL;
			END;
		END MergeNode;

		PROCEDURE Flatten*(parent: Node);
		VAR
			child : Node;

			PROCEDURE MergeChildren(child : Node);
			BEGIN
				WHILE (child # NIL) DO
					MergeNode(child, parent);
					MergeChildren(child.child);
					child := child.sibling;
				END;
			END MergeChildren;

		BEGIN {EXCLUSIVE}
			ASSERT(parent # NIL);
			(* Merge all children of 'parent' into the parent.next list *)
			parent.next := NIL;
			MergeChildren(parent.child);
			(* adjust sibling references *)
			parent.child := parent.next;
			parent.next := NIL;
			child := parent.child;
			WHILE (child # NIL) DO
				child.sibling := child.next;
				child := child.next;
			END;
			(* clear 'next' references *)
			parent.nofChildren := 0;
			child := parent.child;
			WHILE (child # NIL) DO
				child.parent := parent;
				INC(parent.nofChildren);
				child.child := NIL;
				child.nofChildren := 0;
				child.next := NIL;
				child := child.sibling;
			END;
			(* sort children *)
			PostProcessProfile(SELF);
		END Flatten;

		PROCEDURE VisitorClearMark(node : Node);
		BEGIN
			ASSERT(node # NIL);
			node.marked := FALSE;
		END VisitorClearMark;

		PROCEDURE Mark*(CONST pattern : ARRAY OF CHAR; minPercent : LONGINT);
		BEGIN {EXCLUSIVE}
			COPY(pattern, SELF.pattern);
			SELF.minPercent := minPercent;
			VisitNodes(nodes, VisitorClearMark);
			VisitNodes(nodes, VisitorSetMark);
		END Mark;

		PROCEDURE VisitorSetMark(node : Node);
		VAR parent : Node;
		BEGIN
			ASSERT(node # NIL);
			IF Strings.Match(pattern, node.name) & (node.percent >= minPercent) THEN (* mark leaf node and all its parents *)
				node.marked := TRUE;
				parent := node.parent;
				WHILE (parent # NIL) & (parent.marked = FALSE) DO
					parent.marked := TRUE;
					parent := parent.parent;
				END;
			END;
		END VisitorSetMark;

		PROCEDURE VisitNodes(node : Node; visitorProc : VisitorProcedure);
		BEGIN
			ASSERT(visitorProc # NIL);
			WHILE (node # NIL) DO
				VisitNodes(node.child, visitorProc);
				visitorProc(node);
				node := node.sibling;
			END;
		END VisitNodes;

		PROCEDURE Visit*(visitorProc : VisitorProcedure);
		BEGIN {EXCLUSIVE}
			VisitNodes(nodes, visitorProc);
		END Visit;

		PROCEDURE &Init*;
		BEGIN
			nodes := NIL;
			nofSamples := 0;
			nofProcessors := 0;
			nofRunsTooDeep := 0;
			nofUnwindingFaults := 0;
			nofSamplesNotStored := 0;
			pattern := "*";
			minPercent := 0;
		END Init;

	END Profile;

VAR
	(* sample data *)
	samples : Samples;
	sampleInfos : SampleInfos;

	maxNofSamples : LONGINT;

	(* statistics *)
	nofRunsTooDeep : LONGINT;
	nofUnwindingFaults : LONGINT;
	nofSamplesNotStored : LONGINT;
	nofSamples : LONGINT;

	(* current index into 'samples' array *)
	currentIndex : LONGINT;
	locked : BOOLEAN; (* protect 'currentIndex' *)

	(* Profiler state *)
	state : LONGINT;

(* Find a node with name 'name' within the children of 'parent'. Returns NIL if no such node found *)
PROCEDURE FindChildNode(CONST name : Name; parent : Node) : Node;
VAR child : Node;
BEGIN
	ASSERT(parent # NIL);
	child := parent.child;
	WHILE (child # NIL) & (child.name # name) DO child := child.sibling; END;
	RETURN child;
END FindChildNode;

(*	Add node for procedure 'procedurename' to the children of 'parent'. If there is already a node
	for the procedure, just increment the 'Node.count' field *)
PROCEDURE MergeChildNode(CONST procedureName :  ARRAY OF CHAR; parent : Node) : Node;
VAR child, temp : Node; name : Name;
BEGIN
	ASSERT((procedureName # "") & (parent # NIL));
	COPY(procedureName, name);
	child := FindChildNode(name, parent);
	IF (child # NIL) THEN (* merge *)
		INC(child.count);
	ELSE (* create and insert new child *)
		NEW(child);
		child.name := name;
		child.count := 1;
		child.parent := parent;
		INC(parent.nofChildren);
		IF (parent.child = NIL) THEN
			parent.child := child;
		ELSE
			temp := parent.child;
			WHILE (temp.sibling # NIL) DO temp := temp.sibling; END;
			temp.sibling := child;
		END;
	END;
	ASSERT(child # NIL);
	RETURN child;
END MergeChildNode;

(* Add 'sample' to 'profile' *)
PROCEDURE AddSample(profile : Node; type, info : LONGINT; CONST sampleInfo : SampleInfo; CONST sample : Sample);
VAR node : Node; module : Modules.Module; pc,startpc : ADDRESS; nodeName, name : Name; i : LONGINT;

	PROCEDURE GenerateNodeName(module : Modules.Module; CONST procedureName : ARRAY OF CHAR) : Name;
	VAR name : Name;
	BEGIN
		IF (module # NIL) THEN COPY(module.name, name); ELSE name := "Unknown"; END;
		Strings.AppendX(name, ".");
		Strings.AppendX(name, procedureName);
		RETURN name;
	END GenerateNodeName;

	PROCEDURE GenerateProcessorName(processorID : LONGINT) : Name;
	VAR name : Name; nbr : ARRAY 16 OF CHAR;
	BEGIN
		name := "Processor P";
		Strings.IntToStr(processorID, nbr); Strings.AppendX(name, nbr);
		RETURN name;
	END GenerateProcessorName;

	PROCEDURE GenerateProcessName(process : Objects.Process) : Name;
	VAR
		name : Name; nbr : ARRAY 16 OF CHAR;
		module : Modules.Module; typeDescriptor : Modules.TypeDesc;
		adr : ADDRESS;
	BEGIN
		IF (process # NIL) THEN
			name := "Thread ID=";
			Strings.IntToStr(process.id, nbr); Strings.AppendX(name, nbr);
			Strings.AppendX(name, " [");
			IF (process.obj # NIL) THEN
				SYSTEM.GET(SYSTEM.VAL(ADDRESS, process.obj)-SIZEOF(ADDRESS), adr);
				Modules.ThisTypeByAdr(adr, module, typeDescriptor);
				IF (module # NIL) THEN
					Strings.AppendX(name, module.name); Strings.AppendX(name, ".");
					IF (typeDescriptor # NIL) & (typeDescriptor.name # "") THEN
						Strings.AppendX(name, typeDescriptor.name);
					ELSE
						Strings.AppendX(name, "UnknownType");
					END;
				ELSE
					Strings.AppendX(name, "UnknownModule");
				END;
			ELSE
				Strings.AppendX(name, "Unknown");
			END;
			Strings.AppendX(name, "]");
		ELSE
			name := "Thread=NIL";
		END;
		RETURN name;
	END GenerateProcessName;

BEGIN
	node := profile;
	CASE info OF
		|None: (* skip *)
		|Threads:
			node := MergeChildNode(GenerateProcessName(sampleInfo.process) , node);
		|Processors:
			node := MergeChildNode(GenerateProcessorName(sampleInfo.processorID) , node);
		|ThreadsProcessors:
			node := MergeChildNode(GenerateProcessName(sampleInfo.process) , node);
			node := MergeChildNode(GenerateProcessorName(sampleInfo.processorID) , node);
		|ProcessorsThreads:
			node := MergeChildNode(GenerateProcessorName(sampleInfo.processorID) , node);
			node := MergeChildNode(GenerateProcessName(sampleInfo.process) , node);
	ELSE
		(* ignore *)
	END;
	IF (type = Hierarchical) THEN
		i := MaxUnwindingDepth-1;
		WHILE (i >= 1) & (sample[i] = Invalid) DO DEC(i); END;

		WHILE (i >= 0) DO
			(* get procedure name *)
			pc := sample[i];
			module := Modules.ThisModuleByAdr(pc);
			Reflection.GetProcedureName(pc, name, startpc);
			nodeName := GenerateNodeName(module, name);
			node := MergeChildNode(nodeName, node);
			DEC(i);
		END;
	ELSE
		IF (sample[0] # Invalid) THEN
			pc := sample[0];
			module := Modules.ThisModuleByAdr(pc);
			Reflection.GetProcedureName(pc, name,startpc);
			nodeName := GenerateNodeName(module, name);
			node := MergeChildNode(nodeName, node);
		END;
	END;
END AddSample;

PROCEDURE HandleTimer(id: LONGINT; process : Objects.Process;  pc, bp, lowAdr, highAdr : ADDRESS);
VAR index, depth : LONGINT;
BEGIN
	(* acquire lock that protects currentIndex *)
	WHILE Machine.AtomicTestSet(locked) DO Machine.SpinHint; (* busy wait *) END;
	index := currentIndex;
	INC(currentIndex);
	locked := FALSE; (* release lock *)

	IF (index < maxNofSamples) THEN
		Machine.AtomicInc(nofSamples);
	ELSE
		Machine.AtomicInc(nofSamplesNotStored);
		RETURN;
	END;

	sampleInfos[index].processorID := id;
	sampleInfos[index].process := process;

	(* unwind stack *)
	samples[index][0] := pc;
	depth := 1;
	WHILE (bp # 0) & (lowAdr <= bp) & (bp < highAdr) (* Machine.Less(bp, highAdr)*)  & (depth < MaxUnwindingDepth) DO
		SYSTEM.GET(bp + SIZEOF(ADDRESS), pc);
		SYSTEM.GET(bp, bp);
		samples[index][depth] := pc;
		INC(depth);
	END;
	IF (bp # 0) & ((bp < lowAdr) OR (bp > highAdr)) THEN
		InvalidateSample(samples[index]);
		Machine.AtomicInc(nofUnwindingFaults);
	END;
	IF (depth >= MaxUnwindingDepth) THEN (* run not valid *)
		InvalidateSample(samples[index]);
		Machine.AtomicInc(nofRunsTooDeep);
	END;
END HandleTimer;

PROCEDURE InvalidateSample(VAR sample : Sample);
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO MaxUnwindingDepth-1 DO
		sample[i] := Invalid;
	END;
END InvalidateSample;

(* Sort children of node 'parent' using insertion sort *)
PROCEDURE SortChildren(parent : Node);
VAR temp, sortedNodes : Node;

	PROCEDURE InsertSorted(node : Node; VAR list : Node);
	VAR temp : Node;
	BEGIN
		ASSERT(node # NIL);
		IF (list = NIL) OR (node.count >= list.count) THEN
			node.next := list;
			list := node;
		ELSE
			temp := list;
			WHILE (temp.next # NIL) & (temp.next.count >= node.count) DO temp := temp.next; END;
			node.next := temp.next;
			temp.next := node;
		END;
	END InsertSorted;

BEGIN
	IF (parent # NIL) & (parent.child # NIL) & (parent.child.sibling # NIL) THEN
		temp := parent.child;
		WHILE (temp # NIL) DO
			InsertSorted(temp, sortedNodes);
			temp := temp.sibling;
		END;
		parent.child := sortedNodes;
		temp := sortedNodes;
		WHILE (temp # NIL) DO
			temp.sibling := temp.next;
			temp := temp.next;
		END;
	END;
END SortChildren;

PROCEDURE PostProcessNode(profile : Profile; node : Node);
BEGIN
	WHILE (node # NIL) DO
		(* calculate percentages *)
		node.extern := FALSE;
		node.percent := 100 * (node.count / profile.nofSamples);
		SortChildren(node);
		PostProcessNode(profile, node.child);
		node := node.sibling;
	END;
END PostProcessNode;

PROCEDURE PostProcessProfile(profile : Profile);
BEGIN
	ASSERT(profile # NIL);
	PostProcessNode(profile, profile.nodes);
END PostProcessProfile;

PROCEDURE CreateProfile(type : LONGINT; info : LONGINT) : Profile;
VAR profile : Profile; index : LONGINT;
BEGIN (* {Caller holds module lock} *)
	ASSERT(samples # NIL);
	NEW(profile);
	profile.nofSamples := nofSamples;
	profile.nofProcessors := Machine.NumberOfProcessors();
	profile.nofRunsTooDeep := nofRunsTooDeep;
	profile.nofUnwindingFaults := nofUnwindingFaults;
	profile.nofSamplesNotStored := nofSamplesNotStored;
	NEW(profile.nodes); profile.nodes.count := nofSamples;
	profile.nodes.name := "Profile";
	FOR index := 0 TO nofSamples-1 DO
		AddSample(profile.nodes, type, info, sampleInfos[index], samples[index]);
	END;
	PostProcessProfile(profile);
	RETURN profile;
END CreateProfile;

(** Returns the size of the sampling buffer in bytes for a given maximum sampling time in seconds *)
PROCEDURE GetBufferSize*(time : LONGINT) : LONGINT;
BEGIN
	RETURN time * Kernel.Second * Machine.NumberOfProcessors() * MaxUnwindingDepth * SIZEOF(ADDRESS);
END GetBufferSize;

(**	Generate hierarchical profile of the last profiler run's data. Returns NIL if no data available *)
PROCEDURE GetProfile*(type, info : LONGINT; VAR profile : Profile; VAR res : LONGINT);
BEGIN {EXCLUSIVE}
	profile := NIL;
	IF (state # Running) THEN
		IF (samples # NIL) THEN
			profile := CreateProfile(type, info);
			res := Ok;
		ELSE
			res := NoProfileDataAvailable;
		END;
	ELSE
		res := AlreadyRunning;
	END;
END GetProfile;

(** Start profiling. If the profiler is already running, it is stopped and the sample data is discarded before re-starting it *)
PROCEDURE Start*(context : Commands.Context); (** [options] ~ *)
VAR options : Options.Options; unit : ARRAY 4 OF CHAR; maxTime, bufferSize, res : LONGINT;
BEGIN
	NEW(options);
	options.Add("t", "time", Options.Integer); (* in seconds *)
	IF options.Parse(context.arg, context.error) THEN
		IF ~options.GetInteger("time", maxTime) THEN maxTime := DefaultMaxTime; END;
		IF (maxTime > 0) THEN
			StartProfiling(maxTime, res);
			IF (res = Ok) THEN
				context.out.String("Profiler started. MaxTime: "); context.out.Int(maxTime, 0);
				context.out.String(" seconds, MaxDepth: "); context.out.Int(MaxUnwindingDepth, 0);
				context.out.String(" frames [");
				unit := "B";
				bufferSize := GetBufferSize(maxTime);
				IF (bufferSize DIV 1024 > 10) THEN bufferSize := bufferSize DIV 1024; unit := "KB"; END;
				IF (bufferSize DIV 1024 > 10000) THEN bufferSize := bufferSize DIV 1024; unit := "MB"; END;
				context.out.Int(bufferSize, 0); context.out.String(" "); context.out.String(unit);
				context.out.String(" buffer]");
			ELSE
				Errors.ToStream(res, context.out)
			END;
		ELSE
			context.out.String("Parameter error: time must be >= 1");
		END;
		context.out.Ln;
	END;
END Start;

(** Start profiling. If the profiler is already running, it is stopped and the sample data is discarded before re-starting it *)
PROCEDURE StartProfiling*(maxTime : LONGINT; VAR res : LONGINT);
BEGIN {EXCLUSIVE}
	ASSERT(maxTime > 0);
	IF (state # Running) THEN
		currentIndex := 0;
		nofSamples := 0;
		nofRunsTooDeep := 0;
		nofUnwindingFaults := 0;
		nofSamplesNotStored := 0;
		maxNofSamples := maxTime * Kernel.Second * Machine.NumberOfProcessors();
		NEW(samples, maxNofSamples);
		NEW(sampleInfos, maxNofSamples);
		HierarchicalProfiler0.Enable(HandleTimer);
		state := Running;
		res := Ok;
	ELSE
		res := AlreadyRunning;
	END;
END StartProfiling;

(** Stop profiling. The profile data is not discarded. It can be retrieved using the procedure 'GetProfile' *)
PROCEDURE Stop*(context : Commands.Context);
VAR res : LONGINT;
BEGIN
	StopProfiling(res);
	IF (res = Ok) THEN
		context.out.String("Profiler stopped, "); context.out.Int(nofSamples, 0);
		context.out.String(" samples");
	ELSE
		Errors.ToStream(res, context.out);
	END;
	context.out.Ln;
END Stop;

(** Stop profiling. The profile data is not discarded. It can be retrieved using the procedure 'GetProfile' *)
PROCEDURE StopProfiling*(VAR res : LONGINT);
BEGIN {EXCLUSIVE}
	IF (state = Running) THEN
		HierarchicalProfiler0.Disable;
		state := NotRunningDataAvailable;
		res := Ok;
	ELSE
		res := NotRunning;
	END;
END StopProfiling;

PROCEDURE Continue*(context : Commands.Context); (** ~ *)
VAR res : LONGINT;
BEGIN
	ContinueProfiling(res);
	IF (res = Ok) THEN
		context.out.String("Continue profiling...");
	ELSE
		Errors.ToStream(res, context.out);
	END;
	context.out.Ln;
END Continue;

PROCEDURE ContinueProfiling*(VAR res : LONGINT);
BEGIN {EXCLUSIVE}
	IF (state # Running) THEN
		IF (samples # NIL) THEN
			IF (nofSamples < maxNofSamples) THEN
				HierarchicalProfiler0.Enable(HandleTimer);
				state := Running;
				res := Ok;
			ELSE res := SampleBufferFull;
			END;
		ELSE res := SampleBufferNotInitialized;
		END;
	ELSE res := AlreadyRunning;
	END;
END ContinueProfiling;

(** Returns TRUE if the profiler is currently running, FALSE otherwise *)
PROCEDURE GetState*(VAR currentSamples, maxSamples : LONGINT) : LONGINT;
BEGIN {EXCLUSIVE}
	IF (state = Running) THEN
		currentSamples := currentIndex;
		maxSamples := maxNofSamples;
	END;
	RETURN state;
END GetState;

(**	Show the profile *)
PROCEDURE Show*(context : Commands.Context);
VAR profile : Profile; indent : LONGINT;

	PROCEDURE ShowNodes(parent : Node; indent : LONGINT; out : Streams.Writer);
	BEGIN
		WHILE (parent # NIL) DO
			parent.Show(out, indent);
			ShowNodes(parent.child, indent +4, out);
			parent := parent.sibling;
		END;
	END ShowNodes;

BEGIN {EXCLUSIVE}
	IF (state # Running) THEN
		IF (samples # NIL) THEN
			profile := CreateProfile(Hierarchical, None);
			indent := 0;
			ShowNodes(profile.nodes, 0, context.out);
		ELSE
			context.out.String("No profile data available!");
		END;
	ELSE
		context.out.String("Profiler is running!");
	END;
	context.out.Ln;
END Show;

PROCEDURE Cleanup;
VAR ignore : LONGINT;
BEGIN
	StopProfiling(ignore);
END Cleanup;

BEGIN
	locked := FALSE;
	state := NotRunningNoDataAvailable;
	Modules.InstallTermHandler(Cleanup);
END HierarchicalProfiler.

HierarchicalProfiler.Start ~

HierarchicalProfiler.Stop ~

HierarchicalProfiler.Show ~

SystemTools.Free HierarchicalProfiler ~