% 25/05/25 corrected the reassignment of longitudinal man column index from 12 to 9 for the CS-LSTM model for reassigning 3 - acceleration to 1 - normal speed
%% 16/05/25 added 'Acceleration' as a category for longitudinal manoeuver as used in STDAN model training and edit the files being saved to only save acceleartion for 
% STDAN model files. Update the file saving location for the STDAN model

%% Process dataset into mat files %%

clear; clc;
%% Inputs:
%Locations of raw input files:
% us101_1 = 'raw/us101-0750-0805.txt';
% us101_2 = 'raw/us101-0805-0820.txt';
% us101_3 = 'raw/us101-0820-0835.txt';
% i80_1 = 'raw/i80-1600-1615.txt';
% i80_2 = 'raw/i80-1700-1715.txt';
i80_3 = 'raw/i80-1715-1730.txt';

%% Fields taken from NGSIM dataset for the STDAN model:

%{
1: Dataset Id
2: Vehicle Id (field 1)
3: Frame Number (field 2)
4: Local X (field 5)
5: Local Y (field 6)
6: Lane Id (field 14)
7: Instantaneous Velocity (field 12)
8: Instantaneous Acceleration (field 13)
9: Vehicle type (field 11)
10: Lateral maneuver
11: Longitudinal maneuver
9-47: Neighbor Car Ids at grid location
%}

%% Load data and add dataset id
disp('Loading data...')
% trajOri{1} = load(us101_1);
% trajOri{1} = single([ones(size(trajOri{1},1),1),trajOri{1}]); % single(): Convert to single precision
% trajOri{2} = load(us101_2);
% trajOri{2} = single([2*ones(size(trajOri{2},1),1),trajOri{2}]);
% trajOri{3} = load(us101_3);
% trajOri{3} = single([3*ones(size(trajOri{3},1),1),trajOri{3}]);
% trajOri{4} = load(i80_1);
% trajOri{4} = single([4*ones(size(trajOri{4},1),1),trajOri{4}]);
% trajOri{5} = load(i80_2);
% trajOri{5} = single([5*ones(size(trajOri{5},1),1),trajOri{5}]);
% trajOri{6} = load(i80_3);
% trajOri{6} = single([6*ones(size(trajOri{6},1),1),trajOri{6}]);

trajOri{1} = load(i80_3);
trajOri{1} = single([ones(size(trajOri{1},1),1),trajOri{1}]);

for k = 1%:5 %6 % filter out the required fields only
    traj{k} = trajOri{k}(:,[1,2,3,6,7,13,14,15,12]); % 1-Dataset ID, 2-Vehicle_ID, 3-Frame_ID, 6-Local_X, 7-Local_Y, 13-velocity, 14-acceleration, 15-Lane_ID, 12-Vehicle class
    
    if k <=3 
        traj{k}(traj{k}(:,8)>=6,6) = 6; % **Ask N. Deo - Is there Lane_ID's more than 6? why is the US101 data's Lane_ID gets capped at 6? Why not do this for the i80 dataset?
    end    
    traj{k}(:,10:51) = 0; % added on 19/05/26
end

vehTrajs{1} = containers.Map; % containers.Map() creates an empty Map. The properties are KeyType (set to 'char'), ValueType (set to'any'), Count (set to 0)
vehTrajs{2} = containers.Map;
vehTrajs{3} = containers.Map;
vehTrajs{4} = containers.Map;
vehTrajs{5} = containers.Map;
vehTrajs{6} = containers.Map;

vehTimes{1} = containers.Map;
vehTimes{2} = containers.Map;
vehTimes{3} = containers.Map;
vehTimes{4} = containers.Map;
vehTimes{5} = containers.Map;
vehTimes{6} = containers.Map;

vehTrajsRaw{1} = containers.Map; % containers.Map() creates an empty Map. The properties are KeyType (set to 'char'), ValueType (set to'any'), Count (set to 0)
vehTrajsRaw{2} = containers.Map;
vehTrajsRaw{3} = containers.Map;
vehTrajsRaw{4} = containers.Map;
vehTrajsRaw{5} = containers.Map;
vehTrajsRaw{6} = containers.Map;

%% Parse fields (listed above):
disp('Parsing fields...')

