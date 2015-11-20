# To compile all files in a specific release...
#
# A2
#
# 	Release.Build A2 ~
#
#	Bootimage (IDE)
#	Linker.Link \PAOS: \.Obx AOS:IDE.Bin 0100000H 1000H Kernel Traps
#	ATADisks DiskVolumes DiskFS BootConsole ~
#
#	Bootimage (USB)
#	Linker.Link \PAOS: \.Obx AOS:USB.Bin 0100000H 1000H Kernel Traps
#	UsbHubDriver UsbEhci UsbUhci UsbOhci UsbStorageBoot
#	DiskVolumes DiskFS BootConsole ~
#
# A2 Cooperative
#
#	Release.Build --build --path="./" A2Cooperative ~
#	StaticLinker.Link --fileName=a2.bin --extension=Gof --displacement=100000H --path="./" Trace CPU Runtime Counters APIC Processors Queues BaseTypes Activities ExclusiveBlocks HeapManager Interrupts Environment Mutexes Machine Heaps Modules GarbageCollector Objects Kernel KernelLog Streams Reflection TrapWriters Traps Plugins Disks PCI ATADisks Caches Commands Files DiskVolumes Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker GenericLoader BootConsole ~
#
# A2 RPi Cooperative
#
#	Release.Build --build --path="./" A2RPiCooperative ~
#	StaticLinker.Link --fileName=kernel.img --extension=Gof --displacement=8000H --path="./" Trace CPU Runtime Counters Processors Queues BaseTypes Timer Activities ExclusiveBlocks HeapManager Interrupts Environment Mutexes Machine Heaps Modules GarbageCollector Objects Kernel ~
#
# WINAOS
#
# There are two different variants of WinAOS:
#
# 	Internal version: Oberon Application runs in a WinAos  Window
#
# 	Release.Build --build WinAos ~
#
#	Bootimage
#	PELinker.Link --path=../obj/  Win32.Aos.Link ~
#
# 	External version: Oberon Applications runs in a separate MS Windows Window
#
# 	Release.Build eWinAos ~
#
#	Bootimage
#	PELinker.Link  --path=../ObjE/ Win32.Aos.Link ~
#
# WINAOS generic
#	Release.Build --path="/temp/obg/" WinAosNewObjectFile ~
#	StaticLinker.Link --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H --path="/temp/obg/" Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands FIles WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~
#  Do not forget to add the object file path to the path and to add ObjectFileExtension= ".ObfW" to your .ini file in order to configure the loader.
# 
# WINAOS Cooperative
#	Release.Build  --path="./" WinAosCooperative ~
#	StaticLinker.Link --fileFormat=PE32 --fileName=a2.exe --extension=GofCW --displacement=401000H --path="./" Trace CPU Runtime Counters Kernel32 Processors Queues BaseTypes Timer Activities ExclusiveBlocks Environment Mutexes Interrupts Machine Heaps Modules GarbageCollector Objects Kernel KernelLog Streams Commands FIles WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader BootConsole ~
#	FSTools.CloseFiles A2.exe ~
# 
# Notes:
#	-	The command PELinker.Link creates the Aos.exe executable file. Per default, it will be created in the Work folder.
#	-	The configuration file aos.ini specifies from which directory the object files are loaded. If you want to switch between the
#		internal and external version, you need to adapted aos.ini.
#
# For the detailed command syntax: See Release.Mod
#

# The HEADER section includes the following information:
#
#	VERSION
#	Version string of the form <Major> "." <Minor>
#	Compatibility to Release.Mod: Major version numbers must be equal. Minor number of Release.Mod must be at lest <Minor>
#
# The BUILD section describes what builds can be built. For each build, the following options can be specified:
#
#	INCLUDE
#	In this package description file it is possible to describe files that are only contained in certain builds. This is done by using indicates, e.g. WIN { list of files } means that
#	the files listed in curly brackets will only be included in builds that include the indicator WIN.
#	Note that if a file is listed without an indicator, it will be included in all releases, so INCLUDE describes what files should be additionally
#	included.
#	The list of indicators must be specified as enquoted string of space separated indicator names.
#
#	COMPILER
#	Compile command to be used to compile the files included in the build. This option can be overriden by using the --compiler option of
#	the Release.Build command.
#
#	COMPILEOPTIONS, TARGET, EXTENSION & PATH
# 	Command line options for the compiler. These options can be overriden by using the --target, --extension and --path  option of the
#	Release.Build command.
#	The release tool be generate the compiler option string like : COMPILEOPTIONS + " \d" + TARGET + " \." + EXTENSION + " \P" + PATH
#
#	EXCLUDEPACKAGES
#	By default, all packages are included in all builds. Using the EXCLUDEPACKAGES option, packages can explicitly be excluded from a build.
#	The list of packages must be specified as enquoted string of space separated package names.
#	This option can be overriden by the --exclude option of the Release.Build command.
#
#	DISABLED
#	Set to TRUE to indicate that a build is broken. The Release.Check command will not attempt to compile
#	disabled builds. The commands Release.Build and Release.Rebuild will prompt a warning message but do their jobs. All other
#	commands simply ignore this setting.
#
# To actually build such a build, call Release.Build buildname ~
#
# Note:
#
#	Files whose name is of the form prefix.mid.suffix where prefix="Release" and suffix#"Mod" will be added to the corresponding package twice:
#	prefix.mid.suffix AND mid.suffix
#

HEADER
	VERSION "1.0"
END

BUILDS
	A2 {
		INCLUDE "NATIVE NATIVEORIG I386 I386ORIG UNCOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS ""
		TARGET "AMD"
		EXTENSION "Obx"
		SYMBOLEXTENSION "Obx"
		PATH "AOS:"
		EXCLUDEPACKAGES ""
		DISABLED "FALSE"
	}
	A2Cooperative {
		INCLUDE "NATIVE I386 COOP NATIVECOOP NATIVEI386COOP I386COOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "--cooperative --objectFile=Generic --newObjectFile --traceModule=Trace --mergeSections"
		TARGET "AMD"
		EXTENSION "Gof"
		SYMBOLEXTENSION "Sym"
		PATH "AOS:"
		EXCLUDEPACKAGES "Applications GuiApplications Fun Testing Education Contributions Oberon OberonGadgets OberonApplications OberonDocumentation OberonVoyager OberonAnts"
		DISABLED "FALSE"
	}
	A2RPiCooperative {
		INCLUDE "NATIVE ARM RPI COOP RPICOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "--cooperative --objectFile=Generic --newObjectFile --traceModule=Trace --mergeSections"
		TARGET "ARM"
		EXTENSION "Gof"
		SYMBOLEXTENSION "Sym"
		PATH "AOS:"
		EXCLUDEPACKAGES "System Drivers Compiler ApplicationsMini Applications GuiApplicationsMini GuiApplications Fun Testing Education Build EFI Contributions Oberon OberonGadgets OberonApplications OberonDocumentation OberonVoyager OberonAnts"
		DISABLED "FALSE"
	}
	A2NewObjectFile
	{
		INCLUDE "NATIVE NATIVEGEN I386 I386GEN UNCOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "--objectFile=Generic --newObjectFile --mergeSections"
		TARGET "AMD"
		EXTENSION "Gox"
		SYMBOLEXTENSION "Syx"
		PATH "AOS:"
		EXCLUDEPACKAGES "Applications GuiApplications Fun Testing Education Contributions Oberon OberonGadgets OberonApplications OberonDocumentation OberonVoyager OberonAnts"
		DISABLED "FALSE"
	}
	WinAosNewObjectFile
	{
		INCLUDE "WIN iWIN WINGEN UNCOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "--objectFile=Generic --newObjectFile --mergeSections"
		TARGET "AMD"
		EXTENSION "GofW"
		SYMBOLEXTENSION "SymW"
		PATH "AOS:"
		EXCLUDEPACKAGES "Oberon OberonGadgets OberonApplications OberonDocumentation OberonVoyager OberonAnts TrueTypeFonts CjkFonts Pr3Fonts ScreenFonts Pr6Fonts"
		DISABLED "FALSE"
	}
	A2_64 {
		INCLUDE "NATIVE NATIVEORIG AMD64 AMD64ORIG UNCOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "--bits=64"
		TARGET "AMD"
		EXTENSION "Abx"
		SYMBOLEXTENSION "Abx"
		PATH "AOS:"
		EXCLUDEPACKAGES "Contributions Oberon OberonGadgets OberonApplications OberonDocumentation OberonVoyager OberonAnts"
		DISABLED "FALSE"
	}
	A2mini {
		INCLUDE "NATIVE NATIVEORIG I386 I386ORIG UNCOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS ""
		TARGET "AMD"
		EXTENSION "Obx"
		SYMBOLEXTENSION "Obx"
		PATH "AOS:"
		EXCLUDEPACKAGES "Applications GuiApplications Fun Testing Education Contributions Oberon OberonGadgets OberonApplications OberonDocumentation OberonVoyager OberonAnts"
		DISABLED "FALSE"
	}
	WinAos {
		INCLUDE "WIN WINORIG iWIN UNCOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS ""
		TARGET "AMD"
		EXTENSION "Obw"
		SYMBOLEXTENSION "Obw"
		PATH "../obj/"
		EXCLUDEPACKAGES ""
		DISABLED "FALSE"
	}
	WinAosCooperative {
		INCLUDE "WIN iWIN COOP WINCOOP I386COOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "--cooperative --objectFile=Generic --newObjectFile --traceModule=Trace"
		TARGET "AMD"
		EXTENSION "GofCW"
		SYMBOLEXTENSION "SymCW"
		PATH "../obj/"
		EXCLUDEPACKAGES "Oberon OberonGadgets OberonApplications OberonDocumentation OberonVoyager OberonAnts TrueTypeFonts CjkFonts Pr3Fonts ScreenFonts Pr6Fonts"
		DISABLED "FALSE"
	}
	WinAosMini
	{
		INCLUDE "WIN WINORIG iWIN UNCOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS ""
		TARGET "AMD"
		EXTENSION "Obw"
		SYMBOLEXTENSION "Obw"
		PATH ""
		EXCLUDEPACKAGES "Build Education Fun Testing Contributions Oberon OberonGadgets OberonApplications OberonDocumentation OberonVoyager OberonAnts CjkFonts Pr3Fonts Pr6Fonts"
		DISABLED "FALSE"
	}
	eWinAos {
		INCLUDE "WIN WINORIG eWIN UNCOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS ""
		TARGET "AMD"
		EXTENSION "Obw"
		SYMBOLEXTENSION "Obw"
		PATH "../ObjE/"
		EXCLUDEPACKAGES ""
		DISABLED "FALSE"
	}
	LinuxAos {
		INCLUDE "UNIX LINUX UNCOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS ""
		TARGET "AMD"
		EXTENSION "Obj"
		SYMBOLEXTENSION "Obj"
		PATH "NewAos/"
		EXCLUDEPACKAGES "OberonVoyager OberonAnts"
		DISABLED "FALSE"
	}
	DarwinAos {
		INCLUDE "UNIX DARWIN UNCOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS "--darwinHost"
		TARGET "AMD"
		EXTENSION "Obj"
		SYMBOLEXTENSION "Obj"
		PATH "NewAos/"
		EXCLUDEPACKAGES "OberonVoyager OberonAnts"
		DISABLED "FALSE"
	}
	SolarisAos {
		INCLUDE "UNIX SOLARIS UNCOOP"
		COMPILER "Compiler.Compile"
		COMPILEOPTIONS ""
		TARGET "AMD"
		EXTENSION "Obj"
		SYMBOLEXTENSION "Obj"
		PATH "NewAos/"
		EXCLUDEPACKAGES "OberonVoyager OberonAnts"
		DISABLED "FALSE"
	}
END

PACKAGE Kernel ARCHIVE "Kernel.zip" SOURCE "KernelSrc.zip" DESCRIPTION "A2 Kernel"

	License.Text
	OBEMBR.BIN 												# MBR
	BootManagerMBR.Bin BootManagerTail.Bin 					# Boot manager
	BootManager.Bin BootManager.Text
	OBL.Bin OBL.Text 											# Boot loader
	Setup.Text													# Documentation

