MODULE X509;
(**
	X.509 Certificates and certificate management.
	See RFC5280 standard.
	Written by Timothée Martiel, 2014, with some fragments by P. Hunziker.
*)
IMPORT Streams, Dates, CryptoBigNumbers, CryptoRSA, ASN1 (*, ASN1Printer*), KernelLog;
CONST
	Trace = FALSE;

	(** Certificate verification status *)
	Correct * = 0; Expired * = 1; SelfSigned * = 2; Incorrect * = 3;
TYPE
	(** Represent an issuer or a subject. Only mandatory fields are kept. Fields are NIL if not present. *)
	Entity * = RECORD
		country-, organisation-, organisationUnit-, distName-, state-, commonName-: POINTER TO ARRAY OF CHAR;
		serial-: LONGINT;
	END;

	(** Base certificate type. Certificates are specialized according to the encryption algorithm they provide. *)
	Certificate * = OBJECT
		VAR
			(* tbsCertificate field of X.509 *)
			version-, serial-: LONGINT;
			algorithm-: POINTER TO ARRAY OF CHAR;
			validity-: RECORD notBefore-, notAfter-: Dates.DateTime END;
			identifier-: POINTER TO ARRAY OF CHAR;
			publicKey-: CryptoRSA.Key;
			issuer-, subject-: Entity;

			(* signatureAlgorithm field of X.509 *)
			(* signatureValue of X.509 *)

		(** Verifies validity of certificate. Returns a value between Correct and 
		*)
		PROCEDURE Verify * (): LONGINT;
		BEGIN
			RETURN Correct
		END Verify;

		(** Reads a certificate from a stream *)
		PROCEDURE Read * (reader: Streams.Reader);
		CONST
			TimeLength = 15;
		VAR
			res: BOOLEAN;
			root, segment, data: ASN1.Triplet;
			length: LONGINT;
			r: Streams.StringReader;
			writer: Streams.Writer;
		BEGIN
			root := ASN1.Decode(reader, 0, length);

			(* tbsCertificate *)
			segment := root.child;

			(* version *)
			data := segment.child;
			(*Check(data.tag = ASN1.Integer);*)
			IF (data.next.tag = ASN1.Integer) THEN
				(* Explicit version specified *)
				IF data.tag = ASN1.Integer THEN
					version := data.ivalue + 1
				ELSE
					version := ORD(data.svalue[0])
				END;
				data := data.next;
			ELSE
				version := 1
			END;

			(* serial. *)
			(*Check(data.tag = ASN1.Integer);*)
			serial := data.ivalue;

			(* algorithm OID *)
			data := data.next;
			(*Check(data.child.tag = ASN1.Oid);*)
			algorithm := data.child.svalue;
			(* Algorithm parameters are ignored *)

			(* issuer = CA *)
			data := data.next;
			FormatEntity(data, issuer);

			(* validity *)
			data := data.next;
			NEW(r, TimeLength);
			r.SetRaw(data.child.svalue^, 0, LEN(data.child.svalue^));
			res := ReadTime(r, validity.notBefore);
			(*Check(res);*)
			r.SetRaw(data.child.next.svalue^, 0, LEN(data.child.next.svalue^));
			r.SetPos(0);			
			res := ReadTime(r, validity.notAfter);
			(*Check(res);*)

			(* subject *)
			data := data.next;
			FormatEntity(data, subject);

			(* subject public key algorithm *)
			(*data := data.next;*)

			(* subject public key *)
			data := data.next;
			FormatRsaPublicKey(data, publicKey);

			IF version > 2 THEN
				(* extensions *)
				data := data.next
			END;

			(* Signature algorithm -- from top level again *)
			segment := segment.next;

			(* Signature value *)
			segment := segment.next;

			IF Trace THEN
				KernelLog.String("========== Read X509 Certificate ========="); KernelLog.Ln;
				Streams.OpenWriter(writer, KernelLog.Send);
				PrintCertificate(SELF, writer);
				KernelLog.String("========== End X509 Certificate ========="); KernelLog.Ln
			END
		END Read;

		(** Writes a certificate to a stream *)
		PROCEDURE Write * (writer: Streams.Writer);
		END Write;
	END Certificate;

	(* ========== Helper procedures ========== *)
	PROCEDURE IsDigit(char: CHAR): BOOLEAN;
	BEGIN
		IF (ORD(char) < ORD('0')) OR (ORD(char) > ORD('9')) THEN
			RETURN FALSE
		ELSE
			RETURN TRUE
		END
	END IsDigit;

	(** Read an UTCTime type object from stream and fills the date with it. Returns success. *)
	PROCEDURE ReadUTCTime(reader: Streams.Reader; VAR date: Dates.DateTime): BOOLEAN;
	VAR
		char: CHAR;
	BEGIN
		(* Year: 2 digits, >= 50 -> 19..; < 50 -> 20.. *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.year := 10 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.year, ORD(char) - ORD('0'));
		IF date.year >= 50 THEN
			INC(date.year, 1900)
		ELSE
			INC(date.year, 2000)
		END;

		(* Month, 2 digits *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.month := 10 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.month, ORD(char) - ORD('0'));

		(* Day, 2 digits *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.day := 10 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.day, ORD(char) - ORD('0'));

		(* Hours, 2 digits *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.hour := 10 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.hour, ORD(char) - ORD('0'));

		(* Minutes, 2 digits *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.minute := 10 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.minute, ORD(char) - ORD('0'));

		(* Seconds, 2 digits *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.second := 10 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.second, ORD(char) - ORD('0'));

		(* Check for trailing 'Z' *)
		char := reader.Get();
		IF char # 'Z' THEN
			RETURN FALSE
		ELSE
			RETURN TRUE
		END
	END ReadUTCTime;

	(** Writes and UTCTime type object from date. *)
	PROCEDURE WriteUTCTime(writer: Streams.Writer; CONST date: Dates.DateTime);
	BEGIN
	END WriteUTCTime;

	(** Same as ReadUTCTime, but reads a GeneralizedTime instead. Returns success. *)
	PROCEDURE ReadGeneralizedTime(reader: Streams.Reader; VAR date: Dates.DateTime): BOOLEAN;
	VAR
		char: CHAR;
	BEGIN
		(* Year: 4 digits *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.year := 1000 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.year, 100 * ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.year, 10 * ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.year, ORD(char) - ORD('0'));
		
		(* Month, 2 digits *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.month := 10 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.month, ORD(char) - ORD('0'));

		(* Day, 2 digits *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.day := 10 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.day, ORD(char) - ORD('0'));

		(* Hours, 2 digits *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.hour := 10 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.hour, ORD(char) - ORD('0'));

		(* Minutes, 2 digits *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.minute := 10 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.minute, ORD(char) - ORD('0'));

		(* Seconds, 2 digits *)
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		date.second := 10 * (ORD(char) - ORD('0'));
		char := reader.Get();
		IF ~IsDigit(char) THEN RETURN FALSE END;
		INC(date.second, ORD(char) - ORD('0'));

		(* Check for trailing 'Z' *)
		char := reader.Get();
		IF char # 'Z' THEN
			RETURN FALSE
		ELSE
			RETURN TRUE
		END
	END ReadGeneralizedTime;

	(** Same as WriteUTCTime, but writes a GeneralizedTime instead. *)
	PROCEDURE WriteGeneralizedTime(writer: Streams.Writer; CONST date: Dates.DateTime);
	BEGIN
		writer.Int(date.year, 4);
		writer.Int(date.month, 2);
		writer.Int(date.day, 2);
		writer.Char('Z')
	END WriteGeneralizedTime;

	(** Selects the reading type: UTCTime or GeneralizedTime *)
	PROCEDURE ReadTime(reader: Streams.Reader; VAR date: Dates.DateTime): BOOLEAN;
	VAR
		pos: LONGINT;
		res: BOOLEAN;
	BEGIN
		res := ReadUTCTime(reader, date);
		IF ~res THEN
			res := ReadGeneralizedTime(reader, date);
			RETURN res
		END;
		RETURN TRUE
	END ReadTime;

	(** Formats an entity record from an ASN1 triplet *)
	PROCEDURE FormatEntity(triplet: ASN1.Triplet; VAR entity: Entity);
	CONST
		Country = 1; Org = 2; OrgUnit = 3; DistNameQual = 4; State = 5; CommonName = 6;
		Serial = 7;
	VAR
		data, key, value: ASN1.Triplet;
		currentData: LONGINT;
	BEGIN
		data := triplet.child;
		WHILE data # NIL DO
			key := data.child;
			WHILE key # NIL DO
				value := key.child;
				WHILE value # NIL DO
					(* If we already registered a data key, we store the value *)
					IF currentData # 0 THEN
						CASE currentData OF
							 Country: entity.country := value.svalue
							|Org: entity.organisation := value.svalue
							|OrgUnit: entity.organisationUnit := value.svalue
							|DistNameQual: entity.distName := value.svalue
							|State: entity.state := value.svalue
							|CommonName: entity.commonName := value.svalue
						END;
						currentData := 0
					ELSIF (value.svalue[0] = 55X) & (value.svalue[1] = 4X) & (value.svalue[2] = 6X) THEN
						currentData := Country
					ELSIF (value.svalue[0] = 55X) & (value.svalue[1] = 4X) & (value.svalue[2] = 8X) THEN
						currentData := State
					ELSIF (value.svalue[0] = 55X) & (value.svalue[1] = 4X) & (value.svalue[2] = 0AX) THEN
						currentData := Org
					ELSIF (value.svalue[0] = 55X) & (value.svalue[1] = 4X) & (value.svalue[2] = 0BX) THEN
						currentData := OrgUnit
					ELSIF (value.svalue[0] = 55X) & (value.svalue[1] = 4X) & (value.svalue[2] = 3X) THEN
						currentData := CommonName
					END;
					value := value.next
				END;
				key := key.next;
			END;
			data := data.next
		END;
	END FormatEntity;

	(** Formats a RSA public key from a ASN1 triplet. *)
	PROCEDURE FormatRsaPublicKey * (publicKey: ASN1.Triplet; VAR key: CryptoRSA.Key);
	VAR
		algo: POINTER TO ARRAY OF CHAR;
		sequence, mod,exp: ASN1.Triplet;
		sr: Streams.StringReader;
		len0:LONGINT;
		modulus, exponent: CryptoBigNumbers.BigNumber;
	BEGIN
		algo := publicKey.child.child.svalue; 

		NEW(sr, LEN(publicKey.child.next.svalue^));
		sr.SetRaw(publicKey.child.next.svalue^, 0, LEN(publicKey.child.next.svalue^));
		sequence := ASN1.Decode(sr, publicKey.child.next.level + 1, len0);

		mod := sequence.child;
		CryptoBigNumbers.AssignBin(modulus, mod.svalue^, 0, LEN(mod.svalue^));

		exp:=mod.next;
		IF exp.ivalue # 0 THEN
			CryptoBigNumbers.AssignInt(exponent, exp.ivalue)
		ELSE
			CryptoBigNumbers.AssignBin(exponent, exp.svalue^, 0, LEN(exp.svalue^))
		END;
		key := CryptoRSA.PubKey(exponent, modulus);
	END FormatRsaPublicKey;

	(** Print a date in human readable form *)
	PROCEDURE PrintDate(date: Dates.DateTime; writer: Streams.Writer);
	BEGIN
		(* date *)
		writer.Int(date.year, 0); writer.String('/'); writer.Int(date.month, 0); writer.String('/'); writer.Int(date.day, 0);

		(* time *)
		writer.String(" "); writer.Int(date.hour, 0); writer.String(":"); writer.Int(date.minute, 0); writer.String(":"); writer.Int(date.second, 0)
	END PrintDate;

	PROCEDURE PrintEntity(entity: Entity; writer: Streams.Writer);
	BEGIN
		IF entity.country # NIL THEN
			writer.String("	country:	"); writer.Bytes(entity.country^, 0, LEN(entity.country)); writer.Ln
		END;
		IF entity.organisation # NIL THEN
			writer.String("	organisation:	"); writer.Bytes(entity.organisation^, 0, LEN(entity.organisation)); writer.Ln
		END;
		IF entity.organisationUnit # NIL THEN
			writer.String("	organisation unit:	"); writer.Bytes(entity.organisationUnit^, 0, LEN(entity.organisationUnit)); writer.Ln
		END;
		IF entity.distName # NIL THEN
			writer.String("	distinguished name:	"); writer.Bytes(entity.distName^, 0, LEN(entity.distName)); writer.Ln
		END;
		IF entity.state # NIL THEN
			writer.String("	state:	"); writer.Bytes(entity.state^, 0, LEN(entity.state)); writer.Ln
		END;
		IF entity.commonName # NIL THEN
			writer.String("	common name:	"); writer.Bytes(entity.commonName^, 0, LEN(entity.commonName)); writer.Ln
		END;
	END PrintEntity;
	
	(** Prints a certificate in human readable form *)
	PROCEDURE PrintCertificate * (certificate: Certificate; writer: Streams.Writer);
	VAR
		count: LONGINT;
		mod: ARRAY 16 * 4096 OF CHAR;
	BEGIN
		writer.String("== Begin of Certificate =="); writer.Ln;

		writer.String("version:	"); writer.Int(certificate.version, 0); writer.Ln;

		writer.String("serial:	"); writer.Int(certificate.serial, 0); writer.Ln;

		writer.String("signature:"); writer.Ln;
		writer.String("	algorithm:	");
		FOR count := 0 TO LEN(certificate.algorithm) - 1 DO
			writer.Hex(ORD(certificate.algorithm[count]), -2); writer.String(" ");
		END;
		writer.Ln;

		writer.String("Issuer:"); writer.Ln;
		PrintEntity(certificate.issuer, writer);

		writer.String("validity:"); writer.Ln;
		writer.String("	not before:	"); PrintDate(certificate.validity.notBefore, writer); writer.Ln;
		writer.String("	not after:	"); PrintDate(certificate.validity.notAfter, writer); writer.Ln;

		writer.String("Subject:"); writer.Ln;
		PrintEntity(certificate.subject, writer);

		writer.String("RSA public key:"); writer.Ln;
		writer.String("	modulus:	"); CryptoBigNumbers.TextWrite(writer, certificate.publicKey.modulus); writer.Ln;
		(*writer.Update;
		CryptoBigNumbers.GetBinaryValue(certificate.publicKey.modulus, mod, 0);
		writer.String("	modulus:	"); FOR count := 0 TO LEN(mod) - 1 DO writer.Hex(ORD(mod[count]), -2); writer.String(' '); writer.Update END; writer.Ln;*)
		writer.String("	exponent:	"); CryptoBigNumbers.TextWrite(writer, certificate.publicKey.exponent); writer.Ln;

		writer.String("== End of Certificate =="); writer.Ln
	END PrintCertificate;

	(* ========== Error reporting ========== *)
	PROCEDURE Check(b: BOOLEAN);
	BEGIN
		ASSERT(b)
	END Check;
END X509.
