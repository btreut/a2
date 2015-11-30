(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMParser;

IMPORT
		JT := JVMTypes, Reals;
		
(* i want to read from texts, files, inputstreams, bytearrays, char arrays, intarrays ;
 and i want to use always the same parser *)
TYPE Reader* = OBJECT
								PROCEDURE next*( VAR char : INTEGER):BOOLEAN;
								BEGIN END next;
						END Reader;
						
		StringReader *= OBJECT(Reader)
								VAR
									buffer : JT.String; pos, len : LONGINT;						
								
								PROCEDURE next*( VAR char : INTEGER):BOOLEAN;
								BEGIN
									IF pos < len THEN char := buffer[pos]; INC(pos); RETURN TRUE
									ELSE char := 0; RETURN FALSE END
								END next;
								
								PROCEDURE init*( string :JT.String; start, len : LONGINT );
								BEGIN
									buffer := string; pos := start; SELF.len := len;
									ASSERT( LEN(buffer)>= len )
								END init;
								END StringReader;
								
	PROCEDURE ParseFloat*( r : Reader; VAR val : LONGREAL ):BOOLEAN;
	CONST error = -1;
				start = 0; sign = 1; intpart = 2; fract = 3; fractpart = 4; 
				expo = 5; expsign = 6; exppart = 7; ok = 8;
				
	VAR exp, y : LONGINT;			
		    state, char : INTEGER;
			neg, negexp, more : BOOLEAN;
		BEGIN
			state := start; val := 0; exp := 0; 
			more := r.next( char );
			WHILE more & (state#error) DO	
				CASE CHR(char) OF
					"+": IF state = start THEN state := sign; neg := FALSE
							ELSIF state = exp THEN state := expsign; negexp := FALSE
							ELSE state := error END
					|"-": IF state = start THEN state := intpart; neg := TRUE
							ELSIF state = expo THEN state := expsign; negexp := TRUE
							ELSE state := error END
					|"0".."9": IF (state = intpart) OR (state = sign) OR (state = start) THEN 
										state := intpart; val := val*10 + char - ORD("0"); 
									ELSIF (state = fract) OR (state=fractpart ) THEN state := fractpart;
										val := val + (char - ORD("0"))/y; y := y*10;
									ELSIF (state = expo) OR (state=expsign) OR (state=exppart) THEN
										state := exppart; exp := exp*10 + char - ORD("0")
									ELSE state := error
									END;
					|".": IF state = intpart THEN state := fract; y:=10;
							ELSE state := error END
					|"e","E": IF (state = fract) OR (state=fractpart) THEN state := expo
												 ELSE state := error END
					|" ": IF state = start THEN 
							ELSE state := error END
					ELSE state := error
				END;
				more := r.next( char )									
			END;			
			IF state#error THEN				
				IF negexp THEN exp := -exp END; 
				IF neg THEN val := -val END;
				val := val*Reals.Ten(exp);
				RETURN TRUE;
			ELSE
				val := Reals.NaNL( 0, 0 );
				RETURN FALSE
			END				
	END ParseFloat;
	
END JVMParser.

System.Free JVMParser~

JVMParser.Test "-23.14"