MODULE Telnet; (* ejz,  *)
	IMPORT Modules, Streams, TCP, TCPServices, ShellCommands, KernelLog;

	CONST
		NUL = CHR(0); BEL = CHR(7); BS = CHR(8); HT = CHR(9); LF = CHR(10); VT = CHR(11); FF = CHR(12); CR = CHR(13);

		CmdEOF = CHR(236); CmdSUSP = CHR(237); CmdABORT = CHR(238); CmdEOR = CHR(239);
		CmdSE* = CHR(240); CmdNOP = CHR(241); CmdDM = CHR(242); CmdBRK = CHR(243); CmdIP = CHR(244);
		CmdAO = CHR(245); CmdAYT = CHR(246); CmdEC = CHR(247); CmdEL = CHR(248); CmdGA = CHR(249);
		CmdSB* = CHR(250); CmdWILL* = CHR(251); CmdWONT = CHR(252); CmdDO* = CHR(253); CmdDONT = CHR(254);
		CmdIAC* = CHR(255);

		OptEcho* = CHR(1); OptSupGoAhead* = CHR(3); OptStatus = CHR(5); OptTimingMatk = CHR(6);
		OptTerminalType* = CHR(24); OptWindowSize* = CHR(31); OptTerminalSpeed = CHR(32);
		OptFlowControl = CHR(33); OptLineMode = CHR(34); OptEnvVars = CHR(36); OptNewEnv = CHR(39);

		MaxLine = 256;

		Telnet* = 0; VT100* = 1; Echo* = 2;Tcp*=3;  Closed* = 31;

	TYPE
		Connection* = OBJECT
			VAR
				C: Streams.Connection;
				R*: Streams.Reader; W*: Streams.Writer;
				flags*: SET; (* Telnet, VT100, Echo, Closed *)

			PROCEDURE WILL*(option: CHAR);
			BEGIN
				W.Char(CmdIAC);
				IF option = OptEcho THEN
					W.Char(CmdDO); W.Char(OptEcho)
				ELSIF option = OptSupGoAhead THEN
					W.Char(CmdDO); W.Char(OptSupGoAhead)
				ELSE
					W.Char(CmdDONT); W.Char(option)
				END
			END WILL;

			PROCEDURE WONT*(option: CHAR);
			BEGIN
				W.Char(CmdIAC); W.Char(CmdDONT); W.Char(option)
			END WONT;

			PROCEDURE Do*(option: CHAR);
			BEGIN
				W.Char(CmdIAC);
				IF option = OptEcho THEN
					W.Char(CmdWILL); W.Char(OptEcho); INCL(flags, Echo)
				ELSIF option = OptSupGoAhead THEN
					W.Char(CmdWILL); W.Char(OptSupGoAhead)
				ELSE
					W.Char(CmdWONT); W.Char(option)
				END
			END Do;

			PROCEDURE DONT*(option: CHAR);
			BEGIN
				IF option = OptEcho THEN EXCL(flags, Echo) END;
				W.Char(CmdIAC); W.Char(CmdWONT); W.Char(option)
			END DONT;

			PROCEDURE SB*(option: CHAR);
				VAR ch0, ch: CHAR;
			BEGIN