baseOut = 'C:\NGSIM_OUTPUT';

folderCSLSTM = fullfile(baseOut, 'CSLSTM');
folderSTDAN  = fullfile(baseOut, 'STDAN');
folderMMnTP  = fullfile(baseOut, 'MMnTP');

if ~exist(folderCSLSTM, 'dir'); mkdir(folderCSLSTM); end
if ~exist(folderSTDAN,  'dir'); mkdir(folderSTDAN); end
if ~exist(folderMMnTP,  'dir'); mkdir(folderMMnTP); end

% Global counters
counter_LLC = 1;
counter_RLC = 1;

% Buffer settings
bufferSize = 200;
bufLLC_CSLSTM = cell(bufferSize,1);
bufLLC_STDAN  = cell(bufferSize,1);
bufLLC_MMnTP  = cell(bufferSize,1);
bufRLC_CSLSTM = cell(bufferSize,1);
bufRLC_STDAN  = cell(bufferSize,1);
bufRLC_MMnTP  = cell(bufferSize,1);

bufCountLLC = 0;
bufCountRLC = 0;

for ii = 1%:5 %6
    vehIds = unique(traj{ii}(:,2)); % identifies all the unique vehicle IDs in all 6 recorded datasets in turns.
    % C = unique(A) for the array A returns the same values as in A but with no repetitions. C will be sorted.

    % Next statement fills the "vehTrajs" dictionary/ map with key-value pairs, where keys as vehicle_IDs
    % and the values are a matrix of all the rows related to that vehicle ID.
    % Basically it's all original rows with vehicle ID matching the key and the filtered columns from the original .txt file

    for v = 1:length(vehIds)
        vehTrajsRaw{ii}(int2str(vehIds(v))) = traj{ii}(traj{ii}(:,2) == vehIds(v),:); % Trajectories of unique vehicles, where key is vehIDs 
        % and the value is 'all trajectory data' related to that vehID
    end

    % Next statement fills the "vehTimes" dictionary/ map with key-value pairs, where keys as Frame_IDs
    % and the values are a matrix of all the rows related to that Frame_ID.
    % Captures all the vehicles involved in a given Frame_ID (given timesnap)
    timeFrames = unique(traj{ii}(:,3)); % identifies all the unique Frame_IDs in all 6 recorded datasets

    for v = 1:length(timeFrames)
        vehTimes{ii}(int2str(timeFrames(v))) = traj{ii}(traj{ii}(:,3) == timeFrames(v),:); % All the vehicle trajectory data on a timeframe
    end

    % for the full length of each dataset, Get the value for time, dsId (dataset Id), vehId (vehicle Id)
    for k = 1:length(traj{ii}(:,1))
        time = traj{ii}(k,3);
        dsId = traj{ii}(k,1);
        vehId = traj{ii}(k,2);
        vehtraj = vehTrajsRaw{ii}(int2str(vehId)); % getting the vehicle trajectory for the current vehicle_ID (vehId)from vehTrajs map for the current dataset
        ind = find(vehtraj(:,3)==time); % Find the index of the vehicle trajectory where the frame ID (column 3) matches the 'time'.I.e. find the index of
        % the exact track from the list of tracks for a vehicle: vehid
        % find(): Find indices of nonzero elements
        
        if isempty(ind)
            continue; % Skip this iteration if no match is found
        end

        ind = ind(1); % Could there ever be more than one?
        lane = traj{ii}(k,8);

        % Add a field to match the synthetic dataset on the road referene angle
        traj{ii}(k,10) = 0;

        % Get lateral maneuver:
        ub = min(size(vehtraj,1),ind+40);% Upper bound is calculated by checking whether the index at each record has 40
        %(0.5*8sec duration used for observation and prediction) more Frame_IDs to the future and taking the lowest timeFrame
        % size(X,1) returns the number of rows of X and size(X,[1 2]) returns a row vector containing the number of rows & columns.
        lb = max(1, ind-40);% Lower bound is calculated by checking whether the index at each record has 40 more Frame_IDs to the past and taking
        % the highest Frame_ID
        if vehtraj(ub,8)>vehtraj(ind,8) || vehtraj(ind,8)>vehtraj(lb,8)% future lane Id > current lane Id OR current lane Id > past lane Id
            traj{ii}(k,11) = 3;% Categorise as 'Right Lane-change' and adds it to a new column_7
        elseif vehtraj(ub,8)<vehtraj(ind,8) || vehtraj(ind,8)<vehtraj(lb,8)
            traj{ii}(k,11) = 2;% Left Lane-change
        else
            traj{ii}(k,11) = 1;% Lane Keep
        end

        % Get longitudinal maneuver:
        ub = min(size(vehtraj,1),ind+50);% Upper bound is calculated by checking whether the index at each record has 50 more frames(5s to the future)to
        % the future and taking the lowest duration
        lb = max(1, ind-30);% Lower bound is calculated by checking whether the index at each record has 30 frames to the past or checking if at the start
        % of the recording
        if ub==ind || lb ==ind% If current index is the start OR the end of the recording....
            traj{ii}(k,12) =1;% longitudinal maneuver is categorised as 'Normal speed' and adds it to a new column_8
        else
            vHist = (vehtraj(ind,5)-vehtraj(lb,5))/(ind-lb);% Historical velocity calculated by dividing the longitudinal distance between
            % current and lower bound time frames
            vFut = (vehtraj(ub,5)-vehtraj(ind,5))/(ub-ind);% Future velocity calculated by dividing the longitudinal distance between
            % current and lower bound time frames
            if vFut/vHist < 0.8% vehicle to be performing a braking maneuver if it’s average speed over the prediction horizon is less
                % than 0.8 times its speed at the time of the prediction
                traj{ii}(k,12) = 2;% Braking and adds it to a new column_8
            elseif vFut/vHist > 1.25% vehicle to be performing an acceleration maneuver if it’s average speed over the prediction horizon is greater
                % than 1.25 times its speed at the time of the prediction. Only used for STDAN model               
                traj{ii}(k,12) = 3;                    
            else
                traj{ii}(k,12) = 1;
            end
        end           
        
        % Get grid locations:
        t = vehTimes{ii}(int2str(time));
        frameEgo = t(t(:,8) == lane,:);
        frameL = t(t(:,8) == lane-1,:);
        frameR = t(t(:,8) == lane+1,:);
        if ~isempty(frameL)
            for l = 1:size(frameL,1)
                y = frameL(l,5)-traj{ii}(k,5);
                if abs(y) <90
                    gridInd = 1+round((y+90)/15);
                    traj{ii}(k,12+gridInd) = frameL(l,2);
                end
            end
        end
        for l = 1:size(frameEgo,1)
            y = frameEgo(l,5)-traj{ii}(k,5);
            if abs(y) <90 && y~=0
                gridInd = 14+round((y+90)/15);
                traj{ii}(k,12+gridInd) = frameEgo(l,2);
            end
        end
        if ~isempty(frameR)
            for l = 1:size(frameR,1)
                y = frameR(l,5)-traj{ii}(k,5);
                if abs(y) <90
                    gridInd = 27+round((y+90)/15);
                    traj{ii}(k,12+gridInd) = frameR(l,2);
                end
            end
        end
    end   
    
    % Next statement fills the "vehTrajs" dictionary/ map with key-value pairs, where keys as vehicle_IDs
    % and the values are a matrix of all the rows related to that vehicle ID.   
    for v = 1:length(vehIds)
        vehTrajs{ii}(int2str(vehIds(v))) = traj{ii}(traj{ii}(:,2) == vehIds(v),1:12); % Trajectories of unique vehicles, where key is vehIDs 
        % and the value is 'all trajectory data' related to that vehID
    end  
    
    % Build the tracks for CS-LSTM and STDAN models     
    for v = 1:length(vehIds)
        % Trajectories of unique vehicles, where key is vehIDs and the value is 'all trajectory data' related to that vehID
        vehTrack = traj{ii}(traj{ii}(:,2) == vehIds(v),:);
        vehTrack_Ori = trajOri{ii}(trajOri{ii}(:,2) == vehIds(v),:);
        tracks_CSLSTM {ii, vehIds(v)} = vehTrack(:, 3:5)';
        % tracks_STDAN {ii, vehIds(v)} = vehTrack(:, 3:11)';
        tracks_STDAN {ii, vehIds(v)} = vehTrack(:, [3:9, 11:12])';
        tracks_MMnTP {ii, vehIds(v)} = vehTrack_Ori(:,:)';
    end  

    for v = 1:length(vehIds)

        vehtraj = vehTrajs{ii}(int2str(vehIds(v)));

        latMan = vehtraj(:,11); % lateral manoeuvre column
        frames = vehtraj(:,3); % frame numbers

        % Find true lane change points (transition from keep to LC)
        prev = latMan(1:end-1);
        next = latMan(2:end);
        LC_points = (prev == 1) & (next ~= 1);
        LC_idx = find(LC_points) + 1;

        for k = 1:length(LC_idx)

            LC_type = latMan(LC_idx(k)); % 2 = LLC, 3 = RLC
            LC_frame = frames(LC_idx(k));

            % 8 second window = 80 frames before and after
            fLow = LC_frame - 100; % 650 frames, equivalent to 100 seconds
            fHigh = LC_frame + 100;

            % Extract TRUE temporal window from full traj
            windowRows = traj{ii}(traj{ii}(:,3)>=fLow & traj{ii}(:,3)<=fHigh, :);
            windowRows_Ori = trajOri{ii}(trajOri{ii}(:,3)>=fLow & trajOri{ii}(:,3)<=fHigh, :);
            
            if LC_type == 2   % LLC
                
                LLCtraj_CSLSTM = windowRows(:, [1,2,3,4,5,8,10,11,12,13:end]);

                LLCtraj_CSLSTM(LLCtraj_CSLSTM(:,9)==3,9)=1; % Corrected the longitudinal manouever allocation for CS-LSTM (26/05/26)

                LLCtraj_STDAN = windowRows(:, [1,2,3,4,5,6,7,8,9,10,11,12,13:end]);
                
                LLCtraj_MMnTP = windowRows_Ori;

                bufCountLLC = bufCountLLC + 1;

                bufLLC_CSLSTM{bufCountLLC} = LLCtraj_CSLSTM;
                bufLLC_STDAN{bufCountLLC}  = LLCtraj_STDAN;
                bufLLC_MMnTP{bufCountLLC}  = LLCtraj_MMnTP;

                globalIndex = counter_LLC;
                counter_LLC = counter_LLC + 1;
                
                if bufCountLLC == bufferSize

                    for b = 1:bufCountLLC

                        idx = globalIndex - bufCountLLC + b;

                        fileCS = fullfile(folderCSLSTM, ['NGSIM_LLC_' num2str(idx) '.mat']);
                        fileST = fullfile(folderSTDAN,  ['NGSIM_LLC_' num2str(idx) '.mat']);
                        fileMN = fullfile(folderMMnTP,  ['NGSIM_LLC_' num2str(idx) '.mat']);

                        LLCtraj_CSLSTM = bufLLC_CSLSTM{b};
                        LLCtraj_STDAN  = bufLLC_STDAN{b};
                        LLCtraj_MMnTP  = bufLLC_MMnTP{b};

                        save(fileCS, 'LLCtraj_CSLSTM', '-v7.3');
                        save(fileST, 'LLCtraj_STDAN',  '-v7.3');
                        save(fileMN, 'LLCtraj_MMnTP',  '-v7.3');
                    end

                    bufLLC_CSLSTM = cell(bufferSize,1);
                    bufLLC_STDAN  = cell(bufferSize,1);
                    bufLLC_MMnTP  = cell(bufferSize,1);
                    bufCountLLC = 0;

                    fclose('all');   % IMPORTANT stability fix
                end

            elseif LC_type == 3   % RLC
                
                RLCtraj_CSLSTM = windowRows(:, [1,2,3,4,5,8,10,11,12,13:end]);
                RLCtraj_CSLSTM(RLCtraj_CSLSTM(:,9)==3,9)=1; % Corrected the longitudinal manouever allocation for CS-LSTM (26/05/26)

                RLCtraj_STDAN = windowRows(:, [1,2,3,4,5,6,7,8,9,10,11,12,13:end]);
                
                RLCtraj_MMnTP = windowRows_Ori;
                
                bufCountRLC = bufCountRLC + 1;

                bufRLC_CSLSTM{bufCountRLC} = RLCtraj_CSLSTM;
                bufRLC_STDAN{bufCountRLC}  = RLCtraj_STDAN;
                bufRLC_MMnTP{bufCountRLC}  = RLCtraj_MMnTP;

                globalIndex = counter_RLC;

                counter_RLC = counter_RLC + 1;
                if bufCountRLC == bufferSize

                    for b = 1:bufCountRLC

                        idx = globalIndex - bufCountRLC + b;

                        fileCS = fullfile(folderCSLSTM, ['NGSIM_RLC_' num2str(idx) '.mat']);
                        fileST = fullfile(folderSTDAN,  ['NGSIM_RLC_' num2str(idx) '.mat']);
                        fileMN = fullfile(folderMMnTP,  ['NGSIM_RLC_' num2str(idx) '.mat']);

                        RLCtraj_CSLSTM = bufRLC_CSLSTM{b};
                        RLCtraj_STDAN  = bufRLC_STDAN{b};
                        RLCtraj_MMnTP  = bufRLC_MMnTP{b};

                        save(fileCS, 'RLCtraj_CSLSTM', '-v7.3');
                        save(fileST, 'RLCtraj_STDAN',  '-v7.3');
                        save(fileMN, 'RLCtraj_MMnTP',  '-v7.3');
                    end

                    bufRLC_CSLSTM = cell(bufferSize,1);
                    bufRLC_STDAN  = cell(bufferSize,1);
                    bufRLC_MMnTP  = cell(bufferSize,1);
                    bufCountRLC = 0;

                    fclose('all');
                end
            end
        end
    end
