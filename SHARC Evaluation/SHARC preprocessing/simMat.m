% This script generates Train/Val/Test datasets using ONLY simulation data
% (NGSIM removed completely)

Models = ["STDAN","CS-LSTM"];

for i = 1:length(Models)

    model = char(Models(i));

    % Select folder based on model
    switch model
        case "CS-LSTM"
            folder = 'matFiles4CSLSTM_Sim';
        case "STDAN"
            folder = 'matFiles4STDAN_Sim';
    end

    basePath = 'C:\Users\gamage_a\Documents\CM_Curves\matlabScripts\set85\';
    folderPath = fullfile(basePath, folder);

    % Get all .mat files (simulation only now)
    matFiles = dir(fullfile(folderPath, '*.mat'));

    % Exclude known non-sample files
    excludedFiles = {'sim_tracks.mat', 'tracks.mat'};
    fileNames = setdiff({matFiles.name}, excludedFiles);

    N = length(fileNames);

    % Shuffle file order
    fileNames = fileNames(randperm(N));

    % -----------------------------
    % Build synthetic trajectory data
    % -----------------------------
    simTraj = [];

    for j = 1:N
        data = load(fullfile(folderPath, fileNames{j}));
        fields = fieldnames(data);
        simTraj = [simTraj; data.(fields{1})];
    end

    % -----------------------------
    % Load ONLY simulation tracks
    % -----------------------------
    simData = load(fullfile(folderPath, 'sim_tracks.mat'));
    simFields = fieldnames(simData);
    CMtracks = simData.(simFields{1});

    % Remove empty leading columns
    [~, cols] = size(CMtracks);
    nonEmptyCols = false(1, cols);

    for col = 1:cols
        nonEmptyCols(col) = any(~cellfun(@isempty, CMtracks(:, col)));
    end

    firstNonEmptyCol = find(nonEmptyCols, 1, 'first');
    CMtracks_filtered = CMtracks(:, firstNonEmptyCol:end);

    % Only simulation tracks used
    simTracks = CMtracks_filtered;

    % -----------------------------
    % Train / Val / Test split
    % -----------------------------
    trajTr = [];
    trajVal = [];
    trajTs = [];

    for ii = 1:6
        sim = simTraj(simTraj(:,1) == ii, :);

        len1 = floor(length(sim) * 0.7);
        len2 = floor(length(sim) * 0.8);

        trajTr = [trajTr; sim(1:len1,:)];
        trajVal = [trajVal; sim(len1+1:len2,:)];
        trajTs = [trajTs; sim(len2+1:end,:)];
    end

    % -----------------------------
    % Edge case filtering
    % -----------------------------
    disp('Filtering edge cases...')

    trajTr = filterValidTraj(trajTr, simTracks);
    trajVal = filterValidTraj(trajVal, simTracks);
    trajTs = filterValidTraj(trajTs, simTracks);

    % -----------------------------
    % Save outputs
    % -----------------------------
    saveDir = fullfile(basePath, [model ' simRetrain']);

    if ~exist(saveDir, 'dir')
        mkdir(saveDir);
    end

    disp('Saving mat files...')

    traj = trajTr;
    save(fullfile(saveDir, 'simTrainSet.mat'), 'traj', 'simTracks');

    traj = trajVal;
    save(fullfile(saveDir, 'simValSet.mat'), 'traj', 'simTracks');

    traj = trajTs;
    save(fullfile(saveDir, 'simTestSet.mat'), 'traj', 'simTracks');

end

disp('Process complete!')

% -----------------------------
% Helper function
% -----------------------------
function trajOut = filterValidTraj(trajIn, simTracks)

    inds = zeros(size(trajIn,1),1);

    for k = 1:size(trajIn,1)

        t = trajIn(k,3);
        track = simTracks{trajIn(k,1), trajIn(k,2)};

        if track(1,31) <= t && track(1,end) > (t + 1)
            inds(k) = 1;
        end
    end

    trajOut = trajIn(find(inds),:);
end