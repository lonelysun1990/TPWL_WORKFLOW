function [] = readPlotResults(caseDir, caseName, targetSchedule, trainingSchedule)
% simply read all .mat file needed and plot
% this code will be more elegant and efficient later
iDir = [caseDir 'data/'];
oDir = [iDir 'figure_output/'];
[timeRec, well] = readResults(iDir, targetSchedule, trainingSchedule, 'wellVar');
% plotting part
plotToolKit(oDir, caseName, targetSchedule,trainingSchedule, timeRec, well, 'wellVar');

% top layer mobility over time
[timeRec, well] = readResults(iDir, targetSchedule, trainingSchedule, 'total_mob');
plotToolKit(oDir, caseName, targetSchedule, trainingSchedule, timeRec, well, 'total_mob');
% later
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
for iRef = 1 : size(trainingSchedule, 2)
    eval(['load ' iDir 'full_well_' int2str(trainingSchedule(iRef)) '.mat time ' plotVar]);
%     timeRec.ref = time;
    eval(['timeRec.ref_' int2str(iRef) ' = time;']);
    eval(['well.ref_' int2str(iRef) ' = ' plotVar ';']);
    eval(['clear time ' plotVar]);
end
end

function [] = plotToolKit(oDir, caseName, targetSchedule, trainingSchedule, timeRec, well, plotVar)
nWell = size(well.recon,2);
set(0, 'DefaultAxesFontSize', 20);
print_training = 2; % 1. print one training, 2. print multiple training
for iWell = 1:nWell
    figure()
    hold on;
    h_full = plot(timeRec.full, well.full(:,iWell),'ro--','linewidth',2);
    if print_training == 1
        plot(timeRec.ref_1, well.ref_1(:,iWell),'k--','linewidth',2);
    else
        grey = [0.7,0.7,0.7];
        for iRef = 1 : size(trainingSchedule, 2)
            eval(['h_ref = plot(timeRec.ref_' int2str(iRef) ', well.ref_' int2str(iRef) '(:,iWell),''color'', grey,''linewidth'',2);']);
        end
    end
h_recon = plot(timeRec.recon, well.recon(:,iWell),'b^--','linewidth',2);
legend([h_full, h_ref, h_recon],{'ADGPRS','Training','POD-TPWL'},'location','best');
if strcmp(plotVar, 'wellVar')
    axis([0 max(timeRec.recon) ...
	floor(min([well.ref_1(:,iWell); well.full(:, iWell); well.recon(:,iWell)])*0.99) ...
	ceil(max([well.ref_1(:,iWell); well.full(:, iWell); well.recon(:,iWell)])*1.01) ...
	]);
    xlabel('Time (day)');
    ylabel('Well BHP (psia)');
    figure_name = [oDir, caseName, '_schedule_' int2str(targetSchedule) '_well_' int2str(iWell)];
else % total mobility
    axis([0 max(timeRec.recon) ...
	floor(min([well.ref_1; well.full; well.recon])*0.99) ...
	ceil(max([well.ref_1; well.full; well.recon])*1.01) ...
	]);
    xlabel('Time (day)');
    ylabel('Total mobility (lb mol RB^{-1} cP^{-1})');
    figure_name = [oDir, caseName, '_schedule_' int2str(targetSchedule) '_mobility'];    
end
eval(['print -dpng -r300 -cmyk -zbuffer ' figure_name '.png']);
end
end




