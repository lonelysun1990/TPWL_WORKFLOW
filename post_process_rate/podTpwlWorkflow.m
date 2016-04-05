% called by NOMAD
function [obj_output] = podTpwlWorkflow(well_param)
%% workflow switches
runADonly = 0;

loadTraining = 0;
loadFullOrder = 0;
reRunTraining = 0;
reRunFullOrder = 0;
isPOD = 0;
isTPWL = 1;
% isTPWLfull = 0;
isPlotResult = 0;

%% capability swithes
isPS = 1; % point selection (runTPWL, TPWL_attemp)
isMultiTrain = 1; % multiple training with derivatives (trainingAD, )

%% parameters
rootDir = '/data/cees/zjin/TPWL_WORKFLOW/';

% caseName = 'CO2_Aquifer';
% caseName = 'CO2_2COMP';
% caseName = 'CO2_SYN';
caseName = 'CO2_SYN_4Well';

caseDir = [rootDir 'rate_control/' caseName '/'];
templateDir = [rootDir 'input_template/' caseName '/'];
trainingSchedule = [1201, 1202, 1203, 1204, 1205];
targetSchedule = 1001;
optSchedule = 1001;

%% operations
trainingAD(loadTraining, reRunTraining, isMultiTrain, caseDir, caseName, ...
    trainingSchedule, templateDir);
fullTestAD(loadFullOrder, reRunFullOrder, caseDir, targetSchedule, ...
    caseName, templateDir);
runPOD(isPOD, isMultiTrain, caseDir, caseName, trainingSchedule);
% generate well schedules in each optimization iteration
genWellSchedule(well_param, optSchedule);
% runAD(runADonly);
runAD(runADonly, runADonly, 0, caseDir, caseName, ...
    optSchedule, templateDir);
runTPWL(isTPWL, isPS, isMultiTrain, caseDir, trainingSchedule, optSchedule, caseName, templateDir);
% runTPWLfull(isTPWLfull, caseDir, trainingSchedule, targetSchedule, caseName);
plotResult(isPlotResult, caseDir, caseName, targetSchedule, trainingSchedule);
obj_val = objEval(caseDir, optSchedule, isTPWL);
extr_bar = extrBarEval(well_param);
obj_output = [obj_val; extr_bar];
% fprintf(['objective value = ' int2str(obj_val) '\n']);
end

function runAD(loadTraining, reRunTraining, isMultiTrain, caseDir, caseName, ...
    trainingSchedule, templateDir)
% by default, the first case in trainingSchedule is with derivatives
if reRunTraining % re-run trainings on AD-GPRS
    inputAD(1, trainingSchedule, caseDir, templateDir);
    runADGPRS(1, trainingSchedule, caseDir,isMultiTrain);
end
fprintf('load training:\n');
tic
if loadTraining % load training data
    for iCase = 1 : size(trainingSchedule,2)
        scheduleDir = ['training_',int2str(iCase),'/'];
        % read snapshots
        readHDF_attemp(iCase == 1, isMultiTrain, trainingSchedule(iCase), caseDir, scheduleDir, caseName);
        % read jacobian
        if iCase ==1 || isMultiTrain
            readJacobi_attemp(caseName, trainingSchedule(iCase), caseDir, iCase);
        end
        % flash calculation
        flashCal(caseDir, 0, 0, trainingSchedule(iCase), 0, caseName, templateDir);
    end
end
toc
end

function [] = trainingAD(loadTraining, reRunTraining, isMultiTrain, caseDir, caseName, ...
    trainingSchedule, templateDir)
% by default, the first case in trainingSchedule is with derivatives
if reRunTraining % re-run trainings on AD-GPRS
    inputAD(1, trainingSchedule, caseDir, templateDir);
    runADGPRS(1, trainingSchedule, caseDir,isMultiTrain);
end
fprintf('load training:\n');
tic
if loadTraining % load training data
    for iCase = 1 : size(trainingSchedule,2)
        scheduleDir = ['training_',int2str(iCase),'/'];
        % read snapshots
        readHDF_attemp(iCase == 1, isMultiTrain, trainingSchedule(iCase), caseDir, scheduleDir, caseName);
        % read jacobian
        if iCase ==1 || isMultiTrain
            readJacobi_attemp(caseName, trainingSchedule(iCase), caseDir, iCase);
        end
        % flash calculation
        flashCal(caseDir, 0, 0, trainingSchedule(iCase), 0, caseName, templateDir);
    end
end
toc
end

function [] = fullTestAD(loadFullOrder, reRunFullOrder, caseDir, ...
    targetSchedule, caseName, templateDir)
if reRunFullOrder
    inputAD(0, targetSchedule, caseDir, templateDir);
    runADGPRS(0, targetSchedule, caseDir, 0);
end
if loadFullOrder
    for iCase = 1 : size(targetSchedule)
        scheduleDir = ['target_',int2str(iCase),'/']; % just for now
        readHDF_attemp(0, 0, targetSchedule(iCase), caseDir, scheduleDir, caseName);
        flashCal(caseDir, 0, 0, targetSchedule, 0, caseName, templateDir);
    end 
end
end

function [] = runPOD(isPOD, isMultiTrain, caseDir, caseName, trainingSchedule)
% POD
if isPOD
    fprintf('POD:\n');
    tic
    POD_attemp(caseDir, caseName, trainingSchedule, isMultiTrain);
    toc
end
end

function [] = runTPWL(isTPWL, isPS, isMultiTrain, caseDir, trainingSchedule, targetSchedule, caseName, templateDir)
% TPWL
if isTPWL
    fprintf('TPWL:\n');
    tic
    TPWL_attemp(isPS, isMultiTrain, caseDir, caseName, trainingSchedule, targetSchedule);
    toc
    fprintf('TPWL flash:\n');
    tic
    flashCal(caseDir, 1, 1, targetSchedule, trainingSchedule, caseName, templateDir);
    toc
end

end

function [] = runTPWLfull(isTPWLfull, caseDir, trainingSchedule, targetSchedule, caseName)
% TPWL with full order, no POD
if isTPWLfull
    TPWL_direct(caseDir, trainingSchedule, targetSchedule);
    flashCal(caseDir, 1, 0, targetSchedule, trainingSchedule, caseName, templateDir);
end
end

function [] = plotResult(isPlotResult, caseDir, caseName, targetSchedule, trainingSchedule)
if isPlotResult
    readPlotResults(caseDir, caseName, targetSchedule, trainingSchedule)
end
end

function [obj_val] = objEval(caseDir, optSchedule, isTPWL)
obj_val = objEvaluation(caseDir, optSchedule, isTPWL);
end

function [extr_bar] = extrBarEval(well_param)
nWells = 4;
extr_bar = zeros(nWells*2, 1);
ctrl_param = reshape(well_param, [], nWells - 1);
ctrl_sum = sum(ctrl_param,2);
extr_bar(1 : nWells, :) = ctrl_sum - 0.95;    % P1 + P5 + P9 < 0.95, and so on.
extr_bar(nWells+1 : end, :) = 0.5 - ctrl_sum; % P1 + P5 + P9 > 0.5, and so on.
end



