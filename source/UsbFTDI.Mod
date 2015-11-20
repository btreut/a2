MODULE UsbFTDI;  (** AUTHOR "neuf"; PURPOSE "FTDI FT232BM USB-RS232 Converter Driver"; *)
(**
 * This is a A2 port of ftdi-sio.c, ftdi-sio.h.
 *
 * Usage:
 *
 *	UsbFTDI.Install ~ loads this driver
 *	SystemTools.Free UsbFTDI ~
 *
 * Status: BETA
 *
 * References:
 *
 *	UsbRS232.Mod by staubesv
 *	ftdi-sio.c Linux FTDI device driver
 *	ftdi-sio.h contains some documentation
 *
 * History:
 *
 *	26.09.2009	First Release (neuf)
 *	9.11.2012 Patched a bug in Send (COPY copies only until 0X), added some time tracing when buffer overflows (fof)
 *
 * Todo:
 *	- Correct Set(Get)LCR(MCR)
 *	- use PurgeTx(Rx) (in Port.Close?)
 * 	- use SetEvent(Error)Char (necessary?)
 *	- testing
 *)

IMPORT Usb (* for init of Usbdi.drivers ! *), SYSTEM, Kernel, KernelLog, Modules, Serials, Usbdi;

CONST

	Name = "UsbFtdi";
	Description = "USB-RS232 Interface Converter Driver (FT232BM)";
	Priority = 0;

	BufSize = 8192;

	TraceSend = {0};				(* Display sent characters *)
	TraceReceive = {1};			(* Display received characters *)
	TraceCommands = {2};
	TraceReceiveData = {3};
	TraceReceiveStatus = {4};
	(*TraceAll = {0..31};*)
	TraceNone = {};

(*	Trace = TraceReceive+TraceReceiveStatus+TraceReceiveData;*)
	Trace = TraceNone;

	Debug = TRUE;
	Verbose = TRUE;

	ModuleName = "UsbFTDI";

	(* ------- FTDI specific data ----------- *)
	(* IDs *)
	IdVendorFTDI = 0403H;
	IdProductFT232 = 6001H;

	(* Expected endpoints *)
	EpBulkOut = 02H; 	(* Used to send data *)
	EpBulkIn = 081H; 	(* Used to receive data *)

	(* request types (for convenience all of they collect here)*)
	FtdiReset=0;			(* Reset the port *)
	FtdiModemCtrl=1;		(* Set the modem control register *)
	FtdiSetFlowCtrl=2;		(* Set flow control register *)
	FtdiSetBaudrate=3;		(* Set baud rate *)
	FtdiSetData=4;			(* Set the data characteristics of the port *)
	FtdiGetModemStatus=5;	(* Retrieve current value of modern status register *)
	FtdiSetEventChar=6;		(* Set the event character *)
	FtdiSetErrorChar=7;		(* Set the error character *)

	(* Port Identifier Table (not used for now)*)
