MODULE EFIGraphicalConsole; (** AUTHOR ""; PURPOSE ""; *)

IMPORT SYSTEM,Trace;

CONST
	(* PixelFormat enum *)
	PFRGBX8Bit= 0; (* a pixel is 32 bit. Each color is 8bit and they are ordered Red,Green,Blue,Reserved *)
	PFBGRX8Bit= 1; (* a pixel is 32 bit. Each color is 8bit and they are ordered Blue,Green,Red,Reserved *)
	PFBitMask= 2; (* format is defined by PixelBitmask *)
	PFBltOnly= 3; (* this mode does not support a physical frame buffer *)
	PFMax= 4;

TYPE
	Buffer = ADDRESS;

	Char = RECORD
		dx*,x*,y*,w*,h*: INTEGER;
		buffer*: Buffer;
	END;

	Font = RECORD
		height*, minX*, maxX*, minY*, maxY*: INTEGER;
		char: ARRAY 256 OF Char;
	END;

	(* copies of types in EFIGraphicsOutput -- to be independent of EFI *)
	GraphicsModeInfo = POINTER TO GraphicsModeInfoDescription;
	GraphicsModeInfoDescription = RECORD
		Version-: LONGINT; (* = 0 for the structure specified here. If > 0, structure extended backwards compatibly *)
		HorizontalResolution-: LONGINT;
		VerticalResolution-: LONGINT;
		PixelFormat-: LONGINT; (* enum *)
		PixelBitmask-: RECORD RedMask-,GreenMask-,BlueMask-,ReservedMask-:LONGINT; END;
		PixelsPerScanline-: LONGINT;
	END;

	VAR
		font: Font;
		(* character pattern buffer *)
		buffer: ARRAY 1342 OF CHAR;

		(* frame buffer parameters *)
		adr: ADDRESS; VAR x,y: SIZE; w,h,depth: SIZE;
		info: GraphicsModeInfo;

	PROCEDURE MakeFont*(VAR font: Font);
	VAR buf: Buffer; pos: LONGINT;
		PROCEDURE SetBuf(VAR p: Buffer); BEGIN p := ADDRESSOF(buffer[pos]) END SetBuf;
		PROCEDURE Put1(ch: CHAR); BEGIN buffer[pos] := ch; INC(pos) END Put1;
		PROCEDURE Dimensions(VAR char: Char; dx,x,y,w,h: INTEGER); BEGIN char.dx := dx; char.x := x; char.y := y; char.w := w; char.h := h END Dimensions;
	BEGIN
		font.height := 14;
		font.minX := 0;
		font.maxX := 13;
		font.minY := -4;
		font.maxY := 10;
		Dimensions(font.char[0], 7, 1, 0, 5, 10);SetBuf(font.char[0].buffer);Put1(005X);Put1(00AX);Put1(01FX);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(01FX);
		Dimensions(font.char[1], 12, 0, -3, 12, 12);SetBuf(font.char[1].buffer);Put1(00CX);Put1(00CX);Put1(0FFX);Put1(00FX);Put1(001X);Put1(008X);Put1(001X);Put1(008X);Put1(001X);Put1(008X);Put1(001X);Put1(008X);Put1(001X);Put1(008X);Put1(001X);Put1(008X);Put1(001X);Put1(008X);Put1(001X);Put1(008X);Put1(001X);Put1(008X);Put1(001X);Put1(008X);Put1(0FFX);Put1(00FX);
		Dimensions(font.char[2], 12, 0, -3, 12, 12);font.char[2].buffer := font.char[1].buffer;
		Dimensions(font.char[3], 12, 0, -3, 12, 12);font.char[3].buffer := font.char[1].buffer;
		Dimensions(font.char[4], 12, 0, -3, 12, 12);font.char[4].buffer := font.char[1].buffer;
		Dimensions(font.char[5], 12, 0, -3, 12, 12);font.char[5].buffer := font.char[1].buffer;
		Dimensions(font.char[6], 12, 0, -3, 12, 12);font.char[6].buffer := font.char[1].buffer;
		Dimensions(font.char[7], 12, 0, -3, 12, 12);font.char[7].buffer := font.char[1].buffer;
		Dimensions(font.char[8], 12, 0, -3, 12, 12);font.char[8].buffer := font.char[1].buffer;
		Dimensions(font.char[9], 16, 0, 0, 0, 0);SetBuf(font.char[9].buffer);Put1(000X);Put1(000X);
		Dimensions(font.char[10], 12, 0, -3, 12, 12);font.char[10].buffer := font.char[1].buffer;
		Dimensions(font.char[11], 12, 0, -3, 12, 12);font.char[11].buffer := font.char[1].buffer;
		Dimensions(font.char[12], 12, 0, -3, 12, 12);font.char[12].buffer := font.char[1].buffer;
		Dimensions(font.char[13], 12, 0, -3, 12, 12);font.char[13].buffer := font.char[1].buffer;
		Dimensions(font.char[14], 12, 0, -3, 12, 12);font.char[14].buffer := font.char[1].buffer;
		Dimensions(font.char[15], 12, 0, -3, 12, 12);font.char[15].buffer := font.char[1].buffer;
		Dimensions(font.char[16], 12, 0, -3, 12, 12);font.char[16].buffer := font.char[1].buffer;
		Dimensions(font.char[17], 12, 0, -3, 12, 12);font.char[17].buffer := font.char[1].buffer;
		Dimensions(font.char[18], 12, 0, -3, 12, 12);font.char[18].buffer := font.char[1].buffer;
		Dimensions(font.char[19], 12, 0, -3, 12, 12);font.char[19].buffer := font.char[1].buffer;
		Dimensions(font.char[20], 12, 0, -3, 12, 12);font.char[20].buffer := font.char[1].buffer;
		Dimensions(font.char[21], 12, 0, -3, 12, 12);font.char[21].buffer := font.char[1].buffer;
		Dimensions(font.char[22], 12, 0, -3, 12, 12);font.char[22].buffer := font.char[1].buffer;
		Dimensions(font.char[23], 12, 0, -3, 12, 12);font.char[23].buffer := font.char[1].buffer;
		Dimensions(font.char[24], 12, 0, -3, 12, 12);font.char[24].buffer := font.char[1].buffer;
		Dimensions(font.char[25], 12, 0, -3, 12, 12);font.char[25].buffer := font.char[1].buffer;
		Dimensions(font.char[26], 12, 0, -3, 12, 12);font.char[26].buffer := font.char[1].buffer;
		Dimensions(font.char[27], 12, 0, -3, 12, 12);font.char[27].buffer := font.char[1].buffer;
		Dimensions(font.char[28], 12, 0, -3, 12, 12);font.char[28].buffer := font.char[1].buffer;
		Dimensions(font.char[29], 12, 0, -3, 12, 12);font.char[29].buffer := font.char[1].buffer;
		Dimensions(font.char[30], 12, 0, -3, 12, 12);font.char[30].buffer := font.char[1].buffer;
		Dimensions(font.char[31], 12, 0, -3, 12, 12);font.char[31].buffer := font.char[1].buffer;
		Dimensions(font.char[32], 4, 0, 0, 0, 0);SetBuf(font.char[32].buffer);Put1(000X);Put1(000X);
		Dimensions(font.char[33], 4, 2, 0, 1, 9);SetBuf(font.char[33].buffer);Put1(001X);Put1(009X);Put1(001X);Put1(001X);Put1(000X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);
		Dimensions(font.char[34], 5, 1, 6, 3, 3);SetBuf(font.char[34].buffer);Put1(003X);Put1(003X);Put1(005X);Put1(005X);Put1(005X);
		Dimensions(font.char[35], 7, 0, 0, 6, 9);SetBuf(font.char[35].buffer);Put1(006X);Put1(009X);Put1(012X);Put1(012X);Put1(012X);Put1(03FX);Put1(012X);Put1(03FX);Put1(012X);Put1(012X);Put1(012X);
		Dimensions(font.char[36], 6, 0, -1, 6, 11);SetBuf(font.char[36].buffer);Put1(006X);Put1(00BX);Put1(004X);Put1(00FX);Put1(014X);Put1(014X);Put1(014X);Put1(00CX);Put1(00AX);Put1(00AX);Put1(00AX);Put1(03CX);Put1(008X);
		Dimensions(font.char[37], 9, 1, 0, 7, 9);SetBuf(font.char[37].buffer);Put1(007X);Put1(009X);Put1(032X);Put1(04AX);Put1(04CX);Put1(034X);Put1(008X);Put1(016X);Put1(019X);Put1(029X);Put1(026X);
		Dimensions(font.char[38], 7, 0, 0, 7, 9);SetBuf(font.char[38].buffer);Put1(007X);Put1(009X);Put1(04EX);Put1(031X);Put1(021X);Put1(051X);Put1(04AX);Put1(00CX);Put1(012X);Put1(012X);Put1(01CX);
		Dimensions(font.char[39], 3, 1, 6, 1, 3);SetBuf(font.char[39].buffer);Put1(001X);Put1(003X);Put1(001X);Put1(001X);Put1(001X);
		Dimensions(font.char[40], 5, 1, -2, 3, 11);SetBuf(font.char[40].buffer);Put1(003X);Put1(00BX);Put1(004X);Put1(002X);Put1(002X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(002X);Put1(002X);Put1(004X);
		Dimensions(font.char[41], 5, 1, -2, 3, 11);SetBuf(font.char[41].buffer);Put1(003X);Put1(00BX);Put1(001X);Put1(002X);Put1(002X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(002X);Put1(002X);Put1(001X);
		Dimensions(font.char[42], 7, 0, 0, 7, 7);SetBuf(font.char[42].buffer);Put1(007X);Put1(007X);Put1(022X);Put1(014X);Put1(008X);Put1(07FX);Put1(008X);Put1(014X);Put1(022X);
		Dimensions(font.char[43], 7, 0, 0, 7, 7);SetBuf(font.char[43].buffer);Put1(007X);Put1(007X);Put1(008X);Put1(008X);Put1(008X);Put1(07FX);Put1(008X);Put1(008X);Put1(008X);
		Dimensions(font.char[44], 3, 0, -3, 2, 5);SetBuf(font.char[44].buffer);Put1(002X);Put1(005X);Put1(001X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);
		Dimensions(font.char[45], 7, 1, 3, 6, 1);SetBuf(font.char[45].buffer);Put1(006X);Put1(001X);Put1(03FX);
		Dimensions(font.char[46], 3, 1, 0, 1, 2);SetBuf(font.char[46].buffer);Put1(001X);Put1(002X);Put1(001X);Put1(001X);
		Dimensions(font.char[47], 5, 0, 0, 5, 10);SetBuf(font.char[47].buffer);Put1(005X);Put1(00AX);Put1(001X);Put1(001X);Put1(002X);Put1(002X);Put1(004X);Put1(004X);Put1(008X);Put1(008X);Put1(010X);Put1(010X);
		Dimensions(font.char[48], 6, 0, 0, 5, 9);SetBuf(font.char[48].buffer);Put1(005X);Put1(009X);Put1(00EX);Put1(00AX);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(00AX);Put1(00EX);
		Dimensions(font.char[49], 6, 0, 0, 3, 9);SetBuf(font.char[49].buffer);Put1(003X);Put1(009X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(005X);Put1(006X);Put1(004X);
		Dimensions(font.char[50], 6, 0, 0, 5, 9);SetBuf(font.char[50].buffer);Put1(005X);Put1(009X);Put1(01FX);Put1(001X);Put1(002X);Put1(004X);Put1(008X);Put1(008X);Put1(008X);Put1(008X);Put1(007X);
		Dimensions(font.char[51], 6, 1, 0, 4, 9);SetBuf(font.char[51].buffer);Put1(004X);Put1(009X);Put1(007X);Put1(004X);Put1(008X);Put1(008X);Put1(007X);Put1(004X);Put1(008X);Put1(008X);Put1(007X);
		Dimensions(font.char[52], 6, 0, 0, 6, 9);SetBuf(font.char[52].buffer);Put1(006X);Put1(009X);Put1(008X);Put1(008X);Put1(008X);Put1(03FX);Put1(009X);Put1(009X);Put1(00AX);Put1(00CX);Put1(008X);
		Dimensions(font.char[53], 6, 0, 0, 5, 9);SetBuf(font.char[53].buffer);Put1(005X);Put1(009X);Put1(007X);Put1(008X);Put1(010X);Put1(010X);Put1(018X);Put1(00FX);Put1(001X);Put1(002X);Put1(01EX);
		Dimensions(font.char[54], 6, 0, 0, 5, 9);SetBuf(font.char[54].buffer);Put1(005X);Put1(009X);Put1(00EX);Put1(011X);Put1(011X);Put1(013X);Put1(00DX);Put1(001X);Put1(002X);Put1(006X);Put1(018X);
		Dimensions(font.char[55], 6, 0, 0, 5, 9);SetBuf(font.char[55].buffer);Put1(005X);Put1(009X);Put1(002X);Put1(002X);Put1(002X);Put1(004X);Put1(004X);Put1(004X);Put1(008X);Put1(008X);Put1(01FX);
		Dimensions(font.char[56], 6, 0, 0, 5, 9);SetBuf(font.char[56].buffer);Put1(005X);Put1(009X);Put1(00EX);Put1(011X);Put1(011X);Put1(00AX);Put1(004X);Put1(00AX);Put1(011X);Put1(011X);Put1(00EX);
		Dimensions(font.char[57], 6, 0, 0, 5, 9);SetBuf(font.char[57].buffer);Put1(005X);Put1(009X);Put1(003X);Put1(00CX);Put1(008X);Put1(010X);Put1(016X);Put1(019X);Put1(011X);Put1(011X);Put1(00EX);
		Dimensions(font.char[58], 4, 2, 0, 1, 7);SetBuf(font.char[58].buffer);Put1(001X);Put1(007X);Put1(001X);Put1(001X);Put1(000X);Put1(000X);Put1(000X);Put1(001X);Put1(001X);
		Dimensions(font.char[59], 4, 1, -3, 2, 10);SetBuf(font.char[59].buffer);Put1(002X);Put1(00AX);Put1(001X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(000X);Put1(000X);Put1(000X);Put1(002X);Put1(002X);
		Dimensions(font.char[60], 7, 0, 0, 7, 7);SetBuf(font.char[60].buffer);Put1(007X);Put1(007X);Put1(060X);Put1(018X);Put1(006X);Put1(001X);Put1(006X);Put1(018X);Put1(060X);
		Dimensions(font.char[61], 7, 1, 2, 5, 3);SetBuf(font.char[61].buffer);Put1(005X);Put1(003X);Put1(01FX);Put1(000X);Put1(01FX);
		Dimensions(font.char[62], 7, 0, 0, 7, 7);SetBuf(font.char[62].buffer);Put1(007X);Put1(007X);Put1(003X);Put1(00CX);Put1(030X);Put1(040X);Put1(030X);Put1(00CX);Put1(003X);
		Dimensions(font.char[63], 6, 1, 0, 4, 9);SetBuf(font.char[63].buffer);Put1(004X);Put1(009X);Put1(002X);Put1(002X);Put1(000X);Put1(002X);Put1(002X);Put1(004X);Put1(008X);Put1(008X);Put1(007X);
		Dimensions(font.char[64], 12, 1, 0, 10, 9);SetBuf(font.char[64].buffer);Put1(00AX);Put1(009X);Put1(00CX);Put1(000X);Put1(0C2X);Put1(001X);Put1(059X);Put1(001X);Put1(069X);Put1(002X);Put1(049X);Put1(002X);Put1(049X);Put1(002X);Put1(072X);Put1(002X);Put1(006X);Put1(001X);Put1(0F8X);Put1(000X);
		Dimensions(font.char[65], 7, 0, 0, 7, 9);SetBuf(font.char[65].buffer);Put1(007X);Put1(009X);Put1(041X);Put1(041X);Put1(022X);Put1(03EX);Put1(022X);Put1(014X);Put1(014X);Put1(008X);Put1(008X);
		Dimensions(font.char[66], 7, 1, 0, 5, 9);SetBuf(font.char[66].buffer);Put1(005X);Put1(009X);Put1(00FX);Put1(011X);Put1(011X);Put1(011X);Put1(00FX);Put1(011X);Put1(011X);Put1(011X);Put1(00FX);
		Dimensions(font.char[67], 7, 1, 0, 5, 9);SetBuf(font.char[67].buffer);Put1(005X);Put1(009X);Put1(01CX);Put1(002X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(002X);Put1(01CX);
		Dimensions(font.char[68], 9, 1, 0, 7, 9);SetBuf(font.char[68].buffer);Put1(007X);Put1(009X);Put1(01FX);Put1(021X);Put1(041X);Put1(041X);Put1(041X);Put1(041X);Put1(041X);Put1(021X);Put1(01FX);
		Dimensions(font.char[69], 7, 1, 0, 5, 9);SetBuf(font.char[69].buffer);Put1(005X);Put1(009X);Put1(01FX);Put1(001X);Put1(001X);Put1(001X);Put1(01FX);Put1(001X);Put1(001X);Put1(001X);Put1(01FX);
		Dimensions(font.char[70], 6, 1, 0, 5, 9);SetBuf(font.char[70].buffer);Put1(005X);Put1(009X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(01FX);Put1(001X);Put1(001X);Put1(001X);Put1(01FX);
		Dimensions(font.char[71], 8, 1, 0, 6, 9);SetBuf(font.char[71].buffer);Put1(006X);Put1(009X);Put1(03CX);Put1(022X);Put1(021X);Put1(021X);Put1(021X);Put1(001X);Put1(001X);Put1(002X);Put1(03CX);
		Dimensions(font.char[72], 8, 1, 0, 6, 9);SetBuf(font.char[72].buffer);Put1(006X);Put1(009X);Put1(021X);Put1(021X);Put1(021X);Put1(021X);Put1(03FX);Put1(021X);Put1(021X);Put1(021X);Put1(021X);
		Dimensions(font.char[73], 3, 1, 0, 1, 9);SetBuf(font.char[73].buffer);Put1(001X);Put1(009X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);
		Dimensions(font.char[74], 4, 0, 0, 3, 9);SetBuf(font.char[74].buffer);Put1(003X);Put1(009X);Put1(003X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);
		Dimensions(font.char[75], 7, 1, 0, 6, 9);SetBuf(font.char[75].buffer);Put1(006X);Put1(009X);Put1(021X);Put1(011X);Put1(009X);Put1(005X);Put1(003X);Put1(005X);Put1(009X);Put1(011X);Put1(021X);
		Dimensions(font.char[76], 6, 1, 0, 5, 9);SetBuf(font.char[76].buffer);Put1(005X);Put1(009X);Put1(01FX);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);
		Dimensions(font.char[77], 11, 0, 0, 11, 9);SetBuf(font.char[77].buffer);Put1(00BX);Put1(009X);Put1(021X);Put1(004X);Put1(021X);Put1(004X);Put1(051X);Put1(004X);Put1(052X);Put1(002X);Put1(052X);Put1(002X);Put1(08AX);Put1(002X);Put1(08AX);Put1(002X);Put1(004X);Put1(001X);Put1(004X);Put1(001X);
		Dimensions(font.char[78], 9, 1, 0, 7, 9);SetBuf(font.char[78].buffer);Put1(007X);Put1(009X);Put1(041X);Put1(061X);Put1(051X);Put1(049X);Put1(049X);Put1(045X);Put1(045X);Put1(043X);Put1(041X);
		Dimensions(font.char[79], 9, 1, 0, 7, 9);SetBuf(font.char[79].buffer);Put1(007X);Put1(009X);Put1(01CX);Put1(022X);Put1(041X);Put1(041X);Put1(041X);Put1(041X);Put1(041X);Put1(022X);Put1(01CX);
		Dimensions(font.char[80], 6, 1, 0, 5, 9);SetBuf(font.char[80].buffer);Put1(005X);Put1(009X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(00FX);Put1(011X);Put1(011X);Put1(011X);Put1(00FX);
		Dimensions(font.char[81], 9, 1, -2, 8, 11);SetBuf(font.char[81].buffer);Put1(008X);Put1(00BX);Put1(0C0X);Put1(020X);Put1(01CX);Put1(022X);Put1(041X);Put1(041X);Put1(041X);Put1(041X);Put1(041X);Put1(022X);Put1(01CX);
		Dimensions(font.char[82], 7, 1, 0, 6, 9);SetBuf(font.char[82].buffer);Put1(006X);Put1(009X);Put1(021X);Put1(011X);Put1(011X);Put1(009X);Put1(00FX);Put1(011X);Put1(011X);Put1(011X);Put1(00FX);
		Dimensions(font.char[83], 6, 1, 0, 4, 9);SetBuf(font.char[83].buffer);Put1(004X);Put1(009X);Put1(007X);Put1(008X);Put1(008X);Put1(004X);Put1(006X);Put1(002X);Put1(001X);Put1(001X);Put1(00EX);
		Dimensions(font.char[84], 7, 0, 0, 7, 9);SetBuf(font.char[84].buffer);Put1(007X);Put1(009X);Put1(008X);Put1(008X);Put1(008X);Put1(008X);Put1(008X);Put1(008X);Put1(008X);Put1(008X);Put1(07FX);
		Dimensions(font.char[85], 8, 1, 0, 6, 9);SetBuf(font.char[85].buffer);Put1(006X);Put1(009X);Put1(01EX);Put1(012X);Put1(021X);Put1(021X);Put1(021X);Put1(021X);Put1(021X);Put1(021X);Put1(021X);
		Dimensions(font.char[86], 7, 0, 0, 7, 9);SetBuf(font.char[86].buffer);Put1(007X);Put1(009X);Put1(008X);Put1(008X);Put1(014X);Put1(014X);Put1(022X);Put1(022X);Put1(022X);Put1(041X);Put1(041X);
		Dimensions(font.char[87], 13, 0, 0, 13, 9);SetBuf(font.char[87].buffer);Put1(00DX);Put1(009X);Put1(008X);Put1(002X);Put1(008X);Put1(002X);Put1(014X);Put1(005X);Put1(014X);Put1(005X);Put1(012X);Put1(009X);Put1(0A2X);Put1(008X);Put1(0A2X);Put1(008X);Put1(041X);Put1(010X);Put1(041X);Put1(010X);
		Dimensions(font.char[88], 7, 0, 0, 7, 9);SetBuf(font.char[88].buffer);Put1(007X);Put1(009X);Put1(041X);Put1(022X);Put1(022X);Put1(014X);Put1(008X);Put1(014X);Put1(022X);Put1(022X);Put1(041X);
		Dimensions(font.char[89], 6, 0, 0, 6, 9);SetBuf(font.char[89].buffer);Put1(006X);Put1(009X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(00AX);Put1(012X);Put1(011X);Put1(021X);Put1(021X);
		Dimensions(font.char[90], 5, 0, 0, 5, 9);SetBuf(font.char[90].buffer);Put1(005X);Put1(009X);Put1(01FX);Put1(001X);Put1(002X);Put1(002X);Put1(004X);Put1(008X);Put1(008X);Put1(010X);Put1(01FX);
		Dimensions(font.char[91], 5, 1, -2, 3, 11);SetBuf(font.char[91].buffer);Put1(003X);Put1(00BX);Put1(007X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(007X);
		Dimensions(font.char[92], 5, 0, 0, 5, 10);SetBuf(font.char[92].buffer);Put1(005X);Put1(00AX);Put1(010X);Put1(010X);Put1(008X);Put1(008X);Put1(004X);Put1(004X);Put1(002X);Put1(002X);Put1(001X);Put1(001X);
		Dimensions(font.char[93], 5, 1, -2, 3, 11);SetBuf(font.char[93].buffer);Put1(003X);Put1(00BX);Put1(007X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(007X);
		Dimensions(font.char[94], 7, 0, 0, 7, 8);SetBuf(font.char[94].buffer);Put1(007X);Put1(008X);Put1(008X);Put1(008X);Put1(008X);Put1(008X);Put1(049X);Put1(02AX);Put1(01CX);Put1(008X);
		Dimensions(font.char[95], 3, 0, 3, 3, 1);SetBuf(font.char[95].buffer);Put1(003X);Put1(001X);Put1(007X);
		Dimensions(font.char[96], 7, 2, 8, 2, 2);SetBuf(font.char[96].buffer);Put1(002X);Put1(002X);Put1(002X);Put1(001X);
		Dimensions(font.char[97], 6, 1, 0, 4, 7);SetBuf(font.char[97].buffer);Put1(004X);Put1(007X);Put1(00BX);Put1(009X);Put1(009X);Put1(00EX);Put1(008X);Put1(009X);Put1(00EX);
		Dimensions(font.char[98], 7, 1, 0, 5, 10);SetBuf(font.char[98].buffer);Put1(005X);Put1(00AX);Put1(00FX);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(013X);Put1(01DX);Put1(001X);Put1(001X);Put1(001X);
		Dimensions(font.char[99], 5, 1, 0, 4, 7);SetBuf(font.char[99].buffer);Put1(004X);Put1(007X);Put1(007X);Put1(009X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(00EX);
		Dimensions(font.char[100], 7, 1, 0, 5, 10);SetBuf(font.char[100].buffer);Put1(005X);Put1(00AX);Put1(017X);Put1(019X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(01EX);Put1(010X);Put1(010X);Put1(010X);
		Dimensions(font.char[101], 6, 1, 0, 4, 7);SetBuf(font.char[101].buffer);Put1(004X);Put1(007X);Put1(007X);Put1(009X);Put1(001X);Put1(00FX);Put1(009X);Put1(009X);Put1(00EX);
		Dimensions(font.char[102], 4, 0, 0, 4, 10);SetBuf(font.char[102].buffer);Put1(004X);Put1(00AX);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(00FX);Put1(002X);Put1(002X);Put1(00CX);
		Dimensions(font.char[103], 6, 1, -3, 5, 10);SetBuf(font.char[103].buffer);Put1(005X);Put1(00AX);Put1(00EX);Put1(011X);Put1(011X);Put1(00EX);Put1(001X);Put1(006X);Put1(009X);Put1(009X);Put1(009X);Put1(01EX);
		Dimensions(font.char[104], 7, 1, 0, 5, 10);SetBuf(font.char[104].buffer);Put1(005X);Put1(00AX);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(013X);Put1(01DX);Put1(001X);Put1(001X);Put1(001X);
		Dimensions(font.char[105], 3, 1, 0, 1, 10);SetBuf(font.char[105].buffer);Put1(001X);Put1(00AX);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(000X);Put1(000X);Put1(001X);
		Dimensions(font.char[106], 3, 0, -3, 2, 13);SetBuf(font.char[106].buffer);Put1(002X);Put1(00DX);Put1(001X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(000X);Put1(000X);Put1(002X);
		Dimensions(font.char[107], 6, 1, 0, 5, 10);SetBuf(font.char[107].buffer);Put1(005X);Put1(00AX);Put1(011X);Put1(009X);Put1(005X);Put1(003X);Put1(005X);Put1(009X);Put1(011X);Put1(001X);Put1(001X);Put1(001X);
		Dimensions(font.char[108], 3, 1, 0, 1, 10);SetBuf(font.char[108].buffer);Put1(001X);Put1(00AX);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);
		Dimensions(font.char[109], 11, 1, 0, 9, 7);SetBuf(font.char[109].buffer);Put1(009X);Put1(007X);Put1(011X);Put1(001X);Put1(011X);Put1(001X);Put1(011X);Put1(001X);Put1(011X);Put1(001X);Put1(011X);Put1(001X);Put1(033X);Put1(001X);Put1(0DDX);Put1(001X);
		Dimensions(font.char[110], 7, 1, 0, 5, 7);SetBuf(font.char[110].buffer);Put1(005X);Put1(007X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(013X);Put1(01DX);
		Dimensions(font.char[111], 7, 1, 0, 5, 7);SetBuf(font.char[111].buffer);Put1(005X);Put1(007X);Put1(00FX);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(01EX);
		Dimensions(font.char[112], 7, 1, -3, 5, 10);SetBuf(font.char[112].buffer);Put1(005X);Put1(00AX);Put1(001X);Put1(001X);Put1(001X);Put1(00FX);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(013X);Put1(01DX);
		Dimensions(font.char[113], 7, 1, -3, 5, 10);SetBuf(font.char[113].buffer);Put1(005X);Put1(00AX);Put1(010X);Put1(010X);Put1(010X);Put1(017X);Put1(019X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(01EX);
		Dimensions(font.char[114], 4, 1, 0, 3, 7);SetBuf(font.char[114].buffer);Put1(003X);Put1(007X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(003X);Put1(005X);
		Dimensions(font.char[115], 5, 0, 0, 4, 7);SetBuf(font.char[115].buffer);Put1(004X);Put1(007X);Put1(007X);Put1(008X);Put1(008X);Put1(006X);Put1(001X);Put1(001X);Put1(00EX);
		Dimensions(font.char[116], 4, 0, 0, 4, 9);SetBuf(font.char[116].buffer);Put1(004X);Put1(009X);Put1(006X);Put1(00AX);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(00FX);Put1(002X);Put1(002X);
		Dimensions(font.char[117], 7, 1, 0, 5, 7);SetBuf(font.char[117].buffer);Put1(005X);Put1(007X);Put1(017X);Put1(019X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);
		Dimensions(font.char[118], 5, 0, 0, 5, 7);SetBuf(font.char[118].buffer);Put1(005X);Put1(007X);Put1(004X);Put1(004X);Put1(00AX);Put1(00AX);Put1(011X);Put1(011X);Put1(011X);
		Dimensions(font.char[119], 9, 0, 0, 9, 7);SetBuf(font.char[119].buffer);Put1(009X);Put1(007X);Put1(044X);Put1(000X);Put1(044X);Put1(000X);Put1(0AAX);Put1(000X);Put1(0AAX);Put1(000X);Put1(0AAX);Put1(000X);Put1(011X);Put1(001X);Put1(011X);Put1(001X);
		Dimensions(font.char[120], 5, 0, 0, 5, 7);SetBuf(font.char[120].buffer);Put1(005X);Put1(007X);Put1(011X);Put1(011X);Put1(00AX);Put1(004X);Put1(00AX);Put1(011X);Put1(011X);
		Dimensions(font.char[121], 5, 0, -3, 5, 10);SetBuf(font.char[121].buffer);Put1(005X);Put1(00AX);Put1(002X);Put1(002X);Put1(004X);Put1(004X);Put1(004X);Put1(00AX);Put1(00AX);Put1(011X);Put1(011X);Put1(011X);
		Dimensions(font.char[122], 5, 0, 0, 5, 7);SetBuf(font.char[122].buffer);Put1(005X);Put1(007X);Put1(01FX);Put1(002X);Put1(002X);Put1(004X);Put1(008X);Put1(008X);Put1(01FX);
		Dimensions(font.char[123], 4, 0, -2, 4, 11);SetBuf(font.char[123].buffer);Put1(004X);Put1(00BX);Put1(00CX);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(001X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(00CX);
		Dimensions(font.char[124], 3, 1, -3, 1, 13);SetBuf(font.char[124].buffer);Put1(001X);Put1(00DX);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);
		Dimensions(font.char[125], 4, 0, -2, 4, 11);SetBuf(font.char[125].buffer);Put1(004X);Put1(00BX);Put1(003X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(008X);Put1(004X);Put1(004X);Put1(004X);Put1(004X);Put1(003X);
		Dimensions(font.char[126], 7, 0, 2, 7, 3);SetBuf(font.char[126].buffer);Put1(007X);Put1(003X);Put1(031X);Put1(049X);Put1(046X);
		Dimensions(font.char[127], 12, 0, -3, 12, 12);font.char[127].buffer := font.char[1].buffer;
		Dimensions(font.char[128], 7, 0, 0, 7, 10);SetBuf(font.char[128].buffer);Put1(007X);Put1(00AX);Put1(041X);Put1(041X);Put1(022X);Put1(03EX);Put1(022X);Put1(014X);Put1(014X);Put1(008X);Put1(008X);Put1(022X);
		Dimensions(font.char[129], 9, 1, 0, 7, 10);SetBuf(font.char[129].buffer);Put1(007X);Put1(00AX);Put1(01CX);Put1(022X);Put1(041X);Put1(041X);Put1(041X);Put1(041X);Put1(041X);Put1(022X);Put1(01CX);Put1(022X);
		Dimensions(font.char[130], 8, 1, 0, 6, 10);SetBuf(font.char[130].buffer);Put1(006X);Put1(00AX);Put1(01EX);Put1(012X);Put1(021X);Put1(021X);Put1(021X);Put1(021X);Put1(021X);Put1(021X);Put1(021X);Put1(00CX);
		Dimensions(font.char[131], 6, 1, 0, 4, 10);SetBuf(font.char[131].buffer);Put1(004X);Put1(00AX);Put1(00BX);Put1(009X);Put1(009X);Put1(00EX);Put1(008X);Put1(009X);Put1(00EX);Put1(000X);Put1(009X);Put1(009X);
		Dimensions(font.char[132], 7, 1, 0, 5, 10);SetBuf(font.char[132].buffer);Put1(005X);Put1(00AX);Put1(00FX);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(01EX);Put1(000X);Put1(012X);Put1(012X);
		Dimensions(font.char[133], 7, 1, 0, 5, 10);SetBuf(font.char[133].buffer);Put1(005X);Put1(00AX);Put1(017X);Put1(019X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(000X);Put1(00AX);Put1(00AX);
		Dimensions(font.char[134], 6, 1, 0, 4, 10);SetBuf(font.char[134].buffer);Put1(004X);Put1(00AX);Put1(00BX);Put1(009X);Put1(009X);Put1(00EX);Put1(008X);Put1(009X);Put1(00EX);Put1(000X);Put1(009X);Put1(006X);
		Dimensions(font.char[135], 6, 1, 0, 4, 10);SetBuf(font.char[135].buffer);Put1(004X);Put1(00AX);Put1(007X);Put1(009X);Put1(001X);Put1(00FX);Put1(009X);Put1(009X);Put1(00EX);Put1(000X);Put1(009X);Put1(006X);
		Dimensions(font.char[136], 3, 0, 0, 3, 10);SetBuf(font.char[136].buffer);Put1(003X);Put1(00AX);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(000X);Put1(005X);Put1(002X);
		Dimensions(font.char[137], 7, 1, 0, 5, 10);SetBuf(font.char[137].buffer);Put1(005X);Put1(00AX);Put1(00FX);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(01EX);Put1(000X);Put1(011X);Put1(00EX);
		Dimensions(font.char[138], 7, 1, 0, 5, 10);SetBuf(font.char[138].buffer);Put1(005X);Put1(00AX);Put1(017X);Put1(019X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(000X);Put1(011X);Put1(00EX);
		Dimensions(font.char[139], 6, 1, 0, 4, 10);SetBuf(font.char[139].buffer);Put1(004X);Put1(00AX);Put1(00BX);Put1(009X);Put1(009X);Put1(00EX);Put1(008X);Put1(009X);Put1(00EX);Put1(000X);Put1(004X);Put1(002X);
		Dimensions(font.char[140], 6, 1, 0, 4, 10);SetBuf(font.char[140].buffer);Put1(004X);Put1(00AX);Put1(007X);Put1(009X);Put1(001X);Put1(00FX);Put1(009X);Put1(009X);Put1(00EX);Put1(000X);Put1(004X);Put1(002X);
		Dimensions(font.char[141], 3, 0, 0, 2, 10);SetBuf(font.char[141].buffer);Put1(002X);Put1(00AX);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(000X);Put1(002X);Put1(001X);
		Dimensions(font.char[142], 7, 1, 0, 5, 10);SetBuf(font.char[142].buffer);Put1(005X);Put1(00AX);Put1(00FX);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(01EX);Put1(000X);Put1(004X);Put1(002X);
		Dimensions(font.char[143], 7, 1, 0, 5, 10);SetBuf(font.char[143].buffer);Put1(005X);Put1(00AX);Put1(017X);Put1(019X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(000X);Put1(004X);Put1(002X);
		Dimensions(font.char[144], 6, 1, 0, 4, 10);SetBuf(font.char[144].buffer);Put1(004X);Put1(00AX);Put1(007X);Put1(009X);Put1(001X);Put1(00FX);Put1(009X);Put1(009X);Put1(006X);Put1(000X);Put1(004X);Put1(008X);
		Dimensions(font.char[145], 6, 1, 0, 4, 10);SetBuf(font.char[145].buffer);Put1(004X);Put1(00AX);Put1(007X);Put1(009X);Put1(001X);Put1(00FX);Put1(009X);Put1(009X);Put1(006X);Put1(000X);Put1(009X);Put1(009X);
		Dimensions(font.char[146], 3, 0, 0, 3, 10);SetBuf(font.char[146].buffer);Put1(003X);Put1(00AX);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(002X);Put1(000X);Put1(005X);Put1(005X);
		Dimensions(font.char[147], 5, 1, -4, 4, 11);SetBuf(font.char[147].buffer);Put1(004X);Put1(00BX);Put1(002X);Put1(004X);Put1(006X);Put1(000X);Put1(007X);Put1(009X);Put1(001X);Put1(001X);Put1(001X);Put1(001X);Put1(00EX);
		Dimensions(font.char[148], 6, 1, 0, 4, 10);SetBuf(font.char[148].buffer);Put1(004X);Put1(00AX);Put1(00BX);Put1(009X);Put1(009X);Put1(00EX);Put1(008X);Put1(009X);Put1(00EX);Put1(000X);Put1(004X);Put1(008X);
		Dimensions(font.char[149], 7, 1, 0, 5, 10);SetBuf(font.char[149].buffer);Put1(005X);Put1(00AX);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(011X);Put1(013X);Put1(01DX);Put1(000X);Put1(00DX);Put1(016X);
		Dimensions(font.char[150], 7, 1, 0, 5, 10);SetBuf(font.char[150].buffer);Put1(005X);Put1(00AX);Put1(00DX);Put1(011X);Put1(011X);Put1(011X);Put1(009X);Put1(005X);Put1(005X);Put1(009X);Put1(009X);Put1(006X);
		Dimensions(font.char[151], 12, 0, -3, 12, 12);font.char[151].buffer := font.char[1].buffer;
		Dimensions(font.char[152], 12, 0, -3, 12, 12);font.char[152].buffer := font.char[1].buffer;
		Dimensions(font.char[153], 12, 0, -3, 12, 12);font.char[153].buffer := font.char[1].buffer;
		Dimensions(font.char[154], 12, 0, -3, 12, 12);font.char[154].buffer := font.char[1].buffer;
		Dimensions(font.char[155], 8, 0, 3, 8, 1);SetBuf(font.char[155].buffer);Put1(008X);Put1(001X);Put1(0FFX);
		Dimensions(font.char[156], 12, 0, -3, 12, 12);font.char[156].buffer := font.char[1].buffer;
		Dimensions(font.char[157], 12, 0, -3, 12, 12);font.char[157].buffer := font.char[1].buffer;
		Dimensions(font.char[158], 12, 0, -3, 12, 12);font.char[158].buffer := font.char[1].buffer;
		Dimensions(font.char[159], 7, 0, 0, 0, 0);SetBuf(font.char[159].buffer);Put1(000X);Put1(000X);
		Dimensions(font.char[160], 12, 0, -3, 12, 12);font.char[160].buffer := font.char[1].buffer;
		Dimensions(font.char[161], 12, 0, -3, 12, 12);font.char[161].buffer := font.char[1].buffer;
		Dimensions(font.char[162], 12, 0, -3, 12, 12);font.char[162].buffer := font.char[1].buffer;
		Dimensions(font.char[163], 12, 0, -3, 12, 12);font.char[163].buffer := font.char[1].buffer;
		Dimensions(font.char[164], 12, 0, -3, 12, 12);font.char[164].buffer := font.char[1].buffer;
		Dimensions(font.char[165], 12, 0, -3, 12, 12);font.char[165].buffer := font.char[1].buffer;
		Dimensions(font.char[166], 12, 0, -3, 12, 12);font.char[166].buffer := font.char[1].buffer;
		Dimensions(font.char[167], 12, 0, -3, 12, 12);font.char[167].buffer := font.char[1].buffer;
		Dimensions(font.char[168], 12, 0, -3, 12, 12);font.char[168].buffer := font.char[1].buffer;
		Dimensions(font.char[169], 12, 0, -3, 12, 12);font.char[169].buffer := font.char[1].buffer;
		Dimensions(font.char[170], 12, 0, -3, 12, 12);font.char[170].buffer := font.char[1].buffer;
		Dimensions(font.char[171], 12, 0, -3, 12, 12);font.char[171].buffer := font.char[1].buffer;
		Dimensions(font.char[172], 12, 0, -3, 12, 12);font.char[172].buffer := font.char[1].buffer;
		Dimensions(font.char[173], 12, 0, -3, 12, 12);font.char[173].buffer := font.char[1].buffer;
		Dimensions(font.char[174], 12, 0, -3, 12, 12);font.char[174].buffer := font.char[1].buffer;
		Dimensions(font.char[175], 12, 0, -3, 12, 12);font.char[175].buffer := font.char[1].buffer;
		Dimensions(font.char[176], 12, 0, -3, 12, 12);font.char[176].buffer := font.char[1].buffer;
		Dimensions(font.char[177], 12, 0, -3, 12, 12);font.char[177].buffer := font.char[1].buffer;
		Dimensions(font.char[178], 12, 0, -3, 12, 12);font.char[178].buffer := font.char[1].buffer;
		Dimensions(font.char[179], 12, 0, -3, 12, 12);font.char[179].buffer := font.char[1].buffer;
		Dimensions(font.char[180], 12, 0, -3, 12, 12);font.char[180].buffer := font.char[1].buffer;
		Dimensions(font.char[181], 12, 0, -3, 12, 12);font.char[181].buffer := font.char[1].buffer;
		Dimensions(font.char[182], 12, 0, -3, 12, 12);font.char[182].buffer := font.char[1].buffer;
		Dimensions(font.char[183], 12, 0, -3, 12, 12);font.char[183].buffer := font.char[1].buffer;
		Dimensions(font.char[184], 12, 0, -3, 12, 12);font.char[184].buffer := font.char[1].buffer;
		Dimensions(font.char[185], 12, 0, -3, 12, 12);font.char[185].buffer := font.char[1].buffer;
		Dimensions(font.char[186], 12, 0, -3, 12, 12);font.char[186].buffer := font.char[1].buffer;
		Dimensions(font.char[187], 12, 0, -3, 12, 12);font.char[187].buffer := font.char[1].buffer;
		Dimensions(font.char[188], 12, 0, -3, 12, 12);font.char[188].buffer := font.char[1].buffer;
		Dimensions(font.char[189], 12, 0, -3, 12, 12);font.char[189].buffer := font.char[1].buffer;
		Dimensions(font.char[190], 12, 0, -3, 12, 12);font.char[190].buffer := font.char[1].buffer;
		Dimensions(font.char[191], 12, 0, -3, 12, 12);font.char[191].buffer := font.char[1].buffer;
		Dimensions(font.char[192], 12, 0, -3, 12, 12);font.char[192].buffer := font.char[1].buffer;
		Dimensions(font.char[193], 12, 0, -3, 12, 12);font.char[193].buffer := font.char[1].buffer;
		Dimensions(font.char[194], 12, 0, -3, 12, 12);font.char[194].buffer := font.char[1].buffer;
		Dimensions(font.char[195], 12, 0, -3, 12, 12);font.char[195].buffer := font.char[1].buffer;
		Dimensions(font.char[196], 12, 0, -3, 12, 12);font.char[196].buffer := font.char[1].buffer;
		Dimensions(font.char[197], 12, 0, -3, 12, 12);font.char[197].buffer := font.char[1].buffer;
		Dimensions(font.char[198], 12, 0, -3, 12, 12);font.char[198].buffer := font.char[1].buffer;
		Dimensions(font.char[199], 12, 0, -3, 12, 12);font.char[199].buffer := font.char[1].buffer;
		Dimensions(font.char[200], 12, 0, -3, 12, 12);font.char[200].buffer := font.char[1].buffer;
		Dimensions(font.char[201], 12, 0, -3, 12, 12);font.char[201].buffer := font.char[1].buffer;
		Dimensions(font.char[202], 12, 0, -3, 12, 12);font.char[202].buffer := font.char[1].buffer;
		Dimensions(font.char[203], 12, 0, -3, 12, 12);font.char[203].buffer := font.char[1].buffer;
		Dimensions(font.char[204], 12, 0, -3, 12, 12);font.char[204].buffer := font.char[1].buffer;
		Dimensions(font.char[205], 12, 0, -3, 12, 12);font.char[205].buffer := font.char[1].buffer;
		Dimensions(font.char[206], 12, 0, -3, 12, 12);font.char[206].buffer := font.char[1].buffer;
		Dimensions(font.char[207], 12, 0, -3, 12, 12);font.char[207].buffer := font.char[1].buffer;
		Dimensions(font.char[208], 12, 0, -3, 12, 12);font.char[208].buffer := font.char[1].buffer;
		Dimensions(font.char[209], 12, 0, -3, 12, 12);font.char[209].buffer := font.char[1].buffer;
		Dimensions(font.char[210], 12, 0, -3, 12, 12);font.char[210].buffer := font.char[1].buffer;
		Dimensions(font.char[211], 12, 0, -3, 12, 12);font.char[211].buffer := font.char[1].buffer;
		Dimensions(font.char[212], 12, 0, -3, 12, 12);font.char[212].buffer := font.char[1].buffer;
		Dimensions(font.char[213], 12, 0, -3, 12, 12);font.char[213].buffer := font.char[1].buffer;
		Dimensions(font.char[214], 12, 0, -3, 12, 12);font.char[214].buffer := font.char[1].buffer;
		Dimensions(font.char[215], 12, 0, -3, 12, 12);font.char[215].buffer := font.char[1].buffer;
		Dimensions(font.char[216], 12, 0, -3, 12, 12);font.char[216].buffer := font.char[1].buffer;
		Dimensions(font.char[217], 12, 0, -3, 12, 12);font.char[217].buffer := font.char[1].buffer;
		Dimensions(font.char[218], 12, 0, -3, 12, 12);font.char[218].buffer := font.char[1].buffer;
		Dimensions(font.char[219], 12, 0, -3, 12, 12);font.char[219].buffer := font.char[1].buffer;
		Dimensions(font.char[220], 12, 0, -3, 12, 12);font.char[220].buffer := font.char[1].buffer;
		Dimensions(font.char[221], 12, 0, -3, 12, 12);font.char[221].buffer := font.char[1].buffer;
		Dimensions(font.char[222], 12, 0, -3, 12, 12);font.char[222].buffer := font.char[1].buffer;
		Dimensions(font.char[223], 12, 0, -3, 12, 12);font.char[223].buffer := font.char[1].buffer;
		Dimensions(font.char[224], 12, 0, -3, 12, 12);font.char[224].buffer := font.char[1].buffer;
		Dimensions(font.char[225], 12, 0, -3, 12, 12);font.char[225].buffer := font.char[1].buffer;
		Dimensions(font.char[226], 12, 0, -3, 12, 12);font.char[226].buffer := font.char[1].buffer;
		Dimensions(font.char[227], 12, 0, -3, 12, 12);font.char[227].buffer := font.char[1].buffer;
		Dimensions(font.char[228], 12, 0, -3, 12, 12);font.char[228].buffer := font.char[1].buffer;
		Dimensions(font.char[229], 12, 0, -3, 12, 12);font.char[229].buffer := font.char[1].buffer;
		Dimensions(font.char[230], 12, 0, -3, 12, 12);font.char[230].buffer := font.char[1].buffer;
		Dimensions(font.char[231], 12, 0, -3, 12, 12);font.char[231].buffer := font.char[1].buffer;
		Dimensions(font.char[232], 12, 0, -3, 12, 12);font.char[232].buffer := font.char[1].buffer;
		Dimensions(font.char[233], 12, 0, -3, 12, 12);font.char[233].buffer := font.char[1].buffer;
		Dimensions(font.char[234], 12, 0, -3, 12, 12);font.char[234].buffer := font.char[1].buffer;
		Dimensions(font.char[235], 12, 0, -3, 12, 12);font.char[235].buffer := font.char[1].buffer;
		Dimensions(font.char[236], 12, 0, -3, 12, 12);font.char[236].buffer := font.char[1].buffer;
		Dimensions(font.char[237], 12, 0, -3, 12, 12);font.char[237].buffer := font.char[1].buffer;
		Dimensions(font.char[238], 12, 0, -3, 12, 12);font.char[238].buffer := font.char[1].buffer;
		Dimensions(font.char[239], 12, 0, -3, 12, 12);font.char[239].buffer := font.char[1].buffer;
		Dimensions(font.char[240], 12, 0, -3, 12, 12);font.char[240].buffer := font.char[1].buffer;
		Dimensions(font.char[241], 12, 0, -3, 12, 12);font.char[241].buffer := font.char[1].buffer;
		Dimensions(font.char[242], 12, 0, -3, 12, 12);font.char[242].buffer := font.char[1].buffer;
		Dimensions(font.char[243], 12, 0, -3, 12, 12);font.char[243].buffer := font.char[1].buffer;
		Dimensions(font.char[244], 12, 0, -3, 12, 12);font.char[244].buffer := font.char[1].buffer;
		Dimensions(font.char[245], 12, 0, -3, 12, 12);font.char[245].buffer := font.char[1].buffer;
		Dimensions(font.char[246], 12, 0, -3, 12, 12);font.char[246].buffer := font.char[1].buffer;
		Dimensions(font.char[247], 12, 0, -3, 12, 12);font.char[247].buffer := font.char[1].buffer;
		Dimensions(font.char[248], 12, 0, -3, 12, 12);font.char[248].buffer := font.char[1].buffer;
		Dimensions(font.char[249], 12, 0, -3, 12, 12);font.char[249].buffer := font.char[1].buffer;
		Dimensions(font.char[250], 12, 0, -3, 12, 12);font.char[250].buffer := font.char[1].buffer;
		Dimensions(font.char[251], 12, 0, -3, 12, 12);font.char[251].buffer := font.char[1].buffer;
		Dimensions(font.char[252], 12, 0, -3, 12, 12);font.char[252].buffer := font.char[1].buffer;
		Dimensions(font.char[253], 12, 0, -3, 12, 12);font.char[253].buffer := font.char[1].buffer;
		Dimensions(font.char[254], 12, 0, -3, 12, 12);font.char[254].buffer := font.char[1].buffer;
		Dimensions(font.char[255], 12, 0, -3, 12, 12);font.char[255].buffer := font.char[1].buffer;
	END MakeFont;



	PROCEDURE Mask(buf: ADDRESS; bitof, stride, x, y, w, h, adr, dstride, depth: SIZE);
	CONST SetSize = MAX (SET) + 1;
	VAR p, i, dadr: ADDRESS; s: SET; space,d: LONGINT; bitofs: SIZE;
	BEGIN
		IF (w > 0) & (h > 0) THEN
			i := buf MOD SIZEOF (SET);
			bitofs := bitof + i * 8;
			p := buf-i + bitofs DIV SetSize * SIZEOF (SET);	(* p always aligned to 32-bit boundary *)
			bitofs := bitofs MOD SetSize; stride := stride*8;
			LOOP
				SYSTEM.GET(p, s); i := bitofs;
				LOOP
					IF (i MOD SetSize) IN s THEN
						dadr := adr+(y*dstride+(x+i-bitofs)*depth);
						FOR d := 0 TO depth-1 DO
							SYSTEM.PUT8(dadr+d,0FFH);
						END;
					END;
					INC(i);
					IF i-bitofs = w THEN EXIT END;
					IF i MOD SetSize = 0 THEN SYSTEM.GET(p+i DIV 8, s) END
				END;
				DEC(h);
				IF h = 0 THEN EXIT END;
				INC(y); INC(bitofs, stride);
				IF (bitofs >= SetSize) OR (bitofs < 0) THEN	(* moved outside s *)
					INC(p, bitofs DIV SetSize * SIZEOF (SET)); bitofs := bitofs MOD SetSize
				END
			END
		END
	END Mask;


	PROCEDURE RenderChar0(c: CHAR; adr: ADDRESS; VAR x,y: SIZE; w,h,depth: SIZE );
	VAR char: Char; stride,pw,ph: LONGINT;

		PROCEDURE Scroll;
		VAR x0,y0: ADDRESS; val: CHAR; sadr,dadr: ADDRESS;
		BEGIN
			FOR y0 := font.height TO y+font.height-1 DO
				sadr := adr + y0*w*depth DIV 8;
				dadr := adr + (y0-font.height)*w*depth DIV 8;
				FOR x0 := 0 TO w*depth DIV 8-1 DO
					SYSTEM.GET(sadr+x0,val);
					SYSTEM.PUT(dadr+x0,val);
				END;
			END;
			FOR y0 := y+1 TO h-1 DO
				dadr := adr + y0*w*depth DIV 8;
				FOR x0 := 0 TO w*depth DIV 8-1 DO
					SYSTEM.PUT(dadr+x0, 0);
				END;
			END;
		END Scroll;

	BEGIN
		IF c = 0DX THEN
			 x := 0;
		ELSIF c = 0AX THEN
			IF y + 2*font.height >= h THEN
				Scroll;
			ELSE
				INC(y, font.height);
			END;
		ELSE
			char := font.char[ORD(c)];
			IF (char.w > 0) & (char.h>0) & (x+char.x < w) THEN
				pw := SYSTEM.GET8(char.buffer);
				ph := SYSTEM.GET8(char.buffer+1);
				stride := (pw + 7) DIV 8;
				Mask(char.buffer, 16+stride*(char.h-1)*8, -stride, x+char.x, y+font.height-char.y-char.h, char.w, char.h, adr, w*depth DIV 8, depth DIV 8)
			END;
			INC(x,char.dx);
		END;
	END RenderChar0;


	PROCEDURE RenderChar(c: CHAR);
	BEGIN
		RenderChar0(c, adr,x,y,w,h,depth);
	END RenderChar;

	PROCEDURE GetDepth(info: GraphicsModeInfo): LONGINT; (* depth in bits *)
	VAR mask, depth: LONGINT;
	BEGIN
		CASE info.PixelFormat OF
			PFRGBX8Bit, PFBGRX8Bit :
				depth := 32
			| PFBitMask :
				mask := info.PixelBitmask.RedMask + info.PixelBitmask.GreenMask + info.PixelBitmask.BlueMask;
				depth := 0;
				WHILE mask # 0 DO mask := LSH(mask,-1); INC(depth); END;
			| PFBltOnly :
				depth := 0;
		END;
		RETURN depth
	END GetDepth;

	PROCEDURE SetupConsole*(graphicsModeInfo: ADDRESS; frameBufferAdr: ADDRESS);
	VAR i: ADDRESS;
	VAR tmp: HUGEINT;
	BEGIN
		Trace.String("Graphical Console, info = "); Trace.Address(graphicsModeInfo); Trace.Ln;
		Trace.String("Graphical Console, address = "); Trace.Address(frameBufferAdr); Trace.Ln;
		info := SYSTEM.VAL(GraphicsModeInfo, graphicsModeInfo);

		FOR i := 0 TO 9 DO
			SYSTEM.GET(graphicsModeInfo+i*8,tmp);
			Trace.Hex(tmp,8);
			Trace.Ln;
		END;
		adr := frameBufferAdr;
		x := 0; y := 0; w := info.HorizontalResolution; h :=  info.VerticalResolution; depth := GetDepth(info);
		Trace.String("Graphical Console, w = "); Trace.Address(w); Trace.Ln;
		Trace.String("Graphical Console, h = "); Trace.Address(h); Trace.Ln;
		Trace.String("Graphical Console, depth = "); Trace.Address(depth); Trace.Ln;

		FOR i := 0 TO w*h*depth DIV 8-1 DO SYSTEM.PUT(adr+i,0)	END;
		RenderChar("X"); RenderChar("X");
		Trace.Char := RenderChar;
		Trace.String("Graphical Console started"); Trace.Ln;
	END SetupConsole;


BEGIN
	Trace.String("Graphical Console Enter"); Trace.Ln;
	MakeFont(font);
	Trace.String("Graphical Console Exit"); Trace.Ln;
END EFIGraphicalConsole.



~~~
The following module can be used to generate font for console (Oberon grey box must be started).



MODULE GenerateFont; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Files, Commands, SYSTEM, Fonts IN Oberon, Display IN Oberon, Streams, D := Debugging;

CONST debug = TRUE;
VAR out: Streams.Writer;
TYPE
	PatternPtr = POINTER TO RECORD
		buf: ARRAY 8192 OF CHAR	(* w = buf[0], h = buf[1], pixmap = buf[2..] *)
	END;

	Char = RECORD
		dx*,x*,y*,w*,h*: INTEGER;
		pat*: POINTER TO ARRAY OF CHAR;
	END;

	Font = RECORD
		height*, minX*, maxX*, minY*, maxY*: INTEGER;
		char: ARRAY 256 OF Char
	END;

PROCEDURE Do*(context: Commands.Context);
VAR
	name: ARRAY 64 OF CHAR; l,i: LONGINT; file: Files.File; r: Files.Reader; font: Fonts.Font; p: PatternPtr;
	pw, ph,stride: LONGINT;
	dx,dy,x,y,w,h: INTEGER;
	dx2,dy2,x2,y2,w2,h2: INTEGER;
	pat,pat2: Display.Pattern; j: LONGINT; done: BOOLEAN; len: LONGINT;

	PROCEDURE Mask(VAR buf: ARRAY OF CHAR; bitof, stride, x, y, w, h: LONGINT);
	CONST SetSize = MAX (SET) + 1;
	VAR p, i, bitofs: ADDRESS; s: SET;
	BEGIN
		IF (w > 0) & (h > 0) THEN
			i := ADDRESSOF(buf[0]) MOD SIZEOF (SET);
			bitofs := bitof + i * 8;
			p := ADDRESSOF(buf[0])-i + bitofs DIV SetSize * SIZEOF (SET);	(* p always aligned to 32-bit boundary *)
			bitofs := bitofs MOD SetSize; stride := stride*8;
			LOOP
				SYSTEM.GET(p, s); i := bitofs;
				LOOP
					IF (i MOD SetSize) IN s THEN
						D.String("*") ELSE D.String("-") END;
					INC(i);
					IF i-bitofs = w THEN EXIT END;
					IF i MOD SetSize = 0 THEN SYSTEM.GET(p+i DIV 8, s) END
				END;
				D.Ln;
				DEC(h);
				IF h = 0 THEN EXIT END;
				INC(y); INC(bitofs, stride);
				IF (bitofs >= SetSize) OR (bitofs < 0) THEN	(* moved outside s *)
					INC(p, bitofs DIV SetSize * SIZEOF (SET)); bitofs := bitofs MOD SetSize
				END
			END
		END
	END Mask;

	PROCEDURE WriteChar(i: LONGINT);
	BEGIN
		context.out.String("font.char["); context.out.Int(i,1); context.out.String("]");
		out.Update;
	END WriteChar;


BEGIN
	out := context.out;
	IF context.arg.GetString(name) THEN
		font := Fonts.This(name);
		(*
		out.String("PROCEDURE MakeFont(VAR font: Font);"); out.Ln;
		out.String("VAR buf: Buffer; pos: LONGINT;");out.Ln;
		out.String("PROCEDURE SetBuf(VAR p: Buffer); BEGIN p := ADDRESSOF(buffer[pos]) END SetBuf;"); out.Ln;
		out.String("PROCEDURE Put1(ch: CHAR); BEGIN buffer[pos] := ch; INC(pos) END Put1;"); out.Ln;
		out.String("PROCEDURE Dimensions(VAR char: Char; dx,x,y,w,h: INTEGER); BEGIN char.dx := dx; char.x := x; char.y := y; char.w := w; char.h := h END Dimensions;"); out.Ln;
		out.String("BEGIN");out.Ln;
		*)
		out.String("font.height := "); out.Int(font.height,1); out.String(";"); out.Ln;
		out.String("font.minX := "); out.Int(font.minX,1); out.String(";");out.Ln;
		out.String("font.maxX := "); out.Int(font.maxX,1); out.String(";");out.Ln;
		out.String("font.minY := "); out.Int(font.minY,1); out.String(";");out.Ln;
		out.String("font.maxY := "); out.Int(font.maxY,1); out.String(";");out.Ln;
		len := 0;

		FOR i := 0 TO 255 DO
		Fonts.GetChar(font, CHR(i), dx, x, y, w,h,pat);
		p := SYSTEM.VAL(PatternPtr, pat);
		pw := ORD(p.buf[0]); ph := ORD(p.buf[1]);
		out.String("Dimensions("); WriteChar(i); out.String(", ");
		out.Int(dx,1);out.String(", ");
		out.Int(x,1);out.String(", ");
		out.Int(y,1);out.String(", ");
		out.Int(w,1);out.String(", ");
		out.Int(h,1); out.String(");");
		stride := (pw + 7) DIV 8;
		done := FALSE;
		j := 0;
		WHILE ~done & (j<i) DO
			Fonts.GetChar(font, CHR(j), dx2, x2, y2, w2,h2,pat2);
			IF pat2 = pat THEN
				done := TRUE;
				WriteChar(i); out.String(".buffer := "); WriteChar(j); out.String(".buffer;"); out.Ln;
			END;
			INC(j);
		END;
		IF ~done THEN
			out.String("SetBuf("); WriteChar(i); out.String(".buffer);");
			FOR j := 0 TO h*stride-1 +2  DO
				INC(len);
				out.String("Put1("); out.Hex(ORD(p.buf[j]),-3); out.String("X);");
			END;out.Ln;
		END;

		IF debug THEN Mask(p.buf, 16+(ph-1)*stride*8,-stride, x, h-y-ph, pw,ph) END;

		END;
		(* out.String("END MakeFont;"); *)
		out.Ln;

		out.String("VAR buffer: ARRAY "); out.Int(len,1); out.String(" OF CHAR"); out.Ln;
	END;
END Do;

END GenerateFont.