# Active Oberon run-time

	 # Runtime support for HUGEINT and strings
	UNCOOP { Runtime.Mod }
	I386COOP { I386.CPU.Mod }
	RPICOOP { RPI.CPU.Mod }

	# Low-level trace output
	Trace.Mod

	# cooperative runtime system
	COOP { Counters.Mod }
	NATIVEI386COOP { I386.APIC.Mod APIC.Processors.Mod BIOS.ACPI.Mod ACPI.Timer.Mod}
	WINCOOP { Coop.Win32.Kernel32.Mod Win32.Processors.Mod  Win32.Timer.Mod}
	RPICOOP { RPI.Processors.Mod RPI.Timer.Mod }
	COOP { Queues.Mod BaseTypes.Mod Activities.Mod ExclusiveBlocks.Mod Interrupts.Mod Coop.Runtime.Mod }
	NATIVECOOP { HeapManager.Mod BIOS.Environment.Mod }
	RPICOOP { HeapManager.Mod RPI.Environment.Mod }
	WINCOOP { Win32.Environment.Mod }

	UNIX { Unix.Glue.Mod }
	DARWIN { Darwin.I386.Unix.Mod } LINUX { Linux.I386.Unix.Mod } SOLARIS { Solaris.I386.Unix.Mod }

	WINORIG { Win32.Kernel32.Mod}
	WINGEN {Generic.Win32.Kernel32.Mod}

	I386ORIG { I386.Machine.Mod }
	I386GEN { Generic.I386.Machine.Mod }
	AMD64 { AMD64.Machine.Mod }
	WINORIG, WINGEN {Win32.Machine.Mod }
	COOP { Mutexes.Mod }
	I386COOP { Coop.I386.Machine.Mod }
	RPICOOP { Coop.ARM.Machine.Mod }

	UNIX { Unix.I386.Machine.Mod }

	NATIVEORIG, NATIVEGEN, WINORIG, WINGEN { Heaps.Mod }
	UNIX { Unix.Heaps.Mod }
	COOP { Coop.Heaps.Mod }

	NATIVEORIG, WINORIG, UNIX { Modules.Mod }
	NATIVEGEN, WINGEN { Generic.Modules.Mod}
	COOP { Coop.Modules.Mod GarbageCollector.Mod }

	NATIVEORIG, NATIVEGEN { Objects.Mod Kernel.Mod }
	WINORIG, WINGEN { Win32.Objects.Mod Win32.Kernel.Mod }
	UNIX { Unix.Objects.Mod Unix.Kernel.Mod }
	COOP { Coop.Objects.Mod Coop.Kernel.Mod }
END

PACKAGE System ARCHIVE "System.zip" SOURCE "SystemSrc.zip" DESCRIPTION "System"

# kernel extensions

	# Kernel log output
	KernelLog.Mod

	# Services and device drivers
	Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod

	I386, WIN, UNIX { I386.Reals.Mod }
	AMD64 { AMD64.Reals.Mod }
	ARM { ARM.Reals.Mod }

	# default trap handling
	UNCOOP { Reflection.Mod }
	COOP { Coop.Reflection.Mod }
	TrapWriters.Mod CRC.Mod SystemVersion.Mod
	NATIVEORIG, NATIVEGEN { Traps.Mod }
	AMD64 { AMD64.Traps.Mod }
	ARM { ARM.Traps.Mod }
	WINORIG, WINGEN {  Win32.Traps.Mod }
	UNIX { Unix.StdIO.Mod Unix.Traps.Mod }
	COOP { Coop.Traps.Mod }

	# Recursive and R/W locks
	Locks.Mod

	# PCI bus interface
	I386 {BiosFreePCI.Mod }
	AMD64 { AMD64.PCI.Mod }

	# Realtime clock driver
	NATIVE { Clock.Mod }
	WIN { Win32.Clock.Mod }
	UNIX { Unix.Clock.Mod }

	# Memory cache control
	I386ORIG, I386GEN { I386.MemCache.Mod }
	AMD64ORIG { AMD64.MemCache.Mod }
	COOP { Coop.MemCache.Mod }

	# Block device interface
	Disks.Mod

	Files.Mod


	Dates.Mod Strings.Mod # low-level utility modules
	UTF8Strings.Mod

	FileTrapWriter.Mod

	Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod OberonFS.Mod 	# file systems
	FATVolumes.Mod FATFiles.Mod
	ISO9660Volumes.Mod ISO9660Files.Mod

	UNIX { Unix.UnixFiles.Mod }

	WIN {
		Win32.User32.Mod Win32.WinTrace.Mod Win32.ODBC.Mod Win32.Shell32.Mod Win32.SQL.Mod
		Win32.WinFS.Mod
	}

	NATIVE,WIN,UNIX { RelativeFileSystem.Mod } # file system relative to path

	NATIVE,WIN,UNIX { Loader.Mod }
	NATIVEGEN, WINGEN, COOP {BitSets.Mod Diagnostics.Mod StringPool.Mod ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod }

	# binding modules
	NATIVE,WIN { BootConsole.Mod }
	UNIX { Unix.BootConsole.Mod }

	Displays.Mod

	 # input drivers
 	Inputs.Mod

	# Command line option parser
	Options.Mod

	# system event logging
	Events.Mod
	EventsUtils.Mod
	EventsKernelLog.Mod EventsFileLog.Mod EventsMemoryLog.Mod

	DynamicStrings.Mod XMLObjects.Mod XML.Mod XMLScanner.Mod XMLParser.Mod 	# XML parser (swalther)
	Configuration.Mod Configuration.XML Save.Configuration.XML FileHandlers.Mod		# XML-based configuration file

	BootShell.Mod

	I386,UNIX { I386.Network.Mod }
	AMD64 { AMD64.Network.Mod }
	ARM { ARM.Network.Mod }
	NATIVE { NetworkMii.Mod }

	ActiveTimers.Mod

	WIN { Win32.GDI32.Mod }
	WINORIG, WINGEN { Win32.Display.Mod }
	WINCOOP { Coop.Win32.Display.Mod }
	
	WIN {
		Win32.WSock32.Mod
		Win32.Network.Mod
		Win32.IP.Mod Win32.DNS.Mod
		Win32.UDP.Mod
		Win32.TCP.Mod
		Win32.CommandLine.Mod	# Command Line Parsing for Windows A2
	}

	I386 { I386.IP.Mod I386.IPv4.Mod }
	AMD64 { AMD64.IP.Mod AMD64.IPv4.Mod }
	ARM { ARM.IP.Mod ARM.IPv4.Mod }

	NATIVE {
		IPv6.Mod ICMP.Mod UDP.Mod DNS.Mod 	# IP, UDP, TCP
		TCP.Mod DHCP.Mod
		InitNetwork.Mod MinInitNetwork.Mod						# network initialisation
		Ping.Mod TraceRoute.Mod TCPPortLog.Mod	 	# network tools
	}

	UNIX {
		Unix.IP.Mod
		Unix.Sockets.Mod
		Unix.TCP.Mod Unix.UDP.Mod Unix.DNS.Mod
	}

	# Serial port interface
	Serials.Mod

	# Sound device interface
	SoundDevices.Mod

	# Joystick interface
	Joysticks.Mod

	# TV card interface
	TVDriver.Mod

END

PACKAGE Drivers ARCHIVE "Drivers.zip" SOURCE "DriversSrc.zip" DESCRIPTION "Device Drivers"

	# virtual device drivers
	VirtualDisks.Mod # Virtual disk (implements Disks interface)
	DisplayNull.Mod # Virtual display (implements Displays interface)

	# Serial port drivers (implement Serials interface)
	NATIVE { V24.Mod }
	WIN { Win32.V24.Mod }
	UNIX { Unix.V24.Mod }

	# PC speaker driver
	NATIVE { Beep.Mod }
	WIN { Win32.Beep.Mod }

	# Pseudo sound driver for UnixAos
	UNIX { Unix.OpenAL.Mod  OpenALSound.Mod }

	WIN { Win32.WinDisks.Mod } # direct windows disk access, implements Disks interface

	NATIVE { SCSI.Mod }

	I386 { I386.ATADisks.Mod }
	AMD64 { AMD64.ATADisks.Mod }

	I386 { I386.Adaptec7Script.Mod Adaptec7.Mod } # Adaptec SCSI driver

	NATIVE {
		# disk drivers (implement Disks interface)
		NCRScript.Mod SymbiosASPI.Mod SymbiosDisks.Mod NCR810Disks.Mod	# Symbios SCSI driver
	}

	# PS/2 keyboard incl. layouts

	I386 { I386.Keyboard.Mod }
	AMD64 { AMD64.Keyboard.Mod }

	NATIVE {
		KeyUK.Bin KeyCA.Bin KeyCH.Bin KeyD.Bin KeyN.Bin KeyTR.Bin KeyPL.Bin KeyDV.Bin
		KeyFR.Bin KeyBE.Bin KeySF.Bin KeyIT.Bin KeyUS.Bin

		MousePS2.Mod MouseSerial.Mod

		# Display drivers (implement Displays interface)
		DisplayLinear.Mod

		# Loopback driver (implements Network interface)
		Loopback.Mod

		# network drivers (implement Network interface)
		Ethernet3Com90x.Mod RTL8139.Mod RTL8169.Mod Intel8255x.Mod
		AM79C970.Mod

		# Sound drivers (implement SoundDevice interface)
		EnsoniqSound.Mod YMF754.Mod YMF754.Bin i810Sound.Mod

		# TV card driver (implements TVDriver interface)
		BT848.Mod

		# USB core
		UsbDebug.Mod
		Usbdi.Mod UsbHcdi.Mod
		UsbUhci.Mod UsbOhci.Mod UsbEhci.Mod UsbEhciPCI.Mod
		UsbDriverLoader.Mod UsbUtilities.Mod Usb.Mod UsbHubDriver.Mod

		# USB mass storage class driver
		UsbStorageBase.Mod UsbStorageBot.Mod UsbStorageCbi.Mod
		UsbStorageScm.Mod UsbStorageBoot.Mod UsbStorage.Mod

		# USB HID class driver
		UsbHid.Mod
		UsbMouse.Mod
		
		#USB <-> RS232 FTDI driver
		UsbFTDI.Mod
	}

	I386 { I386.UsbKeyboard.Mod }
	AMD64 { AMD64.UsbKeyboard.Mod }

	NATIVE {
		UsbHidUP.Mod UsbHidErrors.Mod UsbHidReport.Mod
		UsbHidParserExt.Mod UsbHidParser.Mod
		UsbHidDriver.Mod

		# USB network drivers
		UsbNetwork.Mod UsbNetworkUSB200M.Mod

		UsbPrinter.Mod
		UsbGarminGPS18.Mod

		# Touchscreen drivers
		UsbTouchscreen.Mod

		# Bluetooth stack
		Bluetooth.Mod BluetoothUART.Mod UsbBluetooth.Mod BluetoothUSB.Mod
		BluetoothHCI.Mod BluetoothL2CAP.Mod BluetoothRFCOMM.Mod
	}
	
	NATIVEORIG {
		# Floppy disk driver
		Diskettes.Mod
	}
END

PACKAGE Compiler ARCHIVE "Compiler.zip" SOURCE "CompilerSrc.zip" DESCRIPTION "Active Oberon Compiler"
	# this package should be moved before any GUI part (dependencies must be removed in Backend)

	StringPool.Mod Diagnostics.Mod Debugging.Mod

	Fox.Tool	
	BitSets.Mod ObjectFile.Mod GenericLinker.Mod StaticLinker.Mod
	FoxBasic.Mod  FoxProgTools.Mod  FoxScanner.Mod FoxCSharpScanner.Mod FoxSyntaxTree.Mod FoxGlobal.Mod
	FoxActiveCells.Mod FoxHardware.Mod FoxFormats.Mod FoxPrintout.Mod
	FoxParser.Mod FoxCSharpParser.Mod  FoxSemanticChecker.Mod
	FoxBackend.Mod FoxSections.Mod 
	FoxFrontend.Mod FoxOberonFrontend.Mod FoxCSharpFrontend.Mod
	FoxCompiler.Mod FoxFingerPrinter.Mod  FoxInterfaceComparison.Mod FoxTextualSymbolFile.Mod FoxBinarySymbolFile.Mod
	FoxBinaryCode.Mod FoxIntermediateCode.Mod FoxIntermediateBackend.Mod FoxCodeGenerators.Mod
	FoxBinaryObjectFile.Mod FoxGenericObjectFile.Mod
	FoxAMD64InstructionSet.Mod FoxAMD64Assembler.Mod FoxAMDBackend.Mod
	FoxAssembler.Mod FoxIntermediateAssembler.Mod FoxDisassembler.Mod
	FoxARMInstructionSet.Mod FoxARMAssembler.Mod FoxARMBackend.Mod	FoxMinosObjectFile.Mod
	FoxIntermediateParser.Mod FoxIntermediateObjectFile.Mod FoxIntermediateLinker.Mod 
	FoxTRMInstructionSet.Mod FoxTRMAssembler.Mod FoxTRMBackend.Mod 

	FoxInterpreterBackend.Mod FoxTranspilerBackend.Mod
	FoxDocumentationScanner.Mod FoxDocumentationTree.Mod FoxDocumentationPrinter.Mod FoxDocumentationHtml.Mod 
	FoxDocumentationParser.Mod FoxDocumentationBackend.Mod

	FoxProfiler.Mod

	# Runtime support for math oberon (Move to runtime package? *)
	I386, WIN, UNIX { XMM.I386.Math.Mod XMM.I386.MathL.Mod }
	#FPU32 { I386.Math.Mod I386.MathL.Mod }
	AMD64 { XMM.AMD64.Math.Mod XMM.AMD64.MathL.Mod }
	#FPU64 { AMD64.Math.Mod AMD64.MathL.Mod }
	FoxArrayBase.Mod
	I386, WIN, UNIX { I386.FoxArrayBaseOptimized.Mod }
END

