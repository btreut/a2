library testa2;


procedure KernelLogInt(a,b:LONGINT);  stdcall; external 'TestDll' name 'Int';
procedure KernelLogStr(s:PChar); stdcall;external 'TestDll' name 'String';

procedure helloword1(a,b:LONGINT);stdcall;
BEGIN
 KernelLogInt(a,b);
end;
procedure helloword2;stdcall;
var
 s:ARRAY[0..100] OF CHAR;
BEGIN
 s:='Hi from delphi!';
 KernelLogStr(@s);
end;

exports
   helloword1 name 'helloword1',
   helloword2 name 'helloword2';


end.
