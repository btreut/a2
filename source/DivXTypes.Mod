MODULE DivXTypes;

(* Type Info for DivXPlayer *)
(* Written by Thomas Trachsel, ttrachsel@web.de, 18.9.2003 *)
(* Heavily based on the OpenDivX Decoder: www.projectmayo.com *)


	IMPORT
		SYSTEM;

	CONST
		(* Write Debug Output to into File DivXDebug.Log *)
		Debug* = FALSE;
		EnableMMX* = TRUE;

		DecMbc* = 45;	(* used for max resolution *)
		DecMbr* = 36;

		(* Startcodes in MPEG-4 Stream *)
		VisualObjectSequenceStartCode* = 1B0H;
		VideoObjectStartCode* = 8;
		VisualObjectLayerStartCode* = 12H;
		GroupOfVopStartCode* = 1B3H;
		VideoObjectPlaneStartCode* = 1B6H;
		UserDataStartCode* = 1B2H;

		IVOP* = 0;
		PVOP* = 1;
		BVOP* = 2;

		Rectangular* = 0;
		Binary* = 1;
		BinaryShapeOnly* = 2;
		GrayScaleOnly* = 3;

		StaticSprite* = 1;

		NotCoded* = -1;
		Inter* = 0;
		InterQ* = 1;
		Inter4V* = 2;
		Intra* = 3;
		IntraQ* = 4;
		Stuffing* = 7;

		Top* = 1;
		Left* = 0;

	TYPE
		(* Helper Types *)
		PointerToArrayOfCHAR* = POINTER TO ARRAY OF CHAR;
		PointerToArrayOfLONGINT* = POINTER TO ARRAY OF LONGINT;
		PointerToArrayOfSHORTINT* = POINTER TO ARRAY OF SHORTINT;

		DCStoreLumArray* = POINTER TO ARRAY OF ARRAY OF LONGINT;
		ACLeftLumArray* = POINTER TO ARRAY OF ARRAY OF ARRAY OF LONGINT;
		ACTopLumArray* = POINTER TO ARRAY OF ARRAY OF ARRAY OF LONGINT;
		DCStoreChrArray* = POINTER TO ARRAY OF ARRAY OF ARRAY OF LONGINT;
		ACLeftChrArray* = POINTER TO ARRAY OF ARRAY OF ARRAY OF ARRAY OF LONGINT;
		ACTopChrArray* = POINTER TO ARRAY OF ARRAY OF ARRAY OF ARRAY OF LONGINT;


	TYPE
		VideoBuffer*=RECORD
		data*: POINTER TO ARRAY OF CHAR;
		index*: LONGINT;
		size*: LONGINT;
	END;

	(* 2 helper functions *)
	TYPE
		MyUtils*  = OBJECT

		(* Compare to arrays up to "len" elements *)
		PROCEDURE CompareCharArrays*( VAR ar1,ar2: ARRAY OF CHAR; len: LONGINT ): BOOLEAN;
		VAR
			i: LONGINT;
		BEGIN
			IF ( len > LEN( ar1 ) ) OR ( len > LEN( ar2 ) ) THEN
				RETURN FALSE;
			END;

			FOR i := 0 TO len-1 DO
				IF ar1[i] # ar2[i] THEN
					RETURN FALSE;
				END;
			END;
			RETURN TRUE;
		END CompareCharArrays;

		(* Set Mem To given value *)
		PROCEDURE MemSet*( d: PointerToArrayOfCHAR; offset: LONGINT; val: CHAR; len: LONGINT );
		VAR
			begin, end: ADDRESS;
		BEGIN
			begin := ADDRESSOF( d[offset]  );

			IF len + offset <= LEN( d ) THEN
				end := len + begin;
			ELSE
				end := LEN( d ) + begin;
			END;

			WHILE begin < end DO
				SYSTEM.PUT8( begin, val );
				INC( begin );
			END;
		END MemSet;
	END MyUtils;

	TYPE TabTypePtr* = POINTER TO TabType;
	TYPE TabType* = RECORD
		val*, len*: LONGINT;
	END;

	(* Tables that are used in more than one object *)
	TYPE MP4Tables* = OBJECT
	VAR
		intraQuantMatrix*: ARRAY 64 OF LONGINT;
		nonIntraQuantMatrix*: ARRAY 64 OF LONGINT;
		zigZagScan*, alternateHorizontalScan*, alternateVerticalScan*: PointerToArrayOfLONGINT;

	PROCEDURE &init*;
	BEGIN
		NEW( zigZagScan, 64 );
		zigZagScan[0] := 0; zigZagScan[1] := 1; zigZagScan[2] := 8;  zigZagScan[3] := 16; zigZagScan[4] := 9;
		zigZagScan[5] := 2; zigZagScan[6] := 3; zigZagScan[7] := 10; zigZagScan[8] := 17;  zigZagScan[9] := 24;
		zigZagScan[10] := 32; zigZagScan[11] := 25; zigZagScan[12] := 18; zigZagScan[13] := 11; zigZagScan[14] := 4;
		zigZagScan[15] := 5; zigZagScan[16] := 12; zigZagScan[17] := 19; zigZagScan[18] := 26; zigZagScan[19] := 33;
		zigZagScan[20] := 40; zigZagScan[21] := 48; zigZagScan[22] := 41; zigZagScan[23] := 34; zigZagScan[24] := 27;
		zigZagScan[25] := 20; zigZagScan[26] := 13; zigZagScan[27] := 6; zigZagScan[28] := 7; zigZagScan[29] := 14;
		zigZagScan[30] := 21; zigZagScan[31] := 28; zigZagScan[32] := 35; zigZagScan[33] := 42; zigZagScan[34] := 49;
		zigZagScan[35] := 56; zigZagScan[36] := 57; zigZagScan[37] := 50; zigZagScan[38] := 43; zigZagScan[39] := 36;
		zigZagScan[40] := 29; zigZagScan[41] := 22; zigZagScan[42] := 15; zigZagScan[43] := 23; zigZagScan[44] := 30;
		zigZagScan[45] := 37; zigZagScan[46] := 44; zigZagScan[47] := 51; zigZagScan[48] := 58; zigZagScan[49] := 59;
		zigZagScan[50] := 52; zigZagScan[51] := 45; zigZagScan[52] := 38; zigZagScan[53] := 31; zigZagScan[54] := 39;
		zigZagScan[55] := 46; zigZagScan[56] := 53; zigZagScan[57] := 60; zigZagScan[58] := 61; zigZagScan[59] := 54;
		zigZagScan[60] := 47; zigZagScan[61] := 55; zigZagScan[62] := 62; zigZagScan[63] := 63;

		NEW( alternateHorizontalScan, 64 );
		alternateHorizontalScan[0] := 0; alternateHorizontalScan[1] := 1; alternateHorizontalScan[2] := 2;
		alternateHorizontalScan[3] := 3; alternateHorizontalScan[4] := 8; alternateHorizontalScan[5] := 9;
		alternateHorizontalScan[6] := 16; alternateHorizontalScan[7] := 17; alternateHorizontalScan[8] := 10;
		alternateHorizontalScan[9] := 11; alternateHorizontalScan[10] := 4; alternateHorizontalScan[11] := 5;
		alternateHorizontalScan[12] := 6; alternateHorizontalScan[13] := 7; alternateHorizontalScan[14] := 15;
		alternateHorizontalScan[15] := 14; alternateHorizontalScan[16] := 13; alternateHorizontalScan[17] := 12;
		alternateHorizontalScan[18] := 19; alternateHorizontalScan[19] := 18; alternateHorizontalScan[20] := 24;
		alternateHorizontalScan[21] := 25; alternateHorizontalScan[22] := 32; alternateHorizontalScan[23] := 33;
		alternateHorizontalScan[24] := 26; alternateHorizontalScan[25] := 27; alternateHorizontalScan[26] := 20;
		alternateHorizontalScan[27] := 21; alternateHorizontalScan[28] := 22; alternateHorizontalScan[29] := 23;
		alternateHorizontalScan[30] := 28; alternateHorizontalScan[31] := 29; alternateHorizontalScan[32] := 30;
		alternateHorizontalScan[33] := 31; alternateHorizontalScan[34] := 34; alternateHorizontalScan[35] := 35;
		alternateHorizontalScan[36] := 40; alternateHorizontalScan[37] := 41; alternateHorizontalScan[38] := 48;
		alternateHorizontalScan[39] := 49; alternateHorizontalScan[40] := 42; alternateHorizontalScan[41] := 43;
		alternateHorizontalScan[42] := 36; alternateHorizontalScan[43] := 37; alternateHorizontalScan[44] := 38;
		alternateHorizontalScan[45] := 39; alternateHorizontalScan[46] := 44; alternateHorizontalScan[47] := 45;
		alternateHorizontalScan[48] := 46; alternateHorizontalScan[49] := 47; alternateHorizontalScan[50] := 50;
		alternateHorizontalScan[51] := 51; alternateHorizontalScan[52] := 56; alternateHorizontalScan[53] := 57;
		alternateHorizontalScan[54] := 58; alternateHorizontalScan[55] := 59; alternateHorizontalScan[56] := 52;
		alternateHorizontalScan[57] := 53; alternateHorizontalScan[58] := 54; alternateHorizontalScan[59] := 55;
		alternateHorizontalScan[60] := 60; alternateHorizontalScan[61] := 61; alternateHorizontalScan[62] := 62;
		alternateHorizontalScan[63] := 63;

		NEW( alternateVerticalScan, 64 );
		alternateVerticalScan[0] := 0; alternateVerticalScan[1] := 8; alternateVerticalScan[2] := 16;
		alternateVerticalScan[3] := 24; alternateVerticalScan[4] := 1; alternateVerticalScan[5] := 9;
		alternateVerticalScan[6] := 2; alternateVerticalScan[7] := 10; alternateVerticalScan[8] := 17;
		alternateVerticalScan[9] := 25; alternateVerticalScan[10] := 32; alternateVerticalScan[11] := 40;
		alternateVerticalScan[12] := 48; alternateVerticalScan[13] := 56; alternateVerticalScan[14] := 57;
		alternateVerticalScan[15] := 49; alternateVerticalScan[16] := 41; alternateVerticalScan[17] := 33;
		alternateVerticalScan[18] := 26; alternateVerticalScan[19] := 18; alternateVerticalScan[20] := 3;
		alternateVerticalScan[21] := 11; alternateVerticalScan[22] := 4; alternateVerticalScan[23] := 12;
		alternateVerticalScan[24] := 19; alternateVerticalScan[25] := 27; alternateVerticalScan[26] := 34;
		alternateVerticalScan[27] := 42; alternateVerticalScan[28] := 50; alternateVerticalScan[29] := 58;
		alternateVerticalScan[30] := 35; alternateVerticalScan[31] := 43; alternateVerticalScan[32] := 51;
		alternateVerticalScan[33] := 59; alternateVerticalScan[34] := 20; alternateVerticalScan[35] := 28;
		alternateVerticalScan[36] := 5; alternateVerticalScan[37] := 13; alternateVerticalScan[38] := 6;
		alternateVerticalScan[39] := 14; alternateVerticalScan[40] := 21; alternateVerticalScan[41] := 29;
		alternateVerticalScan[42] := 36; alternateVerticalScan[43] := 44; alternateVerticalScan[44] := 52;
		alternateVerticalScan[45] := 60; alternateVerticalScan[46] := 37; alternateVerticalScan[47] := 45;
		alternateVerticalScan[48] := 53; alternateVerticalScan[49] := 61; alternateVerticalScan[50] := 22;
		alternateVerticalScan[51] := 30; alternateVerticalScan[52] := 7; alternateVerticalScan[53] := 15;
		alternateVerticalScan[54] := 23; alternateVerticalScan[55] := 31; alternateVerticalScan[56] := 38;
		alternateVerticalScan[57] := 46; alternateVerticalScan[58] := 54; alternateVerticalScan[59] := 62;
		alternateVerticalScan[60] := 39; alternateVerticalScan[61] := 47; alternateVerticalScan[62] := 55;
		alternateVerticalScan[63] := 63;

		intraQuantMatrix[0] := 8; intraQuantMatrix[1] := 17; intraQuantMatrix[2] := 18; intraQuantMatrix[3] := 19;
		intraQuantMatrix[4] := 21; intraQuantMatrix[5] := 23; intraQuantMatrix[6] := 25; intraQuantMatrix[7] := 27;
		intraQuantMatrix[8] := 17; intraQuantMatrix[9] := 18; intraQuantMatrix[10] := 19; intraQuantMatrix[11] := 21;
		intraQuantMatrix[12] := 23; intraQuantMatrix[13] := 25; intraQuantMatrix[14] := 27; intraQuantMatrix[15] := 28;
		intraQuantMatrix[16] := 20; intraQuantMatrix[17] := 21; intraQuantMatrix[18] := 22; intraQuantMatrix[19] := 23;
		intraQuantMatrix[20] := 24; intraQuantMatrix[21] := 26; intraQuantMatrix[22] := 28; intraQuantMatrix[23] := 30;
		intraQuantMatrix[24] := 21; intraQuantMatrix[25] := 22; intraQuantMatrix[26] := 23; intraQuantMatrix[27] := 24;
		intraQuantMatrix[28] := 26; intraQuantMatrix[29] := 28; intraQuantMatrix[30] := 30; intraQuantMatrix[31] := 32;
		intraQuantMatrix[32] := 22; intraQuantMatrix[33] := 23; intraQuantMatrix[34] := 24; intraQuantMatrix[35] := 26;
		intraQuantMatrix[36] := 28; intraQuantMatrix[37] := 30; intraQuantMatrix[38] := 32; intraQuantMatrix[39] := 35;
		intraQuantMatrix[40] := 23; intraQuantMatrix[41] := 24; intraQuantMatrix[42] := 26; intraQuantMatrix[43] := 28;
		intraQuantMatrix[44] := 30; intraQuantMatrix[45] := 32; intraQuantMatrix[46] := 35; intraQuantMatrix[47] := 38;
		intraQuantMatrix[48] := 25; intraQuantMatrix[49] := 26; intraQuantMatrix[50] := 28; intraQuantMatrix[51] := 30;
		intraQuantMatrix[52] := 32; intraQuantMatrix[53] := 35; intraQuantMatrix[54] := 38; intraQuantMatrix[55] := 41;
		intraQuantMatrix[56] := 27; intraQuantMatrix[57] := 28; intraQuantMatrix[58] := 30; intraQuantMatrix[59] := 32;
		intraQuantMatrix[60] := 35; intraQuantMatrix[61] := 38; intraQuantMatrix[62] := 41; intraQuantMatrix[63] := 45;

		nonIntraQuantMatrix[0] := 16; nonIntraQuantMatrix[1] := 17; nonIntraQuantMatrix[2] := 18;
		nonIntraQuantMatrix[3] := 19; nonIntraQuantMatrix[4] := 20; nonIntraQuantMatrix[5] := 21;
		nonIntraQuantMatrix[6] := 22; nonIntraQuantMatrix[7] := 23; nonIntraQuantMatrix[8] := 17;
		nonIntraQuantMatrix[9] := 18; nonIntraQuantMatrix[10] := 19; nonIntraQuantMatrix[11] := 20;
		nonIntraQuantMatrix[12] := 21; nonIntraQuantMatrix[13] := 22; nonIntraQuantMatrix[14] := 23;
		nonIntraQuantMatrix[15] := 24; nonIntraQuantMatrix[16] := 18; nonIntraQuantMatrix[17] := 19;
		nonIntraQuantMatrix[18] := 20; nonIntraQuantMatrix[19] := 21; nonIntraQuantMatrix[20] := 22;
		nonIntraQuantMatrix[21] := 23; nonIntraQuantMatrix[22] := 24; nonIntraQuantMatrix[23] := 25;
		nonIntraQuantMatrix[24] := 19; nonIntraQuantMatrix[25] := 20; nonIntraQuantMatrix[26] := 21;
		nonIntraQuantMatrix[27] := 22; nonIntraQuantMatrix[28] := 23; nonIntraQuantMatrix[29] := 24;
		nonIntraQuantMatrix[30] := 26; nonIntraQuantMatrix[31] := 27; nonIntraQuantMatrix[32] := 20;
		nonIntraQuantMatrix[33] := 21; nonIntraQuantMatrix[34] := 22; nonIntraQuantMatrix[35] := 23;
		nonIntraQuantMatrix[36] := 25; nonIntraQuantMatrix[37] := 26; nonIntraQuantMatrix[38] := 27;
		nonIntraQuantMatrix[39] := 28; nonIntraQuantMatrix[40] := 21; nonIntraQuantMatrix[41] := 22;
		nonIntraQuantMatrix[42] := 23; nonIntraQuantMatrix[43] := 24; nonIntraQuantMatrix[44] := 26;
		nonIntraQuantMatrix[45] := 27; nonIntraQuantMatrix[46] := 28; nonIntraQuantMatrix[47] := 30;
		nonIntraQuantMatrix[48] := 22; nonIntraQuantMatrix[49] := 23; nonIntraQuantMatrix[50] := 24;
		nonIntraQuantMatrix[51] := 26; nonIntraQuantMatrix[52] := 27; nonIntraQuantMatrix[53] := 28;
		nonIntraQuantMatrix[54] := 30; nonIntraQuantMatrix[55] := 31; nonIntraQuantMatrix[56] := 23;
		nonIntraQuantMatrix[57] := 24; nonIntraQuantMatrix[58] := 25; nonIntraQuantMatrix[59] := 27;
		nonIntraQuantMatrix[60] := 28; nonIntraQuantMatrix[61] := 30; nonIntraQuantMatrix[62] := 31;
		nonIntraQuantMatrix[63] := 33

	END init;
	END MP4Tables;

	(* ac dc Prediction *)
	TYPE ACDC* = OBJECT
	VAR
		dcStoreLum*: DCStoreLumArray;
		acLeftLum*: ACLeftLumArray;
		acTopLum*: ACTopLumArray;

		dcStoreChr*: DCStoreChrArray;
		acLeftChr*: ACLeftChrArray;
		acTopChr*: ACTopChrArray;

		predictDir*: LONGINT;

		PROCEDURE &init*;
		BEGIN
			NEW( dcStoreLum, 2*DecMbr + 1, 2*DecMbc + 1 );
			NEW( acLeftLum, 2*DecMbr + 1, 2*DecMbc + 1, 7 );
			NEW( acTopLum, 2*DecMbr + 1, 2*DecMbc + 1, 7 );

			NEW( dcStoreChr, 2, DecMbr + 1, DecMbc + 1 );
			NEW( acLeftChr, 2, DecMbr + 1, DecMbc + 1, 7 );
			NEW( acTopChr, 2, DecMbr + 1 , DecMbc + 1, 7 )

		END init;
	END ACDC;

	(* Contains the actual state of the decoding process. One Instance of that Objekt is shared between the modules *)
	TYPE MP4State* = OBJECT
	VAR
		hdr*: MP4Header;
		mp4Tables*: MP4Tables;
		quantStore*: ARRAY ( DecMbr + 1 ) OF ARRAY ( DecMbc + 1 ) OF LONGINT;

		coeffPred*: ACDC;

		clpData*, clp*: POINTER TO ARRAY OF LONGINT;	(* Attention, needed offset to access elements: +512  *)

		horizontalSize*, verticalSize*, juiceHor*, juiceVer*, codedPictureWidth*, codedPictureHeight*,
		chromWidth*, chromHeight*: LONGINT;

		(* Buffers for the Pictures *)
		edgedRef*, edgedFor*, frameRef*, frameFor*, displayFrame*: PointerToArrayOfCHAR;
		edgedRefBaseOffset*: ARRAY 3 OF LONGINT;	(* Required, because OBERON doesn't support Pointer Arithmetic *)
		edgedForBaseOffset*: ARRAY 3 OF LONGINT;	(* Required, because OBERON doesn't support Pointer Arithmetic *)
		frameRefBaseOffset*: ARRAY 3 OF LONGINT;	(* Required, because OBERON doesn't support Pointer Arithmetic *)
		frameForBaseOffset*: ARRAY 3 OF LONGINT;	(* Required, because OBERON doesn't support Pointer Arithmetic *)
		displayFrameBaseOffset*: ARRAY 3 OF LONGINT;

		modeMap*: ARRAY ( DecMbr + 1 ) OF ARRAY ( DecMbc + 2 ) OF LONGINT;
		mbWidth*, mbHeight*: LONGINT;

		PROCEDURE &init*;
		BEGIN
			NEW( hdr);
			NEW( coeffPred );
			NEW( mp4Tables );
		END init;

		PROCEDURE SetUpState*( buffers: MP4Buffers);
		VAR
			i, j, cc, offset: LONGINT;
		BEGIN
			(* picture dimension vars *)
			horizontalSize := hdr.width;
			verticalSize := hdr.height;
			codedPictureWidth := horizontalSize + 64;
			codedPictureHeight := verticalSize + 64;
			chromWidth := codedPictureWidth DIV 2;
			chromHeight := codedPictureHeight DIV 2;

			(* init the whole stuff *)
			NEW( clpData, 1024 );
			clp := clpData;
			FOR i := -512 TO 511 DO
				IF i < -256 THEN
					clp[i + 512] := -256
				ELSIF i > 255 THEN
					clp[i + 512] := 255
				ELSE
					 clp[i + 512] := i
				END;
			END;

			(* dc prediction border *)
			FOR i := 0 TO ( 2*DecMbc ) DO
				coeffPred.dcStoreLum[0][i] := 1024
			END;

			FOR i := 1 TO ( 2*DecMbr ) DO
				coeffPred.dcStoreLum[i][0] := 1024
			END;

			FOR i := 0 TO (DecMbc ) DO
				coeffPred.dcStoreChr[0][0][i] := 1024;
				coeffPred.dcStoreChr[1][0][i] := 1024
			END;

			FOR i := 1 TO ( DecMbr ) DO
				coeffPred.dcStoreChr[0][i][0] := 1024;
				coeffPred.dcStoreChr[1][i][0] := 1024
			END;

			(* ac prediction border *)
			FOR i := 0 TO ( 2*DecMbc ) DO
				FOR j := 0 TO 6 DO
					coeffPred.acLeftLum[0][i][j] := 0;
					coeffPred.acTopLum[0][i][j] := 0
				END;
			END;

			FOR i := 1 TO ( 2*DecMbr ) DO
				FOR j := 0 TO 6 DO
					coeffPred.acLeftLum[i][0][j] := 0;
					coeffPred.acTopLum[i][0][j] := 0
				END;
			END;

			(* two different pointer for Cb and Cr components *)
			FOR i := 0 TO ( DecMbc ) DO
				FOR j := 0 TO 6 DO
					coeffPred.acLeftChr[0][0][i][j] := 0;
					coeffPred.acTopChr[0][0][i][j] := 0;
					coeffPred.acLeftChr[1][0][i][j] := 0;
					coeffPred.acTopChr[1][0][i][j] := 0
				END;
			END;

			FOR i := 1 TO ( DecMbr ) DO
				FOR j := 0 TO 6 DO
					coeffPred.acLeftChr[0][i][0][j] := 0;
					coeffPred.acTopChr[0][i][0][j] := 0;
					coeffPred.acLeftChr[1][i][0][j] := 0;
					coeffPred.acTopChr[1][i][0][j] := 0
				END;
			END;

			(* edged forward and reference frame *)
			FOR cc := 0 TO 2 DO
				IF cc = 0 THEN
					edgedRef := buffers.edgedRefBuffer;
					edgedRefBaseOffset[cc] := 0;
					ASSERT( edgedRef # NIL );

					edgedFor := buffers.edgedForBuffer;
					edgedForBaseOffset[cc] := 0;
					ASSERT( edgedFor # NIL );

					frameRef := edgedRef;
					frameRefBaseOffset[cc] := edgedRefBaseOffset[cc] + codedPictureWidth*32 + 32;

					frameFor := edgedFor;
			    		frameForBaseOffset[cc] := edgedForBaseOffset[cc] + codedPictureWidth*32 + 32
			    ELSE
					IF cc = 1 THEN
						offset := codedPictureWidth*codedPictureHeight;
					ELSE
						offset := codedPictureWidth*codedPictureHeight + chromWidth*chromHeight;
					END;

					edgedRef := buffers.edgedRefBuffer;
					edgedRefBaseOffset[cc] := offset;
					ASSERT( edgedRef # NIL );

					edgedFor := buffers.edgedForBuffer;
					edgedForBaseOffset[cc] := offset;
					ASSERT( edgedFor # NIL );

					frameRef[cc] := edgedRef[cc];
					frameRefBaseOffset[cc] := edgedRefBaseOffset[cc] + ( chromWidth*16 ) + 16;
					frameFor[cc] := edgedFor[cc];
					frameForBaseOffset[cc] := edgedForBaseOffset[cc] + ( chromWidth*16 ) + 16
				END;
			END;

			(* display frame *)
			FOR cc := 0 TO 2 DO
				CASE cc OF
					  0: offset := 0;
					| 1: offset := horizontalSize*verticalSize;
					| 2: offset := horizontalSize*verticalSize + ( ( horizontalSize*verticalSize ) DIV 4 )
				END;

				displayFrame := buffers.displayBuffer;
				displayFrameBaseOffset[cc] := offset;
				ASSERT( displayFrame # NIL )
			END;

			mbWidth := horizontalSize DIV 16;
			mbHeight := verticalSize DIV 16;

			(* Macroblock mode border *)
			FOR i := 0 TO mbWidth DO
				modeMap[0][i] := Intra
			END;

			FOR i := 0 TO mbHeight DO
				modeMap[i][0] := Intra;
				modeMap[i][mbWidth+1] := Intra
			END;
		END SetUpState;

	END MP4State;

	(* Contains the Header of the avi File *)
	TYPE MP4Header = OBJECT
	VAR
		ident*, randomAccessibleVol*, typeIndication*,isObjectLayerIdentifier*, visualObjectLayerVerId*,
		visualObjectLayerPriority*, aspectRatioInfo*, volControlParameters*, chromaFormat*, lowDelay*, vbvParameters*,
		firstHalfBitRate*, latterHalfBitRate*, firstHalfvbvBufferSize*, latterHalfvbvBufferSize*, firstHalfvbvOccupancy*,
		latterHalfvbvOccupancy*, shape*, timeIncrementResolution*, fixedVopRate*, fixedVopTimeIncrement*, width*, height*,
		interlaced*, obmcDisable*, spriteUsage*, not8Bit*, quantPrecision*, bitsPerPixel*, quantType*, loadIntraQuantMatrix*,
		loadNonIntraQuantMatrix*, quarterPixel*, complexityEstimationDisable*, errorResDisable*, dataPartitioning*,
		intraacdcPredDisable*, scalability*: LONGINT;

		(* gop *)
		timeCode*, closedGov*, brokenLink*, vop*, predictionType*, timeBase*, timeInc*, vopCoded*, roundingType*,
		horSpatRef*, verSpatRef*, changeCRDisable*, constantAlpha*, constantAlphaValue*, intradcvlcthr*, quantizer*,
		fCodeFor*, shapeCodingType*: LONGINT;

		(* macroblock *)
		notCoded*, mcbpc*, derivedMbType*, cbpc*, acPredFlag*, cbpy*, dQuant*, cbp*: LONGINT;

		(* extra/derived *)
		mbASize*, mbXSize*, mbYSize*, picNum*, mba*, mbXPos*, mbYPos*, intraBlockRescaled*: LONGINT;

		PROCEDURE & init*; (* opt: DecoderOptions ); *)
		BEGIN
			(* Set default values *)
			(*
			width := opt.xDim;
			height := opt.yDim;
			*)
			quantPrecision := 5;
			bitsPerPixel := 8;
			quantType := 0;

			timeIncrementResolution := 15;
			complexityEstimationDisable := 1;

			picNum := 0;
			(*
			mbXSize := width DIV 16;
			mbYSize := height DIV 16;
			mbASize := mbXSize * mbYSize
			*)
		END init;

		PROCEDURE FinishHeader*;
		BEGIN
			mbXSize := width DIV 16;
			mbYSize := height DIV 16;
			mbASize := mbXSize * mbYSize
		END FinishHeader;

	END MP4Header;

	(* Contains decoder options *)
	TYPE DecoderOptions* = OBJECT
	VAR
		xDim*,yDim*, displayYSize*, displayCSize*: LONGINT;	(* Size Of Image *)
		deblockYH*, deblockYV*, deringY*, deblockCH*, deblockCV*, deringC*: BOOLEAN;

		PROCEDURE &init*(width: LONGINT; height: LONGINT );
		BEGIN
			SetPostProcessLevel( 10 );
			xDim := width;
			yDim := height;

			displayYSize := xDim * yDim;
			displayCSize := ( xDim * yDim ) DIV 4
		END init;

		(* Set Postprocesslevel *)
		PROCEDURE SetPostProcessLevel*( n: LONGINT );
		BEGIN
			CASE n OF
					0: deblockYH := FALSE; deblockYV := FALSE; deringY := FALSE;
						deblockCH := FALSE; deblockCV := FALSE; deringC := FALSE;
				| 1: deblockYH := TRUE; deblockYV := FALSE; deringY := FALSE;
						deblockCH := FALSE; deblockCV := FALSE; deringC := FALSE;
				| 2: deblockYH := TRUE; deblockYV := TRUE; deringY := FALSE;
						deblockCH := FALSE; deblockCV := FALSE; deringC := FALSE;
				| 3: deblockYH := TRUE; deblockYV := TRUE; deringY := TRUE;
						deblockCH := FALSE; deblockCV := FALSE; deringC := FALSE;
				| 4: deblockYH := TRUE; deblockYV := TRUE; deringY := TRUE;
						deblockCH := TRUE; deblockCV := FALSE; deringC := FALSE;
				| 5: deblockYH := TRUE; deblockYV := TRUE; deringY := TRUE;
						deblockCH := TRUE; deblockCV := TRUE; deringC := FALSE
			ELSE
				deblockYH := TRUE; deblockYV := TRUE; deringY := TRUE;
				deblockCH := TRUE; deblockCV := TRUE; deringC := TRUE
			END;
		END SetPostProcessLevel;
	END DecoderOptions;

	(* Buffers for the decoder *)
	MP4Buffers *= OBJECT
	VAR
		displayBuffer*, edgedRefBuffer*, edgedForBuffer*: PointerToArrayOfCHAR;
		edgedRefBufferSize*, edgedForBufferSize*, displayBufferSize*: LONGINT;

		PROCEDURE &init*( opt: DecoderOptions );
		BEGIN
			edgedRefBufferSize := ( ( opt.xDim + 64 ) * ( opt.yDim + 64 ) ) +
				( 2 * ( ( ( opt.xDim DIV 2 ) + 64 ) * ( ( opt.yDim DIV 2 ) + 64 ) ) );
			edgedForBufferSize := edgedRefBufferSize;

			displayBufferSize := opt.displayYSize + ( 2 * opt.displayCSize );

			NEW( displayBuffer, displayBufferSize );
			NEW( edgedRefBuffer, edgedRefBufferSize );
			NEW( edgedForBuffer, edgedForBufferSize )
		END init;

	END MP4Buffers;
END DivXTypes.