PACKAGE ApplicationsMini ARCHIVE "ApplicationsMini.zip" SOURCE "ApplicationsMiniSrc.zip" DESCRIPTION "Minimal applications set"

	# Error API and error codes definition
	Errors.Mod errors.txt

	# Access to system functions
	UNIX { Unix.ProcessInfo0.Mod }
	NATIVE, WIN { ProcessInfo0.Mod }
	ProcessInfo.Mod

	SystemTools.Mod
	Reboot.Mod # Tool to reboot machine after delay (and write system reboot time to file)

	WIN { Win32.WinApplications.Mod }

	NATIVE {
		DriverDatabase.Mod DriverDatabase.XML
		PCITools.Mod pci.ids # Automatic HW detection
	}

	I386, WIN, UNIX { XMM.I386.Math.Mod XMM.I386.MathL.Mod }
	AMD64 { XMM.AMD64.Math.Mod XMM.AMD64.MathL.Mod }
	#FPU32 { I386.Math.Mod I386.MathL.Mod }
	#FPU64 { AMD64.Math.Mod AMD64.MathL.Mod }

	Random.Mod  Drand48.Mod

	SerialsVirtual.Mod # Virtual serial port (implements Serials interface)

	Autostart.Mod FSTools.Mod

	UpTime.Mod	# Uptime monitor

	CLUTs.Mod AosDefault.Pal

	# raster images (eos)
	I386, WIN, UNIX { I386.Raster.Mod }
	AMD64 { AMD64.Raster.Mod }

	Localization.Mod
	Archives.Mod

	WMRectangles.Mod WMEvents.Mod
	Repositories.Mod

	FP1616.Mod DefaultTextStyles.XML	# Text System

	Texts.Mod


	UndoManager.Mod

	CRC.Mod
	Inflate.Mod # decompression on streams
	Unzip.Mod 	# zip file support
	ZipFS.Mod

	Codecs.Mod	# Codec Defintions

	# Support for bidirectional text rendering and contextual dependencies
	BidiMirroring.txt
	UnicodeData.txt
	UnicodeProperties.Mod
	ArabicContext.xml
	TestContext.xml
	ContextualDependency.Mod
	UnicodeBidirectionality.Mod

	# Move to graphical package!!
	I386, WIN, UNIX { I386.WMRasterScale.Mod }
	AMD64 { AMD64.WMRasterScale.Mod }

	WMGraphics.Mod


	TextUtilities.Mod bluebottle.xsl	# Text Utilities

	Types.Mod
	Models.Mod
	WMProperties.Mod

	WMMessages.Mod
	WMWindowManager.Mod

	WMGraphicUtilities.Mod

	WMDropTarget.Mod

	WMComponents.Mod # Components

	KernelLogger.Mod

	# Compiler interfaces
	CompilerInterface.Mod FoxTextCompiler.Mod

	# PC - Parallel Compiler (self-compile only)
	PCDebug.Mod PCM.Mod PCS.Mod PCT.Mod PCBT.Mod 	# prk
	PCLIR.Mod PCO.Mod PCG386.Mod PCC.Mod PCV.Mod PCArrays.Mod
	PCB.Mod PCP.Mod PCA386.Mod PCOM.Mod PCOF.Mod PCOFPE.Mod PC.Mod
	I386,WIN { ArrayBase.Mod I386.ArrayBaseOptimized.Mod }
	PCOARM.Mod PCARMCP.Mod PCARMRegisters.Mod	# ARM Backend (be)
	PCAARM.Mod PCGARM.Mod
	ASMAMD64.Mod PCAAMD64.Mod PCGAMD64.Mod	# AMD64 Backend
	OPA.Data
	Errors.XML cnErrors.XML	# Error messages

	WhitespaceRemover.Mod

	# Interface to host system clipboard
	HostClipboard.Mod
	WIN { Win32.Clipboard.Mod }

	Tar.Mod

	Zlib.Mod ZlibBuffers.Mod ZlibDeflate.Mod ZlibInflate.Mod 	# Zlib
	ZlibWriters.Mod ZlibReaders.Mod Zip.Mod ZipTool.Mod	# Zip FS prk

	BIT.Mod

	# Image codecs
	PNGDecoder.Mod BMPCodec.Mod GIFCodec.Mod
	JPEGDecoder.Mod

	# Animation codecs
	AnimationCodec.Mod

	NATIVE { # USB info tools & documentation
		UsbInfo.Mod UsbSkeleton.Mod UsbTools.Mod Usb.Text
	}

	# Partitions Framework
	PartitionsLib.Mod FATScavenger.Mod Partitions.Mod
	DiskTests.Mod DiskBenchmark.Mod
	config.txt # default config string settings
	PartitionEditorTable.Mod

	NATIVEORIG{ Profiler.Mod HierarchicalProfiler0.Mod } # Hierarchical profiler has GUI: WMProfiler.Mod
	WINORIG, WINGEN { Win32.HierarchicalProfiler0.Mod }
	NATIVEORIG, WINORIG, WINGEN { HierarchicalProfiler.Mod}

	FTPClient.Mod

	XYModem.Mod
	Shell.Mod Shell.Alias	# Stream-based shell
	ShellSerial.Mod	# Shell over serial port

	Installer.Mod InstallerPackages.XML

	CryptoBigNumbers.Mod CryptoBase64.Mod CryptoUtils.Mod CryptoCiphers.Mod CryptoARC4.Mod
	CryptoDES.Mod CryptoDES3.Mod 
	CryptoHashes.Mod CryptoMD5.Mod CryptoSHA1.Mod CryptoSHA256.Mod
	CryptoKeccakF1600.Mod CryptoKeccakSponge.Mod CryptoSHA3.Mod CryptoCSPRNG.Mod
	CryptoPrimes.Mod CryptoDSA.Mod CryptoDiffieHellman.Mod
	CryptoAES.Mod
	CryptoBlowfish.Mod
	CryptoTwofish.Mod
	CryptoCAST.Mod 
	CryptoHMAC.Mod CryptoIDEA.Mod
	CryptoRSA.Mod
	
	Checksum.Mod	# MD5, SHA1 and SHA3 checksum generator
END

PACKAGE Applications ARCHIVE "Applications.zip" SOURCE "ApplicationsSrc.zip" DESCRIPTION "Applications"

	Fido.Mod

	I386, WIN, UNIX { I386.CPUID.Mod }
	AMD64 { AMD64.CPUID.Mod }

	A2Sequencers.Mod

	PictImages.Mod

	V24Tracer.Mod	# Trace serialport

	XMLGeneratorSchema.Mod CSS2.Mod CSS2Scanner.Mod CSS2Parser.Mod 	# XML & CSS (swalther)

	RAWPrinter.Mod LPR.Mod	# Sending ps files to Printers

	ASN1.Mod  PKCS1.Mod  X509.Mod  TLS.Mod
	bluebottleselfsigned.der

	TCPServices.Mod  TestServer.Mod 	# TCP services
	TCPTools.Mod						# Some useful TCP-related commands

	NATIVEORIG { Performance.Mod }
	WIN, UNIX, NATIVECOOP { Win32.Performance.Mod } # This is just a dummy

	Bin2Hex.Mod BinToCode.Mod

	Base64.Mod

	DisplayGTF.Mod	# Create VESA 3.0 Init Strings

	GZip.Mod

	ShellCommands.Mod Telnet.Mod 	# Telnet Shell (currently broken)

	I386ORIG { I386.MemInfo.Mod }	# basic tools module
	AMD64ORIG { AMD64.MemInfo.Mod }
	I386,WIN { Info.Mod }

	TFClasses.Mod Mail.Mod SMTPClient.Mod
	TFLog.Mod WebHTTP.Mod 							# extended HTTP Server (tf/be)
	WebHTTPClient.Mod WebHTTPTools.Mod WebHTTPServer.Mod
	WebHTTPServerTools.Mod WebSSMPPlugin.Mod
	NATIVE,WIN { WebDefaultSSMP.Mod }
	WebHTTPServerStatistics.Mod

	NATIVE { WebWormWatch.Mod }

	POP3Client.Mod

	RFC865Client.Mod
	QuoteServer.Mod Quotes.txt 	# quote server (be)

	NATIVE {
		RfsConnection.Mod RfsClientProxy.Mod RfsFS.Mod 	# Rfs (pstuedi)
		TFTP.Mod TFTPServer.Mod TFTPFS.Mod 			 	# TFTP (be)
	}

	FTPFS.Mod
	NATIVE,WIN { WebFTPServer.Mod }	# FTP server (be)

	XModem.Mod

	SearchTools.Mod
	DiffLib.Mod
	TextConverter.Mod

	TaskScheduler.Mod

	NATIVE { # Open Sound Control
		OSC.Mod OSCRegistry.Mod OSCQueue.Mod
		OSCService.Mod OSCNet.Mod OSCEval.Mod OSCExample.Mod
	}

	FTP.Mod
	DES.Mod VNCServer.Mod

	# Audio codecs
	WAVCodec.Mod 	# WAV support
	MP3Decoder.Mod MP3Huffman.Bin  # MP3 Decoder

	# Video codecs
	I386, WIN, UNIX {
		I386.IDCT.Mod
		AVI.Mod DivXTypes.Mod I386.DivXHelper.Mod I386.DivXDecoder.Mod # DivX Support
		MPEGTables.Mod I386.MPEGUtilities.Mod MPEGVideoDecoder.Mod 	# MPEG1/2 Support
	}

	# Image codecs
	JPEG2000DecoderUtil.Mod JPEG2000DecoderCS.Mod JPEG2000Decoder.Mod

	MD5.Mod	# Temporarily moved here from gadgets
	HTTPSupport.Mod HTTPSession.Mod DynamicWebpage.Mod 	# Dynamic Webpages support
	DynamicWebpagePlugin.Mod PrevalenceSystem.Mod
	WMDropTarget.Mod
	GenericSort.Mod WebStd.Mod WebComplex.Mod

	WMCharCodes.Mod HTMLScanner.Mod HTMLParser.Mod gb2312.txt 	# Webbrowser
	NewHTTPClient.Mod

	UnihanParser.Mod  Radicals.txt	# Unicode tool

	CSV.Mod # support for comma separated value files
END

PACKAGE GuiApplicationsMini ARCHIVE "GuiApplicationsMini.zip" SOURCE "GuiApplicationsMiniSrc.zip" DESCRIPTION "Minimal GUI applications set"

# Window Manager (tf)

	ColorModels.Mod

	WMDefaultWindows.Mod

	WMDefaultFont.Mod WMFontManager.Mod WMOberonFonts.Mod WMCCGFonts.Mod WMBitmapFont.Mod	# Font support
	OpenTypeInt.Mod OpenTypeScan.Mod OpenType.Mod OpenTypeFonts.Mod  WMOTFonts.Mod	# OpenType Fonts

	cjkfont.bfnt # since used as fallback

	WindowManager.Mod
	UNIX { Unix.X11.Mod Unix.X11Api.Mod Unix.XDisplay.Mod Unix.Beep.Mod Unix.KbdMouse.Mod Unix.Clipboard.Mod }


	# Icons representing applications (don't put icons used by applications inside!)
	WMIcons.tar


	Attributes.Mod

	# Components
	WMStandardComponents.Mod
	WMProgressComponents.Mod
	WMShapes.Mod
	WMFigures.Mod
	WMScrollableComponents.Mod
	WMPieMenu.Mod
	WMPopups.Mod
	PositionDebugging.Mod
	SyntaxHighlighter.Mod SyntaxHighlighter.XML
	WMTextView.Mod WMInputMethods.Mod
	WMEditors.Mod 												# Editor
	WMSearchComponents.Mod
	WMMacros.Mod Macros.XML									# Editor extension
	WMGrids.Mod WMStringGrids.Mod 							# Grid components
	WMTrees.Mod WMMixer.Mod WMTabComponents.Mod
	WMColorComponents.Mod
	WMAnimations.Mod
	WMDropDownLists.Mod

	WMRestorable.Mod Release.Auto.dsk
	WMApplications.Mod

	WMDialogs.Mod
	WMDocumentEditor.Mod

	WMErrors.Mod
	WMOSD.Mod
	WMArchives.Mod
	WMCharMap.Mod
	WMUnicodeMarkerTool.Mod

	UNIX { Unix.DisplayRefresher.Mod }

	Standard.rep Models.rep Shapes.rep Colors.rep System.rep

# Programmer's Editing Tool
	ModuleParser.Mod
 	ModuleTrees.Mod ModuleTreesIcons.tar
	WMXMLTree.Mod

	WMDiagnostics.Mod

	PETTrees.Mod PETModuleTree.Mod PETXMLTree.Mod
	PET.Mod PETIcons.tar

# Input Method Editors
	WMArabicIME.Mod											# Arabic IME
	WMArmenianIME.Mod										# Armenian IME
	WMHebrewIME.Mod											# Hebrew IME
	WMPinyinIME.Mod PinyinIMETable.txt PinyinIMEPhrases.txt	# Pinyin IME
	WMRussianIME.Mod											# Russian IME
	WMUkrainianIME.Mod										# Ukrainian IME
	WMEthiopicIME.Mod
	WMUnicodeIME.Mod										# Unicode IME
	WMInputMethodTool.Mod

	WMUtilities.Mod WMTrapWriter.Mod							# Window Manager Utilities
	FoxA2Interface.Mod												# Compiler Debug Windows

	WMMenus.Mod 												# menu support
	WMDiagramComponents.Mod

	MainMenu.Mod	# menu system
	StartMenu.rep
	StartMenu.Mod
	MenuPage00.XML MenuPage10.XML MenuPage20.XML MenuPage30.XML
	MenuPage40.XML MenuPage50.XML MenuPage60.XML MenuPage70.XML
	MenuPage80.XML MenuPage90.XML

	HotKeys.Mod HotKeys.XML	# hot key support

	WMNavigate.Mod WMNavigator.Mod Navigation.rep	# Windows navigation
	WMDesktops.Mod

	Notepad.Mod
	WMSystemComponents.Mod icons.tar
	WMFileManager.Mod WMSearchTool.Mod
	WMFTPClient.Mod

	NATIVE { WMUsbInfo.Mod WMUsbInfo.tar	}

	# Skin support
	SkinLanguage.Mod FNHistories.Mod SkinEngine.Mod SkinConfig.XML

	ZeroSkin.zip # default skin



	# Trackers
	WMProcessInfo.Mod
	WMObjectTracker.Mod
	NATIVE { WMTCPTracker.Mod }
	WIN { Win32.WMTCPTracker.Mod }

	WMKernelLog.Mod  # GUI for KernelLogger.Mod
	WMEventLog.Mod	# GUI for Events.Mod

