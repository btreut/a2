MODULE JPEG2000Decoder;

	(* Part of the JPEG2000 decoder implementation *)
	(* Partially based on the JJ2000 reference implementation of EPF Lausanne (http://jj2000.epfl.ch) *)
	(* Contains the main decoding chain (except for the codestream parsing component) *)

	(*
		TODO:
		- "Perfect reconstruction" in the irreversible wavelet filter not done, i.e. the precision somehow is not
		   very accurate which results in a rounding error that gets propagated from up-left
		   to down-right in the image.
		- Colorspace transformation described in a JP2 file is ignored presently.
		- The bit-depths of components that undergo multiple component transformation have to be
		   calculated (that is, the bit-depths before the inverse mct takes place). The dequantizer needs
		   those bit-depths (not the ones for the original image components)
		   -> See also procedure 'ComputeUntransformedBitDepths' in this module (it's commented out)
		- Optimization: Inline procedures Renormd, LpsExchange and MpsExchange of MQDecoder.
	*)

	IMPORT SYSTEM, KernelLog, Streams, J2KCS := JPEG2000DecoderCS, J2KU := JPEG2000DecoderUtil,
			Codecs, Raster, Machine;

	CONST

		(* --- Compile options --- *)

		CBLK_BUFSIZE = 5;	(* The number of code-blocks that each decoder component can buffer locally *)
							(* This means that whenever a component requests code-blocks from the *)
							(* underlying component it will get at most as much code-blocks as fit in the buffer *)

		(* --- END Compile options --- *)

		(* --- Configuration constants --- *)

		(* Constants identifying each component (used for options object for each component) *)
		ENTROPY_DECODER* = 2;
		ROI_DESCALER* = 3;
		DEQUANTIZER* = 4;
		INVERSE_DWT* = 5;
		INVERSE_MCT* = 6;

		(* --- END Configuration constants --- *)

		(* Used by a component to set the data type it wants to get delivered from the lower component *)
		DATA_LONGINT* = 0;
		DATA_REAL* = 1;


		(* --- JP2 box types --- *)

		JP2SIGN	= 6A502020H; (* JPEG2000 Signature box *)
		JP2FTYP	= 66747970H; (* File Type box *)
		JP2HEAD	= 6A703268H; (* JP2 Header box *)
		JP2IHDR	= 69686472H; (* Image Header box *)
		JP2BPCC	= 62706363H; (* Bits Per Component box *)
		JP2COLR	= 636F6C72H; (* Colour Specification box *)
		JP2PCLR	= 70636C72H; (* Palette box *)
		JP2CMAP	= 636D6170H; (* Component Mapping box *)
		JP2CDEF	= 63646566H; (* Channel Definition box *)
		JP2RESL	= 72657320H; (* Resolution box *)
		JP2RESC	= 72657363H; (* Capture Resolution box *)
		JP2RESD	= 72657364H; (* Default Display Resolution box *)
		JP2CCST		= 6A703263H; (* Contiguous Codestream box *)
		JP2INPR	= 6A703269H; (* Intellectual Property box *)
		JP2XMLD	= 786D6C20H; (* XML box *)
		JP2UUID	= 75756964H; (* UUID box *)
		JP2UINF	= 75696E66H; (* UUID Info box *)
		JP2ULST	= 75637374H; (* UUID List box *)
		JP2URLS	= 75726C20H; (* URL box *)

		(* --- END JP2 box types --- *)

		JP2_FTBRAND = 6A703220H;	(* File Type brand ('jp2/040') *)

		ENTROPY_SEG_MARKER = SYSTEM.VAL(LONGINT, 0AH);

		(* --- Constants used in MQ-Decoder --- *)

		MQTABSIZ = 47;	(* The size of the table which contains the probability estimations, state transitions, nlps, nmps and switch values.*)

		(* --- END Constants used in MQ-Decoder --- *)

		(* --- Constants used in EntropyDecoder --- *)

		(* The number of bits used to represent a specific neighbor state as used in the significance propagation and cleanup coding passes *)
		ENTROPY_ZERO_BITS = 8;
		(* The number of bits used to represent neighbor states / signs as used in the sign bit decoding *)
		ENTROPY_SIGN_BITS = 8;
		(*
			 Masks to see wether a specific neighbor is significant ("1" means "significant"):
			 We have one "register" to store all information about neighbor significance
			 The order from most significant bit to least significant bit is the following:
			 HL (horizontal left) - HR (horizontal right) - VU (vertical up) - VD (vertical down) - <Diagonals>, where the internal order of <Diagonals> is
			 not specified in more detail
		*)
		ENTROPY_SIGHL = LSH(SYSTEM.VAL(LONGINT, 1), ENTROPY_ZERO_BITS - 1);	(* HL: horizontal left neighbor *)
		ENTROPY_SIGHR = LSH(SYSTEM.VAL(LONGINT, 1), ENTROPY_ZERO_BITS - 2);	(* HR: horizontal right neighbor *)
		ENTROPY_SIGVU = LSH(SYSTEM.VAL(LONGINT, 1), ENTROPY_ZERO_BITS - 3);	(* VU: vertical upper neighbor *)
		ENTROPY_SIGVD = LSH(SYSTEM.VAL(LONGINT, 1), ENTROPY_ZERO_BITS - 4);	(* VD: vertical lower neighbor *)


		(* Mask to extract the context of the sign lut (and discarding the xor bit) *)
		SIGN_LUT_MASK = SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0FH));

		(* The separation (in bits) of the two state vectors stored in the same state register *)
		STATE_SEP = 16;

		(* First-row coefficient values *)
		(* Flag for the significane a first-row coefficient (in the state register) *)
		STATE_SIG_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 14));
		(* Flag to indicate if a first-row coefficient has been visited in the decoding of the current bit-plane *)
		STATE_VISITED_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 13));
		(* Flag to indicate if a first-row coefficient is in the magnitude refinement phase *)
		STATE_MAGREF_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 12));
		(* 1 if the horizontal left neighbor has a negative sign, 0 else *)
		STATE_H_L_SIGN_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 11));
		(* 1 if the horizontal right neighbor has a negative sign, 0 else *)
		STATE_H_R_SIGN_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 10));
		(* 1 if the vertical-up neighbor has a negative sign, 0 else *)
		STATE_V_U_SIGN_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 9));
		(* 1 if the vertical_down neighbor has a negative sign, 0 else *)
		STATE_V_D_SIGN_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 8));

		(* 1 if the horizontal left neighbor is significant already, 0 else *)
		STATE_H_L_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 7));
		(* 1 if the horizontal right neighbor is significant already, 0 else *)
		STATE_H_R_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 6));
		(* 1 if the vertical-up neighbor is significant already, 0 else *)
		STATE_V_U_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 5));
		(* 1 if the vertical_down neighbor is significant already, 0 else *)
		STATE_V_D_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 4));

		(* 1 if the diagonal upper left neighbor is significant already, 0 else *)
		STATE_D_UL_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 3));
		(* 1 if the diagonal upper right neighbor is significant already, 0 else *)
		STATE_D_UR_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 2));
		(* 1 if the diagonal lower left neighbor  is significant already, 0 else *)
		STATE_D_DL_R1 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), 1));
		(* 1 if the diagonal lower right neighbor is significant already, 0 else *)
		STATE_D_DR_R1 = SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 1));
		(* Mask to extract the zero-bin context vector of a first-row coefficient *)
		STATE_VECT_MASK_R1 = SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0FFH));
		(* Mask to extract the sign context vector of a first-row coefficient *)
		SIGN_VECT_MASK_R1 = SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0FF0H));
		(*
			How much we need to shift the state vector of a first row coefficient
			so that the sign context vector starts at the LSB.
		*)
		SIGN_VECT_SHIFT_R1 = 4;

		(* And the same stuff for the second-row coefficient *)
		(* Flag for the significane a second-row coefficient (in the state register) *)
		STATE_SIG_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_SIG_R1), STATE_SEP));
		(* Flag to indicate if a second-row coefficient has been visited in the decoding of the current bit-plane *)
		STATE_VISITED_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_VISITED_R1), STATE_SEP));
		(* Flag to indicate if a second-row coefficient is in the magnitude refinement phase *)
		STATE_MAGREF_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_MAGREF_R1), STATE_SEP));
		(* 1 if the horizontal left neighbor has a negative sign, 0 else *)
		STATE_H_L_SIGN_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_H_L_SIGN_R1), STATE_SEP));
		(* 1 if the horizontal right neighbor has a negative sign, 0 else *)
		STATE_H_R_SIGN_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_H_R_SIGN_R1), STATE_SEP));
		(* 1 if the vertical-up neighbor has a negative sign, 0 else *)
		STATE_V_U_SIGN_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_V_U_SIGN_R1), STATE_SEP));
		(* 1 if the vertical_down neighbor has a negative sign, 0 else *)
		STATE_V_D_SIGN_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_V_D_SIGN_R1), STATE_SEP));

		(* 1 if the horizontal left neighbor is significant already, 0 else *)
		STATE_H_L_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_H_L_R1), STATE_SEP));
		(* 1 if the horizontal right neighbor is significant already, 0 else *)
		STATE_H_R_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_H_R_R1), STATE_SEP));
		(* 1 if the vertical-up neighbor is significant already, 0 else *)
		STATE_V_U_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_V_U_R1), STATE_SEP));
		(* 1 if the vertical_down neighbor is significant already, 0 else *)
		STATE_V_D_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_V_D_R1), STATE_SEP));

		(* 1 if the diagonal upper left neighbor is significant already, 0 else *)
		STATE_D_UL_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_D_UL_R1), STATE_SEP));
		(* 1 if the diagonal upper right neighbor is significant already, 0 else *)
		STATE_D_UR_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_D_UR_R1), STATE_SEP));
		(* 1 if the diagonal lower left neighbor  is significant already, 0 else *)
		STATE_D_DL_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_D_DL_R1), STATE_SEP));
		(* 1 if the diagonal lower right neighbor is significant already, 0 else *)
		STATE_D_DR_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_D_DR_R1), STATE_SEP));
		(* Mask to extract the zero-bin context vector of a first-row coefficient *)
		STATE_VECT_MASK_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, STATE_VECT_MASK_R1), STATE_SEP));
		(* Mask to extract the sign context vector of a first-row coefficient *)
		SIGN_VECT_MASK_R2 = SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, SIGN_VECT_MASK_R1), STATE_SEP));
		(*
			How much we need to shift the state vector of a first row coefficient
			so that the sign context vector starts at the LSB.
		*)
		SIGN_VECT_SHIFT_R2 = 4 + STATE_SEP;


		(* The contexts for the magnitude refinement (MR) pass *)
		ENTROPY_MR_CTX = 16;				(* x neighbors significant, not first refinement for coefficient *)
		ENTROPY_MR_FIRSTNZ_CTX = 15;	(* >= 1 neighbors significant, first refinement for coefficient *)
		ENTROPY_MR_FIRSTZ_CTX = 14;		(* 0 neighbors significant, first refinement for coefficient *)


		(* The UNIFORM and run-length contexts *)
		ENTROPY_UNICTX = 17;
		ENTROPY_RUNCTX = 18;

		ENTROPY_ARRAYOFF = 1;

		ENTROPY_STRIPE_HEIGHT = 4;
		ENTROPY_NUM_PASSES = 3;
		ENTROPY_NUM_NON_BYPASS_BP = 4;
		ENTROPY_FIRST_BYPASS_IDX = 3 * ENTROPY_NUM_PASSES + 1;

		(* --- END Constants used in EntropyDecoder --- *)


		(* --- Constants used for Inverse multiple component transformation --- *)

		MCT_NONE = 0;
		MCT_RCT = 1;
		MCT_ICT = 2;

		(* --- END Constants used for Inverse multiple component transformation --- *)


		(* --- Registered filters --- *)

		(* Reversible filters (operating on LONGINTs) *)
		FILTER_5X3_LIFTING* = 0;
		(* Irreversible filters (operating on REALs) *)
		FILTER_9X7_LIFTING* = 1;

		(* --- END Registered filters --- *)

	TYPE

		(** This is an interface identifying objects that contain a (2 dimensional) block of data *)
		DataBlk = OBJECT
			VAR
				offset : LONGINT;	(* The offset in the data container at which data for this block starts *)
				scanw : LONGINT;	(* The row scan width, i.e. the distance (in data samples) of the first
										 data sample of row j to the first data sample of row j+1 *)
		END DataBlk;

		(** A data block containing data of type LONGINT *)
		DataBlkInt = OBJECT(DataBlk)
			VAR
				data : J2KU.LongIntArrayPtr;
		END DataBlkInt;

		(** A data block containing data of type REAL *)
		DataBlkReal = OBJECT(DataBlk)
			VAR
				data : J2KU.RealArrayPtr;
		END DataBlkReal;

		(* --- MQ-Decoder types --- *)


		(**
			This implementation follows the software conventions for the adaptive entropy decoder
			mentioned in the JPEG2000 standard (Annex J.1)
		*)
		MQDecoder = OBJECT
			VAR
				a : LONGINT;			(* The 'A register' containing the current interval size *)
				c : LONGINT;			(* The 'C register' containing the current byte of compressed image data being decoded *)
				ct : LONGINT;			(* The counter which keeps track of how many bits (of the last byte read in) are still in the lower part of c *)
				b : LONGINT;			(* The current byte to be handled *)
				index : J2KU.LongIntArrayPtr;	(* For every context the current index is stored here *)
				initIdx : J2KU.LongIntArrayPtr;	(* For every context the initial index is stored here *)
				mps : J2KU.LongIntArrayPtr;		(* For every context the current MPS is stored here *)
				initMps : J2KU.LongIntArrayPtr;	(* For every context the initial MPS is stored here *)
				br : J2KU.ByteArrayReader;		(* Source from which to get new bytes *)
				markerFound : BOOLEAN;		(* Indicates if a marker has been found *)


			PROCEDURE &InitNew *(initIdx, initMps : J2KU.LongIntArrayPtr);
				BEGIN
					br := NIL;
					ReInit(initIdx, initMps);
			END InitNew;


			PROCEDURE ReInit (initIdx, initMps : J2KU.LongIntArrayPtr);
				BEGIN
					ASSERT(LEN(initMps^) = LEN(initIdx^));
					SELF.initIdx := initIdx;
					SELF.initMps := initMps;
					NEW(index, LEN(initIdx^));
					NEW(mps, LEN(initMps^));

					IF br = NIL THEN
						NEW(br, NIL, -1, 0);
					ELSE
						br.ReInit(NIL, -1, 0);
					END;

			END ReInit;


			(**
				This procedure makes new raw coded code-block data available to the MQ-Decoder.
				The MQ-Decoder restarts with the new segment (i.e. The 'A' and 'C registers' will be flushed and refilled).

				data:	The new coded code-block data (by reference)
				offset:	Where to start reading from the data buffer
				len:		The length of this segment of coded code-block data
			*)
			PROCEDURE NextSegment (data : J2KU.ByteArrayPtr; offset, len : LONGINT);
				BEGIN
					br.SetArray(data, offset, len);
					InitDec();
			END NextSegment;

			PROCEDURE GetByteReader () : J2KU.ByteArrayReader;
				BEGIN
					RETURN br;
			END GetByteReader;


			(** Resets the contexts to their initial index and mps values *)
			PROCEDURE ResetContexts;
				BEGIN
					SYSTEM.MOVE(ADDRESSOF(initIdx[0]), ADDRESSOF(index[0]), LEN(initIdx)*SIZEOF(LONGINT));
					SYSTEM.MOVE(ADDRESSOF(initMps[0]), ADDRESSOF(mps[0]), LEN(initMps)*SIZEOF(LONGINT));
			END ResetContexts;

			(**
				Returns the next bit of the original data .
				cx:	The context to use
			*)
			PROCEDURE Decode (cx : LONGINT) : LONGINT;
				VAR
					chigh, d : LONGINT;
				BEGIN
					chigh := LSH(c, -16);

					a := a - MQPROB[index[cx]];

					IF chigh < a THEN
						(* The MPS case *)
						IF (SYSTEM.VAL(SET, a) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 00008000H))) = {} THEN
							d := MpsExchange(cx);
							Renormd();
						ELSE
							 d := mps[cx];
						END;
					ELSE
						(* The LPS case *)
						chigh := chigh - a;

						(* Update the original 'c register' *)
						(* c := (c BITWISE-AND 0x0000FFFF) BITWISE-OR (chigh << 16) *)
						c := SYSTEM.VAL(LONGINT, (SYSTEM.VAL(SET, c) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0000FFFFH))) + SYSTEM.VAL(SET, LSH(chigh, 16)));
						d := LpsExchange(cx);
						Renormd();
					END;

					RETURN d;
			END Decode;

			(** Renormalization procedure as described in the standartd *)
			PROCEDURE Renormd;
				BEGIN
					REPEAT
						IF ct = 0 THEN
							ByteIn();
						END;

						a := LSH(a, 1);
						c := LSH(c, 1);
						DEC(ct);
					UNTIL (SYSTEM.VAL(SET, a) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 00008000H))) # {};
			END Renormd;

			(**
				LPS exchange procedure as described in the standartd
				cx: The current context
			*)
			PROCEDURE LpsExchange (cx : LONGINT) : LONGINT;
				VAR
					d : LONGINT;
				BEGIN

					IF a < MQPROB[index[cx]] THEN
						a := MQPROB[index[cx]];
						d := mps[cx];
						index[cx] := MQNMPS[index[cx]];
					ELSE
						a := MQPROB[index[cx]];
						d := SYSTEM.VAL(LONGINT, {0} / SYSTEM.VAL(SET, mps[cx]));
						IF MQSWITCH[index[cx]] = 1 THEN
							mps[cx] := SYSTEM.VAL(LONGINT, {0} / SYSTEM.VAL(SET, mps[cx]));
						END;
						index[cx] := MQNLPS[index[cx]];
					END;

					RETURN d;
			END LpsExchange;

			(**
				MPS exchange procedure as described in the standartd
				cx: The current context
			*)
			PROCEDURE MpsExchange (cx : LONGINT) : LONGINT;
				VAR
					d : LONGINT;
				BEGIN

					IF a < MQPROB[index[cx]] THEN
						d := SYSTEM.VAL(LONGINT, {0} / SYSTEM.VAL(SET, mps[cx]));
						IF MQSWITCH[index[cx]] = 1 THEN
							mps[cx] := SYSTEM.VAL(LONGINT, {0} / SYSTEM.VAL(SET, mps[cx]));
						END;
						index[cx] := MQNLPS[index[cx]];
					ELSE
						d := mps[cx];
						index[cx] := MQNMPS[index[cx]];
					END;

					RETURN d;
			END MpsExchange;

			(** Byte input procedure as described in the standartd *)
			PROCEDURE ByteIn;
				BEGIN

					IF ~markerFound THEN
						IF b = 255 THEN
							b := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, br.Read()) * {0..7}); (* Convert -1 to 0xFF *)

							IF b > 8FH THEN
								markerFound := TRUE;
								ct := 8;
							ELSE
								c := c + SYSTEM.VAL(LONGINT, 0FE00H) - LSH(b, 9);
								ct := 7;
							END;
						ELSE
							b := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, br.Read()) * {0..7}); (* Convert -1 to 0xFF *)
							(*
								NOTE: The Standard specifies here: c = c + 0xFE00 - (B << 8). But we use an BITWISE-XOR operation instead of the subtraction.
								That's ok because no carry overs can occur since we subtract from 0xFF00
							*)
							c := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, c) + ({8..15} / SYSTEM.VAL(SET, LSH(b, 8))));

							ct := 8;
						END;
					ELSE
						ct := 8;
					END;
			END ByteIn;

			(** Decoder initialization procedure as described in the standartd *)
			PROCEDURE InitDec;
				BEGIN
					markerFound := FALSE;

					b := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, br.Read()) * {0..7}); (* Converts -1 to 0xFF *)
					(* c := (b BITWISE-XOR 0xFF) << 16 *)
					c := LSH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, b) / {0..7}), 16);
					ByteIn();
					c := LSH(c, 7);
					ct := ct - 7;
					a := SYSTEM.VAL(LONGINT, 00008000H);
			END InitDec;

			(** Checks the remainder of the segment (used when predictable termination coding is used) *)
			PROCEDURE CheckPredTerm () : BOOLEAN;
				VAR
					k : LONGINT;	(* The number of bits that were added in the termination process *)
					q : LONGINT;
				BEGIN

					(*
						(1)
						If everything went normal, the current byte must be 0xFF if a terminating marker
						has not been found yet.
					*)
					IF (b # 255) & ~markerFound THEN
						RETURN FALSE;
					END;

					(*
						(2)
						If 'ct' is not 0 we must have reached the terminating marker already
					*)
					IF (ct # 0) & ~markerFound THEN
						RETURN FALSE;
					END;

					(*
						(3)
						If 'ct' is 1 there were no spare bits at the encoder, this is all we can check
					*)
					IF ct = 1 THEN
						RETURN TRUE;
					END;

					(*
						(4)
						If 'ct' is 0, then the next byte must be the second byte of a terminating
						marker (i.e. larger than 0x8F) if the terminating marker has not beed
						read yet
					*)
					IF ct = 0 THEN
						IF ~markerFound THEN
							b := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, br.Read()) * {0..7});
							IF b <= 8FH THEN
								RETURN FALSE;
							END;
						END;
						(* Adjust 'ct' for last byte *)
						ct := 8;
					END;

					(*
						(5)
						Now we can calculate the 'k', the number of bits having
						error resilience information. 'k' is the number of bits left
						to normalization in the 'C register', minus 1
					*)
					k := ct - 1;

					(*
						(6)
						The predictable termination policy is as if an LPS interval was
						coded, and a renormalization of 'k' bits was caused, before the
						termination marker started
					*)

					(*
						We first check if an LPS is decoded, that causes a renormalization
						of 'k' bits. Worst case is smallest LPS probability 'q' that causes
						a renormalization of 'k' bits
					*)
					q := LSH(8000H, -k);

					(* Check that we can decode an LPS interval of probability 'q' *)
					DEC(a, q);

					IF LSH(c, -16) < a THEN
						(* Error: MPS interval decoded *)
						RETURN FALSE;
					END;

					(* OK: LPS interval decoded *)
					c := c - LSH(a, 16);

					(*
						Here 'a' can not be smaller than 'q' because the minimum value
						for 'a' is 0x8000-0x4000 = 0x4000 and 'q' is set to a value equal
						or smaller than that
					*)
					a := q;
					Renormd();

					(*
						(7)
						Everything seems OK, we have checked the 'C register' for the LPS
						symbols and ensured that it is followed by bits synthesized by the
						termination marker
					*)
					RETURN TRUE;
			END CheckPredTerm;

		END MQDecoder;

		(* --- END MQ-Decoder types --- *)

		(* --- Entropy decoder types --- *)

		EntropyDecoder = OBJECT
			VAR
				cr : J2KCS.CodestreamReader;
				decSpec : J2KCS.DecoderSpecs;

				(*
					CONCEPT:
					The state array for entropy coding. Each element of the state array
					stores the state of two coefficients. The lower 16 bits store the state
					of a coefficient in row 'i' and column 'j', while the upper 16 bits
					store the state of a coefficient in row 'i+1' and column 'j'. The 'i'
					row is either the first or the third row of a stripe. This packing of
					the states into 32 bit words allows a faster scan of all coefficients
					on each coding pass and diminishes the amount of data transferred. The
					size of the state array is increased by 1 on each side (top, bottom,
					left, right) to handle boundary conditions without any special logic.

					The state of a coefficient is stored in the following way in the
					lower 16 bits, where bit 0 is the least significant bit. Bit 15 is not used.
					Bit 14 is the significance of a coefficient (0 if non-significant, 1 otherwise).
					Bit 13 is the visited state (i.e. if a coefficient has been coded in the
					significance propagation pass of the current bit-plane). Bit 12 indicates if
					the magnitude refinement has already been applied to the
					coefficient. Bits 11 to 8 store the sign of the already significant left, right,
					up and down neighbors (1 for negative, 0 for positive or not yet significant).
					Bits 7 to 4 store the significance of the left, right, up and down neighbors
					(1 for significant, 0 for non significant). Bits 3	to 0 store the significance
					of the diagonal coefficients (up-left, up-right, down-left and down-right;
					1 for significant, 0 for non significant).

					The upper 16 bits the state is stored as in the lower 16 bits,
					but with the bits shifted up by 16.

					The lower 16 bits are referred to as "row 1" ("R1") while the upper
					16 bits are referred to as "row 2" ("R2").
				*)
				state : J2KU.SetArrayPtr;
				mq : MQDecoder;			(* A reference to the MQ decoder *)
				dbr : J2KU.DataBitReader;			(* Used to read raw bits of coefficient data extracted from the stream *)
				(* Some entropy decoder options *)
				predTerm, resetCtx, vertCausal, segUsed : BOOLEAN;
				concealError : BOOLEAN;		(* If TRUE, error concealment will be done (if errors are detected) *)

			PROCEDURE &InitNew *(edOpt : J2KU.EntropyDecoderOptions;
									cr : J2KCS.CodestreamReader;
									decSpec : J2KCS.DecoderSpecs);
				BEGIN
					mq := NIL;
					dbr := NIL;
					ReInit(edOpt, cr, decSpec);
			END InitNew;

			PROCEDURE ReInit (	edOpt : J2KU.EntropyDecoderOptions;
									cr : J2KCS.CodestreamReader;
									decSpec : J2KCS.DecoderSpecs);
				BEGIN
					concealError := edOpt.concealError;
					SELF.cr := cr;
					SELF.decSpec := decSpec;

					IF mq = NIL THEN
						NEW(mq, MQ_INITSTATES, MQ_INITMPS);
					ELSE
						mq.ReInit(MQ_INITSTATES, MQ_INITMPS);
					END;

					IF dbr = NIL THEN
						NEW(dbr, mq.GetByteReader());
					ELSE
						dbr.ReInit(mq.GetByteReader());
					END;

					state := NIL;

			END ReInit;

			(**
				Sets the maximum layer range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested.
				This procedure shall NOT be called after the first code-block data
				has been read.

				maxStartLayer and maxEndLayer are inclusive.
			*)
			PROCEDURE SetMaxLayerRange (maxStartLayer, maxEndLayer : LONGINT);
				BEGIN
					cr.SetMaxLayerRange(maxStartLayer, maxEndLayer);
			END SetMaxLayerRange;

			(**
				Sets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE SetLayerRange (startLayer, endLayer : LONGINT);
				BEGIN
					cr.SetLayerRange(startLayer, endLayer);
			END SetLayerRange;

			(**
				Gets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE GetLayerRange (VAR startLayer, endLayer : LONGINT);
				BEGIN
					cr.GetLayerRange(startLayer, endLayer);
			END GetLayerRange;

			(**
				Sets the maximum decomposition level range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested. This procedure
				shall NOT be called after the first code-block data has been read.

				maxStartDecLvl : The decompositon level to start at (inclusive) -> upper bound
				maxEndDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetMaxDecLevelRange (maxStartDecLvl, maxEndDecLvl : LONGINT);
				BEGIN
					cr.SetMaxDecLevelRange(maxStartDecLvl, maxEndDecLvl);
			END SetMaxDecLevelRange;

			(**
				Sets the decomposition level range for which data shall be delivered
				and decoded.

				startDecLvl : The decompositon level to start at (inclusive) -> upper bound
				endDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetDecLevelRange (startDecLvl, endDecLvl : LONGINT);
				BEGIN
					cr.SetDecLevelRange(startDecLvl, endDecLvl);
			END SetDecLevelRange;

			(**
				Gets the decomposition level range for which data shall be delivered
				and decoded.

				startDecLvl : The decompositon level to start at (inclusive) -> upper bound
				endDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE GetDecLevelRange (VAR startDecLvl, endDecLvl : LONGINT);
				BEGIN
					cr.GetDecLevelRange(startDecLvl, endDecLvl);
			END GetDecLevelRange;

			PROCEDURE SetReBuildMode;
				BEGIN
					cr.SetReBuildMode();
			END SetReBuildMode;

			(* Gets the entropy decoded code-blocks *)
			PROCEDURE GetCodeBlocks (VAR cblk : ARRAY OF DataBlk; VAR cblkInfo : ARRAY OF J2KU.CblkInfo; ncblks : LONGINT) : LONGINT;
				VAR
					cblkIdx, ncblksRet : LONGINT;
					codedCblk : ARRAY CBLK_BUFSIZE OF J2KU.CodedCblk;
					curDataBlk : DataBlkInt;
					curCblkInfo : J2KU.CblkInfo;
					passes, curBp, lastNonBypassBp, segIdx, tile, comp : LONGINT;
					zeroLUT, data : J2KU.LongIntArrayPtr;
					bypass, term, cleanupTerm : BOOLEAN;	(* Some entropy decoder options *)
					ok : BOOLEAN;
				BEGIN

					(*
						This implementation relies on the condition that the component above this one
						always requests <= CBLK_BUFSIZE code-blocks
					*)
					ASSERT(ncblks <= CBLK_BUFSIZE);

					ncblksRet := cr.GetCodeBlocks(codedCblk, cblkInfo, ncblks);

					(* Get as many coded code-blocks in the stream as needed, decode them *)
					tile := cr.CurrentTile();

					FOR cblkIdx := 0 TO ncblksRet - 1 DO
						curDataBlk := cblk[cblkIdx](DataBlkInt);
						curCblkInfo := cblkInfo[cblkIdx];

						curBp := curCblkInfo.curbp;
						passes := codedCblk[cblkIdx].cpasses;
						data := curDataBlk.data;

						(* See if we need to allocate a new array *)
						IF	(data = NIL)
							OR (curDataBlk.scanw < curCblkInfo.width)
							OR (LEN(data^) < (curDataBlk.scanw*curCblkInfo.height + curDataBlk.offset))
						THEN
							NEW(data, curCblkInfo.width*curCblkInfo.height);
							curDataBlk.data := data;
							curDataBlk.offset := 0;
							curDataBlk.scanw := curCblkInfo.width;
						END;

						Machine.Fill32(ADDRESSOF(data[0]), LEN(data^)*SIZEOF(LONGINT), 0);
						Machine.Fill32(ADDRESSOF(state[0]), LEN(state^)*SIZEOF(SET), 0);

						(* Restart MQ-Decoder *)
						IF codedCblk[cblkIdx].nseg > 1 THEN
							mq.NextSegment(codedCblk[cblkIdx].data, 0, codedCblk[cblkIdx].segLen[0]);
						ELSE
							mq.NextSegment(codedCblk[cblkIdx].data, 0, codedCblk[cblkIdx].dataLen);
						END;

						mq.ResetContexts();
						segIdx := 1;

						(* See which significance LUT is to be used *)
						CASE curCblkInfo.subbinfo.type OF
								J2KU.SUB_LL:
									zeroLUT := ENTROPY_ZEROLL_LUT;
							|	J2KU.SUB_HL:
									zeroLUT := ENTROPY_ZEROHL_LUT;
							|	J2KU.SUB_LH:
									zeroLUT := ENTROPY_ZEROLL_LUT;
							|	J2KU.SUB_HH:
									zeroLUT := ENTROPY_ZEROHH_LUT;
						END;

						comp := curCblkInfo.subbinfo.component;

						(* Get options *)
						bypass := decSpec.BypassCoding(tile, comp);
						term := decSpec.RegularTermination(tile, comp);
						predTerm := decSpec.PredictableTermination(tile, comp);
						resetCtx := decSpec.ResetContexts(tile, comp);
						segUsed := decSpec.SegmentationSymbols(tile, comp);
						vertCausal := decSpec.VerticallyCausalContext(tile, comp);

						IF bypass THEN
							(* Determine the first bit-plane for which MQ bypassing is used *)
							lastNonBypassBp := J2KU.LONGINT_BITS - 1 - ENTROPY_NUM_NON_BYPASS_BP - curCblkInfo.zerobp;
						END;

						(* The cleanup pass terminates if the "termination on each coding pass" option is used *)
						cleanupTerm := term;
						ok := TRUE;

						(* Cleanup pass comes first *)
						IF (passes > 0) & (curBp >= 0) THEN
							ok := CleanupPass(curDataBlk, curCblkInfo, curBp, zeroLUT, cleanupTerm);

							DEC(passes);

							IF ok OR ~concealError THEN
								DEC(curBp);
							END;
						END;

						IF ok OR ~concealError THEN
							LOOP
								IF (passes <= 0) OR (curBp < 0) THEN EXIT; END;

								IF bypass & (curBp < lastNonBypassBp) THEN
									(* Raw significance propagation pass *)
									(* Start a new raw segment *)
									dbr.NextSegment(NIL, -1, codedCblk[cblkIdx].segLen[segIdx]);
									INC(segIdx);

									ok := RawSigPropPass(curDataBlk, curCblkInfo, curBp, term);
									DEC(passes);

									IF (passes <= 0) OR (~ok & concealError) THEN EXIT; END;

									IF term THEN
										(* Start of new raw segment *)
										dbr.NextSegment(NIL, -1, codedCblk[cblkIdx].segLen[segIdx]);
										INC(segIdx);
									END;

									(* Raw magnitude refinement pass *)
									(* NOTE: We always terminate after this pass *)
									ok := RawMagRefPass(curDataBlk, curCblkInfo, curBp, TRUE);
								ELSE
									IF term THEN
										(* Start of new segment *)
										mq.NextSegment(NIL, -1, codedCblk[cblkIdx].segLen[segIdx]);
										INC(segIdx);
									END;

									(* Significance propagation pass *)
									ok := SigPropPass(curDataBlk, curCblkInfo, curBp, zeroLUT, term);
									DEC(passes);

									IF (passes <= 0) OR (~ok & concealError) THEN EXIT; END;

									IF term THEN
										(* Start of new segment *)
										mq.NextSegment(NIL, -1, codedCblk[cblkIdx].segLen[segIdx]);
										INC(segIdx);
									END;

									(* Magnitude refinement pass *)
									ok := MagRefPass(curDataBlk, curCblkInfo, curBp, term);
								END;

								DEC(passes);

								IF (passes <= 0) OR (~ok & concealError) THEN EXIT; END;

								IF term OR (bypass & (curBp < lastNonBypassBp)) THEN
									(* Start a new MQ segment *)
									mq.NextSegment(NIL, - 1, codedCblk[cblkIdx].segLen[segIdx]);
									INC(segIdx);
								END;

								IF bypass & (curBp = lastNonBypassBp) THEN
									(* From now on the cleanup pass always terminates *)
									cleanupTerm := TRUE;
								END;

								(* Cleanup pass *)
								ok := CleanupPass(curDataBlk, curCblkInfo, curBp, zeroLUT, cleanupTerm);
								DEC(passes);

								IF ~ok & concealError THEN EXIT; END;

								(* Go to next bit-plane *)
								DEC(curBp);

							END;
						END;

						IF ~ok & concealError THEN
							LogConcealMsg(curCblkInfo, curBp);
							Conceal(curDataBlk, curCblkInfo, curBp);
						END;
					END;

					RETURN ncblksRet;
			END GetCodeBlocks;


			PROCEDURE DataAvailable  () : BOOLEAN;
				BEGIN
					RETURN ~cr.EndOfCodestream();
			END DataAvailable;

			PROCEDURE TilePartAvailable  () : BOOLEAN;
				BEGIN
					RETURN cr.TilePartAvailable();
			END TilePartAvailable;

			PROCEDURE AllTilePartsRead () : BOOLEAN;
				BEGIN
					RETURN cr.AllTilePartsRead();
			END AllTilePartsRead;


			PROCEDURE NextTilePart () : BOOLEAN;
				BEGIN
					IF ~cr.NextTilePart() THEN
						RETURN FALSE;
					END;

					RETURN InitTile();
			END NextTilePart;

			PROCEDURE InitTile () : BOOLEAN;
				VAR
					curTile, maxCblkWidth, maxCblkHeight, maxSize : LONGINT;
				BEGIN

					IF cr.CurrentTilePart() = 0 THEN
						(* See if we have to enlarge the state array *)
						curTile := cr.CurrentTile();

						maxCblkWidth := LSH(SYSTEM.VAL(LONGINT, 1), decSpec.GetMaxCblkWidthExp(curTile));
						maxCblkHeight := LSH(SYSTEM.VAL(LONGINT, 1), decSpec.GetMaxCblkHeightExp(curTile));
						maxSize := (maxCblkWidth + 2 * ENTROPY_ARRAYOFF) * (((maxCblkHeight + 1 ) DIV 2)+ 2 * ENTROPY_ARRAYOFF);

						IF (state = NIL) OR (LEN(state^) < maxSize) THEN
							NEW(state, maxSize);
						END;
					END;

					RETURN TRUE;
			END InitTile;

			PROCEDURE CurrentTile () : LONGINT;
				BEGIN
					RETURN cr.CurrentTile();
			END CurrentTile;

			PROCEDURE CurrentTilePart () : LONGINT;
				BEGIN
					RETURN cr.CurrentTilePart();
			END CurrentTilePart;


			PROCEDURE GetSubbandInfo (tile, component, reslevel, subband : LONGINT) : J2KU.SubbandInfo;
				BEGIN
					RETURN cr.GetSubbandInfo(tile, component, reslevel, subband)
			END GetSubbandInfo;

			(* Logs a message when an error has been detected and concealing is done *)
			PROCEDURE LogConcealMsg (cblkInfo : J2KU.CblkInfo; curBp : LONGINT);
				BEGIN
					KernelLog.String("WARNING: EntropyDecoder detected error at bit-plane ");
					KernelLog.Int(curBp, 0);
					KernelLog.String(" in code-block ");
					KernelLog.Int(cblkInfo.index, 0);
					KernelLog.String(" , subband index ");
					KernelLog.Int(cblkInfo.subbinfo.index, 0);
					KernelLog.String(", res. level");
					KernelLog.Int(cblkInfo.subbinfo.reslevel, 0);
					KernelLog.String(", component ");
					KernelLog.Int(cblkInfo.subbinfo.component, 0);
					KernelLog.String(", tile ");
					KernelLog.Int(cr.CurrentTile(), 0);
					KernelLog.Ln();
					KernelLog.String("Concealing...");
					KernelLog.Ln();
			END LogConcealMsg;


			(* This procedure applies the significance propagation pass to the compressed image data *)
			PROCEDURE SigPropPass (cblk : DataBlk; cblkInfo : J2KU.CblkInfo; curBp : LONGINT; zeroLUT : J2KU.LongIntArrayPtr; term : BOOLEAN) : BOOLEAN;
				VAR
					i, j : LONGINT;
					stripeHeight : LONGINT;
					dataIdx, stateIdx : LONGINT;
					curState : SET;
					rowStartState, rowWidthState, rowStartData : LONGINT;
					stateStripeIncr, dataStripeIncr : LONGINT;
					ctx : LONGINT;
					sign : LONGINT;
					setMask : SET;
					ok : BOOLEAN;
					data : J2KU.LongIntArrayPtr;
					scanw : LONGINT;	(* The scan width of the code-block data *)
					off_ul, off_ur, off_dl, off_dr : LONGINT;
				BEGIN
					(* Get local reference to data *)
					data := cblk(DataBlkInt).data;

					setMask := SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 3), curBp - 1));
					rowWidthState := cblkInfo.width + 2 * ENTROPY_ARRAYOFF;
					(* Cache rowStart (of the extended arrays) *)
					rowStartState := rowWidthState + ENTROPY_ARRAYOFF;
					scanw := cblk.scanw;
					rowStartData := cblk.offset;
					stateStripeIncr := (ENTROPY_STRIPE_HEIGHT DIV 2)*rowWidthState;
					dataStripeIncr := ENTROPY_STRIPE_HEIGHT*scanw;

					(* Offsets for diagonal neighbors *)
					off_ul := -rowWidthState - 1;	(* Up left *)
					off_ur := -rowWidthState + 1;	(* Up right *)
					off_dl := rowWidthState - 1;		(* Down left *)
					off_dr := rowWidthState + 1;		(* Down right *)

					i := 0;
					(* Loop on rows *)
					WHILE i < cblkInfo.height DO
						(* We have to check if there are enough rows to scan an entire stripe or just a truncated one *)
						IF ENTROPY_STRIPE_HEIGHT > (cblkInfo.height - i) THEN
							stripeHeight := cblkInfo.height - i;
						ELSE
							stripeHeight := ENTROPY_STRIPE_HEIGHT;
						END;

						FOR j := 0 TO cblkInfo.width - 1 DO
							stateIdx := rowStartState + j;
							dataIdx := rowStartData + j;
							curState := state[stateIdx];

							(* Scan 1st row *)
							IF	(curState * STATE_SIG_R1 = {})
								& (curState * STATE_VECT_MASK_R1 # {})
							THEN

								(* Did the coefficient just become significant? If not, move on *)
								IF mq.Decode(zeroLUT[SYSTEM.VAL(LONGINT, curState * STATE_VECT_MASK_R1)]) = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									ctx := ENTROPY_SIGN_LUT[LSH(SYSTEM.VAL(LONGINT, curState*SIGN_VECT_MASK_R1), -SIGN_VECT_SHIFT_R1)];


									sign := SYSTEM.VAL(LONGINT,
												SYSTEM.VAL(SET, mq.Decode(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ctx) * SIGN_LUT_MASK)))
												/ SYSTEM.VAL(SET, LSH(ctx, -J2KU.LONGINT_BITS + 1))
											);

									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
									IF ~vertCausal THEN
										(* Upper diagonal neighbors *)
										(* Only update previous stripe if not in vertical causal mode *)
										state[stateIdx + off_ul] := state[stateIdx + off_ul] + STATE_D_DR_R2;
										state[stateIdx + off_ur] := state[stateIdx + off_ur] + STATE_D_DL_R2;
									END;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R1 + STATE_VISITED_R1
													+ STATE_V_U_R2 + STATE_V_U_SIGN_R2;

										IF ~vertCausal THEN
											(* Only update previous stripe if not in vertical causal mode *)
											state [stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																		+ STATE_V_D_R2
																		+ STATE_V_D_SIGN_R2;
										END;

										state [stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_H_R_SIGN_R1
															+ STATE_D_UR_R2;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_H_L_SIGN_R1
															+ STATE_D_UL_R2;

									ELSE
										curState := curState
													+ STATE_SIG_R1 + STATE_VISITED_R1
													+ STATE_V_U_R2;

										IF ~vertCausal THEN
											(* Only update previous stripe if not in vertical causal mode *)
											state [stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																		+ STATE_V_D_R2;
										END;

										state [stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_D_UR_R2;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_D_UL_R2;

									END;
								ELSE
									curState := curState + STATE_VISITED_R1;
								END;

								state[stateIdx] := curState;
							END;

							(* Scan 2nd row *)
							INC(dataIdx, scanw);

							IF	(stripeHeight > 1)
								& (curState * STATE_SIG_R2 = {})
								& (curState * STATE_VECT_MASK_R2 # {})
							THEN

								(* Did the coefficient just become significant? If not, move on *)
								IF mq.Decode(zeroLUT[LSH(SYSTEM.VAL(LONGINT, curState * STATE_VECT_MASK_R2), -STATE_SEP)]) = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									ctx := ENTROPY_SIGN_LUT[LSH(SYSTEM.VAL(LONGINT, curState*SIGN_VECT_MASK_R2), -SIGN_VECT_SHIFT_R2)];
									sign := SYSTEM.VAL(LONGINT,
												SYSTEM.VAL(SET, mq.Decode(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ctx) * SIGN_LUT_MASK)))
												/ SYSTEM.VAL(SET, LSH(ctx, -J2KU.LONGINT_BITS + 1))
											);

									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
									(* Lower diagonal neighbors *)
									state[stateIdx + off_dl] := state[stateIdx + off_dl] + STATE_D_UR_R1;
									state[stateIdx + off_dr] := state[stateIdx + off_dr] + STATE_D_UL_R1;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R2 + STATE_VISITED_R2
													+ STATE_V_D_R1 + STATE_V_D_SIGN_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																	+ STATE_V_U_R1
																	+ STATE_V_U_SIGN_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_H_R_SIGN_R2
															+ STATE_D_DR_R1;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_H_L_SIGN_R2
															+ STATE_D_DL_R1;

									ELSE
										curState := curState
													+ STATE_SIG_R2 + STATE_VISITED_R2
													+ STATE_V_D_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																		+ STATE_V_U_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_D_DR_R1;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_D_DL_R1;

									END;
								ELSE
									curState := curState + STATE_VISITED_R2;
								END;

								state[stateIdx] := curState;
							END;

							(* Scan 3rd row *)
							INC(stateIdx, rowWidthState);
							INC(dataIdx, scanw);
							curState := state[stateIdx];

							IF	(stripeHeight > 2)
								& (curState * STATE_SIG_R1 = {})
								& (curState * STATE_VECT_MASK_R1 # {})
							THEN

								(* Did the coefficient just become significant? If not, move on *)
								IF mq.Decode(zeroLUT[SYSTEM.VAL(LONGINT, curState * STATE_VECT_MASK_R1)]) = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									ctx := ENTROPY_SIGN_LUT[LSH(SYSTEM.VAL(LONGINT, curState*SIGN_VECT_MASK_R1), -SIGN_VECT_SHIFT_R1)];
									sign := SYSTEM.VAL(LONGINT,
												SYSTEM.VAL(SET, mq.Decode(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ctx) * SIGN_LUT_MASK)))
												/ SYSTEM.VAL(SET, LSH(ctx, -J2KU.LONGINT_BITS + 1))
											);

									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
										(* Upper diagonal neighbors *)
									state[stateIdx + off_ul] := state[stateIdx + off_ul] + STATE_D_DR_R2;
									state[stateIdx + off_ur] := state[stateIdx + off_ur] + STATE_D_DL_R2;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R1 + STATE_VISITED_R1
													+ STATE_V_U_R2 + STATE_V_U_SIGN_R2;

										state[stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																	+ STATE_V_D_R2
																	+ STATE_V_D_SIGN_R2;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_H_R_SIGN_R1
															+ STATE_D_UR_R2;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_H_L_SIGN_R1
															+ STATE_D_UL_R2;

									ELSE
										curState := curState
													+ STATE_SIG_R1 + STATE_VISITED_R1
													+ STATE_V_U_R2;

										state [stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																	+ STATE_V_D_R2;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_D_UR_R2;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_D_UL_R2;

									END;
								ELSE
									curState := curState + STATE_VISITED_R1;
								END;

								state[stateIdx] := curState;
							END;

							(* Scan 4th row *)
							INC(dataIdx, scanw);

							IF	(stripeHeight > 3)
								& (curState * STATE_SIG_R2 = {})
								& (curState * STATE_VECT_MASK_R2 # {})
							THEN

								(* Did the coefficient just become significant? If not, move on *)
								IF mq.Decode(zeroLUT[LSH(SYSTEM.VAL(LONGINT, curState * STATE_VECT_MASK_R2), -STATE_SEP)]) = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									ctx := ENTROPY_SIGN_LUT[LSH(SYSTEM.VAL(LONGINT, curState*SIGN_VECT_MASK_R2), -SIGN_VECT_SHIFT_R2)];
									sign := SYSTEM.VAL(LONGINT,
												SYSTEM.VAL(SET, mq.Decode(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ctx) * SIGN_LUT_MASK)))
												/ SYSTEM.VAL(SET, LSH(ctx, -J2KU.LONGINT_BITS + 1))
											);


									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
									(* Lower diagonal neighbors *)
									state[stateIdx + off_dl] := state[stateIdx + off_dl] + STATE_D_UR_R1;
									state[stateIdx + off_dr] := state[stateIdx + off_dr] + STATE_D_UL_R1;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R2 + STATE_VISITED_R2
													+ STATE_V_D_R1 + STATE_V_D_SIGN_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																	+ STATE_V_U_R1
																	+ STATE_V_U_SIGN_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_H_R_SIGN_R2
															+ STATE_D_DR_R1;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_H_L_SIGN_R2
															+ STATE_D_DL_R1;

									ELSE
										curState := curState
													+ STATE_SIG_R2 + STATE_VISITED_R2
													+ STATE_V_D_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																		+ STATE_V_U_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_D_DR_R1;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_D_DL_R1;

									END;
								ELSE
									curState := curState + STATE_VISITED_R2;
								END;

								state[stateIdx] := curState;
							END;
						END;

						(* Move to next row of stripes *)
						INC(i, ENTROPY_STRIPE_HEIGHT);
						(* Compute row start of next row *)
						rowStartState := rowStartState + stateStripeIncr;
						rowStartData := rowStartData + dataStripeIncr;
					END;

					(* We may do an error check if predictable termination is used *)
					IF predTerm & term THEN
						ok := mq.CheckPredTerm();
					ELSE
						ok := TRUE;
					END;

					(* Maybe need to reset contexts *)
					IF resetCtx THEN
						mq.ResetContexts();
					END;

					RETURN ok;
			END SigPropPass;

			(*
				This procedure applies the significance propagation pass to the compressed image data,
				reading bits directly from the stream
			*)
			PROCEDURE RawSigPropPass (cblk : DataBlk; cblkInfo : J2KU.CblkInfo; curBp : LONGINT; term : BOOLEAN) : BOOLEAN;
				VAR
					i, j : LONGINT;
					stripeHeight : LONGINT;
					dataIdx, stateIdx : LONGINT;
					curState : SET;
					rowStartState, rowWidthState, rowStartData : LONGINT;
					stateStripeIncr, dataStripeIncr : LONGINT;
					sign : LONGINT;
					setMask : SET;
					ok : BOOLEAN;
					data : J2KU.LongIntArrayPtr;
					scanw : LONGINT;	(* The scan width of the code-block data *)
					off_ul, off_ur, off_dl, off_dr : LONGINT;
				BEGIN
					(* Get local reference to data *)
					data := cblk(DataBlkInt).data;

					setMask := SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 3), curBp - 1));
					rowWidthState := cblkInfo.width + 2 * ENTROPY_ARRAYOFF;
					(* Cache rowStart (of the extended arrays) *)
					rowStartState := rowWidthState + ENTROPY_ARRAYOFF;
					scanw := cblk.scanw;
					rowStartData := cblk.offset;
					stateStripeIncr := (ENTROPY_STRIPE_HEIGHT DIV 2)*rowWidthState;
					dataStripeIncr := ENTROPY_STRIPE_HEIGHT*scanw;

					(* Offsets for diagonal neighbors *)
					off_ul := -rowWidthState - 1;	(* Up left *)
					off_ur := -rowWidthState + 1;	(* Up right *)
					off_dl := rowWidthState - 1;		(* Down left *)
					off_dr := rowWidthState + 1;		(* Down right *)

					i := 0;
					(* Loop on rows *)
					WHILE i < cblkInfo.height DO
						(* We have to check if there are enough rows to scan an entire stripe or just a truncated one *)
						IF ENTROPY_STRIPE_HEIGHT > (cblkInfo.height - i) THEN
							stripeHeight := cblkInfo.height - i;
						ELSE
							stripeHeight := ENTROPY_STRIPE_HEIGHT;
						END;

						FOR j := 0 TO cblkInfo.width - 1 DO
							stateIdx := rowStartState + j;
							dataIdx := rowStartData + j;
							curState := state[stateIdx];

							(* Scan 1st row *)
							IF	(curState * STATE_SIG_R1 = {})
								& (curState * STATE_VECT_MASK_R1 # {})
							THEN
								(* Did the coefficient just become significant? If not, move on *)
								IF dbr.NextBit() = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									sign := dbr.NextBit();

									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
									IF ~vertCausal THEN
										(* Upper diagonal neighbors *)
										(* Only update previous stripe if not in vertical causal mode *)
										state[stateIdx + off_ul] := state[stateIdx + off_ul] + STATE_D_DR_R2;
										state[stateIdx + off_ur] := state[stateIdx + off_ur] + STATE_D_DL_R2;
									END;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R1 + STATE_VISITED_R1
													+ STATE_V_U_R2 + STATE_V_U_SIGN_R2;

										IF ~vertCausal THEN
											(* Only update previous stripe if not in vertical causal mode *)
											state [stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																		+ STATE_V_D_R2
																		+ STATE_V_D_SIGN_R2;
										END;

										state [stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_H_R_SIGN_R1
															+ STATE_D_UR_R2;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_H_L_SIGN_R1
															+ STATE_D_UL_R2;

									ELSE
										curState := curState
													+ STATE_SIG_R1 + STATE_VISITED_R1
													+ STATE_V_U_R2;

										IF ~vertCausal THEN
											(* Only update previous stripe if not in vertical causal mode *)
											state [stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																		+ STATE_V_D_R2;
										END;

										state [stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_D_UR_R2;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_D_UL_R2;

									END;
								ELSE
									curState := curState + STATE_VISITED_R1;
								END;

								state[stateIdx] := curState;
							END;

							(* Scan 2nd row *)
							INC(dataIdx, scanw);

							IF	(stripeHeight > 1)
								& (curState * STATE_SIG_R2 = {})
								& (curState * STATE_VECT_MASK_R2 # {})
							THEN
								(* Did the coefficient just become significant? If not, move on *)
								IF dbr.NextBit() = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									sign := dbr.NextBit();

									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
									(* Lower diagonal neighbors *)
									state[stateIdx + off_dl] := state[stateIdx + off_dl] + STATE_D_UR_R1;
									state[stateIdx + off_dr] := state[stateIdx + off_dr] + STATE_D_UL_R1;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R2 + STATE_VISITED_R2
													+ STATE_V_D_R1 + STATE_V_D_SIGN_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																	+ STATE_V_U_R1
																	+ STATE_V_U_SIGN_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_H_R_SIGN_R2
															+ STATE_D_DR_R1;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_H_L_SIGN_R2
															+ STATE_D_DL_R1;

									ELSE
										curState := curState
													+ STATE_SIG_R2 + STATE_VISITED_R2
													+ STATE_V_D_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																		+ STATE_V_U_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_D_DR_R1;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_D_DL_R1;

									END;
								ELSE
									curState := curState + STATE_VISITED_R2;
								END;

								state[stateIdx] := curState;
							END;

							(* Scan 3rd row *)
							INC(stateIdx, rowWidthState);
							INC(dataIdx, scanw);
							curState := state[stateIdx];

							IF	(stripeHeight > 2)
								& (curState * STATE_SIG_R1 = {})
								& (curState * STATE_VECT_MASK_R1 # {})
							THEN
								(* Did the coefficient just become significant? If not, move on *)
								IF dbr.NextBit() = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									sign := dbr.NextBit();

									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
									(* Upper diagonal neighbors *)
									state[stateIdx + off_ul] := state[stateIdx + off_ul] + STATE_D_DR_R2;
									state[stateIdx + off_ur] := state[stateIdx + off_ur] + STATE_D_DL_R2;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R1 + STATE_VISITED_R1
													+ STATE_V_U_R2 + STATE_V_U_SIGN_R2;

										state[stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																	+ STATE_V_D_R2
																	+ STATE_V_D_SIGN_R2;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_H_R_SIGN_R1
															+ STATE_D_UR_R2;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_H_L_SIGN_R1
															+ STATE_D_UL_R2;

									ELSE
										curState := curState
													+ STATE_SIG_R1 + STATE_VISITED_R1
													+ STATE_V_U_R2;

										state [stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																	+ STATE_V_D_R2;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_D_UR_R2;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_D_UL_R2;

									END;
								ELSE
									curState := curState + STATE_VISITED_R1;
								END;

								state[stateIdx] := curState;
							END;

							(* Scan 4th row *)
							INC(dataIdx, scanw);

							IF	(stripeHeight > 3)
								& (curState * STATE_SIG_R2 = {})
								& (curState * STATE_VECT_MASK_R2 # {})
							THEN
								(* Did the coefficient just become significant? If not, move on *)
								IF dbr.NextBit() = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									sign := dbr.NextBit();

									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
									(* Lower diagonal neighbors *)
									state[stateIdx + off_dl] := state[stateIdx + off_dl] + STATE_D_UR_R1;
									state[stateIdx + off_dr] := state[stateIdx + off_dr] + STATE_D_UL_R1;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R2 + STATE_VISITED_R2
													+ STATE_V_D_R1 + STATE_V_D_SIGN_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																	+ STATE_V_U_R1
																	+ STATE_V_U_SIGN_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_H_R_SIGN_R2
															+ STATE_D_DR_R1;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_H_L_SIGN_R2
															+ STATE_D_DL_R1;

									ELSE
										curState := curState
													+ STATE_SIG_R2 + STATE_VISITED_R2
													+ STATE_V_D_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																		+ STATE_V_U_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_D_DR_R1;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_D_DL_R1;

									END;
								ELSE
									curState := curState + STATE_VISITED_R2;
								END;

								state[stateIdx] := curState;
							END;
						END;

						(* Move to next row of stripes *)
						INC(i, ENTROPY_STRIPE_HEIGHT);
						(* Compute row start of next row *)
						rowStartState := rowStartState + stateStripeIncr;
						rowStartData := rowStartData + dataStripeIncr;
					END;

					(* Try to detect error *)
					IF term THEN
						ok := dbr.CheckBytePadding();
					ELSE
						ok := TRUE;
					END;

					RETURN ok;
			END RawSigPropPass;

			(* This procedure applies the magnitude refinement pass to the compressed image data *)
			PROCEDURE MagRefPass (cblk : DataBlk; cblkInfo : J2KU.CblkInfo; curBp : LONGINT; term : BOOLEAN) : BOOLEAN;
				VAR
					i, j : LONGINT;
					stripeHeight : LONGINT;
					dataIdx, stateIdx : LONGINT;
					curState : SET;
					rowStartState, rowWidthState, rowStartData : LONGINT;
					stateStripeIncr, dataStripeIncr : LONGINT;
					bit : LONGINT;
					tmpDataSample : SET;
					setMask, resetMask : SET;
					ok : BOOLEAN;
					data : J2KU.LongIntArrayPtr;
					scanw : LONGINT;	(* The scan width of the code-block data *)
					off_ul, off_ur, off_dl, off_dr : LONGINT;
				BEGIN
					(* Get local reference to data *)
					data := cblk(DataBlkInt).data;

					setMask := SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), curBp - 1));
					resetMask := SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, -1), curBp + 1));

					rowWidthState := cblkInfo.width + 2 * ENTROPY_ARRAYOFF;
					(* Cache rowStart (of the extended arrays) *)
					rowStartState := rowWidthState + ENTROPY_ARRAYOFF;
					scanw := cblk.scanw;
					rowStartData := cblk.offset;
					stateStripeIncr := (ENTROPY_STRIPE_HEIGHT DIV 2)*rowWidthState;
					dataStripeIncr := ENTROPY_STRIPE_HEIGHT*scanw;

					(* Offsets for diagonal neighbors *)
					off_ul := -rowWidthState - 1;	(* Up left *)
					off_ur := -rowWidthState + 1;	(* Up right *)
					off_dl := rowWidthState - 1;		(* Down left *)
					off_dr := rowWidthState + 1;		(* Down right *)

					i := 0;
					(* Loop on rows *)
					WHILE i < cblkInfo.height DO
						(* We have to check if there are enough rows to scan an entire stripe or just a truncated one *)
						IF ENTROPY_STRIPE_HEIGHT > (cblkInfo.height - i) THEN
							stripeHeight := cblkInfo.height - i;
						ELSE
							stripeHeight := ENTROPY_STRIPE_HEIGHT;
						END;

						FOR j := 0 TO cblkInfo.width - 1 DO
							stateIdx := rowStartState + j;
							dataIdx := rowStartData + j;
							curState := state[stateIdx];

							(* Scan 1st row *)
							IF	((curState * STATE_SIG_R1) = STATE_SIG_R1)
								& ((curState * STATE_VISITED_R1) = {})
							THEN
								IF (curState * STATE_MAGREF_R1) = STATE_MAGREF_R1 THEN
									bit := mq.Decode(ENTROPY_MR_CTX);
								ELSE (* First time in magnitude refinement pass *)
									IF (curState * STATE_VECT_MASK_R1) = {} THEN
										(* No neighbor significant *)
										bit := mq.Decode(ENTROPY_MR_FIRSTZ_CTX);
									ELSE
										bit := mq.Decode(ENTROPY_MR_FIRSTNZ_CTX);
									END;

									(* Mark the coefficient as being in the magnitude refinement pass *)
									state[stateIdx] := curState + STATE_MAGREF_R1;
									curState := curState + STATE_MAGREF_R1;

								END;

								tmpDataSample := SYSTEM.VAL(SET, data[dataIdx]) * resetMask;
								data[dataIdx] := SYSTEM.VAL(LONGINT, tmpDataSample + SYSTEM.VAL(SET, LSH(bit, curBp)) + setMask);
							END;

							(* Scan 2nd row *)
							INC(dataIdx, scanw);

							IF	(stripeHeight > 1)
								& (curState * STATE_SIG_R2 = STATE_SIG_R2)
								& (curState * STATE_VISITED_R2 = {})
							THEN
								IF (curState * STATE_MAGREF_R2) = STATE_MAGREF_R2 THEN
									bit := mq.Decode(ENTROPY_MR_CTX);
								ELSE (* First time in magnitude refinement pass *)
									IF curState * STATE_VECT_MASK_R2 = {} THEN
										(* No neighbor significant *)
										bit := mq.Decode(ENTROPY_MR_FIRSTZ_CTX);
									ELSE
										bit := mq.Decode(ENTROPY_MR_FIRSTNZ_CTX);
									END;

									(* Mark the coefficient as being in the magnitude refinement pass *)
									state[stateIdx] := curState + STATE_MAGREF_R2;
								END;

								tmpDataSample := SYSTEM.VAL(SET, data[dataIdx]) * resetMask;
								data[dataIdx] := SYSTEM.VAL(LONGINT, tmpDataSample + SYSTEM.VAL(SET, LSH(bit, curBp)) + setMask);
							END;

							(* Scan 3rd row *)
							INC(stateIdx, rowWidthState);
							INC(dataIdx, scanw);
							curState := state[stateIdx];

							IF	(stripeHeight > 2)
								& (curState * STATE_SIG_R1 = STATE_SIG_R1)
								& (curState * STATE_VISITED_R1 = {})
							THEN
								IF (curState * STATE_MAGREF_R1) = STATE_MAGREF_R1 THEN
									bit := mq.Decode(ENTROPY_MR_CTX);
								ELSE (* First time in magnitude refinement pass *)
									IF curState * STATE_VECT_MASK_R1 = {} THEN
										(* No neighbor significant *)
										bit := mq.Decode(ENTROPY_MR_FIRSTZ_CTX);
									ELSE
										bit := mq.Decode(ENTROPY_MR_FIRSTNZ_CTX);
									END;

									(* Mark the coefficient as being in the magnitude refinement pass *)
									state[stateIdx] := curState + STATE_MAGREF_R1;
									curState := curState + STATE_MAGREF_R1;
								END;

								tmpDataSample := SYSTEM.VAL(SET, data[dataIdx]) * resetMask;
								data[dataIdx] := SYSTEM.VAL(LONGINT, tmpDataSample + SYSTEM.VAL(SET, LSH(bit, curBp)) + setMask);
							END;

							(* Scan 4th row *)
							INC(dataIdx, scanw);

							IF	(stripeHeight > 3)
								& (curState * STATE_SIG_R2 = STATE_SIG_R2)
								& (curState * STATE_VISITED_R2 = {})
							THEN
								IF (curState * STATE_MAGREF_R2) = STATE_MAGREF_R2 THEN
									bit := mq.Decode(ENTROPY_MR_CTX);
								ELSE (* First time in magnitude refinement pass *)
									IF curState * STATE_VECT_MASK_R2 = {} THEN
										(* No neighbor significant *)
										bit := mq.Decode(ENTROPY_MR_FIRSTZ_CTX);
									ELSE
										bit := mq.Decode(ENTROPY_MR_FIRSTNZ_CTX);
									END;

									(* Mark the coefficient as being in the magnitude refinement pass *)
									state[stateIdx] := curState + STATE_MAGREF_R2;
								END;

								tmpDataSample := SYSTEM.VAL(SET, data[dataIdx]) * resetMask;
								data[dataIdx] := SYSTEM.VAL(LONGINT, tmpDataSample + SYSTEM.VAL(SET, LSH(bit, curBp)) + setMask);
							END;

						END;

						(* Move to next row of stripes *)
						INC(i, ENTROPY_STRIPE_HEIGHT);
						(* Compute row start of next row *)
						rowStartState := rowStartState + stateStripeIncr;
						rowStartData := rowStartData + dataStripeIncr;
					END;

					(* We may do an error check if predictable termination is used *)
					IF predTerm & term THEN
						ok := mq.CheckPredTerm();
					ELSE
						ok := TRUE;
					END;

					(* Maybe need to reset contexts *)
					IF resetCtx THEN
						mq.ResetContexts();
					END;

					RETURN ok;
			END MagRefPass;


			(*
				This procedure applies the magnitude refinement pass to the compressed image data,
				reading directly from the stream
			*)
			PROCEDURE RawMagRefPass (cblk : DataBlk; cblkInfo : J2KU.CblkInfo; curBp : LONGINT; term : BOOLEAN) : BOOLEAN;
				VAR
					i, j : LONGINT;
					stripeHeight : LONGINT;
					dataIdx, stateIdx : LONGINT;
					curState : SET;
					rowStartState, rowWidthState, rowStartData : LONGINT;
					stateStripeIncr, dataStripeIncr : LONGINT;
					bit : LONGINT;
					tmpDataSample : SET;
					setMask, resetMask : SET;
					ok : BOOLEAN;
					data : J2KU.LongIntArrayPtr;
					scanw : LONGINT;	(* The scan width of the code-block data *)
					off_ul, off_ur, off_dl, off_dr : LONGINT;
				BEGIN
					(* Get local reference to data *)
					data := cblk(DataBlkInt).data;

					setMask := SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), curBp - 1));
					resetMask := SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, -1), curBp + 1));

					rowWidthState := cblkInfo.width + 2 * ENTROPY_ARRAYOFF;
					(* Cache rowStart (of the extended arrays) *)
					rowStartState := rowWidthState + ENTROPY_ARRAYOFF;
					scanw := cblk.scanw;
					rowStartData := cblk.offset;
					stateStripeIncr := (ENTROPY_STRIPE_HEIGHT DIV 2)*rowWidthState;
					dataStripeIncr := ENTROPY_STRIPE_HEIGHT*scanw;

					(* Offsets for diagonal neighbors *)
					off_ul := -rowWidthState - 1;	(* Up left *)
					off_ur := -rowWidthState + 1;	(* Up right *)
					off_dl := rowWidthState - 1;		(* Down left *)
					off_dr := rowWidthState + 1;		(* Down right *)

					i := 0;
					(* Loop on rows *)
					WHILE i < cblkInfo.height DO
						(* We have to check if there are enough rows to scan an entire stripe or just a truncated one *)
						IF ENTROPY_STRIPE_HEIGHT > (cblkInfo.height - i) THEN
							stripeHeight := cblkInfo.height - i;
						ELSE
							stripeHeight := ENTROPY_STRIPE_HEIGHT;
						END;

						FOR j := 0 TO cblkInfo.width - 1 DO
							stateIdx := rowStartState + j;
							dataIdx := rowStartData + j;
							curState := state[stateIdx];

							(* Scan 1st row *)
							IF	(curState * STATE_SIG_R1 = STATE_SIG_R1)
								& (curState * STATE_VISITED_R1 = {})
							THEN
								bit := dbr.NextBit();
								tmpDataSample := SYSTEM.VAL(SET, data[dataIdx]) * resetMask;
								data[dataIdx] := SYSTEM.VAL(LONGINT, tmpDataSample + SYSTEM.VAL(SET, LSH(bit, curBp)) + setMask);
								(* No need to set IN_MAG_REF since all magnitude refinement passes to follow are "raw" *)
							END;

							(* Scan 2nd row *)
							INC(dataIdx, scanw);

							IF	(stripeHeight > 1)
								& (curState * STATE_SIG_R2 = STATE_SIG_R2)
								& (curState * STATE_VISITED_R2 = {})
							THEN
								bit := dbr.NextBit();
								tmpDataSample := SYSTEM.VAL(SET, data[dataIdx]) * resetMask;
								data[dataIdx] := SYSTEM.VAL(LONGINT, tmpDataSample + SYSTEM.VAL(SET, LSH(bit, curBp)) + setMask);
								(* No need to set IN_MAG_REF since all magnitude refinement passes to follow are "raw" *)
							END;

							(* Scan 3rd row *)
							INC(stateIdx, rowWidthState);
							INC(dataIdx, scanw);
							curState := state[stateIdx];

							IF	(stripeHeight > 2)
								& (curState * STATE_SIG_R1 = STATE_SIG_R1)
								& (curState * STATE_VISITED_R1 = {})
							THEN
								bit := dbr.NextBit();
								tmpDataSample := SYSTEM.VAL(SET, data[dataIdx]) * resetMask;
								data[dataIdx] := SYSTEM.VAL(LONGINT, tmpDataSample + SYSTEM.VAL(SET, LSH(bit, curBp)) + setMask);
								(* No need to set IN_MAG_REF since all magnitude refinement passes to follow are "raw" *)
							END;

							(* Scan 4th row *)
							INC(dataIdx, scanw);

							IF	(stripeHeight > 3)
								& (curState * STATE_SIG_R2 = STATE_SIG_R2)
								& (curState * STATE_VISITED_R2 = {})
							THEN
								bit := dbr.NextBit();
								tmpDataSample := SYSTEM.VAL(SET, data[dataIdx]) * resetMask;
								data[dataIdx] := SYSTEM.VAL(LONGINT, tmpDataSample + SYSTEM.VAL(SET, LSH(bit, curBp)) + setMask);
							END;
						END;

						(* Move to next row of stripes *)
						INC(i, ENTROPY_STRIPE_HEIGHT);
						(* Compute row start of next row *)
						rowStartState := rowStartState + stateStripeIncr;
						rowStartData := rowStartData + dataStripeIncr;
					END;

					(* Try to detect error *)
					IF term THEN
						ok := dbr.CheckBytePadding();
					ELSE
						ok := TRUE;
					END;

					RETURN ok;
			END RawMagRefPass;



			(* This procedure applies the cleanup pass to the compressed image data *)
			PROCEDURE CleanupPass (cblk : DataBlk; cblkInfo : J2KU.CblkInfo; curBp : LONGINT; zeroLUT : J2KU.LongIntArrayPtr; term : BOOLEAN) : BOOLEAN;
				VAR
					sign, symbol : LONGINT;	(* The symbol returned by the MQ-decoder *)
					dataIdx, stateIdx, tmpDataIdx, tmpStateIdx : LONGINT;
					stripeStartIdx : LONGINT;
					curState, tmpCurState : SET;
					rowStartState, rowWidthState, rowStartData : LONGINT;
					stateStripeIncr, dataStripeIncr : LONGINT;
					stripeHeight : LONGINT;
					i, j : LONGINT;
					ctx : LONGINT;
					setMask : SET;
					ok : BOOLEAN;
					data : J2KU.LongIntArrayPtr;
					scanw : LONGINT;	(* The scan width of the code-block data *)
					off_ul, off_ur, off_dl, off_dr : LONGINT;
				BEGIN
					(* Get local reference to data *)
					data := cblk(DataBlkInt).data;

					setMask := SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 3), curBp - 1));
					rowWidthState := cblkInfo.width + 2 * ENTROPY_ARRAYOFF;
					(* Cache row start *)
					rowStartState := rowWidthState + ENTROPY_ARRAYOFF;
					scanw := cblk.scanw;
					rowStartData := cblk.offset;
					stateStripeIncr := (ENTROPY_STRIPE_HEIGHT DIV 2)*rowWidthState;
					dataStripeIncr := ENTROPY_STRIPE_HEIGHT*scanw;

					(* Offsets for diagonal neighbors *)
					off_ul := -rowWidthState - 1;	(* Up left *)
					off_ur := -rowWidthState + 1;	(* Up right *)
					off_dl := rowWidthState - 1;		(* Down left *)
					off_dr := rowWidthState + 1;		(* Down right *)

					i := 0;
					(* Loop on rows *)
					WHILE i < cblkInfo.height DO
						(* We have to check if there are enough rows to scan an entire stripe or just a truncated one *)
						IF ENTROPY_STRIPE_HEIGHT > (cblkInfo.height - i) THEN
							stripeHeight := cblkInfo.height - i;
						ELSE
							stripeHeight := ENTROPY_STRIPE_HEIGHT;
						END;

						FOR j := 0 TO cblkInfo.width - 1 DO
							stateIdx := rowStartState + j;
							dataIdx := rowStartData + j;
							curState := state[stateIdx];

							(*
								Check for RLC: if all samples are not significant, not visited and do have
								a zero context, and colum is full height, we do RLC
							*)
							IF	(stripeHeight = ENTROPY_STRIPE_HEIGHT)
								& ((curState = {}) & (state[stateIdx + rowWidthState] = {}))
							THEN

								IF mq.Decode(ENTROPY_RUNCTX) = 1 THEN
									(* Not all four bits of the coefficients of this stripe are 0 *)
									(* Determine first non-zero coefficient bit *)
									stripeStartIdx := mq.Decode(ENTROPY_UNICTX);
									stripeStartIdx := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(stripeStartIdx, 1)) + SYSTEM.VAL(SET, mq.Decode(ENTROPY_UNICTX)));

									(* Handle the first non-zero coefficient separately *)
									IF stripeStartIdx > 1 THEN
										tmpStateIdx := stateIdx + rowWidthState;
									ELSE
										tmpStateIdx := stateIdx;
									END;

									tmpDataIdx := dataIdx + scanw*stripeStartIdx;
									tmpCurState := state[tmpStateIdx];

									(* See if the first non-zero coefficient is in top or bottom part of stripe *)
									IF ~ODD(stripeStartIdx) THEN
										(* Coefficient has become significant -> decode sign bit *)
										ctx := ENTROPY_SIGN_LUT[LSH(SYSTEM.VAL(LONGINT, tmpCurState*SIGN_VECT_MASK_R1), -SIGN_VECT_SHIFT_R1)];

										sign := SYSTEM.VAL(LONGINT,
													SYSTEM.VAL(SET, mq.Decode(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ctx) * SIGN_LUT_MASK)))
													/ SYSTEM.VAL(SET, LSH(ctx, -J2KU.LONGINT_BITS + 1))
												);

										data[tmpDataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

										(* Update state information*)
										IF (stripeStartIdx # 0) OR ~vertCausal THEN
											(* Upper diagonal neighbors *)
											(* Only update previous stripe if not in vertical causal mode *)
											state[tmpStateIdx + off_ul] := state[tmpStateIdx + off_ul] + STATE_D_DR_R2;
											state[tmpStateIdx + off_ur] := state[tmpStateIdx + off_ur] + STATE_D_DL_R2;
										END;

										(* Update rest of neighbors, depending on sign *)
										IF sign # 0 THEN
											tmpCurState := tmpCurState
														+ STATE_SIG_R1
														+ STATE_V_U_R2 + STATE_V_U_SIGN_R2;

											IF (stripeStartIdx # 0) OR ~vertCausal THEN
												(* Only update previous stripe if not in vertical causal mode *)
												state [tmpStateIdx - rowWidthState] := state[tmpStateIdx - rowWidthState]
																			+ STATE_V_D_R2
																			+ STATE_V_D_SIGN_R2;
											END;

											state [tmpStateIdx - 1] := state[tmpStateIdx - 1]
																+ STATE_H_R_R1
																+ STATE_H_R_SIGN_R1
																+ STATE_D_UR_R2;

											state [tmpStateIdx + 1] := state[tmpStateIdx + 1]
																+ STATE_H_L_R1
																+ STATE_H_L_SIGN_R1
																+ STATE_D_UL_R2;
										ELSE
											tmpCurState := tmpCurState
														+ STATE_SIG_R1
														+ STATE_V_U_R2;

											IF (stripeStartIdx # 0) OR ~vertCausal THEN
												(* Only update previous stripe if not in vertical causal mode *)
												state [tmpStateIdx - rowWidthState] := state[tmpStateIdx - rowWidthState]
																			+ STATE_V_D_R2;
											END;

											state [tmpStateIdx - 1] := state[tmpStateIdx - 1]
																+ STATE_H_R_R1
																+ STATE_D_UR_R2;

											state [tmpStateIdx + 1] := state[tmpStateIdx + 1]
																+ STATE_H_L_R1
																+ STATE_D_UL_R2;
										END;

									ELSE
										(* Coefficient has become significant -> decode sign bit *)
										ctx := ENTROPY_SIGN_LUT[LSH(SYSTEM.VAL(LONGINT, tmpCurState*SIGN_VECT_MASK_R2), -SIGN_VECT_SHIFT_R2)];
										sign := SYSTEM.VAL(LONGINT,
													SYSTEM.VAL(SET, mq.Decode(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ctx) * SIGN_LUT_MASK)))
													/ SYSTEM.VAL(SET, LSH(ctx, -J2KU.LONGINT_BITS + 1))
												);

										data[tmpDataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

										(* Update state information*)
										(* Lower diagonal neighbors *)
										state[tmpStateIdx + off_dl] := state[tmpStateIdx + off_dl] + STATE_D_UR_R1;
										state[tmpStateIdx + off_dr] := state[tmpStateIdx + off_dr] + STATE_D_UL_R1;

										(* Update rest of neighbors, depending on sign *)
										IF sign # 0 THEN
											tmpCurState := tmpCurState
														+ STATE_SIG_R2
														+ STATE_V_D_R1 + STATE_V_D_SIGN_R1;

											state[tmpStateIdx + rowWidthState] := state[tmpStateIdx + rowWidthState]
																		+ STATE_V_U_R1
																		+ STATE_V_U_SIGN_R1;

											state[tmpStateIdx - 1] := state[tmpStateIdx - 1]
																+ STATE_H_R_R2
																+ STATE_H_R_SIGN_R2
																+ STATE_D_DR_R1;

											state[tmpStateIdx + 1] := state[tmpStateIdx + 1]
																+ STATE_H_L_R2
																+ STATE_H_L_SIGN_R2
																+ STATE_D_DL_R1;

										ELSE
											tmpCurState := tmpCurState
														+ STATE_SIG_R2
														+ STATE_V_D_R1;

											state[tmpStateIdx + rowWidthState] := state[tmpStateIdx + rowWidthState]
																			+ STATE_V_U_R1;

											state[tmpStateIdx - 1] := state[tmpStateIdx - 1]
																+ STATE_H_R_R2
																+ STATE_D_DR_R1;

											state [tmpStateIdx + 1] := state[tmpStateIdx + 1]
																+ STATE_H_L_R2
																+ STATE_D_DL_R1;
										END;
									END;

									(* Save state *)
									state[tmpStateIdx] := tmpCurState;
								ELSE
									(* Ensure that we skip all coefficients *)
									stripeStartIdx := ENTROPY_STRIPE_HEIGHT;
								END;

							ELSE
								stripeStartIdx := -1;
							END;


							(* Scan 1st row *)
							curState := state[stateIdx];

							IF	(stripeStartIdx < 0)
								& (curState * STATE_SIG_R1 = {})
								& (curState * STATE_VISITED_R1 = {})
							THEN

								(* Did the coefficient just become significant? If not, move on *)
								IF mq.Decode(zeroLUT[SYSTEM.VAL(LONGINT, curState * STATE_VECT_MASK_R1)]) = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									ctx := ENTROPY_SIGN_LUT[LSH(SYSTEM.VAL(LONGINT, curState*SIGN_VECT_MASK_R1), -SIGN_VECT_SHIFT_R1)];


									sign := SYSTEM.VAL(LONGINT,
												SYSTEM.VAL(SET, mq.Decode(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ctx) * SIGN_LUT_MASK)))
												/ SYSTEM.VAL(SET, LSH(ctx, -J2KU.LONGINT_BITS + 1))
											);

									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
									IF ~vertCausal THEN
										(* Upper diagonal neighbors *)
										(* Only update previous stripe if not in vertical causal mode *)
										state[stateIdx + off_ul] := state[stateIdx + off_ul] + STATE_D_DR_R2;
										state[stateIdx + off_ur] := state[stateIdx + off_ur] + STATE_D_DL_R2;
									END;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R1
													+ STATE_V_U_R2 + STATE_V_U_SIGN_R2;

										IF ~vertCausal THEN
											(* Only update previous stripe if not in vertical causal mode *)
											state [stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																		+ STATE_V_D_R2
																		+ STATE_V_D_SIGN_R2;
										END;

										state [stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_H_R_SIGN_R1
															+ STATE_D_UR_R2;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_H_L_SIGN_R1
															+ STATE_D_UL_R2;

									ELSE
										curState := curState
													+ STATE_SIG_R1
													+ STATE_V_U_R2;

										IF ~vertCausal THEN
											(* Only update previous stripe if not in vertical causal mode *)
											state [stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																		+ STATE_V_D_R2;
										END;

										state [stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_D_UR_R2;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_D_UL_R2;
									END;

								END;
							END;

							(* Scan 2nd row *)
							INC(dataIdx, scanw);

							IF	(stripeStartIdx < 1)
								& (stripeHeight > 1)
								& (curState * STATE_SIG_R2 = {})
								& (curState * STATE_VISITED_R2 = {})
							THEN

								(* Did the coefficient just become significant? If not, move on *)
								IF mq.Decode(zeroLUT[LSH(SYSTEM.VAL(LONGINT, curState * STATE_VECT_MASK_R2), -STATE_SEP)]) = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									ctx := ENTROPY_SIGN_LUT[LSH(SYSTEM.VAL(LONGINT, curState*SIGN_VECT_MASK_R2), -SIGN_VECT_SHIFT_R2)];
									sign := SYSTEM.VAL(LONGINT,
												SYSTEM.VAL(SET, mq.Decode(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ctx) * SIGN_LUT_MASK)))
												/ SYSTEM.VAL(SET, LSH(ctx, -J2KU.LONGINT_BITS + 1))
											);

									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
									(* Lower diagonal neighbors *)
									state[stateIdx + off_dl] := state[stateIdx + off_dl] + STATE_D_UR_R1;
									state[stateIdx + off_dr] := state[stateIdx + off_dr] + STATE_D_UL_R1;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R2
													+ STATE_V_D_R1 + STATE_V_D_SIGN_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																	+ STATE_V_U_R1
																	+ STATE_V_U_SIGN_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_H_R_SIGN_R2
															+ STATE_D_DR_R1;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_H_L_SIGN_R2
															+ STATE_D_DL_R1;

									ELSE
										curState := curState
													+ STATE_SIG_R2
													+ STATE_V_D_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																		+ STATE_V_U_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_D_DR_R1;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_D_DL_R1;

									END;
								END;
							END;

							(* Set coefficients back to not visited *)
							state[stateIdx] := curState * (-(STATE_VISITED_R1 + STATE_VISITED_R2));

							(* Scan 3rd row *)
							INC(stateIdx, rowWidthState);
							INC(dataIdx, scanw);
							curState := state[stateIdx];

							IF	(stripeStartIdx < 2)
								& (stripeHeight > 2)
								& (curState * STATE_SIG_R1 = {})
								& (curState * STATE_VISITED_R1 = {})
							THEN

								(* Did the coefficient just become significant? If not, move on *)
								IF mq.Decode(zeroLUT[SYSTEM.VAL(LONGINT, curState * STATE_VECT_MASK_R1)]) = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									ctx := ENTROPY_SIGN_LUT[LSH(SYSTEM.VAL(LONGINT, curState*SIGN_VECT_MASK_R1), -SIGN_VECT_SHIFT_R1)];
									sign := SYSTEM.VAL(LONGINT,
												SYSTEM.VAL(SET, mq.Decode(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ctx) * SIGN_LUT_MASK)))
												/ SYSTEM.VAL(SET, LSH(ctx, -J2KU.LONGINT_BITS + 1))
											);

									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
									(* Upper diagonal neighbors *)
									state[stateIdx + off_ul] := state[stateIdx + off_ul] + STATE_D_DR_R2;
									state[stateIdx + off_ur] := state[stateIdx + off_ur] + STATE_D_DL_R2;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R1
													+ STATE_V_U_R2 + STATE_V_U_SIGN_R2;

										state[stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																	+ STATE_V_D_R2
																	+ STATE_V_D_SIGN_R2;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_H_R_SIGN_R1
															+ STATE_D_UR_R2;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_H_L_SIGN_R1
															+ STATE_D_UL_R2;

									ELSE
										curState := curState
													+ STATE_SIG_R1
													+ STATE_V_U_R2;

										state [stateIdx - rowWidthState] := state[stateIdx - rowWidthState]
																	+ STATE_V_D_R2;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R1
															+ STATE_D_UR_R2;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R1
															+ STATE_D_UL_R2;

									END;
								END;
							END;

							(* Scan 4th row *)
							INC(dataIdx, scanw);

							IF	(stripeStartIdx < 3)
								& (stripeHeight > 3)
								& (curState * STATE_SIG_R2 = {})
								& (curState * STATE_VISITED_R2 = {})
							THEN
								(* Did the coefficient just become significant? If not, move on *)
								IF mq.Decode(zeroLUT[LSH(SYSTEM.VAL(LONGINT, curState * STATE_VECT_MASK_R2), -STATE_SEP)]) = 1 THEN
									(* Coefficient has become significant -> decode sign bit *)
									ctx := ENTROPY_SIGN_LUT[LSH(SYSTEM.VAL(LONGINT, curState*SIGN_VECT_MASK_R2), -SIGN_VECT_SHIFT_R2)];
									sign := SYSTEM.VAL(LONGINT,
												SYSTEM.VAL(SET, mq.Decode(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ctx) * SIGN_LUT_MASK)))
												/ SYSTEM.VAL(SET, LSH(ctx, -J2KU.LONGINT_BITS + 1))
											);

									data[dataIdx] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(sign, J2KU.LONGINT_BITS - 1)) + setMask);

									(* Update state information*)
									(* Lower diagonal neighbors *)
									state[stateIdx + off_dl] := state[stateIdx + off_dl] + STATE_D_UR_R1;
									state[stateIdx + off_dr] := state[stateIdx + off_dr] + STATE_D_UL_R1;

									(* Update rest of neighbors, depending on sign *)
									IF sign # 0 THEN
										curState := curState
													+ STATE_SIG_R2
													+ STATE_V_D_R1 + STATE_V_D_SIGN_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																	+ STATE_V_U_R1
																	+ STATE_V_U_SIGN_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_H_R_SIGN_R2
															+ STATE_D_DR_R1;

										state[stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_H_L_SIGN_R2
															+ STATE_D_DL_R1;

									ELSE
										curState := curState
													+ STATE_SIG_R2
													+ STATE_V_D_R1;

										state[stateIdx + rowWidthState] := state[stateIdx + rowWidthState]
																		+ STATE_V_U_R1;

										state[stateIdx - 1] := state[stateIdx - 1]
															+ STATE_H_R_R2
															+ STATE_D_DR_R1;

										state [stateIdx + 1] := state[stateIdx + 1]
															+ STATE_H_L_R2
															+ STATE_D_DL_R1;

									END;

									state[stateIdx] := curState;
								END;
							END;

							(* Set coefficients back to not visited *)
							state[stateIdx] := curState * (-(STATE_VISITED_R1 + STATE_VISITED_R2));
						END;

						(* Move to next row of stripes *)
						INC(i, ENTROPY_STRIPE_HEIGHT);
						(* Compute row start of next row *)
						rowStartState := rowStartState + stateStripeIncr;
						rowStartData := rowStartData + dataStripeIncr;
					END;

					(* Check if segmentation symbols are used *)
					IF segUsed THEN
						(* Assemble 4 bits *)
						symbol := SYSTEM.VAL(LONGINT,
											SYSTEM.VAL(SET, LSH(mq.Decode(ENTROPY_UNICTX), 3))
											+ SYSTEM.VAL(SET, LSH(mq.Decode(ENTROPY_UNICTX), 2))
											+ SYSTEM.VAL(SET, LSH(mq.Decode(ENTROPY_UNICTX), 1))
											+ SYSTEM.VAL(SET, mq.Decode(ENTROPY_UNICTX))
								);
						(* The segmentation symbol is 1010 (or 0xA) *)
						IF symbol # ENTROPY_SEG_MARKER THEN
							RETURN FALSE;
						END;
					END;

					(* We may do an error check if predictable termination is used *)
					IF predTerm & term THEN
						ok := mq.CheckPredTerm();
					ELSE
						ok := TRUE;
					END;

					(* Maybe need to reset contexts *)
					IF resetCtx THEN
						mq.ResetContexts();
					END;

					RETURN ok;
			END CleanupPass;

			(* Conceals a detected error *)
			PROCEDURE Conceal (dataBlk : DataBlk; cblkInfo : J2KU.CblkInfo; bp : LONGINT);
				VAR
					value, setmask, resetmask, mbmask, i, j, rowStart : LONGINT;
					data : J2KU.LongIntArrayPtr;
					scanw : LONGINT;
				BEGIN
					data := dataBlk(DataBlkInt).data;
					scanw := dataBlk.scanw;

					setmask := LSH(1, bp);
					resetmask := LSH(-1, bp);
					(* Mask to extract magnitude bits, without sign bit *)
					mbmask := SYSTEM.VAL(LONGINT, J2KU.LONGINT_SIGN_BIT / SYSTEM.VAL(SET, resetmask));

					(* We need to restore the state before the bit-plane where the error happened *)
					(* Visit each sample and apply the reset mask to it and add a 1/2 approximation if significant *)
					FOR i := 0 TO cblkInfo.height - 1 DO
						rowStart := i*scanw;

						FOR j := 0 TO cblkInfo.width - 1 DO
							value := data[rowStart + j];

							IF SYSTEM.VAL(SET, value) * SYSTEM.VAL(SET, mbmask) # {} THEN
								(*
									Something was decoded in previous bit-planes -> set the approximation
									for the previous bit-plane
								*)
								data[rowStart + j] := SYSTEM.VAL(LONGINT,
																	(SYSTEM.VAL(SET, value)
																	* SYSTEM.VAL(SET, resetmask))
																	+ SYSTEM.VAL(SET, setmask)
																);
							ELSE
								(* Was insignificant in previous bit-plane -> set to 0 *)
								data[rowStart + j] := 0;
							END;
						END;
					END;
			END Conceal;


			PROCEDURE FreeNonRebuildResources;
				BEGIN
					cr.FreeNonRebuildResources();
			END FreeNonRebuildResources;

			PROCEDURE FreeResources;
				BEGIN
					state := NIL;
					mq := NIL;
					dbr := NIL;

					cr.FreeResources();
			END FreeResources;

		END EntropyDecoder;

		(* --- END Entropy decoder types --- *)


		(* --- ROI types --- *)

		ROIDescaler = OBJECT
			VAR
				decSpec : J2KCS.DecoderSpecs;
				ed : EntropyDecoder;
				noROI : BOOLEAN;

			PROCEDURE &InitNew *(roiOpt : J2KU.ROIDescalerOptions;
									ed : EntropyDecoder;
									decSpec : J2KCS.DecoderSpecs);
				BEGIN
					ReInit(roiOpt, ed, decSpec);
			END InitNew;

			PROCEDURE ReInit (	roiOpt : J2KU.ROIDescalerOptions;
									ed : EntropyDecoder;
									decSpec : J2KCS.DecoderSpecs);
				BEGIN
					SELF.noROI := roiOpt.noROI;
					SELF.decSpec := decSpec;
					SELF.ed := ed;
			END ReInit;

			(*
				If ROI decoding is needed, the de-scaled code-blocks are returned. Otherwise nothing is done
			*)
			PROCEDURE GetCodeBlocks (VAR cblk : ARRAY OF DataBlk; VAR cblkInfo : ARRAY OF J2KU.CblkInfo; ncblks : LONGINT) : LONGINT;
				VAR
					cblkIdx, ncblksRet : LONGINT;
					data : J2KU.LongIntArrayPtr;
					curTile, comp, magBits, idx, i, j : LONGINT;
					(*
						First mask needed to extract all magnitude bits in the range of maximum magnitude bits as defined in equation E.2 of the standard.
						Second mask needed to extract magnitude bits beyond the range of maximum magnitude bits.
						Third mask is the inverse of the second one. It's kind of the same as the first mask, except that we also extract the sign bit.
					*)
					mask1, mask2, mask3 : SET;
					approx : SET; (* Mask to set the 1/2 approximation bit, if it gets deleted during truncation *)
					tmp : SET;
					shift : LONGINT;
					width, height, scanw : LONGINT;
				BEGIN

					(* Get as many coded code-blocks in the stream as needed, descale them *)
					ncblksRet := ed.GetCodeBlocks(cblk, cblkInfo, ncblks);
					curTile := ed.CurrentTile();

					FOR cblkIdx := 0 TO ncblksRet - 1 DO
						comp := cblkInfo[cblkIdx].subbinfo.component;

						(* If there is no ROI present then don't do anything *)
						IF ~noROI & decSpec.ROIUsed(curTile, comp) THEN
							data := cblk[cblkIdx](DataBlkInt).data;
							idx := cblk[cblkIdx].offset;
							scanw := cblk[cblkIdx].scanw;
							width := cblkInfo[cblkIdx].width;
							height := cblkInfo[cblkIdx].height;

							shift := decSpec.GetROIShift(curTile, comp);
							magBits := cblkInfo[cblkIdx].subbinfo.magbits;

							mask3 := SYSTEM.VAL(SET, LSH(J2KU.SWAP_MASK, (J2KU.LONGINT_BITS - 1)- magBits));
							mask2 := -mask3;
							mask1 := mask3 * (-J2KU.LONGINT_SIGN_BIT);
							approx := SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), (J2KU.LONGINT_BITS - 2) - magBits));

							(* For every coefficient see if it belongs to the background or a ROI *)
							FOR i := 0 TO height - 1 DO
								FOR j := 0 TO width - 1 DO
									tmp := SYSTEM.VAL(SET, data[idx]);

									IF (tmp * mask1) = {} THEN
										(* Background coefficients: All first MSBs are 0 *)
										(* Need to shift the coefficient *)
										data[idx] := SYSTEM.VAL(LONGINT,
														(tmp * J2KU.LONGINT_SIGN_BIT)	(* extract sign *)
														+ SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, tmp), shift)));

									ELSIF (tmp * mask2) # {} THEN
										(* The number of decoded magnitude bits is greater than the maximum number of magnitude bits -> need to truncate & set approximation bit *)
										data[idx] := SYSTEM.VAL(LONGINT, (tmp * mask3) + approx);
									END;
									INC(idx);
								END;

								idx := idx - width + scanw;
							END;
						END;
					END;

					RETURN ncblksRet;
			END GetCodeBlocks;

			(**
				Sets the maximum layer range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested.
				This procedure shall NOT be called after the first code-block data
				has been read.

				maxStartLayer and maxEndLayer are inclusive.
			*)
			PROCEDURE SetMaxLayerRange (maxStartLayer, maxEndLayer : LONGINT);
				BEGIN
					ed.SetMaxLayerRange(maxStartLayer, maxEndLayer);
			END SetMaxLayerRange;


			(**
				Sets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE SetLayerRange (startLayer, endLayer : LONGINT);
				BEGIN
					ed.SetLayerRange(startLayer, endLayer);
			END SetLayerRange;

			(**
				Gets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE GetLayerRange (VAR startLayer, endLayer : LONGINT);
				BEGIN
					ed.GetLayerRange(startLayer, endLayer);
			END GetLayerRange;

			(**
				Sets the maximum decomposition level range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested. This procedure
				shall NOT be called after the first code-block data has been read.

				maxStartDecLvl : The decompositon level to start at (inclusive) -> upper bound
				maxEndDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetMaxDecLevelRange (maxStartDecLvl, maxEndDecLvl : LONGINT);
				BEGIN
					ed.SetMaxDecLevelRange(maxStartDecLvl, maxEndDecLvl);
			END SetMaxDecLevelRange;

			(**
				Sets the decomposition level range for which data shall be delivered
				and decoded.

				startDecLvl : The decompositon level to start at (inclusive) -> upper bound
				endDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetDecLevelRange (startDecLvl, endDecLvl : LONGINT);
				BEGIN
					ed.SetDecLevelRange(startDecLvl, endDecLvl);
			END SetDecLevelRange;

			(**
				Gets the decomposition level range for which data shall be delivered
				and decoded.

				startDecLvl : The decompositon level to start at (inclusive) -> upper bound
				endDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE GetDecLevelRange (VAR startDec, endDec : LONGINT);
				BEGIN
					ed.GetDecLevelRange(startDec, endDec);
			END GetDecLevelRange;

			PROCEDURE SetReBuildMode;
				BEGIN
					ed.SetReBuildMode();
			END SetReBuildMode;

			PROCEDURE CurrentTile () : LONGINT;
				BEGIN
					RETURN ed.CurrentTile();
			END CurrentTile;

			PROCEDURE CurrentTilePart () : LONGINT;
				BEGIN
					RETURN ed.CurrentTilePart();
			END CurrentTilePart;

			PROCEDURE NextTilePart () : BOOLEAN;
				BEGIN
					RETURN ed.NextTilePart();
			END NextTilePart;

			PROCEDURE DataAvailable () : BOOLEAN;
				BEGIN
					RETURN ed.DataAvailable();
			END DataAvailable;

			PROCEDURE GetSubbandInfo (tile, component, reslevel, subband : LONGINT) : J2KU.SubbandInfo;
				BEGIN
					RETURN ed.GetSubbandInfo(tile, component, reslevel, subband)
			END GetSubbandInfo;

			PROCEDURE TilePartAvailable () : BOOLEAN;
				BEGIN
					RETURN ed.TilePartAvailable();
			END TilePartAvailable;

			PROCEDURE AllTilePartsRead () : BOOLEAN;
				BEGIN
					RETURN ed.AllTilePartsRead();
			END AllTilePartsRead;

			PROCEDURE FreeNonRebuildResources;
				BEGIN
					ed.FreeNonRebuildResources();
			END FreeNonRebuildResources;

			PROCEDURE FreeResources;
				BEGIN
					ed.FreeResources();
			END FreeResources;

		END ROIDescaler;

		(* --- ROI types --- *)


		(* --- Dequantizer types --- *)

		Dequantizer = OBJECT
			VAR
				roi : ROIDescaler;	(* This will be the source for code-blocks *)
				dataTypes : POINTER TO ARRAY OF ARRAY OF LONGINT;
				decSpec : J2KCS.DecoderSpecs;
				tBitDepth : J2KU.LongIntArrayPtr;	(* The bit depths of the transformed components *)
				(*
					Pre-calculated step sizes used in irreversible quantization. The actual step size used is then
					computed by multiplying the respective preStep value with 2^Rb, where Rb is the nominal
					dynamic range for the respective subband.

					1st dim: tile index
					2nd dim: component
					3rd dim: resolution level
					4th dim: subband index
				*)
				(*
					NOTE: We always allocate memory that won't be used, e.g. always values for 3 subbands,
					or space for components for which no quantization is performed
				*)
				preStep : POINTER TO ARRAY OF POINTER TO ARRAY OF POINTER TO ARRAY OF ARRAY 3 OF REAL;

				cblkBuf : ARRAY CBLK_BUFSIZE OF DataBlk;

				overallMinDecLvl : LONGINT;(*
												The overall minimum end decomposition level, i.e. there won't be any
												delivered code-block which belongs to a lower dec. level.
											*)

			PROCEDURE &InitNew *(deqOpt : J2KU.DequantizerOptions;
									roi : ROIDescaler;
									decSpec : J2KCS.DecoderSpecs);
				BEGIN
					dataTypes := NIL;
					tBitDepth := NIL;
					preStep := NIL;

					ReInit(deqOpt, roi, decSpec);
			END InitNew;

			PROCEDURE ReInit (deqOpt : J2KU.DequantizerOptions;
								roi : ROIDescaler;
								decSpec : J2KCS.DecoderSpecs);
				VAR
					ntiles, ncomp, i, j : LONGINT;
					imgInfo : J2KCS.ImageInfo;
					utBitDepth : J2KU.LongIntArrayPtr;	(* The bit depths of the untransformed (i.e. original) components *)
					cblkInt : DataBlkInt;
				BEGIN
					(* Get the relevant decoder option(s) *)
					SELF.roi := roi;
					(* Get number of tiles and components *)
					SELF.decSpec := decSpec;
					imgInfo := decSpec.GetImageInfo();
					ntiles := imgInfo.GetNumTiles();
					ncomp := imgInfo.GetNumComponents();

					NEW(dataTypes, ntiles, ncomp);

					(* Set default data type (LONGINT) *)
					FOR j := 0 TO ntiles - 1 DO
						Machine.Fill32(ADDRESSOF(dataTypes[j][0]), ncomp*SIZEOF(LONGINT), DATA_LONGINT);
					END;

					NEW(utBitDepth, ncomp);

					FOR i := 0 TO ncomp - 1 DO
						utBitDepth[i] := imgInfo.GetBitDepth(i);
					END;

					(* TODO: Compute the actual bit depths *)
					tBitDepth := utBitDepth;

					FOR i := 0 TO CBLK_BUFSIZE - 1 DO
						NEW(cblkInt);
						cblkBuf[i] := cblkInt;
					END;

					preStep := NIL;

					(* By default we expect data for all decomposition levels *)
					overallMinDecLvl := 0;
			END ReInit;


			PROCEDURE SetDataType (tile, component, type : LONGINT);
				BEGIN
					dataTypes[tile][component] := type;
			END SetDataType;

			PROCEDURE DataAvailable () : BOOLEAN;
				BEGIN
					RETURN roi.DataAvailable();
			END DataAvailable;

			PROCEDURE CurrentTile () : LONGINT;
				BEGIN
					RETURN roi.CurrentTile();
			END CurrentTile;

			PROCEDURE CurrentTilePart () : LONGINT;
				BEGIN
					RETURN roi.CurrentTilePart();
			END CurrentTilePart;

			PROCEDURE NextTilePart () : BOOLEAN;
				BEGIN
					IF ~roi.NextTilePart() THEN
						RETURN FALSE;
					END;

					IF roi.CurrentTilePart() = 0 THEN
						(* Need to pre-calculate step sizes *)
						CalculateStepSizes(roi.CurrentTile());
					END;

					RETURN TRUE;
			END NextTilePart;

			(* Pre-calculates the quantization steps for all components of a tile *)
			PROCEDURE CalculateStepSizes (tile : LONGINT);
				CONST
					(* The normalization factor for the manitssa (2^11, since 11 bits are used to represent the mantissa *)
					NORM_FACT = LSH(SYSTEM.VAL(LONGINT, 1), 11);
				VAR
					ntiles, ncomp, i, ndec, r: LONGINT;
					qStyle, exp : LONGINT;
					mant : REAL;
					imgInfo : J2KCS.ImageInfo;
				BEGIN
					imgInfo := decSpec.GetImageInfo();
					ntiles := imgInfo.GetNumTiles();
					ncomp := imgInfo.GetNumComponents();

					(* Loop over components *)
					FOR i := 0 TO ncomp - 1 DO
						(* We need to calculate the stepsizes based on the quantization type *)
						qStyle := decSpec.GetQuantStyle(tile, i);

						CASE qStyle OF
							|	J2KCS.NOQUANT:
									(* EMPTY; no exponent and mantissa provided; step size is always 1 *)
							|	J2KCS.QUANT_EXP:
									(* For every resolution level and subband we have a separate value *)
									IF preStep = NIL THEN
										NEW(preStep, ntiles);
									END;

									IF preStep[tile] = NIL THEN
										NEW(preStep[tile], ncomp);
									END;

									ndec := decSpec.GetNumDecLevels(tile, i);

									(*
										Subract maximum end decomposition level from number of decomposition levels.
										This will give us the actual maximum number of decomposition level from the
										minimum to the end.

										NOTE:	We then allocate from the minimum, NOT from the maximum start
												decomposition level that was specified by calling SetMaxDecLevelRange.
									*)
									DEC(ndec, overallMinDecLvl);

									NEW(preStep[tile][i], ndec + 1);

									(* Resolution level 0 *)
									exp := decSpec.GetQuantExponent(tile, i, 0, J2KU.SUB_LL);
									mant := decSpec.GetQuantMantissa(tile, i, 0, J2KU.SUB_LL);
									preStep[tile][i][0][0] := ((1 + (mant / NORM_FACT)) / LSH(SYSTEM.VAL(LONGINT, 1), exp));

									(* Now the other resolution levels *)
									FOR r := 1 TO ndec DO
										exp := decSpec.GetQuantExponent(tile, i, r, J2KU.SUB_HL);
										mant := decSpec.GetQuantMantissa(tile, i, r, J2KU.SUB_HL);
										preStep[tile][i][r][0] := ((1 + (mant / NORM_FACT)) / LSH(SYSTEM.VAL(LONGINT, 1), exp));

										exp := decSpec.GetQuantExponent(tile, i, r, J2KU.SUB_LH);
										mant := decSpec.GetQuantMantissa(tile, i, r, J2KU.SUB_LH);
										preStep[tile][i][r][1] := ((1 + (mant / NORM_FACT)) / LSH(SYSTEM.VAL(LONGINT, 1), exp));

										exp := decSpec.GetQuantExponent(tile, i, r, J2KU.SUB_HH);
										mant := decSpec.GetQuantMantissa(tile, i, r, J2KU.SUB_HH);
										preStep[tile][i][r][2] := ((1 + (mant / NORM_FACT)) / LSH(SYSTEM.VAL(LONGINT, 1), exp));
									END;
							|	J2KCS.QUANT_DER:
									(* The values for the NL-LL band are signalled only *)
									IF preStep = NIL THEN
										NEW(preStep, ntiles);
									END;

									IF preStep[tile] = NIL THEN
										NEW(preStep[tile], ncomp);
									END;

									NEW(preStep[tile][i], 1);

									exp := decSpec.GetQuantExponent(tile, i, 0, J2KU.SUB_LL);
									mant := decSpec.GetQuantMantissa(tile, i, 0, J2KU.SUB_LL);

									preStep[tile][i][0][0] := ((1 + (mant / NORM_FACT)) / LSH(SYSTEM.VAL(LONGINT, 1), exp));
							ELSE
								KernelLog.String("ERROR (Dequantizer.CalculateStepSizes) : Unknown quantization style");
								KernelLog.Ln();
						END;
					END;
			END CalculateStepSizes;


			PROCEDURE GetSubbandInfo (tile, component, reslevel, subband : LONGINT) : J2KU.SubbandInfo;
				BEGIN
					RETURN roi.GetSubbandInfo(tile, component, reslevel, subband)
			END GetSubbandInfo;


			PROCEDURE TilePartAvailable () : BOOLEAN;
				BEGIN
					RETURN roi.TilePartAvailable();
			END TilePartAvailable;

			PROCEDURE AllTilePartsRead () : BOOLEAN;
				BEGIN
					RETURN roi.AllTilePartsRead();
			END AllTilePartsRead;

			(**
				Sets the maximum layer range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested.
				This procedure shall NOT be called after the first code-block data
				has been read.

				maxStartLayer and maxEndLayer are inclusive.
			*)
			PROCEDURE SetMaxLayerRange (maxStartLayer, maxEndLayer : LONGINT);
				BEGIN
					roi.SetMaxLayerRange(maxStartLayer, maxEndLayer);
			END SetMaxLayerRange;

			(**
				Sets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE SetLayerRange (startLayer, endLayer : LONGINT);
				BEGIN
					roi.SetLayerRange(startLayer, endLayer);
			END SetLayerRange;

			(**
				Gets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE GetLayerRange (VAR startLayer, endLayer : LONGINT);
				BEGIN
					roi.GetLayerRange(startLayer, endLayer);
			END GetLayerRange;

			(**
				Sets the maximum decomposition level range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested. This procedure
				shall NOT be called after the first code-block data has been read.

				maxStartDecLvl : The decompositon level to start at (inclusive) -> upper bound
				maxEndDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetMaxDecLevelRange (maxStartDecLvl, maxEndDecLvl : LONGINT);
				BEGIN
					overallMinDecLvl := maxEndDecLvl;
					roi.SetMaxDecLevelRange(maxStartDecLvl, maxEndDecLvl);
			END SetMaxDecLevelRange;

			(**
				Sets the decomposition level range for which data shall be delivered
				and decoded.

				startDecLvl : The decompositon level to start at (inclusive) -> upper bound
				endDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetDecLevelRange (startDecLvl, endDecLvl : LONGINT);
				BEGIN
					roi.SetDecLevelRange(startDecLvl, endDecLvl);
			END SetDecLevelRange;

			(**
				Gets the decomposition level range for which data shall be delivered
				and decoded.

				startDec : The decompositon level to start at (inclusive) -> upper bound
				endDec : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE GetDecLevelRange (VAR startDec, endDec : LONGINT);
				BEGIN
					roi.GetDecLevelRange(startDec, endDec);
			END GetDecLevelRange;

			PROCEDURE SetReBuildMode;
				BEGIN
					roi.SetReBuildMode();
			END SetReBuildMode;

			(**
				Returns dequantized code-blocks
			*)
			PROCEDURE GetCodeBlocks (VAR cblk : ARRAY OF DataBlk; VAR cblkInfo : ARRAY OF J2KU.CblkInfo; ncblks : LONGINT) : LONGINT;
				VAR
					cblkIdx, ncblksRet : LONGINT;
					qStyle, cblkSize, width, height, shift, i, j, tmp, gainLog : LONGINT;
					curTile, comp, ndec : LONGINT;
					step : REAL;
					realData : J2KU.RealArrayPtr;
					srcData : J2KU.LongIntArrayPtr;
					cblkReal : DataBlkReal;
					subbInfo : J2KU.SubbandInfo;
					dataIdxIn, scanwIn, dataIdxOut, scanwOut : LONGINT;
				BEGIN
					(*
						This implementation relies on the condition that the component above this one
						always requests <= CBLK_BUFSIZE code-blocks
					*)
					ASSERT(ncblks <= CBLK_BUFSIZE);

					ncblksRet := roi.GetCodeBlocks(cblkBuf, cblkInfo, ncblks);

					curTile := roi.CurrentTile();
					FOR cblkIdx := 0 TO ncblksRet - 1 DO
						(* Get the maximum number of most significant bits for this code-block *)
						subbInfo := cblkInfo[cblkIdx].subbinfo;

						comp := subbInfo.component;

						qStyle := decSpec.GetQuantStyle(curTile, comp);

						cblkSize := cblkInfo[cblkIdx].width*cblkInfo[cblkIdx].height;
						width := cblkInfo[cblkIdx].width;
						height := cblkInfo[cblkIdx].height;
						shift := J2KU.LONGINT_BITS - 1 - subbInfo.magbits;
						srcData := cblkBuf[cblkIdx](DataBlkInt).data;
						dataIdxIn := cblkBuf[cblkIdx].offset;
						scanwIn := cblkBuf[cblkIdx].scanw;

						CASE dataTypes[curTile][comp] OF
							 	|	DATA_LONGINT :
							 			(* We can use the source block as destination block *)
										cblk[cblkIdx] := cblkBuf[cblkIdx];

								|	DATA_REAL :
										(* We cannot do in-place modification *)
										(* Allocate new code-block for REAL data *)
										NEW(cblkReal);
										NEW(realData, cblkSize);
										(* Set fields *)
										cblkReal.data := realData;
										cblkReal.offset := 0;
										cblkReal.scanw := width;
										cblk[cblkIdx] := cblkReal;
						END;

						IF qStyle = J2KCS.NOQUANT THEN

							CASE dataTypes[curTile][comp] OF
							 	|	DATA_LONGINT :
										(* First we adjust the data *)
										FOR j := 0 TO height - 1 DO
											FOR i := 0 TO width - 1 DO
												IF srcData[dataIdxIn] >= 0 THEN
													srcData[dataIdxIn] := LSH(srcData[dataIdxIn], -shift);
												ELSE
													srcData[dataIdxIn] := -LSH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, srcData[dataIdxIn]) / J2KU.LONGINT_SIGN_BIT), -shift);
												END;

												INC(dataIdxIn);
											END;

											dataIdxIn := dataIdxIn - width + scanwIn;
										END;
								|	DATA_REAL :
										(* First we adjust the data -> No in-place transformation possible *)
										dataIdxOut := cblk[cblkIdx].offset;
										scanwOut := cblk[cblkIdx].scanw;

										FOR j := 0 TO height - 1 DO
											FOR i := 0 TO width - 1 DO
												IF srcData[dataIdxIn] >= 0 THEN
													realData[dataIdxOut] := LSH(srcData[dataIdxIn], -shift);
												ELSE
													realData[dataIdxOut] := -LSH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, srcData[dataIdxIn]) / J2KU.LONGINT_SIGN_BIT), -shift);
												END;

												INC(dataIdxIn);
												INC(dataIdxOut);
											END;

											dataIdxIn := dataIdxIn - width + scanwIn;
											dataIdxOut := dataIdxOut - width + scanwOut;
										END;
							END;
						ELSE
	    						(* (Irreversible) quantization is used *)
							(* Determine the base 2 exponent of the subband gain and the index of the subband in the step size array *)
							CASE subbInfo.type OF
								|	J2KU.SUB_LL:
										gainLog := 0;
								|	J2KU.SUB_HL:
										gainLog := 1;
								|	J2KU.SUB_LH:
										gainLog := 1;
								|	J2KU.SUB_HH:
										gainLog := 2;
							END;

							IF qStyle = J2KCS.QUANT_DER THEN
								(* Derived exponent *)
								ndec := decSpec.GetNumDecLevels(curTile, comp);
								step := preStep[curTile][comp][0][0]
										* LSH(SYSTEM.VAL(LONGINT, 1), tBitDepth[comp] + gainLog + ndec - subbInfo.declevel);
							ELSE
								(* Values are singalled for each resolution level and subband *)
								step := preStep[curTile][comp][subbInfo.reslevel][subbInfo.index]
										* LSH(SYSTEM.VAL(LONGINT, 1), tBitDepth[comp] + gainLog);
							END;

							(* Adjust the step to the number of magnitude bits *)
							step := step / LSH(SYSTEM.VAL(LONGINT, 1), shift);

							CASE dataTypes[curTile][comp] OF
								|	DATA_LONGINT :
										FOR j := 0 TO height - 1 DO
											FOR i := 0 TO width - 1 DO
												IF srcData[dataIdxIn] < 0 THEN
													tmp := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, srcData[dataIdxIn]) / J2KU.LONGINT_SIGN_BIT);
													srcData[dataIdxIn] := -ENTIER(tmp * step + 0.5);
												ELSE
													srcData[dataIdxIn] := ENTIER(srcData[dataIdxIn] * step + 0.5);
												END;

												INC(dataIdxIn);
											END;

											dataIdxIn := dataIdxIn - width + scanwIn;
										END;

								|	DATA_REAL :
										dataIdxOut := cblk[cblkIdx].offset;
										scanwOut := cblk[cblkIdx].scanw;

										FOR j := 0 TO height - 1 DO
											FOR i := 0 TO width - 1 DO
												IF srcData[dataIdxIn] < 0 THEN
													tmp := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, srcData[dataIdxIn]) / J2KU.LONGINT_SIGN_BIT);
													realData[dataIdxOut] := -tmp * step;
												ELSE
													realData[dataIdxOut] := srcData[dataIdxIn] * step;
												END;

												INC(dataIdxIn);
												INC(dataIdxOut);
											END;

											dataIdxIn := dataIdxIn - width + scanwIn;
											dataIdxOut := dataIdxOut - width + scanwOut;
										END;
							END;
						END;
					END;

					RETURN ncblksRet;
			END GetCodeBlocks;

			PROCEDURE FreeNonRebuildResources;
				BEGIN
					roi.FreeNonRebuildResources();
			END FreeNonRebuildResources;

			PROCEDURE FreeResources;
				VAR
					i : LONGINT;
				BEGIN
					FOR i := 0 TO CBLK_BUFSIZE - 1 DO
						cblkBuf[i] := NIL;
					END;

					dataTypes := NIL;
					tBitDepth := NIL;
					preStep := NIL;
					roi.FreeResources();
			END FreeResources;

		END Dequantizer;


		(* --- END Dequantizer types --- *)


		(* --- Wavelet transformation types --- *)

		(*
			INFO:
			Here there are two strategies when applying wavelet filters:
			The Low Pass First convention and the High Pass First convention.

			The Low Pass First convention is used when the low-pass coefficients
			are located at even indexed positions after up-sampling.

			The High Pass First convention is used when the high-pass coefficients
			are located at even indexed positions after up-sampling.
		*)
		FilterSynInt = OBJECT

			PROCEDURE SynthesizeLPF (	lowCoeffs : J2KU.LongIntArrayPtr; lowOffset, lowStep : LONGINT;
										highCoeffs : J2KU.LongIntArrayPtr; highOffset, highStep : LONGINT;
										outData : J2KU.LongIntArrayPtr; outOffset, outStep, len : LONGINT);
			END SynthesizeLPF;

			PROCEDURE SynthesizeHPF (	lowCoeffs : J2KU.LongIntArrayPtr; lowOffset, lowStep : LONGINT;
										highCoeffs : J2KU.LongIntArrayPtr; highOffset, highStep : LONGINT;
										outData : J2KU.LongIntArrayPtr; outOffset, outStep, len : LONGINT);
			END SynthesizeHPF;

		END FilterSynInt;


		FilterSynReal = OBJECT

			PROCEDURE SynthesizeLPF(	lowCoeffs : J2KU.RealArrayPtr; lowOffset, lowStep : LONGINT;
										highCoeffs : J2KU.RealArrayPtr; highOffset, highStep : LONGINT;
										outData : J2KU.RealArrayPtr; outOffset, outStep, len : LONGINT);
			END SynthesizeLPF;

			PROCEDURE SynthesizeHPF(	lowCoeffs : J2KU.RealArrayPtr; lowOffset, lowStep : LONGINT;
										highCoeffs : J2KU.RealArrayPtr; highOffset, highStep : LONGINT;
										outData : J2KU.RealArrayPtr; outOffset, outStep, len : LONGINT);
			END SynthesizeHPF;

		END FilterSynReal;


		FilterSyn5x3Lifting = OBJECT(FilterSynInt)

			PROCEDURE SynthesizeLPF (	lowCoeffs : J2KU.LongIntArrayPtr; lowOffset, lowStep : LONGINT;
										highCoeffs : J2KU.LongIntArrayPtr; highOffset, highStep : LONGINT;
										outData : J2KU.LongIntArrayPtr; outOffset, outStep, len : LONGINT);
				VAR
					iOut, iHigh, iLow, jmpOut, i : LONGINT;
					oddLen : BOOLEAN;
				BEGIN

					iOut := outOffset;
					jmpOut := 2*outStep;	(* '2*' because of upsampling *)
					iHigh := highOffset;
					iLow := lowOffset;
					oddLen := ODD(len);

					(* Handle head boundary *)
					IF len > 1 THEN
						outData[iOut] := lowCoeffs[iLow] - ASH(highCoeffs[iHigh] + 1, -1);
					ELSE
						outData[iOut] := lowCoeffs[iLow];
					END;

					INC(iOut, jmpOut);
					INC(iLow, lowStep);
					INC(iHigh, highStep);

					(* First reconstruct even-indexed samples *)
					FOR i := 2 TO len - 2 BY 2 DO
						outData[iOut] := lowCoeffs[iLow] - ASH(highCoeffs[iHigh-highStep] + highCoeffs[iHigh] + 2, -2);
						INC(iOut, jmpOut);
						INC(iHigh, highStep);
						INC(iLow, lowStep);
					END;

					(* If we have odd length, this means that the last sample is even-indexed *)
					IF oddLen & (len > 2) THEN
						outData[iOut] := lowCoeffs[iLow] - ASH(highCoeffs[iHigh - highStep] + 1, -1);
					END;

					iOut := outOffset + outStep;
					iHigh := highOffset;

					(* Now go for the odd-indexed samples *)
					FOR i:=1 TO len - 2 BY 2 DO
						outData[iOut] := highCoeffs[iHigh] + ASH(outData[iOut - outStep] + outData[iOut + outStep], -1);
						INC(iOut, jmpOut);
						INC(iHigh, highStep);
					END;

					(* If we have even length, this means that the last sample is odd-indexed *)
					IF ~oddLen & (len > 1) THEN
						outData[iOut] := highCoeffs[iHigh] + outData[iOut-outStep];
					END;

			END SynthesizeLPF;

			PROCEDURE SynthesizeHPF (	lowCoeffs : J2KU.LongIntArrayPtr; lowOffset, lowStep : LONGINT;
										highCoeffs : J2KU.LongIntArrayPtr; highOffset, highStep : LONGINT;
										outData : J2KU.LongIntArrayPtr; outOffset, outStep, len : LONGINT);
				VAR
					iOut, iHigh, iLow, jmpOut, i : LONGINT;
					oddLen : BOOLEAN;
				BEGIN

					iOut := outOffset + outStep;
					jmpOut := 2*outStep;	(* '2*' because of upsampling *)
					iHigh := highOffset;
					iLow := lowOffset;
					oddLen := ODD(len);

					(* First reconstruct even-indexed samples *)
					FOR i := 1 TO len - 2 BY 2 DO
						outData[iOut] := lowCoeffs[iLow] - ASH(highCoeffs[iHigh] + highCoeffs[iHigh+highStep] + 2, -2);
						INC(iOut, jmpOut);
						INC(iHigh, highStep);
						INC(iLow, lowStep);
					END;

					IF ~oddLen & (len > 1) THEN
						outData[iOut] := lowCoeffs[iLow] - ASH(highCoeffs[iHigh] + 1, -1);
					END;

					iOut := outOffset;
					iHigh := highOffset;

					(* Handle head boundary *)
					IF len > 1 THEN
						outData[iOut] := highCoeffs[iHigh] + outData[iOut + outStep];
					ELSE
						outData[iOut] := ASH(highCoeffs[iHigh], -1);
					END;


					INC(iOut, jmpOut);
					INC(iHigh, highStep);

					(* Now go for the odd-indexed samples *)
					FOR i := 2 TO len - 2 BY 2 DO
						outData[iOut] := highCoeffs[iHigh] + ASH(outData[iOut - outStep] + outData[iOut + outStep], -1);
						INC(iOut, jmpOut);
						INC(iHigh, highStep);
					END;

					(* If we have odd length, this means that the last sample is odd-indexed *)
					IF oddLen & (len > 1) THEN
						outData[iOut] := highCoeffs[iHigh] + outData[iOut - outStep];
					END;

			END SynthesizeHPF;


		END FilterSyn5x3Lifting;

	CONST
		(* Lifting constants for the 9x7 irreversible filter *)
		ALPHA = -1.586134342;
		BETA = -0.05298011854;
		GAMMA = 0.8829110762;
		DELTA = 0.443568522;
		KL = 0.8128930655;
		KH = 1.230174106;

	TYPE
		FilterSyn9x7Lifting = OBJECT(FilterSynReal)

			PROCEDURE SynthesizeLPF(	lowCoeffs : J2KU.RealArrayPtr; lowOffset, lowStep : LONGINT;
										highCoeffs : J2KU.RealArrayPtr; highOffset, highStep : LONGINT;
										outData : J2KU.RealArrayPtr; outOffset, outStep, len : LONGINT);
				VAR
					iOut, iHigh, iLow, jmpOut, i : LONGINT;
					oddLen : BOOLEAN;
				BEGIN

					(* NOTE: Step 1 & 2 as specified in the standard have been integrated into steps 3 & 4 *)

					(* Step 3 as specified in the standard *)
					iOut := outOffset;
					jmpOut := 2*outStep;
					iHigh := highOffset;
					iLow := lowOffset;
					oddLen := ODD(len);

					(* Handle head boundary effect if reconstructed signal consists of more than 1 sample*)
					IF len > 1 THEN
						outData[iOut] := lowCoeffs[iLow]/KL  - 2*DELTA*highCoeffs[iHigh]/KH;
					ELSE
						outData[iOut] := lowCoeffs[iLow];
					END;

					INC(iOut, jmpOut);
					INC(iHigh, highStep);
					INC(iLow, lowStep);

					FOR i := 2 TO len - 2 BY 2 DO
						outData[iOut] := lowCoeffs[iLow]/KL - DELTA*(highCoeffs[iHigh - highStep] + highCoeffs[iHigh])/KH;
						INC(iOut, jmpOut);
						INC(iHigh, highStep);
						INC(iLow, lowStep);
					END;

					(* Handle tail boundary effect if reconstructed signal has odd length *)
					(* If we have odd length, this means that the last sample is even-indexed *)
					IF oddLen & (len > 2) THEN
						outData[iOut] := lowCoeffs[iLow]/KL - 2*DELTA*(highCoeffs[iHigh - highStep])/KH;
					END;

					(* Step 4 as specified in the standard *)
					iOut := outOffset + outStep;
					iHigh := highOffset;

					FOR i := 1 TO len - 2 BY 2 DO
						outData[iOut] := highCoeffs[iHigh]/KH - GAMMA*(outData[iOut - outStep] + outData[iOut + outStep]);
						INC(iOut, jmpOut);
						INC(iHigh, highStep);
					END;

					(* Handle tail boundary effect if reconstructed signal has even length *)
					(* If we have even length, this means that the last sample is odd-indexed *)
					IF ~oddLen & (len > 1) THEN
						outData[iOut] := highCoeffs[iHigh]/KH - 2*GAMMA*(outData[iOut - outStep]);
					END;

					(* Step 5 as specified in the standard *)
					iOut := outOffset;

					(* Handle head boundary effect if reconstructed signal consists of more than 1 sample *)
					IF len > 1 THEN
						outData[iOut] := outData[iOut] - 2*BETA*(outData[iOut + outStep]);
					END;

					INC(iOut, jmpOut);

					FOR i := 2 TO len - 2 BY 2 DO
						outData[iOut] := outData[iOut] - BETA*(outData[iOut - outStep] + outData[iOut + outStep]);
						INC(iOut, jmpOut);
					END;

					(* Handle tail boundary effect if reconstructed signal has odd length *)
					(* If we have odd length, this means that the last sample is even-indexed *)
					IF oddLen & (len > 2) THEN
						outData[iOut] := outData[iOut] - 2*BETA*outData[iOut - outStep];
					END;

					(* Step 6 as specified in the standard *)
					iOut := outOffset + outStep;

					FOR i := 1 TO len - 2 BY 2 DO
						outData[iOut] := outData[iOut] - ALPHA*(outData[iOut - outStep] + outData[iOut + outStep]);
						INC(iOut, jmpOut);
					END;

					(* Handle tail boundary effect if reconstructed signal has even length *)
					(* If we have even length, this means that the last sample is odd-indexed *)
					IF ~oddLen & (len > 1) THEN
						outData[iOut] := outData[iOut] - 2*ALPHA*outData[iOut - outStep];
					END;

			END SynthesizeLPF;

			PROCEDURE SynthesizeHPF(	lowCoeffs : J2KU.RealArrayPtr; lowOffset, lowStep : LONGINT;
										highCoeffs : J2KU.RealArrayPtr; highOffset, highStep : LONGINT;
										outData : J2KU.RealArrayPtr; outOffset, outStep, len : LONGINT);
				VAR
					iOut, iHigh, iLow, jmpOut, i : LONGINT;
					oddLen : BOOLEAN;
				BEGIN

					(* NOTE: Step 1 & 2 as specified in the standard have been integrated into steps 3 & 4 *)
					(* Step 3 as specified in the standard *)
					iOut := outOffset + outStep;
					jmpOut := 2*outStep;
					iHigh := highOffset;
					iLow := lowOffset;
					oddLen := ODD(len);

					FOR i := 1 TO len - 2 BY 2 DO
						outData[iOut] := lowCoeffs[iLow]/KL - DELTA*(highCoeffs[iHigh]/KH + highCoeffs[iHigh + highStep]/KH);
						INC(iOut, jmpOut);
						INC(iHigh, highStep);
						INC(iLow, lowStep);
					END;

					(* Handle tail boundary effect if reconstructed signal has even length *)
					(* Ifwe have even length, this means that the last sample is even-indexed *)
					IF ~oddLen & (len > 1) THEN
						outData[iOut] := lowCoeffs[iLow]/KL - 2*DELTA*(highCoeffs[iHigh]/KH);
					END;

					(* Step 4 as specified in the standard *)
					iOut := outOffset;
					iHigh := highOffset;

					(* Handle head boundary effect if reconstructed signal consists of more than 1 sample *)
					IF len > 1 THEN
						outData[iOut] := highCoeffs[iHigh]/KH - 2*GAMMA*outData[iOut + outStep];
					ELSE
						outData[iOut] := highCoeffs[iHigh] / 2;
					END;

					INC(iOut, jmpOut);
					INC(iHigh, highStep);

					FOR i := 2 TO len - 2 BY 2 DO
						outData[iOut] := highCoeffs[iHigh]/KH - GAMMA*(outData[iOut - outStep] + outData[iOut + outStep]);
						INC(iOut, jmpOut);
						INC(iHigh, highStep);
					END;

					(* Handle tail boundary effect if reconstructed signal has odd length *)
					(* If we have odd length, this means that the last sample is odd-indexed *)
					IF oddLen & (len > 2) THEN
						outData[iOut] := highCoeffs[iHigh]/KH - 2*GAMMA*outData[iOut - outStep];
					END;

					(* Step 5 as specified in the standard *)
					iOut := outOffset + outStep;

					FOR i := 1 TO len - 2 BY 2 DO
						outData[iOut] := outData[iOut] - BETA*(outData[iOut - outStep] + outData[iOut + outStep]);
						INC(iOut, jmpOut);
					END;

					(* Handle tail boundary effect if reconstructed signal has even length *)
					(* If we have even length, this means that the last sample is even-indexed *)
					IF ~oddLen & (len > 1) THEN
						outData[iOut] := outData[iOut] - 2*BETA*outData[iOut - outStep];
					END;

					(* Step 6 as specified in the standard *)
					iOut := outOffset;

					(* Handle head boundary effect if reconstructed signal consists of more than 1 sample *)
					IF len > 1 THEN
						outData[iOut] := outData[iOut] - 2*ALPHA*outData[iOut + outStep];
					END;

					INC(iOut, jmpOut);

					FOR i := 2 TO len - 2 BY 2 DO
						outData[iOut] := outData[iOut] - ALPHA*(outData[iOut - outStep] + outData[iOut + outStep]);
						INC(iOut, jmpOut);
					END;

					(* Handle tail boundary effect if reconstructed signal has odd length *)
					(* If we have odd length, this means that the last sample is odd-indexed *)
					IF oddLen & (len > 2) THEN
						outData[iOut] := outData[iOut] - 2*ALPHA*outData[iOut - outStep];
					END;

			END SynthesizeHPF;

		END FilterSyn9x7Lifting;

		InverseDWT = OBJECT
			VAR
				deq : Dequantizer;
				curTile : LONGINT;
				ncomp : LONGINT;
				minDecLvl, maxDecLvl, minLayer, maxLayer : LONGINT;
				reconstructedComps : POINTER TO ARRAY OF ARRAY OF DataBlk;
				reconstructedCompsInfo : POINTER TO ARRAY OF ARRAY OF J2KU.BlkInfo;
				reconstructedRange : POINTER TO ARRAY OF ARRAY 4 OF LONGINT;
				filterIrrev : FilterSynReal;	(* We always use a filter operating on real values when we have irreversible transformation *)
				filterRev : FilterSynInt;		(* We always use a filter operating on integer values when we have reversible transformation *)
				decSpec : J2KCS.DecoderSpecs;
				gotoReBuild : BOOLEAN;
				overallMinDecLvl : LONGINT;

			PROCEDURE &InitNew *(	invDWTOpt : J2KU.InverseDWTOptions;
									deq : Dequantizer;
									decSpec : J2KCS.DecoderSpecs);
				BEGIN
					ReInit(invDWTOpt, deq, decSpec);
			END InitNew;

			PROCEDURE ReInit (	invDWTOpt : J2KU.InverseDWTOptions;
								deq : Dequantizer;
								decSpec : J2KCS.DecoderSpecs);
				VAR
					ntiles : LONGINT;
					imgInfo : J2KCS.ImageInfo;
				BEGIN
					imgInfo := decSpec.GetImageInfo();
					ncomp := imgInfo.GetNumComponents();
					ntiles := imgInfo.GetNumTiles();

					(* Initialize members *)
					SELF.deq := deq;
					SELF.decSpec := decSpec;
					(* Default: Reconstruct the whole image *)
					minDecLvl := 0;
					maxDecLvl := MAX(LONGINT);
					minLayer := 0;
					maxLayer := MAX(LONGINT);
					overallMinDecLvl := 0;

					NEW(reconstructedComps, ntiles, ncomp);
					NEW(reconstructedCompsInfo, ntiles, ncomp);
					NEW(reconstructedRange, ntiles);

					CASE invDWTOpt.filterRev OF
						|	FILTER_5X3_LIFTING :
								filterRev := filter5x3Lift;
						ELSE
							KernelLog.String("ERROR (InverseDWT.ReInit): Invalid reversible filter type specified");
							KernelLog.Ln();
					END;

					CASE invDWTOpt.filterIrrev OF
						|	FILTER_9X7_LIFTING :
								filterIrrev := filter9x7Lift;
						ELSE
							KernelLog.String("ERROR (InverseDWT.ReInit): Invalid irreversible filter type specified");
							KernelLog.Ln();
					END;

					gotoReBuild := FALSE;
			END ReInit;


			PROCEDURE FullTransform () : BOOLEAN;
				BEGIN
					(* Since this implementation does a full transformation per step, this procedure is just a wrapper *)
					RETURN TransformStep();
			END FullTransform;

			(*
				Initializes all coefficients contained in the reconstructed component buffer to 0
				(or 0.0 in the case of floating point values). That is done for all components of the
				current tile.
			*)
			PROCEDURE InitReconstructedRange;
				VAR
					recMinDecLvl, c, ndec : LONGINT;
					reslevel, offset, width, height, scanw, h : LONGINT;
					subbInfo : J2KU.SubbandInfo;
					dataInt : J2KU.LongIntArrayPtr;
					dataReal : J2KU.RealArrayPtr;
				BEGIN
					(*	NOTE:
						We need to re-init the whole buffer up to the current decomposition level.
						We cannot just re-init the reconstructed range, because the lower levels
						also get affected during wavelet reconstruction (-> they're just 0 low pass
						contributions).
					*)
					(* Need to get the 'real' minimum decomposition level of the reconstructed components *)
					IF reconstructedRange[curTile][3] < 0 THEN
						recMinDecLvl := 0;
					ELSE
						recMinDecLvl := reconstructedRange[curTile][3];
					END;

					FOR c := 0 TO ncomp - 1 DO
						ndec := decSpec.GetNumDecLevels(curTile, c);
						reslevel := ndec - recMinDecLvl;

						(* Maybe the component has not been reconstructed at all *)
						IF reslevel >= 0 THEN

							(* Get the LL subband of the reconstructed resolution level *)
							subbInfo := deq.GetSubbandInfo(curTile, c, reslevel, J2KU.SUB_LL);

							offset := reconstructedComps[curTile][c].offset;
							scanw := reconstructedComps[curTile][c].scanw;
							width := subbInfo.width;
							height := subbInfo.height;

							IF reconstructedComps[curTile][c]  IS DataBlkInt THEN
								dataInt := reconstructedComps[curTile][c](DataBlkInt).data;

								FOR h := 0 TO subbInfo.height - 1 DO
									Machine.Fill32(ADDRESSOF(dataInt[offset]), width*SIZEOF(LONGINT), 0);
									INC(offset, scanw);
								END;
							ELSIF reconstructedComps[curTile][c] IS DataBlkReal THEN
								dataReal := reconstructedComps[curTile][c](DataBlkReal).data;

								FOR h := 0 TO subbInfo.height - 1 DO
									Machine.Fill32(ADDRESSOF(dataReal[offset]), width*SIZEOF(REAL), 0);
									INC(offset, scanw);
								END;
							END;
						END;
					END;
			END InitReconstructedRange;


			(*
				Gets data from the lower level (the dequantization component, that is)
				and stores it in the internal buffer.
			*)
			PROCEDURE GetData () : BOOLEAN;
				VAR
					ncblksRet, i, j, rowStartComp, rowStartCblk : LONGINT;
					dataCblkArr : ARRAY CBLK_BUFSIZE OF DataBlk;
					dataCblkInfoArr : ARRAY CBLK_BUFSIZE OF J2KU.CblkInfo;
					dataCblk : DataBlk;
					recComp : DataBlk;
					dataInt : J2KU.LongIntArrayPtr;
					dataReal : J2KU.RealArrayPtr;
					comp : LONGINT;
				BEGIN
					(* We let the dequantizer instantiate the concrete code-blocks *)
					ncblksRet := deq.GetCodeBlocks(dataCblkArr, dataCblkInfoArr, CBLK_BUFSIZE);

					(* Get code-blocks until all blocks for the current resolution level have been received *)
					WHILE ncblksRet > 0 DO

						FOR j := 0 TO ncblksRet - 1 DO
							(* Copy data to internal buffer *)
							comp := dataCblkInfoArr[j].subbinfo.component;
							recComp := reconstructedComps[curTile][comp];
							rowStartComp := dataCblkInfoArr[j].ulsy * recComp.scanw + dataCblkInfoArr[j].ulsx + recComp.offset;
							rowStartCblk := dataCblkArr[j].offset;
							dataCblk := dataCblkArr[j];

							IF dataCblk IS DataBlkInt THEN
								WITH dataCblk : DataBlkInt DO
									dataInt := recComp(DataBlkInt).data;

									FOR i := 0 TO dataCblkInfoArr[j].height - 1 DO
										SYSTEM.MOVE(ADDRESSOF(dataCblk.data[rowStartCblk]), ADDRESSOF(dataInt[rowStartComp]), dataCblkInfoArr[j].width * SIZEOF(LONGINT));
										INC(rowStartComp, recComp.scanw);
										INC(rowStartCblk, dataCblk.scanw);
									END;
								END;
							ELSIF dataCblk IS DataBlkReal THEN
								WITH dataCblk : DataBlkReal DO
									dataReal := recComp(DataBlkReal).data;

									FOR i := 0 TO dataCblkInfoArr[j].height - 1 DO
										SYSTEM.MOVE(ADDRESSOF(dataCblk.data[rowStartCblk]), ADDRESSOF(dataReal[rowStartComp]), dataCblkInfoArr[j].width * SIZEOF(REAL));
										INC(rowStartComp, recComp.scanw);
										INC(rowStartCblk, dataCblk.scanw);
									END;
								END;
							ELSE
								KernelLog.String("ERROR (InverseDWT.TransformStep) : Dequantizer returned unknown data-block type");
								KernelLog.Ln();
								RETURN FALSE;
							END;
						END;

						(* We let the dequantizer instantiate the concrete code-blocks *)
						ncblksRet := deq.GetCodeBlocks(dataCblkArr, dataCblkInfoArr, CBLK_BUFSIZE);
					END;

					RETURN TRUE;
			END GetData;

			(* Does 1 transformation step. This implmentation sets TransformStep = FullTransform *)
			PROCEDURE TransformStep () : BOOLEAN;
				VAR
					i, origMaxDecLvl, origMinDecLvl : LONGINT;
				BEGIN
					(* Save original decomposition level range *)
					origMaxDecLvl := maxDecLvl;
					origMinDecLvl := minDecLvl;

					(*
						We need to set the appropriate decomposition level range, i.e. maybe we don't
						have to rebuild from scratch but can continue reconstructing from the current
						decomposition level range.

						The following conditions for rebuilding from the current state are required:
						1. The layer range has not changed
						2. The maximum decomposition level has not changed
						3. The new minimum decomposition level is lower
						    than the current decomposition level (i.e. the new
						    resolution is higher than the current one)

						Otherwise we need to reconstruct from the beginning.
					*)
					(* NOTE The following IF statement should NEVER evaluate to TRUE, if we're NOT in rebuild mode *)
					IF	(reconstructedRange[curTile][0] = minLayer)
						& (reconstructedRange[curTile][1] = maxLayer)
					THEN

						IF	(reconstructedRange[curTile][3] > origMinDecLvl)
								& (reconstructedRange[curTile][2] = origMaxDecLvl)
						THEN	(* Need only the data of higher resolution levels (i.e. lower decomposition levels) *)
							SetDecLevelRange(reconstructedRange[curTile][3]-1, origMinDecLvl);

							IF ~GetData() THEN
								RETURN FALSE;
							END;

							(*
								We now need to set the start decomposition level to the upper decomposition level of the
								reconstructed components, otherwise we would skip one reconstruction step
							*)
							SetDecLevelRange(reconstructedRange[curTile][3], origMinDecLvl);
						(* If nothing has changed, we don't need to do anything *)
						ELSIF	(reconstructedRange[curTile][3] # origMinDecLvl)
								OR (reconstructedRange[curTile][2] # origMaxDecLvl)
						THEN
							(* Need to reinitialize the reconstructed range *)
							InitReconstructedRange();

							 (* We need to refetch all the data *)
							IF ~GetData() THEN
								RETURN FALSE;
							END;
						END;
					ELSE (* Default case: retrieve all data *)
						(* Need to reinitialize the reconstructed range *)
						InitReconstructedRange();

						IF ~GetData() THEN
							RETURN FALSE;
						END;
					END;

					(* Perform 2D wavelet reconstrution steps for each component of the current tile *)
					(* Transformation only done, if no more tile-parts will follow *)
					IF AllTilePartsRead() THEN
						FOR i := 0 TO ncomp - 1 DO
							IF ~Wavelet2DReconstruction(curTile, i) THEN
								RETURN FALSE;
							END;
						END;

						reconstructedRange[curTile][0] := minLayer;
						reconstructedRange[curTile][1] := maxLayer;
						reconstructedRange[curTile][2] := origMaxDecLvl;
						reconstructedRange[curTile][3] := origMinDecLvl;
					END;

					(* Restore the original decompositon level range *)
					SetDecLevelRange(origMaxDecLvl, origMinDecLvl);

					RETURN TRUE;
			END TransformStep;

			(**
				Sets the maximum layer range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested.
				This procedure shall NOT be called after the first code-block data
				has been read.

				maxStartLayer and maxEndLayer are inclusive.
			*)
			PROCEDURE SetMaxLayerRange (maxStartLayer, maxEndLayer : LONGINT);
				BEGIN
					deq.SetMaxLayerRange(maxStartLayer, maxEndLayer);
			END SetMaxLayerRange;

			(**
				Sets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE SetLayerRange (startLayer, endLayer : LONGINT);
				BEGIN
					SELF.minLayer := startLayer;
					SELF.maxLayer := endLayer;
					deq.SetLayerRange(startLayer, endLayer);
			END SetLayerRange;

			(**
				Gets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE GetLayerRange (VAR startLayer, endLayer : LONGINT);
				BEGIN
					startLayer := minLayer;
					endLayer := maxLayer;
			END GetLayerRange;

			(**
				Sets the maximum decomposition level range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested. This procedure
				shall NOT be called after the first code-block data has been read.

				maxStartDecLvl : The decompositon level to start at (inclusive) -> upper bound
				maxEndDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetMaxDecLevelRange (maxStartDecLvl, maxEndDecLvl : LONGINT);
				BEGIN
					overallMinDecLvl := maxEndDecLvl;
					deq.SetMaxDecLevelRange(maxStartDecLvl, maxEndDecLvl);
			END SetMaxDecLevelRange;

			(**
				Sets the decomposition level range for which data shall be delivered
				and decoded.

				startDecLvl : The decompositon level to start at (inclusive) -> upper bound
				endDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetDecLevelRange (startDecLvl, endDecLvl : LONGINT);
				BEGIN
					SELF.minDecLvl := endDecLvl;
					SELF.maxDecLvl := startDecLvl;
					deq.SetDecLevelRange(startDecLvl, endDecLvl);
			END SetDecLevelRange;

			(**
				Gets the decomposition level range for which data shall be delivered
				and decoded.

				startDec : The decompositon level to start at (inclusive) -> upper bound
				endDec : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE GetDecLevelRange (VAR startDec, endDec : LONGINT);
				BEGIN
					startDec := maxDecLvl;
					endDec := minDecLvl;
			END GetDecLevelRange;

			PROCEDURE GetComponent (component : LONGINT; VAR comp : DataBlk; VAR compInfo : J2KU.BlkInfo);
				BEGIN
					comp := reconstructedComps[curTile][component];
					compInfo := reconstructedCompsInfo[curTile][component];
			END GetComponent;

			PROCEDURE CurrentTile () : LONGINT;
				BEGIN
					RETURN deq.CurrentTile();
			END CurrentTile;

			PROCEDURE CurrentTilePart () : LONGINT;
				BEGIN
					RETURN deq.CurrentTilePart();
			END CurrentTilePart;

			PROCEDURE NextTilePart () : BOOLEAN;
				BEGIN
					IF gotoReBuild THEN
						SetReBuildMode();
						gotoReBuild := FALSE;
					END;

					IF ~deq.NextTilePart() THEN
						RETURN FALSE;
					END;

					RETURN InitTile();
			END NextTilePart;

			PROCEDURE AllTilePartsRead () : BOOLEAN;
				BEGIN
					RETURN deq.AllTilePartsRead();
			END AllTilePartsRead;


			PROCEDURE TilePartAvailable () : BOOLEAN;
				BEGIN
					RETURN deq.TilePartAvailable();
			END TilePartAvailable;

			PROCEDURE DataAvailable () : BOOLEAN;
				BEGIN
					RETURN deq.DataAvailable();
			END DataAvailable;

			PROCEDURE InitTile () : BOOLEAN;
				VAR
					transType, compSize, i, ndec  : LONGINT;
					subbInfo, subbInfoStart : J2KU.SubbandInfo;
					compInt : DataBlkInt;
					compReal : DataBlkReal;
					recCompInfo : J2KU.BlkInfo;
					minDecLvlTile : LONGINT;
				BEGIN
					curTile := deq.CurrentTile();

					IF deq.CurrentTilePart() = 0 THEN
						minDecLvlTile := decSpec.GetMinDecLevels(curTile);

						(* Check that this tile has as much decomposition levels as required *)
						IF minDecLvl > minDecLvlTile THEN
							(* If possible, we can rebuild the image, else we issue an error and move to the end of/close the stream *)
							IF overallMinDecLvl > minDecLvlTile THEN
								(* We need to abort *)
								KernelLog.String("ERROR (InverseDWT.InitTile): Can't build image at requested resolution level: ");
								KernelLog.String(" Minimum resolution level of tile ");
								KernelLog.Int(curTile, 0);
								KernelLog.String(" is higher than the requested resolution level");
								RETURN FALSE;
							ELSE
								(* After the current tile-part has been handled we enter the rebuild mode *)
								gotoReBuild := TRUE;
								(* Adjust new minimum decomposition level *)
								SetDecLevelRange(maxDecLvl, minDecLvlTile);
							END;
						END;

						FOR i := 0 TO ncomp - 1 DO
							ndec := decSpec.GetNumDecLevels(curTile, i);

							(* Get the subband info of the first resolution level (= start dec level for wavelet decomp.) *)
							IF maxDecLvl >= ndec THEN
								subbInfoStart := deq.GetSubbandInfo(curTile, i, 0, J2KU.SUB_LL);
							ELSE
								subbInfoStart := deq.GetSubbandInfo(curTile, i, ndec - maxDecLvl, J2KU.SUB_LL);
							END;

							(* We allocate space for the component at the maximum resolution level*)
							subbInfo := deq.GetSubbandInfo(curTile, i, ndec - overallMinDecLvl, J2KU.SUB_LL);

							compSize := subbInfo.width * subbInfo.height;

							transType := decSpec.GetWavTransType(curTile, i);

							NEW(recCompInfo);
							recCompInfo.ulx := subbInfoStart.ulcx;
							recCompInfo.uly := subbInfoStart.ulcy;
							recCompInfo.width := subbInfoStart.width;
							recCompInfo.height := subbInfoStart.height;

							reconstructedCompsInfo[curTile][i] := recCompInfo;

							IF transType = J2KCS.TRANS_5X3_REV THEN
								NEW(compInt);
								NEW(compInt.data, compSize);
								deq.SetDataType(curTile, i, DATA_LONGINT);
								reconstructedComps[curTile][i] := compInt;
								(*Machine.Fill32(ADDRESSOF(compInt.data[0]), compSize*SIZEOF(LONGINT), 0);*)
							ELSIF transType = J2KCS.TRANS_9X7_IRREV THEN
								NEW(compReal);
								NEW(compReal.data, compSize);
								deq.SetDataType(curTile, i, DATA_REAL);
								reconstructedComps[curTile][i] := compReal;
								(*Machine.Fill32(ADDRESSOF(compReal.data[0]), compSize*SIZEOF(REAL), 0);*)
							END;

							reconstructedComps[curTile][i].offset := 0;
							reconstructedComps[curTile][i].scanw := subbInfo.width;
						END;

						(* Layer range *)
						reconstructedRange[curTile][0] := -1;
						reconstructedRange[curTile][1] := -1;
						(* Decomposition level range *)
						reconstructedRange[curTile][2] := MIN(LONGINT);
						reconstructedRange[curTile][3] := MAX(LONGINT);
					END;

					RETURN TRUE;
			END InitTile;


			(* Performs the 2D wavelet reconstruction with 2D-separable filters *)
			PROCEDURE Wavelet2DReconstruction (tile, component : LONGINT) : BOOLEAN;
				VAR
					recComp : DataBlk;
					recCompInfo : J2KU.BlkInfo;
					ndec, curRes, curDec, ulcx, ulcy, ulx, uly, width, height, i, k, j : LONGINT;
					subbInfo : J2KU.SubbandInfo;
					bufInt, dataInt : J2KU.LongIntArrayPtr;
					bufReal, dataReal : J2KU.RealArrayPtr;
					dataOffset, tmpOffset : LONGINT;
					transType : LONGINT;
				BEGIN
					recComp := reconstructedComps[tile][component];
					recCompInfo := reconstructedCompsInfo[tile][component];

					(* Get the corresponding transformation type *)
					transType := decSpec.GetWavTransType(tile, component);

					(* Get the pointers to the input/output data arrays *)
					IF transType = J2KCS.TRANS_5X3_REV THEN
						dataInt := recComp(DataBlkInt).data;
					ELSIF transType = J2KCS.TRANS_9X7_IRREV THEN
						dataReal := recComp(DataBlkReal).data;
					ELSE
						KernelLog.String("ERROR (InverseDWT.Wavelet2DReconstruction): Invalid/Unknown wavelet tranformation type specified");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					(* Get number of decomposition levels *)
					ndec := decSpec.GetNumDecLevels(tile, component);

					(* Set the actual start decomposition level for this tile-component *)
					IF maxDecLvl > ndec THEN
						curDec := ndec;
					ELSE
						curDec := maxDecLvl;
					END;

					(* Store current values, in case we don't do any transformation *)
					ulcx := recCompInfo.ulx;
					ulcy := recCompInfo.uly;
					width := recCompInfo.width;
					height := recCompInfo.height;

					(* While desired resolution /decomposition level not reached -> transform *)
					(* NOTE: We don't check wether minDecLvl >= 0 here *)
					WHILE (curDec > minDecLvl) DO
						(* Go one decomposition level back *)
						DEC(curDec);
						(* Determine the resolution level to be reconstructed *)
						curRes := ndec - curDec;
						(* Get the LL subband at this resolution level *)
						subbInfo := deq.GetSubbandInfo(tile, component, curRes, J2KU.SUB_LL);

						ulcx := subbInfo.ulcx;
						ulcy := subbInfo.ulcy;
						ulx := subbInfo.ulsx;
						uly := subbInfo.ulsy;
						width := subbInfo.width;
						height := subbInfo.height;

						(* Only do reconstruction if subband has (width # 0) & (height # 0) *)
						IF (width # 0) & (height # 0) THEN

							dataOffset := uly*recComp.scanw + ulx + recComp.offset;

							IF transType = J2KCS.TRANS_5X3_REV THEN
								(* Do the horizontal reconstruction *)
								tmpOffset := dataOffset;

								IF width > height THEN
									NEW(bufInt, width);
								ELSE
									NEW(bufInt, height);
								END;

								IF ~ODD(ulcx) THEN
									(* The first coefficient is a low-pass coefficient *)
									FOR i := 0 TO height - 1 DO
										SYSTEM.MOVE(ADDRESSOF(dataInt[tmpOffset]), ADDRESSOF(bufInt[0]), width*SIZEOF(LONGINT));
										(* If the width is odd then #(low-pass coefficients) = #(high-pass coefficients) + 1 *)
										filterRev.SynthesizeLPF(bufInt, 0, 1, bufInt, (width+1) DIV 2, 1, dataInt, tmpOffset, 1, width);
										INC(tmpOffset, recComp.scanw);
									END;
								ELSE
									(* The first coefficient is a high-pass coefficient *)
									FOR i := 0 TO height - 1 DO
										SYSTEM.MOVE(ADDRESSOF(dataInt[tmpOffset]), ADDRESSOF(bufInt[0]), width*SIZEOF(LONGINT));
										(* If the width is odd then #(high-pass coefficients) = #(low-pass coefficients) + 1 *)
										filterRev.SynthesizeHPF(bufInt, 0, 1, bufInt, width DIV 2, 1, dataInt, tmpOffset, 1, width);
										INC(tmpOffset, recComp.scanw);
									END;
								END;

								(* Do the vertical reconstruction *)
								tmpOffset := dataOffset;
								IF ~ODD(ulcy) THEN
									(* The first coefficient is a low-pass coefficient *)
									FOR i := 0 TO width - 1 DO
										k := tmpOffset;
										FOR j := 0 TO height - 1 DO
											bufInt[j] := dataInt[k];
											INC(k, recComp.scanw);
										END;

										(* If the width is odd then #(low-pass coefficients) = #(high-pass coefficients) + 1 *)
										filterRev.SynthesizeLPF(bufInt, 0, 1, bufInt, (height+1) DIV 2, 1, dataInt, tmpOffset, recComp.scanw, height);
										INC(tmpOffset);
									END;
								ELSE
									(* The first coefficient is a high-pass coefficient *)
									FOR i := 0 TO width - 1 DO
										k := tmpOffset;
										FOR j := 0 TO height - 1 DO
											bufInt[j] := dataInt[k];
											INC(k, recComp.scanw);
										END;

										(* If the width is odd then #(high-pass coefficients) = #(low-pass coefficients) + 1 *)
										filterRev.SynthesizeHPF(bufInt, 0, 1, bufInt, height DIV 2, 1, dataInt, tmpOffset, recComp.scanw, height);
										INC(tmpOffset);
									END;
								END;
							ELSIF transType = J2KCS.TRANS_9X7_IRREV THEN
								(* Do the horizontal reconstruction *)
								tmpOffset := dataOffset;

								IF width > height THEN
									NEW(bufReal, width);
								ELSE
									NEW(bufReal, height);
								END;

								IF ~ODD(ulcx) THEN
									(* The first coefficient is a low-pass coefficient *)
									FOR i := 0 TO height - 1 DO
										SYSTEM.MOVE(ADDRESSOF(dataReal[tmpOffset]), ADDRESSOF(bufReal[0]), width*SIZEOF(REAL));
										(* If the width is odd then #(low-pass coefficients) = #(high-pass coefficients) + 1 *)
										filterIrrev.SynthesizeLPF(bufReal, 0, 1, bufReal, (width+1) DIV 2, 1, dataReal, tmpOffset, 1, width);
										INC(tmpOffset, recComp.scanw);
									END;
								ELSE
									(* The first coefficient is a high-pass coefficient *)
									FOR i := 0 TO height - 1 DO
										SYSTEM.MOVE(ADDRESSOF(dataReal[tmpOffset]), ADDRESSOF(bufReal[0]), width*SIZEOF(REAL));
										(* If the width is odd then #(high-pass coefficients) = #(low-pass coefficients) + 1 *)
										filterIrrev.SynthesizeHPF(bufReal, 0, 1, bufReal, width DIV 2, 1, dataReal, tmpOffset, 1, width);
										INC(tmpOffset, recComp.scanw);
									END;
								END;

								(* Do the vertical reconstruction *)
								tmpOffset := dataOffset;
								IF ~ODD(ulcy) THEN
									(* The first coefficient is a low-pass coefficient *)
									FOR i := 0 TO width - 1 DO
										k := tmpOffset;
										FOR j := 0 TO height - 1 DO
											bufReal[j] := dataReal[k];
											INC(k, recComp.scanw);
										END;

										(* If the width is odd then #(low-pass coefficients) = #(high-pass coefficients) + 1 *)
										filterIrrev.SynthesizeLPF(bufReal, 0, 1, bufReal, (height+1) DIV 2, 1, dataReal, tmpOffset, recComp.scanw, height);
										INC(tmpOffset);
									END;
								ELSE
									(* The first coefficient is a high-pass coefficient *)
									FOR i := 0 TO width - 1 DO
										k := tmpOffset;
										FOR j := 0 TO height - 1 DO
											bufReal[j] := dataReal[k];
											INC(k, recComp.scanw);
										END;

										(* If the width is odd then #(high-pass coefficients) = #(low-pass coefficients) + 1 *)
										filterIrrev.SynthesizeHPF(bufReal, 0, 1, bufReal, height DIV 2, 1, dataReal, tmpOffset, recComp.scanw, height);
										INC(tmpOffset);
									END;
								END;
							END;
						END;
					END;

					(* Update tile-component information *)
					recCompInfo.ulx := ulcx;
					recCompInfo.uly := ulcy;
					recCompInfo.width := width;
					recCompInfo.height := height;

					RETURN TRUE;
			END Wavelet2DReconstruction;

			PROCEDURE SetReBuildMode;
				BEGIN
					deq.SetReBuildMode();
			END SetReBuildMode;

			PROCEDURE FreeNonRebuildResources;
				BEGIN
					deq.FreeNonRebuildResources();
			END FreeNonRebuildResources;

			PROCEDURE FreeResources;
				BEGIN
					reconstructedComps := NIL;
					reconstructedCompsInfo := NIL;
					reconstructedRange := NIL;

					deq.FreeResources();
			END FreeResources;

		END InverseDWT;

		(* --- END Wavelet transformation types --- *)


		(* --- Inverse multiple component transformation types --- *)

		InverseMCT = OBJECT
			VAR
				mct : LONGINT;			(* The transformation type to be used *)
				invDWT : InverseDWT;	(* A reference to the wavelet tranformation object that will deliver data for us *)
				curTile : LONGINT;
				comp012 : POINTER TO ARRAY OF ARRAY OF DataBlkInt;
				comp012Info : POINTER TO ARRAY OF ARRAY OF J2KU.BlkInfo;
				decSpec : J2KCS.DecoderSpecs;
				nonRebuildBuffer : BOOLEAN;		(* Indicates wether the component data buffers shall be treated as rebuild or non-rebuild members *)
				transformRequired : POINTER TO ARRAY OF BOOLEAN;
				startLayer, endLayer, startDecLvl, endDecLvl : LONGINT;

			PROCEDURE &InitNew *(invMCTOpt : J2KU.InverseMCTOptions;
									invDWT : InverseDWT;
									decSpec : J2KCS.DecoderSpecs);
				BEGIN
					ReInit(invMCTOpt, invDWT, decSpec);
			END InitNew;

			PROCEDURE ReInit (	invMCTOpt : J2KU.InverseMCTOptions;
									invDWT : InverseDWT;
									decSpec : J2KCS.DecoderSpecs);
				VAR
					i, ntiles: LONGINT;
					imgInfo : J2KCS.ImageInfo;
				BEGIN
					SELF.invDWT := invDWT;
					SELF.decSpec := decSpec;
					imgInfo := decSpec.GetImageInfo();

					ntiles := imgInfo.GetNumTiles();

					NEW(comp012, ntiles, 3);
					NEW(comp012Info, ntiles, 3);
					nonRebuildBuffer := invMCTOpt.nonRebuildBuffer;

					(* Reconstruct the whole image by default *)
					startLayer := 0;
					endLayer := MAX(LONGINT);
					startDecLvl := MAX(LONGINT);
					endDecLvl := 0;

					NEW(transformRequired, ntiles);

					FOR i := 0 TO ntiles - 1 DO
						transformRequired[i] := TRUE;
					END;

			END ReInit;

			(**
				Sets the maximum layer range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested.
				This procedure shall NOT be called after the first code-block data
				has been read.

				maxStartLayer and maxEndLayer are inclusive.
			*)
			PROCEDURE SetMaxLayerRange (maxStartLayer, maxEndLayer : LONGINT);
				BEGIN
					invDWT.SetMaxLayerRange(maxStartLayer, maxEndLayer);
			END SetMaxLayerRange;

			(**
				Sets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE SetLayerRange (startLayer, endLayer : LONGINT);
				VAR
					i : LONGINT;
				BEGIN
					IF (startLayer # SELF.startLayer) OR (endLayer # SELF.endLayer) THEN
						FOR i := 0 TO LEN(transformRequired^) - 1 DO
							transformRequired[i] := TRUE;
						END;
					END;

					SELF.startLayer := startLayer;
					SELF.endLayer := endLayer;

					invDWT.SetLayerRange(startLayer, endLayer);
			END SetLayerRange;

			(**
				Gets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE GetLayerRange (VAR startLayer, endLayer : LONGINT);
				BEGIN
					invDWT.GetLayerRange(startLayer, endLayer);
			END GetLayerRange;

			(**
				Sets the maximum decomposition level range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested. This procedure
				shall NOT be called after the first code-block data has been read.

				maxStartDecLvl : The decompositon level to start at (inclusive) -> upper bound
				maxEndDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetMaxDecLevelRange (maxStartDecLvl, maxEndDecLvl : LONGINT);
				BEGIN
					invDWT.SetMaxDecLevelRange(maxStartDecLvl, maxEndDecLvl);
			END SetMaxDecLevelRange;

			(**
				Sets the decomposition level range for which data shall be delivered
				and decoded.

				startDecLvl : The decompositon level to start at (inclusive) -> upper bound
				endDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetDecLevelRange (startDecLvl, endDecLvl : LONGINT);
				VAR
					i : LONGINT;
				BEGIN
					IF (startDecLvl # SELF.startDecLvl) OR (endDecLvl # SELF.endDecLvl) THEN
						FOR i := 0 TO LEN(transformRequired^) - 1 DO
							transformRequired[i] := TRUE;
						END;
					END;

					SELF.startDecLvl := startDecLvl;
					SELF.endDecLvl := endDecLvl;

					invDWT.SetDecLevelRange(startDecLvl, endDecLvl);
			END SetDecLevelRange;

			(**
				Gets the decomposition level range for which data shall be delivered
				and decoded.

				startDecLvl : The decompositon level to start at (inclusive) -> upper bound
				endDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE GetDecLevelRange (VAR startDecLvl, endDecLvl : LONGINT);
				BEGIN
					startDecLvl := SELF.startDecLvl;
					endDecLvl := SELF.endDecLvl;
			END GetDecLevelRange;

			(* Adapts a component when no component transformation is done (e.g. converting REAL to LONGINT) *)
			PROCEDURE GetAdaptedComponent (component : LONGINT; VAR comp : DataBlk; VAR compInfo : J2KU.BlkInfo);
				VAR
					tmpComp : DataBlk;
					dataBlkInt : DataBlkInt;
					dataInt : J2KU.LongIntArrayPtr;
					dataReal : J2KU.RealArrayPtr;
					i, j, width, height, dataIdxReal, dataIdxInt, scanwReal, scanwInt : LONGINT;
				BEGIN
					invDWT.GetComponent(component, tmpComp, compInfo);

					IF tmpComp IS DataBlkInt THEN
						comp := tmpComp;
					ELSIF tmpComp IS DataBlkReal THEN
						(* Need to copy the data *)
						width := compInfo.width;
						height := compInfo.height;

						NEW(dataBlkInt);
						NEW(dataInt, width*height);
						dataBlkInt.offset := 0;
						dataBlkInt.scanw := width;
						dataBlkInt.data := dataInt;

						dataReal := tmpComp(DataBlkReal).data;
						dataIdxReal := tmpComp.offset;
						scanwReal := tmpComp.scanw;
						dataIdxInt := dataBlkInt.offset;
						scanwInt := dataBlkInt.scanw;

						FOR j := 0 TO height - 1 DO
							FOR i := 0 TO width - 1 DO
								(* arithmetic rounding used *)
								dataInt[dataIdxInt] := ENTIER(dataReal[dataIdxReal] + 0.5);

								INC(dataIdxReal);
								INC(dataIdxInt);
							END;
							dataIdxReal := dataIdxReal - width + scanwReal;
							dataIdxInt := dataIdxInt - width + scanwInt;
						END;

						comp := dataBlkInt;
					ELSE
						KernelLog.String("ERROR (InverseMCT.GetAdaptedComponent): Returned data block type not unsupported");
						KernelLog.Ln();
					END;
			END GetAdaptedComponent;

			PROCEDURE GetComponent (component : LONGINT; VAR comp : DataBlk; VAR compInfo : J2KU.BlkInfo);
				BEGIN
					IF (component >= 3) OR (mct = MCT_NONE) THEN
						GetAdaptedComponent(component, comp, compInfo);
					ELSE
						comp := comp012[curTile][component];
						compInfo := 	comp012Info[curTile][component];
					END;
			END GetComponent;

			PROCEDURE FullTransform () : BOOLEAN;
				BEGIN
					RETURN TransformStep();
			END FullTransform;

			(* Performs 1 transformation step. TransformStep = FullTransform in this implementation *)
			PROCEDURE TransformStep () : BOOLEAN;
				BEGIN
					(* Let the wavelet transformation perform a full reconstruction of the current tile-part *)
					IF ~invDWT.FullTransform() THEN
						RETURN FALSE;
					END;

					IF  transformRequired[curTile] OR nonRebuildBuffer THEN

						IF AllTilePartsRead() THEN
							transformRequired[curTile] := FALSE;
						END;

						CASE mct OF
								MCT_NONE :
									(* Don't do anything *)
									RETURN TRUE;
							|	MCT_RCT :
									RETURN InverseRCT();
							|	MCT_ICT :
									RETURN InverseICT();
							ELSE
								KernelLog.String("ERROR (InverseMCT.TransformStep) : Invalid component transformation specified");
								KernelLog.Ln();
								RETURN FALSE;
						END;
					END;

					RETURN TRUE;
			END TransformStep;

			PROCEDURE InitTile () : BOOLEAN;
				VAR
					ncomp, rev, i : LONGINT;
					imgInfo : J2KCS.ImageInfo;
				BEGIN
					imgInfo := decSpec.GetImageInfo();

					curTile := invDWT.CurrentTile();
					ncomp := imgInfo.GetNumComponents();

					(* Get the information on wether  a transformation is used or not *)
					IF (ncomp < 3) OR ~decSpec.CompTransUsed(curTile) THEN
						mct := MCT_NONE;
						RETURN TRUE;
					ELSE
						rev := 0;
						FOR i := 0 TO 2 DO
							IF decSpec.IsReversibleWavTrans(curTile, i) THEN
								INC(rev);
							END;
						END;

						IF rev = 3 THEN
							mct := MCT_RCT;
						ELSIF rev = 0 THEN
							mct := MCT_ICT;
						ELSE
							KernelLog.String("ERROR (InverseMCT.InitTile): First three components of tile ");
							KernelLog.Int(curTile, 0);
							KernelLog.String(" differ in reversibility -> can't perform inverse component transformation");
							KernelLog.Ln();
							mct := -1;
							RETURN FALSE;
						END;

						(* If this is the first tile-part we need to allocate buffers for the first 3 components *)
						IF invDWT.CurrentTilePart() = 0 THEN
							(* We allocate integer blocks because that's what we deliver *)
							FOR i := 0 TO 2 DO
								NEW(comp012[curTile][i]);
								comp012[curTile][i].data := NIL;
								NEW(comp012Info[curTile][i]);
							END;
						END;

						RETURN TRUE;
					END;
			END InitTile;

			PROCEDURE CurrentTile () : LONGINT;
				BEGIN
					RETURN invDWT.CurrentTile();
			END CurrentTile;

			PROCEDURE CurrentTilePart () : LONGINT;
				BEGIN
					RETURN invDWT.CurrentTilePart();
			END CurrentTilePart;

			PROCEDURE NextTilePart () : BOOLEAN;
				BEGIN
					IF ~invDWT.NextTilePart() THEN
						RETURN FALSE;
					END;

					RETURN InitTile();
			END NextTilePart;

			PROCEDURE AllTilePartsRead () : BOOLEAN;
				BEGIN
					RETURN invDWT.AllTilePartsRead();
			END AllTilePartsRead;


			PROCEDURE TilePartAvailable () : BOOLEAN;
				BEGIN
					RETURN invDWT.TilePartAvailable();
			END TilePartAvailable;

			PROCEDURE DataAvailable () : BOOLEAN;
				BEGIN
					RETURN invDWT.DataAvailable();
			END DataAvailable;

			PROCEDURE InverseRCT () : BOOLEAN;
				VAR
					tmpComp : ARRAY 3 OF DataBlk;
					data0, data1, data2, outData0, outData1, outData2 : J2KU.LongIntArrayPtr;
					dataLen, i, j, dataIdxOut, dataIdxIn : LONGINT;
					width, height, scanwOut, scanwIn : LONGINT;
				BEGIN
					(* Get the wavelet transformed components *)
					invDWT.GetComponent(0, tmpComp[0], comp012Info[curTile][0]);
					invDWT.GetComponent(1, tmpComp[1], comp012Info[curTile][1]);
					invDWT.GetComponent(2, tmpComp[2], comp012Info[curTile][2]);

					(* We assume that the data arrays of all components are of equal length *)
					(* If that's not the case, then don't proceed *)
					width := comp012Info[curTile][0].width;
					height := comp012Info[curTile][0].height;
					dataLen := width * height;

					IF (dataLen # (comp012Info[curTile][1].width*comp012Info[curTile][1].height)) OR (dataLen # (comp012Info[curTile][2].width*comp012Info[curTile][2].height)) THEN
						KernelLog.String("ERROR (InverseMCT.InverseRCT) : Transformation of components with different number of samples is not supported");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					data0 := tmpComp[0](DataBlkInt).data;
					data1 := tmpComp[1](DataBlkInt).data;
					data2 := tmpComp[2](DataBlkInt).data;

					outData0 := comp012[curTile][0].data;
					outData1 := comp012[curTile][1].data;
					outData2 := comp012[curTile][2].data;

					(* Allocate space in the internal buffer for each component, if not yet done *)
					(* NOTE:
						If the buffer of component 0 is NIL we assume that no transformation has been done,
						i.e. not before the current procedure call. We allocate the data for the other components
						as well. This is legitimate, if we do this everytime. We would get a problem if we'd only
						instantiate buffer for component 0. But that would mean that we didn't transform the
						other components, which would not make any sense (or would it?).
					*)
					IF  (outData0 = NIL) OR (LEN(outData0^) < dataLen) THEN
						NEW(outData0, dataLen);
						NEW(outData1, dataLen);
						NEW(outData2, dataLen);
						comp012[curTile][0].data := outData0;
						comp012[curTile][1].data := outData1;
						comp012[curTile][2].data := outData2;
						comp012[curTile][0].scanw := comp012Info[curTile][0].width;
						comp012[curTile][1].scanw := comp012Info[curTile][1].width;
						comp012[curTile][2].scanw := comp012Info[curTile][2].width;
						comp012[curTile][0].offset := 0;
						comp012[curTile][1].offset := 0;
						comp012[curTile][2].offset := 0;
					END;

					(* Perform the inverse transformation on all samples of each component *)
					dataIdxOut := comp012[curTile][0].offset;
					dataIdxIn := tmpComp[0].offset;
					scanwOut := comp012[curTile][0].scanw;
					scanwIn := tmpComp[0].scanw;

					FOR j := 0 TO height - 1 DO
						FOR i := 0 TO width - 1 DO
							outData1[dataIdxOut] := data0[dataIdxIn] - ASH(data2[dataIdxIn] + data1[dataIdxIn], -2);
							outData0[dataIdxOut] := data2[dataIdxIn] + outData1[dataIdxOut];
							outData2[dataIdxOut] := data1[dataIdxIn] + outData1[dataIdxOut];
							INC(dataIdxOut);
							INC(dataIdxIn);
						END;
						(* Go to next row *)
						dataIdxOut := dataIdxOut - width + scanwOut;
						dataIdxIn := dataIdxIn - width + scanwIn;
					END;

					RETURN TRUE;
			END InverseRCT;

			PROCEDURE InverseICT () : BOOLEAN;
				VAR
					tmpComp : ARRAY 3 OF DataBlk;
					data0, data1, data2 : J2KU.RealArrayPtr;
					outData0, outData1, outData2 : J2KU.LongIntArrayPtr;
					dataLen, i, j, dataIdxOut, dataIdxIn : LONGINT;
					width, height, scanwOut, scanwIn : LONGINT;
				BEGIN
					(* Get the wavelet transformed components *)
					invDWT.GetComponent(0, tmpComp[0], comp012Info[curTile][0]);
					invDWT.GetComponent(1, tmpComp[1], comp012Info[curTile][1]);
					invDWT.GetComponent(2, tmpComp[2], comp012Info[curTile][2]);

					(* We assume that the data arrays of all components are of equal length *)
					(* If that's not the case, then don't proceed *)
					width := comp012Info[curTile][0].width;
					height := comp012Info[curTile][0].height;
					dataLen := width * height;

					IF (dataLen # (comp012Info[curTile][1].width*comp012Info[curTile][1].height)) OR (dataLen # (comp012Info[curTile][2].width*comp012Info[curTile][2].height)) THEN
						KernelLog.String("ERROR (InverseMCT.InverseRCT) : Transformation of components with different number of samples is not supported");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					data0 := tmpComp[0](DataBlkReal).data;
					data1 := tmpComp[1](DataBlkReal).data;
					data2 := tmpComp[2](DataBlkReal).data;

					outData0 := comp012[curTile][0].data;
					outData1 := comp012[curTile][1].data;
					outData2 := comp012[curTile][2].data;

					(* Allocate space in the internal buffer for each component, if not yet done *)
					(* NOTE:
						If the buffer of component 0 is NIL we assume that no transformation has been done,
						i.e. not before the current procedure call. We allocate the data for the other components
						as well. This is legitimate, if we do this everytime. We would get a problem if we'd only
						instantiate buffer for component 0. But that would mean that we didn't transform the
						other components, which would not make any sense (or would it?).
					*)
					IF  (outData0 = NIL) OR (LEN(outData0^) < dataLen) THEN
						NEW(outData0, dataLen);
						NEW(outData1, dataLen);
						NEW(outData2, dataLen);
						comp012[curTile][0].data := outData0;
						comp012[curTile][1].data := outData1;
						comp012[curTile][2].data := outData2;
						comp012[curTile][0].scanw := comp012Info[curTile][0].width;
						comp012[curTile][1].scanw := comp012Info[curTile][1].width;
						comp012[curTile][2].scanw := comp012Info[curTile][2].width;
						comp012[curTile][0].offset := 0;
						comp012[curTile][1].offset := 0;
						comp012[curTile][2].offset := 0;
					END;

					(* Perform the inverse transformation on all samples of each component *)
					dataIdxOut := comp012[curTile][0].offset;
					dataIdxIn := tmpComp[0].offset;
					scanwOut := comp012[curTile][0].scanw;
					scanwIn := tmpComp[0].scanw;

					FOR j := 0 TO height - 1 DO
						FOR i := 0 TO width - 1 DO
							(* Use rounding: floor(x+0.5) *)
							outData0[dataIdxOut] := ENTIER(data0[dataIdxIn] + 1.402*data2[dataIdxIn] + 0.5);
							outData1[dataIdxOut] := ENTIER(data0[dataIdxIn] - 0.34413*data1[dataIdxIn] - 0.71414*data2[dataIdxIn] + 0.5);
							outData2[dataIdxOut] := ENTIER(data0[dataIdxIn] + 1.772*data1[dataIdxIn] + 0.5);
							INC(dataIdxOut);
							INC(dataIdxIn);
						END;
						(* Go to next row *)
						dataIdxOut := dataIdxOut - width + scanwOut;
						dataIdxIn := dataIdxIn - width + scanwIn;
					END;

					RETURN TRUE;
			END InverseICT;


			PROCEDURE SetReBuildMode;
				BEGIN
					invDWT.SetReBuildMode();
			END SetReBuildMode;

			PROCEDURE FreeNonRebuildResources;
				VAR
					imgInfo : J2KCS.ImageInfo;
					ntiles, i : LONGINT;
				BEGIN
					imgInfo := decSpec.GetImageInfo();
					ntiles := imgInfo.GetNumTiles();

					IF nonRebuildBuffer THEN
						(* Free components and infos *)
						FOR i := 0 TO ntiles - 1 DO
							IF comp012[i][0] # NIL THEN
								comp012[i][0].data := NIL;
								comp012[i][1].data := NIL;
								comp012[i][2].data := NIL;
								comp012Info[i][0] := NIL;
								comp012Info[i][1] := NIL;
								comp012Info[i][2] := NIL;
							END;
						END;
					END;

					invDWT.FreeNonRebuildResources();
			END FreeNonRebuildResources;

			PROCEDURE FreeResources;
				BEGIN
					comp012 := NIL;
					comp012Info := NIL;
					transformRequired := NIL;
					invDWT.FreeResources();
			END FreeResources;

		END InverseMCT;


		(* --- END Inverse multiple component transformation types --- *)


		(* --- JP2 File Format types --- *)

	(*
		(* This shall be the interface for applications requesting data contained in boxes. 'data' will only contain raw data, but no subboxes *)
		JP2BoxHandler* = PROCEDURE {DELEGATE} (boxType : LONGINT; boxData : J2K.ByteArrayPtr; boxDataLen : HUGEINT; VAR abort : BOOLEAN);
	*)

		JP2Box = OBJECT
			VAR
				type : LONGINT;
		END JP2Box;

		(** Container for a codestream found in a JP2 file *)
		CodestreamBox = OBJECT(JP2Box)
			VAR
				s : Streams.Reader;

			PROCEDURE &InitNew*;
				BEGIN
					type := JP2CCST;
			END InitNew;
		END CodestreamBox;

	TYPE
		JP2FileFormatReader = OBJECT
			VAR
				s : Streams.Reader;
				isJP2 : BOOLEAN;
				initError : BOOLEAN;
				lastBoxFound, jp2HeaderBoxFound : BOOLEAN;
				curBoxType : LONGINT;
				curBoxLen, curBoxContLen : HUGEINT;	(* current box length: total & content length *)

			PROCEDURE & InitNew *(s : Streams.Reader);
				BEGIN
					ReInit(s);
			END InitNew;

			PROCEDURE ReInit (s : Streams.Reader);
				VAR
					signature : LONGINT;
				BEGIN
					SELF.s := s;

					(* First we need to check if the stream contains a JP2 file *)

					(* --- JPEG 2000 Signature box --- *)
					(* Check if it's possible that this is a JP2 file -> just peek *)
					(* First byte should be 0x00 *)
					IF ORD(s.Peek()) # 00H THEN
						isJP2 := FALSE;
						lastBoxFound := TRUE;
						initError := FALSE;
						RETURN;
					END;

					(* Now we need to actually read from the stream because we still don't know if it's a JP2 file *)
					(* Read the first 12 bytes. They should be 0x0000 000C 6A50 2020 0D0A 870A *)
					ReadBoxInfo();

					(* --- DBox --- *)
					signature := s.Net32();

					IF	(curBoxLen # 12)
						OR (curBoxType # JP2SIGN)
						OR (signature # 0D0A870AH)
					THEN
						isJP2 := FALSE;
						lastBoxFound := TRUE;
						(*
							Issue an error, because we have already read from the stream, and
							there is no JPEG 2000 - Part 1 conforming data anyway.
						*)
						KernelLog.String("ERROR: Not a valid JPEG 2000 - Part 1 file/stream");
						KernelLog.Ln();
						initError := TRUE;
						RETURN;
					END;

					(* The checks till now have convinced us that it's a JP2 file *)
					isJP2 := TRUE;
					lastBoxFound := FALSE;
					jp2HeaderBoxFound := FALSE;

					(* --- File Type box --- *)
					ReadBoxInfo();

					IF curBoxType # JP2FTYP THEN
						KernelLog.String("ERROR (JP2FileFormatReader.ReInit): Invalid box type (read: '");
						KernelLog.Hex(curBoxType, 0);
						KernelLog.String("'; required: '");
						KernelLog.Hex(JP2FTYP, 0);
						KernelLog.String("', i.e. File Type box)");
						KernelLog.Ln();
						initError := TRUE;
						RETURN;
					END;

					initError := ~ReadFileTypeBox();
			END ReInit;

			PROCEDURE InitError () : BOOLEAN;
				BEGIN
					RETURN initError;
			END InitError;

			PROCEDURE IsJP2File () : BOOLEAN;
				BEGIN
					RETURN isJP2;
			END IsJP2File;

			(** Reads box type and length *)
			PROCEDURE ReadBoxInfo;
				VAR
					tmp : LONGINT;
				BEGIN
					(* --- LBox --- *)
					curBoxLen := s.Net32();

					(* --- TBox --- *)
					curBoxType := s.Net32();

					IF curBoxLen = 0 THEN
						curBoxLen := s.Available() + 8;
						curBoxContLen := s.Available();
						lastBoxFound := TRUE;
					ELSIF curBoxLen = 1 THEN
						(* --- XLBox --- *)
						tmp := LSH(s.Net32(), 32);
						curBoxLen := tmp + s.Net32();
						curBoxContLen := curBoxLen - 16;
					ELSE
						curBoxContLen := curBoxLen - 8;
					END;
			END ReadBoxInfo;


			PROCEDURE ReadFileTypeBox () : BOOLEAN;
				VAR
					br, minV : LONGINT;
					clLength : HUGEINT;	(* Length of compatibility list (i.e. the number of list entries) *)
					jp2Comp : BOOLEAN;
				BEGIN

					IF ~HasNextBox() THEN
						(* This can not be the last box *)
						KernelLog.String("ERROR (JP2FileFormatReader.ReadFileTypeBox): File Type box is last in file");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					(* --- BR --- *)
					br := s.Net32();	(* NOTE: Unused *)

					(* --- MinV --- *)
					minV := s.Net32();	(* NOTE: Unused *)

					(* --- CLi --- *)
					clLength := LSH(curBoxContLen - 8, -2);

					(* Compatibility list must at least contain 1 element *)
					IF clLength <= 0 THEN
						KernelLog.String("ERROR (JP2FileFormatReader.ReadFileTypeBox): Empty compatibility list");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					(* Check that there is at least one JP2-FTBRAND entry in the compatibility list *)
					jp2Comp := FALSE;

					WHILE clLength > 0 DO
						IF s.Net32() = JP2_FTBRAND THEN
							jp2Comp := TRUE;
						END;

						DEC(clLength);
					END;

					IF ~jp2Comp THEN
						KernelLog.String("ERROR (JP2FileFormatReader.ReadFileTypeBox): Compatibility list does not contain JPEG 2000 - Part 1");
						KernelLog.Ln();
					END;

					RETURN jp2Comp;
			END ReadFileTypeBox;

			PROCEDURE ReadJP2HeaderBox (VAR box : JP2Box) : BOOLEAN;
				VAR
					headerBoxLen, nColSpecBox : HUGEINT;
					ok : BOOLEAN;
				BEGIN
					(* We just skip the header *)
					(*
						Just check that there is an Image Header box and at least 1 Colour Specification box.
						Don't return any content.
					*)
					box := NIL;

					IF ~HasNextBox() THEN
						KernelLog.String("ERROR (JP2FileFormatReader.ReadJP2HeaderBox): JP2 Header box is last box in file");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					headerBoxLen := curBoxContLen;

					(* Read next box *)
					ReadBoxInfo();

					IF curBoxType # JP2IHDR THEN
						KernelLog.String("ERROR (JP2FileFormatReader.ReadJP2HeaderBox): Image Header box not first box in JP2 Header box");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					ok := SkipBox();
					DEC(headerBoxLen, curBoxLen);

					nColSpecBox := 0;

					WHILE ok & (headerBoxLen > 0) DO
						ReadBoxInfo();

						IF curBoxType =  JP2BPCC THEN
							(* Nothing to do (yet) *)
						ELSIF curBoxType = JP2COLR THEN
							INC(nColSpecBox);
						ELSIF curBoxType = JP2PCLR THEN
							(* Nothing to do (yet) *)
						ELSIF curBoxType = JP2CMAP THEN
							(* Nothing to do (yet) *)
						ELSIF curBoxType = JP2CDEF THEN
							(* Nothing to do (yet) *)
						ELSIF curBoxType = JP2RESL THEN
							(* Nothing to do (yet) *)
						ELSE
							KernelLog.String("NOTICE: Unknown/unexpected JP2 box type found within JP2 Header box: ");
							KernelLog.Hex(curBoxType, 0);
							KernelLog.Ln();
						END;

						ok := SkipBox();
						DEC(headerBoxLen, curBoxLen);
					END;

					IF ok & (nColSpecBox <= 0) THEN
						KernelLog.String("ERROR (JP2FileFormatReader.ReadJP2HeaderBox): No Colour Specification box found");
						KernelLog.Ln();
						ok := FALSE;
					END;

					RETURN ok;
			END ReadJP2HeaderBox;

			(* TODO: Maybe we should copy the stream *)
			(**
				Just returns a reference to the stream. So it is assumed that the codestream
				will be processed before a the next call to NextBox.
			*)
			PROCEDURE ReadContiguousCodestreamBox (VAR box : JP2Box) : BOOLEAN;
				VAR
					ccBox : CodestreamBox;
				BEGIN
					NEW(ccBox);
					ccBox.s := SELF.s;
					box := ccBox;
					RETURN TRUE;
			END ReadContiguousCodestreamBox;

			PROCEDURE ReadIPRBox (VAR box : JP2Box) : BOOLEAN;
				BEGIN
					(* We just skip this box *)
					box := NIL;
					RETURN SkipBox();
			END ReadIPRBox;

			PROCEDURE ReadXMLBox (VAR box : JP2Box) : BOOLEAN;
				BEGIN
					(* We just skip this box *)
					box := NIL;
					RETURN SkipBox();
			END ReadXMLBox;

			PROCEDURE ReadUUIDBox (VAR box : JP2Box) : BOOLEAN;
				BEGIN
					(* We just skip this box *)
					box := NIL;
					RETURN SkipBox();
			END ReadUUIDBox;

			PROCEDURE ReadUUIDInfoBox (VAR box : JP2Box) : BOOLEAN;
				BEGIN
					(* We just skip this box *)
					box := NIL;
					RETURN SkipBox();
			END ReadUUIDInfoBox;

			PROCEDURE HasNextBox () : BOOLEAN;
				BEGIN
					RETURN ~initError & ~lastBoxFound & (s.Available() >= 8);
			END HasNextBox;

			PROCEDURE NextBox (VAR boxtype : LONGINT; VAR length : HUGEINT) : BOOLEAN;
				BEGIN
					IF ~HasNextBox() THEN
						KernelLog.String("ERROR (JP2FileFormatReader.NextBox): No (more) JP2 boxes available");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					ReadBoxInfo();

					(* Determine box type and check constraints *)
					IF curBoxType = JP2HEAD THEN
						IF jp2HeaderBoxFound THEN
							KernelLog.String("ERROR (JP2FileFormatReader.NextBox): Multiple JP2 Header boxes found");
							KernelLog.Ln();
							RETURN FALSE;
						ELSE
							jp2HeaderBoxFound := TRUE;
						END;
					ELSIF curBoxType = JP2CCST THEN
						IF ~jp2HeaderBoxFound THEN
							KernelLog.String("ERROR (JP2FileFormatReader.NextBox): JP2 Header box not found before Contiguous codestream box");
							KernelLog.Ln();
							RETURN FALSE;
						END;
					ELSIF curBoxType = JP2INPR THEN
						(* No constraints (yet) *)
					ELSIF curBoxType = JP2XMLD THEN
						(* No constraints (yet) *)
					ELSIF curBoxType = JP2UUID THEN
						(* No constraints (yet) *)
					ELSIF curBoxType = JP2UINF THEN
						(* No constraints (yet) *)
					ELSE
						KernelLog.String("NOTICE: Unknown/unexpected JP2 box type found in file: ");
						KernelLog.Hex(curBoxType, 0);
						KernelLog.Ln();
					END;

					boxtype := curBoxType;
					length := curBoxContLen;
					RETURN TRUE;
			END NextBox;

			PROCEDURE GetBoxContent (VAR box : JP2Box) : BOOLEAN;
				BEGIN
					(* Determine box type and check constraints *)
					IF curBoxType = JP2HEAD THEN
						RETURN ReadJP2HeaderBox(box);

					ELSIF curBoxType = JP2CCST THEN
						RETURN ReadContiguousCodestreamBox(box);

					ELSIF curBoxType = JP2INPR THEN
						RETURN ReadIPRBox(box);

					ELSIF curBoxType = JP2XMLD THEN
						RETURN ReadXMLBox(box);

					ELSIF curBoxType = JP2UUID THEN
						RETURN ReadUUIDBox(box);

					ELSIF curBoxType = JP2UINF THEN
						RETURN ReadUUIDInfoBox(box);

					ELSE
						(* Unknown box -> skip it *)
						box := NIL;
						RETURN SkipBox();
					END;
			END GetBoxContent;

			PROCEDURE SkipBox () : BOOLEAN;
				BEGIN
					WHILE curBoxContLen > MAX(LONGINT) DO
						s.SkipBytes(MAX(LONGINT));
						DEC(curBoxContLen, MAX(LONGINT));
					END;

					s.SkipBytes(SHORT(curBoxContLen));

					RETURN TRUE;
			END SkipBox;

			(**
				Gets the (first) codestream embedded in the file, if any, and ignores
				all other boxes (i.e. skips them). When soon as the first codestream is
				found this method returns (or NIL if no codestream was found).

				NOTE:
				This method delivers a reference to its own stream object (i.e. the stream
				object to which a reference was given at construction time of this JP2FileFormatReader).
				So it's possible that at the end of a codestream some other data is appended,
				i.e. the remainder of the file.
			*)
			PROCEDURE GetCodestream () : Streams.Reader;
				VAR
					s : Streams.Reader;
					noCodestream : BOOLEAN;
					box : JP2Box;
					boxType : LONGINT;
					boxLen : HUGEINT;
				BEGIN
					s := NIL;
					noCodestream := TRUE;

					WHILE noCodestream & HasNextBox() DO

						IF ~NextBox(boxType, boxLen) THEN
							(* Return on error *)
							RETURN NIL;
						END;

						IF boxType = JP2CCST THEN
							(* Codestream found *)
							noCodestream := FALSE;

							IF GetBoxContent(box) THEN
								ASSERT(box.type = boxType);
								s := box(CodestreamBox).s;
							END;
						ELSE
							(* Skip the box *)
							IF ~SkipBox() THEN
								(* Return on error *)
								RETURN NIL;
							END;
						END;
					END;

					IF noCodestream THEN
						KernelLog.String("ERROR (JP2FileFormatReader.GetCodestream): No codestream found");
						KernelLog.Ln();
					END;

					RETURN s;
			END GetCodestream;

			PROCEDURE FreeResources;
				BEGIN
					s := NIL;
			END FreeResources;


		END JP2FileFormatReader;

		(* --- END JP2 File Format types --- *)


	CONST
		(** Image production status values (so that image consumers may be informed) *)
		PROD_FAILED* = -1;
		PROD_DONE* = 1;

	TYPE
		(**
			Interface for image consumers
		*)
		ImageConsumer* = OBJECT
			(** Set specific pixels *)
			PROCEDURE SetPixels*(pixelData : J2KU.LongIntArrayPtr; xOffset, yOffset, width, height : LONGINT);
			END SetPixels;

			(** Called by image producer to inform about production status *)
			PROCEDURE SetProductionStatus* (status : LONGINT);
			END SetProductionStatus;

		END ImageConsumer;

		ImageProducer = OBJECT
			VAR
				imgFmt : LONGINT;
				src : InverseMCT;
				producedOnce : BOOLEAN;
				imgInfo : J2KCS.ImageInfo;

			PROCEDURE &InitNew*;
				BEGIN
					src := NIL;
					imgFmt := -1;
			END InitNew;

			(* Initializes the image production (determines format & does some checks) *)
			PROCEDURE InitProduction (src : InverseMCT; imgInfo : J2KCS.ImageInfo) : BOOLEAN;
				VAR
					ncomp : LONGINT;
					imgWidth, imgHeight, i : LONGINT;
					compWidth, compHeight : LONGINT;
				BEGIN
					producedOnce := FALSE;

					SELF.src := src;
					SELF.imgInfo := imgInfo;

					ncomp := imgInfo.GetNumComponents();

					(* Determine basic image type *)
					CASE ncomp OF
							1 :
								imgFmt := Codecs.ImgFmtGrey;
						|	3:
								imgFmt := Codecs.ImgFmtRGB;
						|
							4:
								imgFmt := Codecs.ImgFmtRGBA;
						ELSE
							imgFmt := -1;
							KernelLog.String("ERROR (ImageProducer.InitProduction) : Only 1, 3 and 4 components supported currently");
							KernelLog.Ln();
							RETURN FALSE;
					END;

					(* Get image heigth and width *)
					imgWidth := imgInfo.GetImgWidth(0);
					imgHeight := imgInfo.GetImgHeight(0);

					(* Check component sizes and bit-depths *)
					FOR i := 0 TO ncomp - 1 DO
						compWidth := imgInfo.GetCompImgWidth(i, 0);
						compHeight := imgInfo.GetCompImgHeight(i, 0);

						IF (compWidth # imgWidth) OR (compHeight # imgHeight) THEN
							KernelLog.String("ERROR (ImageProducer.InitProduction) : Component subsampling not supported (yet)");
							KernelLog.Ln();
							RETURN FALSE;
						ELSIF imgInfo.GetBitDepth(i) > 8 THEN
							KernelLog.String("ERROR (ImageProducer.InitProduction) : Component bit-depths greater than 8 bits not supported (yet)");
							KernelLog.Ln();
							RETURN FALSE;
						END;
					END;

					RETURN TRUE;
			END InitProduction;

			(* Delivers the image to the image consumers *)
			PROCEDURE ProduceImage (VAR consumers : ARRAY OF ImageConsumer; offset, nconsumer : LONGINT);
				VAR
					ok : BOOLEAN;
					comp : ARRAY 4 OF DataBlkInt; 			(* References to the components *)
					compInfo : ARRAY 4 OF J2KU.BlkInfo;
					data : ARRAY 4 OF J2KU.LongIntArrayPtr;
					maxVal0, maxVal1, maxVal2, maxVal3 : LONGINT;	(* The maximum value of each component sample *)
					levShift0, levShift1, levShift2, levShift3 : LONGINT;		(* The value for the DC level shifting for each component *)
					tmp, tmp0, tmp1, tmp2, tmp3 : LONGINT;
					tileOffX, tileOffY : LONGINT;
					width, height : LONGINT;
					lineBuf : J2KU.LongIntArrayPtr;
					ncomp : LONGINT;
					t, c, i, w, h : LONGINT;
					pos, scanw, rowWrap : LONGINT;
					tmpBlk : DataBlk;
					dummy, curDecLvl : LONGINT;
					status : LONGINT;
				BEGIN

					status := PROD_FAILED;
					ncomp := 0;

					(* Get the maximum value of each component and the level shift *)
					CASE imgFmt OF
							Codecs.ImgFmtGrey :
								tmp := imgInfo.GetBitDepth(0);	(* This returns the original component bit-depth, before any transformation has been done *)
								maxVal0 := LSH(SYSTEM.VAL(LONGINT, 1), tmp) - 1;
								levShift0 := LSH(SYSTEM.VAL(LONGINT, 1), tmp - 1);
								ncomp := 1;
						|	Codecs.ImgFmtRGB :
								tmp := imgInfo.GetBitDepth(0);	(* This returns the original component bit-depth, before any transformation has been done *)
								maxVal0 := LSH(SYSTEM.VAL(LONGINT, 1), tmp) - 1;
								levShift0 := LSH(SYSTEM.VAL(LONGINT, 1), tmp - 1);
								tmp := imgInfo.GetBitDepth(1);
								maxVal1 := LSH(SYSTEM.VAL(LONGINT, 1), tmp) - 1;
								levShift1 := LSH(SYSTEM.VAL(LONGINT, 1), tmp - 1);
								tmp := imgInfo.GetBitDepth(2);
								maxVal2 := LSH(SYSTEM.VAL(LONGINT, 1), tmp) - 1;
								levShift2 := LSH(SYSTEM.VAL(LONGINT, 1), tmp - 1);
								ncomp := 3;
						|	Codecs.ImgFmtRGBA :
								tmp := imgInfo.GetBitDepth(0);	(* This returns the original component bit-depth, before any transformation has been done *)
								maxVal0 := LSH(SYSTEM.VAL(LONGINT, 1), tmp) - 1;
								levShift0 := LSH(SYSTEM.VAL(LONGINT, 1), tmp - 1);
								tmp := imgInfo.GetBitDepth(1);
								maxVal1 := LSH(SYSTEM.VAL(LONGINT, 1), tmp) - 1;
								levShift1 := LSH(SYSTEM.VAL(LONGINT, 1), tmp - 1);
								tmp := imgInfo.GetBitDepth(2);
								maxVal2 := LSH(SYSTEM.VAL(LONGINT, 1), tmp) - 1;
								levShift2 := LSH(SYSTEM.VAL(LONGINT, 1), tmp - 1);
								tmp := imgInfo.GetBitDepth(3);
								maxVal3 := LSH(SYSTEM.VAL(LONGINT, 1), tmp) - 1;
								levShift3 := LSH(SYSTEM.VAL(LONGINT, 1), tmp - 1);
								ncomp := 4;
						ELSE
							KernelLog.String("ERROR (ImageProducer.ProduceImage) : Invalid image format encounterd");
							KernelLog.Ln();
							(* Inform image consumers *)
							FOR i := offset TO (offset + nconsumer - 1) DO
								consumers[i].SetProductionStatus(status);
							END;

							RETURN;
					END;

					IF producedOnce THEN
						src.SetReBuildMode();
					END;

					(* We let the source process the entire codestream *)
					LOOP
						ok := src.NextTilePart();

						IF ~ok THEN
							IF ~src.DataAvailable() THEN
								status := PROD_DONE;
							END;

							EXIT;
						END;

						ok := src.FullTransform();

						IF ok THEN
							(* The transformation has succeeded and the components should now be ready *)
							t := src.CurrentTile();

							FOR c := 0 TO ncomp - 1 DO
								src.GetComponent(c, tmpBlk, compInfo[c]);
								comp[c] := tmpBlk(DataBlkInt);
								data[c] := comp[c].data;
							END;

							src.GetDecLevelRange(dummy, curDecLvl);

							width := compInfo[0].width;
							height := compInfo[0].height;
							tileOffX := compInfo[0].ulx - imgInfo.GetImgULX(curDecLvl);
							tileOffY := compInfo[0].uly - imgInfo.GetImgULY(curDecLvl);

							NEW(lineBuf, width);

							(*
								NOTE: We assume the same scan width for all components.
								This is reasonable, since we don't allow any component subsampling (yet),
								and we may assume that all components (in terms of data structure and memory
								allocation) are all treated the same way by the data source.
							*)
							scanw := comp[0].scanw;
							pos := comp[0].offset;
							rowWrap := scanw - width;

							FOR h := 0 TO height - 1 DO
								CASE imgFmt OF
									|	Codecs.ImgFmtGrey :
											FOR w := 0 TO width - 1 DO
												tmp0 := data[0][pos] + levShift0;

												IF tmp0 > maxVal0 THEN
													tmp0 := maxVal0;
												ELSIF tmp0 < 0 THEN
													tmp0 := 0;
												END;
												lineBuf[w] := SYSTEM.VAL(LONGINT,
																			SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 000000FFH), 24))
																			+ SYSTEM.VAL(SET, LSH(tmp0, 16))
																			+ SYSTEM.VAL(SET, LSH(tmp0, 8))
																			+ SYSTEM.VAL(SET, tmp0));
												INC(pos);
											END;

											INC(pos, rowWrap);
									|	Codecs.ImgFmtRGB :

											FOR w := 0 TO width - 1 DO
												tmp0 := data[0][pos] + levShift0;
												tmp1 := data[1][pos] + levShift1;
												tmp2 := data[2][pos] + levShift2;

												IF tmp0 > maxVal0 THEN
													tmp0 := maxVal0;
												ELSIF tmp0 < 0 THEN
													tmp0 := 0;
												END;

												IF tmp1 > maxVal1 THEN
													tmp1 := maxVal1;
												ELSIF tmp1 < 0 THEN
													tmp1 := 0;
												END;

												IF tmp2 > maxVal2 THEN
													tmp2 := maxVal2;
												ELSIF tmp2 < 0 THEN
													tmp2 := 0;
												END;
												lineBuf[w] := SYSTEM.VAL(LONGINT,
																			SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 000000FFH), 24))
																			+ SYSTEM.VAL(SET, LSH(tmp0, 16))
																			+ SYSTEM.VAL(SET, LSH(tmp1, 8))
																			+ SYSTEM.VAL(SET, tmp2));
												INC(pos);
											END;

											INC(pos, rowWrap);

									|	Codecs.ImgFmtRGBA :

											FOR w := 0 TO width - 1 DO
												tmp0 := data[0][pos] + levShift0;
												tmp1 := data[1][pos] + levShift1;
												tmp2 := data[2][pos] + levShift2;
												tmp3 := data[3][pos] + levShift3;

												IF tmp0 > maxVal0 THEN
													tmp0 := maxVal0;
												ELSIF tmp0 < 0 THEN
													tmp0 := 0;
												END;

												IF tmp1 > maxVal1 THEN
													tmp1 := maxVal1;
												ELSIF tmp1 < 0 THEN
													tmp1 := 0;
												END;

												IF tmp2 > maxVal2 THEN
													tmp2 := maxVal2;
												ELSIF tmp2 < 0 THEN
													tmp2 := 0;
												END;

												IF tmp3 > maxVal3 THEN
													tmp3 := maxVal3;
												ELSIF tmp3 < 0 THEN
													tmp3 := 0;
												END;
												lineBuf[w] := SYSTEM.VAL(LONGINT,
																			SYSTEM.VAL(SET, LSH(tmp0, 24))
																			+ SYSTEM.VAL(SET, LSH(tmp1, 16))
																			+ SYSTEM.VAL(SET, LSH(tmp2, 8))
																			+ SYSTEM.VAL(SET, tmp3));

												INC(pos);
											END;

											INC(pos, rowWrap);

								END;	(* NOTE: No "ELSE" case needed here since we already checked above *)

								FOR i := offset TO (offset + nconsumer - 1) DO
									consumers[i].SetPixels(lineBuf, tileOffX, tileOffY + h, width, 1);
								END;

							END;
						ELSE
							(* Transformation failed -> abort *)
							status := PROD_FAILED;
							EXIT;
						END;
					END;

					IF ~producedOnce THEN
						producedOnce := TRUE;
						src.FreeNonRebuildResources();
					END;

					(* Inform image consumers *)
					FOR i := offset TO (offset + nconsumer - 1) DO
						consumers[i].SetProductionStatus(status);
					END;
			END ProduceImage;

			PROCEDURE GetImgFormat () : LONGINT;
				BEGIN
					RETURN imgFmt;
			END GetImgFormat;

		END ImageProducer;


		InternalToRaster = PROCEDURE {DELEGATE} (pixelBuf : J2KU.LongIntArrayPtr; xOffset, yOffset, length : LONGINT);

		(* An adapter for Raster.Image *)
		RasterImageAdapter* = OBJECT(ImageConsumer)
			VAR
				img : Raster.Image;
				imgFmt : LONGINT;
				transform : InternalToRaster;

			PROCEDURE &InitNew* (img : Raster.Image);
				BEGIN
					SELF.img := img;

					CASE img.fmt.code OF
						|	Raster.bgr565 :
								transform := SetPixelsRGB565;
						|	Raster.bgr888 :
								transform := SetPixelsRGB888;
						|	Raster.bgra8888 :
								transform := SetPixelsRGBA8888;
						ELSE
							KernelLog.String("ERROR: Raster image type ");
							KernelLog.Int(img.fmt.code, 0);
							KernelLog.String(" not supported (yet)");
							KernelLog.Ln();
							transform := SetPixelsNIL;
					END;
			END InitNew;


			PROCEDURE SetFormat* (fmt : LONGINT);
				BEGIN
					imgFmt := fmt;
			END SetFormat;

			PROCEDURE SetPixels*(pixelData : J2KU.LongIntArrayPtr; xOffset, yOffset, width, height : LONGINT);
				VAR
					len : LONGINT;
				BEGIN

					len := width * height;

					transform(pixelData, xOffset, yOffset, len);
			END SetPixels;


			PROCEDURE SetPixelsRGB565 (pixelBuf : J2KU.LongIntArrayPtr; xOffset, yOffset, length : LONGINT);
				VAR
					adr: ADDRESS; int, i : LONGINT;
					r, g, b : LONGINT;
				BEGIN
					adr := img.adr + (img.width*yOffset + xOffset)*2;

					FOR i := 0 TO length - 1 DO
						IF (SYSTEM.VAL(SET, LSH(pixelBuf[i], -24)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 000000FFH) ))# {} THEN	(* model alpha as brightness *)
							r := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET,LSH(pixelBuf[i], -16)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 000000FFH)));
							g := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET,LSH(pixelBuf[i], -8)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 000000FFH)));
							b := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, pixelBuf[i]) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 000000FFH)));
							int := LSH(b, -3) + LSH(LSH(g, -2), 5) + LSH(LSH(r, -3), 11);
							SYSTEM.PUT(adr, CHR(int)); SYSTEM.PUT(adr+1, CHR(LSH(int, -8)));
						END;
						INC(adr, 2);
					END;

			END SetPixelsRGB565;

			PROCEDURE SetPixelsRGB888 (pixelBuf : J2KU.LongIntArrayPtr; xOffset, yOffset, length : LONGINT);
				VAR
					adr: ADDRESS; i : LONGINT;
				BEGIN
					adr := img.adr + (img.width*yOffset + xOffset)*3;

					FOR i := 0 TO length - 1 DO
						IF (SYSTEM.VAL(SET, pixelBuf[i]) * {23..31}) # {} THEN		(* model alpha as brightness *)
							SYSTEM.PUT(adr, CHR(pixelBuf[i]));
							SYSTEM.PUT(adr + 1, CHR(LSH(pixelBuf[i], -8)));
							SYSTEM.PUT(adr + 2, CHR(LSH(pixelBuf[i], -16)));
						END;
						INC(adr, 3);
					END;

			END SetPixelsRGB888;

			PROCEDURE SetPixelsRGBA8888 (pixelBuf : J2KU.LongIntArrayPtr; xOffset, yOffset, length : LONGINT);
				VAR
					adr: ADDRESS; i : LONGINT;
				BEGIN
					adr := img.adr + (img.width*yOffset + xOffset)*4;

					FOR i := 0 TO length - 1 DO
						SYSTEM.PUT(adr, CHR(pixelBuf[i]));
						SYSTEM.PUT(adr + 1, CHR(LSH(pixelBuf[i], -8)));
						SYSTEM.PUT(adr + 2, CHR(LSH(pixelBuf[i], -16)));
						SYSTEM.PUT(adr + 3, CHR(LSH(pixelBuf[i], -24)));
						INC(adr, 4);
					END;
			END SetPixelsRGBA8888;


			(** NIL handler *)
			PROCEDURE SetPixelsNIL (pixelBuf : J2KU.LongIntArrayPtr; xOffset, yOffset, length : LONGINT);
					(* Don't do anything *)
			END SetPixelsNIL;

		END RasterImageAdapter;


		(* --- Decoder types --- *)


		Decoder* = OBJECT(Codecs.ImageDecoder);
			VAR
				decOpt : J2KU.DecoderOptions;
				decSpec : J2KCS.DecoderSpecs;

				fr : JP2FileFormatReader;
				cr : J2KCS.CodestreamReader;
				ed : EntropyDecoder;
				roi : ROIDescaler;
				deq : Dequantizer;
				invDWT : InverseDWT;
				invMCT : InverseMCT;

				imgProd : ImageProducer;

				ready : BOOLEAN;
				deliveredOnce : BOOLEAN;	(* Indicates if the current (open) image stream has been reconstructed (delivered) at least once *)
				minResDec, minLayDec : LONGINT;

			PROCEDURE &InitNew* (decOpt : J2KU.DecoderOptions);
				BEGIN
					SELF.decOpt := decOpt;
					ready := FALSE;
			END InitNew;

			(* --- Codecs.ImageDecoder methods --- *)

			(* open the decoder on a file *)
			PROCEDURE Open*(s : Streams.Reader; VAR res : LONGINT);
				VAR
					imgInfo : J2KCS.ImageInfo;
					buffCr : J2KCS.BufferedCodestreamReader;
				BEGIN

					(* Instantiate decoder chain *)
					IF fr = NIL THEN
						NEW(fr, s);

						IF ~fr.InitError() THEN

							IF fr.IsJP2File() THEN
								s := fr.GetCodestream();
							END;

							IF s # NIL THEN

								IF decOpt.crOpt.component = J2KCS.BUF_CODESTREAM_READER THEN
									NEW(buffCr, decOpt.crOpt, s);
									cr := buffCr;
								ELSE
									NEW(cr, decOpt.crOpt, s);
								END;

								IF ~cr.InitError() THEN
									decSpec := cr.GetDecoderSpecs();
									imgInfo := decSpec.GetImageInfo();

									NEW(ed, decOpt.edOpt, cr, decSpec);
									NEW(roi, decOpt.roiOpt, ed, decSpec);
									NEW(deq, decOpt.deqOpt, roi, decSpec);
									NEW(invDWT, decOpt.invDWTOpt, deq, decSpec);
									NEW(invMCT, decOpt.invMCTOpt, invDWT, decSpec);
									NEW(imgProd);
									ready := imgProd.InitProduction(invMCT, imgInfo);
								END;
							END;
						END;
					ELSE
						fr.ReInit(s);

						IF ~fr.InitError() THEN

							IF fr.IsJP2File() THEN
								s := fr.GetCodestream();
							END;

							IF s # NIL THEN

								cr.ReInit(decOpt.crOpt, s);

								IF ~cr.InitError() THEN
									decSpec := cr.GetDecoderSpecs();
									imgInfo := decSpec.GetImageInfo();

									ed.ReInit(decOpt.edOpt, cr, decSpec);
									roi.ReInit(decOpt.roiOpt, ed, decSpec);
									deq.ReInit(decOpt.deqOpt, roi, decSpec);
									invDWT.ReInit(decOpt.invDWTOpt, deq, decSpec);
									invMCT.ReInit(decOpt.invMCTOpt, invDWT, decSpec);
									ready := imgProd.InitProduction(invMCT, imgInfo);
								END;
							END;
						END;
					END;

					minResDec := 0;
					minLayDec := 0;
					deliveredOnce := FALSE;

					IF ready THEN
						res := Codecs.ResOk;
					ELSE
						res := Codecs.ResFailed;
					END;
			END Open;

			PROCEDURE GetImageInfo*(VAR width, height, format, maxProgressionLevel : LONGINT);
				VAR
					imgInfo : J2KCS.ImageInfo;
				BEGIN
					IF ready THEN
						imgInfo := decSpec.GetImageInfo();

						width := imgInfo.GetImgWidth(0);
						height := imgInfo.GetImgHeight(0);

						format := imgProd.GetImgFormat();

						maxProgressionLevel := decSpec.GetMinNumLayers() - 1;
					END;
			END GetImageInfo;

			(** Render will read and decode the image data up to progrssionLevel.
				If the progressionLevel is lower than a previously rendered progressionLevel,
				the new level can be ignored by the decoder. If no progressionLevel is set with
				SetProgressionLevel, the level is assumed to be maxProgressionLevel of the image,
				which corresponds to best image quality.
			 *)
			PROCEDURE SetProgressionLevel*(progressionLevel: LONGINT);
				VAR
					dec : LONGINT;
				BEGIN
					IF ready THEN
						(* Set image quality in terms of layers *)
						dec := decSpec.GetMinNumLayers() - progressionLevel - 1;

						DecreaseNumLayers(dec);
					END;
			END SetProgressionLevel;

			(** renders the image into the given Raster.Image at the given progressionLevel *)
			PROCEDURE Render*(img : Raster.Image);
				VAR
					imgConsumerArr : ARRAY 1 OF ImageConsumer;
					imgAdapt : RasterImageAdapter;
				BEGIN
					IF ready THEN
						NEW(imgAdapt, img);

						imgConsumerArr[0] := imgAdapt;

						imgProd.ProduceImage(imgConsumerArr, 0, 1);

						deliveredOnce := TRUE;
					ELSE
						KernelLog.String("ERROR (Decoder.Render) : Cannot render image because initializing image production failed");
						KernelLog.Ln();
					END;
			END Render;

			(* --- END Codecs.ImageDecoder methods --- *)

			PROCEDURE DeliverImage* (VAR consumers : ARRAY OF ImageConsumer; offset, nconsumer : LONGINT);
				BEGIN
					IF ready THEN
						imgProd.ProduceImage(consumers, offset, nconsumer);

						deliveredOnce := TRUE;
					ELSE
						KernelLog.String("ERROR (Decoder.DeliverImage) : Cannot deliver image because initializing image production failed");
						KernelLog.Ln();
					END;
			END DeliverImage;

			(**
				Closes the input stream. All information on the image gets lost when this procedure is called.
			*)
			PROCEDURE CloseStream*;
				BEGIN
					(* Release resources *)
					decSpec := NIL;

					fr.FreeResources();
					cr.FreeResources();
					ed.FreeResources();
					roi.FreeResources();
					deq.FreeResources();
					invDWT.FreeResources();
					invMCT.FreeResources();

					ready := FALSE;
			END CloseStream;


			(**
				Gets the maximum resolution level of the image. The maximum value
				is equal to the miniumum number of decomposition levels over all
				(tile-) components. The lowest possible value is 0. If the decoder is
				not ready or the stream is corrupted, -1 is returned.

				NOTE:
				The return value is equal to the maximum resolution level known at
				the current stage of decoding, e.g. calling this procedure after opening
				the decoder on a valid stream will return the maximum resolution level
				as indicated by the main header. However this may change if for example
				in a tile-header read later the minimum decomposition level over the
				tile's components is lower than the minimum known that far.
			*)
			PROCEDURE GetNumResolutionLevels* () : LONGINT;
				BEGIN
					IF ready THEN
						RETURN decSpec.GetImgMinDecLevels() + 1;
					ELSE
						RETURN 0;
					END;
			END GetNumResolutionLevels;

			(**
				Sets by how much the original resolution of the image shall be decreased at minimum.
				The given parameter is an exponent. It indicates that
					<image width at decreased resolution> := <orginal image width> / (2^<exponent>)
					<image height at decreased resolution> := <orginal image height> / (2^<exponent>)

				If the image resolution cannot be decreased by that much, then it won't be reconstructed.

				NOTE: This procedure shall NOT be called after the image has been rendered/delivered once.

				This procedure can be used to save some memory.
			*)
			PROCEDURE MinDecreaseResolutionLevel* (minResDec : LONGINT);
				VAR
					ndec, curStartLvl, curEndLvl : LONGINT;
				BEGIN
					IF ready THEN
						IF ~deliveredOnce THEN
							ndec := decSpec.GetImgMinDecLevels();

							IF minResDec < 0 THEN
								SELF.minResDec := 0;
							ELSIF minResDec <= ndec THEN
								SELF.minResDec := minResDec;
							ELSE
								KernelLog.String("WARNING (Decoder.MinDecreaseResolutionLevel): ");
								KernelLog.String("Cannot decrease resolution level by ");
								KernelLog.Int(minResDec, 0);
								KernelLog.String(". Image has only ");
								KernelLog.Int(ndec + 1, 0);
								KernelLog.String(" resolution levels.");
								KernelLog.Ln();
								SELF.minResDec := ndec;
							END;

							invMCT.SetMaxDecLevelRange(MAX(LONGINT), SELF.minResDec);

							(*
								If the new maximum end decomposition level is higher than the current
								end decomposition level, we need to lower the end decomposition level.
							*)
							invMCT.GetDecLevelRange(curStartLvl, curEndLvl);

							IF curEndLvl < SELF.minResDec THEN
								invMCT.SetDecLevelRange(curStartLvl, SELF.minResDec);
							END;
						ELSE
							KernelLog.String("WARNING (Decoder.MinDecreaseResolutionLevel): ");
							KernelLog.String("Procedure called after first image reconstruction -> won't change current value");
							KernelLog.Ln();
						END;
					END;
			END MinDecreaseResolutionLevel;

			(**
				Decreases the original resolution of the image. The given parameter is an
				exponent. It indicates that
					<image width at decreased resolution> := <orginal image width> / (2^<exponent>)
					<image height at decreased resolution> := <orginal image height> / (2^<exponent>)

				NOTE:
				It is possible that the resolution level cannot be decreased by resDec, i.e. when a tile
				does not exist in a that small resolution. Then the image may be reconstructed at the
				next higher possible resolution level, if that resolution level does not violate
				the minimum decrease in resolution levels (see MinDecreaseResolutionLevel).
			*)
			PROCEDURE DecreaseResolutionLevel* (resDec : LONGINT);
				VAR
					ndec, dec : LONGINT;
				BEGIN
					IF ready THEN
						ndec := decSpec.GetImgMinDecLevels();

						IF resDec < minResDec THEN
							KernelLog.String("WARNING (Decoder.DecreaseResolutionLevel): ");
							KernelLog.String("Cannot decrease resolution level only by ");
							KernelLog.Int(resDec, 0);
							KernelLog.String(". Res. level has to be decreased by at least ");
							KernelLog.Int(minResDec, 0);
							KernelLog.String(".");
							KernelLog.Ln();
							dec := minResDec;
						ELSIF resDec <= ndec THEN
							dec := resDec;
						ELSE
							KernelLog.String("WARNING (Decoder.DecreaseResolutionLevel): ");
							KernelLog.String("Cannot decrease resolution level by ");
							KernelLog.Int(resDec, 0);
							KernelLog.String(". Image has only ");
							KernelLog.Int(ndec + 1, 0);
							KernelLog.String(" resolution levels.");
							KernelLog.Ln();
							dec := ndec;
						END;

						(* We always start building from the lowest possible decomposition level *)
						invMCT.SetDecLevelRange(MAX(LONGINT), dec);
					END;
			END DecreaseResolutionLevel;


			(**
				This procedure is meant to be called after a first image rendering.
				It then provides the the decomposition level at which the image got
				rendered (not the requested decomposition level, since a it's possible
				that a rebuild had to be performed, e.g. when the image, that is a tile
				of the image, did not have the requested decomposition level)
			*)
			PROCEDURE GetCurrentDecompositionLevel* () : LONGINT;
				VAR
					decLvl, minNumDecLvls, dummy : LONGINT;
				BEGIN
					IF ready THEN
						invMCT.GetDecLevelRange(dummy, decLvl);
						minNumDecLvls := decSpec.GetImgMinDecLevels();

						IF decLvl > minNumDecLvls THEN
							RETURN minNumDecLvls;
						ELSE
							RETURN decLvl;
						END;

					ELSE
						RETURN -1;
					END;
			END GetCurrentDecompositionLevel;


			(**
				Gets the number of layers for the image. This value is equal to
				miniumum number of layers over all tiles. If the decoder is
				not ready or the stream is corrupted, -1 is returned.

				NOTE:
				The return value is equal to the minimum number of layers known at
				the current stage of decoding, e.g. calling this procedure after opening
				the decoder on a valid stream will return the number of layers
				as indicated by the main header. However this may change if for example
				in a tile-header read later the number of layers for that tile is lower than
				the minimum known that far.
			*)
			PROCEDURE GetNumLayers* () : LONGINT;
				BEGIN
					IF ready THEN
						RETURN decSpec.GetMinNumLayers();
					ELSE
						RETURN 0;
					END;
			END GetNumLayers;

			(**
				Sets by how much the number of layers shall be decreased at minimum. Note
				that this procedure uses the current state of knowledge, meaning that a subsequent
				tile could have too few layers. In that case all layers for that tile will be decoded.

				NOTE: This procedure shall NOT be called after the image has been rendered/delivered once.

				This procedure can be used to save some memory.
			*)
			PROCEDURE MinDecreaseNumLayers* (minLayers : LONGINT);
				VAR
					maxlayer, maxEndLayer, curStartLayer, curEndLayer : LONGINT;
				BEGIN
					IF ready THEN
						IF ~deliveredOnce THEN
							maxlayer := decSpec.GetMinNumLayers() - 1;

							IF minLayers < 0 THEN
								SELF.minLayDec := 0;
							ELSIF minLayers <= maxlayer THEN
								SELF.minLayDec := minLayers;
							ELSE
								KernelLog.String("WARNING (Decoder.MinDecreaseNumLayers): ");
								KernelLog.String("Cannot decrease number of layers by ");
								KernelLog.Int(minLayers, 0);
								KernelLog.String(". Image has only ");
								KernelLog.Int(maxlayer + 1, 0);
								KernelLog.String(" layers.");
								KernelLog.Ln();
								SELF.minLayDec := maxlayer;
							END;

							maxEndLayer := maxlayer - SELF.minLayDec;

							invMCT.SetMaxLayerRange(0, maxEndLayer);

							(*
								If the new maximum end layer is lower than the current
								end layer, we need to lower the end layer
							*)
							invMCT.GetLayerRange(curStartLayer, curEndLayer);

							IF curEndLayer > maxEndLayer THEN
								invMCT.SetLayerRange(curStartLayer, maxEndLayer);
							END;
						ELSE
							KernelLog.String("WARNING (Decoder.MinDecreaseNumLayers): ");
							KernelLog.String("Procedure called after first image reconstruction -> won't change current value");
							KernelLog.Ln();
						END;
					END;
			END MinDecreaseNumLayers;

			(**
				Decreases the number of layers for the image. If it's not possible to decrease the
				number of layers by as much as indicated, then at least 1 layer will be decoded. Note
				that this procedure uses the current state of knowledge, meaning that a subsequent
				tile could have too few layers. In that case all layers for that tile will be decoded.
			*)
			PROCEDURE DecreaseNumLayers* (layers : LONGINT);
				VAR
					maxlayer, dec : LONGINT;
				BEGIN
					IF ready THEN
						maxlayer := decSpec.GetMinNumLayers() - 1;

						IF layers < minLayDec THEN
							KernelLog.String("WARNING (Decoder.DecreaseNumLayers): ");
							KernelLog.String("Cannot decrease number of layers only by ");
							KernelLog.Int(layers, 0);
							KernelLog.String(". Num. of layers has to be decreased by at least ");
							KernelLog.Int(minLayDec, 0);
							KernelLog.String(".");
							KernelLog.Ln();
							dec := minLayDec;
						ELSIF layers <= maxlayer THEN
							dec := layers;
						ELSE
							KernelLog.String("WARNING (Decoder.DecreaseNumLayers): ");
							KernelLog.String("Cannot decrease number of layers by ");
							KernelLog.Int(layers, 0);
							KernelLog.String(". Image has only ");
							KernelLog.Int(maxlayer + 1, 0);
							KernelLog.String(" layers.");
							KernelLog.Ln();
							dec := maxlayer;
						END;

						invMCT.SetLayerRange(0, maxlayer - dec);
					END;
			END DecreaseNumLayers;

			(**
				This procedure return the number of layers that where used
				to render the image (NOTE: The return value gives the maximum
				number of layers used; it's possible that some tiles have fewer layers).
			*)
			PROCEDURE GetCurrentNumLayers* () : LONGINT;
				VAR
					minNumLayers, curNumLayers, maxLayer, dummy : LONGINT;
				BEGIN
					IF ready THEN
						invMCT.GetLayerRange(dummy, maxLayer);
						curNumLayers := maxLayer + 1;
						minNumLayers := decSpec.GetMinNumLayers();

						IF curNumLayers > minNumLayers THEN
							RETURN minNumLayers;
						ELSE
							RETURN curNumLayers;
						END;
					ELSE
						RETURN -1;
					END;
			END GetCurrentNumLayers;


			PROCEDURE GetNumTiles* () : LONGINT;
				VAR
					imgInfo : J2KCS.ImageInfo;
				BEGIN
					IF ready THEN
						imgInfo := decSpec.GetImageInfo();
						RETURN imgInfo.GetNumTiles();
					ELSE
						RETURN 0;
					END;
			END GetNumTiles;

			PROCEDURE GetNumComponents* () : LONGINT;
				VAR
					imgInfo : J2KCS.ImageInfo;
				BEGIN
					IF ready THEN
						imgInfo := decSpec.GetImageInfo();
						RETURN imgInfo.GetNumComponents();
					ELSE
						RETURN 0;
					END;
			END GetNumComponents;

			(**
				Gets image width & height at a given decomposition level.
				-1 for width & height, if there decoder is not ready yet or an error occured
			*)
			PROCEDURE GetImageSize* (declevel : LONGINT; VAR width, height : LONGINT);
				VAR
					imgInfo : J2KCS.ImageInfo;
					minDec : LONGINT;
				BEGIN
					IF ready THEN
						imgInfo := decSpec.GetImageInfo();
						minDec := decSpec.GetImgMinDecLevels();

						IF declevel <= minDec THEN
							width := imgInfo.GetImgWidth(declevel);
							height := imgInfo.GetImgHeight(declevel);
						END;
					ELSE
						width := -1;
						height := -1;
					END;

			END GetImageSize;

			(**
				Gets the image format (-> see Codecs).
				-1 if there decoder is not ready yet or an error occured
			*)
			PROCEDURE GetImageFormat* () : LONGINT;
				BEGIN
					IF ready THEN
						RETURN imgProd.GetImgFormat();
					ELSE
						RETURN -1;
					END;
			END GetImageFormat;

			(**
				Gets tile horizontal/vertical offset, tile width & height at a given tile and decomposition level.
				-1 for toffx, toffy, width, height, if there decoder is not ready yet or an error occured
			*)
			PROCEDURE GetTileSize* (tile, declevel : LONGINT; VAR toffx, toffy, twidth, theight : LONGINT);
				VAR
					imgInfo : J2KCS.ImageInfo;
				BEGIN
					IF ready THEN
						imgInfo := decSpec.GetImageInfo();

						IF (tile < imgInfo.GetNumTiles()) & (declevel <= decSpec.GetMinDecLevels(tile)) THEN
							toffx := imgInfo.GetTileULX(tile, declevel) - imgInfo.GetImgULX(declevel);
							toffy := imgInfo.GetTileULY(tile, declevel) - imgInfo.GetImgULX(declevel);
							twidth := imgInfo.GetTileWidth(tile, declevel);
							theight := imgInfo.GetTileHeight(tile, declevel);
						END;
					ELSE
						toffx := -1;
						toffy := -1;
						twidth := -1;
						theight := -1;
					END;
			END GetTileSize;

		END Decoder;


		(* --- END Decoder types --- *)

	VAR

		filter5x3Lift : FilterSyn5x3Lifting;
		filter9x7Lift : FilterSyn9x7Lifting;

		(* --- Variables used by entropy decoder --- *)

		(* Tables used to determine the proper context depending on the neighbor states *)
		ENTROPY_ZEROLL_LUT, ENTROPY_ZEROHL_LUT, ENTROPY_ZEROHH_LUT : J2KU.LongIntArrayPtr;
		(* Table used in sign decoding process *)
		ENTROPY_SIGN_LUT : ARRAY LSH(SYSTEM.VAL(LONGINT, 1), ENTROPY_SIGN_BITS) OF LONGINT;

		(* --- END Variables used by entropy decoder --- *)

		(* The initial states and MPS symbols for each context passed to the MQ-Decoder *)
		MQ_INITSTATES, MQ_INITMPS : J2KU.LongIntArrayPtr;

		(* --- Variables used by MQ-Decoder --- *)

		(* "Table" used by the MQ coder to look up probability estimations (2nd dim. index 0), nmps (2nd dim. index 1), nlps (2nd dim. index 2) and switch values (2nd dim. index 3) *)
		MQPROB, MQNMPS, MQNLPS, MQSWITCH : ARRAY MQTABSIZ OF LONGINT;

		(* --- END Variables used by MQ-Decoder --- *)


	(* Initializes the lookup tables used in the MQ and Entropy Coder units *)
	PROCEDURE InitEntropyTables;
		VAR
			i, j : LONGINT;
			twoAtLeast : ARRAY 11 OF LONGINT;	(* All 4 bit values with at least 2 bits = 1 *)
			threeAtLeast : ARRAY 5 OF LONGINT;	(* All 4 bit values with at least 3 bits = 1 *)
			twoBits : ARRAY 6 OF LONGINT;			(* All 4 bit values with 2 bits = 1 *)
			oneBit : ARRAY 4 OF LONGINT;			(* All 4 bit values with 1 bit = 1 *)
			h, v, hl, hr, vu, vd, hlsig, hrsig, vusig, vdsig : LONGINT;
			tmpSignLut : ARRAY 16 OF LONGINT;
		BEGIN

		(* Fill up the lookup table needed for significance propagation and cleanup pass for code-blocks in the LL/LH subband *)

		(* Initialize locally needed arrays here *)
		twoAtLeast[0] := 3;
		twoAtLeast[1] := 5;
		twoAtLeast[2] := 6;
		twoAtLeast[3] := 7;
		twoAtLeast[4] := 9;
		twoAtLeast[5] := 10;
		twoAtLeast[6] := 11;
		twoAtLeast[7] := 12;
		twoAtLeast[8] := 13;
		twoAtLeast[9] := 14;
		twoAtLeast[10] := 15;

		threeAtLeast[0] := 7;
		threeAtLeast[1] := 11;
		threeAtLeast[2] := 13;
		threeAtLeast[3] := 14;
		threeAtLeast[4] := 15;

		twoBits[0] := 3;
		twoBits[1] := 5;
		twoBits[2] := 6;
		twoBits[3] := 9;
		twoBits[4] := 10;
		twoBits[5] := 12;

		oneBit[0] := 1;
		oneBit[1] := 2;
		oneBit[2] := 4;
		oneBit[3] := 8;

		(* The context vector contains the significance of each neighbor of a coefficient in the follwing order: *)
		(* HL - HR - VU - VD - DUL - DUR - DDL - DDR *)

		NEW(ENTROPY_ZEROLL_LUT, LSH(SYSTEM.VAL(LONGINT, 1), ENTROPY_ZERO_BITS));
		NEW(ENTROPY_ZEROHL_LUT, LSH(SYSTEM.VAL(LONGINT, 1), ENTROPY_ZERO_BITS));
		NEW(ENTROPY_ZEROHH_LUT, LSH(SYSTEM.VAL(LONGINT, 1), ENTROPY_ZERO_BITS));

		(* LL / LH subband *)
		(* 2 horizontal significant *)
		FOR i := 0 TO 63 DO
			ENTROPY_ZEROLL_LUT[SYSTEM.VAL(LONGINT, (SYSTEM.VAL(SET, ENTROPY_SIGHL) +  SYSTEM.VAL(SET, ENTROPY_SIGHR)) + SYSTEM.VAL(SET, i))] := 8;
		END;

		(* 1 horizontal significant, at least 1 vertical significant *)
		FOR i := 1 TO 3 DO
			FOR j := 0 TO 15 DO
				ENTROPY_ZEROLL_LUT[SYSTEM.VAL(LONGINT, (SYSTEM.VAL(SET, ENTROPY_SIGHL) + SYSTEM.VAL(SET, LSH(i, 4))) + SYSTEM.VAL(SET, j))] := 7;
				ENTROPY_ZEROLL_LUT[SYSTEM.VAL(LONGINT, (SYSTEM.VAL(SET, ENTROPY_SIGHR) + SYSTEM.VAL(SET, LSH(i, 4))) + SYSTEM.VAL(SET, j))] := 7
			END;
		END;

		(* 1 horizontal significant, 0 vertical significant, at least 1 diagonal significant *)
		FOR i := 1 TO 15 DO
			ENTROPY_ZEROLL_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ENTROPY_SIGHL) + SYSTEM.VAL(SET, i))] := 6;
			ENTROPY_ZEROLL_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ENTROPY_SIGHR) + SYSTEM.VAL(SET, i))] := 6;
		END;

		(* 1 horizontal significant, 0 vertical significant, 0 diagonal significant *)
		ENTROPY_ZEROLL_LUT[ENTROPY_SIGHL] := 5;
		ENTROPY_ZEROLL_LUT[ENTROPY_SIGHR] := 5;

		(* 0 horizontal significant, 2 vertical significant *)
		FOR i := 0 TO 15 DO
			ENTROPY_ZEROLL_LUT[SYSTEM.VAL(LONGINT, (SYSTEM.VAL(SET, ENTROPY_SIGVU) + SYSTEM.VAL(SET, ENTROPY_SIGVD)) + SYSTEM.VAL(SET, i))] := 4;
		END;

		(* 0 horizontal significant, 1 vertical significant *)
		FOR i := 0 TO 15 DO
			ENTROPY_ZEROLL_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ENTROPY_SIGVU) + SYSTEM.VAL(SET, i))] := 3;
			ENTROPY_ZEROLL_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ENTROPY_SIGVD) + SYSTEM.VAL(SET, i))] := 3;
		END;

		(* 0 horizontal significant, 0 vertical significant, at least 2 diagonal significant *)
		FOR i := 0 TO LEN(twoAtLeast) - 1 DO
			ENTROPY_ZEROLL_LUT[twoAtLeast[i]] := 2;
		END;

		(* 0 horizontal significant, 0 vertical significant, 1 diagonal significant *)
		FOR i := 0 TO LEN(oneBit) - 1 DO
			ENTROPY_ZEROLL_LUT[oneBit[i]] := 1;
		END;

		(* 0 horizontal significant, 0 vertical significant, 0 diagonal significant *)
		ENTROPY_ZEROLL_LUT[0] := 0;


		(* HL subband *)

		(* 2 vertical significant *)
		FOR i := 0 TO 3 DO
			FOR j := 0 TO 15 DO
				ENTROPY_ZEROHL_LUT[SYSTEM.VAL(LONGINT, (SYSTEM.VAL(SET, ENTROPY_SIGVU) +  SYSTEM.VAL(SET, ENTROPY_SIGVD)) + SYSTEM.VAL(SET, LSH(i, 6) ) + SYSTEM.VAL(SET, j))] := 8;
			END;
		END;

		(* 1 vertical significant, at least 1 horizontal significant *)
		FOR i := 1 TO 3 DO
			FOR j := 0 TO 15 DO
				ENTROPY_ZEROHL_LUT[SYSTEM.VAL(LONGINT, (SYSTEM.VAL(SET, ENTROPY_SIGVU) + SYSTEM.VAL(SET, LSH(i, 6))) + SYSTEM.VAL(SET, j))] := 7;
				ENTROPY_ZEROHL_LUT[SYSTEM.VAL(LONGINT, (SYSTEM.VAL(SET, ENTROPY_SIGVD) + SYSTEM.VAL(SET, LSH(i, 6))) + SYSTEM.VAL(SET, j))] := 7
			END;
		END;

		(* 1 vertical significant, 0 horizontal significant, at least 1 diagonal significant *)
		FOR i := 1 TO 15 DO
			ENTROPY_ZEROHL_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ENTROPY_SIGVU) + SYSTEM.VAL(SET, i))] := 6;
			ENTROPY_ZEROHL_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ENTROPY_SIGVD) + SYSTEM.VAL(SET, i))] := 6;
		END;

		(* 1 vertical significant, 0 horizontal significant, 0 diagonal significant *)
		ENTROPY_ZEROHL_LUT[ENTROPY_SIGVU] := 5;
		ENTROPY_ZEROHL_LUT[ENTROPY_SIGVD] := 5;

		(* 0 vertical significant, 2 horizontal significant *)
		FOR i := 0 TO 15 DO
			ENTROPY_ZEROHL_LUT[SYSTEM.VAL(LONGINT, (SYSTEM.VAL(SET, ENTROPY_SIGHL) + SYSTEM.VAL(SET, ENTROPY_SIGHR)) + SYSTEM.VAL(SET, i))] := 4;
		END;

		(* 0 vertical significant, 1 horizontal significant *)
		FOR i := 0 TO 15 DO
			ENTROPY_ZEROHL_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ENTROPY_SIGHL) + SYSTEM.VAL(SET, i))] := 3;
			ENTROPY_ZEROHL_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ENTROPY_SIGHR) + SYSTEM.VAL(SET, i))] := 3;
		END;

		(* 0 horizontal significant, 0 vertical significant, at least 2 diagonal significant *)
		FOR i := 0 TO LEN(twoAtLeast) - 1 DO
			ENTROPY_ZEROHL_LUT[twoAtLeast[i]] := 2;
		END;

		(* 0 horizontal significant, 0 vertical significant, 1 diagonal significant *)
		FOR i := 0 TO LEN(oneBit) - 1 DO
			ENTROPY_ZEROHL_LUT[oneBit[i]] := 1;
		END;

		(* 0 horizontal significant, 0 vertical significant, 0 diagonal significant *)
		ENTROPY_ZEROHL_LUT[0] := 0;


		(* HH subband *)

		(* At least 3 diagonal significant *)
		FOR i := 0 TO 15 DO
			FOR j := 0 TO LEN(threeAtLeast) - 1 DO
				ENTROPY_ZEROHH_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(i, 4)) + SYSTEM.VAL(SET, threeAtLeast[j]))] := 8;
			END;
		END;

		(* 2 diagonal significant, at least 1 horizontal or vertical significant *)
		FOR i := 1 TO 15 DO
			FOR j := 0 TO LEN(twoBits) - 1 DO
				ENTROPY_ZEROHH_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(i, 4)) + SYSTEM.VAL(SET, twoBits[j]))] := 7;
			END;
		END;

		(* 2 diagonal significant, 0 horizontal or vertical significant *)
		FOR i := 0 TO LEN(twoBits) - 1 DO
			ENTROPY_ZEROHH_LUT[twoBits[i]] := 6;
		END;

		(* 1 diagonal significant, at least 2 horizontal or vertical significant *)
		FOR i := 0 TO LEN(twoAtLeast) - 1 DO
			FOR j := 0 TO LEN(oneBit) - 1 DO
				ENTROPY_ZEROHH_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(twoAtLeast[i], 4)) + SYSTEM.VAL(SET, oneBit[j]))] := 5;
			END;
		END;

		(* 1 diagonal significant, 1 horizontal or vertical significant *)
		FOR i := 0 TO LEN(oneBit) - 1 DO
			FOR j := 0 TO LEN(oneBit) - 1 DO
				ENTROPY_ZEROHH_LUT[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(oneBit[i], 4)) + SYSTEM.VAL(SET, oneBit[j]))] := 4;
			END;
		END;

		(* 1 diagonal significant, 0 horizontal or vertical significant *)
		FOR i := 0 TO LEN(oneBit) - 1 DO
			ENTROPY_ZEROHH_LUT[oneBit[i]] := 3;
		END;

		(* 0 diagonal significant, at least 2 horizontal or vertical significant *)
		FOR i := 0 TO LEN(twoAtLeast) - 1 DO
			ENTROPY_ZEROHH_LUT[LSH(twoAtLeast[i], 4)] := 2;
		END;

		(* 0 diagonal significant, 1 horizontal or vertical significant *)
		FOR i := 0 TO LEN(oneBit) - 1 DO
			ENTROPY_ZEROHH_LUT[LSH(oneBit[i], 4)] := 1;
		END;

		(* 0 horizontal significant, 0 vertical significant, 0 diagonal significant *)
		ENTROPY_ZEROHH_LUT[0] := 0;


		(* Fill up the lookup table needed for sign bit decoding *)

		(* The context vector contains the significance and sign of the horizontal and vertical neighbors of a coefficient in the following way: *)
		(* Sign HL - Sign HR - Sign VU - Sign VD - HL - HR - VU - VD *)

		(*
			First fill up the temporary context lookup table. This table is needed to fill up
			the "real" table (i.e. the proper index of in the temporary table will be computed -> see below).
		*)

		(* Horizontal contrib. 1, vertical contrib. 1 *)
		tmpSignLut[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(2, 2)) + SYSTEM.VAL(SET, 2))] := 13;
		(* Horizontal contrib. 1, vertical contrib. 0 *)
		tmpSignLut[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(2, 2)) + SYSTEM.VAL(SET, 1))] := 12;
		(* Horizontal contrib. 1, vertical contrib. -1 *)
		tmpSignLut[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(2, 2)) + SYSTEM.VAL(SET, 0))] := 11;
		(* Horizontal contrib. 0, vertical contrib. 1 *)
		tmpSignLut[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(1, 2)) + SYSTEM.VAL(SET, 2))] := 10;
		(* Horizontal contrib. 0, vertical contrib. 0 *)
		tmpSignLut[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(1, 2)) + SYSTEM.VAL(SET, 1))] := 9;
		(* Horizontal contrib. 0, vertical contrib. -1 *)
		tmpSignLut[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(1, 2)) + SYSTEM.VAL(SET, 0))] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 10)) + J2KU.LONGINT_SIGN_BIT);
		(* Horizontal contrib. -1, vertical contrib. 1 *)
		tmpSignLut[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(0, 2)) + SYSTEM.VAL(SET, 2))] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 11)) + J2KU.LONGINT_SIGN_BIT);
		(* Horizontal contrib. -1, vertical contrib. 0 *)
		tmpSignLut[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(0, 2)) + SYSTEM.VAL(SET, 1))] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 12)) + J2KU.LONGINT_SIGN_BIT);
		(* Horizontal contrib. -1, vertical contrib. -1 *)
		tmpSignLut[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(0, 2)) + SYSTEM.VAL(SET, 0))] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 13)) + J2KU.LONGINT_SIGN_BIT);

		FOR i := 0 TO LSH(SYSTEM.VAL(LONGINT, 1), ENTROPY_SIGN_BITS) - 1 DO
			hlsig := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(i, -7)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 1)));
			hrsig := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(i, -6)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 1)));
			vusig := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(i, -5)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 1)));
			vdsig := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(i, -4)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 1)));
			hl := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(i, -3)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 1)));
			hr := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(i, -2)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 1)));
			vu := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(i, -1)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 1)));
			vd := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, i) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 1)));

			h := hl * (1 - 2 * hlsig) + hr * (1 - 2 * hrsig);
			v := vu * (1 - 2 * vusig) + vd * (1 - 2 * vdsig);

			IF h > 1 THEN h := 1; END;
			IF h < -1 THEN h := -1; END;
			IF v > 1 THEN v := 1; END;
			IF v < -1 THEN v := -1 END;

			ENTROPY_SIGN_LUT[i] := tmpSignLut[SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(h+1, 2)) + SYSTEM.VAL(SET, v+1))]
		END;

		(* Initialize the initial states and MPS symbols for each context. These arrays will be passed on to the MQ-Decoder *)

		NEW(MQ_INITSTATES, 19);
		NEW(MQ_INITMPS, 19);

		(* The zero context *)
		MQ_INITSTATES[0] := 4;
		MQ_INITMPS[0] := 0;

		(* The UNIFORM context *)
		MQ_INITSTATES[ENTROPY_UNICTX] := 46;
		MQ_INITMPS[ENTROPY_UNICTX] := 0;

		(* The run-length context *)
		MQ_INITSTATES[ENTROPY_RUNCTX] := 3;
		MQ_INITMPS[ENTROPY_RUNCTX] := 0;

		(* All other contexts *)
		FOR i := 1 TO 16 DO
			MQ_INITSTATES[i] := 0;
			MQ_INITMPS[i] := 0;
		END;

	END InitEntropyTables;

	PROCEDURE InitMQTables;
		BEGIN
		(* Probability estimation Qe *)		(* NMPS *)				(* LPS *)				(* SWITCH *)
		MQPROB[0] := 00005601H;			MQNMPS[0] := 1;		MQNLPS[0] := 1;		MQSWITCH[0] := 1;
		MQPROB[1] := 00003401H;			MQNMPS[1] := 2;		MQNLPS[1] := 6;		MQSWITCH[1] := 0;
		MQPROB[2] := 00001801H;			MQNMPS[2] := 3;		MQNLPS[2] := 9;		MQSWITCH[2] := 0;
		MQPROB[3] := 00000AC1H;			MQNMPS[3] := 4;		MQNLPS[3] := 12;		MQSWITCH[3] := 0;
		MQPROB[4] := 00000521H;			MQNMPS[4] := 5;		MQNLPS[4] := 29;		MQSWITCH[4] := 0;
		MQPROB[5] := 00000221H;			MQNMPS[5] := 38;		MQNLPS[5] := 33;		MQSWITCH[5] := 0;
		MQPROB[6] := 00005601H;			MQNMPS[6] := 7;		MQNLPS[6] := 6;		MQSWITCH[6] := 1;
		MQPROB[7] := 00005401H;			MQNMPS[7] := 8;		MQNLPS[7] := 14;		MQSWITCH[7] := 0;
		MQPROB[8] := 00004801H;			MQNMPS[8] := 9;		MQNLPS[8] := 14;		MQSWITCH[8] := 0;
		MQPROB[9] := 00003801H;			MQNMPS[9] := 10;		MQNLPS[9] := 14;		MQSWITCH[9] := 0;

		MQPROB[10] := 00003001H;		MQNMPS[10] := 11;		MQNLPS[10] := 17;		MQSWITCH[10] := 0;
		MQPROB[11] := 00002401H;		MQNMPS[11] := 12;		MQNLPS[11] := 18;		MQSWITCH[11] := 0;
		MQPROB[12] := 00001C01H;		MQNMPS[12] := 13;		MQNLPS[12] := 20;		MQSWITCH[12] := 0;
		MQPROB[13] := 00001601H;		MQNMPS[13] := 29;		MQNLPS[13] := 21;		MQSWITCH[13] := 0;
		MQPROB[14] := 00005601H;		MQNMPS[14] := 15;		MQNLPS[14] := 14;		MQSWITCH[14] := 1;
		MQPROB[15] := 00005401H;		MQNMPS[15] := 16;		MQNLPS[15] := 14;		MQSWITCH[15] := 0;
		MQPROB[16] := 00005101H;		MQNMPS[16] := 17;		MQNLPS[16] := 15;		MQSWITCH[16] := 0;
		MQPROB[17] := 00004801H;		MQNMPS[17] := 18;		MQNLPS[17] := 16;		MQSWITCH[17] := 0;
		MQPROB[18] := 00003801H;		MQNMPS[18] := 19;		MQNLPS[18] := 17;		MQSWITCH[18] := 0;
		MQPROB[19] := 00003401H;		MQNMPS[19] := 20;		MQNLPS[19] := 18;		MQSWITCH[19] := 0;

		MQPROB[20] := 00003001H;		MQNMPS[20] := 21;		MQNLPS[20] := 19;		MQSWITCH[20] := 0;
		MQPROB[21] := 00002801H;		MQNMPS[21] := 22;		MQNLPS[21] := 19;		MQSWITCH[21] := 0;
		MQPROB[22] := 00002401H;		MQNMPS[22] := 23;		MQNLPS[22] := 20;		MQSWITCH[22] := 0;
		MQPROB[23] := 00002201H;		MQNMPS[23] := 24;		MQNLPS[23] := 21;		MQSWITCH[23] := 0;
		MQPROB[24] := 00001C01H;		MQNMPS[24] := 25;		MQNLPS[24] := 22;		MQSWITCH[24] := 0;
		MQPROB[25] := 00001801H;		MQNMPS[25] := 26;		MQNLPS[25] := 23;		MQSWITCH[25] := 0;
		MQPROB[26] := 00001601H;		MQNMPS[26] := 27;		MQNLPS[26] := 24;		MQSWITCH[26] := 0;
		MQPROB[27] := 00001401H;		MQNMPS[27] := 28;		MQNLPS[27] := 25;		MQSWITCH[27] := 0;
		MQPROB[28] := 00001201H;		MQNMPS[28] := 29;		MQNLPS[28] := 26;		MQSWITCH[28] := 0;
		MQPROB[29] := 00001101H;		MQNMPS[29] := 30;		MQNLPS[29] := 27;		MQSWITCH[29] := 0;

		MQPROB[30] := 00000AC1H;		MQNMPS[30] := 31;		MQNLPS[30] := 28;		MQSWITCH[30] := 0;
		MQPROB[31] := 000009C1H;		MQNMPS[31] := 32;		MQNLPS[31] := 29;		MQSWITCH[31] := 0;
		MQPROB[32] := 000008A1H;		MQNMPS[32] := 33;		MQNLPS[32] := 30;		MQSWITCH[32] := 0;
		MQPROB[33] := 00000521H;		MQNMPS[33] := 34;		MQNLPS[33] := 31;		MQSWITCH[33] := 0;
		MQPROB[34] := 00000441H;		MQNMPS[34] := 35;		MQNLPS[34] := 32;		MQSWITCH[34] := 0;
		MQPROB[35] := 000002A1H;		MQNMPS[35] := 36;		MQNLPS[35] := 33;		MQSWITCH[35] := 0;
		MQPROB[36] := 00000221H;		MQNMPS[36] := 37;		MQNLPS[36] := 34;		MQSWITCH[36] := 0;
		MQPROB[37] := 00000141H;		MQNMPS[37] := 38;		MQNLPS[37] := 35;		MQSWITCH[37] := 0;
		MQPROB[38] := 00000111H;		MQNMPS[38] := 39;		MQNLPS[38] := 36;		MQSWITCH[38] := 0;
		MQPROB[39] := 00000085H;		MQNMPS[39] := 40;		MQNLPS[39] := 37;		MQSWITCH[39] := 0;

		MQPROB[40] := 00000049H;		MQNMPS[40] := 41;		MQNLPS[40] := 38;		MQSWITCH[40] := 0;
		MQPROB[41] := 00000025H;		MQNMPS[41] := 42;		MQNLPS[41] := 39;		MQSWITCH[41] := 0;
		MQPROB[42] := 00000015H;		MQNMPS[42] := 43;		MQNLPS[42] := 40;		MQSWITCH[42] := 0;
		MQPROB[43] := 00000009H;		MQNMPS[43] := 44;		MQNLPS[43] := 41;		MQSWITCH[43] := 0;
		MQPROB[44] := 00000005H;		MQNMPS[44] := 45;		MQNLPS[44] := 42;		MQSWITCH[44] := 0;
		MQPROB[45] := 00000001H;		MQNMPS[45] := 45;		MQNLPS[45] := 43;		MQSWITCH[45] := 0;
		MQPROB[46] := 00005601H;		MQNMPS[46] := 46;		MQNLPS[46] := 46;		MQSWITCH[46] := 0;

	END InitMQTables;


