% attemp to repeat the TPWL procedure
function [] = TPWL_attemp(isPS, isMultiTrain, caseDir, caseName, trainingSchedule, targetSchedule)
ioDir = [caseDir 'data/'];
model = 1; % compositional model, not used right now
fprintf(['TPWL for schedule ',int2str(targetSchedule),':\n']);
% load information
eval(['load ' ioDir caseName '.mat']);
wellPerf = caseObj.nWellPerf;
WIs = caseObj.WIs;
% always use time from the 1st training, need to be changed at some point
for iTrain = 1: size(trainingSchedule, 2)
    eval(['load ' ioDir 'stateVariable_' int2str(trainingSchedule(iTrain)) ...
        '.mat WBvariables time']);
    eval(['time_trains.schedule_' int2str(iTrain) ' = time;']);
    clear time;
end

% process the BHPtarget, make it consistent with BHPtraining
[stateRecord, WBstateRecord, psRecord] = linearInter(isPS, isMultiTrain, ioDir, time_trains, WBvariables, ...
    trainingSchedule, targetSchedule);
time = time_trains.schedule_1;
eval(['save -v7.3 ' ioDir 'priVarTPWL_' int2str(targetSchedule) ...
    '.mat stateRecord WBstateRecord WBvariables psRecord time']);
end

function [control, ctrlMode] = scheduleConvert(ioDir, schedule, time)
eval(['load ' ioDir, 'wellCtrl_' int2str(schedule) '.mat']);% ctrlMode ctrl
tSchedule = cumsum(ctrl(:,end));
control = zeros(size(time, 1), size(ctrl, 2) - 1);
for iStep = 1 : size(time, 1)
    tempTime = find(tSchedule >= time(iStep));
    control(iStep, :) = ctrl(tempTime(1), 1 : end - 1);
end
if strcmp(ctrlMode,'rate')
    control = - control; % negative for injection rate
else
    error('no capability for other control yet!\n');
end
end

function [stateRecord, WBstateRecord, psRecord] = linearInter(isPS, isMultiTrain, ioDir, time_trains, WBvariables,...
    trainingSchedule, targetSchedule)
% this function is the key in TPWL
deriv_train = get_deriv_info(ioDir, trainingSchedule, isMultiTrain);
ctrl_train.type = 'train';
ctrl_target.type = 'target'; % define 2 struct
ctrl_train = get_ctrl_info(ioDir, ctrl_train, trainingSchedule, time_trains, 1);
ctrl_target = get_ctrl_info(ioDir, ctrl_target, targetSchedule, time_trains, 0);

time = time_trains.schedule_1; % use time from the 1st training
stateReduced = deriv_train.schedule_1.rBasis(:,1); % initalize redueced state at t = 0
psRecord = zeros(size(time, 1), 2); % record what point selected at each time step
rStateRecord = zeros(size(stateReduced, 1),size(time, 1));
rStateRecord(:,1) = stateReduced; % initializing t = 0

for iStep = 1 : size(time, 1) - 1
    [selectPoint, selectCtrl, selectTraining] = pointSelection(isPS, isMultiTrain, ...
        iStep, psRecord, ctrl_train, ctrl_target, deriv_train, stateReduced);
    select_deriv = selectDeriv(deriv_train, selectTraining);
    
    AccReduced = select_deriv.Accr{selectPoint,1}*(stateReduced - select_deriv.rBasis(:,selectPoint));% Ai, Ai+1 ?
    JrInv = select_deriv.Jr{selectPoint,1}; % Ji+1
    ctrlReduced = select_deriv.dQdur{selectPoint,1}*(ctrl_target.schedule_1.ctrl_well(iStep+1,:) - selectCtrl(selectPoint+1,:))';
    stateInc = JrInv \ (AccReduced + ctrlReduced);
    stateReduced = select_deriv.rBasis(:,selectPoint+1) - stateInc;
    rStateRecord(:,iStep+1) = stateReduced;
    psRecord(iStep,:) = [selectPoint, selectTraining]; % mostly for debug purpose
end
stateRecord = select_deriv.phi * rStateRecord;
WBstateRecord = stateRecord(WBvariables,:);
end