KernelLog.String("SB "); KernelLog.Int(ORD(option), 0); KernelLog.Ln();
				R.Char(ch0); R.Char(ch);
				WHILE ~((ch0 = CmdIAC) & (ch = CmdSE)) DO
					ch0 := ch; R.Char(ch)
				END
			END SB;

			PROCEDURE Consume*(ch: CHAR);
			END Consume;

			PROCEDURE Dispatch;
				VAR ch: CHAR;
			BEGIN
				R.Char(ch);
				WHILE R.res = Streams.Ok DO
					IF (ch = CmdIAC) & (Telnet IN flags) THEN
						R.Char(ch);
						CASE ch OF
							CmdWILL: R.Char(ch); WILL(ch)
							|CmdWONT: R.Char(ch); WONT(ch)
							|CmdDO: R.Char(ch); Do(ch)
							|CmdDONT: R.Char(ch); DONT(ch)
							|CmdSB: R.Char(ch); SB(ch)
							|CmdIAC: Consume(ch)
						ELSE
							HALT(99)
						END;
						W.Update()
					ELSE
						Consume(ch)
					END;
					R.Char(ch)
				END
			END Dispatch;

			PROCEDURE Setup*;
			END Setup;

			PROCEDURE Close*;
			BEGIN {EXCLUSIVE}
				IF C # NIL THEN
					C.Close(); C := NIL
				END
			END Close;

			PROCEDURE Wait;
			BEGIN {EXCLUSIVE}
				AWAIT(Closed IN flags)
			END Wait;

			PROCEDURE &Init*(C: Streams.Connection);
			BEGIN
				SELF.C := C; flags := {};
				Streams.OpenReader(R, C.Receive);
				Streams.OpenWriter(W, C.Send)
			END Init;

		BEGIN {ACTIVE}
			Setup();
			Dispatch();
			BEGIN {EXCLUSIVE}
				INCL(flags, Closed)
			END
		END Connection;

		ServerConnection = OBJECT (Connection)
			VAR
				ctx: ShellCommands.Context;
				line: ARRAY MaxLine+1 OF CHAR; pos, len: LONGINT;
				term: ARRAY 32 OF CHAR;

			PROCEDURE WILL(option: CHAR);
			BEGIN
				IF option = OptTerminalType THEN
					W.Char(CmdIAC); W.Char(CmdSB);
					W.Char(OptTerminalType);
					W.Char(01X); (* SEND *)
					W.Char(CmdIAC); W.Char(CmdSE)
				ELSE
					WILL^(option)
				END
			END WILL;

			PROCEDURE IsVT100(str: ARRAY OF CHAR): BOOLEAN;
				VAR i: LONGINT; old, ch: CHAR;
			BEGIN
				old := 0X; i := 0; ch := str[0];
				WHILE (ch # 0X) & ~((old = "V") & (ch = "T")) DO
					old := ch; INC(i); ch := str[i]
				END;
				RETURN (old = "V") & (ch = "T")
			END IsVT100;

			PROCEDURE SB(option: CHAR);
				VAR term: ARRAY 32 OF CHAR; i: LONGINT; ch: CHAR;
			BEGIN
				IF option = OptTerminalType THEN
					IF R.Peek() = 0X THEN (* IS *)
						R.Char(ch); (* 0X *)
						R.Char(ch); i := 0;
						WHILE (i < 31) & (ch # CmdIAC) DO
							term[i] := ch; INC(i); R.Char(ch)
						END;
						term[i] := 0X; ASSERT(ch = CmdIAC);
						R.Char(ch); ASSERT(ch = CmdSE);
						IF IsVT100(term) THEN
							COPY(term, SELF.term); INCL(flags, VT100)
						ELSIF term # SELF.term THEN
							COPY(term, SELF.term); WILL(OptTerminalType)
						ELSE
							SELF.term := ""; EXCL(flags, VT100)
						END
					ELSE
						SB^(option)
					END
				ELSE
					SB^(option)
				END
			END SB;

			PROCEDURE Command;
				VAR msg: ARRAY MaxLine OF CHAR; res: LONGINT;
			BEGIN
				ShellCommands.Execute(ctx, line, res, msg);
				IF res # 0 THEN
					W.Int(res, 0); W.String(": "); W.String(msg); W.Ln()
				END
			END Command;

			PROCEDURE Prompt;
			BEGIN
				W.String("> ")
			END Prompt;

			PROCEDURE Consume(ch: CHAR);
				VAR i: LONGINT; update, echo: BOOLEAN;
			BEGIN
				echo := Echo IN flags; update := echo;
				IF ch = CR THEN
					IF echo THEN W.Char(CR) END;
					IF R.Peek() = LF THEN
						R.Char(ch); IF echo THEN W.Char(LF) END
					END;
					line[len] := 0X;
					Command();
					line := ""; pos := 0; len := 0;
					Prompt(); update := TRUE
				ELSIF ch = 08X THEN
					IF pos > 0 THEN
						IF echo THEN W.Char(ch) END;
						DEC(pos)
					END
				ELSIF ch = 07FX THEN
					IF pos > 0 THEN
						IF echo THEN W.Char(ch) END;
						DEC(pos); DEC(len); i := pos;
						WHILE i < MaxLine DO
							line[i] := line[i+1]; INC(i)
						END
					END
				ELSIF ch = 01BX THEN (* ESC *)
					IF (VT100 IN flags) & (R.Peek() = "[") THEN
						R.Char(ch); R.Char(ch);
						CASE ch OF
							"C": IF pos < len THEN
										IF echo THEN W.Char(01BX); W.String("[C") END;
										INC(pos)
									END
							|"D": IF pos > 0 THEN
										IF echo THEN W.Char(01BX); W.String("[D") END;
										DEC(pos)
									END
						ELSE
KernelLog.String("ESC ["); KernelLog.Char(ch); KernelLog.Ln()
						END
					END
				ELSIF (ch >= 020X) & (pos < MaxLine) THEN
					IF echo THEN W.Char(ch) END;
					line[pos] := ch; INC(pos);
					IF pos > len THEN len := pos END
				END;
				IF update THEN W.Update() END
			END Consume;

			PROCEDURE Setup;
			BEGIN
				IF Telnet IN flags THEN
					IF ~(Echo IN flags) THEN
						W.Char(CmdIAC); W.Char(CmdWILL); W.Char(OptEcho)
					END;
					IF ~(VT100 IN flags) THEN
						W.Char(CmdIAC); W.Char(CmdDO); W.Char(OptTerminalType)
					END
				END;
				Prompt(); W.Update()
			END Setup;

			PROCEDURE &Init*(C: Streams.Connection);
			BEGIN
				Init^(C); INCL(flags, Telnet); term := "";
				line := ""; pos := 0; len := 0;
				NEW(ctx, C, R, W, W);
			END Init;

		END ServerConnection;

		Agent = OBJECT (TCPServices.Agent)
			VAR C: ServerConnection;

		BEGIN {ACTIVE}
			NEW(C, client);
			C.Wait(); Terminate()
		END Agent;

	VAR
		service: TCPServices.Service;

	PROCEDURE NewAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
		VAR a: Agent;
	BEGIN
		NEW(a, c, s); RETURN a
	END NewAgent;

	PROCEDURE OpenService*;
	VAR res: LONGINT;
	BEGIN
		IF service = NIL THEN
			NEW(service, 23, NewAgent,res)
		END;
	END OpenService;

	PROCEDURE TermMod;
	BEGIN
		IF service # NIL THEN
			service.Stop; service := NIL;
		END
	END TermMod;

BEGIN
	service := NIL; Modules.InstallTermHandler(TermMod)
END Telnet.

System.Free WMVT100 Telnet ShellCommands ~	System.OpenKernelLog

ShellCommands.Mod WMVT100.Mod

Aos.Call Telnet.OpenService ~

Configuration.DoCommands
System.DeleteFiles Telnet.zip ~
ZipTool.Add \9 Telnet.zip Telnet.Mod ShellCommands.Mod WMVT100.Mod old.WMVT100.Mod ~
NetSystem.SetUser ftp:zeller@lillian.inf.ethz.ch ~
FTP.Open zeller@lillian.inf.ethz.ch ~
FTP.PutFiles Telnet.zip ~
FTP.Close ~
~
