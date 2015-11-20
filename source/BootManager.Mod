(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE BootManager;
(** AUTHOR "afi"; PURPOSE "Split the boot manager object code BootManager.Bin"; *)

IMPORT Commands, Files;

(** Split the boot manager object code BootManager.Bin, obtained by assembling BootManager.Asm,
	into a 512-byte MBR and the rest of it in bmsize sectors. *)
PROCEDURE Split* (context: Commands.Context);
VAR fileName: Files.FileName;
	fi, fo, fo2 : Files.File; r : Files.Reader; w : Files.Writer;
	count,i : LONGINT; ch : CHAR;

BEGIN
	context.arg.SkipWhitespace; context.arg.String (fileName);
	fi := Files.Old(fileName);
	fo := Files.New("BootManagerMBR.Bin");
	fo2 := Files.New("BootManagerTail.Bin");
	IF fi # NIL THEN
		Files.OpenReader(r, fi, 0);
		Files.OpenWriter(w, fo, 0);
		i := 0;
		FOR count := 1 TO 512 DO
			r.Char(ch);
			w.Char(ch);
			INC(i);
		END;
		w.Update;
		Files.Register(fo);

		Files.OpenWriter(w, fo2, 0);
		WHILE r.Available() > 0 DO
			r.Char(ch);
			w.Char(ch);
			INC(i);
		END;
		WHILE i MOD 512 # 0 DO
			w.Char(0X);
			INC(i);
		END;
		w.Update;
		Files.Register(fo2);
	END;
END Split;

BEGIN
END BootManager.

BootManager.Split BootManager.Bin ~