# Partitions Framework GUIs
	# Partition Tool
	WMPartitionsComponents.Mod WMPartitions.Mod
	# Partition Editor
	PartitionEditorComponents.Mod PartitionEditor.Mod

	MultiLogger.Mod

	I386, WIN, UNIX {
		MemoryReader.Mod Decoder.Mod I386Decoder.Mod	# GUI decoder
		ARMDecoder.Mod AMD64Decoder.Mod DecoderRes.zip
	}

	Tutorial.Text Quickstart.Text cn.PrgInOberon.txt	# documentation
	WMTextTool.Mod



# Performance monitor framework

	WMPerfMonPlugins.Mod
	WMPerfMonAlerts.Mod WMPerfMonAlertsUtils.Mod WMPerfMonAlerts.XML

	# perfmon kernel plugins
	NATIVEORIG, NATIVEGEN {
		WMPerfMonPluginCpu.Mod WMPerfMonPluginMemory.Mod
		WMPerfMonPluginInterrupts.Mod
		WMPerfMonPluginUsb.Mod WMPerfMonPluginNetStats.Mod
	}
	WIN { Win32.WMPerfMonPluginCpu.Mod Win32.WMPerfMonPluginMemory.Mod }
	UNIX { Unix.WMPerfMonPluginCpu.Mod Unix.WMPerfMonPluginMemory.Mod }

	NATIVE,WIN {
		WMPerfMonPluginModVars.Mod WMPerfMonPluginHeap.Mod
	}
	WMPerfMonPluginProcesses.Mod
	WMPerfMonPluginSerials.Mod	# perfmon device plugins
	WMPerfMonPluginNetwork.Mod WMPerfMonPluginDisks.Mod
	WMPerfMonPluginPerfMon.Mod 	# perfmon misc plugins
	WMPerfMonPluginEvents.Mod WMPerfMonPluginMessages.Mod

	WMPerfMonComponents.Mod	# GUI

	WMPerfMonTabSystem.Mod
	WMPerfMonTabAlerts.Mod
	UNCOOP { WMPerfMon.Mod WMPerfMon.Text }

	WMClock.Mod
	WMClockImages.tar
	WMCalendar.Mod

	WMV24Component.Mod
	WMShell.Mod	# GUI for Shell

	# GUI for hierarchical profiler (HierarchicalProfiler.Mod)
	NATIVEORIG, WINORIG, WINGEN { WMProfiler.Mod }

	# ssh
	SSH.Tool
	SSH.Configuration.Text
	SSHGlobals.Mod SSHKeys.Mod SSHTransport.Mod SSHAuthorize.Mod
	SSH.Mod SSHClient.Mod
END

PACKAGE GuiApplications ARCHIVE "GuiApplications.zip" SOURCE "GuiApplicationsSrc.zip" DESCRIPTION "Window Manager and Graphical Applications"

	#TFPET
	TFPET.Tool
	code.css
	highlight.js
	TFStringPool.Mod
	BimboScanner.Mod
	TFTypeSys.Mod
	TFDumpTS.Mod
	TFScopeTools.Mod
	TFCheck.Mod
	TFAOParser.Mod
	TFModuleTrees.Mod
	TFPET.Mod
	TFClasses.Mod
	TFDocGenerator.Mod
	TFXRef.Mod

	CharacterLineup.Mod

	WMDesktopIcons.Mod	# Programmable desktop icons
	WMTextStyleTool.Mod

	WMVNCView.Mod VNC.Mod	# VNC

	WMVT100.Mod	# Telnet VT100 Client

	# Skins
	BluePlastic.skin
	reptile.skin pklook.skin redlook.skin traditional.skin
	winxp.skin aqua.skin xmas.skin glass.skin stijn.skin stijnbw.skin

	SkinEditor.Mod SkinTutorial.Text

	Looks.Mod WMSkinLoader.Mod WMBackdropLoader.Mod
	SkinList.XML BackdropList.XML

	WMInspectionComponents.Mod WMInspector.Mod WMInspector.tar
	WMRepositories.Mod WMRepositories.tar
	WMBuilder.Mod WMBuilder.tar
	WMBuilderTransformer.Mod
	TemplateMultiInstanceBase.txt TemplateMultiInstance.txt

	CyberbitNetInstall.Mod

	WMDiff.Mod	# diff tool

	# GUI for TaskScheduler.Mod
	WMTaskScheduler.Mod WMTaskScheduler.tar

	IMAPUtilities.Mod IMAP.Mod IMAPClient.Mod RMSMTP.Mod	# IMAP/SMTP client
	IMAPGUI.Mod IMAPIcons.tar

	# Some additional plugins for the performance monitor
	NATIVE,WIN { WMPerfMonPluginFTPServer.Mod }
	WMPerfMonPluginHTTPServer.Mod
	WMPerfMonPluginQuoteServer.Mod WMPerfMonPluginVNCServer.Mod
	WMPerfMonPluginExample.Mod	# perfmon misc plugins

	WMModuleState.Mod
	WMKeyCode.Mod	# Misc
	WMPicView.Mod
	ComponentViewer.Mod

	WMScreenShot.Mod
	WMBackdrop.Mod mars.png BluebottlePic0.png 	# Backdrop

	# Installer
	WMInstaller.Mod WMInstaller.tar

	NATIVE { # CD recorder
		CDRecordUtils.Mod CDRecordLib.Mod MakeIsoImages.Mod
		CDRecord.Mod WMCDRecorder.Mod
	}

	HotKeysCommands.Mod

	I386, WIN, UNIX { I386.VMWareTools.Mod }		# VMWare
	SynergyClient.Mod			# Synergy

	NATIVE {
 		TVChannels.Mod  	# TV
		TVChannels.XML
		TeletextDecoder.Mod
		TV.Mod
		TeletextFont.Mod teletext.bfnt TeletextBrowser.Mod TeletextViewer.Mod
		next.png prev.png refresh.png
		TVRemoteControl.Mod TV.Tool
	}

	I386, WIN, UNIX { I386.WMTransitions.Mod }
	AMD64 { AMD64.WMTransitions.Mod }
	MediaPlayer.Mod Presentation.Mod
	MP3Player.Mod WMPlayer.Mod
	WAVRecorder.Mod
	OGGUtilities.Mod OGGVorbisPlayer.Mod OGGRadios.Text WMOGGPlayer.Mod	# OGG Player/Radio

	# DTP editor
	DTPData.Mod DTPUtilities.Mod DTPView.Mod DTPEditor.Mod DTPText.Mod
	DTPRect.Mod
	DTPImage.Mod

	GfxMatrix.Mod GfxImages.Mod GfxPaths.Mod GfxRegions.Mod 	# Gfx (eos)
	GfxFonts.Mod Gfx.Mod GfxRaster.Mod GfxBuffer.Mod
	WMGraphicsGfx.Mod

	CSS2Properties.Mod XMLComponents.Mod XMLStyle.Mod XMLLoader.Mod

	SVGUtilities.Mod SVGColors.Mod SVGMatrix.Mod SVG.Mod SVGGradients.Mod
	SVGFilters.Mod SVGRenderer.Mod SVGLoader.Mod SVGDecoder.Mod	# SVG support

	WebBrowserComponents.Mod
	XMLTransformer.Mod HTMLTransformer.Mod  WebBrowserPanel.Mod WebBrowser.Mod

	MailStorage.Mod BimboMail.Mod

	DebugLog.Mod	# Multiprocess Log

	WMJoysticks.Mod # Joystick tools
END

PACKAGE Fun ARCHIVE "Fun.zip" SOURCE "FunSrc.zip" DESCRIPTION "Games, Demos and other fun stuff"

	# games
	WMTetris.Mod
	VNCTetrisServer.Mod
	Bimso.Mod

	# Demos
	WMScribble.Mod 
	#WMGraphicsDemo.Mod 
	SortDemo.Mod
	Demos.rep
	FractalDemo.Mod
	WMBunny.Mod WMBunnyImages.tar
	TuringCoatWnd.Mod

	# 3D menu
	W3dVectors.Mod W3dMatrix.Mod W3dGeometry.Mod W3dAbstractWorld.Mod
	W3dObjectGenerator.Mod W3dRasterizer.Mod W3dWorld.Mod W3dExplorer.Mod
	W3dMenu.Mod W3dMenu.XML
	W3dMenuIcons.tar
	CATServer.Mod
	W3dClusterWatch.Mod W3dClusterWatchIcons.tar Cluster.XML  # 3D Cluster monitor tool

	# Slide show
	WMSlideshow.Mod RetoWMSlideshow.XML SlideShowData.tar

	# Example data
	stucki01.svg stucki02.svg
	Clouds.jp2 Evening.jp2 Rainbow.jp2
	flags.avi
	ComponentStyle.XML ElevatorStyle.XML # example component styles, load with WMComponents.LoadStyle

	# DTP Editor examples
	Demo.Style.XML Demo.Layout.XML Demo.Content.XML

	# Xmas
	xmas04.tar Snow.Mod SaasFee.jpg present.tar MenuEdit.Mod
	PresentViewer.Mod XmasMenu.XML

END

PACKAGE Testing ARCHIVE "Testing.zip" SOURCE "TestingSrc.zip" DESCRIPTION "Tests and benchmarks"

	# Compiler Testsuite
	TestSuite.Mod  PCTest.Mod Versioning.Mod FoxTest.Mod

	Oberon.Compilation.Test Oberon.Execution.Test
	MathArrays.Compilation.Test MathArrays.Execution.Test

	# Files.Mod testing
	TestFiles.Mod Files.Test

	CSV.Test

	NATIVEORIG, NATIVEGEN {
		TestLocks.Mod
		BenchSpeedup.Mod BenchObjCount.Mod
		BenchClockDrift.Mod BenchNew.Mod BenchLocks.Mod
		BenchPingPong.Mod
		BluetoothTest.Mod
	}

	I386ORIG, I386GEN { I386.BenchInterrupts.Mod }
	AMD64 { AMD64.BenchInterrupts.Mod }

	BenchTCP.Mod

	TestDates.Mod # Dates.Mod
	TestStrings.Mod # Strings.Mod

	BenchXML.Mod
	BenchSyntaxHighlighter.Mod

	testutf8.txt 	# utf8 sample file

	# Crypto framework tests
	CryptoTestBigNumbers.Mod CryptoTestCiphers.Mod
	CryptoTestDH.Mod CryptoTestDSA.Mod CryptoTestHMAC.Mod CryptoTestHashes.Mod
	CryptoTestRSA.Mod

	# Device Driver tests
	BeepTest.Mod
	JoysticksTest.Mod

	# Component framework
	TestMenu.Mod Menu.XML # Test WMMenu.Mod
	PieTest.Mod # Test WMPieMneu.Mod
	TestTrees.Mod # Test WMTrees.Mod
	TestComponentDragDrop.Mod
	ComponentInfo.Mod
	TestComponents.Mod
	TestXMLPlugins.Mod
END

PACKAGE Education ARCHIVE "Education.zip" SOURCE "EducationSrc.zip" DESCRIPTION "Examples and Programs For Education Purposes"
	NATIVE,WIN { SSFS.Mod } # Simple Silly File System
	HelloWorld.Mod HelloWorld1.Mod HelloWorld2.Mod HelloWorld3.Mod
	# examples
	Example1.Mod Example2.Mod Example3.Mod
	Example4.Mod Example5.Mod Example6.Mod Example7.Mod
	Example8.Mod
	ExampleTextWriter.Mod

	GUIPat.txt GUIPat.tar	# GUI patterns

	JavaLocks.Mod

	# Dynamic Webpage examples
	WebAccounts.Mod WebForum.Mod ExerciseGroups.Mod	# Active Elements Examples
	DynamicWebpagePlugin.Text accounts.dxp rotator.dxp test0.dxp 	# Dynamic Pages Examples
	test1.dxp test2.dxp test3.dxp
	test4.dxp tutorial1.dxp
	tutorial2.dxp tutorial3.dxp tutorial4.dxp tutorial5.dxp tutorial6.dxp

	public.form.html public.info.ssmp public.System.ssmp public.ActiveObjects.ssmp 	# sample extended website
	public.Memory.ssmp public.WebServer.ssmp
END

