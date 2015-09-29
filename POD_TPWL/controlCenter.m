% main function
function [] = controlCenter()
clear *;
clc;
%% switches
loadTraining = 1;
loadFullOrder = 1;
reRunTraining = 1;
reRunFullOrder = 1;
isPOD = 1;
isTPWL = 1;
isPS = 1; % point selection
isLog = 1; % use log transmissibility
isTPWLfull = 0;
isPlotResult = 1;

%% parameters
caseDir = '..\trans_control\';
templateDir = '..\input_template\';
% caseDir = '../trans_control/';

% caseName = 'CO2_2D'; % 46x46 horizontal 3 components
% caseName = 'CO2_2D_2COMP'; % 46x46 horizontal 2 components
% caseName = 'CO2_layer';% 46x30 vertical
caseName = 'CO2_test'; % 46x30 horizontal

trainingSchedule = [1, 2];
targetSchedule = 3;
wellSchedule = 700;

%% operations
trainingAD(loadTraining, reRunTraining, caseDir, caseName, trainingSchedule, wellSchedule);
fullTestAD(loadFullOrder, reRunFullOrder, caseDir, targetSchedule, caseName, wellSchedule);

runPOD(isPOD, caseDir, caseName, trainingSchedule);
runTPWL(isTPWL, isPS, isLog, caseDir, trainingSchedule, targetSchedule, caseName, wellSchedule);
runTPWLfull(isTPWLfull, caseDir, trainingSchedule, targetSchedule, caseName);
plotResult(isPlotResult, caseDir, caseName, wellSchedule, targetSchedule, trainingSchedule);
end

function [] = trainingAD(loadTraining, reRunTraining, caseDir, caseName, ...
    trainingSchedule, wellSchedule)
% by default, the first case in trainingSchedule is with derivatives
if reRunTraining % re-run trainings on AD-GPRS
    fprintf('rerun training:\n');
    tic
    inputADGPRS(1, trainingSchedule, caseDir, wellSchedule);
    runADGPRS(1, trainingSchedule, caseDir);
    toc
end
if loadTraining % load training data
    fprintf('load training:\n');
    tic
    for iCase = 1 : size(trainingSchedule,2)
        scheduleDir = ['training_',int2str(iCase),'/'];
        % read snapshots
        readHDF_attemp(iCase == 1, trainingSchedule(iCase), caseDir, scheduleDir, caseName);
        % read jacobian
        if iCase ==1
            readJacobi_attemp(caseName, trainingSchedule(iCase), caseDir);
        end
        % flash calculation
        flashCal(caseDir, 0, 0, trainingSchedule(iCase), 0, caseName, wellSchedule);
    end
    toc
end
end

function [] = fullTestAD(loadFullOrder, reRunFullOrder, caseDir, targetSchedule, ...
    caseName, wellSchedule)
if reRunFullOrder
    inputADGPRS(0, targetSchedule, caseDir, wellSchedule);
    runADGPRS(0, targetSchedule, caseDir);
end
if loadFullOrder
    for iCase = 1 : size(targetSchedule)
        scheduleDir = ['target_',int2str(iCase),'/'];
        readHDF_attemp(0, targetSchedule(iCase), caseDir, scheduleDir, caseName);
        flashCal(caseDir, 0, 0, targetSchedule(iCase), 0, caseName, wellSchedule);
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

function [] = runTPWL(isTPWL, isPS, isLog, caseDir, trainingSchedule, targetSchedule, ...
    caseName, wellSchedule)
% TPWL
if isTPWL
    fprintf('TPWL:\n');
    tic
    TPWL_attemp(isPS, isLog, caseDir, caseName, trainingSchedule, targetSchedule, wellSchedule);
    toc
    fprintf('TPWL flash:\n');
    tic
    flashCal(caseDir, 1, 1, targetSchedule, trainingSchedule, caseName, wellSchedule);
    toc
end
end

function [] = runTPWLfull(isTPWLfull, caseDir, trainingSchedule, targetSchedule, caseName)
% TPWL with full order, no POD
if isTPWLfull
    TPWL_direct(caseDir, trainingSchedule, targetSchedule);
    flashCal(caseDir, 1, 0, targetSchedule, trainingSchedule, caseName);
end
end

function [] = plotResult(isPlotResult, caseDir, caseName, wellSchedule, targetSchedule, trainingSchedule)
if isPlotResult
    readPlotResults(caseDir, caseName, wellSchedule, targetSchedule, trainingSchedule)
end
end