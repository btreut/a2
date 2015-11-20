MODULE HelloWorld;

IMPORT
	Commands;

PROCEDURE Hello* (context: Commands.Context);
BEGIN
	context.out.String("Hello"); context.out.Ln;
END Hello;

PROCEDURE HelloCn* (context: Commands.Context);
BEGIN
	context.out.String("你好"); context.out.Ln;
END HelloCn;

PROCEDURE HelloKr* (context: Commands.Context);
BEGIN
	context.out.String("여보세요"); context.out.Ln;
END HelloKr;

PROCEDURE HelloJp* (context: Commands.Context);
BEGIN
	context.out.String("こんにちは"); context.out.Ln;
END HelloJp;

PROCEDURE HelloRu* (context: Commands.Context);
BEGIN
	context.out.String("привет"); context.out.Ln;
END HelloRu;

END HelloWorld.

SystemTools.Free HelloWorld ~
HelloWorld.Hello ~
HelloWorld.HelloCn ~
HelloWorld.HelloKr ~
HelloWorld.HelloJp ~
HelloWorld.HelloRu ~


