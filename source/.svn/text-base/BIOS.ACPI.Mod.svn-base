(* Runtime support for ACPI *)
(* Copyright (C) Florian Negele *)

MODULE ACPI;

CONST HPETSignature* = 54455048H;
CONST RDSPSignature* = 2052545020445352H;

TYPE Address* = RECORD
	value: LONGINT;
END;

TYPE Header* = RECORD
	signature-: LONGINT;
	length-: LONGINT;
	revision-: SHORTINT;
	checksum-: SHORTINT;
	oemID-: ARRAY 6 OF CHAR;
	oemTableID-: ARRAY 8 OF CHAR;
	oemRevision-: LONGINT;
	creatorID-: LONGINT;
	creatorRevision-: LONGINT;
END;

TYPE HPET* = RECORD (Header)
	eventTimerBlockID-: LONGINT;
	baseAddress-: RECORD
		addressSpaceID-: SHORTINT;
		registerBitWidth-: SHORTINT;
		registerBitOffset-: SHORTINT;
		reserved-: SHORTINT;
		addressLow-: Address;
		addressHigh-: Address;
	END;
	hpetNumber-: SHORTINT;
	mainCounterMinimum-: INTEGER;
	oemAttribute-: SHORTINT;
END;

TYPE RDSP* = RECORD
	signature-: HUGEINT;
	checksum-: SHORTINT;
	oemID-: ARRAY 6 OF CHAR;
	revision-: SHORTINT;
	rsdtAddress-: Address;
END;

TYPE RSDT* = RECORD (Header)
	entry-: ARRAY 1024 OF Address;
END;

VAR rdsp- {UNTRACED} := NIL: POINTER {UNSAFE} TO RDSP;

PROCEDURE Checksum (address: ADDRESS; size: SIZE): SHORTINT;
VAR checksum := 0: SHORTINT; block {UNTRACED}: POINTER {UNSAFE} TO ARRAY OF SHORTINT;
BEGIN {UNCOOPERATIVE, UNCHECKED} block := address; WHILE size # 0 DO DEC (size); INC (checksum, block[size]) END; RETURN checksum;
END Checksum;

PROCEDURE Convert- (CONST address: Address): ADDRESS;
VAR result: ADDRESS; masked {UNTRACED}: POINTER {UNSAFE} TO RECORD value: SET END;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	result := address.value; masked := ADDRESS OF result;
	masked.value := masked.value * {0 .. SIZE OF LONGINT * 8 - 1};
	RETURN result;
END Convert;

PROCEDURE GetTable- (signature: LONGINT): ADDRESS;
VAR address: ADDRESS; rsdt {UNTRACED}: POINTER {UNSAFE} TO RSDT; header {UNTRACED}: POINTER {UNSAFE} TO Header; i: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (rdsp # NIL);
	address := Convert (rdsp.rsdtAddress); rsdt := address;
	ASSERT (Checksum (rsdt, rsdt.length) = 0);
	FOR i := 0 TO (rsdt.length - 36) DIV 4 DO
		address := Convert (rsdt.entry[i]); header := address;
		IF (header.signature = signature) & (Checksum (header, header.length) = 0) THEN RETURN header END;
	END;
	RETURN NIL;
END GetTable;

PROCEDURE Initialize-;
VAR address := 0E0000H: ADDRESS; size := 020000H: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	WHILE size # 0 DO
		rdsp := address;
		IF (rdsp.signature = RDSPSignature) & (Checksum (address, 20) = 0) THEN RETURN END;
		INC (address, 16); DEC (size, 16);
	END;
	rdsp := NIL;
END Initialize;

END ACPI.
