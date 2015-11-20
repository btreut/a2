(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE IP;   (** AUTHOR "pjm, mvt, eb, G.F."; PURPOSE "IP (v4 and v6)"; *)

IMPORT S := SYSTEM, KernelLog, Strings, Network;

CONST
	(** Error codes *)
	Ok* = 0;

	(** IP address constants *)
	NilAdrIPv4 = 0;

	(* Comparators for Adr.usedProtocols *)
	IPv4* = 4;
	IPv6* = 6;
	NilAdrIdent = -1;   (* usedProtocol of NilAdrs *)

	MaxNofDNS = 4;

TYPE
	Adr* = RECORD
				ipv4Adr*: LONGINT;
				ipv6Adr*: ARRAY 16 OF CHAR;
				usedProtocol*: LONGINT;
				data*: LONGINT;
			END;
			(** An IP Address.
					usedProtocol = 0: No protocol yet used
					usedProtocol = IPv4: IPv4 address stored in field ipv4Adr
					usedProtocol = IPv6: IPv6 address stored in field ipv6Adr
					data can be used to store additional informations. I.e. in IPv6 the
					prefix length is stored in the data field *)

	Packet* = POINTER TO ARRAY OF CHAR;

	Name* = ARRAY 128 OF  CHAR;   (** Name type for interface name *)

	ARPHandler* = PROCEDURE {DELEGATE} ( ip: Adr; complete: BOOLEAN;
											link: Network.LinkAdr;
											size, sendTime, updateTime, updateDate, hash: LONGINT);

	Interface* = OBJECT
				(*! 	unused in UnixAos, included only for interface compatibility
					mostly a dummy, only 'localAdr' contains valid data in UnixAos !! *)

			VAR
				(** IP addresses of this interface. *)
				localAdr-, maskAdr-, gatewayAdr-, subnetAdr-, broadAdr-: Adr;

				(** name of the interface *)
				name-: Name;

				(** Device that the interface belongs to *)
				dev-: Network.LinkDevice;

				(** DNS server list - can be used by DNS, not used in IP itself *)
				DNS-: ARRAY MaxNofDNS OF  Adr;   (* DNS server list *)
				DNScount-: LONGINT;   (* number of DNS servers in list *)

				(* interface *)
				next*: Interface;   (* next pointer for interface list *)
				closed-: BOOLEAN;   (* is interface already closed? *)
				protocol-: LONGINT;
							 (* Interface for IPv4 or IPv6?. Only used by IP otherwise use dynamic type checking! *)



				PROCEDURE & Init*( addr: Adr );
				BEGIN
					localAdr := addr;
					name := "dummy";
				END Init;

			END Interface;

	InterfaceHandler* = PROCEDURE {DELEGATE} (int: Interface);

VAR
	(* IP *)
	NilAdr*: Adr;   (* To check if an IP address is NIL use IsNilAdr instead *)
	preferredProtocol*: LONGINT;   (* Preferred IP protocol *)

	(** Is address not yet specified *)
	PROCEDURE IsNilAdr*( adr: Adr ): BOOLEAN;
	VAR isNil: BOOLEAN;  i: LONGINT;
	BEGIN
		CASE adr.usedProtocol OF
		| IPv4:   RETURN (adr.ipv4Adr = NilAdrIPv4)
		| IPv6:	isNil := TRUE;  i := 0;
				WHILE ((i < 16) & isNil) DO
					IF adr.ipv6Adr[i] # 0X THEN  isNil := FALSE  END;
					INC( i );
				END;
				RETURN isNil;
		| NilAdrIdent:
				RETURN TRUE;
		ELSE
			RETURN TRUE;
		END;
	END IsNilAdr;


	(* Checks if two addresses are equal *)
	PROCEDURE AdrsEqual*( adr1, adr2: Adr ): BOOLEAN;
	VAR equal: BOOLEAN;  i: LONGINT;

	BEGIN
		IF adr1.usedProtocol # adr2.usedProtocol THEN  RETURN FALSE  END;
		CASE adr1.usedProtocol OF
		| IPv4:	IF adr1.ipv4Adr = adr2.ipv4Adr THEN  RETURN TRUE  END;
		| IPv6:	equal := TRUE;  i := 0;
				WHILE ((i < 16) & equal) DO
					IF adr1.ipv6Adr[i] # adr2.ipv6Adr[i] THEN  equal := FALSE  END;
					INC( i );
				END;
				IF adr1.data # adr2.data THEN  equal := FALSE  END;
				RETURN equal;
		| NilAdrIdent:
				(* both addresses NIL therefore equal *)
				IF adr2.usedProtocol = NilAdrIdent THEN  RETURN TRUE  ELSE  RETURN FALSE  END
		ELSE RETURN FALSE
		END;
		RETURN FALSE
	END AdrsEqual;


	(** Convert a dotted-decimal string to an ip address. Return NilAdr on failure. *)
	PROCEDURE StrToAdr*( ipString: ARRAY OF CHAR ): Adr;
	VAR retAdr: Adr;  i, j, x: LONGINT;
		adr: ARRAY 4 OF CHAR;
		ok: BOOLEAN;
		charCount: LONGINT;   (* ipv6: number of character between two : *)
		ipv6AdrPart: ARRAY 6 OF CHAR;   (* two bytes of an IPv6 address *)
		ipv6AdrRight: ARRAY 16 OF CHAR;   (* right part of an IPv6 address; after :: *)
		hexToChar: ARRAY 3 OF CHAR;
		leftParts: LONGINT;   (* number of bytes before :: *)
		rightParts: LONGINT;   (* number of bytes after :: *)
		val, res: LONGINT;
		state: LONGINT;   (* state of the FSM look at the eof for more info *)
		dPointOcc: BOOLEAN;   (* double point occured *)
		prefixVal: LONGINT;

		(* compute a subpart (two bytes) of a IPv6 address; subpart:=between two : *)
		PROCEDURE ComputeIPv6Part( ): BOOLEAN;
		BEGIN
			CASE charCount OF
			| 0:		RETURN TRUE;
			| 1, 2:	IF dPointOcc THEN  ipv6AdrRight[rightParts] := 0X;  INC( rightParts );
					ELSE  retAdr.ipv6Adr[leftParts] := 0X;  INC( leftParts );
					END;
					Strings.HexStrToInt( ipv6AdrPart, val, res );
					IF res = Strings.Ok THEN
						IF dPointOcc THEN  ipv6AdrRight[rightParts] := CHR( val );  INC( rightParts );
						ELSE  retAdr.ipv6Adr[leftParts] := CHR( val );  INC( leftParts );
						END;
					ELSE  RETURN FALSE
					END;
			| 3:		hexToChar[0] := ipv6AdrPart[0];  hexToChar[1] := 0X;
					Strings.HexStrToInt( hexToChar, val, res );
					IF res = Strings.Ok THEN
						IF dPointOcc THEN  ipv6AdrRight[rightParts] := CHR( val );  INC( rightParts );
						ELSE  retAdr.ipv6Adr[leftParts] := CHR( val );  INC( leftParts );
						END;
					ELSE  RETURN FALSE
					END;
					ipv6AdrPart[0] := "0";  Strings.HexStrToInt( ipv6AdrPart, val, res );
					IF res = Strings.Ok THEN
						IF dPointOcc THEN  ipv6AdrRight[rightParts] := CHR( val );  INC( rightParts );
						ELSE  retAdr.ipv6Adr[leftParts] := CHR( val );  INC( leftParts );
						END;
					ELSE  RETURN FALSE
					END;
			| 4:		hexToChar[0] := ipv6AdrPart[0];  hexToChar[1] := ipv6AdrPart[1];  hexToChar[2] := 0X;
					Strings.HexStrToInt( hexToChar, val, res );
					IF res = Strings.Ok THEN
						IF dPointOcc THEN  ipv6AdrRight[rightParts] := CHR( val );  INC( rightParts );
						ELSE  retAdr.ipv6Adr[leftParts] := CHR( val );  INC( leftParts );
						END;
					ELSE  RETURN FALSE
					END;
					ipv6AdrPart[0] := "0";  ipv6AdrPart[1] := "0";  Strings.HexStrToInt( ipv6AdrPart, val, res );
					IF res = Strings.Ok THEN
						IF dPointOcc THEN  ipv6AdrRight[rightParts] := CHR( val );  INC( rightParts );
						ELSE  retAdr.ipv6Adr[leftParts] := CHR( val );  INC( leftParts );
						END;
					ELSE  RETURN FALSE
					END;
			ELSE  RETURN FALSE;
			END;
			charCount := 0;  RETURN TRUE;
		END ComputeIPv6Part;

	BEGIN
		retAdr := NilAdr;
		IF IsValidIPv4Str( ipString ) THEN
			(* Return an ipv4 address *)
			i := 0;  j := 0;  x := -1;  ok := FALSE;
			LOOP
				IF (ipString[i] = ".") OR (ipString[i] = 0X) THEN
					IF (x < 0) OR (x > 255) OR (j = 4) THEN  EXIT   END;
					adr[j] := CHR( x );
					IF ipString[i] = 0X THEN  ok := (j = 3);  EXIT   END;
					x := -1;  INC( i );  INC( j )
				ELSIF (ipString[i] >= "0") & (ipString[i] <= "9") THEN
					IF x = -1 THEN  x := 0  END;
					x := x*10 + (ORD( ipString[i] ) - ORD( "0" ));  INC( i )
				ELSE  EXIT
				END
			END;

			IF ok THEN  retAdr.ipv4Adr := S.VAL( LONGINT, adr );  retAdr.usedProtocol := IPv4;  RETURN retAdr;
			ELSE  RETURN NilAdr;
			END
		ELSIF IsValidIPv6Str( ipString ) THEN
			i := 0;  state := 1;  charCount := 0;  dPointOcc := FALSE;
			retAdr.usedProtocol := 6;  retAdr.ipv4Adr := NilAdrIPv4;
			i := 0;  j := 0;  charCount := 0;  leftParts := 0;  rightParts := 0;  prefixVal := 0;
			Strings.UpperCase( ipString );

			WHILE (i < (LEN( ipString ) - 1)) & (ipString[i] # 0X) DO
				CASE state OF  (* Using the same FSM as IsValidIPv6Str *)
				| -1:	(* Error state Should never happen, is checked by IsValidIPv6Str() *)
						RETURN NilAdr;
				| 1:       (* reading two blocks of two bytes of 0-9\A-F *)
						IF ipString[i] = ":" THEN
							ipv6AdrPart[charCount] := 0X;
							IF ~ComputeIPv6Part() THEN  RETURN NilAdr  END;
							state := 2;
						ELSIF ipString[i] = "/" THEN
							ipv6AdrPart[charCount] := 0X;
							IF ~ComputeIPv6Part() THEN  RETURN NilAdr  END;
							state := 3;
						ELSE  (* 0-9, A-F *)
							 ipv6AdrPart[charCount] := ipString[i];  INC( charCount );
						END;
				| 2:        (* a : occured *)
						IF ipString[i] = ":" THEN  dPointOcc := TRUE;  state := 4
						ELSE  (* 0-9, A-F *)
							state := 1;  charCount := 0;  ipv6AdrPart[charCount] := ipString[i];  INC( charCount );
						END;
				| 3:		(* prefix will follow *)
						prefixVal := (prefixVal*10) + (ORD( ipString[i] ) - ORD( "0" ));
				| 4:        (* A :: occured *)
						IF ipString[i] = "/" THEN  state := 3
						ELSE
							IF ~ComputeIPv6Part() THEN  RETURN NilAdr  END;
							(* 0-9, A-F *)
							state := 1;  charCount := 0;  ipv6AdrPart[charCount] := ipString[i];  INC( charCount )
						END;
				ELSE
				END;
				INC( i );
			END;

			ipv6AdrPart[charCount] := 0X;
			IF charCount # 0 THEN
				IF ~ComputeIPv6Part() THEN  RETURN NilAdr  END;
			END;
			IF dPointOcc THEN
				(* fill 0X for :: *)
				FOR i := leftParts TO ((LEN( retAdr.ipv6Adr ) - 1) - rightParts) DO  retAdr.ipv6Adr[i] := 0X  END;
				(* fill part behind :: *)
				FOR i := 0 TO (rightParts - 1) DO
					retAdr.ipv6Adr[(LEN( retAdr.ipv6Adr ) - rightParts) + i] := ipv6AdrRight[i]
				END;
			END;
			IF prefixVal > 64 THEN  RETURN NilAdr  END;
			retAdr.data := prefixVal;  RETURN retAdr;
		END;
		RETURN NilAdr;
	END StrToAdr;


(** Convert an IP address to a dotted-decimal string. *)
	PROCEDURE AdrToStr*( adr: Adr;  VAR string: ARRAY OF CHAR );
	VAR i, j, x: LONGINT;
		a: ARRAY 4 OF CHAR;
		val: LONGINT;
		hexToStr: ARRAY 5 OF CHAR;
		prefixLenStr: ARRAY 64 OF CHAR;
		maxZeroRow: LONGINT;  currentZeroRow: LONGINT;
		maxZeroStart: LONGINT;  currentZeroStart: LONGINT;
		lastZero: BOOLEAN;  lastDPoint: BOOLEAN;  countEnded: BOOLEAN;
	BEGIN
		CASE adr.usedProtocol OF
		| IPv4:
				Network.Put4( a, 0, adr.ipv4Adr );
				i := 0;
				FOR j := 0 TO 3 DO
					x := ORD( a[j] );
					IF x >= 100 THEN  string[i] := CHR( ORD( "0" ) + x DIV 100 );  INC( i )  END;
					IF x >= 10 THEN  string[i] := CHR( ORD( "0" ) + x DIV 10 MOD 10 );  INC( i )  END;
					string[i] := CHR( ORD( "0" ) + x MOD 10 );  INC( i );
					IF j = 3 THEN  string[i] := 0X  ELSE  string[i] := "."  END;
					INC( i )
				END
		| IPv6:
				FOR i := 0 TO LEN( adr.ipv6Adr ) - 1 BY 2 DO
					(* simple version *)
					val := ORD( adr.ipv6Adr[i] )*256;  
					val := val + ORD( adr.ipv6Adr[i + 1] );
					Strings.IntToHexStr( val, 3, hexToStr );
					
					(* Delete leading zeros *)
					WHILE (hexToStr[0] = "0") & (hexToStr[1] # 0X) DO  Strings.Delete( hexToStr, 0, 1 )  END;
					Strings.Append( string, hexToStr );
					IF i # (LEN( adr.ipv6Adr ) - 2) THEN  Strings.Append( string, ":" )  END;
				END;

				(* replace longest row of zeros with :: *)
				maxZeroRow := 0;  currentZeroRow := 0;
				maxZeroStart := 0;  currentZeroStart := 0;  i := 0;
				lastZero := FALSE;  lastDPoint := TRUE;  countEnded := TRUE;

				WHILE string[i] # 0X DO
					IF string[i] = "0" THEN
						IF lastDPoint THEN
							INC( currentZeroRow );  lastZero := TRUE;  lastDPoint := FALSE;
							IF countEnded THEN  currentZeroStart := i;  countEnded := FALSE  END;
						END;
					ELSIF string[i] = ":" THEN
						lastDPoint := TRUE;
						IF lastZero THEN  lastZero := FALSE  END;
					ELSE
						IF lastDPoint THEN
							lastDPoint := FALSE;  countEnded := TRUE;
							IF currentZeroRow > maxZeroRow THEN
								maxZeroRow := currentZeroRow;  maxZeroStart := currentZeroStart;
							END;
						END;
					END;
					INC( i );
				END;

				IF ~countEnded THEN
					IF currentZeroRow > maxZeroRow THEN
						maxZeroRow := currentZeroRow;  maxZeroStart := currentZeroStart;
					END;
				END;
				IF maxZeroRow # 0 THEN
					(* write a :: *)
					IF maxZeroStart = 0 THEN
						string[0] := ":";  i := 1;
						WHILE ((string[i] # 0X) & ~((string[i] # "0") & (string[i] # ":"))) DO  INC( i )  END;
						IF string[i] = 0X THEN  COPY( "::", string )  ELSE  Strings.Delete( string, 1, i - 2 )  END;
					ELSE
						i := maxZeroStart;
						WHILE ((string[i] = "0") OR (string[i] = ":")) DO  INC( i )  END;
						IF string[i] = 0X THEN  string[maxZeroStart] := ":";  string[maxZeroStart + 1] := 0X;
						ELSE  Strings.Delete( string, maxZeroStart, i - maxZeroStart - 1 );
						END;
					END;
				END;
				IF adr.data # 0 THEN  (* write prefix *)
					Strings.IntToStr( adr.data, prefixLenStr );  Strings.Append( string, "/" );
					Strings.Append( string, prefixLenStr );
				END;
		ELSE
			IF IsNilAdr( adr ) THEN  string[0] := 0X  END;
		END;
	END AdrToStr;


	(** Convert a IP address from an array [ofs..ofs+x] to an
		Adr-type variable.
		Example for IPv4:
		If the LSB (least significant byte) is stored the the beginning [ofs],
		LSBfirst must be set to TRUE.
			(address "a.b.c.d" is stored as [d,c,b,a])
		If the LSB is stored at the end [ofs+3], LSBfirst must be set to FALSE.
			(address "a.b.c.d" is stored as [a,b,c,d])
		*)
	PROCEDURE ArrayToAdr*( CONST arr: ARRAY OF CHAR;  ofs, protocol: LONGINT;  LSBfirst: BOOLEAN ): Adr;
	VAR adr: Adr;  i, swapTemp: LONGINT;

	BEGIN
		ASSERT( (protocol = 4) OR (protocol = 6) );
		IF protocol = IPv4 THEN  (* index check *)
			IF ~(ofs + 4 <= LEN( arr )) THEN  RETURN NilAdr  END;
			S.MOVE( ADDRESSOF( arr[ofs] ), ADDRESSOF( adr.ipv4Adr ), 4 );
			IF LSBfirst THEN  SwapEndian( adr.ipv4Adr )  END;
			adr.usedProtocol := IPv4;
		ELSIF protocol = IPv6 THEN
			IF ~(ofs + 16 <= LEN( arr )) THEN  RETURN NilAdr  END;
			S.MOVE( ADDRESSOF( arr[ofs] ), ADDRESSOF( adr.ipv6Adr ), 16 );
			IF LSBfirst THEN
				FOR i := 0 TO 3 DO
					S.MOVE( ADDRESSOF( adr.ipv6Adr[i*4] ), ADDRESSOF( swapTemp ), 4 );
					SwapEndian( swapTemp );
					S.MOVE( ADDRESSOF( swapTemp ), ADDRESSOF( adr.ipv6Adr[i*4] ), 4 );
				END;
			END;
			adr.usedProtocol := IPv6;
		ELSE
			RETURN NilAdr;
		END;
		RETURN adr;
	END ArrayToAdr;


	(** Convert an Adr-type variable  into an array [ofs..ofs+x]
		Example in IPv4:
		If the LSB (least significant byte) should be stored the the
		beginning [ofs], LSBfirst must be set to TRUE.
			(address "a.b.c.d" is stored as [d,c,b,a])
		If the LSB should be stored at the end [ofs+3], LSBfirst must be set to FALSE.
			(address "a.b.c.d" is stored as [a,b,c,d])
		*)
	PROCEDURE AdrToArray*( adr: Adr;  VAR arr: ARRAY OF CHAR;  ofs: LONGINT;  LSBfirst: BOOLEAN );
	VAR tempAdr: Adr;  i, swapTemp: LONGINT;

	BEGIN
		tempAdr := adr;
		CASE adr.usedProtocol OF
		| IPv4:
				IF ~(ofs + 4 <= LEN( arr )) THEN  tempAdr := NilAdr  END;
				IF LSBfirst THEN  SwapEndian( tempAdr.ipv4Adr )  END;
				S.MOVE( ADDRESSOF( tempAdr.ipv4Adr ), ADDRESSOF( arr[ofs] ), 4 );
		| IPv6:
				IF ~(ofs + 16 <= LEN( arr )) THEN  tempAdr := NilAdr  END;
				IF LSBfirst THEN
					FOR i := 0 TO 3 DO
						S.MOVE( ADDRESSOF( tempAdr.ipv6Adr[i*4] ), ADDRESSOF( swapTemp ), 4 );
						SwapEndian( swapTemp );
						S.MOVE( ADDRESSOF( swapTemp ), ADDRESSOF( tempAdr.ipv6Adr[i*4] ), 4 );
					END;
				END;
				S.MOVE( ADDRESSOF( adr.ipv6Adr ), ADDRESSOF( arr[ofs] ), 16 );
		ELSE
		END;
	END AdrToArray;


	(** Aos command: Output statistics and configuration of all installed interfaces. *)
	PROCEDURE IPConfig*( par: ANY ): ANY;
	BEGIN
		KernelLog.String( "Interfaces:" );  KernelLog.Ln;  RETURN NIL;
	END IPConfig;


	(* Return TRUE if adr matches the prefix *)
	PROCEDURE MatchPrefix*( adr: Adr;  prefix: Adr ): BOOLEAN;
	VAR
		bytesToCheck: LONGINT;  bitsToCheck: LONGINT;  i: LONGINT;  matches: BOOLEAN;  diffSet: SET;
	BEGIN
		matches := TRUE;
		bytesToCheck := prefix.data DIV 8;  bitsToCheck := prefix.data MOD 8;
		FOR i := 0 TO bytesToCheck - 1 DO
			IF adr.ipv6Adr[i] # prefix.ipv6Adr[i] THEN  matches := FALSE  END;
		END;
		IF bitsToCheck # 0 THEN
			diffSet := {};
			FOR i := 0 TO 8 - bitsToCheck - 1 DO  diffSet := diffSet + {i}  END;
			FOR i := 0 TO bitsToCheck - 1 DO
				IF (S.VAL( SET, adr.ipv6Adr[bytesToCheck] ) - diffSet) #
				    (S.VAL( SET, prefix.ipv6Adr[bytesToCheck] ) - diffSet) THEN  matches := FALSE
				END
			END
		END;
		RETURN matches
	END MatchPrefix;


	(** Checks if a string is a valid IPv4 address *)
	PROCEDURE IsValidIPv4Str( CONST ipString: ARRAY OF CHAR ): BOOLEAN;
	VAR i, j: LONGINT;  ipNr: LONGINT;
		digits: ARRAY 4 OF CHAR;
		startClass: LONGINT;
	BEGIN
		i := 0;

		(* Class A *)
		WHILE (i < Strings.Length( ipString )) & (ipString[i] # '.') & (i < 3) DO  digits[i] := ipString[i];  INC( i )  END;
		digits[i] := 0X;

		IF ipString[i] # '.' THEN  RETURN FALSE  END;

		(* Check if in digits are only numbers *)
		j := 0;
		WHILE digits[j] # 0X DO
			IF (ORD( digits[j] ) - ORD( "0" )) > 9 THEN  RETURN FALSE   END;
			INC( j );
		END;
		Strings.StrToInt( digits, ipNr );
		IF ipNr > 255 THEN  RETURN FALSE   END;

		(* Class B *)
		INC( i );  startClass := i;
		WHILE (i < Strings.Length( ipString )) & (ipString[i] # '.') & (i - startClass <= 3) DO
			digits[i - startClass] := ipString[i];  INC( i );
		END;
		digits[i - startClass] := 0X;

		IF ipString[i] # '.' THEN  RETURN FALSE  END;

		(* Check if in digits are only number *)
		j := 0;
		WHILE digits[j] # 0X DO
			IF (ORD( digits[j] ) - ORD( "0" )) > 9 THEN  RETURN FALSE   END;
			INC( j );
		END;
		Strings.StrToInt( digits, ipNr );
		IF ipNr > 255 THEN  RETURN FALSE   END;

		(* Class C *)
		INC( i );  startClass := i;
		WHILE (i < Strings.Length( ipString )) & (ipString[i] # '.') & (i - startClass <= 3) DO
			digits[i - startClass] := ipString[i];  INC( i );
		END;
		digits[i - startClass] := 0X;

		IF ipString[i] # '.' THEN  RETURN FALSE  END;

		(* Check if in digits are only number *)
		j := 0;
		WHILE digits[j] # 0X DO
			IF (ORD( digits[j] ) - ORD( "0" )) > 9 THEN  RETURN FALSE   END;
			INC( j );
		END;
		Strings.StrToInt( digits, ipNr );
		IF ipNr > 255 THEN  RETURN FALSE   END;

		(* Class D *)
		INC( i );  startClass := i;
		WHILE (i < Strings.Length( ipString )) & (i - startClass <= 3) DO  digits[i - startClass] := ipString[i];  INC( i )  END;
		digits[i - startClass] := 0X;

		(* Check if in digits are only number *)
		j := 0;
		WHILE digits[j] # 0X DO
			IF (ORD( digits[j] ) - ORD( "0" )) > 9 THEN  RETURN FALSE   END;
			INC( j );
		END;
		Strings.StrToInt( digits, ipNr );
		IF ipNr > 255 THEN  RETURN FALSE   END;

		RETURN TRUE;
	END IsValidIPv4Str;


	(** Checks if a string is a valid IPv6 address *)
	PROCEDURE IsValidIPv6Str( ipString: ARRAY OF CHAR ): BOOLEAN;
	VAR i: LONGINT;
		state: LONGINT;   (* -1: error *)
		charCount: LONGINT;
		ascD: LONGINT;  ascH: LONGINT;
		dPointOcc: BOOLEAN;
		prefixLenArr: ARRAY 3 OF LONGINT;
		prefixLen: LONGINT;
	BEGIN
		i := 0;  state := 1;  dPointOcc := FALSE;
		Strings.UpperCase( ipString );

		WHILE (i < (LEN( ipString ) - 1)) & (ipString[i] # 0X) DO
			CASE state OF
			-1:       RETURN FALSE;
			| 1:
						(* 0-9 & A-F *)
						ascD := ORD( ipString[i] ) - ORD( "0" );
						ascH := ORD( ipString[i] ) - ORD( "A" );

						IF ((ascD >= 0) & (ascD <= 9)) OR ((ascH >= 0) & (ascH <= 5)) THEN
							INC( charCount );
							IF charCount > 4 THEN  state := -1  END;
						ELSIF ipString[i] = ":" THEN  charCount := 0;  state := 2;
						ELSIF ipString[i] = "/" THEN  charCount := 0;  state := 3;
						ELSE  state := -1;
						END;
			| 2:       ascD := ORD( ipString[i] ) - ORD( "0" );
						ascH := ORD( ipString[i] ) - ORD( "A" );
						IF ipString[i] = ":" THEN
							IF dPointOcc THEN  state := -1  ELSE  dPointOcc := TRUE;  state := 4  END
						ELSIF ((ascD >= 0) & (ascD <= 9)) OR ((ascH >= 0) & (ascH <= 5)) THEN  INC( charCount );  state := 1;
						ELSE  state := -1;
						END;
			| 3:       ascD := ORD( ipString[i] ) - ORD( "0" );
						IF ~((ascD >= 0) & (ascD <= 9)) THEN  state := -1;
						ELSE
							IF charCount > 3 THEN  state := -1  ELSE  prefixLenArr[charCount] := ascD;  INC( charCount )  END;
						END;
			| 4:       ascD := ORD( ipString[i] ) - ORD( "0" );
						ascH := ORD( ipString[i] ) - ORD( "A" );
						IF ipString[i] = "/" THEN  state := 3;
						ELSIF ((ascD >= 0) & (ascD <= 9)) OR ((ascH >= 0) & (ascH <= 5)) THEN  INC( charCount );  state := 1;
						ELSE  state := -1;
						END;
			ELSE
			END;
			INC( i );
		END;

		CASE state OF
		| 1:       RETURN TRUE;
		| 3:       IF charCount > 0 THEN  prefixLen := 0;
						FOR i := 0 TO charCount - 1 DO  prefixLen := prefixLen*10;  INC( prefixLen, prefixLenArr[i] )  END;
						IF prefixLen <= 64 THEN  RETURN TRUE  ELSE  RETURN FALSE  END;
					ELSE  RETURN FALSE;
					END;
		| 4:      RETURN TRUE;
		ELSE
			RETURN FALSE;
		END;
		RETURN FALSE;
	END IsValidIPv6Str;


	(** Set IPv6 address to zero *)
	PROCEDURE SetIPv6AdrNil( adr: Adr );
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO 15 DO  adr.ipv6Adr[i] := 0X  END;
	END SetIPv6AdrNil;


	(* Swap internal representation of an IP address from big to little endian or vice versa. *)
	PROCEDURE  -SwapEndian(  VAR adr: LONGINT );
	CODE {SYSTEM.i386}
		POP EAX
		MOV ECX, [EAX]
		XCHG CL, CH
		ROL ECX, 16
		XCHG CL, CH
		MOV [EAX], ECX
	END SwapEndian;


BEGIN
	(* NilAdr *)
	NilAdr.ipv4Adr := NilAdrIPv4;
	SetIPv6AdrNil( NilAdr );
	NilAdr.usedProtocol := NilAdrIdent;
END IP.


			