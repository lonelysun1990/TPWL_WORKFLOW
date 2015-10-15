% plot the injection rate as well as the saturation map
function [] = generalPlot_attemp(rootDir, caseName, schedule, trainingSchedule, isTraining, plotTime, axis, slice, comp)
caseDir = [rootDir caseName '/'];
dataFile = [caseDir, 'data/stateVariable_' int2str(schedule) '.mat'];
reconFile = [caseDir, 'data/priVarTPWL_' int2str(schedule) '.mat'];
trainFile = [caseDir, 'data/stateVariable_' int2str(trainingSchedule) '.mat'];
oputDir = [caseDir, 'data/figure_output/'];
if isTraining % full-order simulation
    eval(['load ' dataFile]);
else % reduced-order simulation
    eval(['load ' reconFile]);
    eval(['load ' trainFile ' snapShots']);
    snapShots_train = snapShots;
    eval(['load ' dataFile ' snapShots']);
end
eval(['load ' caseDir, 'data/', caseName '.mat']); % load caseObj

%% plot injection rate
if isTraining
    wellRatePlot(oputDir, caseName, wellRate, time, schedule);
    stateMatrix = snapShots;
else
    stateMatrix = stateRecord; % convert the name of variable
end
%% validate plot time
plot_time_step = timeValidate(time, plotTime);
%% plot pressure/saturation map
[ center_res_data ] = centerRes(stateMatrix, caseObj.nComp, caseObj.cen_x, ...
    caseObj.cen_y, caseObj.res_x, caseObj.res_y, caseObj.res_z); % get center info
centerMapPlot(oputDir, isTraining, 0, caseName, center_res_data, caseObj.dx, caseObj.dy,...
    caseObj.dz, caseObj.cen_x, caseObj.cen_y, caseObj.cen_z, axis, slice, ...
    comp, plot_time_step, plotTime, schedule); % plot map


if ~isTraining
%% plot the 45 degree line for CO2 saturation
satCompare(oputDir, caseName, schedule, stateRecord, snapShots, plot_time_step, plotTime);
%% plot difference map
[ train_center_data ] = centerRes(snapShots_train, caseObj.nComp, caseObj.cen_x, ...
    caseObj.cen_y, caseObj.res_x, caseObj.res_y, caseObj.res_z); 
[ true_center_data ] = centerRes(snapShots, caseObj.nComp, caseObj.cen_x, ...
    caseObj.cen_y, caseObj.res_x, caseObj.res_y, caseObj.res_z); 
[trainDiff, testDiff] = dataDiff(center_res_data, train_center_data, true_center_data);
% plot differnce map between training and true test
centerMapPlot(oputDir, 1, 1, caseName, trainDiff, caseObj.dx, caseObj.dy,...
    caseObj.dz, caseObj.cen_x, caseObj.cen_y, caseObj.cen_z, axis, slice, ...
    comp, plot_time_step, plotTime, schedule); 
% plot difference map between TPWL and true test
centerMapPlot(oputDir, isTraining, 1, caseName, testDiff, caseObj.dx, caseObj.dy,...
    caseObj.dz, caseObj.cen_x, caseObj.cen_y, caseObj.cen_z, axis, slice, ...
    comp, plot_time_step, plotTime, schedule);

%% plot the total mobility
mobilityPlot()

end
end

function [ center_res_data ] = centerRes(stateMatrix, nComp, cen_x, cen_y, ...
    res_x, res_y, res_z)
% the ouput variable center_reservoir_data is a 5-D variable, order of
% dimension: [nComp, x, y, z, time]
edge_x = floor((res_x - cen_x)/2);
edge_y = floor((res_y - cen_y)/2);
full_res_data = reshape(stateMatrix, nComp, res_x, res_y, res_z, []);
center_res_data = full_res_data(:, edge_x + 1:edge_x + cen_x, ...
    edge_y + 1:edge_y + cen_y, :,:);
end

function [] = centerMapPlot(oputDir, isTraining, isDiff, caseName, center_res_data, dx, dy, ...
    dz, cen_x, cen_y, cen_z, axis, slice, comp, plot_time_step, plotTime, schedule)
% axis = 'x'; 'y'; 'z'.
% comp = 1 for pressure; the rest for saturation.
set(0, 'DefaultAxesFontSize', 20);
figureID = figure();
if axis == 'x'
    var_map = reshape(center_res_data(comp,slice,:,:,plot_time_step),cen_y, cen_z);
    [var_map_alt, dz_alt] = interpZ(var_map, dz, dy);
    imagesc(dy,dz_alt,var_map_alt);
    set(figureID, 'PaperUnits', 'inches', 'PaperPosition', [0,0,7,3]);
    xlabel('x (meter)');
    ylabel('z (meter)');
elseif axis == 'y'
    var_map = reshape(center_res_data(comp,:,slice,:,plot_time_step),cen_x, cen_z);
    [var_map_alt, dz_alt] = interpZ(var_map, dz, dx);
    imagesc(dx,dz_alt,var_map_alt);
    set(figureID, 'PaperUnits', 'inches', 'PaperPosition', [0,0,7,3]);
    xlabel('x (meter)');
    ylabel('z (meter)');
