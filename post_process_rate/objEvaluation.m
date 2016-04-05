function [obj_val] = objEvaluation(caseDir, optSchedule, isTPWL)
iDir = [caseDir 'data/'];
oDir = [iDir 'figure_output/'];

% confining layer total mobility is the objective function 
% top layer mobility over time
%[timeRec, well] = readObjResults(iDir, optSchedule, 'total_mob', isTPWL);
%obj_val = objFunCalculation(well);

% confining layer CO2 molar fraction
obj_val = molarFraction(iDir, optSchedule);
% later
end

function obj_val = molarFraction(iDir, optSchedule)
eval(['load ' iDir 'priVarTPWL_' int2str(optSchedule) '.mat']);

n_comp = 2;
n_timestep = size(stateRecord, 2);


temp = reshape(stateRecord, n_comp,[], n_timestep);
temp_2 = reshape(temp(n_comp,:,:), [], n_timestep);
temp_3 = reshape(temp_2(:,n_timestep), 39, 39, 10);
temp_4 = reshape(temp_3(:,:,3), 39,39);
temp_5 = temp_4(8:32, 8:32);
obj_val = sum(sum(temp_5));
end

function [timeRec, well] = readObjResults(iDir, targetSchedule, plotVar, isTPWL)
%% reconstructed by POD-TPWL
if isTPWL
    eval(['load ' iDir 'recon_well_' int2str(targetSchedule) '.mat time ' plotVar]);
    timeRec.recon = time;
    eval(['well = ' plotVar ';']);
    eval(['clear time ' plotVar]);
else % full order AD-GPRS
    %% full order reference from AD-GPRS
    eval(['load ' iDir 'full_well_' int2str(targetSchedule) '.mat time ' plotVar]);
    timeRec.full = time;
    eval(['well = ' plotVar ';']);
    eval(['clear time ' plotVar]);
end

% %% training from AD-GPRS
% for iRef = 1 : size(trainingSchedule, 2)
%     eval(['load ' iDir 'full_well_' int2str(trainingSchedule(iRef)) '.mat time ' plotVar]);
% %     timeRec.ref = time;
%     eval(['timeRec.ref_' int2str(iRef) ' = time;']);
%     eval(['well.ref_' int2str(iRef) ' = ' plotVar ';']);
%     eval(['clear time ' plotVar]);
% end
end

function [obj_val] = objFunCalculation(well)
% the value of total mobility at the end of injection period
obj_val = well(end);
end