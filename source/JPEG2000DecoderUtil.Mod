MODULE JPEG2000DecoderUtil;

	(* Part of the JPEG2000 decoder implementation *)
	(* Partially based on the JJ2000 reference implementation of EPF Lausanne (http://jj2000.epfl.ch) *)
	(* Contains utility types *)

	IMPORT SYSTEM, KernelLog;

	CONST

		(* Number of bits used to represent a LONGINT *)
		LONGINT_BITS* = SYSTEM.VAL(LONGINT, SIZEOF(LONGINT) * 8);
		(* Mask to set / test for the sign bit of a LONGINT, i.e. the MSB of a LONGINT register *)
		LONGINT_SIGN_BIT* = {LONGINT_BITS - 1};

		SWAP_MASK* = SYSTEM.VAL(LONGINT, -1);

		(* --- Subband types --- *)
		SUB_LL*	= 0;
		SUB_HL*	= 1;
		SUB_LH*	= 2;
		SUB_HH*	= 3;

		(* --- Subband types --- *)

		(* --- Constants used by FileInputStream --- *)

		DEFAULT_READER_SIZE = 65536;
		WRITE_ERROR = 2907;

		(* --- END Constants used by FileInputStream --- *)


	TYPE
		(* --- Utility types --- *)
		LongIntArrayPtr* = POINTER TO ARRAY OF LONGINT;
		LongInt2DArrayPtr* = POINTER TO ARRAY OF LongIntArrayPtr;
		LongInt3DArrayPtr* = POINTER TO ARRAY OF LongInt2DArrayPtr;
		LongInt4DArrayPtr* = POINTER TO ARRAY OF LongInt3DArrayPtr;

		ByteArrayPtr* = POINTER TO ARRAY OF CHAR;
		RealArrayPtr* = POINTER TO ARRAY OF REAL;
		SetArrayPtr* = POINTER TO ARRAY OF SET;

		ByteArrayReader* = OBJECT
			VAR
				arr : ByteArrayPtr;			(* A pointer to the raw coded code-block data  that will be processed *)
				arrPos, 						(* The byte position in the raw coded code-block data *)
				dataLen : LONGINT;			(* The number of total bytes of this array (adding the offset) *)

			PROCEDURE &InitNew* (arr : ByteArrayPtr; offset, len : LONGINT);
				BEGIN
					ReInit(arr, offset, len);
			END InitNew;

			PROCEDURE ReInit* (arr : ByteArrayPtr; offset, len : LONGINT);
				BEGIN
					SELF.arr := arr;
					arrPos := offset;
					dataLen := offset + len;
			END ReInit;

			(**
				Sets the byte array from which to read data.
			*)
			PROCEDURE SetArray* (arr : ByteArrayPtr; offset, len : LONGINT);
				BEGIN

					(*
						NOTE:
						If a parameter has an "illegal" value, we don't set it.
						But we set those values which are in a valid range. In this way only some of the state
						variables may be altered. E.g., this could be desirable when a data array has multiple
						segments.
					*)
					IF arr # NIL THEN
						SELF.arr := arr;
						dataLen := offset + len;
						arrPos := offset;
					ELSIF offset < 0 THEN
						arrPos := dataLen;
						INC(dataLen, len);
					ELSE
						dataLen := offset + len;
						arrPos := offset;
					END;
			END SetArray;

			(**
				Reads the next byte in the internal array. If no (more)
				data is available then -1 is returned.
			*)
			PROCEDURE Read* () : LONGINT;
				BEGIN
					IF (arr = NIL) OR (arrPos >= dataLen) THEN
						(* End of array *)
						RETURN -1;
					ELSE

						INC(arrPos);
						RETURN ORD(arr[arrPos - 1]);
					END;
			END Read;

		END ByteArrayReader;

		(**
			An interface for objects that are sources for single bits (e.g. of a stream).
		*)
		BitSource* = OBJECT
			VAR
				PROCEDURE NextBit* () : LONGINT;
				END NextBit;
		END BitSource;

		(**
			Returns single bits (instead of bytes as ByteArrayReader).
			NOTE: This object is specially tailored for the use in an
			entropy decoder.
		*)
		DataBitReader* = OBJECT(BitSource)
			VAR
				br : ByteArrayReader;
				curByte : LONGINT;
				curBytePos : LONGINT;

			PROCEDURE &InitNew* (br : ByteArrayReader);
				BEGIN
					ReInit(br);
			END InitNew;

			PROCEDURE ReInit* (br : ByteArrayReader);
				BEGIN
					SELF.br := br;
					curBytePos := 0;
					curByte := 0;
			END ReInit;

			PROCEDURE NextBit* () : LONGINT;
				BEGIN
					IF curBytePos =  0 THEN
						(* Do bit unstuffing? *)
						IF SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, curByte) * {0..7}) = 0FFH THEN
							curBytePos := 7;
						ELSE
							curBytePos := 8;
						END;
						curByte := br.Read();
					END;

					DEC(curBytePos);

					RETURN SYSTEM.VAL(LONGINT,
											SYSTEM.VAL(SET, LSH(curByte, -curBytePos))
											* {0}
										);
			END NextBit;

			(**
				Starts a new (raw/bypass) segment.
			*)
			PROCEDURE NextSegment* (data : ByteArrayPtr; offset, len : LONGINT);
				BEGIN
					br.SetArray(data, offset, len);
					curBytePos := 0;
					curByte := 0;
			END NextSegment;

			(**
				Checks the byte padding. This procedure checks the remainder of
				each raw segment and tries to detect errors
			*)
			PROCEDURE CheckBytePadding* () : BOOLEAN;
				VAR
					seq : LONGINT;
				BEGIN

					(* If there are no bits left and the current byte is 0xFF then there is a next byte with bit stuffing *)
					IF (curBytePos <= 0) & (curByte = 0FFH) THEN
						curByte := br.Read();
						curBytePos := 7;
					END;

					(*
						(1)
						The last bits that have not been read yet must be an
						alternating sequence of 0's and 1's, starting with a 0
					*)
					IF curBytePos > 0 THEN
						seq := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, curByte) * SYSTEM.VAL(SET, LSH(1, curBytePos) - 1));

						IF seq # LSH(55H, curBytePos - 8) THEN
							RETURN FALSE;
						END;
					END;

					(*
						(2)
						We must have already reached the last byte in the terminated segment, unless
						the last bit read is the LSB of a 0xFF byte in which case an encoder may have
						added an extra byte smaller than 0x80
					*)
					IF curByte # -1 THEN
						IF (curByte = 0FFH) & (curBytePos = 1) THEN
							IF br.Read() >= 80H THEN
								RETURN FALSE;
							END;
						ELSIF br.Read() # -1 THEN
							RETURN FALSE;
						END;
					END;

					RETURN TRUE;
			END CheckBytePadding;

		END DataBitReader;



		(* --- END Utility types --- *)


		(**
			Holds a pointer to compressed image data for a specific code-block. Some
			information on the compressed data is contained as well.
		*)
		CodedCblk* = RECORD
			cpasses* : LONGINT;		(* Number of coding passes for this coded code-block *)
			nseg* : LONGINT;			(* The number of of segments for this coded code-block *)
			segLen* : LongIntArrayPtr;	(* The length of each segment of raw data for this coded code-block and the included coding passes *)
			dataOffset* : LONGINT;		(* The offset into the data array where the data for this coded code-block begins *)
			dataLen* : LONGINT;		(* Thel length of all segments together *)
			data* : ByteArrayPtr;	(* The compressed image data *)
		END;


		(**
			Contains information about a (data) block.
		*)
		BlkInfo* = OBJECT
			VAR
				ulx*, uly* : LONGINT;		(* The blocks upper-left corner x and y coordinates. these coordinates are relative to the reference grid *)
				height*, width* : LONGINT;	(* The width and height of the block (in samples) *)
		END BlkInfo;

		(**
			Contains information about a specific code-block.
		*)
		CblkInfo* = OBJECT(BlkInfo)
			VAR
				(* TODO: Do we really need those two fields? *)
				ulsx*, ulsy* : LONGINT;			(* The code-blocks upper-left corner x and y coordinates. See SubbandInfo object for more information *)
				truncpt* : LONGINT;				(* The truncation point for the code-block, i.e. the total number of coding passes read for the code-block up to now *)
				cpasseslyr* : LongIntArrayPtr;	(* The number of coding passes for each layer *)
				zerobp* : LONGINT;				(* The number of zero bit-planes for this code-block *)
				curbp* : LONGINT;				(* The index of the least significant bit-plane which has been decoded (31 means that no bit-plane has been decoded yet) *)
				datalenlyr* : LongIntArrayPtr;	(* The data length for the code-block in each layer *)
				subbinfo* : SubbandInfo;			(* A reference to the subband info object which describes the subband this code-block belongs to *)
				index* : LONGINT;				(* Index of the code-block in the subband (numbered in raster order) *)
		END CblkInfo;


		(**
			Contains information about a specific subband (of a certain tile-component).
				NOTE:	A subband may also be one that is not present yet, i.e. will be created through
						(inverse) wavelet transformation (that means that a LL subband of the next higher
						resolution level has been created).
		*)
		SubbandInfo* = OBJECT
			VAR
				type* : LONGINT;				(* The subband type: SUB_LL, SUB_HL, SUB_LH or SUB_HH *)
				index* : LONGINT;				(* The index of the subband relativ to the other subbands of the same decomposition level *)
												(* -> SUB_LL: 0, SUB_HL: 0, SUB_LH: 1, SUB_HH: 2 *)
				ulcx*, ulcy* : LONGINT;			(* The upper left horizontal and vertical coordinates relative to the component this subband belongs to *)
												(* NOTE: These are the actual coordinates of the subband in the component domain of the image *)
				ulsx*, ulsy* : LONGINT;			(* The upper left horizontal and vertical coordinates of the subband *)
												(* NOTE: These coordinates ensure that the subband is placed at the right position for the filtering process. If the image consists of only 1 tile then these coordinates are almost the same as ulcx & ulcy (except that we usually start at the origin here)*)
				width*, height* : LONGINT;		(* The width and height of the subband (in component samples) *)
				nblocksx*, nblocksy* : LONGINT;	(* The number of code-blocks (in horizontal and vertical direction) contained in this subband *)
				magbits* : LONGINT;			(* The maximum number of magnitude bits for any coefficient in this subband (this number plays a role in the entropy decoding and dequantization process *)
				component* : LONGINT;			(* The index of the component to which the subband belongs to *)
				reslevel* : LONGINT;			(* The resolution level to which the subband belongs to *)
				declevel* : LONGINT;			(* The decomposition level this subband belongs to *)
		END SubbandInfo;

		(**
			Used as node in a tag tree.
		*)
		TreeNode = RECORD
			value : LONGINT;
			valid : BOOLEAN;
		END;


		(**
			This object is used to code 2 dimensional arrays of integer values by using a tag tree
			(refer to the JPEG2000 Specification, Annex B.10.2 for details). Partial tag trees are
			also covered.
		*)
		TagTree* = OBJECT
			VAR
				(* The index of the maximum level of this tag tree = LEN(nodes^) - 1 *)
				maxLevel : LONGINT;
				maxX : LONGINT;	(* max. index in x direction (equals max. horizontal index of coded matrix) *)
				maxY : LONGINT;	(* max. index in y direction (equals max. vertical index of coded matrix) *)
				(*
					1st dim.: level (top node is located at level 0)
					2nd dim.: node index
				*)
				nodes : POINTER TO ARRAY OF POINTER TO ARRAY OF TreeNode;
				src : BitSource;	(* A reference to the bit source *)

			PROCEDURE &InitNew*(ncblx, ncbly : LONGINT; src : BitSource);
				VAR
					x, y, i, j, prod : LONGINT;
				BEGIN
					maxX := ncblx - 1;
					maxY := ncbly - 1;
					i := 1;
					maxLevel := 0;
					(* The maximum value of height and width determines the amount of levels *)
					IF ncblx > ncbly THEN
						WHILE i < ncblx DO
							INC(maxLevel);
							i := LSH(i, 1);
						END;
					ELSE
						WHILE i < ncbly DO
							INC(maxLevel);
							i := LSH(i, 1);
						END;
					END;

					NEW(nodes, maxLevel+1);

					x := ncblx;
					y := ncbly;
					(* For every level we have to compute the number of nodes, allocate the needed space, and initialize each node *)
					FOR i := maxLevel TO 0 BY -1 DO
						prod := x*y;
						NEW(nodes[i], prod);

						FOR j := 0 TO prod - 1 DO
							nodes[i][j].value := 0;
							nodes[i][j].valid := FALSE;
						END;

						x := LSH(x, -1) + SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, x) * {0});
						y := LSH(y, -1) + SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, y) * {0});
					END;

					SELF.src := src;
			END InitNew;

			(**
				Update the tag tree
				x: 			The horizontal index of the node that needs to be updated
				y: 			The vertical index of the node that needs to be updated
				threshold:	This value determines the threshold to which node values
										maybe incremented in the current procedure call (needed for
										partial tag trees). Actually each node value may be incremented by one
										if the current value is lower than or equal to the threshold
				RETURN: TRUE, if the update operation succeeded, FALSE otherwise
			*)
			PROCEDURE Update*(x, y : LONGINT; threshold : LONGINT) : BOOLEAN;
				VAR
					level, shift, bit, idx, nextIdx, prevIdx : LONGINT;
				BEGIN
					(*
						Precondition :	There is a level lev <= maxLevel, and an index idx such that
										nodes[lev][idx].valid = FALSE and the node represented by nodes[lev][idx]
										is parent of the node represented by nodes[maxLevel][<index of node (x,y) at maxLevel>]
										in the tag tree. maxLevel is assumed to be >= 0.
						Postcondition :	The node described in the precondition has either become valid or its value has increased, i.e.
										the value may be increased later (we use a lazy-update strategy)
						Invariant(s):		num of valid nodes = num of '1's read from the stream
										num of value incrementations = num of '0's read from the stream
										If node(x).valid then node(y).valid for all y: node(y)=ancestor(node(x))
					*)
					IF (x > maxX) OR (y > maxY) THEN
						(* Out of bounds *)
						KernelLog.String("ERROR (TagTree.Update): Indices for tag tree are too large");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					(* Init value to 'first' - 1 ('first' + 1 for shift)*)
					level := -1;
					shift := maxLevel+1;	(* shift is needed to compute the correct index of the ancestors of x,y at each level *)

					(* Skip all valid nodes *)
					REPEAT
						INC(level);
						DEC(shift);
						prevIdx := idx;
						idx := LSH(y, -shift) * (LSH(maxX, -shift) + 1) + LSH(x, -shift);
					UNTIL (level >= maxLevel) OR ~nodes[level][idx].valid;

					IF nodes[level][idx].valid THEN
						(* Precondition not satisfied *)
						KernelLog.String("ERROR: Precondition of TagTree.Update violated");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					(* Restore tag tree condition for the current node *)
					IF (level > 0) & (nodes[level-1][prevIdx].value > nodes[level][idx].value) THEN
						nodes[level][idx].value := nodes[level-1][prevIdx].value;
					END;

					(* Traverse the tree and increment or validate the current node *)
					WHILE (nodes[level][idx].value <= threshold) & (level < maxLevel) DO
						bit := src.NextBit();
						(* We need to have all values on the path to the node being updated *)
						IF bit = 1 THEN
							nodes[level][idx].valid := TRUE;
							INC(level);
							DEC(shift);
							nextIdx := LSH(y, -shift) * (LSH(maxX, -shift) + 1) + LSH(x, -shift);
							nodes[level][nextIdx].value := nodes[level-1][idx].value;
							idx := nextIdx;
						ELSE
							INC(nodes[level][idx].value);
						END;
					END;

					WHILE ~nodes[level][idx].valid & (nodes[level][idx].value <= threshold) DO
						(*
						 	Since we are (or at least should be) at the maximum level we need to increment
							as long as '0's are following or the threshold has been passed
						*)
						bit := src.NextBit();
						IF bit = 1 THEN
							nodes[level][idx].valid := TRUE;
						ELSE
							INC(nodes[level][idx].value);
						END;
					END;

					RETURN TRUE;
			END Update;

			(**
				Test if the node (x,y) is valid (at the max. level)
				RETURN:	TRUE, if the node (x,y) is valid (at the max. level), FALSE otherwise
			*)
			PROCEDURE IsValid* (x, y : LONGINT) : BOOLEAN;
				BEGIN
					IF (x > maxX) OR (y > maxY) THEN
						KernelLog.String("ERROR (TagTree.IsValid): Index out of bounds");
						RETURN FALSE;
					END;

					RETURN nodes[maxLevel][y * (maxX + 1) + x].valid;
			END IsValid;

			(*
				SUMMARY:	Returns the current value of node (x,y) (at the max. level). NOTE: This value may
							be 0 even if the current value should be higher; that's because we use a lazy-update
							strategy. So the returned value only makes sense if the the node is valid.
				RETURN:	The current value of the node (x,y) (or 0 -> see SUMMARY above), -1 if an error occurred
			*)
			PROCEDURE CurrentVal* (x, y : LONGINT) : LONGINT;
				BEGIN
					IF (x > maxX) OR (y > maxY) THEN
						KernelLog.String("ERROR (TagTree.CurrentVal): Index out of bounds");
						RETURN -1;
					END;

					RETURN nodes[maxLevel][y * (maxX + 1) + x].value;
			END CurrentVal;

		END TagTree;

	(*
		(**
			This object is used in the same way as Rider0 is used in the Files module.
			The object declaration was copied and adapted from the Files module.
		*)
		RiderWrapper = OBJECT
			VAR
				r: Files.Rider;

			PROCEDURE Send(VAR buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
				BEGIN
					r.file.WriteBytes(r, buf, ofs, len);
					IF propagate THEN r.file.Update END;
					IF r.res = 0 THEN res := Streams.Ok ELSE res := WRITE_ERROR (* not all bytes written *) END
			END Send;

			PROCEDURE Receive(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
				BEGIN
					r.file.ReadBytes(r, buf, ofs, size);
					len := size - r.res;
					IF len >= min THEN res := Streams.Ok ELSE res := Streams.EOF (* end of file *) END
			END Receive;

		END RiderWrapper;


		FileInputStream* = OBJECT(Streams.Reader)	(* not shareable between multiple processes *)
			VAR
				r: RiderWrapper;

			PROCEDURE &InitFileStream* (f : Files.File; pos : LONGINT);
				BEGIN
					NEW(r); f.Set(r.r, pos);
					InitReader(r.Receive, DEFAULT_READER_SIZE)
			END InitFileStream;

		END FileInputStream;
	*)

		(**
			Holds the options for the decoder at instantiation time.
		*)
		DecoderOptions* = OBJECT
			VAR
				(* Component-specific options *)
				(* NOTE: Some components may not have any options *)
				crOpt* : CodestreamReaderOptions;
				edOpt* : EntropyDecoderOptions;
				roiOpt* : ROIDescalerOptions;
				deqOpt* : DequantizerOptions;
				invDWTOpt* : InverseDWTOptions;
				invMCTOpt* : InverseMCTOptions;
		END DecoderOptions;

		(**
			An 'abstract' object which shall be implemted by option objects,
			providing settings for each component in the (main) decoding chain.
		*)
		ComponentOptions* = OBJECT
			VAR
				(**
					The identifier of the component that this options apply to.
				*)
				component* : LONGINT;
		END ComponentOptions;

		CodestreamReaderOptions* = OBJECT(ComponentOptions)
			VAR
				(**
					If TRUE, then comments found in the COM segments will be printed.
				*)
				printComments* : BOOLEAN;
		END CodestreamReaderOptions;

		EntropyDecoderOptions* = OBJECT(ComponentOptions)
			VAR
				(**
					Specifies if error detection should be performed by the entropy decoder
					engine. If errors are detected they will be concealed and the resulting
					distortion will be less important.

					NOTE: Errors can only be detected if the encoder that generated the data
					included error resilience information.
				*)
				concealError* : BOOLEAN;
		END EntropyDecoderOptions;

		ROIDescalerOptions* = OBJECT(ComponentOptions)
			VAR
				(**
					This argument makes sure that  no ROI de-scaling is performed.
					Decompression is done like there is no ROI in the image
				*)
				noROI* : BOOLEAN;
		END ROIDescalerOptions;


		(**
			Just a marker interface, presently
		*)
		DequantizerOptions* = OBJECT(ComponentOptions)
		END DequantizerOptions;


		InverseDWTOptions* = OBJECT(ComponentOptions)
			VAR
				filterRev* : LONGINT;	(** The reversible filter to use *)
				filterIrrev* : LONGINT;	(** The irreversible filter to use *)
		END InverseDWTOptions;

		InverseMCTOptions* = OBJECT(ComponentOptions)
			VAR
				(**
					Indicates if the internal buffers shall be conserved or not,
					if a change to the rebuild mode is done. If this is set to
					TRUE, then at each rebuild a new buffer for the components
					is allocated (that is, if a multiple component trans. is used at all)
				*)
				nonRebuildBuffer* : BOOLEAN;
		END InverseMCTOptions;


	(* RETURN: The logarithm (base 2) of the largest power of 2 <= x *)
	PROCEDURE Log2Floor* (x : LONGINT) : LONGINT;
		VAR
			logVal : LONGINT;
		BEGIN
			(* NOTE: We don't check wether x >= 1 *)
			logVal := 0;
			WHILE x > 1 DO
				x := LSH(x, -1);
				INC(logVal);
			END;
			RETURN logVal;
	END Log2Floor;


	(* --- END Utility functions --- *)


	(**
		Returns the index of the subband given the subband type.
		SUB_LL is alone in it's domain, so its index is 0.
		The others constitute a group of 3 and are indexed in raster order
		(i.e. raster order relative to the reference grid)
	*)
	PROCEDURE SubbandToSubbandIndex* (subband : LONGINT) : LONGINT;
		BEGIN
			CASE subband OF
				|	SUB_LL :
						RETURN  0;
				|
					SUB_HL :
						RETURN 0;
				|
					SUB_LH :
						RETURN 1;
				|	SUB_HH :
						RETURN 2;
				ELSE
					RETURN -1;
			END;
	END SubbandToSubbandIndex;

	(**
		The inverse transformation to SubbandToSubbandIndex, except that
		we need to know the resolution level, since the whole operation is not
		bijective.
	*)
	PROCEDURE SubbandIndexToSubband* (reslevel, subbIndex : LONGINT) : LONGINT;
		BEGIN
			IF reslevel = 0 THEN
				ASSERT(subbIndex = 0);
				RETURN SUB_LL;
			ELSE
				CASE subbIndex OF
					|	0 :
							RETURN SUB_HL;
					|	1 :
							RETURN SUB_LH;
					|	2 :
							RETURN SUB_HH;
					ELSE
						(* Should never get here *)
						HALT(99);
				END;
			END;
	END SubbandIndexToSubband;

END JPEG2000DecoderUtil.


SystemTools.Free JPEG2000Util~