function [] = readHDF_attemp(primaryTraining, schedule, caseDir, scheduleDir, caseName)% just for now
% attemp to run ADPGRS and read HDF5 output file

iDir = [caseDir, scheduleDir]; % manually change right now
oDir = [caseDir, 'data/'];
%% load case file
% load WBindices, WIs, nWellComp
eval(['load ' oDir caseName '.mat']);
WBindices = caseObj.WBindices;
WIs = caseObj.WIs;
wellPerf = caseObj.nWellPerf;
nComp = caseObj.nComp;
%% load HDF file
fprintf(['loading HDF file for schedule ',int2str(schedule),':\n']);
if primaryTraining % if it is primary training
%     h5file = [iDir 'OUTPUT_gradient_with_DISCRETE.SIM.H5'];
    h5file = [iDir 'OUTPUT_gradient_with_DISCRETE.vars.h5'];
else % if not, with no dirivatives (but state file do not have a difference)
%     h5file = [iDir 'OUTPUT.SIM.H5'];
    h5file = [iDir 'OUTPUT.vars.h5'];
end
% states = hdf5read(h5file,'/FLOW_TRANSPORT/GRIDPROPTIME');
states = hdf5read(h5file,'/FLOW_TRANSPORT/PTZ');
wells = hdf5read(h5file,'/FLOW_TRANSPORT/WELL_STATES');
time = hdf5read(h5file,'/RESTART/TIMES');
states = [states(:,1,:),states(:,3:nComp+1,:)];
nCell = size(states, 3);
nComp = size(states, 2);
timeStep = size(states, 1); % total 128 steps
nWells = size(wells,2);
% should find a way to input WBvariables (here should be 1-indexing)
% WBindices = [1029:1:1031,1040:1:1042]';
temp_WB = (WBindices - 1) * ones(1,nComp) * nComp + ones(size(WBindices)) * (1:nComp);% Idea from Chu Liu
WBvariables = reshape(temp_WB', [], 1);
nWellBlock = length(WBvariables) / nComp;
% matrix manipulation
snapShots = reshape(states(:), timeStep, nCell*nComp)'; % Niu Bi !
for i = 1 : timeStep
    for j = 1:nWells
        wellRate(i,j,:) = wells(i,j).Data{4}.Data;
        wellBHP(i, j) = wells(i,j).Data{1}.Data(1);
        % wellPres = 
    end
end
WBstate = snapShots(WBvariables, :);
% WBstate = stateRearrange(WBvariables, :); % for training case
% if there is production well, you should do something about it here
% PVI estimation
WBstate3D = reshape(WBstate ,nWellBlock, nComp, timeStep);
% flash calculation to get the balanced
% you do not need flash here ! what is the point?
% if you want to compare the well block state, you might need, but not for
% now
trainPVI = calTrainPVI(WBstate, wellBHP, WIs, wellPerf, time, nComp);
timeStep = timeStep - 1;
eval(['save -v7.3 ' oDir 'stateVariable_' int2str(schedule) ...
    ' wellRate wellBHP timeStep snapShots WBvariables WBstate WBindices'...
    ' WBstate3D time trainPVI']);
fprintf(['loading schedule ',int2str(schedule), ' finished!\n']);
end

function [PVI] = calTrainPVI(WBstate, wellBHP, WIs, wellPerf, time, nComp)
timeInterval = [0; diff(time)];
tempState = reshape(WBstate,nComp,sum(wellPerf),size(time, 1));
wellBlockPres = reshape(tempState(1,:,:),sum(wellPerf),size(time, 1));
wellBlockBHP = expandBHP(wellBHP, wellPerf);
PVI = cumsum(WIs' * (wellBlockPres - wellBlockBHP').* timeInterval', 2);
end

function [wellBlockBHP] = expandBHP(wellBHP, wellPerf)
wellBlockBHP = [];
for iWell = 1: size(wellPerf, 2)
    tempBlock = wellBHP(:,iWell) * ones(1, wellPerf(iWell));
    wellBlockBHP = cat(2, wellBlockBHP, tempBlock);
end
end