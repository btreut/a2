(** AUTHOR "Christian Wassmer, chwassme@student.ethz.ch";
	 PURPOSE "utility functions and classes for OGGVorbisPlayer.Mod";
	 DATE "Avril 2004" *)
MODULE OGGUtilities;

IMPORT
	SYSTEM, Strings, Files,  KernelLog, SoundDevices, BIT;

CONST
	(* debugging set *)
	Trace = 1;
	Error = 2;
	Debug =  {Error};

	MaxCodewordLength* = 33;
	MaxBlocksize* = 8192;

	NoHuffmanLeaf = -1;
	(* HuffmanNode directions *)
	GoLeft = 0; GoRight = 1;
	BaseVectorSize = 256;

	(* fraction of fix-point numbers; must be even *)
	Nx* = 20;

VAR
	f: Files.File;
	w*: Files.Writer;
	Ny: LONGINT;
	ScaleFactor: HUGEINT;

TYPE
	(** object for holding PCM buffer data (may also be used for floor-data (24 bits)) *)
	PCMBuffer* = OBJECT
		VAR data*: ARRAY MaxBlocksize OF HUGEINT;

		PROCEDURE Print*(name: ARRAY OF CHAR; len: LONGINT);
		BEGIN
			ArrayHugeLen(name, data, len)
		END Print;

		PROCEDURE PrintShort(name: ARRAY OF CHAR; len: LONGINT);
		VAR
			tmp: POINTER TO ARRAY  OF LONGINT;
			i: LONGINT;
		BEGIN
			NEW(tmp,len);
			FOR  i := 0 TO len - 1 DO
				tmp[i] := SHORT(data[i])
			END;
			ArrayLen(name, tmp^, len);
		END PrintShort;

		(** set whole buffer to 0 *)
		PROCEDURE ZeroBuffer*;
		VAR i: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN String("@VorbisCodec::PCMBuffer::ZeroBuffer()") END;
			FOR i := 0 TO LEN(data) - 1 DO
				data[i] := 0
			END
		END ZeroBuffer;
	END PCMBuffer;

	(** entry-point for a HuffmanTree *)
	HuffmanTree* = OBJECT
		VAR start-: HuffmanNode;

		PROCEDURE &Init*;
		BEGIN
			NEW(start, NoHuffmanLeaf, FALSE, FALSE)
		END Init;

		(** insert the HuffmanNode correspond to the codeword with the value *)
		PROCEDURE AddNode(value, length, codeword: LONGINT);
		BEGIN
			IF (Trace IN Debug) THEN
				String("@MyUtilities::HuffmanTree::AddNode()")
			END;
			start.AddNode(value, length, codeword)
		END AddNode;

		(** check if the length list represents a valid huffman-tree *)
		PROCEDURE IsValidLengthList*(VAR list: IntList; unused: LONGINT): BOOLEAN;
		VAR limit, sum: HUGEINT;
		BEGIN
			IF (Trace IN Debug) THEN
				String("@MyUtilities::HuffmanTree::IsValidLengthList()")
			END;
			GetSumAndLimit(list, sum, limit, unused);
			(* both under- and overspecified huffman-trees are not allowed *)
			RETURN (sum = limit)
		END IsValidLengthList;

		(** check if the list of length represents an overspecified huffman-tree *)
		PROCEDURE IsOverspecified*(VAR list: IntList; unused: LONGINT): BOOLEAN;
		VAR limit, sum: HUGEINT;
		BEGIN
			GetSumAndLimit(list, sum, limit, unused);
			RETURN (sum > limit)
		END IsOverspecified;

		(** check if the list of length represents an underspecified huffman-tree *)
		PROCEDURE IsUnderspecified*(VAR list: IntList; unused: LONGINT): BOOLEAN;
		VAR limit, sum: HUGEINT;
		BEGIN
			GetSumAndLimit(list, sum, limit, unused);
			RETURN (sum > limit)
		END IsUnderspecified;

		(* background: Kraft-McMillan's Theorem - sum(1,n, 1 / (2^l[i])) <= 1  <=> l[i] represents a valid HuffmanTree *)
		PROCEDURE GetSumAndLimit(VAR list: IntList; VAR sum, limit: HUGEINT; unused: LONGINT);
		VAR
			i: HUGEINT;
			cur: ListElement;
		BEGIN
			limit := PowerH(2, MaxCodewordLength);
			sum := 0;
			cur := list.start;
			FOR i := 0 TO list.length - 1 DO
				IF (cur(IntElement).long # unused) THEN (* is it valid length *)
					sum := sum + PowerH(2, MaxCodewordLength - cur(IntElement).long);
				END;
				cur := cur.next
			END
		END GetSumAndLimit;

		(* check wether the list has any used entries *)
		PROCEDURE HasUsedEntries*(VAR list: IntList; unused: LONGINT): BOOLEAN;
		VAR
			i: HUGEINT;
			cur: ListElement;
		BEGIN
			cur := list.start;
			FOR i := 0 TO list.length - 1 DO
				IF (cur(IntElement).long # unused) THEN RETURN TRUE END
			END;
			RETURN FALSE (* list has only unused codebook entries *)
		END HasUsedEntries;

		(** build a HuffmanTree from a IntList, return FALSE if not possible, else TRUE *)
		PROCEDURE BuildTree*(VAR lengths: IntList; VAR codes: IntList; unused: LONGINT);
		VAR
			value: LONGINT;
			curLen, curCode: IntElement;
		BEGIN
			IF (Trace IN Debug) THEN String("@MyUtilities::HuffmanTree::BuildTree()") END;
			curLen := lengths.start(IntElement);
			curCode := codes.start(IntElement);

			value := 0;
			WHILE (curLen # NIL) DO
				(* if it's a used codeword-entry *)
				IF (curLen.long # unused) THEN
					AddNode(value, curLen.long, curCode.long);
					IF (curCode.next # NIL) THEN curCode := curCode.next(IntElement) END
				END; (* else do nothing special*)
				INC(value);
				IF (curLen.next # NIL) THEN curLen := curLen.next(IntElement) ELSE curLen := NIL END
			END
		END BuildTree;

		(** get left or rigth son (as a VAR-parameter) depending on the input (0/1) during Hufman-decode-process
				(it's up to the clients to decide wether a codeword/leaf has been found or not *)
		PROCEDURE GoLeftOrRight*(VAR node: HuffmanNode; bit: LONGINT);
		BEGIN
			IF ((bit # 0) & (bit # 1)) THEN
				KernelLog.String("ASSERTION failed - bit is not 0 or 1"); KernelLog.Ln
			END;
			ASSERT((bit = 0) OR (bit = 1));
			IF (bit = GoLeft) THEN
				node := node.left
			ELSIF (bit = GoRight) THEN
				node := node.right
			END
		END GoLeftOrRight;

		PROCEDURE Print;
		BEGIN
			String("(inorder, *: isFull)");
			IF ~(start = NIL) THEN start.Print() END;
			String("")
		END Print;
	END HuffmanTree;

	(* node containing references to theirs sons and a value representing the decoded codeword *)
	HuffmanNode* = OBJECT
		VAR
			left, right: HuffmanNode;
			value: LONGINT;
			isLeaf, isFull: BOOLEAN; (* isLeaf only used for Print() *)

		PROCEDURE &Init*(value: LONGINT; isLeaf, isFull: BOOLEAN);
		BEGIN
			left := NIL; right := NIL;
			SELF.value := value;
			SELF.isFull := isFull;
			SELF.isLeaf := isLeaf
		END Init;

		(** get the value *)
		PROCEDURE GetValue*(): LONGINT;
		BEGIN
			RETURN value
		END GetValue;

		(** is this node a leaf <=> valid codeword *)
		PROCEDURE IsLeaf*(): BOOLEAN;
		BEGIN
			RETURN isLeaf
		END IsLeaf;

		(** print tree to console in inorder *)
		PROCEDURE Print;
		BEGIN
			IF (left # NIL) THEN left.Print() END;
			w.String("[");
			IF isLeaf THEN w.Int(value, 1) ELSE w.String(".") END;
			IF isFull THEN w.String("*") END;
			w.String("]");
			IF (right # NIL) THEN right.Print() END
		END Print;

		PROCEDURE AddNode(value, length, restCodeword: LONGINT);
		VAR
			digit: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN
				String("@MyUtilities::HuffmanNode::AddNode()")
			END;
			(* we read our codewords from MSb to LSb *)
			digit := LSH(restCodeword, -(length - 1)); (* we need the length-rightmost bits: right shift of length-1 *)
			restCodeword := restCodeword MOD Power(2, length - 1); (* only the (length-1)rightmost bits are used *)

			IF (length = 1) THEN
				(* recursion base *)
				IF (digit = GoLeft) THEN
					NEW(left, value, TRUE, TRUE)
				ELSIF (digit = GoRight) THEN
					NEW(right, value, TRUE, TRUE)
				END
			ELSE
				(* recursion step *)
				IF (digit = GoLeft) THEN
					IF (left = NIL) THEN NEW(left, NoHuffmanLeaf, FALSE, FALSE) END;
					left.AddNode(value, length - 1, restCodeword)
				ELSIF (digit = GoRight) THEN
					IF (right = NIL) THEN NEW(right, NoHuffmanLeaf, FALSE, FALSE) END;
					right.AddNode(value, length - 1, restCodeword)
				END
			END
		END AddNode;
	END HuffmanNode;

	(** data-structure for holding a number of (BaseVectorSize) longint data *)
	Vector* = OBJECT
		VAR
			capacity, len: LONGINT;
			data: ARRAY BaseVectorSize OF HUGEINT;

		PROCEDURE &Init*;
		BEGIN
			len := 0;
			capacity := BaseVectorSize
		END Init;

		PROCEDURE Print*;
		BEGIN
			ArrayHugeLen("vector", data, len);
		END Print;

		(** add a value at the end *)
		PROCEDURE Add*(value: HUGEINT);
		BEGIN
			IF (len >= capacity) THEN
				KernelLog.String("ASSERTION failed - vector exceeds size"); KernelLog.Ln
			END;
			ASSERT(len < capacity);
			data[len] := value;
			INC(len)
		END Add;

		(** increase each value by inc *)
		PROCEDURE Increase(inc: HUGEINT);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO len - 1 DO
				INC(data[i], inc)
			END
		END Increase;

		(** get the length *)
		PROCEDURE GetLen(): LONGINT;
		BEGIN
			RETURN len
		END GetLen;

		(** get the last element *)
		PROCEDURE GetLast(): HUGEINT;
		BEGIN
			RETURN data[len]
		END GetLast;

		(** get value at a certain position *)
		PROCEDURE GetValueAt*(idx: LONGINT): HUGEINT;
		BEGIN
			IF (idx >= len) THEN
				KernelLog.String("ASSERTION failed - access to invalid vector element"); KernelLog.Ln
			END;
			ASSERT(idx < len);
			RETURN data[idx]
		END GetValueAt;

		PROCEDURE IncValueAt(inc: HUGEINT; idx: LONGINT);
		BEGIN
			SetValueAt(inc + GetValueAt(idx), idx)
		END IncValueAt;

		PROCEDURE SetValueAt(val: HUGEINT; idx: LONGINT);
		BEGIN
			IF (idx >= len) THEN
				KernelLog.String("ASSERTION failed - access to invalid vector element"); KernelLog.Ln
			END;
			ASSERT(idx < len);
			data[idx] := val
		END SetValueAt;

		(** concetenate another vector *)
		PROCEDURE Concatenate(VAR v: Vector);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO v.GetLen() - 1 DO
				SELF.Add(v.data[i])
			END
		END Concatenate;
	END Vector;

	List* = OBJECT
		VAR
			length*: HUGEINT;
			start-, last-: ListElement;

		PROCEDURE &Init*(first: ListElement);
		VAR
		BEGIN
			IF (first = NIL) THEN length := 0 ELSE length := 1 END;
			SELF.start := first;
			SELF.last := first
		END Init;

		PROCEDURE Append*(node: ListElement);
		BEGIN
			IF (last = NIL) THEN
				start := node; last := node
			ELSE
				last.next := node;
				last := node
			END;
			INC(length);
			node.next := NIL
		END Append;

		(** print the list *)
		PROCEDURE Print*;
		VAR
			i, split: LONGINT;
			cur: ListElement;
		BEGIN
			i := 0; split := 16; (* every 'split' elements make a line break *)
			cur := SELF.start;
			String("-> List <-");
			Var("list-length", SYSTEM.VAL(LONGINT,length));
			WHILE (cur # NIL) DO
				IF (~(i = 0) & (i MOD split = 0)) THEN w.Ln END;
				cur.Print;
				cur := cur.next;
				INC(i)
			END;
			w.Ln; String("-> END (List) <-")
		END Print;
	END List;

	IntList* = OBJECT(List)
		(** no additional fields needed *)
	END IntList;

	ListElement* = OBJECT
		VAR
			next-: ListElement;

		PROCEDURE &Init*;
		BEGIN
			SELF.next := NIL
		END Init;

		PROCEDURE Print;
			(* do nothing *)
		END Print;
	END ListElement;

	IntElement* = OBJECT(ListElement)
		VAR
			long-: LONGINT;

		PROCEDURE &InitInt*(long: LONGINT);
		BEGIN
			SELF.long := long;
			SELF.next := NIL
		END InitInt;

		PROCEDURE Print;
		BEGIN
			w.Int(long, 3)
		END Print;
	END IntElement;

	BufferPool* = OBJECT
		VAR head, num: LONGINT; buffer: POINTER TO ARRAY OF SoundDevices.Buffer;

		PROCEDURE Append*(x: SoundDevices.Buffer);
		BEGIN {EXCLUSIVE}
			AWAIT(num # LEN(buffer));
			buffer[(head+num) MOD LEN(buffer)] := x;
			INC(num)
		END Append;

		PROCEDURE Remove*(): SoundDevices.Buffer;
		VAR x: SoundDevices.Buffer;
		BEGIN {EXCLUSIVE}
			AWAIT(num # 0);
			x := buffer[head];
			head := (head+1) MOD LEN(buffer);
			DEC(num);
			RETURN x
		END Remove;

		PROCEDURE &Init*(n: LONGINT);
		BEGIN
			head := 0; num := 0; NEW(buffer, n)
		END Init;
	END BufferPool;


	(** these procedures are used in multiple places by the OGGVorbisPlayer *)

	(** get the position number of the lowest set bit of x *)
	PROCEDURE ILog*(x: LONGINT): LONGINT;
	VAR ret: LONGINT;
	BEGIN
		ret := 0;
		LOOP
			IF (x > 0) THEN
				INC(ret);
				x := LSH(x, -1)
			ELSE
				EXIT
			END
		END;
		RETURN ret
	END ILog;

	(** translate the packed binary representation of a Vorbis codebook float value into the
			representation used by the decoder for floating point numbers *)
	PROCEDURE Float32Unpack*(val: LONGINT): HUGEINT;
	VAR
		mantissa, sign, exponent, one: LONGINT;
		res: REAL;
	BEGIN
		mantissa := BIT.LAND(val, 1FFFFFH);
		sign := BIT.LAND(val, LONGINT(80000000H));
		exponent := BIT.LAND(val, 7FE00000H) DIV 1FFFFFH;
		IF (sign # 0) THEN
			mantissa := -1 * mantissa
		END;
		one := 1;
		res := mantissa / LSH(one, -1*(exponent - 788));
		RETURN ScaleUpHuge(res)
	END Float32Unpack;

	(** compute the correct length of the value index for a codebook VQ lookup table of lookup type 1 *)
	PROCEDURE Lookup1Values*(cbEntries, cbDimensions: LONGINT): LONGINT;
	VAR res: LONGINT;
	BEGIN
		res := 0;
		WHILE (Power(res, cbDimensions) <= cbEntries) DO
			INC(res);
		END;
		DEC(res); (* find the highest ... that is smaller than ... *)
		RETURN res
	END Lookup1Values;

	(** find the position n in vector v of the GREATEST value scalar element for which n is less than x and v[n] is less than v[x] *)
	PROCEDURE LowNeighbor*(v: ARRAY OF LONGINT; x: LONGINT): LONGINT;
	VAR i, n: LONGINT;
	BEGIN
		n := 0;
		FOR i := 1 TO x - 1 DO (* n is less than x *)
			IF (v[i] < v[x]) THEN (* v[n] is less than v[x] *)
				IF ((v[i] > v[n]) OR (n = 0)) THEN (* the greatest value OR if its first value less than v[x]*)
					n := i
				END
			END
		END;
		RETURN n
	END LowNeighbor;

	(** find the position n in vector v of the LOWEST value scalar element for which n is less than x and v[n] is greater than v[x] *)
	PROCEDURE HighNeighbor*(v: ARRAY OF LONGINT; x: LONGINT): LONGINT;
	VAR i, n: LONGINT;
	BEGIN
		n := 0;
		FOR i := 0 TO x - 1 DO (* n is less than x *)
			IF (v[i] > v[x]) THEN (* v[n] is greater than v[x] *)
				IF ((v[i] < v[n]) OR (n = 0)) THEN (* the lowest value OR if its first value greater than v[x] *)
					n := i
				END
			END
		END;
		RETURN n
	END HighNeighbor;

	(** find the y-coordinate at point x along the line specified by x0, x1, y0 and y1 *)
	PROCEDURE RenderPoint*(x0,y0,x1,y1,x: LONGINT): LONGINT;
	VAR
		dy, adx, ady, err, off: LONGINT;
	BEGIN
		dy := y1 - y0;
		adx := x1 - x0;
		ady := ABS(dy);
		err := ady * (x - x0);
		off := err DIV adx;
		IF dy < 0 THEN
			RETURN (y0 - off)
		ELSE
			RETURN  (y0 + off)
		END
	END RenderPoint;

	(** construct an integer floor curve for contiguous piecewise line segments *)
	PROCEDURE RenderLine*(x0, y0, x1, y1: LONGINT; VAR v: ARRAY OF HUGEINT);
	VAR dy, adx, ady, x, y, err, base, sy: LONGINT;
	BEGIN
		dy := y1 - y0;
		adx := x1 - x0;
		ady := ABS(dy);
		(* adx is always positive, dy negative or positive *)
		IF (dy < 0) THEN
			base := -1 * ABS(dy) DIV adx (* must round towards zero, DIV-operator does not *)
		ELSE
			base := dy DIV adx
		END;
		x := x0;
		y := y0;
		err := 0;
		IF (dy < 0) THEN
			sy := base - 1
		ELSE
			sy := base + 1
		END;
		ady := ady - ABS(base) * adx;
		v[x] := y;
		FOR x := x0 + 1 TO x1 - 1 DO
			INC(err, ady);
			IF (err >= adx) THEN
				DEC(err, adx);
				INC(y, sy)
			ELSE
				INC(y, base)
			END;
			v[x] := y
		END
	END RenderLine;

	(** sort an array, storing the position changes *)
	PROCEDURE EasySortRemember*(VAR data, sortptr: ARRAY OF LONGINT; n: LONGINT);
	VAR tmp, j, k: LONGINT;
	BEGIN
		IF ((n > LEN(data)) OR (n > LEN(sortptr))) THEN
			KernelLog.String("ASSERTION failed - array too short to sort")
		END;
		ASSERT((n <= LEN(data)) & (n <= LEN(sortptr)));
		FOR j := 0 TO n - 1 DO sortptr[j] := j END; (* no position changes yet *)
		FOR j := 0 TO n - 2 DO
			FOR k := j TO n - 1 DO
				IF (data[sortptr[j]] > data[sortptr[k]]) THEN
					(* remember swapping positions *)
					tmp := sortptr[k];
					sortptr[k] := sortptr[j];
					sortptr[j] := tmp
				END
			END
		END;
	END EasySortRemember;

	(** some mathematical procedures *)

	(** return x to the power of n (ASSERT(n>=0)) *)
	PROCEDURE Power*(x,n: LONGINT): LONGINT;
	VAR res: LONGINT;
	BEGIN
		IF (n < 0) THEN
			KernelLog.String("ASSERTION failed - power of negative numbers are not allowed"); KernelLog.Ln
		END;
		ASSERT(n >= 0);
		IF (n = 0) THEN
			RETURN 1
		ELSE
			res := x;
			WHILE (n > 1) DO
				res := x * res;
				DEC(n)
			END
		END;
		RETURN res;
	END Power;

	(** return x to the power of n (ASSERT(n>=0)) *)
	PROCEDURE PowerH(x: HUGEINT; n: LONGINT): HUGEINT;
	VAR res: HUGEINT;
	BEGIN
		IF (n < 0) THEN
			KernelLog.String("ASSERTION failed - power of negative numbers are not allowed"); KernelLog.Ln
		END;
		ASSERT(n >= 0);
		IF (n = 0) THEN
			RETURN 1
		ELSE
			res := x;
			WHILE (n > 1) DO
				res := x * res;
				DEC(n)
			END
		END;
		RETURN res;
	END PowerH;

	(** return x to the power of n (ASSERT(n>=0)) *)
	PROCEDURE PowerR*(x: REAL; n: LONGINT): REAL;
	VAR res: REAL;
	BEGIN
		IF (n < 0) THEN
			KernelLog.String("ASSERTION failed - power of negative numbers are not allowed"); KernelLog.Ln
		END;
		ASSERT(n >= 0);
		IF (n = 0) THEN
			RETURN 1
		ELSE
			res := x;
			WHILE (n > 1) DO
				res := res * x;
				DEC(n)
			END
		END;
		RETURN res;
	END PowerR;

	(** returns the logarithm to the base 2 *)
	PROCEDURE Log2n*(n: LONGINT): LONGINT;
	VAR res: LONGINT;
	BEGIN
		ASSERT(n > 0);
		res := 0;
		WHILE (n # 1) DO
			n := n DIV 2;
			INC(res);
		END;
		RETURN res
	END Log2n;
(*
	PROCEDURE HighestBit(h: HUGEINT): LONGINT;
	VAR res, i: LONGINT;
	BEGIN
		IF h < 0 THEN h := -1 * h END;
		res := 0;
		FOR i := 0 TO 63 DO
			IF LONGINT(h) MOD 2 = 1 THEN
				res := i
			END;
			h := LSH(h, -1)
		END;
		RETURN res
	END HighestBit;
*)
	(** fix-point arithmetic procedures *)

	(** fixed-point multiplication, result same format as input with fraction n*)
	PROCEDURE MultHugeFP*(a, b: HUGEINT): HUGEINT;
	VAR sign, res: HUGEINT;
	BEGIN
		IF ((a = 0) OR (b = 0)) THEN
			RETURN 0
		ELSE
			res := a * b;
			IF res < 0 THEN
				sign := -1;
				(* eliminate sign for shifting*)
				res := sign * res;
			ELSE
				sign := 1
			END;
			res := LSH(res, -Ny);
			(* rebuild sign *)
			res := sign * res;
			RETURN res
		END
	END MultHugeFP;

	(** fixed-point multiplication for "dot product" of residue and floor *)
	PROCEDURE MultDotProductFP*(residue, floor: HUGEINT): HUGEINT;
	VAR sign: HUGEINT;
	BEGIN
		IF (residue = 0) OR (floor = 0) THEN
			RETURN 0
		ELSE
			IF residue < 0 THEN
				sign := -1;
				residue := sign * residue
			ELSE
				sign := 1
			END;
			(* scale down residue-value which is an integer *)
			residue := ScaleDownHuge(residue);
			residue := sign * residue;

			(* leave floor-value *)

			RETURN residue * floor
		END
	END MultDotProductFP;

	(** fixed-point multiplication, result same format as input with constant fraction Nx*)
	PROCEDURE MultFP*(a, b: HUGEINT): HUGEINT;
	VAR divident, n: LONGINT;
	BEGIN
		IF (a = 0) OR (b = 0) THEN
			RETURN 0
		ELSE
			n := Ny DIV 2;
			divident := LSH(LONG(LONG(1)), n);
			a := a DIV divident;
			b := b DIV divident;
			RETURN a * b
		END
	END MultFP;

	(** fixed-point division, result same format as input with constant fraction Nx*)
	PROCEDURE DivFP*(a, b: LONGINT): LONGINT;
	BEGIN
		RETURN ScaleUpInt(a) DIV b;
	END DivFP;

	(** scales a float up for fix-point representation with fraction Ny *)
	PROCEDURE ScaleUpHuge*(r: REAL): HUGEINT;
	VAR tmp: HUGEINT;
	BEGIN
		tmp := ENTIERH(0.5 + r * ScaleFactor);
		RETURN tmp
	END ScaleUpHuge;

	(** scales a float up for fix-point representation with fraction Ny *)
	PROCEDURE ScaleUp*(r: LONGREAL): LONGINT;
	VAR tmp: LONGINT;
	BEGIN
		tmp := ENTIER(0.5 + r * ScaleFactor);
		RETURN tmp
	END ScaleUp;

	(** scales a float up for fix-point representation with fraction Ny *)
	PROCEDURE ScaleUpRealToHuge*(r: LONGREAL): HUGEINT;
	VAR tmp: HUGEINT;
	BEGIN
		tmp := ENTIERH(0.5 + r * ScaleFactor);
		RETURN tmp
	END ScaleUpRealToHuge;


	(** scales an integer up for fix-point representation with constant fraction Ny *)
	PROCEDURE ScaleUpInt*(i: LONGINT): LONGINT;
	VAR tmp: LONGINT;
	BEGIN
		tmp :=  i * SHORT(ScaleFactor);
		RETURN tmp
	END ScaleUpInt;

	(** scales an huge integer up for fix-point representation with constant fraction Ny *)
	PROCEDURE ScaleUpHugeInt*(i: HUGEINT): HUGEINT;
	VAR tmp: HUGEINT;
	BEGIN
		tmp := i * ScaleFactor;
		RETURN tmp
	END ScaleUpHugeInt;


	(** scales a hugeint down for fix-point representation (rounded) with constant fraction Ny*)
	PROCEDURE ScaleDownRoundedHuge*(i: HUGEINT): LONGINT;
	BEGIN
		RETURN SHORT((i + ScaleFactor DIV 2) DIV ScaleFactor)
	END ScaleDownRoundedHuge;

	(** scales a hugeint down for fix-point representation  with constant fraction Ny*)
	PROCEDURE ScaleDownHuge(i: HUGEINT): HUGEINT;
	BEGIN
		RETURN i DIV ScaleFactor
	END ScaleDownHuge;


	(** procedures for debugging output to a log-file *)

	PROCEDURE GetFilename*(VAR name: ARRAY OF CHAR);
	BEGIN
		f.GetName(name)
	END GetFilename;

	PROCEDURE Array2D*(name: ARRAY OF CHAR; VAR a: ARRAY OF ARRAY OF LONGINT);
	VAR i: LONGINT;
	BEGIN
		w.String("[ "); w.String(name); w.String(" ]"); w.Ln;
		FOR i := 0 TO LEN(a) - 1 DO
			Array("---", a[i]);
			w.Ln;
		END;
		w.Ln; w.String("[ END ("); w.String(name); w.String(") ]"); w.Ln;
		w.Update
	END Array2D;

	PROCEDURE ArrayBool*(name: ARRAY OF CHAR; VAR a: ARRAY OF BOOLEAN);
	VAR i: LONGINT;
	BEGIN
		w.String("[ "); w.String(name); w.String(" ]"); w.Ln;
		FOR i := 0 TO LEN(a) - 1 DO
			IF (~(i = 0) & (i MOD 16 = 0)) THEN
				w.Ln; w.String(" ")
			END;
			IF (a[i]) THEN
				w.String("1")
			ELSE
				w.String("0")
			END;
			IF (i # LEN(a)-1) THEN w.String(", ") END
		END;
		w.Ln; w.String("[ END ("); w.String(name); w.String(") ]"); w.Ln;
		w.Update
	END ArrayBool;

	(** print an array of longint *)
	PROCEDURE Array*(name: ARRAY OF CHAR; VAR a: ARRAY OF LONGINT);
	BEGIN
		ArrayLen(name, a, LEN(a))
	END Array;

	PROCEDURE ArrayHuge*(name: ARRAY OF CHAR; VAR a: ARRAY OF HUGEINT);
	BEGIN
		ArrayHugeLen(name, a, LEN(a))
	END ArrayHuge;

	PROCEDURE ArrayHugeLen*(name: ARRAY OF CHAR; VAR a: ARRAY OF HUGEINT; n: LONGINT);
	VAR i: LONGINT;
	BEGIN
		IF (n > LEN(a)) THEN
			KernelLog.String("ASSERTION failed - array too short")
		END;
		ASSERT(n <= LEN(a));
		w.String("[ "); w.String(name); w.String(" ] "); w.Ln;
		FOR i := 0 TO n - 1 DO
			w.Int(i, 0); w.String(";");
			w.Int(SHORT(a[i]), 0);
			w.Ln;
		END;
		w.Ln; w.String("[ END ("); w.String(name); w.String(") ]"); w.Ln;
		w.Update
	END ArrayHugeLen;

	(** print an array of longint of a given length *)
	PROCEDURE ArrayLen*(name: ARRAY OF CHAR; VAR a: ARRAY OF LONGINT; n: LONGINT);
	VAR i: LONGINT;
	BEGIN
		IF (n > LEN(a)) THEN
			KernelLog.String("ASSERTION failed - array too short")
		END;
		ASSERT(n <= LEN(a));
		w.String("[ "); w.String(name); w.String(" ]"); w.Ln;
		FOR i := 0 TO n - 1 DO
			w.Int(i, 0); w.String(";"); w.Int(a[i], 0); w.Ln;
		END;
		w.Ln; w.String("[ END ("); w.String(name); w.String(") ]"); w.Ln;
		w.Update
	END ArrayLen;

	(** write a string to the log-file *)
	PROCEDURE String*(str: ARRAY OF CHAR);
	BEGIN
		w.String(str); w.Ln; w.Update
	END String;

	(** write some bytes from a buffer *)
	PROCEDURE Buffer*(VAR buf: ARRAY OF CHAR; ofs, len: LONGINT);
	VAR i, line: LONGINT;
		hex: ARRAY 3 OF CHAR;
	BEGIN
		line := 16;
		FOR i := 0 TO len - 1 DO
			IF ((i # 0) & (i MOD line = 0)) THEN w.Ln END;
			CharToHex(buf[ofs + i], hex);
			w.String(hex); w.String(" ")
		END;
		w.Ln; w.Update
	END Buffer;

	PROCEDURE CharToHex(ch: CHAR; VAR hex: ARRAY OF CHAR);
	VAR ord, low, high: LONGINT;
	BEGIN
		ord := ORD(ch);
		low := ord MOD 16;
		high := ord DIV 16;
		hex[0] := GetHexDigit(high);
		hex[1] := GetHexDigit(low);
	END CharToHex;

	PROCEDURE GetHexDigit(val: LONGINT): CHAR;
	BEGIN
		IF (val <= 9) THEN
			RETURN CHR(48 + val)
		ELSE
			RETURN CHR(65 + val - 10)
		END
	END GetHexDigit;

	(** print a varname with its value, type must be a longint *)
	PROCEDURE Var*(name: ARRAY OF CHAR; value: LONGINT);
	BEGIN
		w.String(name); w.String(": "); w.Int(value,5); w.Ln; w.Update
	END Var;

	(** print a varname with its value, type must be a hugeint *)
	PROCEDURE VarH*(name: ARRAY OF CHAR; value: HUGEINT);
	BEGIN
		w.String(name); w.String(": ");
		VarH2(value);
		w.Ln; w.Update
	END VarH;

	(** print a hugeint *)
	PROCEDURE VarH2*(value: HUGEINT);
	VAR sign: LONGINT;
	BEGIN
		IF (value < 0) THEN sign := -1; value := -1 * value ELSE sign := 1 END;
		IF (sign = -1) THEN w.String("-") ELSE w.String(" ") END;
		PrintHex(SHORT (ASH(value, -32)));
		PrintHex(SHORT (value));
		w.Update
	END VarH2;

	PROCEDURE PrintHex(x: LONGINT);
	VAR i, j: LONGINT;
		buf: ARRAY 10 OF CHAR;
	BEGIN
		j := 8;
		FOR i := j-1 TO 0 BY -1 DO
			buf[i] := CHR(x MOD 10H + 48);
			IF buf[i] > "9" THEN
				buf[i] := CHR(ORD(buf[i]) - 48 + 65 - 10)
			END;
			x := x DIV 10H
		END;
		buf[j] := 0X;
		w.String(buf)
	END PrintHex;

	(** print a varname with its value, type must be a REAL *)
	PROCEDURE VarReal*(name: ARRAY OF CHAR; value: LONGREAL);
	VAR tmpStr: ARRAY 32 OF CHAR;
	BEGIN
		Strings.FloatToStr(value, 5, 4, 0, tmpStr);
		w.String(name); w.String(": "); w.String(tmpStr); w.Ln; w.Update
	END VarReal;


	PROCEDURE InitLogger*;
	BEGIN
		f := Files.New("LogFile.csv");
		Files.Register(f);
		Files.OpenWriter(w, f, 0);
	END InitLogger;

BEGIN
	Ny := Nx; (* necessary for some reason *)
	ScaleFactor := LSH(LONG(LONG(1)), Ny DIV 2);
	ScaleFactor := ScaleFactor * ScaleFactor;
END OGGUtilities.
