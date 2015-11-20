# This script is used to generate a bootable ISO image for A2
#
# Path: In this example, the destination path for the object files and all files generated (ZIP, ISO) is ../Test/.
# This folder must exist. You can change it by search all occurences of "../Test/" and replace them by your preferred path..
#
# To create the CD image, do the following three steps:

# Step 1: Compile modules and generate ZIP packages

Release.Build --path="../Test/" --build --zip --xml A2 ~


# Step 2:  Link boot files

SystemTools.DoCommands
Linker.Link \P../Test/ \.Obx ../Test/IDE.Bin 0100000H 1000H Kernel Traps
	ATADisks DiskVolumes DiskFS Loader BootConsole ~
~

# These boot images can't be built anymore because they get to large in terms of size
Linker.Link \P../Test/ \.Obx ../Test/USB.Bin 0100000H 1000H Kernel Traps
	UsbHubDriver UsbEhci UsbStorageBoot
	DiskVolumes DiskFS Loader BootConsole ~
Linker.Link \P../Test/ \.Obx ../Test/SCSI.Bin 0100000H 1000H Kernel Traps
	Adaptec7 NCR810Disks  DiskVolumes DiskFS Loader BootConsole ~
~

# Note:
# Since USB.Bin gets too large when including all three host controller drivers,
# USB.Bin only contains the host controller driver for high-speed USB (UsbEhci.Mod), assuming that the host supports it.
# The low-/full-speed drivers (UsbUhci.Mod, UsbOhci.Mod) can be loaded later on-demand.
# If you want to boot from a computer that does not support high-speed USB, use

Linker.Link \P../Test/ \.Obx ../Test/USBSLOW.Bin 0100000H 1000H Kernel Traps
	UsbHubDriver UsbOhci UsbUhci UsbStorageBoot
	DiskVolumes DiskFS Loader BootConsole ~

# Step 3a: Create image for bootable CD (A2.iso)

SystemTools.DoCommands

SystemTools.Timer start ~

FSTools.Mount RAMDISK RamFS 2000000 4096 ~
FSTools.DeleteFiles RAMDISK:A2.Dsk ~

VirtualDisks.Create RAMDISK:A2.Dsk 320000 512 ~
VirtualDisks.Install -c=80 -h=2 -s=18 -b=512 VDISK0 RAMDISK:A2.Dsk  ~

Linker.Link \P../Test/ \.Obx ../Test/CD.Bin 0100000H 1000H
	Kernel Traps ATADisks DiskVolumes RAMVolumes DiskFS Loader BootConsole ~

Partitions.Format VDISK0#0 AosFS 1024 ../Test/CD.Bin ~
FSTools.Mount TEMP AosFS VDISK0#0 ~

ZipTool.Delete ../Test/Applications.zip InstallerPackages.XML ~
ZipTool.Add --nopath ../Test/Applications.zip ../Test/InstallerPackages.XML ~

ZipTool.ExtractAll --prefix=TEMP: --sourcePath=../Test/ --overwrite --silent
	Kernel.zip System.zip Drivers.zip ApplicationsMini.zip Applications.zip Compiler.zip CompilerSrc.zip
	GuiApplicationsMini.zip GuiApplications.zip Fun.zip Contributions.zip Build.zip EFI.zip
	Oberon.zip OberonGadgets.zip OberonApplications.zip OberonDocumentation.zip
	KernelSrc.zip SystemSrc.zip DriversSrc.zip ApplicationsMiniSrc.zip ApplicationsSrc.zip GuiApplicationsMiniSrc.zip GuiApplicationsSrc.zip FunSrc.zip BuildSrc.zip
	ScreenFonts.zip CjkFonts.zip TrueTypeFonts.zip ~

SystemTools.Show Copy ZIP archives to TEMP:  ~
FSTools.CopyTo TEMP: ../Test/
	Kernel.zip System.zip Drivers.zip ApplicationsMini.zip Applications.zip Compiler.zip
	GuiApplicationsMini.zip GuiApplications.zip
	Fun.zip Testing.zip Build.zip EFI.zip Contributions.zip
	KernelSrc.zip SystemSrc.zip DriversSrc.zip ApplicationsMiniSrc.zip ApplicationsSrc.zip CompilerSrc.zip
	GuiApplicationsMiniSrc.zip GuiApplicationsSrc.zip
	FunSrc.zip TestingSrc.zip BuildSrc.zip EFISrc.zip ContributionsSrc.zip
	Education.zip EducationSrc.zip
	Oberon.zip OberonGadgets.zip OberonApplications.zip OberonDocumentation.zip
	ScreenFonts.zip TrueTypeFonts.zip CjkFonts.zip
	OberonSrc.zip OberonApplicationsSrc.zip OberonGadgetsSrc.zip
	OberonVoyager.zip OberonVoyagerSrc.zip OberonAnts.zip OberonAntsSrc.zip
	Pr3Fonts.zip Pr6Fonts.zip
	IDE.Bin CompileCommand.Tool ~

