(* Runtime support for activities *)
(* Copyright (C) Florian Negele *)

(** The module provides the runtime support for activities associated with active objects. *)
(** It implements a basic task scheduler that distributes the work of concurrent activities to logical processors. *)
(** In addition, it also provides a framework for implementing synchronisation primitives. *)
MODULE Activities;

IMPORT SYSTEM, BaseTypes, Counters, CPU, Processors, Queues, Timer;

(** Represents one of four different priorities of an activity. *)
TYPE Priority* = SIZE;

CONST SafeStackSize = 512 * SIZE OF ADDRESS;
CONST InitialStackSize = CPU.StackSize;
CONST MaximumStackSize* = 1024 * InitialStackSize;

CONST (** Indicates the lowest priority used for idle processors. *) IdlePriority* = 0;
CONST (** Indicates the default priority of new activities. *) DefaultPriority* = 1;
CONST (** Indicates a higher priority than the default. *) HighPriority* = 2;
CONST (** Indicates the highest of all priorities. *) RealtimePriority* = 3;

CONST LowestPriority = IdlePriority; HighestPriority = RealtimePriority;
CONST Priorities = HighestPriority - LowestPriority + 1;

(** Represents a procedure that is called after the execution of an activity has been suspended by the {{{[[Activities.SwitchTo]]}}} procedure. *)
TYPE SwitchFinalizer* = PROCEDURE (previous {UNTRACED}: Activity; value: ADDRESS);

(* Represents the stack of an activity. *)
TYPE Stack = POINTER {DISPOSABLE} TO ARRAY OF CHAR;
TYPE StackRecord = POINTER {UNSAFE} TO RECORD
	prev {UNTRACED}, next {UNTRACED}: Stack;
END;