end

% Flush remaining LLC
for b = 1:bufCountLLC
    idx = counter_LLC - bufCountLLC + b - 1;

    fileCS = fullfile(folderCSLSTM, ['NGSIM_LLC_' num2str(idx) '.mat']);
    fileST = fullfile(folderSTDAN,  ['NGSIM_LLC_' num2str(idx) '.mat']);
    fileMN = fullfile(folderMMnTP,  ['NGSIM_LLC_' num2str(idx) '.mat']);

    LLCtraj_CSLSTM = bufLLC_CSLSTM{b};
    LLCtraj_STDAN  = bufLLC_STDAN{b};
    LLCtraj_MMnTP  = bufLLC_MMnTP{b};

    save(fileCS, 'LLCtraj_CSLSTM', '-v7.3');
    save(fileST, 'LLCtraj_STDAN',  '-v7.3');
    save(fileMN, 'LLCtraj_MMnTP',  '-v7.3');
end

% Flush remaining RLC
for b = 1:bufCountRLC
    idx = counter_RLC - bufCountRLC + b - 1;

    fileCS = fullfile(folderCSLSTM, ['NGSIM_RLC_' num2str(idx) '.mat']);
    fileST = fullfile(folderSTDAN,  ['NGSIM_RLC_' num2str(idx) '.mat']);
    fileMN = fullfile(folderMMnTP,  ['NGSIM_RLC_' num2str(idx) '.mat']);

    RLCtraj_CSLSTM = bufRLC_CSLSTM{b};
    RLCtraj_STDAN  = bufRLC_STDAN{b};
    RLCtraj_MMnTP  = bufRLC_MMnTP{b};

    save(fileCS, 'RLCtraj_CSLSTM', '-v7.3');
    save(fileST, 'RLCtraj_STDAN',  '-v7.3');
    save(fileMN, 'RLCtraj_MMnTP',  '-v7.3');
end

% Generate the 'tracks' files for the CSLSTM, STADAN and MMnTP models
save ('C:\Users\gamage_a\Documents\CM_Curves\matlabScripts\set15\matFiles4CSLSTM_ngsim\tracks', 'tracks_CSLSTM')
save ('C:\Users\gamage_a\Documents\CM_Curves\matlabScripts\set15\matFiles4STDAN_ngsim\tracks', 'tracks_STDAN')
save ('C:\Users\gamage_a\Documents\CM_Curves\matlabScripts\set15\matFiles4MMnTP_ngsim\tracks', 'tracks_MMnTP')

disp('File generation complete!')