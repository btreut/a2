MODULE JPEG2000DecoderCS;

	(* Part of the JPEG2000 decoder implementation *)
	(* Partially based on the JJ2000 reference implementation of EPF Lausanne (http://jj2000.epfl.ch) *)
	(* Contains the J2C codestream parser engine *)

	(*
		KNOWN BUGS:
		- Codestreams with packed packet headers in tile-part headers and with multiple tile-parts
		   won't be decoded correctly if headers are crossing tile-part boundaries and the number of
		   tile-parts for the tile are unknown
	*)

	(*
		TODO:
		- Interpretation of progression order change segments: is the progression order defined
		   in such a segement really referring to the progression after the described one (as
		   suggested by the JJ2000 reference implementation)? (See CodestreamReader.ProgressionChange)
		- Availability of data from the stream could cause some problems (i.e. when the stream is truncated
		   or data is not ready yet)
		- Optimization: in PacketDecoder, ReadCodingPasses could be inlined.
	*)
	IMPORT
		 SYSTEM, J2KU := JPEG2000DecoderUtil, KernelLog, Machine, Streams;

	CONST

		(* --- Compile Options --- *)
		(*
			Some codestream constraints that may be set. This may be used as some kind
			of control mechanism to prevent "out of memory" traps etc. (especially caused
			by corrupted codestreams)
		*)
		MAX_IMG_WIDTH = MAX(LONGINT);	(* Default: MAX(LONGINT) *)
		MAX_IMG_HEIGHT = MAX(LONGINT);	(* Default: MAX(LONGINT) *)
		MAX_TILES = 65535;		(* Default: 65535 (= (maximum tile index + 1) -> refer to the Isot parameter of the SOT segment) *)
		MAX_COMPONENTS = 16384;	(* Default: 16384 (= maximum number of components -> refer to the Csiz parameter of the SIZ segment) *)
		MAX_LAYERS = 65535;	(* Default: 65535 (= maximum number of layers -> refer to the SGcod parameter of the COD segment) *)

		(* --- END Compile Options --- *)

		(* --- Configuration constants --- *)

		CODESTREAM_READER* = 0;
		BUF_CODESTREAM_READER* = 1;

		(* --- END Configuration constants --- *)

		(* --- General constants --- *)

		(**
			This tile-part index is set, when the codestream reader
			and its subcomponents are running in rebuild mode
		*)
		REBUILD_TILEPART* = MAX(LONGINT);

		(* --- END General constants --- *)


		(* --- Codestream Markers --- *)

		SOC		= 0000FF4FH; (* Start of codestream *)
		SOT		= 0000FF90H; (* Start of tile-part *)
		SOD	= 0000FF93H; (* Start of data *)
		EOC		= 0000FFD9H; (* End of codestream *)
		SIZ		= 0000FF51H; (* Image and tile size *)
		COD		= 0000FF52H; (* Coding style default *)
		COC		= 0000FF53H; (* Coding style component *)
		RGN	= 0000FF5EH; (* Region-of-interest *)
		QCD		= 0000FF5CH; (* Quantization default *)
		QCC		= 0000FF5DH; (* Quantization component *)
		POC		= 0000FF5FH; (* Progression order change *)
		TLM	= 0000FF55H; (* Tile-part lengths *)
		PLM	= 0000FF57H; (*  Packet length, main header *)
		PLT		= 0000FF58H; (* Packet length, tile-part header *)
		PPM	= 0000FF60H; (* Packed packet headers, main header *)
		PPT		= 0000FF61H; (* Packed packet headers, tile-part header *)
		SOP		= 0000FF91H; (* Start of packet *)
		EPH		= 0000FF92H; (* End of packet header *)
		CRG		= 0000FF63H; (* Component registration *)
		COM	= 0000FF64H; (* Comment *)

		(* --- END Codestream Markers --- *)

		ENTROPY_NUM_PASSES = 3;
		ENTROPY_FIRST_BYPASS_IDX = 3 * ENTROPY_NUM_PASSES + 1;

		(* --- Quantization styles --- *)

		NOQUANT*		= 00000000H;	(* No quantization *)
		QUANT_DER*	= 00000001H;	(* Scalar derived quantization *)
		QUANT_EXP*	= 00000002H;	(* Scalar expounded quantization *)

		(* --- END Quantization styles --- *)


		(* --- Wavelet transformation types --- *)

		TRANS_9X7_IRREV*	= 00000000H;
		TRANS_5X3_REV*	= 00000001H;

		(* --- END Wavelet transformation types --- *)


		(* --- Progression orders --- *)

		PROG_LRCP	= 00000000H;	(* Layer - resolution level - component - position progression *)
		PROG_RLCP	= 00000001H;	(* Resolution level - layer - component - position progression *)
		PROG_RPCL	= 00000002H;	(* Resolution level - position -  component - layer progression *)
		PROG_PCRL	= 00000003H;	(* Position - component - resolution level - layer progression *)
		PROG_CPRL	= 00000004H;	(* Component - position - resolution level - layer progression *)

		(* --- END Progression orders --- *)

		(* --- Precinct constants --- *)

		MAX_PREC_SIZ = 15;

		(* --- END Precinct constants --- *)
TYPE

		PrecinctExp = RECORD
			ppx : LONGINT;	(* Precinct width exponent *)
			ppy : LONGINT;	(* Precinct height exponent *)
		END;


		(** Component dependent coding style *)
		CodingStyle = OBJECT
			VAR
				maxps : BOOLEAN;			(* Maximum precinct size used? *)
				ndec : LONGINT;				(* Number of decomposition levels *)
				cblw : LONGINT;				(* Code-block width exponent *)
				cblh : LONGINT;				(* Code-block heigth exponent *)
				selcb : BOOLEAN;				(* Selective arithmetic coding bypass? *)
				rescp : BOOLEAN;				(* Reset context probabilities on coding pass boundaries? *)
				term : BOOLEAN;				(* Termination on each coding pass? *)
				vert : BOOLEAN;				(* Vertically causal context? *)
				pred : BOOLEAN;				(* Predictable termination? *)
				segs : BOOLEAN;				(* Segmentation symbols used? *)
				trans : LONGINT;				(* Wavelet transformation type *)
				precs : POINTER TO ARRAY OF PrecinctExp;	(* Precinct sizes (in defined order) *)
		END CodingStyle;

		(** Component Independent Coding Style *)
		CICodingStyle = OBJECT
			VAR
				po : LONGINT;		(* Progression order *)
				nl : LONGINT;		(* Number of layers *)
				mct : LONGINT;	(* Multiple component tranformation type *)
				sop : BOOLEAN;	(* SOP markers used? *)
				eph : BOOLEAN;	(* EPH markers used? *)
		END CICodingStyle;

		Component = OBJECT
			VAR
				signed : BOOLEAN;	(* TRUE if component samples are signed values *)
				depth : LONGINT;		(* Component bit depth *)
				subsx : LONGINT;		(* Horizonal separation (sub-sampling factor) of the component *)
				subsy : LONGINT;		(* Vertical separation (sub-sampling factor) of the component *)
		END Component;

		Quantization = OBJECT
			VAR
				style : LONGINT;			(* Quantization style *)
				nguardb : LONGINT;		(* Number of guard bits *)
				nstepsiz : LONGINT;
				stepsiz : POINTER TO ARRAY OF QuantStep;	(* Array containing quantization step sizes (if signalled in codestream) *)
		END Quantization;

		QuantStep = OBJECT
			VAR
				mant : LONGINT;	(* Mantissa *)
				exp : LONGINT;	(* Exponent *)
		END QuantStep;

		(**
			Image information object. Gives information on image width/heigth
			on different decomposition levels etc.
		*)
		ImageInfo* = OBJECT
			VAR
				xsiz, ysiz : LONGINT;		(* Width / height of reference grid *)
				xos, yos : LONGINT;		(* Horizontal / vertical offset from the origin *)
				nt : LONGINT;			(* Overall number of tiles *)
				nxt, nyt : LONGINT;		(* Number of tiles in horizontal / vertical direction *)
				xt, yt : LONGINT;		(* Width / height of one reference tile w.r.t the reference grid *)
				xtos, ytos : LONGINT;	(* Horizontal / vertical offset from the origin to the first tile *)
				ncomp : LONGINT;		(* Number of components in the image *)
				comps : POINTER TO ARRAY OF Component;

			(**
				Get width of image on reference grid at decomposition level 'declevel'.
			*)
			PROCEDURE GetImgWidth* (declevel : LONGINT) : LONGINT;
				VAR
					tmp : LONGINT;
				BEGIN
					tmp := LSH(SYSTEM.VAL(LONGINT, 1), declevel) - 1;

					RETURN LSH(xsiz + tmp, -declevel) - LSH(xos + tmp, -declevel);
			END GetImgWidth;

			(**
				Get height of image on reference grid at decomposition level 'declevel'.
			*)
			PROCEDURE GetImgHeight* (declevel : LONGINT) : LONGINT;
				VAR
					tmp : LONGINT;
				BEGIN
					tmp := LSH(SYSTEM.VAL(LONGINT, 1), declevel) - 1;

					RETURN LSH(ysiz + tmp, -declevel) - LSH(yos + tmp, -declevel);
			END GetImgHeight;

			(**
				Get horizontal image offset relative to reference grid origin at decomposition level 'declevel'.
			*)
			PROCEDURE GetImgULX* (declevel : LONGINT) : LONGINT;
				VAR
					tmp : LONGINT;
				BEGIN
					tmp := LSH(SYSTEM.VAL(LONGINT, 1), declevel) - 1;

					RETURN LSH(xos + tmp, -declevel);
			END GetImgULX;

			(**
				Get vertical image offset relative to reference grid origin at decomposition level 'declevel'.
			*)
			PROCEDURE GetImgULY* (declevel : LONGINT) : LONGINT;
				VAR
					tmp : LONGINT;
				BEGIN
					tmp := LSH(SYSTEM.VAL(LONGINT, 1), declevel) - 1;

					RETURN LSH(yos + tmp, -declevel);
			END GetImgULY;

			(**
				Get width of one component on reference grid at decomposition level 'declevel'.
			*)
			PROCEDURE GetCompImgWidth* (component, declevel : LONGINT) : LONGINT;
				VAR
					subsx, tmp, cx0, cx1 : LONGINT;
					(* cx0 : Horizontal coordinate of upper left hand sample of component *)
					(* cx1 - 1: Horizontal coordinate of lower right hand sample of component *)
				BEGIN
					subsx := comps[component].subsx;
					tmp := LSH(SYSTEM.VAL(LONGINT, 1), declevel) - 1;

					cx0 := (xos + subsx - 1) DIV subsx;
					cx1 := (xsiz + subsx - 1) DIV subsx;

					RETURN LSH(cx1 + tmp, -declevel) - LSH(cx0 + tmp, -declevel);
			END GetCompImgWidth;

			(**
				Get height of one component on reference grid at decomposition level 'declevel'.
			*)
			PROCEDURE GetCompImgHeight* (component, declevel : LONGINT) : LONGINT;
				VAR
					subsy, tmp, cy0, cy1 : LONGINT;
					(* cy0 : Vertical coordinate of upper left hand sample of component *)
					(* cy1 - 1: Vertical coordinate of lower right hand sample of component *)
				BEGIN
					subsy := comps[component].subsy;
					tmp := LSH(SYSTEM.VAL(LONGINT, 1), declevel) - 1;

					cy0 := (yos + subsy - 1) DIV subsy;
					cy1 := (ysiz + subsy - 1) DIV subsy;

					RETURN LSH(cy1 + tmp, -declevel) - LSH(cy0 + tmp, -declevel);
			END GetCompImgHeight;


			(**
				Get total numbe of tiles in the image.
			*)
			PROCEDURE GetNumTiles* () : LONGINT;
				BEGIN
					RETURN nt;
			END GetNumTiles;

			(**
				Get number of tiles in horizontal direction.
			*)
			PROCEDURE GetNumTilesX* () : LONGINT;
				BEGIN
					RETURN nxt;
			END GetNumTilesX;

			(**
				Get number of tiles in horizontal direction.
			*)
			PROCEDURE GetNumTilesY* () : LONGINT;
				BEGIN
					RETURN nyt;
			END GetNumTilesY;

			(**
				Get width of tile with index 'tile' on reference grid at decomposition level 'declevel'.
			*)
			PROCEDURE GetTileWidth* (tile, declevel : LONGINT) : LONGINT;
				VAR
					tx0, tx1, p, tmp : LONGINT;
				BEGIN
					tmp := LSH(SYSTEM.VAL(LONGINT, 1), declevel) - 1;

					(* Compute the horizontal index of the current tile in the reference grid *)
					p := tile MOD nxt;

					(* Compute upper and lower x-coordinate *)
					tx0 := xtos + p*xt;
					tx1 := tx0 + xt;

					(* Handle boundary conditions *)
					IF xos > tx0 THEN
						tx0 := xos;
					END;

					IF xsiz < tx1 THEN
						tx1 := xsiz;
					END;

					RETURN LSH(tx1 + tmp, -declevel) - LSH(tx0 + tmp, -declevel);
			END GetTileWidth;

			(**
				Get height of tile with index 'tile' on reference grid at decomposition level 'declevel'.
			*)
			PROCEDURE GetTileHeight* (tile, declevel : LONGINT) : LONGINT;
				VAR
					ty0, ty1, q, tmp : LONGINT;
				BEGIN
					tmp := LSH(SYSTEM.VAL(LONGINT, 1), declevel) - 1;

					(* Compute the vertical index of the current tile in the reference grid *)
					q := tile DIV nxt;

					(* Compute upper and lower y-coordinate *)
					ty0 := ytos + q*yt;
					ty1 := ty0 + yt;

					(* Handle boundary conditions *)
					IF yos > ty0 THEN
						ty0 := yos;
					END;

					IF ysiz < ty1 THEN
						ty1 := ysiz;
					END;

					RETURN LSH(ty1 + tmp, -declevel) - LSH(ty0 + tmp, -declevel);
			END GetTileHeight;

			(**
				Get horizontal offset of tile with index 'tile' relative to reference grid origin
				at decomposition level 'declevel'.
			*)
			PROCEDURE GetTileULX* (tile, declevel : LONGINT) : LONGINT;
				VAR
					tx0, p, tmp : LONGINT;
				BEGIN
					tmp := LSH(SYSTEM.VAL(LONGINT, 1), declevel) - 1;

					(* Compute the horizontal index of the current tile in the reference grid *)
					p := tile MOD nxt;

					(* Determine the actual upper left x-coordinate of the tile *)
					tx0 := xtos + p*xt;

					IF xos > tx0 THEN
						tx0 := xos;
					END;

					RETURN LSH(tx0 + tmp, -declevel);
			END GetTileULX;

			(**
				Get horizontal offset of tile with index 'tile' relative to reference grid origin
				at decomposition level 'declevel'.
			*)
			PROCEDURE GetTileULY* (tile, declevel : LONGINT) : LONGINT;
				VAR
					ty0, q, tmp : LONGINT;
				BEGIN
					tmp := LSH(SYSTEM.VAL(LONGINT, 1), declevel) - 1;

					(* Compute the vertical index of the current tile in the reference grid *)
					q := tile DIV nxt;

					(* Determine the actual upper left y-coordinate of the tile *)
					ty0 := ytos + q*yt;

					IF yos > ty0 THEN
						ty0 := yos;
					END;

					RETURN LSH(ty0 + tmp, -declevel);
			END GetTileULY;

			PROCEDURE GetNumComponents* () : LONGINT;
				BEGIN
					RETURN ncomp;
			END GetNumComponents;

			(**
				Get horizontal subsampling factor of component 'component'
			*)
			PROCEDURE GetSubsX* (component : LONGINT) : LONGINT;
				BEGIN
					RETURN comps[component].subsx;
			END GetSubsX;

			(**
				Get vertical subsampling factor of component 'component'
			*)
			PROCEDURE GetSubsY* (component : LONGINT) : LONGINT;
				BEGIN
					RETURN comps[component].subsy;
			END GetSubsY;


			PROCEDURE GetBitDepth* (component : LONGINT) : LONGINT;
				BEGIN
					RETURN comps[component].depth;
			END GetBitDepth;

		END ImageInfo;


		(**
			This object is used to obtain information on the codestream (image info, coding styles, etc.)
			It's created by and obtained through the codestream reader.
		*)
		DecoderSpecs* = OBJECT
			VAR
				imgInfo : ImageInfo;
				(* 1st dimension: tile index; 2nd dimension (if any): component index *)
				cstyle : POINTER TO ARRAY OF ARRAY OF CodingStyle;
				cics : POINTER TO ARRAY OF CICodingStyle;
				quant : POINTER TO ARRAY OF ARRAY OF Quantization;
				roiShift : POINTER TO ARRAY OF ARRAY OF LONGINT;

			PROCEDURE &InitNew*;
				BEGIN
					imgInfo := NIL;
					cstyle := NIL;
					cics := NIL;
					quant := NIL;
					roiShift := NIL;
			END InitNew;

			(**
				Return the image information object
			*)
			PROCEDURE GetImageInfo* () : ImageInfo;
				BEGIN
					RETURN imgInfo;
			END GetImageInfo;

			(**
				TRUE if arithmetic bypass coding is used for the given tile-component.
			*)
			PROCEDURE BypassCoding* (tile, component : LONGINT) : BOOLEAN;
				BEGIN
					RETURN cstyle[tile][component].selcb;
			END BypassCoding;

			(**
				TRUE if regular termination is used when decoding data for the given tile-component.
			*)
			PROCEDURE RegularTermination* (tile, component : LONGINT) : BOOLEAN;
				BEGIN
					RETURN cstyle[tile][component].term;
			END RegularTermination;

			(**
				TRUE if vertically causal context formation is used when decoding data for the given tile-component.
			*)
			PROCEDURE VerticallyCausalContext* (tile, component : LONGINT) : BOOLEAN;
				BEGIN
					RETURN cstyle[tile][component].vert;
			END VerticallyCausalContext;

			(**
				TRUE if predictable termination is used when decoding data for the given tile-component.
			*)
			PROCEDURE PredictableTermination* (tile, component : LONGINT) : BOOLEAN;
				BEGIN
					RETURN cstyle[tile][component].pred;
			END PredictableTermination;

			(**
				TRUE if contexts are reset after each coding pass when decoding data for the given tile-component.
			*)
			PROCEDURE ResetContexts* (tile, component : LONGINT) : BOOLEAN;
				BEGIN
					RETURN cstyle[tile][component].rescp;
			END ResetContexts;

			(**
				TRUE if segmentation symbols are used when decoding data for the given tile-component.
			*)
			PROCEDURE SegmentationSymbols* (tile, component : LONGINT) : BOOLEAN;
				BEGIN
					RETURN cstyle[tile][component].segs;
			END SegmentationSymbols;

			(**
				The wavelet transformation type used for the give tile-component
			*)
			PROCEDURE GetWavTransType* (tile, component : LONGINT) : LONGINT;
				BEGIN
					RETURN cstyle[tile][component].trans;
			END GetWavTransType;

			(**
				TRUE if the wavelet transformation for the given tile-component is reversible
			*)
			PROCEDURE IsReversibleWavTrans* (tile, component : LONGINT) : BOOLEAN;
				BEGIN
					RETURN cstyle[tile][component].trans = TRANS_5X3_REV;
			END IsReversibleWavTrans;

			(**
				TRUE if a multiple component transformation is used for the given tile.
			*)
			PROCEDURE CompTransUsed* (tile : LONGINT) : BOOLEAN;
				BEGIN
					RETURN cics[tile].mct # 0;
			END CompTransUsed;

			(**
				Returns the number of wavelet decomposition levels for a given
				tile-component.
			*)
			PROCEDURE GetNumDecLevels* (tile, component : LONGINT) : LONGINT;
				BEGIN
					RETURN cstyle[tile][component].ndec;
			END GetNumDecLevels;

			(**
				Gets the minimum number of wavelet decomposition levels over all
				tile-components
			*)
			PROCEDURE GetImgMinDecLevels* () : LONGINT;
				VAR
					min, i, j : LONGINT;
				BEGIN
					min := cstyle[0][0].ndec;

					FOR j := 0 TO imgInfo.nt - 1 DO
						FOR i := 1 TO imgInfo.ncomp - 1 DO
							IF cstyle[j][i].ndec < min THEN
								min := cstyle[j][i].ndec;
							END;
						END;
					END;

					RETURN min;
			END GetImgMinDecLevels;

			(**
				Gets the maximum number of wavelet decomposition levels over all
				tile-components
			*)
			PROCEDURE GetImgMaxDecLevels* () : LONGINT;
				VAR
					max, i, j : LONGINT;
				BEGIN
					max := cstyle[0][0].ndec;

					FOR j := 0 TO imgInfo.nt - 1 DO
						FOR i := 1 TO imgInfo.ncomp - 1 DO
							IF cstyle[j][i].ndec > max THEN
								max := cstyle[j][i].ndec;
							END;
						END;
					END;

					RETURN max;
			END GetImgMaxDecLevels;

			(**
				Gets the minimum number of wavelet decomposition levels
				for a given tile.
			*)
			PROCEDURE GetMinDecLevels* (tile : LONGINT) : LONGINT;
				VAR
					min, i : LONGINT;
				BEGIN
					min := cstyle[tile][0].ndec;

					FOR i := 1 TO imgInfo.ncomp - 1 DO
						IF cstyle[tile][i].ndec < min THEN
							min := cstyle[tile][i].ndec;
						END;
					END;

					RETURN min;
			END GetMinDecLevels;


			PROCEDURE GetMaxDecLevels* (tile : LONGINT) : LONGINT;
				VAR
					max, i : LONGINT;
				BEGIN
					max := cstyle[tile][0].ndec;

					FOR i := 1 TO imgInfo.ncomp - 1 DO
						IF cstyle[tile][i].ndec > max THEN
							max := cstyle[tile][i].ndec;
						END;
					END;

					RETURN max;
			END GetMaxDecLevels;


			(**
				Gets the number of layers for a given tile
			*)
			PROCEDURE GetNumLayers* (tile : LONGINT) : LONGINT;
				BEGIN
					RETURN cics[tile].nl;
			END GetNumLayers;

			(**
				Gets the minimum number of layers over all tiles
			*)
			PROCEDURE GetMinNumLayers* () : LONGINT;
				VAR
					i, min : LONGINT;
				BEGIN
					min := cics[0].nl;

					FOR i := 0 TO imgInfo.nt - 1 DO
						IF cics[i].nl < min THEN
							min := cics[i].nl;
						END;
					END;

					RETURN min;
			END GetMinNumLayers;


			(*
				Gets the precinct width exponent for a given tile, component and
				resolution level
			*)
			PROCEDURE GetPPX (tile, comp, reslevel : LONGINT) : LONGINT;
				BEGIN
					IF cstyle[tile][comp].maxps THEN
						RETURN MAX_PREC_SIZ;
					ELSE
						RETURN cstyle[tile][comp].precs[reslevel].ppx;
					END;
			END GetPPX;

			(*
				Gets the precinct height exponent for a given tile, component and
				resolution level
			*)
			PROCEDURE GetPPY (tile, comp, reslevel : LONGINT) : LONGINT;
				BEGIN
					IF cstyle[tile][comp].maxps THEN
						RETURN MAX_PREC_SIZ;
					ELSE
						RETURN cstyle[tile][comp].precs[reslevel].ppy;
					END;
			END GetPPY;

			(**
				Returns the maximum code-block width exponent for a specific tile.
			*)
			PROCEDURE GetMaxCblkWidthExp* (tile : LONGINT) : LONGINT;
				VAR
					i, maxw : LONGINT;
				BEGIN
					maxw := cstyle[tile][0].cblw;

					FOR i := 1 TO imgInfo.ncomp - 1 DO
						IF cstyle[tile][i].cblw > maxw THEN
							maxw := cstyle[tile][i].cblw;
						END;
					END;

					RETURN maxw;
			END GetMaxCblkWidthExp;

			(**
				Returns the maximum code-block height exponent for a specific tile.
			*)
			PROCEDURE GetMaxCblkHeightExp* (tile : LONGINT) : LONGINT;
				VAR
					i, maxh : LONGINT;
				BEGIN
					maxh := cstyle[tile][0].cblh;

					FOR i := 1 TO imgInfo.ncomp - 1 DO
						IF cstyle[tile][i].cblh > maxh THEN
							maxh := cstyle[tile][i].cblh;
						END;
					END;

					RETURN maxh;
			END GetMaxCblkHeightExp;

			(**
				Returns the quantization style for a given tile-component
			*)
			PROCEDURE GetQuantStyle* (tile, comp : LONGINT) : LONGINT;
				BEGIN
					RETURN quant[tile][comp].style;
			END GetQuantStyle;

			(**
				Gets the exponent used in the calculation of the quantization step
				(for a given tile, component, resolution level and subband)
			*)
			PROCEDURE GetQuantExponent* (tile, comp, reslevel, subband : LONGINT) : LONGINT;
				BEGIN
					IF reslevel = 0 THEN
						RETURN quant[tile][comp].stepsiz[0].exp
					ELSE
						RETURN quant[tile][comp].stepsiz[3*(reslevel-1) + subband].exp;
					END;
			END GetQuantExponent;

			(**
				Gets the mantissa used in the calculation of the quantization step
				(for a given tile, component, resolution level and subband)
			*)
			PROCEDURE GetQuantMantissa* (tile, comp, reslevel, subband : LONGINT) : LONGINT;
				BEGIN
					IF reslevel = 0 THEN
						RETURN quant[tile][comp].stepsiz[0].mant;
					ELSE
						RETURN quant[tile][comp].stepsiz[3*(reslevel-1) + subband].mant;
					END;
			END GetQuantMantissa;

			(**
				TRUE, if ROI coding is used for a given tile-component
			*)
			PROCEDURE ROIUsed* (tile, comp : LONGINT) : BOOLEAN;
				BEGIN
					RETURN (roiShift # NIL) & (roiShift[tile][comp] >= 0);
			END ROIUsed;

			(**
				Returns the shift value (as defined in the Maxshift method) for
				ROI decoding (or -1 if there is no such value)
			*)
			PROCEDURE GetROIShift* (tile, comp : LONGINT) : LONGINT;
				BEGIN
					IF (roiShift = NIL) THEN
						RETURN -1;
					ELSE
						RETURN roiShift[tile][comp];
					END;
			END GetROIShift;

		END DecoderSpecs;

		(*
			Holds the progression state for a single tile
		*)
		ProgState = RECORD
			progNr : LONGINT;		(* The current progression number = number of prog. changes so far *)
			progOrder : LONGINT;	(* The progression order *)
			curLay : LONGINT;		(* The current layer *)
			startLay : J2KU.LongInt2DArrayPtr;
			endLay : LONGINT;		(* The last layer of this progression *)
			startRes : LONGINT;		(* The resolution level to start with *)
			curRes : LONGINT;		(* The current res. level *)
			endRes : LONGINT;		(* The last res. level of this progression *)
			startComp : LONGINT;	(* The component to start with *)
			curComp : LONGINT;		(* The current component *)
			endComp : LONGINT;	(* The last component of this progression *)
			curPrec : J2KU.LongInt3DArrayPtr;
			(* NOTE: The following state variables are not needed in the case of position-first progressions *)
			curX : LONGINT;
			curY : LONGINT;
		END;

		(*
			Specifies progression changes.
		*)
		ProgChange = RECORD
			progOrder : LONGINT;	(* The progression order *)
			startRes : LONGINT;		(* The first res. level of this progression *)
			startComp : LONGINT;	(* The first component of this progression *)
			endLay : LONGINT;		(* The last layer of this progression *)
			endRes : LONGINT;		(* The last res .level of this progression *)
			endComp : LONGINT;	(* The last component of this progression *)
		END;

		ProgChangeArrayPtr = POINTER TO ARRAY OF ProgChange;

		(*
			Used to construct a linked list of byte arrays
			(i.e. for packed packet headers)
		*)
		DataListElement = OBJECT
			VAR
				data : J2KU.ByteArrayPtr;
				next : DataListElement;
		END DataListElement;


		(*
			Contains information on how many code-blocks are located (entirely or partial) in
			a specific precinct of a specific tile, component, resolution level and subband. There will be one
			such record per resolution level.
		*)
		PrecinctInfo = RECORD
			(*
				1st dim: subband (NOTE: 0 = LL at lowest resolution level; 0 = HL, 1 = LH, 2 = HH otherwise)
				2nd dim.: Precinct index in the subband (in raster order)
				3rd dim.: 0: Number of code-blocks in horizontal direction,
						1: Number of code-blocks in vertical direction
			*)
			nblocks : POINTER TO ARRAY OF ARRAY OF ARRAY 2 OF LONGINT;
			nprecx : LONGINT;	(* The number of precincts in horizontal direction for a specific tile, component, resolution level (per subband) *)
			nprecy : LONGINT;	(* The number of precincts in vertical direction for a specific tile, component, resolution leve (per subband) *)
		END;



		(*
			Is used to decode packets contained in a JPEG2000 codestream.
		*)
		PacketDecoder = OBJECT(J2KU.BitSource)
			VAR
				cr : CodestreamReader;	(* A reference to the codestream reader so we can read bytes from the stream *)
				curTile : LONGINT;		(* The tile for which packets are decoded currently *)
				curByte : LONGINT;		(* A buffer containing the current byte in the packet (-header) *)
				curBytePos : LONGINT;	(* The position in the current byte buffer. 8 means the buffer is empty, 0 means we're at the beginning of the buffer *)
				decSpec : DecoderSpecs;(* A reference to the current decoder specification *)
				pph : DataListElement;		(* The current data element of packed packet headers *)
				pphPos : LONGINT;		(* The position in the data array of the current first data element *)
				pphTileFirstLast : POINTER TO ARRAY OF ARRAY OF DataListElement;	(* The currently first/last data elements of each tile *)
				pphTilePos : J2KU.LongIntArrayPtr;		(* The poitions in the data array of the currently first data element of each tile *)
				pphMainUsed : BOOLEAN;	(* Indicates wether packed packet headers in the main header are used *)
				pphTileUsed : POINTER TO ARRAY OF BOOLEAN;	(* Indicates wether packed packet headers in tile-part headers are used (for each tile separately) *)
				sopUsed, ephUsed : BOOLEAN;	(* Indicate if SOP or EPH markers are used in the current tile *)

				(*
					Pointers to increment step arrays. That's the step from one precinct to the next one projected to the reference grid at full resolution.
					1st dim: tile index
					2nd dim: component
					3rd dim: resolution level
					4th dim: 0: x direction
							1: y direction
				*)
				incStep : POINTER TO ARRAY OF ARRAY OF POINTER TO ARRAY OF ARRAY 2 OF LONGINT;

				(*
					Same as above, only that the minimal increment step over all resolution levels are stored.
					1st dim: tile index
					2nd dim: component
					3rd dim: 0: x direction
							1: y direction
				*)
				minIncStep : POINTER TO ARRAY OF ARRAY OF ARRAY 2 OF LONGINT;

				(*
					The start and end of each tile. The start index is the start index of the tile-component. The end index
					is the start index of the last precinct contained in the tile-component (at a particular resolution level)
					1st dim: tile index
					2nd dim: component
					3rd dim: resolution level
					4th dim: 0: x direction
							1: y direction
					5th dim: 0: start index
							1: end index
				*)
				sotEot : POINTER TO ARRAY OF ARRAY OF POINTER TO ARRAY OF ARRAY 2, 2 OF LONGINT;

				(*
					Same as above, only that the values of the largest tile-component over all resolution levels are stored
					1st dim: tile index
					2nd dim: component
					3rd dim: 0: x direction
							1: y direction
					4th dim: 0: start index
							1: end index
				*)
				maxSotEot : POINTER TO ARRAY OF ARRAY OF ARRAY 2, 2 OF LONGINT;

				(*
					Pointers to tag trees (inclusion tree & zero bit-plane information tree):
					1st dim: tile index
					2nd dim: component
					3rd dim: resolution level
					4th dim: subband (NOTE: 0 = LL at lowest resolution level; 0 = HL, 1 = LH, 2 = HH otherwise)
					5th dim: precinct index (in raster order)
				*)
				inclTrees : POINTER TO ARRAY OF ARRAY OF POINTER TO ARRAY OF POINTER TO ARRAY OF POINTER TO ARRAY OF J2KU.TagTree;
				zeroTrees : POINTER TO ARRAY OF ARRAY OF POINTER TO ARRAY OF POINTER TO ARRAY OF POINTER TO ARRAY OF J2KU.TagTree;

				(*
					Pointer to lblock for each code-block of  the image:
					1st dim: tile index
					2nd dim: component
					3rd dim: resolution level
					4th dim: subband (NOTE: 0 = LL at lowest resolution level; 0 = HL, 1 = LH, 2 = HH otherwise)
					5th dim: precinct index in the subband (in raster order)
					6th dim: code-block index in the precinct (in raster order)
				*)
				lblock : POINTER TO ARRAY OF ARRAY OF J2KU.LongInt4DArrayPtr;

				(*
					Pointer to code-block information for each code-block of the image:
					1st dim: tile index
					2nd dim: component
					3rd dim: resolution level
					4th dim: subband (NOTE: 0 = LL at lowest resolution level; 0=HL, 1=LH, 2=HH otherwise)
					5th dim: precinct index in the subband (in raster order)
 					6th dim : code-block index in the precinct (in raster order)
				*)
				cblkInfo : POINTER TO ARRAY OF ARRAY OF POINTER TO ARRAY OF POINTER TO ARRAY OF POINTER TO ARRAY OF POINTER TO ARRAY OF J2KU.CblkInfo;

				(*
					Pointer to precinct information for each precinct of the image
					1st dim: tile index
					2nd dim: component
					3rd dim: resolution level
				*)
				precInfo : POINTER TO ARRAY OF ARRAY OF POINTER TO ARRAY OF PrecinctInfo;


			(*
				Creates a new PacketDecoder instance and initializes its member variables.

				cr:	A reference to the CodestreamReader which will deliver the packet headers and data
				decSpec : A reference to the decoder specifications
				pphMain : A list of packed packet headers found in the main header of the codestream
			*)
			PROCEDURE &InitNew *(	cr : CodestreamReader;
									decSpec : DecoderSpecs;
									pphMain : DataListElement);
				BEGIN
					ReInit(cr, decSpec, pphMain);
			END InitNew;

			(*
				Reinitializes the PacketDecoder and its member variables.
				cr:	A reference to the CodestreamReader which will deliver the packet headers and data
				decSpec : A reference to the decoder specifications
				pphMain : A list of packed packet headers found in the main header of the codestream
			*)
			PROCEDURE ReInit (	cr : CodestreamReader;
								decSpec : DecoderSpecs;
								pphMain : DataListElement);
				VAR
					nt, ncomp : LONGINT;
				BEGIN
					SELF.cr := cr;

					SELF.decSpec := decSpec;
					curByte := 0;	(* TODO : Maybe we don't need to initialize this value *)
					curBytePos := 0;
					curTile := 0;	(* TODO : Maybe we don't need to initialize this value *)

					nt := decSpec.imgInfo.GetNumTiles();
					ncomp := decSpec.imgInfo.GetNumComponents();

					NEW(precInfo, nt, ncomp);
					NEW(lblock, nt, ncomp);
					NEW(inclTrees, nt, ncomp);
					NEW(zeroTrees, nt, ncomp);
					NEW(cblkInfo, nt, ncomp);

					NEW(incStep, nt, ncomp);
					NEW(minIncStep, nt, ncomp);
					NEW(sotEot, nt, ncomp);
					NEW(maxSotEot, nt, ncomp);

					IF pphMain # NIL THEN
						(* We create a dummy element and set the position to the end *)
						NEW(pph);
						NEW(pph.data, 1);
						pphPos := 1;
						pph.next := pphMain;
						pphMainUsed := TRUE;
					ELSE
						pph := NIL;
						pphMainUsed := FALSE;
					END;

					pphTileFirstLast := NIL;
					pphTileUsed := NIL;

			END ReInit;


			(*
				Initializes tile-specific member variables of the PacketDecoder instance to
				their appropriate values and sets the current tile to 't'. Usually this is done after a new tile header has been read
				by the CodestreamReader.
				t:	The index of the new current tile in the reference grid
			*)
			PROCEDURE SetAndInitTile(t : LONGINT);
				VAR
					c, r, ndec : LONGINT;
				BEGIN

					BuildIncSotEotArrays(t);

					(* Loop on components *)
					FOR c := 0 TO decSpec.imgInfo.ncomp - 1 DO
						ndec := decSpec.cstyle[t][c].ndec;

						(* Instantiate new arrays for each tile-component *)
						NEW(precInfo[t][c], ndec + 1);
						NEW(lblock[t][c], ndec + 1);
						NEW(zeroTrees[t][c], ndec + 1);
						NEW(inclTrees[t][c], ndec + 1);
						NEW(cblkInfo[t][c], ndec + 1);

						(* Loop on resolution levels *)
						FOR r := 0 TO ndec DO
							(* Create precinct information *)
							CreatePrecinctInfo(t, c, r, precInfo[t][c][r]);
							(* Initialize subbands *)
							InitSubbands(t, c, r, precInfo[t][c][r]);
						END;
					END;

					SetTile(t);
			END SetAndInitTile;

			(*
				Sets t as new current tile
			*)
			PROCEDURE SetTile (t : LONGINT);
				BEGIN
					IF pphTileUsed # NIL THEN
						(* Store the packet packet headers of the previous tile (if there was one) *)
						IF pph # NIL THEN
							pphTileFirstLast[curTile][0] := pph;
							pphTilePos[curTile] := pphPos;
						END;

						IF pphTileUsed[t] THEN
							pph := pphTileFirstLast[t][0];
							pphPos := pphTilePos[t];
						ELSE
							pph := NIL;
						END;
					END;

					(* See, if we need to move on to the next chunk of packed packet headers *)
					IF (pph # NIL) & (pphPos >= LEN(pph.data^)) THEN
						pph := pph.next;
						pphPos := 0;
					END;

					sopUsed := decSpec.cics[t].sop;
					ephUsed := decSpec.cics[t].eph;
					SELF.curTile := t;
			END SetTile;


			(*
				Build helper arrays for finding precinct start & end points
			*)
			PROCEDURE BuildIncSotEotArrays (tile : LONGINT);
				VAR
					c, r, subsX, subsY, ndec, ppx, ppy, shift : LONGINT;
					tileCompULX, tileCompWidth, tileCompULY, tileCompHeight : LONGINT;
					subbInfo : J2KU.SubbandInfo;
				BEGIN

					FOR c := 0 TO decSpec.imgInfo.ncomp - 1 DO
						ndec := decSpec.cstyle[tile][c].ndec;
						(* Get the component subsampling factors *)
						subsX := decSpec.imgInfo.comps[c].subsx;
						subsY := decSpec.imgInfo.comps[c].subsy;

						minIncStep[tile][c][0] := MAX(LONGINT);
						minIncStep[tile][c][1] := MAX(LONGINT);

						NEW(incStep[tile][c], ndec + 1);
						NEW(sotEot[tile][c], ndec + 1);

						(* Get information on the LL band of the highest resolution level, i.e. the whole tile *)
						subbInfo := cr.GetSubbandInfo(tile, c, ndec, J2KU.SUB_LL);

						tileCompULX := subbInfo.ulcx;
						tileCompWidth := subbInfo.width;
						tileCompULY := subbInfo.ulcy;
						tileCompHeight := subbInfo.height;

						FOR r := 0 TO ndec DO
							(* First we handle the increment arrays *)
							ppx := decSpec.GetPPX(tile, c, r);
							ppy := decSpec.GetPPY(tile, c, r);

							shift := ndec - r;
							incStep[tile][c][r][0] := LSH(LSH(subsX, shift), ppx);

							IF incStep[tile][c][r][0] < minIncStep[tile][c][0] THEN
								minIncStep[tile][c][0] := incStep[tile][c][r][0];
							END;

							incStep[tile][c][r][1] := LSH(LSH(subsY, shift), ppy);

							IF incStep[tile][c][r][1] < minIncStep[tile][c][1] THEN
								minIncStep[tile][c][1] := incStep[tile][c][r][1];
							END;

							(* Now handle the start/end of tile array *)
							IF incStep[tile][c][r][0] = 0 THEN
								sotEot[tile][c][r][0][0] := 0;
								sotEot[tile][c][r][0][1] := 1;
								incStep[tile][c][r][0] := 1;
							ELSE
								sotEot[tile][c][r][0][0] := SYSTEM.VAL(LONGINT,
																		SYSTEM.VAL(SET, tileCompULX)
																		* (SYSTEM.VAL(SET, incStep[tile][c][r][0] - 1) / SYSTEM.VAL(SET, J2KU.SWAP_MASK))
															);
								sotEot[tile][c][r][0][1] := tileCompULX + tileCompWidth;
							END;

							IF incStep[tile][c][r][1] = 0 THEN
								sotEot[tile][c][r][1][0] := 0;
								sotEot[tile][c][r][1][1] := 1;
								incStep[tile][c][r][1] := 1;
							ELSE
								sotEot[tile][c][r][1][0] := SYSTEM.VAL(LONGINT,
																		SYSTEM.VAL(SET, tileCompULY)
																		* (SYSTEM.VAL(SET, incStep[tile][c][r][1] - 1) / SYSTEM.VAL(SET, J2KU.SWAP_MASK))
															);
								sotEot[tile][c][r][1][1] := tileCompULY + tileCompHeight;
							END;
						END;

						(*
							Last handle the maximum start/end of tile array, i.e. the start/end
							 of tile for the highest resolution level and smallest increment step
						*)
						IF minIncStep[tile][c][0] = 0 THEN
							maxSotEot[tile][c][0][0] := 0;
							maxSotEot[tile][c][0][1] := 1;
							minIncStep[tile][c][0] := 1;
						ELSE
							maxSotEot[tile][c][0][0] := SYSTEM.VAL(LONGINT,
																		SYSTEM.VAL(SET, tileCompULX)
																		* (SYSTEM.VAL(SET, minIncStep[tile][c][0] - 1) / SYSTEM.VAL(SET, J2KU.SWAP_MASK))
															);
							maxSotEot[tile][c][0][1] := tileCompULX + tileCompWidth;
						END;

						IF minIncStep[tile][c][1] = 0 THEN
							maxSotEot[tile][c][1][0] := 0;
							maxSotEot[tile][c][1][1] := 1;
							minIncStep[tile][c][1] := 1;
						ELSE
							maxSotEot[tile][c][1][0] := SYSTEM.VAL(LONGINT,
																		SYSTEM.VAL(SET, tileCompULY)
																		* (SYSTEM.VAL(SET, minIncStep[tile][c][1] - 1) / SYSTEM.VAL(SET, J2KU.SWAP_MASK))
															);
							maxSotEot[tile][c][1][1] := tileCompULY + tileCompHeight;
						END;

					END;

			END BuildIncSotEotArrays;

			(*
				Creates and initializes a precinct information object
			*)
			PROCEDURE CreatePrecinctInfo(tile, comp, reslevel : LONGINT; VAR precInfo : PrecinctInfo);
				VAR
					incX, incY, incXR, incYR, maxSotX, maxSotY, maxEotX, maxEotY, sotX, sotY, xr, yr : LONGINT;
					ppx, ppy, nprecx, nprecy, nprec, curPrec, px, py, width, height : LONGINT;
					cblkw, cblkh : LONGINT;
					nband, subband : LONGINT;
					subbInfo : J2KU.SubbandInfo;
					cblkwCeil, cblkhCeil : LONGINT;	(* These values are needed when we perform integer division with 'ceil' operation *)
					precw, prech : LONGINT;	(* The width and height of the precincts (i.e. 2^ppx & 2^ppy) *)
					ndec : LONGINT;
					maxpsUsed : BOOLEAN;		(* Maximum precinct size used? *)
					tmp : LONGINT;
				BEGIN
					cblkw := decSpec.cstyle[tile][comp].cblw;
					cblkh := decSpec.cstyle[tile][comp].cblh;
					maxpsUsed := decSpec.cstyle[tile][comp].maxps;
					ndec := decSpec.cstyle[tile][comp].ndec;
					ppx := decSpec.GetPPX(tile, comp, reslevel);
					ppy := decSpec.GetPPY(tile, comp, reslevel);

					incX := minIncStep[tile][comp][0];
					incY := minIncStep[tile][comp][1];

					IF reslevel = 0 THEN
						IF cblkw > ppx THEN
							cblkw := ppx;
						END;

						IF cblkh > ppy THEN
							cblkh := ppy;
						END;

						precw := LSH(SYSTEM.VAL(LONGINT, 1), ppx);
						prech := LSH(SYSTEM.VAL(LONGINT, 1), ppy);

						nband := 1;
					ELSE
						IF cblkw > (ppx - 1) THEN
							cblkw := ppx - 1;
						END;

						IF cblkh > (ppy - 1) THEN
							cblkh := ppy - 1;
						END;
						(*
							NOTE:
							Resolution level # 0 -> precinct/packet size (in terms of samples)
							must be divided by 2 since the PPX and PPY values found in the
							stream refer to the LL-band that will be reconstructed from the
							3 subbands from the same and the LL-band from the next lower
							resolution level
						*)
						precw := LSH(SYSTEM.VAL(LONGINT, 1), ppx - 1);
						prech := LSH(SYSTEM.VAL(LONGINT, 1), ppy - 1);

						nband := 3;
					END;

					(* Get the LL subband of the current resolution level *)
					subbInfo := cr.GetSubbandInfo(tile, comp, reslevel, J2KU.SUB_LL);

					(* Compute the number of precincts *)

					IF subbInfo.width > 0 THEN
						(* NOTE: Implicit 'ceil' operation is done in this division (i.e. shift) by adding [divisor - 1] to the dividend *)
						tmp := LSH(subbInfo.ulcx + subbInfo.width + LSH(SYSTEM.VAL(LONGINT, 1), ppx) - 1, -ppx);
						nprecx := tmp - LSH(subbInfo.ulcx, -ppx);
					ELSE
						nprecx := 0;
					END;

					IF subbInfo.height > 0 THEN
						(* NOTE: Implicit 'ceil' operation is done in this division (i.e. shift) by adding [divisor - 1] to the dividend *)
						tmp := LSH(subbInfo.ulcy + subbInfo.height + LSH(SYSTEM.VAL(LONGINT, 1), ppy) - 1, -ppy);
						nprecy := tmp - LSH(subbInfo.ulcy, -ppy);
					ELSE
						nprecy := 0;
					END;

					nprec := nprecx * nprecy;

					precInfo.nprecx := nprecx;
					precInfo.nprecy := nprecy;

					(* Allocate space for number-of-code-blocks information *)
					NEW(precInfo.nblocks, nband, nprec);

					(* Precompute values that are needed several times *)
					incXR := incStep[tile][comp][reslevel][0];
					incYR := incStep[tile][comp][reslevel][1];
					maxSotX := maxSotEot[tile][comp][0][0];
					maxSotY := maxSotEot[tile][comp][1][0];
					maxEotX := maxSotEot[tile][comp][0][1];
					maxEotY := maxSotEot[tile][comp][1][1];
					sotX := sotEot[tile][comp][reslevel][0][0];
					sotY := sotEot[tile][comp][reslevel][1][0];
					cblkwCeil := LSH(SYSTEM.VAL(LONGINT, 1), cblkw) - 1;
					cblkhCeil := LSH(SYSTEM.VAL(LONGINT, 1), cblkh) - 1;

					(* Build the information on number of code-blocks per precinct *)
					curPrec := 0;

					yr := maxSotY;
					WHILE yr < maxEotY DO
						xr := maxSotX;
						WHILE xr < maxEotX DO
							(* Check wether a precinct starts at this position *)
							IF ((xr = maxSotX) OR (xr MOD incXR = 0))
								& ((yr = maxSotY) OR (yr MOD incYR = 0))
							THEN
								(* See wether the precinct's index is within the bounds *)
								IF curPrec < nprec THEN

									(* Here begins a new precinct *)
									FOR subband := 0 TO nband - 1 DO
										subbInfo := cr.GetSubbandInfo(tile, comp, reslevel, J2KU.SubbandIndexToSubband(reslevel, subband));

										(* Compute the horiztontal index in the subband *)
										IF (xr = maxSotX)
											& (LSH(sotX, reslevel - ndec) # maxSotX)
										THEN
											IF reslevel = 0 THEN
												px := LSH(sotX, reslevel - ndec) - subbInfo.ulcx;
											ELSE
												px := LSH(sotX, reslevel - ndec - 1) - subbInfo.ulcx;
											END;
										ELSE
											IF reslevel = 0 THEN
												px := LSH(xr, reslevel - ndec) - subbInfo.ulcx;
											ELSE
												px := LSH(xr, reslevel - ndec - 1) - subbInfo.ulcx;
											END;
										END;

										(* Compute the vertical index in the subband *)
										IF (yr = maxSotY)
											& (LSH(sotY, reslevel - ndec) # maxSotY)
										THEN
											IF reslevel = 0 THEN
												py := LSH(sotY, reslevel - ndec) - subbInfo.ulcy;
											ELSE
												py := LSH(sotY, reslevel - ndec - 1) - subbInfo.ulcy;
											END;
										ELSE
											IF reslevel = 0 THEN
												py := LSH(yr, reslevel - ndec) - subbInfo.ulcy;
											ELSE
												py := LSH(yr, reslevel - ndec - 1) - subbInfo.ulcy;
											END;
										END;

										IF 	(subbInfo.width <= 0) OR (subbInfo.height <= 0)
											OR (px + precw <= 0) OR (py + prech <= 0)
											OR (px >= subbInfo.width) OR (py >= subbInfo.height)
										THEN
											precInfo.nblocks[subband][curPrec][0] := 0;
											precInfo.nblocks[subband][curPrec][1] := 0;
										ELSE
											(* Calculate number of code-blocks in horizontal direction *)
											IF px + precw > subbInfo.width THEN
												width := subbInfo.width - px;
											ELSE
												width := precw;
											END;

											IF px < 0 THEN
												width := width + px;
												px := 0;
											END;

											(* NOTE: Implicit 'ceil' operation is done in the first division (i.e. shift) by adding [divisor - 1] to the dividend *)
											precInfo.nblocks[subband][curPrec][0] := LSH(px + subbInfo.ulcx + width + cblkwCeil, -cblkw)
																					- LSH(px + subbInfo.ulcx, -cblkw);

												(* Calculate number of code-blocks in vertical direction *)
											IF py + prech > subbInfo.height THEN
												height := subbInfo.height - py;
											ELSE
												height := prech;
											END;

											IF py < 0 THEN
												height := height + py;
												py := 0;
											END;

											(* NOTE: Implicit 'ceil' operation is done in the first division (i.e. shift) by adding [divisor - 1] to the dividend *)
											precInfo.nblocks[subband][curPrec][1] := LSH(py + subbInfo.ulcy + height + cblkhCeil, -cblkh)
																					- LSH(py + subbInfo.ulcy , -cblkh);

										END;

									END; (* Loop on subbands *)
									INC(curPrec);
								END;
							END;
							INC(xr, incX);
						END;
						INC(yr, incY);
					END;

			END CreatePrecinctInfo;


			(*
				Initializes all state & information objects contained in the subbands of
				a given tile, component & resolution level
			*)
			PROCEDURE InitSubbands (tile, comp, reslevel : LONGINT; VAR precInfo : PrecinctInfo);
				VAR
					nl : LONGINT;
					nband, subband : LONGINT;
					subbInfo : J2KU.SubbandInfo;
					ppx, ppy, nprec, precx, nprecx, precy, nprecy, precIdx : LONGINT;
					nblocks, ncblkx, ncblky, cblkIdx, cblkIdxX, cblkIdxY, cblkPrecIdx, i, j, cblkw, cblkh : LONGINT;
					cblkInfoObj : J2KU.CblkInfo;
					cblkStartX, cblkStartY : LONGINT;	(* The start coordinates of the first code-blocks in each column/row of code-blocks in a subband *)
					nomCblkw, nomCblkh : LONGINT;	(* The nominal code-block width and height. These are the actual values, not just the exponents *)
					tmp1, tmp2 : LONGINT;
				BEGIN
					nl := decSpec.cics[tile].nl;
					ppx := decSpec.GetPPX(tile, comp, reslevel);
					ppy := decSpec.GetPPY(tile, comp, reslevel);

					cblkw := decSpec.cstyle[tile][comp].cblw;
					cblkh := decSpec.cstyle[tile][comp].cblh;

					IF reslevel = 0 THEN
						IF cblkw > ppx THEN
							cblkw := ppx;
						END;

						IF cblkh > ppy THEN
							cblkh := ppy;
						END;

						nband := 1;
					ELSE
						IF cblkw > (ppx - 1) THEN
							cblkw := ppx - 1;
						END;

						IF cblkh > (ppy - 1) THEN
							cblkh := ppy - 1;
						END;

						nband := 3;
					END;

					nomCblkw := LSH(SYSTEM.VAL(LONGINT, 1), cblkw);
					nomCblkh := LSH(SYSTEM.VAL(LONGINT, 1), cblkh);

					nprecx := precInfo.nprecx;
					nprecy := precInfo.nprecy;
					nprec := nprecx*nprecy;


					NEW(zeroTrees[tile][comp][reslevel], nband);
					NEW(inclTrees[tile][comp][reslevel], nband);
					NEW(lblock[tile][comp][reslevel], nband);
					NEW(cblkInfo[tile][comp][reslevel], nband);

					FOR subband := 0 TO nband - 1 DO
						subbInfo := cr.GetSubbandInfo(tile, comp, reslevel, J2KU.SubbandIndexToSubband(reslevel, subband));

						NEW(zeroTrees[tile][comp][reslevel][subband], nprec);
						NEW(inclTrees[tile][comp][reslevel][subband], nprec);
						NEW(lblock[tile][comp][reslevel][subband], nprec);
						NEW(cblkInfo[tile][comp][reslevel][subband], nprec);

						cblkIdx := 0;
						precIdx := 0;
						cblkStartY := LSH(LSH(subbInfo.ulcy, -cblkh), cblkh);
						cblkStartX := LSH(LSH(subbInfo.ulcx, -cblkw), cblkw);

						FOR precy := 0 TO nprecy - 1 DO
							(*
								Store the current code-block index; we will need it when
								advancing to the next precinct in vertical direction
							*)
							tmp1 := cblkIdx;

							FOR precx := 0 TO nprecx - 1 DO
								ncblkx := precInfo.nblocks[subband][precIdx][0];
								ncblky := precInfo.nblocks[subband][precIdx][1];
								nblocks := ncblkx*ncblky;

								NEW(zeroTrees[tile][comp][reslevel][subband][precIdx], ncblkx, ncblky, SELF);
								NEW(inclTrees[tile][comp][reslevel][subband][precIdx], ncblkx, ncblky, SELF);

								IF nblocks > 0 THEN
									NEW(lblock[tile][comp][reslevel][subband][precIdx], nblocks);
									NEW(cblkInfo[tile][comp][reslevel][subband][precIdx], nblocks);
									Machine.Fill32(ADDRESSOF(lblock[tile][comp][reslevel][subband][precIdx][0]), nblocks*SIZEOF(LONGINT), 3);
								END;

								cblkPrecIdx := 0;
								tmp2 := cblkIdx;

								FOR i := 0 TO ncblky - 1 DO
									FOR j := 0 TO ncblkx - 1 DO
										NEW(cblkInfoObj);

										cblkInfoObj.subbinfo := subbInfo;
										cblkInfoObj.index := cblkIdx;
										NEW(cblkInfoObj.cpasseslyr, nl);
										NEW(cblkInfoObj.datalenlyr, nl);

										cblkIdxX := cblkIdx MOD subbInfo.nblocksx;

										cblkIdxY := cblkIdx DIV subbInfo.nblocksx;

										(* Compute upper-left x and y coordinates of the code-block with respect to the tile-component *)
										IF cblkIdxY = 0 THEN
											cblkInfoObj.ulsy := subbInfo.ulsy;
										ELSE
											(* Compute index of first code-block in row on partition grid with origin (0,0) *)
											cblkInfoObj.ulsy := cblkStartY + cblkIdxY*nomCblkh - subbInfo.ulcy + subbInfo.ulsy;
										END;

										IF cblkIdxX = 0 THEN
											cblkInfoObj.ulsx := subbInfo.ulsx;
										ELSE
											(* Compute index of first code-block in row on partition grid with origin (0,0) *)
											cblkInfoObj.ulsx := cblkStartX + cblkIdxX*nomCblkw - subbInfo.ulcx + subbInfo.ulsx;
										END;

										(* Compute code-block width and height *)
										IF (cblkIdxY < subbInfo.nblocksy - 1) THEN
											cblkInfoObj.height := cblkStartY + (cblkIdxY+1)*nomCblkh - subbInfo.ulcy + subbInfo.ulsy - cblkInfoObj.ulsy;
										ELSE
											cblkInfoObj.height := (subbInfo.ulsy + subbInfo.height) - cblkInfoObj.ulsy;
										END;

										IF (cblkIdxX < subbInfo.nblocksx - 1) THEN
											cblkInfoObj.width := cblkStartX + (cblkIdxX+1)*nomCblkw - subbInfo.ulcx + subbInfo.ulsx - cblkInfoObj.ulsx;
										ELSE
											cblkInfoObj.width := (subbInfo.ulsx + subbInfo.width) - cblkInfoObj.ulsx;
										END;

										cblkInfo[tile][comp][reslevel][subband][precIdx][cblkPrecIdx] := cblkInfoObj;

										(* Index of the next code-block *)
										INC(cblkIdx);
										INC(cblkPrecIdx);
									END;
									(*
										Compute the index of the first code-block on
										the next row of the current precinct. We need
										to first subtract 1 from the current index since
										we moved one to far
									*)
									cblkIdx := (cblkIdx - ncblkx) + subbInfo.nblocksx;
								END;

								(*
									Compute the index of the code-block at the beginning
									of the next precinct in horizontal direction
								*)
								cblkIdx := tmp2 + ncblkx;
								INC(precIdx);
							END;
							(* Compute the index of the code-block at the beginning of the next row *)
							(*
								NOTE:
								The implicit precondition here is that we assume that we have
								at least 1 precinct in the horizontal direction. It would not make
								any sense to have a vertical precinct and no horizontal one, anyway
							*)
							cblkIdx := tmp1 + ncblky*subbInfo.nblocksx;
						END;
					END;

			END InitSubbands;


			(*
				Sets packed packet headers for a given tile
			*)
			PROCEDURE SetPPHeadersTile (pphNewFirst, pphNewLast : DataListElement; tile : LONGINT);
				VAR
					nt, i : LONGINT;
				BEGIN
					(* We assume that checks are done prior to a call to this procedure -> we use an assertion as 'ultima ratio' *)
					ASSERT(~pphMainUsed);

					IF pphTileFirstLast = NIL THEN
						nt := decSpec.imgInfo.nt;
						NEW(pphTileFirstLast, nt, 2);
						NEW(pphTilePos, nt);
						NEW(pphTileUsed, nt);

						FOR i := 0 TO nt - 1 DO
							pphTileUsed[i] := FALSE;
						END;
					END;

					IF pphTileFirstLast[tile][0] = NIL THEN
						pphTileFirstLast[tile][0] := pphNewFirst;
						pphTileFirstLast[tile][1] := pphNewLast;
						pphTilePos[tile] := 0;
						pphTileUsed[tile] := TRUE;
					ELSE
						pphTileFirstLast[tile][1].next := pphNewFirst;
						pphTileFirstLast[tile][1] := pphNewLast;
					END;
			END SetPPHeadersTile;

			(*
				TRUE, if packed packet headers in tile-part headers are used for the current tile.
			*)
			PROCEDURE PPHTileUsed () : BOOLEAN;
				BEGIN
					RETURN ((pphTileUsed # NIL) & pphTileUsed[curTile]);
			END PPHTileUsed;


			(*
				Indicates wether there still are packed packet headers for the current tile-part (not tile).

				NOTE: 	It is prohibited to call this procedure when the packed packet headers don't stem
						from the main header of the codestream.
			*)
			PROCEDURE PPHMainAvailable () : BOOLEAN;
				BEGIN
					(* We assume that checks are done prior to a call to this procedure -> we use an assertion as 'ultima ratio' *)
					ASSERT(pphMainUsed);

					RETURN (pph # NIL) & (pphPos < LEN(pph.data^));
			END PPHMainAvailable;

			(*
				Indicates wether there still are packed packet headers for the current tile
				(not only for the current tile-part but also for all following tile-parts of the current tile).

				NOTE: 	It is prohibited to call this procedure if packed
						packet headers in the main header are used.
			*)
			PROCEDURE PPHTileAvailable () : BOOLEAN;
				BEGIN
					(* We assume that checks are done prior to a call to this procedure -> we use an assertion as 'ultima ratio' *)
					ASSERT(~pphMainUsed);

					RETURN (pph # NIL) & ((pphPos < LEN(pph.data^)) OR (pph.next # NIL));
			END PPHTileAvailable;


			(*
				Decodes the next packet in the stream.
				comp:		The component to which the code-blocks in the packet belong to
				reslevel:	The resolution level to which the code-blocks in the packet belong to
				layer:		The layer to which the code-blocks in the packet belong to
				precno:		The precinct to which the code-blocks in the packet belong to
				RETURN:	The number of code-blocks for which data has been read; -1 if an error occured
			*)
			PROCEDURE DecodePacket (comp, reslevel, layer, precno : LONGINT; VAR cblk : ARRAY OF J2KU.CodedCblk; VAR cblkInfo : ARRAY OF J2KU.CblkInfo) : LONGINT;
				VAR
					blocksInPacket, i, j, bit, bitsUsed, subband, nbands,  ncblx, ncbly, cblkx, cblky : LONGINT;
					cblkPrecIdx, cpasses, nseg, passtype, dataLen, lastIdx : LONGINT;
					inclTree, zeroTree : J2KU.TagTree;
					emptyPkt, included : BOOLEAN;
					cInfo : J2KU.CblkInfo;
				BEGIN

					(* TODO: Maybe we can place this check somewhere in the CodestreamReader *)
					(* Check that precinct really exists *)
					IF	precno
						>= (precInfo[curTile][comp][reslevel].nprecx * precInfo[curTile][comp][reslevel].nprecy)
					THEN
						(* Packet does not exist *)
						RETURN 0;
					END;

					(* Check if SOP markers are used *)
					IF sopUsed THEN
						ReadSOP();
					END;

					(* Init the current byte position to 8 so that a new byte is read from the stream or packed packet headers *)
					(* NOTE: We don't need to set curByte to 0, because the bit stuffing routine ensures that the last byte of the previous packet was not 0xFF *)
					curBytePos := 0;

					(* reslevel = 0 means we only have the NL-LL band *)
					IF reslevel = 0 THEN
						nbands := 1;
					ELSE
						nbands := 3;
					END;

					blocksInPacket := 0;

					IF NextBit() = 0 THEN
						(* No code-block is included; no more packet header data available *)
						emptyPkt := TRUE;
					ELSE
						emptyPkt := FALSE;
					END;

					FOR subband := 0 TO nbands - 1 DO

						inclTree := inclTrees[curTile][comp][reslevel][subband][precno];
						zeroTree := zeroTrees[curTile][comp][reslevel][subband][precno];
						ncblx := precInfo[curTile][comp][reslevel].nblocks[subband][precno][0];
						ncbly := precInfo[curTile][comp][reslevel].nblocks[subband][precno][1];
						cblkPrecIdx := 0;

						FOR cblky := 0 TO ncbly - 1 DO
							FOR cblkx := 0 TO ncblx - 1 DO
								cInfo := SELF.cblkInfo[curTile][comp][reslevel][subband][precno][cblkPrecIdx];

								(* Code-block inclusion bits *)
								(* If not previously included then update tag tree else 1 bit *)
								included := FALSE;

								IF ~emptyPkt THEN
									(* Check if current code-block is included *)
									IF ~inclTree.IsValid(cblkx, cblky) THEN
										IF ~inclTree.Update(cblkx, cblky, layer) THEN
											(* Error occurred *)
											RETURN -1;
										END;

										IF inclTree.IsValid(cblkx, cblky) THEN
											included := TRUE;
										END;
									ELSE
										bit := NextBit();
										IF bit = 1 THEN
											included := TRUE;
										END;
									END;
								END;

								IF included THEN (* Code-block is included *)
									(* If code-block included for the first time then update zero-bit plane tag-tree *)
									IF ~zeroTree.IsValid(cblkx, cblky) THEN
										IF ~zeroTree.Update(cblkx, cblky, MAX(LONGINT)) THEN
											(* Error occurred *)
											RETURN -1;
										END;

										cInfo.zerobp := zeroTree.CurrentVal(cblkx, cblky);
										cInfo.curbp := J2KU.LONGINT_BITS - 2 - cInfo.zerobp;
										cInfo.truncpt := 0;
									END;

									(* Number of coding passes included *)
									cpasses := ReadCodingPasses();
									cblk[blocksInPacket].cpasses := cpasses;
									INC(cInfo.truncpt, cpasses);

									(* Increase of Lblock *)
									bit := NextBit();
									WHILE bit = 1 DO
										INC(lblock[curTile][comp][reslevel][subband][precno][cblkPrecIdx]);
										bit := NextBit();
									END;

									(* We need to see, how much (terminated) passes there are *)
									IF decSpec.cstyle[curTile][comp].term THEN
										(* Termination on each coding pass is used -> we have as much segments as passes *)
										nseg := cpasses;
									ELSIF decSpec.cstyle[curTile][comp].selcb THEN
										(*
											Selective arithmetic coding bypass is used -> the number of terminated passes depends
											on the indices of the current passes, relativ to the passes that have been read already for
											this code-block
										*)
										IF cInfo.truncpt <= ENTROPY_FIRST_BYPASS_IDX THEN
											(* The new passes are all before the first bypass occurence *)
											nseg := 1;
										ELSE
											nseg := 1;	(* The last segment (which may be terminated or not) *)

											 FOR i := cInfo.truncpt - cpasses TO cInfo.truncpt - 2 DO
											 	IF i >= ENTROPY_FIRST_BYPASS_IDX - 1 THEN
													passtype := i MOD ENTROPY_NUM_PASSES;
													(* passtype = 0 -> cleanup pass, passtype = 2 -> magnitude refinement pass *)
													IF (passtype = 0) OR (passtype = 2) THEN
														INC(nseg);
													END;
											 	END;
											 END;
										END;
									ELSE
										(* Only one single segment *)
										nseg := 1;
									END;

									cblk[blocksInPacket].nseg := nseg;

									(* Length of codeword segments *)
									IF nseg = 1 THEN
										bitsUsed := lblock[curTile][comp][reslevel][subband][precno][cblkPrecIdx] + J2KU.Log2Floor(cpasses);

										cblk[blocksInPacket].dataLen := NextBits(bitsUsed);
									ELSE
										(* Multiple segments used *)
										NEW(cblk[blocksInPacket].segLen, nseg);
										dataLen := 0;

										IF decSpec.cstyle[curTile][comp].term THEN
											(* Termination on each coding pass is used *)
											FOR i := 0 TO nseg - 1 DO
												(* NOTE: Log2Floor(passes) = 0, since passes = 1 *)
												bitsUsed := lblock[curTile][comp][reslevel][subband][precno][cblkPrecIdx];

												cblk[blocksInPacket].segLen[i] := NextBits(bitsUsed);

												INC(dataLen, cblk[blocksInPacket].segLen[i]);
											END;

										ELSIF decSpec.cstyle[curTile][comp].selcb THEN
											(* Selective arithmetic coding bypass is used *)
											j := 0;
											lastIdx := cInfo.truncpt - cpasses - 1;

											 FOR i := cInfo.truncpt - cpasses TO cInfo.truncpt - 2 DO
											 	IF i >= ENTROPY_FIRST_BYPASS_IDX - 1 THEN
													passtype := i MOD ENTROPY_NUM_PASSES;
													(* passtype = 1 -> significance propagation pass -> skip *)
													IF passtype # 1 THEN
 														bitsUsed := lblock[curTile][comp][reslevel][subband][precno][cblkPrecIdx] + J2KU.Log2Floor(i - lastIdx);

														cblk[blocksInPacket].segLen[j] := NextBits(bitsUsed);

														INC(dataLen, cblk[blocksInPacket].segLen[j]);
														INC(j);
														lastIdx := i;
													END;
											 	END;
											 END;

											(* Last included pass *)
								 			bitsUsed := lblock[curTile][comp][reslevel][subband][precno][cblkPrecIdx] + J2KU.Log2Floor(i - lastIdx);

											cblk[blocksInPacket].segLen[j] := NextBits(bitsUsed);

											INC(dataLen, cblk[blocksInPacket].segLen[j]);
										END;

										(* Set the dataLen field of the current code-block *)
										cblk[blocksInPacket].dataLen := dataLen;
									END;

								ELSE (* Code-block is not included *)
									cblk[blocksInPacket].segLen := NIL;
									cblk[blocksInPacket].dataLen := 0;
									cblk[blocksInPacket].cpasses := 0;
								END;

								cblkInfo[blocksInPacket] := cInfo;

								(* Update layer-dependent information *)
								IF layer = 0 THEN
									cInfo.cpasseslyr[layer] := cblk[blocksInPacket].cpasses;
									cInfo.datalenlyr[layer] := cblk[blocksInPacket].dataLen;
								ELSE
									cInfo.cpasseslyr[layer] := cblk[blocksInPacket].cpasses + cInfo.cpasseslyr[layer - 1];
									cInfo.datalenlyr[layer] := cblk[blocksInPacket].dataLen + cInfo.datalenlyr[layer - 1];
								END;

								INC(blocksInPacket);
								INC(cblkPrecIdx);
							END;
						END;

					END;

					(*
						The specification states that a packet header must not end
						with a 0xFF byte. If the last byte of data is  0xFF, the encoder ought
						to have inserted a 0 bit a the beginning of the next byte (as usual).
						This last byte then contains only the stuffed 0 bit, the remaining bits
						are meaningless.
					*)
					IF curByte = 0FFH THEN
						curByte := NextByte();
					END;

					(* Check wether EPH markers have been used *)
					IF ephUsed THEN
						ReadEPH();
					END;

					(* Internalize code-block data *)
					FOR i := 0 TO blocksInPacket - 1 DO

						IF cblk[i].dataLen > 0 THEN
							NEW(cblk[i].data, cblk[i].dataLen);
							cr.ReadBytes(cblk[i].data^, cblk[i].dataLen);
							cblk[i].dataOffset := 0;
						END;
					END;

					RETURN blocksInPacket;
			END DecodePacket;


			PROCEDURE ReadCodingPasses() : LONGINT;
				VAR
					buf : LONGINT;
				BEGIN

					buf := NextBit();

					IF buf = 0 THEN
						RETURN 1;
					END;

					buf := NextBit();

					IF buf = 0 THEN
						RETURN 2;
					END;

					buf := NextBits(2);

					IF buf < 00000003H THEN
						RETURN 3 + buf;
					END;

					buf := NextBits(5);

					IF buf < 0000001FH THEN
						RETURN 6 + buf;
					END;

					buf := NextBits(7);

					RETURN 37 + buf;
			END ReadCodingPasses;

			PROCEDURE GetNumPrecincts(comp, reslevel : LONGINT) : LONGINT;
				BEGIN
					RETURN precInfo[curTile][comp][reslevel].nprecx * precInfo[curTile][comp][reslevel].nprecy;
			END GetNumPrecincts;

			(*
				Returns the maximum number of code-blocks in a packet for the current tile
				(i.e. maximum over all components and resolution levels for the current tile)
			*)
			PROCEDURE GetMaxNumCodeblocksPkt() : LONGINT;
				VAR
					ncomp, nprec, ndec, maxCblks, curCblks : LONGINT;
					i, r, k : LONGINT;
				BEGIN
					ncomp := decSpec.imgInfo.GetNumComponents();
					(* Initialize maximum to 0 *)
					maxCblks := 0;

					FOR i := 0 TO ncomp - 1 DO
						(* Go over all resolution levels *)
						(* First resoltion level (0) *)
						nprec := precInfo[curTile][i][0].nprecx * precInfo[curTile][i][0].nprecy;
						(* Loop over precincts *)
						FOR k := 0 TO nprec - 1 DO
							(* There's only the LL band *)
							curCblks := precInfo[curTile][i][0].nblocks[0][k][0] * precInfo[curTile][i][0].nblocks[0][k][1];
							IF curCblks > maxCblks THEN
								maxCblks := curCblks;
							END;
						END;

						(* Loop over remaining resolution levels *)
						ndec := decSpec.GetNumDecLevels(curTile, i);
						FOR r := 1 TO ndec DO
							nprec := precInfo[curTile][i][r].nprecx * precInfo[curTile][i][r].nprecy;
							(* Loop over precincts *)
							FOR k := 0 TO nprec - 1 DO
								(* We have the HL, LH and HH subbands *)
								curCblks := precInfo[curTile][i][r].nblocks[0][k][0] * precInfo[curTile][i][r].nblocks[0][k][1]
											+ precInfo[curTile][i][r].nblocks[1][k][0] * precInfo[curTile][i][r].nblocks[1][k][1]
											+ precInfo[curTile][i][r].nblocks[2][k][0] * precInfo[curTile][i][r].nblocks[2][k][1];
								IF curCblks > maxCblks THEN
									maxCblks := curCblks;
								END;
							END;
						END;
					END;

					RETURN maxCblks;
			END GetMaxNumCodeblocksPkt;


			(*
				Returns the code-block information object for the code-block located
				in component 'comp', resolution level 'reslevel', subband 'subband' and
				having code-block index 'cblkSubbIdx' within the subband.
			*)
			PROCEDURE GetCblkInfo (comp, reslevel, subband, cblkSubbIdx : LONGINT) : J2KU.CblkInfo;
				VAR
					lastIdx, cblkPrecIdx, cblkPrecIdxX, cblkPrecIdxY : LONGINT;
					nprecx, precIdx, precMin, precMax, precX, precY, precFirstInRowIdx : LONGINT;
					subbIdx, cblkSubbIdxX, cblkSubbIdxY, cblkInfoUpLeftIdx, cblkInfoLowRightIdx : LONGINT;
					subbInfo : J2KU.SubbandInfo;
				BEGIN
					nprecx := precInfo[curTile][comp][reslevel].nprecx;
					subbIdx := J2KU.SubbandToSubbandIndex(subband);

					subbInfo := cr.GetSubbandInfo(curTile, comp, reslevel, subband);

					(* Get the y and x indices of the code-block in the subband *)
					cblkSubbIdxX := cblkSubbIdx MOD subbInfo.nblocksx;
					cblkSubbIdxY := cblkSubbIdx DIV subbInfo.nblocksx;

					(* Search for x index of precinct in which the code-block is located *)
					(* -> Binary search *)
					precMin := 0;
					precMax := nprecx - 1;
					precX := ASH(precMax + precMin, -1);

					LOOP
						IF precMax <= precMin THEN EXIT END;
						(* Get the index of the first code-block in the precinct, i.e. the code-block at the upper left corner of the precinct *)
						cblkInfoUpLeftIdx := cblkInfo[curTile][comp][reslevel][subbIdx][precX][0].index;
						(* Get the index of the last code-block in the precinct, i.e. the code-block at the lower right corner of the precinct *)
						lastIdx := LEN(cblkInfo[curTile][comp][reslevel][subbIdx][precX]^) - 1;
						cblkInfoLowRightIdx := cblkInfo[curTile][comp][reslevel][subbIdx][precX][lastIdx].index;

						IF (cblkInfoUpLeftIdx MOD subbInfo.nblocksx) > cblkSubbIdxX THEN
							(* Searched precinct has lower x index *)
							precMax := precX - 1;
						ELSIF (cblkInfoLowRightIdx MOD subbInfo.nblocksx) < cblkSubbIdxX THEN
							(* Searched precinct has higher x index *)
							precMin := precX + 1;
						ELSE
							(* We have the correct x index of the precinct *)
							EXIT;
						END;

						precX := ASH(precMax + precMin, -1);
					END;

					(* Search for y index (within subband) of precinct *)
					precMin := 0;
					precMax := precInfo[curTile][comp][reslevel].nprecy - 1;
					precY := ASH(precMax + precMin, -1);
					precFirstInRowIdx := ASH(precMax + precMin, -1)*nprecx;

					LOOP
						IF precMax <= precMin THEN EXIT END;
						(* Get the index of the first code-block in the precinct, i.e. the code-block at the upper left corner of the precinct *)
						cblkInfoUpLeftIdx := cblkInfo[curTile][comp][reslevel][subbIdx][precFirstInRowIdx][0].index;
						(* Get the index of the last code-block in the precinct, i.e. the code-block at the lower right corner of the precinct *)
						lastIdx := LEN(cblkInfo[curTile][comp][reslevel][subbIdx][precFirstInRowIdx]^) - 1;
						cblkInfoLowRightIdx := cblkInfo[curTile][comp][reslevel][subbIdx][precFirstInRowIdx][lastIdx].index;

						IF (cblkInfoUpLeftIdx DIV subbInfo.nblocksx) > cblkSubbIdxY THEN
							(* Searched precinct has lower y index *)
							precMax := precY - 1;
						ELSIF (cblkInfoLowRightIdx DIV subbInfo.nblocksx) < cblkSubbIdxY THEN
							(* Searched precinct has higher y index *)
							precMin := precY + 1;
						ELSE
							(* We have the correct x index of the precinct *)
							EXIT;
						END;

						precY := ASH(precMax + precMin, -1);
						precFirstInRowIdx := ASH(precMax + precMin, -1)*nprecx;
					END;

					precIdx := precFirstInRowIdx + precX;

					(* Now compute the code-block index within the precinct *)
					cblkInfoUpLeftIdx := cblkInfo[curTile][comp][reslevel][subbIdx][precIdx][0].index;
					cblkPrecIdxX := cblkSubbIdxX - (cblkInfoUpLeftIdx MOD subbInfo.nblocksx);
					cblkPrecIdxY := cblkSubbIdxY - (cblkInfoUpLeftIdx DIV subbInfo.nblocksx);

					cblkPrecIdx := cblkPrecIdxY*precInfo[curTile][comp][reslevel].nblocks[subbIdx][precIdx][0] + cblkPrecIdxX;

					RETURN cblkInfo[curTile][comp][reslevel][subbIdx][precIdx][cblkPrecIdx];
			END GetCblkInfo;

			PROCEDURE GetIncStep (comp, reslevel : LONGINT; VAR xStep, yStep : LONGINT);
				BEGIN
					xStep := incStep[curTile][comp][reslevel][0];
					yStep := incStep[curTile][comp][reslevel][1];
			END GetIncStep;

			PROCEDURE GetMinIncStep (comp : LONGINT; VAR xStep, yStep : LONGINT);
				BEGIN
					xStep := minIncStep[curTile][comp][0];
					yStep := minIncStep[curTile][comp][1];
			END GetMinIncStep;

			PROCEDURE GetSotEot (comp, reslevel : LONGINT; VAR sotX, eotX, sotY, eotY : LONGINT);
				BEGIN
					sotX := sotEot[curTile][comp][reslevel][0][0];
					eotX := sotEot[curTile][comp][reslevel][0][1];
					sotY := sotEot[curTile][comp][reslevel][1][0];
					eotY := sotEot[curTile][comp][reslevel][1][1];
			END GetSotEot;

			PROCEDURE GetMaxSotEot (comp : LONGINT; VAR sotX, eotX, sotY, eotY : LONGINT);
				BEGIN
					sotX := maxSotEot[curTile][comp][0][0];
					eotX := maxSotEot[curTile][comp][0][1];
					sotY := maxSotEot[curTile][comp][1][0];
					eotY := maxSotEot[curTile][comp][1][1];
			END GetMaxSotEot;

			PROCEDURE ReadSOP;
				VAR
					marker : LONGINT;
					tmpBytes : ARRAY 6 OF CHAR;
				BEGIN
					(* See, if the marker is used *)
					marker := cr.Peek16();

					IF marker = SOP THEN
						(* Marker is used -> Skip the next 6 bytes *)
						(* NOTE: We don't do any checks *)
						cr.ReadBytes(tmpBytes, 6);
					END;
			END ReadSOP;

			PROCEDURE ReadEPH;
				VAR
					marker : LONGINT;
					tmpBytes : ARRAY 2 OF CHAR;
				BEGIN

					IF (pph # NIL) & ((LEN(pph.data^) - pphPos) >= 2) THEN
						marker :=	SYSTEM.VAL(LONGINT,
										SYSTEM.VAL(SET, LSH(LONG(ORD(pph.data[pphPos])), 8))
										+ SYSTEM.VAL(SET, LONG(ORD(pph.data[pphPos + 1])))
									);

						IF marker = EPH THEN
							INC(pphPos, 2);
						END;
					ELSE
						marker := cr.Peek16();

						IF marker = EPH THEN
							(* Marker is used -> Skip the next 2 bytes *)
							(* NOTE: We don't do any checks *)
							cr.ReadBytes(tmpBytes, 2);
						END;
					END;
			END ReadEPH;


			PROCEDURE NextByte () : LONGINT;
				VAR
					byte8 : CHAR;
				BEGIN
					IF pph # NIL THEN
						IF pphPos >= LEN(pph.data^) THEN
							pph := pph.next;

							IF pph = NIL THEN
								KernelLog.String("ERROR (PacketDecoder.NextByte) : No more data available from packed packet headers");
								KernelLog.Ln();
								RETURN -1;
							END;

							pphPos := 0;

						END;

						INC(pphPos);
						RETURN ORD(pph.data[pphPos - 1]);
					ELSE
						cr.ReadByte(byte8);
						RETURN ORD(byte8);
					END;
			END NextByte;


			(*
				Reads the next bit in the stream (i.e. the next bit in the buffer which contains the
				most recently read "stream byte". Bit unstuffing is performed, where necessary.
			*)
			PROCEDURE NextBit() : LONGINT;
				BEGIN
					IF curBytePos =  0 THEN

						(* Do bit unstuffing? *)
						IF curByte = 0FFH THEN
							curBytePos := 7;
						ELSE
							curBytePos := 8;
						END;

						curByte := NextByte();
					END;

					DEC(curBytePos);

					RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(curByte, -curBytePos)) * {0}	);
			END NextBit;


			(*
				Reads the next bits in the stream (i.e. the next bits from the stream).
				At most 32 bits may be read. Bit unstuffing is performed, where necessary.
			*)
			PROCEDURE NextBits (n : LONGINT) : LONGINT;
				VAR
					result : LONGINT;
				BEGIN
					IF n <= curBytePos THEN
						DEC(curBytePos, n);

						RETURN SYSTEM.VAL(LONGINT,
										SYSTEM.VAL(SET, LSH(curByte, -curBytePos))
										* SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), n) - 1)
									);


					ELSE
						result := 0;

						REPEAT
							result := SYSTEM.VAL(LONGINT,
													SYSTEM.VAL(SET, LSH(result, curBytePos))
													+	(
															SYSTEM.VAL(SET, curByte)
															* SYSTEM.VAL(SET, LSH(SYSTEM.VAL(LONGINT, 1), curBytePos) - 1)
														)
												);

							DEC(n, curBytePos);

							(* Do bit unstuffing? *)
							IF curByte = 0FFH THEN
								curBytePos := 7;
							ELSE
								curBytePos := 8;
							END;

							curByte := NextByte();

						UNTIL n <= curBytePos;

						DEC(curBytePos, n);

						result := SYSTEM.VAL(LONGINT,
												SYSTEM.VAL(SET, LSH(result, n))
												+ SYSTEM.VAL(SET, LSH(curByte, -curBytePos))
											);
						RETURN result;
					END;

			END NextBits;

		END PacketDecoder;



		CodestreamReader* = OBJECT
			VAR
				s : Streams.Reader;	(* A reference to the stream containing the JPEG2000 codestream *)
				ntp : LONGINT;				(* The number of tile-parts found in the stream (including the current part) *)
				ntilePartsRead : J2KU.LongIntArrayPtr;	(* The number of tile-parts found in the stream, for each tile *)
				ntilePartsAvailable : J2KU.LongIntArrayPtr;	(* The number of tile-parts for each tile as signalled in by a TNSot parameter of a SOT segment of at least one tile-part *)
				curTile : LONGINT;			(* The index of the current tile for which data is being read *)
				curPart : LONGINT;			(* The index of the current tile-part of curTile for which data is being read *)
				partRem : LONGINT;			(* Number of bytes remaining in the current tile-part *)
				initError : BOOLEAN;		(* TRUE if an error occured during initialization *)
				pktDec : PacketDecoder;		(* The packet decoder used to extract encoded code-block data *)
				cblkBuf : POINTER TO ARRAY OF J2KU.CodedCblk;		(* Buffer for coded code-blocks obtained from the packed decoder *)
				cblkInfoBuf : POINTER TO ARRAY OF J2KU.CblkInfo;
				cblkBufSize : LONGINT;
				ncblkInBuf : LONGINT;
				cblkBufPos : LONGINT;
				endOfCS : BOOLEAN;
				curMarker : LONGINT;
				(*
					Subband information objects
					1st dim: tile index
					2nd dim: component index
					3rd dim: subbands in order (from lowest to highes resolution level, always 4 subbands: LL, HL, LH, HH, in that order)
				*)
				subbInfos : POINTER TO ARRAY OF ARRAY OF POINTER TO ARRAY OF J2KU.SubbandInfo;
				decSpec : DecoderSpecs;
				ppmUsed : BOOLEAN;		(* True if packed packet headers in the main header are used *)
				buf8 : LONGINT;
				buf8Valid : BOOLEAN;

				(*
					Pointers to progression order changes
					1st dim: tile index
					2nd dim: progression change
				*)
				progChanges : POINTER TO ARRAY OF ProgChangeArrayPtr;

				(*
					References to current progression state of each tile:
					1st dim: tile index
				*)
				progStates : POINTER TO ARRAY OF ProgState;

				curLay, curComp, curRes : LONGINT;
				(*
					Current precinct(s) for which packets are being received.
					1st dim: component
					2nd dim: resolution level
					3rd dim: layer
				*)
				curPrec : J2KU.LongInt3DArrayPtr;
				lmin : J2KU.LongInt2DArrayPtr;
				lmax, cmax, rmax, rmin, cmin : LONGINT;
				curX, curY, incX, incY : LONGINT;
				xmax, ymax, xmin, ymin : LONGINT;
				progOrder : LONGINT;

				maxStartLayer, maxEndLayer : LONGINT;
				startLayer, endLayer : LONGINT;
				maxStartDecLvl, maxEndDecLvl : LONGINT;
				startDecLvl, endDecLvl : LONGINT;

				(* If TRUE, tile-part and main headers will be printed (to a certain extent) *)
				printCSInfo : BOOLEAN;
				(* If TRUE, comments found in COM segments will be printed *)
				printCOM : BOOLEAN;

			(*
				Initializes an instance of a JPEG2000-Codestream-Reader.
				The main header is already read here.
				NOTE: The constructor actually just makes a call to the re-initialization method.

				crOpt : The codestream reader options
				stream : The raw byte stream
			*)
			PROCEDURE &InitNew* (crOpt : J2KU.CodestreamReaderOptions;
									stream : Streams.Reader);
				BEGIN
					pktDec := NIL;
					ReInit(crOpt, stream);
			END InitNew;


			(**
				Re-Initializes the JPEG2000-Codestream-Reader.
				The main header is read here.

				crOpt : The codestream reader options
				stream : The raw byte stream
			*)
			PROCEDURE ReInit* (crOpt : J2KU.CodestreamReaderOptions;
								stream : Streams.Reader);
				VAR
					ok : BOOLEAN;
					nt, ncomp, comp, i, j : LONGINT;
					markerStr : ARRAY 8 OF CHAR;
					nppmLeft, nppmRead : LONGINT;
					ppmFirst, ppmLast : DataListElement;
					ncod, nqcd, npoc, ncrg : LONGINT; (* Counter variables used for constraint checking *)
					ncoc, nqcc, nrgn : J2KU.LongIntArrayPtr;
					changes : ProgChangeArrayPtr;
					cstyle : CodingStyle;
					cics : CICodingStyle;
					quant : Quantization;
					imgInfo : ImageInfo;
					roiShift : LONGINT;
				BEGIN
					s := stream;
					curMarker := s.Net16();
					printCOM := crOpt.printComments;

					IF curMarker # SOC THEN
						KernelLog.String("ERROR (CodestreamReader.InitNew): Unexpected/Invalid marker found at beginning of codestream (");
						MarkerToString(curMarker, markerStr);
						KernelLog.String(markerStr);
						KernelLog.String(")");
						KernelLog.Ln();
						initError := TRUE;
						RETURN;
					END;

					curMarker := s.Net16();

					IF curMarker # SIZ THEN
						KernelLog.String("ERROR: Unexpected/Invalid marker found at beginning of main header (");
						MarkerToString(curMarker, markerStr);
						KernelLog.String(markerStr);
						KernelLog.String(")");
						KernelLog.Ln();
						initError := TRUE;
						RETURN;
					END;

					ok := ReadSIZSegment(imgInfo);

					IF ok THEN
						(* Initialize local variables *)
						nt := imgInfo.nt;
						ncomp := imgInfo.ncomp;
						ncod := 0;
						nqcd := 0;
						npoc := 0;
						ncrg := 0;
						NEW(ncoc, ncomp);
						NEW(nqcc, ncomp);
						NEW(nrgn, ncomp);

						Machine.Fill32(ADDRESSOF(ncoc[0]), imgInfo.ncomp*SIZEOF(LONGINT), 0);
						Machine.Fill32(ADDRESSOF(nqcc[0]), imgInfo.ncomp*SIZEOF(LONGINT), 0);
						Machine.Fill32(ADDRESSOF(nrgn[0]), imgInfo.ncomp*SIZEOF(LONGINT), 0);

						nppmLeft := 0;
						nppmRead := 0;
						ppmFirst := NIL;
						ppmLast := NIL;

						(* Initialize member variables needed soon *)
						ppmUsed := FALSE;
						progChanges := NIL;

						(* Now the image information is available and we may allocate the space needed *)
						NEW(decSpec);
						decSpec.imgInfo := imgInfo;
						NEW(decSpec.cstyle, nt, ncomp);
						NEW(decSpec.cics, nt);
						NEW(decSpec.quant, nt, ncomp);
						NEW(decSpec.roiShift, nt, ncomp);
						Machine.Fill32(ADDRESSOF(decSpec.roiShift[0][0]), nt*ncomp*SIZEOF(LONGINT), -1);

						curMarker := s.Net16();
					END;

					WHILE ok & (curMarker # SOT) DO

						CASE curMarker OF
							|	COD :
									ok := ReadCODSegment(cstyle, cics);

									FOR i := 0 TO nt - 1 DO
										decSpec.cics[i] := cics;

										FOR j := 0 TO ncomp - 1 DO
											IF ncoc[j] = 0 THEN
												decSpec.cstyle[i][j] := cstyle;
											END;
										END;
									END;

									INC(ncod);
							|	COC :
									ok := ReadCOCSegment(cstyle, comp);

									(* We need to add the check here, since 'comp' could be beyond of the valid range *)
									IF ok THEN
										(* This is the default coding style for this component (for all tiles) *)
										FOR i := 0 TO nt - 1 DO
											decSpec.cstyle[i][comp] := cstyle;
										END;
										INC(ncoc[comp]);
									END;
							|	RGN :
									ok := ReadRGNSegment(roiShift, comp);

									(* We need to add the check here, since 'comp' could be beyond of the valid range *)
									IF ok THEN
										FOR i := 0 TO nt - 1 DO
											decSpec.roiShift[i][comp] := roiShift;
										END;
										INC(nrgn[comp]);
									END;
							|	QCD :
									ok := ReadQCDSegment(quant);

									FOR i := 0 TO nt - 1 DO
										FOR j := 0 TO ncomp - 1 DO
											IF nqcc[j] = 0 THEN
												decSpec.quant[i][j] := quant;
											END;
										END;
									END;

									INC(nqcd);
							|	QCC :
									ok := ReadQCCSegment(quant, comp);

									(* We need to add the check here, since 'comp' could be beyond of the valid range *)
									IF ok THEN
										(* This is the default quantization for this component (for all tiles) *)
										FOR i := 0 TO nt - 1 DO
											decSpec.quant[i][comp] := quant;
										END;
										INC(nqcc[comp]);
									END;
							|	POC :
									ok := ReadPOCSegment(changes);

									NEW(progChanges, nt);
									FOR i := 0 TO nt - 1 DO
										progChanges[i] := changes;
									END;

									INC(npoc);
							|	TLM :
									ok := ReadTLMSegment();
							|	PLM :
									ok := ReadPLMSegment();
							|	PPM :
									ok := ReadPPMSegment(ppmFirst, ppmLast, nppmLeft, nppmRead);
									ppmUsed := TRUE;
							|	CRG :
									ok := ReadCRGSegment();
									INC(ncrg);
							|	COM :
									ok := ReadCOMSegment();
							ELSE
								KernelLog.String("ERROR: Unexpected/Invalid marker found in main header (");
								MarkerToString(curMarker, markerStr);
								KernelLog.String(markerStr);
								KernelLog.String(")");
								KernelLog.Ln();
								ok := FALSE;
						END;

						curMarker := s.Net16();
					END;

					IF ok THEN
						(* Constraint checks *)
						IF ncod # 1 THEN
							KernelLog.String("ERROR: Found ");
							KernelLog.Int(ncod, 0);
							KernelLog.String(" COD segments in main header (exactly 1 required)");
							KernelLog.Ln();
							ok := FALSE;
						END;

						IF nqcd # 1 THEN
							KernelLog.String("ERROR: Found ");
							KernelLog.Int(nqcd, 0);
							KernelLog.String(" QCD segments in main header (exactly 1 required)");
							KernelLog.Ln();
							ok := FALSE;
						END;

						IF npoc > 1 THEN
							KernelLog.String("ERROR: Found ");
							KernelLog.Int(npoc, 0);
							KernelLog.String(" POC segments in main header (at most 1 allowed)");
							KernelLog.Ln();
							ok := FALSE;
						END;

						IF ncrg > 1 THEN
							KernelLog.String("ERROR: Found ");
							KernelLog.Int(ncrg, 0);
							KernelLog.String(" CRG segments in main header (at most 1 allowed)");
							KernelLog.Ln();
							ok := FALSE;
						END;

						(* Check cardinality constraints of component-specific segments *)
						FOR i := 0 TO ncomp - 1 DO
							IF ncoc[i] > 1 THEN
								KernelLog.String("ERROR: Found ");
								KernelLog.Int(ncoc[i], 0);
								KernelLog.String(" COC segments for component ");
								KernelLog.Int(i, 0);
								KernelLog.String(" in main header (at most 1 per component allowed)");
								KernelLog.Ln();
								ok := FALSE;
							END;

							IF nqcc[i] > 1 THEN
								KernelLog.String("ERROR: Found ");
								KernelLog.Int(nqcc[i], 0);
								KernelLog.String(" QCC segments for component ");
								KernelLog.Int(i, 0);
								KernelLog.String(" in main header (at most 1 per component allowed)");
								KernelLog.Ln();
								ok := FALSE;
							END;

							IF nrgn[i] > 1 THEN
								KernelLog.String("ERROR: Found ");
								KernelLog.Int(nrgn[i], 0);
								KernelLog.String(" RGN segments for component ");
								KernelLog.Int(i, 0);
								KernelLog.String(" in main header (at most 1 per component allowed)");
								KernelLog.Ln();
								ok := FALSE;
							END;
						END;
					END;

					IF ok THEN
						(* Initialize and/or create other members, now that we know that all went well *)
						ntp := 0;
						NEW(ntilePartsRead, nt);
						NEW(ntilePartsAvailable, nt);

						Machine.Fill32(ADDRESSOF(ntilePartsRead[0]), nt*SIZEOF(LONGINT), 0);
						Machine.Fill32(ADDRESSOF(ntilePartsAvailable[0]), nt*SIZEOF(LONGINT), 0);

						ncblkInBuf := 0;
						cblkBufPos := 0;
						cblkBufSize := 0;
						partRem := 0;
						endOfCS := FALSE;
						buf8Valid := FALSE;

						(* We set the maximum range to the maximum allowed (we don't use it here anyhow) *)
						maxStartLayer := 0;
						maxEndLayer := MAX(LONGINT);
						maxStartDecLvl := MAX(LONGINT);
						maxEndDecLvl := 0;
						(* Whole image shall be decoded by default *)
						startLayer := 0;
						endLayer := MAX(LONGINT);
						startDecLvl := MAX(LONGINT);
						endDecLvl := 0;

						NEW(subbInfos, nt, ncomp);

						NEW(progStates, nt);

						IF pktDec = NIL THEN
							NEW(pktDec, SELF, decSpec, ppmFirst);
						ELSE
							pktDec.ReInit(SELF, decSpec, ppmFirst);
						END;
					END;

					initError := ~ok;
			END ReInit;


			PROCEDURE InitError* () : BOOLEAN;
				BEGIN
					RETURN initError;
			END InitError;


			(**
				Reads the header of the next tile-part (if any)
				RETURN: TRUE, if data for the next tile-part is ready to be read, FALSE otherwise
			*)
			PROCEDURE NextTilePart*() : BOOLEAN;
				VAR
					markerStr : ARRAY 8 OF CHAR;
					ok : BOOLEAN;
					bytesSkipped, ncomp, c, ndec: LONGINT;
				BEGIN

					(* Check preconditions *)
					IF endOfCS THEN
						KernelLog.String("ERROR (CodestreamReader.NextTilePart) : Already at end of stream");
						KernelLog.Ln();
						RETURN FALSE;
					ELSIF TilePartAvailable() THEN
						bytesSkipped := JumpToTilePartEnd();
						(*
							There was some data available before jumping to the end of the tile-part,
							so the number of skipped bytes must be > 0
						*)
						IF bytesSkipped <= 0 THEN
							KernelLog.String("ERROR (CodestreamReader.NextTilePart): ");
							KernelLog.String("Tried to jump to end of tile-part (because end of current tile-part has not been reached yet), but failed");
							KernelLog.Ln();
							RETURN FALSE;
						END;
					END;

					IF ntp > 0 THEN
						(* Need to see if we have a byte (of the stream) in the buffer -> flush buffer if so *)
						IF buf8Valid THEN
							buf8Valid := FALSE;
							curMarker := SYSTEM.VAL(LONGINT,
													SYSTEM.VAL(SET, LSH(buf8, 8))
													+ SYSTEM.VAL(SET, LONG(ORD(s.Get())))
											);
						ELSE
							curMarker := s.Net16();
						END;

						(* Write back progression information on the last tile *)
						progStates[curTile].progOrder := progOrder;
						progStates[curTile].curLay := curLay;
						progStates[curTile].startLay := lmin;
						progStates[curTile].endLay := lmax;
						progStates[curTile].curRes := curRes;
						progStates[curTile].endRes := rmax;
						progStates[curTile].startRes := rmin;
						progStates[curTile].curComp := curComp;
						progStates[curTile].endComp := cmax;
						progStates[curTile].startComp := cmin;
						progStates[curTile].curPrec := curPrec;
						progStates[curTile].curX := curX;
						progStates[curTile].curY := curY;
					END;

					IF curMarker = SOT THEN
						IF ReadSOTSegment() THEN
							IF curPart = 0 THEN
								CreateSubbandInfos();
								pktDec.SetAndInitTile(curTile);

								(* Init the progression number field of the progression state record  for this tile *)
								progStates[curTile].progNr := 0;

								ncomp := decSpec.imgInfo.ncomp;
								NEW(lmin, ncomp);
								FOR c := 0 TO ncomp - 1 DO
									ndec := decSpec.cstyle[curTile][c].ndec;
									NEW(lmin[c], ndec + 1);
									Machine.Fill32(ADDRESSOF(lmin[c][0]), (ndec+1)*SIZEOF(LONGINT), 0);
								END;

								lmax := -1;
								(* We need to start a new progression *)
								ProgressionChange();
								(* Set the start values *)
								curRes := rmin;
								curComp := cmin;
								curLay := 0;

								curX := xmin;
								curY := ymin;
							ELSE
								pktDec.SetTile(curTile);

								(* Set the current progression order for the current tile *)
								progOrder := progStates[curTile].progOrder;
								curLay := progStates[curTile].curLay;
								lmin := progStates[curTile].startLay;
								lmax := progStates[curTile].endLay;
								curRes := progStates[curTile].curRes;
								rmax := progStates[curTile].endRes;
								rmin := progStates[curTile].startRes;
								curComp := progStates[curTile].curComp;
								cmax:= progStates[curTile].endComp;
								cmin := progStates[curTile].startComp;
								curPrec := progStates[curTile].curPrec;
								curX := progStates[curTile].curX;
								curY := progStates[curTile].curY;
								pktDec.GetMinIncStep(curComp, incX, incY);
								pktDec.GetMaxSotEot(curComp, xmin, xmax, ymin, ymax);
								(* The coordinates of the last sample are (xmax - 1, ymax - 1) *)
								DEC(xmax);
								DEC(ymax);
							END;

							(*
								Call the initialization routine for the new tile (even if the new tile-part belongs to the
								same tile as the last one)
							*)
							IF InitTile() THEN
								INC(ntp);
								INC(ntilePartsRead[curTile]);
								ok := TRUE;
							END;
						ELSE
							ok := FALSE;
						END;
					ELSIF curMarker = EOC THEN
						endOfCS := TRUE;
						ok := FALSE;
					ELSE
						MarkerToString(curMarker, markerStr);
						KernelLog.String("ERROR (CodestreamReader.NextTilePart) : Invalid marker found (");
						KernelLog.String(markerStr);
						KernelLog.String(")");
						KernelLog.Ln();
						ok := FALSE;
					END;

					RETURN ok;
			END NextTilePart;


			PROCEDURE InitTile () : BOOLEAN;
				VAR
					nblocksPkt : LONGINT;
				BEGIN
					(* See how much packets there are at most for this tile *)
					nblocksPkt := pktDec.GetMaxNumCodeblocksPkt();

					(* Adjust buffer size if needed *)
					IF nblocksPkt > cblkBufSize THEN
						NEW(cblkBuf, nblocksPkt);
						NEW(cblkInfoBuf, nblocksPkt);
						cblkBufSize := nblocksPkt;
					END;

					RETURN TRUE;
			END InitTile;

			(**
				Sets the maximum layer range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested.
				This procedure shall NOT be called after the first code-block data
				has been read.

				maxStartLayer and maxEndLayer are inclusive.
			*)
			PROCEDURE SetMaxLayerRange* (maxStartLayer, maxEndLayer : LONGINT);
				BEGIN
					SELF.maxStartLayer := maxStartLayer;
					SELF.maxEndLayer := maxEndLayer;
			END SetMaxLayerRange;

			(**
				Sets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE SetLayerRange* (startLayer, endLayer : LONGINT);
				BEGIN
					SELF.startLayer := startLayer;
					SELF.endLayer := endLayer;
			END SetLayerRange;

			(**
				Gets the layer range for which data shall be delivered
				and decoded.

				startLayer and endLayer are inclusive.
			*)
			PROCEDURE GetLayerRange* (VAR startLayer, endLayer : LONGINT);
				BEGIN
					startLayer := SELF.startLayer;
					endLayer := SELF.endLayer;
			END GetLayerRange;

			(**
				Sets the maximum decomposition level range for which data shall be delivered
				and decoded, i.e. data outside this range shall NEVER be requested. This procedure
				shall NOT be called after the first code-block data has been read.

				maxStartDecLvl : The decompositon level to start at (inclusive) -> upper bound
				maxEndDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetMaxDecLevelRange* (maxStartDecLvl, maxEndDecLvl : LONGINT);
				BEGIN
					SELF.maxStartDecLvl := maxStartDecLvl;
					SELF.maxEndDecLvl := maxEndDecLvl;
			END SetMaxDecLevelRange;

			(**
				Sets the decomposition level range for which data shall be delivered
				and decoded.

				startDecLvl : The decompositon level to start at (inclusive) -> upper bound
				endDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE SetDecLevelRange* (startDecLvl, endDecLvl : LONGINT);
				BEGIN
					SELF.startDecLvl := startDecLvl;
					SELF.endDecLvl := endDecLvl;
			END SetDecLevelRange;

			(**
				Gets the decomposition level range for which data shall be delivered
				and decoded.

				startDecLvl : The decompositon level to start at (inclusive) -> upper bound
				endDecLvl : The decomposition level to end at (inclusive) -> lower bound
			*)
			PROCEDURE GetDecLevelRange* (VAR startDecLvl, endDecLvl : LONGINT);
				BEGIN
					startDecLvl := SELF.startDecLvl;
					endDecLvl := SELF.endDecLvl;
			END GetDecLevelRange;

			PROCEDURE SetReBuildMode*;
				BEGIN
					(* No rebuild allowed *)
					HALT(99);
			END SetReBuildMode;

			(**
				Gets the next (coded) code-blocks for the current tile-part in the stream. Previously a call to ReadTilePartHeader
				is necessary before any code-blocks may be read.

				cblocks: 	A reference to an array where CodedCblk records are stored
				cblockInfos:	A reference to an array where CblkInfo object references may be stored
										These objects will contain information about the code-blocks in cblocks
				ncblocks: 	The number of code-blocks that shall be fetched
				RETURN:	The actual number of code-blocks fetched
			*)
			PROCEDURE GetCodeBlocks* (VAR cblocks : ARRAY OF J2KU.CodedCblk; VAR cblockInfos: ARRAY OF J2KU.CblkInfo; ncblocks : LONGINT) : LONGINT;
				VAR
					i, startPos, cblkDecLvl : LONGINT;
					ok : BOOLEAN;
				BEGIN

					i := 0;
					(* See, wether buffer not empty: if not then return max(bufSize, ncblocks) code blocks *)
					WHILE i < ncblocks DO
						(* See if the code-block buffer has been read entirely *)
						IF ~TilePartAvailable() THEN
							RETURN i;
						END;

						IF ncblkInBuf <= cblkBufPos THEN

							startPos := s.Pos();

							(* Read the next packet *)
							ncblkInBuf := pktDec.DecodePacket(curComp, curRes, curLay, curPrec[curComp][curRes][curLay], cblkBuf^, cblkInfoBuf^);

							(* Need to check if the code-block is in the valid range (decomposition level, layer) *)
							cblkDecLvl := decSpec.cstyle[curTile][curComp].ndec - curRes;

							IF 	(cblkDecLvl < endDecLvl)
								OR (cblkDecLvl > startDecLvl)
								OR (curLay < startLayer)
								OR (curLay > endLayer)
							THEN
								ncblkInBuf := 0;
							END;

							CASE progOrder OF
									PROG_LRCP:
										ok := AdvanceLayResComPos ();
								|	PROG_RLCP:
 										ok := AdvanceResLayComPos ();
								|	PROG_RPCL:
										ok := AdvanceResPosComLay ();
								|	PROG_PCRL:
										ok := AdvancePosComResLay ();
								|	PROG_CPRL:
										ok := AdvanceComPosResLay ();
								ELSE
									ok := FALSE;
							END;

							cblkBufPos := 0;
							partRem := partRem - (s.Pos() - startPos);

							IF ~ok THEN
								RETURN i;
							END;
						ELSE
							IF cblkBuf[cblkBufPos].dataLen > 0 THEN (* Don't deliver code-blocks with no data *)
								cblocks[i] := cblkBuf[cblkBufPos];
								cblockInfos[i] := cblkInfoBuf[cblkBufPos];

								(* If we don't start from layer 0, we update the current bit plane *)
								IF startLayer > 0 THEN
									cblockInfos[i].curbp :=	J2KU.LONGINT_BITS - 2 - cblockInfos[i].zerobp
															- ((cblockInfos[i].truncpt - cblocks[i].cpasses + 2) DIV 3);
								END;

								INC(i);
							END;

							INC(cblkBufPos);
						END;
					END;

					RETURN ncblocks;
			END GetCodeBlocks;


			PROCEDURE AdvanceLayResComPos () : BOOLEAN;
				VAR
					kmax, c, r : LONGINT;
				BEGIN
					kmax := pktDec.GetNumPrecincts(curComp, curRes) - 1;

					IF curPrec[curComp][curRes][curLay] >= kmax THEN
						(* We need to jump to the next nearest component that has as much resolution levels as indicated by curRes *)
						REPEAT
							IF curComp >= cmax THEN
								IF curRes >= rmax THEN
									IF curLay >= lmax THEN
										(* We have reached the end of this progression -> get next progression *)
										ProgressionChange();

										curLay := MAX(LONGINT);
										FOR c := cmin TO cmax DO
											FOR r := rmin TO rmax DO
												IF (r < LEN(lmin[c]^)) & (lmin[c][r] < curLay) THEN
													curLay := lmin[c][r];
												END;
											END;
										END;
									ELSE
										INC(curLay);
									END;
									curRes := rmin;
								ELSE
									INC(curRes);
								END;
								curComp := cmin;
							ELSE
								INC(curComp);
							END;
						UNTIL (curRes <= decSpec.cstyle[curTile][curComp].ndec) & (curLay >= lmin[curComp][curRes]);
					ELSE
						INC(curPrec[curComp][curRes][curLay]);
					END;

					RETURN TRUE;
			END AdvanceLayResComPos;

			PROCEDURE AdvanceResLayComPos () : BOOLEAN;
				VAR
					kmax, c : LONGINT;
				BEGIN
					kmax := pktDec.GetNumPrecincts(curComp, curRes) - 1;

					IF curPrec[curComp][curRes][curLay] >= kmax THEN
						(* We need to jump to the next nearest component that has as much resolution levels as indicated by curRes *)
						REPEAT
							IF curComp >= cmax THEN
								IF curLay >= lmax THEN
									IF curRes >= rmax THEN
										(* We have reached the end of this progression -> get next progression *)
										ProgressionChange();
										curRes := rmin;
									ELSE
										INC(curRes);
									END;

									curLay := MAX(LONGINT);
									FOR c := cmin TO cmax DO
										IF (curRes < LEN(lmin[c]^)) & (lmin[c][curRes] < curLay) THEN
											curLay := lmin[c][curRes];
										END;
									END;
								ELSE
									INC(curLay);
								END;
								curComp := cmin;
							ELSE
								INC(curComp);
							END;
						UNTIL (curRes <= decSpec.cstyle[curTile, curComp].ndec) & (curLay >= lmin[curComp][curRes]);
					ELSE
						INC(curPrec[curComp][curRes][curLay]);
					END;

					RETURN TRUE;
			END AdvanceResLayComPos;

			PROCEDURE AdvanceResPosComLay () : BOOLEAN;
				VAR
					foundNext : BOOLEAN;
					incXR, incYR : LONGINT;
				BEGIN
					foundNext := FALSE;

					INC(curPrec[curComp][curRes][curLay]);

					(* Get the minimum increment step, i.e. the minimum precinct size projected to the reference grid at full resolution *)
					IF curLay >= lmax THEN
						(* We need to jump to the next nearest component that has as much resolution levels as indicated by curRes *)
						REPEAT
							IF curComp >= cmax THEN
								IF curX >= xmax THEN
									IF curY  >= ymax THEN
										IF curRes >= rmax THEN
											(* We have reached the end of this progression -> get next progression *)
											ProgressionChange();
											curRes := rmin;
										ELSE
											INC(curRes);
										END;
										curY := ymin;
									ELSE
										INC(curY, incY);
									END;
									curX := xmin;
								ELSE
									INC(curX, incX);
								END;
								curComp := cmin;
							ELSE
								INC(curComp);
							END;

							IF (curRes <= decSpec.GetNumDecLevels(curTile, curComp)) THEN
								pktDec.GetIncStep(curComp, curRes, incXR, incYR);

								IF (((curX = xmin) OR (curX MOD incXR = 0)) & (curX <= xmax))
									& (((curY = ymin) OR (curY MOD incYR = 0)) & (curY <= ymax))
								THEN
									foundNext := TRUE;
								END;
							END;
						UNTIL foundNext;

						curLay := lmin[curComp][curRes];
					ELSE
						INC(curLay);
					END;

					RETURN TRUE;
			END AdvanceResPosComLay;

			PROCEDURE AdvancePosComResLay () : BOOLEAN;
				VAR
					foundNext : BOOLEAN;
					incXR, incYR : LONGINT;
				BEGIN
					foundNext := FALSE;

					INC(curPrec[curComp][curRes][curLay]);

					(* Get the minimum increment step, i.e. the minimum precinct size projected to the reference grid at full resolution *)
					IF curLay >= lmax THEN
						(* We need to jump to the next nearest component that has as much resolution levels as indicated by curRes *)
						REPEAT
							IF curRes >= rmax THEN
								IF curComp >= cmax THEN
									IF curX  >= xmax THEN
										IF curY >= ymax THEN
											(* We have reached the end of this progression -> get next progression *)
											ProgressionChange();
											curY := ymin;
										ELSE
											INC(curY, incY);
										END;
										curX := xmin;
									ELSE
										INC(curX, incX);
									END;
									curComp := cmin;
								ELSE
									INC(curComp);
								END;
								curRes := rmin;
							ELSE
								INC(curRes);
							END;

							IF (curRes <= decSpec.GetNumDecLevels(curTile, curComp)) THEN
								pktDec.GetIncStep(curComp, curRes, incXR, incYR);

								IF (((curX = xmin) OR (curX MOD incXR = 0)) & (curX <= xmax))
									& (((curY = ymin) OR (curY MOD incYR = 0)) & (curY <= ymax))
								THEN
									foundNext := TRUE;
								END;
							END;
						UNTIL foundNext;

						curLay := lmin[curComp][curRes];
					ELSE
						INC(curLay);
					END;

					RETURN TRUE;
			END AdvancePosComResLay;

			PROCEDURE AdvanceComPosResLay () : BOOLEAN;
				VAR
					foundNext : BOOLEAN;
					incXR, incYR : LONGINT;
				BEGIN
					foundNext := FALSE;

					INC(curPrec[curComp][curRes][curLay]);

					(* Get the minimum increment step, i.e. the minimum precinct size projected to the reference grid at full resolution *)
					IF curLay >= lmax THEN
						(* We need to jump to the next nearest component that has as much resolution levels as indicated by curRes *)
						REPEAT
							IF curRes >= rmax THEN
								IF curX >= xmax THEN
									IF curY  >= ymax THEN
										IF curComp >= cmax THEN
											(* We have reached the end of this progression -> get next progression *)
											ProgressionChange();
											curComp := cmin;
										ELSE
											INC(curComp);
										END;
										curY := ymin;
									ELSE
										INC(curY, incY);
									END;
									curX := xmin;
								ELSE
									INC(curX, incX);
								END;
								curRes := rmin;
							ELSE
								INC(curRes);
							END;

							IF (curRes <= decSpec.GetNumDecLevels(curTile, curComp)) THEN
								pktDec.GetIncStep(curComp, curRes, incXR, incYR);

								IF (((curX = xmin) OR (curX MOD incXR = 0)) & (curX <= xmax))
									& (((curY = ymin) OR (curY MOD incYR = 0)) & (curY <= ymax))
								THEN
									foundNext := TRUE;
								END;
							END;
						UNTIL foundNext;

						curLay := lmin[curComp][curRes];
					ELSE
						INC(curLay);
					END;

					RETURN TRUE;
			END AdvanceComPosResLay;

			(*
				TODO:	The implementation of this procedure conforms with the reference implmentation (JJ2000).
						But it's not clear, wether the reference implementation is correct (on the issue of
						progression changes, that is).

						-> See further below.
			*)
			PROCEDURE ProgressionChange;
				VAR
					nextProgIdx, c, r : LONGINT;
				BEGIN

					(* Update next first layer index *)
					FOR c := cmin TO cmax DO
						FOR r := rmin TO rmax DO
							IF r < LEN(lmin[c]^) THEN
								lmin[c][r] := lmax + 1;
							END;
						END;
					END;

					nextProgIdx := progStates[curTile].progNr;

					IF (progChanges # NIL) & (progChanges[curTile] # NIL) & (nextProgIdx < LEN(progChanges[curTile]^)) THEN
						IF nextProgIdx > 0 THEN
							progOrder := progChanges[curTile][nextProgIdx - 1].progOrder;
						ELSE
							progOrder := decSpec.cics[curTile].po;
						END;

						rmax := progChanges[curTile][nextProgIdx].endRes - 1;
						cmax := progChanges[curTile][nextProgIdx].endComp - 1;
						lmax := progChanges[curTile][nextProgIdx].endLay - 1;
						rmin := progChanges[curTile][nextProgIdx].startRes;
						cmin := progChanges[curTile][nextProgIdx].startComp;
					ELSE
						IF (progChanges # NIL) & (progChanges[curTile] # NIL) & (nextProgIdx = LEN(progChanges[curTile]^)) THEN
							progOrder := progChanges[curTile][nextProgIdx - 1].progOrder;
						ELSE
							progOrder := decSpec.cics[curTile].po;
						END;

						rmax := decSpec.GetMaxDecLevels(curTile);
						cmax :=  decSpec.imgInfo.ncomp - 1;
						lmax := decSpec.cics[curTile].nl - 1;
						rmin := 0;
						cmin := 0;
					END;

					(* Set the position boundaries (even if not needed) *)
					pktDec.GetMinIncStep(cmin, incX, incY);
					pktDec.GetMaxSotEot(cmin, xmin, xmax, ymin, ymax);
					DEC(xmax);
					DEC(ymax);

					(* Need to create/reinitialize new precinct counters *)
					CreatePrecCounter();

					INC(progStates[curTile].progNr);
			END ProgressionChange;

		(*	TODO:	The semantics of a progression change implied by the reference codec (JJ2000) differs from
					the semantics suggested by this procedure. But which interpretation is correct?
		*)
		(*
			PROCEDURE ProgressionChange ();
				VAR
					nextProgIdx, c, r : LONGINT;
				BEGIN
					(* Update next first layer index *)
					FOR c := cmin TO cmax DO
						FOR r := rmin TO rmax DO
							IF r < LEN(lmin[c]^) THEN
								lmin[c][r] := lmax + 1;
							END;
						END;
					END;

					nextProgIdx := progStates[curTile].progNr;

					IF (progChanges # NIL) & (progChanges[curTile] # NIL) & (nextProgIdx < LEN(progChanges[curTile]^)) THEN

						progOrder := progChanges[curTile][nextProgIdx].progOrder;
						rmax := progChanges[curTile][nextProgIdx].endRes - 1;
						cmax := progChanges[curTile][nextProgIdx].endComp - 1;
						lmax := progChanges[curTile][nextProgIdx].endLay - 1;
						rmin := progChanges[curTile][nextProgIdx].startRes;
						cmin := progChanges[curTile][nextProgIdx].startComp;
					ELSE
						progOrder := decSpec.cics[curTile].po;
						rmax := decSpec.GetMaxDecLevels(curTile);
						cmax :=  decSpec.imgInfo.ncomp - 1;
						lmax := decSpec.cics[curTile].nl - 1;
						rmin := 0;
						cmin := 0;
					END;

					(* Set the position boundaries (even if not needed) *)
					pktDec.GetMinIncStep(cmin, incX, incY);
					pktDec.GetMaxSotEot(cmin, xmin, xmax, ymin, ymax);
					DEC(xmax);
					DEC(ymax);
					(* Need to create new precinct counters *)
					CreatePrecCounter();

					INC(progStates[curTile].progNr);
			END ProgressionChange;
		*)

			PROCEDURE EndOfCodestream* () : BOOLEAN;
				BEGIN
					RETURN endOfCS;
			END EndOfCodestream;


			(*
				Advances to the end of the current tile-part, reads all packets from the stream
			*)
			PROCEDURE JumpToTilePartEnd () : LONGINT;
				VAR
					bytesSkipped, startPos : LONGINT;
					ok : BOOLEAN;
				BEGIN
					bytesSkipped := 0;
					ok := TRUE;

					WHILE TilePartAvailable() & ok DO
						startPos := s.Pos();

						(* Read the next packet *)
						ncblkInBuf := pktDec.DecodePacket(curComp, curRes, curLay, curPrec[curComp][curRes][curLay], cblkBuf^, cblkInfoBuf^);

						CASE progOrder OF
								PROG_LRCP:
									ok := AdvanceLayResComPos ();
							|	PROG_RLCP:
 										ok := AdvanceResLayComPos ();
							|	PROG_RPCL:
									ok := AdvanceResPosComLay ();
							|	PROG_PCRL:
									ok := AdvancePosComResLay ();
							|	PROG_CPRL:
									ok := AdvanceComPosResLay ();
							ELSE
								ok := FALSE;
						END;

						partRem := partRem - (s.Pos() - startPos);
						INC(bytesSkipped, s.Pos() - startPos);
					END;

					RETURN bytesSkipped;
			END JumpToTilePartEnd;

			(**
				Returns the decoder specification object.
				That object contains all information necessary to
				properly decode the compressed image data
			*)
			PROCEDURE GetDecoderSpecs* () : DecoderSpecs;
				BEGIN
					RETURN decSpec;
			END GetDecoderSpecs;

			PROCEDURE CreateSubbandInfos;
				VAR
					c, ndec, tx0, tx1, ty0, ty1, tcx0, tcx1, tcy0, tcy1, p, q, curIdx, reslevel, declevel, tmpW, tmpH : LONGINT;
					ppx, ppy, cblw, cblh : LONGINT;
					parentBand, llBand, hlBand, lhBand, hhBand : J2KU.SubbandInfo;
					cstyle : CodingStyle;
					imgInfo : ImageInfo;
				BEGIN
					imgInfo := decSpec.imgInfo;

					(* Compute the horizontal and vertical indices of the current tile in the reference grid *)
					p := curTile MOD imgInfo.nxt;
					q := curTile DIV imgInfo.nxt;

					(* Determine the actual upper left x-coordinate of the tile *)
					tx0 := imgInfo.xtos + p*imgInfo.xt;
					IF imgInfo.xos > tx0 THEN
						tx0 := imgInfo.xos;
					END;

					(* Determine the actual upper left y-coordinate of the tile *)
					ty0 := imgInfo.ytos + q*imgInfo.yt;
					IF imgInfo.yos > ty0 THEN
						ty0 := imgInfo.yos;
					END;

					(* Determine the actual lower right x-coordinate of the tile *)
					tx1 := imgInfo.xtos + (p+1)*imgInfo.xt;
					IF imgInfo.xsiz < tx1 THEN
						tx1 := imgInfo.xsiz;
					END;

					(* Determine the actual lower right y-coordinate of the tile *)
					ty1 := imgInfo.ytos + (q+1)*imgInfo.yt;
					IF imgInfo.ysiz < ty1 THEN
						ty1 := imgInfo.ysiz;
					END;

					FOR c := 0 TO imgInfo.ncomp - 1 DO

						(* Compute the tile coordinates in the component domain *)
						(* Determine the x-coordinate of the upper left hand sample of the tile-component *)
						tcx0 := (tx0 + imgInfo.comps[c].subsx - 1) DIV imgInfo.comps[c].subsx;

						(* Determine the y-coordinate of the upper left hand sample of the tile-component *)
						tcy0 := (ty0 + imgInfo.comps[c].subsy - 1) DIV imgInfo.comps[c].subsy;

						(* Determine the x-coordinate of the lower right hand sample of the tile-component *)
						tcx1 := (tx1 + imgInfo.comps[c].subsx - 1) DIV imgInfo.comps[c].subsx;

						(* Determine the y-coordinate of the lower right hand sample of the tile-component *)
						tcy1 := (ty1 + imgInfo.comps[c].subsy - 1) DIV imgInfo.comps[c].subsy;

						(* Get number of decomposition levels for the current component *)
						cstyle := decSpec.cstyle[curTile][c];

						ndec := cstyle.ndec;

						ppx := decSpec.GetPPX(curTile, c, ndec);
						ppy := decSpec.GetPPY(curTile, c, ndec);

						IF cstyle.cblw > ppx THEN
							cblw := ppx;
						ELSE
							cblw := cstyle.cblw;
						END;

						IF cstyle.cblh > ppy THEN
							cblh := ppy;
						ELSE
							cblh := cstyle.cblh;
						END;


						(* Values used for implicit 'ceil' operation after division (i.e. shifting) *)
						tmpW := LSH(SYSTEM.VAL(LONGINT, 1), cblw) - 1;
						tmpH := LSH(SYSTEM.VAL(LONGINT, 1), cblh) - 1;

						(* We have to allocate space for all subbands in each decomposition level *)
						NEW(subbInfos[curTile][c], 4 * ndec + 1);

						(* Init the top subband info which holds information on the original tile-component *)
						NEW(parentBand);
						parentBand.type := J2KU.SUB_LL;
						parentBand.index := 0;
						parentBand.ulcx := tcx0;
						parentBand.ulcy := tcy0;
						parentBand.width := tcx1 - tcx0;
						parentBand.height := tcy1 - tcy0;

						IF parentBand.width = 0 THEN
							parentBand.nblocksx := 0;
						ELSE
							(* NOTE: Implicit 'ceil' operation is applied to first term *)
							parentBand.nblocksx := LSH(tcx1 + tmpW, -cblw) - LSH(tcx0, -cblw);
						END;

						IF parentBand.height = 0 THEN
							parentBand.nblocksy := 0;
						ELSE
							(* NOTE: Implicit 'ceil' operation is applied to first term *)
							parentBand.nblocksy := LSH(tcy1 + tmpH, -cblh) - LSH(tcy0, -cblh);
						END;

						(* We always start from the origin in the subband decomposition domain *)
						parentBand.ulsx := 0;
						parentBand.ulsy := 0;
						(*
							The number of magnitude bits of any LL band shall be the
							number of magnitude bits of the LL band of the lowest resolution level.
							NOTE: This is not specified by the standard but is just a convention
							of this implementation. For the top LL band this is a quite nice
							convention since when there are no decomposition levels we at
							least have the right value set here
						*)
						parentBand.magbits := GetNumMagBits(curTile, c, 0, J2KU.SUB_LL);

						parentBand.component := c;
						parentBand.reslevel := ndec;
						parentBand.declevel := 0;
						subbInfos[curTile][c][0] := parentBand;

						(*
							Now that we have set the values for the top subband, we can go over the others in an
							iterative way
						*)
						curIdx := 1;
						declevel := 1;

						FOR reslevel := ndec TO 1 BY -1 DO

							IF cstyle.cblw > (ppx - 1) THEN
								cblw := ppx - 1;
							ELSE
								cblw := cstyle.cblw;
							END;

							IF cstyle.cblh > (ppy - 1) THEN
								cblh := ppy - 1;
							ELSE
								cblh := cstyle.cblh;
							END;

							(* Values used for implicit 'ceil' operation after division (i.e. shifting) *)
							tmpW := LSH(SYSTEM.VAL(LONGINT, 1), cblw) - 1;
							tmpH := LSH(SYSTEM.VAL(LONGINT, 1), cblh) - 1;

							(* The HL subband *)
							NEW(hlBand);
							hlBand.type := J2KU.SUB_HL;
							hlBand.index := 0;
							hlBand.ulcx := LSH(parentBand.ulcx, -1);
							hlBand.ulcy := LSH(parentBand.ulcy + 1, -1);
							hlBand.width := LSH(parentBand.ulcx + parentBand.width, -1) - hlBand.ulcx;
							hlBand.height := LSH(parentBand.ulcy + parentBand.height + 1, -1) - hlBand.ulcy;
							(* Set number of code-blocks for this subband *)
							IF hlBand.width = 0 THEN
								hlBand.nblocksx := 0;
							ELSE
								(* NOTE: Implicit 'ceil' operation is applied to first term *)
								hlBand.nblocksx := LSH(hlBand.ulcx+hlBand.width + tmpW, -cblw) - LSH(hlBand.ulcx, -cblw);
							END;

							IF hlBand.height = 0 THEN
								hlBand.nblocksy := 0;
							ELSE
								(* NOTE: Implicit 'ceil' operation is applied to first term *)
								hlBand.nblocksy := LSH(hlBand.ulcy+hlBand.height + tmpH, -cblh) - LSH(hlBand.ulcy, -cblh);
							END;

							hlBand.magbits := GetNumMagBits(curTile, c, reslevel, J2KU.SUB_HL);

							hlBand.component := c;
							hlBand.reslevel := reslevel;
							hlBand.declevel := declevel;
							subbInfos[curTile][c][curIdx] := hlBand;
							INC(curIdx);

							(* The LH subband *)
							NEW(lhBand);
							lhBand.type := J2KU.SUB_LH;
							lhBand.index := 1;
							lhBand.ulcx := LSH(parentBand.ulcx + 1, -1);
							lhBand.ulcy := LSH(parentBand.ulcy, -1);
							lhBand.width := LSH(parentBand.ulcx + parentBand.width + 1, -1) - lhBand.ulcx;
							lhBand.height := LSH(parentBand.ulcy + parentBand.height, -1) - lhBand.ulcy;
							(* Set number of code-blocks for this subband *)
							IF lhBand.width = 0 THEN
								lhBand.nblocksx := 0;
							ELSE
								(* NOTE: Implicit 'ceil' operation is applied to first term *)
								lhBand.nblocksx := LSH(lhBand.ulcx+lhBand.width + tmpW, -cblw) - LSH(lhBand.ulcx, -cblw);
							END;

							IF lhBand.height = 0 THEN
								lhBand.nblocksy := 0;
							ELSE
								(* NOTE: Implicit 'ceil' operation is applied to first term *)
								lhBand.nblocksy := LSH(lhBand.ulcy+lhBand.height + tmpH, -cblh) - LSH(lhBand.ulcy, -cblh);
							END;

							lhBand.magbits := GetNumMagBits(curTile, c, reslevel, J2KU.SUB_LH);

							lhBand.component := c;
							lhBand.reslevel := reslevel;
							lhBand.declevel := declevel;
							subbInfos[curTile][c][curIdx] := lhBand;
							INC(curIdx);

							(* The HH subband *)
							NEW(hhBand);
							hhBand.type := J2KU.SUB_HH;
							hhBand.index := 2;
							hhBand.ulcx := hlBand.ulcx;
							hhBand.ulcy := lhBand.ulcy;
							hhBand.width := hlBand.width;
							hhBand.height := lhBand.height;
							(* Set number of code-blocks for this subband *)
							hhBand.nblocksx := hlBand.nblocksx;
							hhBand.nblocksy := lhBand.nblocksy;

							hhBand.magbits := GetNumMagBits(curTile, c, reslevel, J2KU.SUB_HH);

							hhBand.component := c;
							hhBand.reslevel := reslevel;
							hhBand.declevel := declevel;
							subbInfos[curTile][c][curIdx] := hhBand;
							INC(curIdx);

							(* At last the LL subband for the NEXT LOWER(!) resolution level *)
							ppx := decSpec.GetPPX(curTile, c, reslevel - 1);
							ppy := decSpec.GetPPY(curTile, c, reslevel - 1);

							IF cstyle.cblw > ppx THEN
								cblw := ppx;
							ELSE
								cblw := cstyle.cblw;
							END;
							IF cstyle.cblh > ppy THEN
								cblh := ppy;
							ELSE
								cblh := cstyle.cblh;
							END;

							(* Values used for implicit 'ceil' operation after division (i.e. shifting) *)
							tmpW := LSH(SYSTEM.VAL(LONGINT, 1), cblw) - 1;
							tmpH := LSH(SYSTEM.VAL(LONGINT, 1), cblh) - 1;

							NEW(llBand);
							llBand.type := J2KU.SUB_LL;
							llBand.index := 0;
							llBand.ulcx := lhBand.ulcx;
							llBand.ulcy := hlBand.ulcy;
							llBand.width := lhBand.width;
							llBand.height := hlBand.height;
							(* Set number of code-blocks for this subband *)

							(* NOTE: Implicit 'ceil' operation is applied to first term *)
							IF llBand.width = 0 THEN
								llBand.nblocksx := 0;
							ELSE
								(* NOTE: Implicit 'ceil' operation is applied to first term *)
								llBand.nblocksx := LSH(llBand.ulcx+llBand.width + tmpW, -cblw) - LSH(llBand.ulcx, -cblw);
							END;

							IF llBand.height = 0 THEN
								llBand.nblocksy := 0;
							ELSE
								(* NOTE: Implicit 'ceil' operation is applied to first term *)
								llBand.nblocksy := LSH(llBand.ulcy+llBand.height + tmpH, -cblh) - LSH(llBand.ulcy, -cblh);
							END;

							(*
								The number of magnitude bits of any LL band shall be the
								number of magnitude bits of the LL band of the lowest resolution level.
								NOTE: This is not specified by the standard but is just a convention
								of this implementation.
							*)
							llBand.magbits := GetNumMagBits(curTile, c, 0, J2KU.SUB_LL);

							llBand.component := c;
							llBand.reslevel := reslevel - 1;
							llBand.declevel := declevel;
							subbInfos[curTile][c][curIdx] := llBand;
							INC(curIdx);

							(* Now set the coordinates in the subband decomposition domain *)
							llBand.ulsx := parentBand.ulsx;
							llBand.ulsy := parentBand.ulsy;
							hlBand.ulsx := parentBand.ulsx + llBand.width;
							hlBand.ulsy := parentBand.ulsy;
							lhBand.ulsx := parentBand.ulsx;
							lhBand.ulsy := parentBand.ulsy + llBand.height;
							hhBand.ulsx := hlBand.ulsx;
							hhBand.ulsy := lhBand.ulsy;

							parentBand := llBand;
							INC(declevel);
						END;
					END;
			END CreateSubbandInfos;

			(**
				Gets the number of magnitude bits for all samples in a specific subband.
			*)
			PROCEDURE GetNumMagBits (tile, comp, reslevel, subband : LONGINT) : LONGINT;
				VAR
					exp, idx : LONGINT;
					quant : Quantization;
				BEGIN
					quant := decSpec.quant[tile][comp];

					IF (quant.style = NOQUANT) OR (quant.style = QUANT_EXP) THEN
						IF reslevel = 0 THEN
							idx := 0;
						ELSE
							idx := 3 * (reslevel - 1) + 1 + J2KU.SubbandToSubbandIndex(subband);
						END;

						exp := quant.stepsiz[idx].exp;
					ELSIF quant.style = QUANT_DER THEN
						IF reslevel = 0 THEN
							exp := quant.stepsiz[0].exp;
						ELSE
							exp := quant.stepsiz[0].exp - (reslevel - 1);
						END;
					END;

					RETURN quant.nguardb + exp - 1;
			END GetNumMagBits;


			PROCEDURE CreatePrecCounter;
				VAR
					c, r, ndec, ncomp, nl : LONGINT;
					cstyle : CodingStyle;
				BEGIN

					ncomp := decSpec.imgInfo.ncomp;

					NEW(curPrec, ncomp);
					nl := decSpec.cics[curTile].nl;

					FOR c := 0 TO ncomp - 1 DO
						cstyle := decSpec.cstyle[curTile][c];

						ndec := cstyle.ndec;

						NEW(curPrec[c], ndec + 1);

						FOR r := 0 TO ndec DO
							NEW(curPrec[c][r], nl);
							(*Machine.Fill32(ADDRESSOF(curPrec[c][r][0]), nl*SIZEOF(LONGINT), 0);*)
						END;
					END;

			END CreatePrecCounter;

			(**
				Gets the subband information objects for a specific subband
			*)
			PROCEDURE GetSubbandInfo* (tile, comp, reslevel, subband : LONGINT) : J2KU.SubbandInfo;
				VAR
					ndec : LONGINT;
					subbOff : LONGINT;
				BEGIN
					ndec := decSpec.cstyle[tile][comp].ndec;

					IF subband = J2KU.SUB_LL THEN
						subbOff := 0;
					ELSE
						subbOff := 1;
					END;

					RETURN subbInfos[tile][comp][(ndec - reslevel)*4 + J2KU.SubbandToSubbandIndex(subband) + subbOff];
			END GetSubbandInfo;

			(*
				Reads the next 2 bytes in the stream, without advancing
			*)
			PROCEDURE Peek16 () : LONGINT;
				BEGIN

					IF ~buf8Valid THEN
						buf8 := ORD(s.Get());
						buf8Valid := TRUE;
					END;

					RETURN
						SYSTEM.VAL(LONGINT,
							SYSTEM.VAL(SET, LSH(buf8, 8))
							+ SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, s.Peek()))
						);

			END Peek16;

			PROCEDURE ReadByte (VAR byte : CHAR);
				BEGIN

					IF buf8Valid THEN
						byte := CHR(buf8);
						buf8Valid := FALSE;
					ELSE
						s.Char(byte);
					END;

			END ReadByte;

			PROCEDURE ReadBytes(VAR bytes : ARRAY OF CHAR; nbytes : LONGINT);
				VAR
					len, off : LONGINT;
				BEGIN

					IF buf8Valid THEN
						bytes[0] := CHR(buf8);
						buf8Valid := FALSE;
						off := 1;
						DEC(nbytes);
					ELSE
						off := 0;
					END;

					(* TODO: Maybe check that nbytes have been read *)
					s.Bytes(bytes, off, nbytes, len);
			END ReadBytes;

			(**
				Returns the index of the tile for which currently data is being read. Usually used to
				find out the tile index to which the last read tile-part header belongs to.
				RETURN:	The index of the current tile
			*)
			PROCEDURE CurrentTile* () : LONGINT;
				BEGIN
					RETURN curTile;
			END CurrentTile;

			(**
				Returns the index of the tile-part (of the current tile) for which currently data is being read. Usually used to
				find out the tile-part index to which the last read tile-part header belongs to.
				RETURN:	The index of the current tile-part
			*)
			PROCEDURE CurrentTilePart* () : LONGINT;
				BEGIN
					RETURN curPart;
			END CurrentTilePart;

			(**
				TRUE if the current tile-part has not been read entirely, FALSE otherwise.
			*)
			PROCEDURE TilePartAvailable* () : BOOLEAN;
				BEGIN
					IF ppmUsed THEN
						RETURN (ncblkInBuf > cblkBufPos) OR (partRem > 0) OR pktDec.PPHMainAvailable();
					ELSIF pktDec.PPHTileUsed() & (ntilePartsRead[curTile] >= ntilePartsAvailable[curTile]) THEN
						RETURN (ncblkInBuf > cblkBufPos) OR (partRem > 0) OR pktDec.PPHTileAvailable();
					ELSE
						RETURN (ncblkInBuf > cblkBufPos) OR (partRem > 0);
					END;
			END TilePartAvailable;

			(**
				TRUE if all tile-parts for a given tile have been read, i.e. there is no more data
				for that tile, FALSE otherwise
			*)
			PROCEDURE AllTilePartsRead* () : BOOLEAN;
				VAR
					progVol, ncomps, nlayers, c, r : LONGINT;
				BEGIN
					IF TilePartAvailable() THEN
						RETURN FALSE;
					ELSIF ntilePartsAvailable[curTile] # 0 THEN
						RETURN ntilePartsRead[curTile] >= ntilePartsAvailable[curTile];
					ELSE
						(*
							Compute the overall progression volume, subtract the
							progression volume still to come. If it's not 0, there
							are still more tile-parts
						*)
						progVol := 0;
						ncomps := decSpec.imgInfo.ncomp;
						nlayers := decSpec.cics[curTile].nl;

						FOR c := 0 TO decSpec.imgInfo.ncomp - 1 DO
							INC(progVol, nlayers*(decSpec.cstyle[curTile][c].ndec + 1));
						END;

						(* Now we subtract the progression volumes already read *)
						FOR c := 0 TO ncomps - 1  DO
							FOR r := 0 TO decSpec.cstyle[curTile][c].ndec DO
								DEC(progVol, lmin[c][r]);
							END;
						END;

						RETURN progVol <= 0;
					END;
			END AllTilePartsRead;

			(**
				Frees all resources not needed in rebuild mode
			*)
			PROCEDURE FreeNonRebuildResources*;
				BEGIN
					(* No rebuild allowed (and therefore this procedure shall not be called either) *)
					HALT(99);
			END FreeNonRebuildResources;

			(**
				Frees all resources
			*)
			PROCEDURE FreeResources*;
				BEGIN
					s := NIL;
					ntilePartsRead := NIL;
					ntilePartsAvailable := NIL;
					pktDec := NIL;
					cblkBuf := NIL;
					cblkInfoBuf := NIL;
					progChanges := NIL;
					progStates := NIL;
					curPrec := NIL;
			END FreeResources;


			PROCEDURE ReadSOTSegment() : BOOLEAN;
				VAR
					lsot, psot, sPos, ePos, comp, i : LONGINT;
					ncod, nqcd, npoc, nmax : LONGINT; (* Counter variables used for constraint checking *)
					ncoc, nqcc, nrgn : J2KU.LongIntArrayPtr;
					tileIdx, partIdx, nparts, ncomp, nt : LONGINT;
					ch : CHAR;
					ok : BOOLEAN;
					cstyle : CodingStyle;
					cics : CICodingStyle;
					quant : Quantization;
					roiShift : LONGINT;
					pptFirst, pptLast : DataListElement;
					pptUsed : BOOLEAN;
					changes : ProgChangeArrayPtr;
				BEGIN
				(*
					IF s.Available() < 10 THEN
						KernelLog.String("ERROR: SOT segment shorter than 10 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)
					ok := TRUE;

					(* Initialize local variables *)
					ncod := 0;
					nqcd := 0;
					npoc := 0;
					ncomp := decSpec.imgInfo.ncomp;
					NEW(ncoc, ncomp);
					NEW(nqcc, ncomp);
					NEW(nrgn, ncomp);

					Machine.Fill32(ADDRESSOF(ncoc[0]), ncomp*SIZEOF(LONGINT), 0);
					Machine.Fill32(ADDRESSOF(nqcc[0]), ncomp*SIZEOF(LONGINT), 0);
					Machine.Fill32(ADDRESSOF(nrgn[0]), ncomp*SIZEOF(LONGINT), 0);

					pptUsed := FALSE;
					pptFirst := NIL;
					pptLast := NIL;

					(* Start position of this SOT segment (before marker) *)
					sPos := s.Pos() - 2;

					lsot := s.Net16();
					tileIdx := s.Net16(); 	(* isot *)
					psot := s.Net32();			(* TODO: Problem occurs if psot >= 2^31 *)
					s.Char(ch);
					partIdx := ORD(ch);		(* tpsot *)
					s.Char(ch);
					nparts := ORD(ch);		(* tnsot *)

					IF (ntilePartsAvailable[tileIdx] = 0) & (nparts # 0) THEN
						ntilePartsAvailable[tileIdx] := nparts;
					END;

					(* Check segment length *)
					(*
						NOTE:	sPos + 2 is the position after the SOT marker
					*)
					IF (s.Pos() - (sPos + 2)) # lsot THEN
						(* The segment length signalled was not correct *)
						KernelLog.String("WARNING: Segment length signalled in SOT segment was wrong. ");
						KernelLog.String("Trying to read further anyway");
						KernelLog.Ln();
					END;

					curMarker := s.Net16();

					WHILE ok & (curMarker # SOD) DO

						CASE curMarker OF
							|	COD :
									ok := ReadCODSegment(cstyle, cics);

									decSpec.cics[tileIdx] := cics;

									FOR i := 0 TO ncomp - 1 DO
										IF ncoc[i] = 0 THEN
											decSpec.cstyle[tileIdx][i] := cstyle;
										END;
									END;

									INC(ncod);
							|	COC :
									ok := ReadCOCSegment(cstyle, comp);

									(* We need to add the check here, since 'comp' could be beyond of the valid range *)
									IF ok THEN
										decSpec.cstyle[tileIdx][comp] := cstyle;
										INC(ncoc[comp]);
									END;
							|	RGN :
									ok := ReadRGNSegment(roiShift, comp);

									(* We need to add the check here, since 'comp' could be beyond of the valid range *)
									IF ok THEN
										decSpec.roiShift[tileIdx][comp] := roiShift;
										INC(nrgn[comp]);
									END;
							|	QCD :
									ok := ReadQCDSegment(quant);

									FOR i := 0 TO ncomp - 1 DO
										IF nqcc[i] = 0 THEN
											decSpec.quant[tileIdx][i] := quant;
										END;
									END;

									INC(nqcd);
							|	QCC :
									ok := ReadQCCSegment(quant, comp);

									(* We need to add the check here, since 'comp' could be beyond of the valid range *)
									IF ok THEN
										decSpec.quant[tileIdx][comp] := quant;
										INC(nqcc[comp]);
									END;
							|	POC :
									ok := ReadPOCSegment(changes);
									(* Set the new end values for the current progression (= start values of new progression) *)
									IF progChanges = NIL THEN
										nt := decSpec.imgInfo.nt;
										NEW(progChanges, nt);
									END;

									progChanges[tileIdx] := changes;
									INC(npoc);
							|	PLT :
									ok := ReadPLTSegment();
							|	PPT :
									ok := ReadPPTSegment(pptFirst, pptLast);
									pptUsed := TRUE;
							|	COM :
									ok := ReadCOMSegment();
							ELSE
								KernelLog.String("Unexpected/Invalid marker found in tile-part header (0x");
								KernelLog.Hex(curMarker, 0);
								KernelLog.String(")");
								KernelLog.Ln();
								ok := FALSE;
						END;

						curMarker := s.Net16();
					END;

					IF partIdx = 0 THEN
						nmax := 1;
					ELSE
						nmax := 0;
					END;

					(* Constraint checks *)
					IF ncod > nmax THEN
						KernelLog.String("ERROR: Found ");
						KernelLog.Int(ncod, 0);
						KernelLog.String(" COD segments in header of tile-part ");
						KernelLog.Int(partIdx, 0);
						KernelLog.String(" of tile ");
						KernelLog.Int(tileIdx, 0);
						KernelLog.String(" (at most ");
						KernelLog.Int(nmax, 0);
						KernelLog.String(" allowed)");
						KernelLog.Ln();
						ok := FALSE;
					END;

					IF nqcd > nmax THEN
						KernelLog.String("ERROR: Found ");
						KernelLog.Int(nqcd, 0);
						KernelLog.String(" QCD segments in header of tile-part ");
						KernelLog.Int(partIdx, 0);
						KernelLog.String(" of tile ");
						KernelLog.Int(tileIdx, 0);
						KernelLog.String(" (at most ");
						KernelLog.Int(nmax, 0);
						KernelLog.String(" allowed)");
						KernelLog.Ln();
						ok := FALSE;
					END;

					IF npoc > 1 THEN
						KernelLog.String("ERROR: Found ");
						KernelLog.Int(npoc, 0);
						KernelLog.String(" POC segments in header of tile-part ");
						KernelLog.Int(partIdx, 0);
						KernelLog.String(" of tile ");
						KernelLog.Int(tileIdx, 0);
						KernelLog.String(" (at most 1 allowed)");
						KernelLog.Ln();
						ok := FALSE;
					END;

					(* Check cardinality constraints of component-specific segments *)
					FOR i := 0 TO ncomp - 1 DO
						IF ncoc[i] > nmax THEN
							KernelLog.String("ERROR: Found ");
							KernelLog.Int(ncoc[i], 0);
							KernelLog.String(" COC segments for component ");
							KernelLog.Int(i, 0);
							KernelLog.String(" in header of tile-part ");
							KernelLog.Int(partIdx, 0);
							KernelLog.String(" of tile ");
							KernelLog.Int(tileIdx, 0);
							KernelLog.String(" (at most ");
							KernelLog.Int(nmax, 0);
							KernelLog.String(" per component allowed )");
							KernelLog.Ln();
							ok := FALSE;
						END;

						IF nqcc[i] > nmax THEN
							KernelLog.String("ERROR: Found ");
							KernelLog.Int(nqcc[i], 0);
							KernelLog.String(" QCC segments for component ");
							KernelLog.Int(i, 0);
							KernelLog.String(" in header of tile-part ");
							KernelLog.Int(partIdx, 0);
							KernelLog.String(" of tile ");
							KernelLog.Int(tileIdx, 0);
							KernelLog.String(" (at most ");
							KernelLog.Int(nmax, 0);
							KernelLog.String(" per component allowed )");
							KernelLog.Ln();
							ok := FALSE;
						END;

						IF nrgn[i] > nmax THEN
							KernelLog.String("ERROR: Found ");
							KernelLog.Int(nrgn[i], 0);
							KernelLog.String(" RGN segments for component ");
							KernelLog.Int(i, 0);
							KernelLog.String(" in header of tile-part ");
							KernelLog.Int(partIdx, 0);
							KernelLog.String(" of tile ");
							KernelLog.Int(tileIdx, 0);
							KernelLog.String(" (at most ");
							KernelLog.Int(nmax, 0);
							KernelLog.String(" per component allowed )");
							KernelLog.Ln();
							ok := FALSE;
						END;
					END;

					IF pptUsed & ppmUsed THEN
						KernelLog.String("ERROR: Both PPM and PPT marker segments used in codestream");
						KernelLog.Ln();
						ok := FALSE;
					END;

					IF ok THEN

						(* End position of this SOT segment (just after the SOD marker has been read) *)
						ePos := s.Pos();

						IF psot = 0 THEN
							(*
								The standard states that if psot = 0 then it is supposed that
								all remaining data in the codestream (except the EOC marker)
								belongs to this tile-part
							*)
							partRem := s.Available() - 2; (* TODO: maybe s.Available() < stream length ? *)
						ELSE
							partRem := psot - (ePos - sPos);
						END;
						(* Set values *)
						SELF.curTile := tileIdx;
						SELF.curPart := partIdx;

						IF pptUsed THEN
							pktDec.SetPPHeadersTile (pptFirst, pptLast, curTile);
						END;
					END;

					RETURN ok;
			END ReadSOTSegment;


			PROCEDURE ReadSIZSegment(VAR imgInfo : ImageInfo) : BOOLEAN;
				VAR
					rsiz, lsiz, i, ssizInt, sPos, ePos : LONGINT;
					ssiz, ch : CHAR;
				BEGIN
				(*
					IF s.Available() < 36 THEN
						KernelLog.String("ERROR: SIZ segment shorter than 38 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)

					sPos := s.Pos();

					lsiz := s.Net16();
					rsiz := s.Net16();

					IF rsiz # 0000H THEN
						KernelLog.String("ERROR: Decoder currently only has capabilities specified in JPEG 2000 - Part 1");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					NEW(imgInfo);
					imgInfo.xsiz := s.Net32();	(* TODO: Problem occurs if xsiz >= 2^31 *)
					imgInfo.ysiz := s.Net32();
					imgInfo.xos := s.Net32();
					imgInfo.yos := s.Net32();
					imgInfo.xt := s.Net32();
					imgInfo.yt := s.Net32();
					imgInfo.xtos := s.Net32();
					imgInfo.ytos := s.Net32();
					imgInfo.ncomp := s.Net16();
					imgInfo.nxt := (imgInfo.xsiz - imgInfo.xtos + imgInfo.xt - 1) DIV imgInfo.xt;
					imgInfo.nyt := (imgInfo.ysiz - imgInfo.ytos + imgInfo.yt - 1) DIV imgInfo.yt;
					imgInfo.nt := imgInfo.nyt*imgInfo.nxt;

					(* Do some checks *)
					IF imgInfo.GetImgWidth(0) > MAX_IMG_WIDTH THEN
						KernelLog.String("ERROR: Image width too large");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					IF imgInfo.GetImgHeight(0) > MAX_IMG_HEIGHT THEN
						KernelLog.String("ERROR: Image height too large");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					IF imgInfo.GetNumTiles() > MAX_TILES THEN
						KernelLog.String("ERROR: Too many tiles");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					IF imgInfo.GetNumComponents() > MAX_COMPONENTS THEN
						KernelLog.String("ERROR: Too many image components");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					NEW(imgInfo.comps, imgInfo.ncomp);

					FOR i := 0 TO imgInfo.ncomp - 1 DO
						NEW(imgInfo.comps[i]);
						s.Char(ssiz);
						ssizInt := ORD(ssiz);
						IF (SYSTEM.VAL(SET, ssizInt) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT,  00000080H))) # {} THEN
							 imgInfo.comps[i].signed := TRUE;
						ELSE
							 imgInfo.comps[i].signed := FALSE;
						END;
						imgInfo.comps[i].depth := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ssizInt) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0000007FH))) + 1;
						s.Char(ch);
						imgInfo.comps[i].subsx := ORD(ch);
						s.Char(ch);
						imgInfo.comps[i].subsy := ORD(ch);
					END;

					ePos := s.Pos();

					(* Check segment length *)
					IF (ePos - sPos) # lsiz THEN
						(* The segment length signalled was not correct *)
						KernelLog.String("WARNING: Segment length signalled in SIZ segment was wrong. ");
						KernelLog.String("Trying to read further anyway");
						KernelLog.Ln();
					END;

					RETURN TRUE;
			END ReadSIZSegment;

			PROCEDURE ReadCODSegment (VAR cod : CodingStyle; VAR cics : CICodingStyle) : BOOLEAN;
				VAR
					lcod, nl, i, scodInt, cblsInt, precsizInt, sPos, ePos : LONGINT;
					scod, prog, mct, ndec, cblw, cblh, cbls, trans, precsiz: CHAR;
					tmpCod : CodingStyle;
					tmpCics : CICodingStyle;
				BEGIN
				(*
					IF s.Available() < 12 THEN
						KernelLog.String("ERROR: COD segment shorter than 12 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)

					sPos := s.Pos();

					lcod := s.Net16();
					s.Char(scod);
					(* --- SGcod --- *)
					s.Char(prog);
					nl := s.Net16();

					(* Check number of layers *)
					IF nl > MAX_LAYERS THEN
						KernelLog.String("ERROR: Too many layers");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					s.Char(mct);

					(* --- SPcod --- *)
					s.Char(ndec);
					s.Char(cblw);
					s.Char(cblh);
					s.Char(cbls);
					s.Char(trans);

					NEW(tmpCics);
					NEW(tmpCod);

					tmpCics.po := ORD(prog);
					tmpCics.nl := nl;

					IF tmpCics.po > 5 THEN
						KernelLog.String("ERROR: Invalid progression order:  0x");
						KernelLog.Hex(tmpCics.po, -1);
						KernelLog.Ln();
						RETURN FALSE;
					END;

					tmpCics.mct := ORD(mct);
					IF tmpCics.mct > 1 THEN
						KernelLog.String("ERROR: Invalid value for multiple component transformation: 0x");
						KernelLog.Hex(tmpCics.mct, -1);
						KernelLog.Ln();
						RETURN FALSE;
					END;

					scodInt := ORD(scod);
					tmpCod.maxps := ~ODD(scodInt);
					tmpCics.sop := ODD(LSH(scodInt, -1));
					tmpCics.eph := ODD(LSH(scodInt, -2));

					tmpCod.ndec := ORD(ndec);
					IF tmpCod.ndec > 32 THEN
						KernelLog.String("ERROR: Invalid number of decomposition levels");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					tmpCod.cblw := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ORD(cblw)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0000000FH))) + 2;
					tmpCod.cblh :=  SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ORD(cblh)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0000000FH))) + 2;
					IF ((tmpCod.cblw > 10) OR (tmpCod.cblh > 10)) OR (tmpCod.cblw + tmpCod.cblh > 12) THEN
						KernelLog.String("ERROR: Invalid code-block width or height exponent: width exp. = ");
						KernelLog.Int(tmpCod.cblw, 0);
						KernelLog.String(", heigth exp. = ");
						KernelLog.Int(tmpCod.cblh, 0);
						KernelLog.Ln();
						RETURN FALSE;
					END;

					cblsInt := ORD(cbls);
					tmpCod.selcb := ODD(cblsInt);
					tmpCod.rescp := ODD(LSH(cblsInt, -1));
					tmpCod.term := ODD(LSH(cblsInt, -2));
					tmpCod.vert := ODD(LSH(cblsInt, -3));

					tmpCod.pred := ODD(LSH(cblsInt, -4));
					tmpCod.segs := ODD(LSH(cblsInt, -5));

					tmpCod.trans := ORD(trans);

					IF ~tmpCod.maxps THEN
						NEW(tmpCod.precs, tmpCod.ndec + 1);
						(* precinct sizes are defined next in the codestream *)
						FOR i := 0 TO tmpCod.ndec DO
							s.Char(precsiz);
							precsizInt := ORD(precsiz);
							tmpCod.precs[i].ppx := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, precsizInt) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0000000FH)));
							tmpCod.precs[i].ppy := LSH(precsizInt, -4);
						END;
					END;

					cics := tmpCics;
					cod := tmpCod;

					ePos := s.Pos();

					(* Check segment length *)
					IF (ePos - sPos) # lcod THEN
						(* The segment length signalled was not correct *)
						KernelLog.String("WARNING: Segment length signalled in COD segment was wrong. ");
						KernelLog.String("Trying to read further anyway");
						KernelLog.Ln();
					END;

					RETURN TRUE;
			END ReadCODSegment;


			PROCEDURE ReadCOCSegment(VAR coc : CodingStyle; VAR comp : LONGINT) : BOOLEAN;
				VAR
					lcoc, ccoc, i, scocInt, cblsInt, precsizInt, sPos, ePos, ncomp : LONGINT;
					ccocByte, scoc, ndec, cblw, cblh, cbls, trans, precsiz: CHAR;
					tmpCoc : CodingStyle;
				BEGIN
				(*
					IF s.Available() < 9 THEN
						KernelLog.String("ERROR: COC segment shorter than 9 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)
					ncomp := decSpec.imgInfo.ncomp;
					sPos := s.Pos();

					lcoc := s.Net16();

					(* --- Ccoc --- *)
					IF ncomp < 257 THEN
						s.Char(ccocByte);
						ccoc := ORD(ccocByte);
					ELSE
						ccoc := s.Net16();
					END;

					IF ccoc >= ncomp THEN
						KernelLog.String("ERROR (CodeStreamReader.ReadCOCSegment) : Ccoc parameter out of valid range");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					(* --- Scoc --- *)
					s.Char(scoc);

					(* --- SPcoc --- *)
					s.Char(ndec);
					s.Char(cblw);
					s.Char(cblh);
					s.Char(cbls);
					s.Char(trans);

					NEW(tmpCoc);

					scocInt := ORD(scoc);
					IF scocInt = 0 THEN
						tmpCoc.maxps := TRUE;
					ELSIF scocInt = 1 THEN
						tmpCoc.maxps := FALSE;
					ELSE
						KernelLog.String(	"ERROR (CodestreamReader.ReadCOCSegment) : Invalid value for coding style parameter read (concerning precinct sizes)");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					tmpCoc.ndec := ORD(ndec);
					IF tmpCoc.ndec > 32 THEN
						KernelLog.String("ERROR (CodestreamReader.ReadCOCSegment) : Invalid number of decomposition levels");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					tmpCoc.cblw := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ORD(cblw)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0000000FH))) + 2;
					tmpCoc.cblh :=  SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ORD(cblh)) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0000000FH))) + 2;
					IF ((tmpCoc.cblw > 10) OR (tmpCoc.cblh > 10)) OR (tmpCoc.cblw + tmpCoc.cblh > 12) THEN
						KernelLog.String("ERROR (CodestreamReader.ReadCOCSegment) : Invalid code-block width or height exponent: width exp. = ");
						KernelLog.Int(tmpCoc.cblw, 0);
						KernelLog.String(", heigth exp. = ");
						KernelLog.Int(tmpCoc.cblh, 0);
						KernelLog.Ln();
						RETURN FALSE;
					END;

					cblsInt := ORD(cbls);
					tmpCoc.selcb := ODD(cblsInt);
					tmpCoc.rescp := ODD(LSH(cblsInt, -1));
					tmpCoc.term := ODD(LSH(cblsInt, -2));
					tmpCoc.vert := ODD(LSH(cblsInt, -3));
					tmpCoc.pred := ODD(LSH(cblsInt, -4));
					tmpCoc.segs := ODD(LSH(cblsInt, -5));

					tmpCoc.trans := ORD(trans);

					IF ~tmpCoc.maxps THEN
						NEW(tmpCoc.precs, tmpCoc.ndec + 1);
						(* precinct sizes are defined next in the codestream *)
						FOR i := 0 TO tmpCoc.ndec DO
							s.Char(precsiz);
							precsizInt := ORD(precsiz);
							tmpCoc.precs[i].ppx := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, precsizInt) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0000000FH)));
							tmpCoc.precs[i].ppy := LSH(precsizInt, -4);
						END;
					END;

					comp := ccoc;
					coc := tmpCoc;
					ePos := s.Pos();

					(* Check segment length *)
					IF (ePos - sPos) # lcoc THEN
						(* The segment length signalled was not correct *)
						KernelLog.String("WARNING: Segment length signalled in COC segment was wrong. ");
						KernelLog.String("Trying to read further anyway");
						KernelLog.Ln();
					END;

					RETURN TRUE;
			END ReadCOCSegment;


			PROCEDURE ReadRGNSegment(VAR roiShift, comp : LONGINT) : BOOLEAN;
				VAR
					lrgn, crgn, sPos, ePos, ncomp : LONGINT;
					crgnByte, srgn, sprgn : CHAR;
				BEGIN
				(*
					IF s.Available() < 5 THEN
						KernelLog.String("ERROR: RGN segment shorter than 4 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)

					ncomp := decSpec.imgInfo.ncomp;
					sPos := s.Pos();

					lrgn := s.Net16();

					IF ncomp < 257 THEN
						s.Char(crgnByte);
						crgn := ORD(crgnByte);
					ELSE
						crgn := s.Net16();
					END;

					IF crgn >= ncomp THEN
						KernelLog.String("ERROR (CodeStreamReader.ReadRGNSegment) : Crgn parameter out of valid range");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					s.Char(srgn);

					IF ORD(srgn) # 0 THEN
						KernelLog.String("ERROR (CodestreamReader.ReadRGNSegment): Invalid ROI style");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					s.Char(sprgn);

					roiShift := ORD(sprgn);
					comp := crgn;

					ePos := s.Pos();

					(* Check segment length *)
					IF (ePos - sPos) # lrgn THEN
						(* The segment length signalled was not correct *)
						KernelLog.String("WARNING: Segment length signalled in RGN segment was wrong. ");
						KernelLog.String("Trying to read further anyway");
						KernelLog.Ln();
					END;


					RETURN TRUE;
			END ReadRGNSegment;


			PROCEDURE ReadQCDSegment(VAR quant : Quantization) : BOOLEAN;
				VAR
					lqcd, ssize, i, sqcdInt, sPos, ePos : LONGINT;
					sqcd, ch : CHAR;
					tmp : Quantization;
				BEGIN
				(*
					IF s.Available() < 4 THEN
						KernelLog.String("ERROR: QCD segment shorter than 4 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)

					sPos := s.Pos();

					lqcd := s.Net16();
					s.Char(sqcd);
					sqcdInt := ORD(sqcd);

					NEW(tmp);
					tmp.style := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, sqcdInt) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0000001FH)));
					tmp.nguardb := LSH(sqcdInt, -5);

					CASE tmp.style OF
							NOQUANT :
								(* We just have an exponent, no mantissa *)
								tmp.nstepsiz := lqcd-3;
								NEW(tmp.stepsiz, tmp.nstepsiz);
								FOR i := 0 TO tmp.nstepsiz - 1 DO
									NEW(tmp.stepsiz[i]);
									tmp.stepsiz[i].mant := 0;
									s.Char(ch);
									tmp.stepsiz[i].exp := LSH(ORD(ch), -3);
								END;
						|	 QUANT_DER :
								(* Only the values for the NL-LL subband are signalled *)
								tmp.nstepsiz := 1;
								NEW(tmp.stepsiz, 1);
								NEW(tmp.stepsiz[0]);
								ssize := s.Net16();
								tmp.stepsiz[0].mant := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ssize) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 000007FFH)));
								tmp.stepsiz[0].exp := LSH(ssize, -11);
						|	QUANT_EXP :
								(* There are as many step sizes signalled as there ae subbands *)
								tmp.nstepsiz := (lqcd-3) DIV 2;
								NEW(tmp.stepsiz, tmp.nstepsiz);
								FOR i := 0 TO tmp.nstepsiz - 1 DO
									NEW(tmp.stepsiz[i]);
									ssize := s.Net16();
									tmp.stepsiz[i].mant := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ssize) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 000007FFH)));
									tmp.stepsiz[i].exp := LSH(ssize, -11);
								END;
						ELSE
							KernelLog.String("ERROR: Invalid quantization style in QCD segment : 0x");
							KernelLog.Hex(tmp.style, -1);
							KernelLog.Ln();
							RETURN FALSE;
					END;

					quant := tmp;

					ePos := s.Pos();

					(* Check segment length *)
					IF (ePos - sPos) # lqcd THEN
						(* The segment length signalled was not correct *)
						KernelLog.String("WARNING: Segment length signalled in QCD segment was wrong. ");
						KernelLog.String("Trying to read further anyway");
						KernelLog.Ln();
					END;

					RETURN TRUE;
			END ReadQCDSegment;

			PROCEDURE ReadQCCSegment(VAR quant : Quantization; VAR comp : LONGINT) : BOOLEAN;
				VAR
					lqcc, ssize, i, sqccInt, cqcc, cqccLen, sPos, ePos, ncomp : LONGINT;
					sqcc, cqccByte, ch : CHAR;
					tmp : Quantization;
				BEGIN
				(*
					IF s.Available() < 5 THEN
						KernelLog.String("ERROR: QCC segment shorter than 5 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)
					ncomp := decSpec.imgInfo.ncomp;
					sPos := s.Pos();

					lqcc := s.Net16();

					(* --- Cqcc --- *)
					IF decSpec.imgInfo.ncomp < 257 THEN
						s.Char(cqccByte);
						cqcc := ORD(cqccByte);
						cqccLen := 1;
					ELSE
						cqcc := s.Net16();
						cqccLen := 2;
					END;

					IF cqcc >= ncomp THEN
						KernelLog.String("ERROR (CodeStreamReader.ReadQCCSegment) : Cqcc parameter out of valid range");
						KernelLog.Ln();
						RETURN FALSE;
					END;

					s.Char(sqcc);
					sqccInt := ORD(sqcc);

					NEW(tmp);
					tmp.style := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, sqccInt) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 0000001FH)));
					tmp.nguardb := LSH(sqccInt, -5);

					CASE tmp.style OF
							NOQUANT :
								(* We just have an exponent, no mantissa *)
								tmp.nstepsiz := lqcc - (3 + cqccLen);
								NEW(tmp.stepsiz, tmp.nstepsiz);
								FOR i := 0 TO tmp.nstepsiz - 1 DO
									NEW(tmp.stepsiz[i]);
									tmp.stepsiz[i].mant := 0;
									s.Char(ch);
									tmp.stepsiz[i].exp := LSH(ORD(ch), -3);
								END;
						|	 QUANT_DER :
								(* Only the values for the NL-LL subband are signalled *)
								tmp.nstepsiz := 1;
								NEW(tmp.stepsiz, 1);
								NEW(tmp.stepsiz[0]);
								ssize := s.Net16();
								tmp.stepsiz[0].mant := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ssize) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 000007FFH)));
								tmp.stepsiz[0].exp := LSH(ssize, -11);
						|	QUANT_EXP :
								(* There are as many step sizes signalled as there ae subbands *)
								tmp.nstepsiz := (lqcc - (3 + cqccLen)) DIV 2;
								NEW(tmp.stepsiz, tmp.nstepsiz);
								FOR i := 0 TO tmp.nstepsiz - 1 DO
									NEW(tmp.stepsiz[i]);
									ssize := s.Net16();
									tmp.stepsiz[i].mant := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ssize) * SYSTEM.VAL(SET, SYSTEM.VAL(LONGINT, 000007FFH)));
									tmp.stepsiz[i].exp := LSH(ssize, -11);
								END;
						ELSE
							KernelLog.String("ERROR: Invalid quantization style in QCC segment : 0x");
							KernelLog.Hex(tmp.style, -1);
							KernelLog.Ln();
							RETURN FALSE;
					END;

					comp := cqcc;
					quant := tmp;

					ePos := s.Pos();

					(* Check segment length *)
					IF (ePos - sPos) # lqcc THEN
						(* The segment length signalled was not correct *)
						KernelLog.String("WARNING: Segment length signalled in QCC segment was wrong. ");
						KernelLog.String("Trying to read further anyway");
						KernelLog.Ln();
					END;

					RETURN TRUE;
			END ReadQCCSegment;

			PROCEDURE ReadPOCSegment(VAR changes : 	ProgChangeArrayPtr) : BOOLEAN;
				VAR
					nchanges, lpoc, i, sPos, ePos : LONGINT;
					rspoc, repoc, cspocByte, cepocByte, ppoc : CHAR;
					twoBytes : BOOLEAN;
				BEGIN
				(*
					IF s.Available() < 2 THEN
						KernelLog.String("ERROR: POC segment shorter than 2 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)
					sPos := s.Pos();

					lpoc := s.Net16();

					IF decSpec.imgInfo.ncomp < 257 THEN
						nchanges := (lpoc - 2) DIV 7;
						twoBytes := FALSE;
					ELSE
						nchanges := (lpoc - 2) DIV 9;
						twoBytes := TRUE;
					END;

					NEW(changes, nchanges);

					FOR i := 0 TO nchanges - 1 DO

						(* --- RSpoc i --- *)
						s.Char(rspoc);
						changes[i].startRes := ORD(rspoc);

						(* --- CSpoc i --- *)
						IF twoBytes THEN
							changes[i].startComp := s.Net16();
						ELSE
							s.Char(cspocByte);
							changes[i].startComp := ORD(cspocByte);
						END;

						(* --- LYEpoc i --- *)
						changes[i].endLay := s.Net16();

						(* --- REpoc i --- *)
						s.Char(repoc);
						changes[i].endRes := ORD(repoc);

						(* --- CEpoc i --- *)
						IF twoBytes THEN
							changes[i].endComp := s.Net16();
						ELSE
							s.Char(cepocByte);
							changes[i].endComp := ORD(cepocByte);
						END;

						(* --- Ppoc i --- *)
						s.Char(ppoc);
						changes[i].progOrder := ORD(ppoc);

					END;

					ePos := s.Pos();

					(* Check segment length *)
					IF (ePos - sPos) # lpoc THEN
						(* The segment length signalled was not correct *)
						KernelLog.String("WARNING: Segment length signalled in POC segment was wrong. ");
						KernelLog.String("Trying to read further anyway");
						KernelLog.Ln();
					END;

					RETURN TRUE;
			END ReadPOCSegment;

			(* NOTE: We just skip this segment *)
			PROCEDURE ReadTLMSegment() : BOOLEAN;
				VAR
					ltlm : LONGINT;
				BEGIN

				(*
					IF s.Available() < 4 THEN
						KernelLog.String("ERROR: TLM segment shorter than 4 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)

					ltlm := s.Net16();

					(* Skip the segment *)
					s.SkipBytes(ltlm - 2);

					KernelLog.String("NOTICE: Found a TLM segment -> skipping it");
					KernelLog.Ln();
					RETURN TRUE;
			END ReadTLMSegment;

			(* NOTE: We just skip this segment *)
			PROCEDURE ReadPLMSegment() : BOOLEAN;
				VAR
					lplm : LONGINT;
				BEGIN

				(*
					IF s.Available() < 3 THEN
						KernelLog.String("ERROR: PLM segment shorter than 3 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)

					lplm := s.Net16();

					(* Skip the segment *)
					s.SkipBytes(lplm - 2);

					KernelLog.String("NOTICE: Found a PLM segment -> skipping it");
					KernelLog.Ln();
					RETURN TRUE;
			END ReadPLMSegment;

			(* NOTE: We just skip this segment *)
			PROCEDURE ReadPLTSegment() : BOOLEAN;
				VAR
					lplt : LONGINT;
				BEGIN

				(*
					IF s.Available() < 3 THEN
						KernelLog.String("ERROR: PLT segment shorter than 3 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)

					lplt := s.Net16();

					(* Skip the segment *)
					s.SkipBytes(lplt - 2);

					KernelLog.String("NOTICE: Found a PLT segment -> skipping it");
					KernelLog.Ln();
					RETURN TRUE;
			END ReadPLTSegment;

			PROCEDURE ReadPPMSegment(VAR first, last : DataListElement; VAR nppmLeft, nppmRead : LONGINT) : BOOLEAN;
				VAR
				 	lppm, len, actLen, sPos, ePos, bytesLeft : LONGINT;
				 	dummy, curElem, newElem : DataListElement;
				 	zppm : CHAR;
				BEGIN

				(*
					IF s.Available() < 3 THEN
						KernelLog.String("ERROR: PPM segment shorter than 3 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)

					sPos := s.Pos();

					lppm := s.Net16();
					s.Char(zppm);

					IF first = NIL THEN
						NEW(dummy);
						dummy.next := NIL;
						curElem := dummy;
					ELSE
						curElem := last;
					END;

					bytesLeft := lppm - 3;

					WHILE bytesLeft > 0 DO
						(* We have to check wether all packet headers for the last tile-part have been read in the preceding PPM segment *)
						IF nppmLeft <= 0 THEN
							(* The next 4 bytes contain information on how many bytes are used to represent all packet headers of the next tile-part *)
							nppmLeft := s.Net32();
							NEW(newElem);
							NEW(newElem.data, nppmLeft);
							newElem.next := NIL;
							curElem.next := newElem;
							curElem := newElem;
							nppmRead := 0;
							DEC(bytesLeft, 4);
						END;

						IF bytesLeft < nppmLeft THEN
							len := bytesLeft;
						ELSE
							len := nppmLeft;
						END;

						s.Bytes(curElem.data^, nppmRead, len, actLen);

						INC(nppmRead, actLen);
						DEC(nppmLeft, actLen);
						DEC(bytesLeft, actLen);
					END;

					IF first = NIL THEN
						first := dummy.next;
					END;

					last := curElem;

					ePos := s.Pos();

					(* Check segment length *)
					IF (ePos - sPos) # lppm THEN
						(* The segment length signalled was not correct *)
						KernelLog.String("WARNING: Segment length signalled in PPM segment was wrong. ");
						KernelLog.String("Trying to read further anyway");
						KernelLog.Ln();
					END;

					RETURN TRUE;
			END ReadPPMSegment;

			PROCEDURE ReadPPTSegment(VAR first, last : DataListElement) : BOOLEAN;
				VAR
				 	lppt, actLen, sPos, ePos, bytesLeft : LONGINT;
				 	zppt : CHAR;
				 	newElem : DataListElement;
				BEGIN

				(*
					IF s.Available() < 3 THEN
						KernelLog.String("ERROR: PPT segment shorter than 3 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)

					sPos := s.Pos();

					lppt := s.Net16();
					s.Char(zppt);

					IF first = NIL THEN
						NEW(first);
						last := first;
						newElem := first;
					ELSE
						NEW(last.next);
						last := last.next;
						newElem := last;
					END;

					bytesLeft := lppt - 3;

					NEW(newElem.data, bytesLeft);
					newElem.next := NIL;

					WHILE bytesLeft > 0 DO
						s.Bytes(newElem.data^, 0, bytesLeft, actLen);
						DEC(bytesLeft, actLen);
					END;

					ePos := s.Pos();

					(* Check segment length *)
					IF (ePos - sPos) # lppt THEN
						(* The segment length signalled was not correct *)
						KernelLog.String("WARNING: Segment length signalled in PPT segment was wrong. ");
						KernelLog.String("Trying to read further anyway");
						KernelLog.Ln();
					END;

					RETURN TRUE;
			END ReadPPTSegment;

			(* NOTE: We just skip this segment *)
			PROCEDURE ReadCRGSegment() : BOOLEAN;
				VAR
				 	lcrg : LONGINT;
				BEGIN

				(*
					IF s.Available() < 2 THEN
						KernelLog.String("ERROR: CRG segment shorter than 2 bytes");
						KernelLog.Ln();
						RETURN FALSE;
					END;
				*)

					lcrg := s.Net16();

					(* Skip the segment *)
					s.SkipBytes(lcrg - 2);

					KernelLog.String("NOTICE: Found a CRG segment -> skipping it");
					KernelLog.Ln();
					RETURN TRUE;
			END ReadCRGSegment;

			PROCEDURE ReadCOMSegment () : BOOLEAN;
				VAR
					lcom, rcom, i : LONGINT;
					com : J2KU.ByteArrayPtr;
				BEGIN

					lcom := s.Net16();
					rcom := s.Net16();
					NEW(com, lcom - 3);
					FOR i := 0 TO lcom - 5 DO
						s.Char(com[i]);
					END;

					com[LEN(com)-1] := 0X;

					IF printCOM THEN
						KernelLog.String("JPEG2000 codestream comment [");
						KernelLog.Ln();
						KernelLog.String("   ");
						KernelLog.String(com^);
						KernelLog.Ln();
						KernelLog.String("]");
						KernelLog.Ln();
					END;

					RETURN TRUE;
			END ReadCOMSegment;

		END CodestreamReader;

		(**
			A buffered version of the codestream readers.
			Buffered in this context means, that we buffer layers for the same
			code-block and only deliver the code-block, if the requested
			number of layers has been obtained, or there are no more layers
			for that code-block.
		*)
		BufferedCodestreamReader* = OBJECT(CodestreamReader)
			VAR
				(*
					Pointer to buffered coded code-blocks off the image:
					1st dim: tile index
					2nd dim: component
					3rd dim: resolution level
					4th dim: subband (NOTE: 0 = LL at lowest resolution level; 0 = HL, 1 = LH, 2 = HH otherwise)
					5th dim: code-block index in the subband (in raster order)
				*)
				bufferedBlocks : POINTER TO ARRAY OF ARRAY OF POINTER TO ARRAY OF POINTER TO ARRAY OF POINTER TO ARRAY OF J2KU.CodedCblk;
				reBuildMode : BOOLEAN;	(* TRUE, if we are in rebuild mode *)
				curSubbIdx, curSubbCblk : LONGINT;
				maxSubbIdx, maxSubbCblk : LONGINT;
				getAllLayers : BOOLEAN;		(*	TRUE, if for a tile all layers shall be delivered (which is much easier
													than having to determine which data is contained in the requested
													layer range, and which not)
												*)

			PROCEDURE &InitNew* (crOpt : J2KU.CodestreamReaderOptions;
									stream : Streams.Reader);
				BEGIN
					ReInit(crOpt, stream);
			END InitNew;

			PROCEDURE ReInit* (crOpt : J2KU.CodestreamReaderOptions;
								stream : Streams.Reader);
				BEGIN
					ReInit^(crOpt, stream);

					IF ~initError THEN
						NEW(bufferedBlocks, decSpec.imgInfo.nt, decSpec.imgInfo.ncomp);

						reBuildMode := FALSE;
					END;
			END ReInit;


			PROCEDURE InitTile () : BOOLEAN;
				VAR
					c, r, nblocks, subband, nband, ndec : LONGINT;
					cstyle : CodingStyle;
					subbInfo : J2KU.SubbandInfo;
				BEGIN
					(* Super call *)
					IF ~InitTile^() THEN
						RETURN FALSE;
					END;

					IF curPart = 0 THEN
						(* Loop on components *)
						FOR c := 0 TO decSpec.imgInfo.ncomp - 1 DO
							cstyle := decSpec.cstyle[curTile][c];

							(* Instantiate new arrays for each tile-component *)
							NEW(bufferedBlocks[curTile][c], cstyle.ndec + 1);

							(* Loop on resolution levels *)
							FOR r := 0 TO cstyle.ndec DO

								IF r = 0 THEN
									nband := 1;
								ELSE
									nband := 3;
								END;

								NEW(bufferedBlocks[curTile][c][r], nband);

								FOR subband := 0 TO nband - 1 DO
									subbInfo := GetSubbandInfo(curTile, c, r, J2KU.SubbandIndexToSubband(r, subband));

									nblocks := subbInfo.nblocksx * subbInfo.nblocksy;

									IF nblocks > 0 THEN
										NEW(bufferedBlocks[curTile][c][r][subband], nblocks);

										Machine.Fill32(ADDRESSOF(bufferedBlocks[curTile][c][r][subband][0]), nblocks*SIZEOF(J2KU.CodedCblk), 0);
									END;
								END;
							END;
						END;
					ELSIF reBuildMode THEN
						(* Set component range *)
						curComp := 0;
						cmax := decSpec.imgInfo.GetNumComponents() - 1;

						(* Set minimum/maximum resolution levels for the new component *)
						ndec := decSpec.GetNumDecLevels(curTile, 0);

						(*
							If the start decomposition level is greater than the number of
							decomposition levels for the current tile-component, we start from
							the minimum resolution level available.
						*)
						IF startDecLvl > ndec THEN
							curRes := 0;
						ELSE
							(* The start decomposition level is not the maxim decomposition level *)
							curRes := ndec - startDecLvl;
						END;

						(*
							Need to check wether the current tile-component has data for
							the decomposition level range.
						*)
						IF endDecLvl > ndec THEN
							(*
								The minimum decomposition level is greater than the number
								of decomposition levels for this tile-component -> don't deliver
								any data
							*)
							rmax := -1;
						ELSE
							rmax := ndec - endDecLvl;
						END;

						curSubbIdx := 0;
						curSubbCblk := 0;
					END;

					(* Need to see if we can get all the layers for this tile, or if we have to return a specific layer range *)
					IF (startLayer = 0) & (endLayer >= decSpec.cics[curTile].nl - 1) THEN
						getAllLayers := TRUE;
					ELSE
						getAllLayers := FALSE;
					END;

					RETURN TRUE;
			END InitTile;


			(**
				Goes into the rebuil mode. This is used to reconstruct a previously decoded image
				at a lower/higher resolution level or in better/worse quality.

				NOTE: The rebuild mode may NOT be supported by some components in the decoding chain.

				IMPORTANT:	This procedure MUST NOT be called before the image has been
								reconstructed once.
			*)
			PROCEDURE SetReBuildMode*;
				BEGIN
					reBuildMode := TRUE;

					curTile := -1;
					curPart := REBUILD_TILEPART;
			END SetReBuildMode;

			(* Aadds a coded code-block to the output buffer *)
			PROCEDURE AddBlock (VAR cblock : J2KU.CodedCblk; cblockInfo : J2KU.CblkInfo);
				VAR
					i, j : LONGINT;
					tmpSegLen : J2KU.LongIntArrayPtr;
					totSegLen, firstSegLen, lastSegLen : LONGINT;
					dataEndPos : LONGINT;
					nseg : LONGINT;
					locComp, locRes, locSubb, locSubbCblk : LONGINT;
				BEGIN
					(* Buffer variables locally, so the compiler won't get in trouble ;-) *)
					locComp := cblockInfo.subbinfo.component;
					locRes := cblockInfo.subbinfo.reslevel;
					locSubb := cblockInfo.subbinfo.index;
					locSubbCblk := cblockInfo.index;

					cblock.data := bufferedBlocks[curTile][locComp][locRes][locSubb][locSubbCblk].data;
					nseg := bufferedBlocks[curTile][locComp][locRes][locSubb][locSubbCblk].nseg;
					tmpSegLen := bufferedBlocks[curTile][locComp][locRes][locSubb][locSubbCblk].segLen;

					IF startLayer = 0 THEN
						(* Adjust data offset and length *)
						cblock.dataOffset := 0;
						cblock.dataLen := cblockInfo.datalenlyr[endLayer];
						(* Adjust number of coding passes *)
						cblock.cpasses := cblockInfo.cpasseslyr[endLayer];
						cblockInfo.curbp := J2KU.LONGINT_BITS - 2 - cblockInfo.zerobp;
					ELSE
						(* Adjust data offset and length *)
						cblock.dataOffset := cblockInfo.datalenlyr[startLayer - 1];
						cblock.dataLen := cblockInfo.datalenlyr[endLayer] - cblockInfo.datalenlyr[startLayer - 1];
						(* Adjust number of coding passes *)
						cblock.cpasses := cblockInfo.cpasseslyr[endLayer] - cblockInfo.cpasseslyr[startLayer - 1];
						cblockInfo.curbp :=	J2KU.LONGINT_BITS - 2 - cblockInfo.zerobp
											- ((cblockInfo.cpasseslyr[startLayer - 1] + 2) DIV 3);
					END;


					(* Now we need to adjust the segment lengths *)
					IF  tmpSegLen # NIL THEN
						(*
							We need to get the first and last terminated segments for which this coded code-block
							contains data. Then we need to find out, how much of the segments actually
							belongs to the layer range of this coded code-block (since start or end
							segments of a layer may be unterminated)
						*)
						i := -1;
						totSegLen := 0;

						REPEAT
							INC(i);
							INC(totSegLen, tmpSegLen[i]);
						UNTIL totSegLen > cblock.dataOffset;
						(* i now contains the index of the first terminated segment to which the start layer contributes data *)

						(* Compute length of first segment for this coded code-block *)
						firstSegLen := totSegLen - cblock.dataOffset;

						(* Now find the end index *)
						j := i;
						dataEndPos := cblock.dataOffset + cblock.dataLen;
						WHILE (totSegLen <= dataEndPos) & (j < LEN(tmpSegLen^) - 1) DO
							INC(j);
							INC(totSegLen, tmpSegLen[j]);
						END;
						(*
							NOTE:
							j now contains either the index of the last terminated segment to which the end layer contributes,
							or one segment beyond that (that's the case if the last terminated segment does not contain
							any data after the requested end layer). The latter case does not cause any problems, because the
							number of coding passes ensures that we don't decode the extra segments that belong to layers
							after the requested end layer.
						*)

						(*
							We only have to allocate a segment length array if there is more than 1 segment
						*)
						IF j > i THEN
							cblock.nseg := j-i+1;
							(* Compute length of last segment for this coded code-block *)
							lastSegLen := tmpSegLen[j] - (totSegLen - dataEndPos);

							NEW(cblock.segLen, cblock.nseg);
							cblock.segLen[0] := firstSegLen;
							cblock.segLen[cblock.nseg - 1] := lastSegLen;

							(* If there is anything in between the two segments -> move it *)
							IF cblock.nseg > 2 THEN
								SYSTEM.MOVE(ADDRESSOF(tmpSegLen[i+1]), ADDRESSOF(cblock.segLen[1]), (cblock.nseg-2)*SIZEOF(LONGINT));
							END;
						ELSE
							cblock.nseg := 1;
							cblock.segLen := NIL;
						END;
					ELSE
						cblock.nseg := 1;
						cblock.segLen := NIL;
					END;

			END AddBlock;

			(*
				Updates a specific buffered coded code-block (i.e. when data of higher layers has to be added)
			*)
			PROCEDURE UpdateBufferedBlock (VAR cblk : J2KU.CodedCblk; cblkInfo : J2KU.CblkInfo);
				VAR
					newDataLen, newSegs : LONGINT;
					newSize, newSegSize : LONGINT;
					tmpBlock : J2KU.CodedCblk;
					tmpData : J2KU.ByteArrayPtr;
					tmpSegLen : J2KU.LongIntArrayPtr;
					layLeft: LONGINT;
					comp, reslevel, subbIdx, cblkSubbIdx : LONGINT;
				BEGIN
					newDataLen := cblk.dataLen;
					newSegs := cblk.nseg;
					(* Buffer index variables locally, as not to make the compiler unhappy ;-) *)
					comp := cblkInfo.subbinfo.component;
					reslevel := cblkInfo.subbinfo.reslevel;
					subbIdx := cblkInfo.subbinfo.index;
					cblkSubbIdx := cblkInfo.index;

					IF (maxEndLayer < decSpec.cics[curTile].nl - 1) THEN
						layLeft := (maxEndLayer - maxStartLayer) - curLay;
					ELSE
						layLeft := (decSpec.cics[curTile].nl-1 - maxStartLayer) - curLay;
					END;

					IF newDataLen > 0 THEN
						(* Get the corresponding code-block from the internal buffer *)
						tmpBlock := bufferedBlocks[curTile][comp][reslevel][subbIdx][cblkSubbIdx];

						(* If it's the first layer for the code-block we need to allocate space for the data *)
						IF tmpBlock.dataLen = 0 THEN
							(*
								NOTE:
								The specification states that if the code-block truncation points
								associated with each layer are optimal in the rate-distortion sense
								(that's what we assume) then on average each layer contains contributions
								from approximately half the code-blocks. So the assumption now is that
								every code-block is contained in about half of all (remaining) layers (with about the
								same amount of data. This maybe is a naive assumption since it is possible that some
								code-blocks contribute to almost all layers and others to almost none and the data length
								may vary largely. But that's still better than always having to allocate space for data of a
								new layer (isn't it?).
							*)
							newSize := newDataLen + LSH(newDataLen * layLeft, -1);
							NEW(tmpBlock.data, newSize);
						(* See wether the data array of the buffered code-block is large enough or not *)
						ELSIF LEN(tmpBlock.data^) < (newDataLen + tmpBlock.dataLen + tmpBlock.dataOffset) THEN
							tmpData := tmpBlock.data;
							(* NOTE: See reasoning above *)
							newSize := newDataLen + tmpBlock.dataLen + LSH(newDataLen * layLeft, -1);
							NEW(tmpBlock.data, newSize);
							(* Move the existing data to the new array *)
							SYSTEM.MOVE(ADDRESSOF(tmpData[0]), ADDRESSOF(tmpBlock.data[0]), tmpBlock.dataLen);
						END;

						(* If we have entropy bypass coding or termination, we store all segment lenghts *)
						IF decSpec.cstyle[curTile][comp].selcb OR decSpec.cstyle[curTile][comp].term THEN
							(* Now do a similar thing for the segment lengths array *)
							IF tmpBlock.segLen = NIL THEN
								newSegSize := newSegs + LSH(newSegs * layLeft, -1);
								NEW(tmpBlock.segLen, newSegSize);

								Machine.Fill32(ADDRESSOF(tmpBlock.segLen[0]), newSegSize*SIZEOF(LONGINT), 0);
							ELSIF LEN(tmpBlock.segLen^) < (newSegs + tmpBlock.nseg) THEN
								tmpSegLen := tmpBlock.segLen;
								(* NOTE: See reasoning above *)
									newSegSize := newSegs + tmpBlock.nseg + LSH(newSegs * layLeft, -1);
								NEW(tmpBlock.segLen, newSegSize);

								(* Move the existing segment lengths to the new array *)
								SYSTEM.MOVE(ADDRESSOF(tmpSegLen[0]), ADDRESSOF(tmpBlock.segLen[0]), LEN(tmpSegLen^) * SIZEOF(LONGINT));
								(* Init the remaining fields with 0 *)
								Machine.Fill32(ADDRESSOF(tmpBlock.segLen[LEN(tmpSegLen^)]), (newSegSize-LEN(tmpSegLen^))*SIZEOF(LONGINT), 0);
							END;

							IF decSpec.cstyle[curTile][comp].term THEN
								IF newSegs > 1 THEN
									SYSTEM.MOVE(ADDRESSOF(cblk.segLen[0]), ADDRESSOF(tmpBlock.segLen[tmpBlock.nseg]), newSegs * SIZEOF(LONGINT));
									INC(tmpBlock.nseg, newSegs);
								ELSE
									tmpBlock.segLen[tmpBlock.nseg] := cblk.dataLen;
									INC(tmpBlock.nseg);
								END;
							(* If we have bypass coding, we need to calculate the number of terminated segments *)
							ELSE	(* Bypass coding used *)
								IF newSegs > 1 THEN
									(* We must have passed the first bypass index, else we would have had only 1 segment *)
									tmpSegLen := tmpBlock.segLen;
									(* The first segment may be a completion of an unterminated segment *)
									INC(tmpSegLen[tmpBlock.nseg], cblk.segLen[0]);

									(* Copy the other segment lenghts *)
									SYSTEM.MOVE(ADDRESSOF(cblk.segLen[1]), ADDRESSOF(tmpSegLen[tmpBlock.nseg + 1]), (newSegs-1)*SIZEOF(LONGINT));

									(* If the last segment is terminated we need to increment the number of segments *)
									(* truncpt MOD ENTROPY_NUM_PASSES =  2-> significance propagation pass *)
									IF (cblkInfo.truncpt MOD ENTROPY_NUM_PASSES) # 2 THEN
										(* Last segment is terminated *)
										INC(tmpBlock.nseg, newSegs);
									ELSE
										(* Last segment is un-terminated *)
										INC(tmpBlock.nseg, newSegs - 1);
									END;
								ELSE
									(* Only 1 segment in this layer *)
									INC(tmpBlock.segLen[tmpBlock.nseg], cblk.dataLen);
									(* truncpt MOD ENTROPY_NUM_PASSES =  2-> significance propagation pass *)
									IF 	(cblkInfo.truncpt >= ENTROPY_FIRST_BYPASS_IDX) &
										((cblkInfo.truncpt MOD ENTROPY_NUM_PASSES) # 2) THEN
										(* This was the last chunk for this segment -> terminate it *)
										INC(tmpBlock.nseg);
									END;
								END;
							END;
						END;

						SYSTEM.MOVE(ADDRESSOF(cblk.data[cblk.dataOffset]), ADDRESSOF(tmpBlock.data[tmpBlock.dataLen]), newDataLen);
						INC(tmpBlock.dataLen, newDataLen);
						INC(tmpBlock.cpasses, cblk.cpasses);

						bufferedBlocks[curTile][comp][reslevel][subbIdx][cblkSubbIdx] := tmpBlock;
					END;
			END UpdateBufferedBlock;

			(**
				-> See CodestreamReader.GetCodeBlocks
			*)
			PROCEDURE GetCodeBlocks* (VAR cblocks : ARRAY OF J2KU.CodedCblk; VAR cblockInfos : ARRAY OF J2KU.CblkInfo; ncblocks : LONGINT) : LONGINT;
				VAR
					i, j, startPos, tmpCblkInBuf, cblkDecLvl, subbIdx, cblkSubbIdx : LONGINT;
					ok, deliver : BOOLEAN;
				BEGIN

					(* Check if we're in rebuild mode *)
					IF reBuildMode THEN
						RETURN GetBufferedBlocks(cblocks, cblockInfos, ncblocks);
					END;

					i := 0;
					(* See, wether buffer not empty: if not then return max(bufSize, ncblocks) code blocks *)
					WHILE i < ncblocks DO
						IF ~TilePartAvailable^() THEN
							RETURN i;
						END;

						(* See if the code-block buffer has been read entirely *)
						IF ncblkInBuf <= cblkBufPos THEN

							startPos := s.Pos();

							ncblkInBuf := 0;
							deliver := TRUE;

							tmpCblkInBuf := pktDec.DecodePacket(curComp, curRes, curLay, curPrec[curComp][curRes][curLay], cblkBuf^, cblkInfoBuf^);

							(* Need to check if the code-block is in the valid range (decomposition level, layer) *)
							cblkDecLvl := decSpec.cstyle[curTile][curComp].ndec - curRes;

							(* See if have to deliver the code-blocks at all *)
							(* NOTE: If we're outside the maximum decomposition level range, we discard the new code-block totally *)
							IF 	(cblkDecLvl < endDecLvl)
								OR (cblkDecLvl > startDecLvl)
							THEN
								IF 	(cblkDecLvl < maxEndDecLvl)
									OR (cblkDecLvl > maxStartDecLvl)
								THEN
									tmpCblkInBuf := 0;
								END;

								deliver := FALSE;
							END;

							IF	(curLay < startLayer)
								OR (curLay > endLayer)
							THEN
								IF	(curLay < maxStartLayer)
									OR (curLay > maxEndLayer)
								THEN
									tmpCblkInBuf := 0;
								END;

								deliver := FALSE;
							END;

							(* Update the buffered code-blocks *)
							FOR j := 0 TO tmpCblkInBuf - 1 DO
								(* Update the the code-block *)
								UpdateBufferedBlock(cblkBuf[j], cblkInfoBuf[j]);
							END;

							(* See, if we can deliver the code-blocks already *)
							IF	deliver &
								((curLay = endLayer) OR (curLay = decSpec.cics[curTile].nl - 1))
							THEN
								(* Put the blocks in the return buffer *)
								FOR j := 0 TO tmpCblkInBuf - 1 DO
									IF getAllLayers THEN
										(* We need all layers -> Just get code-block from buffer *)
										subbIdx := cblkInfoBuf[j].subbinfo.index;
										cblkSubbIdx := cblkInfoBuf[j].index;
										cblkBuf[ncblkInBuf] := bufferedBlocks[curTile][curComp][curRes][subbIdx][cblkSubbIdx];
									ELSE
										(* We need to calculate which data parts are to be delivered exactly*)
										AddBlock(cblkBuf[ncblkInBuf], cblkInfoBuf[j]);
									END;

									cblkInfoBuf[ncblkInBuf] := cblkInfoBuf[j];
									INC(ncblkInBuf);
								END;
							END;

							CASE progOrder OF
									PROG_LRCP:
										ok := AdvanceLayResComPos();
								|	PROG_RLCP:
 										ok := AdvanceResLayComPos();
								|	PROG_RPCL:
										ok := AdvanceResPosComLay();
								|	PROG_PCRL:
										ok := AdvancePosComResLay();
								|	PROG_CPRL:
										ok := AdvanceComPosResLay();
								ELSE
									ok := FALSE;
							END;

							IF ~ok THEN
								RETURN i;
							END;

							cblkBufPos := 0;
							partRem := partRem - (s.Pos() - startPos);
						ELSE
							(* Don't deliver code-blocks with no data *)
							IF cblkBuf[cblkBufPos].dataLen > 0 THEN
								cblocks[i] := cblkBuf[cblkBufPos];
								cblockInfos[i] := cblkInfoBuf[cblkBufPos];
								INC(i);
							END;

							INC(cblkBufPos);
						END;
					END;

					RETURN ncblocks;

			END GetCodeBlocks;

			(*
				Same as GetCodeBlocks, but used when in rebuild mode
			*)
			PROCEDURE GetBufferedBlocks (VAR cblocks : ARRAY OF J2KU.CodedCblk; VAR cblockInfos : ARRAY OF J2KU.CblkInfo; ncblocks : LONGINT) : LONGINT;
				VAR
					ncblocksRet: LONGINT;
					ndec, cblkDecLvl : LONGINT;
					curSubbType : LONGINT;
					locCurComp, locCurRes, locCurSubbIdx, locCurSubbCblk : LONGINT;
				BEGIN
					ncblocksRet := 0;
					(*
						Store counter variables locally, so that compiler does not trap when
						it can't find enough registers (i.e. when accessing multi-dimensional arrays)
					*)
					locCurComp := curComp;
					locCurRes := curRes;
					locCurSubbIdx := curSubbIdx;
					locCurSubbCblk := curSubbCblk;

					(* Loop over components *)
					WHILE locCurComp <= cmax DO

						(* Loop over resolution levels *)
						WHILE locCurRes <= rmax DO

							IF locCurRes = 0 THEN
								maxSubbIdx := 0;
							ELSE
								maxSubbIdx := 2;
							END;

							cblkDecLvl := decSpec.cstyle[curTile][locCurComp].ndec - locCurRes;

							(*
								We deliver for the current resolution level only if the code-blocks
								would lie in the requested decomposition level range.
							 *)
							IF (cblkDecLvl <= startDecLvl) & (cblkDecLvl >= endDecLvl) THEN
								(* Loop over subbands *)
								WHILE locCurSubbIdx <= maxSubbIdx DO

									curSubbType := J2KU.SubbandIndexToSubband(locCurRes, locCurSubbIdx);
									maxSubbCblk := LEN(bufferedBlocks[curTile][locCurComp][locCurRes][locCurSubbIdx]^) - 1;

									(* Loop over blocks in subband *)
									WHILE locCurSubbCblk <= maxSubbCblk DO

										cblockInfos[ncblocksRet] := pktDec.GetCblkInfo(	locCurComp,
																						locCurRes,
																						curSubbType,
																						locCurSubbCblk);

										IF getAllLayers THEN
											(* Just copy from buffer *)
											cblocks[ncblocksRet] := bufferedBlocks[curTile][locCurComp][locCurRes][locCurSubbIdx][locCurSubbCblk];
											cblockInfos[ncblocksRet].curbp := J2KU.LONGINT_BITS - 2 - cblockInfos[ncblocksRet].zerobp;
										ELSE
											(* Need to determine which code-block data is to be delivered (i.e. which data belongs to the requested layer range) *)
											AddBlock(cblocks[ncblocksRet], cblockInfos[ncblocksRet]);
										END;

										(* Don't deliver code-blocks with no data *)
										IF cblocks[ncblocksRet].dataLen > 0 THEN
											INC(ncblocksRet);
										END;

										INC(locCurSubbCblk);

										(* Check if we have enough blocks *)
										IF ncblocksRet = ncblocks THEN
											(* Update counter variables *)
											curComp := locCurComp;
											curRes := locCurRes;
											curSubbIdx := locCurSubbIdx;
											curSubbCblk := locCurSubbCblk;

											RETURN ncblocksRet;
										END;
									END;
									INC(locCurSubbIdx);
									locCurSubbCblk := 0;
								END;
							END;
							INC(locCurRes);
							(* We start over on all subbands *)
							locCurSubbIdx := 0;
						END;
						INC(locCurComp);

						IF locCurComp <= cmax THEN
							(* Set minimum/maximum resolution levels for the new component *)
							ndec := decSpec.GetNumDecLevels(curTile, locCurComp);

							(*
								If the start decomposition level is greater than the number of
								decomposition levels for the current tile-component, we start from
								the minimum resolution level available.
							*)
							IF startDecLvl > ndec THEN
								locCurRes := 0;
							ELSE
								(* The start decomposition level is not the maxim decomposition level *)
								locCurRes := ndec - startDecLvl;
							END;

							(*
								Need to check wether the current tile-component has data for
								the decomposition level range.
							*)
							IF endDecLvl > ndec THEN
								(*
									The minimum decomposition level is greater than the number
									of decomposition levels for this tile-component -> don't deliver
									any data
								*)
								rmax := -1;
							ELSE
								rmax := ndec - endDecLvl;
							END;
						END;
					END;

					(* Update counter variables *)
					curComp := locCurComp;
					curRes := locCurRes;
					curSubbIdx := locCurSubbIdx;
					curSubbCblk := locCurSubbCblk;

					RETURN ncblocksRet;
			END GetBufferedBlocks;

			PROCEDURE TilePartAvailable* () : BOOLEAN;
				BEGIN
					IF reBuildMode THEN
						RETURN	(curComp < cmax)
									OR (
										(curComp = cmax)
										& (
											(curRes < rmax)
											OR (curSubbIdx < maxSubbIdx)
											OR (curSubbCblk <= maxSubbCblk)
										)
									);
					ELSE
						RETURN TilePartAvailable^();
					END;
			END TilePartAvailable;

			PROCEDURE JumpToTilePartEnd () : LONGINT;
				BEGIN
					IF reBuildMode THEN
						curComp := cmax + 1;
						curRes := rmax;
						curSubbIdx := maxSubbIdx;
						curSubbCblk := maxSubbCblk + 1;

						RETURN 0;
					ELSE
						RETURN JumpToTilePartEnd^();
					END;
			END JumpToTilePartEnd;


			PROCEDURE NextTilePart*() : BOOLEAN;
				VAR
					imgInfo : ImageInfo;
					ntiles : LONGINT;
					ok : BOOLEAN;
				BEGIN
					IF reBuildMode THEN

						imgInfo := decSpec.GetImageInfo();
						ntiles := imgInfo.GetNumTiles();

						(* We need to ensure there is some data available for the next tile, else we need to skip it *)
						REPEAT
							INC(curTile);
						UNTIL (curTile >= ntiles) OR (ntilePartsRead[curTile] > 0);

						IF curTile < ntiles THEN
							pktDec.SetTile(curTile);
							ok := InitTile();
						ELSE
							(* Just to ensure that TilePartAvailable() returns FALSE *)
							curComp := cmax + 1;
							curRes := rmax;
							curSubbIdx := maxSubbIdx;
							curSubbCblk := maxSubbCblk + 1;

							(* Leave rebuild mode *)
							reBuildMode := FALSE;

							(* If we're not at the end of the codestream, we continue reading from the stream *)
							IF ~EndOfCodestream^() THEN
								ok := NextTilePart^();
							ELSE
								(* We're at the end of the stream too -> no data (neither rebuild nor stream data) *)
								ok := FALSE;
							END;
						END;

						RETURN ok;
					ELSE
						RETURN NextTilePart^();
					END;
			END NextTilePart;

			PROCEDURE EndOfCodestream* () : BOOLEAN;
				VAR
					imgInfo : ImageInfo;
				BEGIN
					IF reBuildMode THEN
						imgInfo := decSpec.GetImageInfo();

						RETURN imgInfo.GetNumTiles() <= curTile;
					ELSE
						RETURN EndOfCodestream^();
					END;
			END EndOfCodestream;

			PROCEDURE FreeNonRebuildResources*;
				BEGIN
					s := NIL;
					progChanges := NIL;
					progStates := NIL;
					curPrec := NIL;
			END FreeNonRebuildResources;

			PROCEDURE FreeResources*;
				BEGIN
					FreeResources^();
					bufferedBlocks := NIL;
			END FreeResources;

		END BufferedCodestreamReader;


		(* --- Utility functions --- *)

		PROCEDURE MarkerToString (marker : LONGINT; VAR str : ARRAY OF CHAR);
			VAR
				i : LONGINT;
			BEGIN
				ASSERT (LEN(str) >= 7);

				CASE marker OF
					|	SOC :
							COPY("SOC", str);
					|	SOT :
							COPY("SOT", str);
					|	SOD :
							COPY("SOD", str);
					|	EOC :
							COPY("EOC", str);
					|	SIZ :
							COPY("SIZ", str);
					|	COD :
							COPY("COC", str);
					|	COC :
							COPY("COC", str);
					|	RGN :
							COPY("RGN", str);
					|	QCD :
							COPY("QCD", str);
					|	QCC :
							COPY("QCC", str);
					|	POC :
							COPY("POC", str);
					|	TLM :
							COPY("TLM", str);
					|	PLM :
							COPY("PLM", str);
					|	PLT :
							COPY("PLT", str);
					|	PPM :
							COPY("PPM", str);
					|	PPT :
							COPY("PPT", str);
					|	SOP :
							COPY("SOP", str);
					|	EPH :
							COPY("EPH", str);
					|	CRG :
							COPY("CRG", str);
					|	COM :
							COPY("COM", str);
					ELSE
						str[0] := '0';
						str[1] := 'x';
						(* NOTE: No optimizations done here *)
						FOR i := 5 TO 2 BY -1 DO
							str[i] := CHR(marker MOD 10H + 48);
							IF str[i] > "9" THEN
								str[i] := CHR(ORD(str[i]) - 48 + 65 - 10)
							END;
							marker := marker DIV 10H;
						END;
						str[6] := 0X;
				END;
		END MarkerToString;

END JPEG2000DecoderCS.