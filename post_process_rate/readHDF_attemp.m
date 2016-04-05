function [] = readHDF_attemp(primaryTraining, isMultiTrain, schedule, caseDir, scheduleDir, caseName)% just for now
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
if primaryTraining || isMultiTrain % if it is primary training
    h5file = [iDir 'OUTPUT_gradient_with_DISCRETE.sim.h5'];
else % if not, with no dirivatives (but state file do not have a difference)
    h5file = [iDir 'OUTPUT.sim.h5'];
end
states = hdf5read(h5file,'/GRIDPROPTIME');
wells = hdf5read(h5file,'/WELL_STATES');
time = hdf5read(h5file,'/TIMES');
states = states(:,2:end,:);
nCell = size(states, 3);
nComp = size(states, 2);
timeStep = size(states, 1);
nWells = size(wells,2);
% should find a way to input WBvariables (here should be 1-indexing)
% WBindices = [51911:46:52003, 51866:1:51870, 51819:-46:51635, 51864:-1:51862]';
temp_WB = (WBindices - 1) * ones(1,nComp) * nComp + ones(size(WBindices)) * (1:nComp);% Idea from Chu Liu
WBvariables = reshape(temp_WB', [], 1);
nWellBlock = length(WBvariables) / nComp;
% matrix manipulation
snapShots = reshape(states(:), timeStep, nCell*nComp)'; % Niu Bi !
for i = 1 : timeStep
    for j = 1:nWells
        wellRate(i,j,:) = wells(i,j).Data{4}.Data;
        wellBHP(i, j) = wells(i,j).Data{1}.Data(1);
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
timeStep = timeStep - 1;
eval(['save -v7.3 ' oDir 'stateVariable_' int2str(schedule) ' wellRate wellBHP timeStep snapShots WBvariables WBstate WBindices WBstate3D time']);
fprintf(['loading schedule ',int2str(schedule), ' finished!\n']);
end

