function [] = flashCal(caseDir, isTPWL, isPOD, schedule, trainingSchedule, caseName, templateDir)
ioDir = [caseDir 'data/'];
flashDir = [caseDir 'schedule_flash/'];
exeDir = '..\..\excutable\'; % relative to schedule_flash
% setup flash folder
flashSetup(templateDir, flashDir);
% start flash
fprintf(['flash for schedule ', int2str(schedule),':\n']);
eval(['load ' ioDir caseName '.mat']);
if isTPWL
    eval(['load ' ioDir 'stateVariable_' int2str(trainingSchedule(1)) '.mat time WBindices']);
    if isPOD
        eval(['load ' ioDir 'priVarTPWL_' int2str(schedule) ...
            ' stateRecord WBstateRecord WBvariables']);
    else
        eval(['load ' ioDir 'TPWL_direct_' int2str(schedule) ...
            ' stateRecord WBstateRecord WBvariables']);
    end
else % full order model reference solution
    eval(['load ' ioDir 'stateVariable_' int2str(schedule) '.mat snapShots WBstate WBvariables WBindices time']);
    WBstateRecord = WBstate;
end

%% data preparation
nComp = caseObj.nComp;
nWellBlock = size(WBvariables, 1) / nComp;
nCell = caseObj.res_x * caseObj.res_y * caseObj.res_z;
% cellIndices = (1:nCell)';
nWell = caseObj.nWell;
temperature = caseObj.temp; % K
WIs = caseObj.WIs;
wellPerf = caseObj.nWellPerf;
timeStep = size(WBstateRecord, 2);
% mobility_layer = 15;

%% flash workflow
[oDataRC] = doFlash(flashDir, exeDir, 'RC', WBstateRecord, WBindices, ...
    nComp, nWellBlock, temperature, timeStep);
[oDataSC] = doFlash(flashDir, exeDir, 'SC', WBstateRecord, WBindices, ...
    nComp, nWellBlock, temperature, timeStep);
% get total mobility of the layer
% if isTPWL
%     [layerStateRecord, layerIndices] = layerSelect(stateRecord, mobility_layer, caseObj);
% else
%     [layerStateRecord, layerIndices] = layerSelect(snapShots, mobility_layer, caseObj);
% end
% [resDataRC] = doFlash(flashDir, exeDir, 'RC', layerStateRecord, layerIndices, ...
%     nComp, caseObj.res_x*caseObj.res_y, temperature, timeStep);
% get well information
[wellCtrl, ctrlMode] = scheduleConvert(ioDir, schedule, time);
% wellVar = wellRate(oDataRC, oDataSC,  nWell, timeStep, WI, nComp, wellCtrl, ctrlMode);
wellVar = wellRate_ResCond(oDataRC, oDataSC,  nWell, timeStep, WIs, nComp, ...
    wellCtrl, ctrlMode, wellPerf);
if isTPWL % TPWL
    eval(['save -v7.3 ' ioDir 'recon_well_' int2str(schedule) ' wellVar time']);
%     eval(['save -v7.3 ' ioDir 'priVarTPWL_' int2str(schedule) ' resDataRC -append']);
else % full order model reference solution
    eval(['save -v7.3 ' ioDir 'full_well_' int2str(schedule) ' wellVar time']);
%     eval(['save -v7.3 ' ioDir 'stateVariable_' int2str(schedule) ' resDataRC -append']);
end
fprintf(['flash ',int2str(schedule),' finished!\n']);
end

