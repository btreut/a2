MODULE CryptoKeccakF1600; (** AUTHOR "GF"; PURPOSE "KeccakF-1600 sponge function"; *)
(*
	The Keccak sponge function, designed by Guido Bertoni, Joan Daemen,
	Michaël Peeters and Gilles Van Assche. For more information, feedback or
	questions, please refer to our website: http://keccak.noekeon.org/
*)

IMPORT S := SYSTEM;

CONST
	Width* = 1600;			(* state size in bits *)
	LaneSize* = 8;			(* lane size in bytes *)
	
CONST 
	nrRounds = 24;  nrLanes = 25;
	
TYPE
	Lane = RECORD  low, high: SET  END;
	State = ARRAY nrLanes OF Lane;

VAR 
	roundConstants: ARRAY nrRounds OF Lane;
	rhoOffsets: ARRAY nrLanes OF LONGINT;
	
TYPE 
	Instance* = OBJECT
	VAR
		state: State;


		PROCEDURE & Init*;
		BEGIN
			Initialize
		END Init;
		
		PROCEDURE Initialize*;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO nrLanes-1 DO  state[i].low := {};  state[i].high := {}  END
		END Initialize;


		PROCEDURE XORBytesInLane*( laneNo, laneOffset, length: LONGINT;  CONST data: ARRAY OF CHAR; dataOffset: LONGINT );
		VAR
			lane: Lane;
		BEGIN
			ASSERT( (laneNo < nrLanes) & (laneOffset < LaneSize) & (laneOffset+length <= LaneSize) );
			lane.low := {};  lane.high := {};
			S.MOVE( ADDRESSOF( data[dataOffset] ), ADDRESSOF( lane ) + laneOffset, length );
			
			ToBitInterleaving( lane, lane );
			
			state[laneNo].low := state[laneNo].low / lane.low;
			state[laneNo].high := state[laneNo].high / lane.high;
		END XORBytesInLane;


		PROCEDURE XORLanes*( CONST data: ARRAY OF CHAR; offset, laneCount: LONGINT );
		VAR
			lane: Lane;  laneNo: LONGINT;
		BEGIN
			ASSERT( laneCount <= nrLanes );
			FOR laneNo := 0 TO laneCount - 1 DO
				S.MOVE( ADDRESSOF( data[offset + laneNo*LaneSize] ), ADDRESSOF( lane ), LaneSize );
				
				ToBitInterleaving( lane, lane );
				
				state[laneNo].low := state[laneNo].low / lane.low;
				state[laneNo].high := state[laneNo].high / lane.high;
			END
		END XORLanes;


		PROCEDURE ComplementBit*( position: LONGINT );
		VAR
			laneNo, bit: LONGINT;
		BEGIN
			ASSERT( position < 1600 );
			laneNo := position DIV 64;  bit := position MOD 64; 
			IF bit < 32 THEN
				state[laneNo].low := state[laneNo].low / {bit}
			ELSE
				state[laneNo].high := state[laneNo].high / {bit - 32};
			END
		END ComplementBit;


		PROCEDURE ExtractBytesInLane*( laneNo, laneOffset, length: LONGINT;  VAR data: ARRAY OF CHAR; dataOffset: LONGINT );
		VAR
			lane: Lane;
		BEGIN
			ASSERT( (laneNo < nrLanes) & (laneOffset < LaneSize) & (laneOffset+length <= LaneSize) );
			FromBitInterleaving( state[laneNo], lane );
			S.MOVE( ADDRESSOF( lane ) + laneOffset, ADDRESSOF( data[dataOffset] ), length )
		END ExtractBytesInLane;


		PROCEDURE ExtractLanes*( VAR data: ARRAY OF CHAR; offset, laneCount: LONGINT );
		VAR 
			lane: Lane;  laneNo: LONGINT;
		BEGIN
			ASSERT( laneCount <= nrLanes );
			FOR laneNo := 0 TO laneCount - 1 DO
				FromBitInterleaving(state[laneNo], lane );
				S.MOVE( ADDRESSOF( lane ), ADDRESSOF( data[offset + laneNo*LaneSize] ), LaneSize )
			END
		END ExtractLanes;

		PROCEDURE XORPermute*(	CONST inData: ARRAY OF CHAR; offset, count: LONGINT );
		BEGIN
			XORLanes( inData, offset, count );
			Permute;
		END XORPermute;
		
		
		PROCEDURE XORPermuteExtract*(	CONST inData: ARRAY OF CHAR; inOffset, inLaneCount: LONGINT; 
												VAR outData: ARRAY OF CHAR; outOffset, outLaneCount: LONGINT );
		BEGIN
			XORLanes( inData, inOffset, inLaneCount );
			Permute;
			ExtractLanes( outData, outOffset, outLaneCount )
		END XORPermuteExtract;


		PROCEDURE Permute*;
		VAR r: LONGINT;
		BEGIN
			FOR r := 0 TO nrRounds-1 DO  Round( state, r ) END
		END Permute;


	END Instance;





	(* Credit to Henry S. Warren, Hacker's Delight, Addison-Wesley, 2002	*)
	PROCEDURE ToBitInterleaving( CONST in: Lane; VAR out: Lane );
	VAR temp, temp0, temp1: SET;
	BEGIN
	        temp0 := in.low;
	        temp1 := in.high;
	        temp := (temp0 / LSH( temp0, -1 )) * S.VAL( SET, 022222222H );  temp0 := temp0 / temp / LSH( temp, 1 );
	        temp := (temp0 / LSH( temp0, -2 )) * S.VAL( SET, 00C0C0C0CH );  temp0 := temp0 / temp / LSH( temp, 2 );
	        temp := (temp0 / LSH( temp0, -4 )) * S.VAL( SET, 000F000F0H );  temp0 := temp0 / temp / LSH( temp, 4 );
	        temp := (temp0 / LSH( temp0, -8 )) * S.VAL( SET, 00000FF00H );  temp0 := temp0 / temp / LSH( temp, 8 );
	        
	        temp := (temp1 / LSH( temp1, -1 )) * S.VAL( SET, 022222222H );  temp1 := temp1 / temp / LSH( temp, 1 );
	        temp := (temp1 / LSH( temp1, -2 )) * S.VAL( SET, 00C0C0C0CH );  temp1 := temp1 / temp / LSH( temp, 2 );
	        temp := (temp1 / LSH( temp1, -4 )) * S.VAL( SET, 000F000F0H );  temp1 := temp1 / temp / LSH( temp, 4 );
	        temp := (temp1 / LSH( temp1, -8 )) * S.VAL( SET, 00000FF00H );  temp1 := temp1 / temp / LSH( temp, 8 );
	        out.low := (temp0 * S.VAL( SET, 00000FFFFH )) + LSH( temp1, 16 );
	        out.high := LSH( temp0, - 16) + (temp1 * S.VAL( SET, 0FFFF0000H ));
	END ToBitInterleaving;

	(* Credit to Henry S. Warren, Hacker's Delight, Addison-Wesley, 2002 *)
	PROCEDURE FromBitInterleaving( CONST in: Lane;  VAR out: Lane );
	VAR temp, temp0, temp1: SET;
	BEGIN
	        temp0 := in.low; 
	        temp1 := in.high; 
	        temp := (temp0 * S.VAL( SET, 00000FFFFH )) + LSH( temp1, 16 ); 
	        temp1 := LSH( temp0, - 16) + (temp1 * S.VAL( SET, 0FFFF0000H )); 
	        temp0 := temp; 
	        temp := (temp0 / LSH( temp0, -8 )) * S.VAL( SET, 00000FF00H );  temp0 := temp0 / temp / LSH( temp, 8 ); 
	        temp := (temp0 / LSH( temp0, -4 )) * S.VAL( SET, 000F000F0H );  temp0 := temp0 / temp / LSH( temp, 4 ); 
	        temp := (temp0 / LSH( temp0, -2 )) * S.VAL( SET, 00C0C0C0CH );  temp0 := temp0 / temp / LSH( temp, 2 ); 
	        temp := (temp0 / LSH( temp0, -1 )) * S.VAL( SET, 022222222H );  temp0 := temp0 / temp / LSH( temp, 1 ); 
	        
	        temp := (temp1 / LSH( temp1, -8 )) * S.VAL( SET, 00000FF00H );  temp1 := temp1 / temp / LSH( temp, 8 );
	        temp := (temp1 / LSH( temp1, -4 )) * S.VAL( SET, 000F000F0H );  temp1 := temp1 / temp / LSH( temp, 4 );
	        temp := (temp1 / LSH( temp1, -2 )) * S.VAL( SET, 00C0C0C0CH );  temp1 := temp1 / temp / LSH( temp, 2 );
	        temp := (temp1 / LSH( temp1, -1 )) * S.VAL( SET, 022222222H );  temp1 := temp1 / temp / LSH( temp, 1 );
	        out.low := temp0;
	        out.high := temp1;
	END FromBitInterleaving;



	PROCEDURE ROL64( VAR lane: Lane; offset: LONGINT );
	VAR tmp: SET;
	BEGIN
		IF ODD( offset ) THEN
			tmp := lane.low;
			lane.low := ROT( lane.high, (offset+1) DIV 2 );
			lane.high := ROT( tmp, (offset-1) DIV 2 )
		ELSE
			lane.low := ROT( lane.low, offset DIV 2 );
			lane.high := ROT( lane.high, offset DIV 2 )
		END;
	END ROL64;
	

	PROCEDURE ROL64_1XOR( CONST in1, in2: Lane; VAR out: Lane );
	BEGIN
		out.low := ROT( in1.high, 1 ) / in2.low;
		out.high := in1.low / in2.high;
	END ROL64_1XOR;


	PROCEDURE Round( VAR a: State; r: LONGINT );
	VAR
		x, y, i, i1, i2: LONGINT;
		c, d: ARRAY 5 OF Lane;  
		a0: State;  
	BEGIN
		(* theta *)
		FOR x := 0 TO 4 DO
			c[x].low := {};  c[x].high := {};
			FOR y := 0 TO 20 BY 5 DO
				c[x].low := c[x].low / a[x+y].low;  
				c[x].high := c[x].high / a[x+y].high;	
			END
		END;
		FOR x := 0 TO 4 DO
			ROL64_1XOR( c[(x+1) MOD 5], c[(x+4) MOD 5], d[x] );
		END;
		FOR x := 0 TO 4 DO
			FOR y := 0 TO 4 DO
				i := x + 5*y;
				a[i].low := a[i].low / d[x].low;  
				a[i].high := a[i].high / d[x].high	
			END
		END;
		(* rho *)
		FOR i := 0 TO 24 DO
			ROL64( a[i], rhoOffsets[i] );	
		END;
		(* pi *)
		a0 := a;
		FOR x := 0 TO 4 DO
			FOR y := 0 TO 4 DO
				a[y + 5*((2*x + 3*y) MOD 5)] := a0[x + 5*y]
			END
		END;
		(* chi *)
		FOR y := 0 TO 20 BY 5 DO
			FOR x := 0 TO 2 DO
				i := x + y;  i1 := x + 1 + y;  i2 := x + 2 + y;
				c[x].low := a[i].low / ((-a[i1].low) * a[i2].low);
				c[x].high := a[i].high / ((-a[i1].high) * a[i2].high);
			END;
			i := 3 + y;  i1 := 4 + y;  i2 := 0 + y;
			c[3].low := a[i].low / ((-a[i1].low) * a[i2].low);
			c[3].high := a[i].high / ((-a[i1].high) * a[i2].high);
			i := 4 + y;  i1 := 0 + y;  i2 := 1 + y;
			c[4].low := a[i].low / ((-a[i1].low) * a[i2].low);
			c[4].high := a[i].high / ((-a[i1].high) * a[i2].high);
			FOR x := 0 TO 4 DO  
				a[x+y].low := c[x].low;
				a[x+y].high := c[x].high
			END
		END;
		(* iota *)
		a[0].low := a[0].low / roundConstants[r].low;
		a[0].high := a[0].high / roundConstants[r].high;
	END Round;
	
	

	(* ---------------------------------------------------------------- *)


	PROCEDURE InitializeRoundConstants;
	VAR
		LFSRstate: SET;
		i, j, bit: LONGINT;
		lane: Lane;
	BEGIN
		LFSRstate := {0};
		FOR i := 0 TO nrRounds - 1 DO
			lane.low := {};  lane.high := {};
			FOR j := 0 TO 6 DO
	       		bit := ASH( 1, j ) - 1; 
	 			IF LFSR86540( LFSRstate ) THEN
	      			IF bit < 32 THEN  INCL( lane.low, bit )  ELSE  INCL( lane.high, bit - 32 )  END
	   			END
	  		END;
	   		ToBitInterleaving( lane, roundConstants[i] );
	 	END
	END InitializeRoundConstants;



	PROCEDURE InitializeRhoOffsets;
	VAR
	    x, y, t, oldY: LONGINT;
	BEGIN
	  	rhoOffsets[0] := 0;
	 	x := 1;
		y := 0;
		FOR t := 0 TO 23 DO
			rhoOffsets[x + 5*y] := ((t+1)*(t+2) DIV 2) MOD 64;
	        	oldY := y;  y := (2*x + 3*y) MOD 5;
	        	x := oldY;
		END
	END InitializeRhoOffsets;

	PROCEDURE LFSR86540( VAR LFSR: SET ): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		result := 0 IN LFSR;
		IF 7 IN LFSR THEN
			(* Primitive polynomial over GF(2): x^8+x^6+x^5+x^4+1 *)
			LFSR := LSH( LFSR, 1) / S.VAL( SET, 71H );
		ELSE
			LFSR := LSH( LFSR, 1 )
		END;
		RETURN result;
	END LFSR86540;



BEGIN
	InitializeRoundConstants;
	InitializeRhoOffsets;
END CryptoKeccakF1600.

	
