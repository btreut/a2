MODULE DisplayLinear;

IMPORT CPU, Displays, Plugins;

CONST Width = 1024;
CONST Height = 768;
CONST Depth = 24;

VAR display: Displays.Display;

VAR buffer: RECORD {ALIGNED (16)}
	size, code := 0: SIZE;
	setPhysicalDisplay: RECORD tag := 048003H, size := 8, length := 8, width := Width, height := Height: SIZE END;
	setVirtualDisplay: RECORD tag := 048004H, size := 8, length := 8, width := Width, height := Height: SIZE END;
	setDepth: RECORD tag := 048005H, size := 4, length := 4, depth := Depth: SIZE END;
	setVirtualOffset: RECORD tag := 048009H, size := 8, length := 8, x := 0, y := 0: SIZE END;
	allocateBuffer: RECORD tag := 040001H, size := 8, length := 8: SIZE; frameBuffer: RECORD address := 0: ADDRESS; size := 0: SIZE END END;
	getPitch: RECORD tag := 040008H, size := 4, length := 4, pitch: SIZE END;
	end: RECORD tag := 0: SIZE END;
	padding: RECORD END;
END;

PROCEDURE Initialize;
CONST Mailbox = 3F00B880H; Status = 18H; Write = 20H; Tags = 8;
VAR address: ADDRESS; result: LONGINT;
BEGIN
	buffer.size := ADDRESS OF buffer.padding - ADDRESS OF buffer.size;
	FOR address := ADDRESS OF buffer.size TO ADDRESS OF buffer.padding BY CPU.CacheLineSize DO CPU.Clean (address) END;

	REPEAT
		WHILE 31 IN CPU.ReadMask (Mailbox + Status) DO END;
		CPU.WriteWord (Mailbox + Write, ADDRESS OF buffer + Tags);
		FOR address := ADDRESS OF buffer.size TO ADDRESS OF buffer.padding BY CPU.CacheLineSize DO CPU.Invalidate (address) END;
	UNTIL buffer.allocateBuffer.frameBuffer.address # NIL;

	NEW(display);
	display.width := buffer.setVirtualDisplay.width;
	display.height := buffer.setVirtualDisplay.height;
	display.offscreen := 0;
	display.format := buffer.setDepth.depth DIV 8;
	display.unit := 10000;
	display.InitFrameBuffer(buffer.allocateBuffer.frameBuffer.address, buffer.allocateBuffer.frameBuffer.size, buffer.getPitch.pitch);
	display.desc := "Linear framebuffer driver for Raspberry Pi";
	Displays.registry.Add(display, result);
	ASSERT(result = Plugins.Ok);
END Initialize;

BEGIN
	Initialize;
END DisplayLinear.
