function [data, header, varLenHeader] = readSpro(filename)
%% [data, header, varLenHeader] = READSPRO(filename)
% Reads spro4 or spro5 feature file.
% data: An NxM matrix where N is the number of feature vectors, and M is 
% dimension of feature vectors.
% header: A structure containing three fields:
% 	- header.featureSize: M
% 	- header.contentFlags: bit letter description of Spro flags
% 	- header.frameRate: number of feature vectors per second. 1/(d/1000), 
%     where d is "frame shift in ms" in sfbcep command. Default d is 10
% varLenHeader: A matrix of cells representing variable length header (if
% provided). Each row of varLenHeader is a 1x2 cell array containing a pair
% of key-value header field.
%
% Here is the list of possible flags within headero.contentFlags:
%   `E'	 feature vector contains log-energy.
%   `Z'	 mean has been removed
%   `N'	 static log-energy has been suppressed (always with `E' and `D')
%   `D'	 feature vector contains delta coefficients
%   `A'	 feature vector contains delta-delta coefficients (always with `D')
%   `R'	 variance has been normalized (always with `Z')
% reference: http://www.irisa.fr/metiss/guig/spro/spro-4.0.1/spro_3.html#SEC17


    %% IMPORTANT: there is a bug in 2010 original implementation of SPro,
    %% which is actually not consistent with documentation. The bug is that 
    %% contentFlag is 64 bits instead of 32 bits. if you are working with
    %% original implementation, set BUG_CONTENTFLAGS_64BITS to 1
    BUG_CONTENTFLAGS_64BITS = 0;

    %% Open stream
    % From Spro documentations: To avoid byte-order problems, binary parts 
    % of the feature streams, such as the fixed length header and the feature 
    % vectors, are always  stored in little-endian format (Intel-like processor)
    machineFormat = 'l'; % Little-endian
    fid = fopen(filename,'r',machineFormat);
    if fid<0
        error('Cannot open file "%s"',filename);
    end
    
    %% Read variable length header (if provided)
    firstBytes = fread(fid,8,'char');
    varLenHeaderStr = '';
    if firstBytes' == uint8('<header>')
        tmpStr = char(fread(fid,9,'char')');
        while ~strcmp(tmpStr, '</header>')
            varLenHeaderStr = strcat(varLenHeaderStr,tmpStr(end));
            fseek(fid,-8,'cof');
            tmpStr = char(fread(fid,9,'char')');
        end
        varLenHeaderStr = varLenHeaderStr(1:end-length('</header'));
        if fread(fid,1,'char') ~= uint8(sprintf('\n'))
            warning('Bad header: Missing carriage return after </header>');
            fseek(fid,-1,'cof');
        end
    else
        fseek(fid,0,'bof');
        warning('Missing <header> tag. Can cause problem in working with scopy');
    end
    varLenHeader = {};
    if ~isempty(varLenHeaderStr)
        vlh_lines = strsplit(varLenHeaderStr,'\n');
        for lineNum=1:length(vlh_lines)
            line = vlh_lines{lineNum};
            lineSegs = strsplit(line,'#');
            line = lineSegs{1}; % remove possible comment
            eques = strsplit(line,';');
            for equNum=1:length(eques)
                equ = strsplit(eques{equNum},'=');
                if length(equ)>1
                    varLenHeader{end+1,1} = strtrim(equ{1});
                    varLenHeader{end,2} = strtrim(equ{2});
                end
            end
        end
    end
    %% Read Header
    feaSize = fread(fid,1,'short');
    if feaSize < 0
        error('Corrupted Spro header file');
    end
    contentFlags = fread(fid,1,'uint32');
    if BUG_CONTENTFLAGS_64BITS == 1
        fseek(fid,4,'cof');
    end
    frameRate = fread(fid,1,'float32');
    %% Check data size before reading data
    dataPos = ftell(fid);
    fseek(fid,0,'eof');
    endPos = ftell(fid);
    if rem(endPos - dataPos,feaSize) ~= 0 
         errorStr = 'Invalid data size. ';
         if rem(endPos - dataPos,feaSize) == 4 
             errorStr = strcat(errorStr, ...
             'it seems you should switch BUG_CONTENTFLAGS_64BITS in code');
         end
         error(errorStr);
    end
    fseek(fid,dataPos,'bof');
    %% Read content Flags
    header.contentFlags = '';
    if nargout > 1
        header.featureSize = feaSize;
        if bitand(contentFlags,hex2dec('01'))
            header.contentFlags = strcat(header.contentFlags, 'E');
        end
        if bitand(contentFlags,hex2dec('02'))
            header.contentFlags = strcat(header.contentFlags, 'Z');
        end
        if bitand(contentFlags,hex2dec('04'))
            header.contentFlags = strcat(header.contentFlags, 'N');
        end
        if bitand(contentFlags,hex2dec('08'))
            header.contentFlags = strcat(header.contentFlags, 'D');
        end
        if bitand(contentFlags,hex2dec('01'))
            header.contentFlags = strcat(header.contentFlags, 'A');
        end
        if bitand(contentFlags,hex2dec('20'))
            header.contentFlags = strcat(header.contentFlags, 'R');
        end
        header.frameRate = frameRate;
    end
    %% Read data
    data = fread(fid,[feaSize Inf],'float32')';
    %% close stream
    fclose(fid);
end
