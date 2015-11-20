MODULE FoxActiveCells; (** AUTHOR "fof"; PURPOSE "hardware library for the ActiveCells compiler"; *)
(*! deprecated -- not used any more in Active Cells 3 *)
IMPORT SyntaxTree := FoxSyntaxTree, Basic := FoxBasic, Global := FoxGlobal, Files, Streams,  D := Debugging, Diagnostics, Strings, Commands, GenericLinker, StaticLinker, SYSTEM, Modules;

CONST
	In*= SyntaxTree.InPort; Out*= SyntaxTree.OutPort;
	defaultInstructionMemorySize*=0; (* in code units *)
	defaultDataMemorySize *=2048; (* in data units *)
	defaultPortWidth *=32; (* bits *)
	defaultFifoSize *=32; (* "words" of port width size *)
	defaultChannelWidth* = 32;
	CodeFileExtension*="code";
	DataFileExtension*="data";
	SpecificationFileExtension*="spec";
	ObjectFileExtension*="Gof";

	VectorCapability*=Global.VectorCapability;
	FloatingPointCapability*=Global.FloatingPointCapability;
	TRMSCapability*=Global.TRMSCapability;

	TraceError=FALSE;
	BasePortAddress=LONGINT(0FFFFFFE0H);
	TraceSame= FALSE;

	(* comparison flags *)
	CheckModules= 0;
	CheckParameters=1;
	CheckCapabilityParameters = 2;