(*
	PitDefault=0; (* SIOA *)
	PitSioA=1; (* SIOA *)
	(* The device this driver is tested with one has only one port *)
	PitSioB=2; (* SIOB *)
	PitParallel=	3; (* Parallel *)
*)

	(* FtdiRESET *)
	(*
	* BmRequestType:  0100 0000B
	* bRequest:       FtdiRESET
	* wValue:         Control Value
	*                   0 = Reset SIO
	*                   1 = Purge RX buffer
	*                   2 = Purge TX buffer
	* wIndex:         Port
	* wLength:        0
	* Data:           None
	*
	* The Reset SIO command has this effect:
	*
	*    Sets flow control set to 'none'
	*    Event char = $0D
	*    Event trigger = disabled
	*    Purge RX buffer
	*    Purge TX buffer
	*    Clear DTR
	*    Clear RTS
	*    baud and data format not reset
	*
	* The Purge RX and TX buffer commands affect nothing except the buffers
	*
	*)
	(*FtdiResetRequestType=40H;*)
	FtdiResetRequest=FtdiReset;
	FtdiResetSio=0;
	FtdiResetPurgeRx=1;
	FtdiResetPurgeTx=2;


	(* FtdiSET_BAUDRATE *)
	(*
	* BmRequestType:  0100 0000B
	* bRequest:       FtdiSET_BAUDRATE
	* wValue:         BaudDivisor value - see below
	* wIndex:         Port
	* wLength:        0
	* Data:           None
	* The BaudDivisor values are calculated as follows:
	* - BaseClock is either 12000000 or 48000000 depending on the device. FIXME: I wish
	*   I knew how to detect old chips to select proper base clock!
	* - BaudDivisor is a fixed point number encoded in a funny way.
	*   (--WRONG WAY OF THINKING--)
	*   BaudDivisor is a fixed point number encoded with following bit weighs:
	*   (-2)(-1)(13..0). It is a radical with a denominator of 4, so values
	*   end with 0.0 (00...), 0.25 (10...), 0.5 (01...), and 0.75 (11...).
	*   (--THE REALITY--)
	*   The both-bits-set has quite different meaning from 0.75 - the chip designers
	*   have decided it to mean 0.125 instead of 0.75.
	*   This info looked up in FTDI application note "FT8U232 DEVICES \ Data Rates
	*   and Flow Control Consideration for USB to RS232".
	* - BaudDivisor = (BaseClock / 16) / BaudRate, where the (=) operation should
	*   automagically re-encode the resulting value to take fractions into consideration.
	* As all values are integers, some bit twiddling is in order:
	*   BaudDivisor = (BaseClock / 16 / BaudRate) |
	*   (((BaseClock / 2 / BaudRate) & 4) ? 0x4000    // 0.5
	*    : ((BaseClock / 2 / BaudRate) & 2) ? 0x8000  // 0.25
	*    : ((BaseClock / 2 / BaudRate) & 1) ? 0xc000  // 0.125
	*    : 0)
	*
	* For the FT232BM, a 17th divisor bit was introduced to encode the multiples
	* of 0.125 missing from the FT8U232AM.  Bits 16 to 14 are coded as follows
	* (the first four codes are the same as for the FT8U232AM, where bit 16 is
	* always 0):
	*   000 - add .000 to divisor
	*   001 - add .500 to divisor
	*   010 - add .250 to divisor
	*   011 - add .125 to divisor
	*   100 - add .375 to divisor
	*   101 - add .625 to divisor
	*   110 - add .750 to divisor
	*   111 - add .875 to divisor
	* Bits 15 to 0 of the 17-bit divisor are placed in the urb value.  Bit 16 is
	* placed in bit 0 of the urb index.
	*
	* Note that there are a couple of special cases to support the highest baud
	* rates.  If the calculated divisor value is 1, this needs to be replaced with
	* 0.  Additionally for the FT232BM, if the calculated divisor value is 0x4001
	* (1.5), this needs to be replaced with 0x0001 (1) (but this divisor value is
	* not supported by the FT8U232AM).
	*)
	(*FtdiSetBaudrateRequestType=40H;*)
	FtdiSetBaudrateRequest=FtdiSetBaudrate;

	(* FtdiData *)
	(*
	* BmRequestType:  0100 0000B
	* bRequest:       FtdiData
	* wValue:         Data characteristics (see below)
	* wIndex:         Port
	* wLength:        0
	* Data:           No
	*
	* Data characteristics
	*
	*   B0..7   Number of data bits
	*   B8..10  Parity
	*           0 = None
	*           1 = Odd
	*           2 = Even
	*           3 = Mark
	*           4 = Space
	*   B11..13 Stop Bits
	*           0 = 1
	*           1 = 1.5
	*           2 = 2
	*   B14
	*           1 = TX ON (break)
	*           0 = TX OFF (normal state)
	*   B15 Reserved
	*
	*)
	(*FtdiSetDataRequestType=40H;*)
	FtdiSetDataRequest=FtdiSetData;
	FtdiSetData5=5;
	FtdiSetData6=6;
	FtdiSetData7=7;
	FtdiSetData8=8;
	FtdiSetDataParityNone={};(*(0x0 << 8 )*)
	FtdiSetDataParityOdd={8};(*(0x1 << 8 )*)
	FtdiSetDataParityEven={9};(*(0x2 << 8 )*)
	FtdiSetDataParityMark={8,9};(*(0x3 << 8 )*)
	FtdiSetDataParitySpace={10};(*(0x4 << 8 )*)
	FtdiSetDataStopBits1={};(*(0x0 << 11 )*)
	FtdiSetDataStopBits15={11};(*(0x1 << 11 )*)
	FtdiSetDataStopBits2={12};(*(0x2 << 11 )*)
	FtdiSetDataBreak={14};(*(0x1 << 14)*)

	(* FtdiModemCtrl *)
	(*
	* BmRequestType:   0100 0000B
	* bRequest:        FtdiModemCtrl
	* wValue:          ControlValue (see below)
	* wIndex:          Port
	* wLength:         0
	* Data:            None
	*
	* NOTE: If the device is in RTS/CTS flow control, the RTS set by this
	* command will be IGNORED without an error being returned
	* Also - you can not set DTR and RTS with one control message
	* ControlValue
	* B0    DTR state
	*          0 = reset
	*          1 = set
	* B1    RTS state
	*          0 = reset
	*          1 = set
	* B2..7 Reserved
	* B8    DTR state enable
	*          0 = ignore
	*          1 = use DTR state
	* B9    RTS state enable
	*          0 = ignore
	*          1 = use RTS state
	* B10..15 Reserved
	*)
	(*FtdiModemCtrlRequestType=40H;*)
	FtdiModemCtrlRequest=FtdiModemCtrl;
	FtdiDtrMask=0;
	(*
	FtdiDtrHigh={0,8}(*right???*);(*( 1 | ( FtdiDtrMASK  << 8))*)
	FtdiDtrLow={0}(*right???*);(*( 0 | ( FtdiDtrMASK  << 8))*)
	*)
	FtdiRtsMask=1;
	(*
	FtdiRtsHigh={1,9}(*right???*);(*( 2 | ( FtdiRtsMASK << 8 ))*)
	FtdiRtsLow={1}(*right???*);(*( 0 | ( FtdiRtsMASK << 8 ))*)
	*)

	(* FtdiFlowCtrl *)
	(*
	*   BmRequestType:  0100 0000b
	*   bRequest:       FtdiFlowCtrl
	*   wValue:         Xoff/Xon
	*   wIndex:         Protocol/Port - hIndex is protocl / lIndex is port
	*   wLength:        0
	*   Data:           None
	*
	* hIndex protocol is:
	*   B0 Output handshaking using RTS/CTS
	*       0 = disabled
	*       1 = enabled
	*   B1 Output handshaking using DTR/DSR
	*       0 = disabled
	*       1 = enabled
	*   B2 Xon/Xoff handshaking
	*       0 = disabled
	*       1 = enabled
	*
	* A value of zero in the hIndex field disables handshaking
	*
	* If Xon/Xoff handshaking is specified, the hValue field should contain the XOFF character
	* and the lValue field contains the XON character.
	*)

	(*FtdiFlowCtrlRequestType=40H;*)
	FtdiFlowCtrlRequest=FtdiSetFlowCtrl;
	FtdiDisableFlowCtrl={}; (*0x0*)
	FtdiRtsCtsHs={8}(*right???*);(*(0x1 << 8)*)
	FtdiDtrDsrHs={9}(*right???*);(*(0x2 << 8)*)
	FtdiXonXoffHs={10}(*right???*);(*(0x4 << 8)*)

	(*
	* FtdiEventCHAR
	*
	* Set the special event character for the specified communications port.
	* If the device sees this character it will immediately return the
	* data read so far - rather than wait 40ms or until 62 bytes are read
	* which is what normally happens.
	*  BmRequestType:   0100 0000b
	*  bRequest:        FtdiEventChar
	*  wValue:          EventChar
	*  wIndex:          Port
	*  wLength:         0
	*  Data:            None
	*
	* wValue:
	*   B0..7   Event Character
	*   B8      Event Character Processing
	*             0 = disabled
	*             1 = enabled
	*   B9..15  Reserved
	*
	*)
	(*FtdiEventCharRequestType=40H;*)
	FtdiEventCharRequest=FtdiSetEventChar;



	(* FtdiErrorChar *)
	(* Set the parity error replacement character for the specified communications port *)
	(*
	*  BmRequestType:  0100 0000b
	*  bRequest:       FtdiEventCHAR
	*  wValue:         Error Char
	*  wIndex:         Port
	*  wLength:        0
	*  Data:           None
	*
	*Error Char
	*  B0..7  Error Character
	*  B8     Error Character Processing
	*           0 = disabled
	*           1 = enabled
	*  B9..15 Reserved
	*
	*)
	(*FtdiErrorCharRequestType=40H;*)
	FtdiErrorCharRequest=FtdiSetErrorChar;

	(* FtdiGetModemSTATUS *)
	(* Retreive the current value of the modem status register *)
	(*
	*   BmRequestType:   1100 0000b
	*   bRequest:        FtdiGetModemSTATUS
	*   wValue:          zero
	*   wIndex:          Port
	*   wLength:         1
	*   Data:            Status
	*
	* One byte of data is returned
	* B0..3 0
	* B4    CTS
	*         0 = inactive
	*         1 = active
	* B5    DSR
	*         0 = inactive
	*         1 = active
	* B6    Ring Indicator (RI)
	*         0 = inactive
	*         1 = active
	* B7    Receive Line Signal Detect (RLSD)
	*         0 = inactive
	*         1 = active
	*)
	(*FtdiGetModemStatusRequestType=0C0H; (ToHost+Vendor+Device)*)
	FtdiGetModemStatusRequest=FtdiGetModemStatus;
	FtdiCtsMask=4;(* 0x10*)
	FtdiDsrMask=5;(* 0x20*)
	FtdiRiMask=6;(* 0x40*)
	FtdiRlsdMask=7;(*0x80*)



