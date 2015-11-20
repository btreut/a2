MODULE PCARMCP;	(** be  **)

IMPORT SYSTEM, PCO := PCOARM, PCM, PCBT, KernelLog;

CONST
	Trace = FALSE;

	ErrInternalError* = 100;
	ErrConstantNotRegistered* = 101;
	ErrAddressNotRegistered* = 102;

	FlushThreshold = 80H;

TYPE
	UseList = OBJECT
		VAR
			pc: LONGINT;	(* where the element is used *)
			next: UseList;

		PROCEDURE &Init*(pc: LONGINT);
		BEGIN SELF.pc := pc
		END Init;
	END UseList;

	Element = OBJECT
		VAR
			pc: LONGINT;	(* where this element is located in the code, -1 if unknown *)
			firstUse:LONGINT;	(* where this element's first use is located in the code. *)
			next: Element;
			uses: UseList;

		PROCEDURE &InitElement*;
		BEGIN pc := -1
		END InitElement;
	END Element;

	Constant = OBJECT(Element)
		VAR
			value: LONGINT;

		PROCEDURE &Init*(value: LONGINT);
		BEGIN InitElement; SELF.value := value
		END Init;
	END Constant;

	Address = OBJECT(Element)
		VAR
			adr: PCM.Attribute;

		PROCEDURE &Init*(adr: PCM.Attribute);
		BEGIN InitElement; SELF.adr := adr
		END Init;
	END Address;

	ConstantPool* = OBJECT
		VAR items: Element;
			limitPC: LONGINT;	(* constant pool must be flushed the latest at this pc *)

		(* Init - constructor *)
		PROCEDURE &Init*;
		BEGIN PCO.SetConstantPoolBarrierCallback(FlushCallback); limitPC := -1
		END Init;

		(* Insert - inserts the element 'i' at the correct position in the linked list *)
		PROCEDURE Insert(i: Element);
		VAR p,c: Element;
		BEGIN
			c := items; p := NIL;
			WHILE (c # NIL) & (c.firstUse < i.firstUse) DO p := c; c := c.next END;
			IF (p = NIL) THEN
				i.next := c; items := i
			ELSE
				i.next := p.next; p.next := i
			END
		END Insert;

		PROCEDURE AddConstant*(pc, c: LONGINT): LONGINT;
		VAR i, p: Element; cnst: Constant; use: UseList;
		BEGIN { EXCLUSIVE }
			IF Trace THEN
				KernelLog.Enter;
				KernelLog.String("Adding constant "); KernelLog.Int(c, 0); KernelLog.String(" @ "); KernelLog.Int(pc, 0);
				KernelLog.Exit
			END;
			i := items; p := NIL;
			WHILE (i # NIL) & (~(i IS Constant) OR (i(Constant).value # c)) DO p := i; i := i.next END;
			IF (i = NIL) THEN
				NEW(cnst, c); i := cnst; i.firstUse := pc;
				Insert(i)
				(*
				IF (last = NIL) THEN items := cnst; last := cnst
				ELSE last.next := cnst; last := cnst
				END
				*)
			ELSIF (i.firstUse > pc) THEN
				i.firstUse := pc;
				IF ((p # NIL) & (p.firstUse > i.firstUse)) OR ((i.next # NIL) & (i.next.firstUse < i.firstUse)) THEN
					IF (p # NIL) THEN p.next := i.next
					ELSE items := i.next
					END;
					Insert(i)
				END
			END;
			IF (i.pc # -1) THEN (* already stored somewhere *)
				IF (pc + 8 - i.pc < 1000H) THEN RETURN i.pc - pc - 8
				ELSE i.pc := -1 (* we need a new location *)
				END
			END;
			NEW(use, pc); use.next := i.uses; i.uses := use;
			IF (limitPC = -1) THEN
				limitPC := pc + 1000H - 2*PCO.InstructionSize - FlushThreshold; (* FFFh is max offset, aligned word access at FFCh minus one branch *)
				PCO.SetConstantPoolBarrier(limitPC)
			END;
			RETURN 0
		END AddConstant;

		PROCEDURE AddAddress*(pc: LONGINT; adr: PCM.Attribute): LONGINT;
		VAR i, p: Element; address: Address; use: UseList;
		BEGIN { EXCLUSIVE }
			IF Trace THEN
				KernelLog.Enter;
				KernelLog.String("Adding address "); KernelLog.Hex(ADDRESSOF(adr^), 8); KernelLog.String(" @ "); KernelLog.Int(pc, 0);
				KernelLog.Exit
			END;
			i := items;
			WHILE (i # NIL) & (~(i IS Address) OR (i(Address).adr # adr)) DO p := i; i := i.next END;
			IF (i = NIL) THEN
				NEW(address, adr); i := address; i.firstUse := pc;
				Insert(i)
			ELSIF (i.firstUse > pc) THEN
				i.firstUse := pc;
				IF ((p # NIL) & (p.firstUse > i.firstUse)) OR ((i.next # NIL) & (i.next.firstUse < i.firstUse)) THEN
					IF (p # NIL) THEN p.next := i.next
					ELSE items := i.next
					END;
					Insert(i)
				END
			END;
			IF (i.pc # -1) THEN (* already stored somewhere *)
				IF (pc + 8 - i.pc < 1000H) THEN RETURN i.pc - pc - 8
				ELSE i.pc := -1 (* we need a new location *)
				END
			END;
			(* 08.05.02: interface changed *)
			IF (adr IS PCBT.GlobalVariable) THEN
				(*
				WITH adr: PCBT.GlobalVariable DO
					l := adr.link;
					IF (l = NIL) OR (l.offset # -1) THEN (* only add an entry to the fixup list if needed *)
						(* adr.link is a linked list that contains all locations where the address of this global variable needs to be
							fixed by the loader. If adr.link = NIL, this is the first time the address of the global is used and we have
							to add it to the list. If adr.link.offset # -1, then the address is already stored somewhere, but we can't
							use it (because it's too far away from the load instruction); i.e. we'll get a new location and consequently
							need a new fixup link.
							cf. Flush
						*)
						NEW(l); l.offset := -1; l.next := adr.link; adr.link := l
					END;
				END
				*)
			ELSIF (adr IS PCBT.Procedure) THEN
				(* nothing to do *)
				(*IF adr.imported THEN adr.fixlist := -1 (* TODO (= adr of constant in code) *)
				ELSE PCBT.context.syscalls[PCBT.procaddr] := 0 (* TODO *)
				END;
				HALT(ErrInternalError) (* TODO *)*)
			ELSE Error(pc, "AddAddress: unknown 'adr' type")
			END;
			NEW(use, pc); use.next := i.uses; i.uses := use;
			IF (limitPC = -1) THEN
				limitPC := pc + 1000H - 2*PCO.InstructionSize - FlushThreshold; (* FFFh is max offset, aligned word access at FFCh minus one branch *)
				PCO.SetConstantPoolBarrier(limitPC)
			END;
			RETURN 0
		END AddAddress;

		PROCEDURE Flush*(pc: LONGINT);
		VAR i: Element; u: UseList; adr: PCM.Attribute; cnt: LONGINT;
		BEGIN
			IF Trace THEN
				KernelLog.Enter; KernelLog.String("Flushing Constant Pool..."); KernelLog.Ln
			END;
			i := items;
			WHILE (i # NIL) DO
				i.firstUse := MAX(LONGINT); (* reset firstUse field *)
				IF (i.uses # NIL) & (i.pc = -1) THEN
					INC(cnt);
					IF Trace THEN
						IF (i IS Constant) THEN KernelLog.String("  constant (value = "); KernelLog.Int(i(Constant).value, 0)
						ELSE KernelLog.String("  address (id = "); KernelLog.Hex(ADDRESSOF(i(Address).adr^), 8)
						END;
						KernelLog.String(");  pc = ")
					END;
					i.pc := PCO.GetCodePos();
					IF (i IS Constant) THEN PCO.DCD(i(Constant).value)
					ELSE
						adr := i(Address).adr;
						IF (adr IS PCBT.GlobalVariable) THEN	(* fix offsets in adr.link structure *)
							WITH adr: PCBT.GlobalVariable DO
								PCO.DCD(adr.offset);
								(* 08.05.02: interface changed
								IF (adr.link = NIL) THEN Error(pc, "Flush: 'adr.link' is NIL") END;
								IF (adr.link.offset = -1) THEN adr.link.offset := i.pc DIV 4 END
								*)
								PCBT.context.UseVariable(adr, i.pc DIV 4)
							END
						ELSIF (adr IS PCBT.Procedure) THEN
							WITH adr: PCBT.Procedure DO
								(*
								IF adr.imported THEN
									PCO.DCD(adr.fixlist*10000H);
									adr.fixlist := i.pc DIV 4
								ELSE
									(* local procedure variables: fixup-list located in the code *)
									IF (adr.next = NIL) & (PCBT.context.lastEntry # adr) THEN PCBT.context.NewEntry(adr) END;
									PCO.DCD(PCBT.context.syscalls[PCBT.procaddr]*10000H + adr.entryNr);
									PCBT.context.syscalls[PCBT.procaddr] := i.pc DIV 4
								END
								*)
								PCO.DCD(0);
								PCBT.context.UseProcedure(adr, i.pc DIV 4)
							END
						ELSE Error(pc, "Flush: unknown 'adr' type")
						END;
					END;
					IF Trace THEN
						KernelLog.Hex(i.pc, 8); KernelLog.Ln;
						KernelLog.String("  fixing references at pos: ")
					END;
					u := i.uses;
					WHILE (u # NIL) DO
						IF Trace THEN KernelLog.Int(u.pc, 5) END;
						PCO.FixLoad(u.pc, i.pc - (u.pc + 8));
						u := u.next
					END;
					IF Trace THEN KernelLog.Ln END;
					i.uses := NIL
				END;
				i := i.next
			END;
			limitPC := -1;
			PCO.SetConstantPoolBarrier(limitPC);
			IF Trace THEN KernelLog.String(" # of addresses/constants flushed: "); KernelLog.Int(cnt, 0); KernelLog.Exit END
		END Flush;

		(* FlushCallback - callback handler called by PCOARM *)
		PROCEDURE FlushCallback(pc: LONGINT);
		BEGIN
			IF Trace THEN
				KernelLog.Enter; KernelLog.Hex(pc, 8); KernelLog.String(": Constant Pool: Flush callback called"); KernelLog.Exit
			END;
			PCO.B(PCO.AL, 0); (* branch target still unknown, will be fixed after the Flush *)
			Flush(pc);
			PCO.FixJump(pc, (PCO.GetCodePos() - (pc + 8)) DIV 4)
		END FlushCallback;

		PROCEDURE Error(pc: LONGINT; CONST msg: ARRAY OF CHAR);
		BEGIN
			KernelLog.Enter;
			KernelLog.String("ConstantPool Error @ pc = "); KernelLog.Hex(pc, 8); KernelLog.String("h: ");
			KernelLog.String(msg);
			KernelLog.Exit;
			HALT(ErrInternalError);
		END Error;
	END ConstantPool;

END PCARMCP.