PACKAGE Build ARCHIVE "Build.zip" SOURCE "BuildSrc.zip"  DESCRIPTION "Build Tools"
	Build.Tool Build.VMWare.Tool
	WIN { Win32.Build.Tool Win32.BuildMini.Tool }
	AosInst.Tool Aos.Par			# Install tool
	IsoImages.Mod
	ReleaseThreadPool.Mod Release.Mod Release.Tool 	# Build release tool
	PETReleaseTree.Mod
	Linker0.Mod Linker1.Mod Linker.Mod
	WIN { Win32.Aos.Link }
	UNIX { 
		Unix.BootLinkerHeaps.Mod Unix.BootLinkerModules.Mod Unix.BootLinkerLoader.Mod  
		Unix.BootLinker.Mod UnixAos.Tool
	}
	OBEMBR4.ASM BootManager.Asm OBL.Asm  # Asm
	BootManager.Mod BootManager.Tool # Splits up BootManager.Bin into BootManagerMBR.Bin and BootManagerTail.Bin
END

PACKAGE EFI ARCHIVE "EFI.zip" SOURCE "EFISrc.zip" DESCRIPTION "EFI Boot Loader and API"
	EFI.Tool EFI.Mod
	I386, WIN, UNIX {I386.EFIMachine.Mod}
	AMD64 { AMD64.EFIMachine.Mod }


	EFIBlockIO.Mod EFIDiskIO.Mod
	EFIFileProtocol.Mod EFISimpleFS.Mod
	EFILoadedImage.Mod EFIGraphicsOutput.Mod EFITrace.Mod

	EFILib.Mod

	EFITest.Mod EFIGraphicalConsole.Mod EFIA2Loader.Mod
END

PACKAGE Contributions ARCHIVE "Contributions.zip" SOURCE "ContributionsSrc.zip"  DESCRIPTION "Contributions"
	# Alan D. Freed (AlFreed@ohio.net) and Felix Friedrich (friedrich@gsf.de)
	# CAPO - Computational Analysis Platform for Oberon
	# BSD - License ok to use in release files
	Capo.Text Capo.Tool Capo.Ascii.Text

	Sage.UDPChat.Text Sage.UDPChatBase.Mod Sage.UDPChatServer.Mod 	# UDP chat tool (Yaroslav Romanchenko)
	Sage.UDPChatClient.Mod

	CyrillicUtilities.Mod # by sage

	YMF754Util.Mod	# Utilitiy for creating YMF754.Bin for YMF754.Mod sound card driver

	# SMB client & server
	SambaClient.Mod SambaServer.Mod

	srRenderTools.Text  srReadMe.Text 	# Realtime Fractal-Voxel Raytracer (Soren Renner)
	srBase.Mod srRayEngine.Mod srMath.Mod I386.srE.Mod srGL.Mod srHex.Mod srImage.Mod
	srVoxel.Mod srVoxel2.Mod srVoxel3.Mod srVolShader.Mod srVoxel4.Mod srVoxel5.Mod
	srM2Space.Mod srM3Space.Mod srM5Space.Mod srM6Space.Mod srRastermovie.Mod
	srTexVox.Mod srThermoCell.Mod srTree.Mod sr3DTexture.Mod srLifeVox.Mod
	srRotaVox.Mod srvoxels.Mod srRender.Mod
	recticle.png

	MenuPages.Mod # generate MenuPageXX.XML files

	# Video for Windows
	WIN { Win32.VfW.Mod RasterPixelFormats.Mod VideoExample.Mod TestVideo.Mod}

	WMOverlay.Mod WMOverlay.tar
	
	# Oberon pretty printing
	PrettyPrint.Mod  PrettyPrintHighlighter.XML
	
	# streams and files compression
	Huffman.mod

	NbrInt8.Mod NbrInt16.Mod NbrInt32.Mod I386.NbrInt64.Mod NbrInt.Mod NbrRat.Mod
	I386.NbrRe32.Mod I386.NbrRe64.Mod NbrRe.Mod NbrCplx.Mod NbrStrings.Mod

	NATIVE,WIN {
		DataErrors.Mod DataIO.Mod Data.Mod DataStacks.Mod DataQueues.Mod
		DataLists.Mod DataTrees.Mod

		MathInt.Mod MathRat.Mod MathReSeries.Mod MathRe.Mod MathCplxSeries.Mod
		MathCplx.Mod MathCbrt.Mod MathErf.Mod MathGamma.Mod

		CalcFn.Mod CalcD1.Mod CalcD2.Mod CalcD3.Mod CalcD4.Mod CalcGauss.Mod
		MathMitLef.Mod CalcConvolution.Mod CalcGrunwald.Mod CalcDiethelm.Mod

		# Disable index checking for these modules with \sx for efficiency
		I386.Array1dBytes.Mod Array1dInt.Mod Array1dRat.Mod Array1dRe.Mod Array1dCplx.Mod I386.ArrayXdBytes.Mod
		ArrayXdInt.Mod ArrayXdRat.Mod ArrayXdRe.Mod ArrayXdCplx.Mod Array2dInt.Mod Array2dRat.Mod
		Array2dRe.Mod Array2dCplx.Mod

		VecInt.Mod VecRat.Mod VecRe.Mod VecCplx.Mod

		MtxInt.Mod MtxRat.Mod MtxRe.Mod MtxCplx.Mod

		CubeInt.Mod CubeRat.Mod CubeRe.Mod CubeCplx.Mod

		LinEqRe.Mod LinEqLU.Mod LinEqCholesky.Mod LinEqSVD.Mod
		HCubeInt.Mod HCubeRat.Mod HCubeRe.Mod HCubeCplx.Mod
		DataTemplate.Mod.Text MathRandomSeed.dat
	}

	# Testsuite
	CapoTest1.2.zip	# requires Oberon

	WPM.Mod # Web page maker

	# Aubrey McIntosh (aubrey.macintosh@alumni.utexas.net)
	# BSD - License ok to use in release files
	 AlmSmtpReceiver.Atg AlmSmtpReceiver.Tool AlmSmtpReceiver.Mod 	# SMTP receiver
	 AlmSmtpReceiver.Guide.Text

	# Thomas Frey (tfrey@enigon.net)
	# BSD - License ok to use in release files
	NATIVE { TFSMTPServer.Mod TFSMTPServer.Text Rename.TFMailConfig.XML }	# SMTP Mail forwarder
	WMFontCCGConverter.Mod
	WebCGI.Mod RegisterRFW.Mod WebBimbodot.Mod TFWebForum.Mod	# CGI support and examples
	PDF.Mod AFM.Mod PDFExample.Mod	# PDF Writer

	Visualizer.Mod # generate class diagrams
	ReleaseVisualizerScanner.Mod ReleaseVisualizer.Mod # generate PDF poster of all modules

	# ObeDAV - WebDAV and DeltaV for Oberon, Edgar Schwarz, edited by Robin Stoll. OdSVN.Mod also required
	# Subversion Client by Robin Stoll (rstoll@student.ethz.ch)
	OdUtil.Mod OdXml.Mod OdCond.Mod
	OdAuthBase.Mod OdAuth.Mod
	OdClient.Mod
	# OdClientTools.Mod
	OdVCSBase.Mod
	# OdDeltavBase.Mod
	OdSvn.Tool
	# OdPlugin.Mod

	SVN.Text
	SVNArgument.Mod
	SVNOutput.Mod
	SVNUtil.Mod
	NATIVE { SVNAdmin.Mod }
	WIN { Win32.SVNAdmin.Mod }
	NATIVE, WIN {
		OdSvn.Mod
		SVNWebDAV.Mod
		SVN.Mod
	}

	# GPL!
	NATIVE { UsbRS232.Mod GPL.Text }

	NATIVE { FirewireLowUtil.Mod FirewireLow.Mod FirewireSBP2.Mod }	# IEEE 1394 support (HD)

	TeletextServer.zip	# Teletext Server for TV
END

PACKAGE Oberon ARCHIVE "Oberon.zip" SOURCE "OberonSrc.zip"  DESCRIPTION "Oberon for A2"
	# emulation modules
	NATIVE,UNIX { Oberon.Kernel.Mod }
	NATIVE,WIN { Oberon.Types.Mod }
	WIN { Win32.Oberon.Kernel.Mod }
	Oberon.Modules.Mod
	NATIVE,UNIX { Oberon.FileDir.Mod Oberon.Files.Mod }
	WIN { Win32.Oberon.FileDir.Mod Win32.Oberon.Files.Mod }

	Oberon.Disks.Mod

	Oberon.Objects.Mod
	OberonInput.Mod 	# WM-less Oberon I/O

	NATIVE,iWIN, UNIX { OberonDisplay.Mod }
	NATIVE,iWIN, UNIX { Oberon.Display.Mod }
	NATIVE,iWIN, UNIX {
		Oberon.Input.Mod 	# WM-based Display & Input
		Oberon.Viewers.Mod Oberon.Fonts.Mod
	}
	
	NATIVE,iWIN, UNIX {Oberon.Mod}
	
	eWIN {
	Win32.Oberon.Mod
	Win32.Threads.Mod
	Win32.Oberon.Displays.Mod Win32.Oberon.Display.Mod Win32.Oberon.Viewers.Mod
	Win32.Oberon.Input.Mod Win32.Oberon.Fonts.Mod Win32.Oberon.Windows.Mod
	}

	Oberon.Texts.Mod

	WIN { Win32.OberonConfiguration.Mod }

	NATIVE,iWIN,UNIX  { Oberon.Oberon.Mod }
	eWIN { Win32.Oberon.WinFonts.Mod Win32.Oberon.Oberon.Mod }

	Oberon.MenuViewers.Mod Oberon.TextFrames.Mod

	NATIVE,iWIN,UNIX  { Oberon.System.Mod }

	Oberon.In.Mod Oberon.Out.Mod Oberon.Dates.Mod Oberon.Strings.Mod 	# Utility modules

	NATIVE, iWIN { Oberon.Centronics.Mod }

	NATIVE,iWIN,UNIX { I386.Oberon.Bitmaps.Mod Oberon.Pictures.Mod }

	Oberon.RandomNumbers.Mod

	Oberon.V24.Mod
	NATIVE { Oberon.Printer.Mod }
	UNIX { Unix.Oberon.Printer.Mod }
	eWIN  { Win32.Oberon.Bitmaps.Mod Win32.Oberon.Pictures.Mod }
	WIN { Win32.Oberon.Printer.Mod Win32.ADVAPI32.Mod }
	eWIN { Win32.Oberon.System.Mod Win32.OberonDisplay.Mod }

	Compiler.Tool Oberon.OPM.Mod Oberon.OPS.Mod Oberon.OPT.Mod Oberon.OPB.Mod Oberon.OPA.Mod Oberon.OPP.Mod 	# Compiler (prk)
	Oberon.OPO.Mod Oberon.OPL.Mod Oberon.OPC.Mod Oberon.OPV.Mod Oberon.Compiler.Mod Oberon.OPAData.Mod OPA.Data

	Edit.Tool Oberon.Edit.Mod 	# Edit
	Script.Tool Oberon.Styles.Mod Oberon.ScriptFrames.Mod Oberon.Script.Mod 	# Script

	NATIVEORIG, NATIVEGEN {
	Oberon.Diskettes.Mod 	# Diskette driver
	Backup.Tool Oberon.Diskette.Mod Oberon.Backup.Mod 	# Backup
	}

	Partitions.Tool  Oberon.Partitions.Mod 	# Partition

	NATIVE, iWIN { Oberon.Miscellaneous.Mod } 	# Miscellaneous
	Miscellaneous.Tool

	Oberon.Browser.Mod 	# Browser (Compiler.Tool)
 	DOS.Tool Oberon.FATFiles.Mod Oberon.DOS.Mod	# DOS
	Oberon.Hello.Mod	# Demo program (UserGuide.Text)

	NATIVE,UNIX { Oberon.PSPrinter.Mod PSHeader.Text Oberon.HPLaserPrinter.Mod Oberon.HPPCL.Mod }	# Printer drivers
	WIN { Win32.Oberon.PSPrinter.Mod }
	UNIX { Unix.Oberon.UnixPrinter.Mod }

	Default.Pal Light.Pal Dark.Pal White.Pal Black.Pal	# Palettes

	System.Text UserGuide.Text Feedback.Text Release.Oberon.Text 	# Texts
	System.Tool LoadGadgets.Text 	# Tools

	# Configuration
	Configuration.Tool
	WIN { Win32.Oberon.Registry.Mod }
	eWIN { Win32.Oberon.Configuration.Mod }
	NATIVE,iWIN { Oberon.Configuration.Mod  }

# Basic Tools.  NetSystem, Telnet, TextMail, ET, developer's tools, OpenType.
	Tools.Tool

	# NetSystem TCP/IP
	Release.NetSystem.Tool

	NATIVE { Oberon.NetSystem.Mod }
	WIN { Win32.Oberon.NetSystem.Mod }
	UNIX { Unix.Oberon.NetSystem.Mod }

	Oberon.HelloServer.Mod

	Oberon.Terminals.Mod Oberon.TerminalFrames.Mod Oberon.Telnet.Mod 	# Telnet
	Oberon.TextMail.Mod 	# TextMail
	Oberon.FTP.Mod 	# FTP

	IFS.Tool Oberon.XYplane.Mod Oberon.IFS.Mod 	# IFS

	Greek.Tool Math.Tool 	# Greek & Math fonts

		# Developer tools
	ET.Tool Oberon.ET.Mod Oberon.Menu.Mod ET.Popup.Menu 	# ET and Menu

	Oberon.Decoder.Mod 	# Decode .Obj & .Sym files
	Oberon.V24Log.Mod Oberon.SysLog.Mod 	# V24 log and SysLog
	OFS.Tool 	# OFS tool module

	Oberon.ZlibWriters.Mod Oberon.ZlibReaders.Mod 	# Zip tool
	Oberon.Zip.Mod Zip.Tool Oberon.ZipTool.Mod
	GZip.Tool Oberon.GZWriters.Mod Oberon.GZReaders.Mod Oberon.GZip.Mod 	# GZip tool
	Oberon.TGZ.Mod 	# .tgz unpacker
	NATIVE { Oberon.PCITools.Mod } 	# PCI scanner

