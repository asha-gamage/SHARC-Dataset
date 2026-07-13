%% User Settings

folderPath = 'C:\Users\gamage_a\Documents\CM_Curves\matlabScripts\set15\matFiles4MMnTP_ngsim';

baseOutputName = 'MMnTP_ngsimLCs_Test';

% Number of output files to create
nParts = 1;

%% --------------------------------------------------------------------
% Get MAT files

matFiles = dir(fullfile(folderPath,'*.mat'));

excluded = {'sim_tracks.mat','tracks.mat'};
keepMask = ~ismember({matFiles.name}, excluded);

files = matFiles(keepMask);

nFiles = numel(files);

fprintf('Files found: %d\n', nFiles);

if nFiles == 0
    error('No MAT files found.');
end

%% --------------------------------------------------------------------
% Split files into nParts approximately equal groups

edges = round(linspace(0, nFiles, nParts+1));

fileGroups = cell(1,nParts);

for p = 1:nParts
    fileGroups{p} = (edges(p)+1):edges(p+1);
end

%% --------------------------------------------------------------------
% Create output filenames automatically

outputFiles = cell(nParts,1);

for p = 1:nParts
    outputFiles{p} = fullfile( ...
        folderPath, ...
        sprintf('%s_Part%d.txt', baseOutputName, p));
end

%% --------------------------------------------------------------------
% Format string
%
% Original MAT files:
%   19 columns
%
% Output TXT files:
%   Columns 2:19 only
%   = 18 columns total

fmt = [repmat('%.6g\t',1,17) '%.6g\n'];

%% --------------------------------------------------------------------
% Process each output file

for p = 1:nParts

    fprintf('\n=====================================\n');
    fprintf('Creating Part %d of %d\n', p, nParts);
    fprintf('=====================================\n');

    fidOut = fopen(outputFiles{p}, 'w');

    if fidOut == -1
        error('Cannot open output file:\n%s', outputFiles{p});
    end

    groupIdx = fileGroups{p};

    fprintf('Files in this part: %d\n', numel(groupIdx));

    for k = groupIdx

        filePath = fullfile(files(k).folder, files(k).name);

        fprintf('Processing %s\n', files(k).name);

        %% Load file

        S = load(filePath);

        varNames = fieldnames(S);

        if isempty(varNames)
            warning('No variables found in %s. Skipping.', files(k).name);
            clear S
            continue
        end

        data = S.(varNames{1});

        %% Validate dimensions

        if size(data,2) ~= 19
            error('Unexpected column count in %s (%d columns found, expected 19).', ...
                files(k).name, size(data,2));
        end

        %% Remove first column

        data = data(:,2:end);

        %% Write entire matrix at once

        fprintf(fidOut, fmt, data.');

        %% Free memory immediately

        clearvars S data varNames

    end

    fclose(fidOut);

    fprintf('Finished Part %d\n', p);

    % Optional: show output file size
    info = dir(outputFiles{p});
    fprintf('Output size: %.2f MB\n', info.bytes/1024^2);

end

%% --------------------------------------------------------------------
fprintf('\nAll %d output files created successfully.\n', nParts);

for p = 1:nParts

    info = dir(outputFiles{p});

    fprintf('Part %d : %.2f MB\n', ...
        p, info.bytes/1024^2);

end