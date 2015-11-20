MODULE DivXHelper;

(* Part of the DivXPlayer *)
(* Written by Thomas Trachsel, ttrachsel@web.de, 18.9.2003 *)
(* Heavily based on the OpenDivX Decoder: www.projectmayo.com *)

IMPORT
	SYSTEM, Streams, DT := DivXTypes, AVI, idct := IDCT;

	CONST
		(* Const for idct *)
		W1 = 2841;                (* 2048*sqrt(2)*cos(1*pi/16) *)
		W2 = 2676;                (* 2048*sqrt(2)*cos(2*pi/16) *)
		W3 = 2408;                 (* 2048*sqrt(2)*cos(3*pi/16) *)
		W5 = 1609;                 (* 2048*sqrt(2)*cos(5*pi/16) *)
		W6 = 1108;                 (* 2048*sqrt(2)*cos(6*pi/16) *)
		W7 = 565;                  (* 2048*sqrt(2)*cos(7*pi/16) *)

	(* VLD Escape *)
		Escape = 7167;

	TYPE Event = RECORD
		last, run, level: LONGINT;
	END;

	(* Texture Decoding of a Block *)
	TYPE TextureDecoding* = OBJECT
	VAR
		block*: DT.PointerToArrayOfLONGINT;
		mp4State: DT.MP4State;
		dcScaler: LONGINT;
		saiAcLeftIndex: ARRAY 8 OF LONGINT;
		vld: VLD;
		log: Streams.Writer;
		srcBlock, dstBlock*: POINTER TO ARRAY 68 OF INTEGER;

	PROCEDURE & init*( state: DT.MP4State; logWriter: Streams.Writer );
	BEGIN
		log := logWriter;
		NEW(vld, log);
		mp4State := state;

		saiAcLeftIndex[0] := 0;
		saiAcLeftIndex[1] := 8;
		saiAcLeftIndex[2] := 16;
		saiAcLeftIndex[3] := 24;
		saiAcLeftIndex[4] := 32;
		saiAcLeftIndex[5] := 40;
		saiAcLeftIndex[6] := 48;
		saiAcLeftIndex[7] := 56;

		NEW( block, 64 );
		NEW(srcBlock); NEW(dstBlock);
	END init;

	PROCEDURE ClearBlock;
	BEGIN
		IF DT.EnableMMX THEN ClearBlockMMX( ADDRESSOF( block[0] ) );
		ELSE ClearBlockGeneric();
		END;
	END ClearBlock;

	(* Reset block to 0 *)
	PROCEDURE ClearBlockGeneric;
	VAR
		i: LONGINT;
		adr: LONGINT;
	BEGIN
		adr := ADDRESSOF( block[0] );
		FOR i := 0 TO 63 DO
			SYSTEM.PUT32( adr, 0 );
			adr := adr + SIZEOF( LONGINT )
		END;
	END ClearBlockGeneric;

	PROCEDURE ClearBlockMMX( dst: LONGINT );
	CODE{ SYSTEM.MMX, SYSTEM.PentiumPro }
		MOV		EDX, -32				; clear loop counter
		MOV		ESI, [EBP+dst]			; capture block address

		PXOR  MMX0, MMX0					; mm0 = 0
	loop:
		MOVQ	[ESI], MMX0					; clear memory location
		ADD		ESI, 8
		INC		EDX
		JNZ		loop
		EMMS
	END ClearBlockMMX;

	(* Decode an intracoded macroblock *)
	PROCEDURE BlockIntra*( blockNum: LONGINT; coded:BOOLEAN; VAR r: DT.VideoBuffer ): LONGINT;
	VAR
		i, dctDcSize, dctDcDiff, temp: LONGINT;
		event: Event;
		zigzag: DT.PointerToArrayOfLONGINT;
	BEGIN
		ClearBlock();

		(* dc coeff *)
		SetDCScaler(blockNum); 							(* calculate DC scaler *)

		IF blockNum < 4 THEN
			dctDcSize := GetDCSizeLum(r);
			IF dctDcSize # 0 THEN
				dctDcDiff := GetDCDiff( dctDcSize, r )
			ELSE
				dctDcDiff := 0
			END;

			IF dctDcSize > 8 THEN
				temp := AVI.GetBits(1, r.data^ , r.index);	(* marker bit *)
			END;
		ELSE
			dctDcSize := GetDCSizeChr(r);
			IF dctDcSize # 0 THEN
				dctDcDiff := GetDCDiff( dctDcSize, r )
			ELSE
				dctDcDiff := 0
			END;

			IF dctDcSize > 8 THEN
				temp := AVI.GetBits(1, r.data^, r.index );	(* marker bit *)
			END;
		END;
		block[0] := dctDcDiff;

		IF DT.Debug THEN
			log.String("dctDcSize, dctDcDiff: "); log.Int( dctDcSize, 0 ); log.Char( ' ' ); log.Int(dctDcDiff, 00 ); log.Ln()
		END;

		(*  dc reconstruction, prediction direction *)
		DCRecon( blockNum, block );

		IF coded THEN
			IF mp4State.hdr.acPredFlag = 1 THEN
				IF mp4State.coeffPred.predictDir = DT.Top THEN
					zigzag := mp4State.mp4Tables.alternateHorizontalScan
				ELSE
					zigzag := mp4State.mp4Tables.alternateVerticalScan
				END;
			ELSE
				zigzag := mp4State.mp4Tables.zigZagScan
			END;

			(* VLD Decoding *)
			i := 1;
			REPEAT (* event vld *)
				vld.VldIntraDCT( event, r );
				ASSERT( event.run # -1 );
				i := i + event.run;
				block[zigzag[i]] := event.level;

				IF DT.Debug THEN
					log.String( "Vld Intra Event: Run Level Last " ); log.Int( event.run, 0 ); log.Char( ' ' );
					log.Int( event.level, 0 ); log.Char( ' ' ); log.Int( event.last, 0 ); log.Ln()
				END;

				INC( i )
			UNTIL event.last # 0;
		END;

		(* ac reconstruction *)
		mp4State.hdr.intraBlockRescaled := ACRescaling(blockNum, block );

		IF mp4State.hdr.intraBlockRescaled = 0 THEN
			ACRecon( blockNum, block )
		END;

		ACStore(blockNum, block );

		(* Inverse quantization *)
		IF mp4State.hdr.quantType = 0 THEN IQuant( block, TRUE )
		ELSE IQuantTypeFirst( block )
		END;

		(* inverse dct *)
		IDCT( block );

		RETURN 1
	END BlockIntra;

	(* Decode an intercoded macroblock *)
	PROCEDURE BlockInter*( blockNum: LONGINT; coded: BOOLEAN; VAR r: DT.VideoBuffer ): LONGINT;
	VAR
		event: Event;
		zigzag: DT.PointerToArrayOfLONGINT;
		k, m, i, qScale, q2Scale, qAdd: LONGINT;

	BEGIN
		(* Clear Block *)
		ClearBlock();
		zigzag := mp4State.mp4Tables.zigZagScan; 	(* zigzag scan dir *)

		(* inverse quant type *)
		IF mp4State.hdr.quantType = 0 THEN
			qScale := mp4State.hdr.quantizer;
			q2Scale := qScale * 2;
			IF ( qScale MOD 2 ) > 0 THEN qAdd := qScale
			ELSE qAdd := qScale - 1
			END;

			(* VLD Decoding *)
			i := 0;
			REPEAT (* event vld *)
				vld.VldInterDCT( event, r );
				ASSERT( i # -1 );

				i := i + event.run;
				IF event.level > 0 THEN block[zigzag[i]] := ( q2Scale * event.level ) + qAdd
				ELSE block[zigzag[i]] := ( q2Scale * event.level ) - qAdd
				END;

				IF DT.Debug THEN
					log.String( "Vld Inter Event: Run Level Last " ); log.Int( event.run, 0 ); log.Char( ' ' ); log.Int( event.level, 0 );
					log.Char( ' ' ); log.Int( event.last, 0 ); log.Ln()
				END;

				INC( i )
			UNTIL event.last # 0;
		ELSE
			m := 0; i := 0;

			(* event vld *)
			REPEAT
				vld.VldInterDCT( event, r );
				i := i + event.run;

				IF event.level > 0 THEN k := 1
				ELSE k := -1
				END;

				block[zigzag[i]] := ( ( 2 * event.level + k ) * mp4State.hdr.quantizer *
					mp4State.mp4Tables.nonIntraQuantMatrix[zigzag[i]] ) DIV 16;

				m := SYSTEM.VAL( LONGINT, SYSTEM.VAL( SET, m ) / SYSTEM.VAL( SET, block[zigzag[i]] ) );

				IF DT.Debug THEN
					log.String( "Vld Inter Event: Run Level Last " ); log.Int( event.run, 0 ); log.Char( ' ' ); log.Int( event.level, 0 );
					log.Char( ' ' ); log.Int( event.last, 0 ); log.Ln()
				END;

				INC( i )
			UNTIL event.last # 0;

			(* if (!(m%2)) ld->block[63] ^= 1; *)
			IF ( m MOD 2 ) = 0 THEN
				block[63] := SYSTEM.VAL( LONGINT, SYSTEM.VAL( SET , block[63] ) / SYSTEM.VAL(SET, 1 ) )
			END;
		END;

		(* inverse dct *)
		IDCT( block );

		RETURN 1
	END BlockInter;

	(* Dump macroblock into logfile *)
	PROCEDURE DumpMacroBlock;
	VAR
		i: LONGINT;
	BEGIN
		log.String( "Macroblock: " );
		FOR i := 0 TO 63 DO
			log.Int( block[i], 0 ); log.String( " " )
		END;
		log.Ln()
	END DumpMacroBlock;

	(* Get size of the vld code used to derive the luminance DC coefficients *)
	PROCEDURE GetDCSizeLum(VAR r: DT.VideoBuffer): LONGINT;
	VAR
		code: LONGINT;
	BEGIN
		IF AVI.ShowBits(11, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(11, r.index );
			RETURN 12
		END;
		IF AVI.ShowBits(10, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(10, r.index );
			RETURN 11
		END;
		IF AVI.ShowBits(9, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(9, r.index );
			RETURN 10
		END;
		IF AVI.ShowBits(8, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(8, r.index );
			RETURN 9
		END;
		IF AVI.ShowBits(7, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(7, r.index );
			RETURN 8
		END;
		IF AVI.ShowBits(6, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(6, r.index );
			RETURN 7
		END;
		IF AVI.ShowBits(5, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(5, r.index );
			RETURN 6
		END;
		IF AVI.ShowBits(4, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(4, r.index );
			RETURN 5
		END;

		code := AVI.ShowBits(3, r.data^, r.index);
		IF code = 1 THEN
			AVI.SkipBits(3, r.index);
			RETURN 4
		ELSIF code = 2 THEN
			AVI.SkipBits(3, r.index);
			RETURN 3
		ELSIF code = 3 THEN
			AVI.SkipBits(3, r.index);
			RETURN 0
		END;

		code := AVI.ShowBits(2, r.data^, r.index);
		IF code = 2 THEN
			AVI.SkipBits(2, r.index);
			RETURN 2
		ELSIF code = 3 THEN
			AVI.SkipBits(2, r.index);
			RETURN 1
		END;

		RETURN 0
	END GetDCSizeLum;

	(* Get ize of the vld code used to derive the chrominance DC coefficients *)
	PROCEDURE GetDCSizeChr(VAR r: DT.VideoBuffer):LONGINT;
	BEGIN
		IF AVI.ShowBits(12, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(12, r.index);
			RETURN 12
		END;
		IF AVI.ShowBits(11, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(11, r.index);
			RETURN 11
		END;
		IF AVI.ShowBits(10, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(10, r.index);
			RETURN 10
		END;
		IF AVI.ShowBits(9, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(9, r.index);
			RETURN 9
		END;
		IF AVI.ShowBits(8, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(8, r.index);
			RETURN 8
		END;
		IF AVI.ShowBits(7, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(7, r.index);
			RETURN 7
		END;
		IF AVI.ShowBits(6, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(6, r.index);
			RETURN 6
		END;
		IF AVI.ShowBits(5, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(5, r.index);
			RETURN 5
		END;
		IF AVI.ShowBits(4, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(4, r.index);
			RETURN 4
		END;
		IF AVI.ShowBits(3, r.data^, r.index ) = 1 THEN
			AVI.SkipBits(3, r.index);
			RETURN 3
		END;

		RETURN 3 - AVI.GetBits(2, r.data^, r.index);
	END GetDCSizeChr;

	(* Used to derive the value of the differential DC coefficients in intra macroblocks *)
	PROCEDURE GetDCDiff( dctDCSize: LONGINT; VAR r: DT.VideoBuffer ): LONGINT;
	VAR
		code, msb: LONGINT;
	BEGIN
		code := AVI.GetBits(dctDCSize, r.data^, r.index );
		msb := LSH( code, -(dctDCSize - 1) );

		IF msb = 0 THEN
			RETURN  -SYSTEM.VAL( LONGINT, ( SYSTEM.VAL( SET, code ) /
				SYSTEM.VAL( SET , Pow( 2, dctDCSize ) - 1 ) ) )
		ELSE
			RETURN code
		END;
	END GetDCDiff;

	(* Helper Function *)
	PROCEDURE Pow( x, y: LONGINT ): LONGINT;
	VAR
		res, count: LONGINT;
	BEGIN
		IF y = 0 THEN
			RETURN 1;
		END;
		res := x;
		FOR count := 0 TO y - 2 DO
			res := res * x
		END;

		RETURN res
	END Pow;

	(* Used to scale the DC coefficients *)
	PROCEDURE SetDCScaler( blockNum: LONGINT );
	VAR
		quant: LONGINT;
	BEGIN
		quant := mp4State.hdr.quantizer;

		IF blockNum < 4 THEN
			IF ( quant > 0 ) & ( quant < 5) THEN
				dcScaler := 8
			ELSIF ( quant > 4 ) & ( quant < 9 ) THEN
				dcScaler := ( 2 * quant )
			ELSIF ( quant > 8 ) & ( quant < 25 ) THEN
				dcScaler := ( quant + 8 )
			ELSE
				dcScaler := ( 2 * quant - 16 )
			END;
		ELSE
			IF ( quant > 0 ) & ( quant < 5 ) THEN
				dcScaler := 8
			ELSIF ( quant > 4 ) & ( quant < 25 ) THEN
				dcScaler := ( ( quant + 13 ) DIV 2 )
			ELSE
				dcScaler := ( quant - 6 )
			END;
		END;
	END SetDCScaler;

(*

	B - C
	|   |
	A - x

*)
	(* Reconstruct the DC coefficients *)
	PROCEDURE DCRecon( blockNum: LONGINT; dcValue: DT.PointerToArrayOfLONGINT );
	VAR
		bXPos, bYPos, dcPred, chrNum: LONGINT;
		dcStoreLum: DT.DCStoreLumArray;
		dcStoreChr: DT.DCStoreChrArray;
		temp1, temp2: LONGINT; (* Due to compiler limitation *)
	BEGIN
		IF mp4State.hdr.predictionType = DT.PVOP THEN
			RescuePredict()
		END;

		IF blockNum < 4 THEN
			dcStoreLum := mp4State.coeffPred.dcStoreLum;
			bXPos := ( mp4State.hdr.mbXPos * 2 )  + ( blockNum MOD 2 );
			bYPos := ( mp4State.hdr.mbYPos * 2 ) + ( ( blockNum MOD 4 ) DIV 2 );

			(* set prediction direction *)
			(* ( Fa - Fb ) < ( Fb - Fc ) *)
			temp1 := ABS( dcStoreLum[bYPos][bXPos] - dcStoreLum[bYPos+1][bXPos] );
			temp2 := ABS( dcStoreLum[bYPos][bXPos] - dcStoreLum[bYPos][bXPos+1] );
			IF temp1 < temp2 THEN
				mp4State.coeffPred.predictDir := DT.Top;
				dcPred := dcStoreLum[bYPos][bXPos+1]
			ELSE
				mp4State.coeffPred.predictDir := DT.Left;
				dcPred := dcStoreLum[bYPos+1][bXPos]
			END;

			dcValue[0] := dcValue[0] + DivDiv( dcPred, dcScaler );
			dcValue[0] := dcValue[0] * dcScaler;

			(* store dc value *)
			dcStoreLum[bYPos+1][bXPos+1] := dcValue[0]
		ELSE (* chrominance blocks *)
			dcStoreChr := mp4State.coeffPred.dcStoreChr;
			bXPos := mp4State.hdr.mbXPos;
			bYPos := mp4State.hdr.mbYPos;
			chrNum := blockNum - 4;

			(* set prediction direction *)
			(* Fa - Fb < Fb - Fc *)
			temp1 := dcStoreChr[chrNum][bYPos][bXPos];
			temp1 := ABS( temp1 - dcStoreChr[chrNum][bYPos+1][bXPos] );
			temp2 := dcStoreChr[chrNum][bYPos][bXPos];
			temp2 := ABS( temp2 - dcStoreChr[chrNum][bYPos][bXPos+1] );
			IF temp1 < temp2 THEN
				mp4State.coeffPred.predictDir := DT.Top;
				dcPred := dcStoreChr[chrNum][bYPos][bXPos+1]
			ELSE
				mp4State.coeffPred.predictDir := DT.Left;
				dcPred := dcStoreChr[chrNum][bYPos+1][bXPos]
			END;

			dcValue[0] := dcValue[0] + DivDiv( dcPred, dcScaler );
			dcValue[0] := dcValue[0] * dcScaler;

			(* store dc value *)
			temp1 := dcValue[0];
			mp4State.coeffPred.dcStoreChr[chrNum][bYPos+1][bXPos+1] := temp1
		END;
	END DCRecon;

	(* Helper function *)
	PROCEDURE DivDiv( a, b: LONGINT ): LONGINT;
	BEGIN
		IF a > 0 THEN
			RETURN ( a + ( b DIV 2 ) ) DIV b
		ELSE
			RETURN ( a - ( b DIV 2 ) ) DIV b
		END;
	END DivDiv;

	(* Reconstruct AC Prediction *)
	PROCEDURE ACRecon(blockNum: LONGINT;  psBlock: DT.PointerToArrayOfLONGINT );
	VAR
		i, bXPos, bYPos, chrNum: LONGINT;
		temp, temp2: LONGINT; (* Due to compiler limitations *)
	BEGIN
		IF blockNum < 4 THEN
			bXPos := (mp4State.hdr.mbXPos * 2 ) + ( blockNum MOD 2 );
			bYPos := (mp4State.hdr.mbYPos *2 ) + ( ( blockNum MOD 4 ) DIV 2 );
		ELSE
			bXPos := mp4State.hdr.mbXPos;
			bYPos := mp4State.hdr.mbYPos;
		END;

		(* predict coefficients *)
		IF mp4State.hdr.acPredFlag > 0 THEN
			IF blockNum < 4 THEN
				IF mp4State.coeffPred.predictDir = DT.Top THEN
					FOR i := 1 TO 7 DO
						temp := mp4State.coeffPred.acTopLum[bYPos][bXPos + 1][i - 1];
						psBlock[i] := psBlock[i] + temp
					END;
				ELSE (* left prediction *)
					FOR i := 1 TO 7 DO
						temp := saiAcLeftIndex[i];
						temp2 := psBlock[temp];
						psBlock[temp] := temp2 + mp4State.coeffPred.acLeftLum[bYPos+1][bXPos][i-1]
					END;
				END;
			ELSE
				chrNum := blockNum - 4;

				IF mp4State.coeffPred.predictDir = DT.Top THEN
					FOR i := 1 TO 7 DO
						temp2 := bXPos+1;
						temp := mp4State.coeffPred.acTopChr[chrNum][bYPos][temp2][i-1];
						psBlock[i] := psBlock[i] + temp
					END;
				ELSE (* left prediction *)
					FOR i := 1 TO 7 DO
						temp := mp4State.coeffPred.acLeftChr[chrNum][bYPos+1][bXPos][i-1];
						psBlock[saiAcLeftIndex[i]] := psBlock[saiAcLeftIndex[i]] + temp
					END;
				END;
			END;
		END;
	END ACRecon;

	(* Store AC Prediction for later use *)
	PROCEDURE ACStore( blockNum: LONGINT; psBlock: DT.PointerToArrayOfLONGINT );
	VAR
		bXPos, bYPos, i, chrNum: LONGINT;
		temp1, temp2, temp3, temp4: LONGINT; (* Due to compiler limits *)
	BEGIN
			IF blockNum < 4 THEN
			bXPos := ( mp4State.hdr.mbXPos * 2 ) + ( blockNum MOD 2 );
			bYPos := ( mp4State.hdr.mbYPos * 2 ) + ( ( blockNum MOD 4 ) DIV 2)
		ELSE
			bXPos := mp4State.hdr.mbXPos;
			bYPos := mp4State.hdr.mbYPos
		END;

		temp1 := bYPos + 1;
		temp2 := bXPos + 1;

		(* store coefficients *)
		IF blockNum < 4 THEN
			FOR i := 1 TO 7 DO
				temp3 := i - 1;
				mp4State.coeffPred.acTopLum[temp1][temp2][temp3] := psBlock[i];
				mp4State.coeffPred.acLeftLum[temp1][temp2][temp3] := psBlock[saiAcLeftIndex[i]]
			END;
		ELSE
			chrNum := blockNum - 4;
			FOR i := 1 TO 7 DO
				temp3 := i - 1;
				temp4 := psBlock[i];
				mp4State.coeffPred.acTopChr[chrNum][temp1][temp2][temp3] := temp4;
				temp4 := psBlock[saiAcLeftIndex[i]];
				mp4State.coeffPred.acLeftChr[chrNum][temp1][temp2][temp3] := temp4
			END;
		END;
	END ACStore;

	PROCEDURE Rescale( predictQuant, currentQuant, coeff: LONGINT ): LONGINT;
	BEGIN
		IF coeff # 0 THEN
			RETURN DivDiv( coeff* predictQuant, currentQuant )
		ELSE
			RETURN 0
		END;
	END Rescale;

	(* AC Rescaling *)
	PROCEDURE ACRescaling( blockNum: LONGINT; psBlock: DT.PointerToArrayOfLONGINT ): LONGINT;
	VAR
		mbXPos, mbYPos, currentQuant, predictQuant, bXPos, bYPos, i: LONGINT;
		temp1, temp2: LONGINT;
	BEGIN
		mbXPos := mp4State.hdr.mbXPos;
		mbYPos := mp4State.hdr.mbYPos;
		currentQuant := mp4State.hdr.quantizer;

		IF mp4State.coeffPred.predictDir = DT.Top THEN
			predictQuant := mp4State.quantStore[mbYPos][mbXPos + 1]
		ELSE
			predictQuant := mp4State.quantStore[mbYPos + 1][mbXPos]
		END;

		IF ( mp4State.hdr.acPredFlag = 0 ) OR ( currentQuant = predictQuant ) OR ( blockNum = 3 ) THEN
			RETURN 0
		END;

		IF ( mbYPos = 0 ) & ( mp4State.coeffPred.predictDir = DT.Top ) THEN
			RETURN 0
		END;
		IF ( mbXPos = 0 ) & ( mp4State.coeffPred.predictDir = DT.Left ) THEN
			RETURN 0
		END;
		IF ( mbXPos = 0 ) & ( mbYPos = 0 ) THEN
			RETURN 0
		END;

		IF blockNum < 4 THEN
			bXPos := ( mp4State.hdr.mbXPos * 2 ) + ( blockNum MOD 2 );
			bYPos := ( mp4State.hdr.mbYPos * 2 ) + ( ( blockNum MOD 4 ) DIV 2 );
		ELSE
			bXPos := mp4State.hdr.mbXPos;
			bYPos := mp4State.hdr.mbYPos;
		END;

		IF mp4State.coeffPred.predictDir = DT.Top THEN (* rescale only if really needed *)
			CASE blockNum OF
				0 ..  1:
					FOR i := 1 TO 7 DO
						psBlock[i] := psBlock[i] +
							Rescale( predictQuant, currentQuant, mp4State.coeffPred.acTopLum[bYPos][bXPos + 1][i - 1] )
					END;
					RETURN 1;
			| 4:
				temp1 := bXPos + 1;
				FOR i := 1 TO 7 DO
					temp2 := i - 1;
					psBlock[i] := psBlock[i] +
						Rescale(predictQuant, currentQuant, mp4State.coeffPred.acTopChr[0][bYPos][temp1][temp2])
				END;
				RETURN 1;
			| 5:
				temp1 := bXPos + 1;
				FOR i := 1 TO 7 DO
					temp2 := i - 1;
					psBlock[i] := psBlock[i] +
						Rescale( predictQuant, currentQuant, mp4State.coeffPred.acTopChr[1][bYPos][temp1][temp2])
				END;
				RETURN 1;
			ELSE
				(* Nothing to do *)
			END;
		ELSE
			CASE blockNum OF
				0:
					FOR i := 1 TO 7 DO
						psBlock[saiAcLeftIndex[i]] := psBlock[saiAcLeftIndex[i]] +
							Rescale( predictQuant, currentQuant, mp4State.coeffPred.acLeftLum[bYPos + 1][bXPos][i - 1] )
					END;
					RETURN 1;
			| 2:
				FOR i := 1 TO 7 DO
					psBlock[saiAcLeftIndex[i]] := psBlock[saiAcLeftIndex[i]] +
						Rescale( predictQuant, currentQuant, mp4State.coeffPred.acLeftLum[bYPos + 1][bXPos][i - 1] )
				END;
				RETURN 1;
			| 4:
				FOR i := 1 TO 7 DO
					psBlock[saiAcLeftIndex[i]] := psBlock[saiAcLeftIndex[i]] +
						Rescale(predictQuant, currentQuant, mp4State.coeffPred.acLeftChr[0][bYPos + 1][bXPos][i - 1] )
				END;
				RETURN 1;
			| 5:
				FOR i := 1 TO 7 DO
					psBlock[saiAcLeftIndex[i]] := psBlock[saiAcLeftIndex[i]]
						+ Rescale(predictQuant, currentQuant, mp4State.coeffPred.acLeftChr[1][bYPos + 1][bXPos][i - 1] )
				END;
				RETURN 1;
			ELSE
				(* Nothing to do *)
			END;
		END;
		RETURN 0;
	END ACRescaling;

	(* Check if block is an intra block *)
	PROCEDURE IsIntra( mbY, mbX: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ( mp4State.modeMap[mbY + 1][mbX + 1] = DT.Intra ) OR
			( mp4State.modeMap[mbY + 1][mbX + 1] = DT.IntraQ )
	END IsIntra;

	(* Rescue Prediction *)
	PROCEDURE RescuePredict;
	VAR
		mbXPos, mbYPos, i: LONGINT;
	BEGIN
		mbXPos := mp4State.hdr.mbXPos;
		mbYPos := mp4State.hdr.mbYPos;

		IF IsIntra( mbYPos - 1, mbXPos - 1 ) = FALSE THEN
			(* rescue -A- DC value *)
			mp4State.coeffPred.dcStoreLum[2*mbYPos][2*mbXPos] := 1024;
			mp4State.coeffPred.dcStoreChr[0][mbYPos][mbXPos] := 1024;
			mp4State.coeffPred.dcStoreChr[1][mbYPos][mbXPos] := 1024
		END;

		(* left *)
		IF IsIntra( mbYPos, mbXPos - 1 ) = FALSE THEN
			(* rescue -B- DC values *)
			mp4State.coeffPred.dcStoreLum[2*mbYPos + 1][2*mbXPos] := 1024;
			mp4State.coeffPred.dcStoreLum[2*mbYPos + 2][2*mbXPos] := 1024;
			mp4State.coeffPred.dcStoreChr[0][mbYPos + 1][mbXPos] := 1024;
			mp4State.coeffPred.dcStoreChr[1][mbYPos + 1][mbXPos] := 1024;
			(* rescue -B- AC values *)
			FOR i := 0 TO 6 DO
				mp4State.coeffPred.acLeftLum[2*mbYPos + 1][2*mbXPos][i] := 0;
				mp4State.coeffPred.acLeftLum[2*mbYPos + 2][2*mbXPos][i] := 0;
				mp4State.coeffPred.acLeftChr[0][mbYPos + 1][mbXPos][i] := 0;
				mp4State.coeffPred.acLeftChr[1][mbYPos + 1][mbXPos][i] := 0
			END;
		END;
		(* top *)
		IF IsIntra( mbYPos - 1, mbXPos ) = FALSE THEN
			(* rescue -C- DC values *)
			mp4State.coeffPred.dcStoreLum[2*mbYPos][2*mbXPos + 1] := 1024;
			mp4State.coeffPred.dcStoreLum[2*mbYPos][2*mbXPos + 2] := 1024;
			mp4State.coeffPred.dcStoreChr[0][mbYPos][mbXPos + 1] := 1024;
			mp4State.coeffPred.dcStoreChr[1][mbYPos][mbXPos + 1] := 1024;
			(* rescue -C- AC values *)
			FOR i := 0 TO 6 DO
				mp4State.coeffPred.acTopLum[2*mbYPos][2*mbXPos + 1][i] := 0;
				mp4State.coeffPred.acTopLum[2*mbYPos][2*mbXPos + 2][i] := 0;
				mp4State.coeffPred.acTopChr[0][mbYPos][mbXPos + 1][i] := 0;
				mp4State.coeffPred.acTopChr[1][mbYPos][mbXPos + 1][i] := 0
			END;
		END
	END RescuePredict;

	PROCEDURE FastCopy(from, sizefrom, offsetfrom, to, sizeto, offsetto: LONGINT);

	END FastCopy;


	(* two dimensional inverse discrete cosine transform - not optimized *)
	PROCEDURE IDCT( block: DT.PointerToArrayOfLONGINT );
	BEGIN
		srcBlock[4] := SHORT(block[0]);
		srcBlock[5] := SHORT(block[1]);
		srcBlock[6] := SHORT(block[2]);
		srcBlock[7] := SHORT(block[3]);
		srcBlock[8] := SHORT(block[4]);
		srcBlock[9] := SHORT(block[5]);
		srcBlock[10] := SHORT(block[6]);
		srcBlock[11] := SHORT(block[7]);

		srcBlock[12] := SHORT(block[8]);
		srcBlock[13] := SHORT(block[9]);
		srcBlock[14] := SHORT(block[10]);
		srcBlock[15] := SHORT(block[11]);
		srcBlock[16] := SHORT(block[12]);
		srcBlock[17] := SHORT(block[13]);
		srcBlock[18] := SHORT(block[14]);
		srcBlock[19] := SHORT(block[15]);

		srcBlock[20] := SHORT(block[16]);
		srcBlock[21] := SHORT(block[17]);
		srcBlock[22] := SHORT(block[18]);
		srcBlock[23] := SHORT(block[19]);
		srcBlock[24] := SHORT(block[20]);
		srcBlock[25] := SHORT(block[21]);
		srcBlock[26] := SHORT(block[22]);
		srcBlock[27] := SHORT(block[23]);

		srcBlock[28] := SHORT(block[24]);
		srcBlock[29] := SHORT(block[25]);
		srcBlock[30] := SHORT(block[26]);
		srcBlock[31] := SHORT(block[27]);
		srcBlock[32] := SHORT(block[28]);
		srcBlock[33] := SHORT(block[29]);
		srcBlock[34] := SHORT(block[30]);
		srcBlock[35] := SHORT(block[31]);


		srcBlock[36] := SHORT(block[32]);
		srcBlock[37] := SHORT(block[33]);
		srcBlock[38] := SHORT(block[34]);
		srcBlock[39] := SHORT(block[35]);
		srcBlock[40] := SHORT(block[36]);
		srcBlock[41] := SHORT(block[37]);
		srcBlock[42] := SHORT(block[38]);
		srcBlock[43] := SHORT(block[39]);

		srcBlock[44] := SHORT(block[40]);
		srcBlock[45] := SHORT(block[41]);
		srcBlock[46] := SHORT(block[42]);
		srcBlock[47] := SHORT(block[43]);
		srcBlock[48] := SHORT(block[44]);
		srcBlock[49] := SHORT(block[45]);
		srcBlock[50] := SHORT(block[46]);
		srcBlock[51] := SHORT(block[47]);

		srcBlock[52] := SHORT(block[48]);
		srcBlock[53] := SHORT(block[49]);
		srcBlock[54] := SHORT(block[50]);
		srcBlock[55] := SHORT(block[51]);
		srcBlock[56] := SHORT(block[52]);
		srcBlock[57] := SHORT(block[53]);
		srcBlock[58] := SHORT(block[54]);
		srcBlock[59] := SHORT(block[55]);

		srcBlock[60] := SHORT(block[56]);
		srcBlock[61] := SHORT(block[57]);
		srcBlock[62] := SHORT(block[58]);
		srcBlock[63] := SHORT(block[59]);
		srcBlock[64] := SHORT(block[60]);
		srcBlock[65] := SHORT(block[61]);
		srcBlock[66] := SHORT(block[62]);
		srcBlock[67] := SHORT(block[63]);

		idct.Transform(ADDRESSOF(srcBlock[4]), ADDRESSOF(dstBlock[4]));

(*		block[0] := LONG(dstBlock[4]);
		block[1] := LONG(dstBlock[5]);
		block[2] := LONG(dstBlock[6]);
		block[3] := LONG(dstBlock[7]);
		block[4] := LONG(dstBlock[8]);
		block[5] := LONG(dstBlock[9]);
		block[6] := LONG(dstBlock[10]);
		block[7] := LONG(dstBlock[11]);
		block[8] := LONG(dstBlock[12]);
		block[9] := LONG(dstBlock[13]);
		block[10] := LONG(dstBlock[14]);
		block[11] := LONG(dstBlock[15]);

		block[12] := LONG(dstBlock[16]);
		block[13] := LONG(dstBlock[17]);
		block[14] := LONG(dstBlock[18]);
		block[15] := LONG(dstBlock[19]);
		block[16] := LONG(dstBlock[20]);
		block[17] := LONG(dstBlock[21]);
		block[18] := LONG(dstBlock[22]);
		block[19] := LONG(dstBlock[23]);

		block[20] := LONG(dstBlock[24]);
		block[21] := LONG(dstBlock[25]);
		block[22] := LONG(dstBlock[26]);
		block[23] := LONG(dstBlock[27]);
		block[24] := LONG(dstBlock[28]);
		block[25] := LONG(dstBlock[29]);
		block[26] := LONG(dstBlock[30]);
		block[27] := LONG(dstBlock[31]);

		block[28] := LONG(dstBlock[32]);
		block[29] := LONG(dstBlock[33]);
		block[30] := LONG(dstBlock[34]);
		block[31] := LONG(dstBlock[35]);
		block[32] := LONG(dstBlock[36]);
		block[33] := LONG(dstBlock[37]);
		block[34] := LONG(dstBlock[38]);
		block[35] := LONG(dstBlock[39]);


		block[36] := LONG(dstBlock[40]);
		block[37] := LONG(dstBlock[41]);
		block[38] := LONG(dstBlock[42]);
		block[39] := LONG(dstBlock[43]);
		block[40] := LONG(dstBlock[44]);
		block[41] := LONG(dstBlock[45]);
		block[42] := LONG(dstBlock[46]);
		block[43] := LONG(dstBlock[47]);

		block[44] := LONG(dstBlock[48]);
		block[45] := LONG(dstBlock[49]);
		block[46] := LONG(dstBlock[50]);
		block[47] := LONG(dstBlock[51]);
		block[48] := LONG(dstBlock[52]);
		block[49] := LONG(dstBlock[53]);
		block[50] := LONG(dstBlock[54]);
		block[51] := LONG(dstBlock[55]);

		block[52] := LONG(dstBlock[56]);
		block[53] := LONG(dstBlock[57]);
		block[54] := LONG(dstBlock[58]);
		block[55] := LONG(dstBlock[59]);
		block[56] := LONG(dstBlock[60]);
		block[57] := LONG(dstBlock[61]);
		block[58] := LONG(dstBlock[62]);
		block[59] := LONG(dstBlock[63]);

		block[60] := LONG(dstBlock[64]);
		block[61] := LONG(dstBlock[65]);
		block[62] := LONG(dstBlock[66]);
		block[63] := LONG(dstBlock[67]);
*)

		IF DT.Debug THEN
			DumpMacroBlock()
		END;
	END IDCT;

	(* row (horizontal) IDCT

	  7                       pi         1 dst[k] = sum c[l] * src[l] * cos( -- *
  	( k + - ) * l ) l=0                      8          2

  		where: c[0]    = 128 c[1..7] = 128*sqrt(2)
	*)
	PROCEDURE IDCTRow( blk: DT.PointerToArrayOfLONGINT; baseIndex: LONGINT);
	VAR
		x0, x1, x2, x3, x4, x5, x6, x7, x8: LONGINT;
		adr, tempAdr: LONGINT;
	BEGIN
		adr := ADDRESSOF( blk[baseIndex] );

		(* shortcut *)
		x1 := SYSTEM.GET32( adr + 4*SIZEOF(LONGINT) ) * 2048;
		x2 := SYSTEM.GET32( adr + 6*SIZEOF(LONGINT) );
		x3 := SYSTEM.GET32( adr + 2*SIZEOF(LONGINT) );
		x4 := SYSTEM.GET32( adr + SIZEOF(LONGINT) );
		x5 := SYSTEM.GET32( adr + 7*SIZEOF(LONGINT) );
		x6 := SYSTEM.GET32( adr + 5*SIZEOF(LONGINT) );
		x7 := SYSTEM.GET32( adr + 3*SIZEOF(LONGINT) );

		IF ( x1 = 0 ) & ( x2 = 0 ) & ( x3 = 0 ) & ( x4 = 0 ) & ( x5 = 0 ) & ( x6 = 0 ) & ( x7 = 0 )  THEN
			x0 := SYSTEM.GET32( adr ) * 8;
			SYSTEM.PUT32( adr , x0 );
			tempAdr := adr + SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			RETURN
		END;
		x0 := ( SYSTEM.GET32( adr ) * 2048 ) + 128;    (* for proper rounding in the fourth stage *)

		(* first stage *)
		x8 := W7 * ( x4 + x5 );
		x4 := x8 + ( W1 - W7 ) * x4;
		x5 := x8 - ( W1 + W7 ) * x5;
		x8 := W3 * ( x6 + x7 );
		x6 := x8 - ( W3 - W5 ) * x6;
		x7 := x8 - ( W3 + W5 ) * x7;

		(* second stage *)
		x8 := x0 + x1;
		x0 := x0 - x1;
		x1 := W6 * ( x3 + x2 );
		x2 := x1 - ( W2 + W6 ) * x2;
		x3 := x1 + ( W2 - W6 ) * x3;
		x1 := x4 + x6;
		x4 := x4 - x6;
		x6 := x5 + x7;
		x5 := x5 - x7;

		(* third stage *)
		x7 := x8 + x3;
		x8 := x8 - x3;
		x3 := x0 + x2;
		x0 := x0 - x2;
		x2 := ( 181 * ( x4 + x5 ) + 128 ) DIV 256;
		x4 := ( 181 * ( x4 - x5 ) + 128 ) DIV 256;

		(* fourth stage *)
		SYSTEM.PUT32( adr, ( x7 + x1 ) DIV 256 );
		tempAdr := adr + SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, ( x3 + x2 ) DIV 256 );
		tempAdr := tempAdr + SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, ( x0 + x4 ) DIV 256 );
		tempAdr := tempAdr + SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, ( x8 + x6 ) DIV 256 );
		tempAdr := tempAdr + SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, ( x8 - x6 ) DIV 256 );
		tempAdr := tempAdr + SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, ( x0 - x4 ) DIV 256 );
		tempAdr := tempAdr + SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, ( x3 - x2 ) DIV 256 );
		tempAdr := tempAdr + SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, ( x7 - x1 ) DIV 256 )
	END IDCTRow;

	(* column (vertical) IDCT

 	 7                         pi         1 dst[8*k] = sum c[l] * src[8*l] *
 	 cos( -- * ( k + - ) * l ) l=0                        8          2

 	 where: c[0]    = 1/1024 c[1..7] = (1/1024)*sqrt(2)
	*)
	PROCEDURE IDCTCol( blk: DT.PointerToArrayOfLONGINT; baseIndex: LONGINT );
	VAR
		x0, x1, x2, x3, x4, x5, x6, x7, x8: LONGINT;
		adr, tempAdr, sourceAdr: LONGINT;
	BEGIN
		adr := ADDRESSOF( blk[baseIndex] );

		(* shortcut *)
		x1 := SYSTEM.GET32( adr + 32*SIZEOF(LONGINT) ) * 256;
		x2 := SYSTEM.GET32( adr + 48*SIZEOF(LONGINT) );
		x3 := SYSTEM.GET32( adr + 16*SIZEOF(LONGINT) );
		x4 := SYSTEM.GET32( adr + 8*SIZEOF(LONGINT) );
		x5 := SYSTEM.GET32( adr + 56*SIZEOF(LONGINT) );
		x6 := SYSTEM.GET32( adr + 40*SIZEOF(LONGINT) );
		x7 := SYSTEM.GET32( adr + 24*SIZEOF(LONGINT) );

		IF ( x1 = 0 ) & ( x2 = 0 ) & ( x3 = 0 ) & ( x4 = 0 ) & ( x5 = 0 ) & ( x6 = 0 ) & ( x7 = 0 )  THEN
			x0 := mp4State.clp[( ( SYSTEM.GET32( adr ) + 32 ) DIV 64 ) + 512]; (* +512 is base Offset in Array *)
			SYSTEM.PUT32( adr , x0 );
			tempAdr := adr + 8*SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + 8*SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + 8*SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + 8*SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + 8*SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + 8*SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			tempAdr := tempAdr + 8*SIZEOF( LONGINT );
			SYSTEM.PUT32( tempAdr, x0 );
			RETURN
		END;

		 x0 := (SYSTEM.GET32( adr )* 256) + 8192;

		(* first stage *)
		x8 := W7 * ( x4 + x5 ) + 4;
		x4 := ( x8 + ( W1 - W7 ) * x4 ) DIV 8;
		x5 := ( x8 - ( W1 + W7) * x5 ) DIV 8;
		x8 := W3 * ( x6 + x7 ) + 4;
		x6 := ( x8 - ( W3 - W5 ) * x6 )DIV 8;
		x7 := ( x8 - ( W3 + W5 ) * x7 ) DIV 8;

		(* second stage *)
		x8 := x0 + x1;
		x0 := x0 - x1;
		x1 := W6 * ( x3 + x2 ) + 4;
		x2 := ( x1 - ( W2 + W6 ) * x2 ) DIV 8;
		x3 := ( x1 + ( W2 - W6 ) * x3 ) DIV 8;
		x1 := x4 + x6;
		x4 := x4 - x6;
		x6 := x5 + x7;
		x5 := x5 - x7;

		(* third stage *)
		x7 := x8 + x3;
		x8 := x8 - x3;
		x3 := x0 + x2;
		x0 := x0 - x2;
		x2 := ( 181 * ( x4 + x5 ) + 128 ) DIV 256;
		x4 := ( 181 * ( x4 - x5 ) + 128 ) DIV 256;

		(* fourth stage *)
		tempAdr := adr;
		sourceAdr := ADDRESSOF( mp4State.clp[512] );
		SYSTEM.PUT32( tempAdr, SYSTEM.GET32( ( ( ( x7 + x1 ) DIV 16384 )*SIZEOF(LONGINT) ) + sourceAdr ) );
		tempAdr := tempAdr + 8*SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, SYSTEM.GET32( ( ( ( x3 + x2 ) DIV 16384 )*SIZEOF(LONGINT) ) + sourceAdr ) );
		tempAdr := tempAdr + 8*SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, SYSTEM.GET32( ( ( ( x0 + x4 ) DIV 16384 )*SIZEOF(LONGINT) ) + sourceAdr ) );
		tempAdr := tempAdr + 8*SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, SYSTEM.GET32( ( ( ( x8 + x6 ) DIV 16384 )*SIZEOF(LONGINT) ) + sourceAdr ) );
		tempAdr := tempAdr + 8*SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, SYSTEM.GET32( ( ( ( x8 - x6 ) DIV 16384 )*SIZEOF(LONGINT) ) + sourceAdr ) );
		tempAdr := tempAdr + 8*SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, SYSTEM.GET32( ( ( ( x0 - x4 ) DIV 16384 )*SIZEOF(LONGINT) ) + sourceAdr ) );
		tempAdr := tempAdr + 8*SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, SYSTEM.GET32( ( ( ( x3 - x2 ) DIV 16384 )*SIZEOF(LONGINT) ) + sourceAdr ) );
		tempAdr := tempAdr + 8*SIZEOF( LONGINT );
		SYSTEM.PUT32( tempAdr, SYSTEM.GET32( ( ( ( x7 - x1 ) DIV 16384 )*SIZEOF(LONGINT) ) + sourceAdr ) )
	END IDCTCol;

	(* iquant type h.263, not optimized *)
	PROCEDURE IQuant( psBlock: DT.PointerToArrayOfLONGINT; intraFlag: BOOLEAN );
	VAR
		i, qScale, q2Scale, qAdd: LONGINT;
		start, coeff: LONGINT;
	BEGIN
		qScale := mp4State.hdr.quantizer;
		q2Scale := qScale * 2;

		IF ( qScale MOD 2 ) > 0 THEN
			qAdd := qScale
		ELSE
			qAdd := qScale - 1
		END;

		IF intraFlag THEN start := 1 ELSE start := 0 END;

		FOR i := start TO 63 DO
			coeff := psBlock[i];

			IF coeff # 0 THEN
				IF coeff > 0 THEN
					psBlock[i] := ( q2Scale * coeff ) + qAdd
				ELSE
					psBlock[i] := -( ( q2Scale * ( -coeff ) ) + qAdd )
				END;
			END;
		END;
	END IQuant;

	(* iquant type h.263, not optimized,2.nd type *)
	PROCEDURE IQuantTypeFirst( psblock: DT.PointerToArrayOfLONGINT );
	VAR
		i: LONGINT;
	BEGIN
		FOR i := 1 TO 63 DO
			IF psblock[i] # 0 THEN
				psblock[i] := (psblock[i] * 2 * mp4State.hdr.quantizer *
					mp4State.mp4Tables.intraQuantMatrix[mp4State.mp4Tables.zigZagScan[i]] ) DIV 16;
			END;
		END;
	END IQuantTypeFirst;

	END TextureDecoding;


	(* Variable length decoding *)
	TYPE VLD = OBJECT
	VAR
		tableB161: ARRAY 112 OF DT.TabType;
		tableB162: ARRAY 96 OF DT.TabType;
		tableB163: ARRAY 120 OF DT.TabType;
		tableB171: ARRAY 112 OF DT.TabType;
		tableB172: ARRAY 96 OF DT.TabType;
		tableB173: ARRAY 120 OF DT.TabType;
		log: Streams.Writer;

	PROCEDURE &init*(logWriter:Streams.Writer );
	VAR
		i: LONGINT;
	BEGIN
		log := logWriter;

		(* tables to decode Table B16 VLC - 112 values *)
		tableB161[0].val := 4353; tableB161[0].len := 7; tableB161[1].val := 4289; tableB161[1].len := 7;
		tableB161[2].val := 385; tableB161[2].len := 7; tableB161[3].val := 4417; tableB161[3].len := 7;
		tableB161[4].val := 449; tableB161[4].len := 7; tableB161[5].val := 130; tableB161[5].len := 7;
		tableB161[6].val := 67; tableB161[6].len := 7; tableB161[7].val := 9; tableB161[7].len := 7;
		tableB161[8].val := 4098; tableB161[8].len := 6; tableB161[9].val := 4098; tableB161[9].len := 6;
		tableB161[10].val := 321; tableB161[10].len := 6; tableB161[11].val := 321; tableB161[11].len := 6;
		tableB161[12].val := 4225; tableB161[12].len := 6; tableB161[13].val := 4225; tableB161[13].len := 6;
		tableB161[14].val := 4161; tableB161[14].len := 6; tableB161[15].val := 4161; tableB161[15].len := 6;
		tableB161[16].val := 257; tableB161[16].len := 6; tableB161[17].val := 257; tableB161[17].len := 6;
		tableB161[18].val := 193; tableB161[18].len := 6; tableB161[19].val := 193; tableB161[19].len := 6;
		tableB161[20].val := 8; tableB161[20].len := 6; tableB161[21].val := 8; tableB161[21].len := 6;
		tableB161[22].val := 7; tableB161[22].len := 6; tableB161[23].val := 7; tableB161[23].len := 6;
		tableB161[24].val := 66; tableB161[24].len := 6; tableB161[25].val := 66; tableB161[25].len := 6;
		tableB161[26].val := 6; tableB161[26].len := 6; tableB161[27].val := 6; tableB161[27].len := 6;
		FOR i := 28 TO 31 DO
			tableB161[i].val := 129; tableB161[i].len := 5
		END;
		FOR i := 32 TO 35 DO
			tableB161[i].val := 5; tableB161[i].len := 5
		END;
		FOR i := 36 TO 39 DO
			tableB161[i].val := 4; tableB161[i].len := 5
		END;
		FOR i := 40 TO 47 DO
			tableB161[i].val := 4097; tableB161[i].len := 4
		END;
		FOR i := 48 TO 79 DO
			tableB161[i].val := 1; tableB161[i].len := 2
		END;
		FOR i := 80 TO 95 DO
			tableB161[i].val := 2; tableB161[i].len := 3
		END;
		FOR i := 96 TO 103 DO
			tableB161[i].val := 65; tableB161[i].len := 4
		END;
		FOR i := 96 TO 103 DO
			tableB161[i].val := 65; tableB161[i].len := 4
		END;
		FOR i := 104 TO 111 DO
			tableB161[i].val := 3; tableB161[i].len := 4
		END;

		tableB162[0].val := 18; tableB162[0].len := 10; tableB162[1].val := 17; tableB162[1].len := 10;
		tableB162[2].val := 4993; tableB162[2].len := 9; tableB162[3].val := 4993; tableB162[3].len := 9;
		tableB162[4].val := 4929; tableB162[4].len := 9; tableB162[5].val := 4929; tableB162[5].len := 9;
		tableB162[6].val := 4865; tableB162[6].len := 9; tableB162[7].val := 4865; tableB162[7].len := 9;
		tableB162[8].val := 4801; tableB162[8].len := 9; tableB162[9].val := 4801; tableB162[9].len := 9;
		tableB162[10].val := 4737; tableB162[10].len := 9; tableB162[11].val := 4737; tableB162[11].len := 9;
		tableB162[12].val := 4162; tableB162[12].len := 9; tableB162[13].val := 4162; tableB162[13].len := 9;
		tableB162[14].val := 4100; tableB162[14].len := 9; tableB162[15].val := 4100; tableB162[15].len := 9;
		tableB162[16].val := 769; tableB162[16].len := 9; tableB162[17].val := 769; tableB162[17].len := 9;
		tableB162[18].val := 705; tableB162[18].len := 9; tableB162[19].val := 705; tableB162[19].len := 9;
		tableB162[20].val := 450; tableB162[20].len := 9; tableB162[21].val := 450; tableB162[21].len := 9;
		tableB162[22].val := 386; tableB162[22].len := 9; tableB162[23].val := 386; tableB162[23].len := 9;
		tableB162[24].val := 322; tableB162[24].len := 9; tableB162[25].val := 322; tableB162[25].len := 9;
		tableB162[26].val := 195; tableB162[26].len := 9; tableB162[27].val := 195; tableB162[27].len := 9;
		tableB162[28].val := 131; tableB162[28].len := 9; tableB162[29].val := 131; tableB162[29].len := 9;
		tableB162[30].val := 70; tableB162[30].len := 9; tableB162[31].val := 70; tableB162[31].len := 9;
		tableB162[32].val := 69; tableB162[32].len := 9; tableB162[33].val := 69; tableB162[33].len := 9;
		tableB162[34].val := 16; tableB162[34].len := 9; tableB162[35].val := 16; tableB162[35].len := 9;
		tableB162[36].val := 258; tableB162[36].len := 9; tableB162[37].val := 258; tableB162[37].len := 9;
		tableB162[38].val := 15; tableB162[38].len := 9; tableB162[39].val := 15; tableB162[39].len := 9;
		tableB162[40].val := 14; tableB162[40].len := 9; tableB162[41].val := 14; tableB162[41].len := 9;
		tableB162[42].val := 13; tableB162[42].len := 9; tableB162[43].val := 13; tableB162[43].len := 9;
		FOR i := 44 TO 47 DO
			tableB162[i].val := 4609; tableB162[i].len := 8
		END;
		FOR i := 48 TO 51 DO
			tableB162[i].val := 4545; tableB162[i].len := 8
		END;
		FOR i := 52 TO 55 DO
			tableB162[i].val := 4481; tableB162[i].len := 8
		END;
		FOR i := 56 TO 59 DO
			tableB162[i].val := 4099; tableB162[i].len := 8
		END;
		FOR i := 60 TO 63 DO
			tableB162[i].val := 641; tableB162[i].len := 8
		END;
		FOR i := 64 TO 67 DO
			tableB162[i].val := 577; tableB162[i].len := 8
		END;
		FOR i := 68 TO 71 DO
			tableB162[i].val := 513; tableB162[i].len := 8
		END;
		FOR i := 72 TO 75 DO
			tableB162[i].val := 4673; tableB162[i].len := 8
		END;
		FOR i := 76 TO 79 DO
			tableB162[i].val := 194; tableB162[i].len := 8
		END;
		FOR i := 80 TO 83 DO
			tableB162[i].val := 68; tableB162[i].len := 8
		END;
		FOR i := 84 TO 87 DO
			tableB162[i].val := 12; tableB162[i].len := 8
		END;
		FOR i := 88 TO 91 DO
			tableB162[i].val := 11; tableB162[i].len := 8
		END;
		FOR i := 92 TO 95 DO
			tableB162[i].val := 10; tableB162[i].len := 8
		END;

		tableB163[0].val := 4103; tableB163[0].len := 11; tableB163[1].val := 4103; tableB163[1].len := 11;
		tableB163[2].val := 4102; tableB163[2].len := 11; tableB163[3].val := 4102; tableB163[3].len := 11;
		tableB163[4].val := 22; tableB163[4].len := 11; tableB163[5].val := 22; tableB163[5].len := 11;
		tableB163[6].val := 21; tableB163[6].len := 11; tableB163[7].val := 21; tableB163[7].len := 11;
		FOR i := 8 TO 11 DO
			tableB163[i].val := 4226; tableB163[i].len := 10
		END;
		FOR i := 12 TO 15 DO
			tableB163[i].val := 4163; tableB163[i].len := 10
		END;
		FOR i := 16 TO 19 DO
			tableB163[i].val := 4101; tableB163[i].len := 10
		END;
		FOR i := 20 TO 23 DO
			tableB163[i].val := 833; tableB163[i].len := 10
		END;
		FOR i := 24 TO 27 DO
			tableB163[i].val := 323; tableB163[i].len := 10
		END;
		FOR i := 28 TO 31 DO
			tableB163[i].val := 514; tableB163[i].len := 10
		END;
		FOR i := 32 TO 35 DO
			tableB163[i].val := 259; tableB163[i].len := 10
		END;
		FOR i := 36 TO 39 DO
			tableB163[i].val := 196; tableB163[i].len := 10
		END;
		FOR i := 40 TO 43 DO
			tableB163[i].val := 132; tableB163[i].len := 10
		END;
		FOR i := 44 TO 47 DO
			tableB163[i].val := 71; tableB163[i].len := 10
		END;
		FOR i := 48 TO 51 DO
			tableB163[i].val := 20; tableB163[i].len := 10
		END;
		FOR i := 52 TO 55 DO
			tableB163[i].val := 19; tableB163[i].len := 10
		END;
		tableB163[56].val := 23; tableB163[56].len := 11; tableB163[57].val := 23; tableB163[57].len := 11;
		tableB163[58].val := 24; tableB163[58].len := 11; tableB163[59].val := 24; tableB163[59].len := 11;
		tableB163[60].val := 72; tableB163[60].len := 11; tableB163[61].val := 72; tableB163[61].len := 11;
		tableB163[62].val := 578; tableB163[62].len := 11; tableB163[63].val := 578; tableB163[63].len := 11;
		tableB163[64].val := 4290; tableB163[64].len := 11; tableB163[65].val := 4290; tableB163[65].len := 11;
		tableB163[66].val := 4354; tableB163[66].len := 11; tableB163[67].val := 4354; tableB163[67].len := 11;
		tableB163[68].val := 5057; tableB163[68].len := 11; tableB163[69].val := 5057; tableB163[69].len := 11;
		tableB163[70].val := 5121; tableB163[70].len := 11; tableB163[71].val := 5121; tableB163[71].len := 11;
		tableB163[72].val := 25; tableB163[72].len := 12; tableB163[73].val := 26; tableB163[73].len := 12;
		tableB163[74].val := 27; tableB163[74].len := 12; tableB163[75].val := 73; tableB163[75].len := 12;
		tableB163[76].val := 387; tableB163[76].len := 12; tableB163[77].val := 74; tableB163[77].len := 12;
		tableB163[78].val := 133; tableB163[78].len := 12; tableB163[79].val := 451; tableB163[79].len := 12;
		tableB163[80].val := 897; tableB163[80].len := 12; tableB163[81].val := 4104; tableB163[81].len := 12;
		tableB163[82].val := 4418; tableB163[82].len := 12; tableB163[83].val := 4482; tableB163[83].len := 12;
		tableB163[84].val := 5185; tableB163[84].len := 12; tableB163[85].val := 5249; tableB163[85].len := 12;
		tableB163[86].val := 5313; tableB163[86].len := 12; tableB163[87].val := 5377; tableB163[87].len := 12;
		FOR i := 88 TO 119 DO
			tableB163[i].val := 7167; tableB163[i].len := 7
		END;

		tableB171[0].val := 4225; tableB171[0].len := 7; tableB171[1].val := 4209; tableB171[1].len := 7;
		tableB171[2].val := 4193; tableB171[2].len := 7; tableB171[3].val := 4177; tableB171[3].len := 7;
		tableB171[4].val := 193; tableB171[4].len := 7; tableB171[5].val := 177; tableB171[5].len := 7;
		tableB171[6].val := 161; tableB171[6].len := 7; tableB171[7].val := 4; tableB171[7].len := 7;
		tableB171[8].val := 4161; tableB171[8].len := 6; tableB171[9].val := 4161; tableB171[9].len := 6;
		tableB171[10].val := 4145; tableB171[10].len := 6; tableB171[11].val := 4145; tableB171[11].len := 6;
		tableB171[12].val := 4129; tableB171[12].len := 6; tableB171[13].val := 4129; tableB171[13].len := 6;
		tableB171[14].val := 4113; tableB171[14].len := 6; tableB171[15].val := 4113; tableB171[15].len := 6;
		tableB171[16].val := 145; tableB171[16].len := 6; tableB171[17].val := 145; tableB171[17].len := 6;
		tableB171[18].val := 129; tableB171[18].len := 6; tableB171[19].val := 129; tableB171[19].len := 6;
		tableB171[20].val := 113; tableB171[20].len := 6; tableB171[21].val := 113; tableB171[21].len := 6;
		tableB171[22].val := 97; tableB171[22].len := 6; tableB171[23].val := 97; tableB171[23].len := 6;
		tableB171[24].val := 18; tableB171[24].len := 6; tableB171[25].val := 18; tableB171[25].len := 6;
		tableB171[26].val := 3; tableB171[26].len := 6; tableB171[27].val := 3; tableB171[27].len := 6;
		FOR i := 28 TO 31 DO
			tableB171[i].val := 81; tableB171[i].len := 5
		END;
		FOR i := 32 TO 35 DO
			tableB171[i].val := 65; tableB171[i].len := 5
		END;
		FOR i := 36 TO 39 DO
			tableB171[i].val := 49; tableB171[i].len := 5
		END;
		FOR i := 40 TO 47 DO
			tableB171[i].val := 4097; tableB171[i].len := 4
		END;
		FOR i := 48 TO  79 DO
			tableB171[i].val := 1; tableB171[i].len := 2
		END;
		FOR i := 80 TO 95 DO
			tableB171[i].val := 17; tableB171[i].len := 3
		END;
		FOR i := 96 TO 103 DO
			tableB171[i].val := 33; tableB171[i].len := 4
		END;
		FOR i := 104 TO 111 DO
			tableB171[i].val := 2; tableB171[i].len := 4
		END;

		tableB172[0].val := 9; tableB172[0].len := 10; tableB172[1].val := 8; tableB172[1].len := 10;
		tableB172[2].val := 4481; tableB172[2].len := 9; tableB172[3].val := 4481; tableB172[3].len := 9;
		tableB172[4].val := 4465; tableB172[4].len := 9; tableB172[5].val := 4465; tableB172[5].len := 9;
		tableB172[6].val := 4449; tableB172[6].len := 9; tableB172[7].val := 4449; tableB172[7].len := 9;
		tableB172[8].val := 4433; tableB172[8].len := 9; tableB172[9].val := 4433; tableB172[9].len := 9;
		tableB172[10].val := 4417; tableB172[10].len := 9; tableB172[11].val := 4417; tableB172[11].len := 9;
		tableB172[12].val := 4401; tableB172[12].len := 9; tableB172[13].val := 4401; tableB172[13].len := 9;
		tableB172[14].val := 4385; tableB172[14].len := 9; tableB172[15].val := 4385; tableB172[15].len := 9;
		tableB172[16].val := 4369; tableB172[16].len := 9; tableB172[17].val := 4369; tableB172[17].len := 9;
		tableB172[18].val := 4098; tableB172[18].len := 9; tableB172[19].val := 4098; tableB172[19].len := 9;
		tableB172[20].val := 353; tableB172[20].len := 9; tableB172[21].val := 353; tableB172[21].len := 9;
		tableB172[22].val := 337; tableB172[22].len := 9; tableB172[23].val := 337; tableB172[23].len := 9;
		tableB172[24].val := 321; tableB172[24].len := 9; tableB172[25].val := 321; tableB172[25].len := 9;
		tableB172[26].val := 305; tableB172[26].len := 9; tableB172[27].val := 305; tableB172[27].len := 9;
		tableB172[28].val := 289; tableB172[28].len := 9; tableB172[29].val := 289; tableB172[29].len := 9;
		tableB172[30].val := 273; tableB172[30].len := 9; tableB172[31].val := 273; tableB172[31].len := 9;
		tableB172[32].val := 257; tableB172[32].len := 9; tableB172[33].val := 257; tableB172[33].len := 9;
		tableB172[34].val := 241; tableB172[34].len := 9; tableB172[35].val := 241; tableB172[35].len := 9;
		tableB172[36].val := 66; tableB172[36].len := 9; tableB172[37].val := 66; tableB172[37].len := 9;
		tableB172[38].val := 50; tableB172[38].len := 9; tableB172[39].val := 50; tableB172[39].len := 9;
		tableB172[40].val := 7; tableB172[40].len := 9; tableB172[41].val := 7; tableB172[41].len := 9;
		tableB172[42].val := 6; tableB172[42].len := 9; tableB172[43].val := 6; tableB172[43].len := 9;
		FOR i := 44 TO 47 DO
			tableB172[i].val := 4353; tableB172[i].len := 8
		END;
		FOR i := 48 TO 51 DO
			tableB172[i].val := 4337; tableB172[i].len := 8
		END;
		FOR i := 52 TO 55 DO
			tableB172[i].val := 4321; tableB172[i].len := 8
		END;
		FOR i := 56 TO 59 DO
			tableB172[i].val := 4305; tableB172[i].len := 8
		END;
		FOR i := 60 TO 63 DO
			tableB172[i].val := 4289; tableB172[i].len := 8
		END;
		FOR i := 64 TO 67 DO
			tableB172[i].val := 4273; tableB172[i].len := 8
		END;
		FOR i := 68 TO 71 DO
			tableB172[i].val := 4257; tableB172[i].len := 8
		END;
		FOR i := 72 TO 75 DO
			tableB172[i].val := 4241; tableB172[i].len := 8
		END;
		FOR i := 76 TO 79 DO
			tableB172[i].val := 225; tableB172[i].len := 8
		END;
		FOR i := 80 TO 83 DO
			tableB172[i].val := 209; tableB172[i].len := 8
		END;
		FOR i := 84 TO 87 DO
			tableB172[i].val := 34; tableB172[i].len := 8
		END;
		FOR i := 88 TO 91 DO
			tableB172[i].val := 19; tableB172[i].len := 8
		END;
		FOR i := 92 TO 95 DO
			tableB172[i].val := 5; tableB172[i].len := 8
		END;

		tableB173[0].val := 4114; tableB173[0].len := 11; tableB173[1].val := 4114; tableB173[1].len := 11;
		tableB173[2].val := 4099; tableB173[2].len := 11; tableB173[3].val := 4099; tableB173[3].len := 11;
		tableB173[4].val := 11; tableB173[4].len := 11; tableB173[5].val := 11; tableB173[5].len := 11;
		tableB173[6].val := 10; tableB173[6].len := 11; tableB173[7].val := 10; tableB173[7].len := 11;
		FOR i := 8 TO 11 DO
			tableB173[i].val := 4545; tableB173[i].len := 10
		END;
		FOR i := 12 TO 15 DO
			tableB173[i].val := 4529; tableB173[i].len := 10
		END;
		FOR i := 16 TO 19 DO
			tableB173[i].val := 4513; tableB173[i].len := 10
		END;
		FOR i := 20 TO 23 DO
			tableB173[i].val := 4497; tableB173[i].len := 10
		END;
		FOR i := 24 TO 27 DO
			tableB173[i].val := 146; tableB173[i].len := 10
		END;
		FOR i := 28 TO 31 DO
			tableB173[i].val := 130; tableB173[i].len := 10
		END;
		FOR i := 32 TO 35 DO
			tableB173[i].val := 114; tableB173[i].len := 10
		END;
		FOR i := 36 TO 39 DO
			tableB173[i].val := 98; tableB173[i].len := 10
		END;
		FOR i := 40 TO 43 DO
			tableB173[i].val := 82; tableB173[i].len := 10
		END;
		FOR i := 44 TO 47 DO
			tableB173[i].val := 51; tableB173[i].len := 10
		END;
		FOR i := 48 TO 51 DO
			tableB173[i].val := 35; tableB173[i].len := 10
		END;
		FOR i := 52 TO 55 DO
			tableB173[i].val := 20; tableB173[i].len := 10
		END;
		tableB173[56].val := 12; tableB173[56].len := 11; tableB173[57].val := 12; tableB173[57].len := 11;
		tableB173[58].val := 21; tableB173[58].len := 11; tableB173[59].val := 21; tableB173[59].len := 11;
		tableB173[60].val := 369; tableB173[60].len := 11; tableB173[61].val := 369; tableB173[61].len := 11;
		tableB173[62].val := 385; tableB173[62].len := 11; tableB173[63].val := 385; tableB173[63].len := 11;
		tableB173[64].val := 4561; tableB173[64].len := 11; tableB173[65].val := 4561; tableB173[65].len := 11;
		tableB173[66].val := 4577; tableB173[66].len := 11; tableB173[67].val := 4577; tableB173[67].len := 11;
		tableB173[68].val := 4593; tableB173[68].len := 11; tableB173[69].val := 4593; tableB173[69].len := 11;
		tableB173[70].val := 4609; tableB173[70].len := 11; tableB173[71].val := 4609; tableB173[71].len := 11;
		tableB173[72].val := 22; tableB173[72].len := 12; tableB173[73].val := 36; tableB173[73].len := 12;
		tableB173[74].val := 67; tableB173[74].len := 12; tableB173[75].val := 83; tableB173[75].len := 12;
		tableB173[76].val := 99; tableB173[76].len := 12; tableB173[77].val := 162; tableB173[77].len := 12;
		tableB173[78].val := 401; tableB173[78].len := 12; tableB173[79].val := 417; tableB173[79].len := 12;
		tableB173[80].val := 4625; tableB173[80].len := 12; tableB173[81].val := 4641; tableB173[81].len := 12;
		tableB173[82].val := 4657; tableB173[82].len := 12; tableB173[83].val := 4673; tableB173[83].len := 12;
		tableB173[84].val := 4689; tableB173[84].len := 12; tableB173[85].val := 4705; tableB173[85].len := 12;
		tableB173[86].val := 4721; tableB173[86].len := 12; tableB173[87].val := 4737; tableB173[87].len := 12;
		FOR i := 88 TO 119 DO
			tableB173[i].val := 7167; tableB173[i].len := 7
		END;
	END init;

	(* Variable length codes decoding for intra blocks *)
	PROCEDURE VldIntraDCT( VAR event: Event; VAR r: DT.VideoBuffer  );
	VAR
		tab: DT.TabType;
		lMax, rMax: LONGINT;
		temp: LONGINT;
	BEGIN
		event.run := -1;
		event.level := -1;
		event.last := -1;

		tab := VldTableB16( AVI.ShowBits(12, r.data^, r.index), r );

		IF tab.len = -1  THEN (* bad code *)
			event.run   := -1;
			event.level := -1;
			event.last  := -1;
			RETURN
		END;

		IF tab.val # Escape THEN
			event.run := ( tab.val DIV 64 ) MOD 64;
			event.level :=  tab.val MOD 64;
			event.last := ( tab.val DIV 4096 ) MOD 2;
			IF AVI.GetBits(1, r.data^, r.index ) > 0 THEN event.level := -event.level END;
		ELSE
			(* this value is escaped - see para 7.4.1.3 *)
			(* assuming shortVideoHeader == 0 *)
			CASE AVI.ShowBits(2, r.data^, r.index ) OF
				0 .. 1: (* Type 1 *)
					AVI.SkipBits( 1, r.index );
					tab := VldTableB16( AVI.ShowBits( 12, r.data^, r.index ), r );  (* use table B-16 *)
					IF tab.len = -1 THEN (* bad code *)
						event.run := -1;
						event.level := -1;
						event.last := -1;
						RETURN
					END;

					event.run := ( tab.val DIV 64 ) MOD 64;
					event.level := tab.val MOD 64;
					event.last := ( tab.val DIV 4096 ) MOD 2;
					lMax := VldTableB19( event.last, event.run );  (* use table B-19 *)
					event.level := event.level + lMax;
					IF AVI.GetBits(1, r.data^, r.index ) > 0 THEN event.level := -event.level END;
				| 2:  (* Type 2 *)
					AVI.SkipBits( 2, r.index );
					tab := VldTableB16( AVI.ShowBits( 12, r.data^, r.index ), r );  (* use table B-16 *)
					IF tab.len = -1 THEN (* bad code *)
						event.run := -1;
						event.level := -1;
						event.last := -1
					ELSE
						event.run := ( tab.val DIV 64 ) MOD 64;
						event.level := tab.val MOD 64;
						event.last := ( tab.val DIV 4096 ) MOD 2;
						rMax := VldTableB21( event.last, event.level ); (* use table B-21 *)
						event.run := event.run + rMax + 1;
						IF AVI.GetBits( 1, r.data^, r.index ) > 0 THEN event.level := -event.level END;
					END;
				| 3:  (* Type 3  - fixed length codes *)
					AVI.SkipBits(2, r.index );
					event.last := AVI.GetBits( 1, r.data^, r.index );
					event.run := AVI.GetBits(6, r.data^, r.index );  (* table B-18 *)
					temp := AVI.GetBits( 1, r.data^, r.index ); (* marker bit *)
					event.level := AVI.GetBits( 12, r.data^, r.index ); (* table B-18 *)
					(* sign extend level... *)
					(* event.level = (event.level & 0x800) ? (event.level | (-1 ^ 0xfff)) : event.level; *)
					IF 11 IN SYSTEM.VAL( SET, event.level )  THEN
						 event.level := SYSTEM.VAL( LONGINT,
						 	SYSTEM.VAL( SET, event.level ) + SYSTEM.VAL( SET, -4096  ) )
					END;
					temp := AVI.GetBits( 1, r.data^, r.index ); (* marker bit *)
			END;
		END;

		RETURN
	END VldIntraDCT;

	(* Variable length codes decoding for interblocks *)
	PROCEDURE VldInterDCT( VAR event: Event; VAR r: DT.VideoBuffer );
	VAR
		tab :DT.TabType;
		lMax, rMax,  temp: LONGINT;
	BEGIN
		event.run := -1;
		event.level := -1;
		event.last := -1;

		tab := VldTableB17( AVI.ShowBits( 12, r.data^, r.index ), r );
		IF tab.len = -1 THEN (* bad code *)
			event.run := -1;
			event.level := -1;
			event.last := -1;
			RETURN
		END;

		IF tab.val # Escape THEN
			event.run := (tab.val DIV 16 ) MOD 256;
			event.level :=  tab.val MOD 16;
			event.last  := (tab.val DIV 4096 ) MOD 2;
			IF AVI.GetBits( 1, r.data^, r.index ) > 0 THEN event.level := -event.level END;
		ELSE
			(* this value is escaped - see para 7.4.1.3 *)
			(* assuming short_video_header == 0 *)
			CASE AVI.ShowBits( 2, r.data^, r.index ) OF
			  0 .. 1: (* Type 1 *)
					AVI.SkipBits(1, r.index );
					tab := VldTableB17( AVI.ShowBits( 12, r.data^, r.index ), r );  (* use table B-17 *)
					IF tab.len = -1 THEN
						event.run := -1;
						event.level := -1;
						event.last := -1;
						RETURN
					END;

					event.run := ( tab.val DIV 16 ) MOD 256;
					event.level :=  tab.val MOD 16;
					event.last := ( tab.val DIV 4096 ) MOD 2;
					lMax := VldTableB20( event.last, event.run );  (* use table B-20 *)
					event.level := event.level + lMax;
					IF AVI.GetBits(1, r.data^, r.index ) > 0 THEN event.level := -event.level END;
				| 2:  (* Type 2 *)
					AVI.SkipBits( 2, r.index );
					tab := VldTableB17( AVI.ShowBits( 12, r.data^, r.index ), r );  (* use table B-16 *)
					IF tab.len = -1 THEN (* bad code *)
						event.run := -1;
						event.level := -1;
						event.last := -1
					ELSE
						event.run := ( tab.val DIV 16 ) MOD 256;
						event.level := tab.val MOD 16;
						event.last  := ( tab.val DIV 4096 ) MOD 2;
						rMax := VldTableB22( event.last, event.level );  (* use table B-22 *)
						event.run := event.run + rMax + 1;
						IF AVI.GetBits( 1, r.data^, r.index ) > 0 THEN event.level := -event.level END;
					END;
				| 3:  (* Type 3  - fixed length codes *)
					AVI.SkipBits( 2, r.index );
					event.last := AVI.GetBits( 1, r.data^, r.index );
					event.run := AVI.GetBits( 6, r.data^, r.index ); (* table B-18 *)
					temp := AVI.GetBits( 1, r.data^, r.index ); (* marker bit *)
					event.level := AVI.GetBits( 12, r.data^, r.index ); (* table B-18 *)
					(* sign extend level... *)
					(* event.level = (event.level & 0x800) ? (event.level | (-1 ^ 0xfff)) : event.level; *)
					IF 11 IN SYSTEM.VAL( SET, event.level ) THEN
						 event.level := SYSTEM.VAL( LONGINT,
						 	SYSTEM.VAL( SET, event.level ) + ( SYSTEM.VAL( SET, -4096 ) ) )
					END;
					temp := AVI.GetBits( 1, r.data^, r.index ); (* marker bit *)
			END;
		END;
		RETURN
	END VldInterDCT;

	(* GEet variable length code event *)
	PROCEDURE VldEvent( intraFlag: BOOLEAN; VAR event: Event; VAR r: DT.VideoBuffer);
	BEGIN
		IF intraFlag THEN
			VldIntraDCT( event, r );
		ELSE
			VldInterDCT( event,  r);
		END;
	END VldEvent;

	(* Table B-19 -- ESCL(a), LMAX values of intra macroblocks *)
	PROCEDURE VldTableB19( last, run: LONGINT ): LONGINT;
	BEGIN
		IF last = 0 THEN
			CASE run OF
					0: RETURN 27;
				| 1: RETURN 10;
				| 2: RETURN  5;
				| 3: RETURN  4;
				| 4 .. 7: RETURN  3;
				| 8 .. 9: RETURN  2;
				| 10 .. 14: RETURN  1;
			ELSE (* illegal? *)
				RETURN  0;
			END;
		ELSE
			CASE run OF
					0: RETURN  8;
				| 1: RETURN  3;
				| 2 .. 6: RETURN  2;
				| 7 .. 20: RETURN  1;
			ELSE (* illegal? *)
				RETURN 0;
			END;
		END;
	END VldTableB19;

	(* Table B-20 -- ESCL(b), LMAX values of inter macroblocks *)
	PROCEDURE VldTableB20( last, run: LONGINT ): LONGINT;
	BEGIN
		IF last = 0 THEN
			CASE run OF
			 		0: RETURN 12;
				| 1: RETURN 6;
				| 2: RETURN 4;
				| 3 .. 6: RETURN 3;
				| 7 .. 10: RETURN 2;
				| 11 .. 26: RETURN 1;
			ELSE
				RETURN 0;
			END;
		ELSE
			CASE run OF
					0: RETURN 3;
				| 1: RETURN 2;
				| 2 .. 40: RETURN 1;
			ELSE
				RETURN 0;
			END;
		END;
	END VldTableB20;

	(* Table B-21 -- ESCR(a), RMAX values of intra macroblocks *)
	PROCEDURE VldTableB21( last, level: LONGINT ): LONGINT;
	BEGIN
		IF last = 0 THEN
			CASE level OF
					1: RETURN 14;
				| 2: RETURN 9;
				| 3: RETURN 7;
				| 4: RETURN 3;
				| 5: RETURN 2;
				| 6 .. 10: RETURN 1;
				| 11 .. 27: RETURN 0;
			ELSE
				RETURN 0;
			END;
		ELSE
			CASE level OF
					1: RETURN 20;
				| 2: RETURN 6;
				| 3: RETURN 1;
				| 4 .. 8: RETURN 0;
			ELSE
				RETURN 0;
			END;
		END;
	END VldTableB21;

	(* Table B-22 -- ESCR(b), RMAX values of inter macroblocks *)
	PROCEDURE VldTableB22(  last, level: LONGINT ): LONGINT;
	BEGIN
		IF last = 0 THEN
			CASE level OF
					1: RETURN 26;
				| 2: RETURN 10;
				| 3: RETURN 6;
				| 4: RETURN 2;
				| 5 .. 6: RETURN 1;
				| 7 .. 12: RETURN 0;
			ELSE
				RETURN 0;
			END;
		ELSE
			CASE level OF
					1: RETURN 40;
				| 2: RETURN 1;
				| 3: RETURN 0;
			ELSE
				RETURN 0;
			END;
		END;
	END VldTableB22;


	PROCEDURE VldTableB16(code: LONGINT; VAR r: DT.VideoBuffer): DT.TabType;
	VAR
		tab: DT.TabType;
	BEGIN
		IF code >= 512 THEN
			tab := tableB161[(code DIV 32 ) - 16];
		ELSIF code >= 128 THEN
			tab := tableB162[(code DIV 4 ) - 32];
		ELSIF code >= 8 THEN
			tab := tableB163[code - 8];
		ELSE
			(* invalid Huffman code *)
			tab.len := -1;
			RETURN tab;
		END;
		AVI.SkipBits( tab.len, r.index );
		RETURN tab;
	END VldTableB16;

	PROCEDURE VldTableB17( code: LONGINT; VAR r: DT.VideoBuffer ): DT.TabType;
	VAR
		tab: DT.TabType;
	BEGIN
		IF code >= 512 THEN
			tab := tableB171[( code DIV 32 ) - 16];
		ELSIF code >= 128 THEN
			tab := tableB172[( code DIV 4 ) - 32];
		ELSIF code >= 8 THEN
			tab := tableB173[code - 8];
		ELSE
			(* invalid Huffman code *)
			tab.len := -1;
			RETURN tab;
		END;

		AVI.SkipBits( tab.len, r.index );
		RETURN tab;
	END VldTableB17;

	END VLD;

END DivXHelper.