% attemp to repeat the TPWL procedure
function [] = TPWL_attemp(isPS, caseDir, caseName, trainingSchedule, targetSchedule)
ioDir = [caseDir 'data/'];
model = 1; % compositional model, not used right now
fprintf(['TPWL for schedule ',int2str(targetSchedule),':\n']);
% load information
eval(['load ' ioDir caseName '.mat']);
wellPerf = caseObj.nWellPerf;
WIs = caseObj.WIs;
eval(['load ' ioDir 'stateVariable_' int2str(trainingSchedule(1)) ...
    '.mat WBvariables time']);
% process the BHPtarget, make it consistent with BHPtraining
[ctrlTraining, ctrlMode] = scheduleConvert(ioDir, trainingSchedule(1), time);
[ctrlTarget, ~] = scheduleConvert(ioDir, targetSchedule, time);
[stateRecord, WBstateRecord, psRecord] = linearInter(isPS, ioDir, time, WBvariables, ...
    ctrlTraining, ctrlTarget, trainingSchedule);
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
end
end

function [stateRecord, WBstateRecord, psRecord] = linearInter(isPS, ioDir, time, WBvariables,...
    ctrlTraining, ctrlTarget, trainingSchedule)
% this function is the key in TPWL
eval(['load ' ioDir 'reducedInfo_' int2str(trainingSchedule(1))]);
stateReduced = rBasis(:,1); % initalize redueced state at t = 0
psRecord = zeros(size(time)); % record what point selected at each time step
rStateRecord = zeros(size(stateReduced, 1),size(time, 1));
rStateRecord(:,1) = stateReduced; % initializing t = 0
trainPVI = calPVI(ctrlTraining, time);
targetPVI = calPVI(ctrlTarget, time);
for iStep = 1 : size(time, 1) - 1
    selectPoint = pointSelection(isPS, iStep, psRecord, trainPVI, targetPVI, rBasis, stateReduced);
    AccReduced = Accr{selectPoint,1}*(stateReduced - rBasis(:,selectPoint));% Ai, Ai+1 ?
    JrInv = Jr{selectPoint,1}; % Ji+1
    ctrlReduced = dQdur{selectPoint,1}*(ctrlTarget(iStep+1,:) - ctrlTraining(selectPoint+1,:))';
    stateInc = JrInv \ (AccReduced + ctrlReduced);
    stateReduced = rBasis(:,selectPoint+1) - stateInc;
    rStateRecord(:,iStep+1) = stateReduced;
    psRecord(iStep,1) = selectPoint; % mostly for debug purpose
end
stateRecord = phi * rStateRecord;
WBstateRecord = stateRecord(WBvariables,:);
end

% old point selection
% function [selectPoint] = pointSelection(isPS, iStep, psRecord, trainPVI, targetPVI, rBasis, stateReduced) % retrive this
% % control parameters
% range = 10; % n points in front, n points back
% weightPVI = 1e5; % weight of PVI over reduced states
% epsilon = 1e-3;
% 
% if isPS
%     selRange = rangeSelection(range, iStep, size(rBasis, 2));   
%     trainState = [weightPVI*trainPVI(selRange)' /(targetPVI(iStep) + epsilon); ...
%         rBasis(:,selRange') ./ (sum(stateReduced) + epsilon) ];
%     targetState = [weightPVI*targetPVI(iStep) /(targetPVI(iStep) + epsilon); ...
%         stateReduced ./ (sum(stateReduced) + epsilon)];
%     tempDist = dist([targetState,trainState]); % Q by Q matrix
%     distance = tempDist(1,2:end); % first row of dist matrix
%     [~, min_index] = min(distance);
%     selectPoint = selRange(min_index);
%     selectPoint = stuckAvoid(psRecord, selectPoint, iStep, size(rBasis, 2));
% else
%     selectPoint = iStep;
% end
% end

function [selectPoint] = pointSelection(isPS, iStep, psRecord, trainPVI, targetPVI, rBasis, stateReduced)
% control parameters
param.range = 10; % n points in front, n points back
param.weightPVI = 0; % weight of PVI over reduced states
param.epsilon = 1e-3;
method = 1; % 1.weighted PVI; 2.cosine similarity; 3.local resolution
if isPS
    switch method
        case 1,
            selectPoint = weightedPVI(iStep, psRecord, trainPVI, targetPVI, rBasis, stateReduced, param);
        case 2,
            selectPoint = cosineSimilarity(iStep, psRecord, rBasis, stateReduced, param);
        case 3,
            selectPoint = localResolution(iStep, psRecord, trainPVI, targetPVI, rBasis, stateReduced, param);
        otherwise,
            error('no matching method!\n');
    end
else
    selectPoint = iStep;
end
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
selectPoint = stuckAvoid(psRecord, selectPoint, iStep, size(rBasis, 2));
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
selectPoint = stuckAvoid(psRecord, selectPoint, iStep, size(rBasis, 2));
end

function [selectPoint] = localResolution()
end


function [PVI] = calPVI(ctrlSchedule, time)
timeInterval = [0; diff(time)];
rateSum = sum(ctrlSchedule,2);
PVI = cumsum(timeInterval .* rateSum, 1);
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


