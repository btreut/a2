MODULE CryptoSHA3;	(** AUTHOR "GF"; PURPOSE "SHA-3"; *)
(*
	The Keccak sponge function, designed by Guido Bertoni, Joan Daemen,
	Michaël Peeters and Gilles Van Assche. For more information, feedback or
	questions, please refer to our website: http://keccak.noekeon.org/
*)

IMPORT	Hashes := CryptoHashes, Sponge := CryptoKeccakSponge;

TYPE
	Hash* = OBJECT (Hashes.Hash)
		VAR
			sponge: Sponge.Instance;
			capacity: LONGINT;
			
		PROCEDURE &Init*;	(* sha3-256 (default) *)
		BEGIN
			NEW( sponge );
			capacity := 2*256;   
			Initialize	
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			IF capacity = 2*224 THEN
				SetNameAndSize^( "sha3-224", 224 DIV 8 );
			ELSIF capacity = 2*256 THEN
				SetNameAndSize^( "sha3-256", 256 DIV 8 );
			ELSIF capacity = 2*384 THEN
				SetNameAndSize^( "sha3-384", 384 DIV 8 );
			ELSIF capacity = 2*512 THEN
				SetNameAndSize^( "sha3-512", 512 DIV 8 );
			ELSE
				HALT( 1000 )
			END;
			sponge.Initialize( Sponge.Width - capacity, capacity );
			initialized := TRUE
		END Initialize;
		
		PROCEDURE SetNameAndSize*( CONST name: ARRAY OF CHAR; bytesize: LONGINT );
		(* valid bytesize values: 28, 32(default), 48, 64 *)
		BEGIN
			capacity := 2*8*bytesize;  Initialize;
			IF name # "" THEN  SetNameAndSize^( name, bytesize )  END
		END SetNameAndSize;
		

		(** data: value to be hashed *)
		PROCEDURE Update*( CONST data: ARRAY OF CHAR;  pos, len: LONGINT );
		BEGIN
			ASSERT( initialized );	
			sponge.Absorb( data, pos, len )
		END Update;
		

		(** get the hashvalue of length SELF.size *)
		PROCEDURE GetHash*( VAR buf: ARRAY OF CHAR;  pos: LONGINT );
		BEGIN
			sponge.AbsorbLastFewBits( 6X );  (* 1(pad) || 10(sha3) *)
			sponge.Squeeze( buf, pos, size )
		END GetHash;

	END Hash;



	
	(** get an instance of SHA-3 *)
	PROCEDURE NewHash*( ) : Hashes.Hash;
		VAR h: Hash;
	BEGIN
		NEW( h );  RETURN h
	END NewHash;



END CryptoSHA3.