# ARM decoder
	Oberon.PCARMDecoder.Mod
# Additional things
	Oberon.Aos.Mod Oberon.OFSTools.Mod Oberon.CleanupFiles.Mod 	# Aos-specific tools
	NATIVE { Oberon.TestNet.Mod }
	AosTools.Tool

	NATIVE { Oberon.TFTPTool.Mod }

	GUI.Text
	Oberon.FATTools.Mod FAT.Tool
END

PACKAGE OberonGadgets ARCHIVE "OberonGadgets.zip" SOURCE "OberonGadgetsSrc.zip"  DESCRIPTION "Oberon Gadgets Framework"

	Colors.Tool

	NATIVE,iWIN,UNIX {
		Oberon.Colors.Mod 	# Color models
		Oberon.Display3.Mod Oberon.Effects.Mod
	}

	eWIN {
		Win32.Oberon.Colors.Mod
		Win32.Oberon.Display3.Mod Win32.Oberon.Effects.Mod
	}

	Oberon.Printer3.Mod Oberon.Attributes.Mod Oberon.Links.Mod

	NATIVE,iWIN,UNIX { Oberon.Gadgets.Mod }
	eWIN { Win32.Oberon.Gadgets.Mod }

	WIN { Win32.Oberon.PrinterInfo.Mod }

	Oberon.BasicGadgets.Mod Oberon.TextFields.Mod Oberon.ListRiders.Mod Oberon.ListModels.Mod Oberon.ListDags.Mod 	# Gadget catalog in Gadgets.Panel
	Oberon.ListGadgets.Mod

	Oberon.Lists.Mod
	Oberon.Panels.Mod


	NATIVE,WIN { Oberon.TextGadgets0.Mod Oberon.TextGadgets.Mod }
	UNIX { Unix.Oberon.TextGadgets0.Mod Unix.Oberon.TextGadgets.Mod }

	Oberon.BasicFigures.Mod

	NATIVE,WIN { Oberon.Scrollbars.Mod }
	UNIX { Unix.Oberon.Scrollbars.Mod Unix.Oberon.TextSBControl.Mod }

	NATIVE,UNIX { Oberon.Directories.Mod }
	WIN { Win32.Oberon.Directories.Mod }

	Oberon.Clocks.Mod Oberon.Organizers.Mod
	Oberon.Complex.Mod Oberon.SetGadgets.Mod Oberon.TimeStamps.Mod Oberon.Gages.Mod Oberon.AudioGadgets.Mod
	Oberon.ProgressMeters.Mod Oberon.Sisiphus.Mod Sisyphus.Data
	Oberon.Documents.Mod Oberon.Views.Mod

	NATIVE,iWIN,UNIX { Oberon.Desktops.Mod }
	eWIN { Win32.Oberon.Desktops.Mod }

	NATIVE,WIN { Oberon.TextDocs.Mod }
	UNIX { Unix.Oberon.TextDocs.Mod }

	TextDocs.Lib Oberon.PanelDocs.Mod 	# Document catalog
	Oberon.Icons.Mod Oberon.ColorTools.Mod Oberon.NamePlates.Mod Oberon.Navigators.Mod Oberon.NoteBooks.Mod

	NATIVE,iWIN,UNIX { Oberon.Finder.Mod }
	eWIN { Win32.Oberon.Finder.Mod }

	Oberon.GadgetsIn.Mod Oberon.GadgetsOut.Mod

	eWIN { Win32.Oberon.Miscellaneous.Mod Win32.COMDLG32.Mod Win32.Oberon.WinMenus.Mod Win32.Oberon.WinPrinter.Mod }

	Libraries.Panel Oberon.ScrollViews.Mod Oberon.RefGadgets.Mod Oberon.Columbus.Mod Columbus.Lib 	# Columbus in Popups.Tool
	ObjExplorer.Panel Oberon.ObjExplorer.Mod 	# ObjExplorer in Popups.Tool
	Compress.Tool Oberon.Compress.Mod Oberon.CompressCrypt.Mod 	# Compress in Popups.Tool
	AsciiCoder.Tool Oberon.AsciiCoder.Mod 	# AsciiCoder in Popups.Tool
	Decoders.Tool Oberon.Base64.Mod Oberon.UUDecoder.Mod Oberon.BinHex.Mod Oberon.Rot13.Mod 	# Decoders in Popups.Tool
	Oberon.Tar.Mod Oberon.QuotedPrintable.Mod
	Builder.Tool Oberon.Builder.Mod 	# Builder in Popups.Tool
	Watson.Panel Definitions.Tool Oberon.Watson0.Mod Oberon.Watson.Mod Watson.Lib 	# Watson in Popups.Tool
	EditTools.Tool Oberon.EditTools.Mod 	# EditTools in Popups.Tool
	Outlines.Tool Oberon.Outlines.Mod 	# Outlines in Popups.Tool
	Oberon.OFormatterIO.Mod Oberon.OFormatter.Mod
	Oberon.StyleGadgets.Mod Oberon.ScriptGadgets.Mod
	Rembrandt.Panel Oberon.Rembrandt0.Mod

	NATIVE,iWIN,UNIX { Oberon.Rembrandt.Mod }
	eWIN { Win32.Oberon.Rembrandt.Mod }

	Oberon.RembrandtDocs.Mod 	# Rembrandt in Popups.Tool
	Oberon.RembrandtTools.Mod Rembrandt.Lib Clown.Pict Grapes.Pict
	Gadgets.Pict Default.Pict 	# Default.Pict used in Scramble

	PC.Tool Oberon.ErrorGadgets.Mod Oberon.PC.Mod 	# Oberon Interface for PACO

	WIN { Win32.PELinker.Mod PELinker.Tool }

	iWIN { Win32.Oberon.Clipboard.Mod }
	eWIN { Win32.External.Oberon.Clipboard.Mod Win32.Oberon.RegistryTools.Mod }
	WIN { Win32.Oberon.FontRes.Mod FontRes.Tool }
	UNIX { Unix.Oberon.Clipboard.Mod }
	WIN,UNIX { Clipboard.Tool }

	Oberon.JPEG.Mod Oberon.GIF.Mod Oberon.XBM.Mod Oberon.BMP.Mod Oberon.ICO.Mod Oberon.PCX.Mod Oberon.TGA.Mod Oberon.IFF.Mod 	# Picture converters
	Oberon.ColorModels.Mod Oberon.XPM.Mod Oberon.PPM.Mod Oberon.PSD.Mod

	Images.Tool Oberon.Images.Mod

	NATIVE,iWIN,UNIX { Oberon.ImageGadgets.Mod }
	eWIN { Win32.Oberon.WinImages.Mod Win32.Oberon.ImageGadgets.Mod }

	Oberon.ImageDocs.Mod 	# Images

	Oberon.PictImages.Mod Oberon.BMPImages.Mod Oberon.JPEGImages.Mod Oberon.GIFImages.Mod Oberon.PSDImages.Mod
	Colors.Panel

	NATIVE, iWIN,UNIX { Oberon.ColorGadgets.Mod }
	eWIN { Win32.Oberon.ColorGadgets.Mod }

	Oberon.PCXImages.Mod	# Color views
	Oberon.ColorWells.Mod 	# Leonardo legacy

	System3.Tool Applications.Tool Documentation.Tool Release.Popups.Tool Programming.Tool Editing.Tool	# Hypertools in Popups.Tool
	Desktops.Tool Gadgets.Tool 	# in Popups.Tool
	Printers.Tool

	Gadgets.Panel Documents.Panel TextDocs.Panel 	# Panels in Popups.Tool

	Oberon.Desk  	# in Popups.Tool
	Backdrop.Pict 	# in Popups.Tool
	TextDocs.Tool 	# in Popups.Tool
	Icons.Lib Symbols.Lib 	# Symbols.Lib used in DirectoryView

# Gadgets Networking
	Network.Tool NetDocs.Lib

	Oberon.Streams.Mod Oberon.TextStreams.Mod Oberon.BTrees.Mod Oberon.MIME.Mod Oberon.HyperDocs.Mod 	# Utility modules
	Oberon.NetTools.Mod Oberon.PasswordFields.Mod

	HyperDocs.Tool HyperDocs.Panel HyperLinks.Panel Oberon.HyperDocTools.Mod 	# HyperDocs
	Mail.Tool Mail.Panel # MD5.Mod
	Oberon.Mail.Mod 	# Mail
	FTP.Tool Oberon.FTPDocs.Mod 	# FTP
	Finger.Tool Oberon.Finger.Mod 	# Finger
	News.Tool Oberon.News.Mod 	# News
	Gopher.Tool Oberon.Gopher.Mod 	# Gopher
	Telnet.Panel Oberon.TerminalGadgets.Mod Oberon.TelnetGadgets.Mod Telnet.Tool	# Telnet

	HTTP.Tool Oberon.HTTPDocs0.Mod Oberon.HTMLDocs.Mod Oberon.HTTPDocs.Mod Authorization.html 	# HTTP/HTML
	Oberon.HTMLForms.Mod Oberon.HTMLImages.Mod Oberon.HTMLTables.Mod

	Oberon.ZipDocs.Mod 	# .zip reader

	Oberon.Packages.Mod Oberon.PlugIns.Mod Oberon.HTMLPlugIns.Mod 	# Packages

	WIN { Win32.Oberon.PlugInDocs.Mod }

	NATIVEORIG, NATIVEGEN {
	Oberon.Profiler.Mod 	# alternative profiler (prk)
	Oberon.FATDocs.Mod 	# FAT browser (be)
	}
END

# Additional/contributed Gadgets applications.
PACKAGE OberonApplications ARCHIVE "OberonApplications.zip" SOURCE "OberonApplicationsSrc.zip" DESCRIPTION "Oberon Applications"

	Oberon.Copyright.Mod Copyright.Text 	# Add/remove copyright
	Oberon.FileDisks.Mod

