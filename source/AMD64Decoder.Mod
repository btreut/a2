MODULE AMD64Decoder; (** AUTHOR "negelef"; PURPOSE "AMD64 disassembler"; *)

IMPORT SYSTEM, Decoder, Streams;

CONST

	objFileSuffix = "Abx";

	(* max argument count *)
	maxArgs = 3;

	(* Legacy prefixes *)
	prOperand = 0;
	prAddress = 1;
	prCS = 2;
	prDS = 3;
	prES = 4;
	prFS = 5;
	prGS = 6;
	prSS = 7;
	prLOCK = 8;
	prREP = 9;
	prREPN = 10;

	prF3 = prREP;
	pr66 = prOperand;
	prF2 = prREPN;

	(* REX prefixes *)
	prREX = 11;
	prREXW = 12;
	prREXR = 13;
	prREXX = 14;
	prREXB = 15;

	(* AMD64 instruction set *)
	opInvalid = 0;
	opReserved = 1;
	opADC = 2;
	opADD = 3;
	opADDPD = 4;
	opADDPS = 5;
	opADDSD = 6;
	opADDSS = 7;
	opADDSUBPD = 8;
	opADDSUBPS = 9;
	opAND = 10;
	opANDNPD = 11;
	opANDNPS = 12;
	opANDPD = 13;
	opANDPS = 14;
	opBSF = 15;
	opBSR = 16;
	opBSWAP = 17;
	opBT = 18;
	opBTC = 19;
	opBTR = 20;
	opBTS = 21;
	opCALL = 22;
	opCBW = 23;
	opCDQ = 24;
	opCDQE = 25;
	opCLC = 26;
	opCLD = 27;
	opCLGI = 28;
	opCLI = 29;
	opCLTS = 30;
	opCMC = 31;
	opCMP = 32;
	opCMPPD = 33;
	opCMPPS = 34;
	opCMPSB = 35;
	opCMPSD = 36;
	opCMPSQ = 37;
	opCMPSS = 38;
	opCMPSW = 39;
	opCMPXCHG = 40;
	opCMPXCHG16B = 41;
	opCMPXCHG8B = 42;
	opCOMISD = 43;
	opCOMISS = 44;
	opCPUID = 45;
	opCQO = 46;
	opCVTDQ2PD = 47;
	opCVTDQ2PS = 48;
	opCVTPD2PI = 49;
	opCVTPD2PS = 50;
	opCVTPI2PD = 51;
	opCVTPI2PS = 52;
	opCVTPS2DQ = 53;
	opCVTPS2PD = 54;
	opCVTPS2PI = 55;
	opCVTSD2SI = 56;
	opCVTSD2SS = 57;
	opCVTSI2SD = 58;
	opCVTSI2SS = 59;
	opCVTSS2SD = 60;
	opCVTSS2SI = 61;
	opCVTTPD2DQ = 62;
	opCVTTPD2PI = 63;
	opCVTTPS2DQ = 64;
	opCVTTPS2PI = 65;
	opCVTTSD2SI = 66;
	opCVTTSS2SI = 67;
	opCWD = 68;
	opCWDE = 69;
	opDEC = 70;
	opDIV = 71;
	opDIVPD = 72;
	opDIVPS = 73;
	opDIVSD = 74;
	opDIVSS = 75;
	opEMMS = 76;
	opENTER = 77;
	opF2XM1 = 78;
	opFABS = 79;
	opFADD = 80;
	opFADDP = 81;
	opFBLD = 82;
	opFBSTP = 83;
	opFCHS = 84;
	opFCMOVB = 85;
	opFCMOVBE = 86;
	opFCMOVE = 87;
	opFCMOVNB = 88;
	opFCMOVNBE = 89;
	opFCMOVNE = 90;
	opFCMOVNU = 91;
	opFCMOVU = 92;
	opFCOM = 93;
	opFCOMI = 94;
	opFCOMIP = 95;
	opFCOMP = 96;
	opFCOMPP = 97;
	opFCOS = 98;
	opFDECSTP = 99;
	opFDIV = 100;
	opFDIVP = 101;
	opFDIVR = 102;
	opFDIVRP = 103;
	opFEMMS = 104;
	opFFREE = 105;
	opFIADD = 106;
	opFICOM = 107;
	opFICOMP = 108;
	opFIDIV = 109;
	opFIDIVR = 110;
	opFILD = 111;
	opFIMUL = 112;
	opFINCSTP = 113;
	opFIST = 114;
	opFISTP = 115;
	opFISTTP = 116;
	opFISUB = 117;
	opFISUBR = 118;
	opFLD = 119;
	opFLD1 = 120;
	opFLDCW = 121;
	opFLDENV = 122;
	opFLDL2E = 123;
	opFLDL2T = 124;
	opFLDLG2 = 125;
	opFLDLN2 = 126;
	opFLDPI = 127;
	opFLDZ = 128;
	opFMUL = 129;
	opFMULP = 130;
	opFNCLEX = 131;
	opFNINIT = 132;
	opFNOP = 133;
	opFNSAVE = 134;
	opFNSTCW = 135;
	opFNSTENV = 136;
	opFNSTSW = 137;
	opFPATAN = 138;
	opFPREM = 139;
	opFPREM1 = 140;
	opFPTAN = 141;
	opFRNDINT = 142;
	opFRSTOR = 143;
	opFSCALE = 144;
	opFSIN = 145;
	opFSINCOS = 146;
	opFSQRT = 147;
	opFST = 148;
	opFSTP = 149;
	opFSUB = 150;
	opFSUBP = 151;
	opFSUBR = 152;
	opFSUBRP = 153;
	opFTST = 154;
	opFUCOM = 155;
	opFUCOMI = 156;
	opFUCOMIP = 157;
	opFUCOMP = 158;
	opFUCOMPP = 159;
	opFWAIT = 160;
	opFXAM = 161;
	opFXCH = 162;
	opFXRSTOR = 163;
	opFXSAVE = 164;
	opFXTRACT = 165;
	opFYL2X = 166;
	opFYL2XP1 = 167;
	opHADDPD = 168;
	opHADDPS = 169;
	opHLT = 170;
	opHSUBPD = 171;
	opHSUBPS = 172;
	opIDIV = 173;
	opIMUL = 174;
	opIN = 175;
	opINC = 176;
	opINSB = 177;
	opINSD = 178;
	opINSW = 179;
	opINT = 180;
	opINVD = 181;
	opINVLPG = 182;
	opINVLPGA = 183;
	opIRET = 184;
	opIRETD = 185;
	opIRETQ = 186;
	opJA = 187;
	opJB = 188;
	opJBE = 189;
	opJCXZ = 190;
	opJE = 191;
	opJECXZ = 192;
	opJG = 193;
	opJGE = 194;
	opJL = 195;
	opJLE = 196;
	opJMP = 197;
	opJNB = 198;
	opJNBE = 199;
	opJNE = 200;
	opJNO = 201;
	opJNP = 202;
	opJO = 203;
	opJP = 204;
	opJRCXZ = 205;
	opJS = 206;
	opLAHF = 207;
	opLAR = 208;
	opLDDQU = 209;
	opLDMXCSR = 210;
	opLEA = 211;
	opLEAVE = 212;
	opLFENCE = 213;
	opLFS = 214;
	opLGDT = 215;
	opLGS = 216;
	opLIDT = 217;
	opLLDT = 218;
	opLMSW = 219;
	opLODSB = 220;
	opLODSD = 221;
	opLODSQ = 222;
	opLODSW = 223;
	opLOOP = 224;
	opLOOPE = 225;
	opLOOPNE = 226;
	opLSL = 227;
	opLSS = 228;
	opLTR = 229;
	opMASKMOVDQU = 230;
	opMASKMOVQ = 231;
	opMAXPD = 232;
	opMAXPS = 233;
	opMAXSD = 234;
	opMAXSS = 235;
	opMFENCE = 236;
	opMINPD = 237;
	opMINPS = 238;
	opMINSD = 239;
	opMINSS = 240;
	opMOV = 241;
	opMOVA = 242;
	opMOVAPD = 243;
	opMOVAPS = 244;
	opMOVB = 245;
	opMOVBE = 246;
	opMOVD = 247;
	opMOVDDUP = 248;
	opMOVDQ2Q = 249;
	opMOVDQA = 250;
	opMOVDQU = 251;
	opMOVE = 252;
	opMOVG = 253;
	opMOVGE = 254;
	opMOVHLPS = 255;
	opMOVHPD = 256;
	opMOVHPS = 257;
	opMOVL = 258;
	opMOVLE = 259;
	opMOVLHPS = 260;
	opMOVLPD = 261;
	opMOVLPS = 262;
	opMOVMSKPD = 263;
	opMOVMSKPS = 264;
	opMOVNB = 265;
	opMOVNBE = 266;
	opMOVNE = 267;
	opMOVNO = 268;
	opMOVNP = 269;
	opMOVNTDQ = 270;
	opMOVNTI = 271;
	opMOVNTPD = 272;
	opMOVNTPS = 273;
	opMOVNTQ = 274;
	opMOVO = 275;
	opMOVP = 276;
	opMOVQ = 277;
	opMOVQ2DQ = 278;
	opMOVS = 279;
	opMOVSB = 280;
	opMOVSD = 281;
	opMOVSHDUP = 282;
	opMOVSLDUP = 283;
	opMOVSQ = 284;
	opMOVSS = 285;
	opMOVSW = 286;
	opMOVSX = 287;
	opMOVSXD = 288;
	opMOVUPD = 289;
	opMOVUPS = 290;
	opMOVZX = 291;
	opMUL = 292;
	opMULPD = 293;
	opMULPS = 294;
	opMULSD = 295;
	opMULSS = 296;
	opNEG = 297;
	opNOP = 298;
	opNOT = 299;
	opOR = 300;
	opORPD = 301;
	opORPS = 302;
	opOUT = 303;
	opOUTSB = 304;
	opOUTSD = 305;
	opOUTSW = 306;
	opPACKSSDW = 307;
	opPACKSSWB = 308;
	opPACKUSWB = 309;
	opPADDB = 310;
	opPADDD = 311;
	opPADDQ = 312;
	opPADDSB = 313;
	opPADDSW = 314;
	opPADDUSB = 315;
	opPADDUSW = 316;
	opPADDW = 317;
	opPAND = 318;
	opPANDN = 319;
	opPAUSE = 320;
	opPAVGB = 321;
	opPAVGUSB = 322;
	opPAVGW = 323;
	opPCMPEQB = 324;
	opPCMPEQD = 325;
	opPCMPEQW = 326;
	opPCMPGTB = 327;
	opPCMPGTD = 328;
	opPCMPGTW = 329;
	opPEXTRW = 330;
	opPF2ID = 331;
	opPF2IW = 332;
	opPFACC = 333;
	opPFADD = 334;
	opPFCMPEQ = 335;
	opPFCMPGE = 336;
	opPFCMPGT = 337;
	opPFMAX = 338;
	opPFMIN = 339;
	opPFMUL = 340;
	opPFNACC = 341;
	opPFPNACC = 342;
	opPFRCP = 343;
	opPFRCPIT1 = 344;
	opPFRSQIT1 = 345;
	opPFRSQRT = 346;
	opPFSUB = 347;
	opPFSUBR = 348;
	opPI2FD = 349;
	opPI2FW = 350;
	opPINSRW = 351;
	opPMADDWD = 352;
	opPMAXSW = 353;
	opPMAXUB = 354;
	opPMINSW = 355;
	opPMINUB = 356;
	opPMOVMSKB = 357;
	opPMULHRW = 358;
	opPMULHUW = 359;
	opPMULHW = 360;
	opPMULLW = 361;
	opPMULUDQ = 362;
	opPOP = 363;
	opPOPF = 364;
	opPOPFD = 365;
	opPOPFQ = 366;
	opPOR = 367;
	opPREFETCH = 368;
	opPREFETCHNTA = 369;
	opPREFETCHT0 = 370;
	opPREFETCHT1 = 371;
	opPREFETCHT2 = 372;
	opPREFETCHW = 373;
	opPSADBW = 374;
	opPSHUFD = 375;
	opPSHUFHW = 376;
	opPSHUFLW = 377;
	opPSHUFW = 378;
	opPSLLD = 379;
	opPSLLDQ = 380;
	opPSLLQ = 381;
	opPSLLW = 382;
	opPSRAD = 383;
	opPSRAW = 384;
	opPSRLD = 385;
	opPSRLDQ = 386;
	opPSRLQ = 387;
	opPSRLW = 388;
	opPSUBB = 389;
	opPSUBD = 390;
	opPSUBQ = 391;
	opPSUBSB = 392;
	opPSUBSW = 393;
	opPSUBUSB = 394;
	opPSUBUSW = 395;
	opPSUBW = 396;
	opPSWAPD = 397;
	opPUNPCKHBW = 398;
	opPUNPCKHDQ = 399;
	opPUNPCKHQDQ = 400;
	opPUNPCKHWD = 401;
	opPUNPCKLBW = 402;
	opPUNPCKLDQ = 403;
	opPUNPCKLQDQ = 404;
	opPUNPCKLWD = 405;
	opPUSH = 406;
	opPUSHF = 407;
	opPUSHFD = 408;
	opPUSHFQ = 409;
	opPXOR = 410;
	opRCL = 411;
	opRCPPS = 412;
	opRCPSS = 413;
	opRCR = 414;
	opRDMSR = 415;
	opRDPMC = 416;
	opRDTSC = 417;
	opRDTSCP = 418;
	opRET = 419;
	opROL = 420;
	opROR = 421;
	opRSM = 422;
	opRSQRTPS = 423;
	opRSQRTSS = 424;
	opSAHF = 425;
	opSAR = 426;
	opSBB = 427;
	opSCASB = 428;
	opSCASD = 429;
	opSCASQ = 430;
	opSCASW = 431;
	opSETA = 432;
	opSETB = 433;
	opSETBE = 434;
	opSETE = 435;
	opSETG = 436;
	opSETGE = 437;
	opSETL = 438;
	opSETLE = 439;
	opSETNB = 440;
	opSETNBE = 441;
	opSETNE = 442;
	opSETNO = 443;
	opSETNP = 444;
	opSETO = 445;
	opSETP = 446;
	opSETS = 447;
	opSFENCE = 448;
	opSGDT = 449;
	opSHL = 450;
	opSHLD = 451;
	opSHR = 452;
	opSHRD = 453;
	opSHUFPD = 454;
	opSHUFPS = 455;
	opSIDT = 456;
	opSKINIT = 457;
	opSLDT = 458;
	opSMSW = 459;
	opSQRTPD = 460;
	opSQRTPS = 461;
	opSQRTSD = 462;
	opSQRTSS = 463;
	opSTC = 464;
	opSTD = 465;
	opSTGI = 466;
	opSTI = 467;
	opSTMXCSR = 468;
	opSTOSB = 469;
	opSTOSD = 470;
	opSTOSQ = 471;
	opSTOSW = 472;
	opSTR = 473;
	opSUB = 474;
	opSUBPD = 475;
	opSUBPS = 476;
	opSUBSD = 477;
	opSUBSS = 478;
	opSWAPGS = 479;
	opSYSCALL = 480;
	opSYSRET = 481;
	opTEST = 482;
	opUCOMISD = 483;
	opUCOMISS = 484;
	opUD2 = 485;
	opUNPCKHPD = 486;
	opUNPCKHPS = 487;
	opUNPCKLPD = 488;
	opUNPCKLPS = 489;
	opVERR = 490;
	opVERW = 491;
	opVMLOAD = 492;
	opVMMCALL = 493;
	opVMRUN = 494;
	opVMSAVE = 495;
	opWBINVD = 496;
	opWRMSR = 497;
	opXADD = 498;
	opXCHG = 499;
	opXLAT = 500;
	opXOR = 501;
	opXORPD = 502;
	opXORPS = 503;

	(* GP registers offsets *)
	regNONE = 0;

	regrAX = 0;
	regrCX = 1;
	regrDX = 2;
	regrBX = 3;
	regrSP = 4;
	regrBP = 5;
	regrSI = 6;
	regrDI = 7;
	regr8 = 8;
	regr9 = 9;
	regr10 = 10;
	regr11 = 11;
	regr12 = 12;
	regr13 = 13;
	regr14 = 14;
	regr15 = 15;

	(* 8bit GP registers *)
	regAL = 1;
	regCL = 2;
	regDL = 3;
	regBL = 4;
	regAH = 5; (* addressable only without REX prefix *)
	regCH = 6; (* addressable only without REX prefix *)
	regDH = 7; (* addressable only without REX prefix *)
	regBH = 8; (* addressable only without REX prefix *)
	regR8B = 9;
	regR9B = 10;
	regR10B = 11;
	regR11B = 12;
	regR12B = 13;
	regR13B = 14;
	regR14B = 15;
	regR15B = 16;
	regSPL = 17; (* addressable only with REX prefix *)
	regBPL = 18; (* addressable only with REX prefix *)
	regSIL = 19; (* addressable only with REX prefix *)
	regDIL = 20; (* addressable only with REX prefix *)

	(* 16bit GP registers *)
	regAX = 21;
	regCX = 22;
	regDX = 23;
	regBX = 24;
	regSP = 25;
	regBP = 26;
	regSI = 27;
	regDI = 28;
	regR8W = 29;
	regR9W = 30;
	regR10W = 31;
	regR11W = 32;
	regR12W = 33;
	regR13W = 34;
	regR14W = 35;
	regR15W = 36;

	(* 32bit GP registers *)
	regEAX = 37;
	regECX = 38;
	regEDX = 39;
	regEBX = 40;
	regESP = 41;
	regEBP = 42;
	regESI = 43;
	regEDI = 44;
	regR8D = 45;
	regR9D = 46;
	regR10D = 47;
	regR11D = 48;
	regR12D = 49;
	regR13D = 50;
	regR14D = 51;
	regR15D = 52;

	(* 64bit GP registers *)
	regRAX = 53;
	regRCX = 54;
	regRDX = 55;
	regRBX = 56;
	regRSP = 57;
	regRBP = 58;
	regRSI = 59;
	regRDI = 60;
	regR8 = 61;
	regR9 = 62;
	regR10 = 63;
	regR11 = 64;
	regR12 = 65;
	regR13 = 66;
	regR14 = 67;
	regR15 = 68;

	(* segment registers *)
	regES = 69;
	regCS = 70;
	regSS = 71;
	regDS = 72;
	regFS = 73;
	regGS = 74;

	(* floating point stack registers *)
	regST0 = 75;
	regST1 = 76;
	regST2 = 77;
	regST3 = 78;
	regST4 = 79;
	regST5 = 80;
	regST6 = 81;
	regST7 = 82;

	(* control registers *)
	regCR0 = 83;
	regCR1 = 84;
	regCR2 = 85;
	regCR3 = 86;
	regCR4 = 87;
	regCR5 = 88;
	regCR6 = 89;
	regCR7 = 90;
	regCR8 = 91;
	regCR9 = 92;
	regCR10 = 93;
	regCR11 = 94;
	regCR12 = 95;
	regCR13 = 96;
	regCR14 = 97;
	regCR15 = 98;

	(* debug registers *)
	regDR0 = 99;
	regDR1 = 100;
	regDR2 = 101;
	regDR3 = 102;
	regDR4 = 103;
	regDR5 = 104;
	regDR6 = 105;
	regDR7 = 106;
	regDR8 = 107;
	regDR9 = 108;
	regDR10 = 109;
	regDR11 = 110;
	regDR12 = 111;
	regDR13 = 112;
	regDR14 = 113;
	regDR15 = 114;

	(* xmm registers *)
	regXMM0 = 115;
	regXMM1 = 116;
	regXMM2 = 117;
	regXMM3 = 118;
	regXMM4 = 119;
	regXMM5 = 120;
	regXMM6 = 121;
	regXMM7 = 122;
	regXMM8 = 123;
	regXMM9 = 124;
	regXMM10 = 125;
	regXMM11 = 126;
	regXMM12 = 127;
	regXMM13 = 128;
	regXMM14 = 129;
	regXMM15 = 130;

	(* mmx registers *)
	regMMX0 = 131;
	regMMX1 = 132;
	regMMX2 = 133;
	regMMX3 = 134;
	regMMX4 = 135;
	regMMX5 = 136;
	regMMX6 = 137;
	regMMX7 = 138;

	regIP = 139;
	regRIP = 140;

