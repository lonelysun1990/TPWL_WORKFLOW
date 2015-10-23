function [] = readPlotResults(caseDir, caseName, targetSchedule, trainingSchedule)
% simply read all .mat file needed and plot
% this code will be more elegant and efficient later
iDir = [caseDir 'data/'];
oDir = [iDir 'figure_output/'];
[timeRec, well] = readResults(iDir, targetSchedule, trainingSchedule, 'wellVar');
% plotting part
plotToolKit(oDir, caseName, targetSchedule, timeRec, well, 'wellVar');

% top layer mobility over time
[timeRec, well] = readResults(iDir, targetSchedule, trainingSchedule, 'total_mob');
plotToolKit(oDir, caseName, targetSchedule, timeRec, well, 'total_mob');
end

function [timeRec, well] = readResults(iDir, targetSchedule, trainingSchedule, plotVar)
%% reconstructed by POD-TPWL
eval(['load ' iDir 'recon_well_' int2str(targetSchedule) '.mat time ' plotVar]);
timeRec.recon = time;
eval(['well.recon = ' plotVar ';']);
eval(['clear time ' plotVar]);

%% full order reference from AD-GPRS
eval(['load ' iDir 'full_well_' int2str(targetSchedule) '.mat time ' plotVar]);
timeRec.full = time;
eval(['well.full = ' plotVar ';']);
eval(['clear time ' plotVar]);

%% training from AD-GPRS
eval(['load ' iDir 'full_well_' int2str(trainingSchedule(1)) '.mat time ' plotVar]);
timeRec.ref = time;
eval(['well.ref = ' plotVar ';']);
eval(['clear time ' plotVar]);
end

function [] = plotToolKit(oDir, caseName, targetSchedule, timeRec, well, plotVar)
nWell = size(well.recon,2);
set(0, 'DefaultAxesFontSize', 20);
for iWell = 1:nWell
figure()
hold on;
plot(timeRec.full, well.full(:,iWell),'ro--','linewidth',2);
plot(timeRec.ref, well.ref(:,iWell),'k--','linewidth',2);
plot(timeRec.recon, well.recon(:,iWell),'b^--','linewidth',2);
legend('ADGPRS','Training','POD-TPWL','location','best');
if strcmp(plotVar, 'wellVar')
    axis([0 max(timeRec.recon) ...
	floor(min([well.ref(:,iWell); well.full(:, iWell); well.recon(:,iWell)])*0.99) ...
	ceil(max([well.ref(:,iWell); well.full(:, iWell); well.recon(:,iWell)])*1.01) ...
	]);
    xlabel('Time (day)');
    ylabel('Well BHP (psia)');
    figure_name = [oDir, caseName, '_schedule_' int2str(targetSchedule) '_well_' int2str(iWell)];
else
    axis([0 max(timeRec.recon) ...
	floor(min([well.ref; well.full; well.recon])*0.99) ...
	ceil(max([well.ref; well.full; well.recon])*1.01) ...
	]);
    xlabel('Time (day)');
    ylabel('Total mobility (lb mol RB^{-1} cP^{-1})');
    figure_name = [oDir, caseName, '_schedule_' int2str(targetSchedule) '_mobility'];    
end
eval(['print -dpng -r300 -cmyk -zbuffer ' figure_name '.png']);
end
end