FSTools.Watch TEMP ~
FSTools.Unmount TEMP ~

Partitions.SetConfig VDISK0#0
	TraceMode="0" TracePort="1" TraceBPS="19200" TraceMem="0B8000H,2,80,25"
	BootVol1="RAM RamFS 8000 4096"
	BootVol2="CD AosFS #0,R"
	RamFS="RAMVolumes.New DiskFS.NewFS"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	Boot1="Keyboard.Install;MousePS2.Install"
	Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhciPCI.Install;UsbUhci.Install;UsbOhci.Install"
	Boot3="WindowManager.Install"
	Boot4="Loopback.Install;Ethernet3Com90x.Install;RTL8139.Install;Intel8255x.Install;AM79C970.Install"
	Boot5="Autostart.Run"
	Boot6="InitNetwork.Init"
	Boot="DisplayLinear.Install"
	Init="117"
	CacheSize="1000"
	AutoNetConfig="1"
	ATAPIForcePIO="1"
	~
VirtualDisks.Uninstall VDISK0 ~
IsoImages.Make ../Test/A2.iso RAMDISK:A2.Dsk ~
FSTools.Unmount RAMDISK ~

SystemTools.Show CD image build time:  ~ SystemTools.Timer elapsed ~
~~

# Step 3b: Create image for bootable CD (A2mini.iso)

SystemTools.DoCommands

SystemTools.Timer start ~

FSTools.Mount RAMDISK RamFS 2000000 4096 ~
FSTools.DeleteFiles RAMDISK:A2.Dsk ~

VirtualDisks.Create RAMDISK:A2.Dsk 80000 512 ~
VirtualDisks.Install -c=80 -h=2 -s=18 -b=512 VDISK0 RAMDISK:A2.Dsk ~

Linker.Link \P../Test/ \.Obx ../Test/CD.Bin 0100000H 1000H
	Kernel Traps ATADisks DiskVolumes RAMVolumes DiskFS Loader BootConsole ~

Partitions.Format VDISK0#0 AosFS 1024 ../Test/CD.Bin ~
FSTools.Mount TEMP AosFS VDISK0#0 ~

ZipTool.Delete ../Test/Applications.zip InstallerPackages.XML ~
ZipTool.Add --nopath ../Test/Applications.zip ../Test/InstallerPackages.XML ~

ZipTool.ExtractAll --prefix=TEMP: --sourcePath=../Test/ --overwrite --silent
	Kernel.zip System.zip Drivers.zip ApplicationsMini.zip Compiler.zip GuiApplicationsMini.zip Build.zip
	KernelSrc.zip SystemSrc.zip DriversSrc.zip ApplicationsMiniSrc.zip  CompilerSrc.zip GuiApplicationsMiniSrc.zip BuildSrc.zip
	ScreenFonts.zip ~

FSTools.Watch TEMP ~
FSTools.Unmount TEMP ~

Partitions.SetConfig VDISK0#0
	TraceMode="0" TracePort="1" TraceBPS="19200" TraceMem="0B8000H,2,80,25"
	BootVol1="RAM RamFS 8000 4096"
	BootVol2="CD AosFS #0,R"
	RamFS="RAMVolumes.New DiskFS.NewFS"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	Boot1="Keyboard.Install;MousePS2.Install"
	Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhciPCI.Install;UsbUhci.Install;UsbOhci.Install"
	Boot3="WindowManager.Install"
	Boot5="Autostart.Run"
	Boot="DisplayLinear.Install"
	Init="117"
	CacheSize="1000"
	AutoNetConfig="1"
	ATAPIForcePIO="1"
	~
VirtualDisks.Uninstall VDISK0 ~
IsoImages.Make ../Test/A2mini.iso RAMDISK:A2.Dsk ~
FSTools.Unmount RAMDISK ~