(* Descriptors returned by the device
 *
 *  Device Descriptor
 *
 * Offset	Field			Size		Value	Description
 * 0			bLength				1	0x12	Size of descriptor in bytes
 * 1			bDescriptorType		1	0x01	DEVICE Descriptor Type
 * 2			bcdUSB				2	0x0110	USB Spec Release Number
 * 4			bDeviceClass		1	0x00	Class Code
 * 5			bDeviceSubClass	1	0x00	SubClass Code
 * 6			bDeviceProtocol		1	0x00	Protocol Code
 * 7			bMaxPacketSize0	1	0x08	Maximum packet size for endpoint 0
 * 8			idVendor			2	0x0403	Vendor ID
 * 10		idProduct			2	0x8372	Product ID (FtdiPID)
 * 12		bcdDevice			2	0x0001	Device release number
 * 14		iManufacturer		1	0x01	Index of man. string desc
 * 15		iProduct			1	0x02	Index of prod string desc
 * 16		iSerialNumber		1	0x02	Index of serial nmr string desc
 * 17		bNumConfigurations 1    0x01	Number of possible configurations
 *
 * Configuration Descriptor
 *
 * Offset	Field			Size	Value
 * 0	bLength			1	0x09	Size of descriptor in bytes
 * 1	bDescriptorType		1	0x02	CONFIGURATION Descriptor Type
 * 2	wTotalLength		2	0x0020	Total length of data
 * 4	bNumInterfaces		1	0x01	Number of interfaces supported
 * 5	bConfigurationValue	1	0x01	Argument for SetCOnfiguration() req
 * 6	iConfiguration		1	0x02	Index of config string descriptor
 * 7	bmAttributes		1	0x20	Config characteristics Remote Wakeup
 * 8	MaxPower		1	0x1E	Max power consumption
 *
 * Interface Descriptor
 *
 * Offset	Field			Size	Value
 * 0	bLength			1	0x09	Size of descriptor in bytes
 * 1	bDescriptorType		1	0x04	INTERFACE Descriptor Type
 * 2	bInterfaceNumber	1	0x00	Number of interface
 * 3	bAlternateSetting	1	0x00	Value used to select alternate
 * 4	bNumEndpoints		1	0x02	Number of endpoints
 * 5	bInterfaceClass		1	0xFF	Class Code
 * 6	bInterfaceSubClass	1	0xFF	Subclass Code
 * 7	bInterfaceProtocol	1	0xFF	Protocol Code
 * 8	iInterface		1	0x02	Index of interface string description
 *
 * IN Endpoint Descriptor
 *
 * Offset	Field			Size	Value
 * 0	bLength			1	0x07	Size of descriptor in bytes
 * 1	bDescriptorType		1	0x05	ENDPOINT descriptor type
 * 2	bEndpointAddress	1	0x82	Address of endpoint
 * 3	bmAttributes		1	0x02	Endpoint attributes - Bulk
 * 4	bNumEndpoints		2	0x0040	maximum packet size
 * 5	bInterval		1	0x00	Interval for polling endpoint
 *
 * OUT Endpoint Descriptor
 *
 * Offset	Field			Size	Value
 * 0	bLength			1	0x07	Size of descriptor in bytes
 * 1	bDescriptorType		1	0x05	ENDPOINT descriptor type
 * 2	bEndpointAddress	1	0x02	Address of endpoint
 * 3	bmAttributes		1	0x02	Endpoint attributes - Bulk
 * 4	bNumEndpoints		2	0x0040	maximum packet size
 * 5	bInterval		1	0x00	Interval for polling endpoint
 *
 * DATA FORMAT
 *
 * IN Endpoint
 *
 * The device reserves the first two bytes of data on this endpoint to contain the current
 * values of the modem and line status registers. In the absence of data, the device
 * generates a message consisting of these two status bytes every 40 ms
 *
 * Byte 0: Modem Status
 *
 * Offset	Description
 * B0	Reserved - must be 1
 * B1	Reserved - must be 0
 * B2	Reserved - must be 0
 * B3	Reserved - must be 0
 * B4	Clear to Send (CTS)
 * B5	Data Set Ready (DSR)
 * B6	Ring Indicator (RI)
 * B7	Receive Line Signal Detect (RLSD)
 *
 * Byte 1: Line Status
 *
 * Offset	Description
 * B0	Data Ready (DR)
 * B1	Overrun Error (OE)
 * B2	Parity Error (PE)
 * B3	Framing Error (FE)
 * B4	Break Interrupt (BI)
 * B5	Transmitter Holding Register (THRE)
 * B6	Transmitter Empty (TEMT)
 * B7	Error in RCVR FIFO
 *
 *)
 FtdiRs0Cts=4;(*(1 << 4)*)
 FtdiRs0Dsr=5;(*(1 << 5)*)
 FtdiRs0Ri=6;(*(1 << 6)*)
 FtdiRs0Rlsd=7;(*(1 << 7)*)

 FtdiRsDr=0;  (*1*)
 FtdiRsOe=1; (*(1<<1)*)
 FtdiRsPe=2; (*(1<<2)*)
 FtdiRsFe=3; (*(1<<3)*)
 FtdiRsBi=4; (*(1<<4)*)
 FtdiRsThre=5; (*(1<<5)*)
 FtdiRsTempt=6; (*(1<<6)*)
 FtdiRsFifo=7;  (*(1<<7)*)

(*
 * OUT Endpoint
 *
 * This device reserves the first bytes of data on this endpoint contain the length
 * and port identifier of the message. For the FTDI USB Serial converter the port
 * identifier is always 1.
 *
 * Byte 0: Line Status
 *
 * Offset	Description
 * B0	Reserved - must be 1
 * B1	Reserved - must be 0
 * B2..7	Length of message - (not including Byte 0)
 *
 *)


