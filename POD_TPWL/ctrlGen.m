% generate well control
function [] = ctrlGen()
caseDir = '../trans_control/';
templateDir = 'input_template/';
ioDir = [caseDir, 'data/'];
schedule = 700;
nWells = 2;
interNum = 8;% number of interval
ctrlMode = 'rate';
genCtrl = 'file_percent'; % 1. file; 2. pattern generate; 
totalRate = 4.15e4; % reservoir m3/day
[interLen, ctrlParam] = patternGen(ioDir, genCtrl, interNum, nWells, totalRate);
inputAD(caseDir, templateDir, ctrlMode, ctrlParam, schedule, nWells, interLen);
ctrl = matFile(ioDir, interLen, ctrlParam, ctrlMode, schedule);
schedulePlot(ctrl, ioDir, schedule);
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

function [] = inputAD(caseDir, templateDir, ctrlMode, ctrlParam, schedule, nWells, interLen)
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
f_input = fopen([caseDir, templateDir, 'wells_' int2str(schedule) '.in'], 'w');
fprintf(f_input, str_master);
fclose(f_input);
end

function[ctrl] = matFile(ioDir, interLen, ctrlParam, ctrlMode, schedule)
ctrl = cat(2, ctrlParam, interLen);
eval(['save -v7.3 ' ioDir, 'wellCtrl_' int2str(schedule) ' ctrlMode ctrl']);
end

function [wellNames] = nameWell(nWells)
wellNames = {};
for iWell = 1: nWells
    wellNames = cat(2, wellNames, {['W00' int2str(iWell)]});
end
end

function [] = schedulePlot(ctrl, ioDir, schedule)
% time reshape
timeTemp = (cumsum(ctrl(:,end))* ones(1,2))';
timeTemp_2 = timeTemp(:);
timeRec = [0;timeTemp_2(1:end - 1)];
% wellCtrl reshape
wellCtrl = zeros(size(ctrl, 1)*2, size(ctrl, 2) -1);
wellCtrl(1:2:end-1) = ctrl(:,1:end-1);
wellCtrl(2:2:end) = ctrl(:,1:end-1);
% plot part
oDir = [ioDir 'figure_output/'];
set(0,'DefaultAxesFontSize', 20);
colorStyle = {'b-','r--','g--','m--'};
figure();
for iWell = 1 : size(ctrl, 2) -1
    plot(timeRec, wellCtrl(:,iWell), colorStyle{iWell},'linewidth',2);
    hold on;
end
xlabel('Time (day)');
ylabel('Well Rate (m^3 / day)');
legend('Well 1','Well 2','Well 3','Well 4');
figure_name = [oDir 'well_schedule_' int2str(schedule)];
eval(['print -dpng -r300 -cmyk -zbuffer ' figure_name '.png']);
end
