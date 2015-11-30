(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMThreads;
	(*automatically generated stub for java/lang/Thread *)
	
IMPORT
		SYSTEM, AosModules, AosActive, AosHeap, AosKernel,
		JC := JVMConsole, JT := JVMTypes, JS := JVMSystem, 
		JI := JVMInterfaces, JE := JVMExceptions, JB := JVMBase, jjlObject,  jjlString,  jjlThrowable;

TYPE
	
	Object = jjlObject.Object;
	RunnableObj = jjlObject.Object;
	String = jjlString.String;
	ThreadGroup = jjlObject.Object;
	ClassLoader = jjlObject.Object;
	Throwable = jjlThrowable.Throwable;
	RefArray = jjlObject.RefArray;
	Class = JB.Class;

CONST
	(*thread state*)
		running = 1; dead = 2;

	(* static final fields *)
	MAXPRIORITY* = 3;
	MINPRIORITY* = 1;
	NORMPRIORITY* = 2;

VAR
		debugInfo, warningInfo, infoInfo, statusInfo, errorInfo, failureInfo: JC.LoggingInfo;

TYPE
	Thread* = OBJECT (Object)
		VAR
			(*fields defined in java/lang/Thread, do not change*)
			group-: ThreadGroup;		(* ThreadGroup group *)
			toRun-: RunnableObj;		(* final Runnable toRun *)
			name-: String;					(* String name *)
			daemon-: BOOLEAN;		(* boolean daemon *)
			priority-: LONGINT;			(* int priority *)
			contextClassLoader-: ClassLoader;		(* private ClassLoader contextClassLoader *)
			
			(* own fields *)
			interrupted :BOOLEAN;
			timer : AosKernel.Timer;	(*cached, created at first call of sleep*)
			state: SHORTINT;
		
		PROCEDURE init*();   (* <init>()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init;

		PROCEDURE init8291*(runnable: RunnableObj);   (* <init>(Ljava/lang/Runnable;)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init8291;

		PROCEDURE init4624*(runnable: RunnableObj; name: String);   (* <init>(Ljava/lang/Runnable;Ljava/lang/String;)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init4624;

		PROCEDURE init1930*(name: String);   (* <init>(Ljava/lang/String;)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init1930;

		PROCEDURE init3900*(group: ThreadGroup; runnable: RunnableObj);   (* <init>(Ljava/lang/ThreadGroup;Ljava/lang/Runnable;)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init3900;

		PROCEDURE init4148*(group: ThreadGroup; runnable: RunnableObj; name: String);   (* <init>(Ljava/lang/ThreadGroup;Ljava/lang/Runnable;Ljava/lang/String;)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init4148;

		PROCEDURE init8524*(p0: Class; p1: Class; p2: String; p3: JT.Long);   (* <init>(Ljava/lang/ThreadGroup;Ljava/lang/Runnable;Ljava/lang/String;J)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init8524;

		PROCEDURE init1949(group: ThreadGroup; name: String);   (* <init>(Ljava/lang/ThreadGroup;Ljava/lang/String;)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init1949;

		PROCEDURE checkAccess*();   (* checkAccess()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END checkAccess;

		PROCEDURE countStackFrames*(): JT.Int;   (* countStackFrames()I *)
		BEGIN	(* put your implementation here *)
			JC.String(errorInfo, "Thread.countStackFrames not implemented"); JC.Ln(errorInfo);
			RETURN 1
		END countStackFrames;

		PROCEDURE destroy*();   (* destroy()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END destroy;

		PROCEDURE getContextClassLoader*(): ClassLoader;   (* getContextClassLoader()Ljava/lang/ClassLoader; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getContextClassLoader;

		PROCEDURE getName*(): String;   (* getName()Ljava/lang/String; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getName;

		PROCEDURE getPriority*(): JT.Int;   (* getPriority()I *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getPriority;

		PROCEDURE getThreadGroup*(): ThreadGroup;   (* getThreadGroup()Ljava/lang/ThreadGroup; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getThreadGroup;

		PROCEDURE interrupt*();   (* interrupt()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END interrupt;

		PROCEDURE isAlive*(): BOOLEAN;   (* isAlive()Z *)
		BEGIN	(* put your implementation here *)
			RETURN state = running
		END isAlive;

		PROCEDURE isDaemon*(): BOOLEAN;   (* isDaemon()Z *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END isDaemon;

		PROCEDURE isInterrupted*(): BOOLEAN;   (* isInterrupted()Z *)
		BEGIN	(* put your implementation here *)
			JC.String(errorInfo, "Thread.isInterrupted not implemented"); JC.Ln(errorInfo);
			RETURN FALSE;
		END isInterrupted;

		PROCEDURE join164*();   (* join()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END join164;

		PROCEDURE join108*(p0: JT.Long);   (* join(J)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END join108;

		PROCEDURE join496*(p0: JT.Long; p1: JT.Int);   (* join(JI)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END join496;

		PROCEDURE nativeDestroy();   (* nativeDestroy()V *)
		VAR  p, t: AosActive.Process;  ptr: PTR;
		BEGIN
			JC.String(infoInfo, "Thread.nativeDestroy() called"); JC.Ln(infoInfo);
			ptr := SELF;
			AosActive.snapshotEnabled := TRUE;
			AosHeap.GC;
			WHILE AosActive.snapshot # NIL DO
				p := AosActive.snapshot; AosActive.snapshot := p.link;
				IF p.obj = ptr THEN  t := p  END
			END;
			IF t # NIL THEN
				AosActive.TerminateThis(p, FALSE);
			END
		END nativeDestroy;

		PROCEDURE nativeInit();   (* nativeInit()V *)
		BEGIN	(* put your implementation here *)
			(*nothing to do*)
		END nativeInit;

		PROCEDURE nativeInterrupt();   (* nativeInterrupt()V *)
		BEGIN	(* put your implementation here *)
			JC.String(failureInfo, "Thread.nativeInterrupt not implemented"); JC.Ln(failureInfo);
			HALT(99)
		END nativeInterrupt;

		PROCEDURE nativeResume();   (* nativeResume()V *)
		BEGIN	(* put your implementation here *)
			JC.String(failureInfo, "Thread.nativeResume not implemented"); JC.Ln(failureInfo);
			HALT(99)
		END nativeResume;

		PROCEDURE nativeSetPriority(p0: JT.Int);   (* nativeSetPriority(I)V *)
		BEGIN	(* put your implementation here *)
			JC.String(warningInfo, "SetPriority "); JC.Int(warningInfo, p0, 0); JC.String(warningInfo, " ignored"); JC.Ln(warningInfo);
(*
			AosActive.SetPriority(p0);
*)
		END nativeSetPriority;

		PROCEDURE nativeStop(p0: Throwable);   (* nativeStop(Ljava/lang/Throwable;)V *)
		BEGIN	(* put your implementation here *)
			destroy
		END nativeStop;

		PROCEDURE nativeSuspend();   (* nativeSuspend()V *)
		BEGIN	(* put your implementation here *)
			JC.String(failureInfo, "Thread.nativeSuspend not implemented"); JC.Ln(failureInfo);
			HALT(99)
		END nativeSuspend;

		PROCEDURE resume*();   (* resume()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END resume;

		PROCEDURE run*();   (* run()V *)
		BEGIN	(* use java implementation *)
		END run;
		
		PROCEDURE setContextClassLoader*(p0: ClassLoader);   (* setContextClassLoader(Ljava/lang/ClassLoader;)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END setContextClassLoader;

		PROCEDURE setDaemon*(p0: BOOLEAN);   (* setDaemon(Z)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END setDaemon;

		PROCEDURE setName*(name: String);   (* setName(Ljava/lang/String;)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END setName;

		PROCEDURE setPriority*(prio: JT.Int);   (* setPriority(I)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END setPriority;

		PROCEDURE start*();   (* start()V *)
		BEGIN
			jjlObject.Assert(state = 0, "java/lang/IllegalThreadStateException", "Thread.start already called on this thread");
			JC.String(infoInfo, "Start "); JC.Hex(infoInfo, SYSTEM.VAL(LONGINT, SELF), 10); JC.Int(infoInfo, priority, 4);
			IF priority = 5 THEN priority := NORMPRIORITY
			ELSIF priority = 10 THEN priority := MAXPRIORITY
			END;
			JC.String(infoInfo, " -> "); JC.Int(infoInfo, priority, 0); JC.Ln(infoInfo);
			jjlObject.CreateActivity(RunBody, priority, {}, SELF);
(*
			jjlObject.Lock(SELF);
			state := running;
			jjlObject.Unlock(SELF);
*)
		END start;

		PROCEDURE stop164*();   (* stop()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END stop164;

		PROCEDURE stop977*(p0: Throwable);   (* stop(Ljava/lang/Throwable;)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END stop977;

		PROCEDURE suspend*();   (* suspend()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END suspend;

		PROCEDURE this();   (* this()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END this;

		PROCEDURE toString*(): Object;   (* toString()Ljava/lang/String; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END toString;

(*

	BEGIN {ACTIVE}
		jjlObject.Lock(SELF);
			AWAIT (state = running);
			AosActive.SetPriority(priority);
		jjlObject.Unlock(SELF);
		IF JE.EnableExceptions THEN AosActive.SetExceptionHandler(JE.HandleException) END;
		JS.InitFPU;
		run;	(*call run implemented by java or overwritter by the actual class -> does the interface call there*)
		state := dead;
		JC.String("Thread is dead "); JC.Hex(SYSTEM.VAL(LONGINT, SELF), 0); JC.Ln;
*)
	END Thread;

VAR
	(* fields defined in java/lang/Thread, do not change *)
	numAnonymousThreadsCreated-: JT.Int;		(* private static int numAnonymousThreadsCreated *)
	
	(* own variables *)
	class*: JB.Class;
	firstThread-: Thread;	(*used for startup, when no java thread exists; created by JVM; used by currentThread*)
	
	PROCEDURE KillAll*;
	VAR t: Thread;
	BEGIN (*{EXCLUSIVE}*)
		JC.String(errorInfo, "JVMThreads.KillAll unimplemented"); JC.Ln(errorInfo);
	END KillAll;
	
	PROCEDURE clinit;   (* <clinit>()V *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END clinit;
	
		
	PROCEDURE RunBody(td :LONGINT; obj : RunnableObj);
	VAR tdobj : LONGINT;
		t : Thread;
	BEGIN
	    t := obj(Thread);
		IF JE.EnableExceptions THEN AosActive.SetExceptionHandler(JE.HandleException) END;
		JS.InitFPU;
		JC.String(infoInfo, "Thread running "); JC.Hex(infoInfo, SYSTEM.VAL(LONGINT, obj), 0); JC.Ln(infoInfo);
		t.state := running;
		t.run;	(*call run implemented by java or overwritten by the actual class -> does the interface call there*)
		t.state := dead;
		JC.String(infoInfo, "Thread dead "); JC.Hex(infoInfo, SYSTEM.VAL(LONGINT, obj), 0); JC.Ln(infoInfo);
	END RunBody;
	
	PROCEDURE activeCount*(): JT.Int;   (* activeCount()I *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END activeCount;

	PROCEDURE currentThread*(): Thread;   (* currentThread()Ljava/lang/Thread; *) 
	VAR p: PTR;  t: Thread;
		l: LONGINT;
	BEGIN
		t := firstThread;
		p := AosActive.ActiveObject();
		IF p IS Thread THEN  t := p(Thread)  END;
		RETURN t
	END currentThread;

	PROCEDURE dumpStack*();   (* dumpStack()V *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END dumpStack;

	PROCEDURE enumerate*(p0: RefArray): JT.Int;   (* enumerate([Ljava/lang/Thread;)I *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END enumerate;

	PROCEDURE holdsLock*(p0: Object): BOOLEAN;   (* holdsLock(Ljava/lang/Object;)Z *)
	BEGIN	(* put your implementation here *)
		HALT(99)
	END holdsLock;

	PROCEDURE interrupted*(): BOOLEAN;   (* interrupted()Z *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END interrupted;

	PROCEDURE sleep108*(delay: JT.Long);   (* sleep(J)V *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END sleep108;

	PROCEDURE sleep496*(delay: JT.Long; p1: JT.Int);   (* sleep(JI)V *)
	VAR thread : Thread;
	BEGIN
		thread := currentThread();
		IF thread # NIL THEN
(*
			JC.String("Sleep "); JC.Int(SHORT(ASH(delay, -32)), 0); JC.String(" / "); JC.Int(SHORT(delay), 0); JC.Ln;
*)
			IF thread.timer = NIL THEN  NEW(thread.timer)  END;
			thread.timer.Sleep(SHORT(delay))
		END
	END sleep496;

	PROCEDURE yield*();   (* yield()V *)
	BEGIN	
		AosActive.Yield();
	END yield;
	
	PROCEDURE MakeFirstThread*(g: ThreadGroup);
	BEGIN
		ASSERT(g # NIL, 10000);
		ASSERT(class # NIL, 10001);
(*
		NEW(firstThread);
		firstThread.class := class;
		firstThread.group := g;
		firstThread.name := jjlString.CreateString0("Thread -  -1");
		firstThread.toRun := NIL;
		firstThread.priority := MINPRIORITY;
		firstThread.daemon := FALSE;
*)
	END MakeFirstThread;
	
	PROCEDURE Status*;
	BEGIN
		JC.String(statusInfo, "Active Count = "); JC.Int(statusInfo, activeCount(), 0); JC.Ln(statusInfo);
	END Status;
	
BEGIN
	debugInfo.kind := JC.Debug; debugInfo.source := JC.VM;
	warningInfo.kind := JC.Warning; debugInfo.source := JC.VM;
	infoInfo.kind := JC.Info; infoInfo.source := JC.VM;
	statusInfo.kind := JC.Info; statusInfo.source := JC.VM;
	errorInfo.kind := JC.Error; errorInfo.source := JC.VM;
	failureInfo.kind := JC.Failure; failureInfo.source := JC.VM;
END JVMThreads.


(*
	30.07.03	prk	Logging functions, add kind and source; filtering support
	09.03.03	prk	active object removed, explicit kernel call used: trouble if java allocates thread object
	09.03.03	prk	improve priority handling
	12.02.03	prk	Logging functions, use same interface as AosOut
	29.12.02	prk	update to classpath snapshot 28.12.02
	11.01.02	prk	Aos 21.12.01 port
	12.11.01	prk	Use AosSleep for implementing delays
	27.05.01	prk	merge Thread.java with classpath 0.02
	11.04.01	prk	update to classpath 0.02
*)	
(*
ToDo
	remove IsJThread and related vars/procs
*)