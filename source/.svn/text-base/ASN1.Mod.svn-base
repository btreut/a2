MODULE ASN1; (** AUTHOR "Patrick Hunziker"; PURPOSE "ISO 8824/8825 standard tag/length/data encoding"; *)

(* ASN1(Abstract Syntax Notation One) is a standard that defines a formalism for the specification of abstract data types.

PROCEDURE Decode(ASN1Stream):Triplet produces a hierarchical tree with triple.next and triplet.child dependencies.*)

(*to do: correctly decode big integer numbers which do not fit into standard oberon types*)
(*to do for more general ASN1 implementation: bit strings of undefined length: see ftp://ftp.rsa.com/pub/pkcs/ascii/layman.asc; not needed for certifcates*)
(*refine standard OIDs as hex constants, for direct comparison*)
(*to do: encoding *)

IMPORT Streams;

CONST
Trace=FALSE;

(*ASN1 class*)
ASN1Universal*=0;
ASN1Application*=1;
ASN1Context*=2;
ASN1Private*=3;

(*
BER_TAG_UNKNOWN 0 
BER_TAG_BOOLEAN 1 
BER_TAG_INTEGER 2 
BER_TAG_BIT_STRING 3 
BER_TAG_OCTET_STRING 4 
BER_TAG_NULL 5 
BER_TAG_OID 6 
BER_TAG_OBJECT_DESCRIPTOR 7 
BER_TAG_EXTERNAL 8 
BER_TAG_REAL 9 
BER_TAG_ENUMERATED 10
  12 to 15 are reserved for future versions of the recommendation 
BER_TAG_PKIX_UTF8_STRING 12
BER_TAG_SEQUENCE 16 
BER_TAG_SET 17
BER_TAG_NUMERIC_STRING 18 
BER_TAG_PRINTABLE_STRING 19 
BER_TAG_T61_STRING 20 
BER_TAG_TELETEX_STRING BER_TAG_T61_STRING 
BER_TAG_VIDEOTEX_STRING 21 
BER_TAG_IA5_STRING 22
BER_TAG_UTC_TIME 23 
BER_TAG_GENERALIZED_TIME 24
BER_TAG_GRAPHIC_STRING 25 
BER_TAG_ISO646_STRING 26 
BER_TAG_GENERAL_STRING 27 
BER_TAG_VISIBLE_STRING BER_TAG_ISO646_STRING
 28 - are reserved for future versions of the recommendation 
BER_TAG_PKIX_UNIVERSAL_STRING 28 
BER_TAG_PKIX_BMP_STRING 30 
*)

Boolean* =1H;
Integer* =2H;
BitString* =3H;
(*
BIT STRING: BER encoding. Primitive or constructed. 
In a primitive encoding, the first contents octet gives the number of bits by which the length of the bit string 
is less than the next multiple of eight (this is called the "number of unused bits"). 
The second and following contents octets give the value of the bit string, converted to an octet string. 
The conversion process is as follows:
     1.   The bit string is padded after the last bit with zero to seven bits of any value to make the length
          of the bit string a multiple of eight. If the  length of the bit string is a multiple of eight
          already, no padding is done.
     2.   The padded bit string is divided into octets. The first eight bits of the padded bit string become
          the first octet, bit 8 to bit 1, and so on through the last eight bits of the padded bit string.
In a constructed encoding, the contents octets give the concatenation of the BER encodings of consecutive substrings
of the bit string, where each substring except the last has a length that is a multiple of eight bits.

Example: The BER encoding of the BIT STRING value "011011100101110111" can be any of the following, among
others, depending on the choice of padding bits, the form of length octets, and whether the encoding is primitive or constructed:
03 04 06 6e 5d c0                               DER encoding
03 04 06 6e 5d e0                       padded with "100000"
03 81 04 06 6e 5d c0              long form of length octets
23 09        constructed encoding: "0110111001011101" + "11"
   03 03 00 6e 5d
   03 02 06 c0

DER encoding. Primitive.
The contents octects are as for a primitive BER encoding, except that the bit string is padded with zero-valued bits.
Example: The DER encoding of the BIT STRING value "011011100101110111" is 03 04 06 6e 5d c0
*)

String* =4H;
Null* =5H;
Oid* =6H;
UTF8* =0CH;
PrintableString* =13H;
TeletexString* =14H;
IA5String*=16H;

(*
UTCTime
The UTCTime type denotes a coordinated universal time or Greenwich Mean Time (GMT) value. A UTCTime value includes
the local time precise to either minutes or seconds, and an offset from GMT in hours and minutes. It takes any of the
following forms:
YYMMDDhhmmZ
YYMMDDhhmm+hh'mm'
YYMMDDhhmm-hh'mm'
YYMMDDhhmmssZ
YYMMDDhhmmss+hh'mm'
YYMMDDhhmmss-hh'mm'
*)

UTCTime* =17H;
BMPString* =1EH;
Sequence* =30H;
Set* =31H;

TYPE CharString*=POINTER TO ARRAY OF CHAR;

(* data element in DER encoded certificates: tag[class+type] - length[1..n bytes] - value[0..n bytes]  *)
TYPE Triplet* = OBJECT (* todo: 1 Byte tags are sufficient for certificates, but in general, multiple byte tags may occur in other contexts  *)
				VAR tag*:LONGINT;
				class*:LONGINT;
				length*:LONGINT;
				unusedbits*:LONGINT;
				constructed*:BOOLEAN;
				definite*: BOOLEAN;
				
				bvalue*:BOOLEAN;
				ivalue*:LONGINT;
				svalue*:POINTER TO ARRAY OF CHAR;
				
				child*, curchild:Triplet;
				next*:Triplet;
				level*:LONGINT; (*pretty print*)
				
			PROCEDURE AppendChild*(t:Triplet);
			BEGIN
				IF child=NIL THEN child:=t; curchild:=t ELSE curchild.next:=t; curchild:=t; END;
			END AppendChild;
			
			PROCEDURE Print*(w: Streams.Writer);
			VAR i:LONGINT;
			BEGIN
				w.Char(09X);
				FOR i:=0 TO level-1 DO w.String("- "); END;
				w.Hex(tag,4); w.String("H[");
				w.Int(length,0); w.String("]");
				CASE tag OF 
				| Boolean: IF bvalue THEN w.String("true") ELSE w.String("false") END;
				| Integer: IF length<=4 THEN w.Int(ivalue,0);ELSE PrintHexString(w,svalue^) END;
				| Oid: PrintNumericString(w, svalue^); w.String("  "); PrintHexString(w, svalue^);
				| PrintableString: PrintString(w,svalue^);
				| UTCTime: PrintString(w,svalue^);
				| BitString: w.Char("("); w.Int(unusedbits,0); w.Char(")"); IF svalue#NIL THEN PrintHexString(w, svalue^) END;
				| Sequence, Set:
				ELSE 
					IF svalue#NIL THEN PrintHexString(w,svalue^);END;
				END;
				w.Ln;
			END Print;
		END Triplet;
		
VAR log*: Streams.Writer;
		
PROCEDURE PrintHexString*(w:Streams.Writer; CONST s: ARRAY OF CHAR);
CONST hex="0123456789ABCDEF";
VAR i:LONGINT; c:CHAR;
BEGIN
	FOR i:=0 TO LEN(s)-1 DO
		c:=s[i];
		w.Char(hex[ORD(c) DIV 16]); 
		w.Char(hex[ORD(c) MOD 16]);
		w.Char(" ");
	END;
END PrintHexString;

PROCEDURE PrintNumericString*(w:Streams.Writer; CONST s: ARRAY OF CHAR);
VAR i:LONGINT; c:CHAR;
BEGIN
	w.String("  ");
	FOR i:=0 TO LEN(s)-1 DO
		c:=s[i];
		w.Int(ORD(c),0);
		w.Char(".");
	END;
END PrintNumericString;

PROCEDURE PrintString*(w:Streams.Writer; CONST s: ARRAY OF CHAR);
VAR i:LONGINT; c:CHAR;
BEGIN
	FOR i:=0 TO LEN(s)-1 DO
		c:=s[i];
		IF (ORD(c)>=20H) & (ORD(c)<=7EH) THEN w.Char(c) ELSE w.Char("."); END;
	END;
END PrintString;

PROCEDURE Decode*(reader:Streams.Reader; level:LONGINT; VAR len:LONGINT): Triplet;
VAR t,t1:Triplet; lengthbytes,len0,hdrlen:LONGINT; i:LONGINT; c:CHAR;
BEGIN
	NEW(t); t.level:=level;
	len:=0; hdrlen:=0;
	reader.Char(c); INC(len); INC(hdrlen);
	IF Trace & (log#NIL) THEN log.Char("{");  log.Hex(ORD(c),0);log.Char("H"); log.Char("}"); END;
	t.class:= ORD(c) DIV 64;
	t.constructed:= ODD (ORD(c) DIV 32);
	IF ORD(c) MOD 32#31 THEN 	t.tag:=ORD(c) MOD 64; (* 'constructed' bit included *)
	ELSE
		REPEAT
			reader.Char(c); INC(len); INC(hdrlen);
			t.tag:=t.tag*128+ ORD(c) MOD 128;
		UNTIL ORD(c) DIV 128 # 1;
	END;
	reader.Char(c); INC(len); INC(hdrlen);
	IF ORD(c)<128 THEN t.length:=ORD(c); t.definite:=TRUE;
	ELSIF ORD(c)=128 THEN t.definite:=FALSE;
	(* to do: class=0, length=0 is used to encode end of bit stream of undefined length, see ftp://ftp.rsa.com/pub/pkcs/ascii/layman.asc*)
	ELSE 
		lengthbytes:= ORD(c) MOD 128; t.definite:=TRUE;
		FOR i:=0 TO lengthbytes-1 DO (* read all length bytes here ...*)
			t.length:=256*t.length;
			reader.Char(c); INC(len);  INC(hdrlen);
			t.length:=t.length+ORD(c);
		END;
	END;
	CASE t.tag OF
	| Boolean: reader.Char(c);INC(len); t.bvalue:=c#0X;
	| Integer: 
		IF t.length<=4 THEN 
			 NEW(t.svalue,t.length); 
			 FOR i:=0 TO t.length-1 DO 
					t.ivalue:=256*t.ivalue;
					reader.Char(c); INC(len);
					t.svalue[i]:=c;
					t.ivalue:=t.ivalue+ORD(c);
			END;
		ELSE
			NEW(t.svalue,t.length); 
			reader.Bytes(t.svalue^,0,t.length,len0); len:=len+len0;
		END;
	| BitString: 
		reader.Char(c); t.unusedbits:=ORD(c); INC(len);
		IF FALSE & (ORD(reader.Peek())=30H) (*rsa bit string 1024b*) THEN (*unreliable hack. to do: pass info about recursive bitstring to child*)
			IF Trace & (log#NIL) THEN log.String("(BitSRec  "); log.Int(len,0); log.String(")");t.Print(log);  END;
			t.child:=Decode(reader,level+1, len0);  len:=len+len0;
		ELSE
			NEW(t.svalue,t.length-1); 
			IF t.length>0 THEN reader.Bytes(t.svalue^,0,t.length-1,len0); len:=len+len0; END;
		END;
	| String:
		NEW(t.svalue,t.length); 
		reader.Bytes(t.svalue^,0,t.length,len0);len:=len+len0;
	| Set:
		IF Trace & (log#NIL) THEN log.String("(Set  "); log.Int(len,0); log.String("+)"); t.Print(log); END; (*bytes not including body*)
		t.child:=Decode(reader,level+1, len0);len:=len+len0;
	| Sequence:
		IF Trace & (log#NIL) THEN log.String("(Seq "); log.Int(len,0); log.String("+)"); t.Print(log); END; (*bytes not including body*)
		WHILE len-hdrlen<t.length DO
			t1:=Decode(reader,level+1, len0); len:=len+len0;
			(*t1.next:=t.next; t.next:=t1;*)
			t.AppendChild(t1);
		END;
	ELSE
		NEW(t.svalue,t.length); 
		IF t.length>0 THEN reader.Bytes(t.svalue^,0,t.length,len0); len:=len+len0; END;
	END;
	IF Trace & (log#NIL) THEN
		CASE t.tag OF
		| Integer: log.String("(Integer  "); log.Int(len,4); log.Char(")"); t.Print(log);(*bytes including header*)
		| BitString: 
			IF t.constructed THEN log.String("(constrBitString "); ELSE log.String("(BitString "); END;
			log.Int(len,4); log.Char(")"); t.Print(log); (*bytes including header*)
		| String: log.String("(String   ");log.Int(len,4); log.Char(")"); t.Print(log);(*bytes including header*)
		| Null: log.String("(Null     ");log.Int(len,4); log.Char(")"); t.Print(log);(*bytes including header*)
		| Oid: log.String("(OID");log.Int(len,4); log.Char(")"); t.Print(log);(*bytes including header*)
		| PrintableString: log.String("(Printable");log.Int(len,4); log.Char(")"); t.Print(log);(*bytes including header*)
		| UTCTime: log.String("(UTCTime");log.Int(len,4); log.Char(")"); t.Print(log);(*bytes including header*)
		| Set: 
		| Sequence:
		ELSE log.String("(t.tag="); log.Hex(t.tag,4);log.Int(len,4); log.Char(")"); t.Print(log); (*bytes including header*)
		END;
	END;
	RETURN t
END Decode;

END ASN1.
