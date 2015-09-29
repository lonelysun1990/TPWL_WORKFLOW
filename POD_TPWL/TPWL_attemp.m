% attemp to repeat the TPWL procedure
function [] = TPWL_attemp(isPS, isLog, caseDir, caseName, trainingSchedule, targetSchedule, wellSchedule)
ioDir = [caseDir 'data/'];
model = 1; % compositional model, not used right now
fprintf(['TPWL for schedule ',int2str(targetSchedule),':\n']);
% load information
eval(['load ' ioDir caseName '.mat']);
wellPerf = caseObj.nWellPerf;
WIs = caseObj.WIs;
eval(['load ' ioDir 'stateVariable_' int2str(trainingSchedule(1)) ...
    '.mat WBvariables time trainPVI']);
% process the BHPtarget, make it consistent with BHPtraining
[ctrlTraining,~] = scheduleConvert(ioDir, trainingSchedule(1), time, 'trans', wellSchedule);
[ctrlTarget,wellTarget] = scheduleConvert(ioDir, targetSchedule, time, 'trans', wellSchedule);

[stateRecord, WBstateRecord, psRecord] = linearInter(isPS, isLog, ioDir, time, WBvariables, ...
    ctrlTraining, ctrlTarget, trainingSchedule, trainPVI, wellPerf, WIs, wellTarget);
eval(['save -v7.3 ' ioDir 'priVarTPWL_' int2str(targetSchedule) ...
    '.mat stateRecord WBstateRecord WBvariables']);
end

function [control, wellCtrl] = scheduleConvert(ioDir, schedule, time, ctrlParam, wellSchedule)
%specially designed in trans control
eval(['load ' ioDir, 'wellCtrl_' int2str(wellSchedule) '.mat']);% ctrlMode ctrl
tSchedule = cumsum(ctrl(:,end));
wellCtrl = zeros(size(time, 1), size(ctrl, 2) - 1);
for iStep = 1 : size(time, 1)
    tempTime = find(tSchedule >= time(iStep));
    wellCtrl(iStep, :) = ctrl(tempTime(1), 1 : end - 1);
end
if strcmp(ctrlParam, 'trans')
    eval(['load ' ioDir 'trans_' int2str(schedule)]);
    control = trans;
else
    control = wellCtrl;
end
end

function [stateRecord, WBstateRecord, psRecord] = linearInter(isPS, isLog, ioDir, time, WBvariables,...
    ctrlTraining, ctrlTarget, trainingSchedule, trainPVI, wellPerf, WIs, wellTarget)
eval(['load ' ioDir 'reducedInfo_' int2str(trainingSchedule(1))]);
stateReduced = rBasis(:,1); % initalize redueced state at t = 0
psRecord = zeros(size(time)); % record what point selected at each time step
rStateRecord = zeros(size(stateReduced, 1),size(time, 1));
rStateRecord(:,1) = stateReduced; % initializing t = 0
targetPVI = 0; % starting with 0 PVI
PVIrecord = zeros(size(time)); % for debug purpose
for iStep = 1 : size(time, 1) - 1
    targetPVI = calTargetPVI(targetPVI, wellTarget, time, iStep, ...
        stateReduced, phi, WBvariables, wellPerf, WIs); % targetPVI have to be calculated in real time
    selectPoint = pointSelection(isPS, iStep, psRecord, trainPVI, targetPVI, rBasis, stateReduced);
    AccReduced = Accr{iStep,1}*(stateReduced - rBasis(:,iStep));% Ai, Ai+1 ?
    JrInv = Jr{iStep,1};%Ji+1
    ctrlDiff = ctrlDifference(isLog, ctrlTarget, ctrlTraining);
    ctrlReduced = dQdur{iStep,1}*ctrlDiff;
    stateInc = JrInv \ (AccReduced + ctrlReduced);
    stateReduced = rBasis(:,iStep+1) - stateInc;
    rStateRecord(:,iStep+1) = stateReduced;
    psRecord(iStep+1,1) = selectPoint; % mostly for debug purpose
    PVIrecord(iStep+1,1) = targetPVI; 
end
stateRecord = phi * rStateRecord;
WBstateRecord = stateRecord(WBvariables,:);
end

function [selectPoint] = pointSelection(isPS, iStep, psRecord, trainPVI, targetPVI, rBasis, stateReduced)
% control parameters
range = 10; % n points in front, n points back
weightPVI = 10; % weight of PVI over reduced states
epsilon = 1e-3;

if isPS
    selRange = rangeSelection(range, iStep, size(rBasis, 2));   
    trainState = [weightPVI*trainPVI(selRange) /(targetPVI + epsilon); ...
        rBasis(:,selRange') ./ (sum(stateReduced) + epsilon)];
    targetState = [weightPVI*targetPVI /(targetPVI + epsilon); ...
        stateReduced ./ (sum(stateReduced) + epsilon)];
    tempDist = dist([targetState,trainState]); % Q by Q matrix
    distance = tempDist(1,2:end); % first row of dist matrix
    [~, min_index] = min(distance);
    selectPoint = selRange(min_index);
    selectPoint = stuckAvoid(psRecord, selectPoint, iStep, size(rBasis, 2));
else
    selectPoint = iStep;
end
end

function [PVI] = calTargetPVI(targetPVI, ctrlSchedule, time, iStep, ...
    stateReduced, Phi, WBvariables, wellPerf, WIs)
nComp = size(WBvariables, 1) / sum(wellPerf);
timeInterval = [0; diff(time)];
tempState = Phi * stateReduced;
tempBlockPres = reshape(tempState(WBvariables, :), nComp, sum(wellPerf));
blockPres = tempBlockPres(1,:)';
wellBlockBHP = expandBHP(ctrlSchedule, wellPerf);
PVI = targetPVI + WIs' * (blockPres - wellBlockBHP(iStep, :)')...
    * timeInterval(iStep);
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

function [wellBlockBHP] = expandBHP(wellBHP, wellPerf)
wellBlockBHP = [];
for iWell = 1: size(wellPerf, 2)
    tempBlock = wellBHP(:,iWell) * ones(1, wellPerf(iWell));
    wellBlockBHP = cat(2, wellBlockBHP, tempBlock);
end
end

function [ctrlDiff] = ctrlDifference(isLog, ctrlTarget, ctrlTraining)
if isLog
    ctrlDiff = ctrlTraining .*(log(ctrlTarget) - log(ctrlTraining));
else
    ctrlDiff = ctrlTarget - ctrlTraining;
end
end




