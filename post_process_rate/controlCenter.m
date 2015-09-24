% main function
function [] = controlCenter()
clear *;
clc;
%% switches
loadTraining = 0;
loadFullOrder = 0;
reRunTraining = 0;
reRunFullOrder = 0;
isPOD = 0;
isTPWL = 1;
isPS = 1; % point selection
isTPWLfull = 0;
isPlotResult = 1;

%% parameters
rootDir = '../rate_control/';
% caseName = 'CO2_Aquifer';
caseName = 'CO2_2COMP';
% caseName = 'CO2_SYN';
caseDir = [rootDir caseName '/'];
templateDir = ['../input_template/' caseName '/'];
trainingSchedule = [500, 510];
targetSchedule = 520;

%% operations
trainingAD(loadTraining, reRunTraining, caseDir, caseName, ...
    trainingSchedule, templateDir);
fullTestAD(loadFullOrder, reRunFullOrder, caseDir, targetSchedule, ...
    caseName, templateDir);
runPOD(isPOD, caseDir, caseName, trainingSchedule);
runTPWL(isTPWL, isPS, caseDir, trainingSchedule, targetSchedule, caseName, templateDir);
runTPWLfull(isTPWLfull, caseDir, trainingSchedule, targetSchedule, caseName);
plotResult(isPlotResult, caseDir, caseName, targetSchedule, trainingSchedule);
end

function [] = trainingAD(loadTraining, reRunTraining, caseDir, caseName, ...
    trainingSchedule, templateDir)
% by default, the first case in trainingSchedule is with derivatives
if reRunTraining % re-run trainings on AD-GPRS
    inputAD(1, trainingSchedule, caseDir, templateDir);
    runADGPRS(1, trainingSchedule, caseDir);
end
fprintf('load training:\n');
tic
if loadTraining % load training data
    for iCase = 1 : size(trainingSchedule,2)
        scheduleDir = ['training_',int2str(iCase),'/'];
        % read snapshots
        readHDF_attemp(iCase == 1, trainingSchedule(iCase), caseDir, scheduleDir, caseName);
        % read jacobian
        if iCase ==1
            readJacobi_attemp(caseName, trainingSchedule(iCase), caseDir);
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
    runADGPRS(0, targetSchedule, caseDir);
end
if loadFullOrder
    for iCase = 1 : size(targetSchedule)
        scheduleDir = ['target_',int2str(iCase),'/']; % just for now
        readHDF_attemp(0, targetSchedule(iCase), caseDir, scheduleDir, caseName);
        flashCal(caseDir, 0, 0, targetSchedule, 0, caseName, templateDir);
    end 
end
end

function [] = runPOD(isPOD, caseDir, caseName, trainingSchedule)
% POD
if isPOD
    fprintf('POD:\n');
    tic
    POD_attemp(caseDir, caseName, trainingSchedule);
    toc
end
end

function [] = runTPWL(isTPWL, isPS, caseDir, trainingSchedule, targetSchedule, caseName, templateDir)
% TPWL
if isTPWL
    fprintf('TPWL:\n');
    tic
    TPWL_attemp(isPS, caseDir, caseName, trainingSchedule, targetSchedule);
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