TYPE

	(* generic argument *)
	Arg = OBJECT

		PROCEDURE Print (w : Streams.Writer);
		END Print;

	END Arg;

	(* Immediate argument *)
	ArgImm = OBJECT (Arg)
		VAR
			imm : HUGEINT;

		PROCEDURE &New *(imm : HUGEINT);
		BEGIN SELF.imm := imm;
		END New;

		PROCEDURE Print (w : Streams.Writer);
		BEGIN PrintImm (imm, w);
		END Print;

	END ArgImm;

	(* register argument *)
	ArgReg = OBJECT (Arg)
		VAR
			reg : LONGINT;

		PROCEDURE &New *(reg : LONGINT);
		BEGIN SELF.reg := reg;
		END New;

		PROCEDURE Print (w : Streams.Writer);
		BEGIN PrintReg (w, reg);
		END Print;

	END ArgReg;

	(* memory reference argument *)
	ArgMem = OBJECT (Arg)
		VAR
			segment, reg, scale, base: LONGINT; disp : HUGEINT;

		PROCEDURE &New *(segment, reg, scale , base: LONGINT; disp : HUGEINT);
		BEGIN
			SELF.segment := segment;
			SELF.reg := reg;
			SELF.scale := scale;
			SELF.base := base;
			SELF.disp := disp;
		END New;

		PROCEDURE Print (w : Streams.Writer);
		BEGIN
			IF segment # regNONE THEN
				PrintReg (w, segment); w.String (":")
			END;

			w.String ("[");

			IF reg # regNONE THEN
				PrintReg (w, reg);
				IF scale > 1 THEN w.String ("*"); w.Int (scale, 0) END;
			END;

			IF base = regNONE THEN
				IF (reg = regNONE) THEN
					PrintImm (disp, w);
				ELSIF disp > 0 THEN
					w.String (" + ");
					PrintImm (disp, w);
				ELSIF disp < 0 THEN
					w.String (" - ");
					PrintImm (-disp, w);
				END
			ELSE
				IF (reg # regNONE) THEN
					w.String (" + ");
				END;
				PrintReg (w, base);
				IF disp > 0 THEN
					w.String (" + ");
					PrintImm (disp, w);
				ELSIF disp < 0 THEN
					w.String (" - ");
					PrintImm (-disp, w);
				END
			END;

			w.String ("]");
		END Print;

	END ArgMem;

	(* AMD64 instruction *)
	AMD64Opcode = OBJECT (Decoder.Opcode)
	VAR
		prefixCount : LONGINT;
		prefixes : SET;
		instr: LONGINT;
		arg : ARRAY maxArgs OF Arg;
		hidePrefixes: BOOLEAN;

		PROCEDURE &New*(proc : Decoder.ProcedureInfo; stream : Streams.Writer);
		BEGIN
			New^(proc, stream);
			prefixCount := 0;
			prefixes := {};
			hidePrefixes := FALSE;
		END New;

		PROCEDURE PrintOpcodeBytes (w : Streams.Writer);
		VAR
			i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN (code) - 1 DO
				WriteHex8 (ORD (code[i]), w);
				IF i < prefixCount THEN
					w.String (" | ");
				ELSE
					w.String (" ");
				END
			END
		END PrintOpcodeBytes;

		PROCEDURE PrintInstruction (w : Streams.Writer);
		BEGIN
			IF ~hidePrefixes THEN
				IF prREP IN prefixes THEN w.String ("REP ") END;
				IF prREPN IN prefixes THEN w.String ("REPN ") END;
			END;

			IF prLOCK IN prefixes THEN w.String ("LOCK ") END;

			CASE instr OF
			| opInvalid: w.String ("Invalid");
			| opReserved: w.String ("Reserved");
			| opADC: w.String ("ADC");
			| opADD: w.String ("ADD");
			| opADDPD: w.String ("ADDPD");
			| opADDPS: w.String ("ADDPS");
			| opADDSD: w.String ("ADDSD");
			| opADDSS: w.String ("ADDSS");
			| opADDSUBPD: w.String ("ADDSUBPD");
			| opADDSUBPS: w.String ("ADDSUBPS");
			| opAND: w.String ("AND");
			| opANDNPD: w.String ("ANDNPD");
			| opANDNPS: w.String ("ANDNPS");
			| opANDPD: w.String ("ANDPD");
			| opANDPS: w.String ("ANDPS");
			| opBSF: w.String ("BSF");
			| opBSR: w.String ("BSR");
			| opBSWAP: w.String ("BSWAP");
			| opBT: w.String ("BT");
			| opBTC: w.String ("BTC");
			| opBTR: w.String ("BTR");
			| opBTS: w.String ("BTS");
			| opCALL: w.String ("CALL");
			| opCBW: w.String ("CBW");
			| opCDQ: w.String ("CDQ");
			| opCDQE: w.String ("CDQE");
			| opCLC: w.String ("CLC");
			| opCLD: w.String ("CLD");
			| opCLGI: w.String ("CLGI");
			| opCLI: w.String ("CLI");
			| opCLTS: w.String ("CLTS");
			| opCMC: w.String ("CMC");
			| opCMP: w.String ("CMP");
			| opCMPPD: w.String ("CMPPD");
			| opCMPPS: w.String ("CMPPS");
			| opCMPSB: w.String ("CMPSB");
			| opCMPSD: w.String ("CMPSD");
			| opCMPSQ: w.String ("CMPSQ");
			| opCMPSS: w.String ("CMPSS");
			| opCMPSW: w.String ("CMPSW");
			| opCMPXCHG: w.String ("CMPXCHG");
			| opCMPXCHG16B: w.String ("CMPXCHG16B");
			| opCMPXCHG8B: w.String ("CMPXCHG8B");
			| opCOMISD: w.String ("COMISD");
			| opCOMISS: w.String ("COMISS");
			| opCPUID: w.String ("CPUID");
			| opCQO: w.String ("CQO");
			| opCVTDQ2PD: w.String ("CVTDQ2PD");
			| opCVTDQ2PS: w.String ("CVTDQ2PS");
			| opCVTPD2PI: w.String ("CVTPD2PI");
			| opCVTPD2PS: w.String ("CVTPD2PS");
			| opCVTPI2PD: w.String ("CVTPI2PD");
			| opCVTPI2PS: w.String ("CVTPI2PS");
			| opCVTPS2DQ: w.String ("CVTPS2DQ");
			| opCVTPS2PD: w.String ("CVTPS2PD");
			| opCVTPS2PI: w.String ("CVTPS2PI");
			| opCVTSD2SI: w.String ("CVTSD2SI");
			| opCVTSD2SS: w.String ("CVTSD2SS");
			| opCVTSI2SD: w.String ("CVTSI2SD");
			| opCVTSI2SS: w.String ("CVTSI2SS");
			| opCVTSS2SD: w.String ("CVTSS2SD");
			| opCVTSS2SI: w.String ("CVTSS2SI");
			| opCVTTPD2DQ: w.String ("CVTTPD2DQ");
			| opCVTTPD2PI: w.String ("CVTTPD2PI");
			| opCVTTPS2DQ: w.String ("CVTTPS2DQ");
			| opCVTTPS2PI: w.String ("CVTTPS2PI");
			| opCVTTSD2SI: w.String ("CVTTSD2SI");
			| opCVTTSS2SI: w.String ("CVTTSS2SI");
			| opCWD: w.String ("CWD");
			| opCWDE: w.String ("CWDE");
			| opDEC: w.String ("DEC");
			| opDIV: w.String ("DIV");
			| opDIVPD: w.String ("DIVPD");
			| opDIVPS: w.String ("DIVPS");
			| opDIVSD: w.String ("DIVSD");
			| opDIVSS: w.String ("DIVSS");
			| opEMMS: w.String ("EMMS");
			| opENTER: w.String ("ENTER");
			| opF2XM1: w.String ("F2XM1");
			| opFABS: w.String ("FABS");
			| opFADD: w.String ("FADD");
			| opFADDP: w.String ("FADDP");
			| opFBLD: w.String ("FBLD");
			| opFBSTP: w.String ("FBSTP");
			| opFCHS: w.String ("FCHS");
			| opFCMOVB: w.String ("FCMOVB");
			| opFCMOVBE: w.String ("FCMOVBE");
			| opFCMOVE: w.String ("FCMOVE");
			| opFCMOVNB: w.String ("FCMOVNB");
			| opFCMOVNBE: w.String ("FCMOVNBE");
			| opFCMOVNE: w.String ("FCMOVNE");
			| opFCMOVNU: w.String ("FCMOVNU");
			| opFCMOVU: w.String ("FCMOVU");
			| opFCOM: w.String ("FCOM");
			| opFCOMI: w.String ("FCOMI");
			| opFCOMIP: w.String ("FCOMIP");
			| opFCOMP: w.String ("FCOMP");
			| opFCOMPP: w.String ("FCOMPP");
			| opFCOS: w.String ("FCOS");
			| opFDECSTP: w.String ("FDECSTP");
			| opFDIV: w.String ("FDIV");
			| opFDIVP: w.String ("FDIVP");
			| opFDIVR: w.String ("FDIVR");
			| opFDIVRP: w.String ("FDIVRP");
			| opFEMMS: w.String ("FEMMS");
			| opFFREE: w.String ("FFREE");
			| opFIADD: w.String ("FIADD");
			| opFICOM: w.String ("FICOM");
			| opFICOMP: w.String ("FICOMP");
			| opFIDIV: w.String ("FIDIV");
			| opFIDIVR: w.String ("FIDIVR");
			| opFILD: w.String ("FILD");
			| opFIMUL: w.String ("FIMUL");
			| opFINCSTP: w.String ("FINCSTP");
			| opFIST: w.String ("FIST");
			| opFISTP: w.String ("FISTP");
			| opFISTTP: w.String ("FISTTP");
			| opFISUB: w.String ("FISUB");
			| opFISUBR: w.String ("FISUBR");
			| opFLD: w.String ("FLD");
			| opFLD1: w.String ("FLD1");
			| opFLDCW: w.String ("FLDCW");
			| opFLDENV: w.String ("FLDENV");
			| opFLDL2E: w.String ("FLDL2E");
			| opFLDL2T: w.String ("FLDL2T");
			| opFLDLG2: w.String ("FLDLG2");
			| opFLDLN2: w.String ("FLDLN2");
			| opFLDPI: w.String ("FLDPI");
			| opFLDZ: w.String ("FLDZ");
			| opFMUL: w.String ("FMUL");
			| opFMULP: w.String ("FMULP");
			| opFNCLEX: w.String ("FNCLEX");
			| opFNINIT: w.String ("FNINIT");
			| opFNOP: w.String ("FNOP");
			| opFNSAVE: w.String ("FNSAVE");
			| opFNSTCW: w.String ("FNSTCW");
			| opFNSTENV: w.String ("FNSTENV");
			| opFNSTSW: w.String ("FNSTSW");
			| opFPATAN: w.String ("FPATAN");
			| opFPREM: w.String ("FPREM");
			| opFPREM1: w.String ("FPREM1");
			| opFPTAN: w.String ("FPTAN");
			| opFRNDINT: w.String ("FRNDINT");
			| opFRSTOR: w.String ("FRSTOR");
			| opFSCALE: w.String ("FSCALE");
			| opFSIN: w.String ("FSIN");
			| opFSINCOS: w.String ("FSINCOS");
			| opFSQRT: w.String ("FSQRT");
			| opFST: w.String ("FST");
			| opFSTP: w.String ("FSTP");
			| opFSUB: w.String ("FSUB");
			| opFSUBP: w.String ("FSUBP");
			| opFSUBR: w.String ("FSUBR");
			| opFSUBRP: w.String ("FSUBRP");
			| opFTST: w.String ("FTST");
			| opFUCOM: w.String ("FUCOM");
			| opFUCOMI: w.String ("FUCOMI");
			| opFUCOMIP: w.String ("FUCOMIP");
			| opFUCOMP: w.String ("FUCOMP");
			| opFUCOMPP: w.String ("FUCOMPP");
			| opFWAIT: w.String ("FWAIT");
			| opFXAM: w.String ("FXAM");
			| opFXCH: w.String ("FXCH");
			| opFXRSTOR: w.String ("FXRSTOR");
			| opFXSAVE: w.String ("FXSAVE");
			| opFXTRACT: w.String ("FXTRACT");
			| opFYL2X: w.String ("FYL2X");
			| opFYL2XP1: w.String ("FYL2XP1");
			| opHADDPD: w.String ("HADDPD");
			| opHADDPS: w.String ("HADDPS");
			| opHLT: w.String ("HLT");
			| opHSUBPD: w.String ("HSUBPD");
			| opHSUBPS: w.String ("HSUBPS");
			| opIDIV: w.String ("IDIV");
			| opIMUL: w.String ("IMUL");
			| opIN: w.String ("IN");
			| opINC: w.String ("INC");
			| opINSB: w.String ("INSB");
			| opINSD: w.String ("INSD");
			| opINSW: w.String ("INSW");
			| opINT: w.String ("INT");
			| opINVD: w.String ("INVD");
			| opINVLPG: w.String ("INVLPG");
			| opINVLPGA: w.String ("INVLPGA");
			| opIRET: w.String ("IRET");
			| opIRETD: w.String ("IRETD");
			| opIRETQ: w.String ("IRETQ");
			| opJA: w.String ("JA");
			| opJB: w.String ("JB");
			| opJBE: w.String ("JBE");
			| opJCXZ: w.String ("JCXZ");
			| opJE: w.String ("JE");
			| opJECXZ: w.String ("JECXZ");
			| opJG: w.String ("JG");
			| opJGE: w.String ("JGE");
			| opJL: w.String ("JL");
			| opJLE: w.String ("JLE");
			| opJMP: w.String ("JMP");
			| opJNB: w.String ("JNB");
			| opJNBE: w.String ("JNBE");
			| opJNE: w.String ("JNE");
			| opJNO: w.String ("JNO");
			| opJNP: w.String ("JNP");
			| opJO: w.String ("JO");
			| opJP: w.String ("JP");
			| opJRCXZ: w.String ("JRCXZ");
			| opJS: w.String ("JS");
			| opLAHF: w.String ("LAHF");
			| opLAR: w.String ("LAR");
			| opLDDQU: w.String ("LDDQU");
			| opLDMXCSR: w.String ("LDMXCSR");
			| opLEA: w.String ("LEA");
			| opLEAVE: w.String ("LEAVE");
			| opLFENCE: w.String ("LFENCE");
			| opLFS: w.String ("LFS");
			| opLGDT: w.String ("LGDT");
			| opLGS: w.String ("LGS");
			| opLIDT: w.String ("LIDT");
			| opLLDT: w.String ("LLDT");
			| opLMSW: w.String ("LMSW");
			| opLODSB: w.String ("LODSB");
			| opLODSD: w.String ("LODSD");
			| opLODSQ: w.String ("LODSQ");
			| opLODSW: w.String ("LODSW");
			| opLOOP: w.String ("LOOP");
			| opLOOPE: w.String ("LOOPE");
			| opLOOPNE: w.String ("LOOPNE");
			| opLSL: w.String ("LSL");
			| opLSS: w.String ("LSS");
			| opLTR: w.String ("LTR");
			| opMASKMOVDQU: w.String ("MASKMOVDQU");
			| opMASKMOVQ: w.String ("MASKMOVQ");
			| opMAXPD: w.String ("MAXPD");
			| opMAXPS: w.String ("MAXPS");
			| opMAXSD: w.String ("MAXSD");
			| opMAXSS: w.String ("MAXSS");
			| opMFENCE: w.String ("MFENCE");
			| opMINPD: w.String ("MINPD");
			| opMINPS: w.String ("MINPS");
			| opMINSD: w.String ("MINSD");
			| opMINSS: w.String ("MINSS");
			| opMOV: w.String ("MOV");
			| opMOVA: w.String ("MOVA");
			| opMOVAPD: w.String ("MOVAPD");
			| opMOVAPS: w.String ("MOVAPS");
			| opMOVB: w.String ("MOVB");
			| opMOVBE: w.String ("MOVBE");
			| opMOVD: w.String ("MOVD");
			| opMOVDDUP: w.String ("MOVDDUP");
			| opMOVDQ2Q: w.String ("MOVDQ2Q");
			| opMOVDQA: w.String ("MOVDQA");
			| opMOVDQU: w.String ("MOVDQU");
			| opMOVE: w.String ("MOVE");
			| opMOVG: w.String ("MOVG");
			| opMOVGE: w.String ("MOVGE");
			| opMOVHLPS: w.String ("MOVHLPS");
			| opMOVHPD: w.String ("MOVHPD");
			| opMOVHPS: w.String ("MOVHPS");
			| opMOVL: w.String ("MOVL");
			| opMOVLE: w.String ("MOVLE");
			| opMOVLHPS: w.String ("MOVLHPS");
			| opMOVLPD: w.String ("MOVLPD");
			| opMOVLPS: w.String ("MOVLPS");
			| opMOVMSKPD: w.String ("MOVMSKPD");
			| opMOVMSKPS: w.String ("MOVMSKPS");
			| opMOVNB: w.String ("MOVNB");
			| opMOVNBE: w.String ("MOVNBE");
			| opMOVNE: w.String ("MOVNE");
			| opMOVNO: w.String ("MOVNO");
			| opMOVNP: w.String ("MOVNP");
			| opMOVNTDQ: w.String ("MOVNTDQ");
			| opMOVNTI: w.String ("MOVNTI");
			| opMOVNTPD: w.String ("MOVNTPD");
			| opMOVNTPS: w.String ("MOVNTPS");
			| opMOVNTQ: w.String ("MOVNTQ");
			| opMOVO: w.String ("MOVO");
			| opMOVP: w.String ("MOVP");
			| opMOVQ: w.String ("MOVQ");
			| opMOVQ2DQ: w.String ("MOVQ2DQ");
			| opMOVS: w.String ("MOVS");
			| opMOVSB: w.String ("MOVSB");
			| opMOVSD: w.String ("MOVSD");
			| opMOVSHDUP: w.String ("MOVSHDUP");
			| opMOVSLDUP: w.String ("MOVSLDUP");
			| opMOVSQ: w.String ("MOVSQ");
			| opMOVSS: w.String ("MOVSS");
			| opMOVSW: w.String ("MOVSW");
			| opMOVSX: w.String ("MOVSX");
			| opMOVSXD: w.String ("MOVSXD");
			| opMOVUPD: w.String ("MOVUPD");
			| opMOVUPS: w.String ("MOVUPS");
			| opMOVZX: w.String ("MOVZX");
			| opMUL: w.String ("MUL");
			| opMULPD: w.String ("MULPD");
			| opMULPS: w.String ("MULPS");
			| opMULSD: w.String ("MULSD");
			| opMULSS: w.String ("MULSS");
			| opNEG: w.String ("NEG");
			| opNOP: w.String ("NOP");
			| opNOT: w.String ("NOT");
			| opOR: w.String ("OR");
			| opORPD: w.String ("ORPD");
			| opORPS: w.String ("ORPS");
			| opOUT: w.String ("OUT");
			| opOUTSB: w.String ("OUTSB");
			| opOUTSD: w.String ("OUTSD");
			| opOUTSW: w.String ("OUTSW");
			| opPACKSSDW: w.String ("PACKSSDW");
			| opPACKSSWB: w.String ("PACKSSWB");
			| opPACKUSWB: w.String ("PACKUSWB");
			| opPADDB: w.String ("PADDB");
			| opPADDD: w.String ("PADDD");
			| opPADDQ: w.String ("PADDQ");
			| opPADDSB: w.String ("PADDSB");
			| opPADDSW: w.String ("PADDSW");
			| opPADDUSB: w.String ("PADDUSB");
			| opPADDUSW: w.String ("PADDUSW");
			| opPADDW: w.String ("PADDW");
			| opPAND: w.String ("PAND");
			| opPANDN: w.String ("PANDN");
			| opPAUSE: w.String ("PAUSE");
			| opPAVGB: w.String ("PAVGB");
			| opPAVGUSB: w.String ("PAVGUSB");
			| opPAVGW: w.String ("PAVGW");
			| opPCMPEQB: w.String ("PCMPEQB");
			| opPCMPEQD: w.String ("PCMPEQD");
			| opPCMPEQW: w.String ("PCMPEQW");
			| opPCMPGTB: w.String ("PCMPGTB");
			| opPCMPGTD: w.String ("PCMPGTD");
			| opPCMPGTW: w.String ("PCMPGTW");
			| opPEXTRW: w.String ("PEXTRW");
			| opPF2ID: w.String ("PF2ID");
			| opPF2IW: w.String ("PF2IW");
			| opPFACC: w.String ("PFACC");
			| opPFADD: w.String ("PFADD");
			| opPFCMPEQ: w.String ("PFCMPEQ");
			| opPFCMPGE: w.String ("PFCMPGE");
			| opPFCMPGT: w.String ("PFCMPGT");
			| opPFMAX: w.String ("PFMAX");
			| opPFMIN: w.String ("PFMIN");
			| opPFMUL: w.String ("PFMUL");
			| opPFNACC: w.String ("PFNACC");
			| opPFPNACC: w.String ("PFPNACC");
			| opPFRCP: w.String ("PFRCP");
			| opPFRCPIT1: w.String ("PFRCPIT1");
			| opPFRSQIT1: w.String ("PFRSQIT1");
			| opPFRSQRT: w.String ("PFRSQRT");
			| opPFSUB: w.String ("PFSUB");
			| opPFSUBR: w.String ("PFSUBR");
			| opPI2FD: w.String ("PI2FD");
			| opPI2FW: w.String ("PI2FW");
			| opPINSRW: w.String ("PINSRW");
			| opPMADDWD: w.String ("PMADDWD");
			| opPMAXSW: w.String ("PMAXSW");
			| opPMAXUB: w.String ("PMAXUB");
			| opPMINSW: w.String ("PMINSW");
			| opPMINUB: w.String ("PMINUB");
			| opPMOVMSKB: w.String ("PMOVMSKB");
			| opPMULHRW: w.String ("PMULHRW");
			| opPMULHUW: w.String ("PMULHUW");
			| opPMULHW: w.String ("PMULHW");
			| opPMULLW: w.String ("PMULLW");
			| opPMULUDQ: w.String ("PMULUDQ");
			| opPOP: w.String ("POP");
			| opPOPF: w.String ("POPF");
			| opPOPFD: w.String ("POPFD");
			| opPOPFQ: w.String ("POPFQ");
			| opPOR: w.String ("POR");
			| opPREFETCH: w.String ("PREFETCH");
			| opPREFETCHNTA: w.String ("PREFETCHNTA");
			| opPREFETCHT0: w.String ("PREFETCHT0");
			| opPREFETCHT1: w.String ("PREFETCHT1");
			| opPREFETCHT2: w.String ("PREFETCHT2");
			| opPREFETCHW: w.String ("PREFETCHW");
			| opPSADBW: w.String ("PSADBW");
			| opPSHUFD: w.String ("PSHUFD");
			| opPSHUFHW: w.String ("PSHUFHW");
			| opPSHUFLW: w.String ("PSHUFLW");
			| opPSHUFW: w.String ("PSHUFW");
			| opPSLLD: w.String ("PSLLD");
			| opPSLLDQ: w.String ("PSLLDQ");
			| opPSLLQ: w.String ("PSLLQ");
			| opPSLLW: w.String ("PSLLW");
			| opPSRAD: w.String ("PSRAD");
			| opPSRAW: w.String ("PSRAW");
			| opPSRLD: w.String ("PSRLD");
			| opPSRLDQ: w.String ("PSRLDQ");
			| opPSRLQ: w.String ("PSRLQ");
			| opPSRLW: w.String ("PSRLW");
			| opPSUBB: w.String ("PSUBB");
			| opPSUBD: w.String ("PSUBD");
			| opPSUBQ: w.String ("PSUBQ");
			| opPSUBSB: w.String ("PSUBSB");
			| opPSUBSW: w.String ("PSUBSW");
			| opPSUBUSB: w.String ("PSUBUSB");
			| opPSUBUSW: w.String ("PSUBUSW");
			| opPSUBW: w.String ("PSUBW");
			| opPSWAPD: w.String ("PSWAPD");
			| opPUNPCKHBW: w.String ("PUNPCKHBW");
			| opPUNPCKHDQ: w.String ("PUNPCKHDQ");
			| opPUNPCKHQDQ: w.String ("PUNPCKHQDQ");
			| opPUNPCKHWD: w.String ("PUNPCKHWD");
			| opPUNPCKLBW: w.String ("PUNPCKLBW");
			| opPUNPCKLDQ: w.String ("PUNPCKLDQ");
			| opPUNPCKLQDQ: w.String ("PUNPCKLQDQ");
			| opPUNPCKLWD: w.String ("PUNPCKLWD");
			| opPUSH: w.String ("PUSH");
			| opPUSHF: w.String ("PUSHF");
			| opPUSHFD: w.String ("PUSHFD");
			| opPUSHFQ: w.String ("PUSHFQ");
			| opPXOR: w.String ("PXOR");
			| opRCL: w.String ("RCL");
			| opRCPPS: w.String ("RCPPS");
			| opRCPSS: w.String ("RCPSS");
			| opRCR: w.String ("RCR");
			| opRDMSR: w.String ("RDMSR");
			| opRDPMC: w.String ("RDPMC");
			| opRDTSC: w.String ("RDTSC");
			| opRDTSCP: w.String ("RDTSCP");
			| opRET: w.String ("RET");
			| opROL: w.String ("ROL");
			| opROR: w.String ("ROR");
			| opRSM: w.String ("RSM");
			| opRSQRTPS: w.String ("RSQRTPS");
			| opRSQRTSS: w.String ("RSQRTSS");
			| opSAHF: w.String ("SAHF");
			| opSAR: w.String ("SAR");
			| opSBB: w.String ("SBB");
			| opSCASB: w.String ("SCASB");
			| opSCASD: w.String ("SCASD");
			| opSCASQ: w.String ("SCASQ");
			| opSCASW: w.String ("SCASW");
			| opSETA: w.String ("SETA");
			| opSETB: w.String ("SETB");
			| opSETBE: w.String ("SETBE");
			| opSETE: w.String ("SETE");
			| opSETG: w.String ("SETG");
			| opSETGE: w.String ("SETGE");
			| opSETL: w.String ("SETL");
			| opSETLE: w.String ("SETLE");
			| opSETNB: w.String ("SETNB");
			| opSETNBE: w.String ("SETNBE");
			| opSETNE: w.String ("SETNE");
			| opSETNO: w.String ("SETNO");
			| opSETNP: w.String ("SETNP");
			| opSETO: w.String ("SETO");
			| opSETP: w.String ("SETP");
			| opSETS: w.String ("SETS");
			| opSFENCE: w.String ("SFENCE");
			| opSGDT: w.String ("SGDT");
			| opSHL: w.String ("SHL");
			| opSHLD: w.String ("SHLD");
			| opSHR: w.String ("SHR");
			| opSHRD: w.String ("SHRD");
			| opSHUFPD: w.String ("SHUFPD");
			| opSHUFPS: w.String ("SHUFPS");
			| opSIDT: w.String ("SIDT");
			| opSKINIT: w.String ("SKINIT");
			| opSLDT: w.String ("SLDT");
			| opSMSW: w.String ("SMSW");
			| opSQRTPD: w.String ("SQRTPD");
			| opSQRTPS: w.String ("SQRTPS");
			| opSQRTSD: w.String ("SQRTSD");
			| opSQRTSS: w.String ("SQRTSS");
			| opSTC: w.String ("STC");
			| opSTD: w.String ("STD");
			| opSTGI: w.String ("STGI");
			| opSTI: w.String ("STI");
			| opSTMXCSR: w.String ("STMXCSR");
			| opSTOSB: w.String ("STOSB");
			| opSTOSD: w.String ("STOSD");
			| opSTOSQ: w.String ("STOSQ");
			| opSTOSW: w.String ("STOSW");
			| opSTR: w.String ("STR");
			| opSUB: w.String ("SUB");
			| opSUBPD: w.String ("SUBPD");
			| opSUBPS: w.String ("SUBPS");
			| opSUBSD: w.String ("SUBSD");
			| opSUBSS: w.String ("SUBSS");
			| opSWAPGS: w.String ("SWAPGS");
			| opSYSCALL: w.String ("SYSCALL");
			| opSYSRET: w.String ("SYSRET");
			| opTEST: w.String ("TEST");
			| opUCOMISD: w.String ("UCOMISD");
			| opUCOMISS: w.String ("UCOMISS");
			| opUD2: w.String ("UD2");
			| opUNPCKHPD: w.String ("UNPCKHPD");
			| opUNPCKHPS: w.String ("UNPCKHPS");
			| opUNPCKLPD: w.String ("UNPCKLPD");
			| opUNPCKLPS: w.String ("UNPCKLPS");
			| opVERR: w.String ("VERR");
			| opVERW: w.String ("VERW");
			| opVMLOAD: w.String ("VMLOAD");
			| opVMMCALL: w.String ("VMMCALL");
			| opVMRUN: w.String ("VMRUN");
			| opVMSAVE: w.String ("VMSAVE");
			| opWBINVD: w.String ("WBINVD");
			| opWRMSR: w.String ("WRMSR");
			| opXADD: w.String ("XADD");
			| opXCHG: w.String ("XCHG");
			| opXLAT: w.String ("XLAT");
			| opXOR: w.String ("XOR");
			| opXORPD: w.String ("XORPD");
			| opXORPS: w.String ("XORPS");
			END;
		END PrintInstruction;

		PROCEDURE PrintArguments (w : Streams.Writer);
		VAR
			i: LONGINT;
		BEGIN
			FOR i := 0 TO maxArgs - 1 DO
				IF arg[i] # NIL THEN
					IF i > 0 THEN w.String (", ") END;
				 	arg[i].Print (w);
				END
			END
		END PrintArguments;

		PROCEDURE PrintVariables (w : Streams.Writer);
		VAR
			i, count: LONGINT;
			argMem: ArgMem;
			field : Decoder.FieldInfo;

		BEGIN
			(* actually copied from Decoder.... *)
			count := 0;
			FOR i := 0 TO maxArgs - 1 DO
				IF (arg[i] # NIL) & (arg[i] IS ArgMem) THEN
					argMem := arg[i](ArgMem);
					IF (argMem.reg = regRBP) OR (argMem.reg = regEBP) THEN
						field := proc.GetFieldAtOffset(SHORT (argMem.disp));
						IF field # NIL THEN
							field.AddMarkerPosition(w.Pos());
							IF count > 0 THEN
								w.String(", ")
							END;
							w.String(field.name);
							w.String(": ");
							argMem.Print (w);
							INC (count);
						END
					END
				END
			END
		END PrintVariables;

	END AMD64Opcode;

	(* AMD dissassembler*)
	AMD64Decoder = OBJECT (Decoder.Decoder)

		PROCEDURE NewOpcode() : Decoder.Opcode;
		VAR
			opcode : AMD64Opcode;
		BEGIN
			NEW(opcode, currentProc, outputStreamWriter);
			RETURN opcode
		END NewOpcode;

		PROCEDURE DecodeThis(opcode : Decoder.Opcode);
		VAR
			opc : AMD64Opcode;
			byte, code, arg, mod, segment, reg, rm, scale, index, base, disp: LONGINT;
			modRM : BOOLEAN;

			PROCEDURE ReadImm8 (): LONGINT;
			BEGIN
				RETURN ORD (ReadChar ());
			END ReadImm8;

			PROCEDURE ReadImm16 (): LONGINT;
			BEGIN
				RETURN ReadInt ();
			END ReadImm16;

			PROCEDURE ReadImm32 (): LONGINT;
			BEGIN
				RETURN ReadLInt ();
			END ReadImm32;

			PROCEDURE ReadImm64 (): HUGEINT;
			BEGIN
				RETURN ReadHInt ();
			END ReadImm64;

			PROCEDURE ReadOffset8 (): LONGINT;
			VAR
				offset: LONGINT;
			BEGIN
				offset := ORD (ReadChar ());
				IF offset >= 080H THEN DEC (offset, 100H) END;
				RETURN offset;
			END ReadOffset8;

			PROCEDURE ReadOffset16 (): LONGINT;
			VAR
				offset: LONGINT;
			BEGIN
				offset := ReadInt ();
				IF offset >= 08000H THEN DEC (offset, 10000H) END;
				RETURN offset;
			END ReadOffset16;

			PROCEDURE ReadOffset32 (): LONGINT;
			BEGIN
				RETURN ReadLInt ();
			END ReadOffset32;

			PROCEDURE ReadOffset64 (): HUGEINT;
			BEGIN
				RETURN ReadHInt ();
			END ReadOffset64;

			PROCEDURE ReadHInt (): HUGEINT;
			VAR
				value: HUGEINT;
			BEGIN
				SYSTEM.PUT (ADDRESSOF (value), ReadLInt ());
				SYSTEM.PUT (ADDRESSOF (value) + 4, ReadLInt ());
				RETURN value;
			END ReadHInt;

			PROCEDURE Invalid;
			BEGIN
				Instr (opInvalid);
				Bug (code, 0);
			END Invalid;

			PROCEDURE Reserved;
			BEGIN
				Instr (opReserved);
			END Reserved;

			PROCEDURE DecodePrefixes;
			BEGIN
				LOOP
					byte := ORD (ReadChar ());
					CASE byte OF
					| 066H: INCL (opc.prefixes, prOperand);
					| 067H: INCL (opc.prefixes, prAddress);
					| 02EH: INCL (opc.prefixes, prCS);
					| 03EH: INCL (opc.prefixes, prDS);
					| 026H: INCL (opc.prefixes, prES);
					| 064H: INCL (opc.prefixes, prFS);
					| 065H: INCL (opc.prefixes, prGS);
					| 036H: INCL (opc.prefixes, prSS);
					| 0F0H: INCL (opc.prefixes, prLOCK);
					| 0F3H: INCL (opc.prefixes, prREP);
					| 0F2H: INCL (opc.prefixes, prREPN);
					ELSE
						IF byte DIV 10H = 4H THEN (* REX prefixes start with 4H *)
							INCL (opc.prefixes, prREX);
							IF byte DIV 8H MOD 2H # 0 THEN INCL (opc.prefixes, prREXW) END;
							IF byte DIV 4H MOD 2H # 0 THEN INCL (opc.prefixes, prREXR) END;
							IF byte DIV 2H MOD 2H # 0 THEN INCL (opc.prefixes, prREXX) END;
							IF byte MOD 2H # 0 THEN INCL (opc.prefixes, prREXB) END;
							byte := ORD (ReadChar ());
							INC (opc.prefixCount);
						END;
						RETURN;
					END;
					INC (opc.prefixCount);
				END;
			END DecodePrefixes;

			PROCEDURE Prefix (prefix: LONGINT): BOOLEAN;
			BEGIN
				RETURN prefix IN opc.prefixes;
			END Prefix;

			(* set the current opcode instruction *)
			PROCEDURE Instr (instr : LONGINT);
			BEGIN
				opc.instr := instr;
			END Instr;

			(* set opcode instruction based on current operand size override *)
			PROCEDURE InstrOp (instr16, instr32, instr64 : LONGINT);
			BEGIN
				IF Prefix (prREXW) THEN
					Instr (instr64);
				ELSIF Prefix (prOperand) THEN
					Instr (instr16);
				ELSE
					Instr (instr32);
				END
			END InstrOp;

			(* parse ModRM byte *)
			PROCEDURE ModRM;
			BEGIN
				IF modRM THEN RETURN ELSE modRM := TRUE END;

				byte := ORD (ReadChar ());
				mod := byte DIV 40H MOD 4H;
				reg := byte DIV 8H MOD 8H;
				rm := byte MOD 8H;

				IF (mod # 3) & (rm = 4) THEN
					byte := ORD (ReadChar ());
					scale := byte DIV 40H MOD 4H;
					index := byte DIV 8H MOD 8H;
					base := byte MOD 8H;
				ELSE
					base := 0;
				END;

				IF mod = 1 THEN
					disp := ORD (ReadChar ());
					IF disp > 07FH THEN DEC (disp, 0100H) END;
				ELSIF (mod = 2) OR ((mod = 0) & (rm = 5)) OR (base = 5) THEN
					disp := ReadLInt ();
				ELSE
					disp := 0;
				END
			END ModRM;

			PROCEDURE GetOperandSize () : LONGINT;
			BEGIN
				IF Prefix (prREXW) THEN
					RETURN 64;
				ELSIF Prefix (prOperand) THEN
					RETURN 16;
				ELSE
					RETURN 32;
				END
			END GetOperandSize;

			PROCEDURE  GetOperandReg (offset: LONGINT): LONGINT;
			BEGIN
				IF Prefix (prREXW) THEN
					RETURN regRAX + offset;
				ELSIF Prefix (prOperand) THEN
					RETURN regAX + offset;
				ELSE
					RETURN regEAX + offset;
				END
			END GetOperandReg;

			PROCEDURE  GetReg (base, offset : LONGINT; extension : BOOLEAN) : LONGINT;
			BEGIN
				IF base = regES THEN
					IF offset >= 6 THEN Invalid; END;
					RETURN base + offset;
				ELSIF extension THEN
					IF base = regrAX THEN
						RETURN GetOperandReg (offset + 8)
					ELSE
						RETURN base + offset + 8
					END
				ELSIF (base = regAL) & (offset >= 4) & (prREX IN opc.prefixes) THEN
					RETURN regSPL - 4 + offset;
				ELSIF base = regrAX THEN
					RETURN GetOperandReg (offset)
				ELSE
					RETURN base + offset;
				END
			END GetReg;

			PROCEDURE GetAddressReg (offset: LONGINT; extension: BOOLEAN): LONGINT;
			BEGIN
				IF extension THEN
					IF prAddress IN opc.prefixes THEN RETURN regR8D + offset ELSE RETURN regR8 + offset END;
				ELSE
					IF prAddress IN opc.prefixes THEN RETURN regEAX + offset ELSE RETURN regRAX + offset END;
				END
			END GetAddressReg;

			PROCEDURE  AddImm (imm: HUGEINT);
			VAR
				argImm: ArgImm;
			BEGIN
				NEW (argImm, imm); opc.arg[arg] := argImm; INC (arg);
			END AddImm;

			PROCEDURE  AddReg (reg: LONGINT);
			VAR
				argReg: ArgReg;
			BEGIN
				NEW (argReg, reg); opc.arg[arg] := argReg; INC (arg);
			END AddReg;

			PROCEDURE  AddRMReg (base: LONGINT);
			BEGIN
				ModRM; AddReg (GetReg (base, reg, prREXR IN opc.prefixes));
			END AddRMReg;

			PROCEDURE  AddMem (segment, reg, scale , base: LONGINT; disp: HUGEINT);
			VAR
				argMem: ArgMem;
			BEGIN
				NEW (argMem, segment, reg, scale, base, disp); opc.arg[arg] := argMem; INC (arg);
			END AddMem;

			PROCEDURE  AddModMem;
			VAR
				reg, baseReg, scaling : LONGINT;
			BEGIN
				ModRM;

				IF mod = 3 THEN
					Invalid; RETURN;
				ELSIF (mod = 0) & (rm = 5) THEN
					IF Prefix (prREXB) & Prefix (prAddress) THEN reg := regIP ELSE reg := regRIP END;
					scaling := 1;
					baseReg := regNONE;
				ELSIF rm = 4 THEN
					IF (index = 4) & ~Prefix (prREXX) THEN
						reg := regNONE
					ELSE
						reg := GetAddressReg (index, Prefix (prREXX));
					END;

					IF (base = 5) & (mod = 0) THEN
						baseReg := regNONE
					ELSE
						baseReg := GetAddressReg (base, Prefix (prREXB));
					END;

					CASE scale OF
					| 0: scaling := 1;
					| 1: scaling := 2;
					| 2: scaling := 4;
					| 3: scaling := 8;
					END

				ELSE
					reg := GetAddressReg (rm, Prefix (prREXB));
					scaling := 1;
					baseReg := regNONE;
				END;

				AddMem (segment, reg, scaling, baseReg, disp);
			END AddModMem;

			PROCEDURE AddModRM (base: LONGINT);
			BEGIN
				ModRM;
				IF mod = 3 THEN
					AddReg (GetReg (base, rm, Prefix (prREXB)));
				ELSE
					AddModMem;
				END
			END AddModRM;

			PROCEDURE AddFPReg (offset: LONGINT);
			BEGIN
				AddReg (regST0 + offset);
			END AddFPReg;

			(* helper functions, see AMD64 programmers manual vol 3, instruction encoding *)

			PROCEDURE AL; BEGIN AddReg (regAL) END AL;
			PROCEDURE CL; BEGIN AddReg (regCL) END CL;
			PROCEDURE Cdq; BEGIN AddRMReg (regCR0) END Cdq;
			PROCEDURE Ddq; BEGIN AddRMReg (regDR0) END Ddq;
			PROCEDURE DX; BEGIN AddReg (regDX) END DX;
			PROCEDURE eAX; BEGIN IF GetOperandSize () = 16 THEN AddReg (regAX) ELSE AddReg (regEAX) END; END eAX;
			PROCEDURE Eb; BEGIN AddModRM (regAL) END Eb;
			PROCEDURE Ed; BEGIN AddModRM (regEAX) END Ed;
			PROCEDURE Edq; BEGIN IF GetOperandSize () = 64 THEN AddModRM (regRAX) ELSE AddModRM (regEAX) END END Edq;
			PROCEDURE Ev; BEGIN AddModRM (regrAX) END Ev;
			PROCEDURE Ew; BEGIN AddModRM (regAX) END Ew;
			PROCEDURE FS; BEGIN AddReg (regFS) END FS;
			PROCEDURE Fv; END Fv;
			PROCEDURE Gb; BEGIN AddRMReg (regAL) END Gb;
			PROCEDURE Gd; BEGIN AddRMReg (regEAX) END Gd;
			PROCEDURE Gdq; BEGIN IF GetOperandSize () = 64 THEN AddRMReg (regRAX) ELSE AddRMReg (regEAX) END END Gdq;
			PROCEDURE Gv; BEGIN AddRMReg (regrAX) END Gv;
			PROCEDURE Gz; BEGIN IF GetOperandSize () = 16 THEN AddRMReg (regAX) ELSE AddRMReg (regEAX) END END Gz;
			PROCEDURE Ib; BEGIN AddImm (ReadImm8 ()) END Ib;

			PROCEDURE Iv;
			BEGIN
				 CASE GetOperandSize () OF
				 | 16: AddImm (ReadImm16 ());
				 | 32: AddImm (ReadImm32 ());
				 | 64: AddImm (ReadImm64 ());
				 END;
			END Iv;

			PROCEDURE Iw; BEGIN AddImm (ReadInt ()) END Iw;
			PROCEDURE Iz; BEGIN IF GetOperandSize () = 16 THEN AddImm (ReadImm16 ()) ELSE AddImm (ReadImm32 ()) END END Iz;
			PROCEDURE Jb; BEGIN AddImm (ReadOffset8 ()) END Jb;
			PROCEDURE Jz; BEGIN IF GetOperandSize () = 16 THEN AddImm (ReadOffset16 ()) ELSE AddImm (ReadOffset32 ()) END END Jz;
			PROCEDURE M; BEGIN AddModMem () END M;
			PROCEDURE Mb; BEGIN AddModMem () END Mb;
			PROCEDURE Md; BEGIN AddModMem () END Md;
			PROCEDURE Mdq; BEGIN AddModMem () END Mdq;
			PROCEDURE Mp; BEGIN AddModMem () END Mp;
			PROCEDURE Mq; BEGIN AddModMem () END Mq;
			PROCEDURE Ms; BEGIN AddModMem () END Ms;
			PROCEDURE MwRv; BEGIN AddModRM (regrAX) END MwRv;
			PROCEDURE Ob; BEGIN AddMem (regNONE, regNONE, 1, regNONE, ReadOffset8 ()) END Ob;

			PROCEDURE Ov;
			BEGIN
				 CASE GetOperandSize () OF
				 | 16: AddMem (regNONE, regNONE, 1, regNONE, ReadOffset16 ());
				 | 32: AddMem (regNONE, regNONE, 1, regNONE, ReadOffset32 ());
				 | 64: AddMem (regNONE, regNONE, 1, regNONE, ReadOffset64 ());
				 END;
			END Ov;

			PROCEDURE Pq; BEGIN AddRMReg (regMMX0) END Pq;
			PROCEDURE Pdq; BEGIN AddRMReg (regMMX0) END Pdq;
			PROCEDURE PRq; BEGIN ModRM; IF mod = 3 THEN AddModRM (regMMX0) ELSE Invalid END END PRq;
			PROCEDURE Qd; BEGIN AddModRM (regMMX0) END Qd;
			PROCEDURE Qq; BEGIN AddModRM (regMMX0) END Qq;
			PROCEDURE rAX; BEGIN AddReg (GetOperandReg (regrAX)) END rAX;
			PROCEDURE Rdq; BEGIN AddModRM (regRAX) END Rdq;
			PROCEDURE Sw; BEGIN AddRMReg (regES) END Sw;
			PROCEDURE Xb; BEGIN AddMem (regNONE, GetAddressReg (regrSI, FALSE), 1, regNONE, 0) END Xb;
			PROCEDURE Xv; BEGIN AddMem (regNONE, GetAddressReg (regrSI, FALSE), 1, regNONE, 0) END Xv;
			PROCEDURE Xz; BEGIN AddMem (regNONE, GetAddressReg (regrSI, FALSE), 1, regNONE, 0) END Xz;
			PROCEDURE Yb; BEGIN AddMem (regNONE, GetAddressReg (regrDI, FALSE), 1, regNONE, 0) END Yb;
			PROCEDURE Yv; BEGIN AddMem (regNONE, GetAddressReg (regrDI, FALSE), 1, regNONE, 0) END Yv;
			PROCEDURE Yz; BEGIN AddMem (regNONE, GetAddressReg (regrDI, FALSE), 1, regNONE, 0) END Yz;
			PROCEDURE Vdq; BEGIN AddRMReg (regXMM0) END Vdq;
			PROCEDURE Vdqsd; BEGIN AddRMReg (regXMM0) END Vdqsd;
			PROCEDURE Vdqss; BEGIN AddRMReg (regXMM0) END Vdqss;
			PROCEDURE Vps; BEGIN AddRMReg (regXMM0) END Vps;
			PROCEDURE Vpd; BEGIN AddRMReg (regXMM0) END Vpd;
			PROCEDURE Vq; BEGIN AddRMReg (regXMM0) END Vq;
			PROCEDURE VRdq; BEGIN ModRM; IF mod = 3 THEN AddModRM (regXMM0) ELSE Invalid END END VRdq;
			PROCEDURE VRpd; BEGIN ModRM; IF mod = 3 THEN AddModRM (regXMM0) ELSE Invalid END END VRpd;
			PROCEDURE VRps; BEGIN ModRM; IF mod = 3 THEN AddModRM (regXMM0) ELSE Invalid END END VRps;
			PROCEDURE VRq; BEGIN ModRM; IF mod = 3 THEN AddModRM (regXMM0) ELSE Invalid END END VRq;
			PROCEDURE Vsd; BEGIN AddRMReg (regXMM0) END Vsd;
			PROCEDURE Vss; BEGIN AddRMReg (regXMM0) END Vss;
			PROCEDURE Wdq; BEGIN AddModRM (regXMM0) END Wdq;
			PROCEDURE Wpd; BEGIN AddModRM (regXMM0) END Wpd;
			PROCEDURE Wq; BEGIN AddModRM (regXMM0) END Wq;
			PROCEDURE Wps; BEGIN AddModRM (regXMM0) END Wps;
			PROCEDURE Wsd; BEGIN AddModRM (regXMM0) END Wsd;
			PROCEDURE Wss; BEGIN AddModRM (regXMM0) END Wss;

			PROCEDURE Type1 (instr, offset : LONGINT);
			BEGIN
				Instr (instr);
				CASE offset OF
				| 0: Eb; Gb;
				| 1: Ev; Gv;
				| 2: Gb; Eb;
				| 3: Gv; Ev;
				| 4: AL; Ib;
				| 5: rAX; Iz;
				END
			END Type1;

			PROCEDURE Type2 (instr, offset : LONGINT);
			BEGIN
				Instr (instr);

				IF prREXB IN opc.prefixes THEN INC (offset, 8) END;

				IF GetOperandSize () = 16 THEN
					AddReg (regAX + offset);
				ELSE
					AddReg (regRAX + offset);
				END
			END Type2;

			PROCEDURE Type3 (instr : LONGINT);
			BEGIN
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (instr); Vdq; Wdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (instr); Pq; Qq; END;
			END Type3;

			PROCEDURE Group1;
			BEGIN
				ModRM;

				CASE reg OF
				| 0: Instr (opADD);
				| 1: Instr (opOR);
				| 2: Instr (opADC);
				| 3: Instr (opSBB);
				| 4: Instr (opAND);
				| 5: Instr (opSUB);
				| 6: Instr (opXOR);
				| 7: Instr (opCMP);
				END;

				CASE code OF
				| 080H: Eb; Ib;
				| 081H: Ev; Iz;
				| 082H: Invalid;
				| 083H: Ev; Ib;
				END
			END Group1;

			PROCEDURE Group1a;
			BEGIN
				ModRM;

				IF reg = 0 THEN
					Instr (opPOP); Ev;
				ELSE
					Invalid;
				END

			END Group1a;

			PROCEDURE Group2;
			BEGIN
				ModRM;

				CASE reg OF
				| 0: Instr (opROL);
				| 1: Instr (opROR);
				| 2: Instr (opRCL);
				| 3: Instr (opRCR);
				| 4: Instr (opSHL);
				| 5: Instr (opSHR);
				| 6: Instr (opSHL);
				| 7: Instr (opSHR);
				END;

				CASE code OF
				| 0C0H: Eb; Ib;
				| 0C1H: Ev; Ib;
				| 0D0H: Eb; AddImm (1);
				| 0D1H: Ev; AddImm (1);
				| 0D2H: Eb; AddReg (regCL);
				| 0D3H: Ev; AddReg (regCL);
				END

			END Group2;

			PROCEDURE Group3;
			BEGIN
				ModRM;

				CASE reg OF
				| 0..1: Instr (opTEST);
				| 2: Instr (opNOT);
				| 3: Instr (opNEG);
				| 4: Instr (opMUL);
				| 5: Instr (opIMUL);
				| 6: Instr (opDIV);
				| 7: Instr (opIDIV);
				END;

				CASE code OF
				| 0F6H: Eb; IF reg <= 1 THEN Ib END;
				| 0F7H: Ev; IF reg <= 1 THEN Iz END;
				END

			END Group3;

			PROCEDURE Group4;
			BEGIN
				ModRM;

				CASE reg OF
				| 0: Instr (opINC);
				| 1: Instr (opDEC);
				ELSE
					Invalid; RETURN;
				END;

				Eb;

			END Group4;

			PROCEDURE Group5;
			BEGIN
				ModRM;

				CASE reg OF
				| 0: Instr (opINC); Ev;
				| 1: Instr (opDEC); Ev;
				| 2: Instr (opCALL); Ev;
				| 3: Instr (opCALL); Mp;
				| 4: Instr (opJMP); Ev;
				| 5: Instr (opJMP); Mp;
				| 6: Instr (opPUSH); Ev;
				ELSE
					Invalid;
				END;

			END Group5;

			PROCEDURE Group6;
			BEGIN
				ModRM;

				CASE reg OF
				| 0: Instr (opSLDT); MwRv;
				| 1: Instr (opSTR); MwRv;
				| 2: Instr (opLLDT); Ew;
				| 3: Instr (opLTR); Ew;
				| 4: Instr (opVERR); Ew;
				| 5: Instr (opVERW); Ew;
				ELSE
					Invalid;
				END;

			END Group6;

			PROCEDURE Group7;
			BEGIN
				ModRM;

				CASE reg OF
				| 0: Instr (opSGDT); Ms;
				| 1: Instr (opSIDT); Ms;
				| 2: Instr (opLGDT); Ms;
				| 3: IF mod = 3 THEN GroupModRM ELSE Instr (opLIDT); Ms END;
				| 4: Instr (opSMSW); MwRv;
				| 6: Instr (opLMSW); Ew;
				| 7: IF mod = 3 THEN GroupModRM ELSE Instr (opINVLPG); Mb END;
				ELSE
					Invalid;
				END;

			END Group7;

			PROCEDURE Group8;
			BEGIN
				ModRM;

				CASE reg OF
				| 4: Instr (opBT);
				| 5: Instr (opBTS);
				| 6: Instr (opBTR);
				| 7: Instr (opBTC);
				ELSE
					Invalid; RETURN;
				END;

				Ev; Ib;

			END Group8;

			PROCEDURE Group9;
			BEGIN
				ModRM;

				IF reg = 1 THEN
					IF Prefix (prREXW) THEN
						Instr (opCMPXCHG16B); Mdq;
					ELSE
						Instr (opCMPXCHG8B); Mq;
					END;
				ELSE
					Invalid;
				END;

			END Group9;

			PROCEDURE Group10;
			BEGIN
				Invalid;
			END Group10;

			PROCEDURE Group11;
			BEGIN
				ModRM;

				IF reg = 0 THEN
					Instr (opMOV);
				ELSE
					Invalid; RETURN;
				END;

				CASE code OF
				| 0C6H: Eb; Ib;
				| 0C7H: Ev; Iz;
				END
			END Group11;

			PROCEDURE Group12;
			BEGIN
				ModRM;

				IF Prefix (prF2) OR Prefix (prF3) THEN
					Invalid; RETURN;
				END;

				CASE reg OF
				| 2: Instr (opPSRLW);
				| 4: Instr (opPSRAW);
				| 6: Instr (opPSLLW);
				ELSE
					Invalid; RETURN;
				END;

				IF Prefix (pr66) THEN
					VRdq; Ib;
				ELSE
					PRq; Ib;
				END;

			END Group12;

			PROCEDURE Group13;
			BEGIN
				ModRM;

				IF Prefix (prF2) OR Prefix (prF3) THEN
					Invalid; RETURN;
				END;

				CASE reg OF
				| 2: Instr (opPSRLD);
				| 4: Instr (opPSRAD);
				| 6: Instr (opPSLLD);
				ELSE
					Invalid; RETURN;
				END;

				IF Prefix (pr66) THEN
					VRdq; Ib;
				ELSE
					PRq; Ib;
				END;

			END Group13;

			PROCEDURE Group14;
			BEGIN
				ModRM;

				IF Prefix (prF2) OR Prefix (prF3) THEN
					Invalid; RETURN;
				END;

				CASE reg OF
				| 2: Instr (opPSRLQ);
				| 3: IF Prefix (pr66) THEN Instr (opPSRLDQ) ELSE Invalid; RETURN; END;
				| 6: Instr (opPSLLQ);
				| 7: IF Prefix (pr66) THEN Instr (opPSLLDQ) ELSE Invalid; RETURN; END;
				ELSE
					Invalid; RETURN;
				END;

				IF Prefix (pr66) THEN
					VRdq; Ib;
				ELSE
					PRq; Ib;
				END;

			END Group14;

			PROCEDURE Group15;
			BEGIN
				ModRM;

				IF Prefix (pr66) OR Prefix (prF2) OR Prefix (prF3) THEN
					Invalid; RETURN;
				END;

				CASE reg OF
				| 0: Instr (opFXSAVE); M;
				| 1: Instr (opFXRSTOR); M;
				| 2: Instr (opLDMXCSR); Md;
				| 3: Instr (opSTMXCSR); Md;
				| 5..7: GroupModRM;
				ELSE
					Invalid;
				END;

			END Group15;

			PROCEDURE Group16;
			BEGIN
				ModRM;

				CASE reg OF
				| 0: Instr (opPREFETCHNTA);
				| 1: Instr (opPREFETCHT0);
				| 2: Instr (opPREFETCHT1);
				| 3: Instr (opPREFETCHT2);
				| 4..7: Instr (opNOP);
				END;

			END Group16;

			PROCEDURE GroupP;
			BEGIN
				ModRM;

				CASE reg OF
				| 0: Instr (opPREFETCH);
				| 1, 3: Instr (opPREFETCHW);
				ELSE
					Instr (opPREFETCH);
				END;

			END GroupP;

			PROCEDURE GroupModRM;
			BEGIN
				ModRM;

				IF code = 0F01H THEN
					CASE reg OF
					3:
						CASE rm OF
						| 0: Instr (opVMRUN);
						| 1: Instr (opVMMCALL);
						| 2: Instr (opVMLOAD);
						| 3: Instr (opVMSAVE);
						| 4: Instr (opSTGI);
						| 5: Instr (opCLGI);
						| 6: Instr (opSKINIT);
						| 7: Instr (opINVLPGA);
						END;
					| 7:
						CASE rm OF
						| 0: Instr (opSWAPGS);
						| 1: Instr (opRDTSCP);
						ELSE
							Invalid;
						END;
					END;
				ELSIF code = 0FAEH THEN
					CASE reg OF
					| 5: Instr (opLFENCE);
					| 6: Instr (opMFENCE);
					| 7: Instr (opSFENCE);
					END;
				END;

			END GroupModRM;

			PROCEDURE Group3DNow;
			BEGIN
				ModRM;

				CASE ORD (ReadChar ()) OF
				| 00CH: Instr (opPI2FW);
				| 00DH: Instr (opPI2FD);
				| 01CH: Instr (opPF2IW);
				| 01DH: Instr (opPF2ID);
				| 08AH: Instr (opPFNACC);
				| 08EH: Instr (opPFPNACC);
				| 090H: Instr (opPFCMPGE);
				| 094H: Instr (opPFMIN);
				| 096H: Instr (opPFRCP);
				| 097H: Instr (opPFRSQRT);
				| 09AH: Instr (opPFSUB);
				| 09EH: Instr (opPFADD);
				| 0A0H: Instr (opPFCMPGT);
				| 0A4H: Instr (opPFMAX);
				| 0A6H: Instr (opPFRCPIT1);
				| 0A7H: Instr (opPFRSQIT1);
				| 0AAH: Instr (opPFSUBR);
				| 0AEH: Instr (opPFACC);
				| 0B0H: Instr (opPFCMPEQ);
				| 0B4H: Instr (opPFMUL);
				| 0B6H: Instr (opPFRCPIT1);
				| 0B7H: Instr (opPMULHRW);
				| 0BBH: Instr (opPSWAPD);
				| 0BFH: Instr (opPAVGUSB);
				ELSE
					Reserved; RETURN;
				END;

				 Pq; Qq;
			END Group3DNow;

			PROCEDURE Groupx87;

				PROCEDURE MemInstr (instr : LONGINT);
				BEGIN
					Instr (instr);
					AddModMem;
				END MemInstr;

				PROCEDURE StackInstr0i (instr : LONGINT);
				BEGIN
					Instr (instr);
					AddFPReg (0);
					AddFPReg (rm);
				END StackInstr0i;

				PROCEDURE StackInstri0 (instr : LONGINT);
				BEGIN
					Instr (instr);
					AddFPReg (rm);
					AddFPReg (0);
				END StackInstri0;

				PROCEDURE FPInstr0i (meminstr, stackinstr: LONGINT);
				BEGIN
					IF mod # 3 THEN
						MemInstr (meminstr);
					ELSE
						StackInstr0i (stackinstr);
					END;
				END FPInstr0i;

				PROCEDURE FPInstri0 (meminstr, stackinstr: LONGINT);
				BEGIN
					IF mod # 3 THEN
						MemInstr (meminstr);
					ELSE
						StackInstri0 (stackinstr);
					END;
				END FPInstri0;

			BEGIN
				ModRM;

				CASE code OF
				0D8H:
					CASE reg OF
					| 0: FPInstr0i (opFADD, opFADD);
					| 1: FPInstr0i (opFMUL, opFMUL);
					| 2: FPInstr0i (opFCOM, opFCOM);
					| 3: FPInstr0i (opFCOMP, opFCOMP);
					| 4: FPInstr0i (opFSUB, opFSUB);
					| 5: FPInstr0i (opFSUBR, opFSUBR);
					| 6: FPInstr0i (opFDIV, opFDIV);
					| 7: FPInstr0i (opFDIVR, opFDIVR);
					END;
				| 0D9H:
					CASE reg OF
					| 0: FPInstr0i (opFLD, opFLD);
					| 1: IF mod # 3 THEN Invalid ELSE StackInstr0i (opFXCH) END;
					| 2: IF mod # 3 THEN MemInstr (opFST) ELSIF rm = 0 THEN Instr (opFNOP) ELSE Invalid END;
					| 3: IF mod # 3 THEN MemInstr (opFSTP) ELSE Reserved END;
					| 4: IF mod # 3 THEN MemInstr (opFLDENV) ELSE
						CASE rm OF
						| 0: Instr (opFCHS);
						| 1: Instr (opFABS);
						| 4: Instr (opFTST);
						| 5: Instr (opFXAM);
						ELSE
							Invalid;
						END; END;
					| 5: IF mod # 3 THEN MemInstr (opFLDCW) ELSE
						CASE rm OF
						| 0: Instr (opFLD1);
						| 1: Instr (opFLDL2T);
						| 2: Instr (opFLDL2E);
						| 3: Instr (opFLDPI);
						| 4: Instr (opFLDLG2);
						| 5: Instr (opFLDLN2);
						| 6: Instr (opFLDZ);
						| 7: Invalid;
						END; END;
					| 6: IF mod # 3 THEN MemInstr (opFNSTENV) ELSE
						CASE rm OF
						| 0: Instr (opF2XM1);
						| 1: Instr (opFYL2X);
						| 2: Instr (opFPTAN);
						| 3: Instr (opFPATAN);
						| 4: Instr (opFXTRACT);
						| 5: Instr (opFPREM1);
						| 6: Instr (opFDECSTP);
						| 7: Instr (opFINCSTP);
						END; END;
					| 7: IF mod # 3 THEN MemInstr (opFNSTCW) ELSE
						CASE rm OF
						| 0: Instr (opFPREM);
						| 1: Instr (opFYL2XP1);
						| 2: Instr (opFSQRT);
						| 3: Instr (opFSINCOS);
						| 4: Instr (opFRNDINT);
						| 5: Instr (opFSCALE);
						| 6: Instr (opFSIN);
						| 7: Instr (opFCOS);
						END; END;
					END;
				| 0DAH:
					CASE reg OF
					| 0: FPInstr0i (opFIADD, opFCMOVB);
					| 1: FPInstr0i (opFIMUL, opFCMOVE);
					| 2: FPInstr0i (opFICOM, opFCMOVBE);
					| 3: FPInstr0i (opFICOMP, opFCMOVU);
					| 4: IF mod # 3 THEN MemInstr (opFISUB) ELSE Invalid END;
					| 5: IF mod # 3 THEN MemInstr (opFISUBR) ELSIF rm = 1 THEN Instr (opFUCOMPP) ELSE Invalid END;
					| 6: IF mod # 3 THEN MemInstr (opFIDIV) ELSE Invalid END;
					| 7: IF mod # 3 THEN MemInstr (opFIDIVR) ELSE Invalid END;
					END;
				| 0DBH:
					CASE reg OF
					| 0: FPInstr0i (opFILD, opFCMOVNB);
					| 1: FPInstr0i (opFISTTP, opFCMOVNE);
					| 2: FPInstr0i (opFIST, opFCMOVNBE);
					| 3: FPInstr0i (opFISTP, opFCMOVNU);
					| 4: IF mod # 3 THEN Invalid ELSE
						CASE rm OF
						| 2: Instr (opFNCLEX);
						| 3: Instr (opFNINIT);
						ELSE
							Reserved;
						END; END;
					| 5: FPInstr0i (opFLD, opFUCOMI);
					| 6: IF mod # 3 THEN Invalid ELSE StackInstr0i (opFCOMI) END;
					| 7: IF mod # 3 THEN MemInstr (opFSTP) ELSE Invalid END;
					END;
				| 0DCH:
					CASE reg OF
					| 0: FPInstri0 (opFADD, opFADD);
					| 1: FPInstri0 (opFMUL, opFMUL);
					| 2: IF mod # 3 THEN MemInstr (opFCOM) ELSE Reserved END;
					| 3: IF mod # 3 THEN MemInstr (opFCOMP) ELSE Reserved END;
					| 4: FPInstri0 (opFSUB, opFSUBR);
					| 5: FPInstri0 (opFSUBR, opFSUB);
					| 6: FPInstri0 (opFDIV, opFDIVR);
					| 7: FPInstri0 (opFDIVR, opFDIV);
					END;
				| 0DDH:
					CASE reg OF
					| 0: IF mod # 3 THEN MemInstr (opFLD) ELSE Instr (opFFREE); AddFPReg (rm) END
					| 1: IF mod # 3 THEN MemInstr (opFISTTP) ELSE Reserved END;
					| 2: IF mod # 3 THEN MemInstr (opFST) ELSE Instr (opFST); AddFPReg (rm) END
					| 3: IF mod # 3 THEN MemInstr (opFSTP) ELSE Instr (opFSTP); AddFPReg (rm) END
					| 4: FPInstri0 (opFRSTOR, opFUCOM);
					| 5: IF mod # 3 THEN Invalid ELSE Instr (opFUCOMP); AddFPReg (rm) END;
					| 6: IF mod # 3 THEN MemInstr (opFNSAVE) ELSE Invalid END;
					| 7: IF mod # 3 THEN MemInstr (opFNSTSW) ELSE Invalid END;
					END;
				| 0DEH:
					CASE reg OF
					| 0: FPInstri0 (opFIADD, opFADDP);
					| 1: FPInstri0 (opFIMUL, opFMULP);
					| 2: IF mod # 3 THEN MemInstr (opFICOM) ELSE Reserved END;
					| 3: IF mod # 3 THEN MemInstr (opFICOMP) ELSIF rm = 1 THEN Instr (opFCOMPP) ELSE Invalid END;
					| 4: FPInstri0 (opFISUB, opFSUBRP);
					| 5: FPInstri0 (opFISUBR, opFSUBP);
					| 6: FPInstri0 (opFIDIV, opFDIVRP);
					| 7: FPInstri0 (opFIDIVR, opFDIVP);
					END;
				| 0DFH:
					CASE reg OF
					| 0: IF mod # 3 THEN MemInstr (opFILD) ELSE Reserved END;
					| 1: IF mod # 3 THEN MemInstr (opFISTTP) ELSE Reserved END;
					| 2: IF mod # 3 THEN MemInstr (opFIST) ELSE Reserved END;
					| 3: IF mod # 3 THEN MemInstr (opFISTP) ELSE Reserved END;
					| 4: IF mod # 3 THEN MemInstr (opFBLD) ELSIF rm = 0 THEN Instr (opFNSTSW) ELSE Invalid END;
					| 5: FPInstr0i (opFILD, opFUCOMIP);
					| 6: FPInstr0i (opFBSTP, opFCOMIP);
					| 7: IF mod # 3 THEN MemInstr (opFISTP) ELSE Invalid END;
					END;
				END;
			END Groupx87;

		BEGIN

			opc := opcode(AMD64Opcode);

			DecodePrefixes;

			IF prFS IN opc.prefixes THEN segment := regFS
			ELSIF prGS IN opc.prefixes THEN segment := regGS
			ELSE segment := regNONE END;

			IF byte = 00FH THEN
				code := byte * 0100H + ORD (ReadChar ());
				opc.hidePrefixes := TRUE;
			ELSE
				code := byte
			END;

			arg := 0;

			CASE code OF
			| 000H..005H: Type1 (opADD, code - 000H);
			| 008H..00DH: Type1 (opOR, code - 008H);
			| 010H..015H: Type1 (opADC, code - 010H);
			| 018H..01DH: Type1 (opSBB, code - 018H);
			| 020H..025H: Type1 (opAND, code - 020H);
			| 028H..02DH: Type1 (opSUB, code - 028H);
			| 030H..035H: Type1 (opXOR, code - 030H);
			| 038H..03DH: Type1 (opCMP, code - 038H);
			| 050H..057H: Type2 (opPUSH, (code - 050H) MOD 08H);
			| 058H..05FH: Type2 (opPOP, (code - 058H) MOD 08H);
			| 063H: Instr (opMOVSXD); Gv; Ed;
			| 068H: Instr (opPUSH); Iz;
			| 069H: Instr (opIMUL); Gv; Ev; Iz;
			| 06AH: Instr (opPUSH); Ib;
			| 06BH: Instr (opIMUL); Gv; Ev; Ib;
			| 06CH: Instr (opINSB); Yb; DX;
			| 06DH: InstrOp (opINSW, opINSD, opINSD); Yz; DX;
			| 06EH: Instr (opOUTSB); DX; Xb;
			| 06FH: InstrOp (opOUTSW, opOUTSD, opOUTSD); DX; Xz;
			| 070H: Instr (opJO); Jb;
			| 071H: Instr (opJNO); Jb;
			| 072H: Instr (opJB); Jb;
			| 073H: Instr (opJNB); Jb;
			| 074H: Instr (opJE); Jb;
			| 075H: Instr (opJNE); Jb;
			| 076H: Instr (opJBE); Jb;
			| 077H: Instr (opJNBE); Jb;
			| 078H: Instr (opJA); Jb;
			| 079H: Instr (opJS); Jb;
			| 07AH: Instr (opJP); Jb;
			| 07BH: Instr (opJNP); Jb;
			| 07CH: Instr (opJL); Jb;
			| 07DH: Instr (opJGE); Jb;
			| 07EH: Instr (opJLE); Jb;
			| 07FH: Instr (opJG); Jb;
			| 080H..083H: Group1;
			| 084H: Instr (opTEST); Eb; Gb;
			| 085H: Instr (opTEST); Ev; Gv;
			| 086H: Instr (opXCHG); Eb; Gb;
			| 087H: Instr (opXCHG); Ev; Gv;
			| 088H: Instr (opMOV); Eb; Gb;
			| 089H: Instr (opMOV); Ev; Gv;
			| 08AH: Instr (opMOV); Gb; Eb;
			| 08BH: Instr (opMOV); Gv; Ev;
			| 08CH: Instr (opMOV); Ev; Sw;
			| 08DH: Instr (opLEA); Gv; M;
			| 08EH: Instr (opMOV); Sw; Ev;
			| 08FH: Group1a;
			| 090H: IF Prefix (prF3) THEN Instr (opPAUSE) ELSE Instr (opNOP) END;
			| 091H..097H: Instr (opXCHG); AddReg (GetReg (regrAX, (code - 090H) MOD 8, Prefix (prREXB))); rAX;
			| 098H: InstrOp (opCBW, opCWDE, opCDQE);
			| 099H: InstrOp (opCWD, opCDQ, opCQO);
			| 09BH: Instr (opFWAIT);
			| 09CH: InstrOp (opPUSHF, opPUSHFD, opPUSHFQ); Fv;
			| 09DH: InstrOp (opPOPF, opPOPFD, opPOPFQ); Fv;
			| 09EH: Instr (opSAHF);
			| 09FH: Instr (opLAHF);
			| 0A0H: Instr (opMOV); AL; Ob;
			| 0A1H: Instr (opMOV); rAX; Ov;
			| 0A2H: Instr (opMOV); Ob; AL;
			| 0A3H: Instr (opMOV); Ov; rAX;
			| 0A4H: Instr (opMOVSB); Yb; Xb;
			| 0A5H: InstrOp (opMOVSW, opMOVSD, opMOVSQ); Yv; Xv;
			| 0A6H: Instr (opCMPSB); Xb; Yb;
			| 0A7H: InstrOp (opCMPSW, opCMPSD, opCMPSQ); Xv; Yv;
			| 0A8H: Instr (opTEST); AL; Ib;
			| 0A9H: Instr (opTEST); rAX; Iz;
			| 0AAH: Instr (opSTOSB); Yb; AL;
			| 0ABH: InstrOp (opSTOSW, opSTOSD, opSTOSQ); Yv; rAX;
			| 0ACH: Instr (opLODSB); AL; Xb;
			| 0ADH: InstrOp (opLODSW, opLODSD, opLODSQ); rAX; Xv;
			| 0AEH: Instr (opSCASB); AL; Yb;
			| 0AFH: InstrOp (opSCASW, opSCASD, opSCASQ); rAX; Yv;
			| 0B0H..0B7H: Instr (opMOV); AddReg (GetReg (regAL, (code - 0B0H) MOD 8, Prefix (prREXB))); Ib;
			| 0B8H..0BFH: Instr (opMOV); AddReg (GetReg (regrAX, (code - 0B8H) MOD 8, Prefix (prREXB))); Iv;
			| 0C0H..0C1H: Group2;
			| 0C2H: Instr (opRET); Iw;
			| 0C3H: Instr (opRET);
			| 0C6H..0C7H: Group11;
			| 0C8H: Instr (opENTER); Iw; Ib;
			| 0C9H: Instr (opLEAVE);
			| 0CAH: Instr (opRET); Iw;
			| 0CBH: Instr (opRET);
			| 0CCH: Instr (opINT); AddImm (3);
			| 0CDH: Instr (opINT); Ib;
			| 0CFH: InstrOp (opIRET, opIRETD, opIRETQ);
			| 0D0H..0D3H: Group2;
			| 0D7H: Instr (opXLAT);
			| 0D8H..0DFH: Groupx87;
			| 0E0H: Instr (opLOOPNE); Jb;
			| 0E1H: Instr (opLOOPE); Jb;
			| 0E2H: Instr (opLOOP); Jb;
			| 0E3H: InstrOp (opJCXZ, opJECXZ, opJRCXZ); Jb;
			| 0E4H: Instr (opIN); AL; Ib;
			| 0E5H: Instr (opIN); eAX; Ib;
			| 0E6H: Instr (opOUT); Ib; AL;
			| 0E7H: Instr (opOUT); Ib; eAX;
			| 0E8H: Instr (opCALL); Jz;
			| 0E9H: Instr (opJMP); Jz;
			| 0EBH: Instr (opJMP); Jb;
			| 0ECH: Instr (opIN); AL; DX;
			| 0EDH: Instr (opIN); eAX; DX;
			| 0EEH: Instr (opOUT); DX; AL;
			| 0EFH: Instr (opOUT); DX; eAX;
			| 0F0H: Instr (opINT); AddImm (1);
			| 0F4H: Instr (opHLT);
			| 0F5H: Instr (opCMC);
			| 0F6H..0F7H: Group3;
			| 0F8H: Instr (opCLC);
			| 0F9H: Instr (opSTC);
			| 0FAH: Instr (opCLI);
			| 0FBH: Instr (opSTI);
			| 0FCH: Instr (opCLD);
			| 0FDH: Instr (opSTD);
			| 0FEH: Group4;
			| 0FFH: Group5;
			ELSE
			CASE code OF
			| 00F00H: Group6;
			| 00F01H: Group7;
			| 00F02H: Instr (opLAR); Gv; Ew;
			| 00F03H: Instr (opLSL); Gv; Ew;
			| 00F05H: Instr (opSYSCALL);
			| 00F06H: Instr (opCLTS);
			| 00F07H: Instr (opSYSRET);
			| 00F08H: Instr (opINVD);
			| 00F09H: Instr (opWBINVD);
			| 00F0BH: Instr (opUD2);
			| 00F0DH: GroupP;
			| 00F0EH: Instr (opFEMMS);
			| 00F0FH: Group3DNow;
			| 00F10H:
				IF Prefix (prF3) THEN Instr (opMOVSS); Vdqss; Wss;
				ELSIF Prefix (pr66) THEN Instr (opMOVUPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opMOVSD); Vdqsd; Wsd;
				ELSE Instr (opMOVUPS); Vps; Wps; END;
			| 00F11H:
				IF Prefix (prF3) THEN Instr (opMOVSS); Wss; Vss;
				ELSIF Prefix (pr66) THEN Instr (opMOVUPD); Wpd; Vpd;
				ELSIF Prefix (prF2) THEN Instr (opMOVSD); Wsd; Vsd;
				ELSE Instr (opMOVUPS); Wsd; Vsd; END;
			| 00F12H:
				IF Prefix (prF3) THEN Instr (opMOVSLDUP); Vps; Wps;
				ELSIF Prefix (pr66) THEN Instr (opMOVLPD); Vsd; Mq;
				ELSIF Prefix (prF2) THEN Instr (opMOVDDUP); Vpd; Wsd;
				ELSE ModRM;
					IF mod = 3 THEN Instr (opMOVHLPS); Vps; VRq;
					ELSE Instr (opMOVLPS); Vps; Mq; END;
				END;
			| 00F13H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opMOVLPD); Mq; Vsd;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVLPS); Mq; Vps; END;
			| 00F14H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opUNPCKLPD); Vpd; Wq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opUNPCKLPS); Vps; Wq; END;
			| 00F15H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opUNPCKHPD); Vpd; Wq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opUNPCKHPS); Vps; Wq; END;
			| 00F16H:
				IF Prefix (prF3) THEN Instr (opMOVSHDUP); Vps; Wps;
				ELSIF Prefix (pr66) THEN Instr (opMOVHPD); Vsd; Mq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE ModRM;
					IF mod = 3 THEN Instr (opMOVLHPS); Vps; VRq;
					ELSE Instr (opMOVHPS); Vps; Mq; END;
				END;
			| 00F17H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opMOVHPD); Mq; Vsd;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVHPS); Mq; Vps; END;
			| 00F18H: Group16;
			| 00F19H..00F1FH: Instr (opNOP); ModRM;
			| 00F20H: Instr (opMOV); Rdq; Cdq;
			| 00F21H: Instr (opMOV); Rdq; Ddq;
			| 00F22H: Instr (opMOV); Cdq; Rdq;
			| 00F23H: Instr (opMOV); Ddq; Rdq;
			| 00F28H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opMOVAPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVAPS); Vps; Wps; END;
			| 00F29H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opMOVAPD); Wpd; Vpd;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVAPS); Wps; Vps; END;
			| 00F2AH:
				IF Prefix (prF3) THEN Instr (opCVTSI2SS); Vss; Edq;
				ELSIF Prefix (pr66) THEN Instr (opCVTPI2PD); Vpd; Qq;
				ELSIF Prefix (prF2) THEN Instr (opCVTSI2SD); Vsd; Edq;
				ELSE Instr (opCVTPI2PS); Vps; Qq; END;
			| 00F2BH:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opMOVNTPD); Mdq; Vpd;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVNTPS); Mdq; Vps; END;
			| 00F2CH:
				IF Prefix (prF3) THEN Instr (opCVTTSS2SI); Gdq; Wss;
				ELSIF Prefix (pr66) THEN Instr (opCVTTPD2PI); Pq; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opCVTTSD2SI); Gdq; Wsd;
				ELSE Instr (opCVTTPS2PI); Pq; Wps; END;
			| 00F2DH:
				IF Prefix (prF3) THEN Instr (opCVTSS2SI); Gdq; Wss;
				ELSIF Prefix (pr66) THEN Instr (opCVTPD2PI); Pq; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opCVTSD2SI); Gdq; Wsd;
				ELSE Instr (opCVTPS2PI); Pq; Wps; END;
			| 00F2EH:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opUCOMISD); Vsd; Wsd;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opUCOMISS); Vss; Wss; END;
			| 00F2FH:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opCOMISD); Vpd; Wsd;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opCOMISS); Vps; Wps; END;
			| 00F30H: Instr (opWRMSR);
			| 00F31H: Instr (opRDTSC);
			| 00F32H: Instr (opRDMSR);
			| 00F33H: Instr (opRDPMC);
			| 00F40H: Instr (opMOVO); Gv; Ev;
			| 00F41H: Instr (opMOVNO); Gv; Ev;
			| 00F42H: Instr (opMOVB); Gv; Ev;
			| 00F43H: Instr (opMOVNB); Gv; Ev;
			| 00F44H: Instr (opMOVE); Gv; Ev;
			| 00F45H: Instr (opMOVNE); Gv; Ev;
			| 00F46H: Instr (opMOVBE); Gv; Ev;
			| 00F47H: Instr (opMOVNBE); Gv; Ev;
			| 00F48H: Instr (opMOVA); Gv; Ev;
			| 00F49H: Instr (opMOVS); Gv; Ev;
			| 00F4AH: Instr (opMOVP); Gv; Ev;
			| 00F4BH: Instr (opMOVNP); Gv; Ev;
			| 00F4CH: Instr (opMOVL); Gv; Ev;
			| 00F4DH: Instr (opMOVGE); Gv; Ev;
			| 00F4EH: Instr (opMOVLE); Gv; Ev;
			| 00F4FH: Instr (opMOVG); Gv; Ev;
			| 00F50H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opMOVMSKPD); Gd; VRpd;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVMSKPS); Gd; VRps; END;
			| 00F51H:
				IF Prefix (prF3) THEN Instr (opSQRTSS); Vss; Wss;
				ELSIF Prefix (pr66) THEN Instr (opSQRTPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opSQRTSD); Vsd; Wsd;
				ELSE Instr (opSQRTPS); Vps; Wps; END;
			| 00F52H:
				IF Prefix (prF3) THEN Instr (opRSQRTSS); Vss; Wss;
				ELSIF Prefix (pr66) THEN Invalid;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opRSQRTPS); Vps; Wps; END;
			| 00F53H:
				IF Prefix (prF3) THEN Instr (opRCPSS); Vss; Wss;
				ELSIF Prefix (pr66) THEN Invalid;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opRCPPS); Vps; Wps; END;
			| 00F54H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opANDPS); Vps; Wps;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opANDPD); Vpd; Wpd; END;
			| 00F55H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opANDNPS); Vps; Wps;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opANDNPD); Vpd; Wpd; END;
			| 00F56H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opORPS); Vps; Wps;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opORPD); Vpd; Wpd; END;
			| 00F57H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opXORPS); Vps; Wps;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opXORPD); Vpd; Wpd; END;
			| 00F58H:
				IF Prefix (prF3) THEN Instr (opADDSS); Vss; Wss;
				ELSIF Prefix (pr66) THEN Instr (opADDPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opADDSD); Vsd; Wsd;
				ELSE Instr (opADDPS); Vps; Wps; END;
			| 00F59H:
				IF Prefix (prF3) THEN Instr (opMULSS); Vss; Wss;
				ELSIF Prefix (pr66) THEN Instr (opMULPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opMULSD); Vsd; Wsd;
				ELSE Instr (opMULPS); Vps; Wps; END;
			| 00F5AH:
				IF Prefix (prF3) THEN Instr (opCVTSS2SD); Vsd; Wss;
				ELSIF Prefix (pr66) THEN Instr (opCVTPD2PS); Vps; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opCVTSD2SS); Vss; Wsd;
				ELSE Instr (opCVTPS2PD); Vpd; Wps; END;
			| 00F5BH:
				IF Prefix (prF3) THEN Instr (opCVTTPS2DQ); Vdq; Wps;
				ELSIF Prefix (pr66) THEN Instr (opCVTPS2DQ); Vdq; Wps;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opCVTDQ2PS); Vpd; Wdq; END;
			| 00F5CH:
				IF Prefix (prF3) THEN Instr (opSUBSS); Vss; Wss;
				ELSIF Prefix (pr66) THEN Instr (opSUBPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opSUBSD); Vsd; Wsd;
				ELSE Instr (opSUBPS); Vps; Wps; END;
			| 00F5DH:
				IF Prefix (prF3) THEN Instr (opMINSS); Vss; Wss;
				ELSIF Prefix (pr66) THEN Instr (opMINPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opMINSD); Vsd; Wsd;
				ELSE Instr (opMINPS); Vps; Wps; END;
			| 00F5EH:
				IF Prefix (prF3) THEN Instr (opDIVSS); Vss; Wss;
				ELSIF Prefix (pr66) THEN Instr (opDIVPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opDIVSD); Vsd; Wsd;
				ELSE Instr (opDIVPS); Vps; Wps; END;
			| 00F5FH:
				IF Prefix (prF3) THEN Instr (opMAXSS); Vss; Wss;
				ELSIF Prefix (pr66) THEN Instr (opMAXPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opMAXSD); Vsd; Wsd;
				ELSE Instr (opMAXPS); Vps; Wps; END;
			| 00F60H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPUNPCKLBW); Vdq; Wq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPUNPCKLBW); Pq; Qd; END;
			| 00F61H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPUNPCKLWD); Vdq; Wq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPUNPCKLWD); Pq; Qd; END;
			| 00F62H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPUNPCKLDQ); Vdq; Wq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPUNPCKLDQ); Pq; Qd; END;
			| 00F63H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPACKSSWB); Vdq; Wdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPACKSSWB); Pq; Qq; END;
			| 00F64H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPCMPGTB); Vdq; Wdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPCMPGTB); Pq; Qq; END;
			| 00F65H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPCMPGTW); Vdq; Wdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPCMPGTW); Pq; Qq; END;
			| 00F66H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPCMPGTD); Vdq; Wdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPCMPGTD); Pq; Qq; END;
			| 00F67H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPACKUSWB); Vdq; Wdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPACKUSWB); Pq; Qq; END;
			| 00F68H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPUNPCKHBW); Vdq; Wq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPUNPCKHBW); Pq; Qd; END;
			| 00F69H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPUNPCKHWD); Vdq; Wq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPUNPCKHWD); Pq; Qd; END;
			| 00F6AH:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPUNPCKHDQ); Vdq; Wq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPUNPCKHDQ); Pq; Qd; END;
			| 00F6BH:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPACKSSDW); Vdq; Wdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPACKSSDW); Pq; Qq; END;
			| 00F6CH:
				IF Prefix (pr66) THEN Instr (opPUNPCKLQDQ); Vdq; Wq;
				ELSE Invalid; END;
			| 00F6DH:
				IF Prefix (pr66) THEN Instr (opPUNPCKHQDQ); Vdq; Wq;
				ELSE Invalid; END;
			| 00F6EH:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opMOVD); Vdq; Edq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVD); Pq; Edq; END;
			| 00F6FH:
				IF Prefix (prF3) THEN Instr (opMOVDQU); Vdq; Wdq;
				ELSIF Prefix (pr66) THEN Instr (opMOVDQA); Vdq; Edq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVQ); Pq; Qq; END;
			| 00F70H:
				IF Prefix (prF3) THEN Instr (opPSHUFHW); Vq; Wq; Ib;
				ELSIF Prefix (pr66) THEN Instr (opPSHUFD); Vdq; Wdq; Ib;
				ELSIF Prefix (prF2) THEN Instr (opPSHUFLW); Vq; Wq; Ib;
				ELSE Instr (opPSHUFW); Pq; Qq; Ib; END;
			| 00F71H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Group12;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Group12; END;
			| 00F72H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Group13;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Group13; END;
			| 00F73H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Group14;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Group14; END;
			| 00F74H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPCMPEQB); Vdq; Wdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPCMPEQB); Pq; Qq; END;
			| 00F75H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPCMPEQW); Vdq; Wdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPCMPEQW); Pq; Qq; END;
			| 00F76H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPCMPEQD); Vdq; Wdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPCMPEQD); Pq; Qq; END;
			| 00F77H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Invalid;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opEMMS); END;
			| 00F7CH:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opHADDPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opHADDPS); Vps; Wps;
				ELSE Invalid; END;
			| 00F7DH:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opHSUBPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opHSUBPS); Vps; Wps;
				ELSE Invalid; END;
			| 00F7EH:
				IF Prefix (prF3) THEN Instr (opMOVQ); Vq; Wq;
				ELSIF Prefix (pr66) THEN Instr (opMOVD); Edq; Vdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVD); Edq; Pdq; END;
			| 00F7FH:
				IF Prefix (prF3) THEN Instr (opMOVDQU); Wdq; Vdq;
				ELSIF Prefix (pr66) THEN Instr (opMOVDQA); Wdq; Vdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVQ); Qq; Pq; END;
			| 00F80H: Instr (opJO); Jz;
			| 00F81H: Instr (opJNO); Jz;
			| 00F82H: Instr (opJB); Jz;
			| 00F83H: Instr (opJNB); Jz;
			| 00F84H: Instr (opJE); Jz;
			| 00F85H: Instr (opJNE); Jz;
			| 00F86H: Instr (opJBE); Jz;
			| 00F87H: Instr (opJNBE); Jz;
			| 00F88H: Instr (opJA); Jz;
			| 00F89H: Instr (opJS); Jz;
			| 00F8AH: Instr (opJP); Jz;
			| 00F8BH: Instr (opJNP); Jz;
			| 00F8CH: Instr (opJL); Jz;
			| 00F8DH: Instr (opJGE); Jz;
			| 00F8EH: Instr (opJLE); Jz;
			| 00F8FH: Instr (opJG); Jz;
			| 00F90H: Instr (opSETO); Eb;
			| 00F91H: Instr (opSETNO); Eb;
			| 00F92H: Instr (opSETB); Eb;
			| 00F93H: Instr (opSETNB); Eb;
			| 00F94H: Instr (opSETE); Eb;
			| 00F95H: Instr (opSETNE); Eb;
			| 00F96H: Instr (opSETBE); Eb;
			| 00F97H: Instr (opSETNBE); Eb;
			| 00F98H: Instr (opSETA); Eb;
			| 00F99H: Instr (opSETS); Eb;
			| 00F9AH: Instr (opSETP); Eb;
			| 00F9BH: Instr (opSETNP); Eb;
			| 00F9CH: Instr (opSETL); Eb;
			| 00F9DH: Instr (opSETGE); Eb;
			| 00F9EH: Instr (opSETLE); Eb;
			| 00F9FH: Instr (opSETG); Eb;
			| 00FA0H: Instr (opPUSH); FS;
			| 00FA1H: Instr (opPOP); FS;
			| 00FA2H: Instr (opCPUID);
			| 00FA3H: Instr (opBT); Ev; Gv;
			| 00FA4H: Instr (opSHLD); Ev; Gv; Ib;
			| 00FA5H: Instr (opSHLD); Ev; Gv; CL;
			| 00FA8H: Instr (opPUSH); FS;
			| 00FA9H: Instr (opPOP); FS;
			| 00FAAH: Instr (opRSM);
			| 00FABH: Instr (opBTS); Ev; Gv;
			| 00FACH: Instr (opSHRD); Ev; Gv; Ib;
			| 00FADH: Instr (opSHRD); Ev; Gv; CL;
			| 00FAEH: Group15;
			| 00FAFH: Instr (opIMUL); Gv; Ev;
			| 00FB0H: Instr (opCMPXCHG); Eb; Gb;
			| 00FB1H: Instr (opCMPXCHG); Ev; Gv;
			| 00FB2H: Instr (opLSS); Gz; Mp;
			| 00FB3H: Instr (opBTR); Ev; Gv;
			| 00FB4H: Instr (opLFS); Gz; Mp;
			| 00FB5H: Instr (opLGS); Gz; Mp;
			| 00FB6H: Instr (opMOVZX); Gv; Eb;
			| 00FB7H: Instr (opMOVZX); Gv; Ew;
			| 00FB9H: Group10;
			| 00FBAH: Group8;
			| 00FBBH: Instr (opBTC); Ev; Gv;
			| 00FBCH: Instr (opBSF); Gv; Ev;
			| 00FBDH: Instr (opBSR); Gv; Ev;
			| 00FBEH: Instr (opMOVSX); Gv; Eb;
			| 00FBFH: Instr (opMOVSX); Gv; Ew;
			| 00FC0H: Instr (opXADD); Eb; Gb;
			| 00FC1H: Instr (opXADD); Ev; Gv;
			| 00FC2H:
				IF Prefix (prF3) THEN Instr (opCMPSS); Vss; Wss; Ib;
				ELSIF Prefix (pr66) THEN Instr (opCMPPD); Vpd; Wpd; Ib;
				ELSIF Prefix (prF2) THEN Instr (opCMPSD); Vsd; Wsd; Ib;
				ELSE Instr (opCMPPS); Vps; Wps; Ib; END;
			| 00FC3H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Invalid;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVNTI); Mdq; Gdq; END;
			| 00FC4H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPINSRW); Vdq; Ew; Ib;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPINSRW); Pq; Ew; Ib; END;
			| 00FC5H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPEXTRW); Gd; VRdq; Ib;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPEXTRW); Gd; PRq; Ib; END;
			| 00FC6H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opSHUFPD); Vpd; Wpd; Ib;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opSHUFPS); Vps; Wps; Ib; END;
			| 00FC7H: Group9;
			| 00FC8H..00FCFH: Instr (opBSWAP); AddReg (GetReg (regEAX, (code - 00FC8H) MOD 8, prREXB IN opc.prefixes)); Iv;
			| 00FD0H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opADDSUBPD); Vpd; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opADDSUBPS); Vps; Wps;
				ELSE Invalid; END;
			| 00FD1H: Type3 (opPSRLW);
			| 00FD2H: Type3 (opPSRLD);
			| 00FD3H: Type3 (opPSRLQ);
			| 00FD4H: Type3 (opPADDQ);
			| 00FD5H: Type3 (opPMULLW);
			| 00FD6H:
				IF Prefix (prF3) THEN Instr (opMOVQ2DQ); Vdq; PRq;
				ELSIF Prefix (pr66) THEN Instr (opMOVQ); Wq; Vq;
				ELSIF Prefix (prF2) THEN Instr (opMOVDQ2Q); Pq; VRq;
				ELSE Invalid; END;
			| 00FD7H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opPMOVMSKB); Gd; VRdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opPMOVMSKB); Gd; PRq; END;
			| 00FD8H: Type3 (opPSUBUSB);
			| 00FD9H: Type3 (opPSUBUSW);
			| 00FDAH: Type3 (opPMINUB);
			| 00FDBH: Type3 (opPAND);
			| 00FDCH: Type3 (opPADDUSB);
			| 00FDDH: Type3 (opPADDUSW);
			| 00FDEH: Type3 (opPMAXUB);
			| 00FDFH: Type3 (opPANDN);
			| 00FE0H: Type3 (opPAVGB);
			| 00FE1H: Type3 (opPSRAW);
			| 00FE2H: Type3 (opPSRAD);
			| 00FE3H: Type3 (opPAVGW);
			| 00FE4H: Type3 (opPMULHUW);
			| 00FE5H: Type3 (opPMULHW);
			| 00FE6H:
				IF Prefix (prF3) THEN Instr (opCVTDQ2PD); Vpd; Wq;
				ELSIF Prefix (pr66) THEN Instr (opCVTTPD2DQ); Vq; Wpd;
				ELSIF Prefix (prF2) THEN Instr (opPSADBW); Pq; Qq;
				ELSE Invalid; END;
			| 00FE7H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opMOVNTDQ); Mdq; Vdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMOVNTQ); Mq; Pq; END;
			| 00FE8H: Type3 (opPSUBSB);
			| 00FE9H: Type3 (opPSUBSW);
			| 00FEAH: Type3 (opPMINSW);
			| 00FEBH: Type3 (opPOR);
			| 00FECH: Type3 (opPADDSB);
			| 00FEDH: Type3 (opPADDSW);
			| 00FEEH: Type3 (opPMAXSW);
			| 00FEFH: Type3 (opPXOR);
			| 00FF0H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Invalid;
				ELSIF Prefix (prF2) THEN Instr (opLDDQU); Vpd; Mdq;
				ELSE Invalid; END;
			| 00FF1H: Type3 (opPSLLW);
			| 00FF2H: Type3 (opPSLLD);
			| 00FF3H: Type3 (opPSLLQ);
			| 00FF4H: Type3 (opPMULUDQ);
			| 00FF5H: Type3 (opPMADDWD);
			| 00FF6H: Type3 (opPSADBW);
			| 00FF7H:
				IF Prefix (prF3) THEN Invalid;
				ELSIF Prefix (pr66) THEN Instr (opMASKMOVDQU); Vdq; VRdq;
				ELSIF Prefix (prF2) THEN Invalid;
				ELSE Instr (opMASKMOVQ); Pq; PRq; END;
			| 00FF8H: Type3 (opPSUBB);
			| 00FF9H: Type3 (opPSUBW);
			| 00FFAH: Type3 (opPSUBD);
			| 00FFBH: Type3 (opPSUBQ);
			| 00FFCH: Type3 (opPADDB);
			| 00FFDH: Type3 (opPADDW);
			| 00FFEH: Type3 (opPADDD);
			ELSE
				Invalid;
			END;
			END;

			WHILE arg < maxArgs DO
				opc.arg[arg] := NIL; INC (arg);
			END

		END DecodeThis;

	END AMD64Decoder;