function [ctrl_schedule] = get_ctrl_info(ioDir, ctrl_schedule, schedule, time_trains, isTraining)
for iSchedule = 1 : size(schedule, 2)
    if ~isTraining % loading ctrl for target
        time = time_trains.schedule_1;
    else
        eval(['time = time_trains.schedule_' int2str(iSchedule) ';']);
    end
    [ctrl_well, ~] = scheduleConvert(ioDir, schedule(iSchedule), time);
    [field_PVI, well_PVI] = calPVI(ctrl_well, time);
    eval(['ctrl_schedule.schedule_' int2str(iSchedule) '.field_PVI = field_PVI;']);
    eval(['ctrl_schedule.schedule_' int2str(iSchedule) '.well_PVI = well_PVI;']);
    eval(['ctrl_schedule.schedule_' int2str(iSchedule) '.ctrl_well = ctrl_well;']);
    clear field_PVI well_PVI ctrl_well;
end
end

function [deriv_train] = get_deriv_info(ioDir, trainingSchedule, isMultiTrain)
for iTrain = 1: size(trainingSchedule, 2)
    if iTrain == 1 || isMultiTrain
        eval(['load ' ioDir 'reducedInfo_' int2str(trainingSchedule(iTrain))]);
        eval(['deriv_train.schedule_' int2str(iTrain) '.Accr = Accr;']);
        eval(['deriv_train.schedule_' int2str(iTrain) '.Jr = Jr;']);
        eval(['deriv_train.schedule_' int2str(iTrain) '.dQdur = dQdur;']);
        eval(['deriv_train.schedule_' int2str(iTrain) '.phi = phi;']);
        eval(['deriv_train.schedule_' int2str(iTrain) '.phiT = phiT;']);
        eval(['deriv_train.schedule_' int2str(iTrain) '.rBasis = rBasis;']);
        clear Accr Jr dQdur phi phiT rBasis;
    end
end
end

function [select_deriv] = selectDeriv(deriv_train, selectTraining)
eval(['select_deriv = deriv_train.schedule_' int2str(selectTraining) ';']);
end

% function [selectPoint, selectTraining] = pointSelection(isPS, isMultiTrain, ...
%     iStep, psRecord, ctrlTraining, trainPVI, targetPVI, rBasis, stateReduced)
% % control parameters
% param.range = 10; % n points in front, n points back
% param.weightPVI = 1e5; % weight of PVI over reduced states
% param.epsilon = 1e-3;
% method = 1; % 1.weighted PVI; 2.cosine similarity; 3.local resolution
% if isPS
%     switch method
%         case 1,
%             selectPoint = weightedPVI(iStep, psRecord, trainPVI, targetPVI, rBasis, stateReduced, param);
%         case 2,
%             selectPoint = cosineSimilarity(iStep, psRecord, rBasis, stateReduced, param);
%         case 3,
%             selectPoint = localResolution(iStep, psRecord, trainPVI, targetPVI, rBasis, stateReduced, param);
%         otherwise,
%             error('no matching method!\n');
%     end
% else
%     selectPoint = iStep;
% end
% selectTraining = ctrlTraining;
% end

function [selectPoint, selectCtrl, selectTraining] = pointSelection(isPS, isMultiTrain, ...
    iStep, psRecord, ctrl_train, ctrl_target, deriv_train, stateReduced)
% control parameters
param.range = 10; % n points in front, n points back
param.weightPVI = 1e5; % weight of PVI over reduced states
param.epsilon = 1e-3;
method = 1;
% point selection associated with multi derivatives in training
% isMultiTrain  0: (1,2,3)
% isMultiTrain  1: (4)
% 1.weighted PVI; 2.cosine similarity; 3.local resolution 4. well PVI

if ~isPS % no point selection
    % for sure, no multi-derivative
    selectPoint = iStep;
    selectTraining = 1;
elseif ~isMultiTrain % point selection
    rBasis = deriv_train.schedule_1.rBasis;
    switch method
        case 1,
            selectPoint = weightedPVI(iStep, psRecord(:,1), ctrl_train.schedule_1.field_PVI, ctrl_target.schedule_1.field_PVI, rBasis, stateReduced, param);
        case 2,
            selectPoint = cosineSimilarity(iStep, psRecord(:,1), rBasis, stateReduced, param);
        case 3,
            selectPoint = localResolution(iStep, psRecord(:,1), ctrl_train.schedule_1.field_PVI, ctrl_target.schedule_1.field_PVI, rBasis, stateReduced, param);
        otherwise,
            error('no matching method!\n');
    end
    selectTraining = 1;