# Gadgets Applications

	Oberon.OTInt.Mod Oberon.OTScan.Mod Oberon.OType.Mod Oberon.OTFonts.Mod OType.Text 	# OpenType

	Gfx.Tool Oberon.GfxMatrix.Mod Oberon.GfxImages.Mod Oberon.GfxPaths.Mod Oberon.GfxRegions.Mod 	# Gfx library
	Oberon.GfxFonts0.Mod
	Oberon.GfxFonts.Mod Oberon.Gfx.Mod Oberon.GfxRaster.Mod Oberon.GfxPrinter.Mod
	Oberon.GfxBuffer.Mod Oberon.GfxDisplay.Mod Oberon.GfxPS.Mod Oberon.GfxOType.Mod
	Oberon.GfxPKFonts.Mod
	GfxProlog.ps
	GfxHowto.html GfxOverview.html Oberon.GfxTest.Mod Oberon.GfxDemo.Mod 	# Gfx documentation

	Leonardo.Panel Leonardo.Lib LeoConfig.Text Leonardo.Fig 	# Leonardo in Popups.Tool
	Oberon.Leonardo.Mod Oberon.LeoFrames.Mod Oberon.LeoTools.Mod Oberon.LeoDocs.Mod
	Oberon.LeoPanels.Mod Oberon.LeoLists.Mod Oberon.LeoPens.Mod Oberon.LeoOutliners.Mod
	Oberon.LeoPenEditors.Mod Oberon.LeoPaths.Mod Oberon.LeoPathEditors.Mod
	Oberon.LeoSplines.Mod Oberon.LeoSplineEditors.Mod Oberon.LeoCaptions.Mod
	Oberon.LeoCaptionEditors.Mod Oberon.LeoBasic.Mod Oberon.LeoBasicEditors.Mod
	Oberon.LeoImages.Mod Oberon.LeoImageEditors.Mod Oberon.LeoDraw.Mod
	Leonardo.Text 	# Leonardo documentation

	Oberon.Scheme.Mod Oberon.SchemeOps.Mod Oberon.Vinci.Mod Oberon.VinciGadgets.Mod 	# Vinci
	Oberon.VinciDocs.Mod Oberon.VinciShapes.Mod Oberon.VinciPens.Mod Oberon.VinciEditors.Mod
	Scheme.Init Vinci.Init
	Clip.Vinci Labels.Vinci Smiley.Vinci Stars.Vinci Test.Vinci Test1.Vinci Test2.Vinci
	Rect2.Shape NGon.Shape Distance.Shape CoordSys.Shape YinYang.Shape
	Vinci.Text 	# Vinci documentation

	TextPopups.Tool Oberon.TextPopups.Mod TextPopups.Text 	# TextPopups in Applications.Tool
	V24.Panel Oberon.V24Gadgets.Mod	# V24Gadgets in Applications.Tool
	Hex.Tool Oberon.Hex.Mod 	# Binary file editor in Applications.Tool
	HPCalc.Panel Oberon.Conversions.Mod Oberon.HPCalc.Mod 	# HPCalc in Applications.Tool
	NATIVE { Snapshot.Tool Oberon.Snapshot.Mod }	# SnapShot in Applications.Tool
	EditKeys.Tool Oberon.EditKeys.Mod EditKeys.Text 	# EditKeys in Applications.Tool
	Find.Tool Find.Panel # Find in Applications.Tool
	Oberon.Find.Mod
	Oberon.TeXTools.Mod 	# TeXTools in TextPopups.Text
	SaveScreen.Tool Oberon.SaveScreen.Mod Oberon.SaveTiles.Mod Oberon.SaveParticles.Mod 	# SaveScreen in Applications.Tool
	Oberon.SaveDecay.Mod Oberon.SaveSisyphus.Mod Oberon.SaveSwarm.Mod SaveScreen.Text
	SavePoints.Text Oberon.SavePoints.Mod SavePoints.Data Oberon.MakePoints.Mod
	SaveLife.html SaveLife.gif Oberon.SaveLife.Mod Oberon.SaveArt.Mod

	NATIVE { LPRPrinter.Tool Oberon.LPRPrinter.Mod } 	# LPRPrinter
	Oberon.DayTime.Mod 	# DayTime client

	Backdrops.Panel Oberon.Backdrops.Mod Backdrops.Book Bows.Pict Bricks.Pict Cells.Pict 	# Backdrops in Applications.Tool
	Clouds.Pict Coins.Pict Fractal.Pict Molecules.Pict Plasma.Pict Spirals.Pict Surface.Pict 	# (used by Tetris)
	Textils.Pict Threads.Pict Trees.Pict Marble.Pict Crochet.Pict Flock.Pict Pebbles.Pict

	Layout.Tool LayoutEdit.Panel Oberon.LayoutPanels0.Mod Oberon.LayoutPanels.Mod 	# LayoutEditor in Applications.Tool
	LayoutSamples.Arc

	LayLa.Tool Oberon.Layouts.Mod Oberon.LayLaS.Mod Oberon.LayLa.Mod Oberon.LayLa2S.Mod Oberon.LayLa2.Mod 	# LayLa in Applications.Tool
	Oberon.LayLaDemo.Mod LayLa.QuickGuide.Text LayLa.Guide.Eng.Text # LayLa.Guide.De.Text
	LayLa.Demo.Config LayLa.Include.Config LayLa2.Demo.Config LayLa2.Include.Config
	LayLaTest.Lib

	NATIVE {
	Dim3.Panel Oberon.Dim3Base.Mod Oberon.Dim3Paint.Mod Oberon.Dim3Engine.Mod Oberon.Dim3Read.Mod 	# Dim3 in Applications.Tool
	Oberon.Dim3Frames.Mod City.poly Cube.poly Example.poly Gadgets.poly Room.poly
	Sphere.poly Tetra.poly Tree.poly XMas.poly Tree1.Pict X29Plane.poly Dim3Guide.Text
	}

	BooksDev.Panel BooksUser.Panel Tutorials.Book Tutorials.Tool	# Book tutorials (not linked)
	Oberon.Books0.Mod Oberon.Books.Mod Oberon.BooksHelp.Mod Oberon.BookDocs.Mod Oberon.BookCompiler.Mod

	Coco.Tool Oberon.Sets.Mod Oberon.CRS.Mod Oberon.CRT.Mod Oberon.CRA.Mod Oberon.CRX.Mod Oberon.CRP.Mod 	# Coco in Applications.Tool
	Oberon.Coco.Mod CR.ATG Scanner.FRM Parser.FRM Coco.Report.ps

	FontEditor.Panel Oberon.FontEditor.Mod 	# FontEditor in Applications.Tool
	ASCIITab.Tool Oberon.ASCIITab.Mod 	# ASCIITab in Applications.Tool
	Oberon.Magnifier.Mod 	# Magnifier in Applications.Tool

	Games.Tool Icons2.Lib Icons3.Lib
	CardGames.Panel Oberon.Cards.Mod Oberon.Solitaire.Mod Oberon.Spider.Mod Oberon.Freecell.Mod Cards.Pict 	# CardGames in Games.Tool
	CardGames.Book
	Oberon.MineSweeper.Mod MineSweeperBD.Pict 	# MineSweeper in Games.Tool
	Oberon.Sokoban.Mod Sokoban.Data	# Sokoban in Games.Tool
	Oberon.Scramble.Mod 	# Scramble (uses Default.Pict) in Games.Tool
	Oberon.Shanghai.Mod Shanghai.Scn.Fnt 	# Shanghai in Games.Tool
	Tetris.Panel Oberon.Tetris.Mod 	# Tetris (uses Backdrops) in Games.Tool
	Oberon.Asteroids.Mod 	# Asteroids in Games.Tool

	HTML.Tool Oberon.HTML.Mod TestHTML.Text	# HTML in Applications.Tool
	WTS.Tool Oberon.WTS.Mod Oberon.WTSFold.Mod Oberon.WTSPict.Mod Oberon.WTSStamp.Mod Oberon.WTSDraw.Mod 	# WTS in Applications.Tool
	CUSeeMe.Panel Oberon.CUSM.Mod 	# CuSeeMe in Applications.Tool
	Diff.Tool Oberon.DiffGadgets.Mod Oberon.Diff.Mod 	# Diff in Applications.Tool
	Sort.Tool Oberon.Sort.Mod 	# Sort in Applications.Tool
	RX.Tool Oberon.RXA.Mod Oberon.RX.Mod 	# RX in Applications.Tool
	PictConverters.Tool Oberon.PictConverters.Mod Oberon.PS.Mod PS.HeaderR.Text 	# PictConverters in Applications.Tool
	Histogram.Panel Oberon.Histogram.Mod 	# Histogram in Applications.Tool
	MultiMail.Panel Oberon.MultiMail.Mod 	# MultiMail in Applications.Tool
	Calc.Tool Oberon.Calc.Mod	# Calc in Applications.Tool
	Calculator.Panel Oberon.Calculator.Mod Oberon.CalculatorGadgets.Mod Calculator.LayLa	# Calculator in Applications.Tool
	Oberon.DBF.Mod Oberon.DBFDump.Mod 	# DBFDump in Applications.Tool
	Swarm.Panel Oberon.Swarm.Mod Swarm.Book Swarm.Lib	# Swarm in Applications.Tool

	Oberon.DVIFiles.Mod Oberon.DVIViewers.Mod Oberon.DVIDocs.Mod DVI.Lib 	# DVI viewer
	Packages.Tool # install Oberon packages
END

# Gadgets examples & documentation.  All internal links valid.
PACKAGE OberonDocumentation ARCHIVE "OberonDocumentation.zip" SOURCE "" DESCRIPTION "Oberon Documentation"
	SamplePrograms.Tool
	ColorSystem.Panel Oberon.ColorSystem.Mod 	# ColorSystem in Documentation.Tool
	PhonePad.Panel Oberon.PhonePad.Mod 	# PhonePad
	Plotter.Panel Oberon.Plotter.Mod Oberon.Plot.Mod 	# Plotter
	Lissajous.Panel Oberon.Lissajous.Mod Oberon.Graphs.Mod 	# Lissajous
	Simulator.Panel Oberon.Diagrams.Mod Oberon.Simulator.Mod 	# Simulator
	Oberon.Popups.Mod 	# Popups
	Oberon.BartSimpson.Mod Bart.Pict	# BartSimpson
	Oberon.Cups.Mod 	# Cups
	Oberon.Examples.Mod Oberon.Examples1.Mod Oberon.OpenDemo.Mod Oberon.OpenDemo2.Mod 	# Examples
	Oberon.ExampleOberon.Mod # how  to use Oberon within A2
	Oberon.Suitcases.Mod 	# Suitcases
	Oberon.Skeleton.Mod Oberon.ViewSkeleton.Mod Oberon.ColorDriver.Mod Oberon.DocumentSkeleton.Mod	# Skeletons
	Oberon.Portraits.Mod 	# Portraits
	Oberon.Reminders.Mod	# in SamplePrograms.Tool
	# use Compiler.Compile
	TestOrganizer.Panel	# in SamplePrograms.Tool
	Oberon.TaskExample.Mod	# in SamplePrograms.Tool
	NATIVE { Oberon.UDPExample.Mod }
	Oberon.TCPExample.Mod 	# NetSystem examples

	System3F1.Graphic System3F2.Graphic System3F3.Graphic System3F4.Graphic	# Some example Gadgets diagrams
	System3F5.Graphic System3F6.Graphic System3F7.Graphic

	IntroToGadgets.Text OberonReport.html Oberon.Report.Text References.Text GadgetsChanges.Text 	# Introductory documentation

	Book.Tool Chapter0.Text Chapter1.Text Chapter2.Text Chapter3.Text Chapter4.Text 	# The Oberon Companion
	Chapter5.Text Chapter6.Text Chapter7.Text AppendA.Text AppendB.Text
	AppendC.Text Biblio.Text

	Images.Text 	# Images documentation
	ScriptGuide.Text ETGuide.Text 	# Script and ET documentation
END

PACKAGE OberonVoyager ARCHIVE "OberonVoyager.zip" SOURCE "OberonVoyagerSrc.zip" DESCRIPTION "Oberon Voyager"

	# Portability Module
	eWIN { Win32.Oberon.vyPortability.Mod }
	NATIVE, iWIN,UNIX { Oberon.vyPortability.Mod }
	Oberon.vyHost.Mod Oberon.vyHostFonts.Mod 	# Host modules
	Oberon.vyLinks.Mod Oberon.vyHostStrings.Mod Oberon.vyHostTexts.Mod Oberon.vyBase.Mod Oberon.vyName.Mod 	# Base and Name
	Oberon.vyScanners.Mod Oberon.vyParser.Mod Oberon.vyPars.Mod Oberon.vyIn.Mod Oberon.vyOut.Mod Oberon.vyFiles.Mod Oberon.vyTextsCtl.Mod 	# In and Output
	Oberon.vyBoolean.Mod Oberon.vyBit.Mod Oberon.vySet.Mod Oberon.vyReal.Mod Oberon.vyLongreal.Mod
	Oberon.vyChiSquare.Mod Oberon.vyInteger.Mod Oberon.vyLongint.Mod 	# 1d Arrays
	Oberon.vyLongintVec.Mod Oberon.vyRealVec.Mod Oberon.vyStringVec.Mod Oberon.vyReadMatrix.Mod Oberon.vyConsume.Mod
	Oberon.vyBooleanVec.Mod Oberon.vyIntVec.Mod Oberon.vyLongrealVec.Mod Oberon.vyTypes.Mod Oberon.vyPointerVec.Mod 	# 1d Vectors
	Oberon.vyRanBase.Mod Oberon.vyRanSkeleton.Mod Oberon.vyRanParksMiller.Mod Oberon.vyRandom.Mod Oberon.vyRandu.Mod
	Oberon.vyRan1.Mod Oberon.vyRanCombo.Mod Oberon.vyRanKiss.Mod Oberon.vyRanMWC.Mod Oberon.vyRanMWC1616.Mod
	Oberon.vyRanSupr.Mod Oberon.vy.jbrtStdNormal.Mod 	# Random number generation
	Oberon.vyKolSmirL.Mod Oberon.vyXPValues.Mod Oberon.vyQFisher.Mod Oberon.vyMatrixTypes.Mod
	Oberon.vyGraphBase0.Mod Oberon.vyGraphBase.Mod Oberon.vyEvents.Mod Oberon.vyRectangles.Mod Oberon.vyPatterns.Mod
	Oberon.vyTracking.Mod Oberon.vyCommandMenus.Mod Oberon.vyDisplay2d.Mod Oberon.vyPHIGS3D.Mod
	Oberon.vyPaint3d.Mod Oberon.vyAxis.Mod Oberon.vyColorPalettes.Mod Oberon.vyPort.Mod Oberon.vyHostPrint.Mod Oberon.vyGraphicCtl.Mod 	# Graphics
	Oberon.vyLine.Mod Oberon.vyLinePlot.Mod Oberon.vyHighlight.Mod Oberon.vyScatter2.Mod Oberon.vyRegress.Mod Oberon.vyPolyWorld.Mod
	Oberon.vyBitmaps.Mod Oberon.vyLayers3d.Mod Oberon.vyGraph.Mod Oberon.vyRectPlot.Mod Oberon.vyScatter1.Mod Oberon.vyScatter3.Mod
	Oberon.vyScatter.Mod Oberon.vyHistogram.Mod Oberon.vyCharts.Mod Oberon.vySketch.Mod Oberon.vyDistribution.Mod
	Oberon.vySurface.Mod Oberon.vyMaxMass.Mod Oberon.vyShorth.Mod Oberon.vyScale.Mod Oberon.vyGrid.Mod
	Oberon.vySlider.Mod Oberon.vySlider2d.Mod Oberon.vyLabel.Mod Oberon.vyBoxWhisker.Mod Oberon.vyCaption.Mod Oberon.vyFctEdit.Mod
	Oberon.vyMouseData.Mod 	# Layers
	Oberon.vy.Voyager.Mod Oberon.vyFctRandom.Mod Oberon.vyComplex.Mod Oberon.vyLCpx.Mod Oberon.vyLongComplex.Mod
	Oberon.vyPComplex.Mod Oberon.vyPLongComplex.Mod Oberon.vyDialogElems.Mod Oberon.vyStd2dLayer.Mod Oberon.vyXYPlane.Mod
	Oberon.vyxPlots.Mod
	Oberon.vy.dbgSortTest.Mod Oberon.vy.dbgTestVec.Mod Oberon.vydbg.RandomTest.Mod Oberon.vyDemo.Mod
	Oberon.vyIcons.Mod Oberon.vyQuickDraw.Mod
