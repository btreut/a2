%
%   Loads n-dimensional data in format compatible with ArrayIO from OCTK library
%
%   INPUT:	
%   	FileName - string of file name to load
%   OUTPUT:
%       loaded array
%
function x = loadnd(fileName)

file = fopen(fileName);
if file < 0 
    error('could not open specified file!');
end;

% first read file ID
%ch = fread(file,11,'char=>char');
strID = fgetl(file);
if ~strcmp(strID,'octkArray')
    error('invalid data ID in the file header!');
end;

% read data type code
n = fread(file,1,'int32');

switch n
    case 1
        dType = 'int8'; frmt = 'int8=>int8';
    case 2
        dType = 'int16'; frmt = 'int16=>int16';
    case 3
        dType = 'int32'; frmt = 'int32=>int32';
    case 4
        dType = 'int64'; frmt = 'int64=>int64';
    case 5
        dType = 'single'; frmt = 'single=>single';
    case 6
        dType = 'double'; frmt = 'double=>double';
    case 7
        dType = 'single'; frmt = 'single=>single';
    case 8
        dType = 'double'; frmt = 'double=>double';    
    case 9
        dType = 'uint8'; frmt = 'uint8=>uint8';
end;

% data dimensionality

ndim = fread(file,1,'int32');

% data size
sz = fread(file,ndim,'int32')';
if (n ~= 7) && (n ~= 8)
    x = fread(file,prod(sz),frmt);    
else
    x = fread(file,[2 prod(sz)],frmt); 
    x = complex(x(1,:),x(2,:));
end;
fclose(file);

% if more than 1D permute
if ndim > 1    
    x = reshape(x,sz(end:-1:1));
    ord = 1:length(sz);
    x = permute(x,ord(end:-1:1));
end;
