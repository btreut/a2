MODULE SQLite3Test;

IMPORT
	Kernel32, SQLite3, KernelLog;
	
PROCEDURE Test*;
VAR
	database: SQLite3.Database;
	lpString: Kernel32.LPSTR;
	str: ARRAY 1024 OF CHAR;
BEGIN
	IF SQLite3.LibraryLoaded THEN
		SQLite3.open("base.db3", database);
		SQLite3.exec(database, "CREATE TABLE TABLE1 (ID INTEGER PRIMARY KEY, F1 INTEGER, F2 INTEGER, F3 INTEGER, F4 INTEGER);", NIL, Kernel32.NULL, lpString);
		Kernel32.CopyString(lpString, str);
		KernelLog.String(str); KernelLog.Ln;
		SQLite3.close(database)
	END
END Test;

END SQLite3Test.

S.Free SQLite3Test SQLite3~
SQLite3Test.Test~