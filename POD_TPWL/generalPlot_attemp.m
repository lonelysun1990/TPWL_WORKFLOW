% plot the injection rate as well as the saturation map
function [] = generalPlot_attemp(schedule, caseName, plotTime, axis, slice, comp)
dataFile = ['stateVariable_' int2str(schedule) '.mat'];
eval(['load ' dataFile]);
eval(['load ' caseName '.mat']); % load caseObj
oputDir = 'figure_output';
%% plot injection rate
wellRatePlot(oputDir, caseName, wellRate, time);
%% validate plot time
[valid, plot_time_step] = timeValidate(time, plotTime);
if valid == 0
    return;
end
%% plot pressure/saturation map
[ center_res_data ] = centerRes(snapShots, caseObj.nComp, caseObj.cen_x, ...
    caseObj.cen_y, caseObj.res_x, caseObj.res_y, caseObj.res_z); % get center info
centerMapPlot(oputDir, caseName, center_res_data, caseObj.dx, caseObj.dy,...
    caseObj.dz, caseObj.cen_x, caseObj.cen_y, caseObj.cen_z, axis, slice, ...
    comp, plot_time_step, plotTime); % plot map
end

function [ center_res_data ] = centerRes(snapShots, nComp, cen_x, cen_y, ...
    res_x, res_y, res_z)
% the ouput variable center_reservoir_data is a 5-D variable, order of
% dimension: [nComp, x, y, z, time]
edge_x = floor((res_x - cen_x)/2);
edge_y = floor((res_y - cen_y)/2);
full_res_data = reshape(snapShots, nComp, res_x, res_y, res_z, []);
center_res_data = full_res_data(:, edge_x + 1:edge_x + cen_x, ...
    edge_y + 1:edge_y + cen_y, :,:);
end

function [] = centerMapPlot(oputDir, caseName, center_res_data, dx, dy, ...
    dz, cen_x, cen_y, cen_z, axis, slice, comp, plot_time_step, plotTime)
% axis = 'x'; 'y'; 'z'.
% comp = 1 for pressure; the rest for saturation.
figureID = figure();
if axis == 'x'
    var_map = reshape(center_res_data(comp,slice,:,:,plot_time_step),cen_y, cen_z);
    imagesc(dy,dz,var_map');
    set(figureID, 'PaperUnits', 'inches', 'PaperPosition', [0,0,7,3]);
    xlabel('z(meter)');
    ylabel('y(meter)');
elseif axis == 'y'
    var_map = reshape(center_res_data(comp,:,slice,:,plot_time_step),cen_x, cen_z);
    imagesc(dx,dz,var_map');
    set(figureID, 'PaperUnits', 'inches', 'PaperPosition', [0,0,7,3]);
    xlabel('z(meter)');
    ylabel('x(meter)');
elseif axis == 'z'
    var_map = reshape(center_res_data(comp,:,:,slice,plot_time_step),cen_x, cen_y);
    imagesc(dx,dy,var_map');
    xlabel('y(meter)');
    ylabel('x(meter)'); 
else
    disp('Map plotting failure! Please specify axis.');
    close(figureID);
    return;
end
title([axis ' ' int2str(slice) ' @ ' int2str(plotTime) ' days']);
caxis([0,1]);
colorbar;
eval(['saveas(figureID, ' '''' oputDir '\' caseName '_' axis '_' int2str(slice) ...
    '_' int2str(plotTime) 'days'', ''png'');']);
end

function [] = wellRatePlot(oputDir, caseName, wellRate, time)
% inject well
wellRate = abs(wellRate);
nWells = size(wellRate, 2);
for iWell = 1 : nWells
    figureID = figure();
    years = time / 365;
    plot(years, wellRate(:,iWell,1),'linewidth',3) % gas phase 1, water phase 2;
    xlabel('Time(Years)');
    ylabel('Rate (M^{3}/Day)');
    eval(['title(''Well ' int2str(iWell) ' CO2 Rate'')']);
    eval(['saveas(figureID, ' '''' oputDir '\' caseName '_well_' int2str(iWell) ...
     ''', ''png'');']);
end
end

function [valid, plot_time_step] = timeValidate(time, plotTime)
plot_time_step = find(time>=plotTime,1);
if isempty(plot_time_step)
    valid = 0;
    disp('Map plotting failure! Time out of range.');
else
    valid = 1;
end
end