(** Represents the handler identifying activities that are currently either running or suspended. *)
TYPE Activity* = OBJECT {DISPOSABLE} (Queues.Item)

	VAR processor {UNTRACED}: POINTER {UNSAFE} TO Processor;
	VAR firstStack {UNTRACED}: Stack;
	VAR stackLimit: ADDRESS;
	VAR quantum := CPU.Quantum: LONGWORD;
	VAR priority: Priority;
	VAR finalizer := NIL: SwitchFinalizer;
	VAR previous: Activity; argument: ADDRESS;
	VAR framePointer {UNTRACED}: BaseTypes.StackFrame;
	VAR procedure: PROCEDURE;
	VAR object-: BaseTypes.Object;
	VAR bound := FALSE: BOOLEAN;
	VAR startTime-: Timer.Counter;
	VAR time- := 0: HUGEINT;
	VAR stack {UNTRACED}: Stack;

	PROCEDURE &InitializeActivity (procedure: PROCEDURE; priority: Priority);
	VAR stackRecord {UNTRACED}: StackRecord; StackFrameDescriptor {UNTRACED} EXTERN "BaseTypes.StackFrame": BaseTypes.Descriptor;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		ASSERT (priority < Priorities);
		ASSERT (InitialStackSize > SafeStackSize);
		NEW (stack, InitialStackSize);
		ASSERT (stack # NIL);
		firstStack := stack;
		stackRecord := ADDRESS OF stack[0];
		stackRecord.next := NIL;
		stackRecord.prev := NIL;
		stackLimit := ADDRESS OF stack[SafeStackSize+3* SIZE OF ADDRESS]; SELF.priority := priority;
		framePointer := ADDRESS OF stack[InitialStackSize - 4 * SIZE OF ADDRESS - CPU.StackDisplacement];
		framePointer.caller := Start;
		framePointer.previous := NIL;
		framePointer.descriptor := ADDRESS OF StackFrameDescriptor;
		SELF.procedure := procedure;
	END InitializeActivity;

	PROCEDURE ~Finalize;
	VAR stackFrame {UNTRACED}: BaseTypes.StackFrame; currentActivity {UNTRACED}: Activity; stack{UNTRACED}, next{UNTRACED}: Stack; stackRecord{UNTRACED}: StackRecord;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		stackFrame := framePointer;
		currentActivity := SYSTEM.GetActivity ()(Activity); SYSTEM.SetActivity (SELF);
		WHILE stackFrame # NIL DO stackFrame.Reset; stackFrame := stackFrame.previous END;
		SYSTEM.SetActivity (currentActivity);
		stack := firstStack;
		REPEAT
			stackRecord := ADDRESS OF stack[0];
			next := stackRecord.next;
			DISPOSE (stack);
			stack := next;
		UNTIL stack = NIL;
		Finalize^;
	END Finalize;

END Activity;

(* Represents a handler for an activity that is associated with an active object. *)
TYPE Process = OBJECT {DISPOSABLE} (Activity)

	PROCEDURE &InitializeProcess (procedure: PROCEDURE; priority: Priority; object: BaseTypes.Object);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		InitializeActivity (procedure, priority);
		ASSERT (object # NIL);
		ASSERT (object.action # NIL);
		SELF.object := object;
		object.action.activity := SELF;
	END InitializeProcess;

	PROCEDURE Unlink;
	BEGIN {UNCOOPERATIVE, UNCHECKED} object := NIL;
	END Unlink;

	PROCEDURE ~Finalize;
	VAR item: Queues.Item;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		IF object # NIL THEN
			object.action.activity := NIL;
			IF Queues.Dequeue (item, object.action.waitingQueue) THEN Resume (item(Activity)) END;
			Unlink;
		END;
		Finalize^;
	END Finalize;

END Process;

(* Stores information per processor. *)
TYPE Processor = RECORD
	assigning := FALSE: BOOLEAN;
	originalFramePointer: ADDRESS;
	readyQueue: ARRAY Priorities OF Queues.AlignedQueue;
	runningActivity: Activity;
	index: SIZE;
	dummy {ALIGNED (CPU.CacheLineSize)} : RECORD END;
END;

VAR processors: ARRAY Processors.Maximum OF Processor;
VAR readyQueue: ARRAY Priorities OF Queues.AlignedQueue;
VAR working, physicalProcessors, virtualProcessors: Counters.AlignedCounter;

(** Stores an atomic counter indicating the number of activities that are awaiting interrupts to occur. *)
(** The scheduler stops its execution if all processors are idle, unless there are activities waiting for interrupts. *)
VAR awaiting*: Counters.AlignedCounter;

PROCEDURE GetProcessTime-(): HUGEINT;
VAR activity: Activity; diff: Timer.Counter;
BEGIN{UNCOOPERATIVE, UNCHECKED}
	activity := SYSTEM.GetActivity ()(Activity);
	diff := Timer.GetCounter()-activity.startTime;
	RETURN activity.time + diff;
END GetProcessTime;

(** Returns the handler of the current activity executing this procedure call. *)
PROCEDURE GetCurrentActivity- (): {UNTRACED} Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED} RETURN SYSTEM.GetActivity ()(Activity);
END GetCurrentActivity;

(** Returns the unique index of the processor executing this procedure call. *)
PROCEDURE GetCurrentProcessorIndex- (): SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED} IF SYSTEM.GetActivity () # NIL THEN RETURN SYSTEM.GetActivity ()(Activity).processor.index ELSE RETURN 0 END;
END GetCurrentProcessorIndex;

(** Sets the priority of the current activity calling this procedure and returns the previous value. *)
PROCEDURE SetCurrentPriority- (priority: Priority): Priority;
VAR currentActivity {UNTRACED}: Activity; previousPriority: Priority;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (priority < Priorities);
	currentActivity := SYSTEM.GetActivity ()(Activity);
	previousPriority := currentActivity.priority;
	currentActivity.priority := priority;
	RETURN previousPriority;
END SetCurrentPriority;

(** Binds the calling activity to the currently executing processor. *)
PROCEDURE BindToCurrentProcessor-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	SYSTEM.GetActivity ()(Activity).bound := TRUE;
END BindToCurrentProcessor;

(** Returns whether there is an activity that is ready to run and has at least the specified priority. *)
PROCEDURE Select- (VAR activity: Activity; minimum: Priority): BOOLEAN;
VAR processor {UNTRACED}: POINTER {UNSAFE} TO Processor;
VAR priority := HighestPriority + 1: Priority; item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	processor := SYSTEM.GetActivity ()(Activity).processor;
	REPEAT
		DEC (priority);
		IF Queues.Dequeue (item, processor.readyQueue[priority]) THEN
			activity := item(Activity); RETURN TRUE;
		ELSIF Queues.Dequeue (item, readyQueue[priority]) THEN
			activity := item(Activity);
			IF activity.bound & (activity.processor # processor) THEN
				Enqueue (activity, ADDRESS OF activity.processor.readyQueue[activity.priority]);
			ELSE
				RETURN TRUE;
			END;
		END;
	UNTIL priority = minimum;
	RETURN FALSE;
END Select;

(** Performs a cooperative task switch by suspending the execution of the current activity and resuming the execution of any other activity that is ready to continue. *)
(** This procedure is called by the compiler whenever it detects that the time quantum of the current activity has expired. *)
PROCEDURE Switch-;
VAR currentActivity {UNTRACED}, nextActivity: Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	currentActivity := SYSTEM.GetActivity ()(Activity);
	IF Select (nextActivity, currentActivity.priority) THEN
		SwitchTo (nextActivity, Enqueue, ADDRESS OF readyQueue[currentActivity.priority]);
		FinalizeSwitch;
	ELSE
		currentActivity.quantum := CPU.Quantum;
	END;
END Switch;

(* Switch finalizer that enqueues the previous activity to the specified ready queue. *)
PROCEDURE Enqueue (previous {UNTRACED}: Activity; queue {UNTRACED}: POINTER {UNSAFE} TO Queues.Queue);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Queues.Enqueue (previous, queue^);
	IF ADDRESS OF queue^ = ADDRESS OF readyQueue[IdlePriority] THEN RETURN END;
	IF Counters.Read (working) < Processors.count THEN Processors.ResumeAllProcessors END;
END Enqueue;

(** Resumes the execution of an activity that was suspended by a call to the {{{[[Activities.SwitchTo]]}}} procedure beforehand. *)
PROCEDURE Resume- (activity: Activity);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (activity # NIL);
	Enqueue (activity, ADDRESS OF readyQueue[activity.priority])
END Resume;

(** Performs a synchronous task switch. *)
(** The resumed activity continues its execution by first calling the specified finalizer procedure with the given argument. *)
(** Each invocation of this procedure must be directly followed by a call to the {{{[[Activities.FinalizeSwitch]]}}} procedure. *)
PROCEDURE SwitchTo- (VAR activity: Activity; finalizer: SwitchFinalizer; argument: ADDRESS);
VAR currentActivity {UNTRACED}, nextActivity {UNTRACED}: Activity; diff: Timer.Counter;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	currentActivity := SYSTEM.GetActivity ()(Activity);
	currentActivity.framePointer := SYSTEM.GetFramePointer ();
	currentActivity.quantum := CPU.Quantum;
	diff := Timer.GetCounter() - currentActivity.startTime;
	currentActivity.time := currentActivity.time + diff;
	nextActivity := activity;
	nextActivity.processor := currentActivity.processor;
	nextActivity.finalizer := finalizer;
	nextActivity.argument := argument;
	nextActivity.previous := currentActivity;
	nextActivity.processor.runningActivity := nextActivity;
	nextActivity.startTime := Timer.GetCounter();
	activity := NIL;
	SYSTEM.SetActivity (nextActivity);
	SYSTEM.SetFramePointer (nextActivity.framePointer);
END SwitchTo;

(** Finalizes a task switch performed by calling the switch finalizer of the previously suspended activity. *)
(** This procedure must be called after each invocation of the {{{[[Activities.SwitchTo]]}}} procedure. *)
PROCEDURE FinalizeSwitch-;
VAR currentActivity {UNTRACED}: Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	currentActivity := SYSTEM.GetActivity ()(Activity);
	IF currentActivity.finalizer # NIL THEN currentActivity.finalizer (currentActivity.previous, currentActivity.argument) END;
	currentActivity.finalizer := NIL; currentActivity.previous := NIL;
END FinalizeSwitch;

(* Entry point for new activities. *)
PROCEDURE Start;
VAR currentActivity {UNTRACED}: Activity;
VAR procedure {UNTRACED}: POINTER {UNSAFE} TO RECORD body: PROCEDURE (object {UNTRACED}: OBJECT) END;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FinalizeSwitch;
	currentActivity := SYSTEM.GetActivity ()(Activity);
	procedure := ADDRESS OF currentActivity.procedure;
	procedure.body (currentActivity.object);
	TerminateCurrentActivity;
END Start;

(** This procedure is called by the compiler for each {{{NEW}}} statement that creates an active object. *)
(** It associates an active object with a new activity that begins its execution with the specified body procedure. *)
PROCEDURE Create- (body: PROCEDURE; priority: Priority; object {UNTRACED}: BaseTypes.Object);
VAR activity: Process;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF priority = IdlePriority THEN priority := SYSTEM.GetActivity ()(Activity).priority END;
	NEW (activity, body, priority, object);
	ASSERT (activity # NIL);
	Resume (activity);
END Create;

(** Creates an activity that pretends to be executed on a distinct processor. *)
PROCEDURE CreateVirtualProcessor- (): {UNTRACED} Activity;
VAR activity {UNTRACED}: Activity; index: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	NEW (activity, NIL, DefaultPriority);
	ASSERT (activity # NIL);
	index := Counters.Increment (virtualProcessors, 1) + Processors.count;
	ASSERT (index < Processors.Maximum);
	activity.processor := ADDRESS OF processors[index];
	activity.processor.index := index;
	activity.bound := TRUE;
	RETURN activity;
END CreateVirtualProcessor;

(** Temporarily exchanges the currently running activity with a virtual processor in order to call the specified procedure in a different context. *)
PROCEDURE CallVirtual- (procedure: PROCEDURE (value: ADDRESS); value: ADDRESS; processor {UNTRACED}: Activity);
VAR currentActivity {UNTRACED}: Activity; stackPointer: ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (processor # NIL);
	currentActivity := SYSTEM.GetActivity ()(Activity); stackPointer := SYSTEM.GetStackPointer (); SYSTEM.SetActivity (processor);
	SYSTEM.SetStackPointer (ADDRESS OF processor.stack[LEN (processor.stack) - CPU.StackDisplacement]);
	procedure (value); SYSTEM.SetActivity (currentActivity); SYSTEM.SetStackPointer (stackPointer);
END CallVirtual;

(** Creates a new activity that calls the specified procedure. *)
PROCEDURE Call- (procedure: PROCEDURE);
VAR activity: Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	NEW (activity, procedure, DefaultPriority);
	ASSERT (activity # NIL);
	Resume (activity);
END Call;

(** Starts the scheduler on the current processor by creating a new activity that calls the specified procedure. *)
(** This procedure is called by the runtime system once during the initialization of each processor. *)
PROCEDURE Execute- (procedure: PROCEDURE);
VAR previousActivity {UNTRACED}: Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	SYSTEM.SetActivity (NIL);
	BeginExecution (procedure);
	previousActivity := SYSTEM.GetActivity ()(Activity);
	previousActivity.processor.runningActivity := NIL;
	SYSTEM.SetActivity (NIL);
	Dispose (previousActivity, NIL);
END Execute;

(* Turns the calling procedure temporarily into an activity that begins its execution with the specified procedure. *)
PROCEDURE BeginExecution (procedure: PROCEDURE);
VAR activity {UNTRACED}: Activity; index: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	NEW (activity, procedure, DefaultPriority);
	ASSERT (activity # NIL);
	index := Counters.Increment (physicalProcessors, 1);
	ASSERT (index < Processors.count);
	activity.processor := ADDRESS OF processors[index];
	activity.processor.originalFramePointer := SYSTEM.GetFramePointer ();
	activity.processor.runningActivity := activity; activity.processor.index := index;
	ASSERT (Counters.Increment (working, 1) < Processors.count);
	IF (index = 0) & (Processors.count > 1) THEN Processors.StartAll END;
	SYSTEM.SetActivity (activity); SYSTEM.SetFramePointer (activity.framePointer);
END BeginExecution;

(* Yields the execution of the current activity to any activity with the given minimal priority. *)
PROCEDURE YieldExecution (minimum: Priority; finalizer: SwitchFinalizer; value: ADDRESS);
VAR nextActivity: Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	LOOP
		IF Select (nextActivity, minimum) THEN
			SwitchTo (nextActivity, finalizer, value);
			FinalizeSwitch;
		ELSE
			IF Counters.Decrement (working, 1) + Counters.Read (awaiting) > 1 THEN Processors.SuspendCurrentProcessor END;
			IF Counters.Increment (working, 1) + Counters.Read (awaiting) = 0 THEN EXIT END;
		END;
	END;
END YieldExecution;

(* This procedure returns to the procedure that called BeginExecution. *)
PROCEDURE EndExecution;
VAR currentActivity {UNTRACED}: Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	currentActivity := SYSTEM.GetActivity ()(Activity);
	currentActivity.framePointer := SYSTEM.GetFramePointer ();
	IF Counters.Decrement (working, 1) < Processors.count THEN Processors.ResumeAllProcessors END;
	SYSTEM.SetFramePointer (currentActivity.processor.originalFramePointer);
END EndExecution;

(** This is the default procedure for initially idle processors starting the scheduler using the {{{[[Activities.Execute]]}}} procedure. *)
PROCEDURE Idle-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (SetCurrentPriority (IdlePriority) = DefaultPriority);
	YieldExecution (IdlePriority + 1, Enqueue, ADDRESS OF readyQueue[IdlePriority]); EndExecution;
END Idle;

(** Terminates the execution of the current activity calling this procedure. *)
(** This procedure is also invoked at the end of the body of an active object. *)
PROCEDURE {NORETURN} TerminateCurrentActivity-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	YieldExecution (IdlePriority, Dispose, NIL);
	EndExecution; HALT (1234);
END TerminateCurrentActivity;

(* Switch finalizer that disposes the resources of the terminated activity. *)
PROCEDURE Dispose (previous {UNTRACED}: Activity; value: ADDRESS);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	DISPOSE (previous);
END Dispose;

(** This procedure is called by the compiler while executing a {{{WAIT}}} statement. *)
(** It awaits the termination of all activities associated with an active object. *)
PROCEDURE Wait- (object {UNTRACED}: BaseTypes.Object);
VAR nextActivity: Activity; item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (object # NIL);
	IF object.action = NIL THEN RETURN END;
	IF object.action.activity = NIL THEN RETURN END;
	REPEAT UNTIL Select (nextActivity, IdlePriority);
	SwitchTo (nextActivity, EnqueueWaiting, object.action); FinalizeSwitch;
	WHILE Queues.Dequeue (item, object.action.waitingQueue) DO Resume (item (Activity)) END;
END Wait;

(* Switch finalizer that enqueues acitivities waiting on an active object. *)
PROCEDURE EnqueueWaiting (previous {UNTRACED}: Activity; action {UNTRACED}: POINTER {UNSAFE} TO BaseTypes.Action);
VAR item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Queues.Enqueue (previous, action.waitingQueue);
	IF action.activity # NIL THEN RETURN END;
	IF Queues.Dequeue (item, action.waitingQueue) THEN Resume (item (Activity)) END;
END EnqueueWaiting;

PROCEDURE  ReturnToStackSegment*;
VAR 
	stackFrame {UNTRACED}: BaseTypes.StackFrame;
	currentActivity {UNTRACED}: Activity; 
	newStack {UNTRACED}: Stack;
	stackRecord {UNTRACED}: StackRecord; 
BEGIN{UNCOOPERATIVE, UNCHECKED}
	(* old stack pointer and base pointer have been pushed again, we have to revert this *)
	stackFrame := SYSTEM.GetFramePointer();
	(*
	TRACE(stackFrame.caller);
	TRACE(stackFrame.previous);
	previousFrame := stackFrame.previous;
	TRACE(ADDRESS OF previousFrame.caller + SIZE OF ADDRESS);
	TRACE(previousFrame.caller);
	TRACE(previousFrame.previous);
	*)
	currentActivity := SYSTEM.GetActivity ()(Activity);
	stackRecord := ADDRESS OF currentActivity.stack[0];
	newStack := stackRecord.prev;
	currentActivity.stack := newStack;
	currentActivity.stackLimit := ADDRESS OF newStack[SafeStackSize + 3 * SIZE OF ADDRESS];
END ReturnToStackSegment;

PROCEDURE {NOPAF} ReturnToStackSegment0;
BEGIN{UNCOOPERATIVE, UNCHECKED}
	CPU.SaveResult;
	ReturnToStackSegment;
	CPU.RestoreResultAndReturn;
END ReturnToStackSegment0;

(** Expands the stack memory of the current activity to include the specified stack address and returns the new stack pointer to be set after the call. *)
PROCEDURE ExpandStack- (address: ADDRESS; parSize: SIZE): ADDRESS;
VAR 
	currentActivity {UNTRACED}: Activity; 
	varSize, minSize, newSize: SIZE;  sp: ADDRESS;
	newStack {UNTRACED}: POINTER {DISPOSABLE} TO ARRAY OF CHAR; 
	stackFrame {UNTRACED}, previousFrame {UNTRACED}, newFrame {UNTRACED}: BaseTypes.StackFrame;
	stackRecord{UNTRACED}, newStackRecord{UNTRACED}: StackRecord;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* check for valid argument *)
	currentActivity := SYSTEM.GetActivity ()(Activity);
	
	stackFrame := SYSTEM.GetFramePointer ();
	previousFrame := stackFrame.previous;
	varSize := stackFrame.previous - address;
	
	(*
	TRACE(SYSTEM.GetFramePointer(), address, varSize, parSize, size, stackFrame.caller);
	*)
	ASSERT(varSize >= 0); 
	ASSERT(parSize >= 0);

	newSize := LEN (currentActivity.stack); (* current stack size *)
	minSize := SafeStackSize + parSize + varSize + 3 * SIZEOF(ADDRESS) (* stack frame *) + 3 * SIZEOF(ADDRESS) (* prev, next *);
	REPEAT INC (newSize, newSize) UNTIL newSize >= minSize;
	ASSERT (newSize <= MaximumStackSize);
	stackRecord := ADDRESS OF currentActivity.stack[0];
	newStack := stackRecord.next;
	IF (newStack = NIL) OR (LEN(newStack) < newSize) THEN 
		NEW (newStack, newSize); 
		ASSERT (newStack # NIL);
		newStackRecord := ADDRESS OF newStack[0];
		newStackRecord.prev := currentActivity.stack;
		newStackRecord.next := NIL;
		stackRecord.next := newStack;
	ELSE 
		newStackRecord := ADDRESS OF newStack[0];
		ASSERT(newStackRecord.prev = currentActivity.stack);
		ASSERT(stackRecord.next = newStack);
	END;
	newSize := LEN(newStack); 
	newFrame := ADDRESS OF newStack[0] + newSize- parSize -  3*SIZE OF ADDRESS; 
	newFrame.previous := stackFrame.previous;
	newFrame.descriptor := previousFrame.descriptor;
	newFrame.caller := ReturnToStackSegment0;
	previousFrame.descriptor := stackFrame.descriptor; (* trick to get a base stack frame descriptor *)

	stackFrame.previous := newFrame;
	SYSTEM.MOVE(ADDRESS OF previousFrame.caller + SIZE OF ADDRESS, ADDRESS OF newFrame.caller + SIZE OF ADDRESS, parSize); (* copy parameters *)
		
	sp := ADDRESSOF(newFrame.descriptor) - varSize; 
	currentActivity.stack := newStack;
	currentActivity.stackLimit := ADDRESS OF newStack[SafeStackSize + 3 * SIZE OF ADDRESS];

	RETURN sp; 
END ExpandStack;

(** Returns whether the specified address corresponds to a local variable that resides on the stack of the current activity calling this procedure. *)
PROCEDURE IsLocalVariable- (address: ADDRESS): BOOLEAN;
VAR currentActivity {UNTRACED}: Activity; begin, end: ADDRESS; stack {UNTRACED}: Stack; stackRecord {UNTRACED}: StackRecord;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	currentActivity := SYSTEM.GetActivity ()(Activity);
	IF currentActivity = NIL THEN RETURN FALSE END;
	stack := currentActivity.firstStack;
	REPEAT
		begin := ADDRESS OF stack[0];
		end := begin + LEN (stack);
		IF (address >= begin) & (address < end) THEN RETURN TRUE END;
		stackRecord := begin;
		stack := stackRecord.next;
	UNTIL stack = NIL;
	RETURN FALSE;
END IsLocalVariable;

(** Returns whether any activity is currently executing an assignment statement. *)
PROCEDURE AssignmentsInProgress- (): BOOLEAN;
VAR i: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO Processors.Maximum - 1 DO IF processors[i].assigning THEN RETURN TRUE END END; RETURN FALSE;
END AssignmentsInProgress;

(** Terminates the module and disposes all of its resources. *)
PROCEDURE Terminate-;
VAR priority: Priority;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR priority := LowestPriority TO HighestPriority DO
		Queues.Dispose (readyQueue[priority]);
	END;
END Terminate;

END Activities.
