(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(* ConvertNCRScript.Do *)

MODULE NCRScript;	(** non-portable *)	(* Contributed by P. Ryser to the System 3 project *)
(** AUTHOR "ryser"; PURPOSE "NCR/Symbios SCSI firmware"; *)
(* ported by phk *)

	IMPORT SYSTEM, Machine;

	CONST
		dsaSelect* = 0; dsaMsgOut* = 1; dsaCmd* = 2;
		dsaStatus* = 3; dsaData* = 4; dsaMsgIn* = 5;
		dsaTableSize* = 6;

		AIntErrUnexpectedPhase* = 000000000H;
		AIntErrSelectFailed* = 000000040H;
		AIntHandleMsgIn* = 000000021H;
		AIntNormCommandComplete* = 000000022H;
		AIntNormDisc* = 000000023H;
		AIntGotSIGP* = 000000024H;
		AIntReselected* = 000000025H;
		AIntMsgOutPhase* = 000000030H;
		AIntCmdPhase* = 000000031H;
		AIntDataInPhase* = 000000032H;
		AIntDataOutPhase* = 000000033H;
		AIntStatusPhase* = 000000034H;
		AIntMsgInPhase* = 000000035H;
		EntCommandComplete*   = 0000000B8H;
		EntCompleteMsgInPhase* = 000000100H;
		EntDisconnected*      = 0000000E0H;
		EntRejectMsg*         = 000000150H;
		EntResumeDataInPhase* = 000000058H;
		EntResumeCmdPhase*    = 000000038H;
		EntResumeDataOutPhase* = 000000078H;
		EntResumeMsgInPhase*  = 0000000A8H;
		EntResumeMsgOutPhase* = 000000020H;
		EntResumeStatusPhase* = 000000090H;
		EntSelection*         = 000000000H;
		EntToDecisions*       = 000000108H;
		EntWaitReselect*      = 000000138H;

	TYPE
		TableEntry* = RECORD
			count*: LONGINT; address*: Machine.Address32;
		END;
		BufferTable* = ARRAY dsaTableSize OF TableEntry;

	VAR
		ScriptsAddress*: Machine.Address32;
		Script*: ARRAY  2*67H + 3 OF LONGINT;


	PROCEDURE CheckAlign;
	VAR adr: ADDRESS;
	BEGIN
		adr := ADDRESSOF(Script[0]);
		ASSERT(SYSTEM.VAL (LONGINT, adr) MOD 4 = 0, 100)
	END CheckAlign;

	PROCEDURE SetUnsigned(VAR integer: LONGINT; hugeint: HUGEINT);
	BEGIN
		integer := SHORT(hugeint);
	END SetUnsigned;

	PROCEDURE Init;
	BEGIN
		SetUnsigned(Script[0] , 060000200H);	SetUnsigned(Script[1] , 000000000H);
		SetUnsigned(Script[2] , 047000000H);	SetUnsigned(Script[3] , 000000168H);
		SetUnsigned(Script[4] , 086830000H);	SetUnsigned(Script[5] , 0000000F0H);
		SetUnsigned(Script[6] , 080000000H);	SetUnsigned(Script[7] , 000000000H);	(*		SetUnsigned(Script[b] , 098080000H);	SetUnsigned(Script[b] , 000000030H); *)
		SetUnsigned(Script[8] , 01E000000H);	SetUnsigned(Script[9] , 000000008H);
		SetUnsigned(Script[10] , 082830000H);	SetUnsigned(Script[11] , 0000000D8H);
		SetUnsigned(Script[12] , 080000000H);	SetUnsigned(Script[13] , 000000000H);	(*		SetUnsigned(Script[b] , 098080000H);	SetUnsigned(Script[b] , 000000031H);  *)
		SetUnsigned(Script[14] , 060000008H);	SetUnsigned(Script[15] , 000000000H);
		SetUnsigned(Script[16] , 01A000000H);	SetUnsigned(Script[17] , 000000010H);
		SetUnsigned(Script[18] , 081830000H);	SetUnsigned(Script[19] , 0000000B8H);
		SetUnsigned(Script[20] , 080000000H);	SetUnsigned(Script[21] , 000000000H);	(*		SetUnsigned(Script[b] , 098080000H);	SetUnsigned(Script[b] , 000000032H);	*)
		SetUnsigned(Script[22] , 019000000H);	SetUnsigned(Script[23] , 000000020H);
		SetUnsigned(Script[24] , 0838B0000H);	SetUnsigned(Script[25] , 000000020H);
		SetUnsigned(Script[26] , 080880000H);	SetUnsigned(Script[27] , 000000098H);
		SetUnsigned(Script[28] , 080000000H);	SetUnsigned(Script[29] , 000000000H);	(*		SetUnsigned(Script[b] , 098080000H);	SetUnsigned(Script[b] , 000000033H);	*)
		SetUnsigned(Script[30] , 018000000H);	SetUnsigned(Script[31] , 000000020H);
		SetUnsigned(Script[32] , 083830000H);	SetUnsigned(Script[33] , 000000080H);
		SetUnsigned(Script[34] , 080000000H);	SetUnsigned(Script[35] , 000000000H);	(*		SetUnsigned(Script[b] , 098080000H);	SetUnsigned(Script[b] , 000000034H);	*)
		SetUnsigned(Script[36] , 01B000000H);	SetUnsigned(Script[37] , 000000018H);
		SetUnsigned(Script[38] , 087830000H);	SetUnsigned(Script[39] , 000000068H);
		SetUnsigned(Script[40] , 080000000H);	SetUnsigned(Script[41] , 000000000H);	(*		SetUnsigned(Script[b] , 098080000H);	SetUnsigned(Script[b] , 000000035H);	*)
		SetUnsigned(Script[42] , 01F000000H);	SetUnsigned(Script[43] , 000000028H);
		SetUnsigned(Script[44] , 098080000H);	SetUnsigned(Script[45] , 000000021H);
		SetUnsigned(Script[46] , 07C027F00H);	SetUnsigned(Script[47] , 000000000H);
		SetUnsigned(Script[48] , 060000040H);	SetUnsigned(Script[49] , 000000000H);
		SetUnsigned(Script[50] , 098180000H);	SetUnsigned(Script[51] , 000000000H);
		SetUnsigned(Script[52] , 048000000H);	SetUnsigned(Script[53] , 000000000H);
		SetUnsigned(Script[54] , 098080000H);	SetUnsigned(Script[55] , 000000022H);
		SetUnsigned(Script[56] , 07C027F00H);	SetUnsigned(Script[57] , 000000000H);
		SetUnsigned(Script[58] , 060000040H);	SetUnsigned(Script[59] , 000000000H);
		SetUnsigned(Script[60] , 048000000H);	SetUnsigned(Script[61] , 000000000H);
		SetUnsigned(Script[62] , 098080000H);	SetUnsigned(Script[63] , 000000023H);
		SetUnsigned(Script[64] , 060000040H);	SetUnsigned(Script[65] , 000000000H);
		SetUnsigned(Script[66] , 0878B0000H);	SetUnsigned(Script[67] , 0FFFFFF90H);
		SetUnsigned(Script[68] , 0828A0000H);	SetUnsigned(Script[69] , 0FFFFFF18H);
		SetUnsigned(Script[70] , 0818A0000H);	SetUnsigned(Script[71] , 0FFFFFF30H);
		SetUnsigned(Script[72] , 0808A0000H);	SetUnsigned(Script[73] , 0FFFFFF48H);
		SetUnsigned(Script[74] , 0838A0000H);	SetUnsigned(Script[75] , 0FFFFFF58H);
		SetUnsigned(Script[76] , 098080000H);	SetUnsigned(Script[77] , 000000000H);
		SetUnsigned(Script[78] , 054000000H);	SetUnsigned(Script[79] , 000000030H);
		SetUnsigned(Script[80] , 0720A0000H);	SetUnsigned(Script[81] , 000000000H);
		SetUnsigned(Script[82] , 098080000H);	SetUnsigned(Script[83] , 000000025H);
		SetUnsigned(Script[84] , 058000008H);	SetUnsigned(Script[85] , 000000000H);
		SetUnsigned(Script[86] , 060000040H);	SetUnsigned(Script[87] , 000000000H);
		SetUnsigned(Script[88] , 01E000000H);	SetUnsigned(Script[89] , 000000008H);
		SetUnsigned(Script[90] , 080880000H);	SetUnsigned(Script[91] , 0FFFFFF98H);
		SetUnsigned(Script[92] , 098080000H);	SetUnsigned(Script[93] , 000000024H);
		SetUnsigned(Script[94] , 098080000H);	SetUnsigned(Script[95] , 000000040H);
		ScriptsAddress := Machine.Ensure32BitAddress (Machine.PhysicalAdr(ADDRESSOF(Script[0]), 201*4));
		CheckAlign
	END Init;

BEGIN
	Init
END NCRScript.




(* old Version: without disconnect/reconnect: WORKS!!!!
MODULE NCRScript;

	CONST
		ETestDestUsed* = 0000000ACH;
		ETestSrcUsed* = 0000000ABH;
		AIntErrUnexpectedPhase* = 000000000H;
		AIntErrCheckCondition* = 000030000H;
		AIntErrSelectFailed* = 000040000H;
		AIntMsgWdtr* = 001000000H;
		AIntMsgSdtr* = 001010000H;
		AIntMsg1* = 001020000H;
		AIntNormCommandComplete* = 002020000H;
		AIntNormDisc* = 002030000H;
		AIntTest1* = 004000000H;
		AIntTest2* = 004010000H;
		AIntTest2NormDisc* = 004020000H;
		EntAcceptMessage* = 000000218H;
		EntCmdoutCmdout* = 000000048H;
		EntCommandComplete* = 000000248H;
		EntCommandCompleteMsgIn* = 000000258H;
		EntMsgIn* = 0000000E0H;
		EntRespondMessage* = 000000228H;
		EntRejectMessage* = 0000001F8H;
		EntSelectMsgOut* = 000000018H;
		EntSelection* = 000000000H;
		EntTest1* = 0000002A8H;
		EntTest2* = 0000002BCH;
		EntTest2MsgOut* = 0000002D4H;

	VAR
		Script*: ARRAY 201 OF LONGINT;


	PROCEDURE SetUnsigned(VAR integer: LONGINT; hugeint: HUGEINT);
	BEGIN
		integer := SHORT(hugeint);
	END SetUnsigned;


	PROCEDURE Init;
	BEGIN
		SetUnsigned(Script[ 0] , 060000200H);	SetUnsigned(Script[ 1] , 000000000H);	SetUnsigned(Script[ 2] , 047000000H);	SetUnsigned(Script[ 3] , 000000290H);
		SetUnsigned(Script[ 4] , 0868B0000H);	SetUnsigned(Script[ 5] , 000000000H);	SetUnsigned(Script[ 6] , 01E000000H);	SetUnsigned(Script[ 7] , 000000008H);
		SetUnsigned(Script[ 8] , 0828B0000H);	SetUnsigned(Script[ 9] , 000000018H);	SetUnsigned(Script[ 10] , 09F030000H);	SetUnsigned(Script[ 11] , 000000000H);
		SetUnsigned(Script[ 12] , 08F8B0000H);	SetUnsigned(Script[ 13] , 0000000A8H);	SetUnsigned(Script[ 14] , 0878B0000H);	SetUnsigned(Script[ 15] , 0FFFFFFF0H);
		SetUnsigned(Script[ 16] , 09A030000H);	SetUnsigned(Script[ 17] , 000000000H);	SetUnsigned(Script[ 18] , 01A000000H);	SetUnsigned(Script[ 19] , 000000018H);
		SetUnsigned(Script[ 20] , 09A0B0000H);	SetUnsigned(Script[ 21] , 000000000H);	SetUnsigned(Script[ 22] , 08F8B0000H);	SetUnsigned(Script[ 23] , 000000080H);
		SetUnsigned(Script[ 24] , 09E0B0000H);	SetUnsigned(Script[ 25] , 000000000H);	SetUnsigned(Script[ 26] , 0808B0000H);	SetUnsigned(Script[ 27] , 000000028H);
		SetUnsigned(Script[ 28] , 0818B0000H);	SetUnsigned(Script[ 29] , 000000010H);	SetUnsigned(Script[ 30] , 0838B0000H);	SetUnsigned(Script[ 31] , 0000001C8H);
		SetUnsigned(Script[ 32] , 080880000H);	SetUnsigned(Script[ 33] , 0FFFFFFC8H);	SetUnsigned(Script[ 34] , 019000000H);	SetUnsigned(Script[ 35] , 000000028H);
		SetUnsigned(Script[ 36] , 080880000H);	SetUnsigned(Script[ 37] , 000000010H);	SetUnsigned(Script[ 38] , 018000000H);	SetUnsigned(Script[ 39] , 000000028H);
		SetUnsigned(Script[ 40] , 080880000H);	SetUnsigned(Script[ 41] , 000000000H);	SetUnsigned(Script[ 42] , 09A0B0000H);	SetUnsigned(Script[ 43] , 000000000H);
		SetUnsigned(Script[ 44] , 08F8B0000H);	SetUnsigned(Script[ 45] , 000000028H);	SetUnsigned(Script[ 46] , 09E0B0000H);	SetUnsigned(Script[ 47] , 000000000H);
		SetUnsigned(Script[ 48] , 0980B0000H);	SetUnsigned(Script[ 49] , 000000000H);	SetUnsigned(Script[ 50] , 0990B0000H);	SetUnsigned(Script[ 51] , 000000000H);
		SetUnsigned(Script[ 52] , 0838B0000H);	SetUnsigned(Script[ 53] , 000000170H);	SetUnsigned(Script[ 54] , 080880000H);	SetUnsigned(Script[ 55] , 0FFFFFFC8H);
		SetUnsigned(Script[ 56] , 01F000000H);	SetUnsigned(Script[ 57] , 000000038H);	SetUnsigned(Script[ 58] , 0808C0001H);	SetUnsigned(Script[ 59] , 000000070H);
		SetUnsigned(Script[ 60] , 0808CDF20H);	SetUnsigned(Script[ 61] , 000000030H);	SetUnsigned(Script[ 62] , 0808C0002H);	SetUnsigned(Script[ 63] , 000000118H);
		SetUnsigned(Script[ 64] , 0808C0003H);	SetUnsigned(Script[ 65] , 000000110H);	SetUnsigned(Script[ 66] , 0808C0004H);	SetUnsigned(Script[ 67] , 000000030H);
		SetUnsigned(Script[ 68] , 0980C0007H);	SetUnsigned(Script[ 69] , 001020000H);	SetUnsigned(Script[ 70] , 0980C000FH);	SetUnsigned(Script[ 71] , 001020000H);
		SetUnsigned(Script[ 72] , 080880000H);	SetUnsigned(Script[ 73] , 0000000D0H);	SetUnsigned(Script[ 74] , 080880000H);	SetUnsigned(Script[ 75] , 0000000C8H);
		SetUnsigned(Script[ 76] , 060000040H);	SetUnsigned(Script[ 77] , 000000000H);	SetUnsigned(Script[ 78] , 090080000H);	SetUnsigned(Script[ 79] , 000000000H);
		SetUnsigned(Script[ 80] , 07C027F00H);	SetUnsigned(Script[ 81] , 000000000H);	SetUnsigned(Script[ 82] , 060000040H);	SetUnsigned(Script[ 83] , 000000000H);
		SetUnsigned(Script[ 84] , 048000000H);	SetUnsigned(Script[ 85] , 000000000H);	SetUnsigned(Script[ 86] , 098080000H);	SetUnsigned(Script[ 87] , 002030000H);
		SetUnsigned(Script[ 88] , 060000040H);	SetUnsigned(Script[ 89] , 000000000H);	SetUnsigned(Script[ 90] , 09F030000H);	SetUnsigned(Script[ 91] , 000000000H);
		SetUnsigned(Script[ 92] , 01F000000H);	SetUnsigned(Script[ 93] , 000000040H);	SetUnsigned(Script[ 94] , 0808C0002H);	SetUnsigned(Script[ 95] , 000000010H);
		SetUnsigned(Script[ 96] , 0808C0003H);	SetUnsigned(Script[ 97] , 000000038H);	SetUnsigned(Script[ 98] , 080880000H);	SetUnsigned(Script[ 99] , 000000068H);
		SetUnsigned(Script[ 100] , 060000040H);	SetUnsigned(Script[ 101] , 000000000H);	SetUnsigned(Script[ 102] , 01F000000H);	SetUnsigned(Script[ 103] , 000000048H);
		SetUnsigned(Script[ 104] , 080840002H);	SetUnsigned(Script[ 105] , 000000050H);	SetUnsigned(Script[ 106] , 060000040H);	SetUnsigned(Script[ 107] , 000000000H);
		SetUnsigned(Script[ 108] , 01F000000H);	SetUnsigned(Script[ 109] , 000000050H);	SetUnsigned(Script[ 110] , 098080000H);	SetUnsigned(Script[ 111] , 001000000H);
		SetUnsigned(Script[ 112] , 060000040H);	SetUnsigned(Script[ 113] , 000000000H);	SetUnsigned(Script[ 114] , 01F000000H);	SetUnsigned(Script[ 115] , 000000048H);
		SetUnsigned(Script[ 116] , 080840001H);	SetUnsigned(Script[ 117] , 000000020H);	SetUnsigned(Script[ 118] , 060000040H);	SetUnsigned(Script[ 119] , 000000000H);
		SetUnsigned(Script[ 120] , 01F000000H);	SetUnsigned(Script[ 121] , 000000050H);	SetUnsigned(Script[ 122] , 01F000000H);	SetUnsigned(Script[ 123] , 000000058H);
		SetUnsigned(Script[ 124] , 098080000H);	SetUnsigned(Script[ 125] , 001010000H);	SetUnsigned(Script[ 126] , 058000008H);	SetUnsigned(Script[ 127] , 000000000H);
		SetUnsigned(Script[ 128] , 060000040H);	SetUnsigned(Script[ 129] , 000000000H);	SetUnsigned(Script[ 130] , 01E000000H);	SetUnsigned(Script[ 131] , 000000060H);
		SetUnsigned(Script[ 132] , 090080000H);	SetUnsigned(Script[ 133] , 000000000H);	SetUnsigned(Script[ 134] , 060000040H);	SetUnsigned(Script[ 135] , 000000000H);
		SetUnsigned(Script[ 136] , 090080000H);	SetUnsigned(Script[ 137] , 000000000H);	SetUnsigned(Script[ 138] , 058000008H);	SetUnsigned(Script[ 139] , 000000000H);
		SetUnsigned(Script[ 140] , 060000040H);	SetUnsigned(Script[ 141] , 000000000H);	SetUnsigned(Script[ 142] , 01E000000H);	SetUnsigned(Script[ 143] , 000000010H);
		SetUnsigned(Script[ 144] , 090080000H);	SetUnsigned(Script[ 145] , 000000000H);	SetUnsigned(Script[ 146] , 01B000000H);	SetUnsigned(Script[ 147] , 000000020H);
		SetUnsigned(Script[ 148] , 06A340000H);	SetUnsigned(Script[ 149] , 000000000H);	SetUnsigned(Script[ 150] , 01F000000H);	SetUnsigned(Script[ 151] , 000000030H);
		SetUnsigned(Script[ 152] , 07C027F00H);	SetUnsigned(Script[ 153] , 000000000H);	SetUnsigned(Script[ 154] , 060000040H);	SetUnsigned(Script[ 155] , 000000000H);
		SetUnsigned(Script[ 156] , 072340000H);	SetUnsigned(Script[ 157] , 000000000H);	SetUnsigned(Script[ 158] , 098180000H);	SetUnsigned(Script[ 159] , 000000000H);
		SetUnsigned(Script[ 160] , 048000000H);	SetUnsigned(Script[ 161] , 000000000H);	SetUnsigned(Script[ 162] , 098080000H);	SetUnsigned(Script[ 163] , 002020000H);
		SetUnsigned(Script[ 164] , 048000000H);	SetUnsigned(Script[ 165] , 000000000H);	SetUnsigned(Script[ 166] , 098080000H);	SetUnsigned(Script[ 167] , 000030000H);
		SetUnsigned(Script[ 168] , 098080000H);	SetUnsigned(Script[ 169] , 000040000H);	SetUnsigned(Script[ 170] , 0C0000004H);	SetUnsigned(Script[ 171] , 000000000H);
		SetUnsigned(Script[ 172] , 000000000H);	SetUnsigned(Script[ 173] , 098080000H);	SetUnsigned(Script[ 174] , 004000000H);	SetUnsigned(Script[ 175] , 060000200H);
		SetUnsigned(Script[ 176] , 000000000H);	SetUnsigned(Script[ 177] , 047000000H);	SetUnsigned(Script[ 178] , 000000050H);	SetUnsigned(Script[ 179] , 0868B0000H);
		SetUnsigned(Script[ 180] , 000000000H);	SetUnsigned(Script[ 181] , 01E000000H);	SetUnsigned(Script[ 182] , 000000008H);	SetUnsigned(Script[ 183] , 01A000000H);
		SetUnsigned(Script[ 184] , 000000018H);	SetUnsigned(Script[ 185] , 019000000H);	SetUnsigned(Script[ 186] , 000000028H);	SetUnsigned(Script[ 187] , 01B000000H);
		SetUnsigned(Script[ 188] , 000000020H);	SetUnsigned(Script[ 189] , 01F000000H);	SetUnsigned(Script[ 190] , 000000030H);	SetUnsigned(Script[ 191] , 07C027F00H);
		SetUnsigned(Script[ 192] , 000000000H);	SetUnsigned(Script[ 193] , 060000040H);	SetUnsigned(Script[ 194] , 000000000H);	SetUnsigned(Script[ 195] , 048000000H);
		SetUnsigned(Script[ 196] , 000000000H);	SetUnsigned(Script[ 197] , 098080000H);	SetUnsigned(Script[ 198] , 004020000H);	SetUnsigned(Script[ 199] , 098080000H);
		SetUnsigned(Script[ 200] , 004010000H);
	END Init;

BEGIN
	Init
END NCRScript.
*)
