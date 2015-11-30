%
%   Loads n-dimensional data in format compatible with ArrayIO from OCTK library
%
%   INPUT:	
%       x - array to store    
%   	FileName - string of file name to store
%
function savend(x,fileName)

file = fopen(fileName,'w');

% file ID
fwrite(file,'octkArray','uint8');
fwrite(file,[13 10],'uint8');

% data type

if isa(x,'int8')
    fwrite(file,1,'int32'); sformat = 'int8';
elseif isa(x,'int16')
    fwrite(file,2,'int32'); sformat = 'int16';
elseif isa(x,'int32')
    fwrite(file,3,'int32'); sformat = 'int32';
elseif isa(x,'int64')
    fwrite(file,4,'int32'); sformat = 'int64';
elseif isa(x,'single')
    fwrite(file,5,'int32'); sformat = 'single';
elseif isa(x,'double')
    fwrite(file,6,'int32'); sformat = 'double';   
end;

% data dimensionality
ndim = ndims(x);
if (ndim==2) && ((size(x,1) == 1) || (size(x,2) == 1))
    ndim = 1;
end;
fwrite(file,ndim,'int32');

% data size
if ndim > 1
    fwrite(file,size(x),'int32');
else
    fwrite(file,length(x),'int32');
end;

% if more than 1D permute
if ndim > 1   
    ord = 1:ndim;
    x = permute(x,ord(end:-1:1));
end;

fwrite(file,x,sformat);

fclose(file);