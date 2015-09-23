function [] = TPWL_direct(caseDir, trainingSchedule, targetSchedule)
ioDir = [caseDir 'data/'];

var = struct;
var = loadDerivative(var, ioDir, trainingSchedule);
var = loadSanpshots(var, ioDir, trainingSchedule);
[ctrlTraining] = scheduleConvert(ioDir, trainingSchedule(1), var.time, 'well');
[ctrlTarget] = scheduleConvert(ioDir, targetSchedule, var.time, 'well');
var = interpolation(var, ctrlTraining, ctrlTarget);
% hacky part
stateRecord = var.StateRecord;
WBstateRecord = var.WBstate;
WBvariables = var.WBvar;
eval(['save -v7.3 ' ioDir 'TPWL_direct_' int2str(targetSchedule) ...
    '.mat stateRecord WBstateRecord WBvariables']);
fprintf('end!\n');
end

% pass deriv by reference
function [var] = loadDerivative(var, ioDir, trainingSchedule)
eval(['load ' ioDir 'Matrix_Acc_' int2str(trainingSchedule(1)) '.mat Acc']);
eval(['load ' ioDir 'Matrix_J_' int2str(trainingSchedule(1)) '.mat J']);
eval(['load ' ioDir 'Matrix_U_' int2str(trainingSchedule(1)) '.mat dQdu']);
var.J = J;
var.A = Acc;
var.U = dQdu; 
end

function [var] = loadSanpshots(var, ioDir, trainingSchedule)
eval(['load ' ioDir 'stateVariable_' int2str(trainingSchedule(1)) ' snapShots WBvariables time']);
var.state = snapShots;
var.time = time;
var.WBvar = WBvariables;
end

function [var] = interpolation(var, ctrlTraining, ctrlTarget)
state = var.state(:,1); % initalize redueced state at t = 0
var.StateRecord = zeros(size(state, 1),size(var.time, 1));
var.StateRecord(:,1) = state; % initializing t = 0
for iStep = 1 : size(var.time, 1) - 1
    AccReduced = var.A{iStep,1}*(state - var.state(:,iStep));% Ai, Ai+1 ?
    JrInv = var.J{iStep,1}; % Ji+1
    ctrlReduced = var.U{iStep,1}*(ctrlTarget(iStep+1,:) - ctrlTraining(iStep+1,:))';
    stateInc = JrInv \ (AccReduced + ctrlReduced);
    state = var.state(:,iStep+1) - stateInc;
    var.StateRecord(:,iStep+1) = state;
    fprintf('step:%i\n',iStep);
end
var.WBstate = var.StateRecord(var.WBvar,:);
end

function [control] = scheduleConvert(ioDir, schedule, time, ctrlParam)
if strcmp(ctrlParam,'well')
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
elseif strcmp(ctrlParam, 'perm')
    eval(['load ' ioDir 'perm_' int2str(schedule)]);
    control = perm;
end
end