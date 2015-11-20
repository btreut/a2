MODULE CryptoKeccakSponge;	(** OUTHOR "GF"; PURPOSE "Keccak, sponge mode"; *)
(*
	The Keccak sponge function, designed by Guido Bertoni, Joan Daemen,
	Michaël Peeters and Gilles Van Assche. For more information, feedback or
	questions, please refer to our website: http://keccak.noekeon.org/
*)

IMPORT Keccak := CryptoKeccakF1600;

CONST
	LaneSize = Keccak.LaneSize;
	Width* = Keccak.Width;
	DefaultRate* = 1024;
	DefaultCapacity* = 576;
	
TYPE 
	Instance* = OBJECT 
	VAR
		state: Keccak.Instance;	(* The state processed by the permutation. *)
		chunk: LONGINT;		(* The value of the rate in bytes *)
		index: LONGINT;			(* The position in the state of the next byte to be 
									input (when absorbing) or output (when squeezing). *)
		squeezing: BOOLEAN	;	(* false: in the absorbing phase; otherwise, in the squeezing phase. *)
		cmodl: LONGINT;		(* chunk MOD LaneSize *)
		cdivl: LONGINT;			(* chunk DIV LaneSize *)

		PROCEDURE &Init*;
		BEGIN
			NEW( state );
			Initialize( DefaultRate, DefaultCapacity )
		END Init;
		
		
		PROCEDURE Initialize*( rate, capacity: LONGINT );
		BEGIN
			ASSERT( rate + capacity = Width );
			ASSERT( (rate > 0) & (rate <= Width) & (rate MOD 8 = 0) );
			state.Initialize;
			chunk := rate DIV 8;
			index := 0;
			cmodl := chunk MOD LaneSize;
			cdivl := chunk DIV LaneSize;
			squeezing := FALSE
		END Initialize;
	
		
		PROCEDURE Absorb*( CONST data: ARRAY OF CHAR; offset, len: LONGINT );
		VAR 
			piece, lanes, laneNo, laneOffset, bytes: LONGINT;
		BEGIN
			ASSERT( squeezing = FALSE ); 
			WHILE len > 0 DO
				IF (index = 0) & ( len >= chunk) THEN
					(* fast lane: processing whole blocks first *)
					state.XORLanes( data, offset, cdivl );
					IF cmodl # 0 THEN  state.XORBytesInLane( cdivl, 0, cmodl, data, offset )  END;
					state.Permute;
					INC( offset, chunk );  DEC( len, chunk );  
				ELSE
					(* normal lane: using the message queue*)
					piece := len;
					IF index + piece > chunk THEN  piece := chunk - index  END;
					IF (index = 0) & (piece >=  LaneSize) THEN
						lanes := piece DIV LaneSize;  bytes := lanes*LaneSize;
						state.XORLanes( data, offset, lanes );
						INC( offset, bytes );  DEC( len, bytes );  DEC( piece, bytes ); 
						INC( index, bytes );   
					END;
					WHILE piece > 0 DO
						laneNo := index DIV LaneSize;
						laneOffset := index MOD LaneSize;
						bytes := LaneSize - laneOffset;
						IF bytes > piece THEN  bytes := piece  END;
						state.XORBytesInLane( laneNo, laneOffset, bytes, data, offset );
						INC( offset, bytes );  DEC( len, bytes ); DEC( piece, bytes );
						INC( index, bytes )
					END;
					IF index = chunk THEN  state.Permute;  index := 0  END
				END
			END
		END Absorb;
		
		
		
		PROCEDURE Squeeze*( VAR data: ARRAY OF CHAR;  offset, len: LONGINT );
		VAR piece, lanes, laneNo, laneOffset, bytes: LONGINT;
		BEGIN
			IF ~squeezing THEN  AbsorbLastFewBits( 01X )  END;
			WHILE len > 0 DO
				IF (index = chunk) & (len >= chunk) THEN
					(* fast lane: processing whole blocks first*)
					state.Permute;
					state.ExtractLanes( data, offset, cdivl );
					IF cmodl # 0 THEN  state.ExtractBytesInLane( cdivl, 0, cmodl, data, offset + cdivl*LaneSize )  END;
					INC( offset, chunk );  DEC( len, chunk )
				ELSE
					(* normal lane: using the message queue *)
					IF index = chunk THEN  state.Permute;  index := 0  END;
					piece := len;
					IF index + piece > chunk THEN  piece := chunk - index  END;
					IF (index = 0) & (piece >= LaneSize) THEN
						lanes := piece DIV LaneSize;  bytes := lanes*LaneSize;
						state.ExtractLanes( data, offset, lanes );
						DEC( len, bytes );  INC( offset, bytes );
						INC( index, bytes );  DEC( piece, bytes )
					END;
					WHILE piece > 0 DO
						laneNo := index DIV LaneSize;
						laneOffset := index MOD LaneSize;
						bytes := LaneSize - laneOffset;
						IF bytes > piece THEN  bytes := piece  END;
						state.ExtractBytesInLane( laneNo, laneOffset, bytes, data, offset );
						DEC( len, bytes );  INC( offset, bytes );
						INC( index, bytes );  DEC( piece, bytes )
					END
				END
			END;
		END Squeeze;
		
		PROCEDURE AbsorbLastFewBits*( data: CHAR );
		VAR tmp: ARRAY 4 OF CHAR;
		BEGIN
			ASSERT( (data # 0X) & (squeezing = FALSE) ); 
			tmp[0] := data;
			state.XORBytesInLane( index DIV LaneSize, index MOD LaneSize, 1, tmp, 0 );
			IF (data >= 80X) & (index = chunk - 1) THEN  state.Permute  END;
			state.ComplementBit( chunk*8 - 1 );
			state.Permute;
			index := 0;
			squeezing := TRUE
		END AbsorbLastFewBits;
	
	END Instance;
	


END CryptoKeccakSponge.