TYPE
	Name*= ARRAY 256 OF CHAR;

	PortInstance*=RECORD
		instance-: Instance; port-: Port
	END;

	(* base type of all ingredients of the specification graph *)
	Symbol*=OBJECT
	VAR name-: Name;
		scope-: Scope;

		PROCEDURE GetFullName*(VAR name: ARRAY OF CHAR; in: Scope);

			PROCEDURE InScope(this,in : Scope): BOOLEAN;
			BEGIN
				WHILE (this # NIL) & (this # in) DO
					this := this.scope;
				END;
				RETURN this # NIL
			END InScope;

		BEGIN
			IF (SELF.scope # NIL) & ~InScope(in,SELF.scope) THEN
				SELF.scope.GetFullName(name,in);
				Strings.Append(name,".");
				Strings.Append(name,SELF.name);
			ELSE
				COPY(SELF.name,name)
			END;
		END GetFullName;

		PROCEDURE InitSymbol(CONST name: ARRAY OF CHAR; scope: Scope);
		BEGIN
			COPY(name,SELF.name);
			SELF.scope := scope;
		END InitSymbol;

		PROCEDURE AppendToMsg*(VAR msg: ARRAY OF CHAR);
		VAR name:Name;
		BEGIN
			GetFullName(name, NIL);
			Strings.Append(msg, name);
		END AppendToMsg;

		PROCEDURE Same*(as: Symbol; flags: SET): BOOLEAN;
		BEGIN
			RETURN name = as.name
		END Same;

	END Symbol;

	SymbolList*= OBJECT(Basic.List)

		PROCEDURE GetSymbol*(i: LONGINT): Symbol;
		VAR a: ANY;
		BEGIN
			a := Get(i); IF a = NIL THEN RETURN NIL ELSE RETURN a(Symbol) END
		END GetSymbol;

		PROCEDURE AddSymbol(a: Symbol);
		BEGIN Add(a);
		END AddSymbol;

		PROCEDURE ByName*(CONST name: ARRAY OF CHAR): Symbol;
		VAR a: Symbol; i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				a := GetSymbol(i);
				IF (a # NIL) & (a.name = name) THEN RETURN a END;
			END;
			RETURN NIL
		END ByName;

		PROCEDURE Same(as: SymbolList; flags: SET): BOOLEAN;
		VAR i: LONGINT; left, right: Symbol;
		BEGIN
			IF as.Length() # Length() THEN RETURN FALSE END;
			FOR i := 0 TO Length()-1 DO
				left := GetSymbol(i);
				right := as.GetSymbol(i);
				IF ~left.Same(right, flags) THEN RETURN FALSE END;
			END;
			RETURN TRUE
		END Same;

	END SymbolList;

	(* representation of a channel end point
		- represented as PORT parameter in the language
		- endpoint of FIFOs in hardware
	*)
	Port*= OBJECT (Symbol)
	VAR
		direction-: LONGINT;
		adr-: LONGINT;
		width-: LONGINT;
		delegate-: PortInstance;
		index-: LONGINT;

		PROCEDURE Same(as: Symbol; flags: SET): BOOLEAN;
		BEGIN
			IF TraceSame THEN TRACE("Port",name) END;
			IF (as = NIL) OR ~(as IS Port) THEN RETURN FALSE END;
			WITH as: Port DO
				IF (direction # as.direction) OR (adr # as.adr) OR (width # as.width) THEN RETURN FALSE END;
			END;
			RETURN Same^(as, flags)
		END Same;

		PROCEDURE &InitPort*(CONST name: ARRAY OF CHAR; scope: Scope; direction: LONGINT; adr: LONGINT);
		BEGIN
			InitSymbol(name,scope);
			SELF.direction := direction;
			SELF.adr := adr;
			width := defaultPortWidth;
			delegate.instance := NIL;
			index := -1;
		END InitPort;

		PROCEDURE SetWidth*(widthInBits: LONGINT);
		BEGIN width := widthInBits
		END SetWidth;

		PROCEDURE Delegate*(instance: Instance; port: Port);
		BEGIN
			delegate.instance := instance; delegate.port := port
		END Delegate;

		PROCEDURE Write*(w: Streams.Writer; indent: LONGINT);
		BEGIN
			Indent(w,indent);
			w.Int(index,1);
			w.String(" name="); w.String(name);
			w.String(" direction=");
			IF direction = In THEN w.String("in ");
			ELSIF direction=Out THEN w.String("out ");
			END;
			w.String(" adr="); w.Int(adr,1);
			w.String(" width="); w.Int(width,1);
			w.String(" delegateInstance=");
			IF delegate.instance = NIL THEN
				w.String("none")
			ELSE
				w.String(delegate.instance.name);
				w.String(" delegatePort="); w.String(delegate.port.name);
			END;
			w.Ln;
			w.Update;
		END Write;

		PROCEDURE Read*(r: Streams.Reader): BOOLEAN;
		VAR s: Name; index: LONGINT;
		BEGIN
			IF ~r.GetInteger(index,FALSE) OR (index # SELF.index) OR ~CheckItem(r,"name") OR ~GetString(r,name)
			OR ~CheckItem(r,"direction") OR ~GetString(r,s)
			THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			IF s = "in" THEN direction := In
			ELSIF s="out" THEN direction := Out
			END;
			IF ~CheckItem(r,"adr") OR ~r.GetInteger(adr,FALSE) OR
			~CheckItem(r,"width") OR ~r.GetInteger(width,FALSE) OR
			~CheckItem(r,"delegateInstance") OR ~GetString(r,s)
			THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;

			IF s = "none" THEN delegate.instance := NIL
			ELSE
				delegate.instance := scope.instances.ByName(s);
				ASSERT(delegate.instance # NIL);
				IF ~CheckItem(r,"delegatePort") OR ~GetString(r,s) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
				delegate.port := delegate.instance.instanceType.ports.ByName(s);
			END;
			RETURN TRUE
		END Read;

	END Port;

	PortList*= OBJECT(Basic.List)

		PROCEDURE GetPort*(i: LONGINT): Port;
		VAR a: ANY;
		BEGIN
			a := Get(i); IF a = NIL THEN RETURN NIL ELSE RETURN a(Port) END
		END GetPort;

		PROCEDURE AddPort(a: Port);
		BEGIN a.index := Length(); Add(a);
		END AddPort;

		PROCEDURE ByName*(CONST name: ARRAY OF CHAR): Port;
		VAR a: Port; i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				a := GetPort(i);
				IF (a # NIL) & (a.name = name) THEN RETURN a END;
			END;
			RETURN NIL
		END ByName;

		PROCEDURE Same(as: PortList; flags: SET): BOOLEAN;
		VAR i: LONGINT; left, right: Port;
		BEGIN
			IF as.Length() # Length() THEN RETURN FALSE END;
			FOR i := 0 TO Length()-1 DO
				left := GetPort(i);
				right := as.GetPort(i);
				IF ~left.Same(right, flags) THEN RETURN FALSE END;
			END;
			RETURN TRUE
		END Same;


	END PortList;

	(* devices are additional components that can be attached to processors
		- implicitly represented as imported module and used interface in the language
		- represented as components attached to processor in hardware
	*)
	Device*= OBJECT (Symbol)
	VAR
		adr-: LONGINT;
		index-: LONGINT;

		PROCEDURE Same(as: Symbol; flags: SET): BOOLEAN;
		BEGIN
			IF TraceSame THEN TRACE("Device",name) END;
			IF (as = NIL) OR ~(as IS Device) THEN RETURN FALSE END;
			WITH as: Device DO
				IF (adr # as.adr) OR (index # as.index) THEN RETURN FALSE END;
			END;
			RETURN Same^(as, flags)
		END Same;


		PROCEDURE &InitDevice*(CONST name: ARRAY OF CHAR; scope: Scope; adr: LONGINT);
		BEGIN
			InitSymbol(name,scope);
			SELF.adr := adr;
			index := -1;
		END InitDevice;

		PROCEDURE Write*(w:Streams.Writer; indent: LONGINT);
		BEGIN
			Indent(w,indent);
			w.Int(index,1);
			w.String(" name="); w.String(name); w.String(" adr="); w.Int(adr,1); w.Ln;
			w.Update;
		END Write;

		PROCEDURE Read*(r: Streams.Reader): BOOLEAN;
		VAR i: LONGINT;
		BEGIN
			RETURN r.GetInteger(i,FALSE) & (i=index) &
			CheckItem(r,"name") & GetString(r,name) &
			CheckItem(r,"adr") & r.GetInteger(adr,FALSE);
		END Read;

	END Device;

	DeviceList*= OBJECT(Basic.List)

		PROCEDURE GetDevice*(i: LONGINT): Device;
		VAR a: ANY;
		BEGIN
			a := Get(i); IF a = NIL THEN RETURN NIL ELSE RETURN a(Device) END
		END GetDevice;

		PROCEDURE AddDevice(p: Device);
		BEGIN
			ASSERT(ByName(p.name) = NIL);
			p.index := Length(); Add(p);
		END AddDevice;

		PROCEDURE ByName*(CONST name: ARRAY OF CHAR): Device;
		VAR a: Device; i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				a := GetDevice(i);
				IF (a # NIL) & (a.name = name) THEN RETURN a END;
			END;
			RETURN NIL
		END ByName;

		PROCEDURE Same(as: DeviceList; flags: SET): BOOLEAN;
		VAR i: LONGINT; left, right: Device;
		BEGIN
			IF as.Length() # Length() THEN RETURN FALSE END;
			FOR i := 0 TO Length()-1 DO
				left := GetDevice(i);
				right := as.GetDevice(i);
				IF ~left.Same(right, flags) THEN RETURN FALSE END;
			END;
			RETURN TRUE
		END Same;


	END DeviceList;

	(*
		a module is a collection of actors
		- represented as IMPORT in source code
		- has no representation in hardware
	*)
	Module*=OBJECT (Symbol)
	VAR
		fileName*: Files.FileName; (* preparation for separate compilation (optimization) *)
		index-: LONGINT;

		PROCEDURE Same(as: Symbol; flags: SET): BOOLEAN;
		BEGIN
			IF TraceSame THEN TRACE("Module",name) END;
			IF (as = NIL) OR  ~(as IS Module) THEN RETURN FALSE END;
			WITH as: Module DO
				IF (index # as.index) OR (fileName # as.fileName) THEN RETURN FALSE END;
			END;
			RETURN Same^(as, flags)
		END Same;

		PROCEDURE & InitModule(CONST name: ARRAY OF CHAR; scope: Scope; CONST fileName: ARRAY OF CHAR);
		BEGIN
			InitSymbol(name,scope);
			COPY(name, SELF.name);
			COPY(fileName, SELF.fileName);
			index := -1;
		END InitModule;

		PROCEDURE Write*(w:Streams.Writer; indent: LONGINT);
		BEGIN
			Indent(w,indent);
			w.Int(index,1);
			w.String(" name="); w.String(name);
			w.String(" filename="); w.String("'"); w.String(fileName); w.String("'");
			w.Ln;
			w.Update;
		END Write;

		PROCEDURE Read*(r: Streams.Reader): BOOLEAN;
		VAR i: LONGINT;
		BEGIN
			RETURN r.GetInteger(i,FALSE) & (i=index) & CheckItem(r,"name") & GetString(r,name)
				&CheckItem(r,"filename") & GetString(r,fileName);
		END Read;

	END Module;

	ModuleList*= OBJECT(Basic.List)

		PROCEDURE GetModule*(i: LONGINT): Module;
		VAR a: ANY;
		BEGIN
			a := Get(i); IF a = NIL THEN RETURN NIL ELSE RETURN a(Module) END
		END GetModule;

		PROCEDURE AddModule(a: Module);
		BEGIN a.index := Length(); Add(a);
		END AddModule;

		PROCEDURE ByName*(CONST name: ARRAY OF CHAR): Module;
		VAR a: Module; i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				a := GetModule(i);
				IF (a # NIL) & (a.name = name) THEN RETURN a END;
			END;
			RETURN NIL
		END ByName;

		PROCEDURE Same(as: ModuleList; flags: SET): BOOLEAN;
		VAR i: LONGINT; left, right: Module;
		BEGIN
			IF as.Length() # Length() THEN RETURN FALSE END;
			FOR i := 0 TO Length()-1 DO
				left := GetModule(i);
				right := as.GetModule(i);
				IF ~left.Same(right, flags) THEN RETURN FALSE END;
			END;
			RETURN TRUE
		END Same;


	END ModuleList;

	(*
		parameters are used for setting up initial values on instances
	*)
	Parameter*=OBJECT (Symbol)
	CONST
		Boolean=0;Integer=1;String=2;
	VAR
		index-: LONGINT;
		parameterType-: SHORTINT; (* Integer or Boolean, for the time being *)
		integer-: LONGINT;
		boolean-: BOOLEAN;
		string-: Strings.String;

		PROCEDURE Same(as: Symbol; flags: SET): BOOLEAN;
		BEGIN
			IF TraceSame THEN TRACE("Parameter",name) END;
			IF (as = NIL) OR ~(as IS Parameter) THEN RETURN FALSE END;
			WITH as: Parameter DO
				(*IF (index # as.index) OR (type # as.type) OR (integer # as.integer) OR (as.boolean # boolean) THEN RETURN FALSE END;*)
				IF (index # as.index) OR (parameterType # as.parameterType) THEN RETURN FALSE; END;
				IF ((parameterType = 0) & (as.boolean # boolean))
					OR ((parameterType = 1) & (as.integer # integer))
					OR ((parameterType = 2) & (as.string^ # string^)) THEN RETURN FALSE; END;
			END;
			RETURN Same^(as, flags)
		END Same;

		PROCEDURE &Init(CONST name: ARRAY OF CHAR; scope: Scope);
		BEGIN
			InitSymbol(name,scope);
		END Init;

		PROCEDURE SetBoolean*(b: BOOLEAN);
		BEGIN
			parameterType := Boolean; boolean := b
		END SetBoolean;

		PROCEDURE SetInteger*(i: LONGINT);
		BEGIN
			parameterType := Integer; integer := i
		END SetInteger;

		PROCEDURE SetString*(CONST s: ARRAY OF CHAR);
		BEGIN
			parameterType := String; string := Strings.NewString(s);
		END SetString;


		PROCEDURE Write(w: Streams.Writer; indent: LONGINT);
		VAR typeName: SyntaxTree.String;
		BEGIN
			Indent(w,indent);
			w.Int(index,1);
			w.String(" name="); w.String(name);
			w.String(" type=");
			IF parameterType = Integer THEN w.String("INTEGER")
			ELSIF parameterType=Boolean THEN w.String("BOOLEAN")
			ELSIF parameterType=String THEN w.String("STRING");
			END;
			w.String(" value=");
			IF parameterType = Integer THEN w.Int(integer,1)
			ELSIF parameterType=Boolean THEN
				IF boolean THEN w.String("TRUE") ELSE w.String("FALSE") END
			ELSIF parameterType = String THEN w.String("'"); w.String(string^); w.String("'");
			END;
			w.Ln;
			w.Update;
		END Write;

		PROCEDURE Read(r: Streams.Reader): BOOLEAN;
		VAR index: LONGINT; s: Name;
		BEGIN
			IF r.GetInteger(index,FALSE) & CheckItem(r,"name") & GetString(r,name)
				&CheckItem(r,"type") & GetString(r,s) & CheckItem(r,"value") THEN
					IF s= "INTEGER" THEN parameterType := Integer
					ELSIF s = "BOOLEAN" THEN parameterType := Boolean
					ELSIF s = "STRING" THEN parameterType := String
					ELSE RETURN FALSE
					END;
					IF (parameterType = Integer) & r.GetInteger(integer,FALSE) THEN
					ELSIF (parameterType=Boolean) & GetString(r,s) THEN
						IF s="TRUE" THEN boolean := TRUE ELSE boolean := FALSE END;
					ELSIF (parameterType=String) & GetString(r,s) THEN
						string := Strings.NewString(s);
					ELSE RETURN FALSE
					END;
			ELSE RETURN FALSE
			END;
			RETURN TRUE
		END Read;

	END Parameter;

	ParameterList*= OBJECT(Basic.List)

		PROCEDURE GetParameter*(i: LONGINT): Parameter;
		VAR a: ANY;
		BEGIN
			a := Get(i); IF a = NIL THEN RETURN NIL ELSE RETURN a(Parameter) END
		END GetParameter;

		PROCEDURE AddParameter(a: Parameter);
		BEGIN a.index := Length(); Add(a);
		END AddParameter;

		PROCEDURE ByName*(CONST name: ARRAY OF CHAR): Parameter;
		VAR a: Parameter; i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				a := GetParameter(i);
				IF (a # NIL) & (a.name = name) THEN RETURN a END;
			END;
			RETURN NIL
		END ByName;

		PROCEDURE Same(as: ParameterList; flags: SET): BOOLEAN;
		VAR i: LONGINT; left, right: Parameter;
		BEGIN
			IF as.Length() # Length() THEN RETURN FALSE END;
			FOR i := 0 TO Length()-1 DO
				left := GetParameter(i);
				right := as.GetParameter(i);
				IF ~left.Same(right, flags) THEN RETURN FALSE END;
			END;
			RETURN TRUE
		END Same;

	END ParameterList;

	(*
		instances are variables in networks pointing to a type
		- represented as VAR ... in assemblies (networks)
		- when instantiated the instance represents the instance of a processor in hardware
	*)
	Instance*=OBJECT (Symbol)
	VAR
		instanceType-: Type; (* instance type *)
		parameters-: ParameterList;
		capabilityParameters-: ParameterList;
		index-: LONGINT;
		(* caches: *)
		instructionMemorySize-, dataMemorySize-: LONGINT;
		capabilities-: SET;

		PROCEDURE Same(as: Symbol; flags: SET): BOOLEAN;
		BEGIN
			IF TraceSame THEN TRACE("Instance",name) END;
			IF (as = NIL) OR ~(as IS Instance) THEN RETURN FALSE END;
			WITH as: Instance DO
				IF (index # as.index) THEN RETURN FALSE END;
				IF ~instanceType.Same(as.instanceType, flags) THEN RETURN FALSE END;
				IF (CheckParameters IN flags) & ~parameters.Same(as.parameters, flags) THEN RETURN FALSE END;
				IF (CheckCapabilityParameters IN flags) & ~capabilityParameters.Same(as.capabilityParameters, flags) THEN RETURN FALSE END;
				IF (instructionMemorySize # as.instructionMemorySize) THEN RETURN FALSE END;
				IF (dataMemorySize # as.dataMemorySize) THEN RETURN FALSE END;
			END;
			RETURN Same^(as, flags)
		END Same;

		PROCEDURE IsEngine*(): BOOLEAN;
		BEGIN
			RETURN Global.EngineCapability IN capabilities
		END IsEngine;

		PROCEDURE &Init(CONST name: ARRAY OF CHAR; scope: Scope; c: Type);
		BEGIN
			InitSymbol(name,scope);
			instanceType := c;
			index := -1; SELF.scope := scope; NEW(parameters,4); NEW(capabilityParameters, 4);
			ASSERT(scope # NIL);
			SetType(c);
		END Init;

		PROCEDURE SetType(type: Type);
		BEGIN
			IF type # NIL THEN
				SELF.instanceType := type;
				dataMemorySize := type.dataMemorySize;
				capabilities := type.capabilities;
			END;
		END SetType;


		PROCEDURE SetInstructionMemorySize*(value: LONGINT);
		BEGIN instructionMemorySize := value
		END SetInstructionMemorySize;

		PROCEDURE SetDataMemorySize*(value: LONGINT);
		BEGIN dataMemorySize := value
		END SetDataMemorySize;

		PROCEDURE AddParameter*(CONST name: ARRAY OF CHAR): Parameter;
		VAR parameter: Parameter;
		BEGIN
			NEW(parameter,name,NIL); parameters.Add(parameter);
			RETURN parameter
		END AddParameter;

		PROCEDURE AddCapabilityParameter*(CONST name: ARRAY OF CHAR): Parameter;
		VAR parameter: Parameter;
		BEGIN
			NEW(parameter,name,NIL); capabilityParameters.Add(parameter);
			RETURN parameter
		END AddCapabilityParameter;

		PROCEDURE Write(w: Streams.Writer; indent: LONGINT);
		VAR typeName: Name; parameter: Parameter; i: LONGINT;
		BEGIN
			Indent(w,indent); INC(indent);
			w.Int(index,1);
			w.String(" name="); w.String(name);
			instanceType.GetFullName(typeName,scope);
			w.String(" type="); w.String(typeName);
			w.String(" instructionMemorySize="); w.Int(instructionMemorySize,1);
			w.String(" dataMemorySize="); w.Int(dataMemorySize,1);
			w.String(" capabilities="); WriteSet(w,capabilities);
			w.Ln;
			Indent(w,indent);

			w.String("parameters=");w.Int(parameters.Length(),1); w.Ln;
			FOR i := 0 TO parameters.Length()-1 DO
				parameter := parameters.GetParameter(i);
				parameter.Write(w,indent+1);
			END;

			Indent(w,indent);
			w.String("capabilityParameters=");w.Int(capabilityParameters.Length(),1); w.Ln;
			FOR i := 0 TO capabilityParameters.Length()-1 DO
				parameter := capabilityParameters.GetParameter(i);
				parameter.Write(w,indent+1);
			END;

			w.Update;
		END Write;

		PROCEDURE Read(r: Streams.Reader): BOOLEAN;
		VAR index: LONGINT; s: Name; symbol: Symbol; i,number: LONGINT; parameter: Parameter;
		BEGIN
			IF r.GetInteger(index,FALSE) & CheckItem(r,"name") & GetString(r,name) &
			CheckItem(r,"type") & GetString(r,s) &
			CheckItem(r,"instructionMemorySize") & r.GetInteger(instructionMemorySize,FALSE) &
			CheckItem(r,"dataMemorySize") & r.GetInteger(dataMemorySize,FALSE) &
			CheckItem(r,"capabilities") & GetSet(r,capabilities)
			THEN
				symbol := GetSymbol(scope,s);
				IF symbol = NIL THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
				SetType(symbol(Type));
				IF ~CheckItem(r,"parameters") OR ~r.GetInteger(number,FALSE)
				THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
				FOR i := 0 TO number-1 DO
					parameter := AddParameter("");
					IF ~parameter.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
				END;
				IF ~CheckItem(r,"capabilityParameters") OR ~r.GetInteger(number,FALSE)
				THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
				FOR i := 0 TO number-1 DO
					parameter := AddCapabilityParameter("");
					IF ~parameter.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
				END;

				RETURN TRUE
			ELSE IF TraceError THEN HALT(100) ELSE RETURN FALSE END
			END;
		END Read;

		PROCEDURE AppendToMsg(VAR msg: ARRAY OF CHAR);
		VAR name:Name;
		BEGIN
			AppendToMsg^(msg);
			instanceType.GetFullName(name,NIL);
			Strings.Append(msg," (");
			Strings.Append(msg,name);
			Strings.Append(msg,")");
		END AppendToMsg;

	END Instance;

	InstanceList*= OBJECT(Basic.List)

		PROCEDURE GetInstance*(i: LONGINT): Instance;
		VAR a: ANY;
		BEGIN
			a := Get(i); IF a = NIL THEN RETURN NIL ELSE RETURN a(Instance) END
		END GetInstance;

		PROCEDURE AddInstance(a: Instance);
		BEGIN a.index := Length(); Add(a);
		END AddInstance;

		PROCEDURE ByName*(CONST name: ARRAY OF CHAR): Instance;
		VAR a: Instance; i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				a := GetInstance(i);
				IF (a # NIL) & (a.name = name) THEN RETURN a END;
			END;
			RETURN NIL
		END ByName;

		PROCEDURE Same(as: InstanceList; flags: SET): BOOLEAN;
		VAR i: LONGINT; left, right: Symbol;
		BEGIN
			IF as.Length() # Length() THEN RETURN FALSE END;
			FOR i := 0 TO Length()-1 DO
				left := GetInstance(i);
				right := as.GetInstance(i);
				IF ~left.Same(right, flags) THEN RETURN FALSE END;
			END;
			RETURN TRUE
		END Same;

	END InstanceList;

	InstanceMethod*= PROCEDURE {DELEGATE} (instance: Instance): BOOLEAN;
	TypeMethod*= PROCEDURE {DELEGATE} (type: Type): BOOLEAN;

	Scope*=OBJECT (Symbol)
	VAR
		symbols-: SymbolList;
		instances-: InstanceList;
		channels-: ChannelList;
		types-: TypeList;
		ports-: PortList;
		index-: LONGINT;
		specification-: Specification;

		PROCEDURE &InitScope(CONST name: ARRAY OF CHAR; scope: Scope; specification: Specification);
		BEGIN
			COPY(name,SELF.name); SELF.specification := specification;
			NEW(instances,4); NEW(channels,4);
			NEW(ports,4); NEW(types,4);
			NEW(symbols,4);
			index := -1;
		END InitScope;

		PROCEDURE Same(as: Symbol; flags: SET): BOOLEAN;
		BEGIN
			IF TraceSame THEN TRACE("Scope",name) END;
			IF (as = NIL) OR ~(as IS Scope) THEN RETURN FALSE END;
			WITH as: Scope DO
				IF ~symbols.Same(as.symbols, flags) THEN RETURN FALSE END;
				IF ~instances.Same(as.instances, flags) THEN RETURN FALSE END;
				IF ~channels.Same(as.channels, flags) THEN RETURN FALSE END;
				IF ~types.Same(as.types, flags) THEN RETURN FALSE END;
				IF ~ports.Same(as.ports, flags) THEN RETURN FALSE END;
			END;
			RETURN Same^(as, flags)
		END Same;

		PROCEDURE FindSymbol(CONST name: ARRAY OF CHAR; traverse: BOOLEAN): Symbol;
		VAR symbol: Symbol;
		BEGIN
			symbol := symbols.ByName(name);
			IF (symbol = NIL) & (scope # NIL) & traverse THEN RETURN scope.FindSymbol(name,TRUE)
			ELSE RETURN symbol;
			END;
		END FindSymbol;

		PROCEDURE NewInstance*(CONST name: ARRAY OF CHAR; type: Type): Instance;
		VAR instance: Instance;
		BEGIN
			NEW(instance, name, SELF, type);
			instances.AddInstance(instance);
			symbols.AddSymbol(instance);
			RETURN instance
		END NewInstance;

		(* generate a new channel, may be overwritten by implementations if a non-default channel object has to be installed *)
		PROCEDURE NewChannel*(): Channel;
		VAR channel: Channel; name: Name;
		BEGIN
			name := "@Channel"; Basic.AppendNumber(name,channels.Length());
			NEW(channel,name,SELF);
			channels.AddChannel(channel);
			symbols.AddSymbol(channel);
			RETURN channel;
		END NewChannel;

		(* generate a new port, may be overwritten by implementations if a non-default port object has to be installed *)
		PROCEDURE NewPort*(CONST name: ARRAY OF CHAR; direction: LONGINT; adr: LONGINT): Port;
		VAR port: Port;
		BEGIN
			NEW(port, name,SELF, direction,adr);
			ports.AddPort(port);
			symbols.AddSymbol(port);
			RETURN port
		END NewPort;

		(* generate a new type, may be overwritten by implementations if a non-default type object has to be installed *)
		PROCEDURE NewType*(CONST name: ARRAY OF CHAR): Type;
		VAR type: Type;
		BEGIN
			NEW(type,name,SELF);
			types.AddType(type);
			symbols.AddSymbol(type);
			 RETURN type
		END NewType;

		PROCEDURE ForEachInstanceDo*(method: InstanceMethod): BOOLEAN;
		VAR i: LONGINT; instance: Instance; type: Type;
		BEGIN
			FOR i := 0 TO instances.Length()-1 DO
				instance := instances.GetInstance(i);
				IF ~method(instance) THEN RETURN FALSE END;
			END;
			(*
			FOR i := 0 TO types.Length()-1 DO
				type := types.GetType(i);
				IF ~type.ForEachInstanceDo(method) THEN RETURN FALSE END
			END;
			*)
			RETURN TRUE
		END ForEachInstanceDo;


		PROCEDURE ForEachTypeDo*(method: TypeMethod): BOOLEAN; (* used for linking *)
		VAR type: Type; i: LONGINT;
		BEGIN
			FOR i := 0 TO types.Length()-1 DO
				type := types.GetType(i);
				IF ~method(type) THEN RETURN FALSE END;
				IF ~type.ForEachTypeDo(method) THEN RETURN FALSE END; (* subtypes *)
			END;
			RETURN TRUE
		END ForEachTypeDo;

		(*
		PROCEDURE Link*(diagnostics: Diagnostics.Diagnostics; codeUnit, dataUnit: LONGINT): BOOLEAN;
		VAR type: Type; i: LONGINT;
		BEGIN
			FOR i := 0 TO types.Length()-1 DO
				type := types.GetType(i);
				IF type.instances.Length()=0 THEN
					IF ~type.LinkType(diagnostics, codeUnit, dataUnit) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
				ELSE
					type.SetDataMemorySize(0);
				END;
				IF ~type.Link(diagnostics, codeUnit, dataUnit) THEN RETURN FALSE END; (* subtypes ? *)
			END;
			RETURN TRUE
		END Link;
		*)

	END Scope;

	(*
		definition of a (virtual) computing node (processor)
		- represented by ACTOR or ASSEMBLY (-> virtual) in source code
		- represented as processor (if ACTOR) and as network or processors (if ASSEMBLY) in hardware
	*)
	Type*=OBJECT (Scope)
	VAR
		devices-: DeviceList;
		modules-: ModuleList; (* for linking / compiling *)
		instructionMemorySize-, dataMemorySize-: LONGINT; (* sizes in units *)
		capabilities-: SET;

		PROCEDURE Same(as: Symbol; flags: SET): BOOLEAN;
		BEGIN
			IF TraceSame THEN TRACE("Type",name) END;
			IF (as = NIL) OR ~(as IS Type) THEN RETURN FALSE END;
			WITH as: Type DO
				IF ~devices.Same(as.devices, flags) THEN RETURN FALSE END;
				IF (CheckModules IN flags) & ~modules.Same(as.modules, flags) THEN RETURN FALSE END;
				IF (instructionMemorySize # as.instructionMemorySize) THEN RETURN FALSE END;
				IF (dataMemorySize # as.dataMemorySize) THEN RETURN FALSE END;
				IF (capabilities # as.capabilities) THEN RETURN FALSE END;
			END;
			RETURN TRUE (*RETURN Same^(as, flags)*)
		END Same;


		PROCEDURE & InitType*(CONST name: ARRAY OF CHAR; scope: Scope);
		BEGIN
			InitScope(name,scope,scope.specification);
			ASSERT(specification # NIL);
			instructionMemorySize := defaultInstructionMemorySize;
			dataMemorySize := defaultDataMemorySize;
			NEW(devices,4);
			NEW(modules,4);
			SELF.scope := scope;
			capabilities := {};
		END InitType;

		PROCEDURE AddCapability*(capability: LONGINT);
		BEGIN
			INCL(capabilities, capability);
		END AddCapability;

		PROCEDURE SetInstructionMemorySize*(value: LONGINT);
		BEGIN instructionMemorySize := value
		END SetInstructionMemorySize;

		PROCEDURE SetDataMemorySize*(value: LONGINT);
		BEGIN dataMemorySize := value
		END SetDataMemorySize;

		(* generate a new device, may be overwritten by implementations if a non-default device object has to be installed *)
		PROCEDURE NewDevice*(CONST name: ARRAY OF CHAR; adr: LONGINT): Device;
		VAR device: Device;
		BEGIN
			NEW(device,name,SELF, adr);
			devices.AddDevice(device);
			symbols.AddSymbol(device);
			RETURN device;
		END NewDevice;

		PROCEDURE NewModule*(CONST moduleName, fileName: ARRAY OF CHAR): Module;
		VAR module: Module;
		BEGIN
			NEW(module, moduleName, SELF, fileName);
			modules.AddModule(module);
			symbols.AddSymbol(module);
			RETURN module;
		END NewModule;



		(*
		PROCEDURE ThisPort(CONST name: ARRAY OF CHAR): Port;
		VAR type: Type; port:Port; i: LONGINT;
		BEGIN
			(*! suboptimal, replace by two-staged version *)
			FOR i := 0 TO subTypes.Length()-1 DO
				type := subTypes.GetType(i);
				port := type.ports.ByName(name);
				IF port # NIL THEN RETURN port END;
			END;
			RETURN NIL
		END ThisPort;
		*)
		(* moved to compiler driver
		PROCEDURE LinkType*(diagnostics: Diagnostics.Diagnostics; codeUnit, dataUnit: LONGINT): BOOLEAN;
		VAR
			fileName, codeFileName, dataFileName: Files.FileName;
			code, data: StaticLinker.Arrangement; linker: GenericLinker.Linker;
			module: Module;
			linkRoot,msg: SyntaxTree.String;
			i: LONGINT;
			logFile: Files.File; linkerLog: Files.Writer;
		BEGIN
			NEW (code, 0);
			NEW (data, 0);
			NEW (linker, diagnostics, linkerLog, FALSE (* useAll *), FALSE (* stripInitCodes *), code, data);
			GetFullName(msg,NIL);
			Strings.Append(msg,".log");
			logFile := Files.New(msg);
			IF logFile # NIL THEN NEW(linkerLog,logFile,0) ELSE logFile := NIL END;
			GetFullName(linkRoot,NIL);
			Strings.Append(linkRoot,".@BodyStub");
			linker.SetLinkRoot(linkRoot);
			FOR i := 0 TO modules.Length()-1 DO
				module := modules.GetModule(i);
				StaticLinker.ReadObjectFile(module.name, "",ObjectFileExtension,linker);
			END;

			(* do linking after having read in all blocks to account for potential constraints *)
			IF ~linker.error THEN linker.Link; END;

			instructionMemorySize := MAX(code.SizeInBits() DIV codeUnit, instructionMemorySize);
			dataMemorySize := MAX(data.SizeInBits() DIV dataUnit, dataMemorySize);

			GetFullName(fileName,NIL);
			Files.JoinExtension(fileName,CodeFileExtension,codeFileName);
			Files.JoinExtension(fileName,DataFileExtension,dataFileName);

			IF ~linker.error THEN
				StaticLinker.WriteOutputFile (code, codeFileName, linker, StaticLinker.WriteTRMCodeFile);
				StaticLinker.WriteOutputFile (data, dataFileName, linker, StaticLinker.WriteTRMDataFile);
				GetFullName(msg,NIL); Strings.Append(msg," successfully linked");
				IF linkerLog # NIL THEN linkerLog.Update; Files.Register(logFile) END;
				IF specification.log # NIL THEN specification.log.String(msg); specification.log.Ln END;
			ELSE
				msg := "could not link ";
				Strings.Append(msg,linkRoot);
				 FOR i := 0 TO modules.Length()-1 DO
				 	module := modules.GetModule(i);
				 	Strings.Append(msg," "); Strings.Append(msg,module.name);
				 END;
				 diagnostics.Error("",Diagnostics.Invalid, Diagnostics.Invalid, msg);
			END;
			RETURN ~linker.error
		END LinkType;
		*)

		PROCEDURE Read(r: Streams.Reader): BOOLEAN;
		VAR port: Port; module: Module; device: Device; i,number: LONGINT;
			channel: Channel; instance: Instance; type: Type;
		BEGIN
			IF ~r.GetInteger(i,FALSE) OR (index # i) OR
				~CheckItem(r,"name") OR  ~GetString(r,name) OR
			~CheckItem(r,"instructionMemorySize") OR ~r.GetInteger(instructionMemorySize,FALSE) OR
			~CheckItem(r,"dataMemorySize") OR ~r.GetInteger(dataMemorySize,FALSE) OR
			~CheckItem(r,"capabilities") OR ~GetSet(r,capabilities) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			IF ~CheckItem(r,"types") OR ~r.GetInteger(number,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			FOR i := 0 TO number-1 DO
				type := NewType("");
				IF ~type.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			END;
			IF ~CheckItem(r,"instances") OR ~r.GetInteger(number,FALSE)
			THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END
			END;
			FOR i := 0 TO number-1 DO
				instance := NewInstance("",NIL);
				IF ~instance.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			END;
			IF ~CheckItem(r,"ports")OR ~ r.GetInteger(number,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			FOR i := 0 TO number-1 DO
				port := NewPort("",0,0);
				IF ~port.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			END;
			IF ~CheckItem(r,"modules")OR ~ r.GetInteger(number,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			FOR i := 0 TO number-1 DO
				module := NewModule("","");
				IF ~module.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			END;
			IF ~CheckItem(r,"devices")OR ~ r.GetInteger(number,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			FOR i := 0 TO number-1 DO
				device := NewDevice("",0);
				IF ~device.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			END;
			IF ~CheckItem(r,"channels") OR ~ r.GetInteger(number,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			FOR i := 0 TO number-1 DO
				channel := NewChannel();
				IF ~channel.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			END;
			RETURN TRUE
		END Read;

		PROCEDURE Write*(w: Streams.Writer; indent: LONGINT);
		VAR port: Port; device: Device; module: Module; instance: Instance; channel: Channel; type: Type; i: LONGINT;
		BEGIN
			Indent(w,indent); INC(indent);
			w.Int(index,1);
			w.String(" name="); w.String(name);
			w.String(" instructionMemorySize="); w.Int(instructionMemorySize,1);
			w.String(" dataMemorySize="); w.Int(dataMemorySize,1);
			w.String(" capabilities="); WriteSet(w, capabilities);
			w.Ln;
			(* sub types first because of potential delegates on ports *)
			Indent(w,indent); w.String("types=");w.Int(types.Length(),1); w.Ln;
			FOR i := 0 TO types.Length()-1 DO
				type := types.GetType(i);
				type.Write(w,indent+1);
			END;
			Indent(w,indent);
			w.String("instances=");w.Int(instances.Length(),1); w.Ln;
			FOR i := 0 TO instances.Length()-1 DO
				instance := instances.GetInstance(i);
				instance.Write(w,indent+1);
			END;
			Indent(w,indent);
			w.String("ports=");w.Int(ports.Length(),1); w.Ln;
			FOR i := 0 TO ports.Length()-1 DO
				port := ports.GetPort(i);
				port.Write(w,indent+1);
			END;
			Indent(w,indent);
			w.String("modules="); w.Int(modules.Length(),1);  w.Ln;
			FOR i := 0 TO modules.Length()-1 DO
				module := modules.GetModule(i);
				module.Write(w,indent+1);
			END;
			Indent(w,indent);
			w.String("devices="); w.Int(devices.Length(),1); w.Ln;
			FOR i := 0 TO devices.Length()-1 DO
				device := devices.GetDevice(i);
				device.Write(w,indent+1);
			END;
			Indent(w,indent);
			w.String("channels=");w.Int(channels.Length(),1); w.Ln;
			FOR i := 0 TO channels.Length()-1 DO
				channel := channels.GetChannel(i);
				channel.Write(w,indent+1);
			END;
			w.Update;
		END Write;

	END Type;

	TypeList*= OBJECT(Basic.List)

		PROCEDURE GetType*(i: LONGINT): Type;
		VAR a: ANY;
		BEGIN
			a := Get(i); IF a = NIL THEN RETURN NIL ELSE RETURN a(Type) END
		END GetType;

		PROCEDURE AddType(a: Type);
		BEGIN a.index := Length(); Add(a);
		END AddType;

		PROCEDURE ByName*(CONST name: ARRAY OF CHAR): Type;
		VAR a: Type; i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				a := GetType(i);
				IF (a # NIL) & (a.name = name) THEN RETURN a END;
			END;
			RETURN NIL
		END ByName;

		PROCEDURE Same(as: TypeList; flags: SET): BOOLEAN;
		VAR i: LONGINT; left, right: Type;
		BEGIN
			IF as.Length() # Length() THEN RETURN FALSE END;
			FOR i := 0 TO Length()-1 DO
				left := GetType(i);
				right := as.GetType(i);
				IF ~left.Same(right, flags) THEN RETURN FALSE END;
			END;
			RETURN TRUE
		END Same;

	END TypeList;

	(*
		channel defines the channel between ports
		- defined by CONNECT in source code
		- represented as FIFO in hardware
	*)
	Channel*=OBJECT (Symbol)
	VAR
		in-, out-: PortInstance;
		fifoSize-: LONGINT;
		widthInBits-: LONGINT;
		index-: LONGINT; (* useful for implementations that emulate channels (simulator) *)


		PROCEDURE Same(as: Symbol; flags: SET): BOOLEAN;
		BEGIN
			IF TraceSame THEN TRACE("Channel",name) END;
			IF (as = NIL) OR ~(as IS Channel) THEN RETURN FALSE END;
			WITH as: Channel DO
				IF ~in.instance.Same(as.in.instance, flags) THEN RETURN FALSE END;
				IF ~in.port.Same(as.in.port, flags) THEN RETURN FALSE END;
				IF ~out.instance.Same(as.out.instance, flags) THEN RETURN FALSE END;
				IF ~out.port.Same(as.out.port, flags) THEN RETURN FALSE END;
				IF widthInBits # as.widthInBits THEN RETURN FALSE END;
				IF index # as.index THEN RETURN FALSE END;
			END;
			RETURN Same^(as, flags)
		END Same;

		PROCEDURE & InitChannel(CONST name: ARRAY OF CHAR; scope: Scope);
		BEGIN
			InitSymbol(name,scope);
			fifoSize := defaultFifoSize;
			widthInBits := defaultChannelWidth;
			in.port := NIL; in.instance := NIL;
			out.port := NIL; out.instance := NIL;
			SELF.index := -1;
		END InitChannel;

		PROCEDURE ConnectIn*(instance: Instance; port: Port);
		BEGIN in.port := port; in.instance := instance;
		END ConnectIn;

		PROCEDURE ConnectOut*(instance: Instance; port: Port);
		BEGIN out.port := port; out.instance := instance;
		END ConnectOut;

		PROCEDURE SetFifoSize*(size: LONGINT);
		BEGIN fifoSize := size
		END SetFifoSize;

		PROCEDURE SetWidth*(width: LONGINT);
		BEGIN widthInBits := width
		END SetWidth;

		PROCEDURE Read(r: Streams.Reader): BOOLEAN;
		VAR s: Name; i: LONGINT;
		BEGIN
			IF ~r.GetInteger(i,FALSE) OR (i#index) OR
			~CheckItem(r,"name") OR ~GetString(r,name) OR
			~CheckItem(r,"outInstance") OR ~ GetString(r,s) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			IF s#"NIL" THEN out.instance := scope.instances.ByName(s) END;
			IF ~CheckItem(r,"outPort") OR ~GetString(r,s) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			IF s#"NIL" THEN out.port := out.instance.instanceType.ports.ByName(s) END;
			IF ~CheckItem(r,"inInstance") OR ~ GetString(r,s) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			IF s#"NIL" THEN in.instance := scope.instances.ByName(s) END;
			IF ~CheckItem(r,"inPort")OR ~GetString(r,s) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			IF s#"NIL" THEN	in.port := in.instance.instanceType.ports.ByName(s) END;
			IF ~CheckItem(r,"size")OR ~r.GetInteger(i,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			fifoSize := i;
			IF ~CheckItem(r,"width")OR ~r.GetInteger(i,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			widthInBits := i;
			RETURN TRUE
		END Read;

		PROCEDURE Write*(w: Streams.Writer; indent: LONGINT);
		BEGIN
			Indent(w,indent);
			w.Int(index,1);
			w.String(" name="); w.String(name);
			w.String(" outInstance="); IF out.instance = NIL THEN w.String("NIL") ELSE w.String(out.instance.name) END;
			w.String(" outPort="); IF out.port = NIL THEN w.String("NIL") ELSE w.String(out.port.name) END;
			w.String(" inInstance="); IF in.instance = NIL THEN w.String("NIL") ELSE w.String(in.instance.name) END;
			w.String(" inPort="); IF in.port = NIL THEN w.String("NIL") ELSE w.String(in.port.name) END;
			w.String(" size="); w.Int(fifoSize,1);
			w.String(" width="); w.Int(widthInBits,1);
			w.Ln;w.Update;
		END Write;

	END Channel;

	ChannelList*= OBJECT(Basic.List)

		PROCEDURE GetChannel*(i: LONGINT): Channel;
		VAR a: ANY;
		BEGIN
			a := Get(i); IF a = NIL THEN RETURN NIL ELSE RETURN a(Channel) END
		END GetChannel;

		PROCEDURE AddChannel*(a: Channel);
		BEGIN a.index := Length(); Add(a);
		END AddChannel;

		PROCEDURE ByName*(CONST name: ARRAY OF CHAR): Channel;
		VAR a: Channel; i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				a := GetChannel(i);
				IF (a # NIL) & (a.name = name)  THEN RETURN a END;
			END;
			RETURN NIL
		END ByName;

		PROCEDURE ByPort*(port: Port): Channel;
		VAR a: Channel; i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				a := GetChannel(i);
				IF (a # NIL) & (a.in.port = port) OR (a.out.port=port) THEN RETURN a END;
			END;
			RETURN NIL
		END ByPort;

		PROCEDURE Same(as: ChannelList; flags: SET): BOOLEAN;
		VAR i: LONGINT; left, right: Channel;
		BEGIN
			IF as.Length() # Length() THEN RETURN FALSE END;
			FOR i := 0 TO Length()-1 DO
				left := GetChannel(i);
				right := as.GetChannel(i);
				IF ~left.Same(right, flags) THEN RETURN FALSE END;
			END;
			RETURN TRUE
		END Same;


	END ChannelList;

	(*
		a specification is a collection of actors together with factory procedures to build hardware
		- represented as IMPORT in source code
		- to build hardware scripts generating hardware
	*)
	Specification*=OBJECT (Scope) (* specification object including hardware factory *)
	VAR
		instructionSet-: Name;

		diagnostics-: Diagnostics.Diagnostics;
		log-: Streams.Writer;
		supportedDevices-: DeviceList;
		imports-: SymbolList;
		frequencyDivider-: LONGINT;

		PROCEDURE AddDevice*(CONST name: ARRAY OF CHAR; adr: HUGEINT);
		VAR device: Device;
		BEGIN
			NEW(device, name, SELF, LONGINT(adr)); supportedDevices.AddDevice(device);
		END AddDevice;

		PROCEDURE Same*(as: Symbol; flags: SET): BOOLEAN;
		VAR i: LONGINT;
		BEGIN
			IF TraceSame THEN TRACE("SameSpecification", name) END;
			IF (as = NIL) OR ~(as IS Specification) THEN RETURN FALSE END;
			WITH as: Specification DO
				IF as.instructionSet # instructionSet THEN RETURN FALSE END;
				IF ~imports.Same(as.imports,flags) THEN RETURN FALSE END;
				IF frequencyDivider # as.frequencyDivider THEN RETURN FALSE END;
			END;
			RETURN Same^(as, flags);
		END Same;

		PROCEDURE DefineDevices*(system: Global.System);
		VAR i: LONGINT; device: Device;
		BEGIN
			FOR i := 0 TO supportedDevices.Length()-1 DO
				device := supportedDevices.GetDevice(i);
				system.AddCapability(Basic.MakeString(device.name));
			END;
		END DefineDevices;

		PROCEDURE & Init*(CONST name: ARRAY OF CHAR; diagnostics: Diagnostics.Diagnostics; log: Streams.Writer);
		VAR device: Device;
		BEGIN
			InitScope(name,NIL,SELF);
			instructionSet := "UNDEFINED";
			NEW(supportedDevices,4);
			SELF.diagnostics := diagnostics;
			SELF.log := log;

			AddDevice("DDR", 0FFCAH);
			AddDevice("RS232",0FFFFFFC4H);

			AddDevice("LCD", 0FFFFFFC8H);
			AddDevice("LEDDigits", 0FFFFFFC8H);

			AddDevice("CF", 0FFFFFFCCH);
			AddDevice("LED", 0FFFFFFC7H);
			AddDevice("TIMER", 0FFFFFFC6H);
			(*AddDevice("PORT",0FF10H); *)
			AddDevice("PORT", 0FFFFFFE0H);
			AddDevice("Switch", 0FFFFFFC7H);
			AddDevice("Wheel", 0FFFFFFCAH);
			AddDevice("PersistentSwitch", 0FFFFFFCBH);
			AddDevice("Motor",0FFFFFFCEH);
			AddDevice("BraceletSPI",0FFFFFFD2H);
			AddDevice("GPI",0FFFFFFD6H);
			AddDevice("GPO",0FFFFFFD6H);
			AddDevice("WDT", 0FFFFFFD8H); (*watch dog timer*)
			AddDevice("SPI", 0FFFFFFD4H); (*ROBOT SPI on ML510*)
			NEW(imports,4);
			frequencyDivider := 1;
		END Init;

		(*! this is a bit quick and dirty, think about general concepts of such parameters *)
		PROCEDURE SetFrequencyDivider*(divider: LONGINT);
		BEGIN frequencyDivider := divider
		END SetFrequencyDivider;

		PROCEDURE AddImport*(CONST name: ARRAY OF CHAR);
		VAR import: Specification;
		BEGIN
			IF imports.ByName(name) = NIL THEN
				import := LoadSpecification(name,NIL,NIL);
				IF import # NIL THEN imports.Add(import); symbols.Add(import) END;
			END;
		END AddImport;

		PROCEDURE SetInstructionSet*(CONST instructionSet: ARRAY OF CHAR);
		BEGIN
			COPY(instructionSet,SELF.instructionSet);
		END SetInstructionSet;

		PROCEDURE Write*(w: Streams.Writer; indent: LONGINT);
		VAR type: Type; channel: Channel; i: LONGINT; instance: Instance;port: Port; import: Symbol;
		BEGIN
			Indent(w,indent);w.String("name="); w.String(name); w.Ln;
			INC(indent);
			Indent(w,indent); w.String("instructionSet="); w.String(instructionSet); w.Ln;
			Indent(w,indent); w.String("frequencyDivider="); w.Int(frequencyDivider,1); w.Ln;
			Indent(w,indent); w.String("imports="); w.Int(imports.Length(),1); w.Ln;
			FOR i := 0 TO imports.Length()-1 DO
				import := imports.GetSymbol(i);
				Indent(w,indent+1); w.String(import.name); w.Ln;
			END;
			Indent(w,indent); w.String("types=");w.Int(types.Length(),1); w.Ln;
			FOR i := 0 TO types.Length()-1 DO
				type := types.GetType(i);
				type.Write(w,indent+1);
			END;
			(* sub types first because of potential delegates on ports *)
			Indent(w,indent); w.String("instances=");w.Int(instances.Length(),1); w.Ln;
			FOR i := 0 TO instances.Length()-1 DO
				instance := instances.GetInstance(i);
				instance.Write(w,indent+1);
			END;
			Indent(w,indent); w.String("ports=");w.Int(ports.Length(),1); w.Ln;
			FOR i := 0 TO ports.Length()-1 DO
				port := ports.GetPort(i);
				port.Write(w,indent+1);
			END;
			Indent(w,indent); w.String("channels=");w.Int(channels.Length(),1); w.Ln;
			FOR i := 0 TO channels.Length()-1 DO
				channel := channels.GetChannel(i);
				channel.Write(w,indent+1);
			END;
			w.Update;
		END Write;

		PROCEDURE Read*(r: Streams.Reader): BOOLEAN;
		VAR i, number: LONGINT; type: Type;
			instance: Instance; port: Port; channel: Channel; importName: Name;
		BEGIN
			IF ~CheckItem(r,"name") OR ~GetString(r,name) OR
			~CheckItem(r,"instructionSet") OR ~GetString(r,instructionSet) OR
			~CheckItem(r,"frequencyDivider") OR ~r.GetInteger(frequencyDivider,FALSE) OR
			~CheckItem(r,"imports") OR ~r.GetInteger(number,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			FOR i := 0 TO number-1 DO
				IF ~GetString(r,importName) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
				AddImport(importName);
			END;
			IF ~CheckItem(r,"types") OR ~r.GetInteger(number,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			FOR i := 0 TO number-1 DO
				type := NewType("");
				IF ~type.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			END;
			IF ~CheckItem(r,"instances") OR ~r.GetInteger(number,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			FOR i := 0 TO number-1 DO
				instance := NewInstance("",NIL);
				IF ~instance.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			END;
			IF ~CheckItem(r,"ports")OR ~r.GetInteger(number,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			FOR i := 0 TO number-1 DO
				port := NewPort("",0,0);
				IF ~port.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			END;
			IF ~CheckItem(r,"channels") OR ~r.GetInteger(number,FALSE) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			FOR i := 0 TO number-1 DO
				channel := NewChannel();
				IF ~channel.Read(r) THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			END;
			RETURN TRUE
		END Read;

		PROCEDURE GetPortAddress*(number: LONGINT): LONGINT;
		BEGIN
			RETURN BasePortAddress+2*number;
		END GetPortAddress;

		PROCEDURE Emit*(): BOOLEAN; (* to be overwritten by implementers *)
		VAR w: Files.Writer; f: Files.File; fileName: Files.FileName; msg: Name;
		BEGIN
			FlattenNetwork(SELF);
			Files.JoinExtension(SELF.name,SpecificationFileExtension,fileName);
			f := Files.New(fileName);
			IF f # NIL THEN
				NEW(w,f,0);
				Write(w,0);
				w.Update;
				Files.Register(f);

				msg := "Wrote Active Cells specification to file "; Strings.Append(msg, fileName);
				IF log # NIL THEN log.String(msg); log.Ln; END;
				RETURN TRUE
			ELSE
				diagnostics.Error(fileName,Diagnostics.Invalid, Diagnostics.Invalid,"could not generate file");
				IF TraceError THEN HALT(100) ELSE RETURN FALSE END
			END;
		END Emit;

	END Specification;


	(*
	PROCEDURE ReadHugeint(r: Streams.Reader; VAR x: HUGEINT): BOOLEAN;
	VAR low, high: LONGINT;
	BEGIN
		IF r.GetInteger(high, FALSE) & r.GetInteger(low, FALSE) THEN
			x := high * 100000000H + low;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END ReadHugeint;

	PROCEDURE WriteHugeint(r: Streams.Writer; x: HUGEINT);
	VAR low, high: LONGINT;
	BEGIN
		low := SHORT(x); high := SHORT(x DIV 100000000H);
		r.Int(high,1); r.String(" "); r.Int(low,1);
	END WriteHugeint;
	*)

	PROCEDURE Indent(w: Streams.Writer; indent: LONGINT);
	BEGIN
		WHILE indent > 0 DO
			w.String("  ");
			DEC(indent);
		END;
	END Indent;

	PROCEDURE CheckItem(VAR r: Streams.Reader; CONST name: ARRAY OF CHAR): BOOLEAN;
	VAR i: LONGINT; ch: CHAR; b: BOOLEAN;
	BEGIN
		i := 0;
		b := r.GetChar(ch);
		WHILE (r.res=Streams.Ok) & (ch # "=") DO
			IF name[i] # ch THEN IF TraceError THEN HALT(100) ELSE RETURN FALSE END END;
			INC(i);
			r.Char(ch);
		END;
		RETURN TRUE
	END CheckItem;

	PROCEDURE GetString(VAR r: Streams.Reader; VAR name: ARRAY OF CHAR): BOOLEAN;
	VAR c: CHAR;
	BEGIN
		c := r.Peek();
		IF r.GetString(name) THEN RETURN TRUE
		ELSE RETURN (name[0]=0X) & (c="'") OR (c='"')
		END;
	END GetString;

	PROCEDURE GetSet(VAR r: Streams.Reader; VAR set: SET): BOOLEAN;
	VAR int: LONGINT;
	BEGIN
		IF r.GetInteger(int, FALSE) THEN set := SYSTEM.VAL(SET, int); RETURN TRUE ELSE RETURN FALSE END;
	END GetSet;

	PROCEDURE WriteSet(VAR r: Streams.Writer; set: SET);
	VAR int: LONGINT;
	BEGIN
		int := SYSTEM.VAL(LONGINT, set);
		r.Int(int,1);
	END WriteSet;

	(**
		Load an ActiveCells specification
		name - specification name, with or without suffix ".spec"
	*)
	PROCEDURE LoadSpecification*(CONST name: ARRAY OF CHAR; diagnostics: Diagnostics.Diagnostics; log: Streams.Writer): Specification;
	VAR fileName: Files.FileName; spec: Specification; f: Files.File; r: Files.Reader;
	BEGIN
		COPY(name,fileName);
		Strings.Append(fileName,".spec");
		f := Files.Old(fileName);
		(*
		IF f = NIL THEN
			COPY(name, fileName);
			f := Files.Old(fileName);
		END;
		*)

		IF f = NIL THEN IF log # NIL THEN log.String("could not load specification "); log.String(name); log.Ln END; RETURN NIL END;

		NEW(spec, "", diagnostics, log);
		NEW(r,f,0);
		IF spec.Read(r) THEN
			RETURN spec
		ELSE
			RETURN NIL
		END;
	END LoadSpecification;

	PROCEDURE ReadSpecification*(context: Commands.Context);
	VAR fileName: Files.FileName; r: Files.Reader; specification: Specification;f : Files.File; b: BOOLEAN; diagnostics: Diagnostics.StreamDiagnostics;
	BEGIN
		b := context.arg.GetString(fileName);
		NEW(diagnostics, context.error);
		specification := LoadSpecification(fileName, diagnostics, context.out);
		IF specification # NIL THEN
			specification.Write(context.out,0);
		END;
	END ReadSpecification;

	PROCEDURE CompareSpecification*(context: Commands.Context);
	VAR fileName: Files.FileName; spec1, spec2: Specification; b: BOOLEAN;
	BEGIN
		b := context.arg.GetString(fileName);
		spec1 :=  LoadSpecification(fileName, NIL, context.error);
		IF spec1 = NIL THEN context.error.String("could not load specification "); context.error.String(fileName); RETURN END;
		b := context.arg.GetString(fileName);
		spec2 := LoadSpecification(fileName, NIL, context.error);
		IF spec2 = NIL THEN context.error.String("could not load specification "); context.error.String(fileName); RETURN END;
		IF spec1.Same(spec2, {}) THEN context.out.String("Specifications are equal") ELSE context.out.String("specifications are not equal"); END;
	END CompareSpecification;



	(*
	(**
		Load an ActiveCells specification

		platformId - string ID of the platform to use
		name - specification name
	*)
	PROCEDURE LoadSpecification*(CONST platformId: ARRAY OF CHAR; CONST name: ARRAY OF CHAR; diagnostics: Diagnostics.Diagnostics; log: Streams.Writer): Specification;
	VAR
		platform: PlatformDesc;
		fileName: Files.FileName;
		mod: Modules.Module;
		res: LONGINT;
		msg: ARRAY 8 OF CHAR;
	BEGIN

		Strings.Concat("Fox",platformId,fileName);
		IF Modules.ModuleByName(fileName) = NIL THEN (* if platform module is not loaded - try to load it *)
			mod := Modules.ThisModule(fileName,res,msg);
		END;

		COPY(name,fileName);
		Strings.Append(fileName,".spec");

		platform := GetPlatform(platformId); ASSERT(platform # NIL);
		RESULT := platform.specLoader(fileName,diagnostics,log);

		RETURN RESULT;
	END LoadSpecification;

	(** Register an ActiveCells hardware platform *)
	PROCEDURE RegisterPlatform*(platformDesc: PlatformDesc);
	VAR i: LONGINT;
	BEGIN
		ASSERT(platformDesc # NIL);
		ASSERT(platformDesc.platformId # NIL);
		ASSERT(platformDesc.specLoader # NIL);

		i := 0;
		WHILE (i < platforms.Length()) & (platforms.Get(i)(PlatformDesc).platformId^ # platformDesc.platformId^) DO
			INC(i);
		END;

		IF i < platforms.Length() THEN RETURN; END; (* do not allow registering same platform twice! *)

		platforms.Add(platformDesc);

		D.String("registered ActiveCells hardware platform "); D.String(platformDesc.platformId^); D.Ln;
	END RegisterPlatform;

	(** Get an ActiveCells hardware platform descriptor given the platform ID string *)
	PROCEDURE GetPlatform*(CONST platformId: ARRAY OF CHAR): PlatformDesc;
	VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE (i < platforms.Length()) & (platforms.Get(i)(PlatformDesc).platformId^ # platformId) DO
			INC(i);
		END;

		IF i < platforms.Length() THEN
			RETURN platforms.Get(i)(PlatformDesc);
		ELSE
			RETURN platform;
		END;
	END GetPlatform;

	PROCEDURE LoadSpecificationDefault(CONST name: ARRAY OF CHAR; diagnostics: Diagnostics.Diagnostics; log: Streams.Writer): Specification;
	VAR r: Files.Reader;  specification: Specification; f: Files.File;
	BEGIN
		specification := NIL;
		f := Files.Old(name);
		IF f # NIL THEN NEW(r,f,0); NEW(specification,"",diagnostics,log);
			IF ~specification.Read(r) THEN specification := NIL END;
		END;
		RETURN specification
	END LoadSpecificationDefault;

	*)

	PROCEDURE GetSymbol*(scope: Scope; CONST name: ARRAY OF CHAR): Symbol;
	VAR scopeName: Name; i,j: LONGINT; symbol: Symbol; first: BOOLEAN;
	BEGIN
		i := 0; first := TRUE;
		WHILE (scope # NIL) & (name[i] # 0X) DO
			j := 0;
			WHILE (name[i] # 0X) & (name[i] # ".") DO
				scopeName[j] := name[i];
				INC(i); INC(j);
			END;
			scopeName[j] := 0X; INC(i);
			(*
			D.String("find symbol : "); D.String(scopeName); D.Ln;
			*)
			symbol := scope.FindSymbol(scopeName, first); first := FALSE;
			IF (symbol # NIL) & (symbol IS Scope) THEN scope := symbol(Scope)
			ELSE scope := NIL
			END;
		END;
		IF name[i] # 0X THEN RETURN NIL ELSE RETURN symbol END;
	END GetSymbol;
	
	PROCEDURE Clone*(symbol: Symbol): Symbol;
	BEGIN
		RETURN symbol;
		(* does nothing -- for compatibility with ActiveCells2 *)
	END Clone;
	

	PROCEDURE FlattenNetwork*(scope: Scope);
	VAR instance,subInstance,newInstance: Instance; oldChannel,channel: Channel;
		 instances: InstanceList; channels: ChannelList;
		 i,j: LONGINT; name: SyntaxTree.String;
		 port: Port;

		 PROCEDURE FlattenPortInstance(VAR pi: PortInstance);
		 VAR name: Name; port, prevPort: Port; instance: Instance;
		 BEGIN
		 	IF pi.port # NIL THEN
			 	port := pi.port.delegate.port;
			 	IF port # NIL THEN
				 	instance := pi.port.delegate.instance;
				 	ASSERT(instance # NIL);
			 		COPY(pi.instance.name,name);
			 		(* iteratively resolve port delegation and build local instance name *)
			 		WHILE  port # NIL DO
			 			prevPort := port;
			 			ASSERT(instance # NIL);
				 		Strings.Append(name,"."); Strings.Append(name,instance.name);
				 		instance := port.delegate.instance;
				 		port := port.delegate.port;
				 	END;
				 	port := prevPort;
				 	instance := instances.ByName(name);
				 	ASSERT(port # NIL);
				 	ASSERT(instance # NIL);
				 	pi.instance := instance;
				 	pi.port := port;
			 	END;
			 END;
		 END FlattenPortInstance;

		 PROCEDURE EmbedInstance(instance: Instance; VAR subInstance: Instance): Instance;
		 VAR name: Name; newInstance: Instance; i: LONGINT; parameter,newParameter: Parameter;
		 BEGIN
		 	COPY(instance.name, name); Strings.Append(name,"."); Strings.Append(name,subInstance.name);
		 	newInstance := instances.ByName(name);
		 	IF newInstance = NIL THEN
		 		NEW(newInstance, name, scope, subInstance.instanceType);
		 		FOR i := 0 TO subInstance.parameters.Length()-1 DO
		 			parameter := subInstance.parameters.GetParameter(i);
		 			newParameter := newInstance.AddParameter(parameter.name);
		 			newParameter.index := parameter.index;
		 			newParameter.parameterType := parameter.parameterType;
		 			newParameter.integer := parameter.integer;
		 			newParameter.boolean := parameter.boolean;
		 		END;
		 	END;
		 	RETURN newInstance
		 END EmbedInstance;

	BEGIN
		IF scope.instances.Length()=0 THEN RETURN END;
		NEW(instances,4); NEW(channels,4);
		FOR i := 0 TO scope.channels.Length()-1 DO
			(* copy local channels one-to-one *)
			oldChannel := scope.channels.GetChannel(i);
			channels.AddChannel(oldChannel);
		END;
		FOR i := 0 TO scope.instances.Length()-1 DO
			instance := scope.instances.GetInstance(i);
			IF instance.instanceType.instances.Length() # 0 THEN
				FlattenNetwork(instance.instanceType);
				FOR j := 0 TO instance.instanceType.instances.Length()-1 DO
					subInstance := instance.instanceType.instances.GetInstance(j);
					newInstance := EmbedInstance(instance, subInstance);
					instances.AddInstance(newInstance)
				END;
				FOR j := 0 TO instance.instanceType.channels.Length()-1 DO
					oldChannel := instance.instanceType.channels.GetChannel(j);
					(* do not copy name: duplicates! *)
					channel := scope.NewChannel();
					channel.ConnectIn(oldChannel.in.instance, oldChannel.in.port);
					channel.ConnectOut(oldChannel.out.instance, oldChannel.out.port);

					channel.SetFifoSize(oldChannel.fifoSize);
					channel.SetWidth(oldChannel.widthInBits);
					channel.in.instance := EmbedInstance(instance, channel.in.instance);
					channel.out.instance := EmbedInstance(instance, channel.out.instance);
					channels.AddChannel(channel);
				END;
			ELSE
				(* copy one-to-one *)
				instances.AddInstance(instance);
			END;
		END;
		FOR i := 0 TO channels.Length()-1 DO
			channel := channels.GetChannel(i);
			FlattenPortInstance(channel.in);
			FlattenPortInstance(channel.out);
		END;
		FOR i := 0 TO scope.ports.Length()-1 DO
			port := scope.ports.GetPort(i);
			FlattenPortInstance(port.delegate);
		END;
		scope.instances := instances;
		scope.channels := channels;
	END FlattenNetwork;

	PROCEDURE NormalizeName*(CONST src: ARRAY OF CHAR; VAR dest: ARRAY OF CHAR);
	VAR i: LONGINT; ch: CHAR;
	BEGIN
		i := 0;
		REPEAT
			ch := src[i];
			CASE ch OF
				".", "@", "[", "]": dest[i] := "0";
			ELSE
				dest[i] := ch
			END;
			INC(i);
		UNTIL ch = 0X;
	END NormalizeName;

	(* write a string and replace dots by the underscore character *)
	PROCEDURE WriteName*(w: Streams.Writer; scope: Scope; CONST name, suffix: ARRAY OF CHAR);
	VAR n: ARRAY 256 OF CHAR;
	BEGIN
		IF scope # NIL THEN scope.GetFullName(n,NIL); ELSE n := "" END;
		IF name # "" THEN
			IF n # "" THEN Strings.Append(n,".") END;
			Strings.Append(n,name);
		END;
		NormalizeName(n,n);
		IF suffix # "" THEN
			ASSERT(n# "");
			Strings.Append(n,"_"); Strings.Append(n,suffix)
		END;
		w.String(n);
	END WriteName;

	(*
	PROCEDURE InitMod;
	BEGIN
		NEW(platforms,3);
		NEW(platform);
		platform.platformId := Strings.NewString("DEFAULT");
		platform.specLoader := LoadSpecificationDefault;
	END InitMod;


BEGIN
	InitMod;
	*)
END FoxActiveCells.

FoxActiveCells.ReadSpecification Test.spec ~
FSTools.CopyFiles TL.spec => Test.spec ~
FoxActiveCells.CompareSpecification Test TL ~~

SystemTools.FreeDownTo FoxActiveCells ~