TYPE

	UsbFtdiDriver = OBJECT (Usbdi.Driver)
	VAR
		port : Port;
		controlPipe : Usbdi.Pipe;
		bulkIn: Usbdi.Pipe;
		bulkOut : Usbdi.Pipe;
		data1, data4, data64 : Usbdi.BufferPtr; (* datax -> ARRAY x OF CHAR *)
		status2 : Usbdi.BufferPtr;
		diagnostics : SET;
		msr : SET; (* Modem Status Register: Updated by UpdateStatus() & GetMSR *)
		lsr : SET;   (* Line Status Register: Updated by UpdateStatus() *)
		mcr : SET; (* Modem Control Register *)
		lcr : SET;   (* Line Control Register *)
		mc : SET; (*  Serials.DTR, Serials.RTS, Serials.DSR, Serials.CTS, Serials.RI, Serials.DCD & Serials.BI (Break Interrupt) *)

		PROCEDURE Connect() : BOOLEAN;
		VAR ignore : Usbdi.Status;
		BEGIN
			(* Get default control pipe *)
			controlPipe := device.GetPipe(0);
			IF controlPipe = NIL THEN
				IF Debug THEN ShowModule("Couldn't get default control pipe."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* Get bulk in pipes *)
			bulkIn := device.GetPipe(EpBulkIn);
			IF (bulkIn = NIL) THEN
				IF Debug THEN ShowModule("Couldn't get in pipes."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* Get bulk out pipe *)
			bulkOut := device.GetPipe(EpBulkOut);
			IF bulkOut = NIL THEN
				IF Debug THEN ShowModule("Couldn't get bulk out pipe."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* the interrupt pipe for endpoint EpInterruptStatus is used to asynchronously receive status information... set up the USB transfers. *)
			bulkIn.SetTimeout(0);
			NEW(port); port.driver := SELF; (* port is used in completion handler, must be set up here *)
			bulkIn.SetCompletionHandler(UpdateDataStatus);
			ignore := bulkIn.Transfer(64, 0, data64^);

			(* Reset device *)
			IF ~Reset() THEN
				IF Debug THEN ShowModule("GetMSR failed during connect."); KernelLog.Ln; END;
				RETURN FALSE;
			END;



			(* Get Modem Status Register (MSR) *)
			IF ~GetMSR(msr) THEN
				IF Debug THEN ShowModule("GetMSR failed during connect."); KernelLog.Ln; END;
				RETURN FALSE;
			END;



			(* Register port at Serials *)
			Serials.RegisterPort(port, Description);
			RETURN TRUE;
		END Connect;

		PROCEDURE Disconnect;
		BEGIN
			IF Debug THEN ShowModule("Driver Disconnected"); KernelLog.Ln; END;
			Serials.UnRegisterPort(SELF.port);
		END Disconnect;

		PROCEDURE ResetCmd(type:LONGINT):BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			(*
			usb_control_msg(serial->dev, usb_sndctrlpipe(serial->dev, 0),

			FTDI_SIO_RESET_REQUEST, FTDI_SIO_RESET_REQUEST_TYPE,

			FTDI_SIO_RESET_SIO,

			0, buf, 0, WDR_TIMEOUT);
			*)
			status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, FtdiResetRequest, type, 0, 0, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("SetLCR failed."); KernelLog.Ln; END;
				RETURN FALSE;
			ELSE
				RETURN TRUE;
			END;
		END ResetCmd;
		PROCEDURE Reset():BOOLEAN;
		BEGIN
			RETURN ResetCmd(FtdiResetSio);
		END Reset;
		PROCEDURE PurgeTx():BOOLEAN;
		BEGIN
			RETURN ResetCmd(FtdiResetPurgeTx);
		END PurgeTx;
		PROCEDURE PurgeRx():BOOLEAN;
		BEGIN
			RETURN ResetCmd(FtdiResetPurgeRx);
		END PurgeRx;
		PROCEDURE SetEventChar(ch:CHAR):BOOLEAN;
		VAR wValue:LONGINT;status : Usbdi.Status;
		BEGIN
			wValue:=LAND(ORD(ch),100H);
			status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, FtdiEventCharRequest, wValue, 0, 0, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("SetEventChar failed."); KernelLog.Ln; END;
				RETURN FALSE;
			ELSE
				RETURN TRUE;
			END;
		END SetEventChar;
		PROCEDURE SetErrorChar(ch:CHAR):BOOLEAN;
		VAR wValue:LONGINT;status : Usbdi.Status;
		BEGIN
			wValue:=LAND(ORD(ch),100H);
			status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, FtdiErrorCharRequest, wValue, 0, 0, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("SetEventChar failed."); KernelLog.Ln; END;
				RETURN FALSE;
			ELSE
				RETURN TRUE;
			END;
		END SetErrorChar;


		(* Interrupt on Completion - Handler for EpBulkIn; status(first 2 bytes) & data contained in variable data64 *)
		PROCEDURE UpdateDataStatus(status : Usbdi.Status; actLen : LONGINT);
		VAR ignore : Usbdi.Status;i:LONGINT;
		BEGIN
			IF Trace * TraceReceive # {} THEN
				ShowModule("UpdateDataStatus: Received ");
				KernelLog.String(" Bytes: ");KernelLog.Int(actLen, 0);
				KernelLog.String(" Status: ");KernelLog.Int(status,0);
				KernelLog.Ln;
			END;
			IF (status = Usbdi.Ok) OR (status = Usbdi.ShortPacket) THEN
				IF actLen>=2 THEN
					msr := SYSTEM.VAL(SET, data64[0]); (* status2[0] is the MSR *)
					IF FtdiRiMask IN msr THEN INCL(mc, Serials.RI); ELSE EXCL(mc, Serials.RI); END;
					IF FtdiDsrMask IN msr THEN INCL(mc, Serials.DSR); ELSE EXCL(mc, Serials.DSR); END;
					IF FtdiCtsMask IN msr THEN INCL(mc, Serials.CTS); ELSE EXCL(mc, Serials.CTS); END;
					IF FtdiRlsdMask IN msr THEN INCL(mc,  Serials.DCD); ELSE EXCL(mc, Serials.DCD); END;
					IF Trace * TraceReceiveStatus # {} THEN
						IF Serials.RI IN mc THEN KernelLog.String("[RI]"); END;
						IF Serials.DSR IN mc THEN KernelLog.String("[DSR]"); END;
						IF Serials.CTS IN mc THEN KernelLog.String("[CTS]"); END;
						IF Serials.DCD IN mc THEN KernelLog.String("[DCD]"); END;
					END;
					lsr := SYSTEM.VAL(SET, data64[1]); (* status2[1] is the LSR *)
					diagnostics := {};
					IF FtdiRsOe IN lsr THEN INCL(diagnostics, Serials.OverrunError); END;
					IF FtdiRsPe IN lsr THEN INCL(diagnostics, Serials.ParityError); END;
					IF FtdiRsFe IN lsr THEN INCL(diagnostics, Serials.FramingError); END;
					IF FtdiRsBi IN lsr THEN
						INCL(mc, Serials.BreakInterrupt); INCL(diagnostics, Serials.BreakInterrupt);
					ELSE
						EXCL(mc, Serials.BreakInterrupt);
					END;
					IF Trace * TraceReceiveStatus # {} THEN
						IF Serials.BreakInterrupt IN mc THEN KernelLog.String("[BI]"); END;
						KernelLog.String(" Errors: ");
						IF diagnostics = {} THEN KernelLog.String("none");
						ELSE
							IF Serials.OverrunError IN diagnostics THEN KernelLog.String("[Overrun]"); END;
							IF Serials.ParityError IN diagnostics THEN KernelLog.String("[Parity]"); END;
							IF Serials.FramingError IN diagnostics THEN KernelLog.String("[Framing]"); END;
							IF Serials.BreakInterrupt IN diagnostics THEN KernelLog.String("BreakInterrupt]"); END;
						END;
					END;
				END;
				IF actLen>2 THEN (* okay... now we have not only status but data too *)
					IF Trace * TraceReceiveData # {} THEN
						ShowModule("UpdateDataStatus: Received "); KernelLog.Int(actLen, 0); KernelLog.String(" Bytes:");
						FOR i := 0 TO actLen - 1 DO KernelLog.Char(" "); KernelLog.Int(ORD(data64[i]), 0); END;
						KernelLog.Ln;
					END;
					(* leave in data64 data only (exclude 2 status bytes)*)
					FOR i:=0 TO actLen-3 DO
						data64[i]:=data64[i+2];
					END;
					port.HandleData(data64^, actLen-2);
				END;
				ignore := bulkIn.Transfer(64, 0, data64^);(* get next data *)
			ELSE
				IF Debug THEN ShowModule("UpdateDataStatus failed."); KernelLog.Ln; 
					TRACE(status);
					
				END;
				ignore := bulkIn.Transfer(64, 0, data64^);(* get next data *)
			END;
			IF Trace * TraceReceiveStatus # {} THEN KernelLog.Ln; END;
		END UpdateDataStatus;

		(*
		* The BaudDivisor values are calculated as follows:
		* - BaseClock is either 12000000 or 48000000 depending on the device. FIXME: I wish
		*   I knew how to detect old chips to select proper base clock!
		* - BaudDivisor is a fixed point number encoded in a funny way.
		*   (--WRONG WAY OF THINKING--)
		*   BaudDivisor is a fixed point number encoded with following bit weighs:
		*   (-2)(-1)(13..0). It is a radical with a denominator of 4, so values
		*   end with 0.0 (00...), 0.25 (10...), 0.5 (01...), and 0.75 (11...).
		*   (--THE REALITY--)
		*   The both-bits-set has quite different meaning from 0.75 - the chip designers
		*   have decided it to mean 0.125 instead of 0.75.
		*   This info looked up in FTDI application note "FT8U232 DEVICES \ Data Rates
		*   and Flow Control Consideration for USB to RS232".
		* - BaudDivisor = (BaseClock / 16) / BaudRate, where the (=) operation should
		*   automagically re-encode the resulting value to take fractions into consideration.
		* As all values are integers, some bit twiddling is in order:
		*   BaudDivisor = (BaseClock / 16 / BaudRate) |
		*   (((BaseClock / 2 / BaudRate) & 4) ? 0x4000    // 0.5
		*    : ((BaseClock / 2 / BaudRate) & 2) ? 0x8000  // 0.25
		*    : ((BaseClock / 2 / BaudRate) & 1) ? 0xc000  // 0.125
 		*    : 0)
		*
		* For the FT232BM, a 17th divisor bit was introduced to encode the multiples
		* of 0.125 missing from the FT8U232AM.  Bits 16 to 14 are coded as follows
		* (the first four codes are the same as for the FT8U232AM, where bit 16 is
		* always 0):
		*   000 - add .000 to divisor
		*   001 - add .500 to divisor
		*   010 - add .250 to divisor
		*   011 - add .125 to divisor
		*   100 - add .375 to divisor
		*   101 - add .625 to divisor
		*   110 - add .750 to divisor
		*   111 - add .875 to divisor
		* Bits 15 to 0 of the 17-bit divisor are placed in the urb value.  Bit 16 is
		* placed in bit 0 of the urb index.
		*
		* Note that there are a couple of special cases to support the highest baud
		* rates.  If the calculated divisor value is 1, this needs to be replaced with
		* 0.  Additionally for the FT232BM, if the calculated divisor value is 0x4001
		* (1.5), this needs to be replaced with 0x0001 (1) (but this divisor value is
		* not supported by the FT8U232AM).
 		*)

