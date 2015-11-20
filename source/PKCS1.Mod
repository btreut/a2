(**
	Implementation of the PKCS#1 encryption scheme for RSA.
	See RFC 2437.
	Timothée Martiel, 2014
*)
MODULE PKCS1;

	IMPORT CryptoBigNumbers, CryptoRSA, CryptoUtils, KernelLog;

	CONST
		Trace = FALSE;

	(** Encrypts src[srcOfs] .. src[srcOfs + srcLen - 1] with key and writes the result starting from dest[destOfs]. destLen returns the total written length.
		It uses a block type as specified by blockType. blockType can be 0, 1 or 2.
		destLen = 0 iff encryption failed.
	*)
	PROCEDURE Encrypt * (CONST src: ARRAY OF CHAR; srcOfs, srcLen: LONGINT; key: CryptoRSA.Key; blockType: LONGINT; VAR dest: ARRAY OF CHAR; destOfs: LONGINT; VAR destLen: LONGINT);
		VAR
			k, padd: LONGINT;	(* Length of key modulus and padding string. *)
			counter, ofs: LONGINT;
			encryptionBlock: POINTER TO ARRAY OF CHAR;
			clear, cipher: CryptoBigNumbers.BigNumber;
	BEGIN
		(* Argument checks *)
		ASSERT(key # NIL);
		IF (blockType < 0) OR (blockType > 2) THEN destLen := 0; RETURN END;
		k := 4 * key.modulus.len;
		IF k < 12 THEN destLen := 0; RETURN END;
		IF srcLen > k - 11 THEN destLen := 0; RETURN END;
		IF LEN(src) < srcOfs + srcLen THEN destLen := 0; RETURN END;
		IF LEN(dest) < destOfs + k THEN destLen := 0; RETURN END;

		(* Prepare encryption block *)
		NEW(encryptionBlock, k);
		ofs := 0;
		encryptionBlock[ofs] := 0X; INC(ofs);
		encryptionBlock[ofs] := CHR(blockType); INC(ofs);

		(* Fill padding depending on block type. *)
		padd := k - srcLen - 3;
		ASSERT(padd >= 8);
		CASE blockType OF
			 0:
			 	(* 0X *)
			 	FOR counter := ofs TO ofs + padd - 1 DO
			 		encryptionBlock[counter] := 0X
			 	END
			|1:
				(* 0FFH *)
				FOR counter := ofs TO ofs + padd - 1 DO
					encryptionBlock[counter] := 0FFX
				END
			|2:
				(* Random # 0X *)
				CryptoUtils.RandomBytes(encryptionBlock^, ofs, padd);
				FOR counter := ofs TO ofs + padd - 1 DO
					WHILE encryptionBlock[counter] = 0X DO
						CryptoUtils.RandomBytes(encryptionBlock^, counter, 1)
					END
				END
		END;
		INC(ofs, padd);

		(* Copy separator and data *)
		encryptionBlock[ofs] := 0X; INC(ofs);
		FOR counter := 0 TO srcLen - 1 DO
			encryptionBlock[ofs + counter] := src[srcOfs + counter];
			IF Trace THEN KernelLog.Int(ORD(src[srcOfs + counter]), 0); KernelLog.String(' ') END
		END;
		IF Trace THEN
			KernelLog.Ln;
			KernelLog.String("PKCS#1:"); KernelLog.Ln;
			KernelLog.Buffer(encryptionBlock^, 0, k)
		END;

		(* Encrypt block *)
		CryptoBigNumbers.AssignBin(clear, encryptionBlock^, 0, k);
		cipher := key.Encrypt(clear);
		CryptoBigNumbers.GetBinaryValue(cipher, dest, destOfs);
		destLen := k
	END Encrypt;

	(** Decrypt src[srcOfs] .. src[srcOfs + srcLen - 1] with key, checking for a PKCS#1 formatting with block type blockType.
		The result is written in dest[destOfs] .. dest[destOfs + destLen - 1]. destLen is written with the data length. destLen = 0
		iff decryption failed or PKCS badly formatted.
	*)
	PROCEDURE Decrypt * (CONST src: ARRAY OF CHAR; srcOfs, srcLen: LONGINT; key: CryptoRSA.Key; blockType: LONGINT; VAR dest: ARRAY OF CHAR; destOfs: LONGINT; VAR destLen: LONGINT);
		VAR
			k, padd: LONGINT;
			ofs, counter: LONGINT;
			decryptedBlock: POINTER TO ARRAY OF CHAR;
			clear, cipher: CryptoBigNumbers.BigNumber;
	BEGIN
		(* Argument checks. *)
		k := 4 * key.modulus.len;
		IF srcLen # k THEN destLen := 0; RETURN END;
		(* Guarantees cipher < key.modulus *)
		IF src[srcOfs] # 0X THEN destLen := 0; RETURN END;

		(* Decrypt *)
		CryptoBigNumbers.AssignBin(cipher, src, srcOfs, srcLen);
		clear := key.Decrypt(cipher);
		NEW(decryptedBlock, padd);
		CryptoBigNumbers.GetBinaryValue(clear, decryptedBlock^, 0);

		(* Verify PKCS#1 formatting *)
		ofs := 0;
		IF decryptedBlock[ofs] # 0X THEN destLen := 0; RETURN END;
		INC(ofs);
		IF decryptedBlock[ofs] # CHR(blockType) THEN destLen := 0; RETURN END;
		INC(ofs);
		CASE blockType OF
			 0:
			 	REPEAT INC(ofs) UNTIL decryptedBlock[ofs] # 0X
			|1:
				REPEAT INC(ofs) UNTIL decryptedBlock[ofs] # 0FFX;
				IF decryptedBlock[ofs] # 0X THEN destLen := 0; RETURN END;
				INC(ofs)
			|2:
				REPEAT INC(ofs) UNTIL decryptedBlock[ofs] = 0X;
				INC(ofs)
		END;

		(* ofs points now to the beginning of the data *)
		FOR counter := 0 TO k - ofs - 1 DO
			dest[destOfs + counter] := decryptedBlock[ofs + counter]
		END;
		destLen := k - ofs - 1
	END Decrypt;
END PKCS1.