function [layerStateRecord, layerIndices] = layerSelect(stateRecord, mobility_layer, caseObj)
layerIndices = (caseObj.res_x * caseObj.res_y*(mobility_layer -1)+1:caseObj.res_x * caseObj.res_y*mobility_layer)';
temp_index = reshape([layerIndices*2-1, layerIndices*2]',[], 1);
layerStateRecord = stateRecord(temp_index,:);
end

function [] = flashSetup(templateDir, flashDir)
system(['rm -rf ' flashDir]);
system(['mkdir ' flashDir]);
system(['cp ' templateDir 'flash.sh ' flashDir]);
system(['cp ' templateDir '*.in ' flashDir]);
system(['rm ' flashDir 'gprs_template.in']);
system(['rm ' flashDir 'opt.in']);
system(['rm ' flashDir 'wells_*.in']);             % no need
end

function [oData] = doFlash(flashDir, exeDir, ctrlVar, WBstateRecord, WBindices, ...
    nComp, nWellBlock, temperature, timeStep)
% prepare the flahs input
flashInput(flashDir, ctrlVar, WBstateRecord, WBindices, ...
    nComp, nWellBlock, temperature);

% call ADGPRS to do the flash
[~, k2] = system('uname -a'); 
[~, k4] = system('ver');
if strfind(k2, 'Linux')
    flashLinux(flashDir);
elseif strfind(k4, 'Microsoft Windows')
    flashWin(flashDir, exeDir);
end

% read flash output
oData = flashOutput(flashDir, ctrlVar, nWellBlock, timeStep);
end

function [] = flashWin(flashDir)
% windows will automatically wait program finish
workDir = cd(flashDir);
system([exeDir, 'ADGPRS_x64.exe gprs_flash.in -1 > screen_o_flash.txt']);
cd(workDir);
end

function [finished] = flashLinux(flashDir)
% run flash
workDir = cd(flashDir);
[~, k2] = system(['ssh cees-rcf "cd ' pwd '; qsub flash.sh"']);
flashID = sscanf(k2, '%i',[1,1]);
cd(workDir);
% check status
while true
    pause(1);
    [k1, k2] = system(['ssh cees-rcf qstat ' int2str(flashID)]);
    finished =  k1>0 || ~isempty(strfind(k2, 'C default'));
    % finished = 1 if flash finished
    if finished, break;end
end
end

function [] = flashInput(flashDir, ctrlVar, WBstateRecord, WBindices, ...
    nComp, nWellBlock, temperature)
f_input = fopen([flashDir 'Flash_Input.txt'], 'w');
timeStep = size(WBstateRecord, 2);
fprintf(f_input,'%d\n', nWellBlock * timeStep);
stepVar = (1:timeStep)' * ones(1, nWellBlock);
% blockCount = reshape(WBvariables, nWellBlock, nComp);
% blockCount = ones(timeStep, 1) * blockCount(:,1)';
blockCount = ones(timeStep, 1) * WBindices';
tempVar = temperature * ones(timeStep, 1) * ones(1, nWellBlock);% temperature
if strcmp(ctrlVar, 'RC') % reservoir condtion
    WBstate_temp = permute(reshape(WBstateRecord, nComp, nWellBlock, timeStep),[3, 2, 1]);
    lastComp = 1 - sum(WBstate_temp(:,:,2:end), 3);
    inputMat = cat(3, stepVar, blockCount, WBstate_temp(:,:,1), tempVar, ...
        WBstate_temp(:,:,2:end), lastComp);
elseif strcmp(ctrlVar, 'SC') % surface condition
    oneVar = ones(timeStep, 1) * ones(1, nWellBlock);
    zeroVar = reshape(zeros(timeStep * (nComp - 1), 1) * zeros(1, nWellBlock), ...
        timeStep, nWellBlock, nComp - 1);
    inputMat = cat(3, stepVar, blockCount, oneVar, tempVar, oneVar, ...
        zeroVar);
end
inputMat = reshape(inputMat, timeStep * nWellBlock, 4 + nComp);
fprintf(f_input, [repmat('%g\t', 1, size(inputMat, 2)) '\n'], inputMat');
fclose(f_input);
end

function [outData] = flashOutput(flashDir, ctrlVar, nWellBlock, timeStep)
load([flashDir, 'Flash_Output.txt']);
outData = reshape(Flash_Output, timeStep, nWellBlock, size(Flash_Output, 2)); 
end

function [wellVar] = wellRate(oDataRC, oDataSC,  nWell, timeStep, WI, nComp, ...
wellCtrl, ctrlMode)
nPhase = 2;
wellIndex = ones(timeStep, 1) * WI';
massFracV = oDataSC(:,:,nComp + 5) .* oDataSC(:,:,end - nPhase*2 + 1) ./ ...
    (oDataSC(:,:,nComp + 6) .* oDataSC(:,:,end - nPhase*2 + 2) + ...
    oDataSC(:,:,nComp + 5) .* oDataSC(:,:,end - nPhase*2 + 1));
fluidTransV = massFracV .*(oDataRC(:,:,end - nPhase + 1) + oDataRC(:,:,end)).* ...
    wellIndex .* (oDataRC(:,:,end - nPhase*2 + 1) ./ ...
    oDataSC(:,:,end - nPhase*2 + 1));
wellBlockPres = oDataRC(:,:,3);
wellVar = zeros(timeStep, nWell);
wellPerf = [3,5,5,3]; % not good, only for a particular case
perfNum = cumsum(wellPerf);
for iWell = 1 : nWell
    if strcmp(ctrlMode, 'rate')
        if iWell == 1
            wellVar(:,iWell) = (sum(fluidTransV(:,1:perfNum(iWell)) .* ...
                wellBlockPres(:,1:perfNum(iWell)), 2) + wellCtrl(:,iWell)) ./ ...
                (sum(fluidTransV(:,1:perfNum(iWell)),2));
        else
            wellVar(:,iWell) = (sum(fluidTransV(:,perfNum(iWell - 1)+1:perfNum(iWell)) .* ...
                wellBlockPres(:,perfNum(iWell - 1)+1:perfNum(iWell)), 2) + wellCtrl(:,iWell)) ./ ...
                (sum(fluidTransV(:,perfNum(iWell - 1)+1:perfNum(iWell)),2));
        end
    elseif strcmp(ctrlMode, 'bhp')
        if iWell == 1
            wellVar(:,iWell) = sum(fluidTransV(:,1:perfNum(iWell)).*(wellCtrl(:,iWell) * ...
                ones(1, wellPerf(iWell)) - wellBlockPres(:,1:perfNum(iWell))),2);
        else
            wellVar(:,iWell) = sum(fluidTransV(:,perfNum(iWell-1)+1:perfNum(iWell)).*...
                 (wellCtrl(:,iWell) * ones(1, wellPerf(iWell)) - wellBlockPres(:,perfNum(iWell-1)+1:perfNum(iWell))),2);
        end
    end
end
end

function [wellVar] = wellRate_ResCond(oDataRC, oDataSC,  nWell, timeStep, WIs, nComp, ...
    wellCtrl, ctrlMode, wellPerf)
nPhase = 2;
wellIndex = ones(timeStep, 1) * WIs';
massFracV = oDataSC(:,:,nComp + 5) .* oDataSC(:,:,end - nPhase*2 + 1) ./ ...
    (oDataSC(:,:,nComp + 6) .* oDataSC(:,:,end - nPhase*2 + 2) + ...
    oDataSC(:,:,nComp + 5) .* oDataSC(:,:,end - nPhase*2 + 1));
fluidTransV = massFracV .*(oDataRC(:,:,end - nPhase + 1) + oDataRC(:,:,end)).* wellIndex;
wellBlockPres = oDataRC(:,:,3);
wellVar = zeros(timeStep, nWell);
% wellPerf = [3,5,5,3]; % not good, only for a particular case
perfNum = cumsum(wellPerf);
for iWell = 1 : nWell
    if strcmp(ctrlMode, 'rate')
        if iWell == 1
            wellVar(:,iWell) = (sum(fluidTransV(:,1:perfNum(iWell)) .* ...
                wellBlockPres(:,1:perfNum(iWell)), 2) + wellCtrl(:,iWell)) ./ ...
                (sum(fluidTransV(:,1:perfNum(iWell)),2));
        else
            wellVar(:,iWell) = (sum(fluidTransV(:,perfNum(iWell - 1)+1:perfNum(iWell)) .* ...
                wellBlockPres(:,perfNum(iWell - 1)+1:perfNum(iWell)), 2) + wellCtrl(:,iWell)) ./ ...
                (sum(fluidTransV(:,perfNum(iWell - 1)+1:perfNum(iWell)),2));
        end
    elseif strcmp(ctrlMode, 'bhp')
        if iWell == 1
            wellVar(:,iWell) = sum(fluidTransV(:,1:perfNum(iWell)).*(wellCtrl(:,iWell) * ...
                ones(1, wellPerf(iWell)) - wellBlockPres(:,1:perfNum(iWell))),2);
        else
            wellVar(:,iWell) = sum(fluidTransV(:,perfNum(iWell-1)+1:perfNum(iWell)).*...
                 (wellCtrl(:,iWell) * ones(1, wellPerf(iWell)) - wellBlockPres(:,perfNum(iWell-1)+1:perfNum(iWell))),2);
        end
    end
end
end

function [control, ctrlMode] = scheduleConvert(ioDir, schedule, time)
eval(['load ' ioDir, 'wellCtrl_' int2str(schedule) '.mat']);
tSchedule = cumsum(ctrl(:,end));
control = zeros(size(time, 1), size(ctrl, 2) - 1);
for iStep = 1 : size(time, 1)
    tempTime = find(tSchedule >= time(iStep));
    control(iStep, :) = ctrl(tempTime(1), 1 : end - 1);
end
end
