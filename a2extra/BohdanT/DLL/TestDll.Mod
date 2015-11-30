MODULE TestDll; (** AUTHOR ""; PURPOSE ""; *)
IMPORT SYSTEM,DLL,KernelLog,Strings;
VAR
	lib:DLL.TLibInfo;
	proc1: PROCEDURE{WINAPI}(a,b:LONGINT);
	proc2 : PROCEDURE{WINAPI}();
PROCEDURE {WINAPI}Int*(a,b:LONGINT);
BEGIN
	KernelLog.String("LogInt=");KernelLog.Int(a,b);KernelLog.Ln();
END Int;
PROCEDURE {WINAPI}String(CONST s:ARRAY OF CHAR);
VAR
 i:LONGINT;
BEGIN
(*	KernelLog.Memory(SYSTEM.ADR(s),32);*)
	i:=0;
	WHILE s[i]#0X DO
		KernelLog.Char(s[i]);INC(i)
	END;
END String;
PROCEDURE TestLoad*;
BEGIN
	lib:=DLL.LoadLibrary("Testa2.dll");
	IF lib#NIL THEN
		DLL.GetProcAddress(lib,"helloword1", SYSTEM.VAL(LONGINT,proc1));
		DLL.GetProcAddress(lib,"helloword2", SYSTEM.VAL(LONGINT,proc2));
		IF proc1#NIL THEN
			proc1(5,6);
		ELSE
			KernelLog.String("=helloword1=NIL= ");KernelLog.Ln;
		END;
		IF proc2#NIL THEN
			proc2();
		ELSE
			KernelLog.String("=helloword2=NIL= ");KernelLog.Ln;
		END;
	END;
END TestLoad;
END TestDll.TestLoad~
 