(*	TODO: What are the correct formulas to compute the bit-depths of the untransformed components

	(**
		Computes the bit-depth of each component before inverse MCT is performed
	*)
	PROCEDURE ComputeUntransformedBitDepths (VAR utdepth, tdepth : ARRAY OF LONGINT; ttype : LONGINT ) : BOOLEAN;
		VAR
			pow2ut0, pow2ut1, pow2ut2 : LONGINT;
		BEGIN
			ASSERT(LEN(utdepth) >= LEN(tdepth));
			(*
				If there are less than three components and a multiple
				component transformation is used, then this violates the
				constraints imposed by the specification
			*)
			IF (LEN(utdepth) < 3) & (ttype # MCT_NONE) THEN
				KernelLog.String("ERROR: Computation of original component bit depths failed because there are less than 3 components ");
				KernelLog.String(" and multiple component transformation is used");
				KernelLog.Ln();
				RETURN FALSE;
			END;

			(* The bit depths of the transformed components depends on the component transformation used *)
			CASE ttype OF
					MCT_NONE :
						(* The bit depths of the transformed and un-transformed components are equal *)
						SYSTEM.MOVE(ADDRESSOF(utdepth[0]), ADDRESSOF(tdepth[0]), LEN(utdepth)*SIZEOF(LONGINT));
				|	MCT_RCT :
						(*
							The formulas are:
							tdepth[0] = ceil(log2( 2^(utdepth[0]) + 2^(utdepth[1]) + 2^(utdepth[2]) )) - 2 + 1
							tdepth[1] = ceil(log2( 2^(utdepth[0]) + 2^(utdepth[1]) - 1 )) + 1
							tdepth[2] = ceil(log2( 2^(utdepth[1]) + 2^(utdepth[2]) - 1 )) + 1

							Since 'Log2Floor(x)' computes floor(log2(x)) we use 'Log2Floor(2*x-1) + 1',
							which calculates ceil(log2(x)), for any x >= 1, x integer
						*)
						(* Precalculate the 2^utdepth[x] *)
						pow2ut0 := LSH(SYSTEM.VAL(LONGINT, 1), utdepth[0]);
						pow2ut1 := LSH(SYSTEM.VAL(LONGINT, 1), utdepth[1]);
						pow2ut2 := LSH(SYSTEM.VAL(LONGINT, 1), utdepth[2]);

						tdepth[0] := J2KU.Log2Floor(pow2ut0 + 2*pow2ut1 + pow2ut2 - 1) - 1;
						tdepth[1] := J2KU.Log2Floor(pow2ut2 + pow2ut1 - 1) + 1;
						tdepth[2] := J2KU.Log2Floor(pow2ut0 + pow2ut1 - 1) + 1;
				|	MCT_ICT :
						(* Precalculate the 2^utdepth[x] *)
						pow2ut0 := LSH(SYSTEM.VAL(LONGINT, 1), utdepth[0]);
						pow2ut1 := LSH(SYSTEM.VAL(LONGINT, 1), utdepth[1]);
						pow2ut2 := LSH(SYSTEM.VAL(LONGINT, 1), utdepth[2]);

						tdepth[0] := J2KU.Log2Floor(ENTIER(pow2ut0*0.299072
														+ pow2ut1*0.586914
														+ pow2ut2*0.114014 - 0.5) - 1) + 1;

						tdepth[1] := J2KU.Log2Floor(ENTIER(pow2ut0*0.168701
														+ pow2ut1*0.331299
														+ pow2ut2*0.5 - 0.5) - 1) + 1;

						tdepth[2] := J2KU.Log2Floor(ENTIER(pow2ut0*0.5
														+ pow2ut1*0.418701
														+ pow2ut2*0.081299 - 0.5) - 1) + 1;


				ELSE
					KernelLog.String("ERROR: Computation of original component bit depths failed because ");
					KernelLog.String(" the component transformation type is unknown");
					KernelLog.Ln();
					RETURN FALSE;
			END;

			RETURN TRUE;
	END ComputeUntransformedBitDepths;
*)

	(**
		Returns the default options for the decoder
		(i.e. default components and default options for those components)
	*)
	PROCEDURE GetDefaultDecoderOptions* () : J2KU.DecoderOptions;
		VAR
			decOpt : J2KU.DecoderOptions;
			crOpt : J2KU.CodestreamReaderOptions;
			edOpt : J2KU.EntropyDecoderOptions;
			roiOpt : J2KU.ROIDescalerOptions;
			deqOpt : J2KU.DequantizerOptions;
			invDWTOpt : J2KU.InverseDWTOptions;
			invMCTOpt : J2KU.InverseMCTOptions;
		BEGIN
			(* NOTE: We set the minimum decomposition level and maximum number of layers as fixed *)
			NEW(decOpt);

			(* --- Options for codestream reader --- *)
			NEW(crOpt);
			(* We use the buffered codestream reader by default *)
			crOpt.component := J2KCS.BUF_CODESTREAM_READER;
			crOpt.printComments := FALSE;
			decOpt.crOpt := crOpt;

			(* --- Options for entropy decoder --- *)
			NEW(edOpt);
			edOpt.component := ENTROPY_DECODER;
			(* By default, we don't conceal errors *)
			edOpt.concealError := FALSE;
			decOpt.edOpt := edOpt;

			(* --- Options for ROI de-scaler --- *)
			NEW(roiOpt);
			roiOpt.component := ROI_DESCALER;
			(* By default ROIs shall not be ignored *)
			roiOpt.noROI := FALSE;
			decOpt.roiOpt := roiOpt;

			(* --- Options for dequantizer --- *)
			NEW(deqOpt);
			deqOpt.component := DEQUANTIZER;
			decOpt.deqOpt := deqOpt;

			(* --- Options for inverse wavelet transformation --- *)
			NEW(invDWTOpt);
			invDWTOpt.component := INVERSE_DWT;
			invDWTOpt.filterRev := FILTER_5X3_LIFTING;
			invDWTOpt.filterIrrev := FILTER_9X7_LIFTING;
			decOpt.invDWTOpt := invDWTOpt;

			(* --- Options for inverse multiple component transformation --- *)
			NEW(invMCTOpt);
			invMCTOpt.component := INVERSE_MCT;
			(* Buffer is not considered as rebuild component by default *)
			invMCTOpt.nonRebuildBuffer := TRUE;
			decOpt.invMCTOpt := invMCTOpt;

			RETURN decOpt;
	END GetDefaultDecoderOptions;


	(**
		Decoder factory procedure
	*)
	PROCEDURE Factory*() : Codecs.ImageDecoder;
		VAR
			decOpt : J2KU.DecoderOptions;
			dec : Decoder;
		BEGIN
			(* Set default decoder options *)
			decOpt := GetDefaultDecoderOptions();

			NEW(dec, decOpt);
			RETURN dec;
	END Factory;

(*
	PROCEDURE DecodeUsage(out : Streams.Writer);
		BEGIN
			out.String("Usage: JPEG2000Decoder.Decode {<option>} <fileName>");
			out.Ln();
			out.Ln();
			out.String("    <option> can be any of the following:");
			out.Ln();
			out.Ln();
			out.String("       /v : View the image. If /bmp option is not used, this option is enabeld automatically");
			out.Ln();
			out.Ln();
			out.String("       /bmp <BMP format> <BMP file name> : write decoded image to a BMP file. ");
			out.Ln();
			out.String("          where <BMP format> may be one of the following:");
			out.Ln();
			out.String("             32 (32 bit rgba, 8 bits for r,g,b and alpha)");
			out.Ln();
			out.String("             24 (24 bit rgb, 8 bits for r,g and b)");
			out.Ln();
			out.String("             16 (16 bit rgb, 5 bits for r & b, 6 bits for g)");
			out.Ln();
			out.Ln();
			out.String("       /decrl <decrease in resolution level>: Decreases the resolution level (0 - 32)");
			out.Ln();
			out.Ln();
			out.String("       /decly <decrease in # layers> : Decreases the number of layers (-> decreases the image quality) (0 - 65535)");
			out.Ln();
			out.Ln();
			out.String("       /com : Print comments. If /csinfo option is used then the comments will be embedded in the codestream info output");
			out.Ln();
			out.Ln();
			out.String("       /noroi : Makes sure that no ROI de-scaling is performed. Decompression is done like there was no ROI in the image");
			out.Ln();
			out.Ln();
			out.String("       /errdet : Error detection shall be performed by the entropy decoder. If errors are detected they will be concealed ");
			out.Ln();
			out.String("                      and the resulting distortion will be less significant. Note that errors can only be detected if the the encoder ");
			out.Ln();
			out.String("                      that generated the data included error resilience information");
			out.Ln();
	END DecodeUsage;


	(**
		Mini decoder application for viewing and storing (as BMP files) JPEG2000 images.
	*)
	PROCEDURE Decode* (context : Commands.Context);
		VAR
			noFile : BOOLEAN;
			file : Files.File;
			fileName : ARRAY 255 OF CHAR;
			fs : J2KU.FileInputStream;
			window : WM.BufferWindow;
			decOpt : J2KU.DecoderOptions;
			decoder : Decoder;
			imgConsumerArr : ARRAY 2 OF ImageConsumer;
			nconsumer : LONGINT;
			rasterImgAdapt : RasterImageAdapter;
			imgWidth, imgHeight, maxProg, format : LONGINT;
			(* --- Variables used in option parsing --- *)
			view : BOOLEAN;
			decResStr : ARRAY 3 OF CHAR;
			decLayStr : ARRAY 6 OF CHAR;
			decRes : LONGINT;
			decLay : LONGINT;
			bmpFormatStr : ARRAY 3 OF CHAR;
			bmpFileName : ARRAY 128 OF CHAR;
			bmpFormat : LONGINT;
			bmpRasterFormat : Raster.Format;
			bmpOut : BOOLEAN;
			bmpImg : Raster.Image;
			bmpTransPar : Raster.PictureTransferParameters;
			bmpStoreRet : ANY;
			opt : ARRAY 255 OF CHAR;
			res : LONGINT;
			(* --- END Variables used in option parsing --- *)
		BEGIN
			noFile := TRUE;
			fs := NIL;
			decRes := 0;
			decLay := 0;
			bmpOut := FALSE;
			view := FALSE;
			nconsumer := 0;

			decOpt := GetDefaultDecoderOptions();

			(* Option parsing loop *)
			WHILE context.arg..Available() > 0 DO

				context.arg.SkipSpaces();
				context.arg.String(opt);

				IF opt = "/v" THEN
					view := TRUE;
				ELSIF opt = "/decrl" THEN
					context.arg.SkipSpaces();

					IF context.arg.Available() = 0 THEN
						context.error.String("No resolution decrease value specified");
						context.error.Ln();
						DecodeUsage();
						RETURN NIL;
					ELSE
						context.arg.String(decResStr);
						decRes := -1;
						Strings.StrToInt(decResStr, decRes);

						IF (decRes < 0) OR (decRes > 32) THEN
							context.error.String("Invalid resolution decrease value");
							context.error.Ln();
							DecodeUsage();
							RETURN NIL;
						END;
					END;
				ELSIF opt = "/decly" THEN
					context.arg.SkipSpaces();

					IF context.arg.Available() = 0 THEN
						context.error.String("No layer decrease value specified");
						context.error.Ln();
						DecodeUsage();
						RETURN NIL;
					ELSE
						context.arg.String(decLayStr);
						decLay := -1;
						Strings.StrToInt(decLayStr, decLay);

						IF (decLay < 0) OR (decLay > 65535) THEN
							context.error.String("Invalid layer decrease value");
							context.error.Ln();
							DecodeUsage();
							RETURN NIL;
						END;
					END;
				ELSIF opt = "/bmp" THEN
					context.arg.SkipSpaces();

					IF strReader.Available() = 0 THEN
						context.error.String("No BMP format specified");
						context.error.Ln();
						DecodeUsage();
						RETURN NIL;
					END;

					context.arg.String(bmpFormatStr);
					bmpFormat := -1;
					Strings.StrToInt(bmpFormatStr, bmpFormat);

					IF bmpFormat = 16 THEN
						bmpRasterFormat := Raster.BGR565;
					ELSIF bmpFormat = 24 THEN
						bmpRasterFormat := Raster.BGR888;
					ELSIF bmpFormat = 32 THEN
						bmpRasterFormat := Raster.BGRA8888;
					ELSE
						context.error.String("Invalid BMP format specified");
						context.error.Ln();
						DecodeUsage();
						RETURN NIL;
					END;

					context.arg.SkipSpaces();

					IF context.arg.Available() = 0 THEN
						context.error.String("No BMP output file specified");
						context.error.Ln();
						DecodeUsage();
						RETURN NIL;
					END;

					context.arg.String(bmpFileName);
					bmpOut := TRUE;
				ELSIF opt = "/com" THEN
					decOpt.crOpt.printComments := TRUE;
				ELSIF opt = "/noroi" THEN
					decOpt.roiOpt.noROI := TRUE;
				ELSIF opt = "/errdet" THEN
					decOpt.edOpt.concealError := TRUE;
				ELSIF context.arg.Available() = 0 THEN
					COPY(opt, fileName);
					noFile := FALSE;
				ELSE
					context.error.String("Invalid option '");
					context.error.String(opt);
					context.error.String("'");
					context.error.Ln();
					DecodeUsage();
					RETURN NIL;
				END;
			END;

			IF noFile THEN
				context.error.String("No file specified");
				context.error.Ln();
				DecodeUsage();
				RETURN NIL;
			END;

			file := Files.Old(fileName);

			IF file = NIL THEN
				context.error.String("Couldn't open file ");
				context.error.String(fileName);
				context.error.Ln();
				RETURN NIL;
			END;

			NEW(fs, file, 0);

			IF (fs = NIL) THEN
				context.error.String("Couldn't open reader on file");
				context.error.Ln();
				RETURN NIL;
			END;

			NEW(decoder, decOpt);

			decoder.Open(fs, res);

			IF decoder.GetNumResolutionLevels() < decRes THEN
				context.out.String("WARNING: Cannot decrease resolution level by ");
				context.out.Int(decRes, 0);
				context.out.String(": Image has only ");
				context.out.Int(decoder.GetNumResolutionLevels(), 0);
				context.out.String(" resolution levels");
				context.out.Ln();

				decRes := decoder.GetNumResolutionLevels();
			ELSIF decoder.GetNumLayers() < decLay THEN
				context.out.String("WARNING: Cannot decrease number of layers by ");
				context.out.Int(decLay, 0);
				context.out.String(": Image has only ");
				context.out.Int(decoder.GetNumLayers(), 0);
				context.out.String(" layers");
				context.out.Ln();

				decLay := decoder.GetNumLayers() - 1;
			END;

			decoder.GetImageSize(decRes, imgWidth, imgHeight);

			(* Check if valid size *)
			IF (imgWidth <= 0) OR (imgHeight <= 0) THEN
				RETURN NIL;
			END;

			decoder.DecreaseResolutionLevel(decRes);
			decoder.DecreaseNumLayers(decLay);

			(* Set up output window and/or file *)
			(* Display the image if the "view" option has been set, or the "output-to-file" option is not set *)
			IF view OR ~bmpOut THEN
				NEW(window, imgWidth, imgHeight, FALSE);
				window.SetTitle(WM.NewString(fileName));
				WM.DefaultAddWindow(window);
				NEW(rasterImgAdapt, window.img);
				imgConsumerArr[nconsumer] := rasterImgAdapt;
				INC(nconsumer);
			END;

			IF bmpOut THEN
				IF view & (window.img.fmt.code = bmpRasterFormat.code) THEN
					bmpImg := window.img;
				ELSE
					NEW(bmpImg);
					Raster.Create(bmpImg, imgWidth, imgHeight, bmpRasterFormat);
					NEW(rasterImgAdapt, bmpImg);
					imgConsumerArr[nconsumer] := rasterImgAdapt;
					INC(nconsumer);
				END;
			END;

			(* Deliver the image to the image consumers *)
			decoder.DeliverImage(imgConsumerArr, 0, nconsumer);

			IF view OR ~bmpOut THEN
				window.Invalidate( Rectangles.MakeRect( 0, 0, window.img.width, window.img.height ) );
			END;

			IF bmpOut THEN
				NEW(bmpTransPar);
				bmpTransPar.img := bmpImg;
				COPY(bmpFileName, bmpTransPar.name);
				bmpTransPar.done := FALSE;

				bmpStoreRet := AosBMPImages.AosStore(bmpTransPar);

				IF ~bmpTransPar.done THEN
					context.error.String("Writing decoded image to BMP file failed");
					context.error.Ln;
				END;
			END;
	END Decode;
*)
BEGIN

		InitEntropyTables();
		InitMQTables();

		NEW(filter5x3Lift);
		NEW(filter9x7Lift);

END JPEG2000Decoder.

SystemTools.Free JPEG2000Decoder~
SystemTools.Free JPEG2000DecoderCS~
SystemTools.Free JPEG2000Util~