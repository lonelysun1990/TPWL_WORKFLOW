% generate well control
function [] = ctrlGen()
% directories
rootDir = '../rate_control/';

%
caseName = 'CO2_SYN';
% caseName = 'CO2_2COMP';
%
caseDir = [rootDir caseName '/'];
templateDir = ['../input_template/' caseName '/'];
iDir = ['../model_data/' caseName '/well/'];
oDir = [caseDir, 'data/'];
%
schedule = 2014;
nWells = 2;
interNum = 8;% number of interval
ctrlMode = 'rate';
genCtrl = 'file_percent'; % 1. file; 2. pattern generate; 
totalRate = 3255; % 8974.68; % reservoir m3/day
[interLen, ctrlParam, well_input] = patternGen(iDir, genCtrl, interNum, nWells, totalRate);
inputAD(templateDir, ctrlMode, ctrlParam, schedule, nWells, interLen);
matFile(oDir, interLen, ctrlParam, ctrlMode, schedule);
wellScheduleLog(iDir, schedule, ctrlMode, well_input, totalRate);
end

function [interLen, ctrlParam, well_input] = patternGen(iDir, genCtrl, interNum, nWells, totalRate)

if strcmp(genCtrl, 'file')
    eval(['load ' iDir 'well_input.txt']);
    if size(well_input, 2) - 1 == nWells
        interLen = well_input(:,end);
        ctrlParam = well_input(:,1:end-1);
    else
        error('Number of wells mismatch!');
    end
elseif strcmp(genCtrl, 'file_percent')
    eval(['load ' iDir 'well_input.txt']);
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

function [] = inputAD(templateDir, ctrlMode, ctrlParam, schedule, nWells, interLen)
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
f_input = fopen([templateDir, 'wells_' int2str(schedule) '.in'], 'w');
fprintf(f_input, str_master);
fclose(f_input);
end

function matFile(iDir, interLen, ctrlParam, ctrlMode, schedule)
ctrl = cat(2, ctrlParam, interLen);
eval(['save -v7.3 ' iDir, 'wellCtrl_' int2str(schedule) ' ctrlMode ctrl']);
end

function [wellNames] = nameWell(nWells)
wellNames = {};
for iWell = 1: nWells
    wellNames = cat(2, wellNames, {['W00' int2str(iWell)]});
end
end

function [] = wellScheduleLog(iDir, schedule, ctrlMode, well_input, param)
f_input = fopen([iDir, 'well_schedule_log.txt'], 'a');
time_var = clock;
fprintf(f_input, '%s %d:%d:%d\t schedule: %d\t contrl mode: %s\t %d\n', date, time_var(4), time_var(5), floor(time_var(6)), schedule, ctrlMode, param);
fprintf(f_input, [repmat('%f\t', 1, size(well_input, 2)) '\n'], well_input');
fprintf(f_input, '\n\n');
fclose(f_input);
end



