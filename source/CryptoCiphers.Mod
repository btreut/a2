MODULE CryptoCiphers;   (** empty cipher *)

(*	2002.07.22	g.f. *)

CONST
	(** cipher modes *)
	ECB* = 0;   (** electronic codebook mode *)
	CBC* = 1;   (** cipher-block chaining mode *)
	CTR* = 2;	(** counter mode *)

	(** error codes *)
	Ok* = 0;

TYPE
	Cipher* = OBJECT
			VAR
				name-: ARRAY 64 OF CHAR;
				blockSize-: LONGINT;   (** cipher block size (bytes) *)
				isKeyInitialized*: BOOLEAN;
				mode-: SHORTINT;   (** ECB, CBC *)
				len1, len2: INTEGER;

				PROCEDURE appsize( size: LONGINT );
				VAR i, t, d: LONGINT;
				BEGIN
					IF (size = 64) OR (size = 128) THEN  RETURN   END;
					len2 := len1;  i := 0;  t := 10000;
					WHILE t > size DO  t := t DIV 10  END;
					REPEAT
						d := size DIV t MOD 10;  name[len2] := CHR( 48 + d );  INC( len2 );  t := t DIV 10
					UNTIL t = 0;
					name[len2] := 0X
				END appsize;

				PROCEDURE appmode( CONST str: ARRAY OF CHAR );
				VAR i, j: INTEGER;  c: CHAR;
				BEGIN
					j := len2;  i := 0;
					REPEAT  c := str[i];  INC( i );  name[j] := c;  INC( j )  UNTIL c = 0X;
				END appmode;

				(** initialize key for de/encryption *)
				PROCEDURE InitKey*( CONST src: ARRAY OF CHAR; keybits: LONGINT );
				BEGIN
					appsize( keybits );  isKeyInitialized := TRUE
				END InitKey;

				(** set initialization vector, change mode to CBC;  MUST be invoked AFTER Initkey *)
				PROCEDURE SetIV*( CONST src: ARRAY OF CHAR; mode: SHORTINT );
				BEGIN
					ASSERT( isKeyInitialized );   (* initKey must have been called before *)
					ASSERT( mode IN {CBC, CTR} );
					SELF.mode := mode;  
					IF mode = CBC THEN  appmode( "-cbc" ) ELSE  appmode( "-ctr" )  END
				END SetIV;

				(** encrypts len bytes of data; len must be a multiple of blockSize *)
				PROCEDURE Encrypt*( VAR buf: ARRAY OF CHAR;  pos, len: LONGINT );
				(* empty Cipher does nothing *)
				END Encrypt;

				(** decrypts len bytes of data; len must be a multiple of blockSize *)
				PROCEDURE Decrypt*( VAR buf: ARRAY OF CHAR;  pos, len: LONGINT );
				(* empty Cipher does nothing *)
				END Decrypt;

				(** this method is invoked by subclasses; blocksize in bytes *)
				PROCEDURE SetNameAndBlocksize*( CONST name: ARRAY OF CHAR;  size: LONGINT );
				BEGIN
					COPY( name, SELF.name );  len1 := 0;
					WHILE name[len1] # 0X DO  INC( len1 )  END;
					len2 := len1;  blockSize := size;
				END SetNameAndBlocksize;

				PROCEDURE & Init*;
				BEGIN
					mode := ECB;  isKeyInitialized := FALSE;
					SetNameAndBlocksize( "empty cipher", 8 );
				END Init;

			END Cipher;

	CipherFactory = PROCEDURE ( ): Cipher;

	(** create a new cipher object of the subtype given in modname*)
	PROCEDURE NewCipher*( CONST modname: ARRAY OF CHAR ): Cipher;
	VAR cipher: Cipher;  factory: CipherFactory;
	BEGIN
		cipher := NIL;
		IF modname # "" THEN
			GETPROCEDURE( modname, "NewCipher", factory );
			IF (factory # NIL ) THEN  cipher := factory()  END
		ELSE  NEW( cipher )
		END;
		RETURN cipher;
	END NewCipher;

END CryptoCiphers.