SystemTools.Show CD image build time:  ~ SystemTools.Timer elapsed ~
~~

# Step 3c: Create image for bootable H.D.D.  (A2HDD.img), should work with bochs, at least.

SystemTools.DoCommands

PCAAMD64.Assemble OBLUnreal.Asm ~
PartitionsLib.SetBootLoaderFile OBLUnreal.Bin ~

SystemTools.Timer start ~

FSTools.DeleteFiles ../Test/A2HDD.img ~

VirtualDisks.Create ../Test/A2HDD.img 65520 512 ~
VirtualDisks.Install -b=512 VDISK0 ../Test/A2HDD.img ~

Linker.Link \P../Test/ \.Obx ../Test/IDE.Bin 0100000H 100000H Kernel Traps
	ATADisks DiskVolumes DiskFS Loader BootConsole ~

Partitions.WriteMBR VDISK0#0 OBEMBR.Bin ~
Partitions.InstallBootManager VDISK0#0 ~
Partitions.Create VDISK0#1 76 32 ~

Partitions.Format VDISK0#1 AosFS 512 ../Test/IDE.Bin ~
FSTools.Mount TEMP AosFS VDISK0#1 ~

ZipTool.ExtractAll --prefix=TEMP: --sourcePath=../Test/ --overwrite --silent
	System.zip Drivers.zip ApplicationsMini.zip ApplicationsMiniSrc.zip  Compiler.zip GuiApplicationsMini.zip
	ScreenFonts.zip ~

FSTools.Watch TEMP ~
FSTools.Unmount TEMP ~

Partitions.SetConfig VDISK0#1
	TraceMode="5" TracePort="1" TraceBPS="115200"
	BootVol1="AOS AosFS IDE0#1"
	Boot="DisplayLinear.Install"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	Boot1="Keyboard.Install;MousePS2.Install"
	Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhciPCI.Install;UsbUhci.Install;UsbOhci.Install"
	Boot3="WindowManager.Install"
	Boot5="Autostart.Run"
	Init="144"
	CacheSize="1000"
	ExtMemSize="64"
	MaxProcs="-1"
	~
VirtualDisks.Uninstall VDISK0 ~

SystemTools.Show HDD image build time:  ~ SystemTools.Timer elapsed ~

FSTools.CloseFiles ../Test/A2HDD.img ~

~~


# Step 3d: Create image for bootable H.D.D.  (A2HDD.img) for VirtualBox

SystemTools.DoCommands

SystemTools.Timer start ~

FSTools.DeleteFiles ../Test/A2HDD.img ~

VirtualDisks.Create ../Test/A2HDD.img 320000 512 ~
VirtualDisks.Install -b=512 VDISK0 ../Test/A2HDD.img ~

Linker.Link \P../Test/ \.Obx ../Test/IDE.Bin 0100000H 1000H Kernel Traps
	ATADisks DiskVolumes DiskFS Loader BootConsole ~

Partitions.WriteMBR VDISK0#0 OBEMBR.Bin ~
Partitions.InstallBootManager VDISK0#0 ~
Partitions.Create VDISK0#1 76 32 ~

Partitions.Format VDISK0#1 AosFS 512 ../Test/IDE.Bin ~
FSTools.Mount TEMP AosFS VDISK0#1 ~

ZipTool.ExtractAll --prefix=TEMP: --sourcePath=../Test/ --overwrite --silent
	Kernel.zip System.zip Drivers.zip ApplicationsMini.zip Applications.zip Compiler.zip CompilerSrc.zip
	GuiApplicationsMini.zip GuiApplications.zip Fun.zip Contributions.zip Build.zip EFI.zip
	Oberon.zip OberonGadgets.zip OberonApplications.zip OberonDocumentation.zip
	KernelSrc.zip SystemSrc.zip DriversSrc.zip ApplicationsMiniSrc.zip ApplicationsSrc.zip GuiApplicationsMiniSrc.zip GuiApplicationsSrc.zip FunSrc.zip BuildSrc.zip
	ScreenFonts.zip CjkFonts.zip TrueTypeFonts.zip ~

FSTools.Watch TEMP ~
FSTools.Unmount TEMP ~

