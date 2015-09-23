function [] = readPlotResults(caseDir, caseName, targetSchedule, trainingSchedule)
% simply read all .mat file needed and plot
% this code will be more elegant and efficient later
iDir = [caseDir 'data/'];
oDir = [iDir 'figure_output/'];
[timeRec, well] = readResults(iDir, targetSchedule, trainingSchedule);
% plotting part
plotToolKit(oDir, caseName, targetSchedule, timeRec, well);
end

function [timeRec, well] = readResults(iDir, targetSchedule, trainingSchedule)
%% reconstructed by POD-TPWL
eval(['load ' iDir 'recon_well_' int2str(targetSchedule) '.mat time wellVar']);
timeRec.recon = time;
well.recon = wellVar;
clear time wellVar;

%% full order reference from AD-GPRS
eval(['load ' iDir 'full_well_' int2str(targetSchedule) '.mat time wellVar']);
timeRec.full = time;
well.full = wellVar;
clear time wellVar;

%% training from AD-GPRS
eval(['load ' iDir 'full_well_' int2str(trainingSchedule(1)) '.mat time wellVar']);
timeRec.ref = time;
well.ref = wellVar;
clear time wellVar;
end

function [] = plotToolKit(oDir, caseName, targetSchedule, timeRec, well)
nWell = size(well.recon,2);
set(0, 'DefaultAxesFontSize', 20);
for iWell = 1:nWell
figure(iWell)
hold on;
plot(timeRec.full, well.full(:,iWell),'ro--','linewidth',2);
plot(timeRec.ref, well.ref(:,iWell),'k--','linewidth',2);
plot(timeRec.recon, well.recon(:,iWell),'b^--','linewidth',2);
legend('ADGPRS','Training','POD-TPWL','location','best');
axis([0 max(timeRec.recon) ...
	floor(min([well.ref(:,iWell); well.full(:, iWell); well.recon(:,iWell)])*0.99) ...
	ceil(max([well.ref(:,iWell); well.full(:, iWell); well.recon(:,iWell)])*1.01) ...
	]);
xlabel('Time (day)');
ylabel('Well BHP (psia)');
figure_name = [oDir, caseName, '_schedule_' int2str(targetSchedule) '_well_' int2str(iWell)];
eval(['print -dpng -r300 -cmyk -zbuffer ' figure_name '.png']);
end
end




