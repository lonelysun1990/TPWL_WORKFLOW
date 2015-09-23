function [] = inputAD(isTraining, schedule, caseDir, templateDir)
% templateDir = 'input_template/';
%% check system
[~, k2] = system('uname -a'); 
[~, k4] = system('ver');
if strfind(k2, 'Linux') % Linux OS
    input_linux(isTraining, schedule, caseDir, templateDir);
elseif strfind(k4, 'Microsoft Windows')% Windows OS
    input_win(isTraining, schedule, caseDir, templateDir);
end
end

function [] = input_linux(isTraining, schedule, caseDir, templateDir)
for iSchedule = 1: length(schedule)
    if isTraining
        scheduleDir = ['training_',int2str(iSchedule),'/'];
    else
        scheduleDir = ['target_',int2str(iSchedule),'/']; % just for now
    end
    system(['rm -rf ' caseDir scheduleDir]);
    system(['mkdir ' caseDir scheduleDir]);
    system(['cp ' templateDir '*.sh ' caseDir scheduleDir]);
    system(['cp ' templateDir '*.in ' caseDir scheduleDir]);
    inputModify(schedule(iSchedule), caseDir, scheduleDir);
end
end

function [] = input_win(isTraining, schedule, caseDir, templateDir)
% implement later
end

function [] = inputModify(schedule, caseDir, scheduleDir)
template = [caseDir scheduleDir 'gprs_template.in'];
newFile = [caseDir scheduleDir 'gprs.in'];
f_template = fopen(template,'r');
f_new = fopen(newFile,'w');
labelStr = '&P1';
numline = 0;
while 1
    numline = numline + 1;
    tline = fgets(f_template, 200);
    if tline ~= -1
        tline = regexprep(tline, labelStr, int2str(schedule));
        fprintf(f_new, tline);
    else
        break;
    end
end
fclose(f_template);
fclose(f_new);
end