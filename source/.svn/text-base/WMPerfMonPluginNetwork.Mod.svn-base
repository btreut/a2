MODULE WMPerfMonPluginNetwork; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor network performance plugin"; *)

IMPORT
	WMPerfMonPlugins, Network, Plugins, Modules;

CONST
	PluginName = "NetworkSpeed";
	ModuleName = "WMPerfMonPluginNetwork";

TYPE

	NetParameter* = POINTER TO RECORD (WMPerfMonPlugins.Parameter);
		device* : Network.LinkDevice;
	END;

TYPE

	NetworkSpeed* = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		l : Network.LinkDevice;

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := PluginName; p.description := "Network Send Performance";
			SELF.l := p(NetParameter).device;
			WMPerfMonPlugins.GetNameDesc(l, p.devicename);
			p.modulename := ModuleName;
			p.autoMax := TRUE; p.perSecond := TRUE; p.showSum := TRUE; p.minDigits := 5;
			NEW(ds, 3);
			ds[0].name := "Total"; INCL(ds[0].flags, WMPerfMonPlugins.Sum); ds[0].unit := "KB";
			ds[1].name := "Send"; ds[1].unit := "KB";
			ds[2].name := "Receive"; ds[2].unit := "KB";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		VAR sentKB, receivedKB : REAL;
		BEGIN
			sentKB := l.sendCount / 1024;
			receivedKB := l.recvCount / 1024;
			dataset[0] := sentKB + receivedKB;
			dataset[1] := sentKB;
			dataset[2] := receivedKB;
		END UpdateDataset;

	END NetworkSpeed;

PROCEDURE AddPlugin(dev :Network.LinkDevice);
VAR ns : NetworkSpeed; npar : NetParameter;
BEGIN {EXCLUSIVE}
	NEW(npar); npar.device := dev; NEW(ns, npar);
END AddPlugin;

PROCEDURE RemovePlugin(dev : Network.LinkDevice);
VAR devicename : WMPerfMonPlugins.DeviceName;
BEGIN {EXCLUSIVE}
	WMPerfMonPlugins.GetNameDesc(dev, devicename);
	WMPerfMonPlugins.updater.RemoveByName(PluginName, devicename);
END RemovePlugin;

PROCEDURE EventHandler(event : LONGINT; plugin : Plugins.Plugin);
BEGIN
	IF event = Plugins.EventAdd THEN
		AddPlugin(plugin (Network.LinkDevice))
	ELSIF event = Plugins.EventRemove THEN
		RemovePlugin(plugin (Network.LinkDevice));
	END;
END EventHandler;

PROCEDURE InitPlugins;
VAR table : Plugins.Table; i : LONGINT;
BEGIN
	Network.registry.AddEventHandler(EventHandler, i);
	Network.registry.GetAll(table);
	IF table # NIL THEN FOR i := 0 TO LEN(table)-1 DO AddPlugin(table[i] (Network.LinkDevice)); END; END;
END InitPlugins;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
VAR ignore : LONGINT;
BEGIN
	Network.registry.RemoveEventHandler(EventHandler, ignore);
	WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	InitPlugins;
END WMPerfMonPluginNetwork.

WMPerfMonPluginNetwork.Install ~  SystemTools.Free WMPerfMonPluginNetwork ~