(*
		PROCEDURE BaseToDivisor(baud:INTEGER ):LONGINT;

		VAR

			divfrac: ARRAY 8 OF LONGINT(* = { 0, 3, 2, 4, 1, 5, 6, 7 };*);
			divisor3, divisor: LONGINT;
		BEGIN
			divfrac[0]:=0;divfrac[1]:=3;divfrac[2]:=2;divfrac[3]:=4;
			divfrac[4]:=1;divfrac[5]:=5;divfrac[6]:=6;divfrac[7]:=7;
			divisor3:= (48000000 DIV 2) DIV baud ; (* divisor shifted 3 bits to the left*)
			divisor:= LSH(divisor3,3);
(*divisor3 >> 3*)
			divisor:=divisor + LSH(divfrac[divisor3 ], -14);
			(* Deal with special cases for highest baud rates. *)

			IF divisor = 1 THEN
				divisor:=0  (*1.0*)
			ELSIF divisor=4001H THEN
				divisor:=1;	(* 1.5 *)
			END;

			RETURN divisor;

		END BaseToDivisor;
*)



		(* Set baudrate divisor; returns TRUE if operation succeeded, FALSE otherwise *)
		PROCEDURE SetBaudrate(baudrate : LONGINT) : BOOLEAN;
		VAR divisor : LONGINT; status : Usbdi.Status;
			 wValue, wIndex:LONGINT;
		BEGIN
			IF Trace * TraceCommands # {} THEN ShowModule("SetBaudrate to "); KernelLog.Int(baudrate, 0); KernelLog.String(" bps."); KernelLog.Ln; END;
			port.portbps := 0; (* indicates invalid value *)

			IF ((device.descriptor.idVendor = IdVendorFTDI) & (device.descriptor.idProduct = IdProductFT232)) THEN
			(* use two-byte coded value
				based on frequency = 3 MHz.
				baudrate = 3MHz / divisor
				divisor encoded as
					ofs + 08000H =~= ofs +0.25
					ofs + 04000H =~= ofs +0.5
					ofs + 0C000H =~= ofs +0.125
					ofs + 10000H =~= ofs +0.375
					ofs + 14000H =~= ofs +0.625
					ofs + 18000H =~= ofs +0.75
					ofs + 1C000H =~= ofs +0.875
					where ofs <! 04000H (16234)
			*)
				IF baudrate = 300 THEN wValue := 2710H; wIndex:=0; (* 10000*)
				ELSIF baudrate = 600 THEN wValue := 1388H; wIndex:=0; (*5000*)
				ELSIF baudrate = 1200 THEN wValue := 09C4H; wIndex:=0; (*2500*)
				ELSIF baudrate = 2400 THEN wValue := 04E2H; wIndex:=0; (*1250*)
				ELSIF baudrate = 4800 THEN wValue := 0271H; wIndex:=0; (*625*)
				ELSIF baudrate = 9600 THEN wValue := 4138H; wIndex:=0; (*312+0.5*)
				ELSIF baudrate = 19200 THEN wValue := 809CH; wIndex:=0; (*156+0.25*)
				ELSIF baudrate = 38400 THEN wValue := 0C04EH; wIndex:=0; (*78+0.125*)
				ELSIF baudrate = 57600 THEN wValue := 0034H; wIndex:=0; (*52*)
				ELSIF baudrate = 115200 THEN wValue := 001AH; wIndex:=0; (*26*)
				ELSIF baudrate = 230400 THEN wValue := 000DH; wIndex := 0; (* 13 *)
				ELSIF baudrate = 460800 THEN wValue := 4006H; wIndex := 0; (* 6 + 0.5 *)
				ELSIF baudrate = 921600 THEN wValue := 8003H; wIndex := 0; (*3+0.25*)
				ELSE
					IF Debug THEN ShowModule("SetBaudrate: Wrong baud rate selected."); KernelLog.Ln; END;
					RETURN FALSE;
				END;

				data1[0] := CHR(divisor);
				status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, FtdiSetBaudrateRequest, wValue, wIndex, 0, data1^);

			ELSE (* standart UART way ... *)
				IF (115200 MOD baudrate) # 0 THEN
					IF Debug THEN ShowModule("SetBaudrate: Wrong baud rate selected."); KernelLog.Ln; END;
					RETURN FALSE;
				ELSE
					divisor := 115200 DIV baudrate;
				END;

				data4[0] := CHR(divisor);
				data4[1] := CHR(LSH(divisor, -8));
				data4[2] := CHR(LSH(divisor, -16));
				data4[3] := CHR(LSH(divisor, -24));
				status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, FtdiSetBaudrateRequest, 0, 0, 4, data4^);
			END;

			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("SetBaudrate failed (FtdiSetBaudrateRequest)"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			port.portbps := baudrate;
			RETURN TRUE;
		END SetBaudrate;

		(* Vendor-specific request: Used to set the Line Control Register (LCR) *)
		PROCEDURE SetLCR(set : SET) : BOOLEAN;
		VAR status : Usbdi.Status;wValue:LONGINT;
		BEGIN
			(*data1[0] := SYSTEM.VAL(CHAR, set);*)
			wValue:=SYSTEM.VAL(LONGINT,set);
			status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, FtdiSetDataRequest, wValue, 0, 0, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("SetLCR failed."); KernelLog.Ln; END;
				RETURN FALSE;
			ELSE
				lcr := set;
				RETURN TRUE;
			END;
		END SetLCR;
		(* vendor-specific request: Used to get the Line Control Register (LCR) *)
		PROCEDURE GetLCR(VAR lcr : SET) : BOOLEAN;
		(*VAR status : Usbdi.Status;*)
		BEGIN
			(*
			status := device.Request(Usbdi.ToHost + Usbdi.Vendor + Usbdi.Device, MctGetLineCtrl, 0, 0, 1, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("GetLCR failed."); KernelLog.Ln; END;
				RETURN FALSE;
			ELSE
				lcr := SYSTEM.VAL(SET, data1[0]);
				RETURN TRUE;
			END;
			*)
			lcr:=SELF.lcr;
			RETURN TRUE;
		END GetLCR;
		(* Vendor-specific request: used to set RTS & DTR Bits of the Modem Control Register (MCR) *)
		(* Updates DTR&RTS in mc *)
		PROCEDURE SetMCR(set : SET) : BOOLEAN;
		VAR status : Usbdi.Status;wValue:LONGINT;
		BEGIN
			IF Serials.DTR IN set THEN INCL(mcr, FtdiDtrMask); ELSE EXCL(mcr, FtdiDtrMask); END;
			IF Serials.RTS IN set THEN INCL(mcr, FtdiRtsMask); ELSE EXCL(mcr, FtdiRtsMask); END;
			(*INCL(mcr, MctMcrOut2); (* Always enable Out2 *)*)

			(*data1[0] := CHR(SYSTEM.VAL(LONGINT, mcr));*)
			wValue:=SYSTEM.VAL(LONGINT,mcr);
			status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, FtdiModemCtrlRequest, wValue, 0, 0, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("SetMCR failed: "); KernelLog.Ln; END;
				RETURN FALSE;
			ELSE
				IF Serials.DTR IN set THEN INCL(mc, Serials.DTR) ELSE EXCL(mc, Serials.DTR) END;
				IF Serials.RTS IN set THEN INCL(mc, Serials.RTS) ELSE EXCL (mc, Serials.RTS) END;
				RETURN TRUE;
			END;
		END SetMCR;

		(* Updates the msr & mc variable *)
		PROCEDURE GetMSR(VAR value : SET) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			status := device.Request(Usbdi.ToHost + Usbdi.Vendor + Usbdi.Device, FtdiGetModemStatusRequest, 0, 0, 2, status2^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("GetMSR failed."); KernelLog.Ln; END;
				RETURN FALSE;
			ELSE
				IF Trace * TraceCommands # {} THEN ShowModule("GetMSR succeeded (value: "); KernelLog.Bits(SYSTEM.VAL(SET, data1[0]), 0, 8); KernelLog.String(")");  KernelLog.Ln; END;
				msr := SYSTEM.VAL(SET, status2[0]);
				IF FtdiRiMask IN msr THEN INCL(mc, Serials.RI); ELSE EXCL(mc, Serials.RI); END;
				IF FtdiDsrMask IN msr THEN INCL(mc, Serials.DSR); ELSE EXCL(mc, Serials.DSR); END;
				IF FtdiCtsMask IN msr THEN INCL(mc, Serials.CTS); ELSE EXCL(mc, Serials.CTS);  END;
				(*IF FtdiCdMask IN msr THEN INCL(mc, Serials.DCD); ELSE EXCL(mc, Serials.DCD); END;*)
				value := msr;
				RETURN TRUE;
			END;
		END GetMSR;

		PROCEDURE &Init*;
		BEGIN
			NEW(data1, 1); NEW(data4, 4); NEW(data64, 64); NEW(status2, 2);
			msr := {}; lsr := {}; mcr := {}; lcr := {};
		END Init;

	END UsbFtdiDriver;

TYPE

	Port = OBJECT(Serials.Port)
	VAR
		driver : UsbFtdiDriver;
		portbps : LONGINT;
		data1 : Usbdi.BufferPtr; (* datax -> ARRAY x OF CHAR *)
		buf: ARRAY BufSize OF CHAR;
		sendBuffer: Usbdi.BufferPtr;
		head, tail: LONGINT;
		open: BOOLEAN;
		diagnostic: LONGINT;

		log: ARRAY 16 OF LONGINT;
		logPos: LONGINT;

		PROCEDURE & InitPort;
		BEGIN
			NEW(sendBuffer, 128); NEW(data1,1);
		END InitPort;

		PROCEDURE Open(bps, data, parity, stop : LONGINT; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			IF open THEN
				IF Verbose THEN ShowModule(name); KernelLog.String(" already open"); KernelLog.Ln; END;
				res := Serials.PortInUse;
				RETURN;
			END;
			SetPortState(bps, data, parity, stop, res);
			IF res = Serials.Ok THEN
				open := TRUE;
				head := 0; tail:= 0;
				IF Verbose THEN ShowModule(name); KernelLog.String("opened"); KernelLog.Ln; END;
			END
		END Open;

		(** Send len characters from buf to output, starting at ofs. res is non-zero on error. *)
		PROCEDURE Send(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR status : Usbdi.Status;
		BEGIN {EXCLUSIVE}
			IF ~open THEN res := Serials.Closed; RETURN; END;
			IF Trace * TraceSend # {} THEN ShowModule("Sending "); KernelLog.Int(len, 0); KernelLog.String(" bytes"); KernelLog.Ln; END;
			IF ((sendBuffer = NIL) OR (LEN(sendBuffer) < len)) THEN NEW(sendBuffer, len) END;
			SYSTEM.MOVE(ADDRESSOF(buf[ofs]), ADDRESSOF(sendBuffer[0]), len);
			status := driver.bulkOut.Transfer(len, ofs, sendBuffer^);
			IF status = Usbdi.Ok THEN
				res := Serials.Ok;
				charactersSent := charactersSent + len;
			ELSE
				res := Serials.TransportError;
				IF Debug THEN ShowModule("Transmission failed, res: "); KernelLog.Int(status, 0); KernelLog.Ln; END;
			END;
		END Send;

		(** Send a single character to the UART. *)
		PROCEDURE SendChar(ch: CHAR; VAR res : LONGINT);
		VAR status : Usbdi.Status;
		BEGIN {EXCLUSIVE}
			IF ~open THEN res := Serials.Closed; RETURN; END;
			data1[0] := ch;
			IF Trace * TraceSend # {} THEN ShowModule("Sending character ORD: "); KernelLog.Int(ORD(data1[0]), 0); KernelLog.Ln; END;
			status := driver.bulkOut.Transfer(1, 0, data1^);
			IF status # Usbdi.Ok THEN
				res := Serials.Ok;
				INC(charactersSent);
			ELSE
				res := Serials.TransportError;
				IF Debug THEN ShowModule("Transmission of character failed."); KernelLog.Ln; END;
			END;
		END SendChar;

		(** Wait for the next character is received in the input buffer. The buffer is fed by HandleData *)
		PROCEDURE ReceiveChar(VAR ch: CHAR; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			IF ~open THEN res := Serials.Closed; RETURN; END;
			AWAIT(tail # head);
			IF tail = -1 THEN
				res := Serials.Closed;
			ELSE
				ch := buf[head]; head := (head+1) MOD BufSize;
				res := diagnostic
			END
		END ReceiveChar;


		(** Receive size characters into buf, starting at ofs and return the effective number of bytes read in len.
			Wait until at least min bytes (possibly zero) are available. res is non-zero on error. *)
		PROCEDURE Receive*(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		VAR ch: CHAR;
		BEGIN
			len := 0;
			res := Serials.Ok;
			WHILE (len < min) DO
				ReceiveChar(ch, res);
				IF res # Serials.Ok THEN RETURN END;
				buf[ofs + len] := ch;
				INC(len);
			END;
			WHILE (Available() > 0) & (len < size) DO
				ReceiveChar(ch, res);
				IF res # Serials.Ok THEN RETURN END;
				buf[ofs + len] := ch;
				INC(len)
			END;

			log[logPos] := Kernel.GetTicks();
			logPos := (logPos + 1) MOD LEN(log)

		END Receive;

		(** On detecting an interupt request, transfer the characters from the UART buffer to the input buffer *)
		PROCEDURE HandleData(CONST data :  Usbdi.Buffer; actLen : LONGINT);
		VAR n, i : LONGINT; 	ch : CHAR;
		BEGIN {EXCLUSIVE}
			charactersReceived := charactersReceived + actLen;
			i := 0;
			LOOP
				IF i >= actLen THEN EXIT; END;
				ch := data[i];
				n := (tail + 1) MOD BufSize;
				IF tail = -1 THEN
					(*
					IF Debug THEN KernelLog.String("UsbFTDI.Port.HandleData: connection was closed"); KernelLog.Ln END;
					EXIT
					*)
				ELSIF n # head THEN
					buf[tail] := ch; tail := n
				ELSE
					IF Debug THEN
						IF log[logPos]#MAX(LONGINT) THEN
							KernelLog.String("UsbFTDI.Port.HandleData: Buffer overflow detected"); KernelLog.Ln;
							KernelLog.Int(Kernel.GetTicks(), 1); KernelLog.Ln;
							FOR i := 0 TO LEN(log)-1 DO
								KernelLog.Int(i,1); KernelLog.String(":"); KernelLog.Int(log[(logPos+i) MOD LEN(log)], 1); KernelLog.Ln;
							END;
							log[logPos]:= MAX(LONGINT)
						END;
					END;
					EXIT;
				END;
				INC(i);
				diagnostic := SYSTEM.VAL(LONGINT, driver.diagnostics - {Serials.OverrunError, Serials.ParityError, Serials.FramingError, Serials.BreakInterrupt}); 
					(* not including Serials.OE, Serials.PE, Serials.FE & Serials.BI, otherwise the driver stops receiving data when frame errors occur *)
			END;
		END HandleData;

		PROCEDURE Available(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN (tail - head) MOD BufSize
		END Available;

		PROCEDURE SetPortState(bps, data, parity, stop : LONGINT; VAR res: LONGINT);
		VAR s : SET;
		BEGIN
			IF (bps > 0) & (921600 MOD bps = 0) THEN

				IF (data >= 5)
					& (data <= 8)
					& (parity >= Serials.ParNo)
					& (parity <= Serials.ParSpace)
					& (stop >= Serials.Stop1)
					& (stop <= Serials.Stop1dot5) THEN

					IF ~driver.SetBaudrate(bps) THEN
						res := Serials.WrongBPS; RETURN;
					END;

					(* Prepare parameters destined to LCR data, stop, parity *)
					CASE data OF	(* word length *)
						   5: s := SYSTEM.VAL(SET,FtdiSetData5);
						| 6: s := SYSTEM.VAL(SET,FtdiSetData6);
						| 7: s := SYSTEM.VAL(SET,FtdiSetData7);
						| 8: s := SYSTEM.VAL(SET,FtdiSetData8);
					END;

					CASE parity OF
						   Serials.ParNo: 	s := s + FtdiSetDataParityNone;
						| Serials.ParOdd: 	s := s + FtdiSetDataParityOdd;
						| Serials.ParEven: 	s := s + FtdiSetDataParityEven;
						| Serials.ParMark: 	s := s + FtdiSetDataParityMark;
						| Serials.ParSpace: 	s := s + FtdiSetDataParitySpace;
					END;
					(*
					IF (stop = Serials.Stop1dot5) & (data # 5) THEN res := Serials.WrongStop; RETURN; END;
					IF stop # Serials.Stop1 THEN s := s + FtdiSetDataStopBits2;  END;
					code instead is below*)
					CASE stop OF
						Serials.Stop1: s:=s+FtdiSetDataStopBits1;
						|Serials.Stop1dot5: s:=s+FtdiSetDataStopBits15;
						|Serials.Stop2: s:=s+FtdiSetDataStopBits2;
					END;

					(* Finalize the LCR *)
					IF ~driver.SetLCR(s) THEN
						res := Serials.WrongData;RETURN;
					END;

					(* Set DTR, RTS in the MCR *)
					s := {}; INCL(s, Serials.DTR); INCL(s, Serials.RTS);
					IF ~driver.SetMCR(s) THEN
						res := Serials.WrongData; RETURN;
					END;
					res := Serials.Ok
				ELSE
					res := Serials.WrongData (* bad data/parity/stop *)
				END
			ELSE
				res := Serials.WrongBPS (* bad BPS *)
			END;
		END SetPortState;

		(** Get the port state: speed, no. of data bits, parity, no. of stop bits *)
		PROCEDURE GetPortState(VAR openstat : BOOLEAN; VAR bps, data, parity, stop : LONGINT);
		VAR set : SET; res : BOOLEAN;
		BEGIN
			(* get parameters *)
			openstat := open;
			bps := portbps;

			res := driver.GetLCR(set);
			data:=LAND(SYSTEM.VAL(LONGINT,set),0FFH);


			IF set * FtdiSetDataStopBits2 # {} THEN
				IF data = FtdiSetData5 THEN stop := Serials.Stop1dot5; 	ELSE stop := Serials.Stop2; END;
			ELSE
				stop := Serials.Stop1;
			END;

			IF set * {3..5} = FtdiSetDataParitySpace THEN parity := Serials.ParSpace;
			ELSIF set * {3..5} = FtdiSetDataParityMark THEN parity := Serials.ParMark;
			ELSIF set * {3..5} = FtdiSetDataParityEven THEN parity := Serials.ParEven;
			ELSIF set * {3..5} = FtdiSetDataParityOdd THEN parity := Serials.ParOdd;
			ELSE parity := Serials.ParNo;
			END;
			IF Trace * TraceCommands # {} THEN
				ShowModule("GetPortState of port "); KernelLog.String(name); KernelLog.String(":");
				IF res THEN
					KernelLog.String(" State: "); IF open THEN KernelLog.String("Open"); ELSE KernelLog.String("Closed"); END;
					KernelLog.String(" DataBits: "); KernelLog.Int(data, 0);
					KernelLog.String(" StopBits: "); IF stop=3 THEN KernelLog.String("1.5"); ELSE KernelLog.Int(stop, 0); END;
					KernelLog.String(" Parity: ");
					CASE parity OF
						0 : KernelLog.String("None");
						|1 : KernelLog.String("Odd");
						|2 : KernelLog.String("Even");
						|3 : KernelLog.String("Mark");
						|4 : KernelLog.String("Space");
					ELSE
						KernelLog.String("Unknown");
					END;
					KernelLog.String(" Bps: "); KernelLog.Int(bps, 0); KernelLog.Ln;
				ELSE
					KernelLog.String("Status request failed."); KernelLog.Ln;
				END;
			END;
		END GetPortState;

		(** ClearMC - Clear the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE ClearMC(s: SET);
		VAR  temp : SET; ignore : BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF s * {Serials.DTR, Serials.RTS} # {} THEN
				temp := driver.mcr;
				IF s * {Serials.DTR} # {} THEN EXCL(temp, Serials.DTR); END;
				IF s * {Serials.RTS} # {} THEN EXCL(temp, Serials.RTS); END;
				ignore := driver.SetMCR(temp);
			END;
			IF Serials.Break IN s THEN
				ignore := driver.GetLCR(temp);
				EXCL(temp, Serials.Break);
				ignore := driver.SetLCR(temp);
			END;
		END ClearMC;

		(** SetMC - Set the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE SetMC(s: SET);
		VAR ignore : BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF s * {Serials.DTR, Serials.RTS} # {} THEN ignore := driver.SetMCR(s * {Serials.DTR, Serials.RTS}); END;
			IF Serials.Break IN s THEN
				ignore := driver.SetLCR({Serials.Break});
			END;
		END SetMC;

		(** GetMC - Return the state of the specified modem control lines. s contains the current state of DSR, CTS, RI, DCD & Break Interrupt. *)
		PROCEDURE GetMC(VAR s: SET);
		BEGIN {EXCLUSIVE}
			s := driver.msr; (* Inlcudes CTS, DSR, RI, CD *)
			IF FtdiRsBi IN driver.lsr THEN INCL(s, Serials.Break); END;
		END GetMC;

		PROCEDURE Close;
		VAR timer : Kernel.Timer; counter : LONGINT;
		BEGIN {EXCLUSIVE}
			IF ~open THEN
				IF Verbose THEN ShowModule(name); KernelLog.String(" not open"); KernelLog.Ln; END;
				RETURN;
			ELSE
				IF ~(FtdiRsTempt IN driver.lsr) THEN (* wait for last byte to leave *)
					NEW(timer); counter := 0;
					REPEAT
						timer.Sleep(1);
						INC(counter);
					UNTIL (FtdiRsTempt IN driver.lsr) OR (counter>100); (* No remaining word in the FIFO or transmit shift register *)
				END;
				tail := -1; (* Force a pending Receive to terminate in error. *)
				open := FALSE;
				IF Verbose THEN ShowModule(name); KernelLog.String(" closed"); KernelLog.Ln END;
			END;
		END Close;

	END Port;

PROCEDURE LAND(x, y: LONGINT): LONGINT;
BEGIN RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, x) * SYSTEM.VAL(SET, y))
END LAND;

PROCEDURE ShowModule(CONST string : ARRAY OF CHAR);
BEGIN
	KernelLog.String(ModuleName); KernelLog.String(": "); KernelLog.String(string);
END ShowModule;

PROCEDURE Probe(dev : Usbdi.UsbDevice; id : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
VAR driver : UsbFtdiDriver;
BEGIN
	IF ((dev.descriptor.idVendor = IdVendorFTDI) & (dev.descriptor.idProduct = IdProductFT232)) THEN (* FTDI FT2232 *)
	ELSE (* device not supported *)
		RETURN NIL;
	END;
	NEW(driver);
	RETURN driver;
END Probe;

PROCEDURE Cleanup;
BEGIN
	Usbdi.drivers.Remove(Name);
END Cleanup;

PROCEDURE Install*;
END Install;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Usbdi.drivers.Add(Probe, Name, Description, Priority)
END UsbFTDI.
SystemTools.Free UsbFTDI ~
UsbFTDI.Install ~
UsbFTDI.Open ~
UsbFTDI.Send ~
UsbFTDI.Close~ 