else % MultiTrain
    % the only point selection so far with MultiTrain and point selection
    % method 4
    [selectPoint, selectTraining] = wellPVI(iStep, psRecord, ctrl_train, ctrl_target, deriv_train, param);
end

eval(['selectCtrl = ctrl_train.schedule_' int2str(selectTraining) '.ctrl_well;']);
end

function [selectPoint] = weightedPVI(iStep, psRecord, trainPVI, targetPVI, rBasis, stateReduced, param)
selRange = rangeSelection(param.range, iStep, size(rBasis, 2));
trainState = [param.weightPVI*trainPVI(selRange)' /(targetPVI(iStep) + param.epsilon); ...
    rBasis(:,selRange') ./ (sum(stateReduced) + param.epsilon) ];
targetState = [param.weightPVI*targetPVI(iStep) /(targetPVI(iStep) + param.epsilon); ...
    stateReduced ./ (sum(stateReduced) + param.epsilon)];
tempDist = dist([targetState,trainState]); % Q by Q matrix
distance = tempDist(1,2:end); % first row of dist matrix
[~, min_index] = min(distance);
selectPoint = selRange(min_index);
selectPoint = stuckAvoid(psRecord(:,1), selectPoint, iStep, size(rBasis, 2));
end

function [selectPoint, selectTraining] = wellPVI(iStep, psRecord, ctrl_train, ctrl_target, deriv_train, param)
min_dist = -1;
for iTrain = 1:size(fieldnames(ctrl_train), 1)-1
    eval(['rBasis = deriv_train.schedule_' int2str(iTrain) '.rBasis;']);
    selRange = rangeSelection(param.range, iStep, size(rBasis, 2));
    eval(['trainPVI = ctrl_train.schedule_' int2str(iTrain) '.well_PVI;']);
    targetPVI = ctrl_target.schedule_1.well_PVI;
    trainState = [trainPVI(selRange,:)' ./(targetPVI(iStep,:)'*ones(size(selRange')) + param.epsilon) ];
    targetState = [targetPVI(iStep,:) ./(targetPVI(iStep,:) + param.epsilon) ];
    tempDist = dist([targetState',trainState]); % Q by Q matrix
    distance = tempDist(1,2:end); % first row of dist matrix
    [temp_dist, min_index] = min(distance);
    if temp_dist < min_dist || min_dist == -1
        min_dist = temp_dist;
        selectTraining = iTrain;
        selectPoint = selRange(min_index);
    end
end
eval(['rBasis = deriv_train.schedule_' int2str(selectTraining) '.rBasis;']);
selectPoint = stuckAvoid(psRecord(:,1), selectPoint, iStep, size(rBasis, 2));
end

function [selectPoint] = cosineSimilarity(iStep, psRecord, rBasis, stateReduced, param)
selRange = rangeSelection(param.range, iStep, size(rBasis, 2));
trainState = normc(rBasis(:,selRange')); % select the states in the range and normalized it
targetState = normc(stateReduced);
cosine_angle = trainState' * targetState;
% [~, max_index] = max(cosine_angle);
max_index = find(abs(cosine_angle - max(cosine_angle))<0.0001);
[~,select_index] = min(abs(max_index - iStep));
selectPoint = selRange(select_index);
selectPoint = stuckAvoid(psRecord(:,1), selectPoint, iStep, size(rBasis, 2));
end

function [selectPoint] = localResolution()
end


function [PVI, well_PVI] = calPVI(ctrlSchedule, time)
timeInterval = [0; diff(time)];
rateSum = sum(ctrlSchedule,2);
PVI = cumsum(timeInterval .* rateSum, 1);
well_PVI = cumsum(timeInterval* ones(1,size(ctrlSchedule,2)) .* ctrlSchedule, 1);
end

function [selRange] = rangeSelection(range, iStep, totalStep)
minPt = max(1, iStep - range);
maxPt = min(totalStep - 1, iStep + range);
selRange = (minPt : 1 : maxPt)';
end

function [selectPoint] = stuckAvoid(psRecord, selectPoint, iStep, totalStep)
checkPoint = 3;
if iStep > checkPoint && selectPoint < totalStep - 1 && ...
        sum(psRecord(iStep - checkPoint : iStep - 1) == selectPoint) == checkPoint
    selectPoint = selectPoint + 1;% manually avoid stuck
end
end