PROCEDURE PrintReg (w : Streams.Writer; reg : LONGINT);
BEGIN
	CASE reg OF
	| regAL: w.String ("AL");
	| regCL: w.String ("CL");
	| regDL: w.String ("DL");
	| regBL: w.String ("BL");
	| regAH: w.String ("AH");
	| regCH: w.String ("CH");
	| regDH: w.String ("DH");
	| regBH: w.String ("BH");
	| regSPL: w.String ("SPL");
	| regBPL: w.String ("BPL");
	| regSIL: w.String ("SIL");
	| regDIL: w.String ("DIL");
	| regR8B: w.String ("R8B");
	| regR9B: w.String ("R9B");
	| regR10B: w.String ("R10B");
	| regR11B: w.String ("R11B");
	| regR12B: w.String ("R12B");
	| regR13B: w.String ("R13B");
	| regR14B: w.String ("R14B");
	| regR15B: w.String ("R15B");

	| regAX: w.String ("AX");
	| regCX: w.String ("CX");
	| regDX: w.String ("DX");
	| regBX: w.String ("BX");
	| regSP: w.String ("SP");
	| regBP: w.String ("BP");
	| regSI: w.String ("SI");
	| regDI: w.String ("DI");
	| regR8W: w.String ("R8W");
	| regR9W: w.String ("R9W");
	| regR10W: w.String ("R10W");
	| regR11W: w.String ("R11W");
	| regR12W: w.String ("R12W");
	| regR13W: w.String ("R13W");
	| regR14W: w.String ("R14W");
	| regR15W: w.String ("R15W");

	| regEAX: w.String ("EAX");
	| regECX: w.String ("ECX");
	| regEDX: w.String ("EDX");
	| regEBX: w.String ("EBX");
	| regESP: w.String ("ESP");
	| regEBP: w.String ("EBP");
	| regESI: w.String ("ESI");
	| regEDI: w.String ("EDI");
	| regR8D: w.String ("R8D");
	| regR9D: w.String ("R9D");
	| regR10D: w.String ("R10D");
	| regR11D: w.String ("R11D");
	| regR12D: w.String ("R12D");
	| regR13D: w.String ("R13D");
	| regR14D: w.String ("R14D");
	| regR15D: w.String ("R15D");

	| regRAX: w.String ("RAX");
	| regRCX: w.String ("RCX");
	| regRDX: w.String ("RDX");
	| regRBX: w.String ("RBX");
	| regRSP: w.String ("RSP");
	| regRBP: w.String ("RBP");
	| regRSI: w.String ("RSI");
	| regRDI: w.String ("RDI");
	| regR8: w.String ("R8");
	| regR9: w.String ("R9");
	| regR10: w.String ("R10");
	| regR11: w.String ("R11");
	| regR12: w.String ("R12");
	| regR13: w.String ("R13");
	| regR14: w.String ("R14");
	| regR15: w.String ("R15");

	| regES: w.String ("ES");
	| regCS: w.String ("CS");
	| regSS: w.String ("SS");
	| regDS: w.String ("DS");
	| regFS: w.String ("FS");
	| regGS: w.String ("GS");

	| regST0: w.String ("ST0");
	| regST1: w.String ("ST1");
	| regST2: w.String ("ST2");
	| regST3: w.String ("ST3");
	| regST4: w.String ("ST4");
	| regST5: w.String ("ST5");
	| regST6: w.String ("ST6");
	| regST7: w.String ("ST7");

	| regCR0: w.String ("CR0");
	| regCR1: w.String ("CR1");
	| regCR2: w.String ("CR2");
	| regCR3: w.String ("CR3");
	| regCR4: w.String ("CR4");
	| regCR5: w.String ("CR5");
	| regCR6: w.String ("CR6");
	| regCR7: w.String ("CR7");
	| regCR8: w.String ("CR8");
	| regCR9: w.String ("CR9");
	| regCR10: w.String ("CR10");
	| regCR11: w.String ("CR11");
	| regCR12: w.String ("CR12");
	| regCR13: w.String ("CR13");
	| regCR14: w.String ("CR14");

	| regDR0: w.String ("DR0");
	| regDR1: w.String ("DR1");
	| regDR2: w.String ("DR2");
	| regDR3: w.String ("DR3");
	| regDR4: w.String ("DR4");
	| regDR5: w.String ("DR5");
	| regDR6: w.String ("DR6");
	| regDR7: w.String ("DR7");
	| regDR8: w.String ("DR8");
	| regDR9: w.String ("DR9");
	| regDR10: w.String ("DR10");
	| regDR11: w.String ("DR11");
	| regDR12: w.String ("DR12");
	| regDR13: w.String ("DR13");
	| regDR14: w.String ("DR14");

	| regXMM0: w.String ("XMM0");
	| regXMM1: w.String ("XMM1");
	| regXMM2: w.String ("XMM2");
	| regXMM3: w.String ("XMM3");
	| regXMM4: w.String ("XMM4");
	| regXMM5: w.String ("XMM5");
	| regXMM6: w.String ("XMM6");
	| regXMM7: w.String ("XMM7");
	| regXMM8: w.String ("XMM8");
	| regXMM9: w.String ("XMM9");
	| regXMM10: w.String ("XMM10");
	| regXMM11: w.String ("XMM11");
	| regXMM12: w.String ("XMM12");
	| regXMM13: w.String ("XMM13");
	| regXMM14: w.String ("XMM14");

	| regMMX0: w.String ("MMX0");
	| regMMX1: w.String ("MMX1");
	| regMMX2: w.String ("MMX2");
	| regMMX3: w.String ("MMX3");
	| regMMX4: w.String ("MMX4");
	| regMMX5: w.String ("MMX5");
	| regMMX6: w.String ("MMX6");
	| regMMX7: w.String ("MMX7");

	| regIP: w.String ("IP");
	| regRIP: w.String ("RIP");

	END
END PrintReg;

PROCEDURE PrintImm (n: HUGEINT; w : Streams.Writer);
VAR high, low: LONGINT;
BEGIN
	IF (n >= -80H) & (n < 100H) THEN
		w.Int (SYSTEM.VAL (SHORTINT, n), 0);
	ELSE
		SYSTEM.GET (ADDRESSOF (n), low);
		SYSTEM.GET (ADDRESSOF (n) + 4, high);
		IF high # 0 THEN w.Hex (high, 0) END;
		w.Hex (low, 0); w.Char ('H');
	END;
END PrintImm;

PROCEDURE AMD64DecoderFactory (reader : Streams.Reader) : Decoder.Decoder;
VAR
	amd64Decoder : AMD64Decoder;
BEGIN
	NEW(amd64Decoder, reader);
	RETURN amd64Decoder
END AMD64DecoderFactory;

PROCEDURE Init*;
BEGIN
	Decoder.RegisterDecoder(objFileSuffix, AMD64DecoderFactory, NIL);
END Init;

END AMD64Decoder.

SystemTools.Free AMD64Decoder~
AMD64Decoder.Init~
Decoder.Open Test.Abx~


SystemTools.Free Decoder~
Decoder.Open Test.Bbx~

