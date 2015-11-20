**************** 32 BIT ********************

** Loader * *

SystemTools.DoCommands
Compiler.Compile  --objectFile=Generic --symbolFile=Textual --bits=32 --traceModule=Trace
	Runtime.Mod Trace.Mod EFI.Mod I386.EFIMachine.Mod EFITrace.Mod EFIFileProtocol.Mod EFISimpleFS.Mod
	EFILoadedImage.Mod EFIGraphicsOutput.Mod EFILib.Mod EFIGraphicalConsole.Mod EFIA2Loader.Mod
~
StaticLinker.Link --fileName=E:/felix.svn/qemu/disk/A2Loader.efi --fileFormat=EFI32 --displacement=401000H
	Runtime Trace EFI EFIMachine EFITrace EFISimpleFS  EFIFileProtocol EFILoadedImage EFIGraphicsOutput EFILib 
	 EFIGraphicalConsole EFIA2Loader~
~

** Kernel Image **

SystemTools.DoCommands
Compiler.Compile --objectFileExtension=.Obx --symbolFileExtension=.Obx

	Runtime.Mod Trace.Mod I386.Machine.Mod Heaps.Mod Modules.Mod Objects.Mod Kernel.Mod
	Interfaces.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod I386.Reals.Mod
	Reflection.Mod Traps.Mod Locks.Mod BiosFreePCI.Mod Clock.Mod I386.MemCache.Mod Disks.Mod Files.Mod
	Dates.Mod Strings.Mod UTF8Strings.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod
	RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod
	ISO9660Files.Mod RelativeFileSystem.Mod Loader.Mod BootConsole.Mod I386.ATADisks.Mod
~
Linker.Link \.Obx E:/felix.svn/qemu/disk/IDE.Bin 0100000H 1000H 
	Kernel Traps ATADisks DiskVolumes DiskFS BootConsole Loader ~
~
**************** 64 BIT ********************

** Loader **
~
SystemTools.DoCommands
Compiler.Compile  --objectFile=Generic --symbolFile=Textual --bits=64 --traceModule=Trace
	AMD64.Runtime.Mod Trace.Mod EFI.Mod AMD64.EFIMachine.Mod EFITrace.Mod EFIFileProtocol.Mod EFISimpleFS.Mod
	EFILoadedImage.Mod EFIGraphicsOutput.Mod EFILib.Mod EFIGraphicalConsole.Mod EFIA2Loader.Mod
~
StaticLinker.Link --fileName=E:/felix.svn/qemu/disk/A2Loader.efi --fileFormat=EFI64 --displacement=401000H
	Runtime Trace EFI EFIMachine EFITrace EFISimpleFS  EFIFileProtocol EFILoadedImage EFIGraphicsOutput EFILib 
	 EFIGraphicalConsole EFIA2Loader
~
~

** Kernel Image **

SystemTools.DoCommands
	Compiler.Compile --newObjectFile --objectFile=Generic  -b=AMD --bits=64
	AMD64.Runtime.Mod Trace.Mod EFI.AMD64.Machine.Mod EFIGraphicalConsole.Mod StartConsole.Mod Heaps.Mod oc/Generic.Modules.Mod Objects.Mod Kernel.Mod 
	Interfaces.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod AMD64.Reals.Mod 
	Reflection.Mod AMD64.Traps.Mod Locks.Mod BiosFreePCI.Mod Clock.Mod AMD64.MemCache.Mod Disks.Mod Files.Mod 
	Dates.Mod Strings.Mod UTF8Strings.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod 
	RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod 
	ISO9660Files.Mod RelativeFileSystem.Mod Loader.Mod BootConsole.Mod AMD64.ATADisks.Mod ~
	
	StaticLinker.Link
	--fileName=E:/felix.svn/qemu/disk/IDE.Bin
	--extension=Gof
	--displacement=01000000H
	Runtime Trace Machine EFIGraphicalConsole StartConsole Heaps Modules Objects Kernel 
	KernelLog Plugins Streams Commands Reals 
	Reflection Traps Locks PCI Clock MemCache Disks Files 
	ATADisks
	Dates Strings UTF8Strings Caches   	    
	Loader  BootConsole ~
~


******* config file *******
	PET.Open E:/felix.svn/qemu/disk/Config.txt ~
	
	
TraceMode="4" 
TracePort="1" 
TraceBPS="115200"
CacheSize="1000"
MaxProcs="-1"
ExtMemSize="127"
ATADetect="legacy"
~
BootVol1="AOS AosFS IDE0#1"
AosFS="DiskVolumes.New DiskFS.NewFS"
Boot1="Keyboard.Install;MousePS2.Install"
Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhci.Install;UsbUhci.Install;UsbOhci.Install"
Boot3="WindowManager.Install"
Boot5="Autostart.Run"
Boot="DisplayLinear.Install"

~~


SystemTools.DoCommands
	VirtualDisks.Create A2HDD.img 65520 512 ~
	VirtualDisks.Install -b=512 VDISK0 A2HDD.img ~

	Linker.Link \.Obx IDE.Bin 0100000H 1000H Kernel Traps ATADisks DiskVolumes DiskFS BootConsole ~

	Partitions.WriteMBR VDISK0#0 OBEMBR.Bin ~
	Partitions.InstallBootManager VDISK0#0 ~
	Partitions.Create VDISK0#1 76 32 ~

	Partitions.Format VDISK0#1 AosFS 512 IDE.Bin ~

	Partitions.SetConfig VDISK0#1
		TraceMode="5" TracePort="1" TraceBPS="115200"
		BootVol1="AOS AosFS IDE0#1"
		AosFS="DiskVolumes.New DiskFS.NewFS"
		Boot1="Keyboard.Install;MousePS2.Install"
		Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhci.Install;UsbUhci.Install;UsbOhci.Install"
		Boot3="WindowManager.Install"
		Boot5="Autostart.Run"
		Boot="DisplayLinear.Install"
		Init=""
		CacheSize="1000"
		~
	VirtualDisks.Uninstall VDISK0 ~
	~
	
	
SystemTools.DoCommands
VirtualDisks.Create A2:A2HDD.img 65520 ~
VirtualDisks.Install VDISK A2:A2HDD.img ~
Partitions.InstallBootManager VDISK#0 ~
Partitions.Create VDISK#1 76 31 ~
PCAAMD64.Assemble Bbl.Asm ~
PartitionsLib.SetBootLoaderFile BBL.Bin~
Partitions.Format VDISK#1 AosFS -2 E:/felix.svn/qemu/disk/IDE.Bin~
Partitions.SetConfig VDISK#1
	TraceMode="5" TracePort="1"
	MaxProcs="-1" ATADetect="legacy"
	BootVol1="RAM RamFS 8000 4096"
	BootVol2="CD AosFS #0,R"
	RamFS="RAMVolumes.New DiskFS.NewFS"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	Boot1="Keyboard.Install;MousePS2.Install"
	Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhci.Install;UsbUhci.Install;UsbOhci.Install"
	Boot3="WindowManager.Install"
	Boot4="Loopback.Install;Ethernet3Com90x.Install;RTL8139.Install;Intel8255x.Install;AM79C970.Install"
	Boot5="Autostart.Run"
	Boot6="InitNetwork.Init"
	Boot="DisplayLinear.Install"
	Init=""
	CacheSize="1000"
	AutoNetConfig="1"
	ATAPIForcePIO="1"
	ExtMemSize="128" ~
VirtualDisks.Uninstall VDISK ~
~