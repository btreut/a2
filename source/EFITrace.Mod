MODULE EFITrace; (** AUTHOR "Matthias Frei"; PURPOSE "EFI Console Output"; *)

IMPORT EFI, Trace;

PROCEDURE Char (char: CHAR);
VAR text: ARRAY 2 OF EFI.Char16; status: EFI.Status;
BEGIN
	text[0] := ORD (char); text[1] := 0;
	status := EFI.table.ConOut.OutputString (EFI.table.ConOut, text);
END Char;

PROCEDURE Color (color: SHORTINT);
VAR status: EFI.Status;
BEGIN status := EFI.table.ConOut.SetAttribute (EFI.table.ConOut, color);
END Color;

BEGIN
	Trace.Char := Char;
	Trace.Color := Color;
END EFITrace.