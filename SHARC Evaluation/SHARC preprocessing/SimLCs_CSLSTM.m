%%This script geneates an equvalent .mat file for each simulated LC
%%scenario using CarMaker and assigns the longitudinal and lateral
%%manoeuver classification

% Define the folder path (adjust the path to your folder)
% folderPath = 'C:\Users\gamage_a\Documents\CM_Curves\SimOutput\WMGL241\20250131\textFiles4CSLSTM\'; 
folderPath = 'C:\Users\gamage_a\Documents\CM_Curves\matlabScripts\set15\textFiles4CSLSTM\';
% folderPath = '..\SimOutput\WMGL241\20250131\textFiles4CSLSTM\';  % Replace with your folder path
% Get a list of all .mat files in the folder
txtFiles = dir(fullfile(folderPath, '*.txt'));
N = length(txtFiles); 
groupedTraj = cell(6,1);

for i = 1:N
    traj = load([folderPath,txtFiles(i).name]);
%     traj = single(sortrows(traj,2)); % Sort the array based on vehicle IDs and convert to single precision
    traj = single(sortrows(traj,[2 3]));  % vehicleID, then time    
    % Remove duplicate (vehicleID, time) rows coming from CarMaker logs
    key = traj(:,[2 3]);  % vehicleID + time
    [~, uniqueIdx] = unique(key, 'rows', 'first');
    traj = traj(sort(uniqueIdx), :);
    
    % ====== FIXED COLUMN PREALLOCATION (CRITICAL) ======
    EXPECTED_COLS = 51;

    if size(traj,2) < EXPECTED_COLS
        traj(:, EXPECTED_COLS) = 0;   % force fixed width
    elseif size(traj,2) > EXPECTED_COLS
        error('Input file %s already has more than %d columns. Check source data.', ...
            txtFiles(i).name, EXPECTED_COLS);
    end
    % ===================================================

    vehTrajs = containers.Map;
    vehTimes = containers.Map;
    
    %disp('Parsing fields...')
       
    vehIds = unique(traj(:,2)); % identifies all the unique vehicleIDs
    for v = 1:length(vehIds)       
        vehTrajs(int2str(vehIds(v))) = traj(traj(:,2) == vehIds(v),:);        
    end
        
    timeFrames = unique(traj(:,3)); % identifies all the unique timeframes
    for v = 1:length(timeFrames)
        vehTimes(int2str(timeFrames(v))) = traj(traj(:,3) == timeFrames(v),:);
    end
    
    for k = 1:length(traj(:,1))
        time = traj(k,3);
        dsId = traj(k,1);
        vehId = traj(k,2);
        vehtraj = vehTrajs(int2str(vehId));
        ind = find(vehtraj(:,3)==time);
        ind = ind(1);
        lane = traj(k,6);
        
        % Get lateral maneuver:
        ub = min(size(vehtraj,1),ind+40); % Upper bound is calculated by checking whether the index at each record has 40 more points to the future and taking the lowest duration
        lb = max(1, ind-40);% Lower bound is calculated by checking whether the index at each record has 40 more points to the past or checking if at the start of the recording
        if vehtraj(ub,6) > vehtraj(ind,6) || vehtraj(ind,6) > vehtraj(lb,6)% future lane Id > current lane Id OR current lane Id > past lane Id
            traj(k,8) = 3; % Right Lane-change and adds it to a new column_8
        elseif vehtraj(ub,6) < vehtraj(ind,6) || vehtraj(ind,6) < vehtraj(lb,6)
            traj(k,8) = 2; % Left Lane-change
        else
            traj(k,8) = 1; % Lane Keep
        end
        
        % Get longitudinal maneuver:
        ub = min(size(vehtraj,1),ind+50);% Upper bound is calculated by checking whether the index at each record has 50 more points to the future and taking the lowest duration
        lb = max(1, ind-30);% Lower bound is calculated by checking whether the index at each record has 30 more points to the past or checking if at the start of the recording
        if ub==ind || lb ==ind % If current index is the start OR the end of the recording....
            traj(k,9) = 1;% longitudinal maneuver is categorised as 'Normal speed'
        else
            vHist = (vehtraj(ind,5)-vehtraj(lb,5))/(ind-lb); % Historical velocity calculated by dividing the longitudinal distance between current and lower bound time frames
            vFut = (vehtraj(ub,5)-vehtraj(ind,5))/(ub-ind); % Future velocity calculated by dividing the longitudinal distance between current and lower bound time frames
            if vFut/vHist <0.8 % vehicle to be performing a braking maneuver if it’s average speed over the prediction horizon is less than 0.8 times its speed at the time of prediction
                traj(k,9) = 2; % Braking
            else
                traj(k,9) = 1;
            end
        end
        
        %% Get grid locations:
        t = vehTimes(int2str(time));
        frameEgo = t(t(:,6) == lane,:);
        frameL = t(t(:,6) == lane-1,:);
        frameR = t(t(:,6) == lane+1,:);
        if ~isempty(frameL)
            for l = 1:size(frameL,1)
                y = frameL(l,5)-traj(k,5);
                if abs(y) < 90 % 90feet distance boundary
                    gridInd = 1+round((y+90)/15); % Calculates the required number of columns to the matrix
                    traj(k,9+gridInd) = frameL(l,2); % Adds the new columns to the matrix after column 8, which is the longitudinal maneuver
                end
            end
        end
        for l = 1:size(frameEgo,1)
            y = frameEgo(l,5)-traj(k,5);
            if abs(y) <90 && y~=0
                gridInd = 14+round((y+90)/15);% 90/15 =6, So 14 comes from column 8+6.
                traj(k,9+gridInd) = frameEgo(l,2);
            end
        end
        if ~isempty(frameR)
            for l = 1:size(frameR,1)
                y = frameR(l,5)-traj(k,5);
                if abs(y) <90
                    gridInd = 27+round((y+90)/15);
                    traj(k,9+gridInd) = frameR(l,2);
                end
            end
        end
    end
    
    if size(traj,2) ~= EXPECTED_COLS
        error('Column mismatch in file %s. Expected %d, got %d.', ...
            txtFiles(i).name, EXPECTED_COLS, size(traj,2));
    end 

    % Define output folders
    folder1 = 'C:\Users\gamage_a\Documents\CM_Curves\matlabScripts\set15\matFiles4CSLSTM_Combi';
    folder2 = 'C:\Users\gamage_a\Documents\CM_Curves\matlabScripts\set15\matFiles4CSLSTM_Sim';
    
    % Create folders if they do not exist
    if ~exist(folder1, 'dir')
        mkdir(folder1);
    end

    if ~exist(folder2, 'dir')
        mkdir(folder2);
    end  

    [~, baseName, ~] = fileparts(txtFiles(i).name);
    outputName = baseName;

    savePath_1 = fullfile(folder1, [outputName '.mat']);
    savePath_2 = fullfile(folder2, [outputName '.mat']);

    save(savePath_1, 'traj');
    save(savePath_2, 'traj');

    % Create the Trajs for 'tracks' file
    if dsId >= 1 && dsId <= 6
        groupedTraj{dsId} = [groupedTraj{dsId}; traj];  % Append the row to the corresponding ID group
    end     
end

% Generate the 'tracks file 
tracks_CM = {};
for h = 1:5
    vehIds = unique(groupedTraj{h}(:,2)); % identifies all the unique vehicleIDs
    for v = 1:length(vehIds)
        vehTrack = groupedTraj{h}(groupedTraj{h}(:,2) == vehIds(v),:);
        % Generate the tracks for dataset creation
        tracks_CM {h, vehIds(v)} = vehTrack(:, 3:5)';
    end
end
savePath_1 = 'C:\Users\gamage_a\Documents\CM_Curves\matlabScripts\set15\matFiles4CSLSTM_Combi\sim_tracks';
savePath_2 = 'C:\Users\gamage_a\Documents\CM_Curves\matlabScripts\set15\matFiles4CSLSTM_Sim\sim_tracks';
save(savePath_1, 'tracks_CM'); save(savePath_2, 'tracks_CM')  

disp ('File generation complete!')


