MODULE KernelLogger; (** AUTHOR "TF"; PURPOSE "Periodically copy kernel log buffer into text"; *)

IMPORT
	SYSTEM, KernelLog, Texts, TextUtilities, Kernel, Modules;

CONST
	BufSize = 8192 * 16; (* Kernel buffer size *)
	UpdateInterval = 200;	(* ms *)
	LocalBuf = 4096 * 2;

	MaxLogSize = 4*BufSize;

TYPE
	(* periodically poll the kernel log buffer *)
	Logger = OBJECT
	VAR
		timer : Kernel.Timer;
		alive, dead, added : BOOLEAN;
		buf : ARRAY LocalBuf OF CHAR;
		bufPos : LONGINT;
		ch : CHAR;
		tw : TextUtilities.TextWriter;

		limitCounter, n: LONGINT;

		PROCEDURE &Open;
		BEGIN
			dead := FALSE; alive := TRUE;
			NEW(timer);
			NEW(tw, kernelLog);
		END Open;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			KernelLog.CloseBuffer;
			alive := FALSE; timer.Wakeup;
			AWAIT(dead)
		END Close;

		PROCEDURE Get() : CHAR;
		VAR res : CHAR;
		BEGIN
			IF (bufPos >= LocalBuf) OR (buf[bufPos] = 0X) THEN
				bufPos := 0;
				KernelLog.GetBuffer(buf)
			END;
			res := buf[bufPos];
			INC(bufPos);
			RETURN res
		END Get;

	BEGIN {ACTIVE}
		(* pre loading the fonts so traps can be displayed even when the disk is causing the trap *)
		tw.SetFontName("Courier"); tw.String("Log started");
		tw.SetFontName("Oberon"); tw.Ln;
		WHILE alive DO
			bufPos := 0; added := FALSE;
			LOOP
				ch := Get();
				IF ch # 0X THEN
					IF ch = 0EX THEN tw.SetFontName("Courier"); tw.SetFontColor(LONGINT(0800000FFH));
					ELSIF ch = 0FX THEN tw.SetFontName("Oberon"); tw.SetFontColor(0FFH);
					ELSIF ch = 0DX THEN (* ignore CR character - this approximates the CRLF -> LF *)
					ELSE tw.Char(ch); added := TRUE;
					END;
				END;	(* 0X (end), 0DX (CR), 0AX (LF), 0EX (FixedFont), 0FX (NormalFont) *)
				IF (ch = 0X) OR ~alive THEN EXIT END;
				
				INC(limitCounter);
				
				IF limitCounter >= 1024 THEN
					kernelLog.AcquireWrite;
					n := kernelLog.GetLength();
					IF n > MaxLogSize THEN
						kernelLog.Delete(0,n-MaxLogSize);					
					END;
					kernelLog.ReleaseWrite;
					limitCounter := 0;
				END;	
			END;
			IF added THEN
				tw.Update;

				kernelLog.AcquireWrite;
				n := kernelLog.GetLength();
				IF n > MaxLogSize+1024 THEN
					kernelLog.Delete(0,n-MaxLogSize);					
				END;
				kernelLog.ReleaseWrite;
			END;
			timer.Sleep(UpdateInterval);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE END;
	END Logger;

VAR
	logger : Logger;
	buf : POINTER TO ARRAY OF CHAR;
	kernelLog- : Texts.Text;

PROCEDURE Start*;
CONST OberonKernel = "Oberon.Kernel"; OberonSystem = "Oberon.System";
VAR kernelLockOberon, kernelUnlockOberon, systemStopLog : PROCEDURE;
BEGIN {EXCLUSIVE}
	IF logger # NIL THEN KernelLog.Enter; KernelLog.String("Logger already running! "); KernelLog.Exit; RETURN END;

	KernelLog.Enter; KernelLog.String("Starting logger"); KernelLog.Exit;
	NEW(buf, BufSize);
	IF ~KernelLog.OpenBuffer(ADDRESSOF(buf[0]), LEN(buf)) THEN
		(* Kill Oberon Logger *)
		IF Modules.ModuleByName (OberonKernel) # NIL THEN
			GETPROCEDURE (OberonKernel, "LockOberon", kernelLockOberon);
			GETPROCEDURE (OberonKernel, "UnlockOberon", kernelUnlockOberon);
		END;
		IF Modules.ModuleByName (OberonSystem) # NIL THEN
			GETPROCEDURE (OberonSystem, "StopLog", systemStopLog);
		END;
		IF (kernelLockOberon # NIL) & (kernelUnlockOberon # NIL) &(systemStopLog # NIL) THEN
			kernelLockOberon; systemStopLog; kernelUnlockOberon;
			KernelLog.CloseBuffer; 	IF KernelLog.OpenBuffer(ADDRESSOF(buf[0]), LEN(buf)) THEN
				KernelLog.Enter; KernelLog.String("Oberon KernelLog stopped. New buffer installed"); KernelLog.Exit
			END
		END;
	END;
	NEW(logger);
END Start;

PROCEDURE Stop*;
BEGIN {EXCLUSIVE}
	IF logger # NIL THEN
		KernelLog.Enter; KernelLog.String("Stopping logger"); KernelLog.Exit;
		logger.Close; logger := NIL;
		KernelLog.Enter; KernelLog.String("Logger stopped"); KernelLog.Exit;
	END;
END Stop;

PROCEDURE Cleanup;
BEGIN
	IF logger # NIL THEN
		KernelLog.CloseBuffer;
		logger.Close
	END
END Cleanup;

BEGIN
	NEW(kernelLog);
	Start;
	Modules.InstallTermHandler(Cleanup);
END KernelLogger.

KernelLogger.Start ~
KernelLogger.Stop ~
SystemTools.Free WMKernelLog KernelLogger ~
