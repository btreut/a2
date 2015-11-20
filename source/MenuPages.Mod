MODULE MenuPages; (** AUTHOR "staubesv"; PURPOSE "Generate Menupages"; *)

IMPORT
	Streams, Commands, Files, WMComponents, WMStandardComponents;

CONST
	MinNofColumns = 4;
	ColumnWidth = 120;

PROCEDURE GetColumn() : WMStandardComponents.Panel;
VAR column : WMStandardComponents.Panel;
BEGIN
	NEW(column);
	column.SetName("Standard:Panel");
	column.alignment.Set(WMComponents.AlignLeft);
	column.bounds.SetWidth(ColumnWidth);
	RETURN column;
END GetColumn;

PROCEDURE GetButton(CONST caption, command : ARRAY OF CHAR; color, colorHover : LONGINT) : WMStandardComponents.Button;
VAR button : WMStandardComponents.Button; syscmd : WMStandardComponents.SystemCommand;
BEGIN
	NEW(button);
	button.SetName("Standard:Button");
	button.caption.SetAOC(caption);
	button.alignment.Set(WMComponents.AlignTop);
	button.onClickHandler.SetAOC("X Run");
	IF (caption = "") THEN button.enabled.Set(FALSE); END;
	IF (color # 0) THEN button.clDefault.Set(color); END;
	IF (colorHover # 0) THEN button.clHover.Set(colorHover); END;
	NEW(syscmd);
	syscmd.SetName("Standard:SystemCommand");
	syscmd.id.SetAOC("X");
	syscmd.commandString.SetAOC(command);
	button.AddContent(syscmd);
	RETURN button;
END GetButton;

PROCEDURE GetColor(in : Streams.Reader) : LONGINT;
VAR ch : CHAR; color : LONGINT;
BEGIN
	in.SkipWhitespace;
	ch := in.Peek();
	IF ("0" <= ch) & (ch <= "9") THEN
		in.Int(color, TRUE);
	ELSE
		color := 0;
	END;
	RETURN color;
END GetColor;

PROCEDURE GetEntry(in : Streams.Reader; VAR name, command : ARRAY OF CHAR; VAR color, colorHover : LONGINT);
BEGIN
	name := ""; command := "";
	color := 0; colorHover := 0;
	in.SkipWhitespace; in.String(name);
	in.SkipWhitespace; in.String(command);
	color := GetColor(in);
	colorHover := GetColor(in);
END GetEntry;

PROCEDURE AddEntries(menuPage : WMStandardComponents.Panel; in : Streams.Reader);
VAR
	column : WMStandardComponents.Panel; nofColumns : LONGINT;
	entryName : ARRAY 64 OF CHAR;
	commandStr : ARRAY 512 OF CHAR;
	color, colorHover : LONGINT;
BEGIN
	nofColumns := 0;
	WHILE ((in.res = Streams.Ok) & (in.Peek() # 0X)) OR (nofColumns < MinNofColumns) DO
		column := GetColumn();
		menuPage.AddContent(column);
		GetEntry(in, entryName, commandStr, color, colorHover);
		column.AddContent(GetButton(entryName, commandStr, color, colorHover));
		GetEntry(in, entryName, commandStr, color, colorHover);
		column.AddContent(GetButton(entryName, commandStr, color, colorHover));
		in.SkipWhitespace;
		INC(nofColumns);
	END;
END AddEntries;

PROCEDURE Generate*(context : Commands.Context); (** filename menuName {Entries} ~ *)
VAR
	filename : Files.FileName; file : Files.File; writer : Files.Writer;
	menuName : ARRAY 64 OF CHAR;
	menuPage : WMStandardComponents.Panel;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(filename);
	context.arg.SkipWhitespace; context.arg.String(menuName);
	IF (menuName # "") THEN
		NEW(menuPage);
		menuPage.SetName("Standard:Panel");
		menuPage.fillColor.Set(0);
		menuPage.SetAttributeValue("caption", menuName);
		AddEntries(menuPage, context.arg);
		file := Files.New(filename);
		IF (file # NIL) THEN
			Files.OpenWriter(writer, file, 0);
			menuPage.Write(writer, NIL, 0);
			writer.Update;
			Files.Register(file);
			context.out.String("Generated menu page "); context.out.String(filename); context.out.Ln;
		ELSE
			context.out.String("Could not generate file '"); context.out.String(filename); context.out.Ln;
		END;
	ELSE
		context.out.String("Expected menu name argument"); context.out.Ln;
	END;
END Generate;

END MenuPages.

SystemTools.Free MenuPages ~

MenuPages.Generate MenuPage15.xml TestMenu
	Hello "SystemTools.Show Hello"
	World "SystemTools.Show World"
	"" ""
	News "SystemTools.Show News"
	"" ""
	"" ""
	"" ""
	Reboot "SystemTools.Reboot" 0FF000060H 0FF0000FFH
~