elseif axis == 'z'
    var_map = reshape(center_res_data(comp,:,:,slice,plot_time_step),cen_x, cen_y);
    imagesc(dx,dy,var_map');
    xlabel('x (meter)');
    ylabel('y (meter)'); 
else
    disp('Map plotting failure! Please specify axis.');
    close(figureID);
    return;
end
% title([axis ' ' int2str(slice) ' @ ' int2str(plotTime) ' days']);
if isDiff ~= 1
    caxis([0,0.75]); % 1.0 %0.75
else
    caxis([0,0.10]); % 0.05
end
colorbar;
% eval(['saveas(figureID, ' '''' oputDir '\' caseName '_' axis '_' int2str(slice) ...
%     '_' int2str(plotTime) 'days'', ''png'');']);
if isTraining
    type = 'full_order';
else
    type = 'reconstruct';
end
figure_name = [oputDir caseName '_schedule_' int2str(schedule) '_' axis '_' int2str(slice) '_' int2str(plotTime) 'days_' type];
if isDiff
    figure_name = [figure_name '_diff'];
end
eval(['print -dpng -r300 -cmyk -zbuffer ' figure_name '.png']);
end

function [var_map_alt, dz_alt] = interpZ(var_map, dz, dxy)
z_layer = 200;
dz_alt = 0:sum(dz)/(z_layer-1):sum(dz);
cum_z = reshape([cumsum(dz), cumsum(dz)+0.0001]',[],1);
cum_z = [0;cum_z(1:end-1)];
var_map_temp = reshape([var_map; var_map],length(dxy), 2*length(dz));
[XY, Z] = meshgrid(dxy, cum_z);
[XYq, Zq] = meshgrid(dxy, dz_alt);
var_map_alt = interp2(XY,Z,var_map_temp',XYq,Zq);
end

function [] = wellRatePlot(oputDir, caseName, wellRate, time, schedule)
% inject well
set(0, 'DefaultAxesFontSize', 20);
colorStyle = {'b--','r--','g--','m--'};
wellLabel = {'well 1', 'well 2','well 3','well 4',};
wellRate = abs(wellRate);
nWells = size(wellRate, 2);
figureID = figure();
hold on;
for iWell = 1 : nWells
    plot(time, wellRate(:,iWell,1), colorStyle{iWell}, 'linewidth',3) % gas phase 1, water phase 2;   
end
xlabel('Time (day)');
ylabel('Rate (m^{3}/day)');
% eval(['title(''schedule ' int2str(schedule) ' CO2 Rate'')']);
legend(wellLabel,'location','best');
axis([0 time(end) min(min(wellRate(:,:,1)))*0.95 max(max(wellRate(:,:,1))*1.05)]);
% eval(['saveas(figureID, ' '''' oputDir '\' caseName '_ctrl_' int2str(schedule) ...
%     ''', ''png'');']);
figure_name = [oputDir caseName '_ctrl_' int2str(schedule)];
eval(['print -dpng -r300 -cmyk -zbuffer ' figure_name '.png'])
end

function [plot_time_step] = timeValidate(time, plotTime)
plot_time_step = find(time>=plotTime,1);
if isempty(plot_time_step)
    disp('Map plotting failure! Time out of range.');
    return;
end
end

function satCompare(oputDir, caseName, schedule, stateRecord, snapShots, plot_time_step, plotTime)
set(0, 'DefaultAxesFontSize', 20);
% 45 degree line for pressure
figure()
range = max(snapShots(1:2:end-1,plot_time_step)) - min(snapShots(1:2:end-1,plot_time_step));
min_p = min(snapShots(1:2:end-1,plot_time_step)) - range * 0.2;
max_p = max(snapShots(1:2:end-1,plot_time_step)) + range * 0.2;
line = linspace(min_p, max_p);
plot(line,line,'r--','linewidth',2);
hold on;
plot(snapShots(1:2:end-1,plot_time_step), stateRecord(1:2:end-1,plot_time_step),'b.','markersize',15);
legend('45 degree line','POD-TPWL vs. AD-GPRS','location','best');
xlabel('Pressure AD-GPRS (psi)');
ylabel('Pressure POD-TPWL (psi)');
axis([min_p max_p min_p max_p]);
figure_name = [oputDir caseName '_schedule_' int2str(schedule) '_' int2str(plotTime) 'days_pressure'];
eval(['print -dpng -r300 -cmyk -zbuffer ' figure_name '.png']);

% 45 degree line for pressure
figure()
line = linspace(min(snapShots(2:2:end,plot_time_step))*0.97,max(snapShots(2:2:end,plot_time_step))*1.02);
plot(line,line,'r--','linewidth',2);
hold on;
plot(snapShots(2:2:end,plot_time_step), stateRecord(2:2:end,plot_time_step),'b.','markersize',15);
legend('45 degree line','POD-TPWL vs. AD-GPRS','location','best');
xlabel('CO_{2} molar fraction AD-GPRS');
ylabel('CO_{2} molar fraction POD-TPWL');
axis([0 0.8 0 0.8]);%1.05 %0.8
figure_name = [oputDir caseName '_schedule_' int2str(schedule) '_' int2str(plotTime) 'days_comp'];
eval(['print -dpng -r300 -cmyk -zbuffer ' figure_name '.png']);
end

function [trainDiff, testDiff] = dataDiff(center_res_data, train_center_data, true_center_data)
trainDiff = abs(center_res_data - train_center_data);
testDiff = abs(center_res_data - true_center_data);
end