Partitions.SetConfig VDISK0#1
	TraceMode="0" TracePort="1" TraceBPS="115200"
	BootVol1="AOS AosFS IDE0#1"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	Boot1="Keyboard.Install;MousePS2.Install"
	Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhciPCI.Install;UsbUhci.Install;UsbOhci.Install"
	Boot3="WindowManager.Install"
	Boot5="Autostart.Run"
	Boot="DisplayLinear.Install"
	Init="144"
	ATADetect="legacy"
	ExtMemSize="256"
	CacheSize="1000"
	~
VirtualDisks.Uninstall VDISK0 ~

SystemTools.Show HDD image build time:  ~ SystemTools.Timer elapsed ~
~~

../Test/CompileCommand.Tool


***********************************************************************
# Step 1: Compile modules and generate ZIP packages
Release.Build --path="../Test/" --build --zip --xml A2 ~

# Step 3e: Create image for bootable USB  (A2USB.img)


SystemTools.DoCommands

Compiler.Compile  -b=AMD --objectFileExtension=.Obx --symbolFileExtension=.Obx --destPath=../Test/ BiosFreePCI.Mod UsbEhci.Mod UsbEhciPCI.Mod  ~

PCAAMD64.Assemble OBLUnreal.Asm ~
PartitionsLib.SetBootLoaderFile OBLUnreal.Bin ~
PCAAMD64.Assemble BootManager.Asm ~
BootManager.Split BootManager.Bin ~
SystemTools.Timer start ~

FSTools.DeleteFiles ../Test/A2HDD.img ~

VirtualDisks.Create ../Test/A2HDD.img 320000 512 ~
VirtualDisks.Install -b=512 VDISK0 ../Test/A2HDD.img ~

Linker.Link \P../Test/ \.Obx ../Test/USB.Bin 0100000H 100000H Kernel Traps
	UsbHubDriver UsbEhci UsbEhciPCI UsbStorageBoot
	DiskVolumes DiskFS Loader BootConsole ~

Partitions.WriteMBR VDISK0#0 OBEMBR.Bin ~
Partitions.InstallBootManager VDISK0#0 BootManagerMBR.Bin BootManagerTail.Bin ~
Partitions.Create VDISK0#1 76 150 ~

Partitions.Format VDISK0#1 AosFS -1 ../Test/USB.Bin ~ (* -1 makes sure that actual boot file size is taken as offset for AosFS *)
FSTools.Mount TEMP AosFS VDISK0#1 ~

ZipTool.ExtractAll --prefix=TEMP: --sourcePath=../Test/ --overwrite --silent
	Kernel.zip System.zip Drivers.zip ApplicationsMini.zip Applications.zip Compiler.zip CompilerSrc.zip
	GuiApplicationsMini.zip GuiApplications.zip Fun.zip Contributions.zip Build.zip EFI.zip
	Oberon.zip OberonGadgets.zip OberonApplications.zip OberonDocumentation.zip
	KernelSrc.zip SystemSrc.zip DriversSrc.zip ApplicationsMiniSrc.zip ApplicationsSrc.zip GuiApplicationsMiniSrc.zip GuiApplicationsSrc.zip FunSrc.zip BuildSrc.zip
	ScreenFonts.zip CjkFonts.zip TrueTypeFonts.zip ~

FSTools.Watch TEMP ~
FSTools.Unmount TEMP ~

Partitions.SetConfig VDISK0#1
	TraceMode="1" 
	TracePort="1" 
	TraceBPS="115200"
	BootVol1="AOS AosFS USB0#1"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	CacheSize="1000"
	ExtMemSize="512"
	MaxProcs="-1"
	ATADetect="legacy"
	Init="118"
	Boot="DisplayLinear.Install"
	Boot1="Keyboard.Install;MousePS2.Install"
	Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhciPCI.Install;UsbUhci.Install;UsbOhci.Install"
	Boot3="WindowManager.Install"
	Boot4="Autostart.Run"
	~
VirtualDisks.Uninstall VDISK0 ~

SystemTools.Show HDD image build time:  ~ SystemTools.Timer elapsed ~

FSTools.CloseFiles ../Test/A2HDD.img ~

~
use this to test machine with autoreboot
	Boot5="Reboot.Do 10000 reboot"
	

WinDisks.Install E: RW ~

~
*** CAUTION: check that drive is not a local drive !!!! ***
SystemTools.DoCommands
Partitions.FileToPartition PhysicalDrive1#0 ../Test/A2HDD.img 0 160000  ~
WinDisks.Uninstall "PhysicalDrive1" ~
~




