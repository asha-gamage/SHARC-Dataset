% =========================================================================
% Combines shuffled .mat trajectory files from NGSIM and simulated data
% and generates Train / Validation / Test datasets.
%
% OPTIMISED LARGE-DATASET VERSION
%
% FEATURES:
%   - Uses matfile() streaming for gigantic traj matrices
%   - Saves traj separately as MATLAB v7.3
%   - Saves combiTracks separately as MATLAB v7
%   - Avoids RAM explosions
%   - Avoids dynamic array growth
%   - Compatible with PyTorch + h5py
%
% OUTPUT FILES:
%
%   trainTrajSet.mat     (v7.3)
%   valTrajSet.mat       (v7.3)
%   testTrajSet.mat      (v7.3)
%
%   trainTracks.mat      (v7)
%   valTracks.mat        (v7)
%   testTracks.mat       (v7)
%
% =========================================================================

clear;
clc;

Models = "CS-LSTM";
% Models = ["STDAN","CS-LSTM"];
split = "";% "30_70";

for m = 1:length(Models)
    
    %% ====================================================================
    % MODEL SELECTION
    % =====================================================================
    
    model = Models(m);
    
    switch model
        case "CS-LSTM"
            folder = fullfile('matFiles4CSLSTM_ngsim\',split);
            
        case "STDAN"
            folder = fullfile('matFiles4STDAN_ngsim\', split);
    end
    
    basePath   = 'C:\Users\gamage_a\Documents\CM_Curves\matlabScripts\set15\';
    folderPath = fullfile(basePath, folder);
    
    disp('============================================================')
    disp(['Processing model: ', char(model)])
    disp('============================================================')
    
    %% ====================================================================
    % LOAD TRACK FILES
    % =====================================================================
    
    disp('Loading track files...')
    
    NGSIM_tracks = load(fullfile(folderPath,'tracks.mat'));
%     simtracks    = load(fullfile(folderPath,'sim_tracks.mat'));
    
    ngFields  = fieldnames(NGSIM_tracks);
%     simFields = fieldnames(simtracks);
    
%     combiTracks = [NGSIM_tracks.(ngFields{1}), ...
%         simtracks.(simFields{1})];
     ngsimTracks = [NGSIM_tracks.(ngFields{1})];

    % Offset simulated vehicle IDs
    NGSIM_MaxVehID = size(NGSIM_tracks.(ngFields{1}),2);    
    disp(['SIM VehIDs will start from: ', num2str(NGSIM_MaxVehID)])
    
    %% ====================================================================
    % PRECOMPUTE TRACK START/END TIMES
    % =====================================================================
    
    disp('Precomputing track metadata...')
    
    startMap = containers.Map('KeyType','char','ValueType','double');
    endMap   = containers.Map('KeyType','char','ValueType','double');
    
    [rows, cols] = size(ngsimTracks);
    
    for r = 1:rows
        for c = 1:cols            
            track = ngsimTracks{r,c};
            
            if isempty(track)
                continue
            end
            
            if size(track,2) < 31
                continue
            end
            
            key = sprintf('%d_%d', r, c);
            
            startMap(key) = track(1,31);
            endMap(key)   = track(1,end);
            
        end
    end
    
    disp('Track metadata complete.')
    
    %% ====================================================================
    % GET TRAJECTORY FILES
    % =====================================================================
    
    matFiles = dir(fullfile(folderPath,'*.mat'));    
    excludedFiles = {'tracks.mat','sim_tracks.mat'};    
    matNames = setdiff({matFiles.name}, excludedFiles);
    
    N = length(matNames);    
    shuffledFiles = matNames(randperm(N));    
    disp(['Total trajectory files: ', num2str(N)])
    
    %% ====================================================================
    % CREATE OUTPUT DIRECTORY
    % =====================================================================
    
    saveDir = fullfile(basePath, [char(model) ' Retrain_ngsimLCs' char(split)]);
    
    if ~exist(saveDir,'dir')
        mkdir(saveDir);
    end
    
    %% ====================================================================
    % OUTPUT FILE NAMES
    % =====================================================================
    
    trainTrajFile = fullfile(saveDir,'trainTrajSet.mat');
    valTrajFile   = fullfile(saveDir,'valTrajSet.mat');
    
    trainTracksFile = fullfile(saveDir,'trainTracks.mat');
    valTracksFile   = fullfile(saveDir,'valTracks.mat');
    
    %% ====================================================================
    % SAVE TRACK FILES SEPARATELY (STANDARD v7)
    % =====================================================================
    
    disp('Saving track files (v7)...')
    
%     save(trainTracksFile,'combiTracks','-v7')
%     save(valTracksFile,'combiTracks','-v7')
    
    save(trainTracksFile,'ngsimTracks','-v7')
    save(valTracksFile,'ngsimTracks','-v7')
    
    %% ====================================================================
    % CREATE EMPTY TRAJ FILES (v7.3)
    % =====================================================================
    
    disp('Creating trajectory matfiles (v7.3)...')
    
    traj = [];
    
    save(trainTrajFile,'traj','-v7.3')
    save(valTrajFile,'traj','-v7.3')
    
    %% ====================================================================
    % OPEN WRITABLE MATFILES
    % =====================================================================
    
    mTrain = matfile(trainTrajFile,'Writable',true);
    mVal   = matfile(valTrajFile,'Writable',true);
    
    %% ====================================================================
    % ROW COUNTERS
    % =====================================================================
    
    trainRow = 1;
    valRow   = 1;
    
    %% ====================================================================
    % SPLIT FILE LISTS
    % =====================================================================
    
    disp('Splitting shuffled files into train/val/test sets...')
    
    len1 = floor(N * 0.85);
    
    trainFiles = shuffledFiles(1:len1);
    valFiles   = shuffledFiles(len1+1:end);
    
    %% ====================================================================
    % PROCESS TRAIN FILES
    % =====================================================================
    
    disp('Streaming TRAIN data to disk...')
    
    for j = 1:length(trainFiles)
        
        if mod(j,200)==0
            disp(['TRAIN file ', num2str(j), ...
                ' / ', num2str(length(trainFiles))])
        end
        
        fileName = trainFiles{j};        
        a = load(fullfile(folderPath,fileName));        
        fn = fieldnames(a);        
        data = a.(fn{1});
        
        % Shift simulated vehicle IDs
        if startsWith(fileName,"Sim_")
            data(:,2) = data(:,2) + NGSIM_MaxVehID;
        end
        
        % Force consistent width
        EXPECTED_COLS = 51;
        
        if size(data,2) < EXPECTED_COLS
            data(:,EXPECTED_COLS) = 0;
        elseif size(data,2) > EXPECTED_COLS
            error('File %s has %d columns', ...
                fileName, size(data,2));
        end
        
        % Filter edge cases
        data = fastFilter(data, startMap, endMap);
        
        if isempty(data)
            continue
        end        
        r = size(data,1);
        
        mTrain.traj(trainRow:trainRow+r-1, ...
            1:size(data,2)) = data;        
        trainRow = trainRow + r;
        
    end
    
    %% ====================================================================
    % PROCESS VALIDATION FILES
    % =====================================================================
    
    disp('Streaming VALIDATION data to disk...')
    
    for j = 1:length(valFiles)
        
        if mod(j,200)==0
            disp(['VAL file ', num2str(j), ...
                ' / ', num2str(length(valFiles))])
        end
        
        fileName = valFiles{j};        
        a = load(fullfile(folderPath,fileName));        
        fn = fieldnames(a);        
        data = a.(fn{1});
        
        % Shift simulated vehicle IDs
        if startsWith(fileName,"Sim_")
            data(:,2) = data(:,2) + NGSIM_MaxVehID;
        end
        
        % Force consistent width
        EXPECTED_COLS = 51;
        
        if size(data,2) < EXPECTED_COLS
            data(:,EXPECTED_COLS) = 0;
        elseif size(data,2) > EXPECTED_COLS
            error('File %s has %d columns', ...
                fileName, size(data,2));
        end
        
        % Filter edge cases
        data = fastFilter(data, startMap, endMap);
        
        if isempty(data)
            continue
        end
        
        r = size(data,1);
        
        mVal.traj(valRow:valRow+r-1, ...
            1:size(data,2)) = data;        
        valRow = valRow + r;
        
    end
    
    %% ====================================================================
    % FINAL INFO
    % =====================================================================
    
    disp('============================================================')
    disp('PROCESSING COMPLETE')
    disp(['Train rows: ', num2str(trainRow-1)])
    disp(['Val rows:   ', num2str(valRow-1)])
    disp('============================================================')
    
end

disp('ALL PROCESSING COMPLETE.')

%% =========================================================================
% FILTER FUNCTION
% =========================================================================

function trajOut = fastFilter(trajIn, startMap, endMap)

if isempty(trajIn)
    trajOut = trajIn;
    return
end
keep = false(size(trajIn,1),1);

for k = 1:size(trajIn,1)
    
    datasetID = trajIn(k,1);
    vehID     = trajIn(k,2);
    t         = trajIn(k,3);
    
    key = sprintf('%d_%d', datasetID, vehID);
    
    if isKey(startMap,key)
        
        startT = startMap(key);
        endT   = endMap(key);
        
        if startT <= t && endT > (t + 1)
            keep(k) = true;
        end
        
    end
end
trajOut = trajIn(keep,:);

end