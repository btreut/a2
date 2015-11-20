(* Copyright 2005-2006, Markus Heule, ETH Zurich *)

MODULE OSC; (** AUTHOR "heulemar"; PURPOSE "OpenSoundControl Basetypes"; *)

(*

This Module contains the needed Objecttypes to represent OSCMessages and OSCBundles.

OSCPacket is a common supertype of OSCMessage and OSCBundle, as an OSCPacket received from or sent to the network
can either be a OSCMessage or a OSCBundle. There are also some 'abstract functions' to support easier access
to the corresponding functions in OSCMessage or OSCBundle.

The Objecttypes OSCParam* represent each one Type of OSCArgument. OSCParamObject is a common supertype of all OSCParameter to
support building an array of parameters.

It's rather easy to build a OSCPacket or an OSCBundle:

VAR
	message1: OSCMessage;
	message2: OSCMessage;
	bundle: OSCBundle;
	timetag: OSCTimeTag;
	paramint: OSCParamInteger;
	paramfloat: OSCParamFloat;
BEGIN
	NEW(message1, Strings.NewString('/osc/address/message1'));
	NEW(paramint, 34);
	message1.AddArgument(paramint);
	NEW(message2, Strings.NewString('/osc/address/message2'));
	NEW(paramfloat, 1.234);
	message2.AddArgument(paramfloat);
	NEW(paramint, 20);
	message2.AddArgument(paramfloat);
	NEW(timetag);
	timetag.SetLow(2006,01,01,15,35,00,00); (* year, month, day, hour, minute, second, miliseconds *)
	NET(bundle, timetag);
	bundle.AddPacket(message1);
	bundle.AddPacket(message2);

	* now
		message1 is an OSCMessage to '/osc/address/message1' with one 32bit integer of the value 34
		message2 is an OSCMessage to '/osc/address/message2' with one 32bit float, which has the value 1.234 and one 32bit integer,
			which has the value 20.
		bundle is an OSCBundle with the given timestamp and two messages message1 and message2.

	Note: bundles can also contain bundles.

If you get a parsed packet from the network, then you can access all the needed information of a packet via the member variables of a packet.

OSCMessage m:
	m.address: OSCAddress of OSCMessage m
	m.argumentcount: # of arguments of OSCMessage m
	m.arguments[i]: argument with index i (0<=i<argumentcount). This reference contains always a subclass of OSCPacketObject.
	m.noTypeTagString: Is TRUE iff the recieved packet hasn't got a OSC Type Tag String. In this case, all the received argumentdata
		of length LEN(m.argumentData) is stored in m.argumentData.
OSCBundle b:
	b.timetag: OSCTimeTag of the bundle
	b.messagescount: # of messages or bundles contained in the bundle
	b.messages[i]: packet with index i (0<=i<messagescount)

*)

	IMPORT
		SYSTEM (* Int64 -> Byte[] *),
		Dates, Strings, KernelLog,
		Network (* PutNet4: Little/Big-endian conversion *),
		Reals (* Real -> Byte[] *),
		WMGraphics (* RGBA Color *),
		Clock, Kernel (* Systemtime in ms *);

	CONST

		OSCMessageDefaultArgsCount = 4;
		OSCBundleDefaultMsgCount = 4;
		One32Zero = 100000000H;

		OSCTimeTagOneMS = 418937H; (* := 100000000H DIV 1000 *)

		(* this assumes little endianness, used in the exportfunction of OSCParamInt64 *)
		H = 4; L = 0;

		WrngClassUsedOrFunNotOverl* = 99; (* this trap is executed, if a 'abstract' function wasn't overloaded *)
		Trace* = FALSE;

	VAR
		MonthToDays : ARRAY 13 OF INTEGER; (* copied from Dates.Mod *)

		SysStartSeconds-: LONGINT; (* stores the current bootuptimestamp (secs sincs 1st Jan 1900), when an overflow of Objects.ticks is detected,
										the timestamp will be adjusted *)
		TicksArePositive-: BOOLEAN;


	TYPE
		String* = Strings.String;

	VAR
		OSCBundleIdent: String; (* stores '#bundle' *)

	TYPE
		Blob* = POINTER TO ARRAY OF CHAR;

		(* The following classes are to store the different types of OSC Parameters *)
		OSCParamObject* = OBJECT (* abstract *)
			VAR
				tag-: CHAR;

			(* Returns the number of bytes that this Parameter uses in the argument data.
				This function will be called for every stored argument to calculate the size of the OSCPacket *)
			PROCEDURE GetSize*(): LONGINT; BEGIN HALT(WrngClassUsedOrFunNotOverl); END GetSize;

			(* Exports the argumentdata to packet[pos..pos+GetSize()-1]. In packet all data is stored in network byteorder. *)
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT); BEGIN HALT(WrngClassUsedOrFunNotOverl); END export;

			(* Dumps the current parameter (with stored values) to the kernel log. *)
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamObject { }'); KernelLog.Ln;
			END dump;
		END OSCParamObject;

		ParamArray* = POINTER TO ARRAY OF OSCParamObject;

		(* This 'abstract' class stored the shared functionality of OSCParamInteger and OSCParamRGBAColor *)
		OSCParamAbsInteger = OBJECT(OSCParamObject)
			VAR (* 32bit on IA32 *)
				integer-: LONGINT;
			PROCEDURE GetSize*(): LONGINT;
			BEGIN
				RETURN 4;
			END GetSize;
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			BEGIN
				Network.PutNet4(packet, pos, integer);
				INC(pos, 4);
			END export;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamAbsInteger{ }'); KernelLog.Ln;
			END dump;
		END OSCParamAbsInteger;

		(* int32: OSC Type Tag 'i' *)
		OSCParamInteger* = OBJECT(OSCParamAbsInteger)
			PROCEDURE &InitInteger*(i: LONGINT);
			BEGIN
				integer := i;
				tag := 'i';
			END InitInteger;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamInt { ');
				KernelLog.Int(integer, 1); KernelLog.String(' ('); KernelLog.Hex(integer, 1); KernelLog.String(') }'); KernelLog.Ln;
			END dump;
		END OSCParamInteger;

		(* float32: OSC Type Tag 'f' *)
		OSCParamFloat* = OBJECT(OSCParamObject)
			VAR (* 32bit on IA32 *)
				float-: REAL;
			PROCEDURE &InitFloat*(f: REAL);
			BEGIN
				float := f;
				tag := 'f';
			END InitFloat;
			PROCEDURE GetSize*(): LONGINT;
			BEGIN
				RETURN 4;
			END GetSize;
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			BEGIN
				Network.PutNet4(packet, pos, Reals.Int(float));
				INC(pos, 4);
			END export;
			PROCEDURE dump*(indent: LONGINT);
			VAR
				l, hi, lo: LONGINT;
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamFloat { ');
				l := Reals.RoundL(float*1000);
				hi := l DIV 1000;
				lo := l - hi*1000;
				KernelLog.Int(hi, 1); KernelLog.String('.'); KernelLog.Int(lo, 4);
				(* KernelLog.Float(float, 1); KernelLog.String(' ('); KernelLog.Hex(integer, 1); *) KernelLog.String(' }'); KernelLog.Ln;
			END dump;
		END OSCParamFloat;

		(* This 'abstract' class contains the shared functionality of OSCParamString and OSCParamAltString *)
		OSCParamAbsString = OBJECT(OSCParamObject)
			VAR
				string-: String;
			PROCEDURE GetSize*(): LONGINT;
			BEGIN
				RETURN(padsize(Strings.Length(string^)+1));
			END GetSize;
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			BEGIN
				ASSERT(string # NIL);
				exportString(string, packet, pos);
			END export;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamAbsString { '); KernelLog.String(' }'); KernelLog.Ln;
			END dump;
		END OSCParamAbsString;

		(* OSC-String: OSC Type Tag 's' *)
		OSCParamString* = OBJECT(OSCParamAbsString)
			PROCEDURE &InitString*(s: String);
			BEGIN
				ASSERT(s # NIL);
				string := s;
				tag := 's';
			END InitString;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamString{ ');
				KernelLog.String(string^); KernelLog.String(' }'); KernelLog.Ln;
			END dump;

		END OSCParamString;

		(* OSC-Blob: OSC Type Tag 'b' *)
		OSCParamBlob* = OBJECT(OSCParamObject)
			VAR
				blob-: Blob;
				size-: LONGINT;
			PROCEDURE &InitBlob*(b: Blob; s: LONGINT);
			BEGIN
				ASSERT(b # NIL);
				blob := b;
				size := s;
				tag := 'b';
			END InitBlob;
			PROCEDURE GetSize*(): LONGINT;
			BEGIN
				RETURN(padsize(size)+4);
			END GetSize;
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			VAR i: LONGINT;
			BEGIN
				Network.PutNet4(packet, pos, size); INC(pos, 4);
				FOR i:=0 TO size-1 DO
					packet[pos+i] := blob[i];
				END;
				INC(pos, size);
				WHILE (i MOD 4) # 0 DO
					packet[pos] := 0X; INC(pos);
				END;
			END export;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamBlob { '); KernelLog.Buffer(blob^, 0, size); KernelLog.String(' }'); KernelLog.Ln;
			END dump;
		END OSCParamBlob;

		(* Additional Types:
			h: 64bit Integer
			t: OSC-Timetag
			d: 64bit IEE754 float
			S: alternate string
			c: ASCII-charakter sent as 32bit
			r: 32bit RBGA color
			m 4byte midi message
			T: TRUE (* no bytes in argument data *)
			F: FALSE (* dito *)
			N: NIL (* dito *)
			I: Infinitum (* dito *)
			[, ]: begin & end of data		<= *** This type isn't yet implemented *** *)

		(* int64: OSC Type Tag 'h' *)
		OSCParamInteger64* = OBJECT(OSCParamObject)
			VAR
				integer: HUGEINT;
			PROCEDURE &InitInt64*(i: HUGEINT);
			BEGIN
				integer := i;
				tag := 'h';
			END InitInt64;
			PROCEDURE GetSize*(): LONGINT;
			BEGIN
				RETURN 8;
			END GetSize;
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			VAR
				l, h: LONGINT;
			BEGIN
				SYSTEM.GET(ADDRESSOF(integer)+H, h);
				Network.PutNet4(packet, pos, h); INC(pos, 4);
				SYSTEM.GET(ADDRESSOF(integer)+L, l);
				Network.PutNet4(packet, pos, l); INC(pos, 4);
			END export;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamInteger64 { '); KernelLog.HIntHex(integer, 16); KernelLog.String(' }'); KernelLog.Ln;
			END dump;
		END OSCParamInteger64;

		(* OSC-Timetag: OSC Type Tag 't' *)
		OSCParamTT* = OBJECT(OSCParamObject)
			VAR
				tt: OSCTimeTag;
			PROCEDURE &InitTT*(tt: OSCTimeTag);
			BEGIN
				ASSERT(tt # NIL);
				tag := 't';
			END InitTT;
			PROCEDURE GetSize*(): LONGINT;
			BEGIN
				RETURN tt.GetSize();
			END GetSize;
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			BEGIN
				tt.export(packet, pos);
			END export;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamTT { '); KernelLog.Ln;
				tt.dump(indent+1);
				indentDump(indent); KernelLog.String(' }'); KernelLog.Ln;
			END dump;
		END OSCParamTT;

		(* 64 double IEE754: OSC Type Tag 'd' *)
		OSCParamFloat64* = OBJECT(OSCParamObject)
			VAR
				float: LONGREAL;
			PROCEDURE &InitFloat64*(f: LONGREAL);
			BEGIN
				float := f;
				tag := 'd';
			END InitFloat64;
			PROCEDURE GetSize*(): LONGINT;
			BEGIN
				RETURN 8;
			END GetSize;
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			VAR
				l, h: LONGINT;
			BEGIN
				Reals.IntL(float, h, l);
				Network.PutNet4(packet, pos, h); INC(pos, 4);
				Network.PutNet4(packet, pos, l); INC(pos, 4);
			END export;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamFloat64 { '); KernelLog.String(' }'); KernelLog.Ln;
			END dump;
		END OSCParamFloat64;

		(* alternate type represented as OSC-string: OSC Type Tag 'S' *)
		OSCParamAltString* = OBJECT(OSCParamString)
			PROCEDURE &InitAltString*(s: String);
			BEGIN
				ASSERT(s # NIL);
				string := s;
				tag := 'S';
			END InitAltString;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamAltString { '); KernelLog.String(string^); KernelLog.String(' }'); KernelLog.Ln;
			END dump;
		END OSCParamAltString;

		(* an ASCII-Char: OSC Type Tag 'c' *)
		OSCParamChar* = OBJECT(OSCParamObject)
			VAR
				char: CHAR;
			PROCEDURE &InitChar*(c: CHAR);
			BEGIN
				char := c;
				tag := 'c';
			END InitChar;
			PROCEDURE GetSize*(): LONGINT;
			BEGIN
				RETURN 4;
			END GetSize;
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			BEGIN
				Network.PutNet4(packet, pos, ORD(char)); INC(pos, 4);
			END export;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamChar { '); KernelLog.Char(char); KernelLog.String(' }'); KernelLog.Ln;
			END dump;
		END OSCParamChar;

		(* 32bit RGBA color: OSC Type Tag 'r' *)
		OSCParamRGBAColor* = OBJECT(OSCParamAbsInteger);
			PROCEDURE &InitRGBAColor*(c: WMGraphics.Color);
			BEGIN
				tag := 'r';
				integer := c;
			END InitRGBAColor;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamRGBAColor { '); KernelLog.Int(integer, 4); KernelLog.String(' }'); KernelLog.Ln;
			END dump;
		END OSCParamRGBAColor;

		(* This 'abstract' class contains shared code for all types without argument data *)
		OSCParamEmpty = OBJECT(OSCParamObject)
			PROCEDURE GetSize*(): LONGINT;
			BEGIN
				RETURN 0;
			END GetSize;
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			END export;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamEmpty { }'); KernelLog.Ln;
			END dump;
		END OSCParamEmpty;

		(* True: OSC Type Tag 'T' *)
		OSCParamTrue* = OBJECT(OSCParamEmpty)
			PROCEDURE &InitTrue*;
			BEGIN
				tag := 'T';
			END InitTrue;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamTrue { }'); KernelLog.Ln;
			END dump;
		END OSCParamTrue;

		(* False: OSC Type Tag 'F' *)
		OSCParamFalse* = OBJECT(OSCParamEmpty)
			PROCEDURE &InitFalse*;
			BEGIN
				tag := 'F';
			END InitFalse;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamFalse { }'); KernelLog.Ln;
			END dump;
		END OSCParamFalse;

		(* Nil: OSC Type Tag 'N' *)
		OSCParamNil* = OBJECT(OSCParamEmpty)
			PROCEDURE &InitNil*;
			BEGIN
				tag := 'N';
			END InitNil;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamNil { }'); KernelLog.Ln;
			END dump;
		END OSCParamNil;

		(* Infinitum: OSC Type Tag 'I' *)
		OSCParamInf* = OBJECT(OSCParamEmpty)
			PROCEDURE &InitInf*;
			BEGIN
				tag := 'I';
			END InitInf;
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCParamNil { }'); KernelLog.Ln;
			END dump;
		END OSCParamInf;


		(* OSCTimeTag: Stores a OSC Time Tag
			IF imm is TRUE then this timetag represents the special case "immediately",
			otherwise the seconds since midnight January 1, 1900 are stored in seconds and the number of miliseconds (added to seconds)
			is stored in miliseconds.

			The Timetag can be set with the Set(..), SetLow(...) and the SetImmediatly-Functions. It can be read through the
			read-only members seconds, miliseconds and imm.

			The smallest precision of a OSC Time Tag is one milisecond, this is mainly due to restrictions of kerneltimers and networkingtimeouts.

			*)
		OSCTimeTag* = OBJECT
			VAR
				seconds-: LONGINT; (* seconds from 1st Jan 1900 *)
				miliseconds-: LONGINT; (* 0...999 *)
				imm-: BOOLEAN; (* immediate-flag *)
			PROCEDURE &Init*;
			BEGIN
				seconds := 0; miliseconds := 0; imm := FALSE;
			END Init;
			PROCEDURE GetSize*(): LONGINT; BEGIN RETURN 8; END GetSize;

			(* Sets the OSCTimeTag to the special case 'immediately' *)
			PROCEDURE SetImmediately*; BEGIN imm := TRUE; END SetImmediately;

			(* Sets the OSCTimeTag to the time described by seconds since January 1, 1900 and the miliseconds offset *)
			PROCEDURE Set*(sec, msec: LONGINT);
			BEGIN
				seconds := sec; miliseconds := msec MOD 1000; imm := FALSE;
			END Set;

			(* Sets the OSCTimeTag to the time represented with a Year, Month, ...
				Note: This function doesn't check if the date is really valid *)
			PROCEDURE SetLow*(year (* >=1900 *), month (* 1..12 *), day (* 1..31 *),
				hour (* 0..23 *), min (* 0..59 *), sec (* 0..59 *), msec (* 0..999 *): INTEGER);
			BEGIN
				seconds := TTGetSecondsLow(year, month, day, hour, min, sec);
				miliseconds := msec;
			END SetLow;

			(* Outputs the stored timetag *)
			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				IF imm THEN
					indentDump(indent); KernelLog.String('TT { imm: TRUE } '); KernelLog.Ln;
				ELSE
					indentDump(indent); KernelLog.String('TT { sec: ');
					KernelLog.Int(seconds, 12); KernelLog.String('('); KernelLog.Hex(seconds, 1); KernelLog.String(') ');
					KernelLog.String(' msec: '); KernelLog.Int(miliseconds, 4); KernelLog.String(' }'); KernelLog.Ln;
				END;
			END dump;

			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			VAR
				i: LONGINT;
				fraction: LONGINT;
			BEGIN
				IF imm THEN
					FOR i := 0 TO 6 DO
						packet[pos+i] := 0X;
					END;
					packet[pos+7] := CHR(1);
				ELSE
					Network.PutNet4(packet, pos, seconds);
					fraction := miliseconds * OSCTimeTagOneMS;
					Network.PutNet4(packet, pos+4, fraction);
				END;
				INC(pos, 8);
			END export;
		END OSCTimeTag;

		(* Common superclass of OSCMessage and OSCBundle.
			Used to build arrays, which elements are either a OSCMessage or an OSCBundle.
			Contains also code to support shared functionality.

			When a packet is received from the network, the responsible networkplugin registers a handler
			to return a packet to the sender with the SetReturner(..) procedure. When a returner is registred
			it's possible to send packets back to the sender with the Return(..) procedure.

			Note: Although its possible, you should never inctance an object of this type! *)
		OSCPacket* = OBJECT
			VAR
				bytearray: String;

				returner: OSCReturnProc;
				returnerdata: OBJECT; (* The networkplugin can register also some data with the returner, which is included in the call to
					the returner *)

			PROCEDURE &Init*;
			BEGIN
				bytearray := NIL;
				returner := NIL; returnerdata:= NIL;
			END Init;

			(* This 'abstract' function is used to calculate the size of the binary representation of OSCPackets. *)
			PROCEDURE GetSize*(): LONGINT; BEGIN HALT(WrngClassUsedOrFunNotOverl); END GetSize;
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR position: LONGINT); BEGIN HALT(WrngClassUsedOrFunNotOverl); END export;

			PROCEDURE GetBytes*(): String; (* returns the binary representation of this OSCPacket. *)
			BEGIN
				assemble();
				RETURN bytearray;
			END GetBytes;

			PROCEDURE IsReturnable*(): BOOLEAN; (* returns true, iff it's possible to return a OSCPacket to the sender *)
			BEGIN
				RETURN returner # NIL;
			END IsReturnable;
			PROCEDURE Return*(p: OSCPacket): LONGINT; (* returns the packet p to the sender of the current packet *)
			BEGIN
				IF returner # NIL THEN
					RETURN returner(p, returnerdata);
				ELSE
					RETURN -1;
				END;
			END Return;

			(* registers a returner, overloaded in OSCBundle to register it also to all members of an OSCBundle *)
			PROCEDURE SetReturner*(s: OSCReturnProc; data: OBJECT);
			BEGIN
				returner := s;
				returnerdata := data;
			END SetReturner;

			PROCEDURE dump*(indent: LONGINT);
			BEGIN
				indentDump(indent); KernelLog.String('OSCPacket { bytearray: ');
				KernelLog.Buffer(bytearray^, 0, LEN(bytearray^)); KernelLog.String(' }'); KernelLog.Ln;
			END dump;

			PROCEDURE assemble;
				VAR
					p: LONGINT;
			BEGIN
				NEW(bytearray, GetSize());
				ASSERT(bytearray # NIL);
				p := 0;
				export(bytearray^, p);
			END assemble;

		END OSCPacket;

		OSCPacketArray* = POINTER TO ARRAY OF OSCPacket;

		(* signature of return procedures *)
		OSCReturnProc* = PROCEDURE {DELEGATE} (p: OSCPacket; data: OBJECT): LONGINT;


		(* OSCMessage stores a single OSCMessage *)
		OSCMessage* = OBJECT(OSCPacket)
			VAR
				address-: String;
				argumentcount-: INTEGER;
				arguments-: ParamArray;
				noTypeTagString-: BOOLEAN; (* is TRUE, iff the received packet doesn't contain an OSC Type Tag String *)
				argumentData-: Blob; (* this holds all the argument data, if noTypeTagString is TRUE *)
			PROCEDURE &InitMessage*(adr: String);
			BEGIN
				Init();
				address := adr;
				NEW(arguments, OSCMessageDefaultArgsCount);
				argumentcount := 0;
				noTypeTagString := FALSE;
				argumentData := NIL;
			END InitMessage;

			(* Used internally to increase the size of the arguments-array. *)
			PROCEDURE grow;
			VAR
				newargs: ParamArray;
				i: INTEGER;
			BEGIN
				NEW(newargs, LEN(arguments)*2);
				FOR i:=0 TO argumentcount-1 DO
					newargs[i] := arguments[i];
				END;
				arguments := newargs;
			END grow;

			(* GetSize() returns the length of the binary representation of this OSCMessage in bytes.
				The binary representation of this OSCMessage consists of:
					adr: OSCString;
					osctypetagstring: OSCString;
					"the argument data"
				or if noTypeTagString = TRUE
					adr: OSCString;
					"the argument data"
			*)
			PROCEDURE GetSize*(): LONGINT;
			VAR
				i, argsize: LONGINT;
			BEGIN
				argsize := 0;
				FOR i:=0 TO argumentcount-1 DO
					argsize := argsize + arguments[i].GetSize();
				END;
				IF noTypeTagString THEN
					ASSERT(argumentData # NIL);
					RETURN oscStrSize(address)+LEN(argumentData);
				ELSE
					RETURN
						oscStrSize(address)+
						padsize(1+argumentcount+1)+
						argsize;
				END;
			END GetSize;

			(* AddArgument adds a new Argument to the OSCMessage *)
			PROCEDURE AddArgument*(a: OSCParamObject);
			BEGIN
				IF argumentcount = LEN(arguments) THEN grow; END;
				arguments[argumentcount] := a;
				INC(argumentcount);
			END AddArgument;

			(* exports the binary representation of this OSCMessage to packet[pos..pos+GetSize()-1] *)
			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			VAR
				i: LONGINT;
			BEGIN
				exportString(address, packet, pos);
				IF noTypeTagString THEN
					FOR i:=0 TO LEN(argumentData)-1 DO
						packet[pos+i] := argumentData[i];
					END;
					INC(pos, LEN(argumentData));
					RETURN;
				END;
				(* ,arg-tags*)
				packet[pos] := ','; INC(pos);
				FOR i:=0 TO argumentcount-1 DO
					ASSERT(arguments[i] # NIL);
					packet[pos] := arguments[i].tag; INC(pos);
				END;
				i := argumentcount+1;
				WHILE (i MOD 4) # 0 DO
					packet[pos] := 0X; INC(i); INC(pos);
				END;
				(* arguments *)
				FOR i := 0 TO argumentcount-1 DO
					arguments[i].export(packet, pos);
				END;
			END export;

			PROCEDURE dump*(indent: LONGINT);
				VAR i: LONGINT;
			BEGIN
				indentDump(indent); KernelLog.String('OSCMessage { address: '); KernelLog.String(address^); KernelLog.String(' noTypeTagString: ');
				KernelLog.Boolean(noTypeTagString); KernelLog.Ln;
				FOR i:=0 TO argumentcount-1 DO
					arguments[i].dump(indent+1);
				END;
				IF noTypeTagString THEN
					indentDump(indent); KernelLog.String(' argumentData: '); KernelLog.Buffer(argumentData^, 0, LEN(argumentData^));
				END;
				indentDump(indent); KernelLog.String('}'); KernelLog.Ln;
			END dump;
		END OSCMessage;

		(* OSC Bundle stores a bundle of OSC Messages *)
		OSCBundle* = OBJECT(OSCPacket)
			VAR
				timetag-: OSCTimeTag;
				messages-: OSCPacketArray;
				messagescount-: INTEGER;
			PROCEDURE &InitBundle*(tt: OSCTimeTag; msgs: OSCPacketArray; msgcount: INTEGER);
			BEGIN
				Init();
				timetag := tt;
				messages := msgs;
				IF messages = NIL THEN
					NEW(messages, OSCBundleDefaultMsgCount);
					messagescount := 0;
				ELSE
					messagescount := msgcount;
				END;
			END InitBundle;

			PROCEDURE AddPacket*(p: OSCPacket);
			BEGIN
				IF LEN(messages) = messagescount THEN grow; END;
				messages[messagescount] := p;
				INC(messagescount);
			END AddPacket;
			PROCEDURE GetSize*(): LONGINT;
			VAR
				s: LONGINT;
				i: INTEGER;
			BEGIN (* '#bundle' 8, timetag: 8, bundle elements ( := size + packet ) *)
				s := 16;
				FOR i:= 0 TO messagescount-1 DO
					INC(s, messages[i].GetSize()+4);
				END;
				RETURN s;
			END GetSize;
			PROCEDURE IsBeforeEqual*(rhs: OSCBundle): BOOLEAN;
			BEGIN
				RETURN TTSmaller(SELF.timetag, rhs.timetag) OR TTEqual(SELF.timetag, rhs.timetag);
			END IsBeforeEqual;
			PROCEDURE IsBefore*(rhs: OSCBundle): BOOLEAN;
			BEGIN
				RETURN TTSmaller(SELF.timetag, rhs.timetag);
			END IsBefore;

			(* Note: This function uses Objects.ticks to get a 'exact' systemtime.
				It calculates the seconds since midnight Jan 1, 1900 with SysStartSeconds plus the offset with Objects.ticks.
				If the Timeout of a packet in miliseconds is greather then it can be expressed in an positive LONGINT, a
				maximal timeout of MAX(LONGINT) DIV 1000 is used. *)
			PROCEDURE GetTimeout*(): LONGINT; (* timeout in ms from now *)
			VAR
				nowseconds, nowms: LONGINT;
				ticks: LONGINT;
				diff, diffms: LONGINT;
				overflowdiff: LONGINT;
				timeout: LONGINT;
			BEGIN
				IF timetag.imm THEN RETURN 0 END;
				ticks := Kernel.GetTicks ();
				IF (ticks > 0) # TicksArePositive THEN updateBootup; END;
				nowseconds := SysStartSeconds + (ticks DIV Kernel.Second);
				IF Trace THEN KernelLog.String('GetTimeout.nowseconds '); KernelLog.Hex(nowseconds, 4); KernelLog.Ln; END;
				nowms := ((ticks MOD Kernel.Second) * 1000) DIV Kernel.Second;
				IF Trace THEN KernelLog.String('GetTimeout.nowms '); KernelLog.Int(nowms, 4); KernelLog.Ln;END;
				overflowdiff := MAX(LONGINT) DIV 1000;
				diff := timetag.seconds - nowseconds;
				diffms := timetag.miliseconds - nowms;
				IF diff < 0 THEN RETURN 0; END;
				IF Trace THEN KernelLog.String('GetTimeout.diff '); KernelLog.Int(diff, 4); KernelLog.Ln;END;
				IF Trace THEN KernelLog.String('GetTimeout.diffms '); KernelLog.Int(diffms, 4); KernelLog.Ln;END;
				IF(diffms < 0) THEN DEC(diff); diffms := diffms MOD 1000; END;
				IF (diff >= overflowdiff-1) THEN
					diff := overflowdiff-1;
				END;
				IF Trace THEN KernelLog.String('GetTimeout.diff '); KernelLog.Int(diff, 4); KernelLog.Ln;END;
				IF Trace THEN KernelLog.String('GetTimeout.diffms '); KernelLog.Int(diffms, 4); KernelLog.Ln;END;
				timeout := diff*1000+diffms;
				IF timeout < 0 THEN RETURN 0; END;
				RETURN diff*1000+diffms;
			END GetTimeout;

			(* registers the returner also to all submessages or subbundles *)
			PROCEDURE SetReturner*(s: OSCReturnProc; data: OBJECT);
			VAR
				i: LONGINT;
			BEGIN
				SetReturner^(s, data);
				FOR i:=0 TO messagescount-1 DO
					messages[i].SetReturner(s, data);
				END;
			END SetReturner;

			PROCEDURE dump*(indent: LONGINT);
			VAR
				i: LONGINT;
			BEGIN
				indentDump(indent); KernelLog.String('OSCBundle { timetag: '); timetag.dump(indent+1); KernelLog.String(' packets(');
				KernelLog.Int(messagescount, 1); KernelLog.String(')'); KernelLog.Ln;
				FOR i:=0 TO messagescount-1 DO
					messages[i].dump(indent+1);
				END;
				indentDump(indent); KernelLog.String('}'); KernelLog.Ln;
			END dump;

			PROCEDURE export(VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
			VAR
				i: INTEGER;
			BEGIN
				exportString(OSCBundleIdent, packet, pos);
				timetag.export(packet, pos);
				FOR i := 0 TO messagescount-1 DO
					Network.PutNet4(packet, pos, messages[i].GetSize()); INC(pos, 4);
					messages[i].export(packet, pos);
				END;
			END export;

			(* Used internally to increase the size of the messages-array. *)
			PROCEDURE grow;
			VAR
				newmsgs: OSCPacketArray;
				i: LONGINT;
			BEGIN
				NEW(newmsgs, 2*LEN(messages));
				FOR i:=0 TO LEN(messages)-1 DO
					newmsgs[i] := messages[i];
				END;
				messages := newmsgs;
			END grow;
		END OSCBundle;

	(* helper for indentation of the dump()-function *)
	PROCEDURE indentDump(i: LONGINT);
	VAR
		a: LONGINT;
	BEGIN
		FOR a:=1 TO i DO KernelLog.String('  '); END;
	END indentDump;

	(* Helper for the usage of OSCTimeTag objects *)

	(* Returns the number of seconds since midnight January 1, 1900 until now
		Note: This function doesn't honor the users current timezone.
		Note: The timezone of a timetag isn't specified in the OSC specification v 1.0 by Matt Wright*)
	PROCEDURE TTGetSecondsNow*(): LONGINT;
		VAR year, month, day, hour,minute, second: INTEGER;
		date, time: LONGINT;
	BEGIN
		Clock.Get(time, date);
		hour := SHORT((time DIV 4096) MOD 32);
		minute := SHORT((time DIV 64) MOD 64);
		second := SHORT(time MOD 64);
		year := 1900+SHORT(date DIV 512);
		month := SHORT((date DIV 32) MOD 16);
		day := SHORT(date MOD 32);
		IF Trace THEN KernelLog.String('TTGetSecondsNow(');KernelLog.Int(year, 4); KernelLog.Int(month, 4); KernelLog.Int(day, 4); KernelLog.Int(hour, 4);
			KernelLog.Int(minute, 4); KernelLog.Int(second, 4); KernelLog.String(')'); KernelLog.Ln; END;
		RETURN TTGetSecondsLow(year, month, day, hour, minute, second);
	END TTGetSecondsNow;

	(* Returns the number of seconds from midnight January 1, 1900 to the specified date and time *)
	PROCEDURE TTGetSecondsLow*(year (* >=1900 *), month (* 1..12 *), day (* 1..31 *),
		hour (* 0..23 *), min (* 0..59 *), sec (* 0..59 *): INTEGER): LONGINT;
	VAR
		days, seconds: LONGINT;
		i: INTEGER;
	BEGIN
		days := 0;
		FOR i := 1900 TO year-1 DO
			IF Dates.LeapYear(i) THEN INC(days); END;
		END;
		INC(days, (LONG(year)-1900)*365);  (* years *)
		INC(days, MonthToDays[month-1]); (* months *)
		IF Dates.LeapYear(year) & (month > 2) THEN INC(days); END;
		INC(days, day-1); (* days *)
		seconds := ((days*24 + hour)*60 + min)*60 + sec;
		RETURN seconds;
	END TTGetSecondsLow;

	(* tests if the timetags of a and b are equal *)
	PROCEDURE TTEqual*(a,b: OSCTimeTag): BOOLEAN;
	BEGIN
		ASSERT(a # NIL); ASSERT(b # NIL);
		IF (a.imm = TRUE) & (b.imm = TRUE) THEN RETURN TRUE; END;
		IF (a.imm = TRUE) OR (b.imm = TRUE) THEN RETURN FALSE; END;
		RETURN (a.seconds = b.seconds) & (a.miliseconds = b.miliseconds);
	END TTEqual;

	(* returns TRUE iff the timetag of a is smaller than the timetag of b *)
	PROCEDURE TTSmaller*(a,b: OSCTimeTag): BOOLEAN;
	BEGIN
		ASSERT(a # NIL); ASSERT(b # NIL);
		IF (a.imm = TRUE) & (b.imm = FALSE) THEN RETURN TRUE; END;
		IF b.imm = TRUE THEN RETURN FALSE; END;
		RETURN (a.seconds < b.seconds) OR ((a.seconds = b.seconds) & (a.miliseconds < b.miliseconds));
	END TTSmaller;

	(* returns TRUE iff the timetag of a is greather than the timetag of b *)
	PROCEDURE TTGreather*(a,b: OSCTimeTag): BOOLEAN;
	BEGIN
		RETURN TTSmaller(b,a);
	END TTGreather;

	(* The following ParseOSC*-functions are used to parse an OSCPacket or an OSCMessage.
	The newtorkplugins use this function to translate a binary represenation of a packet to a corresponding
	object.

	Note: This is the only parsing function which is accessible from other modules.

	This function parses the packet in data[0..endofs-1]. It returns the corresponding object or NIL if a
	parse error occured. *)
	PROCEDURE ParseOSCPacket*(VAR data: ARRAY OF CHAR; endofs: LONGINT): OSCPacket;
	VAR
		ofs: LONGINT;
	BEGIN
		IF Trace THEN
			KernelLog.String('ParseOSCPacket started'); KernelLog.Ln;
			KernelLog.Buffer(data, 0, endofs); KernelLog.Ln;
		END;
		ofs := 0;
		RETURN parseOSCPacketInt(data, ofs, endofs);
	END ParseOSCPacket;

	(* parses a packet in data[ofs..endofs-1] (the size of the packet is endofs-ofs).
	Note: Since ofs is a VAR parameter, it will also be adjusted in calling functions! *)
	PROCEDURE parseOSCPacketInt(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCPacket;
	VAR
		p: OSCPacket;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCPacketInt: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		(* size not a multiple of 4 *)
		IF (endofs-ofs) MOD 4 # 0 THEN RETURN NIL; END;
		IF Trace THEN KernelLog.String('size MOD 4 = 0 is ok'); KernelLog.Ln; END;
		IF Strings.StartsWith(OSCBundleIdent^, ofs, data) THEN
			p := parseOSCBundle(data, ofs, endofs);
		ELSE
			p := parseOSCMessage(data, ofs, endofs);
		END;
		IF Trace THEN KernelLog.String('parseOSCPacketInt: '); IF p = NIL THEN KernelLog.String(' parsing message of bundle failed '); END;
			KernelLog.String(' ofs is now:'); KernelLog.Int(ofs, 4); KernelLog.Ln; END;
		(* Not all data parsed *)
		IF ofs # endofs THEN RETURN NIL; END;
		RETURN p;
	END parseOSCPacketInt;

	PROCEDURE parseOSCBundle(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCBundle;
	VAR
		b: OSCBundle;
		p: OSCPacket;
		tt: OSCTimeTag;
		packetsize: LONGINT;
		packetendofs: LONGINT;
		i: LONGINT;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCBundle: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		(* #bundle || tt || { size || message } *)
		IF endofs-ofs < 16 THEN RETURN NIL; END;
		IF ~ skipAndCheckOSCString(data, ofs, ofs+8) THEN RETURN NIL END;
		tt := parseOSCTT(data, ofs);
		NEW(b, tt, NIL, 0);
		WHILE (ofs+4) < endofs DO
			packetsize := Network.GetNet4(data, ofs); INC(ofs, 4);
			packetendofs := ofs+packetsize;
			IF packetendofs > endofs THEN RETURN NIL END;
			p := parseOSCPacketInt(data, ofs, packetendofs);
			IF p = NIL THEN RETURN NIL END;
			ASSERT(ofs = packetendofs);
			b.AddPacket(p);
		END;
		IF ofs # endofs THEN RETURN NIL; END;
		(* Check bundle TimeTags *)
		FOR i:=0 TO b.messagescount-1 DO
			p := b.messages[i];
			IF p IS OSCBundle THEN
				WITH p: OSCBundle DO
					IF TTSmaller(p.timetag, b.timetag) THEN
						IF Trace THEN KernelLog.String('parseOSCBundle: Timetag in a enclosed bundle is smaller then the enclosing timetag');
							KernelLog.Ln; END;
						RETURN NIL;
					END;
				END;
			END;
		END;
		RETURN b;
	END parseOSCBundle;

	PROCEDURE parseOSCTT(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT): OSCTimeTag;
	VAR
		tt: OSCTimeTag;
		sec, fraction, msec: LONGINT;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCTT: '); KernelLog.Int(ofs, 4); KernelLog.Ln; END;
		NEW(tt);
		sec := Network.GetNet4(data, ofs);
		fraction := Network.GetNet4(data, ofs+4);
		INC(ofs, 8);
		(* fraction is signed :( *)
		IF (sec = 0) & (fraction = 1) THEN
			tt.SetImmediately(); RETURN tt;
		END;
		msec := 0;
		IF fraction < 0 THEN
			fraction := - fraction;
			msec := 1000 - (fraction DIV OSCTimeTagOneMS);
			IF msec = 1000 THEN INC(sec); msec := 0; END;
		ELSE
			msec := fraction DIV OSCTimeTagOneMS;
		END;
		tt.Set(sec, msec);
		RETURN tt;
	END parseOSCTT;

	PROCEDURE parseOSCParamInteger(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCParamInteger;
	VAR
		p: OSCParamInteger;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCParamInteger: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		IF (ofs+4) > endofs THEN RETURN NIL END;
		NEW(p, Network.GetNet4(data, ofs)); INC(ofs, 4);
		RETURN p;
	END parseOSCParamInteger;

	PROCEDURE parseOSCParamFloat(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCParamFloat;
	VAR
		p: OSCParamFloat;
		i: LONGINT;
	BEGIN
		IF (ofs+4) > endofs THEN RETURN NIL END;
		i := Network.GetNet4(data, ofs); INC(ofs, 4);
		NEW(p, Reals.Real(i));
		RETURN p;
	END parseOSCParamFloat;

	PROCEDURE parseOSCParamString(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCParamString;
	VAR
		p: OSCParamString;
		s: String;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCParamString: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		s := importString(data, ofs, endofs);
		IF s = NIL THEN RETURN NIL END;
		NEW(p, s);
		RETURN p;
	END parseOSCParamString;

	PROCEDURE parseOSCParamBlob(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCParamBlob;
	VAR
		p: OSCParamBlob;
		b: Blob;
		size, i: LONGINT;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCParamBlob: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		IF (ofs+4) > endofs THEN RETURN NIL END;
		size := Network.GetNet4(data, ofs); INC(ofs, 4);
		IF (ofs+size) > endofs THEN RETURN NIL END;
		NEW(b, size);
		FOR i:=0 TO size-1 DO b[i] := data[ofs+i]; END; INC(ofs, size);
		NEW(p, b, size);
		RETURN p;
	END parseOSCParamBlob;

	PROCEDURE parseOSCParamInteger64(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCParamInteger64;
	VAR
		p: OSCParamInteger64;
		h, l: LONGINT;
		bigint: HUGEINT;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCParamInteger64: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		IF (ofs+8) > endofs THEN RETURN NIL END;
		h := Network.GetNet4(data, ofs); INC(ofs, 4);
		l := Network.GetNet4(data, ofs); INC(ofs, 4);
		SYSTEM.PUT(ADDRESSOF(bigint)+H, h);
		SYSTEM.PUT(ADDRESSOF(bigint)+L, l);
		NEW(p, bigint);
		RETURN p;
	END parseOSCParamInteger64;

	PROCEDURE parseOSCParamTT(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCParamTT;
	VAR
		tt: OSCTimeTag;
		p: OSCParamTT;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCParamTT: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		IF (ofs+8) > endofs THEN RETURN NIL END;
		tt := parseOSCTT(data, ofs);
		IF tt = NIL THEN RETURN NIL; END;
		NEW(p, tt);
		RETURN p;
	END parseOSCParamTT;

	PROCEDURE parseOSCParamFloat64(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCParamFloat64;
	VAR
		p: OSCParamFloat64;
		h,l: LONGINT;
		f: LONGREAL;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCParamFloat64: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		IF (ofs+8) > endofs THEN RETURN NIL END;
		h := Network.GetNet4(data, ofs); INC(ofs, 4);
		l := Network.GetNet4(data, ofs); INC(ofs, 4);
		f := Reals.RealL(h, l);
		NEW(p, f);
		RETURN p;
	END parseOSCParamFloat64;

	PROCEDURE parseOSCParamAltString(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCParamString;
	VAR
		p: OSCParamAltString;
		s: String;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCParamAltString: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		s := importString(data, ofs, endofs);
		IF s = NIL THEN RETURN NIL END;
		NEW(p, s);
		RETURN p;
	END parseOSCParamAltString;

	PROCEDURE parseOSCParamChar(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCParamChar;
	VAR
		p: OSCParamChar;
		i: LONGINT;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCParamChar: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		IF (ofs+4) > endofs THEN RETURN NIL END;
		i := Network.GetNet4(data, ofs); INC(ofs, 4);
		NEW(p, CHR(i));
		RETURN p;
	END parseOSCParamChar;

	PROCEDURE parseOSCParamRGBAColor(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCParamRGBAColor;
	VAR
		p: OSCParamRGBAColor;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCParamRGBAColor: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		IF (ofs + 4) > endofs THEN RETURN NIL END;
		NEW(p, Network.GetNet4(data, ofs)); INC(ofs, 4);
		RETURN p;
	END parseOSCParamRGBAColor;

	PROCEDURE parseOSCParams(adr: String; VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCMessage;
	VAR
		argstrofs: LONGINT;
		m: OSCMessage;
		param: OSCParamObject;
		T: OSCParamTrue;
		F: OSCParamFalse;
		N: OSCParamNil;
		I: OSCParamInf;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCParams: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		NEW(m, adr);
		(* check argumentstring *)
		argstrofs := ofs;
		IF ~ skipAndCheckOSCString(data, ofs, endofs) THEN RETURN NIL END;
		INC(argstrofs); (* skip , *)
		IF Trace THEN KernelLog.String('first parametertype at index: '); KernelLog.Int(argstrofs, 4); KernelLog.Ln; END;
		WHILE data[argstrofs] # 0X DO
			CASE data[argstrofs] OF
				'i':	param := parseOSCParamInteger(data, ofs, endofs);
			|	'f':	param := parseOSCParamFloat(data, ofs, endofs);
			|	's':	param := parseOSCParamString(data, ofs, endofs);
			|	'b':	param := parseOSCParamBlob(data, ofs, endofs);
			|	'h':	param := parseOSCParamInteger64(data, ofs, endofs);
			|	't':	param := parseOSCParamTT(data, ofs, endofs);
			|	'd':	param := parseOSCParamFloat64(data, ofs, endofs);
			|	'S':	param := parseOSCParamAltString(data, ofs, endofs);
			|	'c':	param := parseOSCParamChar(data, ofs, endofs);
			|	'r':	param := parseOSCParamRGBAColor(data, ofs, endofs);
			|	'T':	NEW(T); param := T;
			|	'F':	NEW(F); param := F;
			|	'N':	NEW(N); param := N;
			|	'I':	NEW(I); param := I;
			ELSE
				(* discard message *)
				KernelLog.String('Unknown OSC-Argumenttype: '); KernelLog.Char(data[argstrofs]); KernelLog.Ln;
				RETURN NIL;
			END;
			IF param = NIL THEN RETURN NIL; END;
			m.AddArgument(param);
			INC(argstrofs);
		END;
		IF Trace THEN KernelLog.String('parseOSCParams ended with ofs '); KernelLog.Int(ofs, 4); KernelLog.Ln; END;
		RETURN m;
	END parseOSCParams;

	PROCEDURE parseOSCMessage(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): OSCMessage;
	VAR
		adr: String;
		argumentofs: LONGINT;
		m: OSCMessage;
		i: LONGINT;
	BEGIN
		IF Trace THEN KernelLog.String('parseOSCMessage: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		(* address [ || typetagstring ] || argumentdata *)
		adr := importString(data, ofs, endofs);
		IF adr = NIL THEN RETURN NIL END;
		IF ~ CheckOSCAdrPattern(adr) THEN RETURN NIL END;
		IF Trace THEN KernelLog.String('address parsed: '); KernelLog.String(adr^); KernelLog.Ln; END;
		(* check if typetagstring is there *)
		IF (data[ofs] = ',') THEN
			(* there seems to be a typetagstring *)
			argumentofs := ofs;
			m := parseOSCParams(adr, data, argumentofs, endofs);
			(* if there is something parsed, return it *)
			IF (m # NIL) & (argumentofs = endofs) THEN
				ofs := argumentofs; (* argumentofs was used as positional parameter, therfore also adjust ofs now *)
				RETURN m
			END;
			IF Trace THEN KernelLog.String('parseOSCParams falied... returned ofs: '); KernelLog.Int(argumentofs, 4); KernelLog.Ln;
				IF m = NIL THEN KernelLog.String('but returned message is NIL'); KernelLog.Ln; END; END;
		END;
		IF Trace THEN KernelLog.String('parsing of typetag failed (or no typetag there)'); KernelLog.Ln; END;
		(* parsing of typetagstring failed or no typetagstring available *)
		NEW(m, adr);
		m.noTypeTagString := TRUE;
		NEW(m.argumentData, endofs-ofs);
		FOR i:=0 TO (endofs-ofs)-1 DO
			m.argumentData[i] := data[ofs+i];
		END;
		ofs := endofs;
		RETURN m;
	END parseOSCMessage;

	(* helpers *)
	PROCEDURE CheckOSCAdr*(adr: String): BOOLEAN;
	VAR
		i: LONGINT;
	BEGIN
		ASSERT(adr # NIL);
		i := 0;
		WHILE (i < LEN(adr)) & (adr[i] # 0X) DO
			IF (ORD(adr[i]) < 32) OR (ORD(adr[i]) > 126) THEN RETURN FALSE; END;
			CASE ORD(adr[i]) OF
				32, 35, 42, 44, 63, 91, 93, 123, 125:
					RETURN FALSE;
			ELSE
				(* do nothing *)
			END;
			INC(i);
		END;
		IF i = LEN(adr) THEN RETURN FALSE; END;
		IF adr[0] # '/' THEN RETURN FALSE; END;
		RETURN TRUE;
	END CheckOSCAdr;

	PROCEDURE CheckOSCAdrPattern*(adr: String): BOOLEAN;
	VAR
		i: LONGINT;
	BEGIN
		ASSERT(adr # NIL);
		i := 0;
		WHILE (i < LEN(adr)) & (adr[i] # 0X) DO
			IF (ORD(adr[i]) < 32) OR (ORD(adr[i]) > 126) THEN RETURN FALSE; END;
			CASE ORD(adr[i]) OF
				32, 35:
					RETURN FALSE;
			ELSE
				(* do nothing *)
			END;
			INC(i);
		END;
		IF i = LEN(adr) THEN RETURN FALSE; END;
		IF adr[0] # '/' THEN RETURN FALSE; END;
		RETURN TRUE;
	END CheckOSCAdrPattern;


	PROCEDURE skipAndCheckOSCString(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): BOOLEAN;
	BEGIN
		IF Trace THEN KernelLog.String('skipAndCheckOSCString: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		WHILE (ofs < endofs) & (data[ofs] # 0X) DO INC(ofs); END;
		(* string too long! *)
		IF ofs = endofs THEN 	IF Trace THEN KernelLog.String('string is too long!'); KernelLog.Ln; END; RETURN FALSE; END;
		INC(ofs);
		(* check and skip pad bytes *)
		WHILE (ofs MOD 4) # 0 DO
			IF data[ofs] # 0X THEN RETURN FALSE; END;
			INC(ofs);
		END;
		IF Trace THEN KernelLog.String('offset after padding: '); KernelLog.Int(ofs,4); KernelLog.Ln; END;
		RETURN TRUE;
	END skipAndCheckOSCString;

	(* helper function to import an OSCString - checks also the extra padding 0X characters *)
	PROCEDURE importString(VAR data: ARRAY OF CHAR; VAR ofs: LONGINT; endofs: LONGINT): String;
	VAR
		pos: LONGINT;
		s: String;
	BEGIN
		IF Trace THEN KernelLog.String('importString: '); KernelLog.Int(ofs, 4); KernelLog.Int(endofs, 4); KernelLog.Ln; END;
		pos := ofs;
		WHILE (pos < endofs) & (data[pos] # 0X) DO
			INC(pos);
		END;
		IF data[pos] # 0X THEN RETURN NIL END;
		IF Trace THEN KernelLog.String('end of string: '); KernelLog.Int(pos, 4); KernelLog.Ln; END;
		NEW(s, pos-ofs+1);
		Strings.Copy(data, ofs, pos-ofs+1, s^);
		IF Trace THEN KernelLog.String('copied string: '); KernelLog.String(s^); KernelLog.Ln; END;
		ofs := pos+1;
		WHILE (ofs MOD 4) # 0 DO
			IF data[ofs] # 0X THEN RETURN NIL END;
			INC(ofs);
		END;
		IF Trace THEN KernelLog.String('ofset after padding: '); KernelLog.Int(ofs, 4); KernelLog.Ln; END;
		RETURN s;
	END importString;

	PROCEDURE padsize(i: LONGINT): LONGINT;
	BEGIN
		CASE i MOD 4 OF
			0:	RETURN i; (* size is ok *)
		|	1:	RETURN i+3;
		|	2:	RETURN i+2;
		|	3:	RETURN i+1;
		END;
	END padsize;

	(* returns the length of the exported OSCString of s *)
	PROCEDURE oscStrSize(s: String): LONGINT;
	BEGIN
		ASSERT(s # NIL );
		RETURN padsize(Strings.Length(s^)+1);
	END oscStrSize;

	(* exports an string s to packet[pos..pos+oscstrlen(s)-1] *)
	PROCEDURE exportString(s: String; VAR packet: ARRAY OF CHAR; VAR pos: LONGINT);
	VAR
		i, length: LONGINT;
	BEGIN
		length := oscStrSize(s);
		i := 0;
		WHILE (i < length) & (s[i] # 0X) DO
			packet[pos+i] := s[i];
			INC(i);
		END;
		FOR i := i TO length-1 DO
			packet[pos+i] := 0X;
		END;
		INC(pos, length);
	END exportString;


(* This function have been used for testing during the development of this module *)
	PROCEDURE Test*;
	VAR
		a: ParamArray;
		b: OSCParamInteger;
		c: OSCParamString;
	BEGIN
		NEW(a, 4);
		KernelLog.Int(LEN(a), 4); KernelLog.Ln;
		NEW(b, 10);
		KernelLog.Int(b.integer, 4); KernelLog.Ln;
		NEW(c, Strings.NewString('abc'));
		KernelLog.Int(c.GetSize(), 4); KernelLog.Ln;
		NEW(c, Strings.NewString('abcd'));
		KernelLog.Int(c.GetSize(), 4); KernelLog.Ln;
		NEW(c, Strings.NewString('abcde'));
		KernelLog.Int(c.GetSize(), 4); KernelLog.Ln;
		NEW(c, Strings.NewString('abcdef'));
		KernelLog.Int(c.GetSize(), 4); KernelLog.Ln;
		NEW(c, Strings.NewString('abcdefgh'));
		KernelLog.Int(c.GetSize(), 4); KernelLog.Ln;
		KernelLog.String('OSC.Test done'); KernelLog.Ln;
	END Test;

	PROCEDURE TestGetSize*;
	VAR
		pi: OSCParamInteger;
		pf: OSCParamFloat;
		ps: OSCParamString;
		m: OSCMessage;
	BEGIN
		NEW(pi, 15);
		KernelLog.Int(pi.GetSize(), 4); KernelLog.Ln;
		NEW(pf, 1.52);
		KernelLog.Int(pf.GetSize(), 4); KernelLog.Ln;
		NEW(ps, Strings.NewString('12345'));
		KernelLog.Int(ps.GetSize(), 4);
		NEW(m, Strings.NewString('/abc/def/ghi'));
		m.AddArgument(pi);
		m.AddArgument(pf);
		m.AddArgument(ps);
		KernelLog.Int(m.GetSize(), 4); KernelLog.Ln;
		KernelLog.String('OSC.TestGetSize done'); KernelLog.Ln;
	END TestGetSize;

	PROCEDURE TestAssemble*;
	VAR
		pi: OSCParamInteger;
		pf: OSCParamFloat;
		m: OSCMessage;
		pli: OSCParamInteger64;
		plf: OSCParamFloat64;
		b: OSCBundle;
		tt: OSCTimeTag;
	BEGIN
		NEW(m, Strings.NewString('/abc/def/ghi'));
		m.assemble();
		KernelLog.Buffer(m.bytearray^, 0, LEN(m.bytearray^));KernelLog.Ln;KernelLog.Ln;KernelLog.Ln;
		NEW(pi, 12345678H); m.AddArgument(pi);
		NEW(pi, 12345679H); m.AddArgument(pi);
		NEW(pi, 1234567AH); m.AddArgument(pi);
		NEW(pf, 1.25); m.AddArgument(pf);
		NEW(plf, 5); m.AddArgument(plf);
		NEW(pli, 123456789ABCDEF0H); m.AddArgument(pli);
		m.assemble();
		KernelLog.Buffer(m.bytearray^, 0, LEN(m.bytearray^));KernelLog.Ln;KernelLog.Ln;KernelLog.Ln;
		NEW(tt); tt.SetLow(2005,12,26,12,1,1,123);
		NEW(b, tt, NIL, 0);
		b.AddPacket(m);
		NEW(m, Strings.NewString('/abc/xxx'));
		m.AddArgument(pi);
		b.AddPacket(m);
		b.assemble();
		KernelLog.Buffer(b.bytearray^, 0, LEN(b.bytearray^));KernelLog.Ln;KernelLog.Ln;KernelLog.Ln;
		tt.SetImmediately();
		b.assemble();
		KernelLog.Buffer(b.bytearray^, 0, LEN(b.bytearray^));KernelLog.Ln;KernelLog.Ln;KernelLog.Ln;
		KernelLog.String('OSC.TestAssemble done');
	END TestAssemble;

	PROCEDURE TestTT*;
	VAR
		t: OSCTimeTag;
	BEGIN
		KernelLog.String('OSC.TestTT'); KernelLog.Ln;
		NEW(t);
		t.SetLow(2005, 12, 26, 12, 1, 1, 123);
		KernelLog.String('2005/12/26/12/01/01.123: '); KernelLog.Hex(t.seconds, 10); KernelLog.Int(t.miliseconds, 4); KernelLog.Ln;
	END TestTT;

	PROCEDURE TestBundleTimeout*;
	VAR
		tt: OSCTimeTag;
		b: OSCBundle;
	BEGIN
		KernelLog.String('Bootup: '); KernelLog.Hex(SysStartSeconds, 10); KernelLog.Ln;
		KernelLog.String('Ticks: '); KernelLog.Hex(Kernel.GetTicks (), 10); KernelLog.Ln; KernelLog.Boolean(TicksArePositive); KernelLog.Ln;
		KernelLog.String('TTGetSecondsNow'); KernelLog.Hex(TTGetSecondsNow(), 10); KernelLog.Ln;
		 NEW(tt); tt.Set(TTGetSecondsNow()+1000, 0);
		 NEW(b,tt, NIL, 0);
		 KernelLog.String('GetTimeout: '); KernelLog.Int(b.GetTimeout(), 10); KernelLog.Ln;
		 NEW(tt); tt.SetLow(2006,01,25,10, 28,0,0);
		 NEW(b,tt, NIL, 0);
		 KernelLog.String('GetTimeout: '); KernelLog.Int(b.GetTimeout(), 10); KernelLog.Ln;
		 NEW(tt); tt.SetLow(2005,12,31,13, 28,0,0);
		 NEW(b,tt, NIL, 0);
		 KernelLog.String('GetTimeout: '); KernelLog.Int(b.GetTimeout(), 10); KernelLog.Ln;
	END TestBundleTimeout;

	PROCEDURE TestParser*;
	VAR
		pi: OSCParamInteger;
		pf: OSCParamFloat;
		m: OSCMessage;
		pli: OSCParamInteger64;
		plf: OSCParamFloat64;
		b: OSCBundle;
		tt: OSCTimeTag;
		p: OSCPacket;
	BEGIN
		NEW(m, Strings.NewString('/abc/def/ghi'));
		m.assemble();
		KernelLog.String('Parsing: ');KernelLog.Ln;
		KernelLog.Buffer(m.bytearray^, 0, LEN(m.bytearray^));KernelLog.Ln;KernelLog.Ln;KernelLog.Ln;
		p := ParseOSCPacket(m.bytearray^, LEN(m.bytearray^));
		IF p # NIL THEN KernelLog.String('parsing ok'); ELSE KernelLog.String('parsing failed'); END; KernelLog.Ln;
		NEW(pi, 12345678H); m.AddArgument(pi);
		NEW(pi, 12345679H); m.AddArgument(pi);
		NEW(pi, 1234567AH); m.AddArgument(pi);
		NEW(pf, 1.25); m.AddArgument(pf);
		NEW(plf, 5); m.AddArgument(plf);
		NEW(pli, 123456789ABCDEF0H); m.AddArgument(pli);
		m.assemble();
		KernelLog.String('Parsing: ');KernelLog.Ln;
		KernelLog.Buffer(m.bytearray^, 0, LEN(m.bytearray^));KernelLog.Ln;KernelLog.Ln;KernelLog.Ln;
		p := ParseOSCPacket(m.bytearray^, LEN(m.bytearray^));
		IF p # NIL THEN KernelLog.String('parsing ok'); ELSE KernelLog.String('parsing failed'); END; KernelLog.Ln;
		NEW(tt); tt.SetLow(2005,12,26,12,1,1,123);
		NEW(b, tt, NIL, 0);
		b.AddPacket(m);
		NEW(m, Strings.NewString('/abc/xxx'));
		m.AddArgument(pi);
		b.AddPacket(m);
		b.assemble();
		KernelLog.String('Parsing: ');KernelLog.Ln;
		KernelLog.Buffer(b.bytearray^, 0, LEN(b.bytearray^));KernelLog.Ln;KernelLog.Ln;KernelLog.Ln;
		p := ParseOSCPacket(b.bytearray^, LEN(b.bytearray^));
		IF p # NIL THEN KernelLog.String('parsing ok'); ELSE KernelLog.String('parsing failed'); END; KernelLog.Ln;
		tt.SetImmediately();
		b.assemble();
		KernelLog.String('Parsing: ');KernelLog.Ln;
		KernelLog.Buffer(b.bytearray^, 0, LEN(b.bytearray^));KernelLog.Ln;KernelLog.Ln;KernelLog.Ln;
		p := ParseOSCPacket(b.bytearray^, LEN(b.bytearray^));
		IF p # NIL THEN KernelLog.String('parsing ok'); ELSE KernelLog.String('parsing failed'); END; KernelLog.Ln;
		KernelLog.String('OSC.TestAssemble done');
	END TestParser;

	(* Calculates the 'bootup'-timestamp with the current timestamp and the elapsed ticks since bootup.
		This function is called from the module initializer. *)
	PROCEDURE calculateBootup;
		VAR
			nowseconds: LONGINT;
			ticks: LONGINT;
	BEGIN
		ticks := Kernel.GetTicks ();
		nowseconds := TTGetSecondsNow();
		TicksArePositive := ticks > 0;
		SysStartSeconds := nowseconds - (ticks DIV Kernel.Second);
	END calculateBootup;

	(* This function will be called from GetTimeout() to detect overflows of Objects.ticks *)
	PROCEDURE updateBootup;
		VAR
			ticks: LONGINT;
	BEGIN
		ticks := Kernel.GetTicks ();
		IF ticks > 0 THEN
			TicksArePositive := TRUE;
		ELSIF (ticks < 0) & TicksArePositive THEN
			(* Update Bootup *)
			IF Trace THEN KernelLog.String('updateBootup: SysStartSeconds now: '); KernelLog.Int(SysStartSeconds, 10);
				KernelLog.Hex(SysStartSeconds, 1); KernelLog.Ln; END;
			SysStartSeconds := SysStartSeconds + (1073741824 DIV (Kernel.Second DIV 4)); (* := INC(SysStartSeconds, 2**32/Seconds) *)
			TicksArePositive := FALSE;
			IF Trace THEN KernelLog.String('updateBootup: After update SysStartSeconds: '); KernelLog.Int(SysStartSeconds, 10);
				KernelLog.Hex(SysStartSeconds, 1); KernelLog.Ln; END;
		END;
	END updateBootup;

BEGIN
	MonthToDays[0] := 0; MonthToDays[1] := 31; MonthToDays[2] := 59; MonthToDays[3] := 90; MonthToDays[4] := 120;
	MonthToDays[5] := 151; MonthToDays[6] := 181; MonthToDays[7] := 212; MonthToDays[8] := 243;
	MonthToDays[9] :=  273; MonthToDays[10] := 304; MonthToDays[11] := 334; MonthToDays[12] := 365;
	OSCBundleIdent := Strings.NewString('#bundle');
	calculateBootup;
END OSC.

PC.Compile OSCStrings.Mod OSC.Mod OSCRegistry.Mod OSCQueue.Mod OSCService.Mod OSCNet.Mod OSCExample.Mod OSCEval.Mod~

SystemTools.Free OSCEval OSCExample OSCNet OSCService OSCQueue OSCRegistry OSC OSCUtilities ~

OSC.Test ~
OSC.TestGetSize ~
OSC.TestAssemble ~
OSC.TestTT ~
OSC.TestParser ~