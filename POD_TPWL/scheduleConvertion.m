function [BHPconvert, tStep]=scheduleConvertion(scheduleFile)
% this is a helper function to help convert the well schedule from input
% file format (e.g. 1000*10) to BHP at each time step
% 
% called by: TPWL_attemp
% input: scheduleFile, string variable (e.g. training110)
eval(['load ' scheduleFile]);
load stateVariable110 time % vector storing absolute time at each step
freqBHP = 1000;
stopTimeTPWL = 10000; % the stop time for the test case
stopStep = find(time >= stopTimeTPWL); % truncate the time
stopStep = stopStep(1); % 128 varialbes
tStep = time(1:stopStep);
tSchedule = freqBHP:freqBHP:stopTimeTPWL;
tSchedule = tSchedule';
tScheduleAdd = freqBHP+0.01:freqBHP:stopTimeTPWL-freqBHP+0.01;
tScheduleAdd = tScheduleAdd';
tSchedule = [0; tSchedule; tScheduleAdd];
tSchedule = sort(tSchedule);
bhp = bhp(1:end - 1,:); % last line is redundant
bhpAdd = zeros(size(bhp,1)*2, size(bhp,2));
bhpAdd(1:2:end-1,:)= bhp;
bhpAdd(2:2:end,:) = bhp;
BHPconvert = interp1(tSchedule,bhpAdd,tStep); %128 varialbes
end
