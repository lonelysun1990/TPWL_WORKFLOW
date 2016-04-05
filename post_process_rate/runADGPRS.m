function [finished] = runADGPRS(isTraining, schedule, caseDir, isMultiTrain)
% schedule here is a vector
% check which system we are in
[~, k2] = system('uname -a'); 
[~, k4] = system('ver');
%% run ADGPRS
if strfind(k2, 'Linux') % Linux OS
    [jobID, jobStatus] = runAD_linux(isTraining, schedule, caseDir, isMultiTrain);
elseif strfind(k4, 'Microsoft Windows')% Windows OS
    jobStatus = runAD_win(1, isTraining, schedule);
end

%% check the status
if strfind(k2, 'Linux') % Linux OS
    checkRunAD(jobID, jobStatus);
end
end

% no backward compatibility yet
function [jobStatus] = runAD_win(primaryTraining, isTraining, schedule)
jobStatus = zeros(length(schedule),1);
exeDir = '..\..\excutable\'; % relative to schedule dir
% job status: 0 for un-finished jobs, 1 for finished jobs
for iCase = 1: size(jobStatus,1)
    fprintf(['Run Win AD-GPRS schedule ',int2str(schedule(iCase)),':\n']);
    if isTraining
        scheduleDir = ['training_',int2str(iCase),'/'];
    else
        scheduleDir = ['target_',int2str(iCase),'/']; % just for now
    end
    workDir = cd(scheduleDir);
    if primaryTraining
        system([exeDir,'Optimization_x64.exe opt.in > screen_o_opt.txt']);
    else
        system([exeDir, 'ADGPRS_x64.exe gprs.in > screen_o_gprs.txt']);
    end
    cd(workDir);
    jobStatus(iCase) = 1; % change job status to finished
    fprintf(['Run schedule ',int2str(schedule(iCase)), ' finished!\n']);
end
end

function [jobID, jobStatus] = runAD_linux(isTraining, schedule, caseDir, isMultiTrain)
jobStatus = zeros(length(schedule),1);
jobID = zeros(size(jobStatus));
for iCase = 1 : size(jobStatus,1)
    fprintf(['Run Linux AD-GPRS schedule ',int2str(schedule(iCase)),':\n']);
    if isTraining
        scheduleDir = ['training_',int2str(iCase),'/'];
    else
        scheduleDir = ['target_',int2str(iCase),'/']; % just for now
    end
    workDir = cd([caseDir, scheduleDir]);
    % modified 10-24-2015, add multiple training with derivatives
    % either primary training case, or multi-trianing derivative is on
    if (isTraining && iCase == 1) || (isTraining && isMultiTrain) % 
        [k1, k2] = system(['ssh cees-rcf "cd ' pwd '; qsub optimize.sh"']);
        jobID(iCase) = sscanf(k2, '%i',[1,1]);
    else % else non-primary training or full order test
        [k1, k2] = system(['ssh cees-rcf "cd ' pwd '; qsub simulate.sh"']);
        jobID(iCase) = sscanf(k2, '%i',[1,1]);
    end
    cd(workDir);
end
end

% only used when running on cluster
function [finished] = checkRunAD(jobID, jobStatus)
while true
    pause(5);
    for iCase = 1:size(jobStatus,1)
        if jobStatus(iCase) == 0 % if not finished yet
            [k1, k2] = system(['ssh cees-rcf qstat ' int2str(jobID(iCase))]); % check
            if k1>0 || ~isempty(strfind(k2, 'C default')) % run finished
                jobStatus(iCase) = 1;
            end
        end
    end
    finished = sum(jobStatus) == size(jobStatus, 1);
    if  finished % all entries are 1
        fprintf('all runs are finished!\n');
        break;
    end
end
end





