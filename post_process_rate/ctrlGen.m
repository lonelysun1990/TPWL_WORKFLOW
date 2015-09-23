% generate well control
function [] = ctrlGen()
rootDir = '../rate_control/';
caseName = 'CO2_SYN';
caseDir = [rootDir caseName '/'];
ioDir = [caseDir, 'data/'];
schedule = 810;
nWells = 2;
interNum = 8;% number of interval
ctrlMode = 'rate';
genCtrl = 'file_percent'; % 1. file; 2. pattern generate; 
totalRate = 3255*3; % 8974.68; % reservoir m3/day
[interLen, ctrlParam] = patternGen(ioDir, genCtrl, interNum, nWells, totalRate);
inputAD(caseDir, ctrlMode, ctrlParam, schedule, nWells, interLen);
matFile(ioDir, interLen, ctrlParam, ctrlMode, schedule);
end

function [interLen, ctrlParam] = patternGen(ioDir, genCtrl, interNum, nWells, totalRate)

if strcmp(genCtrl, 'file')
    eval(['load ' ioDir 'well_input.txt']);
    if size(well_input, 2) - 1 == nWells
        interLen = well_input(:,end);
        ctrlParam = well_input(:,1:end-1);
    else
        error('Number of wells mismatch!');
    end
elseif strcmp(genCtrl, 'file_percent')
    eval(['load ' ioDir 'well_input.txt']);
    if size(well_input, 2) - 1 == nWells
        interLen = well_input(:,end);
        ctrlParam = totalRate * well_input(:,1:end-1);
    else
        error('Number of wells mismatch!');
    end
else
    % pattern generate
end
end

function [] = inputAD(caseDir, ctrlMode, ctrlParam, schedule, nWells, interLen)
head_str = {'WCONINJE\n'};
wellNames = nameWell(size(ctrlParam, 2));
well_str = {'\tGAS\tOPEN\tRATE\t', ' 2* /\n'};
str_master = '';
for iInter = 1: size(interLen, 1)
    ctrl_str = '';
    for iWell = 1 : nWells
        ctrl_str = strcat(ctrl_str, num2str(wellNames{iWell}), well_str{1}, ...
            num2str(ctrlParam(iInter,iWell)), well_str{2});
    end
    time_pattern = {'/\n\nTSTEP\n1*', '\n/\n\n'};
    time_str = strcat(time_pattern{1}, num2str(interLen(iInter)), time_pattern{2});
    str_master = strcat(str_master, head_str, ctrl_str, time_str);
end
str_master = strjoin(str_master);
f_input = fopen([caseDir, 'input_template/wells_' int2str(schedule) '.in'], 'w');
fprintf(f_input, str_master);
fclose(f_input);
end

function matFile(ioDir, interLen, ctrlParam, ctrlMode, schedule)
ctrl = cat(2, ctrlParam, interLen);
eval(['save -v7.3 ' ioDir, 'wellCtrl_' int2str(schedule) ' ctrlMode ctrl']);
end

function [wellNames] = nameWell(nWells)
wellNames = {};
for iWell = 1: nWells
    wellNames = cat(2, wellNames, {['W00' int2str(iWell)]});
end
end