END

PACKAGE OberonAnts ARCHIVE "OberonAnts.zip" SOURCE "OberonAntsSrc.zip" DESCRIPTION "OberonAnts"
	Oberon.antsS3.ScrollbarsR.Mod Oberon.antsCommandInvoker.Mod	# generic tools

	eWIN { Win32.Oberon.antsPortability.Mod }
	NATIVE,iWIN,UNIX { Oberon.antsPortability.Mod }	# Portability

	NATIVE,WIN {
		Oberon.antsExpressionsObjects.Mod Oberon.antsExpressions.Mod Oberon.antsExpressionsDefaults.Mod 	# command prompt interpreter
		Oberon.antsSecurity.Mod Oberon.antsOrganizers.Mod Oberon.antsMessages.Mod Oberon.antsScriptObjects.Mod
	}
	eWIN { Win32.Oberon.antsTracking.Mod }
	NATIVE,WIN {
		Oberon.antsContainers.Mod Oberon.antsTexts.Mod Oberon.antsGlobals.Mod Oberon.antsBasicGadgets.Mod Oberon.antsOnTheFly.Mod
		Oberon.antsConstRandom.Mod Oberon.antsFiles.Mod Oberon.antsCommands.Mod Oberon.ants.fofAutomatic.Mod Oberon.antsArrays.Mod
		Oberon.antsReadWrite.Mod Oberon.antsCaches.Mod Oberon.antsPictCoordinate.Mod Oberon.antsBellman.Mod Oberon.antsDirSet.Mod
		Oberon.antsVecOpt.Mod Oberon.antsEffects.Mod Oberon.antsToolbox.Mod Oberon.antsObjects.Mod Oberon.antsArrayObjects.Mod
		Oberon.antsArrayImages.Mod Oberon.antsArrayPictures.Mod
		Oberon.antsHybridObjects.Mod Oberon.antsFunctions.Mod Oberon.antsFctVector.Mod Oberon.ants.Mod Oberon.antsRandom.Mod
		Oberon.antsMC.Mod Oberon.antsKernel.Mod Oberon.antsPerfectS.Mod Oberon.antsMasks.Mod Oberon.antsMatrixPar.Mod
		Oberon.antsNeighbourhoods.Mod Oberon.antsStatistics.Mod Oberon.ants1dArrayObjects.Mod Oberon.ants3dArrayObjects.Mod
		Oberon.ants4dArrayObjects.Mod Oberon.antsHistogramEdit.Mod Oberon.ants1dArrayVectors.Mod Oberon.antsVectors.Mod
		Oberon.antsMeanArray.Mod Oberon.antsEdges.Mod Oberon.antsColors.Mod Oberon.antsMatrixParView.Mod Oberon.antsGraph.Mod
		Oberon.antsDependency.Mod Oberon.antsPointPlot.Mod Oberon.antsArrayPictures16.Mod Oberon.antsArrayConversions.Mod
		Oberon.antsArrayImages16.Mod Oberon.antsViews.Mod Oberon.antsRegions.Mod Oberon.antsModels.Mod Oberon.antsArrayStatistics.Mod
		Oberon.antsPEV.Mod Oberon.ants3D.Mod Oberon.antsPictureViews.Mod Oberon.antsPlots.Mod Oberon.antsFilters.Mod Oberon.antsArrayViews.Mod
		Oberon.antsImageViews.Mod Oberon.ants3dArrayViews.Mod Oberon.antsLinkView.Mod Oberon.antsNDistrView.Mod
		Oberon.antsMCView.Mod Oberon.antsKernelViewer.Mod Oberon.antsInteractivePar.Mod Oberon.antsScale.Mod
		Oberon.antsObjectView.Mod Oberon.antsFctEdit.Mod Oberon.antsValuePlot.Mod Oberon.antsPointPlot2.Mod Oberon.antsLayerOps.Mod
		Oberon.ants1dCup.Mod Oberon.antsBinaryIsingS.Mod Oberon.antsBinaryIsingS2.Mod Oberon.ants3dBinaryIsingS2.Mod
		Oberon.ants4dBinaryIsingS2.Mod Oberon.antsDiscreteIsingS.Mod Oberon.antsMDimDiscreteIsingS.Mod
		Oberon.antsMDimMDiscreteIsingS.Mod Oberon.antsNNSampler.Mod Oberon.antsMDimDiscreteS.Mod
		Oberon.antsMDimDiscreteGS.Mod Oberon.antsAutobinomialS.Mod Oberon.antsAutoNormalS.Mod Oberon.antsGauss1dModel.Mod
		Oberon.antsRandomWalk.Mod Oberon.antsPEIsingDS.Mod Oberon.antsPEVIsingDS.Mod Oberon.antsPotts1DSurvey.Mod
		Oberon.antsHierarchicPotts2d.Mod Oberon.antsComet.Mod Oberon.antsAztec.Mod Oberon.antsLife.Mod Oberon.antsProgRandomWalk.Mod
		Oberon.antsTravelingS.Mod Oberon.antsPottsMonotone.Mod Oberon.antsMinimizeF.Mod Oberon.antsEmpiricD.Mod
		Oberon.antsBinaryEmpiricD.Mod Oberon.antsBinaryEmpiricD2.Mod Oberon.antsDiscreteEmpiricD.Mod
		Oberon.antsBinaryNINNED.Mod Oberon.antsIsingE.Mod Oberon.antsMDimEstimator.Mod Oberon.antsTextures.Mod
		Oberon.antsEstimate.Mod Oberon.antsEstimate2.Mod Oberon.antsPottsSimDataStructure.Mod Oberon.antsTautStringTree.Mod
		Oberon.antsTautString.Mod Oberon.antsPottsSimAdministration.Mod Oberon.antsPottsSimulation.Mod Oberon.antsPorts.Mod
	}
END

PACKAGE TrueTypeFonts ARCHIVE "TrueTypeFonts.zip" SOURCE "" DESCRIPTION "True-type fonts"
	benevento.ttf

	VeraCOPYRIGHT.TXT
	Vera.ttf VeraBd.ttf VeraBI.ttf VeraI.ttf
	VeraMo.ttf VeraMoBd.ttf VeraMoBI.ttf VeraMoI.ttf
	VeraSe.ttf VeraSeBd.ttf
END

PACKAGE CjkFonts ARCHIVE "CjkFonts.zip" SOURCE "" DESCRIPTION "Chinese, Japanese and Korean Fonts"
	Song.ccg Single.ccg
END

PACKAGE ScreenFonts ARCHIVE "ScreenFonts.zip" SOURCE "" DESCRIPTION "Bitmap fonts for screen"
	Courier8.Scn.Fnt Courier10.Scn.Fnt Courier12.Scn.Fnt
	Greek10.Scn.Fnt Greek12.Scn.Fnt Greek14.Scn.Fnt
	Greek16.Scn.Fnt Greek20.Scn.Fnt Greek24.Scn.Fnt
	Math10.Scn.Fnt Math12.Scn.Fnt Math14.Scn.Fnt
	Math16.Scn.Fnt Math20.Scn.Fnt Math24.Scn.Fnt
	Oberon8.Scn.Fnt Oberon8b.Scn.Fnt Oberon8i.Scn.Fnt
	Oberon10.Scn.Fnt Oberon10b.Scn.Fnt Oberon10i.Scn.Fnt
	Oberon12.Scn.Fnt Oberon12b.Scn.Fnt Oberon12i.Scn.Fnt
	Oberon14.Scn.Fnt Oberon14b.Scn.Fnt Oberon14i.Scn.Fnt
	Oberon16.Scn.Fnt Oberon16b.Scn.Fnt Oberon16i.Scn.Fnt
	Oberon20.Scn.Fnt Oberon20b.Scn.Fnt Oberon20i.Scn.Fnt
	Oberon24.Scn.Fnt Oberon24b.Scn.Fnt Oberon24i.Scn.Fnt
	Syntax8.Scn.Fnt Syntax8b.Scn.Fnt Syntax8i.Scn.Fnt Syntax8m.Scn.Fnt
	Syntax10.Scn.Fnt Syntax10b.Scn.Fnt Syntax10i.Scn.Fnt Syntax10m.Scn.Fnt
	Syntax12.Scn.Fnt Syntax12b.Scn.Fnt Syntax12i.Scn.Fnt Syntax12m.Scn.Fnt
	Syntax14.Scn.Fnt Syntax14b.Scn.Fnt Syntax14i.Scn.Fnt Syntax14m.Scn.Fnt
	Syntax16.Scn.Fnt Syntax16b.Scn.Fnt Syntax16i.Scn.Fnt Syntax16m.Scn.Fnt
	Syntax20.Scn.Fnt Syntax20b.Scn.Fnt Syntax20i.Scn.Fnt Syntax20m.Scn.Fnt
	Syntax24.Scn.Fnt Syntax24b.Scn.Fnt Syntax24i.Scn.Fnt Syntax24m.Scn.Fnt
	Philus10.Scn.Fnt Philus10b.Scn.Fnt Philus12.Scn.Fnt Philus12b.Scn.Fnt
END

PACKAGE Pr3Fonts ARCHIVE "Pr3Fonts.zip" SOURCE "" DESCRIPTION "Printer Fonts (300DPI)"
	Courier8.Pr3.Fnt Courier10.Pr3.Fnt Courier12.Pr3.Fnt	# Courier
	Greek10.Pr3.Fnt Greek12.Pr3.Fnt Greek14.Pr3.Fnt	# Greek
	Greek16.Pr3.Fnt Greek20.Pr3.Fnt Greek24.Pr3.Fnt
	Math10.Pr3.Fnt Math12.Pr3.Fnt Math14.Pr3.Fnt	# Math
	Math16.Pr3.Fnt Math20.Pr3.Fnt Math24.Pr3.Fnt
	Oberon8.Pr3.Fnt Oberon8b.Pr3.Fnt Oberon8i.Pr3.Fnt	# Oberon
	Oberon10.Pr3.Fnt Oberon10b.Pr3.Fnt Oberon10i.Pr3.Fnt
	Oberon12.Pr3.Fnt Oberon12b.Pr3.Fnt Oberon12i.Pr3.Fnt
	Oberon14.Pr3.Fnt Oberon14b.Pr3.Fnt Oberon14i.Pr3.Fnt
	Oberon16.Pr3.Fnt Oberon16b.Pr3.Fnt Oberon16i.Pr3.Fnt
	Oberon20.Pr3.Fnt Oberon20b.Pr3.Fnt Oberon20i.Pr3.Fnt
	Oberon24.Pr3.Fnt Oberon24b.Pr3.Fnt Oberon24i.Pr3.Fnt
	Syntax8.Pr3.Fnt Syntax8b.Pr3.Fnt Syntax8i.Pr3.Fnt Syntax8m.Pr3.Fnt	# Syntax
	Syntax10.Pr3.Fnt Syntax10b.Pr3.Fnt Syntax10i.Pr3.Fnt Syntax10m.Pr3.Fnt
	Syntax12.Pr3.Fnt Syntax12b.Pr3.Fnt Syntax12i.Pr3.Fnt Syntax12m.Pr3.Fnt
	Syntax14.Pr3.Fnt Syntax14b.Pr3.Fnt Syntax14i.Pr3.Fnt Syntax14m.Pr3.Fnt
	Syntax16.Pr3.Fnt Syntax16b.Pr3.Fnt Syntax16i.Pr3.Fnt Syntax16m.Pr3.Fnt
	Syntax20.Pr3.Fnt Syntax20b.Pr3.Fnt Syntax20i.Pr3.Fnt Syntax20m.Pr3.Fnt
	Syntax24.Pr3.Fnt Syntax24b.Pr3.Fnt Syntax24i.Pr3.Fnt Syntax24m.Pr3.Fnt
END

PACKAGE Pr6Fonts ARCHIVE "Pr6Fonts.zip" SOURCE "" DESCRIPTION "Printer Fonts (600DPI)"
	Courier8.Pr6.Fnt Courier10.Pr6.Fnt Courier12.Pr6.Fnt	# Courier
	Math10.Pr6.Fnt Math12.Pr6.Fnt Math14.Pr6.Fnt	# Math
	Math16.Pr6.Fnt Math20.Pr6.Fnt Math24.Pr6.Fnt
	Oberon8.Pr6.Fnt Oberon8b.Pr6.Fnt Oberon8i.Pr6.Fnt	# Oberon
	Oberon10.Pr6.Fnt Oberon10b.Pr6.Fnt Oberon10i.Pr6.Fnt
	Oberon12.Pr6.Fnt Oberon12b.Pr6.Fnt Oberon12i.Pr6.Fnt
	Oberon14.Pr6.Fnt Oberon14b.Pr6.Fnt Oberon14i.Pr6.Fnt
	Oberon16.Pr6.Fnt Oberon16b.Pr6.Fnt Oberon16i.Pr6.Fnt
	Oberon20.Pr6.Fnt Oberon20b.Pr6.Fnt Oberon20i.Pr6.Fnt
	Oberon24.Pr6.Fnt Oberon24b.Pr6.Fnt Oberon24i.Pr6.Fnt
END 
